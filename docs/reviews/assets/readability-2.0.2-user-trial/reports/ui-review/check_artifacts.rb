# frozen_string_literal: true

require "json"
require "digest"
require "base64"
require "time"

out = File.expand_path(__dir__)
trial = File.expand_path("../..", out)
runs = {"20261102-1952-ui-plain" => 3850, "20261102-1952-ui-rich" => 3852, "ui-tester" => 3848}
result = {captured_at: Time.now.utc.iso8601, runtime_sha_supplied: "9bf3356cff350d8e2ba11bad1c33aa89881ac456", runs: []}
runs.each do |run, launch|
  dir = File.join(trial, "artifacts", run)
  messages = File.foreach(File.join(dir, "messages.ndjson")).map { |line| JSON.parse(line) }
  cases = messages.filter_map { |m| m["testCase"] }.to_h { |v| [v.fetch("id"), v] }
  starts = messages.filter_map { |m| m["testCaseStarted"] }.to_h { |v| [v.fetch("id"), v] }
  pickles = messages.filter_map { |m| m["pickle"] }.to_h { |v| [v.fetch("id"), v] }
  owner = lambda do |event|
    test_case = cases.fetch(starts.fetch(event.fetch("testCaseStartedId")).fetch("testCaseId"))
    step = test_case.fetch("testSteps").find { |s| s["id"] == event["testStepId"] }
    pickle = pickles.fetch(test_case.fetch("pickleId"))
    {scenario: pickle["name"], hook: !!step["hookId"], step: pickle.fetch("steps").find { |s| s["id"] == step["pickleStepId"] }&.fetch("text")}
  end
  pngs = messages.filter_map { |m| m["attachment"] }.select { |a| a["mediaType"] == "image/png" }.map do |a|
    bytes = Base64.strict_decode64(a.fetch("body"))
    owner.call(a).merge(sha256: Digest::SHA256.hexdigest(bytes), bytes: bytes.bytesize)
  end
  failures = messages.filter_map { |m| m["testStepFinished"] }.select { |f| f.dig("testStepResult", "status") == "FAILED" }.map do |f|
    owner.call(f).merge(result: f.fetch("testStepResult"))
  end
  hooks = messages.filter_map { |m| m["testStepFinished"] }.select { |f| owner.call(f)[:hook] }.map { |f| owner.call(f).merge(status: f.dig("testStepResult", "status")) }
  local = Dir.glob(File.join(dir, "*.png")).map do |path|
    bytes = File.binread(path)
    {path: path, bytes: bytes.bytesize, valid_png_signature: bytes.start_with?("\x89PNG\r\n\x1a\n".b), dimensions: bytes.byteslice(16, 8).unpack("NN"), sha256: Digest::SHA256.hexdigest(bytes), native_match: pngs.any? { |p| p[:sha256] == Digest::SHA256.hexdigest(bytes) }}
  end
  result[:runs] << {launch: launch, artifact_directory: dir, meta: messages.find { |m| m["meta"] }["meta"], native_pngs: pngs, failures: failures, hooks: hooks, local_pngs: local, native_html_exists: File.file?(File.join(dir, "cucumber.html")), native_html_visually_reviewed: false}
end
result[:original_tester_inputs] = %w[workday_practice.feature workday_practice_steps.rb].map do |name|
  original = File.join(trial.sub("rp-trial-2.0.2", "rp-trial-2.0.1"), "features", "tester_ui", name)
  copied = File.join(trial, "features", "tester_ui", name)
  {name: name, original_sha256: Digest::SHA256.file(original).hexdigest, copied_sha256: Digest::SHA256.file(copied).hexdigest, identical: File.binread(original) == File.binread(copied)}
end
result[:error_presentation_comparison] = [[31710,31860],[31753,31911]].map do |plain, rich|
  messages_for = lambda { |id| JSON.parse(File.read(File.join(out, "logs-item-#{id}.json"))).select { |l| l["level"] == "error" }.map { |l| l["message"] } }
  a, b = messages_for.call(plain), messages_for.call(rich)
  {plain_item: plain, rich_item: rich, byte_identical_messages: a == b, added_html_tags_present: b.any? { |m| m.match?(/<(?:span|details|summary|div)\b/) }}
end
File.write(File.join(out, "artifact-verification.json"), JSON.pretty_generate(result) + "\n")
result[:runs].each { |r| puts "Launch #{r[:launch]}: #{r[:native_pngs].length} native checkpoint PNGs, #{r[:failures].length} original failures, #{r[:hooks].count { |h| h[:status] == 'PASSED' }} passed After hooks, #{r[:local_pngs].length} local PNGs." }
puts "Copied tester inputs identical: #{result[:original_tester_inputs].all? { |f| f[:identical] }}"
