# frozen_string_literal: true

require "yaml"

module ReportportalCucumber
  # Loads configuration from defaults, YAML profiles, and environment variables.
  class Config
    DEFAULTS = {
      enabled: true,
      endpoint: nil,
      project: nil,
      api_key: nil,
      launch: "Cucumber",
      launch_description: nil,
      launch_mode: "DEFAULT",
      launch_attributes: [],
      rerun: false,
      rerun_of: nil,
      reporting_async: false,
      batch_size_logs: 20,
      flush_interval: 1.0,
      fail_on_reporting_error: false,
      join: true,
      join_lock_file_name: ".reportportal.lock",
      join_sync_file_name: ".reportportal-launch.json",
      join_wait_timeout_ms: 30_000,
      open_timeout: 5,
      read_timeout: 15,
      write_timeout: 15,
      retry_attempts: 5,
      retry_base_interval: 0.5,
      retry_max_interval: 10.0,
      spool_dir: ".reportportal-spool",
      exit_flush_timeout_ms: 5_000,
      profile: nil
    }.freeze

    ENV_KEY_MAP = {
      "RP_ENABLED" => :enabled,
      "RP_ENDPOINT" => :endpoint,
      "RP_PROJECT" => :project,
      "RP_API_KEY" => :api_key,
      "RP_LAUNCH" => :launch,
      "RP_LAUNCH_DESCRIPTION" => :launch_description,
      "RP_LAUNCH_MODE" => :launch_mode,
      "RP_ATTRIBUTES" => :launch_attributes,
      "RP_RERUN" => :rerun,
      "RP_RERUN_OF" => :rerun_of,
      "RP_REPORTING_ASYNC" => :reporting_async,
      "RP_BATCH_SIZE_LOGS" => :batch_size_logs,
      "RP_FLUSH_INTERVAL" => :flush_interval,
      "RP_FAIL_ON_REPORTING_ERROR" => :fail_on_reporting_error,
      "RP_CLIENT_JOIN" => :join,
      "RP_CLIENT_JOIN_LOCK_FILE_NAME" => :join_lock_file_name,
      "RP_CLIENT_JOIN_SYNC_FILE_NAME" => :join_sync_file_name,
      "RP_CLIENT_JOIN_FILE_WAIT_TIMEOUT_MS" => :join_wait_timeout_ms,
      "RP_HTTP_OPEN_TIMEOUT" => :open_timeout,
      "RP_HTTP_READ_TIMEOUT" => :read_timeout,
      "RP_HTTP_WRITE_TIMEOUT" => :write_timeout,
      "RP_HTTP_RETRY_ATTEMPTS" => :retry_attempts,
      "RP_HTTP_RETRY_BASE_INTERVAL" => :retry_base_interval,
      "RP_HTTP_RETRY_MAX_INTERVAL" => :retry_max_interval,
      "RP_SPOOL_DIR" => :spool_dir,
      "RP_EXIT_FLUSH_TIMEOUT_MS" => :exit_flush_timeout_ms
    }.freeze

    attr_reader(*DEFAULTS.keys)

    # @param profile [String, nil]
    # @param env [Hash]
    # @param yaml_path [String, nil]
    # @param overrides [Hash]
    # @return [Config]
    def self.load(profile: ENV["CUCUMBER_PROFILE"], env: ENV, yaml_path: nil, overrides: {})
      yaml_data = load_yaml(path: yaml_path || env["RP_CONFIG"], profile: profile)
      env_data = load_env(env)
      new(DEFAULTS.merge(yaml_data).merge(env_data).merge(symbolize_keys(overrides)).merge(profile: profile))
    end

    # @param path [String, nil]
    # @param profile [String, nil]
    # @return [Hash]
    def self.load_yaml(path:, profile:)
      config_path = path || default_yaml_candidates.find { |candidate| File.file?(candidate) }
      return {} unless config_path

      raw = YAML.safe_load(File.read(config_path), permitted_classes: [Symbol], aliases: true) || {}
      data = symbolize_keys(raw)
      defaults = symbolize_keys(data[:default] || {})
      profiles = symbolize_keys(data[:profiles] || {})
      selected = symbolize_keys(profiles[profile&.to_sym] || data[profile&.to_sym] || {})
      defaults.merge(selected)
    end

    # @param env [Hash]
    # @return [Hash]
    def self.load_env(env)
      ENV_KEY_MAP.each_with_object({}) do |(env_key, config_key), memo|
        next unless env.key?(env_key)

        memo[config_key] = cast_value(config_key, env.fetch(env_key))
      end
    end

    # @return [Array<String>]
    def self.default_yaml_candidates
      [
        File.join(Dir.pwd, ".reportportal.yml"),
        File.join(Dir.pwd, "config", "reportportal.yml")
      ]
    end

    # @param value [Object]
    # @return [Array<Hash>]
    def self.normalize_attributes(value)
      return value if value.is_a?(Array)
      return [] if value.nil? || value == ""

      value.to_s.split(",").filter_map do |entry|
        item = entry.strip
        next if item.empty?

        if item.include?(":")
          key, raw_value = item.split(":", 2)
          { "key" => key.strip, "value" => raw_value.strip }
        else
          { "value" => item }
        end
      end
    end

    # @param value [Hash]
    def initialize(value = {})
      config = DEFAULTS.merge(self.class.symbolize_keys(value))
      @enabled = truthy?(config[:enabled])
      @endpoint = strip(config[:endpoint])
      @project = strip(config[:project])
      @api_key = strip(config[:api_key])
      @launch = strip(config[:launch]) || DEFAULTS[:launch]
      @launch_description = strip(config[:launch_description])
      @launch_mode = strip(config[:launch_mode]) || DEFAULTS[:launch_mode]
      @launch_attributes = self.class.normalize_attributes(config[:launch_attributes])
      @rerun = truthy?(config[:rerun])
      @rerun_of = strip(config[:rerun_of])
      @reporting_async = truthy?(config[:reporting_async])
      @batch_size_logs = integer(config[:batch_size_logs], minimum: 1)
      @flush_interval = float(config[:flush_interval], minimum: 0.1)
      @fail_on_reporting_error = truthy?(config[:fail_on_reporting_error])
      @join = truthy?(config[:join])
      @join_lock_file_name = strip(config[:join_lock_file_name]) || DEFAULTS[:join_lock_file_name]
      @join_sync_file_name = strip(config[:join_sync_file_name]) || DEFAULTS[:join_sync_file_name]
      @join_wait_timeout_ms = integer(config[:join_wait_timeout_ms], minimum: 1)
      @open_timeout = integer(config[:open_timeout], minimum: 1)
      @read_timeout = integer(config[:read_timeout], minimum: 1)
      @write_timeout = integer(config[:write_timeout], minimum: 1)
      @retry_attempts = integer(config[:retry_attempts], minimum: 1)
      @retry_base_interval = float(config[:retry_base_interval], minimum: 0.01)
      @retry_max_interval = float(config[:retry_max_interval], minimum: @retry_base_interval)
      @spool_dir = strip(config[:spool_dir]) || DEFAULTS[:spool_dir]
      @exit_flush_timeout_ms = integer(config[:exit_flush_timeout_ms], minimum: 1)
      @profile = strip(config[:profile])
    end

    # @return [Boolean]
    def enabled?
      @enabled && endpoint && project && api_key
    end

    # @return [Boolean]
    def reporting_async?
      @reporting_async
    end

    # @return [Boolean]
    def join?
      @join
    end

    # @return [Boolean]
    def rerun?
      @rerun
    end

    # @return [Boolean]
    def fail_on_reporting_error?
      @fail_on_reporting_error
    end

    # @return [String]
    def api_base_path
      reporting_async? ? "/api/v2/#{project}" : "/api/v1/#{project}"
    end

    class << self
      # @param value [Hash]
      # @return [Hash]
      def symbolize_keys(value)
        return {} unless value.is_a?(Hash)

        value.each_with_object({}) do |(key, item), memo|
          memo[key.to_sym] =
            if item.is_a?(Hash)
              symbolize_keys(item)
            elsif item.is_a?(Array)
              item.map { |nested| nested.is_a?(Hash) ? symbolize_keys(nested) : nested }
            else
              item
            end
        end
      end

      # @param config_key [Symbol]
      # @param raw [Object]
      # @return [Object]
      def cast_value(config_key, raw)
        case config_key
        when :enabled, :rerun, :reporting_async, :fail_on_reporting_error, :join
          !%w[0 false no off].include?(raw.to_s.strip.downcase)
        when :batch_size_logs, :join_wait_timeout_ms, :open_timeout, :read_timeout, :write_timeout,
             :retry_attempts, :exit_flush_timeout_ms
          raw.to_i
        when :flush_interval, :retry_base_interval, :retry_max_interval
          raw.to_f
        when :launch_attributes
          normalize_attributes(raw)
        else
          raw
        end
      end
    end

    private

    # @param value [Object]
    # @param minimum [Integer]
    # @return [Integer]
    def integer(value, minimum:)
      [value.to_i, minimum].max
    end

    # @param value [Object]
    # @param minimum [Float]
    # @return [Float]
    def float(value, minimum:)
      [value.to_f, minimum].max
    end

    # @param value [Object]
    # @return [String, nil]
    def strip(value)
      return nil if value.nil?

      item = value.to_s.strip
      item.empty? ? nil : item
    end

    # @param value [Object]
    # @return [Boolean]
    def truthy?(value)
      ![false, nil, "false", "0", "off", "no"].include?(value)
    end
  end
end
