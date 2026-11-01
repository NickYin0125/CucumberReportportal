# frozen_string_literal: true

require "rspec"
require_relative "../../lib/reportportal_cucumber/version"
require_relative "../../examples/current_sdk/helpers/sdk_version"

RSpec.describe "Ledger candidate version and documentation" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:version) { "2.0.1" }
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

  it "prepends an Unreleased section with the owner's exact patch rationale" do
    expect(changelog).to start_with("# Changelog\n\n## #{version} - Unreleased\n")
    expect(changelog.split("\n## ", 3)[1]).to include(rationale)
  end

  it "retains previous release history after the candidate section" do
    # Byte preservation is audited against the frozen branch separately; PR
    # merge checkouts may include legitimate target-branch release prose/dates.
    releases = changelog.scan(/^## (\d+\.\d+\.\d+) - .+$/).flatten
    expect(releases.first(2)).to eq([version, "2.0.0"])
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
    expect(document("script/release/README.md")).to include(rationale)
  end
end
