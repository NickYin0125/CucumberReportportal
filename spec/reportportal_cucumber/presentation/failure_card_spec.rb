# frozen_string_literal: true

require "spec_helper"
require "reportportal_cucumber/automation/failure_redactor"

RSpec.describe ReportportalCucumber::Presentation::FailureCard do
  let(:cwd) { "/project" }
  let(:error) { RuntimeError.new("INDEPENDENT_FULL_BACKTRACE") }
  let(:project_frames) do
    ["/outside/runtime-support.rb:65:in 'IndependentCucumber12.inner_failure'",
     "/outside/runtime-support.rb:59:in 'IndependentCucumber12.deep_failure'",
     "/outside/runtime-support.rb:136:in 'block in <top (required)>'",
     "/project/features/audit.feature:5:in 'independent fail'"]
  end
  let(:backtrace) do
    (project_frames + Array.new(56) { |index| "/ruby/gems/cucumber/runner.rb:#{index + 1}:in 'run'" } +
      ["-e:1:in 'run'", "<internal:kernel>:90:in 'require'"]).join("\n")
  end

  def card(error: self.error, message: error.message, backtrace: self.backtrace, cwd: self.cwd)
    described_class.format(error: error, message: message, backtrace: backtrace, cwd: cwd)
  end

  it "renders the project-first card and preserves all 62 original tail lines exactly" do
    expected = "## \u2717 RuntimeError: INDEPENDENT\\_FULL\\_BACKTRACE\n\n" \
               "`features/audit.feature:5` \u2192 `runtime-support.rb:65`\n\n" \
               "```text\n" \
               "runtime-support.rb:65     IndependentCucumber12.inner_failure\n" \
               "runtime-support.rb:59     IndependentCucumber12.deep_failure\n" \
               "runtime-support.rb:136    block in <top (required)>\n" \
               "features/audit.feature:5  independent fail\n```\n\n" \
               "_Full backtrace \u00b7 62 frames \u00b7 56 framework and 2 runner frames not shown above_\n\n" \
               "```text\n#{backtrace}\n```"
    expect(card).to eq(expected)
    expect(card).to eq(card)
    expect(backtrace.lines.length).to eq(62)
  end

  it "puts continuation lines after meta and labels the project block only for a continuation" do
    message = "\n\nfirst\nsecond <raw>\nthird & raw"
    result = card(message: message, backtrace: project_frames.join("\n"))
    expect(result).to start_with("## \u2717 RuntimeError: first\n\n`features/audit.feature:5` \u2192 `runtime-support.rb:65`")
    expect(result).to include("```text\nsecond <raw>\nthird & raw\n```\n\n_Project frames_\n\n```text")
    expect(result).to include("_Full message_\n\n```text\n#{message}\n```")
    expect(card).not_to include("_Project frames_")
  end

  it "retains P1.5's lines-two-and-three block without repeating an ordinary multiline headline" do
    result = card(message: "first\nsecond <raw>\nthird & raw", backtrace: project_frames.join("\n"))
    expect(result).to include("```text\nsecond <raw>\nthird & raw\n```\n\n_Project frames_\n\n```text")
    expect(result).not_to include("_Full message_", "```text\nfirst\n")
    expect(result.scan("first").length).to eq(1)
  end

  it "adds full-message evidence only beyond the exact title clipping boundary" do
    length = described_class::TITLE_LIMIT - "## \u2717 RuntimeError: ".length
    expect(card(message: "x" * length, backtrace: "")).not_to include("_Full message_")
    message = "x" * (length + 1)
    expect(card(message: message, backtrace: "")).to include("_Full message_\n\n```text\n#{message}\n```")
  end

  it "shows at most eight non-feature project frames and puts the feature last" do
    frames = ["/project/features/a.feature:7:in `step'"] +
             Array.new(12) { |index| "/project/lib/test.rb:#{index + 1}:in `call'" }
    result = card(backtrace: frames.join("\n"))
    excerpt = result.split("```text\n")[1].split("\n```")[0]
    expect(excerpt.lines.length).to eq(9)
    expect(excerpt.lines.last).to eq("features/a.feature:7  step")
    expect(excerpt).not_to include("test.rb:9")
    expect(result).to include("4 project frames not shown above")
  end

  it "uses the first three framework frames when there are no project frames" do
    frames = ["-e:1:in 'run'"] + Array.new(4) { |index| "/ruby/gems/json/parser.rb:#{index}:in 'parse'" }
    result = card(backtrace: frames.join("\n"))
    expect(result).to include("```text\nparser.rb:0  parse\nparser.rb:1  parse\nparser.rb:2  parse\n```")
    expect(result).to include("1 framework and 1 runner frames not shown above")
    expect(result).not_to include(" \u2192 ")
  end

  it "uses a comma and final conjunction for three hidden frame kinds" do
    projects = Array.new(9) { |i| "/project/support.rb:#{i}:in 'call'" }
    frameworks = Array.new(56) { |i| "/ruby/gems/cucumber/runner.rb:#{i}:in 'run'" }
    raw = (projects + frameworks + ["-e:1:in 'run'", "<internal:kernel>:90:in 'require'"]).join("\n")
    expect(card(backtrace: raw)).to include("56 framework, 2 runner and 1 project frames not shown above")
    expect(card(backtrace: raw)).to end_with("```text\n#{raw}\n```")
  end

  it "classifies stdlib and runner frames, shortens locations, and preserves Ruby quote styles" do
    frames = ["#{RbConfig::CONFIG.fetch('rubylibdir')}/json/common.rb:1:in `parse'",
              "/external/features/steps/support.rb:2:in 'work'", "-e:1", "<internal:kernel>:90"]
    result = card(backtrace: frames.join("\n"))
    expect(result).to include("`features/steps/support.rb:2`", "features/steps/support.rb:2  work")
    expect(result).to include("1 framework and 2 runner frames not shown above")
  end

  it "handles struct failures, empty exception messages, and completely empty input" do
    struct = Struct.new(:message, :backtrace).new("struct message", [])
    expect(card(error: struct, backtrace: "")).to eq("## \u2717 struct message")
    expect(card(message: "", backtrace: "")).to eq("## \u2717 RuntimeError")
    expect(card(error: nil, message: "", backtrace: "")).to eq("Step failed")
  end

  [40, 41, 96].each do |length|
    it "caps a #{length}-character project location without changing its raw frame" do
      location = "script/#{'d' * (length - 'script//support.rb:48'.length)}/support.rb:48"
      expect(location.length).to eq(length)
      raw = "/project/#{location}:in 'call'"
      result = card(backtrace: raw)
      displayed = length == 40 ? location : "script/\u2026/support.rb:48"
      expect(result).to include("`#{displayed}`", "#{displayed}  call")
      expect(displayed.length).to be <= 40
      expect(result).to end_with("```text\n#{raw}\n```")
      expect(result).to include("Full backtrace \u00b7 1 frame")
    end
  end

  it "caps the feature location in both meta and the aligned frame block" do
    raw = "/project/features/#{'deep/' * 20}checkout.feature:123:in 'scenario'"
    displayed = "features/\u2026/checkout.feature:123"
    result = card(backtrace: raw)
    expect(result).to include("`#{displayed}`", "#{displayed}  scenario")
    expect(result).to end_with("```text\n#{raw}\n```")
  end

  it "falls back to file:line if keeping the first directory still exceeds the cap" do
    raw = "/project/#{'directory' * 8}/support.rb:48:in 'call'"
    result = card(backtrace: raw)
    expect(result).to include("`support.rb:48`", "support.rb:48  call")
    expect(result).to end_with("```text\n#{raw}\n```")
  end

  [40, 41, 96].each do |length|
    it "bounds a directory-free #{length}-character filename while retaining extension and line" do
      location = "#{'x' * (length - '.rb:48'.length)}.rb:48"
      result = card(backtrace: "#{location}:in 'call'")
      displayed = result.split("\n\n")[1].delete_prefix('`').delete_suffix('`')
      expect(displayed.length).to be <= 40
      expect(displayed).to end_with(".rb:48")
      expect(displayed).to eq(location) if length == 40
      expect(displayed).to include("\u2026") if length > 40
      expect(result).to end_with("```text\n#{location}:in 'call'\n```")
    end
  end

  it "bounds rich-mode display locations while preserving the raw Unicode frame" do
    location = ("\u4e2d" * 80) + ".rb:48"
    raw = "#{location}:in 'call'"
    result = described_class.format(error: error, message: error.message, backtrace: raw, cwd: cwd, presentation: "rich")
    displayed = result.split("\n\n")[1].delete_prefix('`').delete_suffix('`')
    expect(displayed.length).to eq(40)
    expect(displayed).to end_with(".rb:48")
    expect(result).to include("\n#{raw}\n")
  end

  it "caps the complete title at 200 characters without splitting escapes or entities" do
    title = card(message: "x" * 500, backtrace: "").lines.first.chomp
    expect(title.length).to eq(200)
    expect(title).to end_with("\u2026")
    expect(card(message: "x" * 500, backtrace: "")).to include("```text\n#{'x' * 500}\n```")
    title = card(message: "<b>*" * 100, backtrace: "").lines.first.chomp
    expect(title.length).to be <= 200
    expect(title).not_to match(/[<>]|&[^;]*\u2026|\\\u2026/)
    expect(card(message: "x<script>alert(1)</script>", backtrace: ""))
      .to eq("## \u2717 RuntimeError: x&lt;script&gt;alert(1)&lt;/script&gt;")
  end

  it "preserves credential-looking message and frame content without interpreting escaped JSON" do
    result = card(message: 'api_key=SECRET123 failed', backtrace: "/project/support.rb:1:in 'token=SECRET123'")
    expect(result).to include("api\\_key=SECRET123 failed", "token=SECRET123")
    result = card(message: 'failed {"\\u0070assword":"SECRET123"}')
    expect(result).to start_with("## \u2717 RuntimeError")
    expect(result).to include('failed {"\\\\u0070assword":"SECRET123"}')
    expect(result).to end_with("```text\n#{backtrace}\n```")
    expect(result).not_to include("Message withheld")
  end

  it "uses raw parts and a supplied original baseline without constructing a redactor" do
    expect(Automation::EvidenceRedactor).not_to receive(:new)
    result = described_class.format(error: error, message: "api_key=SECRET123", backtrace: "support.rb:1",
                                    baseline: "api_key=SECRET123\nsupport.rb:1", cwd: cwd)
    expect(result).to include("api\\_key=SECRET123", "support.rb:1")
  end

  it "makes no redaction calls when rendering original parts" do
    expect(Automation::EvidenceRedactor).not_to receive(:new)
    expect(described_class.format(error: error, message: error.message, backtrace: backtrace, cwd: cwd))
      .to include("Full backtrace")
  end

  it "preserves raw text across the message/frame boundary" do
    result = card(message: "failure password=", backtrace: "CROSS_BOUNDARY_SECRET\nsupport.rb:1")
    expect(result).to start_with("## \u2717 RuntimeError: failure password=")
    expect(result).to end_with("```text\nCROSS_BOUNDARY_SECRET\nsupport.rb:1\n```")
  end

  it "does not collapse quoted credential-looking text across the message/frame boundary" do
    message = 'failure password="secret first half'
    trace = "secret second half\"\nsupport.rb:1"
    result = card(message: message, backtrace: trace)
    expect(result).to start_with("## \u2717 RuntimeError: #{message}")
    expect(result).to end_with("```text\n#{trace}\n```")
  end

  it "treats a raw omission-marker string as ordinary message and frame content" do
    marker = "[REDACTED] [evidence omitted: unsafe or oversized input]"
    result = card(message: marker, backtrace: marker)
    expect(result).to start_with("## \u2717 RuntimeError: \\[REDACTED\\] \\[evidence omitted: unsafe or oversized input\\]")
    expect(result).to end_with("```text\n#{marker}\n```")
    expect(result).not_to include("Message withheld")
  end

  it "retains the original fallback when rendering raises" do
    allow(ReportportalCucumber::Presentation::MarkdownText).to receive(:inline).and_raise(ArgumentError)
    expect(described_class.format(error: error, message: "password=RAW", backtrace: "", baseline: "password=RAW", cwd: cwd))
      .to eq("password=RAW")
  end

  it "preserves trailing empty message and backtrace lines" do
    result = card(message: "headline\n", backtrace: "support.rb:1\n")
    expect(result).to start_with("## \u2717 RuntimeError: headline")
    expect(result).to include("```text\nheadline\n\n```")
    expect(result).to end_with("```text\nsupport.rb:1\n\n```")
  end

  it "preserves literal JSON quotes instead of decoding an empty string" do
    expect(card(message: '""', backtrace: "")).to eq("## \u2717 RuntimeError: \"\"")
  end

  it "preserves the exact original baseline on oversized evidence or unsafe fences" do
    expect(card(message: "x" * 65_537)).to eq("#{'x' * 65_537}\n#{backtrace}")
    message = "`" * 32 + "~" * 32
    logger = double("logger", warn: nil)
    allow(ReportportalCucumber).to receive(:logger).and_return(logger)
    expect(card(message: message, backtrace: message)).to eq("#{message}\n#{message}")
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end

  %i[inline code fence].each do |entry|
    it "restores the exact baseline with one warning when MarkdownText.#{entry} fails" do
      logger = double("logger", warn: nil)
      allow(ReportportalCucumber).to receive(:logger).and_return(logger)
      allow(ReportportalCucumber::Presentation::MarkdownText).to receive(entry).and_raise("SECRET123")
      expect(card).to eq("INDEPENDENT_FULL_BACKTRACE\n#{backtrace}")
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  it "restores the exact baseline with one warning when count formatting fails" do
    logger = double("logger", warn: nil)
    allow(ReportportalCucumber).to receive(:logger).and_return(logger)
    allow(ReportportalCucumber::Presentation::Units).to receive(:count).and_raise("SECRET123")
    expect(card).to eq("INDEPENDENT_FULL_BACKTRACE\n#{backtrace}")
    expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
  end
end
