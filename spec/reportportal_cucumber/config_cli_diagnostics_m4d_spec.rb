# frozen_string_literal: true

require "spec_helper"
require "digest"
require "json"
require "open3"
require "rbconfig"

RSpec.describe "M4-D bounded Config and CLI diagnostics" do
  limits = {
    spool_max_bytes: "RP_SPOOL_MAX_BYTES", queue_max_records: "RP_QUEUE_MAX_RECORDS",
    queue_max_bytes: "RP_QUEUE_MAX_BYTES", batch_size_logs: "RP_BATCH_SIZE_LOGS",
    batch_max_bytes: "RP_BATCH_MAX_BYTES", queue_admission_timeout_ms: "RP_QUEUE_ADMISSION_TIMEOUT_MS"
  }

  limits.each do |key, option|
    it "identifies #{option} without exposing a rejected Config value or changing strict decimal validation" do
      [0, -1, 1.5, true, nil, "0", "-1", "1.5", "1e3", "256MiB", " 10 ", "+2", "PRIVATE_CONFIG_VALUE"].each do |value|
        expect { ReportportalCucumber::Config.new(key => value) }
          .to raise_error(ArgumentError, "#{option} must be a positive decimal integer")
      end
      expect(ReportportalCucumber::Config.new(key => "4096").public_send(key)).to eq(4096)
      expect(ReportportalCucumber::Config.new(key => 4096).public_send(key)).to eq(4096)
    end
  end

  describe "public CLI" do
    let(:directory) { Dir.mktmpdir("m4d-private-diagnostics-") }
    let(:config) do
      ReportportalCucumber::Config.new(endpoint: "https://diagnostic.example.test", project: "diagnostic",
                                      api_key: "PRIVATE_API_SECRET", spool_dir: File.join(directory, "spool"))
    end
    let(:store) { ReportportalCucumber::Service::SpoolStore.new(config: config) }
    let(:entry) do
      { "launchUuid" => "11111111-1111-4111-8111-111111111111",
        "itemUuid" => "22222222-2222-4222-8222-222222222222", "time" => "1791650000000",
        "message" => "PRIVATE_PAYLOAD_SECRET", "level" => "INFO", "file" => { "name" => "PRIVATE_FILENAME.bin" } }
    end
    let(:transaction_id) do
      store.persist(entries: [entry], files: [{ name: "PRIVATE_FILENAME.bin", mime: "application/octet-stream", bytes: "original-bytes" }], outcome: "failed")
    end
    let(:loaded) { store.load_transaction(id: transaction_id) }

    after { FileUtils.remove_entry(directory) }

    def run_cli(label, env: {}, execute: false, timeout: "5")
      root = File.expand_path("../..", __dir__)
      bootstrap = File.join(directory, "bootstrap.rb")
      capture = File.join(directory, "#{label}.json")
      File.write(bootstrap, <<~'RUBY')
        require "webmock"
        require "digest"
        require "json"
        require "reportportal_cucumber"
        WebMock.enable!
        WebMock.disable_net_connect!
        requests = []
        WebMock.after_request { |request, _| requests << request.method }
        WebMock.stub_request(:get, %r{\Ahttps://diagnostic\.example\.test/api/v1/diagnostic/(launch|item)/uuid/})
          .to_return(status: 200, body: '{"status":"IN_PROGRESS"}')
        api_probe = Module.new do
          def new(...)
            $m4_diagnostic_api_constructed = true
            super
          end
        end
        ReportportalCucumber::ReportPortal::API.singleton_class.prepend(api_probe)
        store_probe = Module.new do
          def load_transaction(**arguments)
            super
          rescue ReportportalCucumber::Service::SpoolStore::Error => error
            $m4_diagnostic_reason = error.reason
            raise
          end
        end
        ReportportalCucumber::Service::SpoolStore.prepend(store_probe)
        at_exit do
          sdk = $LOADED_FEATURES.select { |path| path.match?(%r{/reportportal_cucumber(?:/|\.rb)}) && File.file?(path) }
          File.write(ENV.fetch("M4_DIAGNOSTIC_CAPTURE"), JSON.pretty_generate(
            requests: requests, api_constructed: !!$m4_diagnostic_api_constructed, store_reason: $m4_diagnostic_reason,
            gem_root: Gem.loaded_specs["reportportal-cucumber-ruby"]&.full_gem_path,
            sdk: sdk.to_h { |path| [File.realpath(path), Digest::SHA256.file(path).hexdigest] }
          ))
        end
      RUBY
      child_env = ENV.keys.grep(/\A(?:RP_|BUNDLE_|RUBYOPT\z|RUBYLIB\z|BUNDLER_VERSION\z)/).to_h { |key| [key, nil] }
      child_env.merge!("CUCUMBER_PROFILE" => nil, "M4_DIAGNOSTIC_CAPTURE" => capture)
      if execute
        child_env.merge!("RP_ENDPOINT" => config.endpoint, "RP_PROJECT" => config.project, "RP_API_KEY" => config.api_key,
                         "RP_REPORTING_ASYNC" => "false")
      end
      if (installed = ENV["M4_DIAGNOSTIC_INSTALLED_CLI"])
        child_env.merge!("GEM_HOME" => ENV.fetch("M4_DIAGNOSTIC_GEM_HOME"), "GEM_PATH" => ENV.fetch("M4_DIAGNOSTIC_GEM_PATH"))
        command = [RbConfig.ruby, "-r", bootstrap, installed]
        expected_root = ENV.fetch("M4_DIAGNOSTIC_INSTALLED_ROOT")
      else
        command = [RbConfig.ruby, "-I#{File.join(root, 'lib')}", "-r", bootstrap, File.join(root, "exe/reportportal-spool")]
        expected_root = root
      end
      stdout, stderr, process = Open3.capture3(child_env.merge(env), *command, "--spool-dir", config.spool_dir,
                                             "--transaction", transaction_id, execute ? "--execute" : "--dry-run",
                                             "--timeout", timeout, chdir: directory)
      captured = JSON.parse(File.read(capture))
      %w[config.rb service/spool_store.rb].each do |source|
        path = File.join(File.realpath(expected_root), "lib/reportportal_cucumber", source)
        expect(captured.fetch("sdk").fetch(path)).to eq(Digest::SHA256.file(File.join(root, "lib/reportportal_cucumber", source)).hexdigest)
      end
      if (evidence = ENV["M4_DIAGNOSTIC_EVIDENCE"])
        FileUtils.mkdir_p(evidence)
        File.write(File.join(evidence, "#{label}.json"), JSON.pretty_generate(captured.merge("stdout" => stdout, "stderr" => stderr, "exit_status" => process.exitstatus)))
      end
      expect(process.exitstatus).to eq(2), stderr
      expect(stdout).to be_empty
      expect(stderr.bytesize).to be < 512
      expect(stderr).not_to include(directory, transaction_id, "PRIVATE_API_SECRET", "PRIVATE_PAYLOAD_SECRET", "PRIVATE_FILENAME.bin", "PRIVATE_CONFIG_VALUE")
      expect(captured.fetch("requests")).not_to include("post")
      unless execute && timeout != "0"
        expect(captured.fetch("api_constructed")).to be(false)
        expect(captured.fetch("requests")).to be_empty
      end
      [stderr, captured]
    end

    %w[0 -1 1.5 1e3 256MiB PRIVATE_CONFIG_VALUE].each_with_index do |value, index|
      it "labels invalid spool quota case #{index} in sanitized installed-compatible inspection" do
        stderr, = run_cli("invalid-quota-#{index}", env: { "RP_SPOOL_MAX_BYTES" => value })

        expect(stderr).to include("RP_SPOOL_MAX_BYTES must be a positive decimal integer")
      end
    end

    it "distinguishes a missing physical artifact and asks for the original bytes" do
      File.unlink(loaded.fetch(:files).first.fetch(:path))

      stderr, captured = run_cli("missing-attachment")

      expect(captured.fetch("store_reason")).to eq("missing_attachment")
      expect(stderr).to include("missing_attachment", "original artifact bytes")
    end

    it "distinguishes altered artifact bytes from missing evidence" do
      File.binwrite(loaded.fetch(:files).first.fetch(:path), "tampered-bytes")

      stderr, captured = run_cli("corrupt-attachment")

      expect(captured.fetch("store_reason")).to eq("corrupt_attachment")
      expect(stderr).to include("corrupt_attachment", "original artifact bytes")
    end

    it "identifies missing transaction metadata rather than a missing artifact" do
      File.unlink(File.join(loaded.fetch(:directory), ".manifest.json"))

      stderr, captured = run_cli("missing-transaction")

      expect(captured.fetch("store_reason")).to eq("missing_transaction")
      expect(stderr).to include("missing_transaction", "selected transaction")
    end

    it "identifies corrupt entry evidence without printing the payload" do
      File.open(File.join(loaded.fetch(:directory), ".entries.ndjson"), "ab") { |file| file.write("PRIVATE_PAYLOAD_SECRET") }

      stderr, captured = run_cli("corrupt-entries")

      expect(captured.fetch("store_reason")).to eq("corrupt_entries")
      expect(stderr).to include("corrupt_entries", "original transaction")
    end

    %w[unsafe_path invalid_schema].each do |failure|
      it "provides bounded #{failure} remediation without echoing manifest data" do
        path = File.join(loaded.fetch(:directory), ".manifest.json")
        manifest = JSON.parse(File.read(path))
        failure == "unsafe_path" ? manifest.fetch("files").first["path"] = "../PRIVATE_FILENAME.bin" : manifest["version"] = 99
        File.write(path, JSON.generate(manifest))

        stderr, = run_cli(failure)

        expect(stderr).to include(failure)
        expect(stderr).to include(failure == "unsafe_path" ? "non-symlink" : "supported transaction schema")
      end
    end

    it "identifies quota exhaustion during durable pre-send checkpoint without POST" do
      loaded

      stderr, = run_cli("quota-exceeded", env: { "RP_SPOOL_MAX_BYTES" => "1" }, execute: true)

      expect(stderr).to include("quota_exceeded", "RP_SPOOL_MAX_BYTES")
      expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states"))
        .to eq([{ "state" => "pending" }])
    end

    it "identifies an expired overall deadline without loading targets or constructing API" do
      stderr, = run_cli("deadline", execute: true, timeout: "0")

      expect(stderr).to include("deadline_expired", "--timeout")
      expect(store.load_transaction(id: transaction_id).fetch(:checkpoint).fetch("states"))
        .to eq([{ "state" => "pending" }])
    end
  end
end
