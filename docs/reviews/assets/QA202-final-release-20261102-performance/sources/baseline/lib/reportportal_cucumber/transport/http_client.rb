# frozen_string_literal: true

require "net/http"
require "shellwords"

module ReportportalCucumber
  module Transport
    # Shared Net::HTTP transport with retry/backoff and per-thread connection reuse.
    class HTTPClient
      Response = Struct.new(:status, :headers, :body, :may_duplicate, keyword_init: true)

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
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [Response]
      def post_json(path:, body:, headers: {}, deadline: nil)
        encoded_body = JSON.generate(body)
        enforce_log_json_limit!(path: path, body: encoded_body)
        request(
          method: :post,
          path: path,
          body: encoded_body,
          headers: default_headers.merge(headers).merge("Content-Type" => "application/json"),
          deadline: deadline
        )
      end

      # @param path [String]
      # @param body [Hash]
      # @param headers [Hash]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [Response]
      def put_json(path:, body:, headers: {}, deadline: nil)
        request(
          method: :put,
          path: path,
          body: JSON.generate(body),
          headers: default_headers.merge(headers).merge("Content-Type" => "application/json"),
          deadline: deadline
        )
      end

      # @param path [String]
      # @param headers [Hash]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [Response]
      def get_json(path:, headers: {}, deadline: nil)
        request(
          method: :get,
          path: path,
          body: nil,
          headers: default_headers.merge(headers),
          deadline: deadline
        )
      end

      # @param path [String]
      # @param parts [Array<Hash>]
      # @param headers [Hash]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [Response]
      def post_multipart(path:, parts:, headers: {}, deadline: nil)
        boundary = MultipartHelper.standard_boundary
        normalized_parts = MultipartHelper.normalize_parts(parts)
        max_bytes = log_request?(path) ? batch_max_bytes : nil
        expected_length = MultipartHelper.encoded_length(parts: normalized_parts, boundary: boundary)
        raise MultipartHelper::SizeLimitError if max_bytes && expected_length > max_bytes

        curl_artifacts = prepare_multipart_curl_artifacts(path: path, parts: normalized_parts)
        body_source = MultipartHelper.body_source(parts: normalized_parts, boundary: boundary, max_bytes: max_bytes)
        actual_length = body_source.stream ? body_source.length : body_source.body.bytesize
        raise MultipartHelper::SizeLimitError if max_bytes && actual_length > max_bytes

        request(
          method: :post,
          path: path,
          body: body_source.body,
          body_stream: body_source.stream,
          content_length: body_source.length,
          headers: default_headers.merge(headers).merge("Content-Type" => "multipart/form-data; boundary=#{boundary}"),
          curl_parts: curl_artifacts,
          deadline: deadline
        )
      ensure
        body_source&.tempfile&.close!
      end

      # @return [void]
      def close
        sessions = thread_sessions
        sessions.each_value { |http| http.finish if http.started? }
        sessions.clear
      end

      private

      # @param path [String]
      # @param body [String]
      # @return [void]
      def enforce_log_json_limit!(path:, body:)
        raise MultipartHelper::SizeLimitError if log_request?(path) && body.bytesize > batch_max_bytes
      end

      # @param path [String]
      # @return [Boolean]
      def log_request?(path)
        build_uri(path).path.match?(%r{(?:\A|/)log\z})
      end

      # @return [Integer]
      def batch_max_bytes
        @config.respond_to?(:batch_max_bytes) ? @config.batch_max_bytes : 8 * 1024 * 1024
      end

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
      def request(method:, path:, body:, headers:, curl_parts: nil, body_stream: nil, content_length: nil,
                  deadline: nil)
        attempts = 0

        begin
          attempts += 1
          remaining = deadline&.remaining
          raise Timeout::Error, "reporting deadline expired" if remaining && remaining <= 0
          response = if remaining
                       Timeout.timeout(remaining) do
                         perform(
                           method: method, path: path, body: body, headers: headers, curl_parts: curl_parts,
                           body_stream: body_stream, content_length: content_length
                         )
                       end
                     else
                       perform(
                         method: method, path: path, body: body, headers: headers, curl_parts: curl_parts,
                         body_stream: body_stream, content_length: content_length
                       )
                     end
          response.may_duplicate = attempts > 1 if response.respond_to?(:may_duplicate=)
          return response unless retriable_response?(response)

          raise Error.new("Retriable HTTP #{response.status}", response: response)
        rescue *retriable_network_errors => error
          close_thread_sessions
          raise error if attempts >= @config.retry_attempts

          sleep([backoff_for(attempts), deadline ? deadline.remaining : Float::INFINITY].min)
          retry
        rescue Error => error
          raise error unless retriable_response?(error.response)
          raise error if attempts >= @config.retry_attempts

          sleep([backoff_for(attempts), deadline ? deadline.remaining : Float::INFINITY].min)
          retry
        end
      end

      # @param method [Symbol]
      # @param path [String]
      # @param body [String]
      # @param headers [Hash]
      # @return [Response]
      def perform(method:, path:, body:, headers:, curl_parts: nil, body_stream: nil, content_length: nil)
        uri = build_uri(path)
        log_curl(method: method, uri: uri, headers: headers, body: body, curl_parts: curl_parts)
        request = request_class_for(method).new(uri)
        headers.each { |key, value| request[key] = value }
        if body_stream
          body_stream.rewind
          request.body_stream = body_stream
          request.content_length = content_length
        else
          request.body = body
        end

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
        when :get
          Net::HTTP::Get
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
          body: parse_body(response.body.to_s),
          may_duplicate: false
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

      # @param method [Symbol]
      # @param uri [URI::HTTP]
      # @param headers [Hash]
      # @param body [String]
      # @param curl_parts [Array<String>, nil]
      # @return [void]
      def log_curl(method:, uri:, headers:, body:, curl_parts: nil)
        return unless @config.debug_curl_mode?

        command = ["curl", "-X", method.to_s.upcase]
        headers.each do |key, value|
          next if curl_parts && key.to_s.downcase == "content-type" && value.to_s.include?("multipart/form-data")

          header_value = key.to_s.downcase == "authorization" ? "Bearer <redacted>" : value
          command << "-H" << "#{key}: #{header_value}"
        end

        if curl_parts
          curl_parts.each { |part| command << "--form" << part }
        else
          command << "-d" << body
        end
        command << uri.to_s
        ReportportalCucumber.logger.debug(command.shelljoin)
      end

      # @param path [String]
      # @param parts [Array<Hash>]
      # @return [Array<String>, nil]
      def prepare_multipart_curl_artifacts(path:, parts:)
        return nil unless @config.debug_curl_mode?

        directory = File.expand_path(@config.debug_curl_dir, Dir.pwd)
        FileUtils.mkdir_p(directory)
        basename = "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(4)}"

        parts.each_with_index.map do |part, index|
          if part[:filename]
            file_path =
              if part[:path]
                part.fetch(:path)
              else
                File.join(directory, "#{basename}-#{index}-#{curl_file_name(part)}").tap do |artifact_path|
                  File.binwrite(artifact_path, part.fetch(:body))
                end
              end
            "file=@#{file_path};filename=#{part.fetch(:filename)};type=#{part.fetch(:content_type)}"
          else
            file_path = File.join(directory, "#{basename}-#{index}-#{curl_file_name(part)}")
            File.binwrite(file_path, part.fetch(:body))
            "#{part.fetch(:name)}=@#{file_path};type=#{part.fetch(:content_type)}"
          end
        end
      rescue StandardError => error
        ReportportalCucumber.logger.warn("Unable to prepare multipart curl artifacts for #{path}: #{error.class}: #{error.message}")
        nil
      end

      # @param part [Hash]
      # @return [String]
      def curl_file_name(part)
        candidate = part[:filename] || "#{part.fetch(:name)}.txt"
        candidate.to_s.gsub(%r{[^A-Za-z0-9_.-]}, "_")
      end
    end
  end
end
