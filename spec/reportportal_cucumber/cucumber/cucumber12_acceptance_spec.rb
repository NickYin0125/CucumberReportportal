# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Cucumber 12 real CLI wire acceptance" do
  before { @server = Cucumber12QA::WireServer.new }
  after { @server.stop }

  def items(result)
    result.fetch("wire").fetch("items").values
  end

  def scenarios(result)
    items(result).select { |item| item["type"] == "STEP" && item["hasStats"] }
  end

  def expect_clean_wire(result, exit_code:)
    expect(result.fetch("exit")).to eq(exit_code), "Native CLI exit mismatch:\n#{result['stdout']}\n#{result['stderr']}\n#{result['wire']['errors']}"
    expect(result.fetch("stderr")).not_to match(/terminated with exception|report_on_exception|unhandled exception|ReportPortal reporting incomplete|ReportPortal .* failed/i)
    state = result.fetch("wire")
    expect(state.fetch("errors")).to eq([])
    expect(state.fetch("items")).not_to be_empty
    expect(state.fetch("items").values).to all(include("finish" => a_kind_of(Hash)))
    requests = state.fetch("requests").select { |request| request["method"] == "POST" && request["path"].include?("/item") }
    uuids = requests.map { |request| request.fetch("body").fetch("uuid") }
    expect(uuids.uniq).to eq(uuids)
  end

  def expect_finish(item, status)
    expect(item.fetch("finish").fetch("status").upcase).to eq(status)
  end

  def launch(result)
    result.fetch("wire").fetch("launches").values.fetch(0)
  end

  it "preserves native logs, exact PNG/text bytes, and Step/Before/After/AfterStep ownership" do
    result = Cucumber12QA.run(@server, fixture: "outcomes.feature", tags: "@qa_pass")
    expect_clean_wire(result, exit_code: 0)
    expect_finish(launch(result), "PASSED")
    expect(result.fetch("stdout")).to include("1 scenario (1 passed)")
    scenario = scenarios(result).fetch(0)
    expect_finish(scenario, "PASSED")
    expect(result.fetch("html_bytes")).to be > 1000
    native_attachments = result.fetch("native").filter_map { |message| message["attachment"] }
    expect(result.fetch("events")).not_to be_empty
    expect(result.fetch("events")).to all(include("class" => "Cucumber::Events::AttachCalled", "base" => true))
    expect(result.fetch("events").length).to eq(native_attachments.length)
    owner_by_uuid = result.fetch("wire").fetch("items")
    expected = {
      "native.png" => ["image/png", Base64.strict_decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nXxkAAAAASUVORK5CYII="), /QA native media/],
      "native.txt" => ["text/plain", "native text\r\nsecond line\n\n", /QA native media/],
      "before.txt" => ["text/plain", "before hook\r\n", /Before/i],
      "after.txt" => ["text/plain", "after hook\r\n", /After/i],
      "afterstep.txt" => ["text/plain", "afterstep hook\r\n", /AfterStep/i]
    }
    logs = result.fetch("wire").fetch("logs")
    expected.each do |filename, (mime, bytes, owner_name)|
      matches = logs.select { |entry| entry.dig("file", "name") == filename }
      expect(matches.length).to eq(filename == "afterstep.txt" ? 2 : 1)
      matches.each do |entry|
        file = entry.fetch("wireFile")
        expect(file.fetch("mime")).to eq(mime)
        expect(Base64.strict_decode64(file.fetch("base64"))).to eq(bytes.b)
        owner = owner_by_uuid.fetch(entry.fetch("itemUuid"))
        expect(owner.fetch("name")).to match(owner_name)
        expect(owner).to include("parentUuid" => scenario.fetch("uuid"), "hasStats" => false)
        expect(entry.fetch("sequence")).to be < owner.fetch("finishSequence")
      end
    end
    native_log = logs.select { |entry| entry["message"] == "QA_NATIVE_LOG exact message" }
    expect(native_log.length).to eq(1)
    expect(native_log.first).not_to have_key("file")
    expect(owner_by_uuid.fetch(native_log.first.fetch("itemUuid")).fetch("name")).to include("QA native media")
    %w[QA_BEFORE QA_AFTER QA_AFTERSTEP QA_AROUND_BEFORE QA_AROUND_AFTER].each do |marker|
      expect(logs.map { |entry| entry.fetch("message") }).to include(marker)
    end
  end

  { "fail" => ["FAILED", "FAILED", 1], "undefined" => ["UNDEFINED", "FAILED", 1],
    "pending" => ["PENDING", "FAILED", 1], "ambiguous" => ["AMBIGUOUS", "FAILED", 1],
    "skip" => ["SKIPPED", "SKIPPED", 0] }.each do |tag, (native_status, rp_status, exit_code)|
    it "reports native #{native_status} without strict mode and skips subsequent actions" do
      result = Cucumber12QA.run(@server, fixture: "outcomes.feature", tags: "@qa_#{tag}")
      expect_clean_wire(result, exit_code: exit_code)
      expect_finish(scenarios(result).fetch(0), rp_status)
      expect_finish(launch(result), rp_status)
      native_statuses = result.fetch("native").filter_map { |message| message.dig("testStepFinished", "testStepResult", "status") }
      expect(native_statuses).to include(native_status, "SKIPPED")
      skipped = items(result).find { |item| item["name"] == "And QA passes" }
      expect(skipped).not_to be_nil
      expect_finish(skipped, "SKIPPED")
    end
  end

  %w[before after afterstep around_before around_after].each do |hook|
    it "reports genuine #{hook} hook errors and closes the entire parent tree" do
      result = Cucumber12QA.run(@server, fixture: "hooks.feature", tags: "@qa_#{hook}_fail")
      expect_clean_wire(result, exit_code: 1)
      expect_finish(scenarios(result).fetch(0), "FAILED")
      expect_finish(launch(result), "FAILED")
      if %w[before after].include?(hook)
        expect(result.fetch("wire").fetch("logs").map { |entry| entry.fetch("message") }.join("\n"))
          .to include("QA intentional #{hook.capitalize} failure")
      end
      failed_actions = items(result).select { |item| item["hasStats"] == false && item.dig("finish", "status").to_s.upcase == "FAILED" }
      if hook.start_with?("around")
        # Native AroundHook has no HookStep identity/lifecycle; its result belongs to the scenario.
        diagnostic = result.fetch("wire").fetch("logs").select { |entry| entry["itemUuid"] == scenarios(result).first.fetch("uuid") }
        expect(diagnostic.map { |entry| entry.fetch("message") }.join("\n")).to include("QA intentional Around")
      else
        expect(failed_actions).not_to be_empty
      end
    end
  end

  it "reports Feature/Rule suites, both Backgrounds, four rows across two Examples and rich arguments" do
    result = Cucumber12QA.run(@server, fixture: "hierarchy.feature")
    expect_clean_wire(result, exit_code: 0)
    expect(result.fetch("stdout")).to include("5 scenarios (5 passed)")
    feature = items(result).find { |item| item["type"] == "SUITE" && !item["parentUuid"] }
    rule = items(result).find { |item| item["type"] == "SUITE" && item["parentUuid"] == feature.fetch("uuid") }
    expect(rule.fetch("name")).to include("Native rule suite")
    expect(scenarios(result).length).to eq(5)
    outside = scenarios(result).find { |item| item["name"].include?("Outside rule") }
    expect(outside.fetch("parentUuid")).to eq(feature.fetch("uuid"))
    expanded = scenarios(result).reject { |item| item == outside }
    expect(expanded.map { |item| item.fetch("testCaseId") }.uniq.length).to eq(4)
    expect(expanded.map { |item| item.fetch("uniqueId") }.uniq.length).to eq(4)
    %w[alpha beta gamma delta].each do |name|
      row = expanded.find { |item| item["name"].include?(name) }
      expect(row).to include("parentUuid" => rule.fetch("uuid"), "type" => "STEP", "hasStats" => true)
      expect(row.fetch("parameters")).to include("key" => "name", "value" => name)
      children = items(result).select { |item| item["parentUuid"] == row.fetch("uuid") }
      expect(children.count { |item| item["name"].include?("[Background]") }).to eq(2)
      rich = children.select { |item| item["name"].include?("QA document") || item["name"].include?("QA table") }
      expect(rich.map { |item| item.fetch("description") }.join("\n")).to include(name, "A|B", "line")
      expect_finish(row, "PASSED")
    end
    expect_finish(launch(result), "PASSED")
  end

  [["--retry", "1"], ["--retry", "2", "--retry-total", "1"]].each do |options|
    it "uses native #{options.join(' ')} willBeRetried without poisoning a final-pass launch" do
      result = Cucumber12QA.run(@server, fixture: "retry.feature", tags: "@qa_flaky_alpha", options: options)
      expect_clean_wire(result, exit_code: 0)
      attempts = scenarios(result)
      expect(attempts.length).to eq(2)
      expect(attempts.map { |item| item.fetch("retry") }).to eq([false, true])
      %w[testCaseId uniqueId].each { |key| expect(attempts.map { |item| item.fetch(key) }.uniq.length).to eq(1) }
      expect(attempts.map { |item| item.fetch("uuid") }.uniq.length).to eq(2)
      expect_finish(attempts.first, "FAILED")
      expect_finish(attempts.last, "PASSED")
      finishes = result.fetch("native").filter_map { |message| message["testCaseFinished"] }
      expect(finishes.map { |event| event.fetch("willBeRetried") }).to eq([true, false])
      attempts.each_with_index do |attempt, index|
        log = result.fetch("wire").fetch("logs").find { |entry| entry["message"] == "QA_RETRY_alpha_#{index + 1}" }
        expect(result.fetch("wire").fetch("items").fetch(log.fetch("itemUuid")).fetch("parentUuid")).to eq(attempt.fetch("uuid"))
      end
      items(result).select { |item| item["type"] == "SUITE" }.each { |item| expect_finish(item, "PASSED") }
      expect_finish(launch(result), "PASSED")
    end
  end

  it "stops retrying later failures when --retry-total permanent-failure threshold is reached" do
    result = Cucumber12QA.run(@server, fixture: "retry.feature", tags: "@qa_permanent or @qa_budget_later", options: ["--retry", "1", "--retry-total", "1"])
    expect_clean_wire(result, exit_code: 1)
    expect(scenarios(result).length).to eq(3)
    finishes = result.fetch("native").filter_map { |message| message["testCaseFinished"] }
    expect(finishes.count { |event| event["willBeRetried"] }).to eq(1)
    expect_finish(launch(result), "FAILED")
  end

  it "runs two real parallel_tests workers against one parent-owned launch without early finish" do
    uuid = SecureRandom.uuid
    @server.parent_request(:post, "launch", { "uuid" => uuid, "name" => "CI-owned parallel QA", "startTime" => (Time.now.to_f * 1000).to_i.to_s })
    result = Cucumber12QA.run(@server, fixture: "parallel", parallel: true, launch_uuid: uuid)
    expect_clean_wire(result, exit_code: 0)
    expect(result.fetch("stdout")).to include("2 scenarios (2 passed)")
    expect(scenarios(result).length).to eq(2)
    expect(items(result).map { |item| item.fetch("launchUuid") }.uniq).to eq([uuid])
    expect(result.fetch("wire").fetch("requests").count { |request| request["path"].end_with?("/launch") }).to eq(1)
    expect(launch(result)).not_to have_key("finish")
    expect(result.fetch("wire").fetch("requests").none? { |request| request["path"].include?("/finish") }).to be(true)
    worker_logs = result.fetch("wire").fetch("logs").select { |entry| entry["message"].start_with?("QA_WORKER_") }
    expect(worker_logs.map { |entry| entry["message"] }).to contain_exactly("QA_WORKER_alpha_", "QA_WORKER_beta_2").or contain_exactly("QA_WORKER_alpha_2", "QA_WORKER_beta_")
    worker_logs.each do |entry|
      owner = result.fetch("wire").fetch("items").fetch(entry.fetch("itemUuid"))
      expect(owner).to include("hasStats" => false)
      expect(owner.fetch("name")).to include(entry.fetch("message").include?("alpha") ? 'QA worker "alpha"' : 'QA worker "beta"')
    end
    @server.parent_request(:put, "launch/#{uuid}/finish", { "status" => "PASSED", "endTime" => (Time.now.to_f * 1000).ceil.to_s })
    expect(@server.snapshot.fetch("errors")).to eq([])
    expect(@server.snapshot.fetch("launches").fetch(uuid).fetch("finish")).to include("status" => "PASSED")
    if ENV["RP_QA_EVIDENCE_DIR"]
      File.write(File.join(ENV.fetch("RP_QA_EVIDENCE_DIR"), "..", "parallel-parent.json"),
                 JSON.pretty_generate(@server.snapshot) + "\n")
    end
  end

  it "rejects reporting-enabled ParallelFormatter without an explicit CI-owned launch" do
    result = Cucumber12QA.run(@server, fixture: "parallel", parallel: true)
    expect(result.fetch("exit")).not_to eq(0)
    expect(result.fetch("stdout") + result.fetch("stderr")).to include("RP_LAUNCH_UUID")
    expect(result.fetch("wire").fetch("requests")).to be_empty
    expect(result.fetch("stderr")).not_to match(/terminated with exception|report_on_exception/)
  end

  { "fail" => "FAILED", "undefined" => "UNDEFINED", "pending" => "PENDING" }.each do |tag, native_status|
    it "preserves native #{native_status} when the same step finish returns HTTP 503 in strict reporting mode" do
      @server.stop
      @server = Cucumber12QA::WireServer.new(fault: lambda do |request, state|
        next false unless request["method"] == "PUT" && request["path"].include?("/item/")

        item = state.fetch("items")[request.fetch("path").split("/").last]
        item && item["hasStats"] == false && request.dig("body", "status").to_s.upcase == "FAILED"
      end)
      result = Cucumber12QA.run(@server, fixture: "outcomes.feature", tags: "@qa_#{tag}", label: "finish503")
      expect(result.fetch("exit")).to eq(1), result.fetch("stdout") + result.fetch("stderr")
      expect(result.fetch("native").filter_map { |message| message.dig("testStepFinished", "testStepResult", "status") }).to include(native_status)
      expect(result.fetch("wire").fetch("requests").count { |request| request["injectedStatus"] == 503 }).to be >= 1
      expect(result.fetch("stdout") + result.fetch("stderr")).to include("HTTP 503")
      expect(result.fetch("stderr")).not_to match(/terminated with exception|report_on_exception/)
      expect(result.fetch("stdout")).not_to include("1 scenario (1 passed)")
    end
  end

  it "does not let an earlier retry failure disable final-pass require-complete reporting" do
    @server.stop
    @server = Cucumber12QA::WireServer.new(fault: lambda do |request, _state|
      request["method"] == "POST" && request["path"].end_with?("/log") &&
        request.fetch("body").any? { |entry| entry["message"] == "QA_RETRY_alpha_2" }
    end)
    result = Cucumber12QA.run(@server, fixture: "retry.feature", tags: "@qa_flaky_alpha", options: ["--retry", "1"], label: "delivery503")
    expect(result.fetch("exit")).to eq(2), result.fetch("stdout") + result.fetch("stderr")
    expect(result.fetch("stdout")).to include("1 scenario (1 flaky)")
    expect_finish(scenarios(result).last, "PASSED")
    expect(result.fetch("stderr")).to include("ReportPortal reporting incomplete:", "HTTP 503")
    expect(result.fetch("stderr")).not_to match(/terminated with exception|report_on_exception/)
    expect(result.fetch("wire").fetch("errors")).to eq([])
  end

  it "runs every native AfterAll hook despite a teardown failure and a reporting fault" do
    @server.stop
    @server = Cucumber12QA::WireServer.new(fault: lambda do |request, _state|
      request["method"] == "POST" && request["path"].end_with?("/log") &&
        request.fetch("body").any? { |entry| entry["message"] == "QA_NATIVE_LOG exact message" }
    end)
    result = Cucumber12QA.run(@server, fixture: "outcomes.feature", tags: "@qa_pass", label: "afterall503", after_all_failure: true)
    expect(result.fetch("exit")).not_to eq(0)
    %w[QA_AFTERALL_FIRST QA_AFTERALL_MIDDLE QA_AFTERALL_LAST].each do |marker|
      expect(result.fetch("stdout")).to include(marker)
    end
    expect(result.fetch("stdout") + result.fetch("stderr")).to include("QA intentional AfterAll failure")
    expect(result.fetch("stderr")).not_to match(/terminated with exception|report_on_exception/)
    expect_finish(launch(result), "FAILED")
  end

  [["pass", true, 2], ["pass", false, 0], ["fail", true, 1]].each do |business, complete, exit_code|
    it "fails closed on unresolved native thread evidence with business #{business}, require-complete #{complete}" do
      result = Cucumber12QA.run(@server, fixture: "threaded.feature", tags: "@qa_thread_#{business}",
                               label: "require-complete-#{complete}", require_complete: complete)
      expect(result.fetch("exit")).to eq(exit_code), result.fetch("stdout") + result.fetch("stderr")
      expect(result.fetch("stderr")).not_to match(/terminated with exception|report_on_exception/)
      expect(result.fetch("wire").fetch("errors")).to eq([])
      expect(result.fetch("receipt")).to include("complete" => false)
      expect(result.fetch("receipt").fetch("rejected")).to be >= 2
      expect(result.fetch("stderr").scan("ReportPortal log/attachment rejected: ownership is unresolved").length).to eq(1)
      expect(result.fetch("stderr")).not_to include("QA_UNOWNED_CHILD_THREAD", "unowned-thread.txt", "unowned child thread")
      native = result.fetch("native").filter_map { |entry| entry["attachment"] }
      expect(native.any? { |entry| entry["fileName"] == "unowned-thread.txt" }).to be(true)
      logs = result.fetch("wire").fetch("logs")
      expect(logs.none? { |entry| entry["message"] == "QA_UNOWNED_CHILD_THREAD" || entry.dig("file", "name") == "unowned-thread.txt" }).to be(true)
      parent_log = logs.find { |entry| entry["message"] == "QA_PARENT_THREAD_CONTINUES" }
      expect(parent_log).not_to be_nil
      owner = result.fetch("wire").fetch("items").fetch(parent_log.fetch("itemUuid"))
      expect(owner.fetch("name")).to include("QA joined thread evidence")
      expect(owner).to include("hasStats" => false, "parentUuid" => scenarios(result).first.fetch("uuid"))
      expect_finish(scenarios(result).first, business == "pass" ? "PASSED" : "FAILED")
      expect(result.fetch("stdout")).to include("QA intentional step failure") if business == "fail"
    end
  end
end
