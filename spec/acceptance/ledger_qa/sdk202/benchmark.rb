# frozen_string_literal: true

require "json"
require "digest"

# Library only. No SDK is loaded, process launched, or timing taken on require.
module Ledger202Benchmark
  BASELINE = "3f20313c20b25071fbc49b31e1c6bc772bd599e4"
  BOUNDARIES = %w[renderer_only redaction_plus_rendering].freeze

  def self.gate!(receipt, role:, mode:)
    raise "HOLD: Master final handoff absent" unless receipt["master_final_handoff"] == true &&
      receipt["final_sha"].to_s.match?(/\A[0-9a-f]{40}\z/) && !receipt.fetch("launch_ids", []).empty?
    raise "HOLD: Master quiet window absent" unless receipt["master_quiet_window_approved"] == true &&
      !receipt["quiet_window_id"].to_s.strip.empty? && receipt["no_other_heavy_jobs"] == true
    raise "HOLD: unsupported role/mode" unless %w[baseline candidate].include?(role) && %w[plain rich].include?(mode)
    raise "HOLD: source proof absent" unless receipt["source_bytes_verified"] == true &&
      receipt["source_sha"] == (role == "baseline" ? BASELINE : receipt["final_sha"])
    env = receipt.fetch("environment", {})
    required = %w[image_id ruby cucumber architecture dependency_sha256 cpu_limit memory_limit]
    raise "HOLD: incomplete pinned environment" unless required.all? { |key| !env[key].to_s.empty? } &&
      env["image_id"].match?(/\Asha256:[0-9a-f]{64}\z/) && env["cucumber"] == "12.0.1"
    true
  end

  def self.p95(samples)
    raise "Invalid timing samples" if samples.empty? || samples.any? { |v| !v.is_a?(Numeric) || !v.finite? || v <= 0 }
    samples.sort[(samples.length * 0.95).ceil - 1]
  end

  def self.error_for(row)
    # A fresh process per arm prevents reconstructed classes leaking between runtimes.
    klass = row.fetch("class").split("::").inject(Object) do |context, name|
      raise "Unsafe recorded exception class" unless name.match?(/\A[A-Z]\w*\z/)
      context.const_get(name, false)
    end
    raise "Recorded type is not an exception" unless klass.is_a?(Class) && klass <= Exception
    message, frames = row.values_at("message", "frames")
    klass.allocate.tap do |error|
      error.define_singleton_method(:message) { message.dup }
      error.define_singleton_method(:to_s) { message.dup }
      error.define_singleton_method(:backtrace) { frames.map(&:dup) }
    end
  end

  def self.measure(receipt:, corpus:, role:, mode:)
    gate!(receipt, role: role, mode: mode)
    cases = corpus.fetch("cases")
    ids = cases.map do |row|
      id = Digest::SHA256.hexdigest(JSON.generate(row.values_at("class", "message", "frames")))
      raise "Corpus input changed" unless row.fetch("input_id") == id
      id
    end
    raise "Corpus weighting changed" unless cases.length == 21 &&
      Digest::SHA256.hexdigest(JSON.generate(ids)) == corpus.fetch("corpus_sha256") &&
      receipt["corpus_sha256"] == corpus.fetch("corpus_sha256")
    samples = BOUNDARIES.to_h { |b| [b, []] }
    failure = nil
    begin
      cases.each do |row|
        formatter = ReportportalCucumber::Cucumber::Formatter.allocate
        formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new("rp.presentation" => mode))
        formatter.instance_variable_set(:@launch_uuid, "offline-ledger202")
        sink = Object.new
        sink.define_singleton_method(:emit_log) { |**_fields| nil }
        formatter.instance_variable_set(:@log_buffer, sink)
        formatter.define_singleton_method(:monotonic_timestamp) { |value| value }
        error = error_for(row)
        timestamp = Time.utc(2026, 11, 1)
        pipeline = -> { formatter.send(:emit_error_log, item_uuid: "offline-ledger202-item", error: error, timestamp: timestamp) }
        target = ReportportalCucumber::Presentation::FailureCard
        original = target.method(:format)
        calls = []
        wrapper = Module.new do
          define_method(:format) do |*args, **kwargs, &block|
            calls << [args, kwargs, block]
            super(*args, **kwargs, &block)
          end
        end
        target.singleton_class.prepend(wrapper)
        begin
          pipeline.call
        ensure
          wrapper.send(:remove_method, :format)
        end
        raise "Renderer not called exactly once; no fabricated safe input" unless calls.length == 1
        args, kwargs, block = calls.first
        renderer = -> { original.call(*args, **kwargs, &block) }
        { "renderer_only" => renderer, "redaction_plus_rendering" => pipeline }.each do |boundary, invoke|
          10.times { invoke.call }
          50.times do
            started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            invoke.call
            samples.fetch(boundary) << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
          end
        end
      end
    rescue StandardError => error
      failure = error.class.name
    end
    { "schema" => "ledger-202-matched-timings/1", "status" => failure ? "INCOMPLETE" : "MEASURED_NOT_SCORED",
      "error_class" => failure, "role" => role, "mode" => mode, "receipt" => receipt,
      "corpus_sha256" => corpus.fetch("corpus_sha256"), "samples_ms" => samples }
  end

  def self.compare(before, after)
    raise "Incomplete measurements" unless [before, after].all? { |r| r["status"] == "MEASURED_NOT_SCORED" }
    raise "Wrong comparison roles" unless before["role"] == "baseline" && after["role"] == "candidate"
    [before, after].each { |r| gate!(r.fetch("receipt"), role: r.fetch("role"), mode: r.fetch("mode")) }
    %w[mode corpus_sha256].each { |k| raise "Unmatched #{k}" unless before.fetch(k) == after.fetch(k) }
    %w[environment final_sha quiet_window_id launch_ids].each do |k|
      raise "Unmatched #{k}" unless before.fetch("receipt").fetch(k) == after.fetch("receipt").fetch(k)
    end
    BOUNDARIES.map do |boundary|
      old, current = [before, after].map { |r| r.fetch("samples_ms").fetch(boundary) }
      raise "Incomplete sample weighting" unless old.length == 1050 && current.length == 1050
      old_p95, new_p95 = p95(old), p95(current)
      { boundary: boundary, old_p95_ms: old_p95, new_p95_ms: new_p95,
        stop_more_than_10_percent: new_p95 > old_p95 * 1.10,
        presentation_under_2_ms: boundary == "renderer_only" ? new_p95 < 2 : nil }
    end
  end
end
