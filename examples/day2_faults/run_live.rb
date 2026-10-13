#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require_relative "live_validation"
require_relative "source_manifest"
require "pathname"

module Day2Faults
  module LiveGate
    module_function

    def local_url!(value)
      uri = URI(value)
      raise "Only an explicitly supplied local cluster URL is permitted" unless uri.is_a?(URI::HTTP) &&
        ["localhost", "127.0.0.1", "::1", "rp-latest.localhost"].include?(uri.hostname) &&
        !uri.userinfo && !uri.fragment
      uri
    end

    def validate!(environment)
      raise "Wait for Manager readiness, then set DAY2_MANAGER_READY=true and pass --execute-local-rp" unless
        environment["DAY2_MANAGER_READY"] == "true"
      origin = local_url!(environment["DAY2_RP_ENDPOINT"] || environment.fetch("RP_ENDPOINT"))
      raise "RP endpoint must be an origin" unless ["", "/"].include?(origin.path) && !origin.query
      ready = local_url!(environment.fetch("DAY2_RP_READY_URL", URI.join(origin.to_s, "/api/info").to_s))
      [origin, ready]
    end

    def bounded_get(uri)
      request = Net::HTTP::Get.new(uri)
      http = Net::HTTP.new(uri.host, uri.port, nil)
      http.ipaddr = "127.0.0.1" if uri.hostname == "rp-latest.localhost"
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = http.read_timeout = http.write_timeout = 3
      http.max_retries = 0
      body = +"".b
      status = nil
      Timeout.timeout(4) do
        http.start do |connection|
          connection.request(request) do |response|
            status = response.code.to_i
            response.read_body do |chunk|
              raise LimitError if body.bytesize + chunk.bytesize > 512 * 1024
              body << chunk
            end
          end
        end
      end
      raise "Readiness HTTP #{status}" unless status.between?(200, 299)
      body
    end

    def verify_backend!(bytes, environment)
      current = JSON.parse(bytes)
      expected_version = environment.fetch("DAY2_EXPECTED_API_VERSION").strip
      raise "DAY2_EXPECTED_API_VERSION must be explicit and nonempty" if expected_version.empty?
      # RP 26.0.5 is a release bundle; /api/info reports the API component version.
      raise "Unexpected ReportPortal API component" unless current.dig("build", "repo") == "reportportal/service-api" &&
        current.dig("build", "version") == expected_version
      expected_instance = environment["DAY2_EXPECTED_INSTANCE"]
      if expected_instance && !expected_instance.strip.empty?
        raise "Unexpected ReportPortal instance" unless
          current.dig("extensions", "result", "server.details.instance") == expected_instance.strip
      end
      current
    end

    def credentials(environment)
      project = environment.fetch("RP_PROJECT", "").strip
      raise "RP_PROJECT must name the authorized project" unless project.match?(/\A[A-Za-z0-9][A-Za-z0-9_-]*\z/)
      token = environment.fetch("RP_API_KEY", "").strip
      source = "environment"
      if token.empty?
        helper = environment["DAY2_AUTH_HELPER"]
        raise "RP_API_KEY is required; local helper use requires explicit DAY2_AUTH_HELPER" if helper.to_s.empty?
        # A helper can execute local authentication code only after the local opt-in gate.
        validate!(environment)
        raise "DAY2_AUTH_HELPER must be an existing absolute local Ruby path" unless
          Pathname.new(helper).absolute? && File.extname(helper) == ".rb" && File.file?(helper)
        require helper
        raise "Auth helper must implement LatestRP.login and LatestRP.bearer" unless
          defined?(LatestRP) && LatestRP.respond_to?(:login) && LatestRP.respond_to?(:bearer)
        LatestRP.login
        token = LatestRP.bearer.to_s
        source = "local_helper"
      end
      raise "ReportPortal credential must be nonempty and single-line" if token.empty? || token.match?(/[\r\n]/)
      { token: token, project: project, source: source }
    end

    def main(environment = ENV, arguments = ARGV)
      abort "Live runs require --execute-local-rp after Manager's ready notice" unless arguments == ["--execute-local-rp"]
      origin, ready = validate!(environment)
      # Check explicit configuration before any HTTP, authentication, or launch creation.
      raise "DAY2_EXPECTED_API_VERSION must be explicit and nonempty" if
        environment.fetch("DAY2_EXPECTED_API_VERSION", "").strip.empty?
      before = SourceManifest.capture
      bounded_get(ready)
      info = bounded_get(URI.join(origin.to_s, "/api/info"))
      backend = verify_backend!(info, environment)
      auth = credentials(environment)
      base = environment.fetch("DAY2_EVIDENCE_DIR", File.join(Dir.tmpdir, "reportportal-day2-faults"))
      directory = File.join(base, "real-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}-#{SecureRandom.hex(3)}")
      suite = LiveValidation.new(upstream: origin.to_s, token: auth.fetch(:token), project: auth.fetch(:project), directory: directory,
                                 upstream_ip: origin.hostname == "rp-latest.localhost" ? "127.0.0.1" : nil)
      results = suite.run
      source = SourceManifest.record(directory: directory, before: before)
      Day2Faults.write_evidence(File.join(directory, "summary.json"),
                               { gateway_ready: ready.to_s, expected_api_version: environment.fetch("DAY2_EXPECTED_API_VERSION"),
                                 project: auth.fetch(:project), auth_source: auth.fetch(:source), backend_info: backend, source: source,
                                 results: results.map { |result| result.slice(:label, :validated, :launch_name, :launch_uuid,
                                                                             :receipt, :observed_duplicate_logs, :error) },
                                 exactly_once: false, sigkill_pending_memory_guaranteed: false }, token: auth.fetch(:token))
      puts "Sanitized real reconciliation evidence: #{directory}"
      exit(results.all? { |result| result[:validated] } && source.fetch(:unchanged_during_run) ? 0 : 1)
    end
  end
end

Day2Faults::LiveGate.main if $PROGRAM_NAME == __FILE__
