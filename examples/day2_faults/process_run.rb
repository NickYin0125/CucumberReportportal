# frozen_string_literal: true

require_relative "session"
require "open3"
require "rbconfig"

module Day2Faults
  module ProcessRun
    module_function

    def run(endpoint:, directory:, mode: "passing", token: "local-synthetic", project: "day2", strict: false,
            flush_ms: 350, deadline: 8)
      env = { "RP_ENABLED" => "true", "RP_ENDPOINT" => endpoint, "RP_PROJECT" => project, "RP_API_KEY" => token,
              "RP_LAUNCH" => "day2-fault-native-#{mode}-#{SecureRandom.hex(6)}", "RP_CONFIG" => File.join(__dir__, "empty.yml"),
              "RP_CLIENT_JOIN" => "false", "RP_HTTP_RETRY_ATTEMPTS" => "1", "RP_HTTP_READ_TIMEOUT" => "1",
              "RP_HTTP_WRITE_TIMEOUT" => "1", "RP_EXIT_FLUSH_TIMEOUT_MS" => flush_ms.to_s,
              "RP_BATCH_SIZE_LOGS" => "20", "RP_FLUSH_INTERVAL" => "10", "RP_CONSOLE_MIRROR" => "false",
              "RP_FAIL_ON_REPORTING_ERROR" => strict.to_s, "RP_REQUIRE_COMPLETE_REPORTING" => "false",
              "RP_SPOOL_DIR" => File.join(directory, "spool"), "CUCUMBER_PUBLISH_ENABLED" => "false" }
      root = File.expand_path("../..", __dir__)
      output, errors = +"", +""
      ready = Queue.new
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      signal_at = nil
      status = nil
      scrub = ENV.keys.grep(/\A(?:RP_|CUCUMBER_|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|http_proxy|https_proxy|all_proxy)/)
                 .to_h { |key| [key, nil] }
      Open3.popen3(scrub, RbConfig.ruby, "-I#{File.join(root, 'lib')}", File.join(__dir__, "native.rb"), chdir: root) do |stdin, stdout, stderr, child|
        readers = [[stdout, output], [stderr, errors]].map do |io, buffer|
          Thread.new do
            loop do
              buffer << io.readpartial(16 * 1024)
              raise LimitError, "child output cap" if buffer.bytesize > 2 * 1024 * 1024
              ready << true if buffer.include?("DAY2_SIGNAL_READY") && ready.empty?
            end
          rescue EOFError
            nil
          end
        end
        begin
          stdin.write(JSON.generate(env: env, mode: mode))
          stdin.close
          Timeout.timeout(deadline) do
            if mode == "sigint"
              ready.pop
              signal_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              Process.kill("INT", child.pid)
            end
            status = child.value
            readers.each(&:value)
          end
        ensure
          Process.kill("KILL", child.pid) if child.alive?
          child.join
          readers.each { |thread| thread.join(0.2); thread.kill if thread.alive? }
        end
      end
      line = output.lines.find { |entry| entry.start_with?("DAY2_RESULT=") }
      safe_output = (output + errors).gsub(token, "[REDACTED]")
      raise "Child produced no SDK receipt: #{safe_output.byteslice([safe_output.bytesize - 4000, 0].max, 4000)}" unless line
      raise "Credential exposed by child" if output.include?(token) || errors.include?(token)
      result = JSON.parse(line.delete_prefix("DAY2_RESULT="))
      result.merge("exit" => status.exitstatus, "termsig" => status.termsig, "stdout" => output, "stderr" => errors,
                   "elapsed" => Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
                   "signal_to_exit" => signal_at && Process.clock_gettime(Process::CLOCK_MONOTONIC) - signal_at,
                   "launch_name" => env.fetch("RP_LAUNCH"))
    end
  end
end
