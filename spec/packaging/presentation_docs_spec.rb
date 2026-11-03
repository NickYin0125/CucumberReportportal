# frozen_string_literal: true

require "rspec"
require "digest"
require_relative "../../lib/reportportal_cucumber/version"
require_relative "../../examples/current_sdk/helpers/sdk_version"

RSpec.describe "Readability backport candidate version and documentation" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:version) { "1.3.3" }
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
    previous = lock.sub("reportportal-cucumber-ruby (#{version})", "reportportal-cucumber-ruby (1.3.2)")
    expect(Digest::SHA256.hexdigest(previous)).to eq("7815879167aa1bb7df5b85977c9c2cc7a17456eb26cccea8961a68c1deb86abd")
  end

  it "pins the installed-package consumer fixture exactly" do
    expect(document("spec/packaging/fixtures/Gemfile")).to include(%(gem "reportportal-cucumber-ruby", "= #{version}"))
  end

  it "checks the actual candidate package identity" do
    expect(document("spec/packaging/release_package_spec.rb")).to include(%(expect(package.version.to_s).to eq("#{version}")))
  end

  it "preserves the exact released 1.3.2 root gemspec bytes and dependency bounds" do
    expect(Digest::SHA256.file(File.join(root, "reportportal-cucumber-ruby.gemspec")).hexdigest)
      .to eq("16df774d7a68b19fd38915ab38b11380bb4ad53f3a7903f4a5510b20810b7e99")
  end

  it "dates the authorized release section without borrowing the old Ledger rationale" do
    expect(changelog).to start_with("# Changelog\n\n## #{version} - 2026-11-03\n")
    candidate = changelog.split("\n## ", 3)[1]
    expect(candidate).to include("Selective Readability Backport", "2.0.2", "released 1.3.2", "Decision 19")
    expect(candidate).not_to include(rationale, "715/715", "1,519 examples", "Launches 3807")
  end

  it "retains previous release history after the candidate section" do
    releases = changelog.scan(/^## (\d+\.\d+\.\d+) - .+$/).flatten
    expect(releases.first(3)).to eq([version, "1.3.2", "1.3.1"])
    expect(releases.count("1.3.1")).to eq(1)
    previous = "# Changelog\n\n" + changelog.split(/(?=^## 1\.3\.2 - )/, 2).fetch(1)
    expect(Digest::SHA256.hexdigest(previous)).to eq("d2ebb7fa4f2a01c6baaeb65fec7aaee95eba96061d2fd12bff4de7df7a2885f3")
    expect(previous).to include(rationale)
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

  it "keeps the 1.x no-generated worker policy explicit" do
    expect(document("docs/configuration.md")).to include(
      "The 1.x formatter never generates a `workers` attribute"
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

  it "links the authorized GitHub release while retaining local candidates and the registry boundary" do
    paths = %w[README.md docs/getting-started.md docs/ci.md examples/current_sdk/README.md script/release/README.md]
    paths.each do |relative|
      text = document(relative)
      expect(text).to include("https://github.com/NickYin0125/CucumberReportportal/releases/tag/v#{version}")
      expect(text).not_to include("unpublished", "no 1.3.3 publication is assumed", "There is no 1.3.3 release-download URL")
      expect(text).to match(/RubyGems\s+(?:registry\s+)?publication\s+is\s+not\s+performed|No RubyGems publication/)
      expect(text).to match(/candidate/i)
    end
    expect(document("docs/getting-started.md")).to include("SDK_GEM_ARCHIVE", "gem install", version)
    expect(document("script/release/README.md")).to include("selectively backports 2.0.2", "Decision 19")
    expect(document("script/release/README.md")).not_to include(rationale)
  end

  it "keeps current installation guides on this candidate, not the previous one" do
    %w[README.md docs/getting-started.md docs/ci.md script/release/README.md].each do |relative|
      text = document(relative)
      expect(text).to include(version)
      expect(text).not_to include("reportportal-cucumber-ruby-1.3.2.gem", '"= 1.3.2"', "SDK **1.3.2**")
    end
  end

  it "documents the selective readability and unchanged 1.x failure boundaries" do
    %w[README.md docs/advanced-reporting.md docs/best-practices.md].each do |relative|
      text = document(relative)
      expect(text).to include("ERROR/FATAL", "Decision 19", "v1.3.1", "every backtrace frame", "FailureRedactor")
      expect(text).to match(/not (?:activated|globally redacted)|without\s+globally redacting/)
      expect(text).to match(/whitespace/)
      expect(text).to match(/top-level/)
      expect(text).to match(/repeated header/)
    end
  end

  it "does not claim native HTML screenshot deduplication or borrowed QA acceptance" do
    %w[README.md docs/best-practices.md].each do |relative|
      text = document(relative)
      expect(text).to include("R02 remains unfixed", "hiding passed logs can hide evidence owned by a passed")
      expect(text).to match(/does not also attach that PNG to native\s+HTML/)
    end
    release = changelog.split("\n## ", 3)[1]
    expect(release).to include("1,878 examples per cell", "1,879 examples per cell", "4085-4088",
                              "013fcd5a77511f7e4a3ae6d8018c96815d167abe", "scoped ACCEPT")
    expect(release).not_to include("verification is still required")
  end

  it "bounds the new over-depth withholding guarantee to automatic URL/evidence inputs" do
    text = document("docs/best-practices.md")
    expect(text).to include("bounded decoding budget", "intentionally withheld", "rather than decoded without limit",
                           "four/five-layer percent-encoded", "three-pass guard", "not a fix to the",
                           "raw logs remain outside this sanitization guarantee", "Decision 19")
  end
end
