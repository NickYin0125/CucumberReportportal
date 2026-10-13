# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "securerandom"
require "time"
require "uri"
require_relative "../../examples/day2_endurance/support"

module DurationWorkflow
  DEFAULT_BASE_URL = "http://127.0.0.1:4567"
  COMPLETED = "COMPLETED"
  TRANSIENT_HTTP_CODES = %w[503 504].freeze

  class HttpError < StandardError
    attr_reader :response

    def initialize(response)
      @response = response
      super("HTTP #{response.code}: #{response.body}")
    end
  end

  class Client
    def initialize(base_url:, smoke:)
      @base_url = base_url.sub(%r{/\z}, "")
      @smoke = smoke
    end

    def post_json(path, payload)
      request_json(Net::HTTP::Post, path, payload)
    end

    def get_json(path)
      request_json(Net::HTTP::Get, path, nil)
    end

    private

    def request_json(request_class, path, payload)
      uri = URI("#{@base_url}#{path}")
      attempt = 0
      delay_seconds = retry_base_delay

      loop do
        attempt += 1
        request = build_request(request_class, uri, payload)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: read_timeout) do |http|
          http.request(request)
        end

        if TRANSIENT_HTTP_CODES.include?(response.code) && attempt < max_retry_attempts
          AppLog.warn(
            "Transient clearing API response; retrying with exponential backoff",
            attach: true,
            json: {
              method: request.method,
              uri: uri.to_s,
              status: response.code.to_i,
              attempt: attempt,
              next_delay_seconds: delay_seconds
            }
          )
          sleep(delay_seconds)
          delay_seconds *= 2
          next
        end

        raise HttpError, response unless response.is_a?(Net::HTTPSuccess)

        return parse_json(response.body)
      end
    end

    def build_request(request_class, uri, payload)
      request = request_class.new(uri)
      request["Accept"] = "application/json"
      return request unless payload

      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      request
    end

    def parse_json(body)
      stripped = body.to_s.strip
      return {} if stripped.empty?

      JSON.parse(stripped, symbolize_names: true)
    end

    def max_retry_attempts
      4
    end

    def retry_base_delay
      @smoke ? 0.05 : 1.0
    end

    def read_timeout
      @smoke ? 5 : 30
    end
  end

  class SettlementPoller
    TERMINAL_FAILURE_STATUSES = %w[FAILED REJECTED CANCELLED].freeze

    def initialize(client:, smoke:)
      @client = client
      @interval_seconds = smoke ? 0.1 : 5.0
      @timeout_seconds = smoke ? 10.0 : 180.0
    end

    def wait_until_completed(batch_id)
      started_at = Day2Endurance.monotonic
      last_status = nil
      poll_count = 0

      loop do
        poll_count += 1
        payload = @client.get_json("/api/v1/settlement/batch/#{URI.encode_www_form_component(batch_id)}")
        status = payload.fetch(:status)
        Day2Endurance.check("settlement batch identity", payload.fetch(:batch_id) == batch_id)
        Day2Endurance.check("settlement status enum", (ClearingMockServer::SETTLEMENT_STATUSES + TERMINAL_FAILURE_STATUSES).include?(status))
        if last_status && !TERMINAL_FAILURE_STATUSES.include?(status)
          Day2Endurance.check("settlement never regresses", ClearingMockServer::SETTLEMENT_STATUSES.index(status) >= ClearingMockServer::SETTLEMENT_STATUSES.index(last_status))
        end

        log_settlement_state(last_status, status, batch_id, poll_count, payload)
        if status == COMPLETED
          Day2Endurance.check("completed ledger reference", !payload[:ledger_reference].to_s.empty?)
          return payload.merge(poll_count: poll_count)
        end

        raise "Settlement #{batch_id} ended in #{status}" if TERMINAL_FAILURE_STATUSES.include?(status)
        raise "Settlement #{batch_id} did not complete within #{@timeout_seconds}s" if Day2Endurance.monotonic - started_at >= @timeout_seconds

        last_status = status
        sleep(@interval_seconds)
      end
    end

    private

    def log_settlement_state(from_status, to_status, batch_id, poll_count, payload)
      AppLog.info(
        "Settlement state transition #{from_status || 'START'} -> #{to_status}",
        attach: true,
        json: {
          batch_id: batch_id,
          from: from_status || "START",
          to: to_status,
          poll_count: poll_count,
          payload: payload
        }
      )
    end
  end

  module Helpers
    def duration_smoke?
      %w[1 true yes on].include?(ENV["DURATION_REGRESSION_SMOKE"].to_s.strip.downcase)
    end

    def duration_base_url
      configured = ENV["CLEARING_MOCK_URL"].to_s.strip
      configured.empty? ? DEFAULT_BASE_URL : configured
    end

    def duration_client
      @duration_client ||= Client.new(base_url: duration_base_url, smoke: duration_smoke?)
    end

    def duration_context
      @duration_context ||= {
        trade_id: "TRD-#{SecureRandom.hex(4).upcase}",
        batch_id: "BATCH-#{SecureRandom.hex(4).upcase}",
        correlation_id: SecureRandom.uuid,
        submitted_at: Time.now.utc.iso8601
      }
    end

    def trade_payload
      {
        tradeId: duration_context.fetch(:trade_id),
        batch_id: duration_context.fetch(:batch_id),
        correlationId: duration_context.fetch(:correlation_id),
        product: "USD-CNY IRS",
        account: "ACC-DURATION-001",
        desk: "APAC-rates",
        counterparty: "BANK-ALPHA",
        productType: "INTEREST_RATE_SWAP",
        notional: 1_250_000,
        currency: "USD",
        tradeDate: Time.now.utc.strftime("%Y-%m-%d"),
        submittedAt: duration_context.fetch(:submitted_at)
      }
    end

    def validation_payload
      {
        requestId: "VAL-#{SecureRandom.uuid}",
        validationMode: "strict",
        trade: trade_payload
      }
    end

    def netting_payload
      {
        requestId: "NET-#{SecureRandom.uuid}",
        batch_id: duration_context.fetch(:batch_id),
        account: "ACC-DURATION-001",
        currency: "USD",
        trades: [
          { tradeId: "#{duration_context.fetch(:trade_id)}-PAY", direction: "PAY", notional: 1_250_000, currency: "USD" },
          { tradeId: "#{duration_context.fetch(:trade_id)}-REC", direction: "RECEIVE", notional: 625_000, currency: "USD" }
        ]
      }
    end

    def margin_payload
      {
        requestId: "MRG-#{SecureRandom.uuid}",
        batch_id: duration_context.fetch(:batch_id),
        account: "ACC-DURATION-001",
        currency: "USD",
        positions: [
          { productType: "INTEREST_RATE_SWAP", netNotional: 625_000, tenor: "5Y", riskWeight: 0.035 },
          { productType: "FX_SWAP", netNotional: 840_000, tenor: "3M", riskWeight: 0.018 }
        ]
      }
    end

    def log_transition(stage, from_state, to_state, payload)
      AppLog.info(
        "Clearing workflow #{stage}: #{from_state} -> #{to_state}",
        attach: true,
        json: {
          trade_id: duration_context.fetch(:trade_id),
          batch_id: duration_context.fetch(:batch_id),
          stage: stage,
          from: from_state,
          to: to_state,
          payload: payload
        }
      )
      Day2Endurance.session&.sample("workflow-#{stage}")
    end

    def build_settlement_report
      report_dir = Day2Endurance.session&.directory || ENV.fetch("DURATION_REPORT_DIR", File.expand_path("../../tmp/duration/run-#{Process.pid}", __dir__))
      FileUtils.mkdir_p(report_dir)

      path = File.join(report_dir, "settlement-#{duration_context.fetch(:batch_id)}.csv")
      rows = [
        %w[trade_id batch_id netting_id margin_call_id final_status total_margin ledger_reference poll_count completed_at],
        [
          duration_context.fetch(:trade_id),
          duration_context.fetch(:batch_id),
          @duration_netting.fetch(:netting_id),
          @duration_margin.fetch(:margin_call_id),
          @duration_settlement_final.fetch(:status),
          @duration_margin.fetch(:total_margin),
          @duration_settlement_final.fetch(:ledger_reference),
          @duration_settlement_final.fetch(:poll_count),
          @duration_settlement_final.fetch(:updated_at)
        ]
      ]
      File.write(path, rows.map { |row| row.map { |value| csv_escape(value) }.join(",") }.join("\n") + "\n")

      path
    end

    def csv_escape(value)
      text = value.to_s
      return text unless text.match?(/[",\r\n]/)

      %("#{text.gsub('"', '""')}")
    end

    def attach_settlement_report(path)
      runtime = ReportportalCucumber.current_runtime
      return false unless runtime&.config&.enabled?
      unless respond_to?(:rp_attach)
        raise "rp_attach unavailable with reporting enabled"
      end

      rp_attach(path, name: File.basename(path), mime: "text/csv", message: "Dynamic settlement CSV report", level: :info)
      Day2Endurance.session&.artifact(path, owner_uuid: runtime.runtime_context.active_parent_uuid)
      true
    end
  end
end

World(DurationWorkflow::Helpers)

Given("the duration clearing API is available") do
  AppLog.info(
    "Duration clearing API ready",
    attach: true,
    json: {
      base_url: duration_base_url,
      smoke: duration_smoke?,
      trade_id: duration_context.fetch(:trade_id),
      batch_id: duration_context.fetch(:batch_id)
    }
  )
end

When("I submit a duration trade into clearing") do
  @duration_trade = duration_client.post_json("/api/v1/trades/ingest", trade_payload)
  expect(@duration_trade.fetch(:status)).to eq("ACCEPTED")
  expect(@duration_trade.fetch(:batch_id)).to eq(duration_context.fetch(:batch_id))
  log_transition("Trade", "NEW", @duration_trade.fetch(:status), @duration_trade)
end

When("the trade passes clearing validation") do
  @duration_validation = duration_client.post_json("/api/v1/clearing/validate", validation_payload)
  expect(@duration_validation.fetch(:status)).to eq("VALIDATED")
  expect(@duration_validation.fetch(:valid)).to be(true)
  expect(@duration_validation.fetch(:violations)).to eq([])
  log_transition("Validate", @duration_trade.fetch(:status), @duration_validation.fetch(:status), @duration_validation)
end

When("the trade is included in netting") do
  @duration_netting = duration_client.post_json("/api/v1/clearing/netting", netting_payload)
  expect(@duration_netting.fetch(:status)).to eq("NETTED")
  expect(@duration_netting.fetch(:net_notional)).to eq(-625_000)
  expect(@duration_netting.fetch(:batch_id)).to eq(duration_context.fetch(:batch_id))
  log_transition("Netting", @duration_validation.fetch(:status), @duration_netting.fetch(:status), @duration_netting)
end

When("margin is calculated for the netted batch") do
  @duration_margin = duration_client.post_json("/api/v1/margin/calculate", margin_payload)
  expect(@duration_margin.fetch(:status)).to eq("CALCULATED")
  Day2Endurance.check_margin(margin_payload, @duration_margin.transform_keys(&:to_s))
  log_transition("Margin", @duration_netting.fetch(:status), @duration_margin.fetch(:status), @duration_margin)
end

Then("settlement polling reaches COMPLETED") do
  @duration_settlement_final = DurationWorkflow::SettlementPoller
    .new(client: duration_client, smoke: duration_smoke?)
    .wait_until_completed(duration_context.fetch(:batch_id))

  expect(@duration_settlement_final.fetch(:status)).to eq(DurationWorkflow::COMPLETED)
  log_transition("Settlement Polling", "NETTED", @duration_settlement_final.fetch(:status), @duration_settlement_final)
end

Then("a CSV settlement report is attached") do
  @duration_settlement_report = build_settlement_report
  attached = attach_settlement_report(@duration_settlement_report)

  AppLog.info(
    "Settlement CSV report generated",
    attach: true,
    json: {
      path: @duration_settlement_report,
      attached_to_reportportal: attached,
      size_bytes: File.size(@duration_settlement_report)
    }
  )

  expect(File).to exist(@duration_settlement_report)
  headers, values = Day2Endurance.csv_rows(File.read(@duration_settlement_report))
  row = headers.zip(values).to_h
  expect(row["batch_id"]).to eq(duration_context.fetch(:batch_id))
  expect(row["netting_id"]).to eq(@duration_netting.fetch(:netting_id))
  expect(row["margin_call_id"]).to eq(@duration_margin.fetch(:margin_call_id))
  expect(row["ledger_reference"]).to eq(@duration_settlement_final.fetch(:ledger_reference))
  expect(row["final_status"]).to eq("COMPLETED")
  expect(BigDecimal(row["total_margin"])).to eq(Day2Endurance.margin_oracle(margin_payload))
  expect(attached).to be(true) if ReportportalCucumber.current_runtime&.config&.enabled?
end
