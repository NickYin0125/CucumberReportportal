# frozen_string_literal: true

require "spec_helper"
require "digest"
require "json"
require "open3"
require "rbconfig"
require "reportportal_cucumber/service/spool_replay"

RSpec.describe "M4-D locally unavailable replay inspection" do
  let(:directory) { Dir.mktmpdir("m4d-private-unavailable-") }
  let(:config) do
    ReportportalCucumber::Config.new(endpoint: "https://unavailable.example.test", project: "inspection",
                                    api_key: "PRIVATE_AUTH_SECRET", spool_dir: File.join(directory, "spool"))
  end
  let(:store) { ReportportalCucumber::Service::SpoolStore.new(config: config) }
  let(:entry) do
    { "launchUuid" => "11111111-1111-4111-8111-111111111111",
      "itemUuid" => "22222222-2222-4222-8222-222222222222", "time" => "1791650000000",
      "message" => "PRIVATE_PAYLOAD_SECRET", "level" => "INFO" }
  end

  after { FileUtils.remove_entry(directory) }

  def persist_files(unavailable:, healthy: 0)
    records = (unavailable + healthy).times.map do |index|
      entry.merge("file" => { "name" => "PRIVATE_ARTIFACT_#{index}.bin" })
    end
    files = records.each_with_index.map do |record, index|
      source = index < unavailable ? { path: File.join(directory, "missing-#{index}.bin") } : { bytes: "healthy-bytes" }
      { name: record.fetch("file").fetch("name"), mime: "application/octet-stream" }.merge(source)
    end
    store.persist(entries: records, files: files, outcome: "failed")
  end

  def inspect_transaction(id)
    inspection_config = ReportportalCucumber::Config.new(spool_dir: config.spool_dir)
    expect(ReportportalCucumber::ReportPortal::API).not_to receive(:new)
    summary = ReportportalCucumber::Service::SpoolReplay.new(store: store, config: inspection_config)
      .run(transaction_id: id)
    expect(summary).to be_frozen
    expect(summary.fetch(:unavailable_artifact_reasons)).to be_frozen
    expect(JSON.generate(summary)).not_to include(directory, "PRIVATE_ARTIFACT", "PRIVATE_PAYLOAD_SECRET", "PRIVATE_AUTH_SECRET")
    expect(summary.fetch(:unavailable_artifacts)).to be_between(0, 1_000)
    expect(a_request(:any, %r{unavailable\.example\.test})).not_to have_been_made
    summary
  end

  it "counts multiple actual Store markers without changing confirmed, ambiguous, failed or pending states" do
    id = persist_files(unavailable: 2, healthy: 2)
    states = [{ "state" => "confirmed", "id" => "existing-ack" }, { "state" => "ambiguous" },
              { "state" => "failed" }, { "state" => "pending" }]
    store.update_checkpoint(id: id, states: states)

    summary = inspect_transaction(id)

    expect(summary).to include(confirmed: 1, ambiguous: 1, failed: 1, pending: 1, retained: true,
                              unavailable_artifacts: 2, unavailable_artifact_reasons: ["source_unavailable"])
    expect(store.load_transaction(id: id).fetch(:checkpoint).fetch("states")).to eq(states)
  end

  it "reports zero unavailable artifacts for a healthy real Store attachment" do
    id = persist_files(unavailable: 0, healthy: 1)

    expect(inspect_transaction(id)).to include(pending: 1, retained: true, unavailable_artifacts: 0,
                                              unavailable_artifact_reasons: [])
  end

  def run_cli(id, label, mode: nil)
    root = File.expand_path("../../..", __dir__)
    bootstrap = File.join(directory, "bootstrap.rb")
    capture = File.join(directory, "#{label}.json")
    File.write(bootstrap, <<~'RUBY')
      require "webmock"
      require "json"
      require "digest"
      require "reportportal_cucumber"
      WebMock.enable!
      WebMock.disable_net_connect!
      requests = []
      WebMock.after_request { |request, _| requests << request.method }
      WebMock.stub_request(:get, %r{\Ahttps://unavailable\.example\.test/api/v1/inspection/(launch|item)/uuid/})
        .to_return(status: 200, body: '{"status":"IN_PROGRESS"}')
      probe = Module.new do
        def new(...)
          $m4_unavailable_api_constructed = true
          super
        end
      end
      ReportportalCucumber::ReportPortal::API.singleton_class.prepend(probe)
      at_exit do
        sdk = $LOADED_FEATURES.select { |path| path.match?(%r{/reportportal_cucumber(?:/|\.rb)}) && File.file?(path) }
        File.write(ENV.fetch("M4_UNAVAILABLE_CAPTURE"), JSON.pretty_generate(
          requests: requests, api_constructed: !!$m4_unavailable_api_constructed,
          gem_root: Gem.loaded_specs["reportportal-cucumber-ruby"]&.full_gem_path,
          sdk: sdk.to_h { |path| [File.realpath(path), Digest::SHA256.file(path).hexdigest] }
        ))
      end
    RUBY
    env = ENV.keys.grep(/\A(?:RP_|BUNDLE_|RUBYOPT\z|RUBYLIB\z|BUNDLER_VERSION\z)/).to_h { |key| [key, nil] }
    env.merge!("CUCUMBER_PROFILE" => nil, "M4_UNAVAILABLE_CAPTURE" => capture)
    if mode == "--execute"
      env.merge!("RP_ENDPOINT" => config.endpoint, "RP_PROJECT" => config.project, "RP_API_KEY" => config.api_key)
    end
    if (installed = ENV["M4_UNAVAILABLE_INSTALLED_CLI"])
      env.merge!("GEM_HOME" => ENV.fetch("M4_UNAVAILABLE_GEM_HOME"), "GEM_PATH" => ENV.fetch("M4_UNAVAILABLE_GEM_PATH"))
      command = [RbConfig.ruby, "-r", bootstrap, installed]
      expected_root = ENV.fetch("M4_UNAVAILABLE_INSTALLED_ROOT")
    else
      command = [RbConfig.ruby, "-I#{File.join(root, 'lib')}", "-r", bootstrap, File.join(root, "exe/reportportal-spool")]
      expected_root = root
    end
    args = ["--spool-dir", config.spool_dir, "--transaction", id, "--timeout", "5"]
    args << mode if mode
    stdout, stderr, status = Open3.capture3(env, *command, *args, chdir: directory)
    captured = JSON.parse(File.read(capture))
    path = File.join(File.realpath(expected_root), "lib/reportportal_cucumber/service/spool_replay.rb")
    expect(captured.fetch("sdk").fetch(path)).to eq(Digest::SHA256.file(File.join(root, "lib/reportportal_cucumber/service/spool_replay.rb")).hexdigest)
    if (evidence = ENV["M4_UNAVAILABLE_EVIDENCE"])
      FileUtils.mkdir_p(evidence)
      File.write(File.join(evidence, "#{label}.json"), JSON.pretty_generate(captured.merge("stdout" => stdout, "stderr" => stderr, "exit_status" => status.exitstatus)))
    end
    expect(stdout + stderr).not_to include(directory, "PRIVATE_ARTIFACT", "PRIVATE_PAYLOAD_SECRET", "PRIVATE_AUTH_SECRET")
    expect(stdout.bytesize).to be < 512
    expect(captured.fetch("requests")).not_to include("post")
    unless mode == "--execute"
      expect(captured.fetch("api_constructed")).to be(false)
      expect(captured.fetch("requests")).to be_empty
    end
    [stdout, stderr, status]
  end

  [nil, "--dry-run"].each do |mode|
    it "surfaces one known marker in #{mode || 'default'} installed-compatible CLI inspection without credentials or HTTP" do
      id = persist_files(unavailable: 1)
      before = store.load_transaction(id: id).fetch(:checkpoint)

      stdout, stderr, status = run_cli(id, mode ? "explicit-inspection" : "default-inspection", mode: mode)

      expect(status.exitstatus).to eq(0), stderr
      expect(stderr).to be_empty
      expect(JSON.parse(stdout)).to include("dry_run" => true, "pending" => 1, "retained" => true,
                                            "unavailable_artifacts" => 1, "unavailable_artifact_reasons" => ["source_unavailable"])
      expect(store.load_transaction(id: id).fetch(:checkpoint)).to eq(before)
    end
  end

  it "counts multiple markers including a confirmed sibling in installed-compatible CLI inspection without rewriting states" do
    id = persist_files(unavailable: 2, healthy: 1)
    states = [{ "state" => "confirmed", "id" => "existing-ack" }, { "state" => "pending" }, { "state" => "failed" }]
    store.update_checkpoint(id: id, states: states)
    before = store.load_transaction(id: id).fetch(:checkpoint)

    stdout, stderr, status = run_cli(id, "multiple-inspection", mode: "--dry-run")

    expect(status.exitstatus).to eq(0), stderr
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to include("confirmed" => 1, "pending" => 1, "failed" => 1, "retained" => true,
                                          "unavailable_artifacts" => 2, "unavailable_artifact_reasons" => ["source_unavailable"])
    expect(store.load_transaction(id: id).fetch(:checkpoint)).to eq(before)
  end

  it "reports zero markers for a healthy artifact through installed-compatible CLI inspection" do
    id = persist_files(unavailable: 0, healthy: 1)
    before = store.load_transaction(id: id).fetch(:checkpoint)

    stdout, stderr, status = run_cli(id, "healthy-inspection", mode: "--dry-run")

    expect(status.exitstatus).to eq(0), stderr
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to include("unavailable_artifacts" => 0, "unavailable_artifact_reasons" => [], "pending" => 1)
    expect(store.load_transaction(id: id).fetch(:checkpoint)).to eq(before)
  end

  it "keeps fully confirmed execution eligible for no-HTTP success despite a retained unavailable marker" do
    id = persist_files(unavailable: 1)
    states = [{ "state" => "confirmed", "id" => "existing-ack" }]
    store.update_checkpoint(id: id, states: states)
    inspection_config = ReportportalCucumber::Config.new(spool_dir: config.spool_dir)
    expect(ReportportalCucumber::ReportPortal::API).not_to receive(:new)

    result = ReportportalCucumber::Service::SpoolReplay.new(store: store, config: inspection_config)
      .run(transaction_id: id, execute: true)

    expect(result).to include(confirmed: 1, pending: 0, retained: false)
    expect(store.load_transaction(id: id).fetch(:checkpoint).fetch("states")).to eq(states)
    expect(a_request(:any, %r{unavailable\.example\.test})).not_to have_been_made
  end

  it "refuses installed-compatible CLI execution of a pending marker without POST or fabricated bytes" do
    id = persist_files(unavailable: 1)
    before = store.load_transaction(id: id).fetch(:checkpoint)

    stdout, stderr, status = run_cli(id, "unavailable-execute", mode: "--execute")

    expect(status.exitstatus).to eq(2)
    expect(stdout).to be_empty
    expect(stderr).to include("Transaction attachment is unavailable")
    expect(store.load_transaction(id: id).fetch(:checkpoint)).to eq(before)
  end

  %w[missing_attachment corrupt_attachment].each do |reason|
    it "keeps #{reason} as a hard IQ5 CLI refusal, not a successful unavailable-marker inspection" do
      id = persist_files(unavailable: 0, healthy: 1)
      tx = store.load_transaction(id: id)
      blob = tx.fetch(:files).first.fetch(:path)
      reason == "missing_attachment" ? File.unlink(blob) : File.binwrite(blob, "altered-bytes")

      stdout, stderr, status = run_cli(id, reason, mode: "--dry-run")

      expect(status.exitstatus).to eq(2)
      expect(stdout).to be_empty
      expect(stderr).to include(reason, "original artifact bytes")
      expect(JSON.parse(File.read(File.join(tx.fetch(:directory), ".checkpoint.json"))).fetch("states"))
        .to eq([{ "state" => "pending" }])
    end
  end
end
