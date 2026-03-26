# frozen_string_literal: true

require "net/http"

module ReportportalCucumber
  module Transport
    # Shared Net::HTTP transport with retry/backoff and per-thread connection reuse.
    class HTTPClient
      Response = Struct.new(:status, :headers, :body, keyword_init: true)

      class Error < ReportportalCucumber::ReportingError
        attr_reader :response

        # @param message [String]
        # @param response [Response, nil]
        def initialize(message, response: nil)
          @response = response
          super(message)
        end
      end

      # @param config [ReportportalCucumber::Config]
      def initialize(config:)
        @config = config
        @base_uri = URI(config.endpoint)
      end

      # @param path [String]
      # @param body [Hash]
      # @param headers [Hash]
      # @return [Response]
      def post_json(path:, body:, headers: {})
        request(
          method: :post,
          path: path,
          body: JSON.generate(body),
          headers: default_headers.merge(headers).merge("Content-Type" => "application/json")
        )
      end

      # @param path [String]
      # @param body [Hash]
      # @param headers [Hash]
      # @return [Response]
      def put_json(path:, body:, headers: {})
        request(
          method: :put,
          path: path,
          body: JSON.generate(body),
          headers: default_headers.merge(headers).merge("Content-Type" => "application/json")
        )
      end

      # @param path [String]
      # @param parts [Array<Hash>]
      # @param headers [Hash]
      # @return [Response]
      def post_multipart(path:, parts:, headers: {})
        boundary = "----rp#{SecureRandom.hex(12)}"
        request(
          method: :post,
          path: path,
          body: encode_multipart(parts, boundary),
          headers: default_headers.merge(headers).merge("Content-Type" => "multipart/form-data; boundary=#{boundary}")
        )
      end

      # @return [void]
      def close
        sessions = thread_sessions
        sessions.each_value { |http| http.finish if http.started? }
        sessions.clear
      end

      private

      # @return [Hash]
      def default_headers
        {
          "Authorization" => "Bearer #{@config.api_key}",
          "Accept" => "application/json"
        }
      end

      # @param method [Symbol]
      # @param path [String]
      # @param body [String]
      # @param headers [Hash]
      # @return [Response]
      def request(method:, path:, body:, headers:)
        attempts = 0

        begin
          attempts += 1
          response = perform(method: method, path: path, body: body, headers: headers)
          return response unless retriable_response?(response)

          raise Error.new("Retriable HTTP #{response.status}", response: response)
        rescue *retriable_network_errors => error
          close_thread_sessions
          raise error if attempts >= @config.retry_attempts

          sleep(backoff_for(attempts))
          retry
        rescue Error => error
          raise error if fatal_response?(error.response) || attempts >= @config.retry_attempts

          sleep(backoff_for(attempts))
          retry
        end
      end

      # @param method [Symbol]
      # @param path [String]
      # @param body [String]
      # @param headers [Hash]
      # @return [Response]
      def perform(method:, path:, body:, headers:)
        uri = build_uri(path)
        request = request_class_for(method).new(uri)
        headers.each { |key, value| request[key] = value }
        request.body = body

        raw_response = with_http(uri) { |http| http.request(request) }
        response = build_response(raw_response)
        close_session(uri) if raw_response["connection"].to_s.downcase == "close"
        raise Error.new("HTTP #{response.status}", response: response) if response.status >= 400

        response
      end

      # @param uri [URI::HTTP]
      # @yieldparam http [Net::HTTP]
      # @return [Object]
      def with_http(uri)
        session = session_for(uri)
        yield session
      rescue IOError, EOFError, Errno::ECONNRESET, Errno::EPIPE
        close_session(uri)
        raise
      end

      # @param uri [URI::HTTP]
      # @return [Net::HTTP]
      def session_for(uri)
        key = session_key(uri)
        thread_sessions[key] ||= start_session(uri)
      end

      # @param uri [URI::HTTP]
      # @return [Net::HTTP]
      def start_session(uri)
        proxy_uri = proxy_uri_for(uri)
        klass =
          if proxy_uri
            Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
          else
            Net::HTTP
          end

        klass.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: @config.open_timeout,
          read_timeout: @config.read_timeout,
          write_timeout: @config.write_timeout
        )
      end

      # @param uri [URI::HTTP]
      # @return [void]
      def close_session(uri)
        session = thread_sessions.delete(session_key(uri))
        session&.finish if session&.started?
      end

      # @return [void]
      def close_thread_sessions
        close
      end

      # @param uri [URI::HTTP]
      # @return [String]
      def session_key(uri)
        proxy_uri = proxy_uri_for(uri)
        [uri.scheme, uri.host, uri.port, proxy_uri&.to_s].join(":")
      end

      # @return [Hash]
      def thread_sessions
        Thread.current[:reportportal_http_sessions] ||= {}
      end

      # @param path [String]
      # @return [URI::HTTP]
      def build_uri(path)
        URI.join("#{@base_uri}/", path.sub(%r{\A/}, ""))
      end

      # @param method [Symbol]
      # @return [Class]
      def request_class_for(method)
        case method
        when :post
          Net::HTTP::Post
        when :put
          Net::HTTP::Put
        else
          raise ArgumentError, "Unsupported HTTP method: #{method}"
        end
      end

      # @param response [Net::HTTPResponse]
      # @return [Response]
      def build_response(response)
        Response.new(
          status: response.code.to_i,
          headers: response.each_header.to_h,
          body: parse_body(response.body.to_s)
        )
      end

      # @param body [String]
      # @return [Hash, Array, String]
      def parse_body(body)
        JSON.parse(body)
      rescue JSON::ParserError
        body
      end

      # @param response [Response, nil]
      # @return [Boolean]
      def retriable_response?(response)
        (response && [408, 429].include?(response.status)) || (response && response.status >= 500)
      end

      # @param response [Response, nil]
      # @return [Boolean]
      def fatal_response?(response)
        response && [400, 401, 403].include?(response.status)
      end

      # @return [Array<Class>]
      def retriable_network_errors
        [
          EOFError,
          Errno::ECONNREFUSED,
          Errno::ECONNRESET,
          Errno::EHOSTUNREACH,
          Errno::EPIPE,
          Errno::ETIMEDOUT,
          IOError,
          Net::OpenTimeout,
          Net::ReadTimeout,
          SocketError,
          Timeout::Error
        ]
      end

      # @param attempt [Integer]
      # @return [Float]
      def backoff_for(attempt)
        base = @config.retry_base_interval * (2**(attempt - 1))
        capped = [base, @config.retry_max_interval].min
        capped + rand * (capped / 3.0)
      end

      # @param uri [URI::HTTP]
      # @return [URI::HTTP, nil]
      def proxy_uri_for(uri)
        candidate = ENV[uri.scheme == "https" ? "HTTPS_PROXY" : "HTTP_PROXY"] || ENV["ALL_PROXY"]
        return nil if candidate.to_s.strip.empty?

        URI(candidate)
      rescue URI::InvalidURIError
        nil
      end

      # @param parts [Array<Hash>]
      # @param boundary [String]
      # @return [String]
      def encode_multipart(parts, boundary)
        MultipartHelper.encode(parts: parts, boundary: boundary)
      end
    end
  end
end
