# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"

RSpec.describe "Day-2 bucket security and portable ingress" do
  let(:chart) { File.expand_path("../../helm/reportportal-rich-experience", __dir__) }

  def render(*settings)
    command = [ENV.fetch("HELM_BIN", "helm"), "template", "day2", chart, "--namespace", "day2"]
    settings.each { |setting| command += ["--set", setting] }
    output, error, status = Open3.capture3(*command)
    raise "Chart render failed: #{error}" unless status.success?

    YAML.load_stream(output).compact
  end

  def configuration(*settings)
    render(*settings).find { |entry| entry.dig("metadata", "name") == "day2-video-bucket-config" }.fetch("data")
  end

  def reconcile(enabled: "true", public_read: "true", failure: nil)
    config = configuration
    Dir.mktmpdir("rp-day2-job-") do |directory|
      config.each { |name, body| File.write(File.join(directory, name), body) }
      mc = File.join(directory, "mc")
      File.write(mc, <<~RUBY)
        #!#{RbConfig.ruby}
        require "json"
        File.open(ENV.fetch("MC_LOG"), "a") { |file| file.puts(JSON.generate(ARGV)) }
        if ENV["MC_FAILURE"] == "absent" && ARGV.include?("get-json")
          puts JSON.generate(error: {cause: {Code: "NoSuchBucket"}})
          exit 1
        end
        if ENV["MC_FAILURE"] == "private" && ARGV.include?("get-json")
          puts JSON.generate(error: {cause: {Code: "NoSuchBucketPolicy"}})
          exit 1
        end
        exit 7 if ENV["MC_FAILURE"] == "inspect" && ARGV.include?("get-json")
        exit 8 if ENV["MC_FAILURE"] == "ilm" && ARGV.include?("ilm")
        exit 9 if ENV["MC_FAILURE"] == "quota" && ARGV.include?("quota")
      RUBY
      File.chmod(0o700, mc)
      File.write(File.join(directory, "grep"), "#!/bin/sh\nexit 99\n")
      File.chmod(0o700, File.join(directory, "grep"))
      log = File.join(directory, "calls.ndjson")
      environment = {"PATH" => "#{directory}:#{ENV.fetch('PATH')}", "MC_LOG" => log,
                     "MC_FAILURE" => failure, "MINIO_CONFIGURATION_DIR" => directory,
                     "MINIO_BUCKET" => "automation-videos", "MINIO_ENDPOINT" => "http://minio.invalid:9000",
                     "MINIO_ACCESS_KEY" => "synthetic-key", "MINIO_SECRET_KEY" => "synthetic-secret",
                     "MINIO_WAIT_ATTEMPTS" => "1", "MINIO_WAIT_SLEEP_SECONDS" => "0",
                     "MINIO_BUCKET_ENABLED" => enabled, "MINIO_MAKE_PUBLIC" => public_read,
                     "MINIO_RETENTION_ENABLED" => "true", "MINIO_QUOTA_ENABLED" => "true",
                     "MINIO_QUOTA_SIZE" => "4GiB", "MINIO_OBJECT_PREFIX" => "videos"}
      stdout, stderr, status = Open3.capture3(environment, "/bin/sh", File.join(directory, "reconcile.sh"))
      calls = File.file?(log) ? File.readlines(log).map { |line| JSON.parse(line) } : []
      [calls, stdout + stderr, status]
    end
  end

  it "grants only anonymous GetObject and never listing, upload, delete or bucket administration" do
    policy = JSON.parse(configuration.fetch("read-only.json"))
    expect(policy.fetch("Statement")).to eq([
      {"Action" => ["s3:GetObject"], "Effect" => "Allow", "Principal" => {"AWS" => ["*"]},
       "Resource" => ["arn:aws:s3:::automation-videos/*"], "Sid" => "AnonymousObjectReadOnly"}
    ])
    expect(JSON.parse(configuration.fetch("private.json")).fetch("Statement")).to eq([])
  end

  it "replaces legacy grants with the entire read-only policy and reconciles quota and stable retention" do
    calls, output, status = reconcile
    expect(status).to be_success
    expect(calls.find { |args| args[0, 2] == %w[anonymous set-json] }[2]).to end_with("/read-only.json")
    expect(calls).to include(%w[ilm rule import reportportal/automation-videos],
                             %w[quota set reportportal/automation-videos --size 4GiB])
    expect(output).not_to include("synthetic-key", "synthetic-secret")
    lifecycle = JSON.parse(configuration.fetch("lifecycle.json"))
    expect(lifecycle.fetch("Rules").length).to eq(1)
    expect(lifecycle.dig("Rules", 0, "ID")).to eq("rp-automation-video-retention")
    expect(lifecycle.dig("Rules", 0, "Expiration", "Days")).to eq(30)
    expect(lifecycle.dig("Rules", 0, "NoncurrentVersionExpiration", "NoncurrentDays")).to eq(30)
    # The pinned community server silently discards bucket-level abort rules.
    expect(lifecycle.fetch("Rules").first).not_to have_key("AbortIncompleteMultipartUpload")
  end

  it "actively revokes all previous anonymous grants when makePublic becomes false" do
    calls, _output, status = reconcile(public_read: "false")
    expect(status).to be_success
    expect(calls.find { |args| args[0, 2] == %w[anonymous set-json] }[2]).to end_with("/private.json")
  end

  it "keeps a revocation Job but removes the video route when the extension is disabled" do
    documents = render("videoBucket.enabled=false")
    expect(documents.any? { |entry| entry["kind"] == "Job" && entry.dig("metadata", "name") == "day2-video-bucket-init" }).to be(true)
    expect(documents.any? { |entry| entry["kind"] == "Ingress" && entry.dig("metadata", "name") == "day2-video-bucket" }).to be(false)
    calls, _output, status = reconcile(enabled: "false")
    expect(status).to be_success
    expect(calls.find { |args| args[0, 2] == %w[anonymous set-json] }[2]).to end_with("/private.json")
    expect(calls.flatten).not_to include("mb", "cp", "ilm", "quota")
  end

  it "treats an absent disabled bucket as safe but refuses to disguise an inspection failure" do
    calls, _output, status = reconcile(enabled: "false", failure: "absent")
    expect(status).to be_success
    expect(calls.flatten).not_to include("set-json", "mb")
    _calls, output, status = reconcile(enabled: "false", failure: "inspect")
    expect(status).not_to be_success
    expect(output).to include("revocation was NOT verified")
    calls, _output, status = reconcile(enabled: "false", failure: "private")
    expect(status).to be_success
    expect(calls.flatten).to include("set-json")
    expect(calls.flatten).not_to include("mb")
  end

  it "fails initialization when retention or hard quota cannot be applied" do
    %w[ilm quota].each do |failure|
      _calls, output, status = reconcile(failure: failure)
      expect(status).not_to be_success
      expect(output).not_to include("Video bucket reconciled:")
    end
  end

  it "offers explicit opt-out of policy management without pretending to revoke access" do
    documents = render("videoBucket.enabled=false", "videoBucket.revokeOnDisable=false")
    expect(documents.map { |entry| entry.dig("metadata", "name") }.grep(/video-bucket/)).to be_empty
  end

  it "routes the bucket using portable Prefix matching without regex, rewriting or nginx annotations" do
    ingress = render.find { |entry| entry["kind"] == "Ingress" && entry.dig("metadata", "name") == "day2-video-bucket" }
    expect(ingress.dig("spec", "ingressClassName")).to eq("traefik")
    path = ingress.dig("spec", "rules", 0, "http", "paths", 0)
    expect(path.fetch("path")).to eq("/automation-videos")
    expect(path.fetch("pathType")).to eq("Prefix")
    expect(path.dig("backend", "service", "port", "number")).to eq(9000)
    expect(ingress.fetch("metadata").fetch("annotations", {}).to_s).not_to include("nginx", "rewrite", "regex")
  end

  it "reserves at least half of the rendered MinIO volume for non-video data in shipped profiles" do
    %w[values.yaml values-local-latest.yaml values-production.example.yaml values-huawei.example.yaml].each do |profile|
      output, error, status = Open3.capture3(ENV.fetch("HELM_BIN", "helm"), "template", "day2", chart,
                                            "-f", File.join(chart, profile))
      raise error unless status.success?

      documents = YAML.load_stream(output).compact
      volume = documents.find { |entry| entry["kind"] == "PersistentVolumeClaim" && entry.dig("metadata", "name") == "day2-minio" }
      size = volume.dig("spec", "resources", "requests", "storage")
      expect(size).to eq("8Gi")
      job = documents.find { |entry| entry["kind"] == "Job" && entry.dig("metadata", "name") == "day2-video-bucket-init" }
      quota = job.dig("spec", "template", "spec", "containers", 0, "env").find { |entry| entry["name"] == "MINIO_QUOTA_SIZE" }
      expect(quota.fetch("value")).to eq("4GiB")
    end
  end

  it "rejects malformed bucket names and non-positive retention instead of emitting unsafe policies" do
    ["videoBucket.name=bad_bucket", "videoBucket.retention.expireDays=0",
     "videoBucket.retention.expireDays=1.5", "videoBucket.quota.size=0GiB"].each do |setting|
      _out, _error, status = Open3.capture3(ENV.fetch("HELM_BIN", "helm"), "template", "day2", chart, "--set", setting)
      expect(status).not_to be_success
    end
    _out, _error, status = Open3.capture3(ENV.fetch("HELM_BIN", "helm"), "template", "day2", chart,
                                        "--set-string", "videoBucket.retention.expireDays=30")
    expect(status).not_to be_success
  end
end
