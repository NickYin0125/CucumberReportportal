# frozen_string_literal: true

require "spec_helper"
require "base64"
require "digest"
require "json"
require "open3"
require "rbconfig"
require "timeout"

RSpec.describe "M4-D native Cucumber interruption" do
  it "finishes after one SIGINT to its own child and truthfully retains accepted original-step PNG evidence" do
    root = File.expand_path("../../..", __dir__)
    evidence_root = ENV["M4_D_EVIDENCE_DIR"]
    FileUtils.mkdir_p(evidence_root) if evidence_root
    directory = Dir.mktmpdir("m4d-interrupt-", evidence_root)
    File.chmod(0o700, directory)
    marker = File.join(directory, "accepted.json")
    release = File.join(directory, "release-response")
    capture = File.join(directory, "capture.json")
    feature = File.join(directory, "interrupt.feature")
    steps = File.join(directory, "steps.rb")
    progress = File.join(directory, "progress.txt")
    png = Base64.strict_decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nXxkAAAAASUVORK5CYII=").b
    File.write(feature, <<~FEATURE)
      Feature: M4 native interruption
        Scenario: preserve accepted evidence when the user interrupts
          When I emit evidence and wait for interruption
    FEATURE
    File.write(steps, <<~RUBY)
      When("I emit evidence and wait for interruption") do
        rp_log("M4 interrupted original-step evidence", mirror: false)
        rp_attach(Base64.strict_decode64(#{Base64.strict_encode64(png).inspect}),
                  name: "m4-interrupted.png", mime: "image/png")
        sleep 10
      end
    RUBY
    runner = File.join(directory, "runner.rb")
    File.write(runner, <<~'RUBY')
      require "base64"
      require "digest"
      require "json"
      require "securerandom"
      require "timeout"
      require "webmock"
      require "reportportal_cucumber"
      require "cucumber/cli/main"
      root, feature, steps, marker, release, capture, progress = ARGV
      require File.join(root, "spec/support/rp_mock_server")
      formatter = nil
      instances = Module.new do
        define_method(:new) do |*args, **kwargs, &block|
          formatter = super(*args, **kwargs, &block)
        end
      end
      ReportportalCucumber::Cucumber::Formatter.singleton_class.prepend(instances)
      WebMock.enable!
      WebMock.disable_net_connect!
      endpoint = ENV.fetch("RP_ENDPOINT")
      server = ReportportalCucumber::SpecSupport::RPMockServer.new(endpoint: endpoint).install!
      observed = []
      WebMock.stub_request(:post, endpoint + "/api/v1/m4d/log").to_return do |request|
        multipart = request.headers.fetch("Content-Type").include?("multipart/form-data")
        payload = multipart ? server.send(:parse_multipart, request) : { entries: [JSON.parse(request.body)], files: [] }
        if !multipart && (payload.fetch(:entries).first["level"] != "error" ||
                          !payload.fetch(:entries).first.fetch("message").include?("cucumber/cli/main.rb"))
          raise "Unexpected singleton request instead of native interruption diagnostic"
        end
        ack_id = SecureRandom.uuid unless multipart
        observation = {
          "entries" => payload.fetch(:entries),
          "response_status" => multipart ? 503 : 200, "ack_ids" => ack_id ? [ack_id] : [],
          "files" => payload.fetch(:files).map do |file|
            { "name" => file.fetch(:filename), "mime" => file.fetch(:content_type),
              "length" => file.fetch(:bytes).bytesize, "sha256" => Digest::SHA256.hexdigest(file.fetch(:bytes)) }
          end
        }
        observed << observation
        if multipart
          File.write(marker + ".pending", JSON.generate(observation))
          File.rename(marker + ".pending", marker)
          Timeout.timeout(3) { sleep 0.005 until File.exist?(release) }
          { status: 503, body: '{"message":"controlled response after interruption"}' }
        else
          { status: 200, body: JSON.generate("id" => ack_id) }
        end
      end
      # Registered first, so the SDK's later at_exit finalizer runs before this observer.
      at_exit do
        raise "Formatter missing during interruption" unless formatter
        store = ReportportalCucumber::Service::SpoolStore.new(config: formatter.config)
        transactions = store.transactions.map do |id|
          transaction = store.load_transaction(id: id)
          { "id" => id, "entries" => transaction.fetch(:entries), "checkpoint" => transaction.fetch(:checkpoint),
            "files" => transaction.fetch(:files).map do |file|
              { "name" => file.fetch(:name), "length" => file[:length], "sha256" => file[:sha256],
                "actual_sha256" => file[:path] && Digest::SHA256.file(file.fetch(:path)).hexdigest }
            end }
        end
        loaded = $LOADED_FEATURES.select { |path| path.include?("reportportal_cucumber") && File.file?(path) }
        File.write(capture, JSON.generate(
          "exit_exception" => ($!.is_a?(SystemExit) ? { "class" => $!.class.name, "status" => $!.status } : nil),
          "wants_to_quit" => Cucumber.wants_to_quit,
          "receipt" => formatter.reporting_receipt.to_h, "requests" => observed,
          "items" => server.item_requests, "transactions" => transactions,
          "cucumber_version" => Gem.loaded_specs.fetch("cucumber").version.to_s,
          "loaded_sdk" => loaded.to_h { |path| [File.realpath(path), Digest::SHA256.file(path).hexdigest] }
        ))
      end
      args = ["--require", File.join(root, "lib/reportportal_cucumber.rb"), "--require", steps,
              "--format", "progress", "--out", progress,
              "--format", "ReportPortal::Cucumber::Formatter", "--out", progress + ".rp", feature]
      Cucumber::Cli::Main.new(args).execute!
    RUBY
    env = ENV.keys.grep(/\ARP_/).to_h { |key| [key, nil] }.merge(
      "RP_ENDPOINT" => "https://rp-m4d-interrupt.example.test", "RP_PROJECT" => "m4d",
      "RP_API_KEY" => "synthetic-only", "RP_CLIENT_JOIN" => "false",
      "RP_HTTP_RETRY_ATTEMPTS" => "1", "RP_BATCH_SIZE_LOGS" => "2", "RP_FLUSH_INTERVAL" => "10",
      "RP_FAIL_ON_REPORTING_ERROR" => "false", "RP_EXIT_FLUSH_TIMEOUT_MS" => "200",
      "RP_SPOOL_DIR" => File.join(directory, "spool"), "CUCUMBER_PUBLISH_QUIET" => "true"
    )
    watchdog_used = false
    status = nil
    elapsed = nil
    console = ""
    Open3.popen3(env, RbConfig.ruby, "-I#{File.join(root, 'lib')}", runner,
                root, feature, steps, marker, release, capture, progress, chdir: root, pgroup: true) do |input, output, errors, child|
      input.close
      stdout = Thread.new { output.read }
      stderr = Thread.new { errors.read }
      begin
        Timeout.timeout(5) do
          until File.exist?(marker)
            raise "Child exited before accepting the evidence" if child.join(0)
            sleep 0.005
          end
        end
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Process.kill("INT", child.pid)
        File.write(release, "release controlled HTTP response\n")
        expect(child.join(3)).not_to be_nil, "SIGINT child did not complete within its finite budget"
        status = child.value
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      ensure
        unless child.join(0)
          watchdog_used = true
          File.write(release, "watchdog release\n")
          Process.kill("TERM", child.pid) rescue Errno::ESRCH
          unless child.join(1)
            Process.kill("KILL", child.pid) rescue Errno::ESRCH
            child.join(1)
          end
        end
        File.write(File.join(directory, "child.stdout"), stdout.value)
        console = stderr.value
        File.write(File.join(directory, "child.stderr"), console)
      end
    end
    File.write(File.join(directory, "parent-receipt.json"), JSON.generate(
      "exit_status" => status.exitstatus, "term_signal" => status.termsig,
      "elapsed_after_sigint" => elapsed, "watchdog_used" => watchdog_used
    ))
    expect(watchdog_used).to be(false)
    expect(elapsed).to be < 1.5
    expect(status.exited?).to be(true)
    # Native Cucumber 10's first-INT trap calls exit_unable_to_finish (2), not shell exit 130.
    expect(status.exitstatus).to eq(2)
    expect(console).to include("Exiting... Interrupt again to exit immediately.")
    expect(File.file?(capture)).to be(true), "Final reporting receipt is absent: #{console}"
    result = JSON.parse(File.read(capture))
    expect(result.fetch("wants_to_quit")).to be(true)
    expect(result.fetch("exit_exception")).to eq("class" => "SystemExit", "status" => 2)
    expect(result.fetch("receipt")).to include(
      "cutoff" => 3, "settled" => 3, "confirmed" => 1, "spooled" => 2,
      "pending" => 0, "ambiguous" => 2, "complete" => false, "local_settled" => true
    )
    expect(console.scan("ReportPortal reporting incomplete:").length).to eq(1)
    expect(console).to include("business=failed", "confirmed=1 spooled=2 pending=0 ambiguous=2")
    expect(result.fetch("requests").length).to eq(2)
    wire = JSON.parse(File.read(marker))
    expect(result.fetch("requests").first).to eq(wire)
    expect(wire).to include("response_status" => 503, "ack_ids" => [])
    expect(wire.fetch("entries").length).to eq(2)
    expect(wire.fetch("files")).to eq([{ "name" => "m4-interrupted.png", "mime" => "image/png",
                                         "length" => png.bytesize, "sha256" => Digest::SHA256.hexdigest(png) }])
    action_uuid = wire.fetch("entries").first.fetch("itemUuid")
    diagnostic = result.fetch("requests").last
    expect(diagnostic.fetch("response_status")).to eq(200)
    expect(diagnostic.fetch("ack_ids")).to match([match(/\A[0-9a-f-]{36}\z/)])
    expect(diagnostic.fetch("entries").length).to eq(1)
    expect(diagnostic.fetch("entries").first).to include("itemUuid" => action_uuid, "level" => "error")
    expect(diagnostic.fetch("entries").first.fetch("message")).to include("exit\n", "Kernel.exit",
                                                                         "Cucumber::Cli::Main#trap_interrupt")
    expect(wire.fetch("entries").map { |entry| entry.fetch("itemUuid") }.uniq).to eq([action_uuid])
    action = result.fetch("items").find { |item| item.fetch("responseUuid") == action_uuid }
    expect(action.fetch("name")).to eq("When I emit evidence and wait for interruption")
    expect(action.fetch("body")).to include("type" => "STEP", "hasStats" => false)
    scenario = result.fetch("items").find { |item| item.fetch("responseUuid") == action.fetch("parentUuid") }
    expect(scenario.fetch("body")).to include("type" => "STEP", "hasStats" => true)
    feature_item = result.fetch("items").find { |item| item.fetch("responseUuid") == scenario.fetch("parentUuid") }
    expect(feature_item.fetch("body")).to include("type" => "SUITE", "hasStats" => true)
    retained = result.fetch("transactions").flat_map { |transaction| transaction.fetch("entries") }
    expect(retained).to eq(wire.fetch("entries"))
    expect(result.fetch("transactions").flat_map { |transaction| transaction.fetch("checkpoint").fetch("states") })
      .to eq([{ "state" => "ambiguous" }, { "state" => "ambiguous" }])
    expect(result.fetch("transactions").flat_map { |transaction| transaction.fetch("files") }).to eq([
      { "name" => "m4-interrupted.png", "length" => png.bytesize,
        "sha256" => Digest::SHA256.hexdigest(png), "actual_sha256" => Digest::SHA256.hexdigest(png) }
    ])
    expect(result.fetch("cucumber_version")).to start_with("10.")
    expect(result.fetch("loaded_sdk").keys).to all(start_with(File.realpath(root) + "/lib/"))
  end
end
