# frozen_string_literal: true

require "json"
require "stringio"
require "rspec"

gem "cucumber", ENV.fetch("QA_CUCUMBER", "10.2.0")
$LOAD_PATH.unshift(File.join(ENV.fetch("QA_SOURCE"), "lib"))
require "reportportal_cucumber"

RSpec.describe "Independent selective 1.x backport" do
  def exchange(**options)
    Automation::HttpExchange.new(**{
      method: "POST", url: "https://example.test/orders?region=eu", duration_ms: 23,
      request: { headers: { "X-Request" => "request-header" }, body: "request-body" },
      response: { status: 201, headers: { "X-Response" => "response-header" }, body: "response-body" }
    }.merge(options))
  end

  def assertion(**options)
    ReportportalCucumber::Service::EvidencePresenter.assertion(**{
      name: "independent comparison", expected: "expected", actual: "actual", passed: false
    }.merge(options)).fetch(:markdown)
  end

  def emit_failure(error, mode)
    emissions = []
    buffer = Object.new
    buffer.define_singleton_method(:emit_log) { |**payload| emissions << payload }
    formatter = ReportportalCucumber::Cucumber::Formatter.allocate
    config = ReportportalCucumber::Config.new(presentation: mode)
    expect(config.presentation).to eq(mode)
    formatter.instance_variable_set(:@config, config)
    formatter.instance_variable_set(:@launch_uuid, "independent-launch")
    formatter.instance_variable_set(:@log_buffer, buffer)
    formatter.define_singleton_method(:monotonic_timestamp) { |value| value }
    calls = []
    trace = TracePoint.new(:call) do |event|
      owner = event.defined_class.to_s
      calls << [owner, event.method_id] if owner.include?("FailureRedactor") || owner.include?("EvidenceRedactor")
    end
    trace.enable do
      formatter.send(:emit_error_log, item_uuid: "after-owner", error: error, timestamp: Time.utc(2026, 11, 3))
    end
    expect(calls).to eq([]), "Failure emission activated a redaction path: #{calls.inspect}"
    expect(emissions.length).to eq(1)
    expect(emissions.first.slice(:item_uuid, :launch_uuid, :level, :timestamp)).to eq(
      item_uuid: "after-owner", launch_uuid: "independent-launch", level: :error, timestamp: Time.utc(2026, 11, 3)
    )
    emissions.first.fetch(:message)
  end

  %w[plain rich].each do |mode|
    {
      windows: "\n  cannot open C:\\qa\\logs\\failure.json\napi_key=SYNTHETIC_RAW_1X\n",
      diff: "\nexpected: \"first\\nchanged\"\n     got: \"first\\nsecond\"\n\nDiff:\n@@ -1,2 +1,2 @@\n-first\n+changed\n",
      markup: "\n<script>qa_only</script> & `ticks` | back\\slash\n"
    }.each do |name, message|
      it("INV Decision19 preserves #{name} raw message and frames in #{mode}") do
        frames = ["C:\\qa\\steps.rb:42:in 'work'", "/project/features/raw.feature:7", "", "support.rb:9\n"]
        error = RuntimeError.new(message).tap { |failure| failure.set_backtrace(frames) }
        output = emit_failure(error, mode)
        expect(output.b).to include(message.b)
        expect(output.b).to include(frames.join("\n").b)
        expect(error.message.b).to eq(message.b)
        expect(error.backtrace).to eq(frames)
      end
    end

    it("INV oversized #{mode} failure falls back byte-for-byte, without truncation or redaction") do
      error = RuntimeError.new("api_key=SYNTHETIC_RAW_1X " + "x" * 70_000)
      error.set_backtrace(["C:\\qa\\support.rb:2"])
      expect(emit_failure(error, mode).b).to eq([error.message, error.backtrace.join("\n")].join("\n").b)
    end

    it("DELTA ERROR HTTP remains entirely plain in #{mode}") do
      value = exchange(expected_status: 200)
      expect(value.to_markdown(presentation: mode)).to eq(value.to_markdown(presentation: "plain"))
    end

    it("DELTA failed assertion remains entirely plain in #{mode}") do
      expect(assertion(presentation: mode)).to eq(assertion(presentation: "plain"))
    end

    it("DELTA response body precedes metadata, request body and repeated headers in #{mode}") do
      card = exchange(response: { status: 201, body: "response-body", headers: { "X-Repeat" => ["first", "second"] } }).to_markdown(presentation: mode)
      expect(card.index("response-body")).to be < card.index("https://example.test")
      expect(card.index("response-body")).to be < card.index("request-body")
      expect(card.index("request-body")).to be < card.index("request-header")
      expect(card).to include("X-Repeat: first\nX-Repeat: second")
      expect(card).not_to include('["first", "second"]')
    end

    it("DELTA response survives a large request consuming the shared preview budget in #{mode}") do
      card = exchange(request: { body: ("request\n" * 200) }, response: { status: 201, body: "response-body" }).to_markdown(presentation: mode)
      expect(card).to include("response-body")
    end
  end

  ["error", "fatal"].each do |severity|
    it("DELTA #{severity} Accent guard returns exact plain object") do
      plain = "plain\nbody"
      rich = "plain\n<span>body</span>"
      expect(ReportportalCucumber::Presentation::Accent.guard(plain: plain, rich: rich, level: severity)).to equal(plain)
    end

    it("DELTA #{severity} attachment caption remains entirely plain") do
      arguments = { name: "evidence.png", mime: "image/png", size: 80, level: severity }
      caption = ReportportalCucumber::Presentation::AttachmentCaption
      expect(caption.format(**arguments, presentation: "rich")).to eq(caption.format(**arguments, presentation: "plain"))
    end
  end

  { "" => "empty string", " " => "1 space", "   " => "3 spaces", "\t\n" => "whitespace only", " value " => "leading/trailing whitespace" }.each do |value, label|
    it("DELTA assertion distinguishes #{value.inspect}") do
      expect(assertion(expected: value)).to include(JSON.generate(value), label)
    end
  end

  it "DELTA top-level key differences are sorted, shallow and computed from safe snapshots" do
    card = assertion(expected: { "z" => 1, "gone" => true, "nested" => { "a" => 1 }, "token" => "SYNTHETIC_LEFT" },
      actual: { "z" => 2, "added" => false, "nested" => { "a" => 2 }, "token" => "SYNTHETIC_RIGHT" })
    delta = card.lines.find { |line| line.include?("missing in actual") }
    expect(delta).to include("missing in actual: `gone`", "extra in actual: `added`", "changed: `z`")
    expect(delta).not_to include("`nested`", "`token`")
    expect(card).not_to include("SYNTHETIC_LEFT", "SYNTHETIC_RIGHT")
  end

  it "INV raw AppLog payload is deliberately unchanged" do
    events = []
    world = Object.new
    world.define_singleton_method(:log) { |message| events << message }
    raw = 'api_key=SYNTHETIC_RAW_APPLOG Bearer SYNTHETIC_RAW_APPLOG'
    AppLog.bind(world, output: StringIO.new, color: false)
    AppLog.info(raw, report: true)
    expect(events).to eq([raw])
  ensure
    AppLog.clear!
  end

  {
    encoded_json_key: ['{"\\u0074oken":"SYNTHETIC_SECRET"}', :redact_text],
    encoded_path: ["https://example.test/token%3DSYNTHETIC_SECRET/next", :redact_url],
    encoded_query: ["https://example.test/?%74oken=SYNTHETIC_SECRET&safe=yes", :redact_url],
    malformed_url: ["http://[invalid]/token%3DSYNTHETIC_SECRET?password=SYNTHETIC_SECRET", :redact_url],
    double_bearer: ["Authorization: Bearer Bearer SYNTHETIC_SECRET", :redact_text],
    redacted_prefix: ["token=[REDACTED]SYNTHETIC_SECRET", :redact_text]
  }.each do |name, (input, entry)|
    it("SEC automatic redaction removes #{name} credential residue") do
      redacted = Automation::EvidenceRedactor.new.public_send(entry, input)
      expect(redacted).not_to include("SYNTHETIC_SECRET")
      expect(redacted).not_to be_empty
    end
  end

  it "SEC structured HTTP sanitizes all automatic surfaces while preserving status" do
    value = exchange(url: "https://example.test/token%3DSYNTHETIC_SECRET", error: "Bearer Bearer SYNTHETIC_SECRET",
      request: { headers: { "Authorization" => "Bearer SYNTHETIC_SECRET" }, body: '{"\\u0074oken":"SYNTHETIC_SECRET"}' },
      response: { status: 503, body: "password=[REDACTED]SYNTHETIC_SECRET" })
    [value.summary, value.native_markdown, value.to_markdown, value.to_markdown(presentation: "rich")].each do |output|
      expect(output).not_to include("SYNTHETIC_SECRET")
      expect(output).to include("503")
    end
    expect(value.level).to eq(:error)
  end

  it "DELTA run context description is branch/sha/build only with no 2.x workers" do
    result = ReportportalCucumber::Presentation::RunContext.build(attributes: [], description: nil,
      sdk_version: "1.3.3", cucumber_version: "10.2.0", ruby_version: "3.3", include_workers: false,
      env: { "GITHUB_REF_NAME" => "qa-branch", "GITHUB_SHA" => "abcdef123456", "GITHUB_RUN_ID" => "902", "PARALLEL_TEST_GROUPS" => "8" })
    expect(result.fetch(:description)).to eq("qa-branch@abcdef1 \u00b7 build 902")
    expect(result.fetch(:attributes)).to include({ key: "cucumber", value: "10.2.0" }, { key: "ruby", value: "3.3" })
    expect(result.fetch(:attributes).map { |entry| entry[:key] }).not_to include("workers")
  end

  it "INV run context honors explicit description and attributes without mutation" do
    attributes = [{ key: "sdk", value: "owner" }]
    result = ReportportalCucumber::Presentation::RunContext.build(attributes: attributes, description: "owner text",
      sdk_version: "1.3.3", cucumber_version: "9.2.1", include_workers: false, env: {})
    expect(result.fetch(:description)).to eq("owner text")
    expect(result.fetch(:attributes).count { |entry| entry[:key] == "sdk" }).to eq(1)
    expect(result.fetch(:attributes)).to include(key: "sdk", value: "owner")
    expect(attributes).to eq([{ key: "sdk", value: "owner" }])
  end

  it "INV INFO rich remains opt-in and native HTTP retains its baseline request-first layout" do
    value = exchange
    expect(value.native_markdown).to start_with("### Request")
    expect(value.to_markdown).not_to include("<span", "<details")
    expect(value.to_markdown(presentation: "rich")).to include("<span", "<details")
  end

  it "INV invalid-UTF8 failure fallback preserves the exact original bytes" do
    message = "failure \xff api_key=SYNTHETIC_RAW_1X".b.force_encoding(Encoding::UTF_8)
    error = Struct.new(:message, :backtrace).new(message, ["support.rb:4"])
    expect(emit_failure(error, "rich").b).to eq((message.b + "\nsupport.rb:4".b))
  end

  it "DELTA failure rich and plain payloads are byte-identical, without folded tails" do
    error = RuntimeError.new("\nfirst line\nsecond line\n")
    error.set_backtrace(["/project/features/steps.rb:10", "/vendor/gems/framework.rb:22"])
    expect(emit_failure(error, "rich").b).to eq(emit_failure(error, "plain").b)
  end

  it "INV 1.x does not introduce 2.x NUL sanitation at the payload boundary" do
    original = "left\0right"
    entry = ReportportalCucumber::Service::PayloadBuilder.build_log_entry(launch_uuid: "launch", item_uuid: "item",
      time: Time.utc(2026, 11, 3), message: original, level: :error)
    expect(entry.fetch("message").b).to eq(original.b)
  end

  it "INV legacy pending undefined ambiguous and skipped status normalization is unchanged" do
    %w[pending undefined ambiguous skipped].each do |status|
      expect(ReportportalCucumber::Service::PayloadBuilder.normalize_status(status)).to eq("skipped")
    end
  end

  # Three is the released reference decoder boundary; test both sides even if
  # the implementation later changes its internal guard or constant.
  decode_limit = if Automation::EvidenceRedactor.const_defined?(:MAX_PERCENT_DECODE_PASSES)
                   Automation::EvidenceRedactor.const_get(:MAX_PERCENT_DECODE_PASSES, false)
                 else
                   3
                 end
  [decode_limit - 1, decode_limit, decode_limit + 1, 5].uniq.each do |depth|
    it("SEC depth #{depth} encoded JSON path is safe through URL HTTP and diagnostic channels") do
      value = JSON.generate(password: "SYNTHETIC_DEPTH_SENTINEL")
      depth.times { value = URI.encode_www_form_component(value) }
      url = "https://example.test/" + value
      redactor = Automation::EvidenceRedactor.new
      http = exchange(url: url)
      outputs = { url: redactor.redact_url(url), summary: http.summary, native: http.native_markdown,
        plain: http.to_markdown, rich: http.to_markdown(presentation: "rich"),
        diagnostic: ReportportalCucumber::Service::EvidencePresenter.sanitize_diagnostic(url) }
      aggregate_failures("all automatic depth-#{depth} channels") do
        outputs.each do |channel, output|
          decoded = output.dup
          6.times do
            decoded = URI.decode_www_form_component(decoded)
          rescue ArgumentError
            break
          end
          expect(decoded).not_to include("SYNTHETIC_DEPTH_SENTINEL"), "#{channel} leaked depth #{depth} after decoding"
        end
      end
    end
  end

  it "SEC benign URL and bounded encoded non-credential data are retained" do
    redactor = Automation::EvidenceRedactor.new
    url = "https://example.test/orders?region=eu&page=2"
    expect(redactor.redact_url(url)).to eq(url)
    value = JSON.generate(product: "BENIGN_DEPTH_CONTROL")
    2.times { value = URI.encode_www_form_component(value) }
    output = redactor.redact_url("https://example.test/" + value)
    6.times { output = URI.decode_www_form_component(output) }
    expect(output).to include("BENIGN_DEPTH_CONTROL")
  end
end
