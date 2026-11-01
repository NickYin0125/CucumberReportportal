# frozen_string_literal: true

require "digest"
require "rspec"
require_relative "../../lib/reportportal_cucumber/version"
require_relative "../../examples/current_sdk/helpers/sdk_version"

RSpec.describe "Ledger candidate version and documentation" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:version) { "2.0.2" }
  let(:changelog) { File.binread(File.join(root, "CHANGELOG.md")) }
  let(:rationale) do
    "Released as a patch at the owner's request; the two opt-in switches are additive and off by default."
  end

  def document(relative)
    File.read(File.join(root, relative))
  end

  it "sets the SDK identity to the candidate patch version" do
    expect(ReportportalCucumber::VERSION).to eq(version)
  end

  it "keeps the standalone example on the exact SDK candidate" do
    expect(CurrentSDK::SDK_VERSION).to eq(version)
    expect(document("examples/current_sdk/Gemfile")).to include('gem "reportportal-cucumber-ruby", "= #{CurrentSDK::SDK_VERSION}"')
  end

  it "keeps the root PATH package on the candidate without another SDK entry" do
    lock = document("Gemfile.lock")
    expect(lock.scan(/^    reportportal-cucumber-ruby \(([^)]+)\)$/).flatten).to eq([version])
    expect(lock).to start_with("PATH\n  remote: .\n")
  end

  it "pins the installed-package consumer fixture exactly" do
    expect(document("spec/packaging/fixtures/Gemfile")).to include(%(gem "reportportal-cucumber-ruby", "= #{version}"))
  end

  it "checks the actual candidate package identity" do
    expect(document("spec/packaging/release_package_spec.rb")).to include(%(expect(package.version.to_s).to eq("#{version}")))
  end

  it "uses this SDK candidate in every rejected Cucumber-resolution fixture" do
    source = document("spec/packaging/release_package_spec.rb")
    expect(source).to include(%(gem 'reportportal-cucumber-ruby', '= #{version}'))
    expect(source).to include("%w[9.2.1 10.2.0 11.0.0 12.0.0 13.0.0]")
  end

  it "prepends an Unreleased section without reusing the Ledger release rationale" do
    expect(changelog).to start_with("# Changelog\n\n## #{version} - Unreleased\n")
    expect(changelog.split("\n## ", 3)[1]).not_to include(rationale)
  end

  it "preserves the exact released 2.0.1 Ledger section with its Unreleased heading" do
    ledger = changelog[/^## 2\.0\.1 - Unreleased\n.*?(?=^## |\z)/m]
    expect(ledger).not_to be_nil
    expect(ledger).to include(rationale)
    expect(Digest::SHA256.hexdigest(ledger)).to eq("b691bb3fa90c79f8d64871dc3bbb5c54cd5c8a841acd6e5f9258eb247335d6d1")
  end

  it "retains the final Decision 19 verbatim without applying it to 2.x" do
    expected = <<~'TEXT'
      ## Decision 19: 1.x Failure-Log Content

      Owner-confirmed on 2026-11-01.

      19. On 1.x, the failure log carries the same text v1.3.1 sent, shown in the
          Ledger failure card. Failure-log redaction is not added in 1.3.2: the 2.x
          redactor omits the whole failure for common inputs (any backslash in the
          message), which hid failures that v1.3.1 showed (Launch 3778 versus
          Launches 3637 and 3731). Decision 15's P1.2 exception is withdrawn on 1.x,
          and G8 on 1.x means "nothing is sent that v1.3.1 would not have sent".
          2.x is unchanged; its whole-failure omission is a separate backlog item.
    TEXT
    decisions = document("docs/design/presentation-ledger-owner-decisions.md")
    expect(decisions[/^## Decision 19:.*?(?=^## |\z)/m]&.strip).to eq(expected.strip)
    expect(decisions).to include("PR #8 remains an unreleased 2.0.2 draft")
    expect(decisions).to include("does not certify or publish the split-redaction candidate")
  end

  it "retains previous release history after the candidate section" do
    # Byte preservation is audited against the frozen branch separately; PR
    # merge checkouts may include legitimate target-branch release prose/dates.
    releases = changelog.scan(/^## (\d+\.\d+\.\d+) - .+$/).flatten
    expect(releases.first(3)).to eq([version, "2.0.1", "2.0.0"])
    expect(releases.count("2.0.1")).to eq(1)
    expect(releases.count("2.0.0")).to eq(1)
  end

  %w[README.md docs/configuration.md docs/advanced-reporting.md examples/current_sdk/README.md].each do |relative|
    it "documents both independent opt-ins in #{relative}" do
      text = document(relative)
      expect(text).to include("RP_PRESENTATION", "RP_RUN_CONTEXT", "plain", "false", version)
      expect(text).to match(/Native|native/)
    end
  end

  it "documents exact defaults and the nonreflective invalid-presentation fallback" do
    config = document("docs/configuration.md")
    expect(config).to include("| `RP_PRESENTATION` | `presentation` | `plain` |")
    expect(config).to include("| `RP_RUN_CONTEXT` | `run_context` | `false` |")
    expect(config).to include("without echoing the value and falls back to plain", "1,024")
  end

  it "keeps the 2.x opt-in worker policy explicit" do
    expect(document("docs/configuration.md")).to include(
      "| `workers` (2.x only) | `PARALLEL_TEST_GROUPS`, only when present |"
    )
  end

  [4, 5, 6].each do |number|
    it "retains the exact owner Q/A for Decision #{number} in all three design documents" do
      proposal = document("docs/design/presentation-ledger-proposal.md")
      match = proposal.match(/^#{number}\. Question: (.+)\n\n +Owner answer: (.+)$/)
      expect(match).not_to be_nil
      %w[presentation-ledger-acceptance.md presentation-ledger-owner-decisions.md].each do |name|
        text = document("docs/design/#{name}")
        expect(text).to include("Question: #{match[1]}", "Owner answer: #{match[2]}")
      end
    end
  end

  it "uses supplied/local candidates instead of inventing published assets" do
    paths = %w[README.md docs/getting-started.md docs/ci.md examples/current_sdk/README.md script/release/README.md]
    paths.each do |relative|
      text = document(relative)
      expect(text).not_to match(%r{/releases/(?:tag|download)/v#{Regexp.escape(version)}})
      expect(text).to match(/candidate/i)
    end
    expect(document("docs/getting-started.md")).to include("SDK_GEM_ARCHIVE", "gem install", version)
    expect(document("script/release/README.md")).to include("SDK 2.0.1 Ledger rationale (historical):\n\n#{rationale}")
  end
end
