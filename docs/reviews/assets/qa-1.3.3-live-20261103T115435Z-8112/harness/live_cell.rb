# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "securerandom"
require "time"
require "uri"

OUT = "/evidence"
TOKEN = ENV.fetch("RP_API_KEY")
ENDPOINT = ENV.fetch("RP_ENDPOINT")
PROJECT = ENV.fetch("RP_PROJECT")
raise "Endpoint/project boundary" unless ENDPOINT == "http://rp-2607.localhost:18080" && PROJECT == "superadmin_personal"

def write_safe(name, value)
  output = value.is_a?(String) ? value : JSON.pretty_generate(value) + "\n"
  raise "Credential output suppressed" if output.include?(TOKEN)
  File.write(File.join(OUT, name), output)
end

def get(path)
  uri = URI(ENDPOINT + path)
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{TOKEN}"
  response = Net::HTTP.start(uri.host, uri.port, nil, open_timeout: 5, read_timeout: 20) { |http| http.request(request) }
  raise "RP read HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  return { bytes: response.body.bytesize, sha256: Digest::SHA256.hexdigest(response.body.b), content_type: response["content-type"] } if path.start_with?("/api/v1/data/")
  JSON.parse(response.body)
end

def pages(path)
  all = []
  page = 1
  loop do
    result = get("/api/v1/#{PROJECT}/#{path}#{path.include?('?') ? '&' : '?'}page.size=100&page.page=#{page}")
    all.concat(result.fetch("content"))
    break if page >= result.fetch("page").fetch("totalPages")
    page += 1
    raise "Unexpected pagination" if page > 20
  end
  all
end

def command(name, *argv, chdir: "/tmp/qa-live-source")
  output, status = Open3.capture2e(*argv, chdir: chdir)
  write_safe(name + ".log", output)
  status
end

result = { sha: ENV.fetch("QA_SHA"), status: "RUNNING", r02: "NOT FIXED", compound_arguments: "N/A Cucumber 9/10", native_global_hook_names: "N/A 1.x" }
begin
  FileUtils.cp_r("/source", "/tmp/qa-live-source")
  head, status = Open3.capture2("git", "-C", "/tmp/qa-live-source", "rev-parse", "HEAD")
  raise "Wrong frozen source" unless status.success? && head.strip == ENV.fetch("QA_SHA")
  raise "Package build failed" unless command("package-build", "gem", "build", "reportportal-cucumber-ruby.gemspec", "--output", "/tmp/qa-candidate.gem").success?
  raise "Package install failed" unless command("package-install", "gem", "install", "--local", "--ignore-dependencies", "--no-document", "--install-dir", "/tmp/qa-installed", "/tmp/qa-candidate.gem").success?
  Gem.use_paths("/tmp/qa-installed", ["/tmp/qa-installed", "/bundle/ruby/3.3.0", *Gem.path])
  expressions = ENV.fetch("QA_CUCUMBER").start_with?("9.") ? "17.1.0" : "18.1.0"
  gem "cucumber-cucumber-expressions", "=#{expressions}"
  gem "cucumber", ENV.fetch("QA_CUCUMBER")
  gem "reportportal-cucumber-ruby", "=1.3.3"
  require "reportportal_cucumber"
  installed = Gem.loaded_specs.fetch("reportportal-cucumber-ruby").full_gem_path
  libraries = Dir["/source/lib/**/*.rb"].sort.to_h do |path|
    relative = path.delete_prefix("/source/")
    digest = Digest::SHA256.file(path).hexdigest
    raise "Packaged library mismatch" unless Digest::SHA256.file(File.join(installed, relative)).hexdigest == digest
    [relative, digest]
  end
  FileUtils.cp("/tmp/qa-candidate.gem", File.join(OUT, "candidate.gem"))
  result[:package_sha256] = Digest::SHA256.file("/tmp/qa-candidate.gem").hexdigest
  result[:lib_sha256] = libraries
  result[:runtime] = { ruby: RUBY_DESCRIPTION, gems: Gem.loaded_specs.sort.to_h.transform_values { |spec| spec.version.to_s } }
  if ENV.fetch("QA_MODE") == "plain"
    consumer_files = %w[test/self_test.rb helpers/world.rb helpers/api_client.rb helpers/fixture_server.rb features/step_definitions/api_steps.rb bin/verify]
    result[:consumer_sha256] = consumer_files.to_h do |relative|
      path = "examples/current_sdk/" + relative
      digest = Digest::SHA256.file(File.join("/source", path)).hexdigest
      raise "Packaged consumer source mismatch: #{relative}" unless Digest::SHA256.file(File.join(installed, path)).hexdigest == digest
      [path, digest]
    end
    activation = File.join(OUT, "consumer-activation.rb")
    File.write(activation, <<~RUBY)
      require "json"
      gem "cucumber-cucumber-expressions", #{("=" + expressions).inspect}
      gem "cucumber", #{("=" + ENV.fetch('QA_CUCUMBER')).inspect}
      gem "reportportal-cucumber-ruby", "=1.3.3"
      at_exit do
        File.write("/evidence/consumer-runtime.json", JSON.pretty_generate(
          ruby: RUBY_DESCRIPTION, gems: Gem.loaded_specs.sort.to_h.transform_values { |spec| spec.version.to_s },
          sdk_root: Gem.loaded_specs.fetch("reportportal-cucumber-ruby").full_gem_path) + "\n")
      end
    RUBY
    consumer_script = File.join(installed, "examples/current_sdk/test/self_test.rb")
    consumer_command = [Gem.ruby, "-r", activation, consumer_script]
    write_safe("consumer-command.json", consumer_command)
    consumer_env = { "GEM_HOME" => "/tmp/qa-installed", "GEM_PATH" => (["/tmp/qa-installed", "/bundle/ruby/3.3.0", *Gem.path].uniq.join(":")) }
    consumer_output, consumer_status = Open3.capture2e(consumer_env, *consumer_command, chdir: "/tmp")
    write_safe("consumer-self-tests.log", consumer_output)
    raise "Actual packaged consumer self-tests failed" unless consumer_status.success?
    count = consumer_output.lines.count { |line| line.start_with?("PASS ") }
    declared = consumer_output[/^(\d+) example self-tests passed/, 1].to_i
    raise "Packaged self-test count is missing or incomplete" unless count.positive? && count == declared
    consumer_runtime = JSON.parse(File.read(File.join(OUT, "consumer-runtime.json")))
    raise "Packaged consumer activated wrong Cucumber" unless consumer_runtime.fetch("gems").fetch("cucumber") == ENV.fetch("QA_CUCUMBER")
    raise "Packaged consumer activated a different SDK" unless File.realpath(consumer_runtime.fetch("sdk_root")) == File.realpath(installed)
    result[:consumer_self_tests] = { status: "PASS", actual_checks: count, exit: consumer_status.exitstatus,
      script: consumer_script, cucumber: ENV.fetch("QA_CUCUMBER"), ruby: consumer_runtime.fetch("ruby"),
      genuine_packaged_example: true, not_live_ingestion_proof: true }
  end
  launch_name = "QA133-#{ENV.fetch('QA_SHA')[0, 7]}-c#{ENV.fetch('QA_CUCUMBER')}-#{ENV.fetch('QA_MODE')}-#{SecureRandom.hex(4)}"
  result[:launch_name] = launch_name
  # Child activation is explicit and uses only the newly installed candidate.
  boot = File.join(OUT, "boot.rb")
  File.write(boot, <<~RUBY)
    gem "cucumber-cucumber-expressions", #{("=" + expressions).inspect}
    gem "cucumber", #{ENV.fetch('QA_CUCUMBER').inspect}
    gem "reportportal-cucumber-ruby", "=1.3.3"
    require "cucumber/cli/main"
    exit Cucumber::Cli::Main.new(ARGV).execute!
  RUBY
  child = { "GEM_HOME" => "/tmp/qa-installed", "GEM_PATH" => (["/tmp/qa-installed", "/bundle/ruby/3.3.0", *Gem.path].uniq.join(":")),
    "RP_LAUNCH" => launch_name, "RP_PRESENTATION" => ENV.fetch("QA_MODE"), "RP_RUN_CONTEXT" => "true",
    "RP_ATTRIBUTES" => "qa.source.sha:#{ENV.fetch('QA_SHA')},qa.package.sha256:#{result.fetch(:package_sha256)},qa.cucumber:#{ENV.fetch('QA_CUCUMBER')},qa.mode:#{ENV.fetch('QA_MODE')},qa.independent:true",
    "RP_SOURCE_COMMIT" => ENV.fetch("QA_SHA"), "RP_REPORTING_ASYNC" => "false", "RP_CONSOLE_MIRROR" => "false",
    "RP_DEBUG_CURL" => "false", "QA_LIVE_OUT" => OUT, "CUCUMBER_PUBLISH_QUIET" => "true", "CUCUMBER_PUBLISH_ENABLED" => "false" }
  argv = [Gem.ruby, boot, "--publish-quiet", "--require", "/qa/live_steps.rb", "--format", "ReportPortal::Cucumber::Formatter",
    "--format", "json", "--out", File.join(OUT, "native.json"), "--format", "html", "--out", File.join(OUT, "native.html"), "/qa/live.feature"]
  output, execution = Open3.capture2e(child, *argv, chdir: "/tmp")
  write_safe("cucumber.log", output)
  result[:cucumber_exit] = execution.exitstatus
  # Two intended business failures, not a passing-Cucumber claim.
  native = JSON.parse(File.read(File.join(OUT, "native.json")))
  scenarios = native.flat_map { |feature| feature.fetch("elements", []) }.select { |element| element["type"] == "scenario" }
  statuses = scenarios.map { |scenario| scenario.fetch("steps", []).map { |step| step.dig("result", "status") } }
  result[:native] = { scenarios: scenarios.length, failed_scenarios: statuses.count { |values| values.include?("failed") } }
  raise "Unexpected native outcomes" unless execution.exitstatus == 1 && scenarios.length == 5 && result[:native][:failed_scenarios] == 2
  launch = nil
  30.times do
    launch = pages("launch?filter.eq.name=#{URI.encode_www_form_component(launch_name)}").find { |entry| entry["name"] == launch_name }
    break if launch && launch["status"] != "IN_PROGRESS"
    sleep 1
  end
  raise "Launch missing or unfinished" unless launch && launch["status"] != "IN_PROGRESS"
  attrs = launch.fetch("attributes", []).to_h { |entry| [entry["key"], entry["value"]] }
  raise "Launch does not record full final source SHA" unless attrs["qa.source.sha"] == ENV.fetch("QA_SHA")
  raise "Launch package SHA differs from the tested artifact" unless attrs["qa.package.sha256"] == result.fetch(:package_sha256)
  raise "1.x unexpectedly generated workers metadata" if attrs.key?("workers")
  result[:launch_id] = launch.fetch("id")
  items = (pages("item?filter.eq.launchId=#{launch.fetch('id')}") + pages("item?filter.eq.launchId=#{launch.fetch('id')}&filter.eq.hasStats=false")).uniq { |item| item.fetch("id") }
  logs = items.flat_map { |item| pages("log?filter.eq.item=#{item.fetch('id')}") }.uniq { |log| log.fetch("id") }
  write_safe("rp-snapshot.json", launch: launch, items: items, logs: logs)
  expected = Dir[File.join(OUT, "expected-*.json")].map { |path| JSON.parse(File.read(path)) }
  raise "Missing After evidence expectations" unless expected.length == 2 && expected.map { |entry| entry.fetch("name") }.uniq.length == 2
  expected.each do |entry|
    png_logs = logs.select { |log| log.fetch("message", "").include?(entry.fetch("name")) && log["binaryContent"] }
    raise "PNG missing or duplicated" unless png_logs.length == 1
    log = png_logs.first
    owner = items.find { |item| item.fetch("id") == log.fetch("itemId") }
    raise "PNG did not remain under passed After Hook" unless owner && owner.fetch("name").include?("After") && owner.fetch("status").downcase == "passed"
    bytes = get("/api/v1/data/#{PROJECT}/#{log.fetch('binaryContent').fetch('id')}")
    raise "PNG bytes changed" unless bytes.fetch(:sha256) == entry.fetch("sha256")
    raw = logs.find { |candidate| candidate.fetch("message", "").include?("QA_ORIGINAL_#{entry.fetch('case')}") }
    raise "Raw failure message changed" unless raw && raw.fetch("message").b.include?(entry.fetch("original_message").b)
    raise "Raw failure frames changed" unless raw.fetch("message").b.include?(entry.fetch("original_frames").join("\n").b)
    raise "ERROR decorated in rich mode" if ["<details", "<span"].any? { |tag| raw.fetch("message").include?(tag) }
  end
  all_text = logs.map { |log| log.fetch("message", "") }.join("\n")
  raise "Automatic HTTP secret leaked" if all_text.include?("SYNTHETIC_HTTP_SECRET")
  %w[literal-one literal-two].each { |value| raise "Outline evidence missing" unless all_text.include?("OUTLINE_VALUE=#{value}") }
  http = logs.find { |log| log.fetch("message", "").include?("X-Repeat:") }
  raise "Repeated HTTP headers missing or flattened" unless http && http.fetch("message").include?("X-Repeat: one\nX-Repeat: two")
  card = http.fetch("message")
  raise "Response-first RP HTTP card missing" unless card.index('"accepted"') && card.index('"accepted"') < card.index("https://example.test/orders") && card.index('"accepted"') < card.index('"order"')
  http_error = logs.find { |log| log.fetch("message", "").include?("ERROR_RESPONSE_BODY") }
  raise "HTTP ERROR missing or decorated" unless http_error && !["<span", "<details"].any? { |tag| http_error.fetch("message").include?(tag) }
  raise "Whitespace labels absent in actual RP assertion" unless all_text.include?("empty string") && all_text.include?("whitespace only")
  raise "Shallow key delta absent in actual RP assertion" unless all_text.include?("missing in actual: `gone`") && all_text.include?("extra in actual: `extra`") && all_text.include?("changed: `changed`")
  previews = %w[qa-340-lines.txt qa-48k.txt qa-25-lines.json].map do |name|
    entries = logs.select { |log| log.fetch("message", "").include?(name) && log["binaryContent"] }
    raise "F18 attachment missing or duplicated: #{name}" unless entries.length == 1
    log = entries.first
    digest = get("/api/v1/data/#{PROJECT}/#{log.fetch('binaryContent').fetch('id')}")
    { name: name, item_id: log.fetch("itemId"), log_id: log.fetch("id"), downloaded: digest,
      preview_message_sha256: Digest::SHA256.hexdigest(log.fetch("message")) }
  end
  write_safe("f18-previews.json", previews)
  raise "F18 line truncation notice missing" unless all_text.include?("first 100 lines")
  raise "F18 byte truncation notice missing" unless all_text.include?("first 16 KB of 48 KB")
  result[:counts] = { items: items.length, logs: logs.length, png_entries: expected.length }
  result[:status] = "PASS_RUNTIME_REQUIRES_DOM_REVIEW"
rescue StandardError => error
  result[:status] = "FAIL"
  result[:error] = "#{error.class}: #{error.message}".gsub(TOKEN, "[CREDENTIAL REMOVED]")
ensure
  write_safe("result.json", result)
  puts JSON.generate(result.reject { |key, _| %i[lib_sha256 runtime].include?(key) })
end
exit(result[:status] == "PASS_RUNTIME_REQUIRES_DOM_REVIEW" ? 0 : 1)
