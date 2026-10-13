# frozen_string_literal: true

require "spec_helper"
require_relative "../../examples/day2_faults/run_live"

RSpec.describe Day2Faults::LiveGate do
  let(:environment) do
    { "DAY2_MANAGER_READY" => "true", "RP_ENDPOINT" => "http://127.0.0.1:8080",
      "RP_PROJECT" => "portable_project", "RP_API_KEY" => "synthetic-portable-key",
      "DAY2_EXPECTED_API_VERSION" => "5.15.4" }
  end
  let(:backend) do
    { "build" => { "repo" => "reportportal/service-api", "version" => "5.15.4" },
      "extensions" => { "result" => { "server.details.instance" => "sandbox-instance" } } }
  end

  it "requires Manager readiness before credentials or real fault requests are touched" do
    expect { described_class.validate!({}) }.to raise_error(/Wait for Manager/)
  end

  it "rejects remote production and credential-bearing endpoints" do
    %w[https://production.example.com http://user:password@127.0.0.1 http://rp-latest.localhost.evil.example].each do |url|
      expect { described_class.local_url!(url) }.to raise_error(/local cluster URL/)
    end
  end

  it "permits the explicit local gateway preview and preserved RP host" do
    origin, ready = described_class.validate!("DAY2_MANAGER_READY" => "true", "DAY2_RP_ENDPOINT" => "http://rp-latest.localhost",
                                             "DAY2_RP_READY_URL" => "http://127.0.0.1:18080/ready")
    expect(origin.host).to eq("rp-latest.localhost")
    expect(ready.port).to eq(18080)
  end

  it "uses normal RP_ENDPOINT and defaults readiness to its local API info" do
    origin, ready = described_class.validate!(environment)
    expect(origin.to_s).to eq("http://127.0.0.1:8080")
    expect(ready.to_s).to eq("http://127.0.0.1:8080/api/info")
  end

  it "uses RP_API_KEY and RP_PROJECT without loading an auth helper or reading a historical file" do
    expect(described_class).not_to receive(:require)
    expect(File).not_to receive(:read)
    expect(described_class.credentials(environment)).to eq(
      token: "synthetic-portable-key", project: "portable_project", source: "environment"
    )
    expect(described_class.verify_backend!(JSON.generate(backend), environment)).to eq(backend)
  end

  it "prefers environment credentials even if an optional helper is configured" do
    expect(described_class).not_to receive(:require)
    expect(described_class.credentials(environment.merge("DAY2_AUTH_HELPER" => "/nonexistent/local.rb"))[:source])
      .to eq("environment")
  end

  it "requires RP_API_KEY when no explicit helper is selected" do
    expect { described_class.credentials(environment.reject { |key, _| key == "RP_API_KEY" }) }
      .to raise_error(/RP_API_KEY is required/)
  end

  it "rejects missing or path-like projects and multiline credentials" do
    ["", "../project", "project?credential=secret"].each do |project|
      expect { described_class.credentials(environment.merge("RP_PROJECT" => project)) }.to raise_error(/RP_PROJECT/)
    end
    expect { described_class.credentials(environment.merge("RP_API_KEY" => "first\nsecond")) }
      .to raise_error(/single-line/)
  end

  it "allows an explicit absolute local helper only after the local readiness gate" do
    path = File.expand_path("../../examples/day2_faults/native.rb", __dir__)
    helper = Module.new
    helper.define_singleton_method(:login) { nil }
    helper.define_singleton_method(:bearer) { "synthetic-helper-bearer" }
    stub_const("LatestRP", helper)
    expect(described_class).to receive(:require).with(path)
    expect(helper).to receive(:login).once
    result = described_class.credentials(environment.merge("RP_API_KEY" => "", "DAY2_AUTH_HELPER" => path))
    expect(result).to include(token: "synthetic-helper-bearer", project: "portable_project", source: "local_helper")
  end

  it "never loads a helper without Manager readiness or for a remote target" do
    expect(described_class).not_to receive(:require)
    options = environment.merge("RP_API_KEY" => "", "DAY2_AUTH_HELPER" => "/tmp/unused-helper.rb")
    expect { described_class.credentials(options.merge("DAY2_MANAGER_READY" => "false")) }.to raise_error(/Wait for Manager/)
    expect { described_class.credentials(options.merge("RP_ENDPOINT" => "https://production.example.com")) }
      .to raise_error(/local cluster URL/)
  end

  it "rejects relative or URL helper paths" do
    ["helper.rb", "https://example.com/helper.rb"].each do |path|
      expect { described_class.credentials(environment.merge("RP_API_KEY" => "", "DAY2_AUTH_HELPER" => path)) }
        .to raise_error(/absolute local Ruby path/)
    end
  end

  it "requires explicit API version before HTTP or auth" do
    expect(described_class).not_to receive(:bounded_get)
    expect(described_class).not_to receive(:credentials)
    expect { described_class.main(environment.reject { |key, _| key == "DAY2_EXPECTED_API_VERSION" }, ["--execute-local-rp"]) }
      .to raise_error(/DAY2_EXPECTED_API_VERSION/)
  end

  it "verifies repository/version without needing any prior backend-info file" do
    expect(File).not_to receive(:read)
    expect { described_class.verify_backend!(JSON.generate(backend), environment.merge("DAY2_EXPECTED_API_VERSION" => "different")) }
      .to raise_error(/API component/)
    changed = backend.merge("build" => { "repo" => "another/repo", "version" => "5.15.4" })
    expect { described_class.verify_backend!(JSON.generate(changed), environment) }.to raise_error(/API component/)
  end

  it "optionally pins instance identity and does not require it otherwise" do
    expect(described_class.verify_backend!(JSON.generate(backend), environment)).to eq(backend)
    pinned = environment.merge("DAY2_EXPECTED_INSTANCE" => "sandbox-instance")
    expect(described_class.verify_backend!(JSON.generate(backend), pinned)).to eq(backend)
    expect { described_class.verify_backend!(JSON.generate(backend), pinned.merge("DAY2_EXPECTED_INSTANCE" => "wrong")) }
      .to raise_error(/instance/)
  end
end

RSpec.describe Day2Faults::SourceManifest do
  it "records current harness, fault tests, SDK, and bundle hashes without credentials or generated reports" do
    snapshot = described_class.capture
    expect(snapshot[:files]).to include("examples/day2_faults/run_live.rb", "spec/day2/fault_live_gate_spec.rb",
                                       "lib/reportportal_cucumber.rb", "Gemfile.lock")
    expect(snapshot[:files]).not_to include("examples/day2_faults/VALIDATION.md")
    expect(snapshot[:files].values).to all(match(/\A[0-9a-f]{64}\z/))
    expect(snapshot[:inputs_sha256]).to eq(Digest::SHA256.hexdigest(JSON.generate(snapshot[:files])))
  end

  it "captures before/after source hashes and flags changed inputs without rewriting evidence" do
    directory = Dir.mktmpdir("day2-source-")
    snapshot = described_class.capture
    result = described_class.record(directory: directory, before: snapshot)
    expect(result[:unchanged_during_run]).to be(true)
    expect(result[:manifest_sha256]).to eq(Digest::SHA256.file(File.join(directory, "source-manifest.json")).hexdigest)
    changed = described_class.record(directory: directory, before: snapshot.merge(inputs_sha256: "different"))
    expect(changed[:unchanged_during_run]).to be(false)
  ensure
    FileUtils.remove_entry(directory) if directory && File.directory?(directory)
  end
end
