# frozen_string_literal: true

require_relative "final_wp5_analyze"
require "cgi"

stamp = LedgerWP5Context.stamp
LedgerQAAnalysis::WP5Study::FINAL_HEADS.each do |version, sha|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  rows = []
  (version == "2.0.1" ? ["12.0.1"] : %w[9.2.1 10.2.0]).each do |cucumber|
    study = LedgerQAAnalysis::WP5Study.new(root, stamp, cucumber)
    study.run("rich").each do |fixture, snapshot|
      grouped = study.logs(snapshot).select { |log| log["message"].include?("<details>") }.group_by do |log|
        item = snapshot.fetch("items").find { |entry| entry["id"] == log["itemId"] }
        item = snapshot.fetch("items").find { |entry| entry["id"] == item["parent"] } while item && !(item["type"] == "STEP" && item["hasStats"])
        item && item["id"]
      end
      grouped.each do |context_id, logs|
        context = snapshot.fetch("items").find { |item| item["id"] == context_id }
        launch = snapshot.fetch("launches").first
        expected = logs.flat_map do |log|
          log.fetch("message").scan(/<details>(.*?)<\/details>/m).map do |match|
            body = match.first
            summary = CGI.unescapeHTML(body[/<summary>(.*?)<\/summary>/m, 1].to_s)
            fences = body.scan(/(`{3,})[^\n]*\n(.*?)\n\1/m).map { |_, code| code }
            { log_id: log.fetch("id"), summary: summary, fence_count: fences.length,
              code_sha256: fences.map { |code| Digest::SHA256.hexdigest(code) } }
          end
        end
        rows << { criterion: "P10.8", line: version, cucumber: cucumber, mode: "rich", fixture: fixture,
          runtime_sha: sha, launch_id: launch.fetch("id"), launch_name: launch.fetch("name"), launch_number: launch.fetch("number"),
          item_id: context_id, log_ids: logs.map { |log| log.fetch("id") },
          source_snapshot: study.refs(snapshot).fetch(:source), expected_details: expected,
          owners: logs.map { |log| snapshot.fetch("items").find { |item| item["id"] == log["itemId"] } }.compact.map { |item| item.slice("id", "name") }.uniq,
          url: context && "http://rp-2607.localhost:18080/ui/#superadmin_personal/launches/all/#{launch.fetch('id')}/#{context.fetch('path').tr('.', '/')}/log",
          claim_limit: "Every first-repeat rich details-bearing log is covered. Repeat-two equivalence must separately pass G4; no DOM result is inferred from this plan." }
      end
    end
  end
  output = File.join(root, "docs/reviews/assets", stamp, "dom-plan.json")
  File.write(output, JSON.pretty_generate(schema: "final-head-details-dom-plan/1", rows: rows) + "\n")
  puts JSON.generate(version: version, contexts: rows.length, details: rows.sum { |row| row[:expected_details].length })
end
