# frozen_string_literal: true

require_relative "evidence_redactor"

module Automation
  # Keeps failure messages independent of frames without splitting credentials.
  class FailureRedactor
    Result = Struct.new(:message, :backtrace, :baseline, :fallback_only, keyword_init: true)
    # Only immutable policy is shared; scanners, budgets and evidence remain local to each call.
    DEFAULT_REDACTOR = EvidenceRedactor.new.freeze
    private_constant :DEFAULT_REDACTOR

    # @param redactor [EvidenceRedactor] The unchanged evidence safety policy.
    def initialize(redactor: DEFAULT_REDACTOR)
      @redactor = redactor
    end

    # @param message [String] Original exception message.
    # @param frames [Array<String>] Original entries, including embedded newlines.
    # @return [Result] Redacted parts and an exact safe presentation fallback.
    def redact(message:, frames:)
      backtrace = frames.join("\n")
      if @redactor.cross_unit_credential?([message, *frames])
        return redact_boundary(message, backtrace)
      end

      safe_message = @redactor.redact_text(message)
      safe_backtrace = @redactor.redact_text(backtrace)
      omitted_frames = safe_backtrace == EvidenceRedactor::OMITTED
      safe_backtrace = frames.map { |frame| @redactor.redact_text(frame) }.join("\n") if omitted_frames
      changed_lines = safe_message.count("\n") != message.count("\n") ||
                      safe_backtrace.count("\n") != backtrace.count("\n")
      withheld = safe_message == EvidenceRedactor::OMITTED
      empty_redaction = safe_message.empty? && safe_backtrace.empty? && (!message.empty? || !backtrace.empty?)
      result(safe_message, safe_backtrace,
             fallback_only: empty_redaction || (changed_lines && !withheld && !omitted_frames))
    end

    private

    def redact_boundary(message, backtrace)
      raw = join(message, backtrace)
      baseline = @redactor.redact_text(raw)
      if baseline == EvidenceRedactor::OMITTED || baseline.count("\n") != raw.count("\n")
        return Result.new(message: "", backtrace: "", baseline: baseline.empty? ? "Step failed" : baseline,
                          fallback_only: true)
      end

      return result("", baseline) if message.empty?
      return result(baseline, "") if backtrace.empty?

      lines = baseline.split("\n", -1)
      boundary = message.count("\n") + 1
      result(lines.take(boundary).join("\n"), lines.drop(boundary).join("\n"))
    end

    def result(message, backtrace, fallback_only: false)
      baseline = join(message, backtrace)
      Result.new(message: message, backtrace: backtrace, baseline: baseline.empty? ? "Step failed" : baseline,
                 fallback_only: fallback_only)
    end

    def join(message, backtrace)
      [message, backtrace].reject(&:empty?).join("\n")
    end
  end
end
