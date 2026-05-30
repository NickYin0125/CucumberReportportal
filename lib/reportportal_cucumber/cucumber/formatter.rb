# frozen_string_literal: true

require "cucumber/formatter/ast_lookup"

module ReportportalCucumber
  module Cucumber
    # Cucumber formatter that streams execution state to ReportPortal in real time.
    class Formatter
      attr_reader :config, :runtime_context

      # @param cucumber_config [Object]
      def initialize(cucumber_config)
        @cucumber_config = cucumber_config
        @config = Config.load
        @runtime_context = Runtime::Context.new
        @api = ReportPortal::API.new(config: @config)
        @join = Runtime::Join.new(config: @config)
        @log_buffer = Runtime::LogBuffer.new(api: @api, config: @config, on_error: method(:handle_reporting_error))
        @ast_lookup = build_ast_lookup
        @feature_states = {}
        @scenario_states = {}
        @outline_metadata_cache = {}
        @launch_uuid = nil
        @finalized = false
        @last_timestamp_ms = nil
        ReportportalCucumber.current_runtime = self

        inject_world_module
        subscribe_to_events
        install_exit_flush
      end

      # @param payload [Hash]
      # @return [void]
      def ingest_event(payload)
        case payload["type"] || payload[:type]
        when "test_run_started"
          handle_test_run_started(payload)
        when "test_suite_started", "feature_started"
          handle_test_suite_started(payload)
        when "test_case_started"
          handle_test_case_started(payload)
        when "test_step_started"
          handle_test_step_started(payload)
        when "attachment"
          handle_attachment(payload)
        when "test_step_finished"
          handle_test_step_finished(payload)
        when "test_case_finished"
          handle_test_case_finished(payload)
        when "test_suite_finished", "feature_finished"
          handle_test_suite_finished(payload)
        when "test_run_finished"
          handle_test_run_finished(payload)
        end
      end

      # @param message [String]
      # @param level [String, Symbol]
      # @param timestamp [Time]
      # @param attachment [Hash, nil]
      # @return [void]
      def emit_world_log(message:, level:, timestamp:, attachment: nil)
        return unless reporting_enabled?

        target_item_uuid = runtime_context.current_item_uuid || runtime_context.active_parent_uuid
        @log_buffer.emit_log(
          item_uuid: target_item_uuid,
          launch_uuid: @launch_uuid,
          message: message,
          level: level,
          timestamp: monotonic_timestamp(timestamp),
          attachment: attachment
        )
      end

      # @param message [String]
      # @param level [String, Symbol]
      # @param timestamp [Time]
      # @param attachment [Hash]
      # @return [void]
      def emit_world_attachment(message:, level:, timestamp:, attachment:)
        return unless reporting_enabled?

        target_item_uuid = runtime_context.active_parent_uuid || runtime_context.current_item_uuid
        @log_buffer.emit_log(
          item_uuid: target_item_uuid,
          launch_uuid: @launch_uuid,
          message: message,
          level: level,
          timestamp: monotonic_timestamp(timestamp),
          attachment: attachment
        )
      end

      # @param name [String]
      # @yieldreturn [Object]
      # @return [Object]
      def with_manual_step(name)
        return yield unless reporting_enabled?

        parent_uuid = runtime_context.current_item_uuid
        return yield unless parent_uuid

        start_time = monotonic_timestamp(Time.now)
        local_uuid = SecureRandom.uuid
        failure = nil
        item_uuid = safe_reporting_call(fallback: local_uuid) do
          @api.start_item(
            name: name,
            start_time: start_time,
            type: "step",
            launch_uuid: @launch_uuid,
            parent_uuid: parent_uuid,
            has_stats: false,
            retry: false,
            uuid: local_uuid
          )
        end
        item = Runtime::Context::ItemHandle.new(
          uuid: item_uuid,
          name: name,
          kind: :manual_step,
          parent_uuid: parent_uuid,
          type: "step",
          has_stats: false,
          metadata: {}
        )
        runtime_context.push_step(item)

        yield
      rescue StandardError => error
        failure = error
        emit_error_log(item_uuid: item_uuid || local_uuid, error: error, timestamp: Time.now)
        raise
      ensure
        if item_uuid || local_uuid
          @log_buffer.flush(timeout: @config.exit_flush_timeout_ms / 1000.0)
          safe_reporting_call do
            @api.finish_item(
              item_uuid: item_uuid || local_uuid,
              launch_uuid: @launch_uuid,
              end_time: monotonic_timestamp(Time.now),
              status: failure ? "failed" : "passed"
            )
          end
          runtime_context.pop_step(expected_uuid: item_uuid || local_uuid)
        end
      end

      # @param src [String]
      # @param media_type [String]
      # @param filename [String, nil]
      # @return [void]
      def attach(src, media_type, filename = nil)
        return unless reporting_enabled?

        normalized_type = media_type.to_s.sub(/;base64\z/i, "")
        if normalized_type == "text/x.cucumber.log+plain"
          emit_world_log(message: src.to_s, level: :info, timestamp: Time.now)
          return
        end

        body = media_type.to_s.match?(/;base64\z/i) ? Base64.decode64(src.to_s) : src.to_s
        handle_attachment(
          file_name: filename || default_attachment_name(normalized_type),
          media_type: normalized_type.empty? ? "application/octet-stream" : normalized_type,
          body: body,
          content_encoding: "identity",
          message: filename ? "Attachment: #{filename}" : "Attachment"
        )
      end

      private

      # @return [Boolean]
      def reporting_enabled?
        @config.enabled?
      end

      # @return [void]
      def subscribe_to_events
        return unless @cucumber_config.respond_to?(:on_event)

        {
          test_run_started: method(:handle_test_run_started),
          test_suite_started: method(:handle_test_suite_started),
          test_case_started: method(:handle_test_case_started),
          test_step_started: method(:handle_test_step_started),
          envelope: method(:handle_envelope),
          test_step_finished: method(:handle_test_step_finished),
          test_case_finished: method(:handle_test_case_finished),
          test_suite_finished: method(:handle_test_suite_finished),
          test_run_finished: method(:handle_test_run_finished)
        }.each do |event_name, handler|
          begin
            @cucumber_config.on_event(event_name) { |event| handler.call(event) }
          rescue ArgumentError => error
            raise unless error.message.include?("not recognised")

            debug("Skipping unsupported Cucumber event #{event_name}: #{error.message}")
          end
        end
      end

      # @return [void]
      def inject_world_module
        if @cucumber_config.respond_to?(:include)
          @cucumber_config.include(ReportportalCucumber::Cucumber::World)
        elsif Kernel.respond_to?(:World)
          Kernel.World(ReportportalCucumber::Cucumber::World)
        end
      rescue StandardError
        nil
      end

      # @return [void]
      def install_exit_flush
        at_exit do
          next if @finalized

          finalize_reporting(status: "failed", end_time: Time.now)
        end
      end

      # @param event [Object]
      # @return [void]
      def handle_test_run_started(event)
        return unless reporting_enabled?

        start_time = monotonic_timestamp(extract_timestamp(event) || Time.now)
        debug("Starting launch name=#{@config.launch.inspect} join=#{@config.join?} rerun=#{@config.rerun?}")
        creator = lambda do
          local_uuid = SecureRandom.uuid
          safe_reporting_call(fallback: local_uuid) do
            @api.start_launch(
              name: @config.launch,
              start_time: start_time,
              description: @config.launch_description,
              attributes: @config.launch_attributes,
              mode: @config.launch_mode,
              rerun: @config.rerun?,
              rerun_of: @config.rerun_of,
              uuid: local_uuid
            )
          end
        end

        @launch_uuid =
          if @config.join?
            @join.acquire_or_wait_launch_uuid(&creator)
          else
            creator.call
          end
        debug("Launch ready uuid=#{@launch_uuid}")
      end

      # @param event [Object]
      # @return [void]
      def handle_test_suite_started(event)
        return unless reporting_enabled?

        feature_uri = extract_feature_uri(event)
        runtime_context.set_current_feature(feature_uri)
        ensure_feature_item(feature_uri, start_time: extract_timestamp(event) || Time.now)
      end

      # @param event [Object]
      # @return [void]
      def handle_test_case_started(event)
        return unless reporting_enabled?

        event_time = extract_timestamp(event) || Time.now
        feature_uri = extract_feature_uri(event)
        runtime_context.set_current_feature(feature_uri)
        suite_item = ensure_feature_item(feature_uri, start_time: event_time)
        feature_parent_uuid = runtime_context.current_feature_uuid || suite_item.uuid
        start_time = monotonic_timestamp(event_time)

        scenario_name = extract_scenario_name(event)
        scenario_line = extract_scenario_line(event)
        parameters = extract_parameters(event)
        code_ref = ReportPortal::Models.build_code_ref(feature_uri: feature_uri, scenario_line: scenario_line)
        explicit_test_case_id = explicit_test_case_id_for(event)
        test_case_id = ReportPortal::Models.build_test_case_id(
          explicit_id: explicit_test_case_id,
          code_ref: code_ref,
          parameters: parameters
        )
        unique_id = ReportPortal::Models.build_unique_id(code_ref: code_ref, parameters: parameters)
        scenario_key = build_scenario_key(feature_uri: feature_uri, scenario_line: scenario_line, unique_id: unique_id)
        attempt = runtime_context.next_scenario_attempt(scenario_key)
        retry_flag = attempt > 1
        debug("Starting scenario name=#{scenario_name.inspect} code_ref=#{code_ref} retry=#{retry_flag} parameters=#{parameters.inspect}")
        local_uuid = SecureRandom.uuid
        scenario_uuid = safe_reporting_call(fallback: local_uuid) do
          @api.start_item(
            name: "Scenario: #{scenario_name}",
            start_time: start_time,
            type: "test",
            launch_uuid: @launch_uuid,
            parent_uuid: feature_parent_uuid,
            code_ref: code_ref,
            parameters: parameters,
            has_stats: true,
            retry: retry_flag,
            uuid: local_uuid,
            test_case_id: test_case_id,
            unique_id: unique_id
          )
        end

        item = Runtime::Context::ItemHandle.new(
          uuid: scenario_uuid,
          name: scenario_name,
          kind: :scenario,
          parent_uuid: feature_parent_uuid,
          type: "test",
          has_stats: true,
          metadata: {
            code_ref: code_ref,
            test_case_id: test_case_id,
            unique_id: unique_id,
            attempt: attempt
          }
        )
        runtime_context.start_scenario(scenario_key, item)

        if (test_case_started_id = extract_test_case_started_id(event))
          runtime_context.associate_test_case_started(test_case_started_id, item)
        end

        @scenario_states[scenario_key] = {
          item: item,
          feature_key: feature_uri,
          statuses: [],
          test_case_started_id: test_case_started_id
        }
      end

      # @param event [Object]
      # @return [void]
      def handle_test_step_started(event)
        return unless reporting_enabled?

        scenario_item = runtime_context.current_scenario_item || runtime_context.item_for_test_case_started(extract_test_case_started_id(event))
        hook_type = extract_hook_type(event)
        class_hook = class_hook_type?(hook_type)
        return unless scenario_item || class_hook

        feature_item = runtime_context.current_feature_item || ensure_feature_item(extract_feature_uri(event), start_time: extract_timestamp(event) || Time.now)
        parent_uuid =
          if class_hook
            feature_item&.uuid
          else
            runtime_context.active_parent_uuid || runtime_context.current_item_uuid || scenario_item.uuid
          end
        return unless parent_uuid

        step_name = extract_step_name(event)
        step_description = extract_step_description(event)
        item_type = reportportal_step_type(event)
        debug("Starting nested step name=#{step_name.inspect} type=#{item_type} parent=#{parent_uuid}")
        local_uuid = SecureRandom.uuid
        step_uuid = safe_reporting_call(fallback: local_uuid) do
          @api.start_item(
            name: step_name,
            start_time: monotonic_timestamp(extract_timestamp(event) || Time.now),
            type: item_type,
            launch_uuid: @launch_uuid,
            parent_uuid: parent_uuid,
            description: step_description,
            has_stats: false,
            retry: false,
            uuid: local_uuid
          )
        end
        item = Runtime::Context::ItemHandle.new(
          uuid: step_uuid,
          name: step_name,
          kind: extract_hook?(event) ? :hook : :step,
          parent_uuid: parent_uuid,
          type: item_type,
          has_stats: false,
          metadata: {
            description: step_description,
            feature_key: runtime_context.current_feature_key,
            hook_type: hook_type,
            hook_scope: class_hook ? :class : :method
          }
        )
        runtime_context.push_step(item)
        if (test_step_id = extract_test_step_id(event))
          runtime_context.associate_test_step(test_step_id, item)
        end
      end

      # @param event [Object]
      # @return [void]
      def handle_attachment(event)
        return unless reporting_enabled?

        target_item = runtime_context.item_for_test_step(extract_test_step_id(event))
        target_item ||= runtime_context.item_for_test_case_started(extract_test_case_started_id(event))
        target_item ||= runtime_context.active_parent
        target_item ||= runtime_context.current_item
        return unless target_item

        attachment = build_attachment(event)
        debug("Queueing attachment name=#{attachment[:name].inspect} mime=#{attachment[:mime]} item=#{target_item.uuid}")
        @log_buffer.emit_log(
          item_uuid: target_item.uuid,
          launch_uuid: @launch_uuid,
          message: extract_attachment_message(event, attachment[:name]),
          level: :info,
          timestamp: monotonic_timestamp(extract_timestamp(event) || Time.now),
          attachment: attachment
        )
      end

      # @param event [Object]
      # @return [void]
      def handle_envelope(event)
        attachment = fetch_value(event, :attachment, [:envelope, :attachment])
        return unless attachment

        handle_attachment(to_hash_like(attachment))
      end

      # @param event [Object]
      # @return [void]
      def handle_test_step_finished(event)
        return unless reporting_enabled?

        test_step_id = extract_test_step_id(event)
        item = runtime_context.item_for_test_step(test_step_id) || runtime_context.current_step_item
        return unless item

        status = extract_status(event)
        if status == "failed"
          error = extract_error(event)
          emit_error_log(item_uuid: item.uuid, error: error, timestamp: monotonic_timestamp(extract_timestamp(event) || Time.now))
        end

        debug("Finishing nested step uuid=#{item.uuid} status=#{status}")
        @log_buffer.flush(timeout: @config.exit_flush_timeout_ms / 1000.0)
        finish_time = monotonic_timestamp(extract_timestamp(event) || Time.now)
        safe_reporting_call do
          @api.finish_item(
            item_uuid: item.uuid,
            launch_uuid: @launch_uuid,
            end_time: finish_time,
            status: status
          )
        end
        append_current_scenario_status(status) unless item.kind == :hook && item.metadata[:hook_scope] == :class
        record_class_hook_status(item, status)
        runtime_context.release_test_step(test_step_id) if test_step_id
        runtime_context.pop_step(expected_uuid: item.uuid)
      end

      # @param event [Object]
      # @return [void]
      def handle_test_case_finished(event)
        return unless reporting_enabled?

        scenario_key = runtime_context.current_scenario_key
        return unless @scenario_states[scenario_key]

        finish_scenario_state(
          scenario_key: scenario_key,
          status: extract_status(event),
          end_time: monotonic_timestamp(extract_timestamp(event) || Time.now),
          close_steps: true
        )
      end

      # @param event [Object]
      # @return [void]
      def handle_test_run_finished(event)
        return unless reporting_enabled?

        finalize_reporting(status: extract_run_status(event), end_time: monotonic_timestamp(extract_timestamp(event) || Time.now))
      end

      # @param event [Object]
      # @return [void]
      def handle_test_suite_finished(event)
        return unless reporting_enabled?

        feature_uri = extract_feature_uri(event)
        return unless runtime_context.feature_item(feature_uri)

        finish_feature_state(
          feature_key: feature_uri,
          status: extract_status(event),
          end_time: monotonic_timestamp(extract_timestamp(event) || Time.now)
        )
      end

      # @param status [String]
      # @param end_time [Time]
      # @return [void]
      def finalize_reporting(status:, end_time:)
        return if @finalized

        @finalized = true
        @log_buffer.flush(timeout: @config.exit_flush_timeout_ms / 1000.0)
        finish_open_scenarios(status: status, end_time: monotonic_timestamp(end_time))
        finish_feature_items(end_time: monotonic_timestamp(end_time))
        if @launch_uuid && (!@config.join? || @join.primary?)
          debug("Finalizing launch uuid=#{@launch_uuid} status=#{status}")
          safe_reporting_call do
            @api.finish_launch(
              launch_uuid: @launch_uuid,
              end_time: monotonic_timestamp(end_time),
              status: status,
              attributes: @config.launch_attributes
            )
          end
        end
        @log_buffer.shutdown(timeout: @config.exit_flush_timeout_ms / 1000.0)
      end

      # @param feature_uri [String]
      # @param start_time [Time]
      # @return [Runtime::Context::ItemHandle]
      def ensure_feature_item(feature_uri, start_time:)
        existing = runtime_context.feature_item(feature_uri)
        return runtime_context.activate_feature(feature_uri, existing) if existing

        local_uuid = SecureRandom.uuid
        feature_name = "Feature: #{File.basename(feature_uri, File.extname(feature_uri)).tr('_', ' ')}"
        feature_uuid = safe_reporting_call(fallback: local_uuid) do
          @api.start_item(
            name: feature_name,
            start_time: monotonic_timestamp(start_time),
            type: "suite",
            launch_uuid: @launch_uuid,
            has_stats: false,
            retry: false,
            uuid: local_uuid
          )
        end
        item = Runtime::Context::ItemHandle.new(
          uuid: feature_uuid,
          name: feature_name,
          kind: :feature,
          parent_uuid: nil,
          type: "suite",
          has_stats: false,
          metadata: { feature_uri: feature_uri }
        )
        runtime_context.activate_feature(feature_uri, runtime_context.register_feature(feature_uri, item))
      end

      # @param end_time [Time]
      # @return [void]
      def finish_feature_items(end_time:)
        runtime_context.feature_items.each do |feature_key, item|
          finish_feature_state(feature_key: feature_key, status: aggregate_status(runtime_context.feature_statuses(feature_key)), end_time: end_time, item: item)
        end
      end

      # @param feature_key [String]
      # @param status [String, nil]
      # @param end_time [Time]
      # @param item [Runtime::Context::ItemHandle, nil]
      # @return [void]
      def finish_feature_state(feature_key:, status:, end_time:, item: nil)
        item ||= runtime_context.feature_item(feature_key)
        return unless item

        resolved_status = ReportPortal::Models.normalize_status(status) || aggregate_status(runtime_context.feature_statuses(feature_key))
        debug("Finishing feature feature=#{feature_key} uuid=#{item.uuid} status=#{resolved_status}")
        @log_buffer.flush(timeout: @config.exit_flush_timeout_ms / 1000.0)
        safe_reporting_call do
          @api.finish_item(
            item_uuid: item.uuid,
            launch_uuid: @launch_uuid,
            end_time: monotonic_timestamp(end_time),
            status: resolved_status
          )
        end
        runtime_context.finish_feature(feature_key)
      end

      # @param status [String, nil]
      # @param end_time [Time]
      # @return [void]
      def finish_open_scenarios(status:, end_time:)
        current_key = runtime_context.current_scenario_key
        if current_key && @scenario_states[current_key]
          finish_scenario_state(scenario_key: current_key, status: status, end_time: end_time, close_steps: true)
        end

        @scenario_states.keys.each do |scenario_key|
          finish_scenario_state(scenario_key: scenario_key, status: status, end_time: end_time, close_steps: false)
        end
      end

      # @param scenario_key [String]
      # @param status [String, nil]
      # @param end_time [Time]
      # @param close_steps [Boolean]
      # @return [void]
      def finish_scenario_state(scenario_key:, status:, end_time:, close_steps:)
        scenario_state = @scenario_states[scenario_key]
        return unless scenario_state

        resolved_status = ReportPortal::Models.normalize_status(status) || aggregate_status(scenario_state[:statuses])
        close_open_steps_for_current_scenario(status: resolved_status, end_time: monotonic_timestamp(end_time)) if close_steps

        debug("Finishing scenario uuid=#{scenario_state[:item].uuid} status=#{resolved_status}")
        @log_buffer.flush(timeout: @config.exit_flush_timeout_ms / 1000.0)
        safe_reporting_call do
          @api.finish_item(
            item_uuid: scenario_state[:item].uuid,
            launch_uuid: @launch_uuid,
            end_time: monotonic_timestamp(end_time),
            status: resolved_status
          )
        end
        runtime_context.record_feature_status(scenario_state[:feature_key], resolved_status)
        scenario_state[:statuses] << resolved_status
        runtime_context.release_test_case_started(scenario_state[:test_case_started_id]) if scenario_state[:test_case_started_id]
        runtime_context.finish_scenario(expected_uuid: scenario_state[:item].uuid) if runtime_context.current_scenario_key == scenario_key
        @scenario_states.delete(scenario_key)
      end

      # @param status [String, nil]
      # @param end_time [Time]
      # @return [void]
      def close_open_steps_for_current_scenario(status:, end_time:)
        runtime_context.current_step_stack.reverse_each do |item|
          @log_buffer.flush(timeout: @config.exit_flush_timeout_ms / 1000.0)
          safe_reporting_call do
            @api.finish_item(
              item_uuid: item.uuid,
              launch_uuid: @launch_uuid,
              end_time: monotonic_timestamp(end_time),
              status: status || "failed"
            )
          end
          runtime_context.release_test_steps_for_item(item.uuid)
          runtime_context.pop_step(expected_uuid: item.uuid)
        end
      end

      # @param status [String, nil]
      # @return [void]
      def append_current_scenario_status(status)
        scenario_key = runtime_context.current_scenario_key
        return unless scenario_key

        @scenario_states[scenario_key][:statuses] << status if status
      end

      # @param item [Runtime::Context::ItemHandle]
      # @param status [String, nil]
      # @return [void]
      def record_class_hook_status(item, status)
        return unless item.kind == :hook && item.metadata[:hook_scope] == :class
        return unless status

        feature_key = runtime_context.current_feature_key || item.metadata[:feature_key]
        runtime_context.record_feature_status(feature_key, status) if feature_key
      end

      # @param fallback [Object, nil]
      # @yieldreturn [Object]
      # @return [Object]
      def safe_reporting_call(fallback: nil)
        yield
      rescue StandardError => error
        handle_reporting_error(error)
        raise if @config.fail_on_reporting_error?

        fallback
      end

      # @param error [StandardError]
      # @return [void]
      def handle_reporting_error(error)
        ReportportalCucumber.logger.warn("#{error.class}: #{error.message}")
      end

      # @param item_uuid [String]
      # @param error [Object]
      # @param timestamp [Time]
      # @return [void]
      def emit_error_log(item_uuid:, error:, timestamp:)
        details =
          if error.respond_to?(:message)
            error.message.to_s
          else
            error.to_s
          end
        backtrace =
          if error.respond_to?(:backtrace)
            Array(error.backtrace).join("\n")
          else
            fetch_value(error, :backtrace).to_s
          end
        message = [details, backtrace].reject(&:empty?).join("\n")
        @log_buffer.emit_log(
          item_uuid: item_uuid,
          launch_uuid: @launch_uuid,
          message: message.empty? ? "Step failed" : message,
          level: :error,
          timestamp: monotonic_timestamp(timestamp)
        )
      end

      # @param event [Object]
      # @return [Hash]
      def build_attachment(event)
        encoding = (fetch_value(event, :content_encoding) || "identity").to_s.downcase
        body = fetch_value(event, :body).to_s
        bytes = encoding == "base64" ? Base64.decode64(body) : body
        media_type = fetch_value(event, :media_type) || "application/octet-stream"
        {
          name: fetch_value(event, :file_name) || default_attachment_name(media_type),
          mime: media_type,
          bytes: bytes
        }
      end

      # @param event [Object]
      # @param file_name [String]
      # @return [String]
      def extract_attachment_message(event, file_name)
        fetch_value(event, :message) || "Attachment: #{file_name}"
      end

      # @param media_type [String, nil]
      # @return [String]
      def default_attachment_name(media_type)
        Service::PayloadBuilder.default_attachment_name(media_type)
      end

      # @return [String]
      def overall_status
        aggregate_status(runtime_context.feature_items.keys.flat_map { |key| runtime_context.feature_statuses(key) })
      end

      # @param event [Object]
      # @return [String]
      def extract_run_status(event)
        explicit = extract_status(event)
        return explicit if explicit

        success = fetch_value(event, :success)
        return success ? "passed" : "failed" unless success.nil?

        overall_status
      end

      # @param statuses [Array<String>]
      # @return [String]
      def aggregate_status(statuses)
        normalized = Array(statuses).compact.map { |status| ReportPortal::Models.normalize_status(status) }
        return "passed" if normalized.empty?
        return "failed" if normalized.include?("failed")
        return "skipped" if normalized.any? { |status| status == "skipped" }

        "passed"
      end

      # @param feature_uri [String]
      # @param scenario_line [Integer, String]
      # @param unique_id [String]
      # @return [String]
      def build_scenario_key(feature_uri:, scenario_line:, unique_id:)
        [feature_uri, scenario_line, unique_id].join(":")
      end

      # @param event [Object]
      # @return [String]
      def explicit_test_case_id_for(event)
        env_value = ENV["RP_TEST_CASE_ID"]
        return env_value unless env_value.to_s.strip.empty?

        extract_tags(event).each do |tag|
          case tag
          when /\A@rp[._]test[._]?case[._]?id[:=](.+)\z/i,
               /\A@testCaseId[:=](.+)\z/i,
               /\A@tms[:=](.+)\z/i
            return Regexp.last_match(1).strip
          end
        end

        nil
      end

      # @param event [Object]
      # @return [Array<String>]
      def extract_tags(event)
        tags = fetch_value(event, :tags, [:test_case, :tags], [:pickle, :tags]) || []
        Array(tags).map do |tag|
          if tag.is_a?(String)
            tag
          else
            fetch_value(tag, :name, :value) || tag.to_s
          end
        end
      end

      # @param event [Object]
      # @return [Hash, Array<Hash>, nil]
      def extract_parameters(event)
        fetch_value(event, :parameters, [:example, :parameters], [:test_case, :parameters], [:pickle, :parameters]) ||
          extract_outline_metadata(event)&.fetch(:parameters, nil)
      end

      # @param event [Object]
      # @return [String]
      def extract_feature_uri(event)
        fetch_value(event, :feature_uri, [:test_case, :location, :file], [:uri], [:pickle, :uri]) || "unknown.feature"
      end

      # @param event [Object]
      # @return [String]
      def extract_scenario_name(event)
        fetch_value(event, :scenario_name, [:test_case, :name], [:pickle, :name]) || "Unnamed scenario"
      end

      # @param event [Object]
      # @return [Integer]
      def extract_scenario_line(event)
        value = extract_outline_metadata(event)&.fetch(:scenario_line, nil) ||
          fetch_value(event, :scenario_line, [:test_case, :location, :line], [:location, :line], [:pickle, :location, :line])
        value ? value.to_i : 1
      end

      # @param event [Object]
      # @return [String]
      def extract_step_name(event)
        descriptor = build_step_descriptor(event)
        base_name =
          descriptor&.summary_name ||
          fetch_value(event, :step_text, [:test_step, :text], [:test_step, :name], [:pickle_step, :text], :name) || "Step"
        return hook_display_name(event, base_name) if extract_hook?(event)
        return "[Background] #{base_name}" if extract_background?(event)

        base_name
      end

      # @param event [Object]
      # @return [String, nil]
      def extract_step_description(event)
        return nil if extract_hook?(event)

        build_step_descriptor(event)&.to_markdown
      end

      # @param event [Object]
      # @return [Boolean]
      def extract_hook?(event)
        value = fetch_value(event, :hook, [:test_step, :hook], [:test_step, :hook?])
        value == true || !extract_hook_type(event).nil?
      end

      # @param event [Object]
      # @return [String, nil]
      def extract_hook_type(event)
        value = fetch_value(event, :hook_type, :hookType, [:test_step, :hook_type], [:test_step, :hookType])
        return normalize_hook_type(value) unless value.nil?

        hook = fetch_value(event, :hook, [:test_step, :hook])
        if hook == true
          label = fetch_value(event, :step_text, [:test_step, :text], [:test_step, :name], :name)
          return normalize_hook_type(label)
        end
        return nil unless hook && hook != true

        normalize_hook_type(fetch_value(hook, :type, :hook_type, :name, :text) || hook.class.name || hook)
      end

      # @param value [Object]
      # @return [String, nil]
      def normalize_hook_type(value)
        raw = value.to_s
        return "before_all" if raw.match?(/before(?:_|-|\s)*(?:all|test(?:_|-|\s)*run|class)/i)
        return "after_all" if raw.match?(/after(?:_|-|\s)*(?:all|test(?:_|-|\s)*run|class)/i)
        return "after_step" if raw.match?(/after(?:_|-|\s)*step/i)
        return "before" if raw.match?(/before/i)
        return "after" if raw.match?(/after/i)

        normalized = raw.downcase.gsub(/[^a-z0-9]+/, "_").sub(/\A_+/, "").sub(/_+\z/, "")
        return nil if normalized.empty? || normalized == "true"

        normalized
      end

      # @param hook_type [String, nil]
      # @return [Boolean]
      def class_hook_type?(hook_type)
        %w[before_all before_class after_all after_class].include?(hook_type.to_s)
      end

      # @param event [Object]
      # @return [String]
      def reportportal_step_type(event)
        case extract_hook_type(event)
        when "before", "before_method"
          "before_method"
        when "after", "after_method"
          "after_method"
        when "after_step"
          "after_method"
        when "before_all", "before_class"
          "before_class"
        when "after_all", "after_class"
          "after_class"
        else
          "step"
        end
      end

      # @param event [Object]
      # @param base_name [String]
      # @return [String]
      def hook_display_name(event, base_name)
        case extract_hook_type(event)
        when "before", "before_method"
          "Before Hook: #{base_name}"
        when "after", "after_method"
          "After Hook: #{base_name}"
        when "before_all", "before_class"
          "BeforeAll Hook: #{base_name}"
        when "after_all", "after_class"
          "AfterAll Hook: #{base_name}"
        else
          "Hook: #{base_name}"
        end
      end

      # @param event [Object]
      # @return [Boolean]
      def extract_background?(event)
        value = fetch_value(event, :background, :background_step, [:test_step, :background], [:pickle_step, :background])
        return value if value == true || value == false

        keyword = fetch_value(event, :keyword, [:test_step, :keyword], [:pickle_step, :keyword]).to_s
        keyword.match?(/\Abackground\b/i)
      end

      # @param event [Object]
      # @return [String, nil]
      def extract_test_case_started_id(event)
        value = fetch_value(event, :test_case_started_id, [:test_case, :id], :id)
        value&.to_s
      end

      # @param event [Object]
      # @return [String, nil]
      def extract_test_step_id(event)
        value = fetch_value(event, :test_step_id, :step_id, [:test_step, :id], :id)
        value&.to_s
      end

      # @param event [Object]
      # @return [String, nil]
      def extract_status(event)
        status = fetch_value(event, :status, [:result, :status], [:test_step_result, :status])
        normalized = ReportPortal::Models.normalize_status(status)
        return normalized if normalized

        result = fetch_value(event, :result)
        return ReportPortal::Models.normalize_status(result.to_sym) if result.respond_to?(:to_sym)

        nil
      end

      # @param event [Object]
      # @return [Object]
      def extract_error(event)
        fetch_value(event, :exception, [:result, :exception], :error, [:result, :error]) ||
          Struct.new(:message, :backtrace, keyword_init: true).new(
            message: fetch_value(event, :message, [:result, :message]) || "Step failed",
            backtrace: Array(fetch_value(event, :backtrace, [:result, :backtrace]))
          )
      end

      # @param event [Object]
      # @return [Time, nil]
      def extract_timestamp(event)
        value = fetch_value(event, :timestamp, [:result, :timestamp], [:test_case, :timestamp])
        return nil if value.nil?

        case value
        when Time
          value
        when Integer
          Time.at(value / 1000.0)
        when Float
          Time.at(value)
        else
          Time.parse(value.to_s)
        end
      rescue ArgumentError
        nil
      end

      # @param object [Object]
      # @param paths [Array<Symbol, Array<Symbol>>]
      # @return [Object, nil]
      def fetch_value(object, *paths)
        paths.each do |path|
          value = traverse(object, Array(path))
          return value unless value.nil?
        end
        nil
      end

      # @param current [Object]
      # @param path [Array<Symbol, String>]
      # @return [Object, nil]
      def traverse(current, path)
        path.reduce(current) do |memo, key|
          break nil if memo.nil?

          if memo.is_a?(Hash)
            if memo.key?(key)
              memo[key]
            elsif memo.key?(key.to_s)
              memo[key.to_s]
            elsif memo.key?(key.to_sym)
              memo[key.to_sym]
            end
          elsif memo.respond_to?(key)
            memo.public_send(key)
          else
            break nil
          end
        end
      end

      # @param value [Object]
      # @return [Object]
      def to_hash_like(value)
        return value if value.is_a?(Hash)
        return value.to_h if value.respond_to?(:to_h)

        value
      end

      # @param event [Object]
      # @return [Hash, nil]
      def extract_outline_metadata(event)
        feature_uri = extract_feature_uri(event)
        location_line = fetch_value(event, :scenario_line, [:test_case, :location, :line], [:location, :line], [:pickle, :location, :line])
        return nil if feature_uri.to_s.empty? || location_line.nil?

        cache_key = [feature_uri, location_line.to_i]
        @outline_metadata_cache[cache_key] ||= parse_outline_metadata(feature_uri, location_line.to_i)
      end

      # @param feature_uri [String]
      # @param location_line [Integer]
      # @return [Hash, nil]
      def parse_outline_metadata(feature_uri, location_line)
        return nil unless File.file?(feature_uri)

        lines = File.readlines(feature_uri, chomp: true)
        row_index = location_line - 1
        return nil unless row_index.between?(0, lines.length - 1)
        return nil unless lines[row_index].strip.start_with?("|")

        table_start = row_index
        while table_start.positive? && lines[table_start - 1].strip.start_with?("|")
          table_start -= 1
        end
        return nil if table_start == row_index

        outline_index = table_start - 1
        while outline_index >= 0
          stripped = lines[outline_index].strip
          break if stripped.start_with?("Scenario Outline:", "Scenario Template:")

          outline_index -= 1
        end
        return nil if outline_index.negative?

        headers = split_table_row(lines[table_start])
        values = split_table_row(lines[row_index])
        return nil if headers.empty? || headers.length != values.length

        {
          scenario_line: outline_index + 1,
          parameters: headers.zip(values).to_h
        }
      end

      # @param row [String]
      # @return [Array<String>]
      def split_table_row(row)
        row.strip.sub(/\A\|/, "").sub(/\|\z/, "").split("|").map(&:strip)
      end

      # @param message [String]
      # @return [void]
      def debug(message)
        ReportportalCucumber.logger.debug(message)
      end

      # @param value [Time]
      # @return [Time]
      def monotonic_timestamp(value)
        base_ms = Service::PayloadBuilder.unix_ms(value).to_i
        next_ms =
          if @last_timestamp_ms && base_ms <= @last_timestamp_ms
            @last_timestamp_ms + 1
          else
            base_ms
          end
        @last_timestamp_ms = next_ms
        Time.at(next_ms / 1000, (next_ms % 1000) * 1000, :microsecond)
      end

      # @param event [Object]
      # @return [ReportportalCucumber::ReportPortal::Models::StepDesc, nil]
      def build_step_descriptor(event)
        test_step = fetch_value(event, :test_step)
        return nil unless test_step && @ast_lookup

        ReportPortal::Models::StepDesc.from_test_step(test_step, ast_lookup: @ast_lookup)
      end

      # @return [Object, nil]
      def build_ast_lookup
        return nil unless defined?(::Cucumber::Formatter::AstLookup) && @cucumber_config.respond_to?(:on_event)

        ::Cucumber::Formatter::AstLookup.new(@cucumber_config)
      rescue StandardError
        nil
      end
    end
  end
end
