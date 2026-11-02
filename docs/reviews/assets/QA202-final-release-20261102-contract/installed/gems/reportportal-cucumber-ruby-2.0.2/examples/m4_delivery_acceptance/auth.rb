# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "open3"
require "uri"

module M4DeliveryAuth
  def self.bearer(endpoint)
    supplied = ENV["RP_API_KEY"].to_s
    return supplied unless supplied.empty?

    encoded, _, status = Open3.capture3("kubectl", "--context", "docker-desktop", "--request-timeout=5s",
                                      "-n", "reportportal", "get", "secret", "reportportal-uat-init-password",
                                      "-o", "jsonpath={.data.password}")
    raise "Existing local credential source unavailable" unless status.success? && !encoded.empty?

    uri = URI.join(endpoint + "/", "uat/sso/oauth/token")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth("ui", "uiman")
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request.body = URI.encode_www_form(grant_type: "password", username: "superadmin",
                                       password: Base64.strict_decode64(encoded))
    response = Net::HTTP.start(uri.host, uri.port, open_timeout: 5, read_timeout: 5) { |http| http.request(request) }
    raise "Existing local authentication refused (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("access_token")
  end
end
