# frozen_string_literal: true

require "rspec"
require_relative "../../script/release/tooling"

RSpec.describe "Independent SDK and Helm release versions" do
  let(:version) { "1.3.2" }
  let(:commit) { "a" * 40 }
  let(:commands) { ReleaseTooling::Commands.new }
  let(:source) { ReleaseTooling::Source.new(root: @root, tag: "v#{version}", commit: commit, commands: commands) }
  let(:bundle) { ReleaseTooling::Bundle.new(source, File.join(@root, "output")) }

  before do
    @root = Dir.mktmpdir("independent-release-versions-")
    @chart = File.join(@root, ReleaseTooling::Source::CHART)
    FileUtils.mkdir_p(File.join(@chart, "charts/reportportal"))
    write_gem(version)
    write_chart("1.3.1")
    File.write(File.join(@chart, "charts/reportportal/Chart.yaml"), "apiVersion: v2\nname: reportportal\nversion: 26.10.26\n")
    File.write(File.join(@root, "payload.rb"), "# release fixture\n")
    File.write(File.join(@root, "CHANGELOG.md"), "# Changelog\n\n## #{version} - Unreleased\n\n- Independent SDK and Chart versions.\n")
  end

  after { FileUtils.remove_entry(@root) }

  def write_gem(version, name: "reportportal-cucumber-ruby")
    File.write(File.join(@root, "reportportal-cucumber-ruby.gemspec"), <<~RUBY)
      Gem::Specification.new do |s|
        s.name = #{name.inspect}
        s.version = #{version.inspect}
        s.summary = "Release fixture"
        s.authors = ["Test"]
        s.license = "MIT"
        s.files = ["payload.rb"]
      end
    RUBY
  end

  def write_chart(version, app_version: "26.0.7", name: "reportportal-rich-experience")
    File.write(File.join(@chart, "Chart.yaml"), YAML.dump(
      "apiVersion" => "v2", "name" => name, "version" => version, "appVersion" => app_version
    ))
  end

  def write_synthetic_chart(destination)
    tar = StringIO.new("".b)
    Gem::Package::TarWriter.new(tar) do |writer|
      %w[Chart.yaml charts/reportportal/Chart.yaml].each do |relative|
        content = File.binread(File.join(@chart, relative))
        writer.add_file_simple("reportportal-rich-experience/#{relative}", 0o644, content.bytesize) { |io| io.write(content) }
      end
    end
    Zlib::GzipWriter.open(destination) { |gzip| gzip.write(tar.string) }
  end

  def build_bundle
    # An isolated release fixture only: no real Helm invocation, tag or publication.
    allow(source).to receive(:verify_commit!).and_return(true)
    allow(commands).to receive(:run).and_call_original
    allow(commands).to receive(:run).with("git", "show", "-s", "--format=%ct", commit, chdir: @root).and_return("1793404800\n")
    allow(commands).to receive(:run).with(Gem.ruby, "package", @chart, "--destination", anything, chdir: @root) do |*_args, **_options|
      write_synthetic_chart(File.join(_args.last, source.package_names.last))
      ""
    end
    previous = ENV["HELM_BIN"]
    ENV["HELM_BIN"] = Gem.ruby
    bundle.build!
  ensure
    ENV["HELM_BIN"] = previous
  end

  def refresh_checksums
    path = File.join(bundle.directory, "release-manifest.json")
    manifest = JSON.parse(File.read(path))
    manifest["sha256"] = source.package_names.to_h { |name| [name, bundle.digest(name)] }
    File.write(path, JSON.pretty_generate(manifest) + "\n")
    sums = (source.package_names + ["release-manifest.json"]).sort.map { |name| "#{bundle.digest(name)}  #{name}\n" }.join
    File.write(File.join(bundle.directory, "SHA256SUMS"), sums)
  end

  %w[1.3.2 1.4.0 2.0.1].each do |sdk_version|
    context "with SDK #{sdk_version}" do
      let(:version) { sdk_version }

      it "keeps SDK/tag agreement while allowing Helm 1.3.1" do
        expect(source.identity).to eq(
          "tag" => "v#{version}", "commit" => commit, "version" => version,
          "appVersion" => "26.0.7", "chartVersion" => "1.3.1"
        )
        expect(source.package_names).to eq(["reportportal-cucumber-ruby-#{version}.gem", "reportportal-rich-experience-1.3.1.tgz"])
        expect(source.release_title).to eq("SDK #{version} / Helm 1.3.1")
        expect(source.notes).to start_with("# SDK #{version} / Helm 1.3.1\n")
      end

      it "rejects a gem whose version does not match its tag" do
        write_gem("1.3.0")
        expect { source.identity }.to raise_error(ReleaseTooling::Error, /Tag and gem versions must match/)
      end
    end
  end

  it "preserves the historical manifest and title for SDK 1.3.1" do
    write_gem("1.3.1")
    historic = ReleaseTooling::Source.new(root: @root, tag: "v1.3.1", commit: commit)
    expect(historic.identity).to eq("tag" => "v1.3.1", "commit" => commit, "version" => "1.3.1", "appVersion" => "26.0.7")
    expect(historic.release_title).to eq("SDK and Helm 1.3.1")
    write_chart("1.3.0")
    expect { historic.identity }.to raise_error(ReleaseTooling::Error, /Historical.*versions must match/)
  end

  it "validates the independent chart version rather than accepting arbitrary filenames" do
    [nil, 1.3, "1.3", "01.3.1", "1.3.1-rc.1", "../../escape"].each do |invalid|
      write_chart(invalid)
      expect { source.identity }.to raise_error(ReleaseTooling::Error, /Chart version must be a stable/)
      expect { source.package_names }.to raise_error(ReleaseTooling::Error, /Chart version must be a stable/)
    end
  end

  it "retains the ReportPortal appVersion and Chart-name checks" do
    write_chart("1.3.1", app_version: "26.0.5")
    expect { source.identity }.to raise_error(ReleaseTooling::Error, /appVersion/)
    write_chart("1.3.1", name: "another-chart")
    expect { source.identity }.to raise_error(ReleaseTooling::Error, /Unexpected package names/)
  end

  it "rejects an unexpected Gem name" do
    write_gem(version, name: "another-gem")
    expect { source.identity }.to raise_error(ReleaseTooling::Error, /Unexpected package names/)
  end

  it "builds and verifies SDK 1.3.2 with a synthetic Helm 1.3.1 fixture" do
    build_bundle
    expect(bundle.verify!).to be(true)
    manifest = JSON.parse(File.read(File.join(bundle.directory, "release-manifest.json")))
    expect(manifest).to include("version" => "1.3.2", "chartVersion" => "1.3.1")
    expect(manifest.fetch("sha256").keys).to match_array(source.package_names)
    expect(Gem::Package.new(File.join(bundle.directory, source.package_names.first)).spec.version.to_s).to eq("1.3.2")
  end

  it "rejects a changed chartVersion in the manifest even with refreshed checksums" do
    build_bundle
    path = File.join(bundle.directory, "release-manifest.json")
    manifest = JSON.parse(File.read(path))
    manifest["chartVersion"] = "1.3.2"
    File.write(path, JSON.pretty_generate(manifest) + "\n")
    refresh_checksums
    expect { bundle.verify! }.to raise_error(ReleaseTooling::Error, /manifest identity mismatch/)
  end

  it "checks the version inside the chart archive, not only its filename or digest" do
    build_bundle
    archive = File.join(bundle.directory, source.package_names.last)
    write_chart("1.3.2")
    write_synthetic_chart(archive)
    write_chart("1.3.1")
    refresh_checksums
    expect { bundle.verify! }.to raise_error(ReleaseTooling::Error, /Built chart identity mismatch/)
  end

  it "rejects corrupted SDK bytes before inspecting package metadata" do
    build_bundle
    File.open(File.join(bundle.directory, source.package_names.first), "ab") { |file| file.write("corrupted") }
    expect { bundle.verify! }.to raise_error(ReleaseTooling::Error, /checksum mismatch/)
  end

  it "rejects an incorrect SHA256SUMS file" do
    build_bundle
    File.write(File.join(bundle.directory, "SHA256SUMS"), "0" * 64 + "  incorrect.gem\n")
    expect { bundle.verify! }.to raise_error(ReleaseTooling::Error, /SHA256SUMS mismatch/)
  end

  it "uses the independent versions in both draft and published titles" do
    build_bundle
    publisher = ReleaseTooling::Publisher.new(source, bundle.directory, repository: "owner/repo", commands: commands)
    draft = { "tag_name" => source.tag, "target_commitish" => commit, "draft" => true, "assets" => source.asset_names.map { |name| { "name" => name, "state" => "uploaded" } } }
    allow(publisher).to receive(:read_release).and_return(nil, draft, draft)
    allow(publisher).to receive(:verify_remote!)
    allow(commands).to receive(:run).with("gh", any_args).and_return("")
    publisher.publish!
    expect(commands).to have_received(:run).with("gh", "release", "create", source.tag, "--verify-tag", "--draft", "--target", commit,
                                               "--title", "SDK 1.3.2 / Helm 1.3.1", "--notes-file", anything, "--repo", "owner/repo")
    expect(commands).to have_received(:run).with("gh", "release", "edit", source.tag, "--draft=false", "--latest=false", "--title", "SDK 1.3.2 / Helm 1.3.1",
                                               "--notes-file", anything, "--repo", "owner/repo")
  end
end
