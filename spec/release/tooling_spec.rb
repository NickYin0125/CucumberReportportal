# frozen_string_literal: true

require "rspec"
require_relative "../../script/release/tooling"

RSpec.describe ReleaseTooling do
  let(:sha) { "a" * 40 }
  let(:commands) { ReleaseTooling::Commands.new }
  let(:source) { ReleaseTooling::Source.new(root: @root, tag: "v1.3.0", commit: sha, commands: commands) }
  let(:bundle) { ReleaseTooling::Bundle.new(source, File.join(@root, "output")) }

  before do
    @root = Dir.mktmpdir("release-spec-")
    FileUtils.mkdir_p(File.join(@root, ReleaseTooling::Source::CHART, "charts/reportportal"))
    File.write(File.join(@root, "reportportal-cucumber-ruby.gemspec"), <<~RUBY)
      Gem::Specification.new do |s|
        s.name = "reportportal-cucumber-ruby"
        s.version = "1.3.0"
        s.summary = "Release fixture"
        s.authors = ["Test"]
        s.license = "MIT"
        s.files = ["payload.rb"]
      end
    RUBY
    File.write(File.join(@root, "payload.rb"), "# release fixture\n")
    File.write(File.join(@root, "CHANGELOG.md"), "# Changelog\n\n## 1.3.0 - 2026-10-13\n\n### Safety\n\n- English release notes.\n\n## 1.2.0\n\n- Older notes.\n")
    File.write(File.join(@root, ReleaseTooling::Source::CHART, "Chart.yaml"), <<~YAML)
      apiVersion: v2
      name: reportportal-rich-experience
      version: 1.3.0
      appVersion: "26.0.7"
    YAML
    File.write(File.join(@root, ReleaseTooling::Source::CHART, "charts/reportportal/Chart.yaml"), <<~YAML)
      apiVersion: v2
      name: reportportal
      version: 26.10.26
    YAML
    allow(commands).to receive(:run).and_call_original
    allow(commands).to receive(:run).with("git", "rev-parse", "--verify", "HEAD", chdir: @root).and_return("#{sha}\n")
    allow(commands).to receive(:run).with("git", "rev-parse", "--verify", "refs/tags/v1.3.0^{commit}", chdir: @root).and_return("#{sha}\n")
    allow(commands).to receive(:run).with("git", "merge-base", "--is-ancestor", sha, "refs/remotes/origin/maintenance/1.x", chdir: @root).and_return("")
    allow(commands).to receive(:run).with("git", "status", "--porcelain", "--untracked-files=normal", chdir: @root).and_return("")
    allow(commands).to receive(:run).with("git", "show", "-s", "--format=%ct", sha, chdir: @root).and_return("1791849600\n")
  end

  after { FileUtils.remove_entry(@root) }

  def write_chart_archive(path, time: Time.now.to_i)
    previous = ENV["SOURCE_DATE_EPOCH"]
    ENV["SOURCE_DATE_EPOCH"] = time.to_s
    tar = StringIO.new("".b)
    Gem::Package::TarWriter.new(tar) do |writer|
      %w[Chart.yaml charts/reportportal/Chart.yaml].each do |relative|
        content = File.read(File.join(@root, ReleaseTooling::Source::CHART, relative))
        writer.add_file_simple("reportportal-rich-experience/#{relative}", 0o644, content.bytesize) { |io| io.write(content) }
      end
    end
    Zlib::GzipWriter.open(path) do |gzip|
      gzip.mtime = time
      gzip.write(tar.string)
    end
  ensure
    ENV["SOURCE_DATE_EPOCH"] = previous
  end

  def build_fixture
    # Build a real gem and a synthetic Helm tar, without network, Git changes, or publication.
    helm = File.join(@root, "fixture-helm")
    File.write(helm, "fixture")
    File.chmod(0o755, helm)
    previous = ENV["HELM_BIN"]
    ENV["HELM_BIN"] = helm
    allow(commands).to receive(:run).with(helm, "package", File.join(@root, ReleaseTooling::Source::CHART), "--destination", anything, chdir: @root) do |*_args, **_options|
      scratch = _args.last
      write_chart_archive(File.join(scratch, source.package_names.last))
      ""
    end
    bundle.build!
  ensure
    ENV["HELM_BIN"] = previous
  end

  it "requires stable tags and complete commit identities" do
    ["v1.3", "v01.3.0", "v1.3.0-rc.1", "v1.3.0;echo unsafe", "v0.1.0", "v3.0.0"].each do |tag|
      expect { ReleaseTooling::Source.new(root: @root, tag: tag, commit: sha) }.to raise_error(ReleaseTooling::Error)
    end
    expect { ReleaseTooling::Source.new(root: @root, tag: "v1.3.0", commit: "abc") }.to raise_error(ReleaseTooling::Error)
  end

  it "verifies SDK/chart agreement and independent ReportPortal identity" do
    expect(source.identity).to include("version" => "1.3.0", "appVersion" => "26.0.7")
    chart_path = File.join(@root, ReleaseTooling::Source::CHART, "Chart.yaml")
    File.write(chart_path, File.read(chart_path).sub("version: 1.3.0", "version: 1.2.0"))
    expect { source.identity }.to raise_error(ReleaseTooling::Error, /versions must match/)
    File.write(chart_path, File.read(chart_path).sub("version: 1.2.0", "version: 1.3.0").sub("26.0.7", "26.0.5"))
    expect { source.identity }.to raise_error(ReleaseTooling::Error, /appVersion/)
  end

  it "rejects moved tags and commits outside the approved maintenance ancestry" do
    allow(commands).to receive(:run).with("git", "rev-parse", "--verify", "refs/tags/v1.3.0^{commit}", chdir: @root).and_return("b" * 40)
    expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /tag moved/)
    allow(commands).to receive(:run).with("git", "rev-parse", "--verify", "refs/tags/v1.3.0^{commit}", chdir: @root).and_return(sha)
    allow(commands).to receive(:run).with("git", "merge-base", "--is-ancestor", sha, "refs/remotes/origin/maintenance/1.x", chdir: @root).and_raise(ReleaseTooling::Error, "outside maintenance")
    expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /outside approved release ancestry/)
  end

  it "rejects tracked or untracked dirty release sources without invoking build or publication" do
    [" M lib/client.rb\n", "?? credentials.txt\n"].each do |dirty|
      allow(commands).to receive(:run).with("git", "status", "--porcelain", "--untracked-files=normal", chdir: @root).and_return(dirty)
      expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /clean/)
      expect { bundle.build! }.to raise_error(ReleaseTooling::Error, /clean/)
    end
    expect(commands).not_to have_received(:run).with("gh", any_args)
  end

  it "retains the exact historical legacy manifest/title and limits main fallback to the immutable tag and SHA" do
    expect(source.identity).to eq("tag" => "v1.3.0", "commit" => sha, "version" => "1.3.0", "appVersion" => "26.0.7")
    expect(source.release_title).to eq("SDK and Helm 1.3.0")
    expect(source.ancestry_refs).to eq(["refs/remotes/origin/maintenance/1.x"])
    historical = ReleaseTooling::Source.new(root: @root, tag: "v1.3.1", commit: "4ca2f770e0a84e83688f165ba04b4db8ef855cf9")
    expect(historical.ancestry_refs).to eq(["refs/remotes/origin/maintenance/1.x", "refs/remotes/origin/main"])
    moved = ReleaseTooling::Source.new(root: @root, tag: "v1.3.1", commit: sha)
    expect(moved.ancestry_refs).not_to include("refs/remotes/origin/main")
  end

  context "with independently versioned SDK 2 and Helm 1 artifacts" do
    let(:source) { ReleaseTooling::Source.new(root: @root, tag: "v2.0.0", commit: sha, commands: commands) }

    before do
      gemspec = File.join(@root, "reportportal-cucumber-ruby.gemspec")
      File.write(gemspec, File.read(gemspec).sub('s.version = "1.3.0"', 's.version = "2.0.0"'))
      chart = File.join(@root, ReleaseTooling::Source::CHART, "Chart.yaml")
      File.write(chart, File.read(chart).sub("version: 1.3.0", "version: 1.3.1"))
      changelog = File.join(@root, "CHANGELOG.md")
      File.write(changelog, File.read(changelog).sub("## 1.3.0 -", "## 2.0.0 -"))
      allow(commands).to receive(:run).with("git", "rev-parse", "--verify", "refs/tags/v2.0.0^{commit}", chdir: @root).and_return(sha)
      allow(commands).to receive(:run).with("git", "merge-base", "--is-ancestor", sha, "refs/remotes/origin/main", chdir: @root).and_return("")
    end

    it "builds and verifies SDK2.0.0/chart1.3.1 while keeping ReportPortal26.0.7" do
      expect(source.identity).to include("version" => "2.0.0", "chartVersion" => "1.3.1", "appVersion" => "26.0.7")
      expect(source.release_title).to eq("SDK 2.0.0 / Helm 1.3.1")
      expect(source.package_names).to eq(%w[reportportal-cucumber-ruby-2.0.0.gem reportportal-rich-experience-1.3.1.tgz])
      build_fixture
      expect(bundle.verify!).to be(true)
      expect(source.notes).to start_with("# SDK 2.0.0 / Helm 1.3.1\n")
    end

    it "rejects chart manifest identity tampering even when the SDK version matches" do
      build_fixture
      path = File.join(bundle.directory, "release-manifest.json")
      manifest = JSON.parse(File.read(path))
      manifest["chartVersion"] = "2.0.0"
      File.write(path, JSON.generate(manifest))
      expect { bundle.verify! }.to raise_error(ReleaseTooling::Error, /identity mismatch/)
    end

    it "rejects unstable or incorrect source chart metadata for the independent SDK line" do
      path = File.join(@root, ReleaseTooling::Source::CHART, "Chart.yaml")
      original = File.read(path)
      [original.sub("version: 1.3.1", "version: 1.3.1-rc.1"),
       original.sub("name: reportportal-rich-experience", "name: impostor"),
       original.sub("26.0.7", "26.0.5")].each do |invalid|
        File.write(path, invalid)
        expect { source.identity }.to raise_error(ReleaseTooling::Error)
      end
    end

    it "rejects altered packaged chart identity even after every checksum is recomputed" do
      build_fixture
      chart_path = File.join(@root, ReleaseTooling::Source::CHART, "Chart.yaml")
      original = File.read(chart_path)
      archive_path = File.join(bundle.directory, source.package_names.last)
      [original.sub("version: 1.3.1", "version: 2.0.0"),
       original.sub("name: reportportal-rich-experience", "name: impostor"),
       original.sub("26.0.7", "26.0.5")].each do |invalid|
        File.write(chart_path, invalid)
        write_chart_archive(archive_path)
        File.write(chart_path, original)
        manifest_path = File.join(bundle.directory, "release-manifest.json")
        manifest = JSON.parse(File.read(manifest_path))
        manifest["sha256"] = source.package_names.to_h { |name| [name, bundle.digest(name)] }
        File.write(manifest_path, JSON.pretty_generate(manifest) + "\n")
        sums = (source.package_names + ["release-manifest.json"]).sort.map { |name| "#{bundle.digest(name)}  #{name}\n" }.join
        File.write(File.join(bundle.directory, "SHA256SUMS"), sums)
        expect { bundle.verify! }.to raise_error(ReleaseTooling::Error, /Built chart identity mismatch/)
      end
    end

    it "allows only fixed main or cucumber-12 ancestry, never arbitrary environment refs" do
      expect(source.ancestry_refs).to eq(%w[refs/remotes/origin/main refs/remotes/origin/codex/cucumber-12])
      allow(commands).to receive(:run).with("git", "merge-base", "--is-ancestor", sha, "refs/remotes/origin/main", chdir: @root).and_raise(ReleaseTooling::Error, "foreign main")
      allow(commands).to receive(:run).with("git", "merge-base", "--is-ancestor", sha, "refs/remotes/origin/codex/cucumber-12", chdir: @root).and_return("")
      expect { source.verify_commit! }.not_to raise_error
      allow(commands).to receive(:run).with("git", "merge-base", "--is-ancestor", sha, "refs/remotes/origin/codex/cucumber-12", chdir: @root).and_raise(ReleaseTooling::Error, "foreign release")
      expect { source.verify_commit! }.to raise_error(ReleaseTooling::Error, /outside approved release ancestry/)
    end
  end

  it "takes only the exact versioned changelog section" do
    expect(source.notes).to include("English release notes", "### Safety")
    expect(source.notes).not_to include("Older notes", "1.2.0")
    File.write(File.join(@root, "CHANGELOG.md"), "## 1.3.0-rc.1\n\n- Not this version.\n")
    expect { source.notes }.to raise_error(ReleaseTooling::Error, /exactly one/)
  end

  it "rejects duplicate or empty changelog sections" do
    File.write(File.join(@root, "CHANGELOG.md"), "## 1.3.0\n\n")
    expect { source.notes }.to raise_error(ReleaseTooling::Error, /empty/)
    File.write(File.join(@root, "CHANGELOG.md"), "## 1.3.0\n- One\n## 1.3.0\n- Two\n")
    expect { source.notes }.to raise_error(ReleaseTooling::Error, /exactly one/)
  end

  it "produces installable gem, chart, checksums, and build provenance" do
    build_fixture
    expect(bundle.verify!).to be(true)
    expect(Dir.children(bundle.directory)).to match_array(source.asset_names + ["release-notes.md"])
    expect(JSON.parse(File.read(File.join(bundle.directory, "release-manifest.json")))).to include(source.identity)
  end

  it "makes packages byte-identical across retries despite Helm timestamps" do
    build_fixture
    first = source.asset_names.to_h { |name| [name, bundle.digest(name)] }
    FileUtils.remove_entry(bundle.directory)
    build_fixture
    expect(source.asset_names.to_h { |name| [name, bundle.digest(name)] }).to eq(first)
    original = File.join(@root, "original.tgz")
    changed = File.join(@root, "changed.tgz")
    write_chart_archive(original, time: 1000)
    write_chart_archive(changed, time: 2000)
    bundle.send(:canonical_chart, original, File.join(@root, "canonical-a.tgz"), 1500)
    bundle.send(:canonical_chart, changed, File.join(@root, "canonical-b.tgz"), 1500)
    expect(File.binread(File.join(@root, "canonical-a.tgz"))).to eq(File.binread(File.join(@root, "canonical-b.tgz")))
  end

  it "blocks tampered assets, unsafe bundle files, and altered notes" do
    build_fixture
    notes = File.join(bundle.directory, "release-notes.md")
    File.write(notes, "different")
    expect { bundle.verify! }.to raise_error(ReleaseTooling::Error, /notes differ/)
    File.write(notes, source.notes)
    File.write(File.join(bundle.directory, source.package_names.last), "tampered")
    expect { bundle.verify! }.to raise_error(ReleaseTooling::Error, /checksum mismatch/)
    File.write(File.join(bundle.directory, "extra"), "unsafe")
    expect { bundle.verify! }.to raise_error(ReleaseTooling::Error, /Unexpected or missing/)
  end

  describe "publication" do
    let(:remote) { {} }
    let(:gh_commands) { [] }
    let(:publisher) { ReleaseTooling::Publisher.new(source, bundle.directory, repository: "owner/repo", commands: commands) }
    let(:release) { { "tag_name" => source.tag, "target_commitish" => sha, "draft" => true, "assets" => [] } }

    before do
      build_fixture
      allow(commands).to receive(:run).with("gh", any_args) do |*args, **options|
        gh_commands << args
        case args[1..2]
        when ["api", "repos/owner/repo/releases/tags/v1.3.0"]
          expect(options).to eq(allow_missing: true)
          remote[:release] && !remote[:release].fetch("draft") && JSON.generate(remote[:release])
        when ["api", "repos/owner/repo/releases?per_page=100"]
          expect(args[3..]).to eq(["--paginate", "--slurp"])
          JSON.generate(remote.fetch(:pages, [remote.fetch(:list, [remote[:release]].compact)]))
        when ["release", "create"]
          remote[:release] = release
          ""
        when ["release", "upload"]
          path = args[4]
          name = File.basename(path)
          remote[name] = File.binread(path)
          remote.fetch(:release).fetch("assets") << { "name" => name, "state" => "uploaded" }
          ""
        when ["release", "download"]
          name = args[args.index("--pattern") + 1]
          destination = args[args.index("--dir") + 1]
          File.binwrite(File.join(destination, name), remote.fetch(name))
          ""
        when ["release", "edit"]
          remote.fetch(:release)["draft"] = false
          ""
        else
          raise "Unexpected gh command: #{args.inspect}"
        end
      end
    end

    it "creates a draft, uploads all assets, verifies downloads, then publishes" do
      publisher.publish!
      expect(remote.fetch(:release).fetch("draft")).to be(false)
      expect(gh_commands.first(3).map { |args| args[1] }).to eq(%w[api api release])
      create = gh_commands.find { |args| args[2] == "create" }
      expect(create).to include("--verify-tag", "--draft", "--target", sha)
      expect(gh_commands.last[1..2]).to eq(%w[release edit])
      expect(gh_commands.count { |args| args[2] == "download" }).to eq(4)
      expect(gh_commands.flatten).not_to include("--clobber", "delete")
    end

    it "resumes a partially uploaded draft without overwriting existing assets" do
      remote[:release] = release
      name = source.package_names.first
      remote[name] = File.binread(File.join(bundle.directory, name))
      release["assets"] << { "name" => name, "state" => "uploaded" }
      publisher.publish!
      uploads = gh_commands.select { |args| args[2] == "upload" }.map { |args| File.basename(args[4]) }
      expect(uploads).to match_array(source.asset_names - [name])
      expect(gh_commands.none? { |args| args[2] == "create" }).to be(true)
    end

    it "finds an existing draft hidden by the by-tag endpoint without creating a duplicate" do
      remote[:release] = release
      publisher.publish!
      expect(remote.fetch(:release).fetch("draft")).to be(false)
      expect(gh_commands).to include(["gh", "api", "repos/owner/repo/releases?per_page=100",
                                     "--paginate", "--slurp"])
      expect(gh_commands.none? { |args| args[2] == "create" }).to be(true)
    end

    it "refuses ambiguous drafts instead of selecting or modifying one" do
      remote[:list] = [release, release.dup]
      expect { publisher.publish! }.to raise_error(ReleaseTooling::Error, /Ambiguous/)
      expect(gh_commands.none? { |args| %w[create upload edit].include?(args[2]) }).to be(true)
    end

    it "finds a matching draft on later pages and rejects malformed listing records" do
      remote[:pages] = [[release.merge("tag_name" => "v1.2.0")], [release]]
      expect(publisher.__send__(:read_release)).to eq(release)
      remote[:pages] = [["malformed"]]
      expect { publisher.__send__(:read_release) }.to raise_error(ReleaseTooling::Error, /Unexpected remote release records/)
      expect(gh_commands.none? { |args| %w[create upload edit].include?(args[2]) }).to be(true)
    end

    it "does not turn draft-list authorization failure into a new release" do
      allow(commands).to receive(:run).with("gh", "api", "repos/owner/repo/releases?per_page=100", any_args)
        .and_raise(ReleaseTooling::Error, "HTTP 403")
      expect { publisher.publish! }.to raise_error(ReleaseTooling::Error, /403/)
      expect(gh_commands.none? { |args| %w[create upload edit].include?(args[2]) }).to be(true)
    end

    it "makes a published retry strictly read-only" do
      publisher.publish!
      gh_commands.clear
      publisher.publish!
      expect(gh_commands.all? { |args| args[1] == "api" || args[2] == "download" }).to be(true)
    end

    it "does not repair a published release with missing assets" do
      remote[:release] = release.merge("draft" => false)
      expect { publisher.publish! }.to raise_error(ReleaseTooling::Error, /incomplete/)
      expect(gh_commands.length).to eq(1)
    end

    it "does not overwrite mismatched draft assets or publish them" do
      remote[:release] = release
      name = source.package_names.first
      remote[name] = "wrong bytes"
      release["assets"] << { "name" => name, "state" => "uploaded" }
      expect { publisher.publish! }.to raise_error(ReleaseTooling::Error, /Remote asset differs/)
      expect(gh_commands.none? { |args| %w[upload edit].include?(args[2]) }).to be(true)
    end

    it "leaves a failed upload as an unpublished draft for retry" do
      allow(commands).to receive(:run).with("gh", "release", "upload", source.tag, anything, "--repo", "owner/repo").and_raise(ReleaseTooling::Error, "upload failed")
      expect { publisher.publish! }.to raise_error(ReleaseTooling::Error, /upload failed/)
      expect(remote.fetch(:release).fetch("draft")).to be(true)
      expect(gh_commands.none? { |args| args[2] == "edit" }).to be(true)
    end

    it "rejects incomplete, unexpected or wrong-commit remote assets" do
      remote[:release] = release.merge("target_commitish" => "b" * 40)
      expect { publisher.publish! }.to raise_error(ReleaseTooling::Error, /expected tag and commit/)
      remote[:release] = release.merge("assets" => [{ "name" => "unexpected", "state" => "uploaded" }])
      expect { publisher.publish! }.to raise_error(ReleaseTooling::Error, /Unexpected or duplicate/)
      remote[:release] = release.merge("assets" => [{ "name" => source.package_names.first, "state" => "starter" }])
      expect { publisher.publish! }.to raise_error(ReleaseTooling::Error, /incomplete asset/)
    end
  end

  it "distinguishes a missing release from authentication or network failure" do
    status = instance_double(Process::Status, success?: false)
    allow(commands).to receive(:capture).and_return(["", "gh: Not Found (HTTP 404)", status])
    expect(commands.run("gh", "api", "test", allow_missing: true)).to be_nil
    allow(commands).to receive(:capture).and_return(["", "gh: Bad credentials (HTTP 401)", status])
    expect { commands.run("gh", "api", "test", allow_missing: true) }.to raise_error(ReleaseTooling::Error, /401/)
  end
end
