# frozen_string_literal: true

require "json"
require "net/http"
require "rantly"
require "securerandom"
require "time"
require "uri"
require_relative "../../examples/day2_endurance/support"

module DurationPbt
  DEFAULT_BASE_URL = "http://127.0.0.1:4567"
  DEFAULT_ITERATIONS = 750
  SMOKE_ITERATIONS = 8
  SMOKE_MAX_ITERATIONS = 25
  DEFAULT_RETRY_ATTEMPTS = 3
  RETRYABLE_STATUSES = [503, 504].freeze
  SUCCESS_STATUSES = (200..299)
  ENDPOINTS = {
    trade_ingest: "/api/v1/trades/ingest",
    margin_calculate: "/api/v1/margin/calculate"
  }.freeze

  BOUNDARY_STRINGS = [
    "",
    " ",
    "\u0000",
    "\"quoted\"",
    "\\backslash\\",
    "line\nbreak",
    "tab\tseparated",
    "<script>alert(1)</script>",
    "' OR '1'='1",
    ("../" * 16),
    ("x" * 4096),
    "\u2028\u2029",
    "emoji-\u{1F4A5}",
    "combining-e\u0301",
    "rtl-\u202Egnirts"
  ].freeze

  HUGE_AMOUNTS = [
    0,
    1,
    10**9,
    10**18,
    10**24,
    10**36,
    9_999_999_999_999_999_999_999_999_999
  ].freeze

  CURRENCIES = %w[USD EUR GBP JPY CHF CNH BTC ETH XAU].freeze
  ASSET_CLASSES = %w[EQUITY FX FUTURE OPTION SWAP CRYPTO CREDIT COMMODITY].freeze
  SIDES = %w[BUY SELL SHORT COVER].freeze

  module_function

  def truthy_env?(key)
    %w[1 true yes y on].include?(ENV[key].to_s.strip.downcase)
  end

  def configured_base_url
    ENV["DURATION_REGRESSION_BASE_URL"].to_s.strip.then do |value|
      value.empty? ? ENV.fetch("CLEARING_MOCK_URL", DEFAULT_BASE_URL) : value
    end
  end

  def configured_iterations
    smoke = truthy_env?("DURATION_REGRESSION_SMOKE")
    raw = ENV["DURATION_REGRESSION_ITERATIONS"].to_s.strip
    iterations = raw.empty? ? (smoke ? SMOKE_ITERATIONS : DEFAULT_ITERATIONS) : Integer(raw, 10)
    raise ArgumentError, "DURATION_REGRESSION_ITERATIONS must be positive" unless iterations.positive?
    raise ArgumentError, "Acceptance requires 500-1000 iterations" unless smoke || (500..1000).cover?(iterations)

    smoke ? [iterations, SMOKE_MAX_ITERATIONS].min : iterations
  end

  def configured_retry_attempts
    raw = ENV["DURATION_REGRESSION_RETRY_ATTEMPTS"].to_s.strip
    attempts = raw.empty? ? DEFAULT_RETRY_ATTEMPTS : Integer(raw, 10)
    raise ArgumentError, "DURATION_REGRESSION_RETRY_ATTEMPTS must be positive" unless attempts.positive?

    attempts
  end

  def configure_smoke_runtime!
    return unless truthy_env?("DURATION_REGRESSION_SMOKE")

    ENV["CLEARING_MOCK_LATENCY_SCALE"] = ENV.fetch("CLEARING_MOCK_LATENCY_SCALE", "0.01")
  end

  class TradeGenerator
    attr_reader :seed

    def initialize(seed: Integer(ENV.fetch("DURATION_REGRESSION_SEED", "20261013")))
      @seed = seed
      @random = Random.new(seed)
    end

    def identifier
      @random.bytes(16).unpack1("H*")
    end

    def trade_payload(iteration:)
      correlation_id = identifier
      currency = choice(*CURRENCIES)
      amount = choice(*HUGE_AMOUNTS)

      {
        trade_id: "pbt-#{seed}-#{iteration}-#{identifier}",
        correlation_id: correlation_id,
        source_system: "duration-pbt",
        account_id: "acct-#{iteration}-#{boundary_string}",
        counterparty: boundary_string,
        side: choice(*SIDES),
        asset_class: choice(*ASSET_CLASSES),
        symbol: "SYM-#{boundary_string}",
        quantity: amount,
        price: huge_decimal_string,
        notional: amount * choice(1, 10, 100, 10_000),
        currency: currency,
        trade_date: "2026-10-13T00:00:00Z",
        settlement_date: (Time.utc(2026, 10, 13) + choice(0, 86_400, 172_800, 604_800)).iso8601(6),
        metadata: nested_metadata(depth: choice(3, 4, 5), breadth: choice(2, 3, 4))
      }
    end

    def margin_payload_for(trade_payload, iteration:)
      {
        calculation_id: "margin-pbt-#{iteration}-#{identifier}",
        correlation_id: trade_payload.fetch(:correlation_id),
        account_id: trade_payload.fetch(:account_id),
        currency: trade_payload.fetch(:currency),
        valuation_time: "2026-10-13T00:00:00Z",
        trades: [trade_payload],
        risk: {
          confidence_level: choice("0.9500", "0.9900", "0.9999"),
          stress_window_days: choice(1, 5, 10, 30, 365),
          exposure_limit: choice(*HUGE_AMOUNTS)
        },
        metadata: nested_metadata(depth: choice(2, 3, 4), breadth: choice(2, 3))
      }
    end

    private

    def choice(*values)
      values.fetch(@random.rand(values.length))
    end

    def rantly_integer
      @random.rand(0..(2**63 - 1))
    end

    def boundary_string
      choice(*BOUNDARY_STRINGS)
    end

    def huge_decimal_string
      whole = choice(*HUGE_AMOUNTS)
      fraction = rantly_integer % 1_000_000_000
      "#{whole}.#{fraction.to_s.rjust(9, '0')}"
    end

    def nested_metadata(depth:, breadth:)
      return scalar_metadata_value if depth <= 0

      case choice(:hash, :array, :mixed)
      when :array
        Array.new(breadth) { nested_metadata(depth: depth - 1, breadth: [breadth - 1, 1].max) }
      when :mixed
        {
          "boundaryKey-#{boundary_string}" => nested_metadata(depth: depth - 1, breadth: breadth),
          "auditTrail" => Array.new(breadth) { audit_metadata(depth - 1) },
          "limits" => {
            "maxNotional" => choice(*HUGE_AMOUNTS),
            "minTick" => huge_decimal_string,
            "notes" => boundary_string
          }
        }
      else
        Array.new(breadth).each_with_object({}) do |_, metadata|
          metadata["#{choice('alpha', 'beta', 'gamma')}-#{boundary_string}-#{identifier}"] =
            nested_metadata(depth: depth - 1, breadth: [breadth - 1, 1].max)
        end
      end
    end

    def audit_metadata(depth)
      {
        "eventId" => identifier,
        "actor" => boundary_string,
        "sequence" => rantly_integer,
        "payload" => depth.positive? ? nested_metadata(depth: depth, breadth: 2) : scalar_metadata_value
      }
    end

    def scalar_metadata_value
      case choice(:string, :amount, :boolean, :nil, :timestamp)
      when :string
        boundary_string
      when :amount
        choice(*HUGE_AMOUNTS)
      when :boolean
        choice(true, false)
      when :timestamp
        "2026-10-13T00:00:00Z"
      else
        nil
      end
    end
  end

  class Runner
    attr_reader :base_uri, :iterations, :smoke, :retry_attempts

    def initialize(base_url:, iterations:, smoke:, retry_attempts:)
      @base_uri = normalize_base_uri(base_url)
      @iterations = iterations
      @smoke = smoke
      @retry_attempts = retry_attempts
      @generator = TradeGenerator.new
      @stats = Hash.new(0)
    end

    def run
      configure_webmock_for_target
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      AppLog.debug(
        "Duration PBT starting iterations=#{iterations} smoke=#{smoke} base_url=#{base_uri}",
        json: { iterations: iterations, smoke: smoke, base_url: base_uri.to_s, retry_attempts: retry_attempts }
      )

      (1..iterations).each do |iteration|
        trade_payload = @generator.trade_payload(iteration: iteration)
        Day2Endurance.check("seeded JSON round trip", JSON.parse(JSON.generate(trade_payload)) == Day2Endurance.json_value(trade_payload))
        @input_digest ||= Digest::SHA256.new
        @input_digest.update(JSON.generate(trade_payload))
        AppLog.debug(
          "Duration PBT generated trade iteration=#{iteration}/#{iterations} correlation_id=#{trade_payload[:correlation_id]}"
        )

        ingest_response = post_with_retry(:trade_ingest, ENDPOINTS.fetch(:trade_ingest), trade_payload, iteration)

        margin_payload = @generator.margin_payload_for(trade_payload, iteration: iteration)
        @input_digest.update(JSON.generate(margin_payload))
        margin_response = post_with_retry(:margin_calculate, ENDPOINTS.fetch(:margin_calculate), margin_payload, iteration)

        @stats[:iterations] += 1
        AppLog.info("Duration PBT invariant checks iteration=#{iteration}", attach: true,
                    json: { seed: @generator.seed, iteration: iteration, ingest_status: ingest_response.code.to_i,
                            margin_status: margin_response.code.to_i, margin_oracle: Day2Endurance.margin_oracle(margin_payload).to_s("F"),
                            json_round_trip: true, rejection_or_acceptance_contract: true, margin_contract: true })
        if iteration == 1 || (iteration % 25).zero?
          AppLog.info("Duration huge JSON iteration=#{iteration}", attach: true,
                      json: { seed: @generator.seed, iteration: iteration, boundary: trade_payload,
                              huge: "HUGE-JSON-BOUNDARY-" * 32_768 })
          @stats[:huge_json_logs] += 1
        end
        Day2Endurance.session&.sample("pbt-#{iteration}")
        Day2Endurance.session&.pace(iteration, iterations, started_at)
        AppLog.debug("Duration PBT completed iteration=#{iteration}/#{iterations}")
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      Day2Endurance.session&.sample("pbt-complete")
      summary = @stats.merge(iterations: iterations, elapsed_seconds: elapsed, seed: @generator.seed,
                             input_sha256: @input_digest.hexdigest)
      if Day2Endurance.session
        File.write(File.join(Day2Endurance.session.directory, "pbt.json"), JSON.pretty_generate(summary), mode: "w", perm: 0o600)
      end
      AppLog.debug("Duration PBT finished #{summary.inspect}", json: summary)
      summary
    end

    private

    def normalize_base_uri(base_url)
      uri = URI.parse(base_url)
      raise ArgumentError, "DURATION_REGRESSION_BASE_URL must be a credential-free HTTP URL" unless uri.is_a?(URI::HTTP) && uri.host && !uri.userinfo && !uri.query && !uri.fragment

      uri.path = "" if uri.path == "/"
      uri
    end

    def configure_webmock_for_target
      return unless defined?(WebMock)

      target = /\A#{Regexp.escape("#{base_uri.scheme}://#{base_uri.host}:#{base_uri.port}")}/
      WebMock.disable_net_connect!(allow_localhost: true, allow: target)
    end

    def post_with_retry(name, path, payload, iteration)
      retry_attempts.times do |attempt_index|
        response = post_json(path, payload)
        status = response.code.to_i
        @stats[:requests] += 1
        @stats[:"#{name}_requests"] += 1

        valid = !payload[:counterparty].to_s.strip.empty? && payload[:notional].positive?
        expected = name == :trade_ingest ? (valid ? 202 : 400) : 200
        if status == expected
          body = JSON.parse(response.body)
          Day2Endurance.check("PBT response JSON object", body.is_a?(Hash))
          if name == :margin_calculate
            Day2Endurance.check_margin(payload, body)
          elsif valid
            Day2Endurance.check("ingest acceptance contract", body["status"] == "ACCEPTED" && !body["trade_ingest_id"].to_s.empty? && !body["batch_id"].to_s.empty?)
          else
            Day2Endurance.check("invalid boundary rejected", body["status"] == "REJECTED" && body["valid"] == false && !body.fetch("violations").empty?)
            @stats[:expected_rejections] += 1
          end
          @stats[:checked_requests] += 1
          @stats[:"#{name}_checked"] += 1
          @stats[:accepted_requests] += 1 if SUCCESS_STATUSES.cover?(status)
          AppLog.debug(
            "Duration PBT #{name} accepted iteration=#{iteration} status=#{status} attempt=#{attempt_index + 1}"
          )
          return response
        end

        if RETRYABLE_STATUSES.include?(status)
          warn_retryable_status(name, status, path, iteration, attempt_index, response)
          sleep retry_delay(attempt_index) unless attempt_index == retry_attempts - 1
          next
        end

        AppLog.error(
          "Duration PBT #{name} unexpected HTTP #{status} iteration=#{iteration} body=#{response_snippet(response)}",
          attach: true,
          json: payload
        )
        raise "Unexpected HTTP #{status} from #{path}"
      rescue StandardError => e
        raise if e.message.start_with?("Unexpected HTTP")

        AppLog.error(
          "Duration PBT #{name} exception iteration=#{iteration} attempt=#{attempt_index + 1}: #{e.class}: #{e.message}",
          attach: true,
          json: payload
        )
        raise
      end

      AppLog.error(
        "Duration PBT #{name} exhausted #{retry_attempts} attempts after retryable 503/504 responses iteration=#{iteration}",
        attach: true,
        json: payload
      )
      raise "Retryable #{name} responses did not recover for #{path}"
    end

    def warn_retryable_status(name, status, path, iteration, attempt_index, response)
      @stats[:retryable_responses] += 1
      AppLog.warn(
        "Duration PBT #{name} received HTTP #{status}; retrying iteration=#{iteration} " \
        "attempt=#{attempt_index + 1}/#{retry_attempts} path=#{path} body=#{response_snippet(response)}"
      )
    end

    def post_json(path, payload)
      uri = base_uri + path
      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json"
      request["Content-Type"] = "application/json"
      request["X-Correlation-Id"] = payload[:correlation_id].to_s unless payload[:correlation_id].nil?
      request.body = JSON.generate(payload)

      AppLog.debug("Duration PBT POST #{path} bytes=#{request.body.bytesize}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = timeout_value("DURATION_REGRESSION_OPEN_TIMEOUT", smoke ? 1 : 5)
      http.read_timeout = timeout_value("DURATION_REGRESSION_READ_TIMEOUT", smoke ? 3 : 20)
      http.write_timeout = timeout_value("DURATION_REGRESSION_WRITE_TIMEOUT", smoke ? 1 : 5) if http.respond_to?(:write_timeout=)
      http.start { |session| session.request(request) }
    end

    def timeout_value(env_key, default)
      raw = ENV[env_key].to_s.strip
      raw.empty? ? default : Float(raw)
    end

    def retry_delay(attempt_index)
      base = smoke ? 0.02 : 0.1
      [base * (2**attempt_index), smoke ? 0.1 : 1.0].min
    end

    def response_snippet(response)
      response.body.to_s.byteslice(0, 512).to_s.gsub(/\s+/, " ").strip
    end
  end
end

Given("the clearing duration PBT target is configured") do
  DurationPbt.configure_smoke_runtime!
  @duration_pbt_smoke = DurationPbt.truthy_env?("DURATION_REGRESSION_SMOKE")
  @duration_pbt_iterations = DurationPbt.configured_iterations
  @duration_pbt_base_url = DurationPbt.configured_base_url
  @duration_pbt_retry_attempts = DurationPbt.configured_retry_attempts

  AppLog.debug(
    "Duration PBT target configured base_url=#{@duration_pbt_base_url} " \
    "iterations=#{@duration_pbt_iterations} smoke=#{@duration_pbt_smoke}",
    json: {
      base_url: @duration_pbt_base_url,
      iterations: @duration_pbt_iterations,
      smoke: @duration_pbt_smoke,
      retry_attempts: @duration_pbt_retry_attempts
    }
  )
end

When("I bombard the clearing duration APIs with generated trade JSON") do
  @duration_pbt_result = DurationPbt::Runner.new(
    base_url: @duration_pbt_base_url,
    iterations: @duration_pbt_iterations,
    smoke: @duration_pbt_smoke,
    retry_attempts: @duration_pbt_retry_attempts
  ).run
end

Then("the clearing duration PBT run should finish without unexpected API failures") do
  expect(@duration_pbt_result.fetch(:iterations)).to eq(@duration_pbt_iterations)
  expect(@duration_pbt_result.fetch(:checked_requests)).to eq(@duration_pbt_iterations * DurationPbt::ENDPOINTS.length)
  DurationPbt::ENDPOINTS.each_key do |name|
    expect(@duration_pbt_result.fetch(:"#{name}_checked")).to eq(@duration_pbt_iterations)
    expect(@duration_pbt_result.fetch(:"#{name}_requests")).to be >= @duration_pbt_iterations
  end
  expect(@duration_pbt_result.fetch(:accepted_requests) + @duration_pbt_result.fetch(:expected_rejections, 0)).to eq(@duration_pbt_result.fetch(:checked_requests))
end
