# frozen_string_literal: true

require "bundler/setup"
require "optparse"
require "securerandom"
require "time"
require "socket"
require "tmpdir"
require_relative "support"
require_relative "reconcile"
require_relative "auth"
require_relative "wire_observer"

module Day2Endurance
  ROOT = File.expand_path("../..", __dir__)
  def self.evidence_root(environment: ENV)
    root = environment.fetch("DAY2_EVIDENCE_DIR", File.join(Dir.tmpdir, "reportportal-day2-endurance"))
    raise ArgumentError, "DAY2_EVIDENCE_DIR must be a nonempty absolute single-line path" unless root.is_a?(String) && !root.empty? && !root.match?(/[[:cntrl:]]/) && Pathname.new(root).absolute?
    File.expand_path(root)
  end

  def self.source_manifest
    files = Dir[File.join(ROOT, "lib/**/*.rb")] + Dir[File.join(__dir__, "**/*")]
    files += Dir[File.join(ROOT, "features/duration/**/*")]
    files += Dir[File.join(ROOT, "features/step_definitions/duration_*_steps.rb")]
    files << File.join(ROOT, "features/support/clearing_mock_server.rb")
    files.select { |path| File.file?(path) }.sort.to_h do |path|
      [path.delete_prefix(ROOT + "/"), Digest::SHA256.file(path).hexdigest]
    end
  end

  def self.run(arguments)
    options = { mode: "smoke", seconds: 900, iterations: 750, seed: 20261013,
                endpoint: ENV["RP_ENDPOINT"], project: ENV.fetch("RP_PROJECT", "superadmin_personal") }
    OptionParser.new do |parser|
      parser.on("--mode MODE") { |value| options[:mode] = value }
      parser.on("--endpoint URL") { |value| options[:endpoint] = value }
      parser.on("--project NAME") { |value| options[:project] = value }
      parser.on("--seconds N", Float) { |value| options[:seconds] = value }
      parser.on("--iterations N", Integer) { |value| options[:iterations] = value }
      parser.on("--seed N", Integer) { |value| options[:seed] = value }
    end.parse!(arguments)
    raise "Mode must be smoke, rp-smoke or live" unless %w[smoke rp-smoke live].include?(options[:mode])
    live = options[:mode] == "live"
    reporting = options[:mode] != "smoke"
    raise "Live acceptance requires >=900 real seconds" if live && (!options[:seconds].finite? || options[:seconds] < 900)
    raise "Live acceptance requires 500-1000 iterations" if live && !(500..1000).cover?(options[:iterations])
    if reporting
      Auth.validate_endpoint!(options[:endpoint])
    end
    Auth.validate_project!(options[:project])
    scratch = evidence_root
    FileUtils.mkdir_p(scratch, mode: 0o700)
    directory = File.join(scratch, "#{options[:mode]}-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}-#{SecureRandom.hex(3)}")
    Dir.mkdir(directory, 0o700)
    name = "day2-endurance-#{File.basename(directory)}"
    bearer = nil
    if reporting
      bearer, auth_source = Auth.resolve(endpoint: options.fetch(:endpoint), directory: directory)
      Reconciler.new(endpoint: options.fetch(:endpoint), bearer: bearer, project: options[:project]).response("api/v1/project/#{options[:project]}")
    end
    mock_port = TCPServer.open("127.0.0.1", 0) { |socket| socket.addr.fetch(1) }
    mock_url = "http://127.0.0.1:#{mock_port}"
    environment = {
      "RP_ENABLED" => reporting.to_s, "RP_ENDPOINT" => options[:endpoint].to_s, "RP_PROJECT" => options[:project],
      "RP_API_KEY" => bearer.to_s, "RP_LAUNCH" => name, "RP_CLIENT_JOIN" => "false", "RP_CONSOLE_MIRROR" => "false",
      "RP_REQUIRE_COMPLETE_REPORTING" => "true", "RP_FAIL_ON_REPORTING_ERROR" => "false",
      "RP_LAUNCH_UUID" => nil, "RP_REPORTING_ASYNC" => "false", "RP_RERUN" => "false", "RP_RERUN_OF" => nil,
      "RP_QUEUE_MAX_RECORDS" => ENV.fetch("DAY2_QUEUE_MAX_RECORDS", "128"),
      "RP_QUEUE_MAX_BYTES" => ENV.fetch("DAY2_QUEUE_MAX_BYTES", "8388608"),
      "RP_BATCH_MAX_BYTES" => "2097152", "RP_BATCH_SIZE_LOGS" => "20", "RP_FLUSH_INTERVAL" => "0.2",
      "RP_EXIT_FLUSH_TIMEOUT_MS" => "60000", "RP_SPOOL_DIR" => File.join(directory, "spool"),
      "RP_CONFIG" => File.join(directory, "empty-config.yaml"), "RP_DEBUG_CURL_MODE" => "false",
      "CLEARING_MOCK_AUTOSTART" => "true", "CLEARING_MOCK_DISABLED" => "false", "CLEARING_MOCK_URL" => mock_url,
      "CLEARING_MOCK_DISABLE_CHAOS" => "true", "CLEARING_MOCK_LATENCY_SCALE" => "0.01",
      "DURATION_REGRESSION_BASE_URL" => mock_url,
      "DURATION_REGRESSION_SMOKE" => (!live).to_s, "DURATION_REGRESSION_ITERATIONS" => (live ? options[:iterations] : 8).to_s,
      "DURATION_REGRESSION_SEED" => options[:seed].to_s, "CUCUMBER_PUBLISH_ENABLED" => "false", "CUCUMBER_PUBLISH_QUIET" => "true"
    }
    previous = environment.keys.to_h { |key| [key, ENV[key]] }
    File.write(environment.fetch("RP_CONFIG"), "{}\n", mode: "w", perm: 0o600)
    environment.each { |key, value| ENV[key] = value }
    manifest = source_manifest
    require "reportportal_cucumber"
    raise "Bundler must load the root SDK source" unless Gem.loaded_specs.fetch("reportportal-cucumber-ruby").full_gem_path == ROOT
    if reporting
      config = ReportportalCucumber::Config.load
      self.wire_observer = WireObserver.new(endpoint: config.endpoint, project: config.project, directory: directory,
                                            max_bytes: config.batch_max_bytes, max_entries: config.batch_size_logs)
    end
    self.session = Session.new(directory: directory, target_seconds: live ? options[:seconds] : 0,
                               warmup: live ? Float(ENV.fetch("DAY2_WARMUP_SECONDS", "120")) : 0,
                               rss_max_mb: Float(ENV.fetch("DAY2_RSS_MAX_MB", "768")),
                               rss_slope_mb_min: Float(ENV.fetch("DAY2_RSS_SLOPE_MB_MIN", "8")),
                               threads_max: Integer(ENV.fetch("DAY2_THREADS_MAX", "32")))
    require "cucumber/cli/main"
    args = ["--no-profile", "--publish-quiet", "--require", File.join(__dir__, "bootstrap.rb"),
            "--require", File.join(ROOT, "features/support/clearing_mock_server.rb")]
    Dir[File.join(ROOT, "features/step_definitions/duration_*_steps.rb")].sort.each { |path| args.concat(["--require", path]) }
    args.concat(["--format", "progress", "--out", File.join(directory, "progress.txt"),
                 "--format", "json", "--out", File.join(directory, "cucumber.json"),
                 "--format", "message", "--out", File.join(directory, "messages.ndjson"),
                 "--format", "html", "--out", File.join(directory, "cucumber.html"),
                 "--format", "Day2Endurance::Formatter", "--out", File.join(directory, "reportportal.txt"),
                 File.join(ROOT, "features/duration/clearing_endpoint_contract.feature"),
                 File.join(ROOT, "features/duration/clearing_workflow.feature"),
                 File.join(ROOT, "features/duration/clearing_pbt.feature")])
    native_exit = 2
    File.open(File.join(directory, "console.log"), "w", 0o600) do |console|
      old_out, old_err = $stdout, $stderr
      private_console = PrivateOutput.new(console, bearer: bearer)
      $stdout = $stderr = private_console
      begin
        Cucumber::Cli::Main.new(args, private_console, private_console).execute!
      rescue SystemExit => error
        native_exit = error.status
      ensure
        $stdout, $stderr = old_out, old_err
      end
    end
    run_elapsed = session.elapsed
    receipt = formatter&.reporting_receipt&.to_h || { complete: false, confirmed: 0 }
    result = { mode: options[:mode], seed: options[:seed], pid: Process.pid, native_exit: native_exit,
               elapsed_seconds: run_elapsed, requested_seconds: live ? options[:seconds] : 0, auth_source: auth_source,
               receipt: receipt, final_queue: formatter&.reporting_diagnostics, artifacts: session.artifacts,
               configured_limits: formatter&.config&.then { |config| { queue_max_records: config.queue_max_records, queue_max_bytes: config.queue_max_bytes, batch_max_bytes: config.batch_max_bytes, batch_size_logs: config.batch_size_logs } },
               versions: Gem.loaded_specs.slice("cucumber", "cucumber-cucumber-expressions", "reportportal-cucumber-ruby").transform_values { |gem| gem.version.to_s },
               sdk_source_root: Gem.loaded_specs.fetch("reportportal-cucumber-ruby").full_gem_path,
               source_sha256: manifest, source_unchanged: source_manifest == manifest }
    acceptance_error = nil
    begin
      raise "Native Cucumber failed with exit #{native_exit}" unless native_exit.zero?
      Day2Endurance.check("executed source unchanged", result.fetch(:source_unchanged))
      session.sample("native-finalized")
      Day2Endurance.check("real monotonic duration", run_elapsed >= options[:seconds]) if live
      result[:resources] = session.resource_checks if live
      if reporting
        result[:wire] = wire_observer.summary
        wire_observer.validate!(receipt: receipt, sent_batches: formatter.reporting_diagnostics.fetch(:counters).fetch(:sent_batches))
        Day2Endurance.check_minimum_logs(receipt: receipt, iterations: live ? options[:iterations] : 8)
        reconciler = Reconciler.new(endpoint: options.fetch(:endpoint), bearer: bearer, project: options[:project])
        result[:reconciliation] = reconciler.run(
          name: name, receipt: receipt, native: JSON.parse(File.read(File.join(directory, "cucumber.json"))),
          artifacts: session.artifacts, pbt: JSON.parse(File.read(File.join(directory, "pbt.json"))))
      end
      if bearer
        Day2Endurance.check("bearer absent from native and diagnostic evidence", Dir[File.join(directory, "**/*")].select { |path| File.file?(path) }.none? { |path| File.binread(path).include?(bearer) })
      end
    rescue StandardError => error
      acceptance_error = error
      result[:failure] = { class: error.class.name, message: error.message }
      result[:reconciliation] ||= reconciler.observed if reconciler
    end
    result[:resources] ||= session.resource_result if session.resource_result
    result[:wire] ||= wire_observer.summary if wire_observer
    result[:checks] = session.checks.tally
    result[:passed] = native_exit.zero? && acceptance_error.nil?
    encoded = JSON.pretty_generate(result)
    raise "Credential leak refused" if bearer && encoded.include?(bearer)
    File.write(File.join(directory, "result.json"), encoded, mode: "w", perm: 0o600)
    File.write(File.join(directory, "receipt.json"), JSON.pretty_generate(receipt), mode: "w", perm: 0o600)
    puts "#{options[:mode]} passed=#{result[:passed]} native_exit=#{native_exit} elapsed=#{run_elapsed}s evidence=#{directory}"
    puts "Acceptance failure: #{acceptance_error.message}" if acceptance_error
    native_exit.zero? ? (acceptance_error ? 1 : 0) : native_exit
  ensure
    self.wire_observer = nil
    previous&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

exit Day2Endurance.run(ARGV) if $PROGRAM_NAME == __FILE__
