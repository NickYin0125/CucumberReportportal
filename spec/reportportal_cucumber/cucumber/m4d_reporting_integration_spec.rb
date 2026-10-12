# frozen_string_literal: true

require "spec_helper"
require "base64"
require "digest"
require "open3"
require "rbconfig"

RSpec.describe "M4-D public Cucumber reporting outcomes" do
  PNG = Base64.strict_decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nXxkAAAAASUVORK5CYII=").b.freeze

  def run_public_case(mode:, business_failed: false, strict: false)
    root = File.expand_path("../../..", __dir__)
    evidence_root = ENV["M4_D_EVIDENCE_DIR"]
    FileUtils.mkdir_p(evidence_root) if evidence_root
    directory = Dir.mktmpdir("m4d-public-#{mode}-", evidence_root)
    feature = File.join(directory, "delivery.feature")
    steps = File.join(directory, "steps.rb")
    capture = File.join(directory, "capture.json")
    progress = File.join(directory, "progress.txt")
    File.write(feature, <<~FEATURE)
      Feature: M4-D public reporting outcomes
        Scenario: the business result and report delivery are independent
          When I emit the M4-D evidence#{business_failed ? ' and fail the business assertion' : ''}
    FEATURE
    File.write(steps, <<~RUBY)
      #{mode == 'metadata_early' ? 'Before { true }' : ''}
      When("I emit the M4-D evidence#{business_failed ? ' and fail the business assertion' : ''}") do
        rp_log("M4-D JSON acknowledgement", mirror: false)
        rp_attach(Base64.strict_decode64(#{Base64.strict_encode64(PNG).inspect}),
                  name: "m4d-public.png", mime: "image/png")
        $m4d_business_executed = true
        $m4d_business_failure = #{business_failed}
        #{business_failed ? 'raise "Deliberate M4-D business assertion failure"' : 'true'}
      end
    RUBY
    runner = File.join(directory, "runner.rb")
    File.write(runner, <<~'RUBY')
      require "base64"
      require "digest"
      require "json"
      require "stringio"
      require "webmock"
      require "reportportal_cucumber"
      require "cucumber/cli/main"
      root, feature, steps, capture, progress, mode = ARGV
      require File.join(root, "spec/support/rp_mock_server")

      class M4DPublicKernel
        def exit(code = 0) = throw(:m4d_exit, code)
        def exit!(code = 0) = throw(:m4d_exit, code)
      end
      instance_capture = Module.new do
        define_method(:new) do |*args, **kwargs, &block|
          instance = super(*args, **kwargs, &block)
          $m4d_formatter = instance
          instance
        end
      end
      ReportportalCucumber::Cucumber::Formatter.singleton_class.prepend(instance_capture)
      WebMock.enable!
      WebMock.disable_net_connect!
      endpoint = ENV.fetch("RP_ENDPOINT")
      server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
      log_requests = []
      metadata_faults = []
      persistence_errors = []
      persistence_probe = Module.new do
        define_method(:persist) do |**arguments|
          super(**arguments)
        rescue ReportportalCucumber::Service::SpoolStore::Error => error
          persistence_errors << { "reason" => error.reason.to_s, "message" => error.message }
          raise
        end
      end
      ReportportalCucumber::Service::SpoolStore.prepend(persistence_probe)
      WebMock.stub_request(:post, endpoint + "/api/v1/m4d/log").to_return do |request|
        payload = if request.headers.fetch("Content-Type", "").include?("multipart/form-data")
                    server.send(:parse_multipart, request)
                  else
                    { entries: [JSON.parse(request.body)], files: [] }
                  end
        entries = payload.fetch(:entries)
        log_requests << {
          "entries" => entries,
          "files" => payload.fetch(:files).map do |file|
            { "name" => file.fetch(:filename), "mime" => file.fetch(:content_type),
              "bytes" => file.fetch(:bytes).bytesize, "sha256" => Digest::SHA256.hexdigest(file.fetch(:bytes)) }
          end
        }
        body = case mode
               when "partial" then { "responses" => [{ "id" => "confirmed-json-id" }] }
               when "ambiguous" then { "message" => "HTTP 200 without entry IDs" }
               else
                 entries.length == 1 && payload.fetch(:files).empty? ? { "id" => "singleton-id" } :
                   { "responses" => entries.each_index.map { |index| { "id" => "batch-id-#{index}" } } }
               end
        { status: 200, body: JSON.generate(body) }
      end
      if %w[metadata metadata_early].include?(mode)
        WebMock.stub_request(:put, %r{\A#{Regexp.escape(endpoint)}/api/v1/m4d/item/[^/]+\z})
          .with do |request|
            action = server.item_requests.find { |item| item.fetch("responseUuid") == request.uri.path.split("/").last }
            mode == "metadata_early" ||
              ($m4d_business_executed && action && action.fetch("name").start_with?("When I emit the M4-D evidence"))
          end.to_return do |request|
            action = server.item_requests.find { |item| item.fetch("responseUuid") == request.uri.path.split("/").last }
            metadata_faults << {
              "item_uuid" => action.fetch("responseUuid"), "name" => action.fetch("name"),
              "body" => JSON.parse(request.body), "business_executed" => !!$m4d_business_executed,
              "business_failure" => !!$m4d_business_failure
            }
            { status: 503, body: '{"message":"controlled metadata finish failure"}' }
          end
      end
      errors = StringIO.new
      output = StringIO.new
      status = nil
      exception = nil
      fatal_error = nil
      begin
        args = ["--require", File.join(root, "lib/reportportal_cucumber.rb"), "--require", steps,
                "--format", "progress", "--out", progress,
                "--format", "ReportPortal::Cucumber::Formatter", "--out", progress + ".rp", feature]
        status = catch(:m4d_exit) { Cucumber::Cli::Main.new(args, output, errors, M4DPublicKernel.new).execute! } || 0
      rescue StandardError => error
        fatal_error = error
        exception = { "class" => error.class.name, "message" => error.message }
      ensure
        formatter = $m4d_formatter
        raise "ReportPortal formatter was not instantiated" unless formatter
        store = ReportportalCucumber::Service::SpoolStore.new(config: formatter.config)
        transactions = store.transactions.map do |id|
          transaction = store.load_transaction(id: id)
          { "id" => id, "entries" => transaction.fetch(:entries),
            "files" => transaction.fetch(:files).map do |file|
              { "name" => file.fetch(:name), "sha256" => file[:sha256], "length" => file[:length] }
            end }
        end
        loaded = $LOADED_FEATURES.select { |path| path.include?("reportportal_cucumber") && File.file?(path) }
        File.write(capture, JSON.generate(
          "status" => status, "exception" => exception, "stderr" => errors.string,
          "receipt" => formatter.reporting_receipt.to_h, "logs" => log_requests,
          "metadata_faults" => metadata_faults, "business_executed" => !!$m4d_business_executed,
          "business_failure" => !!$m4d_business_failure,
          "persistence_errors" => persistence_errors,
          "items" => server.item_requests, "transactions" => transactions,
          "cucumber_version" => Gem.loaded_specs.fetch("cucumber").version.to_s,
          "loaded_sdk" => loaded.to_h { |path| [File.realpath(path), Digest::SHA256.file(path).hexdigest] }
        ))
      end
      raise fatal_error if fatal_error
      exit(status)
    RUBY
    env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
      "RP_ENDPOINT" => "https://rp-m4d-public.example.test", "RP_PROJECT" => "m4d",
      "RP_API_KEY" => "synthetic-m4d-token", "RP_CLIENT_JOIN" => "false",
      "RP_BATCH_SIZE_LOGS" => "2", "RP_FLUSH_INTERVAL" => "10",
      "RP_HTTP_RETRY_ATTEMPTS" => "1", "RP_EXIT_FLUSH_TIMEOUT_MS" => "500",
      "RP_FAIL_ON_REPORTING_ERROR" => strict.to_s, "RP_SPOOL_DIR" => File.join(directory, "spool")
    )
    stdout, stderr, process = Open3.capture3(env, "perl", "-e", "alarm 20; exec @ARGV", RbConfig.ruby,
                                           "-I#{File.join(root, 'lib')}", runner, root, feature, steps, capture, progress, mode,
                                           chdir: root)
    File.write(File.join(directory, "child.stdout"), stdout)
    File.write(File.join(directory, "child.stderr"), stderr)
    expect(File.file?(capture)).to be(true), "child did not produce a receipt: #{stderr}\n#{stdout}"
    result = JSON.parse(File.read(capture))
    result.merge("stdout" => stdout, "process_status" => process.exitstatus,
                 "console" => stdout + stderr, "process_stderr" => stderr,
                 "progress" => File.file?(progress) ? File.read(progress) : "", "directory" => directory)
  end

  %w[partial ambiguous].each do |mode|
    it "automatically warns of #{mode} HTTP 200 delivery while a passing business scenario exits 0" do
      result = run_public_case(mode: mode)
      expect(result.fetch("process_status")).to eq(0)
      expect(result.fetch("progress")).to include("1 scenario (1 passed)")
      expect(result.fetch("console").scan("ReportPortal reporting incomplete:").length).to eq(1)
      expect(result.fetch("console")).to include("business=passed", "reporting=incomplete")
      expected = mode == "partial" ? { "confirmed" => 1, "ambiguous" => 1, "spooled" => 1 } :
                                    { "confirmed" => 0, "ambiguous" => 2, "spooled" => 2 }
      expect(result.fetch("receipt")).to include(expected.merge("complete" => false, "pending" => 0))
      expect(result.fetch("logs").length).to eq(1)
      request = result.fetch("logs").first
      expect(request.fetch("entries").length).to eq(2)
      expect(request.fetch("files")).to eq([{ "name" => "m4d-public.png", "mime" => "image/png",
                                               "bytes" => PNG.bytesize, "sha256" => Digest::SHA256.hexdigest(PNG) }])
      png_entry = request.fetch("entries").find { |entry| entry["file"] }
      json_entry = request.fetch("entries").find { |entry| !entry["file"] }
      action = result.fetch("items").find { |item| item.fetch("responseUuid") == json_entry.fetch("itemUuid") }
      expect(action.fetch("name")).to eq("When I emit the M4-D evidence")
      expect(action.fetch("body")).to include("type" => "STEP", "hasStats" => false)
      expect(png_entry.fetch("itemUuid")).to eq(action.fetch("responseUuid"))
      scenario = result.fetch("items").find { |item| item.fetch("responseUuid") == action.fetch("parentUuid") }
      expect(scenario.fetch("body")).to include("type" => "STEP", "hasStats" => true)
      feature = result.fetch("items").find { |item| item.fetch("responseUuid") == scenario.fetch("parentUuid") }
      expect(feature.fetch("body")).to include("type" => "SUITE", "hasStats" => true)
      retained = result.fetch("transactions").flat_map { |transaction| transaction.fetch("entries") }
      expect(retained.map { |entry| entry.fetch("message") }).not_to include("M4-D JSON acknowledgement") if mode == "partial"
      retained_png = result.fetch("transactions").flat_map { |transaction| transaction.fetch("files") }
      expect(retained_png).to include(hash_including("sha256" => Digest::SHA256.hexdigest(PNG), "length" => PNG.bytesize))
      parent_version = Gem.loaded_specs.fetch("cucumber").version
      expect(parent_version).to be >= Gem::Version.new("9.0")
      expect(parent_version).to be < Gem::Version.new("11.0")
      expect(result.fetch("cucumber_version")).to eq(parent_version.to_s)
      expect(result.fetch("loaded_sdk").keys).to all(start_with(File.realpath(File.expand_path("../../..", __dir__)) + "/lib/"))
    end
  end

  [false, true].each do |strict|
    it "preserves the original failed business assertion with strict reporting #{strict}" do
      result = run_public_case(mode: "metadata", business_failed: true, strict: strict)
      expect(result.fetch("business_executed")).to be(true)
      expect(result.fetch("business_failure")).to be(true)
      expect(result.fetch("metadata_faults").length).to be > 0
      expect(result.fetch("metadata_faults")).to all(include(
        "name" => "When I emit the M4-D evidence and fail the business assertion",
        "business_executed" => true, "business_failure" => true,
        "body" => include("status" => "failed")
      ))
      expect(result.fetch("process_status")).to eq(1)
      expect(result.fetch("progress")).to include("Deliberate M4-D business assertion failure", "1 scenario (1 failed)")
      expect(result.fetch("receipt").fetch("metadata_failures")).to be > 0
      expect(result.fetch("receipt").fetch("complete")).to be(false)
      expect(result.fetch("exception")).to be_nil
      expect(result.fetch("console")).to include("business=failed", "reporting=incomplete")
    end
  end

  it "allows strict reporting to fail otherwise-passing business when metadata delivery fails" do
    result = run_public_case(mode: "metadata", strict: true)
    expect(result.fetch("business_executed")).to be(true)
    expect(result.fetch("business_failure")).to be(false)
    expect(result.fetch("metadata_faults")).not_to be_empty
    expect(result.fetch("metadata_faults")).to all(include(
      "name" => "When I emit the M4-D evidence", "business_executed" => true
    ))
    expect(result.fetch("metadata_faults").first.fetch("body")).to include("status" => "passed")
    expect(result.fetch("process_status")).to eq(2)
    expect(result.fetch("status")).to eq(2)
    expect(result.fetch("receipt").fetch("metadata_failures")).to be > 0
    expect(result.fetch("receipt").fetch("complete")).to be(false)
    expect(result.fetch("exception")).to be_nil
    expect(result.fetch("stderr")).to include("HTTP 503 (ReportportalCucumber::Transport::HTTPClient::Error)",
                                              "Formatter#handle_test_step_finished")
    expect(result.fetch("progress")).not_to include("Deliberate M4-D business assertion failure")
  end

  it "reports an early strict metadata failure as Cucumber's opt-in nonzero exit before the business action" do
    result = run_public_case(mode: "metadata_early", strict: true)
    expect(result.fetch("process_status")).to eq(2)
    expect(result.fetch("status")).to eq(2)
    expect(result.fetch("business_executed")).to be(false)
    expect(result.fetch("metadata_faults")).not_to be_empty
    expect(result.fetch("metadata_faults")).to all(include("business_executed" => false))
    expect(result.fetch("stderr")).to include("HTTP 503 (ReportportalCucumber::Transport::HTTPClient::Error)")
    expect(result.fetch("receipt").fetch("metadata_failures")).to be > 0
    expect(result.fetch("receipt").fetch("complete")).to be(false)
    expect(result.fetch("exception")).to be_nil
  end
end
