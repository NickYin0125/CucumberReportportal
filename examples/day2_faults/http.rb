# frozen_string_literal: true

require "socket"
require "timeout"
require "digest"
require "json"
require "net/http"
require "uri"

module Day2Faults
  class LimitError < StandardError; end

  # Net::HTTP consumes this reader directly: no request-sized proxy buffer.
  class BodyStream
    CHUNK = 16 * 1024
    attr_reader :bytes, :digest, :peak_chunk

    def initialize(socket, length)
      @socket, @remaining = socket, length
      @bytes = @peak_chunk = 0
      @digest = Digest::SHA256.new
    end

    def read(length = CHUNK, output = nil)
      return nil if @remaining.zero?

      data = @socket.read([length || CHUNK, CHUNK, @remaining].min)
      raise EOFError unless data && !data.empty?

      @remaining -= data.bytesize
      @bytes += data.bytesize
      @peak_chunk = [@peak_chunk, data.bytesize].max
      @digest.update(data)
      output ? output.replace(data) : data
    end

    def drain
      nil while read
    end

    def collect
      result = +"".b
      while (chunk = read)
        result << chunk
      end
      result
    end
  end

  # One request per connection; bounded workers, headers, body, and wall time.
  class HTTPServer
    attr_reader :port

    def initialize(max_body: 8 * 1024 * 1024, max_clients: 8, timeout: 5, port: 0)
      @max_body, @max_clients, @timeout = max_body, max_clients, timeout
      @mutex = Mutex.new
      @clients = {}
      @listener = TCPServer.new("127.0.0.1", port)
      @port = @listener.addr[1]
      @acceptor = Thread.new do
        loop do
          socket = @listener.accept
          @mutex.synchronize do
            if @clients.length >= @max_clients
              socket.close
              next
            end
            @clients[socket] = Thread.new do
              serve(socket)
            ensure
              socket.close rescue nil
              @mutex.synchronize { @clients.delete(socket) }
            end
          end
        end
      rescue IOError, Errno::EBADF
        nil
      end
    end

    def endpoint = "http://127.0.0.1:#{port}"

    def stop
      @listener.close rescue nil
      @acceptor.join(0.2)
      clients = @mutex.synchronize { @clients.to_a }
      clients.each { |socket, _thread| socket.close rescue nil }
      clients.each { |_socket, thread| thread.kill; thread.join(0.2) }
    end

    def self.respond(socket, status, body, headers = {})
      bytes = body.is_a?(String) ? body.b : JSON.generate(body).b
      fields = { "Content-Type" => "application/json", "Content-Length" => bytes.bytesize.to_s,
                 "Connection" => "close" }.merge(headers)
      socket.write("HTTP/1.1 #{status} #{status < 400 ? 'OK' : 'Fault'}\r\n")
      fields.each { |key, value| socket.write("#{key}: #{value}\r\n") }
      socket.write("\r\n")
      socket.write(bytes)
    end

    private

    def serve(socket)
      Timeout.timeout(@timeout) do
        request_line = socket.gets("\r\n", 8193)
        return unless request_line
        raise LimitError if request_line.bytesize > 8192

        method, target, version = request_line.strip.split(" ")
        raise ArgumentError unless %w[GET POST PUT HEAD DELETE PATCH OPTIONS].include?(method) &&
                                   version == "HTTP/1.1" && target.start_with?("/") && !target.start_with?("//")
        headers = {}
        size = request_line.bytesize
        loop do
          line = socket.gets("\r\n", 8193)
          raise EOFError unless line
          size += line.bytesize
          raise LimitError if size > 32 * 1024 || line.bytesize > 8192
          break if line == "\r\n"

          key, value = line.chomp.split(":", 2)
          raise ArgumentError unless key&.match?(/\A[!#$%&'*+.^_`|~0-9a-z-]+\z/i) && value && !headers.key?(key.downcase)

          headers[key.downcase] = value.strip
        end
        # The SDK always sends Content-Length. Reject unsupported framing before forwarding.
        raise ArgumentError if headers.key?("transfer-encoding")
        raw_length = headers.fetch("content-length", "0")
        raise ArgumentError unless raw_length.match?(/\A\d+\z/)
        length = Integer(raw_length)
        raise LimitError if length > @max_body
        socket.write("HTTP/1.1 100 Continue\r\n\r\n") if headers["expect"] == "100-continue"
        handle(socket, method, target, headers, BodyStream.new(socket, length))
      end
    rescue LimitError
      self.class.respond(socket, 413, { "message" => "local proxy cap exceeded" }) rescue nil
    rescue ArgumentError
      self.class.respond(socket, 400, { "message" => "unsupported HTTP framing" }) rescue nil
    rescue Timeout::Error, IOError, EOFError, SystemCallError
      nil
    end
  end

  class FaultProxy < HTTPServer
    HOP_HEADERS = %w[connection keep-alive proxy-authenticate proxy-authorization te trailer transfer-encoding upgrade].freeze
    ACTIONS = %i[pass status disconnect timeout slow hidden_ack partial_ack].freeze

    def initialize(upstream:, steps: [], scope: :logs, repeat: false, response_cap: 2 * 1024 * 1024,
                   max_events: 1000, upstream_ip: nil, **options)
      @upstream = URI(upstream)
      raise ArgumentError, "HTTP(S) origin required" unless @upstream.is_a?(URI::HTTP) && @upstream.host &&
        !@upstream.userinfo && !@upstream.query && !@upstream.fragment && ["", "/"].include?(@upstream.path)
      raise ArgumentError unless %i[logs finish all].include?(scope)
      raise ArgumentError unless steps.all? { |step| ACTIONS.include?(step.fetch(:action)) }
      @steps, @scope, @repeat = steps, scope, repeat
      @response_cap, @max_events, @upstream_ip = response_cap, max_events, upstream_ip
      @event_mutex = Mutex.new
      @event_condition = ConditionVariable.new
      @events = []
      @active = 0
      @ordinal = @seen = 0
      super(**options)
    end

    def events
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.1
      @event_mutex.synchronize do
        while @active.positive?
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break if remaining <= 0
          @event_condition.wait(@event_mutex, remaining)
        end
        @events.map(&:dup)
      end
    end
    def seen = @event_mutex.synchronize { @seen }

    def clear_faults!
      @event_mutex.synchronize { @steps = []; @repeat = false; @ordinal = 0 }
    end

    private

    def next_step(method, target)
      path = target.split("?", 2).first
      matches = case @scope
                when :logs then method == "POST" && path.match?(%r{/log\z})
                when :finish then method == "PUT" && (path.end_with?("/finish") || path.match?(%r{/item/[^/]+\z}))
                else true
                end
      @event_mutex.synchronize do
        @seen += 1
        step = matches ? (@steps[@ordinal] || (@repeat && @steps.last)) : nil
        @ordinal += 1 if matches
        step || { action: :pass }
      end
    end

    def handle(socket, method, target, headers, stream)
      @event_mutex.synchronize { @active += 1 }
      step = next_step(method, target)
      event = { method: method, path: target.split("?", 2).first, action: step.fetch(:action),
                forwarded: false, uncertain: false }
      case step.fetch(:action)
      when :status
        stream.drain
        event[:status] = step.fetch(:status, 503)
        self.class.respond(socket, event[:status], { "message" => "day2 controlled fault" }, "Retry-After" => "0")
      when :disconnect
        stream.drain
        # Closing without a status line gives deterministic EOF, not an HTTP error.
      when :timeout
        stream.drain
        sleep(step.fetch(:delay, 2))
      else
        sleep(step.fetch(:delay, 0.1)) if step[:action] == :slow
        forward(socket, method, target, headers, stream, step, event)
      end
    rescue StandardError => error
      event[:error_class] = error.class.name
      event[:uncertain] = true if event[:forwarded] && method != "GET"
      raise
    ensure
      event[:request_bytes] = stream.bytes
      event[:request_sha256] = stream.digest.hexdigest
      event[:peak_chunk] = stream.peak_chunk
      @event_mutex.synchronize do
        @events << event.freeze if @events.length < @max_events
        @active -= 1
        @event_condition.broadcast
      end
    end

    def excluded(headers)
      HOP_HEADERS + headers.fetch("connection", "").split(",").map { |name| name.strip.downcase }
    end

    def forward(socket, method, target, headers, stream, step, event)
      http = Net::HTTP.new(@upstream.host, @upstream.port, nil)
      http.use_ssl = @upstream.scheme == "https"
      http.ipaddr = @upstream_ip if @upstream_ip
      http.open_timeout = http.read_timeout = http.write_timeout = @timeout
      http.max_retries = 0
      request = Net::HTTPGenericRequest.new(method, headers.fetch("content-length", "0").to_i.positive?,
                                           method != "HEAD", target)
      headers.each { |key, value| request[key] = value unless (excluded(headers) + %w[host expect]).include?(key) }
      request["host"] = @upstream.host + (@upstream.port == @upstream.default_port ? "" : ":#{@upstream.port}")
      request["connection"] = "close"
      request["accept-encoding"] = headers.fetch("accept-encoding", "identity")
      if headers.fetch("content-length", "0").to_i.positive?
        request.body_stream = stream
        request.content_length = headers.fetch("content-length").to_i
      end
      event[:forwarded] = true
      http.start do |connection|
        connection.request(request) do |response|
          event[:upstream_status] = event[:status] = response.code.to_i
          fields = response.each_header.to_h
          fields.reject! { |key, _| excluded(response.each_header.to_h).include?(key) }
          total = 0
          digest = Digest::SHA256.new
          transformed = %i[partial_ack hidden_ack].include?(step[:action])
          bytes = +"".b
          unless transformed
            socket.write("HTTP/1.1 #{response.code} #{response.message}\r\n")
            # Transfer framing changes, but entity bytes and end-to-end headers do not.
            fields.delete("content-length")
            fields["transfer-encoding"] = "chunked" unless method == "HEAD" || [204, 304].include?(response.code.to_i)
            fields["connection"] = "close"
            fields.each { |key, value| socket.write("#{key}: #{value}\r\n") }
            socket.write("\r\n")
          end
          response.read_body do |chunk|
            total += chunk.bytesize
            raise LimitError if total > @response_cap
            digest.update(chunk)
            if transformed
              bytes << chunk
            else
              socket.write("#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n") unless chunk.empty?
            end
          end
          event[:response_bytes] = total
          event[:response_sha256] = digest.hexdigest
          if transformed && response.is_a?(Net::HTTPSuccess)
            event[:uncertain] = true
            if step[:action] == :hidden_ack
              sleep(step.fetch(:delay, 0))
              return
            end
            parsed = JSON.parse(bytes)
            raise ArgumentError, "partial acknowledgement requires batch responses" unless parsed["responses"].is_a?(Array)
            parsed["responses"] = parsed["responses"].take(step.fetch(:keep, 1))
            fields.delete("content-length")
            self.class.respond(socket, response.code.to_i, parsed, fields)
          elsif transformed
            fields.delete("content-length")
            self.class.respond(socket, response.code.to_i, bytes, fields)
          elsif method != "HEAD" && ![204, 304].include?(response.code.to_i)
            socket.write("0\r\n\r\n")
          end
        end
      end
    end
  end
end
