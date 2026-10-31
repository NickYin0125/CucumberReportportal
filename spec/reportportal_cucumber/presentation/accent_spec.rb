# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "reportportal_cucumber/presentation/accent"

RSpec.describe ReportportalCucumber::Presentation::Accent do
  let(:markdown) { ReportportalCucumber::Presentation::MarkdownText }
  let(:fallback) { ReportportalCucumber::Presentation::Fallback }
  let(:logger) { double("presentation logger", warn: nil) }
  let(:pill_token) do
    "display:inline-block;padding:0 7px;border-radius:9px;font:600 10.5px/1.7 system-ui,-apple-system,Segoe UI,sans-serif;letter-spacing:.04em"
  end
  let(:title_token) { "font:600 13.5px/1.5 system-ui,-apple-system,Segoe UI,sans-serif;color:#2B2B2D" }
  let(:header_token) do
    "font:600 10.5px system-ui,-apple-system,Segoe UI,sans-serif;letter-spacing:.06em;text-transform:uppercase;color:#6B6B6D"
  end

  before { allow(ReportportalCucumber).to receive(:logger).and_return(logger) }

  {
    pass: "color:#276E50;background:#E6F5EE",
    fail: "color:#B23B3B;background:#FBEAEA",
    warn: "color:#8A5A00;background:#FFF3D6",
    info: "color:#0F6C7A;background:#E3F4F7"
  }.each do |tone, token|
    it "uses the proposal's exact, frozen #{tone} pill tokens" do
      expect(described_class::PILL).to eq(pill_token)
      expect(described_class.const_get(tone.upcase)).to eq(token)
      expect(described_class.const_get(tone.upcase)).to be_frozen
      expect(described_class.pill(tone.to_s.upcase, tone: tone))
        .to eq("<span style=\"#{pill_token};#{token}\">#{tone.to_s.upcase}</span>")
    end
  end

  it "uses the exact title and header tokens without changing label case or numeric spelling" do
    expect(described_class::TITLE).to eq(title_token)
    expect(described_class::TH).to eq(header_token)
    [described_class::PILL, described_class::TITLE, described_class::TH].each { |token| expect(token).to be_frozen }
    expect(described_class.title("Order is accepted")).to eq("<span style=\"#{title_token}\">Order is accepted</span>")
    expect(described_class.table_header("notional", columns: 5)).to eq("<span style=\"#{header_token}\">notional</span>")
    expect(described_class.pill("001.2300", tone: :info)).to end_with(">001\\.2300</span>")
    expect(described_class.title("value 1.0e+30")).to end_with(">value 1.0e+30</span>")
  end

  [:unknown, :PASS, "pass", 'info" onclick="unsafe', nil, Object.new].each do |tone|
    it "rejects the non-enumerated tone #{tone.inspect} rather than inserting arbitrary style text" do
      expect { described_class.pill("label", tone: tone) }.to raise_error(KeyError)
    end
  end

  it "escapes HTML and Markdown data in title and pill text, never in attributes" do
    data = '<b onclick="unsafe">& *star* _under_ [link](javascript:bad) `tick`</b>'
    escaped = '&lt;b onclick="unsafe"&gt;&amp; \\*star\\* \\_under\\_ \\[link\\](javascript:bad) \\`tick\\`&lt;/b&gt;'
    expect(described_class.title(data)).to eq("<span style=\"#{title_token}\">#{escaped}</span>")
    expect(described_class.pill(data, tone: :info))
      .to eq("<span style=\"#{pill_token};#{described_class::INFO}\">#{escaped}</span>")
    expect(described_class.title("# heading\nnext")).to end_with(">\\# heading next</span>")
  end

  it "does not accept arbitrary tag names, style strings, or HTML bodies" do
    expect { described_class.title("title", style: "position:fixed") }.to raise_error(ArgumentError)
    expect { described_class.pill("label", tone: :info, tag: "img") }.to raise_error(ArgumentError)
    expect { described_class.details(summary: "caption", html: "<img>") }.to raise_error(ArgumentError)
    expect(described_class.details(summary: "caption", body: "<img>"))
      .to eq("<details><summary>caption</summary>\n\n```text\n<img>\n```\n\n</details>")
  end

  [1, 6].each do |columns|
    it "accents one explicitly supplied header cell in a #{columns}-column table" do
      expect(described_class.table_header("a|b\\c\r\n<other>&", columns: columns))
        .to eq("<span style=\"#{header_token}\">a\\|b\\\\c<br>&lt;other&gt;&amp;</span>")
    end
  end

  [7, 8, 32].each do |columns|
    it "returns the plain escaped cell for a #{columns}-column table" do
      text = "<key>|next\nline"
      expect(described_class.table_header(text, columns: columns)).to eq("&lt;key&gt;\\|next<br>line")
    end
  end

  [0, -1, 6.0, "6", nil].each do |columns|
    it "rejects the invalid column count #{columns.inspect}" do
      expect { described_class.table_header("header", columns: columns) }.to raise_error(ArgumentError)
    end
  end

  it "matches the folded failure-tail golden without altering a single body byte" do
    body = "/project/steps.rb:8:in 'failure'\n/gems/cucumber/core.rb:5:in 'run'"
    summary = "Full backtrace \u00b7 62 frames \u00b7 56 framework and 2 runner frames not shown above"
    expect(described_class.details(summary: summary, body: body)).to eq(<<~MARKDOWN.chomp)
      <details><summary>Full backtrace \u00b7 62 frames \u00b7 56 framework and 2 runner frames not shown above</summary>

      ```text
      /project/steps.rb:8:in 'failure'
      /gems/cucumber/core.rb:5:in 'run'
      ```

      </details>
    MARKDOWN
  end

  it "escapes a summary as single-line HTML text without introducing literal Markdown backslashes" do
    result = described_class.details(summary: "<other> & *star* `tick`\r\n# next", body: "raw")
    expect(result.lines.first.chomp).to eq("<details><summary>&lt;other&gt; &amp; *star* `tick` # next</summary>")
  end

  it "creates a dynamic fence around raw HTML, closing-tag lookalikes, and fence runs" do
    body = "start\n```\n</details>\n<script>raw()</script>\n~~~~\nfinish\n"
    result = described_class.details(summary: "Raw evidence", body: body)
    expect(result).to eq("<details><summary>Raw evidence</summary>\n\n````text\n#{body}\n````\n\n</details>")
    expect(result).not_to include("&lt;script&gt;")
  end

  it "falls through to tildes when necessary and never uses a delimiter longer than 32" do
    body = "`" * 32
    expect(described_class.details(summary: "Body", body: body))
      .to eq("<details><summary>Body</summary>\n\n~~~text\n#{body}\n~~~\n\n</details>")
    expect { described_class.details(summary: "Unsafe", body: "#{'`' * 32}\n#{'~' * 32}") }
      .to raise_error(ArgumentError, "Safe folded evidence fence unavailable")
  end

  it "keeps blank lines around empty, JSON, and truncated fences" do
    expect(described_class.details(summary: "Empty", body: "", language: ""))
      .to eq("<details><summary>Empty</summary>\n\n```\n\n```\n\n</details>")
    expect(described_class.details(summary: "JSON", body: '{ "n": 1.0 }', language: "json"))
      .to eq("<details><summary>JSON</summary>\n\n```json\n{ \"n\": 1.0 }\n```\n\n</details>")
    expect(described_class.details(summary: "Long", body: "abcdefgh", limit: 4))
      .to eq("<details><summary>Long</summary>\n\n```text\nabcd[truncated]\n```\n\n</details>")
  end

  it "uses the shared language allowlist and never inserts a language as raw markup" do
    result = described_class.details(summary: "Body", body: "raw", language: "text\n</summary><img>")
    expect(result).to eq("<details><summary>Body</summary>\n\n```\nraw\n```\n\n</details>")
  end

  it "bounds text through the shared helpers and emits valid UTF-8 for binary inputs" do
    data = "<\xFF&".b.freeze
    expect(described_class.title(data)).to eq("<span style=\"#{title_token}\">&lt;\uFFFD&amp;</span>")
    expect(described_class.pill("abcdefgh", tone: :pass, limit: 4)).to end_with(">abcd\\[truncated\\]</span>")
    expect(described_class.table_header("abcdefgh", columns: 2, limit: 4)).to end_with(">abcd[truncated]</span>")
    expect(described_class.details(summary: "abcdefgh", body: data, summary_limit: 4))
      .to eq("<details><summary>abcd[truncated]</summary>\n\n```text\n<\uFFFD&\n```\n\n</details>")
    expect(data.bytes).to eq([60, 255, 38])
    expect(data.encoding).to eq(Encoding::BINARY)
  end

  [-1, 65_537, 1.0, "4", nil].each do |limit|
    it "rejects invalid byte limit #{limit.inspect} at every boundary" do
      expect { described_class.pill("x", tone: :pass, limit: limit) }.to raise_error(ArgumentError)
      expect { described_class.title("x", limit: limit) }.to raise_error(ArgumentError)
      expect { described_class.table_header("x", columns: 1, limit: limit) }.to raise_error(ArgumentError)
      expect { described_class.details(summary: "x", body: "y", limit: limit) }.to raise_error(ArgumentError)
      expect { described_class.details(summary: "x", body: "y", summary_limit: limit) }.to raise_error(ArgumentError)
    end
  end

  it "rejects non-string data without invoking arbitrary conversion methods" do
    value = Object.new
    expect(value).not_to receive(:to_s)
    expect { described_class.pill(value, tone: :pass) }.to raise_error(TypeError)
    expect { described_class.title(value) }.to raise_error(TypeError)
    expect { described_class.table_header(value, columns: 1) }.to raise_error(TypeError)
    expect { described_class.details(summary: value, body: "body") }.to raise_error(TypeError)
    expect { described_class.details(summary: "summary", body: value) }.to raise_error(TypeError)
    expect { described_class.details(summary: "summary", body: "body", language: value) }.to raise_error(TypeError)
    expect { described_class.guard(plain: value, rich: "rich", level: :info) }.to raise_error(TypeError)
    expect { described_class.guard(plain: "plain", rich: value, level: :info) }.to raise_error(TypeError)
  end

  describe ".guard" do
    it "allows exactly 1024 added bytes and returns the original plain object one byte beyond" do
      plain = "Original".freeze
      limit = (plain + "x" * 1024).freeze
      expect(described_class.guard(plain: plain, rich: limit, level: :info)).to equal(limit)
      expect(described_class.guard(plain: plain, rich: limit + "x", level: :info)).to equal(plain)
      expect(logger).not_to have_received(:warn)
    end

    it "counts multibyte UTF-8 bytes rather than characters" do
      plain = "Original".freeze
      limit = plain + "\u00b7" * 512
      expect(described_class.guard(plain: plain, rich: limit, level: :info)).to equal(limit)
      expect(described_class.guard(plain: plain, rich: limit + "\u00b7", level: :info)).to equal(plain)
    end

    [:error, "error", "ERROR", "ErRoR"].each do |level|
      it "requires byte-identical first lines for #{level.inspect}" do
        plain = "## \u2717 Failed <raw>\n\nOriginal body".freeze
        rich = plain.lines.first + "\n" + described_class.details(summary: "Body", body: "Original body")
        expect(described_class.guard(plain: plain, rich: rich, level: level)).to equal(rich)
        expect(described_class.guard(plain: plain, rich: rich.sub("Failed", "Failure"), level: level)).to equal(plain)
        expect(described_class.guard(plain: plain, rich: rich.sub("<raw>", "&lt;raw&gt;"), level: level)).to equal(plain)
      end
    end

    it "does not normalize whitespace, CRLF, or Unicode in ERROR first lines" do
      [
        ["Failure\r\nbody", "Failure\nbody"],
        ["Failure \nbody", "Failure\nbody"],
        ["\u00e9\nbody", "e\u0301\nbody"],
        ["\nbody", "Failure\nbody"]
      ].each do |plain, rich|
        expect(described_class.guard(plain: plain, rich: rich, level: :error)).to equal(plain)
      end
    end

    it "compares just the first line, including empty and no-newline messages" do
      [["", ""], ["", "\nbody"], ["Failure", "Failure\nbody"], ["Failure\nbody", "Failure"]].each do |plain, rich|
        expect(described_class.guard(plain: plain, rich: rich, level: :error)).to equal(rich)
      end
      plain = "Failure"
      expect(described_class.guard(plain: plain, rich: "Changed", level: :error)).to equal(plain)
    end

    it "applies the byte limit even when an ERROR first line is unchanged" do
      plain = "Failure\nbody".freeze
      rich = plain + "x" * 1025
      expect(described_class.guard(plain: plain, rich: rich, level: :error)).to equal(plain)
    end

    %i[trace debug info warn fatal].each do |level|
      it "permits deliberate non-ERROR title changes at #{level}" do
        plain = "Plain title".freeze
        rich = described_class.title("Styled title")
        expect(described_class.guard(plain: plain, rich: rich, level: level)).to equal(rich)
      end
    end

    [nil, :unknown, "PANIC", 1, Object.new].each do |level|
      it "rejects an unspecified or unknown level #{level.inspect}" do
        expect { described_class.guard(plain: "plain", rich: "rich", level: level) }.to raise_error(ArgumentError)
      end
    end

    it "leaves arbitrary caller text completely untouched rather than rewriting HTML or fences" do
      plain = "User **Markdown** <style>raw</style>\n```\nraw\n```".freeze
      expect(described_class.guard(plain: plain, rich: plain, level: :info)).to equal(plain)
      expect(described_class.guard(plain: plain, rich: plain + "x" * 1025, level: :info)).to equal(plain)
    end
  end

  it "supports the owner-approved passed-assertion and attachment layouts by explicit composition" do
    assertion = described_class.pill("PASS", tone: :pass) + " " + described_class.title("Order is accepted") +
      " \u00b7 expected `ACCEPTED`"
    expect(assertion).to eq("<span style=\"#{pill_token};#{described_class::PASS}\">PASS</span> " \
                           "<span style=\"#{title_token}\">Order is accepted</span> \u00b7 expected `ACCEPTED`")
    attachment = described_class.pill("PNG", tone: :info) + " `visible-fixture.png` \u00b7 640 \u00d7 360 \u00b7 5.3 KB"
    expect(attachment).to eq("<span style=\"#{pill_token};#{described_class::INFO}\">PNG</span> " \
                            "`visible-fixture.png` \u00b7 640 \u00d7 360 \u00b7 5.3 KB")
  end

  it "uses only the closed tag vocabulary and exact style combinations when composing a client card" do
    rich = [described_class.pill("201", tone: :pass), described_class.title("POST /api/orders"),
            described_class.table_header("account", columns: 2),
            described_class.details(summary: "Request headers \u00b7 1", body: "Content-Type: application/json")].join("\n\n")
    expect(rich.scan(/<[^>]+>/).uniq).to contain_exactly(
      "<span style=\"#{pill_token};#{described_class::PASS}\">", "</span>",
      "<span style=\"#{title_token}\">", "<span style=\"#{header_token}\">",
      "<details>", "<summary>", "</summary>", "</details>"
    )
    expect(rich).not_to match(/<style|url\(|position:| class=| id=|<img|<svg|javascript:|\son[a-z]+=/)
  end

  { inline: ->(accent) { accent.title("title") },
    html: ->(accent) { accent.details(summary: "summary", body: "body") },
    cell: ->(accent) { accent.table_header("header", columns: 2) },
    fence: ->(accent) { accent.details(summary: "summary", body: "body") },
    escape_html: ->(accent) { accent.pill("PASS", tone: :pass) },
    longest_run: ->(accent) { accent.details(summary: "summary", body: "body") }
  }.each do |entry, build|
    it "lets #{entry} faults reach the owning outer Fallback and restores only the original baseline" do
      original = "Original baseline evidence".freeze
      plain = "New plain Ledger message".freeze
      allow(markdown).to receive(entry).and_raise(StandardError, "SECRET123")
      reached_guard = false
      result = fallback.render(fallback: -> { original }) do
        candidate = build.call(described_class)
        reached_guard = true
        described_class.guard(plain: plain, rich: candidate, level: :info)
      end
      expect(result).to equal(original)
      expect(reached_guard).to be(false)
      expect(logger).to have_received(:warn).with(fallback::WARNING).once
      expect(Thread.current[fallback::ACTIVE_KEY]).to be_nil
    end
  end

  it "does not turn an unavailable safe fence into empty folded evidence" do
    allow(markdown).to receive(:fence).and_return(nil)
    result = fallback.render(fallback: -> { "Original body evidence" }) do
      described_class.details(summary: "Body", body: "must not disappear")
    end
    expect(result).to eq("Original body evidence")
    expect(logger).to have_received(:warn).with(fallback::WARNING).once
  end

  it "does not rescue direct helper failures or Interrupts on its own" do
    allow(markdown).to receive(:inline).and_raise(StandardError, "helper fault")
    expect { described_class.title("Title") }.to raise_error(StandardError, "helper fault")
    allow(markdown).to receive(:inline).and_raise(Interrupt)
    expect { fallback.render(fallback: -> { "baseline" }) { described_class.title("Title") } }.to raise_error(Interrupt)
    expect(logger).not_to have_received(:warn)
  end

  it "does not read environment switches or runtime context and is deterministic with frozen inputs" do
    expect(ENV).not_to receive(:[])
    expect(ENV).not_to receive(:fetch)
    expect(ReportportalCucumber).not_to receive(:current_runtime)
    summary = "Summary <other>".freeze
    body = "raw *text*\nnext".freeze
    plain = "plain".freeze
    first = described_class.details(summary: summary, body: body)
    second = described_class.details(summary: summary, body: body)
    expect(first).to eq(second)
    expect(described_class.guard(plain: plain, rich: first, level: :info)).to equal(first)
    expect(summary).to eq("Summary <other>")
    expect(body).to eq("raw *text*\nnext")
  end

  it "keeps 1000 deterministic hostile inputs escaped outside dynamic fences and literal inside them" do
    random = Random.new(710_031)
    tokens = ["<other>", "</summary>", "<span style=\"x\">", "&amp;", "|", "\\", "`", "~~~",
              "*", "_", "[x](link)", "#", "\r\n", "\n", "\t", "\u4e2d\u6587", "\u{1f7e2}"]
    1000.times do
      value = Array.new(random.rand(1..24)) { tokens.sample(random: random) }.join
      title = described_class.title(value)
      pill = described_class.pill(value, tone: :info)
      header = described_class.table_header(value, columns: 6)
      expect(title.scan(/<[^>]*>/)).to eq(["<span style=\"#{title_token}\">", "</span>"])
      expect(pill.scan(/<[^>]*>/)).to eq(["<span style=\"#{pill_token};#{described_class::INFO}\">", "</span>"])
      expect(header.scan(/<[^>]*>/).reject { |tag| tag == "<br>" })
        .to eq(["<span style=\"#{header_token}\">", "</span>"])
      expect(header).not_to include("\n", "\r")
      expect(header).not_to match(/(?<!\\)(?:\\\\)*\|/)

      fold = described_class.details(summary: value, body: value)
      summary_line, rest = fold.split("\n\n", 2)
      expect(summary_line.scan(/<[^>]*>/)).to eq(["<details>", "<summary>", "</summary>"])
      delimiter = rest.lines.first.match(/\A(`{3,32}|~{3,32})text\n\z/)[1]
      expect(delimiter.length).to be > (value.scan(/#{Regexp.escape(delimiter[0])}+/).map(&:length).max || 0)
      expect(rest).to eq("#{delimiter}text\n#{value}\n#{delimiter}\n\n</details>")
    end
    expect(logger).not_to have_received(:warn)
  end

  it "can be required alone without loading Cucumber, SDK configuration, or the runtime" do
    root = File.expand_path("../../../lib", __dir__)
    script = <<~'RUBY'
      loaded_before = $LOADED_FEATURES.dup
      require "reportportal_cucumber/presentation/accent"
      accent = ReportportalCucumber::Presentation::Accent
      abort "missing helper" unless accent.pill("PASS", tone: :pass).include?(">PASS</span>")
      allowed = %w[accent markdown_text fallback].map { |name| "/presentation/#{name}.rb" }
      unexpected = ($LOADED_FEATURES - loaded_before).any? do |path|
        path.include?("reportportal_cucumber") && allowed.none? { |suffix| path.end_with?(suffix) }
      end
      abort "loaded SDK core" if unexpected || ReportportalCucumber.respond_to?(:current_runtime)
      abort "loaded Cucumber" if defined?(Cucumber)
    RUBY
    stdout, stderr, status = Open3.capture3(
      "env", "-u", "RUBYOPT", "-u", "BUNDLE_GEMFILE", "-u", "BUNDLE_BIN_PATH", "-u", "BUNDLER_VERSION",
      RbConfig.ruby, "-I#{root}", "-e", script
    )
    expect(status.success?).to(be(true), "stdout: #{stdout}\nstderr: #{stderr}")
  end
end
