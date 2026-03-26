# frozen_string_literal: true

module ReportportalCucumber
  module Runtime
    # Shares a single launch UUID between local processes via a lock file and a sync file.
    class Join
      TimeoutError = Class.new(ReportportalCucumber::ReportingError)

      # @param config [ReportportalCucumber::Config]
      # @param cwd [String]
      def initialize(config:, cwd: Dir.pwd)
        @config = config
        @cwd = cwd
        @primary = false
      end

      # @yieldreturn [String] block that creates the launch when this process becomes primary
      # @return [String]
      def acquire_or_wait_launch_uuid
        deadline = monotonic_now + (@config.join_wait_timeout_ms / 1000.0)
        FileUtils.mkdir_p(File.dirname(lock_path))

        File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
          loop do
            existing = read_sync_state
            return mark_secondary(existing.fetch("launchUuid")) if existing

            if lock.flock(File::LOCK_EX | File::LOCK_NB)
              begin
                existing = read_sync_state
                return mark_secondary(existing.fetch("launchUuid")) if existing

                @primary = true
                launch_uuid = yield
                write_sync_uuid(launch_uuid)
                return launch_uuid
              ensure
                lock.flock(File::LOCK_UN)
              end
            end

            raise TimeoutError, "Timed out waiting for shared ReportPortal launch UUID" if monotonic_now >= deadline

            sleep(0.1)
          end
        end
      end

      # @return [Boolean]
      def primary?
        @primary
      end

      private

      # @return [String]
      def lock_path
        File.expand_path(@config.join_lock_file_name, @cwd)
      end

      # @return [String]
      def sync_path
        File.expand_path(@config.join_sync_file_name, @cwd)
      end

      # @return [String, nil]
      def read_sync_state
        return nil unless File.file?(sync_path)

        payload = JSON.parse(File.read(sync_path))
        return nil unless payload_matches_current_config?(payload)
        return nil unless primary_process_alive?(payload["pid"])

        payload
      rescue JSON::ParserError
        nil
      end

      # @param launch_uuid [String]
      # @return [void]
      def write_sync_uuid(launch_uuid)
        File.write(
          sync_path,
          JSON.generate(
            launchUuid: launch_uuid,
            launchName: @config.launch,
            project: @config.project,
            endpoint: @config.endpoint,
            pid: Process.pid,
            writtenAt: Time.now.utc.iso8601
          )
        )
      end

      # @param launch_uuid [String]
      # @return [String]
      def mark_secondary(launch_uuid)
        @primary = false
        launch_uuid
      end

      # @return [Float]
      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # @param payload [Hash]
      # @return [Boolean]
      def payload_matches_current_config?(payload)
        payload["launchName"].to_s == @config.launch.to_s &&
          payload["project"].to_s == @config.project.to_s &&
          payload["endpoint"].to_s == @config.endpoint.to_s
      end

      # @param pid [Integer, String, nil]
      # @return [Boolean]
      def primary_process_alive?(pid)
        return false if pid.to_i <= 0
        return true if pid.to_i == Process.pid

        Process.kill(0, pid.to_i)
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      end
    end
  end
end
