# frozen_string_literal: true

require "json"
require "digest"
require "find"
require "open3"
require "set"
require "time"
require_relative "final_wp5_context"

module LedgerQAPublication
  class Curator
    LIMIT = 100 * 1024 * 1024
    WARNING = 50 * 1024 * 1024
    ARTIFACTS = %w[.json .ndjson .log .png .jpg .jpeg .txt].freeze
    CACHES = %w[.git .bundle .cache docker-config vendor cache caches node_modules].freeze
    REFERENCES = %w[source sources path paths inputs captured_source fixture_capture required_source
      source_snapshot source_jpg source_capture png new_evidence original_blocked_history
      candidate_runtime_binding plain_ndjson rich_ndjson html_files].freeze
    BROWSER_ASSETS = %w[source_snapshot source_jpg png saved_path download_path local_path].freeze
    COMPANIONS = %w[provenance.json source-provenance.json source-freeze.json runtime.json
      source-guard.json probe.json summary.json result.json local-storage-proof.json].freeze
    GUIDE = "docs/reviews/2026-11-01-ledger-qa-reproduction.md"

    attr_reader :root, :version, :output
    attr_accessor :peers

    def initialize(root:, version:, stamp:, revision:, perf_stamp: "#{stamp}-quiet", tracked_files: nil)
      [stamp, revision, perf_stamp].each do |name|
        raise "Invalid selection name: #{name.inspect}" unless name.match?(/\A[a-z0-9-]+\z/)
      end
      @root, @version = File.expand_path(root), version
      @real_root = File.realpath(@root)
      @stamp, @revision, @perf_stamp = stamp, revision, perf_stamp
      @assets = File.join(@root, "docs/reviews/assets")
      @output = File.join(@assets, stamp, "curated-manifest-#{revision}.json")
      @files, @trees, @scanned, @references = Set.new, Set.new, Set.new, Set.new
      @queue, @provenance, @archive_entries, @archives, @used_archives = [], {}, {}, {}, Set.new
      @cross_root, @opaque, @missing_roots = Set.new, Set.new, Set.new
      @excluded, @fingerprints, @scan_fingerprints, @peers = Hash.new(0), {}, {}, []
      if tracked_files
        @tracked = tracked_files.to_set
      else
        paths, status = Open3.capture2("git", "-C", @root, "ls-files", "-z")
        raise "Cannot determine tracked archive coverage" unless status.success?
        @tracked = paths.split("\0").to_set
      end
    end

    def relative(path)
      path.delete_prefix(@root + "/")
    end

    def checked_path(path)
      raise "Parent traversal is not an evidence path: #{path}" if path.split("/").include?("..")
      absolute = File.expand_path(path, @root)
      raise "Evidence escaped QA root: #{path}" unless absolute.start_with?(@root + "/")
      name = relative(absolute)
      raise "Evidence escaped QA scope: #{name}" unless name.match?(%r{\A(?:spec/|features/|docs/reviews/)})
      cursor = @root
      name.split("/").each do |part|
        cursor = File.join(cursor, part)
        raise "Symlink in evidence path: #{name}" if File.symlink?(cursor)
      end
      if File.exist?(absolute) && !File.realpath(absolute).start_with?(@real_root + "/")
        raise "Realpath escaped QA root: #{name}"
      end
      absolute
    end

    def excluded_reason(path, explicit: false)
      parts = relative(path).split("/")
      return "cache-or-config" unless (parts & CACHES).empty?
      return "source-clone" if parts.include?("pre-wp1-source")
      return nil if relative(path).match?(%r{\Adocs/reviews/assets/(?:wp5-[^/]+/matrix|ledger-qa-runs/[^/]+)/M[1-6]/source/Gemfile(?:\.lock)?\z})
      parts.each_index do |i|
        return "source-clone" if parts[i] == "source" && parts[i, 5] != %w[source docs reviews assets qa-cell-evidence]
      end
      return "repeated-media" if !explicit && parts.include?("media")
      return "package-or-archive" if path.match?(/\.(?:gem|tgz|tar|tar\.gz|tar\.xz|zip|gz|xz)\z/i)
      return "native-html-template" if File.extname(path).downcase == ".html"
      return "manifest-self" if File.basename(path).start_with?("curated-manifest-")
      return "metadata" if File.basename(path).start_with?("._") || File.basename(path) == ".DS_Store"
      nil
    end

    def check_size(bytes, path)
      raise "100 MiB publication gate: #{relative(path)} (#{bytes} bytes)" if bytes >= LIMIT
    end

    def fingerprint(path)
      path = checked_path(path)
      before = File.stat(path)
      check_size(before.size, path)
      signature = ->(stat) { [stat.dev, stat.ino, stat.mode, stat.size, stat.mtime, stat.ctime] }
      cached = @fingerprints[path]
      return cached[:entry] if cached && cached[:stat] == signature.call(before)
      sha = Digest::SHA256.file(path).hexdigest
      after = File.stat(checked_path(path))
      raise "Evidence changed while hashing: #{relative(path)}" unless signature.call(before) == signature.call(after)
      entry = { path: relative(path), bytes: before.size, sha256: sha }
      @fingerprints[path] = { stat: signature.call(after), entry: entry }
      entry
    end

    def add_file(path, explicit: false, code: false)
      path = checked_path(path)
      if (reason = excluded_reason(path, explicit: explicit))
        @excluded[reason] += 1
        return
      end
      return unless File.file?(path)
      return unless code || ARTIFACTS.include?(File.extname(path).downcase)
      check_size(File.size(path), path)
      if @files.add?(path) && %w[.json .ndjson .md].include?(File.extname(path))
        @queue << path
      end
    end

    def add_tree(directory)
      directory = checked_path(directory)
      return unless File.directory?(directory) && @trees.add?(directory)
      Find.find(directory) do |path|
        if (reason = excluded_reason(path))
          @excluded[reason] += 1
          Find.prune if File.directory?(path)
          next
        end
        checked_path(path)
        add_file(path) if File.file?(path)
      end
    end

    def read_json(path)
      path = checked_path(path)
      check_size(File.size(path), path)
      JSON.parse(File.read(path))
    end

    def load_archive_coverage
      pattern = %r{\Adocs/reviews/assets/presentation-ledger-#{Regexp.escape(@version)}-(?:live|checks|matrix)-raw\.manifest\.json\z}
      @tracked.grep(pattern).sort.each do |index|
        manifest = read_json(index)
        archive = manifest.fetch("archive")
        archive_path = checked_path(archive.fetch("path"))
        next unless @tracked.include?(relative(archive_path)) && File.file?(archive_path)
        actual = fingerprint(archive_path)
        raise "Tracked archive fingerprint differs: #{index}" unless actual[:bytes] == archive.fetch("bytes") && actual[:sha256] == archive.fetch("sha256")
        @archives[index] = { index: fingerprint(File.join(@root, index)), archive: actual }
        manifest.fetch("entries").each do |entry|
          name = relative(checked_path(entry.fetch("path")))
          @archive_entries[name] = entry.merge("index" => index)
        end
      end
    end

    def prepare
      load_archive_coverage
      Dir[File.join(@assets, "ledger-qa-live/#{@stamp}-*")].sort.each { |path| add_tree(path) }
      [@stamp, @perf_stamp].uniq.each do |stamp|
        directory = checked_path(File.join(@assets, stamp))
        @missing_roots << relative(directory) unless File.directory?(directory)
        add_tree(directory)
        Dir[File.join(directory, "matrix/*/source/docs/reviews/assets/qa-cell-evidence")].sort.each { |path| add_tree(path) }
        Dir[File.join(directory, "matrix/*/source/{Gemfile,Gemfile.lock}")].sort.each { |path| add_file(path, code: true) }
      end
      Dir[File.join(@root, "spec/acceptance/ledger_qa/*")].sort.each { |path| add_file(path, code: true) }
      Dir[File.join(@root, "features/presentation_ledger/**/*")].sort.each do |path|
        add_file(path, code: true) if path.end_with?(".feature", ".rb")
      end
      Dir[File.join(@assets, "presentation-ledger-#{@version}/S??-#{@stamp}-*.png")].sort.each { |path| add_file(path) }
      add_file(File.join(@root, "docs/reviews/2026-11-01-presentation-ledger-#{@version}-acceptance.md"), code: true)
      add_file(File.join(@assets, "presentation-ledger-#{@version}-acceptance.json"))
      guide = File.join(@root, GUIDE)
      add_file(guide, code: true) if File.file?(guide)
      %w[spec-repair-ruby31-focused.json spec-repair-ruby31-focused.provenance.json g10-spy-diagnosis.json owner-decision15.json].each do |name|
        add_file(File.join(@assets, "wp5-final-20261101", name))
      end
      if @version == "1.3.2"
        old = File.join(@assets, "wp5-final-20261101-localcache/matrix/M2/source/docs/reviews/assets/qa-cell-evidence")
        %w[rspec.json wp5-focused-cache.json wp5-focused-spy-observed.json wp5-spy-errors.ndjson wp5-cache-probe.json].each { |name| add_file(File.join(old, name)) }
      end
      self
    end

    def note(reference, origin, reason)
      @provenance[[reference, reason]] ||= { path: reference, found_in: origin, reason: reason, downloadable_evidence: false }
    end

    def reference(value, origin, missing_allowed: false, browser_asset: false)
      return if value.include?("\n") || value.include?("\0") || value.length > 4096
      prefixes = [@root, "/Users/nick/Documents/crr-qa-#{@version}"]
      prefix = prefixes.find { |candidate| value.start_with?(candidate + "/") }
      name = prefix ? value.delete_prefix(prefix + "/") : value.delete_prefix("./")
      if name.match?(%r{\A(?:docs/design/|spec/|features/|script/|lib/|helm/|Gemfile(?:\.lock)?\z)})
        raise "Browser asset is not a QA observation: #{value}" if browser_asset
        note(name, origin, "Pinned Git source, not an evidence duplicate; use the recorded source SHA")
        return
      end
      unless name.start_with?("docs/reviews/")
        @peers.each do |peer|
          next unless [peer.root, "/Users/nick/Documents/crr-qa-#{peer.version}"].any? { |p| value.start_with?(p + "/") }
          @cross_root << { path: value, qa_version: peer.version, found_in: origin }
          peer.reference(value, "#{@version}:#{origin}", missing_allowed: missing_allowed, browser_asset: browser_asset)
          return
        end
        raise "Browser asset escaped both QA roots: #{value} (#{origin})" if browser_asset
        note(value, origin, "Recorded execution/source location, not a downloadable QA asset; see reproduction guide") if value.start_with?("/Users/", "/private/tmp/", "/qa/")
        return
      end
      return unless @references.add?([name, missing_allowed, browser_asset])
      path = checked_path(name)
      if (entry = @archive_entries[name]) && (!File.file?(path) || fingerprint(path)[:sha256] == entry.fetch("sha256"))
        @used_archives << entry.fetch("index")
        scan(path) if File.file?(path)
        return
      end
      if (reason = excluded_reason(path, explicit: true))
        note(name, origin, "#{reason}: provenance only; not selected; see reproduction guide")
        if reason == "native-html-template"
          reference(name.sub(/\.html\z/, ".ndjson").sub("native-postprocessed.ndjson", "native.ndjson"), origin, missing_allowed: missing_allowed)
        elsif reason == "source-clone" || reason == "package-or-archive"
          add_companions(File.dirname(path))
        end
        return
      end
      if File.directory?(path)
        add_tree(path)
      elsif File.file?(path)
        if name.start_with?("docs/reviews/")
          if ARTIFACTS.include?(File.extname(path).downcase) || File.extname(path) == ".md"
            add_file(path, explicit: true, code: File.extname(path) == ".md")
          else
            note(name, origin, "Non-observation source/format: provenance only; retained wire/snapshot records carry raw inputs")
          end
          add_companions(File.dirname(path))
        else
          note(name, origin, "Pinned Git source, not an evidence duplicate; use the recorded source SHA")
        end
      elsif missing_allowed
        note(name, origin, "Planned or explicitly BLOCKED/missing-proof source; no downloadable observation exists")
      else
        raise "Unresolved evidence reference: #{name} (#{origin})"
      end
    end

    def add_companions(directory)
      if relative(directory).match?(%r{\Adocs/reviews/assets/(?:ledger-qa-(?:live|runs|performance)/|wp5-)}) && !excluded_reason(directory, explicit: true)
        add_tree(directory)
      end
      while directory.start_with?(@assets + "/")
        COMPANIONS.each { |name| add_file(File.join(directory, name)) }
        cell = File.join(directory, "source/docs/reviews/assets/qa-cell-evidence")
        add_tree(cell) if File.directory?(cell)
        %w[Gemfile Gemfile.lock].each do |name|
          dependency = File.join(directory, "source", name)
          add_file(dependency, code: true) if File.file?(dependency) && !excluded_reason(dependency)
        end
        directory = File.dirname(directory)
      end
    end

    def walk(value, origin, reference_key: false, missing_allowed: false, owner: @version, browser_asset: false)
      case value
      when Hash
        owner = value["line"] if %w[2.0.1 1.3.2].include?(value["line"])
        missing_allowed ||= value["verdict"].to_s.match?(/\A(?:BLOCKED|PENDING)/)
        value.each do |key, child|
          key_is_path = REFERENCES.include?(key) || key.match?(/_(?:path|file|source|snapshot|jpg|png|ndjson|html|files|paths)\z/)
          walk(child, origin, reference_key: key_is_path, missing_allowed: missing_allowed || %w[required_source planned_path].include?(key),
            owner: owner, browser_asset: BROWSER_ASSETS.include?(key))
        end
      when Array
        value.each { |child| walk(child, origin, reference_key: reference_key, missing_allowed: missing_allowed, owner: owner, browser_asset: browser_asset) }
      when String
        return unless reference_key
        peer = @peers.find { |candidate| candidate.version == owner } if owner != @version
        if peer && value.delete_prefix("./").start_with?("docs/reviews/")
          @cross_root << { path: value, qa_version: owner, found_in: origin }
          peer.reference(value, "#{@version}:#{origin}", missing_allowed: missing_allowed, browser_asset: browser_asset)
        else
          reference(value, origin, missing_allowed: missing_allowed, browser_asset: browser_asset)
        end
      end
    end

    def scan(path)
      return unless %w[.json .ndjson .md].include?(File.extname(path)) && @scanned.add?(path)
      return if relative(path).match?(%r{-raw\.manifest\.json\z})
      path = checked_path(path)
      check_size(File.size(path), path)
      @scan_fingerprints[path] = fingerprint(path)
      if path.end_with?(".md")
        File.read(path).scan(/\]\(([^)]+)\)/).flatten.each do |link|
          next if link.match?(%r{\A(?:https?://|#)})
          reference(File.expand_path(link.split("#").first, File.dirname(path)), relative(path))
        end
      elsif path.end_with?(".ndjson")
        File.foreach(path) { |line| walk(JSON.parse(line), relative(path)) unless line.strip.empty? }
      else
        walk(read_json(path), relative(path))
      end
    rescue JSON::ParserError
      # Some downloaded fixtures intentionally are opaque/non-JSON bytes.
      raise if File.basename(path).match?(/(?:acceptance|checks|screenshots|snapshot)\.json\z/)
      @opaque << relative(path)
    end

    def pending?
      !@queue.empty?
    end

    def close_references
      scan(@queue.shift) until @queue.empty?
    end

    def manifest
      raise "Reference closure is unfinished" if pending?
      entries = @files.sort.map { |path| fingerprint(path) }
      @scan_fingerprints.each do |path, scanned|
        raise "Evidence changed after reference scan: #{relative(path)}" unless fingerprint(path) == scanned
      end
      { schema: "curated-qa-review-selection/1", version: @version, stamp: @stamp, revision: @revision,
        performance_stamp: @perf_stamp, prepared_at_utc: Time.now.utc.iso8601,
        staging_performed: false, commit_or_push_performed: false,
        status: "DRAFT_SELECTION_NOT_SECRET_AUDIT_OR_STAGING_AUTHORIZATION", file_count: entries.length,
        bytes: entries.sum { |entry| entry[:bytes] }, excluded_counts: @excluded,
        exclusions: "Source clones, caches/config, packages/tars and generated duplicate native HTML remain local. Exact referenced browser originals/downloads are included. No raw file or check object is rewritten or deleted.",
        provenance_only_paths: @provenance.values.sort_by { |entry| [entry[:path], entry[:reason]] },
        tracked_archive_coverage: @used_archives.sort.map { |index| @archives.fetch(index) },
        cross_qa_root_references: @cross_root.to_a.sort_by { |entry| entry[:path] },
        missing_selection_roots: @missing_roots.to_a.sort, opaque_observation_files: @opaque.to_a.sort,
        size_warning_bytes: WARNING, hard_limit_bytes: LIMIT,
        size_warnings: entries.select { |entry| entry[:bytes] >= WARNING },
        reproduction_guide: { qa_version: File.file?(File.join(@root, GUIDE)) ? @version : "2.0.1", path: GUIDE },
        secret_audit_required: "Master must audit this exact selection and tracked archive dependencies before staging/commit. Fingerprints are not a credential audit or publication authorization.",
        entries: entries }
    end

    def output_payload(manifest)
      path = checked_path(@output)
      raise "Never replace an earlier manifest: #{path}" if File.exist?(path)
      payload = JSON.pretty_generate(manifest) + "\n"
      check_size(payload.bytesize, path)
      payload
    end

    def write_manifest(payload)
      path = checked_path(@output)
      check_size(payload.bytesize, path)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(payload) }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  abort "Use --check for a read-only selection check, or no arguments for a fresh manifest" unless ARGV.empty? || ARGV == ["--check"]
  stamp = LedgerWP5Context.stamp
  revision = ENV.fetch("QA_MANIFEST_REVISION", "preliminary-1")
  curators = %w[2.0.1 1.3.2].map do |version|
    LedgerQAPublication::Curator.new(root: ENV.fetch("QA_CURATE_ROOT_#{version.tr('.', '_')}", "/Users/nick/Documents/crr-qa-#{version}"),
      version: version, stamp: stamp, revision: revision, perf_stamp: ENV.fetch("QA_WP5_PERF_STAMP", "#{stamp}-quiet"))
  end
  curators.each { |curator| curator.peers = curators.reject { |peer| peer == curator } }
  curators.each(&:prepare)
  curators.each(&:close_references) while curators.any?(&:pending?)
  manifests = curators.map(&:manifest)
  payloads = curators.zip(manifests).map { |curator, manifest| curator.output_payload(manifest) } unless ARGV == ["--check"]
  curators.each_with_index do |curator, index|
    manifest = manifests[index]
    curator.write_manifest(payloads[index]) if payloads
    puts JSON.generate(version: curator.version, files: manifest[:file_count], bytes: manifest[:bytes],
      provenance_only: manifest[:provenance_only_paths].length, archive_dependencies: manifest[:tracked_archive_coverage].length,
      missing_selection_roots: manifest[:missing_selection_roots], size_warnings: manifest[:size_warnings],
      largest_file: manifest[:entries].max_by { |entry| entry[:bytes] }, manifest_written: !payloads.nil?, manifest: payloads ? curator.output : nil)
  end
end
