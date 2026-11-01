# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "final_wp5_curate"

# Standalone synthetic fixtures only: no product suites, Docker, browser or live evidence.
module LedgerCuratorTest
  STAMP = "wp5-ci-final-20261101"
  ASSETS = "docs/reviews/assets"
  Curator = LedgerQAPublication::Curator
  @assertions = 0

  def self.assert(value, message)
    @assertions += 1
    raise message unless value
  end

  def self.rejects(pattern)
    begin
      yield
    rescue RuntimeError => error
      assert(error.message.match?(pattern), "Unexpected rejection: #{error.message}")
      return
    end
    raise "Expected rejection: #{pattern}"
  end

  def self.put(root, name, value = {})
    path = File.join(root, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, value.is_a?(String) ? value : JSON.generate(value))
    path
  end

  def self.base(root, version = "2.0.1")
    FileUtils.mkdir_p(File.join(root, ASSETS, STAMP))
    FileUtils.mkdir_p(File.join(root, ASSETS, "#{STAMP}-quiet"))
    put(root, "#{ASSETS}/presentation-ledger-#{version}-acceptance.json", { "checks" => [], "criteria" => [] })
    put(root, "docs/reviews/2026-11-01-presentation-ledger-#{version}-acceptance.md", "# Synthetic report\n")
  end

  def self.curator(root, **options)
    Curator.new(root: root, version: "2.0.1", stamp: STAMP, revision: "synthetic-1", tracked_files: [], **options)
  end

  def self.build(subject)
    subject.prepare
    subject.close_references
    subject.manifest
  end

  def self.names(manifest)
    manifest.fetch(:entries).map { |entry| entry.fetch(:path) }
  end

  def self.quiet_root(root)
    selected = "#{ASSETS}/exact-owner-performance/probes/c12.0.1/micro-rich/presentation-timings.json"
    ignored = "#{ASSETS}/#{STAMP}-quiet/not-the-scorer-root.json"
    put(root, selected)
    put(root, ignored)
    result = build(curator(root, perf_stamp: "exact-owner-performance"))
    assert(names(result).include?(selected), "Exact scorer-resolved performance root omitted")
    assert(!names(result).include?(ignored), "Unselected performance attempt leaked into selection")
    assert(result[:performance_stamp] == "exact-owner-performance", "Performance stamp not recorded")
  end

  def self.history_and_browser(root)
    leaf = "#{ASSETS}/ledger-qa-live/wp5-final-20261101-plain/F04"
    %w[snapshot.json wire.json runtime.json downloads/visible-fixture.json].each { |name| put(root, "#{leaf}/#{name}") }
    %w[downloads/visible-fixture.png downloads/visible-fixture.txt].each { |name| put(root, "#{leaf}/#{name}", "exact bytes") }
    put(root, "#{File.dirname(leaf)}/provenance.json")
    put(root, "#{leaf}/native.ndjson", "{\"message\":\"native bytes retained\"}\n")
    put(root, "#{leaf}/native.html", "duplicate native template")
    put(root, "#{leaf}/vendor/not-selected.json")
    put(root, "#{leaf}/media/not-referenced.jpg", "repeated media")
    jpg = "#{ASSETS}/presentation-ledger-2.0.1/original-browser-capture.jpg"
    txt = "#{ASSETS}/presentation-ledger-2.0.1/downloads/visible-fixture.txt"
    put(root, jpg, "browser original bytes")
    put(root, txt, "browser download bytes")
    cell = "#{ASSETS}/wp5-final-20261101-localcache/matrix/M2"
    put(root, "#{cell}/result.json")
    put(root, "#{cell}/source/docs/reviews/assets/qa-cell-evidence/rspec.json")
    put(root, "#{cell}/source/Gemfile", "source 'https://rubygems.org'\n")
    put(root, "#{cell}/source/Gemfile.lock", "exact synthetic dependency lock\n")
    put(root, "#{cell}/source/lib/not-selected.rb", "source clone")
    package = "#{ASSETS}/qa-package/source/archive.gem"
    put(root, package, "not an evidence input")
    data = { "checks" => [{ "check_id" => "Q00001", "evidence" => { "source" => "#{leaf}/snapshot.json" } },
      { "check_id" => "WP5-00001", "evidence" => { "source" => "#{cell}/result.json" },
        "inputs" => { "source_jpg" => jpg, "saved_path" => txt, "html_files" => ["#{leaf}/native.html"], "source" => package } }],
      "criteria" => [{ "check_ids" => %w[Q00001 WP5-00001] }] }
    report = put(root, "#{ASSETS}/presentation-ledger-2.0.1-acceptance.json", data)
    before = File.binread(report)
    result = build(curator(root))
    chosen = names(result)
    %W[#{leaf}/snapshot.json #{leaf}/wire.json #{leaf}/runtime.json #{leaf}/native.ndjson
      #{leaf}/downloads/visible-fixture.json #{leaf}/downloads/visible-fixture.png
      #{leaf}/downloads/visible-fixture.txt #{File.dirname(leaf)}/provenance.json #{jpg} #{txt}
      #{cell}/source/docs/reviews/assets/qa-cell-evidence/rspec.json].each do |name|
      assert(chosen.include?(name), "Missing observation companion: #{name}")
    end
    assert(chosen.none? { |name| name.end_with?(".html", ".gem") || %w[/vendor/ /source/lib/ /media/].any? { |part| name.include?(part) } }, "Excluded duplicate selected")
    assert(result[:provenance_only_paths].any? { |entry| entry[:path] == "#{leaf}/native.html" }, "Excluded HTML lacks provenance explanation")
    assert(chosen.include?("#{cell}/source/Gemfile.lock"), "Exact dependency input was replaced by an unpinned bootstrap")
    assert(File.binread(report) == before && JSON.parse(before) == data, "Raw check objects were changed")
  end

  def self.archives(root)
    index = "#{ASSETS}/presentation-ledger-2.0.1-live-raw.manifest.json"
    archive = "#{ASSETS}/presentation-ledger-2.0.1-live-raw.tar.xz"
    archived = "#{ASSETS}/ledger-qa-live/historical/F04/snapshot.json"
    path = put(root, archive, "synthetic archive bytes; decompression is not part of this test")
    put(root, index, { "archive" => { "path" => archive, "bytes" => File.size(path), "sha256" => Digest::SHA256.file(path).hexdigest },
      "entries" => [{ "path" => archived, "bytes" => 2, "sha256" => Digest::SHA256.hexdigest("{}") }] })
    put(root, "#{ASSETS}/presentation-ledger-2.0.1-acceptance.json", { "checks" => [{ "evidence" => { "source" => archived } }] })
    subject = Curator.new(root: root, version: "2.0.1", stamp: STAMP, revision: "synthetic-1", tracked_files: [index, archive])
    result = build(subject)
    assert(result[:tracked_archive_coverage].length == 1, "Tracked archive coverage not recognized")
    assert(!names(result).include?(archived) && !names(result).include?(archive), "Archived raw or tar redundantly selected")
    put(root, archive, "tampered archive")
    rejects(/archive fingerprint differs/) do
      build(Curator.new(root: root, version: "2.0.1", stamp: STAMP, revision: "synthetic-1", tracked_files: [index, archive]))
    end
  end

  def self.escapes_and_size(root)
    subject = curator(root)
    symlink_target = File.join(File.dirname(root), "outside.json")
    File.binwrite(symlink_target, "{}")
    link = File.join(root, ASSETS, STAMP, "escape.json")
    File.symlink(symlink_target, link)
    rejects(/Symlink/) { subject.prepare }
    File.unlink(link)
    dir = File.join(root, ASSETS, STAMP, "escape-directory")
    File.symlink(File.dirname(root), dir)
    rejects(/Symlink/) { curator(root).checked_path(File.join(dir, "outside.json")) }
    File.unlink(dir)
    # A QA-local TMPDIR can put the sibling under a supported canonical alias.
    outside = "/__ledger_curator_outside_aliases__/outside.json"
    rejects(/escaped QA root/) { subject.checked_path(outside) }
    rejects(/Browser asset escaped both QA roots/) { subject.reference(outside, "synthetic browser record", browser_asset: true) }
    rejects(/Parent traversal/) { subject.checked_path("#{ASSETS}/../../escape.json") }
    rejects(/Invalid selection name/) { curator(root, perf_stamp: "../outside") }
    subject.check_size(Curator::WARNING, File.join(root, ASSETS, "warning-only.json"))
    subject.check_size(Curator::LIMIT - 1, File.join(root, ASSETS, "small.json"))
    huge = put(root, "#{ASSETS}/#{STAMP}/oversized.log", "")
    File.open(huge, "r+") { |file| file.truncate(Curator::LIMIT) }
    rejects(/100 MiB publication gate/) { curator(root).prepare }
    File.unlink(huge)
    result = build(subject = curator(root))
    put(root, "#{ASSETS}/#{STAMP}/curated-manifest-synthetic-1.json", "immutable")
    rejects(/Never replace/) { subject.output_payload(result) }
  end

  def self.canonical_relocation(root)
    snapshot = "#{ASSETS}/ledger-qa-live/synthetic-relocation-only/F04/snapshot.json"
    payload = { "proof" => "canonical reference resolves in the synthetic checkout" }
    put(root, snapshot, payload)
    canonical = "/Users/nick/Documents/crr-qa-2.0.1/#{snapshot}"
    put(root, "#{ASSETS}/presentation-ledger-2.0.1-acceptance.json", { "source_snapshot" => canonical })
    result = build(curator(root))
    entry = result.fetch(:entries).find { |candidate| candidate[:path] == snapshot }
    assert(entry, "Canonical QA reference was not relocated into the synthetic checkout")
    assert(entry[:sha256] == Digest::SHA256.hexdigest(JSON.generate(payload)), "Canonical relocation selected bytes outside the synthetic checkout")
  end

  def self.missing_and_cross_root(root)
    missing = "#{ASSETS}/uncaptured/required.json"
    report = "#{ASSETS}/presentation-ledger-2.0.1-acceptance.json"
    put(root, report, { "checks" => [{ "verdict" => "BLOCKED", "evidence" => { "source" => missing } }] })
    result = build(curator(root))
    assert(result[:provenance_only_paths].any? { |entry| entry[:path] == missing }, "Missing-proof state was erased")
    put(root, report, { "checks" => [{ "verdict" => "PASS", "evidence" => { "source" => missing } }] })
    rejects(/Unresolved evidence reference/) { build(curator(root)) }
    peer_root = File.join(File.dirname(root), "legacy")
    base(peer_root, "1.3.2")
    jpg = "#{ASSETS}/presentation-ledger-2.0.1/cross-root.jpg"
    put(root, jpg, "central browser original")
    put(root, report)
    legacy_snapshot = "#{ASSETS}/ledger-qa-live/legacy-only/F04/snapshot.json"
    put(peer_root, legacy_snapshot)
    put(root, "#{ASSETS}/#{STAMP}/ui-captures.ndjson", JSON.generate(line: "1.3.2", source_snapshot: legacy_snapshot) + "\n")
    put(peer_root, "#{ASSETS}/presentation-ledger-1.3.2-acceptance.json", { "source_jpg" => File.join(root, jpg) })
    central = curator(root)
    legacy = Curator.new(root: peer_root, version: "1.3.2", stamp: STAMP, revision: "synthetic-1", tracked_files: [])
    central.peers, legacy.peers = [legacy], [central]
    [central, legacy].each(&:prepare)
    [central, legacy].each(&:close_references) while [central, legacy].any?(&:pending?)
    assert(names(central.manifest).include?(jpg), "Cross-QA browser original was not routed to its owning selection")
    assert(names(legacy.manifest).include?(legacy_snapshot), "Central log's legacy-relative snapshot was routed into QA2x")
    assert(legacy.manifest[:cross_qa_root_references].length == 1, "Cross-QA dependency not recorded")
  end

  def self.stable_inputs(root)
    subject = curator(root).prepare
    subject.close_references
    put(root, "#{ASSETS}/presentation-ledger-2.0.1-acceptance.json", { "checks" => [], "changed_after_scan" => true })
    rejects(/Evidence changed after reference scan/) { subject.manifest }
  end

  def self.run
    %i[quiet_root history_and_browser archives escapes_and_size canonical_relocation missing_and_cross_root stable_inputs].each do |test|
      Dir.mktmpdir("ledger-curator-test-") do |workspace|
        root = File.join(workspace, "qa")
        base(root)
        public_send(test, root)
      end
      puts "PASS #{test}"
    end
    puts "#{@assertions} assertions; synthetic fixtures only"
  end
end

LedgerCuratorTest.run if $PROGRAM_NAME == __FILE__
