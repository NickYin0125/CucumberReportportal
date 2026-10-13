# frozen_string_literal: true

require "json"
require "securerandom"
require "sinatra/base"
require "socket"
require "time"
require "uri"
require "bigdecimal"

module ClearingMockServer
  DEFAULT_URL = "http://127.0.0.1:4567"
  SETTLEMENT_STATUSES = %w[PENDING PROCESSING COMPLETED].freeze

  # Lightweight Sinatra app that simulates a clearing system with latency,
  # stateful settlement polling, and controlled chaos injection.
  class App < Sinatra::Base
    configure do
      set :environment, :test
      set :logging, false
      set :raise_errors, false
      set :show_exceptions, false
      set :server, :puma
    end

    class << self
      def reset!
        @mutex = Mutex.new
        @settlement_batches = {}
        @random = Random.new(Integer(ENV.fetch("DURATION_REGRESSION_SEED", "20261013")))
      end

      def random
        mutex.synchronize { (@random ||= Random.new(20261013)).rand }
      end

      def next_settlement_status(batch_id)
        mutex.synchronize do
          batch = settlement_batches[batch_id] ||= { polls: 0 }
          index = [batch.fetch(:polls), SETTLEMENT_STATUSES.length - 1].min
          batch[:polls] += 1 unless index == SETTLEMENT_STATUSES.length - 1

          batch[:ledger_reference] ||= "LEDGER-#{SecureRandom.hex(3).upcase}" if index == SETTLEMENT_STATUSES.length - 1
          [SETTLEMENT_STATUSES.fetch(index), batch.fetch(:polls), batch[:ledger_reference]]
        end
      end

      def seed_settlement_batch(batch_id)
        mutex.synchronize { settlement_batches[batch_id] ||= { polls: 0 } }
      end

      private

      def mutex
        @mutex ||= Mutex.new
      end

      def settlement_batches
        @settlement_batches ||= {}
      end
    end

    before do
      content_type :json
      maybe_inject_chaos!
    end

    get "/__health" do
      json_response(200, status: "UP", now: timestamp)
    end

    post "/api/v1/trades/ingest" do
      with_latency(rand_between(0.05, 0.1)) do
        payload = request_json
        halt 400, json_response(400, status: "REJECTED", valid: false, violations: validation_violations(payload)) unless valid_trade_payload?(payload)
        batch_id = payload["batch_id"] || payload["batchId"] || "batch-#{SecureRandom.hex(6)}"
        self.class.seed_settlement_batch(batch_id)

        json_response(
          202,
          status: "ACCEPTED",
          trade_ingest_id: SecureRandom.uuid,
          batch_id: batch_id,
          received_at: timestamp
        )
      end
    end

    post "/api/v1/clearing/validate" do
      payload = request_json
      unless valid_trade_payload?(payload)
        json_response(
          400,
          status: "REJECTED",
          valid: false,
          violations: validation_violations(payload),
          rejected_at: timestamp
        )
      else
        json_response(
          200,
          status: "VALIDATED",
          valid: true,
          validation_id: SecureRandom.uuid,
          violations: [],
          validated_at: timestamp
        )
      end
    end

    post "/api/v1/clearing/netting" do
      with_latency(rand_between(0.5, 1.0)) do
        payload = request_json
        batch_id = payload["batch_id"] || payload["batchId"] || "batch-#{SecureRandom.hex(6)}"
        self.class.seed_settlement_batch(batch_id)

        json_response(
          200,
          status: "NETTED",
          batch_id: batch_id,
          netting_id: SecureRandom.uuid,
          net_notional: net_notional(payload),
          netted_at: timestamp
        )
      end
    end

    post "/api/v1/margin/calculate" do
      with_latency(gaussian_latency(2.0, 5.0, mean: 3.5, stddev: 0.75)) do
        payload = request_json

        json_response(
          200,
          status: "CALCULATED",
          margin_call_id: SecureRandom.uuid,
          total_margin: total_margin(payload),
          calculated_at: timestamp
        )
      end
    end

    get "/api/v1/settlement/batch/:id" do |batch_id|
      with_latency(long_poll_delay) do
        status_name, poll_count, ledger_reference = self.class.next_settlement_status(batch_id)

        json_response(
          200,
          batch_id: batch_id,
          status: status_name,
          poll_count: poll_count,
          ledger_reference: ledger_reference,
          updated_at: timestamp
        )
      end
    end

    not_found do
      json_response(404, error: "No clearing mock route for #{request.request_method} #{request.path_info}")
    end

    error do
      exception = env["sinatra.error"]
      json_response(500, error: exception.message, error_class: exception.class.name)
    end

    helpers do
      def json_response(status_code, payload)
        status status_code
        "#{JSON.generate(payload)}\n"
      end

      def request_json
        body = request.body.read.to_s
        payload = JSON.parse(body)
        halt 400, json_response(400, error: "JSON object required") unless payload.is_a?(Hash)
        payload
      rescue JSON::ParserError
        halt 400, json_response(400, error: "Malformed JSON")
      ensure
        request.body.rewind if request.body.respond_to?(:rewind)
      end

      def maybe_inject_chaos!
        return if request.path_info == "/__health"
        return if self.class.random >= chaos_rate

        status_code = self.class.random < 0.5 ? 503 : 504
        halt status_code, json_response(status_code, error: "Injected clearing mock chaos", injected_at: timestamp)
      end

      def chaos_rate
        return 0.0 if truthy_env?("CLEARING_MOCK_DISABLE_CHAOS")

        raw = ENV["CLEARING_MOCK_CHAOS_RATE"] || ENV["CLEARING_MOCK_CHAOS_PERCENT"]
        return 0.05 if raw.to_s.empty?

        rate = Float(raw)
        rate /= 100.0 if rate > 1.0
        [[rate, 0.0].max, 1.0].min
      rescue ArgumentError
        0.05
      end

      def valid_trade_payload?(payload)
        validation_violations(payload).empty?
      end

      def validation_violations(payload)
        trades = payload.key?("trade") ? [payload["trade"]] : payload.fetch("trades", [payload])
        return ["trades must be a nonempty array"] unless trades.is_a?(Array) && !trades.empty?
        trades.flat_map { |trade| validation_violations_for_trade(trade) }.uniq
      end

      def validation_violations_for_trade(trade)
        return ["trade must be an object"] unless trade.is_a?(Hash)
        violations = []
        violations << "counterparty is required" if trade["counterparty"].to_s.strip.empty?
        violations << "currency must be ISO-4217" unless trade["currency"].to_s.match?(/\A[A-Z]{3}\z/)
        value = trade["notional"]
        violations << "notional must be positive" unless value.is_a?(Numeric) && value.finite? && value.positive?
        violations << "tradeId is required" if (trade["tradeId"] || trade["trade_id"]).to_s.strip.empty?
        violations
      end

      def net_notional(payload)
        trades = payload["trades"] || []
        trades.sum do |trade|
          sign = trade["direction"].to_s.upcase == "PAY" ? -1 : 1
          sign * trade.fetch("notional")
        end
      end

      def total_margin(payload)
        positions = payload["positions"] || payload["trades"] || []
        base = positions.sum { |position| BigDecimal(position.fetch("netNotional", position.fetch("notional", 0)).to_s).abs }
        [base * BigDecimal("0.1"), BigDecimal("1000")].max.round(2).to_f
      end

      def with_latency(seconds)
        remaining = seconds * latency_scale
        while remaining.positive?
          slice = [remaining, 0.1].min
          sleep slice
          remaining -= slice
        end

        yield
      end

      def rand_between(min, max)
        min + (self.class.random * (max - min))
      end

      def gaussian_latency(min, max, mean:, stddev:)
        u1 = [self.class.random, 0.000_001].max
        u2 = self.class.random
        z0 = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
        [[mean + (z0 * stddev), min].max, max].min
      end

      def long_poll_delay
        configured = ENV["CLEARING_MOCK_LONG_POLL_MS"]
        return configured.to_f / 1000.0 if configured && !configured.empty?

        rand_between(0.25, 0.75)
      end

      def latency_scale
        scale = Float(ENV.fetch("CLEARING_MOCK_LATENCY_SCALE", "1"))
        scale.negative? ? 1.0 : scale
      rescue ArgumentError
        1.0
      end

      def truthy_env?(key)
        %w[1 true yes on].include?(ENV[key].to_s.strip.downcase)
      end

      def timestamp
        Time.now.utc.iso8601(3)
      end
    end
  end

  class << self
    def start
      return if @thread&.alive?
      return unless autostart?

      url = configured_url
      uri = URI.parse(url)
      raise ArgumentError, "CLEARING_MOCK_URL must be an http URL, got #{url.inspect}" unless uri.is_a?(URI::HTTP)

      App.reset!
      @thread = Thread.new do
        App.run!(bind: uri.host, port: uri.port, server: "puma", quiet: true)
      end
      @thread.name = "clearing-mock-sinatra" if @thread.respond_to?(:name=)
      @thread.report_on_exception = false if @thread.respond_to?(:report_on_exception=)
      wait_until_accepting(uri)
      ENV["CLEARING_MOCK_URL"] = url
    end

    def stop
      App.quit! if @thread&.alive?
      @thread&.join(5)
    rescue StandardError => error
      warn "Clearing mock cleanup failed (#{error.class}); preserving native outcome"
    ensure
      @thread = nil
    end

    def configured_url
      url = ENV["CLEARING_MOCK_URL"].to_s.strip
      url.empty? ? DEFAULT_URL : url
    end

    def autostart?
      return false if %w[1 true yes on].include?(ENV["CLEARING_MOCK_DISABLED"].to_s.strip.downcase)
      return true if %w[1 true yes on].include?(ENV["CLEARING_MOCK_AUTOSTART"].to_s.strip.downcase)

      false
    end

    private

    def wait_until_accepting(uri)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5

      loop do
        TCPSocket.open(uri.host, uri.port).close
        return
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        raise "Timed out starting clearing mock server at #{uri.host}:#{uri.port}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.05
      end
    end
  end
end

if ClearingMockServer.autostart? && respond_to?(:BeforeAll, true) && respond_to?(:AfterAll, true)
  BeforeAll { ClearingMockServer.start }
  AfterAll { ClearingMockServer.stop }
end

at_exit { ClearingMockServer.stop } if ClearingMockServer.autostart?
