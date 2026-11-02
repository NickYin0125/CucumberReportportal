# frozen_string_literal: true

require_relative "../../../script/acceptance/presentation_ledger_developer"

# Reuse only the published fixture inputs and wire recorder, not developer
# assertions, verdicts, run IDs, or evidence. All observations below are fresh.
module LedgerQA
  ROOT = File.expand_path("../../..", __dir__)
  class Wire < LedgerDeveloper::Wire
    def snapshot
      result = super
      if result[:persistence] == "live_readback"
        result[:queries] = result[:launches].map do |launch|
          id = launch.fetch("id")
          { launch_id: id,
            items_by_launch: pages("item?filter.eq.launchId=#{id}"),
            forbidden_prefix: get("log?filter.eq.launch=#{id}&filter.cnt.message=%21%21%21MARKDOWN_MODE%21%21%21&page.size=1"),
            secret_marker: get("log?filter.eq.launch=#{id}&filter.cnt.message=SECRET123&page.size=1") }
        end
      end
      result
    end
  end

  class Runner < LedgerDeveloper::Runner
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
        result = { id: row[:id], verdict: "BLOCKED", reason: reason, exit: 3 }
        write(File.join(directory, "result.json"), result)
        return result
      end
      canonical = File.join(ROOT, "features/presentation_ledger/qa_runtime")
      FileUtils.mkdir_p(canonical)
      feature = File.join(canonical, "#{row.fetch(:id)}.feature")
      File.write(feature, row.fetch(:source))
      wire = Wire.new(project: @project, upstream: @options[:transport] == "live" ? ENV.fetch("RP_ENDPOINT") : nil)
      command = [@options[:ruby], "-I", File.join(@options[:sdk_root], "lib"), "-e", CLI, "--",
                 "--no-profile", "--publish-quiet", "--require", File.join(HOME, "support.rb"),
                 "--format", "progress", "--format", "json", "--out", File.join(directory, "native.json"),
                 "--format", "message", "--out", File.join(directory, "native.ndjson"),
                 "--format", "html", "--out", File.join(directory, "native.html"),
                 "--format", "ReportPortal::Cucumber::Formatter", "--out", File.join(directory, "rp.out"),
                 "--format", "LedgerDeveloper::Audit", "--out", File.join(directory, "audit.out"),
                 feature.delete_prefix(ROOT + "/")]
      env = child_environment(row, wire, directory)
      env["RP_LAUNCH"] = "ledger-developer-independent-QA-#{File.basename(@output)}-#{row[:id]}"
      write(File.join(directory, "environment.json"), env.select { |key, _| key.start_with?("RP_", "LEDGER_", "GITHUB_", "PARALLEL_") && key != "RP_API_KEY" })
      process = execute(env, command, ROOT)
      write(File.join(directory, "process.json"), process)
      wire.close
      write(File.join(directory, "wire.json"), wire.records)
      begin
        snapshot = wire.snapshot
        write(File.join(directory, "snapshot.json"), snapshot)
      rescue StandardError => error
        write(File.join(directory, "readback-error.json"), error_class: error.class.name)
      end
      native = JSON.parse(File.read(File.join(directory, "native.json"))) rescue nil
      steps = native && native.flat_map { |f| f.fetch("elements", []).flat_map { |s| s.fetch("steps", []) } }
      result = { id: row[:id], exit: process[:exit], signal: process[:signal], timed_out: process[:timed_out],
                 native_steps: steps && steps.group_by { |s| s.dig("result", "status") }.transform_values(&:length),
                 launch_ids: snapshot && snapshot.fetch(:launches, []).map { |l| l["id"] },
                 acceptance_verdict: "NOT_ASSESSED", source_reuse: "fixture data and wire capture only" }
      write(File.join(directory, "result.json"), result)
      puts JSON.generate(result)
      $stdout.flush
      result
    ensure
      wire&.close
    end

    def run
      @project = @options[:transport] == "live" ? ENV.fetch("RP_PROJECT", "superadmin_personal") : "ledger_developer_offline"
      raise "Missing RP_API_KEY; inject securely in the invoking environment" if @options[:transport] == "live" && ENV["RP_API_KEY"].to_s.empty?
      @output = @options.fetch(:output)
      allowed = File.join(ROOT, "docs/reviews/assets") + "/"
      raise "Evidence must be new and under the QA assets directory" unless @output.start_with?(allowed) && !File.exist?(@output)
      FileUtils.mkdir_p(@output, mode: 0o700)
      File.write(File.join(@output, "empty-config.yml"), "{}\n")
      probe = execute(environment, [@options[:ruby], "-I", File.join(@options[:sdk_root], "lib"), "-e", PROBE], ROOT)
      write(File.join(@output, "probe.json"), probe)
      raise "Runtime probe failed; inspect probe.json" unless probe[:exit] == 0
      @runtime = JSON.parse(probe[:stdout])
      write(File.join(@output, "probe-activation.json"), @runtime.fetch("activation"))
      media_inputs = media
      selected = select_rows.flat_map do |row|
        row[:cucumber12] && @runtime.fetch("cucumber").to_i < 12 ? [row, LedgerDeveloper.legacy_companion(row)] : [row]
      end
      write(File.join(@output, "provenance.json"), tester: "Independent Ledger QA", runtime: @runtime,
            sdk_head: git_read("rev-parse", "HEAD"), baseline_or_candidate: @options[:sdk_root],
            selected: selected.map { |r| r[:id] }, media: media_inputs,
            capture_note: "New runs only; no credential headers, no joins, no mutation of pre-existing launches")
      results = selected.map { |row| run_row(row) }
      write(File.join(@output, "summary.json"), results: results, acceptance_verdict: "NOT_ASSESSED")
      puts "QA_RUN_COMPLETE=#{@output}"
      0
    rescue StandardError => error
      warn "QA runner blocked: #{error.class}" # Arbitrary error text may carry a credential.
      2
    end
  end
end

exit LedgerQA::Runner.new(ARGV).run if $PROGRAM_NAME == __FILE__
