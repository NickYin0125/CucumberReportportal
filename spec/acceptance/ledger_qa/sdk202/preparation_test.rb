# frozen_string_literal: true

require "minitest/autorun"
require_relative "benchmark"
require_relative "prepare"

class Ledger202PreparationTest < Minitest::Test
  def receipt(role = "baseline")
    { "master_final_handoff" => true, "final_sha" => "a" * 40, "launch_ids" => [999999],
      "master_quiet_window_approved" => true, "quiet_window_id" => "SYNTHETIC-NOT-AUTHORIZATION",
      "no_other_heavy_jobs" => true, "source_bytes_verified" => true,
      "source_sha" => role == "baseline" ? Ledger202Benchmark::BASELINE : "a" * 40,
      "environment" => { "image_id" => "sha256:" + "b" * 64, "ruby" => "3.4.12",
        "cucumber" => "12.0.1", "architecture" => "aarch64-linux", "dependency_sha256" => "c" * 64,
        "cpu_limit" => "2", "memory_limit" => "3g" } }
  end

  def recording(role, renderer, pipeline)
    { "status" => "MEASURED_NOT_SCORED", "role" => role, "mode" => "plain", "receipt" => receipt(role),
      "corpus_sha256" => "synthetic", "samples_ms" => {
        "renderer_only" => Array.new(1050, renderer), "redaction_plus_rendering" => Array.new(1050, pipeline) } }
  end

  def test_no_receipt_blocks_before_sdk_or_corpus_access
    assert_raises(RuntimeError) { Ledger202Benchmark.measure(receipt: {}, corpus: nil, role: "candidate", mode: "plain") }
    refute Object.const_defined?(:ReportportalCucumber)
  end

  def test_each_gate_is_required
    %w[master_final_handoff final_sha launch_ids master_quiet_window_approved quiet_window_id no_other_heavy_jobs source_bytes_verified source_sha environment].each do |key|
      bad = receipt
      bad.delete(key)
      assert_raises(RuntimeError) { Ledger202Benchmark.gate!(bad, role: "baseline", mode: "plain") }
    end
  end

  def test_strict_ratio_is_applied_independently
    equal = Ledger202Benchmark.compare(recording("baseline", 1.0, 2.0), recording("candidate", 1.1, 2.2))
    assert equal.none? { |r| r[:stop_more_than_10_percent] }
    slow = Ledger202Benchmark.compare(recording("baseline", 1.0, 2.0), recording("candidate", 1.11, 2.0))
    assert slow[0][:stop_more_than_10_percent]
    refute slow[1][:stop_more_than_10_percent]
    slow = Ledger202Benchmark.compare(recording("baseline", 1.0, 2.0), recording("candidate", 1.0, 2.21))
    refute slow[0][:stop_more_than_10_percent]
    assert slow[1][:stop_more_than_10_percent]
  end

  def test_unmatched_or_partial_samples_cannot_compare
    %w[environment final_sha quiet_window_id launch_ids].each do |key|
      after = recording("candidate", 1.0, 2.0)
      after["receipt"][key] = "mismatch"
      assert_raises(RuntimeError) { Ledger202Benchmark.compare(recording("baseline", 1.0, 2.0), after) }
    end
    after = recording("candidate", 1.0, 2.0)
    after["samples_ms"]["renderer_only"].pop
    assert_raises(RuntimeError) { Ledger202Benchmark.compare(recording("baseline", 1.0, 2.0), after) }
  end

  def test_nearest_rank_and_invalid_samples
    assert_equal 95, Ledger202Benchmark.p95((1..100).to_a)
    [[], [0], [-1], [Float::NAN], [Float::INFINITY]].each do |values|
      assert_raises(RuntimeError) { Ledger202Benchmark.p95(values) }
    end
  end

  def test_historical_evidence_without_executing_sdk
    plan, corpus = Ledger202Preparation.build
    assert_equal "HOLD_FOR_MASTER", plan[:status]
    assert_nil plan[:final_verdict]
    assert_equal 21, corpus[:cases].length
    assert_equal 2100, plan.dig(:accepted_check, "actual", "micro", "FailureCard.format", "count")
    assert_equal 1.6121249936986715, plan.dig(:accepted_check, "actual", "micro", "FailureCard.format", "p95_ms")
    assert_equal "FAIL", plan.dig(:excluded_early_result, :verdict)
    assert_equal 0, plan[:benchmarks_executed]
    refute Object.const_defined?(:ReportportalCucumber)
  end
end
