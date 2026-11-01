# frozen_string_literal: true

require "fileutils"
require "open3"
require "optparse"
require "rbconfig"
require "time"
require "timeout"
require_relative "presentation_ledger_developer/fixtures"
require_relative "presentation_ledger_developer/wire"
require_relative "presentation_ledger_developer/testcards"

module LedgerDeveloper
  class Runner
    HOME = File.join(__dir__, "presentation_ledger_developer")
    BOOTSTRAP = "require #{File.join(HOME, 'activation.rb').dump}; LedgerDeveloper::Activation.activate!; ".freeze
    PROBE = BOOTSTRAP + <<~'RUBY'
      require "json"
      require "cucumber"
      require "cucumber/glue/dsl"
      require "reportportal_cucumber"
      puts JSON.generate(ruby: RUBY_DESCRIPTION, ruby_version: RUBY_VERSION,
        cucumber: Gem.loaded_specs.fetch("cucumber").version.to_s, sdk: ReportportalCucumber::VERSION,
        cucumber_expressions: Gem.loaded_specs.fetch("cucumber-cucumber-expressions").version.to_s,
        activation: LedgerDeveloper::Activation.provenance,
        named_hooks: Cucumber::Glue::Dsl.instance_method(:Before).parameters.include?([:key, :name]),
        gems: Gem.loaded_specs.transform_values { |g| {version: g.version.to_s, path: g.full_gem_path} })
    RUBY
    CLI = BOOTSTRAP + 'load Gem.bin_path("cucumber", "cucumber", ENV.fetch("LEDGER_CUCUMBER"))'

    def initialize(argv)
      @options = { transport: "offline", mode: "plain", fixtures: "smoke", sdk_root: ROOT,
                   ruby: RbConfig.ruby, cucumber: "10.2.0", batch_size: 20 }
      parser = OptionParser.new do |o|
        o.banner = "Developer rendering fixtures, NOT independent acceptance.\nUsage: ruby script/acceptance/presentation_ledger_developer.rb [options]\n" \
                   "Exit: 0 expected execution (including evidenced owner-approved native grammar N/A); 1 unexpected result; 2 harness/config error; 3 unsupported selection.\n" \
                   "Legacy F02/F03 automatically retain native parser probes and run separately labelled argument-step companions.\n" \
                   "Offline is default. Live writes require main-author approval of the exact command, plus --authorize-live-writes.\n" \
                   "RP_API_KEY is the only live credential source. No old launches are joined or changed."
        o.on("--transport MODE", %w[offline live]) { |v| @options[:transport] = v }
        o.on("--mode MODE", %w[plain rich default]) { |v| @options[:mode] = v }
        o.on("--fixtures IDS", "smoke (portable passing shapes), all, negative, or comma-separated F01/F10a/etc") { |v| @options[:fixtures] = v }
        o.on("--sdk-root PATH", "Read a candidate or baseline source tree without changing it") { |v| @options[:sdk_root] = File.expand_path(v) }
        o.on("--ruby PATH") { |v| @options[:ruby] = File.expand_path(v) }
        o.on("--cucumber VERSION", "Exact installed 9.x/10.x version (1.x default: 10.2.0); use --cucumber 9.2.1 for Cucumber 9") { |v| @options[:cucumber] = v }
        o.on("--gem-path PATH", "Existing dependencies; no bundle install or lockfile changes") { |v| @options[:gem_path] = v }
        o.on("--png-dir PATH", "Existing C12 visible-pngs, copied byte-for-byte; otherwise deterministic C12 generator") { |v| @options[:png_dir] = File.expand_path(v) }
        o.on("--jpeg PATH", "Exact historical after-failure JPEG (754x790, 36612 B)") { |v| @options[:jpeg] = File.expand_path(v) }
        o.on("--progressive-jpeg PATH", "Override bundled 2x2 SOF2 JPEG for F17; raw bytes preserved") { |v| @options[:progressive_jpeg] = File.expand_path(v) }
        o.on("--batch-size N", Integer) { |v| @options[:batch_size] = v }
        o.on("--output PATH", "New directory under #{HOME}/evidence only") { |v| @options[:output] = File.expand_path(v) }
        o.on("--authorize-live-writes", "Use ONLY after main author approves this exact invocation") { @options[:authorized] = true }
        o.on("--list", "Print fixture catalog without running or writing") { @options[:list] = true }
        o.on("--help") { puts o; @options[:help] = true }
      end
      parser.parse!(argv)
      raise ArgumentError, "Unexpected positional arguments" unless argv.empty?
    end

    def write(path, data)
      text = JSON.pretty_generate(data) + "\n"
      secret = ENV["RP_API_KEY"].to_s
      raise "Credential found in evidence; refusing write" if !secret.empty? && text.include?(secret)
      File.write(path, text, mode: "w", perm: 0o600)
    end

    def environment
      env = ENV.to_h.select { |key, _| %w[PATH HOME TMPDIR GEM_HOME GEM_PATH LANG LC_ALL].include?(key) }
      env["GEM_PATH"] = @options[:gem_path] if @options[:gem_path]
      env.merge("LEDGER_CUCUMBER" => @options[:cucumber], "LEDGER_SDK_ROOT" => @options[:sdk_root], "CUCUMBER_PUBLISH_ENABLED" => "false",
                "CUCUMBER_PUBLISH_QUIET" => "true", "NO_COLOR" => "1", "RP_ENABLED" => "false")
    end

    def execute(env, command, directory)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      stdout = stderr = status = nil
      timed_out = false
      Open3.popen3(env, *command, chdir: directory, unsetenv_others: true, pgroup: true) do |input, output, errors, child|
        input.close
        readers = [Thread.new { output.read }, Thread.new { errors.read }]
        begin
          Timeout.timeout(90) { status = child.value }
        rescue Timeout::Error
          timed_out = true
          Process.kill("KILL", -child.pid)
          status = child.value
        ensure
          stdout, stderr = readers.map(&:value)
        end
      end
      { command: command, exit: status.exitstatus, signal: status.termsig, timed_out: timed_out,
        seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - start, stdout: stdout, stderr: stderr }
    end

    def select_rows
      catalog = LedgerDeveloper.catalog
      selected = case @options[:fixtures]
                 when "all" then catalog
                 when "smoke" then catalog.reject { |row| row[:negative] || row[:unsupported] || row[:media] == :progressive || row[:native_global_hooks] }
                 when "negative" then catalog.select { |row| row[:negative] }
                 else
                   names = @options[:fixtures].split(",")
                   names.each do |name|
                     raise "Unknown fixture selection #{name}" unless catalog.any? { |row| row[:id] == name || row[:id][0, 3] == name }
                   end
                   catalog.select { |row| names.include?(row[:id]) || names.include?(row[:id][0, 3]) }
                 end
      selected
    end

    def media
      directory = File.join(@output, "media")
      Dir.mkdir(directory)
      rows = (1..10).map do |index|
        name = format("screenshot-%02d.png", index)
        source = @options[:png_dir] && File.join(@options[:png_dir], name)
        bytes = source ? File.binread(source) : Testcards.png(index)
        raise "Expected exact 640x360 PNG testcard" unless bytes.start_with?("\x89PNG\r\n\x1a\n".b) && bytes[16, 8].unpack("NN") == [640, 360]
        raise "Historical PNG testcard bytes differ" unless Digest::SHA256.hexdigest(bytes) == Testcards::SHA256.fetch(index - 1)
        File.binwrite(File.join(directory, name), bytes)
        { name: name, mime: "image/png", source: source || "script/acceptance/presentation_ledger_developer/testcards.rb png(#{index})",
          bytes: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes) }
      end
      %i[jpeg progressive_jpeg].each do |key|
        next if key == :jpeg && !@options[key]
        source = @options[key] || File.join(HOME, "progressive_jpeg.json")
        bytes = @options[key] ? File.binread(source) : Base64.strict_decode64(JSON.parse(File.read(source)).fetch("base64"))
        raise "Explicit JPEG MIME requires JPEG signature" unless bytes.start_with?("\xFF\xD8\xFF".b)
        raise "F04 historical JPEG bytes differ" if key == :jpeg && Digest::SHA256.hexdigest(bytes) != "8c472e5064d09cd6d7f8aca0ce5da74e4ff29073ac5f8f45ae96093f46bed1a9"
        raise "F17 requires SOF2 progressive JPEG" if key == :progressive_jpeg && !jpeg_sof(bytes).any? { |marker, _, _| marker == 0xc2 }
        name = "#{key}.jpg"
        File.binwrite(File.join(directory, name), bytes)
        rows << { name: name, mime: "image/jpeg", source: source, bytes: bytes.bytesize,
                  sha256: Digest::SHA256.hexdigest(bytes), sof: jpeg_sof(bytes) }
      end
      write(File.join(directory, "provenance.json"), rows)
      rows
    end

    def git_read(*args)
      root, found = Open3.capture2e("git", "-C", @options[:sdk_root], "rev-parse", "--show-toplevel")
      return nil unless found.success? && File.realpath(root.strip) == File.realpath(@options[:sdk_root])
      output, status = Open3.capture2e("git", "-C", @options[:sdk_root], *args)
      status.success? ? output.strip : nil
    rescue Errno::ENOENT
      nil
    end

    def jpeg_sof(bytes)
      position, frames = 2, []
      while position + 4 <= [bytes.bytesize, 65_536].min
        break unless bytes.getbyte(position) == 0xff
        position += 1 while bytes.getbyte(position) == 0xff
        marker = bytes.getbyte(position)
        position += 1
        break if [0xda, 0xd9].include?(marker)
        next if marker == 0x01 || (0xd0..0xd7).cover?(marker)
        length = bytes[position, 2].unpack1("n")
        break if length < 2 || position + length > bytes.bytesize
        if [0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].include?(marker)
          height, width = bytes[position + 3, 4].unpack("nn")
          frames << [marker, width, height]
        end
        position += length
      end
      frames
    end

    def blocked_reason(row)
      return row[:unsupported] if row[:unsupported]
      return "Installed native Before DSL has no name keyword" if row[:named_hooks] && !@runtime["named_hooks"]
      return "Native global hook logging requires Cucumber 12; legacy BeforeAll has no World log context" if row[:native_global_hooks] && @runtime.fetch("cucumber").to_i < 12
      return "Exact historical JPEG required via --jpeg" if %i[jpeg progressive].include?(row[:media]) && !@options[:jpeg]
      nil
    end

    def native_parser_probe(row, directory)
      probes = row.fetch(:native_parser_sources).map do |order, source|
        scratch = File.join(directory, "native-parser", order)
        FileUtils.mkdir_p(scratch)
        File.write(File.join(scratch, "native.feature"), source)
        command = [@options[:ruby], "-e", CLI, "--", "--no-profile", "--publish-quiet", "--dry-run",
                   "--require", File.join(HOME, "support.rb"), "--format", "progress", "native.feature"]
        # Resolve the selected SDK's dependencies, but install no RP formatter,
        # World, hooks, key, or observer for these grammar-only probes.
        process = execute(environment.merge(activation_environment(scratch)), command, scratch)
        write(File.join(scratch, "process.json"), process)
        token = order == "doc-first" ? "| key | value |" : '"""'
        rejected = process[:exit] == 2 && !process[:timed_out] &&
          process[:stderr].include?("Cucumber::Core::Gherkin::ParseError") && process[:stderr].include?("got '#{token}'")
        { order: order, source_sha256: Digest::SHA256.hexdigest(source), process: process,
          expected_parser_failure_observed: rejected }
      end
      observed = probes.all? { |probe| probe[:expected_parser_failure_observed] }
      harness_error = probes.any? { |probe| probe[:process][:timed_out] || probe[:process][:signal] ||
        (!probe[:expected_parser_failure_observed] && probe[:process][:exit] != 0) }
      evidence = { fixture: row[:id], runtime: @runtime, probes: probes, reporting_enabled: false,
                   owner_decision: "presentation-ledger-acceptance.md Decisions 4", companion: "#{row[:id]}-legacy-separate",
                   native_scope: observed ? "N/A: native parser rejection observed" : "not established", acceptance_verdict: "not_assessed" }
      write(File.join(directory, "native-parser-evidence.json"), evidence)
      { id: row[:id], execution: observed ? "native_compound_not_applicable" : (harness_error ? "harness_error" : "unexpected_result"),
        exit: observed ? 0 : (harness_error ? 2 : 1), parser_evidence: File.join(directory, "native-parser-evidence.json"),
        companion: "#{row[:id]}-legacy-separate", acceptance_verdict: "not_assessed" }
    end

    def child_environment(row, wire, directory)
      mode = row[:presentation] || @options[:mode]
      env = environment.merge(activation_environment(directory)).merge("LEDGER_DEVELOPER_RUN" => "1", "LEDGER_FIXTURE" => row[:id], "LEDGER_EVIDENCE" => directory,
                              "LEDGER_MEDIA" => File.join(@output, "media"), "LEDGER_JPEG" => File.join(@output, "media/jpeg.jpg"),
                              "LEDGER_PROGRESSIVE_JPEG" => File.join(@output, "media/progressive_jpeg.jpg"),
                              "RP_ENABLED" => "true", "RP_CONFIG" => File.join(@output, "empty-config.yml"),
                              "RP_ENDPOINT" => wire.endpoint, "RP_PROJECT" => @project,
                              "RP_API_KEY" => @options[:transport] == "live" ? ENV.fetch("RP_API_KEY") : SecureRandom.hex(24),
                              "RP_LAUNCH" => "ledger-developer-#{row[:id]}-#{@options[:mode]}-#{File.basename(@output)}",
                              "RP_REPORTING_ASYNC" => "false", "RP_CLIENT_JOIN" => "false", "RP_RERUN" => "false",
                              "RP_REQUIRE_COMPLETE_REPORTING" => "true", "RP_FAIL_ON_REPORTING_ERROR" => "true",
                              "RP_HTTP_RETRY_ATTEMPTS" => "1", "RP_BATCH_SIZE_LOGS" => @options[:batch_size].to_s,
                              "RP_SPOOL_DIR" => File.join(directory, "spool"), "RP_DEBUG_CURL_MODE" => "false",
                              "RP_VIDEO_UPLOAD_MODE" => "reportportal_multipart")
      env["RP_PRESENTATION"] = mode unless mode == "default"
      if row[:id].start_with?("F19") && row[:id] != "F19d"
        env.merge!("RP_RUN_CONTEXT" => "true", "GITHUB_REF_NAME" => "feature/ledger", "RP_SOURCE_COMMIT" => "e7dae2b1234567",
                   "GITHUB_RUN_ID" => "42", "PARALLEL_TEST_GROUPS" => "4")
        env["RP_ATTRIBUTES"] = "sdk:custom" if row[:id] == "F19b"
        env["RP_LAUNCH_DESCRIPTION"] = "Given description" if row[:id] == "F19c"
      end
      env
    end

    def activation_environment(directory)
      { "LEDGER_ACTIVATION_REPORT" => File.join(directory, "activation.json"),
        "LEDGER_EXPECTED_ACTIVATION" => File.join(@output, "probe-activation.json") }
    end

    def run_row(row)
      directory = File.join(@output, row.fetch(:id))
      FileUtils.mkdir_p(directory)
      write(File.join(directory, "fixture.json"), row.merge(source_sha256: Digest::SHA256.hexdigest(row[:source])))
      if row[:cucumber12] && @runtime.fetch("cucumber").to_i < 12
        result = native_parser_probe(row, directory)
        write(File.join(directory, "result.json"), result)
        return result
      end
      if (reason = blocked_reason(row))
        result = { id: row[:id], execution: "unsupported", reason: reason, exit: 3 }
        write(File.join(directory, "result.json"), result)
        return result
      end
      FileUtils.mkdir_p(File.join(directory, "features/presentation_ledger"))
      feature_path = "features/presentation_ledger/#{row.fetch(:id)}.feature"
      File.write(File.join(directory, feature_path), row.fetch(:source))
      wire = Wire.new(project: @project, upstream: @options[:transport] == "live" ? ENV.fetch("RP_ENDPOINT") : nil)
      command = [@options[:ruby], "-I", File.join(@options[:sdk_root], "lib"), "-e", CLI, "--",
                 "--no-profile", "--publish-quiet", "--require", File.join(HOME, "support.rb"),
                 "--format", "progress", "--format", "json", "--out", "native.json",
                 "--format", "message", "--out", "native.ndjson",
                 "--format", "ReportPortal::Cucumber::Formatter", "--out", "rp.out",
                 "--format", "LedgerDeveloper::Audit", "--out", "audit.out", feature_path]
      env = child_environment(row, wire, directory)
      write(File.join(directory, "sdk-provenance.json"), head: git_read("rev-parse", "HEAD"), worktree_status: git_read("status", "--short"))
      write(File.join(directory, "environment.json"), env.select { |key, _| key.start_with?("RP_", "LEDGER_", "GITHUB_", "PARALLEL_") && key != "RP_API_KEY" })
      process = execute(env, command, directory)
      write(File.join(directory, "process.json"), process)
      wire.close
      snapshot = wire.snapshot
      write(File.join(directory, "process.json"), process)
      write(File.join(directory, "wire.json"), wire.records)
      write(File.join(directory, "snapshot.json"), snapshot)
      result = evaluate(row, directory, process, wire, snapshot)
      write(File.join(directory, "result.json"), result)
      result
    rescue StandardError => error
      write(File.join(directory, "wire.json"), wire.records) if wire
      result = process_error(row, directory, process, "#{error.class}: #{error.message}")
      write(File.join(directory, "result.json"), result)
      result
    ensure
      wire&.close
    end

    def evaluate(row, directory, process, wire, snapshot)
      report = File.join(directory, "native.json")
      unless File.file?(report) && File.size(report).positive?
        return process_error(row, directory, process, "Native JSON report missing or empty")
      end
      begin
        native = JSON.parse(File.read(report))
      rescue JSON::ParserError => error
        return process_error(row, directory, process, "Invalid native JSON report: #{error.message}")
      end
      return process_error(row, directory, process, "Native JSON report is not an array") unless native.is_a?(Array)
      if process[:timed_out] || process[:signal] || ![0, 1].include?(process[:exit])
        return process_error(row, directory, process, "Child process did not complete normal Cucumber execution")
      end
      scenarios = native.flat_map { |feature| feature.fetch("elements", []) }.reject { |element| element["type"] == "background" }
      results = scenarios.flat_map { |scenario| %w[before steps after].flat_map { |key| scenario.fetch(key, []).map { |step| step["result"] }.compact } }
      failures = results.select { |r| r["status"] == "failed" }
      inputs_path = File.join(directory, "inputs.ndjson")
      inputs = File.file?(inputs_path) ? File.readlines(inputs_path).map { |line| JSON.parse(line) } : []
      expected_files = inputs.select { |input| %w[attachment attachment_input].include?(input["kind"]) }.map { |input| [input.fetch("sha256"), input.fetch("bytes"), input.fetch("mime")] }
      expected_files.concat(inputs.select { |input| input["kind"] == "evidence" }.flat_map do |input|
        input.fetch("artifacts").map do |artifact|
          bytes = Base64.strict_decode64(artifact.fetch("base64"))
          [Digest::SHA256.hexdigest(bytes), bytes.bytesize, artifact.fetch("mime")]
        end
      end)
      runtime = JSON.parse(File.read(File.join(directory, "runtime.json")))
      expected_exit = row[:failed].positive? ? 1 : 0
      checks = { expected_process_exit: process[:exit] == expected_exit && !process[:timed_out],
                 exact_scenario_count: scenarios.length == row[:scenarios],
                 exact_failure_count: failures.length == row[:failed],
                 exact_skipped_count: results.count { |r| r["status"] == "skipped" } == (row[:id] == "F04" ? 1 : 0),
                 no_undefined_pending_ambiguous: results.none? { |r| %w[undefined pending ambiguous].include?(r["status"]) },
                 expected_failure_marker: !row[:error] || failures.all? { |r| r.fetch("error_message", "").include?(row[:error]) },
                 exact_escaping_failures: row[:id] != "F14-negative" || failures.each_with_index.all? { |r, i| r.fetch("error_message").start_with?(LedgerDeveloper::ESCAPES.fetch(i) + " (RuntimeError)") },
                 selected_sdk_only: !runtime.fetch("loaded_sdk_files").empty? && runtime.fetch("loaded_sdk_files").all? { |path| File.realpath(path).start_with?(File.realpath(File.join(@options[:sdk_root], "lib")) + "/") },
                 dependency_activation_matches_probe: runtime["activation"] == @runtime.fetch("activation"),
                 sdk_unchanged_during_fixture: runtime["sdk_source_changed_during_fixture"] == false,
                 raw_attachment_bytes_and_mime: expected_files.sort == wire.records.flat_map { |r| r[:files] || [] }.map { |f| [f[:sha256], f[:bytes], f[:mime]] }.sort,
                 wire_recorded: !wire.records.empty?,
                 wire_success: wire.records.all? { |r| r[:status] && (200..299).cover?(r[:status]) },
                 one_new_launch: wire.launches.size == 1,
                 launch_finished: wire.records.count { |r| r[:method] == "PUT" && r[:path].end_with?("/finish") } == 1,
                 items_finished: wire.items.keys.sort == wire.records.select { |r| r[:method] == "PUT" && r[:path].match?(%r{/item/[^/]+$}) }.map { |r| r[:path].split("/").last }.sort }
      if @options[:transport] == "live"
        checks[:live_launch_finished] = snapshot.fetch(:launches).all? { |launch| launch["endTime"] }
        checks[:live_log_count] = snapshot.fetch(:logs).size == wire.records.sum { |r| (r[:entries] || []).size }
        checks[:live_attachment_bytes] = snapshot.fetch(:files).map { |f| [f[:sha256], f[:bytes]] }.sort == wire.records.flat_map { |r| r[:files] || [] }.map { |f| [f[:sha256], f[:bytes]] }.sort
      end
      checks[:receipt_complete] = runtime["receipt"]["complete"] == true if runtime["receipt"]
      if row[:legacy_companion_of]
        verified = inputs.select { |input| input["kind"] == "legacy_separate_verification" }
        checks[:separate_argument_data_and_order] = verified.length == row[:scenarios] && verified.all? { |input| input["verified"] }
      end
      { id: row[:id], execution: checks.values.all? ? (expected_exit == 1 ? "expected_failure_observed" : "observed") : "unexpected_result",
        exit: checks.values.all? ? 0 : 1, child_exit: process[:exit], checks: checks, launch_uuids: wire.launches,
        launch_ids: snapshot.fetch(:launches, []).map { |launch| launch["id"] }, item_uuids: wire.items.keys,
        limitations: row[:limitations], legacy_companion_of: row[:legacy_companion_of], acceptance_verdict: "not_assessed" }
    end

    def process_error(row, directory, process, detail)
      { id: row[:id], execution: "harness_error", exit: 2, error_class: "DeveloperProcessEvidenceError",
        report_error: detail, process_evidence: File.join(directory, "process.json"),
        child_exit: process && process[:exit], child_signal: process && process[:signal],
        child_timed_out: process && process[:timed_out], child_stdout: process && process[:stdout],
        child_stderr: process && process[:stderr], acceptance_verdict: "not_assessed" }
    end

    def run
      return 0 if @options[:help]
      selected = select_rows
      if @options[:list]
        puts JSON.pretty_generate(selected.map { |row| row.reject { |key, _| key == :source } })
        return 0
      end
      raise "Live command must be explicitly authorized by the main author" if @options[:transport] == "live" && !@options[:authorized]
      raise "Positive batch size required" unless @options[:batch_size].positive?
      @project = @options[:transport] == "live" ? ENV.fetch("RP_PROJECT") : "ledger_developer_offline"
      @output = @options[:output] || File.join(HOME, "evidence", "#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(4)}")
      raise "Output must be a new owned evidence directory" unless @output.start_with?(File.join(HOME, "evidence") + "/") && !File.exist?(@output)
      FileUtils.mkdir_p(@output, mode: 0o700)
      File.write(File.join(@output, "empty-config.yml"), "{}\n")
      probe = execute(environment, [@options[:ruby], "-I", File.join(@options[:sdk_root], "lib"), "-e", PROBE], @output)
      write(File.join(@output, "probe.json"), probe)
      raise "Runtime probe failed (exit #{probe[:exit]}); inspect probe.json\n#{probe[:stderr]}" unless probe[:exit] == 0
      @runtime = JSON.parse(probe[:stdout])
      write(File.join(@output, "probe-activation.json"), @runtime.fetch("activation"))
      major = @runtime.fetch("sdk").split(".").first
      cucumber = @runtime.fetch("cucumber").to_i
      selected = selected.flat_map { |row| row[:cucumber12] && cucumber < 12 ? [row, LedgerDeveloper.legacy_companion(row)] : [row] }
      sha = git_read("rev-parse", "HEAD")
      status = git_read("status", "--short")
      lib_hashes = Dir.glob(File.join(@options[:sdk_root], "lib/**/*.rb")).sort.to_h { |path| [path.delete_prefix(@options[:sdk_root] + "/"), Digest::SHA256.file(path).hexdigest] }
      harness_hashes = [__FILE__, *Dir.glob(File.join(HOME, "*.{rb,json}"))].sort.to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }
      write(File.join(@output, "provenance.json"), kind: "developer_smoke_not_acceptance", runtime: @runtime, options: @options,
            sdk_head: sha, sdk_worktree_status: status, sdk_lib_sha256: lib_hashes, harness_sha256: harness_hashes, frozen_baseline_reference: BASELINES.fetch(major),
            selected: selected.map { |row| row[:id] }, not_selected: LedgerDeveloper.catalog.map { |r| r[:id] } - selected.map { |r| r[:id] },
            decisions: ["Client generated <br> is allowed", "Rich examples override strict word ordering",
                        "Decision 4: legacy native compound N/A requires parser evidence and separate argument verification; 2.x native compound remains mandatory",
                        "No independent acceptance or waiver"],
            media: media)
      results = selected.map do |row|
        result = run_row(row)
        puts "#{row[:id]}: #{result[:execution]}"
        warn result[:child_stderr] if result[:exit] == 2 && result[:child_stderr] && !result[:child_stderr].empty?
        result
      end
      # Preserve synthetic SECRET123 test inputs; redact only a real API key if
      # any dependency unexpectedly emitted it. Such evidence is never success.
      credential_leak = false
      secret = ENV["RP_API_KEY"].to_s
      unless secret.empty?
        Dir.glob(File.join(@output, "**/*")).select { |p| File.file?(p) }.each do |path|
          bytes = File.binread(path)
          next unless bytes.include?(secret.b)
          credential_leak = true
          File.binwrite(path, bytes.gsub(secret.b, "[RP_API_KEY REMOVED]"))
        end
      end
      write(File.join(@output, "summary.json"), kind: "developer_smoke_not_acceptance", results: results, credential_leak: credential_leak,
            wire_note: "Full request/response bodies and attachment bytes retained as base64; authentication headers are never captured.")
      puts "Developer evidence: #{@output}"
      return 2 if credential_leak || results.any? { |r| r[:exit] == 2 }
      return 1 if results.any? { |r| r[:exit] == 1 }
      results.any? { |r| r[:exit] == 3 } ? 3 : 0
    rescue StandardError => error
      warn "Developer harness error: #{error.class}. #{error.message}" unless error.message.include?(ENV["RP_API_KEY"].to_s) && !ENV["RP_API_KEY"].to_s.empty?
      2
    end
  end
end

exit LedgerDeveloper::Runner.new(ARGV).run if $PROGRAM_NAME == __FILE__
