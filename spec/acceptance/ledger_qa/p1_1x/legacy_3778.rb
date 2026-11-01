# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "cgi"
require "fileutils"

module P1Legacy3778
  ROOT = File.expand_path("../../../..", __dir__)
  BASE_SHA = "4ca2f770e0a84e83688f165ba04b4db8ef855cf9"
  SAVED = "docs/reviews/assets/ledger-qa-live/wp5-ci-final-20261101-c10.2.0-baseline/F14-negative"
  INPUTS = "docs/reviews/assets/1x-p1-20261101/launch-3778-inputs.json"

  def self.prepare
    files = %w[snapshot.json runtime.json source-guard.json fixture.json native.ndjson wire.json].to_h do |name|
      relative = "#{SAVED}/#{name}"
      data, status = Open3.capture2("git", "-C", ROOT, "show", "HEAD:#{relative}")
      sha = Digest::SHA256.file(File.join(ROOT, relative)).hexdigest
      raise "Saved observation differs from committed bytes" unless status.success? && Digest::SHA256.hexdigest(data.b) == sha
      [name, { path: relative, sha256: sha }]
    end
    read = ->(name) { JSON.parse(File.read(File.join(ROOT, SAVED, name))) }
    runtime = read.call("runtime.json")
    source = File.dirname(runtime.fetch("activation").fetch("sdk_gemspec"))
    hashes = runtime.fetch("loaded_sdk_sha256_at_start")
    hashes.each do |path, sha|
      relative = path.delete_prefix(source + "/")
      data, status = Open3.capture2("git", "-C", ROOT, "show", "#{BASE_SHA}:#{relative}")
      raise "v1.3.1 source binding failed" unless status.success? && Digest::SHA256.hexdigest(data.b) == sha
    end
    snapshot = read.call("snapshot.json")
    raise "Wrong saved GET Launch" unless snapshot.fetch("persistence") == "live_readback" &&
      snapshot.fetch("launches").map { |l| l.fetch("id") } == [3778] &&
      runtime.fetch("sdk_version") == "1.3.1" && read.call("source-guard.json").fetch("passed")
    exceptions = File.readlines(File.join(ROOT, SAVED, "native.ndjson")).map { |line| JSON.parse(line) }
      .map { |event| event.dig("testStepFinished", "testStepResult", "exception") }.compact
    rows = error_logs(snapshot).map do |index, log|
      exception = exceptions.fetch(index)
      message = exception.fetch("message")
      raise "Unexpected F14 exception class" unless exception.fetch("type") == "RuntimeError"
      raw = log.fetch("message")
      raise "Cannot prove message/frame split" unless raw.start_with?(message + "\n")
      { index: index, class: "RuntimeError", message: message,
        frames: raw.delete_prefix(message + "\n").split("\n", -1), raw_error: raw,
        raw_sha256: Digest::SHA256.hexdigest(raw), launch_id: 3778, item_id: log["itemId"], log_id: log["id"] }
    end
    output = File.join(ROOT, INPUTS)
    FileUtils.mkdir_p(File.dirname(output))
    value = { baseline_sha: BASE_SHA, baseline_launch_id: 3778, observation: "Reused committed historical GET; not a fresh API request",
      capture_qa_commit: Open3.capture2("git", "-C", ROOT, "rev-parse", "HEAD").first.strip,
      loaded_sdk_files_verified: hashes.length, source_files: files,
      ruby: runtime.fetch("ruby"), cucumber: runtime.fetch("cucumber"), rows: rows.sort_by { |r| r[:index] } }
    File.open(output, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.puts(JSON.pretty_generate(value)) }
    puts "Prepared only the 14 original Launch 3778 inputs: #{output}"
  end

  def self.error_logs(snapshot)
    items = snapshot.fetch("items").to_h { |i| [i.fetch("id"), i] }
    rows = snapshot.fetch("logs").select { |l| l["level"].to_s.downcase == "error" }.map do |log|
      index = items.fetch(log.fetch("itemId")).fetch("name")[/\bledger escaping failure (\d+)\z/, 1]
      raise "Unidentified F14 ERROR owner" unless index
      [index.to_i, log]
    end
    raise "Missing or duplicate F14 ERROR logs" unless rows.map(&:first).sort == (0...14).to_a
    rows.sort_by(&:first)
  end

  def self.text_fences(text)
    lines, blocks, index = text.lines(chomp: true), [], 0
    pattern = Regexp.new("\\A([#{96.chr}]{3,}|~{3,})text\\z")
    while index < lines.length
      match = pattern.match(lines[index])
      if match
        closing = ((index + 1)...lines.length).find { |i| lines[i] == match[1] }
        raise "Unclosed text fence" unless closing
        blocks << lines[(index + 1)...closing].join("\n")
        index = closing
      end
      index += 1
    end
    blocks
  end

  def self.content_check(row, log)
    text = log.fetch("message")
    title = CGI.unescapeHTML(text.lines.first.to_s.chomp).gsub(/\\([\\\x60*_\[\]|~])/, '\1')
    lines = row.fetch("message").lines(chomp: true)
    first = lines.index { |line| !line.strip.empty? }
    headline = first ? lines[first] : ""
    continuation = first ? lines[(first + 1)..].join("\n") : ""
    fences = text_fences(text)
    tail = fences.last
    title_ok = title == "## \u2717 RuntimeError: #{headline}"
    continuation_ok = continuation.empty? || fences.first == continuation
    actual = title_ok && continuation_ok && tail ? [row.fetch("message"), tail].join("\n") : nil
    { index: row.fetch("index"), expected_sha256: row.fetch("raw_sha256"),
      actual_sha256: actual && Digest::SHA256.hexdigest(actual),
      message_equal: title_ok && continuation_ok,
      frames_equal: tail == row.fetch("frames").join("\n"), raw_failure_equal: actual == row.fetch("raw_error"),
      baseline: row.slice("launch_id", "item_id", "log_id"), candidate_log_id: log["id"], candidate_item_id: log["itemId"],
      comparison: "Original message content (presentation escaping decoded only) and entire raw tail; no path/frame normalization" }
  end
end

if ENV["QA_P1_3778_REPLAY"] == "1"
  require "reportportal_cucumber"
  module P1Legacy3778
    class Formatter < ReportportalCucumber::Cucumber::Formatter
      def extract_error(event)
        original = super
        @qa_3778_cache ||= {}
        @qa_3778_cache[original.object_id] ||= begin
          @qa_3778_rows ||= JSON.parse(File.read(ENV.fetch("QA_3778_INPUTS"))).fetch("rows")
          row = @qa_3778_rows.find { |r| r.fetch("message") == original.message }
          raise "Native input not in Launch 3778" unless row
          LedgerDeveloper::Input.record("native_input_before_3778_replay", message: original.message, backtrace: original.backtrace)
          LedgerDeveloper::Input.record("explicit_3778_input_replay", source_launch_id: 3778, source_log_id: row.fetch("log_id"),
            source_raw_sha256: row.fetch("raw_sha256"), frame_count: row.fetch("frames").length)
          RuntimeError.new(row.fetch("message")).tap { |error| error.set_backtrace(row.fetch("frames")) }
        end
      end
    end
  end
elsif $PROGRAM_NAME == __FILE__ && ARGV.first == "prepare"
  P1Legacy3778.prepare
elsif $PROGRAM_NAME == __FILE__
  require_relative "../isolated"
  module P1Legacy3778
    class Runner < LedgerQA::IsolatedRunner
      def run_row(row)
        raise "Only F14-negative is authorized for this adapter" unless row[:id] == "F14-negative"
        super(row.merge(id: "F14-negative-3778", origin: "Explicit original-input replay, not a claim of native C9/C10 stack equality"))
      end
      def execute(env, command, directory)
        if command.last.to_s.end_with?("/F14-negative-3778.feature")
          command = command.dup
          command.insert(command.index("--no-profile") + 1, "--require", File.expand_path(__FILE__))
          command[command.index("ReportPortal::Cucumber::Formatter")] = "P1Legacy3778::Formatter"
          env = env.merge("QA_P1_3778_REPLAY" => "1", "QA_3778_INPUTS" => ENV.fetch("QA_3778_INPUTS", File.join(P1Legacy3778::ROOT, P1Legacy3778::INPUTS)))
        end
        super(env, command, directory)
      end
    end
  end
  exit P1Legacy3778::Runner.new(ARGV).run
end
