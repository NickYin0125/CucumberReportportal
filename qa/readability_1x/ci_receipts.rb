# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"

root = File.expand_path("../..", __dir__)
out = File.expand_path(ARGV.fetch(0))
abort "Existing owned extension directory required" unless out.start_with?(File.join(root, "docs/reviews/assets/qa-1.3.3-ci-extension-")) && File.directory?(out)
repo = "NickYin0125/CucumberReportportal"
wrapper = "/private/tmp/rp-release-20261102/gh_safe.rb"
sha = "69aaedecd10a3ac01d7ad90b96e2db1b60343344"
base = "68e81d3697965305438be4fa27aa98aeb4baf726"
gh = lambda do |*arguments|
  stdout, stderr, status = Open3.capture3(RbConfig.ruby, wrapper, *arguments)
  raise "Read-only receipt command failed: #{stderr}" unless status.success?
  stdout
end
write = ->(path, value) { File.write(path, JSON.pretty_generate(value) + "\n") }
pr = JSON.parse(gh.call("pr", "view", "9", "--repo", repo, "--json", "number,url,state,isDraft,baseRefName,headRefName,headRefOid"))
raise "Wrong draft PR identity" unless pr.fetch("isDraft") && pr.fetch("baseRefName") == "maintenance/1.x" && pr.fetch("headRefOid") == sha
write.call(File.join(out, "draft-pr9.json"), pr)
runs = { "41634520578" => "old-pr", "41634383995" => "old-push", "41635045671" => "ci-pr", "41635035639" => "ci-push" }
records = runs.map do |id, label|
  directory = File.join(out, label)
  FileUtils.mkdir_p(directory)
  receipt_path = File.join(directory, "receipt.json")
  receipt = JSON.parse(File.file?(receipt_path) ? File.read(receipt_path) : gh.call("run", "view", id, "--repo", repo, "--json", "databaseId,headSha,status,conclusion,url,event,jobs,createdAt,updatedAt"))
  write.call(File.join(directory, "receipt.json"), receipt)
  expected_sha = label.start_with?("old") ? base : sha
  raise "Run source mismatch #{id}" unless receipt.fetch("headSha") == expected_sha
  raise "Remote run incomplete #{id}" unless receipt.fetch("status") == "completed"
  log_path = File.join(directory, "run.log")
  log = File.file?(log_path) ? File.read(log_path) : gh.call("run", "view", id, "--repo", repo, "--log")
  File.write(File.join(directory, "run.log"), log)
  clean = log.gsub(/\e\[[0-9;]*m/, "")
  matrix_jobs = receipt.fetch("jobs").select { |job| job.fetch("name").include?("matrix (Ruby ") }
  raise "Wrong matrix cell count" unless matrix_jobs.length == 4
  if label.start_with?("old")
    errors = clean.lines.grep(/\$BUNDLE_GEMFILE.*does not exist/)
    raise "First setup failure missing" if errors.empty?
    skipped = matrix_jobs.all? do |job|
      job.fetch("steps").find { |step| step.fetch("name") == "Run full RSpec including installed packaging checks" }.fetch("conclusion") == "skipped"
    end
    raise "Old run unexpectedly executed RSpec" unless skipped && receipt.fetch("conclusion") == "failure"
    next({ id: id, label: label, url: receipt.fetch("url"), conclusion: "failure",
      classification: "pre-test setup-ruby failure; no full SDK counts claimed", setup_errors: errors.map(&:strip), full_rspec_skipped_all_cells: true })
  end
  raise "Remote CI failed #{id}" unless receipt.fetch("conclusion") == "success"
  locks = File.join(directory, "runtime-locks")
  unless File.directory?(locks)
    gh.call("run", "download", id, "--repo", repo, "--pattern", "runtime-lock-*", "--dir", locks)
  end
  cells = matrix_jobs.map do |job|
    name = job.fetch("name")
    ruby, cucumber = name.match(/Ruby ([\d.]+), Cucumber ([\d.]+)/).captures
    job_lines = clean.lines.select { |line| line.start_with?(name + "\t") }
    # gh may label every line UNKNOWN STEP. Actual runner command-group markers
    # plus API step results bind the summaries without guessing textual labels.
    groups = []
    job_lines.each do |line|
      marker = line.match(/##\[group\]Run (.*)/)
      groups << { command: marker[1].strip, lines: [] } if marker
      groups.last.fetch(:lines) << line unless groups.empty?
    end
    command_group = lambda do |command|
      selected = groups.select { |group| group.fetch(:command) == command }
      raise "Ambiguous/missing logged command #{name}/#{command}" unless selected.length == 1
      selected.first.fetch(:lines)
    end
    ["Run full RSpec including installed packaging checks", "Run full offline Cucumber profile",
     "Run release dependency isolation regressions", "Require unchanged tracked source"].each do |step_name|
      step = job.fetch("steps").find { |entry| entry.fetch("name") == step_name }
      raise "Remote step not successful: #{step_name}" unless step && step.fetch("conclusion") == "success"
    end
    summary = lambda do |step|
      values = command_group.call(step).filter_map do |line|
        match = line.match(/(\d+) examples?, (\d+) failures?(?:, (\d+) pending)?/)
        match && { examples: match[1].to_i, failures: match[2].to_i, pending: match[3].to_i }
      end
      raise "No actual summary for #{name}/#{step}" if values.empty?
      values.last
    end
    full = summary.call("bundle exec rspec")
    isolation = summary.call("bundle exec rspec script/release/spec")
    raise "Unexpected full count" unless full == { examples: 1879, failures: 0, pending: 0 }
    raise "Unexpected release isolation count" unless isolation == { examples: 9, failures: 0, pending: 0 }
    offline = command_group.call("bundle exec cucumber")
    raise "Missing full offline scenarios/steps" unless offline.any? { |line| line.include?("1 scenario (1 passed)") } && offline.any? { |line| line.include?("3 steps (3 passed)") }
    artifact = Dir[File.join(locks, "runtime-lock-ruby-#{ruby}-cucumber-#{cucumber}-*")]
    raise "Ambiguous exact runtime artifact" unless artifact.length == 1
    runtime = JSON.parse(File.read(File.join(artifact.first, "runtime.json")))
    lock = File.read(File.join(artifact.first, "Gemfile.lock"))
    expressions = lock.match(/^    cucumber-cucumber-expressions \(([^)]+)\)/)[1]
    raise "Wrong dependency selection" unless runtime.fetch("cucumber") == cucumber && runtime.fetch("sdk") == "1.3.3" && runtime.fetch("diff_lcs") == "1.6.2" && runtime.fetch("bundler") == "2.6.6" && Gem::Version.new(expressions) < Gem::Version.new("19")
    source_dependencies = File.readlines(File.join(artifact.first, "source-dependencies.sha256"), chomp: true).to_h do |line|
      digest, path = line.split(/\s+/, 2)
      actual = Digest::SHA256.file(File.join(out, "candidate-source", path)).hexdigest
      raise "Remote source dependency bytes differ" unless actual == digest
      [path, digest]
    end
    checkout = command_group.call("actions/checkout@v6").filter_map { |line| line.match(/\s([0-9a-f]{40})\s*$/)&.[](1) }.last
    raise "Missing actual checkout SHA" unless checkout
    commit = JSON.parse(gh.call("api", "repos/#{repo}/git/commits/#{checkout}"))
    write.call(File.join(directory, "checkout-#{checkout}.json"), commit)
    source_tree, error, status = Open3.capture3("git", "-C", "/Users/nick/Documents/crr-1.3.3", "rev-parse", "#{sha}^{tree}")
    raise "Remote checkout tree differs" unless status.success? && commit.fetch("tree").fetch("sha") == source_tree.strip
    { job_id: job.fetch("databaseId"), name: name, conclusion: job.fetch("conclusion"), full_rspec: full,
      release_isolation: isolation, offline: { scenarios: 1, steps: 3, all_passed: true },
      runtime: runtime, expressions: expressions, runtime_lock_sha256: Digest::SHA256.hexdigest(lock),
      source_dependency_sha256: source_dependencies, checkout_sha: checkout, checkout_tree_identical_to_ci_sha: true }
  end
  raise "Required gate failed" unless receipt.fetch("jobs").find { |job| job.fetch("name") == "test / test" }.fetch("conclusion") == "success"
  raise "Unexpected packaging execution" unless receipt.fetch("jobs").find { |job| job.fetch("name") == "test / bundle" }.fetch("conclusion") == "skipped"
  { id: id, label: label, url: receipt.fetch("url"), head_sha: sha, conclusion: "success", cells: cells,
    full_rspec_total: cells.sum { |cell| cell.fetch(:full_rspec).fetch(:examples) }, required_gate: "success", packaging: "skipped" }
end
write.call(File.join(out, "remote-summary.json"), ci_sha: sha, old_accepted_sha: base, draft_pr: pr, runs: records,
  read_only_access: true, credentials: "existing keychain credential in gh_safe child only; never printed or saved")
puts JSON.generate(evidence: out, runs: records.map { |record| record.slice(:id, :conclusion, :full_rspec_total) })
