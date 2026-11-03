# frozen_string_literal: true

require "spec_helper"
require "json"
require "stringio"
require "uri"
require "reportportal_cucumber/automation/app_log"
require "reportportal_cucumber/automation/evidence_redactor"
require "reportportal_cucumber/automation/http_exchange"

RSpec.describe Automation::EvidenceRedactor, "repeated Bearer prefixes" do
  let(:policy) { described_class.new }
  let(:secret) { "SYNTHETIC_BEARER_SENTINEL" }

  def encoded(value, layers)
    value = value.bytes.map { |byte| format("%%%02X", byte) }.join
    (layers - 1).times { value = URI.encode_www_form_component(value) }
    value
  end

  def decoded(value)
    3.times { value = URI::DEFAULT_PARSER.unescape(value) }
    value
  end

  def automatic_outputs(source)
    url = source.start_with?("https://") ? source : "https://example.test/orders?page=2"
    http = Automation::HttpExchange.new(method: "GET", url: url, error: source,
                                        request: { body: source }, response: { status: 503 })
    presenter = ReportportalCucumber::Service::EvidencePresenter
    outputs = [policy.redact_text(source), JSON.generate(policy.redact("message" => source)),
               http.summary, http.native_markdown, presenter.sanitize_diagnostic(source)]
    %w[plain rich].each do |mode|
      outputs << http.to_markdown(presentation: mode)
      outputs.concat(presenter.failure(action: "request", error: RuntimeError.new(source),
                                       url: url, details: source, presentation: mode).values)
      outputs.concat(presenter.assertion(name: "request", expected: "safe", actual: source,
                                         passed: false, presentation: mode).values)
    end
    outputs
  end

  it "removes the original QA probe credential from every automatic channel" do
    source = "Authorization: Bearer Bearer #{secret}".freeze

    expect(policy.redact_text(source)).to eq("Authorization: #{described_class::MASK}")
    automatic_outputs(source).each { |output| expect(output).not_to include(secret) }
    expect(source).to eq("Authorization: Bearer Bearer #{secret}")
  end

  {
    standalone: "Bearer Bearer SECRET",
    triple: "Authorization: Bearer Bearer Bearer SECRET",
    mixed_case: "Authorization: bEaReR BEARER SECRET",
    tabs: "Authorization:\tBearer\tBearer\tSECRET",
    mixed_case_tabs: "diagnostic bEaReR\tBEARER \tbearer\tSECRET\nsafe detail",
    mask_prefix: "Authorization=Bearer Bearer [REDACTED]SECRET"
  }.each do |name, template|
    it "consumes the final token for #{name} without omitting ordinary diagnostics" do
      source = template.sub("SECRET", secret).freeze
      once = policy.redact_text(source)

      expect(once).not_to include(secret)
      expect(once).not_to eq(described_class::OMITTED)
      expect(once).to include(described_class::MASK)
      expect(policy.redact_text(once)).to eq(once)
      expect(once).to include("diagnostic", "safe detail") if name == :mixed_case_tabs
      automatic_outputs(source).each { |output| expect(output).not_to include(secret) }
    end
  end

  { header: "Authorization:\tbEaReR\tBEARER\tSECRET", standalone: "bEaReR\tBEARER\tSECRET" }.each do |name, template|
    [1, 2, 3].each do |layers|
      %i[path query fragment malformed].each do |location|
        it "protects #{name} with #{layers} percent-encoding layers in #{location}" do
          part = encoded(template.sub("SECRET", secret), layers)
          url = case location
                when :path then "https://example.test/#{part}"
                when :query then "https://example.test/?payload=#{part}"
                when :fragment then "https://example.test/##{part}"
                when :malformed then "https://example.test/bad path##{part}"
                end.freeze

          expect(decoded(policy.redact_url(url))).not_to include(secret)
          automatic_outputs(url).each { |output| expect(decoded(output)).not_to include(secret) }
        end
      end
    end
  end

  ["Bearer Bearer [REDACTED]", "bEaReR\tBEARER\t[REDACTED]", "Bearer Bearer Bearer [REDACTED]"].each do |value|
    [1, 2, 3].each do |layers|
      it "accepts complete masks after all prefixes in #{value.inspect} at #{layers} layers" do
        url = "https://example.test/#{encoded(value, layers)}"
        once = policy.redact_url(url)

        expect(once).not_to eq(described_class::OMITTED)
        expect(policy.redact_url(once)).to eq(once)
        expect(policy.redact_text(once)).to eq(once)
      end
    end
  end

  ["scheme=Bearer", "bearer_count=2", "A harmless Bearer."].each do |text|
    it "preserves the benign Bearer word control #{text}" do
      expect(policy.redact_text(text.freeze)).to eq(text)
    end
  end

  ["https://example.test/auth/Bearer?page=2", "https://example.test/files/my%20report.pdf?token_count=12"].each do |url|
    it "preserves the normal URL #{url}" do
      expect(policy.redact_url(url.freeze)).to eq(url)
      expect(policy.redact_text(url)).to eq(url)
    end
  end

  it "handles a long prefix chain within the existing input bound without repeated redaction passes" do
    source = ("Bearer\t" * 4_096) + secret
    expect(source.bytesize).to be < described_class::MAX_INPUT_BYTES

    expect(policy.redact_text(source)).to eq("Bearer #{described_class::MASK}")
  end

  it "leaves repeated Bearer credentials raw on ordinary AppLog routes" do
    source = "Authorization: Bearer Bearer #{secret}".freeze
    world = double("reporting world", log: nil, rp_log: nil, rp_active?: true)
    terminal = StringIO.new
    logger = Automation::CucumberLogger.new(world: world, output: terminal, color: false)
    expect(described_class).not_to receive(:new)

    AppLog.with_logger(logger) { AppLog.info(source, report: true) }

    expect(world).to have_received(:log).with(source)
    expect(world).to have_received(:rp_log).with(source, any_args)
    expect(terminal.string).to include(source)
  end

  %w[plain rich].each do |mode|
    it "preserves Decision19 raw message and frames with repeated Bearer in #{mode}" do
      source = "Authorization: Bearer Bearer #{secret}".freeze
      error = RuntimeError.new(source).tap { |failure| failure.set_backtrace([source, "safe.rb:1"]) }
      formatter = ReportportalCucumber::Cucumber::Formatter.allocate
      buffer = double("log buffer", emit_log: nil)
      formatter.instance_variable_set(:@config, ReportportalCucumber::Config.new("rp.presentation" => mode))
      formatter.instance_variable_set(:@launch_uuid, "launch-bearer")
      formatter.instance_variable_set(:@log_buffer, buffer)
      timestamp = Time.utc(2026, 11, 3)
      allow(formatter).to receive(:monotonic_timestamp).with(timestamp).and_return(timestamp)
      expect(described_class).not_to receive(:new)
      expect_any_instance_of(described_class).not_to receive(:redact_text)

      formatter.send(:emit_error_log, item_uuid: "step-bearer", error: error, timestamp: timestamp)

      expect(buffer).to have_received(:emit_log).with(hash_including(
        message: include(source, "```text\n#{error.backtrace.join("\n")}\n```"), level: :error
      ))
      expect(error.message).to eq(source)
      expect(error.backtrace).to eq([source, "safe.rb:1"])
    end
  end
end
