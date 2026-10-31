# frozen_string_literal: true

require "json"
require "fileutils"
require "open3"
require "rbconfig"

root = File.expand_path("../../..", __dir__)
prefix, cucumber, gems = ARGV
abort "usage: faults.rb OUTPUT_PREFIX CUCUMBER GEM_PATH" unless prefix && cucumber && gems
entries = {
  "MarkdownText.html" => "F10a", "MarkdownText.inline" => "F10a", "MarkdownText.code" => "F10a",
  "MarkdownText.fence" => "F10c", "MarkdownText.cell" => "F13", "FailureCard.format" => "F04",
  "LedgerJson.format" => "F10d", "AttachmentCaption.format" => "F01", "AttachmentCaption.kind" => "F01",
  "AttachmentCaption.slug" => "F17", "ImageDimensions.read" => "F01", "ImageDimensions.png" => "F01",
  "ImageDimensions.jpeg" => "F17", "Units.bytes" => "F11a", "Units.count" => "F04", "Units.duration" => "F11b",
  "RunContext.build" => "F19a", "RunContext.first" => "F19a", "RunContext.trim" => "F19a",
  "Accent.pill" => "F10a", "Accent.title" => "F10a", "Accent.table_header" => "F13",
  "Accent.details" => "F04", "Accent.guard" => "F10a"
}
results = []
FileUtils.mkdir_p(prefix)
entries.each do |entry, fixture|
  out = File.join(prefix, entry.tr(".", "-"))
  next if File.file?(File.join(out, "summary.json"))
  command = [RbConfig.ruby, File.join(root, "spec/acceptance/ledger_qa/isolated.rb"), "--transport", "offline", "--mode", "rich",
             "--fixtures", fixture, "--sdk-root", root, "--cucumber", cucumber, "--gem-path", gems,
             "--jpeg", ENV.fetch("QA_JPEG"), "--output", out]
  fallback_capture = File.join(prefix, "#{entry.tr('.', '-')}-fallback.ndjson")
  stdout, stderr, status = Open3.capture3({ "QA_FAULT_ENTRY" => entry, "QA_FALLBACK_CAPTURE" => fallback_capture }, *command)
  process_path = File.join(out, fixture, "process.json")
  child = File.file?(process_path) ? JSON.parse(File.read(process_path)) : {}
  warning = "ReportPortal presentation failed; using baseline format"
  native_path = File.join(out, fixture, "native.json")
  native = File.file?(native_path) ? JSON.parse(File.read(native_path)) : []
  steps = native.flat_map { |f| f.fetch("elements", []).flat_map { |s| s.fetch("steps", []) } }
  result = { entry: entry, fixture: fixture, harness_exit: status.exitstatus, child_exit: child["exit"],
             fault_invocations: child.fetch("stderr", "").scan("QA_FAULT_INVOKED #{entry}").length,
             warning_count: child.fetch("stderr", "").scan(warning).length,
             native_step_statuses: steps.map { |s| s.dig("result", "status") },
             fallback_capture: File.file?(fallback_capture) ? File.readlines(fallback_capture).map { |line| JSON.parse(line) } : [],
             stderr: stderr, stdout: stdout, directory: out }
  results << result
  File.write(File.join(prefix, "fault-results.json"), JSON.pretty_generate(results) + "\n")
  puts JSON.generate(result.reject { |k, _| %i[stdout stderr].include?(k) })
  $stdout.flush
end
