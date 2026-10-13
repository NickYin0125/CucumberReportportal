# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "time"
require "uri"
require_relative "../../examples/day2_endurance/support"

module ClearingEndpointContract
  ENDPOINTS = {
    ingest: { method: :post, path: "/api/v1/trades/ingest" },
    validate: { method: :post, path: "/api/v1/clearing/validate" },
    netting: { method: :post, path: "/api/v1/clearing/netting" },
    margin: { method: :post, path: "/api/v1/margin/calculate" },
    settlement_poll: { method: :get, path: "/api/v1/settlement/batch/%<batch_id>s" }
  }.freeze

  DEFAULT_BASE_URL = "http://127.0.0.1:4567"
  HTTP_OPEN_TIMEOUT = 5
  HTTP_READ_TIMEOUT = 15
  RETRYABLE_STATUSES = [503, 504].freeze

  def clearing_base_url
    configured = ENV.fetch("CLEARING_MOCK_URL", "").strip
    configured.empty? ? DEFAULT_BASE_URL : configured
  end

  def configure_clearing_mock_server
    @clearing_base_uri = URI(clearing_base_url)
    raise "CLEARING_MOCK_URL must be an absolute http(s) URL" unless @clearing_base_uri.is_a?(URI::HTTP)

    AppLog.debug(
      "Clearing Mock Endpoint Contract",
      attach: true,
      json: {
        baseUrl: @clearing_base_uri.to_s,
        endpoints: ENDPOINTS.transform_values { |config| config.slice(:method, :path) }
      }
    )
  end

  def clearing_uri(path, path_params: {})
    base = @clearing_base_uri || URI(clearing_base_url)
    uri = base.dup
    base_path = base.path.to_s.sub(%r{/+\z}, "")
    endpoint_path = expand_endpoint_path(path, path_params).sub(%r{\A/+}, "")
    full_path = [base_path, endpoint_path].reject(&:empty?).join("/")
    full_path = "/#{full_path}" unless full_path.start_with?("/")
    uri.path = full_path
    uri
  end

  def expand_endpoint_path(path, path_params)
    return path.to_s if path_params.empty?

    encoded_params = path_params.transform_values { |value| URI.encode_www_form_component(value.to_s) }
    format(path, encoded_params)
  end

  def execute_clearing_endpoint(endpoint_name, payload: nil, query: nil, path_params: {})
    endpoint = ENDPOINTS.fetch(endpoint_name)
    uri = clearing_uri(endpoint.fetch(:path), path_params: path_params)
    uri.query = URI.encode_www_form(query) if query && !query.empty?

    request = build_clearing_request(endpoint.fetch(:method), uri, payload)
    @last_clearing_payload = payload
    @last_clearing_query = query
    @last_clearing_request = {
      endpoint: endpoint_name,
      method: endpoint.fetch(:method).to_s.upcase,
      url: uri.to_s,
      payload: loggable_payload(payload),
      query: query,
      pathParams: path_params
    }.compact

    AppLog.debug("Clearing Mock Request", attach: true, json: @last_clearing_request)

    @last_clearing_response = execute_with_transient_retry(uri, request)

    @last_clearing_response_json = parse_clearing_json(@last_clearing_response.body)
    AppLog.debug("Clearing Mock Response", attach: true, json: clearing_response_log)
  rescue StandardError => e
    AppLog.error(
      "Clearing Mock Request Failed",
      attach: true,
      json: {
        errorClass: e.class.name,
        errorMessage: e.message,
        request: @last_clearing_request
      }
    )
    raise
  end

  def execute_with_transient_retry(uri, request)
    attempts = duration_contract_smoke? ? 2 : 4
    delay = duration_contract_smoke? ? 0.05 : 0.5

    attempts.times do |index|
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: HTTP_OPEN_TIMEOUT,
        read_timeout: HTTP_READ_TIMEOUT
      ) { |http| http.request(request) }

      return response unless RETRYABLE_STATUSES.include?(response.code.to_i) && index < attempts - 1

      AppLog.warn(
        "Clearing Mock transient response; retrying endpoint contract request",
        attach: true,
        json: {
          status: response.code.to_i,
          attempt: index + 1,
          attempts: attempts,
          next_delay_seconds: delay,
          request: @last_clearing_request
        }
      )
      sleep(delay)
      delay *= 2
    end
  end

  def build_clearing_request(method, uri, payload)
    request_class = case method
                    when :get
                      Net::HTTP::Get
                    when :post
                      Net::HTTP::Post
                    else
                      raise "Unsupported clearing endpoint method: #{method}"
                    end

    request_class.new(uri).tap do |request|
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json" if payload
      request.body = JSON.generate(payload) if payload
    end
  end

  def parse_clearing_json(body)
    return nil if body.to_s.strip.empty?

    JSON.parse(body)
  rescue JSON::ParserError
    nil
  end

  def clearing_response_log
    {
      status: @last_clearing_response.code.to_i,
      message: @last_clearing_response.message,
      headers: clearing_response_headers,
      body: @last_clearing_response_json || @last_clearing_response.body.to_s
    }
  end

  def clearing_response_headers
    headers = {}
    @last_clearing_response.each_header { |name, value| headers[name] = value }
    headers
  end

  def loggable_payload(payload)
    return nil unless payload
    return payload unless payload.dig(:metadata, :fixtureSize) == "large_invalid_trade_payload"

    {
      requestId: payload.fetch(:requestId),
      fixtureSize: payload.dig(:metadata, :fixtureSize),
      invalidTradeCount: payload.fetch(:trades).size,
      reason: "Full invalid payload is attached when the expected HTTP 400 is observed."
    }
  end

  def valid_trade_batch_payload
    {
      requestId: request_id("INGEST"),
      sourceSystem: "cucumber-duration-agent-b",
      clearingHouse: "MOCK-CLEAR",
      receivedAt: Time.now.utc.iso8601,
      trades: [
        valid_trade_payload.fetch(:trade).merge(tradeId: trade_id("IRS-001"), notional: 1_250_000),
        valid_trade_payload.fetch(:trade).merge(tradeId: trade_id("FX-002"), productType: "FX_SWAP", notional: 840_000)
      ]
    }
  end

  def valid_trade_payload
    {
      requestId: request_id("VALIDATE"),
      validationMode: "strict",
      trade: {
        tradeId: trade_id("IRS-VALID"),
        account: "ACC-DURATION-001",
        counterparty: "CP-MOCK-01",
        productType: "INTEREST_RATE_SWAP",
        currency: "USD",
        notional: 1_250_000,
        tradeDate: "2026-05-29",
        settlementDate: "2026-06-03",
        legs: [
          { legId: "FIXED", direction: "PAY", rate: 0.0425, dayCount: "30/360" },
          { legId: "FLOAT", direction: "RECEIVE", index: "SOFR", spread: 0.0015 }
        ]
      }
    }
  end

  def invalid_trade_payload
    {
      requestId: request_id("INVALID"),
      validationMode: "strict",
      metadata: {
        fixtureSize: "large_invalid_trade_payload",
        generatedBy: "sub-agent-b",
        expectedHttpStatus: 400,
        reason: "negative notionals, invalid currencies, missing counterparties and malformed dates"
      },
      trade: {
        tradeId: "",
        account: "ACC-DURATION-INVALID",
        counterparty: nil,
        productType: "UNKNOWN_DERIVATIVE",
        currency: "???",
        notional: -1,
        tradeDate: "not-a-date",
        settlementDate: "2026-01-01",
        legs: []
      },
      trades: Array.new(120) do |index|
        {
          tradeId: "BAD-#{index.to_s.rjust(3, '0')}",
          account: index.even? ? "" : "ACC-DURATION-INVALID",
          counterparty: nil,
          productType: "BROKEN_SWAP",
          currency: index.even? ? "???" : "",
          notional: -(index + 1) * 10_000,
          tradeDate: "2026-99-99",
          settlementDate: "2025-01-01",
          validationErrors: [
            "counterparty is required",
            "currency must be ISO-4217",
            "notional must be positive",
            "settlementDate must be on or after tradeDate"
          ]
        }
      end
    }
  end

  def contract_netting_payload
    {
      requestId: request_id("NETTING"),
      batch_id: settlement_batch_id,
      account: "ACC-DURATION-001",
      nettingSetId: "NET-USD-RATES",
      currency: "USD",
      asOf: "2026-06-01T00:00:00Z",
      trades: [
        { tradeId: trade_id("NET-PAY"), direction: "PAY", notional: 1_250_000, currency: "USD" },
        { tradeId: trade_id("NET-REC"), direction: "RECEIVE", notional: 625_000, currency: "USD" }
      ]
    }
  end

  def contract_margin_payload
    {
      requestId: request_id("MARGIN"),
      account: "ACC-DURATION-001",
      portfolioId: "PF-DURATION-RATES",
      currency: "USD",
      valuationDate: "2026-06-01",
      positions: [
        { productType: "INTEREST_RATE_SWAP", netNotional: 625_000, tenor: "5Y", riskWeight: 0.035 },
        { productType: "FX_SWAP", netNotional: 840_000, tenor: "3M", riskWeight: 0.018 }
      ]
    }
  end

  def settlement_poll_query
    {
      account: "ACC-DURATION-001",
      asOf: Time.now.utc.iso8601
    }
  end

  def settlement_batch_id
    "batch-duration-contract-001"
  end

  def request_id(prefix)
    "#{prefix}-#{SecureRandom.uuid}"
  end

  def trade_id(prefix)
    "#{prefix}-#{SecureRandom.hex(4).upcase}"
  end

  def duration_contract_smoke?
    %w[1 true yes on].include?(ENV["DURATION_REGRESSION_SMOKE"].to_s.strip.downcase)
  end
end

World(ClearingEndpointContract)

Given("the clearing mock server base URL is configured") do
  configure_clearing_mock_server
end

When("I submit a valid trade batch to the clearing ingest endpoint") do
  execute_clearing_endpoint(:ingest, payload: valid_trade_batch_payload)
end

When("I submit a valid trade to the clearing validate endpoint") do
  execute_clearing_endpoint(:validate, payload: valid_trade_payload)
end

When("I submit an invalid trade payload to the clearing validate endpoint") do
  execute_clearing_endpoint(:validate, payload: invalid_trade_payload)
end

When("I submit a netting request to the clearing netting endpoint") do
  execute_clearing_endpoint(:netting, payload: contract_netting_payload)
end

When("I submit a margin request to the clearing margin endpoint") do
  execute_clearing_endpoint(:margin, payload: contract_margin_payload)
end

When("I poll the clearing settlement endpoint") do
  execute_clearing_endpoint(
    :settlement_poll,
    query: settlement_poll_query,
    path_params: { batch_id: settlement_batch_id }
  )
end

Then("the clearing mock response should be successful") do
  status = @last_clearing_response.code.to_i
  unless status.between?(200, 299)
    AppLog.error(
      "Clearing Mock Unexpected HTTP Status",
      attach: true,
      json: {
        expected: "2xx",
        actual: status,
        request: @last_clearing_request,
        response: clearing_response_log
      }
    )
  end

  expect(status).to be_between(200, 299).inclusive
end

Then("the clearing mock response should be HTTP {int}") do |expected_status|
  actual_status = @last_clearing_response.code.to_i

  if expected_status == 400 && actual_status == 400
    payload = @last_clearing_payload || @last_clearing_query || {}
    AppLog.error("Invalid Trade Payload", attach: true, json: payload)
  elsif actual_status != expected_status
    AppLog.error(
      "Clearing Mock Unexpected HTTP Status",
      attach: true,
      json: {
        expected: expected_status,
        actual: actual_status,
        request: @last_clearing_request,
        response: clearing_response_log
      }
    )
  end

  expect(actual_status).to eq(expected_status)
end

Then("the clearing mock response body should be JSON") do
  if @last_clearing_response_json.nil?
    AppLog.error(
      "Clearing Mock Non-JSON Response",
      attach: true,
      json: {
        status: @last_clearing_response.code.to_i,
        body: @last_clearing_response.body.to_s,
        request: @last_clearing_request
      }
    )
  end

  expect(@last_clearing_response_json).not_to be_nil
  body = @last_clearing_response_json
  expect(body).to be_a(Hash)
  case @last_clearing_request.fetch(:endpoint)
  when :ingest
    expect(@last_clearing_response.code.to_i).to eq(202)
    expect(body.fetch("status")).to eq("ACCEPTED")
    expect(body.fetch("trade_ingest_id")).not_to be_empty
  when :validate
    rejected = @last_clearing_response.code.to_i == 400
    expect(body.fetch("valid")).to eq(!rejected)
    expect(body.fetch("status")).to eq(rejected ? "REJECTED" : "VALIDATED")
    expect(body.fetch("violations").empty?).to eq(!rejected)
  when :netting
    expect(body.fetch("status")).to eq("NETTED")
    expect(body.fetch("net_notional")).to eq(-625_000)
    expect(body.fetch("batch_id")).to eq(settlement_batch_id)
    expect(body.fetch("netting_id")).not_to be_empty
  when :margin
    Day2Endurance.check_margin(@last_clearing_payload, body)
  when :settlement_poll
    expect(ClearingMockServer::SETTLEMENT_STATUSES).to include(body.fetch("status"))
    expect(body.fetch("batch_id")).to eq(settlement_batch_id)
    expect(body.fetch("poll_count")).to be >= 1
  end
  Day2Endurance.session&.sample("contract-#{@last_clearing_request.fetch(:endpoint)}")
end
