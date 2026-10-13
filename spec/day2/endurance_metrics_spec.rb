# frozen_string_literal: true

require "spec_helper"
require_relative "../../examples/day2_endurance/support"
require_relative "../../examples/day2_endurance/reconcile"

RSpec.describe Day2Endurance::Session do
  let(:session) { described_class.new(directory: Dir.tmpdir, target_seconds: 900, warmup: 120, rss_max_mb: 200, rss_slope_mb_min: 2, threads_max: 16) }

  def rows(rss:, threads: 8)
    rss.each_with_index.map { |value, index| { elapsed_seconds: 120 + index * 60, rss_mb: value, process_threads: threads } }
  end

  it "accepts bounded post-warmup growth without making a zero-leak claim" do
    session.samples.concat(rows(rss: [100, 101, 102]))
    expect(session.resource_checks.fetch(:observed_rss_slope_mb_min)).to eq(1)
  end

  it "rejects excessive maximum RSS" do
    session.samples.concat(rows(rss: [210, 210, 210]))
    expect { session.resource_checks }.to raise_error(Day2Endurance::InvariantError, "post-warmup RSS maximum")
    expect(session.resource_result.fetch(:observed_rss_max_mb)).to eq(210)
  end

  it "rejects excessive RSS trend" do
    session.samples.concat(rows(rss: [100, 104, 108]))
    expect { session.resource_checks }.to raise_error(Day2Endurance::InvariantError, "post-warmup RSS trend")
  end

  it "rejects excessive process thread count" do
    session.samples.concat(rows(rss: [100, 100, 100], threads: 17))
    expect { session.resource_checks }.to raise_error(Day2Endurance::InvariantError, "post-warmup thread maximum")
  end

  it "rejects insufficient post-warmup evidence" do
    session.samples.concat(rows(rss: [100, 100]))
    expect { session.resource_checks }.to raise_error(/Insufficient/)
  end

  it "uses real monotonic elapsed time" do
    before = session.elapsed
    sleep 0.01
    expect(session.elapsed - before).to be >= 0.01
  end

  it "rejects NaN resource limits" do
    expect { described_class.new(directory: Dir.tmpdir, target_seconds: 900, rss_max_mb: Float::NAN) }.to raise_error(ArgumentError)
  end

  it "rejects warmup longer than acceptance" do
    expect { described_class.new(directory: Dir.tmpdir, target_seconds: 900, warmup: 900) }.to raise_error(ArgumentError)
  end

  [[:peak_records, 129, "queue record bound"], [:peak_bytes, 8_388_609, "queue byte bound"]].each do |key, value, message|
    it "records and rejects #{message} breaches" do
      Dir.mktmpdir("metric-bound-") do |directory|
        sensor = described_class.new(directory: directory, target_seconds: 900)
        allow(Day2Endurance::ProcessProbe).to receive(:read).and_return(rss_mb: 100, process_threads: 1, source: "unit sensor")
        queue = { current_records: 0, current_bytes: 0, peak_records: 1, peak_bytes: 100 }.merge(key => value)
        Day2Endurance.formatter = double(reporting_diagnostics: queue, reporting_receipt: double(to_h: {}), config: double(queue_max_records: 128, queue_max_bytes: 8_388_608))
        expect { sensor.sample("bound-test") }.to raise_error(Day2Endurance::InvariantError, message)
        expect(JSON.parse(File.read(File.join(directory, "metrics.ndjson"))).fetch("queue").fetch(key.to_s)).to eq(value)
      ensure
        Day2Endurance.formatter = nil
      end
    end
  end
end

RSpec.describe Day2Endurance::PrivateOutput do
  it "redacts the in-memory bearer before writing diagnostics" do
    output = StringIO.new
    described_class.new(output, bearer: "unit-private-canary").puts("prefix unit-private-canary suffix")
    expect(output.string).to eq("prefix [REDACTED] suffix\n")
  end

  it "supports the actual Cucumber logger IO contract" do
    output = StringIO.new
    Logger.new(described_class.new(output, bearer: "canary")).warn("canary")
    expect(output.string).to include("[REDACTED]")
    expect(output.string).not_to include("canary")
  end
end

RSpec.describe Day2Endurance::Reconciler do
  it "retrieves every RP result page rather than silently truncating log counts" do
    reconciler = described_class.new(endpoint: "http://rp.example", bearer: "unit-not-a-credential")
    stub_request(:get, /rp.example/).with(query: hash_including("page.page" => "1")).to_return(body: JSON.generate(content: [{ id: 1 }], page: { totalPages: 2 }))
    stub_request(:get, /rp.example/).with(query: hash_including("page.page" => "2")).to_return(body: JSON.generate(content: [{ id: 2 }], page: { totalPages: 2 }))
    expect(reconciler.query("log", "filter.eq.launch" => 1)).to eq([{ "id" => 1 }, { "id" => 2 }])
  end

  context "complete native and RP reconciliation" do
    let(:reconciler) { described_class.new(endpoint: "http://rp.example", bearer: "unit-not-a-credential") }
    let(:csv) { "batch_id,status\nb1,COMPLETED\n" }
    let(:launch) { { "id" => 1, "name" => "unit-run", "status" => "PASSED", "endTime" => 1, "statistics" => { "executions" => { "total" => 8, "passed" => 8 } } } }
    let(:items) do
      [{ "id" => 100, "uuid" => "suite-uuid", "type" => "SUITE" }] +
        8.times.map { |index| { "id" => index + 1, "uuid" => "case-#{index + 1}", "name" => "Scenario: case #{index + 1}", "parent" => 100, "type" => "STEP", "hasStats" => true, "status" => "PASSED" } } +
        [{ "id" => 200, "uuid" => "pbt-action", "name" => "When I bombard the clearing duration APIs", "type" => "STEP", "hasStats" => false, "parent" => 8 }]
    end
    let(:logs) do
      [{ "id" => 11, "itemId" => 8, "message" => "Duration huge JSON iteration=1\n" + "x" * 500_001 },
       { "id" => 12, "itemId" => 8, "message" => "CSV", "binaryContent" => { "id" => "binary-1" } },
       { "id" => 13, "itemId" => 200, "message" => "Duration PBT invariant checks iteration=1" }]
    end
    let(:native) { [{ "elements" => 8.times.map { |index| { "type" => "scenario", "name" => "case #{index + 1}", "steps" => [{ "result" => { "status" => "passed" } }] } } }] }
    let(:receipt) do
      ReportportalCucumber::Service::DeliveryReceipt::FIELDS.to_h { |key| [key, 0] }.merge(complete: true, local_settled: true, timed_out: false, confirmed: 3, cutoff: 3, settled: 3)
    end
    let(:artifacts) { [{ owner_uuid: "case-8", name: "settlement.csv", bytes: csv.bytesize, sha256: Digest::SHA256.hexdigest(csv) }] }

    before do
      Day2Endurance.session = nil
      allow(reconciler).to receive(:query).with("launch", "filter.eq.name" => "unit-run").and_return([launch])
      allow(reconciler).to receive(:query).with("item", "filter.eq.launchId" => 1).and_return(items)
      allow(reconciler).to receive(:query).with("log", "filter.eq.launch" => 1).and_return([])
      allow(reconciler).to receive(:query).with("log", hash_including("filter.eq.item")) do |_resource, filter|
        logs.select { |row| row["itemId"] == filter.fetch("filter.eq.item") }
      end
      allow(reconciler).to receive(:response).with("api/v1/data/superadmin_personal/binary-1").and_return(Struct.new(:body).new(csv))
    end

    def verify
      reconciler.run(name: "unit-run", receipt: receipt, native: native, artifacts: artifacts, pbt: { "huge_json_logs" => 1, "iterations" => 1 })
    end

    it "matches complete outcomes, log counts, original owner and downloaded CSV hash" do
      expect(verify.fetch(:attachments).first).to include(owner_uuid: "case-8", bytes: csv.bytesize, sha256: Digest::SHA256.hexdigest(csv))
    end

    it "rejects missing RP logs despite a complete receipt" do
      logs.delete_at(1)
      expect { verify }.to raise_error(Day2Endurance::InvariantError, /exact RP log count/)
    end

    it "rejects attachment corruption despite matching log counts" do
      allow(reconciler).to receive(:response).and_return(Struct.new(:body).new("corrupt"))
      expect { verify }.to raise_error(Day2Endurance::InvariantError, /CSV bytes and hash/)
    end

    it "rejects attachments moved to another owner" do
      logs[1]["itemId"] = 7
      expect { verify }.to raise_error(Day2Endurance::InvariantError, /CSV bytes and hash/)
    end

    it "rejects truncated huge JSON" do
      logs.first["message"] = "Duration huge JSON iteration=1\ntruncated"
      expect { verify }.to raise_error(Day2Endurance::InvariantError, /huge JSON/)
    end

    it "rejects failed native steps even when RP reports success" do
      native.first["elements"].first["steps"].first["result"]["status"] = "failed"
      expect { verify }.to raise_error(Day2Endurance::InvariantError, /native all steps passed/)
    end

    it "rejects a receipt with local spool rather than server confirmation" do
      receipt[:spooled] = 1
      expect { verify }.to raise_error(Day2Endurance::InvariantError, /no lost or ambiguous/)
    end

    it "rejects a wrong scenario parent" do
      items.find { |row| row["id"] == 8 }["parent"] = 1
      expect { verify }.to raise_error(Day2Endurance::InvariantError, /cases owned by their suites/)
    end

    it "rejects incorrect launch statistics" do
      launch["statistics"]["executions"]["passed"] = 7
      expect { verify }.to raise_error(Day2Endurance::InvariantError, /statistics passed/)
    end
  end
end
