# frozen_string_literal: true

require "json"
require "mime/types"
require_relative "report_context"
require_relative "http_exchange"
require_relative "../service/evidence_presenter"

module Automation
  # Triple-track logger for Cucumber automation code.
  #
  # It mirrors concise diagnostics to the terminal, optionally writes rich
  # payloads to Cucumber's native event bus, and forwards the same evidence to
  # ReportPortal when the current world exposes an active RP runtime.
  class CucumberLogger
    LEVEL_COLORS = {
      trace: 90,
      debug: 90,
      info: 36,
      warn: 33,
      error: 31,
      fatal: 31
    }.freeze
    LEVELS = LEVEL_COLORS.keys.freeze
    ATTACHED_MARKER = "(Attached to Report)"

    # @param world_object [Object, nil] Cucumber World instance.
    # @param world [Object, nil] Keyword-friendly Cucumber World instance.
    # @param output [#puts, nil] Terminal output target. Uses current $stdout when nil.
    # @param color [Boolean, nil] Force ANSI color when true/false; auto-detect when nil.
    # @return [CucumberLogger]
    def initialize(world_object = nil, world: nil, output: nil, color: nil)
      @world = world || world_object
      @output = output
      @color = color
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def trace(message, attach: false, file: nil, json: nil, report: nil)
      log(:trace, message, attach: attach, file: file, json: json, report: report)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def debug(message, attach: false, file: nil, json: nil, report: nil)
      log(:debug, message, attach: attach, file: file, json: json, report: report)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def info(message, attach: false, file: nil, json: nil, report: nil)
      log(:info, message, attach: attach, file: file, json: json, report: report)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def warn(message, attach: false, file: nil, json: nil, report: nil)
      log(:warn, message, attach: attach, file: file, json: json, report: report)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def error(message, attach: false, file: nil, json: nil, report: nil)
      log(:error, message, attach: attach, file: file, json: json, report: report)
    end

    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def fatal(message, attach: false, file: nil, json: nil, report: nil)
      log(:fatal, message, attach: attach, file: file, json: json, report: report)
    end

    # @param level [String, Symbol]
    # @param message [Object]
    # @param attach [Boolean]
    # @param file [String, nil]
    # @param json [Object, nil]
    # @param report [Boolean, nil] Override whether the message is routed to reporting.
    # @return [void]
    def log(level, message, attach: false, file: nil, json: nil, report: nil)
      normalized_level = normalize_level(level)
      report_enabled = report.nil? ? attach : report
      write_terminal(terminal_line(level: normalized_level, message: message, attach: report_enabled, file: file, json: json),
                     normalized_level)
      return unless report_enabled

      rich_message = rich_message(message: message, json: json)
      emit_cucumber_log(rich_message, normalized_level)
      emit_cucumber_attachment(file, normalized_level) if file
      emit_reportportal_log(rich_message, normalized_level)
      emit_reportportal_attachment(file, rich_message, normalized_level) if file
    end

    # @param method [String, Symbol]
    # @param url [String]
    # @param request [Hash]
    # @param response [Hash]
    # @param duration_ms [Numeric, nil]
    # @param expected_status [Integer, nil]
    # @param error [Object, nil]
    # @param report [Boolean]
    # @return [void]
    def http(method:, url:, request: {}, response: {}, duration_ms: nil, expected_status: nil, error: nil, report: true)
      exchange = HttpExchange.new(
        method: method,
        url: url,
        request: request,
        response: response,
        duration_ms: duration_ms,
        expected_status: expected_status,
        error: error
      )
      level = normalize_level(exchange.level)
      summary = exchange.summary
      write_terminal(terminal_line(level: level, message: summary, attach: report, file: nil, json: nil), level)
      return unless report

      report_message = exchange.to_markdown
      emit_cucumber_log(report_message, level)
      emit_reportportal_log(report_message, level)
    end

    # Records a structured diagnostic without changing the test result.
    # @param name [String] Assertion or check name.
    # @param expected [Object] Expected value to include in the comparison.
    # @param actual [Object] Observed value to include in the comparison.
    # @param passed [Boolean] Diagnostic outcome; does not affect the test result.
    # @param details [Object, nil] Optional supplementary diagnostic details.
    # @param report [Boolean] Whether to route Markdown to Cucumber and ReportPortal.
    # @return [void]
    def assertion(name:, expected:, actual:, passed:, details: nil, report: true)
      presentation = ReportportalCucumber::Service::EvidencePresenter.assertion(
        name: name, expected: expected, actual: actual, passed: passed, details: details
      )
      level = passed ? :info : :error
      write_terminal(terminal_line(level: level, message: presentation.fetch(:summary), attach: report,
                                  file: nil, json: nil), level)
      return unless report

      markdown = presentation.fetch(:markdown)
      emit_cucumber_log(markdown, level)
      emit_reportportal_log(markdown, level)
    end

    # @return [Boolean]
    def rp_active?
      return false unless @world && (@world.respond_to?(:rp_log) || @world.respond_to?(:rp_attach))
      return !!@world.rp_active? if @world.respond_to?(:rp_active?)
      return true unless defined?(::ReportportalCucumber) && ::ReportportalCucumber.respond_to?(:current_runtime)

      !::ReportportalCucumber.current_runtime.nil?
    end

    private

    def normalize_level(level)
      key = level.to_s.downcase.to_sym
      LEVELS.include?(key) ? key : :info
    end

    def terminal_line(level:, message:, attach:, file:, json:)
      suffixes = []
      suffixes << ATTACHED_MARKER if attach
      suffixes << "(file: #{File.basename(file.to_s)})" if file
      suffixes << "(json payload)" unless json.nil?
      ["[APPLOG] [#{level.to_s.upcase}]", one_line(message), *suffixes].join(" ")
    end

    def one_line(message)
      message.to_s.gsub(/\s+/, " ").strip
    end

    def write_terminal(output, level)
      line = colorize?(level) ? "\e[#{LEVEL_COLORS.fetch(level)}m#{output}\e[0m" : output
      terminal_output.puts(line)
    end

    def colorize?(level)
      return @color unless @color.nil?

      terminal_output.respond_to?(:tty?) && terminal_output.tty? && ENV["NO_COLOR"].to_s.empty? && LEVEL_COLORS.key?(level)
    end

    def terminal_output
      @output || $stdout
    end

    def rich_message(message:, json:)
      return message.to_s if json.nil?

      "#{message}\n\n```json\n#{pretty_json(json)}\n```"
    end

    def pretty_json(value)
      parsed = value.is_a?(String) ? JSON.parse(value) : value
      JSON.pretty_generate(parsed)
    rescue JSON::ParserError, JSON::GeneratorError
      value.to_s
    end

    def emit_cucumber_log(message, level)
      safe_call(:world_log) do
        ReportContext.with(level: level) { @world.log(message) } if @world&.respond_to?(:log)
      end
    end

    def emit_cucumber_attachment(file, level)
      safe_call(:world_attach) do
        next unless @world&.respond_to?(:attach)
        next unless File.file?(file.to_s)

        ReportContext.with(level: level) do
          @world.attach(File.binread(file.to_s), content_type_for(file), File.basename(file.to_s))
        end
      end
    end

    def emit_reportportal_log(message, level)
      return unless rp_active?
      return if cucumber_event_bus_backed_by_reportportal?

      safe_call(:rp_log) do
        next unless @world.respond_to?(:rp_log)

        rp_log = @world.method(:rp_log)
        accepts_mirror = rp_log.parameters.any? do |kind, name|
          kind == :keyrest || (%i[key keyreq].include?(kind) && name == :mirror)
        end
        keywords = { level: level }
        keywords[:mirror] = false if accepts_mirror
        rp_log.call(message, **keywords)
      end
    end

    def emit_reportportal_attachment(file, message, level)
      return unless rp_active?
      return if cucumber_event_bus_backed_by_reportportal?
      return unless @world.respond_to?(:rp_attach)
      return unless File.file?(file.to_s)

      safe_call(:rp_attach) do
        @world.rp_attach(file.to_s, mime_type: content_type_for(file), message: message, level: level)
      end
    end

    def content_type_for(file)
      filename = File.basename(file.to_s)
      if defined?(::ReportportalCucumber::Transport::MultipartHelper)
        return ::ReportportalCucumber::Transport::MultipartHelper.content_type_for(
          filename: filename,
          declared_type: nil
        )
      end

      MIME::Types.type_for(filename).first&.content_type || "application/octet-stream"
    end

    def safe_call(route)
      yield
    rescue StandardError => e
      safe_message = EvidenceRedactor.new.redact_text(e.message)
      write_terminal("[APPLOG] [WARN] #{route} routing failed: #{e.class}: #{safe_message}", :warn)
    end

    def cucumber_event_bus_backed_by_reportportal?
      return false unless defined?(::ReportportalCucumber)
      return false unless ::ReportportalCucumber.respond_to?(:current_runtime)

      runtime = ::ReportportalCucumber.current_runtime
      defined?(::ReportportalCucumber::Cucumber::Formatter) &&
        runtime.is_a?(::ReportportalCucumber::Cucumber::Formatter)
    end
  end
end
