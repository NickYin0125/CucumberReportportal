# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "pathname"
require "ipaddr"

module Day2Endurance
  module Auth
    def self.validate_endpoint!(endpoint)
      raise ArgumentError, "RP_ENDPOINT must be a single-line absolute HTTP(S) URL" unless endpoint.is_a?(String) && !endpoint.empty? && !endpoint.match?(/[[:cntrl:]]/)
      uri = URI(endpoint)
      raise ArgumentError, "RP_ENDPOINT must be a credential-free absolute HTTP(S) URL" unless uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty? && !uri.userinfo && !uri.query && !uri.fragment
      uri
    rescue URI::InvalidURIError
      raise ArgumentError, "RP_ENDPOINT must be a valid HTTP(S) URL"
    end

    def self.validate_project!(project)
      raise ArgumentError, "RP_PROJECT must be a nonempty single project identifier" unless project.is_a?(String) && project.match?(/\A[A-Za-z0-9][A-Za-z0-9_-]*\z/)
      project
    end

    def self.local_target?(uri)
      host = uri.hostname.to_s.downcase
      return true if host == "localhost" || host.end_with?(".localhost")
      IPAddr.new(host).loopback?
    rescue IPAddr::InvalidAddressError
      false
    end

    def self.resolve(endpoint:, directory:, environment: ENV)
      uri = validate_endpoint!(endpoint)
      if environment.key?("RP_API_KEY")
        key = environment["RP_API_KEY"]
        raise ArgumentError, "RP_API_KEY must be nonempty visible ASCII without whitespace" unless key.is_a?(String) && key.match?(/\A[\x21-\x7e]+\z/)
        return [key, "RP_API_KEY environment"]
      end

      helper = environment["DAY2_AUTH_HELPER"]
      raise ArgumentError, "Set RP_API_KEY or explicitly provide an absolute DAY2_AUTH_HELPER" unless helper.is_a?(String) && !helper.empty? && !helper.match?(/[[:cntrl:]]/) && Pathname.new(helper).absolute?
      raise ArgumentError, "DAY2_AUTH_HELPER is restricted to loopback/local targets" unless local_target?(uri)
      raise ArgumentError, "DAY2_AUTH_HELPER file is unavailable" unless File.file?(helper)
      require helper
      raise "Optional helper must expose LatestRP.login and LatestRP.bearer" unless defined?(LatestRP) && LatestRP.respond_to?(:login) && LatestRP.respond_to?(:bearer)
      adapter = Module.new do
        define_method(:write) do |path, object|
          raise "Unexpected historical write" unless File.basename(path) == "backend-info.json"
          encoded = JSON.pretty_generate(object)
          encoded = encoded.gsub(LatestRP.bearer, "[REDACTED]") if LatestRP.bearer
          File.write(File.join(directory, "backend-info.json"), encoded, mode: "w", perm: 0o600)
        end
        define_method(:http_response) do |uri, request|
          target = URI(endpoint)
          target.path = uri.path
          target.query = uri.query
          request["Host"] = target.port == target.default_port ? target.host : "#{target.host}:#{target.port}"
          http = Net::HTTP.new(target.host, target.port, nil)
          http.ipaddr = "127.0.0.1" if target.host.end_with?(".localhost")
          http.use_ssl = target.scheme == "https"
          http.open_timeout, http.read_timeout = 5, 30
          http.start { |connection| connection.request(request) }
        end
      end
      LatestRP.singleton_class.prepend(adapter)
      LatestRP.login
      key = LatestRP.bearer
      raise "Local helper returned an invalid bearer" unless key.is_a?(String) && key.match?(/\A[\x21-\x7e]+\z/)
      [key, "explicit local helper"]
    end
  end
end
