# frozen_string_literal: true

require "spec_helper"
require "openssl"
require "socket"
require "timeout"

RSpec.describe ReportportalCucumber::Transport::MinioUploader do
  let(:config) do
    ReportportalCucumber::Config.new(
      minio_endpoint: "http://localhost:9000",
      minio_public_base_url: "http://localhost:9000",
      minio_bucket: "automation-videos",
      minio_access_key_id: "synthetic-access-key",
      minio_secret_access_key: "synthetic-secret-key",
      minio_region: "us-east-1"
    )
  end

  it "verifies TLS peers by default and only accepts a boolean false opt-out" do
    [config, ReportportalCucumber::Config.new(minio_ssl_verify_peer: true,
      minio_access_key_id: "synthetic-access", minio_secret_access_key: "synthetic-secret")].each do |settings|
      uploader = described_class.new(config: settings)
      expect(uploader.instance_variable_get(:@client).config.ssl_verify_peer).to be(true)
    end
    uploader = described_class.new(config: ReportportalCucumber::Config.new(minio_ssl_verify_peer: false,
      minio_access_key_id: "synthetic-access", minio_secret_access_key: "synthetic-secret"))
    expect(uploader.instance_variable_get(:@client).config.ssl_verify_peer).to be(false)
    settings = config.dup
    settings.define_singleton_method(:minio_ssl_verify_peer) { "false" }
    expect(described_class.new(config: settings).instance_variable_get(:@client).config.ssl_verify_peer).to be(true)
  end

  # @return [Array<OpenSSL::X509::Certificate, OpenSSL::PKey::RSA>] Synthetic localhost identity.
  def local_tls_identity
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.parse("/CN=localhost")
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60
    cert.not_after = Time.now + 3600
    factory = OpenSSL::X509::ExtensionFactory.new
    factory.subject_certificate = cert
    factory.issuer_certificate = cert
    cert.add_extension(factory.create_extension("basicConstraints", "CA:TRUE", true))
    cert.add_extension(factory.create_extension("keyUsage", "digitalSignature,keyEncipherment,keyCertSign", true))
    cert.add_extension(factory.create_extension("subjectAltName", "DNS:localhost,IP:127.0.0.1"))
    cert.sign(key, OpenSSL::Digest.new("SHA256"))
    [cert, key]
  end

  [false, true].each do |trusted|
    it "#{trusted ? 'uploads with an explicitly trusted' : 'rejects an untrusted'} real local TLS certificate within a deadline" do
      cert, key = local_tls_identity
      tcp = TCPServer.new("127.0.0.1", 0)
      context = OpenSSL::SSL::SSLContext.new
      context.cert = cert
      context.key = key
      server = OpenSSL::SSL::SSLServer.new(tcp, context)
      uploaded = Queue.new
      worker = Thread.new do
        socket = nil
        Timeout.timeout(5) do
          socket = server.accept
          headers = []
          while (line = socket.gets) && line != "\r\n"
            headers << line
          end
          socket.write("HTTP/1.1 100 Continue\r\n\r\n") if headers.join.match?(/Expect:\s*100-continue/i)
          length = headers.join[/Content-Length:\s*(\d+)/i, 1].to_i
          uploaded << socket.read(length)
          socket.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        end
      rescue OpenSSL::SSL::SSLError
        # Expected when the client refuses the self-signed peer before sending data.
        nil
      ensure
        socket&.close
      end
      endpoint = "https://127.0.0.1:#{tcp.addr[1]}"
      Dir.mktmpdir("minio-tls-") do |directory|
        bundle = File.join(directory, "synthetic-ca.pem")
        File.write(bundle, cert.to_pem)
        settings = ReportportalCucumber::Config.new(minio_endpoint: endpoint, minio_public_base_url: endpoint,
          minio_access_key_id: "synthetic-tls-access", minio_secret_access_key: "synthetic-tls-secret",
          minio_ssl_ca_bundle: trusted ? bundle : nil)
        allow(Aws::S3::Client).to receive(:new).and_wrap_original do |original, **options|
          original.call(**options, retry_limit: 0, http_open_timeout: 2, http_read_timeout: 2,
                        http_continue_timeout: 0.1, http_proxy: nil)
        end
        WebMock.disable_net_connect!(allow: %r{\Ahttps://127\.0\.0\.1:#{tcp.addr[1]}/})
        result = nil
        expect do
          Timeout.timeout(4) do
            result = described_class.new(config: settings).upload_video(bytes: "synthetic-mp4", name: "tls.mp4")
          end
        end.to output(trusted ? "" : /Video upload failed/).to_stderr
        if trusted
          expect(result).to start_with(endpoint)
          expect(Timeout.timeout(2) { uploaded.pop }).to eq("synthetic-mp4")
        else
          expect(result).to start_with("Video upload failed")
          expect(result).to match(/certificate verify failed|self.signed/i)
          expect(uploaded).to be_empty
        end
        expect(worker.join(2)).not_to be_nil
      end
    ensure
      tcp&.close
      worker&.kill if worker&.alive?
      worker&.join
      WebMock.disable_net_connect!(allow_localhost: true)
    end
  end

  it "sanitizes bounded failure diagnostics and artifact names on stderr and fallback output" do
    errors = [
      'upload https://PRIVACY_MINIO_USER:PRIVACY_MINIO_PASSWORD@example.test/?token=PRIVACY_MINIO_TOKEN failed password=PRIVACY_MINIO_FIELD',
      '{"pass\u0077ord":"PRIVACY_MINIO_MALFORMED"',
      'upload: {"pass\u0077ord":"PRIVACY_MINIO_EMBEDDED"}',
      "PRIVACY_MINIO_OVERSIZED" + ("x" * 70_000)
    ]
    errors.each do |message|
      client = instance_double(Aws::S3::Client)
      allow(client).to receive(:put_object).and_raise(StandardError, message)
      terminal = StringIO.new
      previous = $stderr
      $stderr = terminal
      result = described_class.new(config: config, client: client).upload_video(
        bytes: "synthetic-mp4", name: "password=PRIVACY_MINIO_NAME")
      expect(result).to start_with("Video upload failed")
      expect(result).to include("The Cucumber run was not interrupted")
      expect(result.bytesize).to be <= described_class::DIAGNOSTIC_LIMIT + 512
      expect(terminal.string.bytesize).to be <= described_class::DIAGNOSTIC_LIMIT + 64
      expect(result + terminal.string).not_to include("PRIVACY_MINIO_")
    ensure
      $stderr = previous
    end
  end

  it "stays fail-safe when the exception message or diagnostic output itself fails" do
    client = instance_double(Aws::S3::Client)
    error = StandardError.new("synthetic failure")
    allow(error).to receive(:message).and_raise(IOError, "PRIVACY_UNSAFE_MESSAGE")
    allow(client).to receive(:put_object).and_raise(error)
    allow($stderr).to receive(:puts).and_raise(IOError, "PRIVACY_UNSAFE_STDERR")
    result = described_class.new(config: config, client: client).upload_video(bytes: "synthetic", name: "safe.mp4")
    expect(result).to include(ReportportalCucumber::Service::EvidencePresenter::OMITTED)
    expect(result).not_to include("PRIVACY_UNSAFE_")
  end

  it "publishes only sanitized fallback to the RP wire while preserving degraded-evidence accounting" do
    settings = ReportportalCucumber::Config.new(endpoint: "https://privacy-minio-rp.example.test", project: "synthetic",
      api_key: "synthetic-rp-key", video_upload_mode: "minio_markdown", batch_size_logs: 1, retry_attempts: 1)
    client = instance_double(Aws::S3::Client)
    allow(client).to receive(:put_object).and_raise(StandardError,
      'upload https://PRIVACY_WIRE_USER:PRIVACY_WIRE_PASSWORD@example.test/?token=PRIVACY_WIRE_TOKEN failed')
    uploader = described_class.new(config: settings, client: client)
    wire = []
    stub_request(:post, "#{settings.endpoint}/api/v1/synthetic/log").to_return do |request|
      wire << request.body
      { status: 201, headers: { "Content-Type" => "application/json" }, body: '{"id":"synthetic-log-id"}' }
    end
    api = ReportportalCucumber::ReportPortal::API.new(config: settings)
    processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: settings, video_uploader: uploader)
    expect do
      expect(processor.emit_log(item_uuid: "step-privacy", launch_uuid: "launch-privacy", message: "safe recording",
        level: :error, timestamp: Time.now, attachment: { name: "safe.mp4", mime: "video/mp4", bytes: "synthetic-mp4" })).to be(true)
      expect(processor.shutdown_receipt(timeout: 2).local_settled).to be(true)
      receipt = processor.reporting_receipt(finalization_complete: true)
      expect(receipt.degraded_evidence).to eq(1)
      expect(receipt.confirmed).to eq(1)
      expect(receipt.complete).to be(false)
    end.to output(/REDACTED/).to_stderr
    expect(wire.length).to eq(1)
    expect(wire.join).not_to include("PRIVACY_WIRE_")
    expect(JSON.parse(wire.first).fetch("message")).to include("Video upload failed", "safe recording")
  ensure
    processor&.shutdown(timeout: 1)
  end

  it "streams path-backed mp4 files to MinIO and returns a public URL" do
    Dir.mktmpdir do |dir|
      video_path = File.join(dir, "failure clip.mp4")
      File.binwrite(video_path, "mp4-bytes")
      captured = nil
      client = instance_double(Aws::S3::Client)
      allow(client).to receive(:put_object) do |params|
        captured = params
        expect(params.fetch(:body).read).to eq("mp4-bytes")
      end

      url = described_class.new(config: config, client: client).upload_video(
        path: video_path,
        name: "failure clip.mp4",
        content_type: "application/mp4"
      )

      expect(captured).to include(
        bucket: "automation-videos",
        content_type: "video/mp4"
      )
      expect(captured.fetch(:key)).to match(%r{\Avideos/\d{4}/\d{2}/\d{2}/.+-failure_clip\.mp4\z})
      expect(url).to start_with("http://localhost:9000/automation-videos/videos/")
      expect(url).to end_with("-failure_clip.mp4")
    end
  end

  it "degrades to a warning message when S3 upload fails" do
    client = instance_double(Aws::S3::Client)
    allow(client).to receive(:put_object).and_raise(Timeout::Error, "execution expired")

    expect do
      result = described_class.new(config: config, client: client).upload_video(
        bytes: "mp4-bytes",
        name: "failure.mp4",
        content_type: "video/mp4"
      )

      expect(result).to include("Video upload failed for failure.mp4")
      expect(result).to include("execution expired")
    end.to output("[WARN] Video upload failed: execution expired\n").to_stderr
  end
end
