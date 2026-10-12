# frozen_string_literal: true

require "cucumber/formatter/ast_lookup"
require "cucumber/glue/dsl"
require "json"
require_relative "ast_metadata"
require_relative "native_lifecycle"
require_relative "../automation/report_context"
require_relative "../automation/evidence_redactor"
require_relative "../service/evidence_presenter"
require_relative "../service/scenario_identity"
require_relative "../service/scenario_attributes"
require_relative "../service/scenario_links"

module ReportportalCucumber
  module Cucumber
    # Cucumber formatter that streams execution state to ReportPortal in real time.
    class Formatter
      SAFE_SCENARIO_LINK_DIAGNOSTICS = Service::ScenarioLinks::DIAGNOSTIC_REASONS.map(&:to_s).freeze
      EVIDENCE_FILENAME_LIMIT = 512
      # Excessive batches are refused and counted, never silently truncated.
      EVIDENCE_MAX_ARTIFACTS = 16

      attr_reader :config, :runtime_context

      # @param cucumber_config [Object]
      def initialize(cucumber_config)
        @cucumber_config = cucumber_config
        @config = Config.load
        @runtime_context = Runtime::Context.new
        if @config.enabled?
          @api = ReportPortal::API.new(config: @config)
          @join = Runtime::Join.new(config: @config) if @config.join? && !@config.ci_owned_launch?
          @log_buffer = Runtime::LogBuffer.new(api: @api, config: @config, on_error: method(:handle_reporting_error))
        end
        @ast_lookup = build_ast_lookup
        @ast_metadata = AstMetadata.new(ast_lookup: @ast_lookup)
        @feature_states = {}
        @scenario_states = {}
        @identity_warnings = Set.new
        @evidence_admission_warning_mutex = Mutex.new
        @evidence_admission_warning_emitted = false
        @missing_reporting_options = @config.reporting_requested? ? @config.missing_reporting_options : [].freeze
        @configuration_failed = !@missing_reporting_options.empty?
        @reporting_failures = @configuration_failed ? 1 : 0
        @capture_close_timeouts = 0
        @finalization_deadline = nil
        @finalization_finished = false
        @business_failed = false
        @strict_reporting_error = nil
        @incomplete_summary_emitted = false
        @stable_scenario_outcomes = Hash.new { |hash, key| hash[key] = {} }
        @launch_uuid = nil
        @finalized = false
        @last_timestamp_ms = nil
        ReportportalCucumber.current_runtime = self

        @native_lifecycle = reporting_lifecycle_active? && NativeLifecycle.attach(cucumber_config: @cucumber_config, formatter: self)
        if reporting_enabled? && @config.join? && !@config.ci_owned_launch?
          ReportportalCucumber.logger.warn("ReportPortal legacy join cannot guarantee shared launch completion; use RP_LAUNCH_UUID with CI-owned completion")
        end

        inject_world_module
        subscribe_to_events
        install_exit_flush if reporting_lifecycle_active?
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

      # @return [Runtime::Context::CaptureTarget, nil]
      def capture_target
        item = runtime_context.current_step_item
        return unless reporting_enabled? && !@finalized && item

        runtime_context.capture_target_for(item, launch_uuid: @launch_uuid)
      end

      # @return [Runtime::Context::CaptureTarget, nil]
      def rp_capture_target
        capture_target
      end

      # @return [Hash] Immutable, thread-safe queue admission diagnostics.
      def reporting_diagnostics
        return @log_buffer.diagnostics if @log_buffer

        { reporting_requested: @config.reporting_requested?, missing_configuration: @missing_reporting_options,
          metadata_failures: @reporting_failures }.freeze
      end

      # @return [ReportportalCucumber::Service::DeliveryReceipt]
      def reporting_receipt
        unless @log_buffer
          values = Service::DeliveryReceipt::FIELDS.to_h { |field| [field, 0] }
          return Service::DeliveryReceipt.new(**values.merge(complete: !@configuration_failed,
                                                            metadata_failures: @reporting_failures,
                                                            local_settled: true, timed_out: false))
        end

        @log_buffer.reporting_receipt(capture_close_timeouts: @capture_close_timeouts,
                                      metadata_failures: @reporting_failures,
                                      finalization_complete: @finalization_finished)
      end

      # Completes reporting only after genuine native AfterAll execution.
      # @param error [Exception, nil] The original native run-hook exception, never replaced.
      # @return [void]
      def complete_native_run(error: nil)
        return unless reporting_lifecycle_active? && !@finalized

        @business_failed ||= !error.nil? && !error.equal?(@strict_reporting_error)
        @finalization_deadline ||= Service::ReportingDeadline.new(timeout: @config.exit_flush_timeout_ms / 1000.0)
        if error && @launch_uuid
          diagnostic = Service::EvidencePresenter.sanitize_diagnostic(error.message, limit: 2048)
          safe_reporting_call(preserve_business_exception: true) do
            @log_buffer.emit_log(item_uuid: nil, launch_uuid: @launch_uuid,
                                 message: "Native AfterAll failed (#{error.class}): #{diagnostic}",
                                 level: :error, timestamp: monotonic_timestamp(Time.now),
                                 deadline: @finalization_deadline)
          end
        end
        status = error ? "failed" : (@native_run_status || "failed")
        finalize_reporting(status: status, end_time: Time.now)
      end

      # @param action [Object]
      # @param error [Object]
      # @param url [String, nil]
      # @param details [Object, nil]
      # @param artifacts [Array<Hash>]
      # @param target [Runtime::Context::CaptureTarget, nil]
      # @return [Boolean]
      def report_evidence(action:, error:, url: nil, details: nil, artifacts: [], target: nil)
        return false unless reporting_enabled? && !@finalized

        deadline = Service::ReportingDeadline.new(timeout: @config.exit_flush_timeout_ms / 1000.0)
        selected = target.nil? ? capture_target : target
        item = runtime_context.acquire_capture_target(selected, launch_uuid: @launch_uuid)
        unless item
          ReportportalCucumber.logger.warn("ReportPortal evidence rejected: target is not an open action in this launch")
          return false
        end
        leased = true

        artifacts = Array(artifacts)
        if artifacts.length > EVIDENCE_MAX_ARTIFACTS
          @log_buffer.reject_logs(count: artifacts.length + 1)
          ReportportalCucumber.logger.warn("ReportPortal evidence rejected: batch exceeds #{EVIDENCE_MAX_ARTIFACTS} artifacts")
          return false
        end
        payloads = artifacts.map { |artifact| build_evidence_payload(artifact) }
        names = payloads.map { |artifact| artifact[:name] }
        rendered = Service::EvidencePresenter.failure(
          action: action,
          error: error,
          url: url,
          details: details,
          artifact_names: names
        )
        redactor = Automation::EvidenceRedactor.new
        summary = redactor.redact_text(rendered.fetch(:summary, rendered.fetch("summary", "Failure evidence")))
        diagnostic = rendered[:details] || rendered["details"]
        message = [summary, diagnostic && redactor.redact_text(diagnostic)].compact.reject(&:empty?).join("\n\n")
        admissions = []
        published = runtime_context.publish_capture_target(selected, launch_uuid: @launch_uuid) do |open_item, cancelled|
          admissions << @log_buffer.emit_log(item_uuid: open_item.uuid, launch_uuid: @launch_uuid, message: message,
                                              level: :error, timestamp: monotonic_timestamp(Time.now),
                                              deadline: deadline, cancelled: cancelled)
          payloads.each do |payload|
            name = payload.fetch(:name)
            attachment = if payload.key?(:path)
                           { name: name, mime: payload.fetch(:mime), path: payload.fetch(:path) }
                         else
                           bytes = payload.fetch(:bytes)
                           { name: name, mime: payload.fetch(:mime), bytes: bytes }
                         end
            admissions << @log_buffer.emit_log(item_uuid: open_item.uuid, launch_uuid: @launch_uuid,
                                                message: "Failure evidence: #{name}", level: :error,
                                                timestamp: monotonic_timestamp(Time.now), attachment: attachment,
                                                deadline: deadline, cancelled: cancelled)
          end
        end
        unless published
          @log_buffer.reject_logs(count: payloads.length + 1) if admissions.empty?
          ReportportalCucumber.logger.warn("ReportPortal evidence rejected: target closed before publication completed")
          return false
        end
        unless admissions.all?
          warn_evidence_admission_once
          return false
        end
        true
      rescue StandardError => reporting_error
        ReportportalCucumber.logger.warn("ReportPortal evidence reporting failed: #{reporting_error.class}")
        false
      ensure
        runtime_context.release_capture_target(selected) if leased
      end

      # @param action [Object]
      # @param error [Object]
      # @param url [String, nil]
      # @param details [Object, nil]
      # @param artifacts [Array<Hash>]
      # @param target [Runtime::Context::CaptureTarget, nil]
      # @return [Boolean]
      def rp_evidence(action:, error:, url: nil, details: nil, artifacts: [], target: nil)
        report_evidence(action: action, error: error, url: url, details: details,
                        artifacts: artifacts, target: target)
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
        active_original = $!
        item_uuid = safe_reporting_call(fallback: local_uuid) do
          @api.start_item(
            name: name,
            start_time: start_time,
            type: "STEP",
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
          type: "STEP",
          has_stats: false,
          metadata: {}
        )
        runtime_context.push_step(item)
        capture_target = runtime_context.register_capture_target(item, launch_uuid: @launch_uuid, owner: self)

        yield
      rescue StandardError => error
        failure = error
        emit_error_log(item_uuid: item_uuid || local_uuid, error: error, timestamp: Time.now)
        raise
      ensure
        if item_uuid || local_uuid
          close_capture_target(capture_target) if capture_target
          flush_before_finish
          safe_reporting_call(preserve_business_exception: !active_original.nil? || !failure.nil?) do
            finish_item_request(
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
        level = Automation::ReportContext.current.fetch(:level, :info)
        if normalized_type == "text/x.cucumber.log+plain"
          emit_world_log(message: src.to_s, level: level, timestamp: Time.now)
          return
        end

        body = media_type.to_s.match?(/;base64\z/i) ? Base64.decode64(src.to_s) : src.to_s
        handle_attachment({
          file_name: filename || default_attachment_name(normalized_type),
          media_type: normalized_type.empty? ? "application/octet-stream" : normalized_type,
          body: body,
          content_encoding: "identity",
          message: filename ? "Attachment: #{filename}" : "Attachment"
        }, level: level)
      end

      private

      # @param artifact [Hash]
      # @return [Hash]
      def build_evidence_payload(artifact)
        options = artifact.transform_keys(&:to_sym)
        path = options[:path]
        bytes = options[:bytes]
        raise ArgumentError, "artifact must include path or bytes" if path.nil? && bytes.nil?

        filename = options[:name].is_a?(String) ? options[:name] : ""
        if path
          raise ArgumentError, "evidence path must be a string" unless path.is_a?(String)

          path = File.expand_path(path)
          raise ArgumentError, "evidence path is not a file" unless File.file?(path)

          filename = File.basename(path) if filename.empty?
          filename = Service::EvidencePresenter.sanitize_diagnostic(
            filename, limit: EVIDENCE_FILENAME_LIMIT
          )
          mime_filename = File.extname(filename).empty? ? File.basename(path) : filename
          mime = Transport::MultipartHelper.content_type_for(
            filename: mime_filename, declared_type: options[:mime]
          )
          return { name: filename, mime: mime, path: path }
        end

        bytes = bytes.read(1_048_577) if bytes.respond_to?(:read)
        bytes = bytes.to_s
        raise ArgumentError, "in-memory evidence exceeds 1 MiB" if bytes.bytesize > 1_048_576

        filename = Service::PayloadBuilder.default_attachment_name(options[:mime]) if filename.empty?
        filename = Service::EvidencePresenter.sanitize_diagnostic(
          filename, limit: EVIDENCE_FILENAME_LIMIT
        )
        mime = Transport::MultipartHelper.content_type_for(filename: filename, declared_type: options[:mime])
        { name: filename, mime: mime, bytes: bytes }
      end

      # @return [Boolean]
      def reporting_enabled?
        @config.enabled?
      end

      # @return [Boolean] Observe required reporting even when transport cannot be configured.
      def reporting_lifecycle_active?
        reporting_enabled? || (@configuration_failed && @config.require_complete_reporting?)
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
        dsl = ::Cucumber::Glue::Dsl
        language = dsl.instance_variable_get(:@rb_language)
        return unless language

        world_modules = language.instance_variable_get(:@world_modules)
        return if world_modules&.include?(ReportportalCucumber::Cucumber::World)

        dsl.build_rb_world_factory([ReportportalCucumber::Cucumber::World], {}, nil)
      end

      # @return [void]
      def install_exit_flush
        at_exit do
          next if @finalized

          # If native teardown never returned, do not infer success from scenario events.
          @business_failed = true
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
          if @config.ci_owned_launch?
            @config.launch_uuid
          elsif @config.join?
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
        source_metadata = @ast_metadata.scenario(uri: feature_uri, location_line: event_location_line(event))
        scenario_description = extract_scenario_description(
          feature_uri: feature_uri,
          scenario_line: scenario_line,
          metadata: source_metadata
        )
        code_ref = ReportPortal::Models.build_code_ref(feature_uri: feature_uri, scenario_line: scenario_line)
        explicit_test_case_id = explicit_test_case_id_for(event)
        scenario_description = build_scenario_links_description(
          description: scenario_description,
          feature_uri: feature_uri,
          scenario_line: scenario_line,
          source: source_metadata,
          explicit_id: explicit_test_case_id
        )
        identity = scenario_identity(
          feature_uri: feature_uri,
          code_ref: code_ref,
          parameters: parameters,
          explicit_id: explicit_test_case_id,
          source: source_metadata
        )
        test_case_id = identity ? identity.test_case_id : ReportPortal::Models.build_test_case_id(
          explicit_id: explicit_test_case_id,
          code_ref: code_ref,
          parameters: parameters
        )
        unique_id = identity ? identity.unique_id : ReportPortal::Models.build_unique_id(code_ref: code_ref, parameters: parameters)
        parameters = identity.parameters if identity && identity.strategy.to_s == "stable_v1"
        scenario_key = build_scenario_key(feature_uri: feature_uri, scenario_line: scenario_line, unique_id: unique_id)
        attempt_key = if identity && identity.strategy.to_s == "stable_v1"
                        stable_retry_key(parent_uuid: feature_parent_uuid, wire_name: "Scenario: #{scenario_name}", unique_id: unique_id)
                      else
                        scenario_key
                      end
        attempt = runtime_context.next_scenario_attempt(attempt_key)
        retry_flag = attempt > 1
        debug("Starting scenario name=#{scenario_name.inspect} code_ref=#{code_ref} retry=#{retry_flag} parameters=#{parameters.inspect}")
        scenario_attributes = build_scenario_attributes(
          source: source_metadata,
          explicit_id: explicit_test_case_id
        )
        local_uuid = SecureRandom.uuid
        scenario_item = {
          name: "Scenario: #{scenario_name}",
          start_time: start_time,
          type: "STEP",
          launch_uuid: @launch_uuid,
          parent_uuid: feature_parent_uuid,
          description: scenario_description,
          code_ref: code_ref,
          parameters: parameters,
          has_stats: true,
          retry: retry_flag,
          uuid: local_uuid,
          test_case_id: test_case_id,
          unique_id: unique_id
        }
        scenario_item[:attributes] = scenario_attributes unless scenario_attributes.nil?
        scenario_uuid = safe_reporting_call(fallback: local_uuid) do
          @api.start_item(**scenario_item)
        end

        item = Runtime::Context::ItemHandle.new(
          uuid: scenario_uuid,
          name: scenario_name,
          kind: :scenario,
          parent_uuid: feature_parent_uuid,
          type: "STEP",
          has_stats: true,
          metadata: {
            code_ref: code_ref,
            description: scenario_description,
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
          stable_retry_key: identity && identity.strategy.to_s == "stable_v1" ? attempt_key : nil,
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
            scenario_item.uuid
          end
        return unless parent_uuid

        step_descriptor = build_step_descriptor(event)
        step_name = extract_step_name(event, descriptor: step_descriptor)
        step_description = extract_step_description(event, descriptor: step_descriptor)
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
        runtime_context.register_capture_target(item, launch_uuid: @launch_uuid, owner: self)
        emit_step_markdown_log(item_uuid: step_uuid, description: step_description, timestamp: extract_timestamp(event) || Time.now) if step_descriptor&.rich?
        if (test_step_id = extract_test_step_id(event))
          runtime_context.associate_test_step(test_step_id, item)
        end
      end

      # @param event [Object]
      # @param level [String, Symbol]
      # @return [void]
      def handle_attachment(event, level: :info)
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
          level: level,
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
          # Native Cucumber can report a strict formatter exception as another failed-step event.
          @business_failed ||= !error.equal?(@strict_reporting_error)
          emit_error_log(item_uuid: item.uuid, error: error, timestamp: monotonic_timestamp(extract_timestamp(event) || Time.now))
        end

        debug("Finishing nested step uuid=#{item.uuid} status=#{status}")
        close_capture_target_for_item(item)
        flush_before_finish
        finish_time = monotonic_timestamp(extract_timestamp(event) || Time.now)
        safe_reporting_call do
          finish_item_request(
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

        @business_failed ||= extract_status(event).to_s.downcase == "failed"

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
        return unless reporting_lifecycle_active?

        if @native_lifecycle
          @native_run_status = extract_run_status(event)
          @business_failed ||= @native_run_status == "failed"
          return
        end

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
        return if @finalized || !reporting_lifecycle_active?

        @business_failed ||= ReportPortal::Models.normalize_status(status).to_s.downcase == "failed"
        @finalized = true
        unless @log_buffer
          @finalization_finished = true
          enforce_complete_reporting
          return
        end

        @finalization_deadline ||= Service::ReportingDeadline.new(timeout: @config.exit_flush_timeout_ms / 1000.0)
        closed = runtime_context.close_capture_targets(
          launch_uuid: @launch_uuid,
          timeout: @finalization_deadline.remaining
        )
        warn_capture_close_timeout unless closed
        flush_before_finish
        finish_open_scenarios(status: status, end_time: monotonic_timestamp(end_time))
        finish_feature_items(end_time: monotonic_timestamp(end_time))
        if @launch_uuid && !@config.ci_owned_launch? && (!@config.join? || @join.primary?)
          debug("Finalizing launch uuid=#{@launch_uuid} status=#{status}")
          safe_reporting_call do
            finish_launch_request(
              launch_uuid: @launch_uuid,
              end_time: monotonic_timestamp(end_time),
              status: status,
              attributes: @config.launch_attributes
            )
          end
        end
        @log_buffer.shutdown_receipt(timeout: @finalization_deadline.remaining, deadline: @finalization_deadline)
        @finalization_finished = true
        enforce_complete_reporting
      ensure
        emit_incomplete_reporting_summary(status) if @finalized
        if @finalized && ReportportalCucumber.current_runtime.equal?(self)
          ReportportalCucumber.current_runtime = nil
        end
      end

      # @return [void] Fail only otherwise successful runs, without reflecting configuration values.
      def enforce_complete_reporting
        return unless @config.require_complete_reporting? && !@business_failed && $!.nil? && !reporting_receipt.complete

        message = if @configuration_failed
                    "ReportPortal required reporting configuration is incomplete: missing #{@missing_reporting_options.join(', ')}"
                  else
                    "ReportPortal final reporting receipt is incomplete"
                  end
        raise ReportportalCucumber::ReportingError, message
      end

      # @param feature_uri [String]
      # @param start_time [Time]
      # @return [Runtime::Context::ItemHandle]
      def ensure_feature_item(feature_uri, start_time:)
        existing = runtime_context.feature_item(feature_uri)
        return runtime_context.activate_feature(feature_uri, existing) if existing

        local_uuid = SecureRandom.uuid
        feature_name = extract_feature_name(feature_uri)
        feature_description = extract_feature_description(feature_uri)
        feature_uuid = safe_reporting_call(fallback: local_uuid) do
          @api.start_item(
            name: feature_name,
            start_time: monotonic_timestamp(start_time),
            type: "SUITE",
            launch_uuid: @launch_uuid,
            description: feature_description,
            has_stats: true,
            retry: false,
            uuid: local_uuid
          )
        end
        item = Runtime::Context::ItemHandle.new(
          uuid: feature_uuid,
          name: feature_name,
          kind: :feature,
          parent_uuid: nil,
          type: "SUITE",
          has_stats: true,
          metadata: { feature_uri: feature_uri, description: feature_description }
        )
        runtime_context.activate_feature(feature_uri, runtime_context.register_feature(feature_uri, item))
      end

      # @param end_time [Time]
      # @return [void]
      def finish_feature_items(end_time:)
        runtime_context.feature_items.each do |feature_key, item|
          finish_feature_state(feature_key: feature_key, status: aggregate_status(feature_statuses_for_reporting(feature_key)), end_time: end_time, item: item)
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

        resolved_status = ReportPortal::Models.normalize_status(status) || aggregate_status(feature_statuses_for_reporting(feature_key))
        debug("Finishing feature feature=#{feature_key} uuid=#{item.uuid} status=#{resolved_status}")
        flush_before_finish
        safe_reporting_call do
          finish_item_request(
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
        flush_before_finish
        safe_reporting_call do
          finish_item_request(
            item_uuid: scenario_state[:item].uuid,
            launch_uuid: @launch_uuid,
            end_time: monotonic_timestamp(end_time),
            status: resolved_status
          )
        end
        if scenario_state[:stable_retry_key]
          @stable_scenario_outcomes[scenario_state[:feature_key]][scenario_state[:stable_retry_key]] = resolved_status
        else
          runtime_context.record_feature_status(scenario_state[:feature_key], resolved_status)
        end
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
          close_capture_target_for_item(item)
          flush_before_finish
          safe_reporting_call do
            finish_item_request(
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
      # @param preserve_business_exception [Boolean]
      # @yieldreturn [Object]
      # @return [Object]
      def safe_reporting_call(fallback: nil, preserve_business_exception: false)
        yield
      rescue StandardError => error
        @reporting_failures += 1
        handle_reporting_error(error)
        if @config.fail_on_reporting_error? && !@business_failed && !preserve_business_exception
          @strict_reporting_error = error
          raise
        end

        fallback
      end

      # @return [Boolean]
      def flush_before_finish
        receipt = @log_buffer.flush_receipt(timeout: remaining_finalization_budget,
                                            deadline: @finalization_deadline)
        return true if receipt.local_settled

        ReportportalCucumber.logger.warn("ReportPortal log flush timed out before item finish; delivery is unconfirmed")
        false
      end

      # @param target [Runtime::Context::CaptureTarget]
      # @return [Boolean]
      def close_capture_target(target)
        closed = runtime_context.close_capture_target(
          target,
          timeout: remaining_finalization_budget
        )
        warn_capture_close_timeout unless closed
        closed
      end

      # @param item [Runtime::Context::ItemHandle]
      # @return [Boolean]
      def close_capture_target_for_item(item)
        closed = runtime_context.close_capture_target_for_item(
          item,
          timeout: remaining_finalization_budget
        )
        warn_capture_close_timeout unless closed
        closed
      end

      # @return [void]
      def warn_capture_close_timeout
        @capture_close_timeouts += 1
        ReportportalCucumber.logger.warn("ReportPortal evidence target close timed out; target was cancelled")
      end

      # @return [Float]
      def remaining_finalization_budget
        @finalization_deadline ? @finalization_deadline.remaining : @config.exit_flush_timeout_ms / 1000.0
      end

      # Emit a bounded whole-run summary without allowing logger failure to affect the business result.
      # @param status [String, Symbol, nil]
      # @return [void]
      def emit_incomplete_reporting_summary(status)
        return unless reporting_lifecycle_active? && !@incomplete_summary_emitted

        @incomplete_summary_emitted = true
        receipt = reporting_receipt
        return if receipt.complete

        business = @business_failed || ReportPortal::Models.normalize_status(status).to_s.downcase == "failed" ? "failed" : "passed"
        message = "ReportPortal reporting incomplete: business=#{business} reporting=incomplete " \
                  "confirmed=#{receipt.confirmed} spooled=#{receipt.spooled} pending=#{receipt.pending} " \
                  "ambiguous=#{receipt.ambiguous} possible_duplicates=#{receipt.possible_duplicates}"
        ReportportalCucumber.logger.warn(message)
      rescue StandardError
        nil
      end

      # @param arguments [Hash]
      # @return [Object]
      def finish_item_request(**arguments)
        if @finalization_deadline
          @api.finish_item(**arguments, deadline: @finalization_deadline)
        else
          @api.finish_item(**arguments)
        end
      end

      # @param arguments [Hash]
      # @return [Object]
      def finish_launch_request(**arguments)
        if @finalization_deadline
          @api.finish_launch(**arguments, deadline: @finalization_deadline)
        else
          @api.finish_launch(**arguments)
        end
      end

      # @param error [StandardError]
      # @return [void]
      def handle_reporting_error(error)
        diagnostic = Service::EvidencePresenter.sanitize_diagnostic(error.message, limit: 2048)
        ReportportalCucumber.logger.warn("#{error.class}: #{diagnostic}")
      rescue StandardError
        nil
      end

      # @return [void]
      def warn_evidence_admission_once
        emit = @evidence_admission_warning_mutex.synchronize do
          next false if @evidence_admission_warning_emitted

          @evidence_admission_warning_emitted = true
        end
        ReportportalCucumber.logger.warn("ReportPortal failure evidence was partially rejected by the bounded queue") if emit
      rescue StandardError
        nil
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

      # @param item_uuid [String]
      # @param description [String, nil]
      # @param timestamp [Time]
      # @return [void]
      def emit_step_markdown_log(item_uuid:, description:, timestamp:)
        return if description.to_s.strip.empty?

        @log_buffer.emit_log(
          item_uuid: item_uuid,
          launch_uuid: @launch_uuid,
          message: description,
          level: :info,
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
        aggregate_status(runtime_context.feature_items.keys.flat_map { |key| feature_statuses_for_reporting(key) })
      end

      # @param feature_key [String]
      # @return [Array<String>]
      def feature_statuses_for_reporting(feature_key)
        stable_outcomes = @stable_scenario_outcomes && @stable_scenario_outcomes[feature_key]
        runtime_context.feature_statuses(feature_key) + Array(stable_outcomes&.values)
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

      # @param feature_uri [String]
      # @param code_ref [String]
      # @param parameters [Hash, Array<Hash>, nil]
      # @param explicit_id [String, nil]
      # @param source [Hash, nil]
      # @return [Service::ScenarioIdentity::Result, nil]
      def scenario_identity(feature_uri:, code_ref:, parameters:, explicit_id:, source:)
        strategy = @config.respond_to?(:identity_strategy) ? @config.identity_strategy : "legacy"
        return unless strategy.to_s == "stable_v1"

        result = Service::ScenarioIdentity.build(
          strategy: strategy,
          explicit_id: explicit_id,
          code_ref: code_ref,
          parameters: parameters,
          feature_uri: feature_uri,
          source: source,
          root: @config.identity_root,
          namespace: @config.identity_namespace
        )
        warn_identity_once(result.fallback_reason) if result.strategy.to_s != "stable_v1"
        result
      rescue StandardError => error
        raise if @config.respond_to?(:fail_on_reporting_error?) && @config.fail_on_reporting_error?

        warn_identity_once("identity_error_#{error.class}")
        nil
      end

      # @param reason [Object]
      # @return [void]
      def warn_identity_once(reason)
        value = reason.to_s
        key = if %w[missing_source ambiguous_source].include?(value)
                value
              elsif value.match?(/\Aidentity_error_[A-Z]\w*(?:::\w+)*\z/)
                value
              else
                "fallback"
              end
        @identity_warnings ||= Set.new
        return if @identity_warnings.include?(key)

        @identity_warnings << key
        ReportportalCucumber.logger.warn("Stable scenario identity unavailable; using legacy identity (#{key})")
      end

      # @param parent_uuid [String]
      # @param wire_name [String]
      # @param unique_id [String]
      # @return [String]
      def stable_retry_key(parent_uuid:, wire_name:, unique_id:)
        JSON.generate([@launch_uuid, parent_uuid, wire_name, unique_id])
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

      # @param source [Hash, nil]
      # @param explicit_id [String, nil]
      # @return [Array<Hash>, nil] Scenario attributes, or nil when disabled/unavailable
      def build_scenario_attributes(source:, explicit_id:)
        return unless @config.respond_to?(:scenario_attributes_enabled)
        return unless @config.scenario_attributes_enabled

        result = Service::ScenarioAttributes.build(
          defaults: @config.scenario_attributes,
          tag_scopes: source&.fetch(:tag_scopes, nil),
          allowed_keys: @config.scenario_attribute_keys,
          explicit_id: explicit_id
        )
        Array(result.diagnostics).each do |diagnostic|
          warn_scenario_attribute_diagnostic(diagnostic, allowed_keys: @config.scenario_attribute_keys)
        end
        result.attributes
      rescue StandardError => error
        ReportportalCucumber.logger.warn("Scenario attributes unavailable (#{error.class})")
        nil
      end

      # @param description [String, nil]
      # @param feature_uri [String]
      # @param scenario_line [Integer]
      # @param source [Hash, nil]
      # @param explicit_id [String, nil]
      # @return [String, nil]
      def build_scenario_links_description(description:, feature_uri:, scenario_line:, source:, explicit_id:)
        enabled = if @config.respond_to?(:scenario_links_enabled?)
                    @config.scenario_links_enabled?
                  elsif @config.respond_to?(:scenario_links_enabled)
                    @config.scenario_links_enabled
                  else
                    false
                  end
        return description unless enabled

        result = Service::ScenarioLinks.build(
          description: description,
          feature_uri: expanded_scenario_link_feature_uri(feature_uri),
          scenario_line: scenario_line,
          example_row_line: source&.fetch(:example_row_line, nil),
          explicit_id: explicit_id,
          source_url_template: optional_config_value(:source_url_template),
          source_commit: optional_config_value(:source_commit),
          source_root: optional_config_value(:source_root),
          ci_run_url: optional_config_value(:ci_run_url),
          tms_url_template: optional_config_value(:tms_url_template)
        )
        warn_scenario_link_diagnostics(result.diagnostics)
        result.description
      rescue StandardError => error
        ReportportalCucumber.logger.warn("Scenario links unavailable (#{error.class})")
        description
      end

      # @param name [Symbol]
      # @return [Object, nil]
      def optional_config_value(name)
        @config.public_send(name) if @config.respond_to?(name)
      end

      # @param diagnostics [Array<Object>]
      # @return [void]
      def warn_scenario_link_diagnostics(diagnostics)
        Array(diagnostics).each do |diagnostic|
          reason = diagnostic.is_a?(Hash) ? diagnostic[:reason] || diagnostic["reason"] : diagnostic
          safe_reason = if (reason.is_a?(Symbol) || reason.is_a?(String)) && SAFE_SCENARIO_LINK_DIAGNOSTICS.include?(reason.to_s)
                          reason.to_s
                        else
                          "invalid_link"
                        end
          ReportportalCucumber.logger.warn("Scenario link omitted (#{safe_reason})")
        end
      end

      # @param feature_uri [Object]
      # @return [Object]
      def expanded_scenario_link_feature_uri(feature_uri)
        return feature_uri unless feature_uri.is_a?(String)
        return feature_uri unless [Encoding::UTF_8, Encoding::US_ASCII].include?(feature_uri.encoding)
        return feature_uri unless feature_uri.valid_encoding?
        return feature_uri if feature_uri.match?(/[\\\x00-\x1f\x7f]/)
        return feature_uri if feature_uri.split("/").include?("..")

        File.expand_path(feature_uri, Dir.pwd)
      rescue StandardError
        feature_uri
      end

      # @param diagnostic [Hash]
      # @param allowed_keys [Array<String>]
      # @return [void]
      def warn_scenario_attribute_diagnostic(diagnostic, allowed_keys:)
        return unless diagnostic.is_a?(Hash)

        reason = diagnostic[:reason]
        scope = diagnostic[:scope]
        key = diagnostic[:key]
        safe_reason = %w[conflict invalid_value invalid_entry missing_source].include?(reason.to_s) ? reason.to_s : "invalid_attribute"
        safe_scope = %w[default feature rule scenario examples explicit_id].include?(scope.to_s) ? scope.to_s : nil
        allowed = Array(allowed_keys).map { |entry| entry.to_s.downcase }
        normalized_key = key.to_s.downcase if !key.nil? && key.to_s.match?(/\A[a-z][a-z0-9_.-]*\z/i)
        safe_key = normalized_key if normalized_key && allowed.include?(normalized_key)
        details = [safe_reason, safe_scope && "scope=#{safe_scope}", safe_key && "key=#{safe_key}"].compact.join(", ")
        ReportportalCucumber.logger.warn("Scenario attribute ignored (#{details})")
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
        provided = fetch_value(event, :parameters, [:example, :parameters], [:test_case, :parameters], [:pickle, :parameters])
        return provided unless provided.nil?

        metadata = extract_outline_metadata(event)
        metadata&.fetch(:parameters, nil)
      end

      # @param event [Object]
      # @return [String]
      def extract_feature_uri(event)
        fetch_value(event, :feature_uri, [:test_case, :location, :file], [:uri], [:pickle, :uri]) || "unknown.feature"
      end

      # @param feature_uri [String]
      # @return [String]
      def extract_feature_name(feature_uri)
        metadata = @ast_metadata.feature(uri: feature_uri)
        name = metadata && metadata[:name].to_s
        keyword = metadata && metadata[:keyword].to_s
        return "#{keyword}: #{name}" unless name.to_s.empty?

        "Feature: #{File.basename(feature_uri, File.extname(feature_uri)).tr('_', ' ')}"
      end

      # @param feature_uri [String]
      # @return [String, nil]
      def extract_feature_description(feature_uri)
        @ast_metadata.feature(uri: feature_uri)&.fetch(:description, nil)
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

      # @param feature_uri [String]
      # @param scenario_line [Integer]
      # @return [String, nil]
      def extract_scenario_description(feature_uri:, scenario_line:, metadata: nil)
        metadata ||= @ast_metadata.scenario(uri: feature_uri, location_line: scenario_line)
        return unless metadata

        parts = []
        parts << metadata[:description]
        if metadata[:rule_name]
          parts << "Rule: #{metadata[:rule_name]}"
          parts << metadata[:rule_description]
        end
        if metadata[:examples_name] || metadata[:example_row_line]
          parts << "Examples: #{metadata[:examples_name]}" if metadata[:examples_name]
          parts << "Example row: #{metadata[:example_row_line]}" if metadata[:example_row_line]
          parameters = metadata[:parameters]
          parts << parameter_description_table(parameters) if parameters
        end
        parts.compact.reject { |part| part.to_s.empty? }.join("\n\n").then { |value| value.empty? ? nil : value }
      end

      # @param event [Object]
      # @param descriptor [ReportportalCucumber::ReportPortal::Models::StepDesc, nil]
      # @return [String]
      def extract_step_name(event, descriptor: nil)
        descriptor ||= build_step_descriptor(event)
        base_name =
          descriptor&.summary_name ||
          fetch_value(event, :step_text, [:test_step, :text], [:test_step, :name], [:pickle_step, :text], :name) || "Step"
        return hook_display_name(event, base_name) if extract_hook?(event)
        return "[Background] #{base_name}" if extract_background?(event, descriptor: descriptor)

        base_name
      end

      # @param event [Object]
      # @param descriptor [ReportportalCucumber::ReportPortal::Models::StepDesc, nil]
      # @return [String, nil]
      def extract_step_description(event, descriptor: nil)
        return nil if extract_hook?(event)

        (descriptor || build_step_descriptor(event))&.to_markdown
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

        hook = fetch_value(event, :hook, [:test_step, :hook], [:test_step, :hook?])
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
          "BEFORE_METHOD"
        when "after", "after_method"
          "AFTER_METHOD"
        when "after_step"
          "AFTER_METHOD"
        when "before_all", "before_class"
          "BEFORE_CLASS"
        when "after_all", "after_class"
          "AFTER_CLASS"
        else
          "STEP"
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
      def extract_background?(event, descriptor: nil)
        value = fetch_value(event, :background, :background_step, [:test_step, :background], [:pickle_step, :background])
        return true if value == true

        test_step = fetch_value(event, :test_step)
        metadata = test_step && @ast_metadata.step(test_step)
        return true if metadata && metadata[:background]
        return false if value == false

        unless test_step && fetch_value(test_step, [:location, :lines], [:location, :line])
          feature_uri = extract_feature_uri(event)
          feature_uri = runtime_context.current_feature_key if feature_uri == "unknown.feature"
          step_text = background_candidate_text(event, descriptor: descriptor)
          metadata = @ast_metadata.background_for_text(uri: feature_uri, text: step_text)
          return true if metadata
        end

        keyword = fetch_value(event, :keyword, [:test_step, :keyword], [:pickle_step, :keyword]).to_s
        return true if keyword.match?(/\Abackground\b/i)

        false
      end

      # @param event [Object]
      # @param descriptor [ReportportalCucumber::ReportPortal::Models::StepDesc, nil]
      # @return [String, nil]
      def background_candidate_text(event, descriptor:)
        descriptor ||= build_step_descriptor(event)
        text = descriptor&.gherkin_text
        text ||= fetch_value(event, :step_text, [:test_step, :text], [:test_step, :name], [:pickle_step, :text], :name)
        text.to_s.strip.sub(/\A(?:Given|When|Then|And|But|\*)\s+/, "")
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
        location_line = event_location_line(event)
        return nil if feature_uri.to_s.empty? || location_line.nil?

        metadata = @ast_metadata.scenario(uri: feature_uri, location_line: location_line)
        metadata if metadata && metadata[:parameters]
      end

      # @param feature_uri [String]
      # @param location_line [Integer]
      # @return [Hash, nil]
      def parse_outline_metadata(feature_uri, location_line)
        metadata = @ast_metadata.scenario(uri: feature_uri, location_line: location_line)
        return unless metadata && metadata[:parameters]

        { scenario_line: metadata[:scenario_line], parameters: metadata[:parameters] }
      end

      # @param parameters [Hash<String, String>]
      # @return [String]
      def parameter_description_table(parameters)
        rows = [parameters.keys, Array.new(parameters.length, "---"), parameters.values].map do |cells|
          "| #{cells.map do |cell|
            cell.to_s.gsub(/\\|\r\n|[|\r\n]/) do |character|
              case character
              when "\\" then "\\\\"
              when "|" then "\\|"
              else "<br>"
              end
            end
          end.join(' | ')} |"
        end
        rows.join("\n")
      end

      # @param event [Object]
      # @return [Integer, nil]
      def event_location_line(event)
        fetch_value(event, [:test_case, :location, :lines], [:test_case, :location, :line],
                    [:location, :lines], [:location, :line], [:pickle, :location, :line], :scenario_line).then do |value|
          if value.is_a?(Array) || value.is_a?(Set) || value.respond_to?(:to_a)
            values = Array(value.to_a).flat_map { |item| item.respond_to?(:to_a) ? item.to_a : [item] }
            value = values.map { |item| fetch_value(item, :line) || item }.max
          end
          value&.to_i
        end
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
