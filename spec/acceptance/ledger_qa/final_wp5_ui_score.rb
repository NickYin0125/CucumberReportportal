# frozen_string_literal: true

require "json"
require "digest"
require_relative "final_wp5_context"

stamp = LedgerWP5Context.stamp
central = File.join("/Users/nick/Documents/crr-qa-2.0.1/docs/reviews/assets", stamp)
read_lines = ->(name) { path = File.join(central, name); File.file?(path) ? File.readlines(path).map { |line| JSON.parse(line) } : [] }
details = read_lines.call("ui-details.ndjson")
titles = read_lines.call("ui-literal-titles.ndjson")
LedgerWP5Context.heads.each do |version, head|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  directory = File.join(root, "docs/reviews/assets", stamp)
  screenshot_path = File.join(directory, "screenshots.json")
  shots = File.file?(screenshot_path) ? JSON.parse(File.read(screenshot_path)) : []
  plan = JSON.parse(File.read(File.join(directory, "dom-plan.json"))).fetch("rows")
  checks = []
  coverage = {}
  add = lambda do |id, label, expected, actual, records, method, passed = nil|
    passed = expected == actual if passed.nil?
    checks << { criterion: id, check: label, method: method, cucumber: records.first && records.first["cucumber"], runtime_sha: head,
      expected: expected, actual: actual, inputs: records,
      verdict: passed ? "PASS" : "FAIL", evidence: {
        launch_ids: records.map { |row| row["launch_id"] }.compact.uniq,
        item_ids: records.map { |row| row["item_id"] }.compact.uniq,
        log_ids: records.flat_map { |row| row["log_ids"] || [row["log_id"]] }.compact.uniq,
        source: records.map { |row| row["path"] || row["source_snapshot"] }.compact.uniq } }
  end
  (version == "2.0.1" ? ["12.0.1"] : %w[9.2.1 10.2.0]).each do |cucumber|
    coverage[cucumber] = {}
    cohort_shots = shots.select do |row|
      row["cucumber"] == cucumber && row["runtime_sha"] == head && %w[PASS FAIL].include?(row["verdict"])
    end
    { "P1.8" => "S01", "P1.9" => "S02" }.each do |id, group|
      rows = cohort_shots.select { |row| row["slug"].start_with?(group) }
      coverage[cucumber][id] = rows.empty? ? "INCOMPLETE" : "COMPLETE"
      rows.each { |row| add.call(id, "#{cucumber} #{row['slug']}: independently judged fresh screenshot", "PASS", row["verdict"], [row], "V") }
    end
    literal = titles.select { |row| row["cucumber"] == cucumber && row["runtime_sha"] == head }
    coverage[cucumber]["P1.6"] = literal.map { |row| row["expected"] }.uniq.length == 2 ? "COMPLETE" : "INCOMPLETE"
    literal.each { |row| add.call("P1.6", "#{cucumber}: literal title text and no data-created script/b elements", { title: row["expected"], script: 0, bold: 0 }.transform_keys(&:to_s), row["actual"], [row], "D") }
    wanted = plan.select { |row| row["cucumber"] == cucumber }
    observed = details.select { |row| row["cucumber"] == cucumber && row["runtime_sha"] == head }
    coverage[cucumber]["P10.8"] = !wanted.empty? && wanted.all? { |entry| observed.any? { |row| row.values_at("launch_id", "item_id", "expected_details") == entry.values_at("launch_id", "item_id", "expected_details") } } ? "COMPLETE" : "INCOMPLETE"
    observed.each { |row| add.call("P10.8", "#{cucumber} #{row['fixture']}: every details fence renders as direct pre/code with exact fenced bytes", "PASS", row["verdict"], [row], "D") }
    p10 = cohort_shots.select { |row| row["mode"] == "rich" && row["slug"].start_with?("S03", "S06", "S08", "S09") }
    required = ["S03", "S06", "S08"]
    families = %w[f10a f10c f11a f11b f11c f12]
    complete = required.all? { |group| p10.any? { |row| row["slug"].start_with?(group) } } && families.all? { |fixture| p10.any? { |row| row["slug"].include?("-#{fixture}-rich-") } }
    coverage[cucumber]["P10.10"] = complete ? "COMPLETE" : "INCOMPLETE"
    p10.each { |row| add.call("P10.10", "#{cucumber} #{row['slug']}: visible rich pills/titles/folds, independently inspected", "PASS", row["verdict"], [row], "V") }
    tones = {}
    cohort_shots.select { |row| row["mode"] == "rich" }.each do |row|
      dom = row["dom"] || {}
      (dom["spans"] || dom["pills"] || []).each do |span|
        tone = case span["text"]
               when "PASS", "201" then "pass"
               when "FAIL", "500" then "fail"
               when "404" then "warn"
               when "PNG", "Text", "JSON" then "info"
               end
        next unless tone && span["radius"].to_s != "0px"
        colors = %w[color background].map { |key| span[key].to_s.scan(/[\d.]+/).first(3).map(&:to_f) }
        next unless colors.all? { |rgb| rgb.length == 3 }
        luminance = colors.map do |rgb|
          linear = rgb.map { |value| channel = value / 255.0; channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4 }
          linear.zip([0.2126, 0.7152, 0.0722]).sum { |channel, weight| channel * weight }
        end
        ratio = (luminance.max + 0.05) / (luminance.min + 0.05)
        tones[tone] ||= { ratio: ratio, computed_style: span, source: row }
      end
    end
    coverage[cucumber]["P10.11"] = tones.keys.sort == %w[fail info pass warn] ? "COMPLETE" : "INCOMPLETE"
    tones.each { |tone, data| add.call("P10.11", "#{cucumber}: computed #{tone} pill contrast, WCAG sRGB relative luminance", ">= 4.5:1", data[:ratio], [data[:source]], "D", data[:ratio] >= 4.5) }
    attachment_shots = cohort_shots.select { |row| row["slug"].start_with?("S06") }
    modal = attachment_shots.select { |row| row["subcheck"] == "preview-modal" && row.dig("dom", "complete") && row.dig("dom", "naturalWidth") == 640 && row.dig("dom", "naturalHeight") == 360 }
    download_sets = Dir[File.join(directory, "ui-downloads/*download-observations.json")].map { |path| JSON.parse(File.read(path)).merge("source_file" => path) }.select do |row|
      attachment_shots.any? { |shot| shot["launch_id"] == row["launch_id"] }
    end
    modes = attachment_shots.reject { |row| row["subcheck"] == "preview-modal" }.map { |row| row["mode"] }.uniq.sort
    exact_downloads = download_sets.select do |row|
      row.fetch("downloads").map { |file| file["expected_filename"] }.sort == %w[visible-fixture.json visible-fixture.png visible-fixture.txt] &&
        row.fetch("downloads").all? { |file| file["actual_saved_filename"] == file["expected_filename"] }
    end
    download_complete = !exact_downloads.empty?
    coverage[cucumber]["P5.8"] = modes == %w[plain rich] && !modal.empty? && download_complete ? "COMPLETE" : "INCOMPLETE"
    attachment_shots.each { |row| add.call("P5.8", "#{cucumber} #{row['slug']}: actual caption/preview visual observation", "PASS", row["verdict"], [row], "V") }
    download_sets.each do |row|
      matching_shot = attachment_shots.find { |shot| shot["launch_id"] == row["launch_id"] }
      add.call("P5.8", "#{cucumber}: actual browser-saved download filenames, not response headers", row.fetch("downloads").map { |file| file["expected_filename"] },
        row.fetch("downloads").map { |file| file["actual_saved_filename"] }, [matching_shot.merge("actual_downloads" => row)], "V")
      row.fetch("downloads").each do |file|
        copy = file["evidence_copy"] || file.fetch("retained_copy")
        actual = File.file?(copy) ? [File.size(copy), Digest::SHA256.file(copy).hexdigest] : nil
        add.call("P5.8", "#{cucumber}: retained actual browser download #{file['actual_saved_filename']} has recorded bytes/hash",
          [file["size"] || file.fetch("bytes"), file["sha256"]], actual, [matching_shot.merge("actual_download" => file)], "V")
      end
      original_names = row.fetch("downloads").map { |file| file["expected_filename"] }
      saved_names = row.fetch("downloads").map { |file| file["actual_saved_filename"] }
      next if original_names == saved_names
      corroborated = exact_downloads.any? do |clean|
        clean.fetch("downloads").map { |file| file.values_at("expected_filename", "size", "sha256") } ==
          row.fetch("downloads").map { |file| file.values_at("expected_filename", "size", "sha256") }
      end
      collision_only = row.fetch("downloads").all? do |file|
        original = file.fetch("expected_filename")
        ext = File.extname(original)
        pattern = /\A#{Regexp.escape(original.delete_suffix(ext))}(?: \(\d+\))?#{Regexp.escape(ext)}\z/
        file.fetch("actual_saved_filename").match?(pattern)
      end
      if corroborated && collision_only
        comparison = checks.find { |check| check[:criterion] == "P5.8" && check[:check].include?("actual browser-saved download filenames") && check.dig(:inputs, 0, "actual_downloads", "source_file") == row["source_file"] }
        comparison[:verdict] = "N/A"
        comparison[:environment_adjudication] = "Raw local collision-suffixed save retained unchanged. Master preserved the prior synthetic Downloads files; a separately recorded clean save has exact original names and byte-identical files. This collision observation is not product acceptance proof."
      end
    end
  end
  File.write(File.join(directory, "ui-checks.json"), JSON.pretty_generate(schema: "fresh-ui-criterion-evidence/1", runtime_sha: head, coverage: coverage, checks: checks) + "\n")
  puts JSON.generate(version: version, coverage: coverage, checks: checks.length, failures: checks.count { |row| row[:verdict] == "FAIL" })
end
