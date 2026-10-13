# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "rubygems/package"
require "stringio"
require "tmpdir"
require "yaml"
require "zlib"

module ReleaseTooling
  class Error < StandardError; end

  class Commands
    def capture(*arguments, **options)
      Open3.capture3(*arguments, **options)
    end

    def run(*arguments, env: {}, chdir: Dir.pwd, allow_missing: false)
      out, err, status = capture(env, *arguments, chdir: chdir)
      return out if status.success?
      return nil if allow_missing && err.match?(/\(HTTP 404\)/)

      raise Error, "Command failed: #{arguments.join(' ')}\n#{err}"
    end
  end

  class Source
    CHART = "helm/reportportal-rich-experience"
    APP_VERSION = "26.0.5"
    attr_reader :root, :tag, :commit, :version, :commands

    def initialize(root:, tag:, commit:, commands: Commands.new)
      raise Error, "Only stable vMAJOR.MINOR.PATCH tags are supported" unless tag.match?(/\Av(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/)
      raise Error, "Expected a full Git commit SHA" unless commit.match?(/\A[0-9a-f]{40}\z/)

      @root, @tag, @commit, @commands = File.expand_path(root), tag, commit, commands
      @version = tag.delete_prefix("v")
    end

    def identity
      gem = Gem::Specification.load(File.join(root, "reportportal-cucumber-ruby.gemspec"))
      raise Error, "Cannot load gem specification" unless gem

      chart = YAML.safe_load_file(File.join(root, CHART, "Chart.yaml"))
      raise Error, "Tag, gem and chart versions must match exactly" unless gem.version.to_s == version && chart.fetch("version") == version
      raise Error, "ReportPortal appVersion must remain #{APP_VERSION}" unless chart.fetch("appVersion") == APP_VERSION
      raise Error, "Unexpected package names" unless gem.name == "reportportal-cucumber-ruby" && chart.fetch("name") == "reportportal-rich-experience"

      { "tag" => tag, "commit" => commit, "version" => version, "appVersion" => APP_VERSION }
    end

    def verify_commit!
      head = commands.run("git", "rev-parse", "--verify", "HEAD", chdir: root).strip
      raise Error, "Checkout does not match release commit" unless head == commit
      resolved = commands.run("git", "rev-parse", "--verify", "refs/tags/#{tag}^{commit}", chdir: root).strip
      raise Error, "Release tag moved or does not match checkout" unless resolved == commit

      commands.run("git", "merge-base", "--is-ancestor", commit, "refs/remotes/origin/main", chdir: root)
    end

    def notes
      text = File.read(File.join(root, "CHANGELOG.md"))
      sections = text.split(/(?=^## )/)
      matches = sections.select { |section| section.lines.first.match?(/\A## \[?v?#{Regexp.escape(version)}\]?(?:\s+-[^\n]*)?\s*\z/) }
      raise Error, "CHANGELOG must contain exactly one section for #{version}" unless matches.length == 1

      body = matches.first.lines.drop(1).join.strip
      raise Error, "Release notes are empty" if body.empty?

      "# SDK and Helm #{version}\n\n#{body}\n"
    end

    def package_names
      ["reportportal-cucumber-ruby-#{version}.gem", "reportportal-rich-experience-#{version}.tgz"]
    end

    def asset_names
      package_names + %w[release-manifest.json SHA256SUMS]
    end
  end

  class Bundle
    attr_reader :source, :directory

    def initialize(source, directory)
      @source, @directory = source, File.expand_path(directory)
    end

    def build!
      source.verify_commit!
      identity = source.identity
      notes = source.notes
      raise Error, "Output directory must be empty" if File.exist?(directory) && !Dir.empty?(directory)

      FileUtils.mkdir_p(directory)
      epoch = Integer(source.commands.run("git", "show", "-s", "--format=%ct", source.commit, chdir: source.root).strip)
      env = { "SOURCE_DATE_EPOCH" => epoch.to_s }
      gem_path = File.join(directory, source.package_names.first)
      source.commands.run(Gem.ruby, "-S", "gem", "build", "reportportal-cucumber-ruby.gemspec", "--output", gem_path,
                          env: env, chdir: source.root)
      helm = ENV.fetch("HELM_BIN") { raise Error, "HELM_BIN must select an executable Helm" }
      raise Error, "HELM_BIN is not executable" unless File.executable?(helm)

      Dir.mktmpdir("release-chart-") do |scratch|
        source.commands.run(helm, "package", File.join(source.root, Source::CHART), "--destination", scratch, chdir: source.root)
        canonical_chart(File.join(scratch, source.package_names.last), File.join(directory, source.package_names.last), epoch)
      end
      manifest = identity.merge("sha256" => source.package_names.to_h { |name| [name, digest(name)] })
      File.write(File.join(directory, "release-manifest.json"), JSON.pretty_generate(manifest) + "\n")
      sums = (source.package_names + ["release-manifest.json"]).sort.map { |name| "#{digest(name)}  #{name}\n" }.join
      File.write(File.join(directory, "SHA256SUMS"), sums)
      File.write(File.join(directory, "release-notes.md"), notes)
      verify!
    end

    def verify!
      expected = source.asset_names + ["release-notes.md"]
      raise Error, "Unexpected or missing release bundle files" unless Dir.children(directory).sort == expected.sort

      expected.each do |name|
        path = File.join(directory, name)
        raise Error, "Release file must be a nonempty regular file: #{name}" unless File.file?(path) && !File.symlink?(path) && File.size?(path)
      end
      manifest = JSON.parse(File.read(File.join(directory, "release-manifest.json")))
      identity = source.identity
      raise Error, "Release manifest identity mismatch" unless manifest.reject { |key, _| key == "sha256" } == identity
      hashes = source.package_names.to_h { |name| [name, digest(name)] }
      raise Error, "Package checksum mismatch" unless manifest.fetch("sha256") == hashes

      hashes["release-manifest.json"] = digest("release-manifest.json")
      sums = hashes.sort.map { |name, hash| "#{hash}  #{name}\n" }.join
      raise Error, "SHA256SUMS mismatch" unless File.read(File.join(directory, "SHA256SUMS")) == sums
      raise Error, "Release notes differ from committed changelog" unless File.read(File.join(directory, "release-notes.md")) == source.notes

      gem = Gem::Package.new(File.join(directory, source.package_names.first))
      gem.verify
      raise Error, "Built gem identity mismatch" unless gem.spec.name == "reportportal-cucumber-ruby" && gem.spec.version.to_s == source.version

      chart = chart_entries(File.join(directory, source.package_names.last))
      metadata = YAML.safe_load(chart.fetch("reportportal-rich-experience/Chart.yaml").fetch(:content))
      unless metadata.fetch("version") == source.version && metadata.fetch("appVersion") == Source::APP_VERSION && metadata.fetch("name") == "reportportal-rich-experience"
        raise Error, "Built chart identity mismatch"
      end
      unless chart.key?("reportportal-rich-experience/charts/reportportal/Chart.yaml")
        raise Error, "Packaged chart must include its built ReportPortal dependency"
      end
      true
    end

    def digest(name)
      Digest::SHA256.file(File.join(directory, name)).hexdigest
    end

    private

    def chart_entries(path)
      entries = {}
      Zlib::GzipReader.open(path) do |gzip|
        Gem::Package::TarReader.new(gzip) do |tar|
          tar.each do |entry|
            name = entry.full_name
            unless name.start_with?("reportportal-rich-experience/") && !name.split("/").include?("..") && (entry.file? || entry.directory?) && !entries.key?(name)
              raise Error, "Unsafe or duplicate chart archive entry: #{name}"
            end
            entries[name] = { content: entry.read, mode: entry.header.mode, directory: entry.directory? }
          end
        end
      end
      entries
    end

    def canonical_chart(input, output, epoch)
      previous = ENV["SOURCE_DATE_EPOCH"]
      entries = chart_entries(input)
      ENV["SOURCE_DATE_EPOCH"] = epoch.to_s
      # Helm embeds wall-clock timestamps. Canonical tar/gzip headers make retries byte-identical.
      tar = StringIO.new("".b)
      Gem::Package::TarWriter.new(tar) do |writer|
        entries.sort.each do |name, entry|
          if entry.fetch(:directory)
            writer.mkdir(name, entry.fetch(:mode))
          else
            data = entry.fetch(:content)
            writer.add_file_simple(name, entry.fetch(:mode), data.bytesize) { |io| io.write(data) }
          end
        end
      end
      Zlib::GzipWriter.open(output) do |gzip|
        gzip.mtime = epoch
        gzip.write(tar.string)
      end
    ensure
      ENV["SOURCE_DATE_EPOCH"] = previous
    end
  end

  class Publisher
    def initialize(source, directory, repository:, commands: source.commands)
      raise Error, "Expected OWNER/REPO repository" unless repository.match?(%r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z})

      @source, @bundle, @repository, @commands = source, Bundle.new(source, directory), repository, commands
    end

    def publish!
      @source.verify_commit!
      @bundle.verify!
      release = read_release
      unless release
        gh("release", "create", @source.tag, "--verify-tag", "--draft", "--target", @source.commit,
           "--title", "SDK and Helm #{@source.version}", "--notes-file", notes_path)
        release = read_release
      end
      validate_release!(release)
      names = release.fetch("assets").map { |asset| asset.fetch("name") }
      raise Error, "Unexpected or duplicate remote release assets" unless (names - @source.asset_names).empty? && names.uniq == names
      raise Error, "Published release is incomplete; refusing to modify it" if !release.fetch("draft") && names.sort != @source.asset_names.sort

      verify_remote!(names)
      unless release.fetch("draft")
        puts "Release #{@source.tag} is already published and verified; no changes made."
        return
      end

      (@source.asset_names - names).each do |name|
        gh("release", "upload", @source.tag, File.join(@bundle.directory, name))
      end
      completed = read_release
      validate_release!(completed)
      uploaded = completed.fetch("assets").map { |asset| asset.fetch("name") }
      raise Error, "Draft asset set mismatch" unless completed.fetch("draft") && uploaded.sort == @source.asset_names.sort

      verify_remote!(uploaded)
      gh("release", "edit", @source.tag, "--draft=false", "--title", "SDK and Helm #{@source.version}", "--notes-file", notes_path)
      puts "Published verified GitHub release #{@source.tag}. RubyGems was not modified."
    end

    private

    def notes_path
      File.join(@bundle.directory, "release-notes.md")
    end

    def gh(*arguments)
      @commands.run("gh", *arguments, "--repo", @repository)
    end

    def read_release
      out = @commands.run("gh", "api", "repos/#{@repository}/releases/tags/#{@source.tag}", allow_missing: true)
      return JSON.parse(out) if out

      # The by-tag endpoint can hide drafts; authenticated listing exposes them.
      listing = @commands.run("gh", "api", "repos/#{@repository}/releases?per_page=100",
                              "--paginate", "--slurp")
      pages = JSON.parse(listing)
      raise Error, "Unexpected remote release listing" unless pages.is_a?(Array) && pages.all? { |page| page.is_a?(Array) }

      releases = pages.flatten(1)
      raise Error, "Unexpected remote release records" unless releases.all? { |release| release.is_a?(Hash) && release["tag_name"].is_a?(String) }

      matches = releases.select { |release| release["tag_name"] == @source.tag }
      raise Error, "Ambiguous remote release drafts for this tag" if matches.length > 1

      matches.first
    end

    def validate_release!(release)
      unless release && release.fetch("tag_name") == @source.tag && release.fetch("target_commitish") == @source.commit
        raise Error, "Remote release does not match the expected tag and commit"
      end
      unless release.fetch("assets").all? { |asset| asset.fetch("state") == "uploaded" }
        raise Error, "Remote release contains an incomplete asset; refusing to overwrite it"
      end
    end

    def verify_remote!(names)
      Dir.mktmpdir("release-download-") do |scratch|
        names.each do |name|
          gh("release", "download", @source.tag, "--pattern", name, "--dir", scratch)
          downloaded = File.join(scratch, name)
          unless File.file?(downloaded) && !File.symlink?(downloaded) && Digest::SHA256.file(downloaded).hexdigest == @bundle.digest(name)
            raise Error, "Remote asset differs: #{name}; refusing to overwrite or publish"
          end
        end
      end
    end
  end
end
