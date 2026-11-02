# frozen_string_literal: true

require "json"
require "digest"

module ReleasePerf202
  BASELINE = "3f20313c20b25071fbc49b31e1c6bc772bd599e4"
  FINAL = "8f44c10533eb4d0a8eae1adcc2ed5b63ace155c7"
  IMAGE = "sha256:316dd4f6b6de632d5ade7bdb78fc33f7e82db8a87785e93a8a2c8d81706d3fe7"
  VOLUME = "ledger-qa202-9bf3356-dependencies"
  DEPENDENCIES = "3a015e3a12387b249ede5ebd6cdb5b638eb916c95c036ff4755cefb081e1536b"
  CORPUS_FILE = "d8b2f24a9d531d9114e02ed960ad50618a42c98d8fdfb22308be7ff285421177"
  CORPUS = "a99b8d138ce4b63d63b531698bf33ffcb0b0ca263136ac20517e4c72a1bd1d4f"
  BOUNDARIES = %w[renderer_only redaction_plus_rendering].freeze

  def self.validate_corpus!(corpus)
    rows = corpus.fetch("cases")
    ids = rows.map do |row|
      id = Digest::SHA256.hexdigest(JSON.generate(row.values_at("class", "message", "frames")))
      raise "Changed corpus input" unless id == row.fetch("input_id")
      id
    end
    raise "Changed corpus count/order/weight" unless rows.length == 21 && corpus.fetch("corpus_sha256") == CORPUS &&
      Digest::SHA256.hexdigest(JSON.generate(ids)) == CORPUS
    rows
  end

  def self.gate!(receipt)
    raise "NOT RUN: final SHA mismatch" unless receipt["final_sha"] == FINAL
    raise "NOT RUN: explicit Master exclusive quiet grant missing" unless
      receipt["master_quiet_window_approved"] == true && receipt["live_network_browser_work_finished"] == true &&
      receipt["no_other_heavy_jobs"] == true && !receipt["master_authorization_quote"].to_s.strip.empty? &&
      receipt["quiet_window_id"].to_s.match?(/\A[a-zA-Z0-9_-]+\z/) &&
      !receipt["granted_at_utc"].to_s.empty?
    true
  end

  def self.p95(samples)
    raise "Invalid samples" if samples.empty? || samples.any? { |v| !v.is_a?(Numeric) || !v.finite? || v <= 0 }
    samples.sort[(samples.length * 0.95).ceil - 1]
  end

  def self.compare(before, after, count: 1050)
    raise "Unmeasured input" unless [before, after].all? { |r| r.fetch("status") == "MEASURED" }
    raise "Wrong roles" unless before["role"] == "baseline" && after["role"] == "candidate"
    %w[mode corpus_sha256 receipt_sha256 environment_sha256].each do |key|
      raise "Unmatched #{key}" unless before.fetch(key) == after.fetch(key)
    end
    raise "Wrong source SHA" unless before["source_sha"] == BASELINE && after["source_sha"] == FINAL
    BOUNDARIES.map do |boundary|
      old, current = [before, after].map { |r| r.fetch("samples_ms").fetch(boundary) }
      raise "Incomplete weighting" unless old.length == count && current.length == count
      a, b = p95(old), p95(current)
      { "boundary" => boundary, "mode" => before.fetch("mode"), "baseline_p95_ms" => a,
        "candidate_p95_ms" => b, "regression_percent" => (b / a - 1) * 100,
        "regression_pass" => b <= a * 1.10, "renderer_under_2ms" => boundary == "renderer_only" ? b < 2 : nil }
    end
  end

  def self.diagnostic_cost(result)
    raise "Unmeasured diagnostic" unless result.fetch("status") == "MEASURED" &&
      result.fetch("scope") == "supplement_only_not_frozen_corpus"
    { "role" => result.fetch("role"), "mode" => result.fetch("mode"), "source_sha" => result.fetch("source_sha"),
      "purpose" => "Absolute encoded-URL cost only; no acceptance threshold or passthrough-versus-sanitization speed gate",
      "boundaries" => result.fetch("samples_ms").transform_values do |values|
        { "count" => values.length, "p95_ms" => p95(values), "median_ms" => values.sort[values.length / 2], "maximum_ms" => values.max }
      end,
      "per_input" => result.fetch("cases").map do |row|
        { "input_id" => row.fetch("input_id"), "resolved_mode" => row.fetch("resolved_mode"),
          "passed_mode" => row.fetch("passed_mode"), "output_sha256" => row.fetch("output_sha256"),
          "boundaries" => row.fetch("samples_ms").transform_values { |v| { "count" => v.length, "p95_ms" => p95(v) } } }
      end }
  end

  def self.error_for(row)
    klass = row.fetch("class").split("::").inject(Object) do |context, name|
      raise "Unsafe exception class" unless name.match?(/\A[A-Z]\w*\z/)
      context.const_get(name, false)
    end
    raise "Not an exception" unless klass.is_a?(Class) && klass <= Exception
    klass.allocate.tap do |error|
      error.define_singleton_method(:message) { row.fetch("message").dup }
      error.define_singleton_method(:to_s) { row.fetch("message").dup }
      error.define_singleton_method(:backtrace) { row.fetch("frames").map(&:dup) }
    end
  end

  def self.prepare_case(row, mode)
    formatter = ReportportalCucumber::Cucumber::Formatter.allocate
    config = ReportportalCucumber::Config.new(presentation: mode)
    raise "Resolved presentation differs from requested mode" unless config.presentation == mode
    formatter.instance_variable_set(:@config, config)
    formatter.instance_variable_set(:@launch_uuid, "release-perf-offline")
    sink = Object.new
    emissions = []
    sink.define_singleton_method(:emit_log) { |**fields| emissions << fields }
    formatter.instance_variable_set(:@log_buffer, sink)
    formatter.define_singleton_method(:monotonic_timestamp) { |value| value }
    error = error_for(row)
    timestamp = Time.utc(2026, 11, 2)
    pipeline = lambda do
      formatter.send(:emit_error_log, item_uuid: "release-perf-item", error: error, timestamp: timestamp)
      emissions.clear
    end
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
      formatter.send(:emit_error_log, item_uuid: "release-perf-item", error: error, timestamp: timestamp)
    ensure
      wrapper.send(:remove_method, :format)
    end
    raise "Renderer not called exactly once; no fabricated replacement" unless calls.length == 1
    args, kwargs, block = calls.first
    raise "Renderer passed wrong presentation" unless kwargs.fetch(:presentation) == mode
    raise "No single ERROR emission" unless emissions.length == 1 && emissions.first.fetch(:level) == :error
    output = emissions.first.fetch(:message)
    proof = { "input_id" => row.fetch("input_id"), "resolved_mode" => config.presentation,
      "passed_mode" => kwargs.fetch(:presentation), "output_sha256" => Digest::SHA256.hexdigest(output),
      "output_bytes" => output.bytesize, "renderer_calls" => calls.length }
    emissions.clear
    [pipeline, -> { original.call(*args, **kwargs, &block) }, proof]
  end

  def self.measure(rows:, mode:, timed:, clock: nil)
    clock ||= -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    samples = BOUNDARIES.to_h { |b| [b, []] }
    per_input = []
    rows.each do |row|
      pipeline, renderer, proof = prepare_case(row, mode)
      record = proof.merge("samples_ms" => {})
      if timed
        { "renderer_only" => renderer, "redaction_plus_rendering" => pipeline }.each do |boundary, call|
          10.times { call.call }
          values = Array.new(50) do
            start = clock.call
            call.call
            (clock.call - start) * 1000
          end
          p95(values)
          record["samples_ms"][boundary] = values
          samples.fetch(boundary).concat(values)
        end
      end
      per_input << record
    end
    { "status" => timed ? "MEASURED" : "VALIDATED_WITHOUT_TIMING", "mode" => mode,
      "cases" => per_input, "samples_ms" => samples, "warmups_per_input" => timed ? 10 : 0,
      "samples_per_input" => timed ? 50 : 0 }
  end

  def self.supplement
    ["https://example.test/path?%74oken=QA_RELEASE_ENCODED_SECRET&visible=1",
     "https://user:QA_RELEASE_ENCODED_SECRET@example.test/path?password=QA_RELEASE_ENCODED_SECRET",
     "https://bad%GG:QA_RELEASE_ENCODED_SECRET@example.test/path?api_key=QA_RELEASE_ENCODED_SECRET"].map do |url|
      row = { "class" => "RuntimeError", "message" => "Request failed #{url}",
        "frames" => ["/project/steps/http.rb:42:in `request'"] }
      row.merge("input_id" => Digest::SHA256.hexdigest(JSON.generate(row.values_at("class", "message", "frames"))))
    end
  end
end
