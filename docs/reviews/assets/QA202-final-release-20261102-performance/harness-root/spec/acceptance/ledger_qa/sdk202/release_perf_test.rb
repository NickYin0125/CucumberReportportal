# frozen_string_literal: true

require "minitest/autorun"
require_relative "release_perf_driver"

# SDK-free doubles keep harness tests outside the authorized timing window.
module ReportportalCucumber
  class Config
    attr_reader :presentation
    def initialize(value = {})
      @presentation = value.fetch(:presentation, "plain")
    end
  end
  module Presentation
    class FailureCard
      def self.format(error:, message:, backtrace:, presentation:)
        [presentation, error.class.name, message, backtrace].join("\n")
      end
    end
  end
  module Cucumber
    class Formatter
      class << self
        attr_accessor :wrong_mode, :skip_renderer
      end
      def emit_error_log(item_uuid:, error:, timestamp:)
        message = if self.class.skip_renderer
                    "fallback"
                  else
                    Presentation::FailureCard.format(error: error, message: error.message,
                      backtrace: error.backtrace.join("\n"), presentation: self.class.wrong_mode || @config.presentation)
                  end
        @log_buffer.emit_log(item_uuid: item_uuid, level: :error, message: message, timestamp: timestamp)
      end
    end
  end
end

class ReleasePerfTest < Minitest::Test
  def setup
    ReportportalCucumber::Cucumber::Formatter.wrong_mode = nil
    ReportportalCucumber::Cucumber::Formatter.skip_renderer = false
  end

  def receipt
    { "final_sha" => ReleasePerf202::FINAL, "master_quiet_window_approved" => true,
      "live_network_browser_work_finished" => true, "no_other_heavy_jobs" => true,
      "master_authorization_quote" => "Exclusive quiet window approved", "quiet_window_id" => "test-window",
      "granted_at_utc" => "2026-11-02T00:00:00Z" }
  end

  def row
    value = { "class" => "RuntimeError", "message" => "exact recorded message", "frames" => ["/project/steps.rb:42"] }
    value.merge("input_id" => Digest::SHA256.hexdigest(JSON.generate(value.values_at("class", "message", "frames"))))
  end

  def measured(role, value)
    { "status" => "MEASURED", "role" => role, "mode" => "rich", "corpus_sha256" => ReleasePerf202::CORPUS,
      "receipt_sha256" => "receipt", "environment_sha256" => "env",
      "source_sha" => role == "baseline" ? ReleasePerf202::BASELINE : ReleasePerf202::FINAL,
      "samples_ms" => ReleasePerf202::BOUNDARIES.to_h { |b| [b, Array.new(1050, value)] } }
  end

  def test_explicit_grant_required_for_each_condition
    assert ReleasePerf202.gate!(receipt)
    %w[master_quiet_window_approved live_network_browser_work_finished no_other_heavy_jobs].each do |key|
      assert_raises(RuntimeError) { ReleasePerf202.gate!(receipt.merge(key => false)) }
    end
    %w[master_authorization_quote quiet_window_id granted_at_utc].each do |key|
      assert_raises(RuntimeError) { ReleasePerf202.gate!(receipt.merge(key => "")) }
    end
    assert_raises(RuntimeError) { ReleasePerf202.gate!(receipt.merge("final_sha" => "other")) }
  end

  def test_correct_config_key_and_both_actual_modes_without_clock
    assert_equal "plain", ReportportalCucumber::Config.new("rp.presentation" => "rich").presentation
    %w[plain rich].each do |mode|
      result = ReleasePerf202.measure(rows: [row], mode: mode, timed: false, clock: -> { flunk "Validation called clock" })
      assert_equal "VALIDATED_WITHOUT_TIMING", result.fetch("status")
      assert_equal mode, result.fetch("cases").first.fetch("resolved_mode")
      assert_equal mode, result.fetch("cases").first.fetch("passed_mode")
      assert result.fetch("samples_ms").values.all?(&:empty?)
    end
  end

  def test_wrong_renderer_mode_fails_before_timing
    ReportportalCucumber::Cucumber::Formatter.wrong_mode = "plain"
    assert_raises(RuntimeError) { ReleasePerf202.prepare_case(row, "rich") }
  end

  def test_no_renderer_call_is_not_replaced_with_fabricated_input
    ReportportalCucumber::Cucumber::Formatter.skip_renderer = true
    assert_raises(RuntimeError) { ReleasePerf202.prepare_case(row, "rich") }
  end

  def test_samples_and_per_input_raw_values_using_fake_clock_only
    tick = 0
    result = ReleasePerf202.measure(rows: [row], mode: "rich", timed: true, clock: -> { tick += 1; tick / 10000.0 })
    ReleasePerf202::BOUNDARIES.each do |boundary|
      assert_equal 50, result.fetch("samples_ms").fetch(boundary).length
      assert_equal result.fetch("samples_ms").fetch(boundary), result.fetch("cases").first.fetch("samples_ms").fetch(boundary)
    end
    assert_equal 200, tick
  end

  def test_no_gate_relaxation
    comparison = ReleasePerf202.compare(measured("baseline", 1.0), measured("candidate", 1.10))
    assert comparison.all? { |r| r.fetch("regression_pass") }
    comparison = ReleasePerf202.compare(measured("baseline", 1.0), measured("candidate", 1.10001))
    assert comparison.none? { |r| r.fetch("regression_pass") }
    comparison = ReleasePerf202.compare(measured("baseline", 2.0), measured("candidate", 2.0))
    assert_equal false, comparison.first.fetch("renderer_under_2ms")
  end

  def test_incomplete_or_unmatched_measurement_fails_closed
    before, after = measured("baseline", 1), measured("candidate", 1)
    assert_raises(RuntimeError) { ReleasePerf202.compare(before, after.merge("mode" => "plain")) }
    assert_raises(RuntimeError) { ReleasePerf202.compare(before, after.merge("status" => "INCOMPLETE")) }
    assert_raises(RuntimeError) { ReleasePerf202.compare(before, after.merge("source_sha" => "other")) }
    after.fetch("samples_ms").fetch("renderer_only").pop
    assert_raises(RuntimeError) { ReleasePerf202.compare(before, after) }
  end

  def test_frozen_corpus_count_order_bytes_and_weight
    path = File.join(ReleasePerfDriver202::QA, ReleasePerfDriver202::CORPUS_PATH)
    corpus = JSON.parse(File.read(path))
    assert_equal ReleasePerf202::CORPUS_FILE, Digest::SHA256.file(path).hexdigest
    assert_equal 21, ReleasePerf202.validate_corpus!(corpus).length
    original = Marshal.dump(corpus)
    corpus.fetch("cases").reverse!
    assert_raises(RuntimeError) { ReleasePerf202.validate_corpus!(corpus) }
    corpus = Marshal.load(original)
    corpus.fetch("cases").pop
    assert_raises(RuntimeError) { ReleasePerf202.validate_corpus!(corpus) }
    corpus = Marshal.load(original)
    corpus.fetch("cases").first["message"] += "changed"
    assert_raises(RuntimeError) { ReleasePerf202.validate_corpus!(corpus) }
  end

  def test_original_quiet_thresholds_and_host_guard
    sample = { "containers" => [{ "name" => "rp2607-control-plane" }], "total_cpu_percent" => 20,
      "host_loadavg" => "{ 1.00 2.00 3.00 }", "host_ncpu" => 8 }
    assert ReleasePerfDriver202.quiet?([sample, sample, sample])
    refute ReleasePerfDriver202.quiet?([sample, sample])
    refute ReleasePerfDriver202.quiet?([sample, sample, sample.merge("total_cpu_percent" => 36)])
    refute ReleasePerfDriver202.quiet?([sample, sample, sample.merge("total_cpu_percent" => 4)])
    refute ReleasePerfDriver202.quiet?([sample, sample, sample.merge("host_loadavg" => "{ 8.01 1 1 }")])
    refute ReleasePerfDriver202.quiet?([sample, sample, sample.merge("containers" => [{ "name" => "unapproved-worker" }])])
  end

  def test_invalid_samples
    [[], [0], [-1], [Float::NAN], [Float::INFINITY], ["1"]].each do |values|
      assert_raises(RuntimeError) { ReleasePerf202.p95(values) }
    end
    assert_equal 95, ReleasePerf202.p95((1..100).to_a)
  end
end
