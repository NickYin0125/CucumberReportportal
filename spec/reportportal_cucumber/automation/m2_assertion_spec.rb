# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe "M2 assertion diagnostics" do
  it "presents concise failure summary and bounded details" do
    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "submit", error: RuntimeError.new("request failed"),
      url: "https://user:password@example.test/?token=secret",
      details: "Password: private\n" + ("detail " * 50_000), artifact_names: []
    )

    expect(result).to include(:summary, :details)
    expect(result.fetch(:summary)).to include("submit", "RuntimeError")
    expect(result.values.join).not_to include("password", "secret", "private")
    expect(result.fetch(:details).bytesize).to be <= 16_384
  end

  it "redacts quoted JSON secrets before bounded details and error summaries are clipped" do
    canary = "CANARY_M2_" + ("x" * 17_000)
    long_json = JSON.generate(password: canary)
    error_secret = "CANARY_M2_ERROR_" + ("y" * 300)

    result = ReportportalCucumber::Service::EvidencePresenter.failure(
      action: "request", error: RuntimeError.new(JSON.generate(password: error_secret)),
      details: long_json
    )

    expect(result.values.join).not_to include("CANARY_M2_")
    expect(result.fetch(:details).bytesize).to be <= 16_384
    expect(result.fetch(:summary).bytesize).to be <= 512
  end

  it "fails closed on a dangling escape and JSON whitespace at the public details limit" do
    limit = ReportportalCucumber::Service::EvidencePresenter::DETAILS_LIMIT
    head = '{"password":"CANARY_DANGLING_'
    clipped_at_escape = head + ("d" * (limit - head.bytesize - 1)) + "\\"
    complete_source = clipped_at_escape + %q("tail"})
    multiline = "{\"password\":\r\n  \"CANARY_MULTILINE_#{"m" * (limit + 100)}\"}"

    expect(JSON.parse(complete_source).fetch("password")).to start_with("CANARY_DANGLING_")
    expect(JSON.parse(multiline).fetch("password")).to start_with("CANARY_MULTILINE_")

    [complete_source, multiline].each do |details|
      result = ReportportalCucumber::Service::EvidencePresenter.failure(
        action: "request", error: RuntimeError.new("failed"), details: details
      )

      expect(result.fetch(:details)).not_to include("CANARY_DANGLING_", "CANARY_MULTILINE_")
      expect(result.fetch(:details).bytesize).to be <= limit
    end
  end

  it "reports pass and failure comparisons without changing Cucumber outcome" do
    world = double("Cucumber world", log: nil)
    output = StringIO.new
    AppLog.bind(world, output: output, color: false)
    expect { AppLog.assertion(name: "total", expected: 3, actual: 3, passed: true) }.not_to raise_error
    expect { AppLog.assertion(name: "total", expected: 3, actual: 4, passed: false) }.not_to raise_error

    expect(output.string).to include("PASS", "FAIL", "total")
    expect(output.string).not_to include("expected: 3", "actual: 4")
  ensure
    AppLog.clear!
  end

  it "redacts assertion values in terminal, native Cucumber logs, and ReportPortal payloads" do
    native = []
    rp_entries = []
    world = Object.new
    world.define_singleton_method(:rp_active?) { true }
    world.define_singleton_method(:log) { |message| native << message }
    world.define_singleton_method(:rp_log) do |message, level = nil, **_options|
      rp_entries << [message, level]
    end
    output = StringIO.new
    AppLog.bind(world, output: output, color: false)
    long_secret = "CANARY_M2_ASSERTION_" + ("z" * 17_000)

    AppLog.assertion(
      name: "credential check", expected: { password: "expected-secret" },
      actual: { password: "actual-secret" }, passed: false,
      details: JSON.generate(payload: { password: long_secret }), report: true
    )

    [output.string, native.join, rp_entries.inspect].each do |text|
      expect(text).not_to include("expected-secret", "actual-secret", "CANARY_M2_ASSERTION_")
    end
    expect(output.string.bytesize).to be <= 600
    expect(native.first.bytesize).to be <= ReportportalCucumber::Service::EvidencePresenter::DETAILS_LIMIT
    expect(rp_entries.first.first.bytesize).to be <= ReportportalCucumber::Service::EvidencePresenter::DETAILS_LIMIT
    expect(native.join).to include("credential check", "FAIL")
    expect(rp_entries.join).to include("credential check", "FAIL")
  ensure
    AppLog.clear!
  end

  it "does not mutate caller-owned values or make a failed diagnostic an assertion exception" do
    expected = { password: "keep-secret" }.freeze
    actual = { value: [1, 2].freeze }.freeze
    world = double("Cucumber world", log: nil)
    AppLog.bind(world, output: StringIO.new, color: false)

    expect do
      AppLog.assertion(name: "diagnostic", expected: expected, actual: actual,
                       passed: false, report: false)
    end.not_to raise_error
    expect(expected[:password]).to eq("keep-secret")
    expect(actual[:value]).to eq([1, 2])
  ensure
    AppLog.clear!
  end
end
