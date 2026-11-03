# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "securerandom"
require "time"

root = File.expand_path("../..", __dir__)
stamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ") + "-" + SecureRandom.hex(2)
out = File.join(root, "docs/reviews/assets/qa-1.3.3-environment-#{stamp}")
FileUtils.mkdir_p(out)
bases = {
  "3.1" => "sha256:7849744f16559a7fc88547a7f6f0b55ea853ee8130b002ff67f59c73c643656c",
  "3.3" => "sha256:ce3b866e0d22c71ec576f9de6d6860be38a73b445df80ae1e0318f08a988848d"
}
results = {}
puts "QA_ENVIRONMENT_EVIDENCE=#{out}"
$stdout.sync = true
bases.each do |series, base|
  name = "ruby#{series.delete('.')}"
  base_alias = "local/crr-qa-1x-base-#{name}:#{base.delete_prefix('sha256:')[0, 12]}"
  raise "Cannot alias existing pinned base" unless system("/usr/local/bin/docker", "image", "tag", base, base_alias)
  verified, verification = Open3.capture2("/usr/local/bin/docker", "image", "inspect", base_alias, "--format", "{{.Id}}")
  raise "Local base alias changed bytes" unless verification.success? && verified.strip == base
  tag = "local/crr-qa-1x-#{name}-tools:#{stamp.downcase}"
  build = ["/usr/local/bin/docker", "build", "--pull=false", "--platform", "linux/arm64", "--progress", "plain",
    "--build-arg", "BASE_IMAGE=#{base_alias}", "--tag", tag, "--file", File.join(__dir__, "environment/Dockerfile"), File.join(__dir__, "environment")]
  File.write(File.join(out, "#{name}-build-command.json"), JSON.pretty_generate(build) + "\n")
  puts "Preparing independent #{series} tools image"
  raise "Image build failed; retain #{name}-build.log" unless system(*build, out: File.join(out, "#{name}-build.log"), err: [:child, :out])
  inspected, status = Open3.capture2("/usr/local/bin/docker", "image", "inspect", tag)
  raise "Cannot inspect prepared image" unless status.success?
  image = JSON.parse(inspected).fetch(0)
  raise "Wrong architecture" unless image.fetch("Architecture") == "arm64" && image.fetch("Os") == "linux"
  File.write(File.join(out, "#{name}-image-inspect.json"), inspected)
  id = image.fetch("Id")
  command = ["/usr/local/bin/docker", "run", "--rm", "--network", "none", "--cpus", "1", "--memory", "1g",
    "-v", "#{__dir__}:/qa:ro", "-v", "#{out}:/evidence", "-v", "/private/tmp/ledger-pinned-tools/linux-arm64:/tools:ro",
    "-e", "PATH=/tools:/usr/local/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    "-e", "QA_RUBY=#{series}", "-e", "QA_PREFLIGHT_OUT=/evidence/#{name}-tools.json", id, "ruby", "/qa/preflight.rb"]
  File.write(File.join(out, "#{name}-preflight-command.json"), JSON.pretty_generate(command) + "\n")
  raise "Prepared image preflight failed" unless system(*command, out: File.join(out, "#{name}-preflight.log"), err: [:child, :out])
  result = JSON.parse(File.read(File.join(out, "#{name}-tools.json")))
  raise "Tool check did not pass" unless result.fetch("status") == "PASS"
  results[series] = { "image" => id, "base_image" => base, "base_alias" => base_alias, "tag" => tag,
    "tool_preflight" => File.join(out, "#{name}-tools.json"), "tools" => result.fetch("tools") }
  File.write(File.join(out, "images.json"), JSON.pretty_generate(results) + "\n")
  puts JSON.generate(ruby: series, image: id, jq: result.fetch("tools").fetch("jq"), status: "PREFLIGHT_PASS")
end
File.write(File.join(__dir__, "environment/images.json"), JSON.pretty_generate(results) + "\n")
puts "Pinned image selection is ready; no SDK tests or RP launches were executed"
