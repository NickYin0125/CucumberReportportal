# frozen_string_literal: true

require "json"
require "digest"
require "net/http"
require "uri"
require "open3"
require "optparse"
require "fileutils"
require "time"

options = {}
OptionParser.new do |p|
  p.banner = "GET-only P1/G8 readback. Required environment: RP_API_KEY only."
  p.on("--capture-dir PATH") { |v| options[:capture] = File.expand_path(v) }
  p.on("--expected-sha SHA") { |v| options[:sha] = v }
  p.on("--out PATH") { |v| options[:out] = File.expand_path(v) }
  p.on("--help") { puts p; exit }
end.parse!(ARGV)
abort "Explicit capture directory, final SHA and new output required" unless options.values_at(:capture, :sha, :out).all? &&
  options[:sha].match?(/\A[0-9a-f]{40}\z/) && ARGV.empty?
abort "Master must inject RP_API_KEY into this process only" if ENV["RP_API_KEY"].to_s.empty?
root = File.expand_path("../../../..", __dir__)
allowed = File.join(root, "docs/reviews/assets/1x-p1-20261101") + "/"
abort "Output must be new and under the 1.x P1 evidence directory" unless options[:out].start_with?(allowed) && !File.exist?(options[:out])
snapshots = Dir[File.join(options[:capture], "**/snapshot.json")].sort
abort "No completed captures" if snapshots.empty?
FileUtils.mkdir_p(options[:out], mode: 0o700)
write = lambda do |path, value|
  contains_key = lambda do |object|
    case object
    when String then object.include?(ENV.fetch("RP_API_KEY"))
    when Hash then object.any? { |k, v| contains_key.call(k) || contains_key.call(v) }
    when Array then object.any? { |v| contains_key.call(v) }
    else false
    end
  end
  raise "Refusing credential-bearing observation" if contains_key.call(value)
  File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.puts(JSON.pretty_generate(value)) }
end
get = lambda do |path|
  uri = URI("http://rp-2607.localhost:18080/api/v1/superadmin_personal/" + path)
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{ENV.fetch('RP_API_KEY')}"
  response = Net::HTTP.start(uri.hostname, uri.port, nil, open_timeout: 5, read_timeout: 25) { |http| http.request(request) }
  raise "Required GET failed HTTP #{response.code}" unless response.code == "200"
  JSON.parse(response.body)
end
pages = lambda do |path|
  page, rows = 1, []
  loop do
    reply = get.call("#{path}&page.size=100&page.page=#{page}")
    rows.concat(reply.fetch("content"))
    break if page >= reply.fetch("page").fetch("totalPages")
    page += 1
  end
  rows
end
results, source_cache = [], {}
begin
  snapshots.each do |path|
    directory = File.dirname(path)
    saved = JSON.parse(File.read(path))
    runtime = JSON.parse(File.read(File.join(directory, "runtime.json")))
    sdk_root = File.dirname(runtime.fetch("activation").fetch("sdk_gemspec"))
    raise "Runtime source changed during capture" if runtime.fetch("sdk_source_changed_during_fixture")
    raise "Wrong SDK version" unless runtime.fetch("sdk_version") == "1.3.2"
    runtime.fetch("loaded_sdk_sha256_at_start").each do |absolute, actual|
      relative = absolute.delete_prefix(sdk_root + "/")
      expected = source_cache[relative] ||= begin
        bytes, status = Open3.capture2("git", "-C", root, "show", "#{options[:sha]}:#{relative}")
        raise "Final source member unavailable" unless status.success?
        Digest::SHA256.hexdigest(bytes.b)
      end
      raise "Runtime does not match final head" unless expected == actual
    end
    saved.fetch("launches").each do |reference|
      id = reference.fetch("id")
      launch = get.call("launch/#{id}")
      raise "Launch identity mismatch" unless launch.fetch("uuid") == reference.fetch("uuid")
      raise "Launch is not finished" unless launch["endTime"]
      items = pages.call("item?filter.eq.launchId=#{id}")
      (saved.fetch("items").map { |i| i.fetch("id") } - items.map { |i| i.fetch("id") }).each { |item_id| items << get.call("item/#{item_id}") }
      raise "Cross-Launch item returned" unless items.all? { |i| i["launchId"] == id }
      logs = (items.flat_map { |i| pages.call("log?filter.eq.item=#{i.fetch('id')}") } +
        pages.call("log?filter.eq.launch=#{id}")).uniq { |l| l.fetch("id") }
      complete = logs.map { |l| l.fetch("id") }.sort == saved.fetch("logs").map { |l| l.fetch("id") }.sort &&
        items.map { |i| i.fetch("id") }.sort == saved.fetch("items").map { |i| i.fetch("id") }.sort
      query = get.call("log?filter.eq.launch=#{id}&filter.cnt.message=SECRET123&page.size=1")
      observation = { persistence: "fresh_independent_GET", observed_at: Time.now.utc.iso8601, source_capture: path,
        source_capture_sha256: Digest::SHA256.file(path).hexdigest, final_runtime_sha: options[:sha],
        ruby: runtime["ruby"], cucumber: runtime["cucumber"], launches: [launch], items: items, logs: logs,
        item_and_log_sets_match_capture: complete, secret_filter_observed_count: query.dig("page", "totalElements"),
        policy: "D19: raw failure bytes may be legacy content; any secret hits require source comparison, not an automatic zero-hit rule",
        verdict: "NOT_SCORED" }
      write.call(File.join(options[:out], "launch-#{id}.json"), observation)
      results << { launch_id: id, complete: complete, items: items.length, logs: logs.length }
      raise "GET evidence incomplete" unless complete
    end
  end
  write.call(File.join(options[:out], "summary.json"), results: results, final_sha: options[:sha], method: "GET only", verdict: "NOT_SCORED")
  puts JSON.generate(results)
rescue StandardError => error
  write.call(File.join(options[:out], "blocked.json"), error_class: error.class.name, reason: "Required source binding or GET incomplete; no PASS inferred", completed: results)
  warn "Readback BLOCKED (#{error.class}); retained completed observations"
  exit 2
end
