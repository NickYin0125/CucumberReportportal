# frozen_string_literal: true

require_relative "final_release_common"
require_relative "live"

module FinalRelease202
  def self.trials
    verify
    authenticate
    input_paths = %w[Gemfile Gemfile.lock Gemfile.source cucumber.yml config helpers features bin test README.md verification.md .gitignore].flat_map do |name|
      full = File.join(TRIAL, name)
      File.directory?(full) ? Dir.glob(full + "/**/*").select { |p| File.file?(p) } : [full]
    end
    manifest = input_paths.sort.map { |p| { path: p.delete_prefix(TRIAL + "/"), sha256: Digest::SHA256.file(p).hexdigest } }
    consumer = File.join(OUT, "current_sdk")
    raise "Consumer already exists" if File.exist?(consumer)
    input_paths.each do |path|
      target = File.join(consumer, path.delete_prefix(TRIAL + "/"))
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(path, target)
    end
    File.symlink(File.join(TRIAL, "node_modules"), File.join(consumer, "node_modules"))
    write(File.join(OUT, "trial-inputs.json"), source: TRIAL, files: manifest, manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(manifest)))
    env = { "PATH" => File.dirname(RbConfig.ruby) + ":" + ENV.fetch("PATH"), "GEM_HOME" => GEMHOME,
      "GEM_PATH" => ([GEMHOME] + Gem.path).uniq.join(File::PATH_SEPARATOR), "BUNDLE_APP_CONFIG" => File.join(OUT, "bundle-config"),
      "SDK_REF" => SHA, "SDK_SOURCE_ROOT" => SOURCE, "EXPECTED_SDK_INSTALL_ROOT" => GEMHOME,
      "SDK_GEM_ARCHIVE" => File.join(SOURCE, "reportportal-cucumber-ruby-2.0.2.gem"),
      "RP_ENABLED" => "false", "RP_CLIENT_JOIN" => "false", "RP_RERUN" => "false", "RP_CONSOLE_MIRROR" => "false",
      "RP_DEBUG_CURL_MODE" => "false", "CUCUMBER_PUBLISH_ENABLED" => "false", "CUCUMBER_PUBLISH_QUIET" => "true" }
    runtime = command(RbConfig.ruby, "bin/runtime", chdir: consumer, env: env)
    write(File.join(OUT, "trial-installed-runtime.json"), runtime.merge(sdk_ref: SHA))
    raise "Trial installed runtime not bound" unless runtime[:exit] == 0 && JSON.parse(runtime[:stdout])["source_matches"]
    rows = [["api-plain", "trial_api", "plain"], ["ui-plain", "trial_ui", "plain"],
      ["api-rich", "trial_api", "rich"], ["ui-rich", "trial_ui", "rich"],
      ["independent-api", "tester_api", "rich"], ["independent-ui", "tester_ui", "rich"]]
    rows.each do |label, profile, mode|
      verify
      directory = File.join(OUT, "trials", label)
      raise "Trial output exists" if File.exist?(directory)
      FileUtils.mkdir_p(directory)
      wire = LedgerQA::Wire.new(project: PROJECT, upstream: ENDPOINT)
      child_env = env.merge("RP_API_KEY" => ENV.fetch("RP_API_KEY"), "RP_ENABLED" => "true", "RP_ENDPOINT" => wire.endpoint, "RP_PROJECT" => PROJECT,
        "RP_PRESENTATION" => mode, "RP_RUN_CONTEXT" => (mode == "rich").to_s, "RP_SOURCE_COMMIT" => SHA,
        "RP_LAUNCH" => "ledger-developer-final-release-current_sdk-#{label}-8f44c10",
        "RP_ATTRIBUTES" => "trial:2.0.2,suite:#{profile},presentation:#{mode},runtime:#{SHA},run:final-contract-20261102",
        "RP_SPOOL_DIR" => File.join(directory, "spool"), "REPORT_DIR" => File.join(directory, "native"),
        "RP_REQUIRE_COMPLETE_REPORTING" => "true", "RP_FAIL_ON_REPORTING_ERROR" => "true", "NO_COLOR" => "1")
      process = command(RbConfig.ruby, "-rbundler/setup", "-e", 'load Gem.bin_path("cucumber", "cucumber")', "--", "--profile", profile,
        chdir: consumer, env: child_env, seconds: 180)
      wire.close
      write(File.join(directory, "process.json"), process)
      write(File.join(directory, "wire.json"), wire.records)
      snapshot = wire.snapshot
      write(File.join(directory, "snapshot.json"), snapshot)
      problems = Ledger202Live.safety(JSON.parse(JSON.generate(snapshot)), JSON.parse(JSON.generate(wire.records)))
      problems << "incomplete_execution" unless [0, 1].include?(process[:exit]) && !process[:signal]
      problems << "missing_launch" unless snapshot[:launches].length == 1
      problems << "hanging_items" if snapshot[:items].any? { |i| i["status"] == "IN_PROGRESS" || !i["endTime"] }
      problems << "hanging_launch" if snapshot[:launches].any? { |i| i["status"] == "IN_PROGRESS" || !i["endTime"] }
      launch = snapshot[:launches].first
      result = { label: label, profile: profile, mode: mode, source_sha: SHA, launch_id: launch && launch["id"],
        url: launch && "#{ENDPOINT}/ui/##{PROJECT}/launches/all/#{launch['id']}", exit: process[:exit],
        item_count: snapshot[:items].length, log_count: snapshot[:logs].length, file_count: snapshot[:files].length,
        problems: problems, status: problems.empty? ? "CAPTURED" : "FAIL" }
      write(File.join(directory, "result.json"), result)
      puts JSON.generate(result)
      $stdout.flush
      raise "Trial safety gate" unless problems.empty?
    ensure
      wire&.close
    end
    unchanged = manifest.all? { |r| Digest::SHA256.file(File.join(TRIAL, r[:path])).hexdigest == r[:sha256] && Digest::SHA256.file(File.join(consumer, r[:path])).hexdigest == r[:sha256] }
    write(File.join(OUT, "trial-inputs-postrun.json"), unchanged: unchanged, source_sha: SHA)
    raise "Trial inputs changed" unless unchanged
  end
end

FinalRelease202.trials if $PROGRAM_NAME == __FILE__
