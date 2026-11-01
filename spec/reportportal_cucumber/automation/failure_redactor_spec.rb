# frozen_string_literal: true

require "spec_helper"
require "reportportal_cucumber/automation/failure_redactor"

RSpec.describe Automation::FailureRedactor do
  let(:redactor) { Automation::EvidenceRedactor.new }
  let(:sanitizer) { described_class.new(redactor: redactor) }
  let(:frames) { ["/project/helper.rb:12:in 'call'", "/project/steps.rb:21:in 'step'", "/project/a.feature:5"] }
  let(:omitted) { Automation::EvidenceRedactor::OMITTED }
  let(:mask) { Automation::EvidenceRedactor::MASK }

  probes = {
    f14_backslash: ['back\\slash', :kept],
    rspec_match: ['expected "ABC" to match /\\d+/', :kept],
    windows_errno: ['No such file or directory @ rb_sysopen - C:\\logs\\failure.json', :kept],
    rspec_multiline_diff: ["expected: \"first\\nsecond\"\n     got: \"first\\nchanged\"\nDiff:\n- second\n+ changed", :withheld],
    embedded_json_quote: ['HTTP 500 body: {"message":"a\\"b"}', :withheld],
    escaped_json_secret: ['request failed: "{\\"api_key\\":\\"SENSITIVE_VALUE\\"}"', :withheld]
  }
  probes.each do |name, (message, disposition)|
    it "#{disposition} #{name} without losing any of the three frame entries" do
      result = sanitizer.redact(message: message, frames: frames)
      expect(result.message).to eq(disposition == :kept ? message : omitted)
      expect(result.backtrace).to eq(frames.join("\n"))
      expect(result.fallback_only).to be(false)
      error = RuntimeError.new(message)
      outputs = %w[plain rich].map do |mode|
        ReportportalCucumber::Presentation::FailureCard.format(error: error, message: result.message,
          backtrace: result.backtrace, baseline: result.baseline, presentation: mode)
      end
      expect(outputs.map { |text| text.lines.first }.uniq.length).to eq(1)
      outputs.each do |output|
        frames.each { |frame| expect(output).to include(frame) }
        expect(output).not_to include("SENSITIVE_VALUE")
        if disposition == :withheld
          expect(output).to start_with("## \u2717 RuntimeError: \\[REDACTED\\]")
          expect(output).not_to include("Message withheld")
        end
      end
    end
  end

  it "redacts message and custom-frame secrets, including the last message line and first frame" do
    result = sanitizer.redact(message: "failure\napi_key=MESSAGE_SECRET", frames: ["password=FRAME_SECRET", *frames])
    expect(result.message).to eq("failure\napi_key=#{mask}")
    expect(result.backtrace).to eq(["password=#{mask}", *frames].join("\n"))
    expect(result.baseline).not_to include("MESSAGE_SECRET", "FRAME_SECRET")
  end

  it "makes exactly two redact_text calls on the normal path" do
    expect(redactor).to receive(:redact_text).with("failure").once.and_call_original
    expect(redactor).to receive(:redact_text).with(frames.join("\n")).once.and_call_original
    sanitizer.redact(message: "failure", frames: frames)
  end

  it "makes 2 + N calls and retains safe Windows frames individually" do
    windows = ["C:\\project\\helper.rb:12:in 'call'", "C:\\project\\steps.rb:21:in 'step'", "C:\\project\\a.feature:5"]
    expect(redactor.redact_text(windows.join("\n"))).to eq(omitted)
    expect(redactor).to receive(:redact_text).with("failure").once.and_call_original
    expect(redactor).to receive(:redact_text).with(windows.join("\n")).once.and_call_original
    windows.each { |frame| expect(redactor).to receive(:redact_text).with(frame).once.and_call_original }
    expect(sanitizer.redact(message: "failure", frames: windows).backtrace).to eq(windows.join("\n"))
  end

  it "treats an embedded newline inside one frame as one fallback redaction unit" do
    custom = "C:\\custom.rb:1\npassword=FRAME_SECRET"
    original = ["C:\\first.rb:1:in 'call'", custom]
    expect(redactor).to receive(:redact_text).with("failure").once.and_call_original
    expect(redactor).to receive(:redact_text).with(original.join("\n")).once.and_call_original
    original.each { |frame| expect(redactor).to receive(:redact_text).with(frame).once.and_call_original }
    result = sanitizer.redact(message: "failure", frames: original)
    expect(result.backtrace).to include("C:\\custom.rb:1\npassword=#{mask}")
    expect(result.baseline).not_to include("FRAME_SECRET")
  end

  it "keeps the unused legacy helper's omission marker in the raw card tail as ordinary text" do
    bad = 'failure {"\\u0070assword":"FRAME_SECRET"}'
    original = [frames.first, bad, frames.last]
    result = sanitizer.redact(message: "failure", frames: original)
    expect(result.backtrace).to eq([frames.first, omitted, frames.last].join("\n"))
    output = ReportportalCucumber::Presentation::FailureCard.format(error: RuntimeError.new("failure"),
      message: result.message, backtrace: result.backtrace, baseline: result.baseline)
    expect(output.scan(omitted).length).to eq(1)
    expect(output).not_to include("FRAME_SECRET")
    expect(output).to include("Full backtrace \u00b7 3 frames")
  end

  it "uses the approved one-call safety path for a credential crossing message and first frame" do
    message = "failure password="
    original = ["CROSS_BOUNDARY_SECRET", *frames]
    expect(redactor).to receive(:redact_text).with([message, *original].join("\n")).once.and_call_original
    result = sanitizer.redact(message: message, frames: original)
    expect(result.message).to eq(message)
    expect(result.backtrace).to eq([mask, *frames].join("\n"))
    expect(result.fallback_only).to be(false)
  end

  it "preserves the exact safe baseline for a quoted credential crossing the boundary" do
    message = 'failure password="first half'
    original = ["second half\"", *frames]
    combined = [message, *original].join("\n")
    expected = redactor.redact_text(combined)
    expect(redactor).to receive(:redact_text).with(combined).once.and_call_original
    result = sanitizer.redact(message: message, frames: original)
    expect(result.baseline).to eq(expected)
    expect(result.fallback_only).to be(true)
    expect(result.baseline).not_to include("first half", "second half")
  end

  it "detects credentials crossing two frame entries even after a Unicode message" do
    original = ["password=", "FRAME_BOUNDARY_SECRET", *frames]
    result = sanitizer.redact(message: "\u6d4b\u8bd5 failure", frames: original)
    expect(result.backtrace).to eq(["password=", mask, *frames].join("\n"))
  end

  it "retains safety for encoded JSON credential keys spanning units" do
    message = '{"\\u0070assword":'
    original = ['"ENCODED_BOUNDARY_SECRET"}']
    result = sanitizer.redact(message: message, frames: original)
    expect(result.fallback_only).to be(true)
    expect(result.baseline).to eq('{"password":"[REDACTED]"}')
  end

  boundary_probes = {
    incomplete_encoded_key: [%q|{"pass\u0077ord": "|, [%q|BOUNDARY_PROBE_SECRET"}|]],
    encoded_key_with_stack: [%q|{"pass\u0077ord": "|, [%q|BOUNDARY_PROBE_SECRET"}|, "/project/steps.rb:42"]],
    embedded_encoded_key: [%q|failure {"\u0070assword":|, [%q|"BOUNDARY_PROBE_SECRET"}|]],
    malformed_unquoted_value: [%q|{"\u0070assword":|, ["BOUNDARY_PROBE_SECRET"]],
    malformed_value_escape: [%q|{"pass\u0077ord": "\q|, [%q|BOUNDARY_PROBE_SECRET"}|]],
    malformed_key_escape: [%q|{"pa\ss\u0077ord": "|, [%q|BOUNDARY_PROBE_SECRET"}|]],
    escaped_value_newline: [%q|{"pass\u0077ord": "prefix| + "\\", [%q|BOUNDARY_PROBE_SECRET"}|]],
    unicode_escape_split: [%q|{"pass\u00|, [%q|77ord": "BOUNDARY_PROBE_SECRET"}|]],
    literal_key_split: [%q|{"pass|, [%q|word": "BOUNDARY_PROBE_SECRET"}|]],
    encoded_frame_key: ["failure", [%q|{"pass\u0077ord": "|, %q|BOUNDARY_PROBE_SECRET"}|]],
    encoded_array_value: [%q|{"pass\u0077ord": [|, [%q|"BOUNDARY_PROBE_SECRET"]}|, "/project/steps.rb:42"]],
    encoded_object_value: [%q|{"pass\u0077ord": {|, [%q|"nested":"BOUNDARY_PROBE_SECRET"}}|, "/project/steps.rb:42"]],
    malformed_array_value: [%q|{"pass\u0077ord": [}|, [%q|BOUNDARY_PROBE_SECRET]}|]],
    dangling_outer_value: [%q|{\"pass\u0077ord\": [\"|, ["BOUNDARY_PROBE_SECRET" + "\\"]],
    outer_escaped_quotes: [%q|{\"pass\u0077ord\": \"|, [%q|BOUNDARY_PROBE_SECRET\"}|]],
    outer_encoded_json: [JSON.generate(%q|{"pass\u0077ord": "BOUNDARY_PROBE_SECRET"}|).split("BOUNDARY_PROBE_SECRET", 2).first,
                         ["BOUNDARY_PROBE_SECRET" + JSON.generate(%q|{"pass\u0077ord": "BOUNDARY_PROBE_SECRET"}|).split("BOUNDARY_PROBE_SECRET", 2).last]],
    outer_encoded_key_newline: [JSON.generate(%q|{"pass\u00| + "\n" + %q|77ord": "|)[0...-1], [%q|BOUNDARY_PROBE_SECRET\"}"|]],
    surrogate_policy_key: [%q|{"\ud83d\udd12pass\u0077ord": "|, [%q|BOUNDARY_PROBE_SECRET"}|]],
    unicode_case_fold: [%q|{"ap\u0130_key": "|, [%q|BOUNDARY_PROBE_SECRET"}|]],
    unicode_prefix: ["\u6d4b\u8bd5 " + %q|{"pass\u0077ord": "|, [%q|BOUNDARY_PROBE_SECRET"}|]]
  }
  boundary_probes.each do |name, (message, original)|
    it "keeps old-whole and candidate output safe for encoded boundary #{name}" do
      combined = [message, original.join("\n")].reject(&:empty?).join("\n")
      expected = Automation::EvidenceRedactor.new.redact_text(combined)
      expect(expected).to eq(omitted)
      expect(redactor).not_to receive(:redact)
      expect(redactor).to receive(:redact_text).with(combined).once.and_call_original

      result = sanitizer.redact(message: message, frames: original)

      expect(result.baseline).to eq(expected)
      expect(result.fallback_only).to be(true)
      expect(result.baseline).not_to include("BOUNDARY_PROBE_SECRET")
    end
  end

  it "uses the unchanged sensitive-key policy for an encoded custom key" do
    redactor = Automation::EvidenceRedactor.new(sensitive_keys: ["private-id"])
    message = %q|{"pr\u0069vate id": "|
    original = [%q|BOUNDARY_PROBE_SECRET"}|, *frames]
    combined = [message, *original].join("\n")
    expect(redactor).to receive(:redact_text).with(combined).once.and_call_original
    result = described_class.new(redactor: redactor).redact(message: message, frames: original)
    expect(result.baseline).to eq(omitted)
  end

  [
    [%q|{"pass\u0077ord": [|, %q|"STRUCTURE_PROBE_SECRET"]}|],
    [%q|{"pass\u0077ord": {|, %q|"nested":"STRUCTURE_PROBE_SECRET"}}|]
  ].each do |message, frame|
    it "retains the exact old non-omitted baseline for a cross-unit structured value #{frame[0]}" do
      combined = [message, frame].join("\n")
      old_whole = redactor.redact_text(combined)
      expect(old_whole).to eq('{"password":"[REDACTED]"}')
      expect(redactor).to receive(:redact_text).with(combined).once.and_call_original
      expect(sanitizer.redact(message: message, frames: [frame]).baseline).to eq(old_whole)
    end
  end

  it "retains safety at every split position through encoded keys and their value opener" do
    marker = "SPLIT_PROBE_SECRET"
    sources = [
      %q|{"pass\u0077ord": "| + marker + %q|"}|,
      %q|{\"pass\u0077ord\": \"| + marker + %q|\"}|,
      JSON.generate(%q|{"pass\u0077ord": "| + marker + %q|"}|),
      %q|{"p\u0061ss word": "| + marker + %q|"}|
    ]
    sources.each do |source|
      (1...source.index(marker)).each do |cut|
        message = source[0...cut]
        original = [source[cut..], frames.first]
        old_whole = redactor.redact_text([message, *original].join("\n"))
        expect(old_whole).not_to include(marker)
        result = sanitizer.redact(message: message, frames: original)
        expect(result.baseline).not_to include(marker), "leak at split #{cut} in #{source.inspect}"
      end
    end
  end

  it "does not use the whole-input exception for a credential contained in one unit" do
    message = %q|{"pass\u0077ord":"LOCAL_PROBE_SECRET"}|
    expect(redactor).to receive(:redact_text).with(message).once.and_call_original
    expect(redactor).to receive(:redact_text).with("").once.and_call_original
    result = sanitizer.redact(message: message, frames: [""])
    expect(result.baseline).to eq('{"password":"[REDACTED]"}')
  end

  it "does not extend an outer-escaped value into unrelated frames" do
    message = JSON.generate(%q|{"pass\u0077ord":"LOCAL_PROBE_SECRET\"quoted"}|)
    expect(redactor).to receive(:redact_text).with(message).once.and_call_original
    expect(redactor).to receive(:redact_text).with(frames.join("\n")).once.and_call_original
    result = sanitizer.redact(message: message, frames: frames)
    expect(result.baseline).not_to include("LOCAL_PROBE_SECRET")
    expect(result.backtrace).to eq(frames.join("\n"))
  end

  [%q|["LOCAL_PROBE_SECRET"]|, %q|{"nested":"LOCAL_PROBE_SECRET"}|].each do |value|
    it "keeps a complete structured credential within its original unit #{value[0]}" do
      message = JSON.generate('{"pass\\u0077ord":' + value + '}')
      expect(redactor).to receive(:redact_text).with(message).once.and_call_original
      expect(redactor).to receive(:redact_text).with(frames.join("\n")).once.and_call_original
      result = sanitizer.redact(message: message, frames: frames)
      expect(result.baseline).not_to include("LOCAL_PROBE_SECRET")
      expect(result.backtrace).to eq(frames.join("\n"))
    end
  end

  it "bounds key decoding and normalization for oversized punctuation-padded credential keys" do
    message = '{"' + "." * Automation::EvidenceRedactor::MAX_INPUT_BYTES + %q|pass\u0077ord": "|
    original = [%q|BOUNDARY_PROBE_SECRET"}|]
    combined = [message, *original].join("\n")
    allow(JSON).to receive(:parse).and_wrap_original do |parser, input, *arguments|
      expect(input.bytesize).to be <= 14
      expect(input).not_to include("BOUNDARY_PROBE_SECRET")
      parser.call(input, *arguments)
    end
    allow(redactor).to receive(:normalize_key).and_wrap_original do |normalizer, input|
      expect(input.bytesize).to be <= 1024
      normalizer.call(input)
    end
    expect(redactor).to receive(:redact_text).with(combined).once.and_call_original
    result = sanitizer.redact(message: message, frames: original)
    expect(result.baseline).to eq(omitted)
  end

  it "does not truncate an oversized unrelated key into a credential match" do
    message = %q|{"pass\u0077ord| + "." * (2 * Automation::EvidenceRedactor::MAX_INPUT_BYTES) + %q|suffix": "|
    original = [%q|PUBLIC_PROBE_VALUE"}|]
    expect(redactor).to receive(:redact_text).with(message).once.and_call_original
    expect(redactor).to receive(:redact_text).with(original.first).once.and_call_original
    allow(redactor).to receive(:normalize_key).and_wrap_original do |normalizer, input|
      expect(input.bytesize).to be <= 1024
      normalizer.call(input)
    end
    result = sanitizer.redact(message: message, frames: original)
    expect(result.message).to eq(omitted)
    expect(result.backtrace).to eq(original.first)
  end

  it "does not use the whole-input exception for an unrelated incomplete JSON key" do
    message = %q|{"not_password": "|
    original = [%q|PUBLIC_PROBE_VALUE"}|]
    expect(redactor).to receive(:redact_text).with(message).once.and_call_original
    expect(redactor).to receive(:redact_text).with(original.first).once.and_call_original
    result = sanitizer.redact(message: message, frames: original)
    expect(result.message).to eq(omitted)
    expect(result.backtrace).to eq(original.first)
  end

  it "detects key tokens without secretly redacting the complete parsed document" do
    message = %q|{"pass\u0077ord": "|
    expect(redactor).not_to receive(:redact)
    expect(redactor).not_to receive(:redact_text)
    expect(redactor).not_to receive(:sanitize_text)
    expect(redactor.cross_unit_credential?([message, %q|BOUNDARY_PROBE_SECRET"}|])).to be(true)
  end

  it "preserves normal structural-redaction fallback and encoded empty text" do
    result = sanitizer.redact(message: "password=\"first\nsecond\"", frames: frames)
    expect(result.fallback_only).to be(true)
    expect(result.baseline).to eq("password=#{mask}\n#{frames.join("\n")}")
    expect(sanitizer.redact(message: '""', frames: []).baseline).to eq("Step failed")
  end

  it "does not change caller-owned message or frame entries" do
    message = "api_key=ORIGINAL_SECRET".freeze
    original = frames.map(&:freeze).freeze
    sanitizer.redact(message: message, frames: original)
    expect(message).to eq("api_key=ORIGINAL_SECRET")
    expect(original).to eq(frames)
  end
end
