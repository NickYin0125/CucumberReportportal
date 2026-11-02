# frozen_string_literal: true

require "minitest/autorun"
require_relative "live"

class Ledger202LiveTest < Minitest::Test
  def snapshot
    { "persistence" => "live_readback", "items" => [{ "id" => 1, "name" => "Scenario", "status" => "FAILED", "type" => "STEP", "hasStats" => true }],
      "logs" => [{ "id" => 2, "itemId" => 1, "message" => "safe", "level" => "ERROR" }], "launches" => [{ "name" => "QA202" }],
      "files" => [], "queries" => [{ "secret_marker" => { "page" => { "totalElements" => 0 } } }] }
  end

  def test_clean_capture
    assert_empty Ledger202Live.safety(snapshot, [])
  end

  def test_secret_is_a_stop
    data = snapshot
    data["logs"][0]["message"] = "SECRET123"
    assert_includes Ledger202Live.safety(data, []), "probe_secret_visible"
  end

  def test_attachment_loss_is_a_stop
    assert_includes Ledger202Live.safety(snapshot, [{ "files" => [{ "sha256" => "abc", "bytes" => 3 }] }]), "raw_attachment_bytes_changed_or_missing"
  end

  def test_status_and_ownership_changes_are_visible
    before = Ledger202Live.signature(snapshot)
    after = snapshot
    after["items"][0]["status"] = "PASSED"
    refute_equal before, Ledger202Live.signature(after)
    after = snapshot
    after["logs"][0].delete("itemId")
    refute_equal before, Ledger202Live.signature(after)
  end

  def test_qa_wrapper_retains_frozen_and_framework_adapters
    assert Ledger202Live::Frozen.ancestors.include?(LedgerQA::FrozenRunner)
    assert Ledger202Live::Framework.ancestors.include?(LedgerQA::FrameworkShapeRunner)
    assert_equal Ledger202Live::NoClock, LedgerDeveloper::Runner.instance_method(:execute).owner
    refute Object.const_defined?(:ReportportalCucumber)
  end
end
