# frozen_string_literal: true

require "yaml"
require "json"
require_relative "service/scenario_attributes"

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
      batch_max_bytes: 8 * 1024 * 1024,
      queue_max_records: 1000,
      queue_max_bytes: 16 * 1024 * 1024,
      queue_overflow_policy: "reject_new",
      queue_admission_timeout_ms: 100,
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
      spool_max_bytes: 268_435_456,
      exit_flush_timeout_ms: 5_000,
      debug_curl_mode: false,
      debug_curl_dir: ".reportportal-curl",
      console_mirror: false,
      video_upload_mode: "reportportal_multipart",
      identity_strategy: "legacy",
      identity_root: nil,
      identity_namespace: nil,
      scenario_attributes_enabled: false,
      scenario_attribute_keys: Service::ScenarioAttributes::DEFAULT_ALLOWED_KEYS,
      scenario_attributes: [],
      scenario_links_enabled: false,
      source_url_template: nil,
      source_commit: nil,
      source_root: nil,
      ci_run_url: nil,
      tms_url_template: nil,
      minio_endpoint: "http://localhost:9000",
      minio_public_base_url: "http://localhost:9000",
      minio_bucket: "automation-videos",
      minio_access_key_id: "minioadmin",
      minio_secret_access_key: "minioadmin",
      minio_region: "us-east-1",
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
      "RP_BATCH_MAX_BYTES" => :batch_max_bytes,
      "RP_QUEUE_MAX_RECORDS" => :queue_max_records,
      "RP_QUEUE_MAX_BYTES" => :queue_max_bytes,
      "RP_QUEUE_OVERFLOW_POLICY" => :queue_overflow_policy,
      "RP_QUEUE_ADMISSION_TIMEOUT_MS" => :queue_admission_timeout_ms,
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
      "RP_SPOOL_MAX_BYTES" => :spool_max_bytes,
      "RP_EXIT_FLUSH_TIMEOUT_MS" => :exit_flush_timeout_ms,
      "RP_DEBUG_CURL_MODE" => :debug_curl_mode,
      "RP_DEBUG_CURL_DIR" => :debug_curl_dir,
      "RP_CONSOLE_MIRROR" => :console_mirror,
      "RP_VIDEO_UPLOAD_MODE" => :video_upload_mode,
      "RP_IDENTITY_STRATEGY" => :identity_strategy,
      "RP_IDENTITY_ROOT" => :identity_root,
      "RP_IDENTITY_NAMESPACE" => :identity_namespace,
      "RP_SCENARIO_ATTRIBUTES_ENABLED" => :scenario_attributes_enabled,
      "RP_SCENARIO_ATTRIBUTE_KEYS" => :scenario_attribute_keys,
      "RP_SCENARIO_ATTRIBUTES" => :scenario_attributes,
      "RP_SCENARIO_LINKS_ENABLED" => :scenario_links_enabled,
      "RP_SOURCE_URL_TEMPLATE" => :source_url_template,
      "RP_SOURCE_COMMIT" => :source_commit,
      "RP_SOURCE_ROOT" => :source_root,
      "RP_CI_RUN_URL" => :ci_run_url,
      "RP_TMS_URL_TEMPLATE" => :tms_url_template,
      "RP_MINIO_ENDPOINT" => :minio_endpoint,
      "RP_MINIO_PUBLIC_BASE_URL" => :minio_public_base_url,
      "RP_MINIO_PUBLIC_ENDPOINT" => :minio_public_base_url,
      "RP_MINIO_BUCKET" => :minio_bucket,
      "RP_MINIO_ACCESS_KEY_ID" => :minio_access_key_id,
      "RP_MINIO_SECRET_ACCESS_KEY" => :minio_secret_access_key,
      "RP_MINIO_REGION" => :minio_region
    }.freeze

    attr_reader(*DEFAULTS.keys)

    # @param profile [String, nil]
    # @param env [Hash]
    # @param yaml_path [String, nil]
    # @param overrides [Hash]
    # @return [Config]
    def self.load(profile: ENV["CUCUMBER_PROFILE"], env: ENV, yaml_path: nil, overrides: {})
      resolved_profile = profile || detect_profile_from_argv
      yaml_data = load_yaml(path: yaml_path || env["RP_CONFIG"], profile: resolved_profile)
      env_data = load_env(env)
      new(DEFAULTS.merge(yaml_data).merge(env_data).merge(symbolize_keys(overrides)).merge(profile: resolved_profile))
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

    # @param argv [Array<String>]
    # @return [String, nil]
    def self.detect_profile_from_argv(argv = ARGV)
      args = Array(argv)
      args.each_with_index do |entry, index|
        return args[index + 1] if entry == "-p" || entry == "--profile"
        if (match = entry.match(/\A--profile=(.+)\z/))
          return match[1]
        end
      end
      nil
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
      @batch_size_logs = positive_integer(config[:batch_size_logs], option: "RP_BATCH_SIZE_LOGS")
      @batch_max_bytes = positive_integer(config[:batch_max_bytes], option: "RP_BATCH_MAX_BYTES")
      @queue_max_records = positive_integer(config[:queue_max_records], option: "RP_QUEUE_MAX_RECORDS")
      @queue_max_bytes = positive_integer(config[:queue_max_bytes], option: "RP_QUEUE_MAX_BYTES")
      policy = config[:queue_overflow_policy]
      @queue_overflow_policy = policy if policy.instance_of?(String)
      @queue_overflow_policy ||= policy.to_s if policy.is_a?(Symbol)
      unless %w[reject_new block].include?(@queue_overflow_policy)
        raise ArgumentError, "Invalid ReportPortal queue configuration"
      end
      @queue_admission_timeout_ms = positive_integer(config[:queue_admission_timeout_ms], option: "RP_QUEUE_ADMISSION_TIMEOUT_MS")
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
      @spool_max_bytes = positive_integer(config[:spool_max_bytes], option: "RP_SPOOL_MAX_BYTES")
      @exit_flush_timeout_ms = integer(config[:exit_flush_timeout_ms], minimum: 1)
      @debug_curl_mode = truthy?(config[:debug_curl_mode])
      @debug_curl_dir = strip(config[:debug_curl_dir]) || DEFAULTS[:debug_curl_dir]
      @console_mirror = truthy?(config[:console_mirror])
      @video_upload_mode = strip(config[:video_upload_mode]) || DEFAULTS[:video_upload_mode]
      @identity_strategy = (strip(config[:identity_strategy]) || DEFAULTS[:identity_strategy]).downcase
      unless %w[legacy stable_v1].include?(@identity_strategy)
        raise ArgumentError, "RP_IDENTITY_STRATEGY must be legacy or stable_v1"
      end
      @identity_root = File.expand_path(strip(config[:identity_root]) || Dir.pwd)
      @identity_namespace = strip(config[:identity_namespace])
      @scenario_attributes_enabled = truthy?(config[:scenario_attributes_enabled])
      raw_attribute_keys = config[:scenario_attribute_keys]
      raw_attribute_keys = raw_attribute_keys.split(",").map(&:strip) if raw_attribute_keys.is_a?(String)
      @scenario_attribute_keys = Service::ScenarioAttributes.normalize_allowed_keys(raw_attribute_keys)
      @scenario_attributes = self.class.parse_scenario_attributes(config[:scenario_attributes])
      @scenario_links_enabled = truthy?(config[:scenario_links_enabled])
      if @scenario_links_enabled
        @source_url_template = self.class.optional_link_string(config[:source_url_template])
        @source_commit = self.class.optional_link_string(config[:source_commit])
        @source_root = self.class.expand_link_root(self.class.optional_link_string(config[:source_root]))
        @ci_run_url = self.class.optional_link_string(config[:ci_run_url])
        @tms_url_template = self.class.optional_link_string(config[:tms_url_template])
      else
        @source_url_template = config[:source_url_template]
        @source_commit = config[:source_commit]
        root = config[:source_root]
        @source_root = if root.is_a?(String) && [Encoding::UTF_8, Encoding::US_ASCII].include?(root.encoding) &&
                         root.valid_encoding? && !root.include?("\0")
                         self.class.expand_link_root(root)
                       else
                         Dir.pwd
                       end
        @ci_run_url = config[:ci_run_url]
        @tms_url_template = config[:tms_url_template]
      end
      @minio_endpoint = strip(config[:minio_endpoint]) || DEFAULTS[:minio_endpoint]
      @minio_public_base_url = strip(config[:minio_public_base_url]) || DEFAULTS[:minio_public_base_url]
      @minio_bucket = strip(config[:minio_bucket]) || DEFAULTS[:minio_bucket]
      @minio_access_key_id = strip(config[:minio_access_key_id]) || DEFAULTS[:minio_access_key_id]
      @minio_secret_access_key = strip(config[:minio_secret_access_key]) || DEFAULTS[:minio_secret_access_key]
      @minio_region = strip(config[:minio_region]) || DEFAULTS[:minio_region]
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

    # @return [Boolean]
    def debug_curl_mode?
      @debug_curl_mode
    end

    # @return [Boolean]
    def console_mirror?
      @console_mirror
    end

    # @return [Boolean]
    def scenario_attributes_enabled?
      @scenario_attributes_enabled
    end

    # @return [Boolean]
    def scenario_links_enabled?
      @scenario_links_enabled
    end

    # @return [Boolean]
    def minio_markdown_video?
      @video_upload_mode.to_s.downcase == "minio_markdown"
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
        when :enabled, :rerun, :reporting_async, :fail_on_reporting_error, :join, :debug_curl_mode,
             :console_mirror, :scenario_attributes_enabled, :scenario_links_enabled
          !%w[0 false no off].include?(raw.to_s.strip.downcase)
        when :batch_size_logs, :batch_max_bytes, :queue_max_records, :queue_max_bytes, :spool_max_bytes,
             :queue_admission_timeout_ms
          raw
        when :join_wait_timeout_ms, :open_timeout, :read_timeout, :write_timeout,
             :retry_attempts, :exit_flush_timeout_ms
          raw.to_i
        when :flush_interval, :retry_base_interval, :retry_max_interval
          raw.to_f
        when :launch_attributes
          normalize_attributes(raw)
        when :scenario_attribute_keys
          raw.to_s.split(",").map(&:strip)
        when :scenario_attributes
          parse_scenario_attributes(raw)
        else
          raw
        end
      end

      # @param value [Object]
      # @return [Hash, Array<Hash>]
      def parse_scenario_attributes(value)
        parsed = value.is_a?(String) ? JSON.parse(value) : value
        unless parsed.is_a?(Hash) || parsed.is_a?(Array)
          raise ArgumentError, "Invalid scenario attribute defaults"
        end

        parsed
      rescue JSON::ParserError
        raise ArgumentError, "Invalid scenario attribute defaults"
      end

      # @param value [Object]
      # @return [String, nil]
      def optional_link_string(value)
        return nil if value.nil?
        unless value.is_a?(String) && [Encoding::UTF_8, Encoding::US_ASCII].include?(value.encoding) &&
               value.valid_encoding? && !value.include?("\0")
          raise ArgumentError, "Invalid scenario link configuration"
        end

        value.empty? ? nil : value.dup
      end

      # @param value [String, nil]
      # @return [String]
      def expand_link_root(value)
        File.expand_path(value || Dir.pwd)
      rescue StandardError
        raise ArgumentError, "Invalid scenario link configuration"
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
    # @param option [String] Fixed public option label, never the supplied value.
    # @return [Integer]
    def positive_integer(value, option:)
      parsed = if value.is_a?(Integer)
                 value
               elsif value.is_a?(String) && value.match?(/\A[0-9]+\z/)
                 Integer(value, 10)
               else
                 raise ArgumentError
               end
      raise ArgumentError unless parsed.positive?

      parsed
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{option} must be a positive decimal integer"
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
