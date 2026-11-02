# frozen_string_literal: true

require "rspec"
require "ripper"

RSpec.describe "2.0.2 readability user documentation" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:candidate_notes) { document("CHANGELOG.md").split("\n## ", 3).fetch(1) }

  def document(relative)
    File.read(File.join(root, relative))
  end

  def prose(relative)
    document(relative).gsub(/\s+/, " ")
  end

  def section(relative, heading)
    document(relative).split(/^## #{Regexp.escape(heading)}\s*$/, 2).fetch(1).split(/^## /, 2).first
  end

  %w[README.md docs/configuration.md docs/advanced-reporting.md].each do |relative|
    it "documents whole-message ERROR/FATAL identity and existing-markup exceptions in #{relative}" do
      text = prose(relative)
      expect(text).to include("ERROR or FATAL", "entire message is byte-identical to plain",
                              "video markup and caller text remain unmodified", "TRACE through WARN")
      expect(text).not_to match(/every ERROR log's first line|Every ERROR first line|folds full backtraces/)
    end
  end

  %w[README.md docs/getting-started.md docs/best-practices.md docs/advanced-reporting.md].each do |relative|
    it "keeps R02 unresolved and explains the passed-After filter in #{relative}" do
      text = prose(relative)
      expect(text).to include("R02 remains unresolved (not fixed)", "Hide all passed logs", "After", "ERROR")
      expect(text).to match(/(?:API.*(?:ownership|ownership.*status)|ownership.*API)/)
      expect(text).to match(/(?:hides.*(?:After.*passed|passed After)|hidden.*passed After)/)
    end

    it "documents the RP-only screenshot tradeoff without changing native failure records in #{relative}" do
      text = prose(relative)
      expect(text).to include("rp_attach", "one RP caption", "PNG", "local",
                              "original failure exception and native failure records")
      expect(text).to match(/Native HTML (?:no longer includes|no longer receives|no longer.*screenshot)|omits the failure screenshot from native HTML/)
    end
  end

  it "keeps the capture API action-scoped rather than promising Scenario retargeting" do
    text = prose("docs/advanced-reporting.md")
    expect(text).to include("cannot select the Scenario as a capture target during After",
                            "invalid/foreign/closed targets", "never falls back to a Scenario",
                            "not to add retargeting", "hook status")
  end

  it "keeps 2.x troubleshooting on Cucumber 12 without the legacy resolution recipe" do
    guide = document("docs/getting-started.md")
    troubleshooting = section("docs/getting-started.md", "First-run troubleshooting")
    expect(troubleshooting).to include("Cucumber `>=12.0.1, ~>12.0`", "remove the legacy expressions `<19` pin")
    expect(guide).not_to include("Keep Cucumber `>=9,<11`", "Cucumber 11 / parameter message-builder failure")
  end

  it "puts the shared HTTP preview bounds beside the API recipe, before its first snippet" do
    recipe = section("docs/best-practices.md", "API tests: observe real calls, then assert")
    limits = recipe.split("```ruby", 2).first.gsub(/\s+/, " ")
    expect(limits).to include("AppLog.http", "shared **16 KiB / 100 lines**",
                              "request and response bodies and headers", "not a separate allowance per section",
                              "Redaction runs before preview clipping", "[preview truncated]",
                              "Full HTTP bodies are not attached automatically")
    expect(limits).to include("response subtitle/body, URL, request subtitle/body, request headers, then response headers",
                              "one `name: value` line per value", "content-type subtitles")
  end

  it "documents the pinned Ruby-to-Node Playwright mapping with primary versioned sources" do
    text = prose("docs/getting-started.md")
    expect(text).to include("Node >=20", "`playwright-ruby-client` **1.62.0**",
                            "COMPATIBLE_PLAYWRIGHT_VERSION = '1.62.1'", "`playwright-core` **1.62.1**",
                            'engines.node: ">=20"', "node_modules/playwright-core/package.json",
                            "https://github.com/YusukeIwaki/playwright-ruby-client/blob/1.62.0/lib/playwright/version.rb",
                            "https://github.com/microsoft/playwright/blob/v1.62.1/packages/playwright-core/package.json",
                            "not a dependency of the minimal Ruby-only Scenario")
    %w[README.md docs/best-practices.md].each do |relative|
      expect(document(relative)).to include("Node >=20", "getting-started.md#4-add-apiui-evidence")
    end
  end

  it "explains whitespace labels and top-level deltas for both failing and passing observations" do
    expect(document("docs/advanced-reporting.md")).to include(
      '"" (empty string)', '"   " (3 spaces)', '" a " (leading/trailing whitespace)'
    )
    text = prose("docs/advanced-reporting.md")
    expect(text).to include("Other strings remain as-is",
                            "sorted top-level keys", "missing in actual", "extra in actual", "changed",
                            "omitting empty groups", "not a recursive diff", "nested changes add no line",
                            "passing observation with differing objects", "equal passing values add no line")
    expect(text).not_to include("before the failed comparison")
  end

  %w[docs/configuration.md docs/advanced-reporting.md].each do |relative|
    it "keeps workers/branch/build in the description and versions in attributes in #{relative}" do
      text = prose(relative)
      expect(text).to include("workers, `branch@sha` and build", "SDK, Cucumber and Ruby versions remain Launch attributes")
      expect(text).to match(/explicit.*(?:retained|win)/)
      expect(text).not_to include("one-line Cucumber/Ruby/branch description")
    end
  end

  it "removes internal historical names from current user guides, not the historical changelog" do
    guides = %w[README.md docs/getting-started.md docs/configuration.md docs/advanced-reporting.md
                docs/best-practices.md docs/ci.md docs/migrating-to-2.0.md]
    guides.each do |relative|
      expect(document(relative)).not_to match(/pre-Ledger|AppLog 1\.3\.1|Ledger(?:'s)? (?:plain|presentation)/i), relative
    end
    expect(document("CHANGELOG.md")).to include("## 2.0.1 - Unreleased\n\n### Ledger Presentation")
  end

  it "uses the current candidate in the migration recipe without claiming fresh QA" do
    migration = prose("docs/migrating-to-2.0.md")
    expect(migration).to include('gem "reportportal-cucumber-ruby", "= 2.0.2", path: ENV.fetch("SDK_SOURCE")',
                                 "not a fresh 2.0.2 regression claim")
  end

  it "keeps the After recipe valid Ruby with one RP-only attachment and no native screenshot route" do
    recipe = document("docs/best-practices.md")[/```ruby\n(After do \|scenario\|.*?\nend)\n```/m, 1]
    expect(recipe).not_to be_nil
    expect(Ripper.sexp(recipe)).not_to be_nil
    expect(recipe.scan(/\brp_attach\(/).length).to eq(1)
    expect(recipe).to include("message: caption, level: :error", "Automation::EvidenceRedactor",
                              "SecureRandom.hex", "@page.screenshot")
    expect(recipe).not_to match(/AppLog\.error|rp_evidence\(|\brp_log\(|(?<!rp_)\battach\(/)
  end

  it "includes the revised guides and their local link destinations in the gem file list" do
    package = Gem::Specification.load(File.join(root, "reportportal-cucumber-ruby.gemspec"))
    guides = %w[README.md CHANGELOG.md docs/getting-started.md docs/configuration.md
                docs/advanced-reporting.md docs/best-practices.md docs/migrating-to-2.0.md]
    guides.each do |relative|
      expect(package.files).to include(relative)
      links = document(relative).scan(/\[[^\]]+\]\(([^\s)]+)(?:\s+"[^"]*")?\)/).flatten
      links.reject { |link| link.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|#|//)}i) }.each do |link|
        destination = File.expand_path(link.split("#", 2).first, File.dirname(File.join(root, relative)))
        expect(destination).to start_with("#{root}/")
        expect(package.files).to include(destination.delete_prefix("#{root}/")), "Unpackaged link in #{relative}: #{link}"
      end
    end
  end

  it "records all six fixes and the example refresh only in the Unreleased candidate section" do
    expect(candidate_notes).to start_with("2.0.2 - Unreleased\n")
    %w[F1 F2 F3 F4 F5 F6].each { |item| expect(candidate_notes).to include("- #{item}:") }
    expect(candidate_notes).to include("examples/current_sdk", "R02 remains unresolved (not fixed)",
                                       "native HTML no longer includes", "project-local npm prefix",
                                       "diagnostic-only", "<word>", "caller-declared passing observations",
                                       "Version attributes are retained")
  end

  it "describes implemented pipeline isolation without claiming cloud publication or live QA" do
    expect(candidate_notes).to include("Keep release-bundle dependencies", "outside the source checkout",
                                       "88 targeted tests", "cloud tag publication remains unverified",
                                       "not authorized", "not completed live QA", "pending validation")
    expect(candidate_notes).not_to include("Planned release-pipeline repair")
  end

  it "records the exact owner screenshot tradeoff and retains the prior R02 decision" do
    decisions = document("docs/design/presentation-ledger-owner-decisions.md")
    clarification = decisions.split("### WP2 Screenshot Scope Clarification\n", 2).fetch(1)
    expect(clarification).to include("Owner-confirmed on 2026-11-02.",
                                    "Owner answer: RP \u5408\u5e76\u4e3a\u4e00\u4e2a\u5e26\u622a\u56fe\u6761\u76ee\uff0c\u539f\u751f HTML \u4e0d\u518d\u9644\u622a\u56fe",
                                    "existing `rp_attach` API", "R02 unresolved (not fixed)")
    expect(decisions).to include("### R02 Scope Clarification", "Do not extend the runtime capture API")
  end
end
