# frozen_string_literal: true

require "spec_helper"
require "json"
require "stringio"
require "uri"
require "reportportal_cucumber/automation/app_log"
require "reportportal_cucumber/automation/evidence_redactor"
require "reportportal_cucumber/automation/http_exchange"

RSpec.describe Automation::EvidenceRedactor, "bounded percent-decoding depth" do
  let(:policy) { described_class.new }
  let(:secret) { "SYNTHETIC_DEPTH_SENTINEL" }

  def encoded(value, depth)
    depth.times { value = URI.encode_www_form_component(value) }
    value
  end

  def decoded(value)
    6.times { value = URI::DEFAULT_PARSER.unescape(value) }
    value
  end

  def recorded_logs
    messages = []
    world = double("reporting world", log: nil, rp_log: nil, rp_active?: true)
    allow(world).to receive(:log) { |message| messages << message }
    allow(world).to receive(:rp_log) { |message| messages << message }
    terminal = StringIO.new
    logger = Automation::CucumberLogger.new(world: world, output: terminal, color: false)
    AppLog.with_logger(logger) { yield }
    [terminal.string, *messages]
  end

  def automatic_outputs(url)
    exchange = Automation::HttpExchange.new(method: "GET", url: url, response: { status: 200 })
    presenter = ReportportalCucumber::Service::EvidencePresenter
    outputs = [policy.redact_url(url), policy.redact_text(url), JSON.generate(policy.redact("url" => url)),
               exchange.summary, exchange.native_markdown, presenter.sanitize_diagnostic(url)]
    %w[plain rich].each do |mode|
      outputs << exchange.to_markdown(presentation: mode)
      outputs.concat(presenter.failure(action: "request", error: RuntimeError.new("request failed"),
                                       url: url, details: { "url" => url }, presentation: mode).values)
      outputs.concat(presenter.assertion(name: url, expected: "safe", actual: url,
                                         passed: false, presentation: mode).values)
    end
    outputs.concat(recorded_logs { AppLog.http(method: "GET", url: url, response: { status: 200 }) })
  end

  max_passes = described_class.const_get(:MAX_PERCENT_DECODE_PASSES)
  { max_minus_one: max_passes - 1, max: max_passes, max_plus_one: max_passes + 1, five: 5 }.each do |label, depth|
    %i[path query query_value fragment malformed].each do |location|
      it "withholds credentials at #{label} (#{depth}) layers in #{location} across automatic evidence routes" do
        part = encoded(JSON.generate(password: secret), depth)
        url = case location
              when :path then "https://example.test/#{part}"
              when :query then "https://example.test/?#{part}"
              when :query_value then "https://example.test/?payload=#{part}"
              when :fragment then "https://example.test/##{part}"
              when :malformed then "https://example.test/bad path##{part}"
              end.freeze

        automatic_outputs(url).each do |output|
          expect(decoded(output)).not_to include(secret)
          expect(output).to include("omitted") if depth > max_passes
        end
        expect(policy.redact_url(url)).to eq(described_class::OMITTED) if depth > max_passes
      end
    end

    { safe_json: JSON.generate(page: 2), safe_route: "users/{id}" }.each do |name, value|
      it "preserves inspectable #{name} but withholds over-depth input at #{label} (#{depth}) layers" do
        url = "https://example.test/#{encoded(value, depth)}".freeze

        if depth <= max_passes
          expect(policy.redact_url(url)).to eq(url)
          expect(policy.redact_text(url)).to eq(url)
          expect(Automation::HttpExchange.new(method: "GET", url: url).summary).to include(url)
        else
          expect(policy.redact_url(url)).to eq(described_class::OMITTED)
          automatic_outputs(url).each { |output| expect(output).to include("omitted") }
        end
      end
    end

    it "accepts complete masks within budget and withholds them over budget at #{label} (#{depth}) layers" do
      url = "https://example.test/#{encoded(JSON.generate(password: described_class::MASK), depth)}"
      output = policy.redact_url(url)

      if depth <= max_passes
        expect(output).not_to eq(described_class::OMITTED)
        expect(policy.redact_url(output)).to eq(output)
      else
        expect(output).to eq(described_class::OMITTED)
      end
    end

    it "leaves raw AppLog messages unchanged at #{label} (#{depth}) layers" do
      url = "https://example.test/#{encoded(JSON.generate(password: secret), depth)}".freeze
      expect(described_class).not_to receive(:new)
      outputs = recorded_logs { AppLog.info(url, report: true) }

      expect(outputs.length).to eq(3)
      expect(outputs.drop(1)).to eq([url, url])
      expect(outputs.first).to include(url)
    end

    %w[plain rich].each do |mode|
      it "keeps Decision19 raw failure content in #{mode} mode at #{label} (#{depth}) layers" do
        url = "https://example.test/#{encoded(JSON.generate(password: secret), depth)}".freeze
        error = RuntimeError.new(url).tap { |failure| failure.set_backtrace([url, "safe.rb:1"]) }
        formatter = ReportportalCucumber::Cucumber::Formatter.allocate
        buffer = double("log buffer", emit_log: nil)
        formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new("rp.presentation" => mode))
        formatter.instance_variable_set(:@launch_uuid, "launch-depth")
        formatter.instance_variable_set(:@log_buffer, buffer)
        timestamp = Time.utc(2026, 11, 3)
        allow(formatter).to receive(:monotonic_timestamp).with(timestamp).and_return(timestamp)
        expect(described_class).not_to receive(:new)
        expect_any_instance_of(described_class).not_to receive(:redact_text)

        formatter.send(:emit_error_log, item_uuid: "step-depth", error: error, timestamp: timestamp)

        expect(buffer).to have_received(:emit_log).with(hash_including(
          message: include(url, "```text\n#{error.backtrace.join("\n")}\n```"), level: :error
        ))
        expect(error.message).to eq(url)
        expect(error.backtrace).to eq([url, "safe.rb:1"])
      end
    end
  end

  it "preserves form-encoded spaces when the fixed percent-decoding budget fully resolves them" do
    url = "https://example.test/#{encoded('my report.pdf', max_passes + 1)}".freeze

    expect(policy.redact_url(url)).to eq(url)
    expect(policy.redact_text(url)).to eq(url)
    expect(Automation::HttpExchange.new(method: "GET", url: url).summary).to include(url)
  end

  it "stops the output check after exactly the configured number of percent-decoding passes" do
    value = encoded(JSON.generate(password: secret), max_passes + 2)
    parser = URI::DEFAULT_PARSER.dup
    stub_const("URI::DEFAULT_PARSER", parser)
    expect(parser).to receive(:unescape).exactly(max_passes).times.and_call_original

    expect(policy.send(:encoded_credential_exposed?, value)).to be(true)
  end
end
