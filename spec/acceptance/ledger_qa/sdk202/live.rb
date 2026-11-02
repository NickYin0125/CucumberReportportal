# frozen_string_literal: true

require_relative "../frozen"
require_relative "../framework_shape"

module Ledger202Live
  module NoClock
    def execute(env, command, directory)
      stdout = stderr = status = nil
      timed_out = false
      # Capture execution results only; performance clocks remain disarmed.
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
      process = { command: command, exit: status.exitstatus, signal: status.termsig,
        timed_out: timed_out, stdout: stdout, stderr: stderr, performance_timing: "NOT_COLLECTED" }
      process
    end
  end
  LedgerDeveloper::Runner.prepend(NoClock)

  module Guards
    def execute(env, command, directory)
      if env["LEDGER_EVIDENCE"]
        env = env.merge("RP_LAUNCH" => "ledger-developer-QA202-INDEPENDENT-#{File.basename(@output)}-#{env.fetch('LEDGER_FIXTURE')}")
      end
      process = super(env, command, directory)
      if env["LEDGER_EVIDENCE"]
        file = File.join(env["LEDGER_EVIDENCE"], "runtime.json")
        if File.file?(file)
          runtime = JSON.parse(File.read(file))
          root = File.realpath(@options[:sdk_root])
          passed = !runtime.fetch("loaded_sdk_files").empty? && runtime.fetch("loaded_sdk_files").all? { |p| File.realpath(p).start_with?(root + "/lib/") } &&
            !runtime["sdk_source_changed_during_fixture"]
          write(File.join(env["LEDGER_EVIDENCE"], "source-guard.json"), expected_source: root, passed: passed,
            source_sha: ENV.fetch("QA202_SOURCE_SHA"), runtime_version: runtime["sdk_version"])
          raise "Source isolation failed" unless passed
        end
      end
      process
    end

    def run_row(row)
      result = super
      id = result.fetch(:id)
      directory = File.join(@output, id)
      path = File.join(directory, "snapshot.json")
      problems = []
      if !File.file?(path)
        problems << "missing_live_readback"
      else
        snapshot = JSON.parse(File.read(path))
        problems.concat(Ledger202Live.safety(snapshot, JSON.parse(File.read(File.join(directory, "wire.json")))))
        signature = Ledger202Live.signature(snapshot)
        write(File.join(directory, "invariants.json"), signature)
        if ENV["QA202_BASELINE_CAPTURE"]
          baseline = File.join(ENV.fetch("QA202_BASELINE_CAPTURE"), id, "invariants.json")
          if File.file?(baseline)
            before = JSON.parse(File.read(baseline))
            signature.each { |key, value| problems << "baseline_drift_#{key}" unless before.fetch(key) == value }
          else
            problems << "missing_baseline_pair"
          end
        end
      end
      problems << "source_or_execution_incomplete" if result[:timed_out] || result[:signal] || ![0, 1].include?(result[:exit])
      write(File.join(directory, "safety.json"), status: problems.empty? ? "CLEAR_TO_CONTINUE" : "STOP",
        problems: problems, launch_ids: result[:launch_ids], source_sha: ENV.fetch("QA202_SOURCE_SHA"))
      unless problems.empty?
        puts JSON.generate(safety: "STOP", fixture: id, problems: problems, launch_ids: result[:launch_ids])
        raise "STOP: acceptance safety gate"
      end
      result
    end
  end

  def self.signature(snapshot)
    items = snapshot.fetch("items").to_h { |item| [item.fetch("id"), item] }
    paths = {}
    path = lambda do |id|
      return "LAUNCH" unless id
      paths[id] ||= begin
        item = items.fetch(id)
        path.call(item["parent"]) + "/" + item.fetch("name")
      end
    end
    tree = items.values.map { |item| [path.call(item["id"]), item["type"], item["status"], item["hasStats"]] }.sort_by(&:to_s)
    logs = snapshot.fetch("logs").group_by { |log| [path.call(log["itemId"]), log["level"]] }.map { |key, rows| key + [rows.length] }.sort_by(&:to_s)
    files = snapshot.fetch("files").map { |file| [path.call(file["item_id"]), file["sha256"], file["bytes"], file["content_type"]] }.sort_by(&:to_s)
    { "tree_status_ownership" => tree, "log_owner_level_counts" => logs, "attachment_owner_bytes_mime" => files }
  end

  def self.safety(snapshot, wire)
    problems = []
    problems << "not_live_persistence" unless snapshot["persistence"] == "live_readback"
    fields = snapshot.fetch("logs").map { |row| row["message"] } +
      (snapshot.fetch("items") + snapshot.fetch("launches")).flat_map { |row| row.values_at("name", "description", "attributes") }
    problems << "probe_secret_visible" if JSON.generate(fields).include?("SECRET123")
    snapshot.fetch("queries").each do |query|
      problems << "probe_secret_query_hit" unless query.dig("secret_marker", "page", "totalElements") == 0
    end
    sent = wire.flat_map { |r| r.fetch("files", []) }.map { |f| [f["sha256"], f["bytes"]] }.sort
    received = snapshot.fetch("files").map { |f| [f["sha256"], f["bytes"]] }.sort
    problems << "raw_attachment_bytes_changed_or_missing" unless sent == received
    problems << "wire_failure" if wire.any? { |r| r["observer_error"] || (r["status"] && !(200..299).cover?(r["status"])) }
    problems
  end

  class Standard < LedgerQA::IsolatedRunner
    prepend Guards
  end
  class Frozen < LedgerQA::FrozenRunner
    prepend Guards
  end
  class Framework < LedgerQA::FrameworkShapeRunner
    prepend Guards
  end
  class Supplement < LedgerQA::IsolatedRunner
    prepend Guards

    def select_rows
      %w[backslash regex windows diff json_quote json_secret values http captions].map do |name|
        { id: "QA202-#{name}", source: "@reportportal_live\nFeature: QA202 independent #{name}\n  Scenario: QA202 #{name}\n    Given QA202 #{name}\n",
          scenarios: 1, origin: "Independent Decision27 supplement; not substituted for historical performance corpus" }
      end
    end

    def execute(env, command, directory)
      if env["LEDGER_EVIDENCE"]
        command = command.dup
        command.insert(command.index("--no-profile") + 1, "--require", File.join(__dir__, "supplement_support.rb"))
      end
      super(env, command, directory)
    end
  end
  class Contract < Supplement
    def select_rows
      %w[regex embedded_json escaped_json].map do |name|
        { id: "C202-#{name}", source: "@reportportal_live\nFeature: QA202 exact R01 #{name}\n  Scenario: R01 #{name}\n    Given QA202 contract #{name}\n",
          scenarios: 1, origin: "Exact F1 contract companions; broader standalone JSON and actual RSpec diff captures retained separately" }
      end
    end

    def execute(env, command, directory)
      if env["LEDGER_EVIDENCE"]
        command = command.dup
        command.insert(command.index("--no-profile") + 1, "--require", File.join(__dir__, "r01_contract_support.rb"))
      end
      super(env, command, directory)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  kind = ARGV.shift
  runner = { "standard" => Ledger202Live::Standard, "frozen" => Ledger202Live::Frozen,
    "framework" => Ledger202Live::Framework, "supplement" => Ledger202Live::Supplement,
    "contract" => Ledger202Live::Contract }.fetch(kind)
  exit runner.new(ARGV).run
end
