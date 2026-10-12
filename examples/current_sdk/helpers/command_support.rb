# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "uri"

module CurrentSDK
  module Commands
    ROOT = File.expand_path("..", __dir__)

    def self.prepare
      abort "Use Ruby >= 3.1; current interpreter is #{RUBY_VERSION}" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.1")
      Dir.chdir(ROOT)
      if File.file?(File.expand_path("../../reportportal-cucumber-ruby.gemspec", ROOT))
        abort "Copy examples/current_sdk outside the SDK checkout before running setup or examples."
      end
      ENV["RP_ENABLED"] ||= "false"
      ENV["RP_CLIENT_JOIN"] ||= "false"
      ENV["RP_CONFIG"] ||= File.join(ROOT, "config/reportportal.yml")
      ENV["CUCUMBER_PUBLISH_ENABLED"] = "false"
      ENV["CUCUMBER_PUBLISH_QUIET"] = "true"
    end

    def self.safe_reporting_endpoint?(value, allow_local_http: false)
      endpoint = URI(value)
      local_http = allow_local_http && endpoint.scheme == "http" &&
        %w[localhost 127.0.0.1].include?(endpoint.host)
      !!((endpoint.scheme == "https" || local_http) && endpoint.host &&
         !endpoint.userinfo && !endpoint.query && !endpoint.fragment)
    rescue URI::InvalidURIError
      false
    end
  end
end
