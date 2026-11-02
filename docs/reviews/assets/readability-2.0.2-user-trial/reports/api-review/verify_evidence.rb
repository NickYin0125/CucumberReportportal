# frozen_string_literal: true

require "json"
require "digest"
require "time"

ROOT = File.expand_path(__dir__)
TRIAL = "/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.2"
OLD = "/Users/nick/Documents/crr-qa-2.0.1/tmp/trial/rp-trial-2.0.1"
SDK = "/Users/nick/Documents/crr-2.0.2"

def read(name)
  JSON.parse(File.read(File.join(ROOT, name)))
end

def logs(item)
  read("logs-#{item}.json").flat_map { |page| page.fetch("content") }
end

launches = [3849, 3851, 3847, 3850].map do |id|
  launch = read("launch-#{id}.json")
  pages = read("items-#{id}.json")
  items = pages.flat_map { |page| page.fetch("content") }
  all_logs = items.flat_map { |item| logs(item.fetch("id")) }
  scenarios = items.select { |item| item["hasStats"] && item["type"] == "STEP" }
  raise "Duplicate item ID" unless items.map { |item| item["id"] }.uniq.size == items.size
  raise "Duplicate log ID" unless all_logs.map { |log| log["id"] }.uniq.size == all_logs.size
  {id: id, name: launch["name"], status: launch["status"], attributes: launch["attributes"],
   statistics: launch["statistics"], scenario_status_counts: scenarios.group_by { |item| item["status"] }.transform_values(&:size),
   item_count: items.size, log_count: all_logs.size, item_pages: pages.map { |page| page["page"] },
   html_decorated_error_ids: all_logs.select { |log| %w[error fatal].include?(log["level"]) && log["message"].to_s.match?(/<(?:span|details)\b/) }.map { |log| log["id"] }}
end

pairs = [[31695, 31845, 21110, 21302], [31695, 31845, 21111, 21303],
         [31700, 31850, 21120, 21312], [31700, 31850, 21121, 21313]].map do |left, right, lid, rid|
  a = logs(left).find { |log| log["id"] == lid }.fetch("message")
  b = logs(right).find { |log| log["id"] == rid }.fetch("message")
  {plain_log: lid, rich_log: rid, byte_identical: a.b == b.b,
   plain_sha256: Digest::SHA256.hexdigest(a), rich_sha256: Digest::SHA256.hexdigest(b)}
end

copies = %w[features/independent/api_contracts.feature features/step_definitions/independent_api_steps.rb
            features/tester_api/workplace_contracts.feature features/tester_api/workplace_steps.rb].map do |path|
  a = Digest::SHA256.file(File.join(OLD, path)).hexdigest
  b = Digest::SHA256.file(File.join(TRIAL, path)).hexdigest
  {path: path, original_sha256: a, copied_sha256: b, identical: a == b}
end

docs = ["README.md", "docs/getting-started.md", "docs/best-practices.md", "docs/configuration.md", "docs/advanced-reporting.md"].map do |path|
  full = File.join(SDK, path)
  lines = File.readlines(full)
  {path: full, sha256: Digest::SHA256.file(full).hexdigest,
   ambiguous_term_matches: lines.each_with_index.filter_map { |line, i| {line: i + 1, text: line.chomp} if line.match?(/AppLog 1\.3\.1|pre-Ledger/) }}
end

excerpts = {"README.md" => [8..23], "docs/best-practices.md" => [95..106, 123..141, 229..236],
            "docs/configuration.md" => [91..95, 114..124]}.flat_map do |path, ranges|
  lines = File.readlines(File.join(SDK, path))
  ranges.map { |range| {path: File.join(SDK, path), lines: range.map { |number| {number: number, text: lines[number - 1].chomp} }} }
end

summary = {verified_at: Time.now.utc.iso8601,
           master_attested_sdk_head: "9bf3356cff350d8e2ba11bad1c33aa89881ac456",
           provenance_limit: "SHA, installation and environment supplied by Master; no independent archive-to-SHA attestation",
           excluded_launches: [3843, 3844, 3845, 3846], launches: launches,
           exact_plain_rich_error_comparisons: pairs, independently_hashed_api_inputs: copies,
           public_docs: docs, doc_excerpts: excerpts,
           native_ui: "Not verified: browser rejected local file URL; no workaround attempted",
           test_executions_by_reviewer: 0}
File.write(File.join(ROOT, "verification.json"), JSON.pretty_generate(summary))
puts JSON.pretty_generate(summary.reject { |key, _| key == :doc_excerpts })
