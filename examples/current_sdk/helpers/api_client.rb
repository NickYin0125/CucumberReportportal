# frozen_string_literal: true

require "net/http"
require "json"

module CurrentSDK
  class ApiClient
    def initialize(base_url)
      @base_url = base_url
    end

    def request(method, path, body: nil, expected_status: nil)
      uri = URI("#{@base_url}#{path}")
      request = Net::HTTP.const_get(method.capitalize).new(uri)
      request["Content-Type"] = "application/json"
      request.body = body unless body.nil?
      AppLog.debug("API helper is sending #{method} #{path}", report: true)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = Net::HTTP.start(uri.host, uri.port, nil, open_timeout: 2, read_timeout: 3, write_timeout: 3) do |http|
        http.request(request)
      end
      record(method, uri, request, response, started, expected_status)
      response
    rescue StandardError => error
      AppLog.http(method: method, url: uri.to_s, error: error, expected_status: expected_status)
      raise
    end

    private

    # Deep helper logging uses the bound scenario World without step arguments.
    def record(method, uri, request, response, started, expected_status)
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      AppLog.http(method: method, url: uri.to_s,
                  request: {headers: request.to_hash, body: request.body},
                  response: {status: response.code.to_i, headers: response.to_hash, body: response.body},
                  duration_ms: elapsed.round(2), expected_status: expected_status)
      AppLog.info("API response snapshot", json: JSON.parse(response.body), report: true)
    end
  end
end
