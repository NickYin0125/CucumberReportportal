# frozen_string_literal: true

require_relative "final_release_common"
require_relative "live"

module FinalRelease202
  module ReadRetry
    def upstream(method, *args)
      attempts = 0
      begin
        attempts += 1
        super(method, *args)
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET
        raise unless method == "GET" && attempts < 3
        sleep 1
        retry
      end
    end
  end
  LedgerDeveloper::Wire.prepend(ReadRetry)

  class Fixtures < LedgerQA::IsolatedRunner
    def execute(env, command, directory)
      command = command.dup
      if (index = command.index("-e"))
        command[index + 1] = 'gem "diff-lcs", "< 2"; ' + command[index + 1]
      end
      super(env, command, directory)
    end

    def select_rows
      rows = super
      rows = rows.map do |r|
        r[:id] == "F16c" ? r.merge(unsupported: nil, failed: 1,
          native_classification: "N/A: Ruby raise requires an Exception; original native unsupported classification retained",
          evidence_scope: "Supplementary event-adapter UNIT/protocol replay only, not native Cucumber non-Exception execution",
          source: "@reportportal_live\nFeature: Final non-Exception adapter\n  Scenario: Struct fallback\n    Given QA non-Exception fallback failure\n") : r
      end
      rows.sort_by! { |r| r[:id].start_with?("F14") ? 0 : r[:id].start_with?("F18") ? 1 : 2 }
      if @options[:fixtures].split(",").include?("F04")
        frozen = rows.find { |r| r[:id] == "F04" }
        rows << frozen.merge(id: "F04-frozen", source: File.read(File.join(FinalRelease202::QA, "features/presentation_ledger/f04_frozen.feature")))
      end
      %w[values http captions].each do |name|
        rows << { id: "QA202-#{name}", source: "@reportportal_live\nFeature: Final QA #{name}\n  Scenario: Final #{name}\n    Given QA202 #{name}\n", scenarios: 1, failed: 0 }
      end
      security = JSON.parse(File.read(File.join(FinalRelease202::OUT, "live-security-inputs.json")))
      source = "@reportportal_live\nFeature: Final encoded security\n" + security.fetch("cases").map do |r|
        "  Scenario: #{r.fetch('id')}\n    Given final encoded probe #{r.fetch('id')}\n"
      end.join("\n")
      rows << { id: "FINAL-security", source: source, scenarios: security.fetch("cases").length, failed: security.fetch("cases").length }
      rows.select! { |r| r[:id] == "FINAL-security" } if ENV["QA_FINAL_SECURITY_ONLY"] == "true"
      rows.select! { |r| r[:id].start_with?("F16") || %w[F13 F20].include?(r[:id]) } if ENV["QA_FINAL_P1_ONLY"] == "true"
      rows.select! { |r| r[:id] == "F01" } if @options[:mode] == "default"
      rows
    end

    def run_row(row)
      directory = File.join(@output, row.fetch(:id))
      FileUtils.mkdir_p(File.join(directory, "features"))
      feature = row[:id] == "F04-frozen" ? "features/audit.feature" : "features/#{row[:id]}.feature"
      File.write(File.join(directory, feature), row.fetch(:source))
      write(File.join(directory, "fixture.json"), row.merge(source_sha256: Digest::SHA256.hexdigest(row[:source])))
      wire = LedgerQA::Wire.new(project: @project, upstream: FinalRelease202::ENDPOINT)
      command = [@options[:ruby], "-I", File.join(@options[:sdk_root], "lib"), "-e", CLI, "--", "--no-profile", "--backtrace", "--publish-quiet",
        "--require", File.join(HOME, "support.rb"), "--require", File.join(__dir__, "supplement_support.rb"),
        "--require", File.join(__dir__, "final_release_probe_support.rb")]
      formatter = "ReportPortal::Cucumber::Formatter"
      if row[:id] == "F04-frozen" || row[:id] == "F16c"
        command.concat(["--require", File.join(FinalRelease202::QA, "spec/acceptance/ledger_qa/runtime-support.rb")]) if row[:id] == "F04-frozen"
        command.concat(["--require", File.join(FinalRelease202::QA, "spec/acceptance/ledger_qa/replay_support.rb")])
        formatter = "LedgerQA::ReplayFormatter"
      end
      command.concat(["--format", "progress", "--format", "json", "--out", "native.json", "--format", "message", "--out", "native.ndjson",
        "--format", "html", "--out", "native.html", "--format", formatter, "--out", "rp.out", "--format", "LedgerDeveloper::Audit", "--out", "audit.out", feature])
      env = child_environment(row, wire, directory).merge("RP_LAUNCH" => "ledger-developer-final-release-8f44c10-#{@options[:mode]}-#{row[:id]}")
      env["QA_FINAL_SECURITY_INPUTS"] = File.join(FinalRelease202::OUT, "live-security-inputs.json")
      env["QA_FROZEN_FAILURE_INPUT"] = File.join(FinalRelease202::QA, "docs/reviews/assets/ledger-qa-frozen-input/launch-76-f04.json") if row[:id] == "F04-frozen"
      write(File.join(directory, "environment.json"), env.reject { |k, _| k == "RP_API_KEY" })
      process = execute(env, command, directory)
      write(File.join(directory, "process.json"), process)
      wire.close
      write(File.join(directory, "wire.json"), wire.records)
      snapshot = wire.snapshot
      write(File.join(directory, "snapshot.json"), snapshot)
      problems = Ledger202Live.safety(JSON.parse(JSON.generate(snapshot)), JSON.parse(JSON.generate(wire.records)))
      problems << "incomplete_process" if process[:timed_out] || process[:signal] || ![0, 1].include?(process[:exit])
      runtime = JSON.parse(File.read(File.join(directory, "runtime.json")))
      problems << "wrong_sdk" unless runtime["sdk_version"] == "2.0.2"
      problems << "hanging_items" if snapshot[:items].any? { |r| r["status"] == "IN_PROGRESS" || !r["endTime"] }
      problems << "hanging_launch" if snapshot[:launches].any? { |r| r["status"] == "IN_PROGRESS" || !r["endTime"] }
      result = { id: row[:id], mode: @options[:mode], source_sha: FinalRelease202::SHA, exit: process[:exit],
        launch_ids: snapshot[:launches].map { |l| l["id"] }, items: snapshot[:items].length, logs: snapshot[:logs].length,
        problems: problems, status: problems.empty? ? "CAPTURED" : "FAIL" }
      write(File.join(directory, "result.json"), result)
      puts JSON.generate(result)
      $stdout.flush
      raise "Final fixture safety gate" unless problems.empty?
      result
    ensure
      wire&.close
    end
  end
end

if $PROGRAM_NAME == __FILE__
  FinalRelease202.verify
  FinalRelease202.authenticate
  mode = ARGV.fetch(0)
  security_only = ARGV[1] == "security"
  p1_only = ARGV[1] == "p1"
  ENV["QA_FINAL_SECURITY_ONLY"] = "true" if security_only
  ENV["QA_FINAL_P1_ONLY"] = "true" if p1_only
  abort "plain, rich or default" unless %w[plain rich default].include?(mode)
  ENV["QA202_SOURCE_SHA"] = FinalRelease202::SHA
  jpeg = "/Users/nick/Documents/crr-2.0.1/script/acceptance/presentation_ledger_developer/evidence/baseline2-all/media/jpeg.jpg"
  exit FinalRelease202::Fixtures.new(["--transport", "live", "--mode", mode, "--sdk-root", FinalRelease202::SOURCE,
    "--cucumber", "12.0.1", "--jpeg", jpeg, "--fixtures", p1_only ? "F13,F16,F20" : "F01,F04,F10,F11,F12,F14,F18",
    "--output", File.join(FinalRelease202::OUT, security_only ? "security-#{mode}" : p1_only ? "p1-#{mode}" : "fixtures-#{mode}-v3")]).run
end
