# frozen_string_literal: true

require "spec_helper"
require "cucumber/events"
require "stringio"

RSpec.describe "Scoped Ledger rich routing" do
  let(:context_class) { ReportportalCucumber::Runtime::Context }
  let(:accent) { ReportportalCucumber::Presentation::Accent }
  let(:time) { Time.utc(2026, 10, 31) }

  def formatter(mode, records, owner: "step")
    instance = ReportportalCucumber::Cucumber::Formatter.allocate
    instance.instance_variable_set(:@config, ReportportalCucumber::Config.new(presentation: mode))
    instance.instance_variable_set(:@launch_uuid, "launch")
    instance.instance_variable_set(:@runtime_context, context_class.new)
    instance.instance_variable_set(:@attachment_name_mutex, Mutex.new)
    instance.instance_variable_set(:@attachment_name_counts, Hash.new(0))
    buffer = double("buffer")
    allow(buffer).to receive(:emit_log) { |**record| records << record; true }
    instance.instance_variable_set(:@log_buffer, buffer)
    allow(instance).to receive(:reporting_enabled?).and_return(true)
    allow(instance).to receive(:monotonic_timestamp).and_return(time)
    instance.runtime_context.start_scenario("case", context_class::ItemHandle.new(uuid: "scenario", kind: :scenario, type: "STEP"))
    item = context_class::ItemHandle.new(uuid: owner, name: "Given values", kind: :step, type: "STEP", parent_uuid: "scenario")
    instance.runtime_context.push_step(item)
    instance.runtime_context.register_capture_target(item, launch_uuid: "launch", owner: instance)
    instance
  end

  def world_for(formatters, native)
    world = Object.new
    world.define_singleton_method(:log) do |message|
      native << message
      formatters.each do |formatter|
        formatter.send(:handle_attach_called, Cucumber::Events::AttachCalled.new(message, "text/x.cucumber.log+plain", nil))
      end
    end
    world.define_singleton_method(:rp_active?) { true }
    world.define_singleton_method(:rp_log) { |*| raise "duplicate RP route" }
    world
  end

  def structured_logs(logger)
    logger.http(method: :get, url: "https://example.test/card", response: { status: 200, body: "safe" })
    logger.assertion(name: "Order <other>", expected: "001.2300", actual: "001.2300", passed: true)
    logger.assertion(name: "Failure", expected: "expected", actual: "actual", passed: false)
  end

  def plain_cards
    ["\u2713 GET /card \u2192 200\n\n_Response_ \u00b7 4 B\n\n```text\nsafe\n```\n\n`https://example.test/card`",
     "\u2713 Assertion passed \u00b7 Order &lt;other&gt; \u00b7 expected `001.2300`",
     "## \u2717 Assertion failed \u00b7 Failure\n\n```text\nexpected  expected\nactual    actual\n```"]
  end

  def native_assertion(name, expected, actual, outcome: "PASS")
    "## Assertion: #{name}\n\n**Outcome:** #{outcome}\n\n| Expected | Actual |\n| --- | --- |\n| #{expected} | #{actual} |"
  end

  after { ReportportalCucumber.current_runtime = nil }

  %w[plain rich].each do |mode|
    it "keeps full native terminal output byte-identical to the baseline in #{mode} mode" do
      records, native = [], []
      instance = formatter(mode, records)
      ReportportalCucumber.current_runtime = instance
      output = StringIO.new
      world = world_for([instance], native)
      original_log = world.method(:log)
      world.define_singleton_method(:log) do |message|
        output.puts("\n#{message}")
        original_log.call(message)
      end
      allow(Time).to receive(:now).and_return(time)
      logger = Automation::CucumberLogger.new(world: world, output: output, color: false)
      logger.assertion(name: "Order", expected: "OK", actual: "OK", passed: true)
      logger.http(method: :post, url: "https://example.test/orders", request: { body: { n: 1 } },
        response: { status: 201, body: { accepted: true } }, duration_ms: 84)
      expect(output.string).to eq(<<~TEXT)
        2026-10-31 00:00:00.000  INFO   PASS: Order (Attached to Report)

        ## Assertion: Order

        **Outcome:** PASS

        | Expected | Actual |
        | --- | --- |
        | OK | OK |
        2026-10-31 00:00:00.000  INFO   POST https://example.test/orders status=201 84ms (Attached to Report)

        ### Request
        - `POST` `https://example.test/orders`
        - Body:
        ```json
        {
          "n": 1
        }
        ```

        ### Response
        - Status: `201`
        - Body:
        ```json
        {
          "accepted": true
        }
        ```

        - Duration: `84` ms
      TEXT
      expect(records.length).to eq(2)
      expect(records).to all(include(item_uuid: "step", level: :info))
      expect(records.map { |entry| entry[:message] }).not_to eq(native)
      expect(records.map { |entry| entry[:message] }).to all(include("<span style=")) if mode == "rich"
    end

    it "selects #{mode} RP bodies only when the exact native bytes match" do
      records = []
      instance = formatter(mode, records)
      card = Automation::ReportContext::LogCard.new("native baseline", plain: "RP plain") { "RP rich" }
      Automation::ReportContext.with(rp_log_card: card) do
        ["native baseline", "RP plain", "native baseline "].each do |body|
          instance.send(:handle_attach_called, Cucumber::Events::AttachCalled.new(body, "text/x.cucumber.log+plain", nil))
        end
      end
      expect(records.map { |entry| entry[:message] }).to eq(["RP #{mode}", "RP plain", "native baseline "])
      expect(card.native).to be_frozen
      expect(card.plain).to be_frozen
    end
  end

  it "lets two formatters independently select their mode while native and terminal stay plain" do
    plain_records, rich_records, native = [], [], []
    plain = formatter("plain", plain_records)
    rich = formatter("rich", rich_records)
    # In particular, the currently active runtime need not be the rich one.
    ReportportalCucumber.current_runtime = plain
    output = StringIO.new
    logger = Automation::CucumberLogger.new(world: world_for([plain, rich], native), output: output, color: false)
    allow(Time).to receive(:now).and_return(time)
    structured_logs(logger)
    expect(plain_records.map { |record| record[:message] }).to eq(plain_cards)
    expect(native).to eq([
      "### Request\n- `GET` `https://example.test/card`\n\n### Response\n- Status: `200`\n- Body:\n```text\nsafe\n```\n",
      native_assertion("Order <other>", "001.2300", "001.2300"),
      native_assertion("Failure", "expected", "actual", outcome: "FAIL")
    ])
    expect(native.join).not_to include("<span style", "<details")
    expect(rich_records.length).to eq(3)
    expect(rich_records.first(2).map { |record| record[:message] }).to all(include("<span style="))
    expect(rich_records.last[:message].b).to eq(plain_records.last[:message].b)
    expect(rich_records.map { |record| record.reject { |key, _| key == :message } })
      .to eq(plain_records.map { |record| record.reject { |key, _| key == :message } })
    expect(output.string).not_to include("<span", "<details")
    reference = StringIO.new
    structured_logs(Automation::CucumberLogger.new(world: Object.new, output: reference, color: false))
    expect(output.string).to eq(reference.string)
    expect(Automation::ReportContext.current).to eq({})
  end

  it "matches exact bytes and native-log MIME only, with no rewriting of caller text" do
    records = []
    rich = formatter("rich", records)
    card = Automation::ReportContext::LogCard.new("trusted \u2713") { "RP alternate" }
    Automation::ReportContext.with(rp_log_card: card, level: :error) do
      ["trusted \u2713 ", "User **text** <span style=\"user\">raw</span>"].each do |message|
        rich.send(:handle_attach_called, Cucumber::Events::AttachCalled.new(message, "text/x.cucumber.log+plain", nil))
        expect(records.last[:message]).to eq(message)
      end
      rich.send(:handle_attachment, { body: Base64.strict_encode64("trusted \u2713"), content_encoding: "base64",
        media_type: "text/x.cucumber.log+plain" }, level: :error)
      expect(records.last[:message]).to eq("RP alternate")
      rich.send(:handle_attach_called, Cucumber::Events::AttachCalled.new("trusted \u2713", "text/plain", "literal.txt"))
      expect(records.last[:attachment][:bytes]).to eq("trusted \u2713")
      expect(records.last[:message]).not_to eq("RP alternate")
    end
    rich.send(:handle_attach_called, Cucumber::Events::AttachCalled.new("trusted \u2713", "text/x.cucumber.log+plain", nil))
    expect(records.last[:message]).to eq("trusted \u2713")
  end

  it "does not let nested ordinary AppLog text inherit a trusted alternate" do
    records, native = [], []
    rich = formatter("rich", records)
    ReportportalCucumber.current_runtime = rich
    logger = Automation::CucumberLogger.new(world: world_for([rich], native), output: StringIO.new)
    card = Automation::ReportContext::LogCard.new("same") { raise "must not render" }
    Automation::ReportContext.with(rp_log_card: card) { logger.info("same", attach: true) }
    expect(records.map { |record| record[:message] }).to eq(["same"])
    expect(native).to eq(["same"])
  end

  it "isolates nested scopes, threads and fibers, including exceptions" do
    outer = Automation::ReportContext::LogCard.new("outer") { "rich outer" }
    inner = Automation::ReportContext::LogCard.new("inner") { "rich inner" }
    Automation::ReportContext.with(rp_log_card: outer, level: :info) do
      expect(Thread.new { Automation::ReportContext.current }.value).to eq({})
      expect(Fiber.new { Automation::ReportContext.current }.resume).to eq({})
      expect do
        Automation::ReportContext.with(rp_log_card: inner, level: :error) do
          expect(Automation::ReportContext.current).to include(rp_log_card: inner, level: :error)
          raise "callback failed"
        end
      end.to raise_error("callback failed")
      expect(Automation::ReportContext.current).to include(rp_log_card: outer, level: :info)
    end
    expect(Automation::ReportContext.current).to eq({})
  end

  it "memoizes one rich fallback across two subscribers, preserving native plain evidence" do
    first_records, second_records, native = [], [], []
    first = formatter("rich", first_records)
    second = formatter("rich", second_records)
    ReportportalCucumber.current_runtime = first
    expect(accent).to receive(:pill).once.and_raise("SECRET123")
    expect(ReportportalCucumber.logger).to receive(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    logger = Automation::CucumberLogger.new(world: world_for([first, second], native), output: StringIO.new)
    logger.http(method: :get, url: "https://example.test/card", response: { status: 200 })
    baseline = Automation::HttpExchange.new(method: :get, url: "https://example.test/card", response: { status: 200 })
      .send(:render_markdown, presentation: false)
    expect(first_records.first[:message]).to eq(baseline)
    expect(second_records.first[:message]).to eq(baseline)
    expect(native.first).to eq(baseline)
    expect(Automation::ReportContext.current).to eq({})
  end

  it "keeps concurrent formatter ownership and scoped alternatives on their originating threads" do
    ready, release = Queue.new, Queue.new
    threads = %w[first second].map do |name|
      Thread.new do
        records, native = [], []
        instance = formatter("rich", records, owner: name)
        ReportportalCucumber.current_runtime = instance
        world = world_for([instance], native)
        original_log = world.method(:log)
        world.define_singleton_method(:log) do |message|
          ready << true
          release.pop
          original_log.call(message)
        end
        Automation::CucumberLogger.new(world: world, output: StringIO.new)
          .assertion(name: name, expected: name, actual: name, passed: true)
        [records, native, Automation::ReportContext.current]
      ensure
        ReportportalCucumber.current_runtime = nil
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    threads.map(&:value).zip(%w[first second]).each do |(records, native, context), name|
      expect(records.length).to eq(1)
      expect(records.first).to include(item_uuid: name, level: :info)
      expect(records.first[:message]).to include(accent.title(name), "expected `#{name}`")
      expect(native).to eq([native_assertion(name, name, name)])
      expect(context).to eq({})
    end
  ensure
    2.times { release << true } if release
    threads&.each { |thread| thread.join(2) }
  end

  it "passes rich mode and the effective ERROR level through external-video routing" do
    results = %w[plain rich].map do |mode|
      sent, uploads = [], []
      api, uploader = Object.new, Object.new
      api.define_singleton_method(:log_batch) do |entries:, files:|
        sent << [entries, files]
        { "responses" => entries.map { { "message" => "ok" } } }
      end
      uploader.define_singleton_method(:upload_video) do |**args|
        uploads << args
        "https://video.example.test/original.mp4"
      end
      config = ReportportalCucumber::Config.new(presentation: mode, video_upload_mode: "minio_markdown")
      processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, video_uploader: uploader)
      processor.emit_log(item_uuid: "owner", launch_uuid: "launch", message: "Caller first line", level: :info,
        timestamp: time, attachment: { name: "original.mp4", mime: "video/mp4", bytes: "unchanged-video" })
      expect(processor.shutdown(timeout: 2)).to be(true)
      [sent, uploads]
    end
    plain, rich = results.map { |sent, _| sent.first.first.first }
    expect(rich.reject { |key, _| key == "message" }).to eq(plain.reject { |key, _| key == "message" })
    expect(rich).to include("level" => "error", "itemUuid" => "owner")
    expect(rich["message"].b).to eq(plain["message"].b)
    expect(rich["message"]).to include("<video", "https://video.example.test/original.mp4")
    expect(rich["message"]).not_to include("<span")
    expect(results.last.last).to eq(results.first.last)
    expect(results.last.last.first).to include(bytes: "unchanged-video", content_type: "video/mp4")
    expect(results.map { |sent, _| sent.first.last }).to eq([[], []])
  end

  it "never retries helpers in rich subscribers after plain rendering has already failed" do
    records, native = [], []
    rich = formatter("rich", records)
    ReportportalCucumber.current_runtime = rich
    expect(ReportportalCucumber::Presentation::MarkdownText).to receive(:inline).once.and_raise("SECRET123")
    expect(accent).not_to receive(:pill)
    expect(ReportportalCucumber.logger).to receive(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    logger = Automation::CucumberLogger.new(world: world_for([rich], native), output: StringIO.new)
    logger.http(method: :get, url: "https://example.test/card", response: { status: 200 })
    expect(records.first[:message]).to eq(native.first)
    expect(native.first).to start_with("### Request")
  end

  it "snapshots bounded assertion data before native callbacks can mutate caller objects" do
    name, expected, actual, details = +"Original name", { count: 1 }, { count: 0 }, { label: +"original details" }
    native, rp = [], []
    world = Object.new
    world.define_singleton_method(:log) do |message|
      native << message.dup
      name.replace("Changed name")
      expected[:count] = 2
      actual[:count] = 3
      details[:label].replace("Changed details")
      rp << Automation::ReportContext.current.fetch(:rp_log_card).rich
    end
    logger = Automation::CucumberLogger.new(world: world, output: StringIO.new)
    logger.assertion(name: name, expected: expected, actual: actual, passed: false, details: details)
    [native.first, rp.first].each do |message|
      expect(message).to include("Original name", 'original details')
      expect(message).not_to include("Changed", '"count": 2', '"count": 3')
    end
    expect(native.first).to eq(native_assertion("Original name", '{"count":1}', '{"count":0}', outcome: "FAIL") +
      "\n\n### Details\n\n{\"label\":\"original details\"}")
    expect(rp.first).to include('expected  { "count": 1 }', 'actual    { "count": 0 }')
    expect(native.first).not_to include("<span style")
    expect(rp.first).not_to include("<span", "<details>")
    expect(expected).to eq(count: 2)
    expect(name).to eq("Changed name")
    expect(details[:label]).to eq("Changed details")
  end

  it "retains original String snapshots and the exact frozen baseline when lazy accenting fails" do
    values = { name: +"Original", expected: +"before expected", actual: +"before actual", details: +"before details", passed: true }
    original = values.transform_values { |value| value.is_a?(String) ? value.dup : value }
    snapshot = ReportportalCucumber::Service::EvidencePresenter.send(:assertion_snapshot, "PASS", *values.values_at(:name, :expected, :actual, :details))
    baseline = ReportportalCucumber::Service::EvidencePresenter.send(:assertion_baseline, snapshot).freeze
    native, rp = [], []
    world = Object.new
    world.define_singleton_method(:log) do |message|
      native << message
      values.each_value { |value| value.replace("Changed") if value.is_a?(String) }
      rp << Automation::ReportContext.current.fetch(:rp_log_card).rich
    end
    expect(accent).to receive(:pill).once.and_raise("SECRET123")
    expect(ReportportalCucumber.logger).to receive(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    Automation::CucumberLogger.new(world: world, output: StringIO.new).assertion(**values)
    expect(native.first).to eq(baseline)
    expect(rp.first).to eq(baseline)
    expect(rp.first).to be_frozen
    expect(rp.first).not_to include("Changed")
  end

  [nil, "plain", "rich"].each do |mode|
    it "uses only the actual runtime configuration for the #{mode.inspect} direct RP route" do
      native, direct = [], []
      world = Object.new
      world.define_singleton_method(:log) { |message| native << message }
      world.define_singleton_method(:rp_active?) { true }
      world.define_singleton_method(:rp_log) { |message, **keywords| direct << [message, keywords] }
      ReportportalCucumber.current_runtime = Struct.new(:config).new(ReportportalCucumber::Config.new(presentation: mode)) if mode
      logger = Automation::CucumberLogger.new(world: world, output: StringIO.new)
      structured_logs(logger)
      expect(direct.length).to eq(3)
      expect(direct.map(&:last)).to eq([{ level: :info, mirror: false }, { level: :info, mirror: false }, { level: :error, mirror: false }])
      expect(native.join).not_to include("<span style", "<details")
      if mode == "rich"
        expect(direct.first(2).map(&:first)).to all(include("<span style="))
        expect(direct.last.first.b).to eq(plain_cards.last.b)
      else
        expect(direct.map(&:first)).to eq(plain_cards)
      end
    end
  end

  it "routes rich evidence and arguments to their owner while descriptions and ERROR captions remain plain" do
    records = []
    rich = formatter("rich", records, owner: "after")
    target = rich.capture_target
    expect(rich.report_evidence(action: "failed", error: RuntimeError.new("original"), target: target,
      artifacts: [{ name: "evidence.txt", mime: "text/plain", bytes: "line\n" * 25 }])).to be(true)
    expect(records.length).to eq(2)
    expect(records).to all(include(item_uuid: "after", level: :error))
    expect(records.first[:message]).not_to include("<span", "<details>")
    wire = ReportportalCucumber::Service::PayloadBuilder.build_log_batch(records, presentation: "rich")
    expect(wire[:entries].last["message"]).to start_with("`evidence.txt` \u00b7 Text")
    expect(wire[:entries].last["message"]).not_to include("<details>")
    expect(wire[:files].first[:bytes]).to eq("line\n" * 25)
    source = Struct.new(:keyword, :text, :data_table).new("Given ", "argument", Struct.new(:rows).new([["qty"], ["1.00"]]))
    descriptor = ReportportalCucumber::ReportPortal::Models::StepDesc.new(step: source)
    expect(rich.send(:extract_step_description, {}, descriptor: descriptor)).to eq(descriptor.to_markdown)
    rich.send(:emit_step_markdown_log, item_uuid: "after", descriptor: descriptor, timestamp: time)
    expect(records.last).to include(item_uuid: "after", level: :info, timestamp: time)
    expect(records.last[:message]).to include(accent::TH, "| 1.00 |")
  end

  [nil, {}, Object.new].each do |foreign_config|
    it "keeps HTTP and assertions on the plain direct route for foreign config #{foreign_config.class}" do
      direct = []
      world = Object.new
      world.define_singleton_method(:rp_active?) { true }
      world.define_singleton_method(:rp_log) { |message, **keywords| direct << [message, keywords] }
      ReportportalCucumber.current_runtime = Struct.new(:config).new(foreign_config)
      output = StringIO.new
      logger = Automation::CucumberLogger.new(world: world, output: output)
      structured_logs(logger)
      expect(direct.length).to eq(3)
      expect(direct.map(&:first).join).not_to include("<span style", "<details")
      expect(output.string).not_to include("routing failed", "WARN")
      expect(direct.map { |_, kwargs| kwargs[:level] }).to eq(%i[info info error])
    end
  end

  it "threads mode through queue probes without repeating failed helpers or changing delivery" do
    sent = []
    api = Object.new
    api.define_singleton_method(:log_batch) do |entries:, files:|
      sent << { entries: entries, files: files }
      { "responses" => entries.map { { "message" => "ok" } } }
    end
    config = ReportportalCucumber::Config.new(presentation: "rich", batch_size_logs: 20, flush_interval: 0.1)
    buffer = ReportportalCucumber::Runtime::LogBuffer.new(api: api, config: config)
    expect(accent).to receive(:pill).exactly(2).times.and_raise("SECRET123")
    expect(ReportportalCucumber.logger).to receive(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).twice
    2.times do |i|
      buffer.emit_log(item_uuid: "step", launch_uuid: "launch", message: "Attachment: #{i}.txt", level: :info,
        timestamp: time, attachment: { name: "#{i}.txt", mime: "text/plain", bytes: "hello", caption_style: "default" })
    end
    expect(buffer.flush(timeout: 2)).to be(true)
    entries = sent.flat_map { |call| call[:entries] }
    expect(entries.map { |entry| entry["message"] }).to eq(["Attachment: 0.txt\n\n```text\nhello\n```", "Attachment: 1.txt\n\n```text\nhello\n```"])
    expect(entries).to all(include("itemUuid" => "step", "launchUuid" => "launch", "level" => "info"))
    expect(sent.flat_map { |call| call[:files] }.map { |file| file[:bytes] }).to eq(%w[hello hello])
  ensure
    buffer&.shutdown(timeout: 2)
  end
end
