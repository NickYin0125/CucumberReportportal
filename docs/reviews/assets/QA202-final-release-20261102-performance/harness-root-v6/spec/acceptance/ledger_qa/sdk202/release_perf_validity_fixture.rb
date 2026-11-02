# frozen_string_literal: true

require_relative "release_perf_fixture"

module ReleasePerfUntimedSubprocess
  def execute(env, command, directory)
    original = command
    command = command.map do |entry|
      entry.end_with?("/spec/acceptance/ledger_qa/performance_support.rb") ?
        File.join(__dir__, "release_perf_validity_support.rb") : entry
    end
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
    { command: command, original_observer_command: original, exit: status.exitstatus, signal: status.termsig,
      timed_out: timed_out, seconds: nil, timing_collection: "DISABLED_UNTIMED_VALIDITY", stdout: stdout, stderr: stderr }
  end
end

LedgerDeveloper::Runner.prepend(ReleasePerfUntimedSubprocess)

if $PROGRAM_NAME == __FILE__
  kind = ARGV.shift
  exit({ "wall" => ReleasePerfWall, "micro" => ReleasePerfMicro, "parallel-micro" => ReleasePerfParallel }.fetch(kind).new(ARGV).run)
end
