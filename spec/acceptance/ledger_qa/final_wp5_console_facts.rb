# frozen_string_literal: true

require "json"
require "open3"
require "digest"
require_relative "final_wp5_context"

stamp = LedgerWP5Context.stamp
directory = "/Users/nick/Documents/crr-qa-2.0.1/docs/reviews/assets/#{stamp}"
output = File.join(directory, "console-ui-source-facts.json")
raise "Preserve prior observation" if File.exist?(output)
paths = %w[app/src/pages/inside/logsPage/logsGridToolbar/logsGridToolbar.jsx app/src/controllers/log/selectors.js]
sources = paths.map do |path|
  url = "https://raw.githubusercontent.com/reportportal/service-ui/5.15.6/#{path}"
  bytes, error, status = Open3.capture3({ "RP_API_KEY" => nil }, "curl", "--fail", "--silent", "--show-error", url)
  raise "Public source fetch failed: #{error}" unless status.success?
  { url: url, tag: "5.15.6", tree_commit: "5ec5e84dc89c1844f4561bfac906ceae7f7d44f8", sha256: Digest::SHA256.hexdigest(bytes),
    source: bytes, relevant_lines: bytes.lines.each_with_index.filter_map { |line, i| { line: i + 1, text: line.chomp } if line.match?(/!isNestedStepsView|consoleView|toggleConsoleView|hasNestedSteps|isLogPageWithNestedSteps/) } }
end
captures = File.readlines(File.join(directory, "ui-captures.ndjson")).map { |line| JSON.parse(line) }.select { |row| row["subcheck"] == "console-unavailable-nested-ui" }
raise "Missing independently observed DOM" unless captures.length == 3 && captures.all? { |row| row.dig("dom", "consoleControls") == 0 && row.dig("dom", "nestedRows").positive? }
data = { schema: "rp-console-blocker-facts/1", public_sources: sources, independent_dom_and_screenshot_records: captures,
  verdict: "BLOCKED", claim: "The actual nested-step view exposes no Console View control. Upstream version-matched source conditionally hides it for nested steps. Markdown-off and Stack trace are not substituted for Console proof.",
  pending_owner_question: "May exact-byte messages be replayed into new flat QA Launches solely to test Console rendering? No exception approved at capture time." }
File.write(output, JSON.pretty_generate(data) + "\n")
puts JSON.generate(path: output, dom_records: captures.length, sources: sources.map { |row| row[:sha256] })
