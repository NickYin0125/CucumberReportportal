# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "securerandom"
require "socket"
require "uri"

module Cucumber12QA
  # Deliberately independent of SDK models: malformed or out-of-order HTTP fails closed.
  class WireServer
    TOKEN = "cucumber12-synthetic-only"
    STATUSES = %w[PASSED FAILED SKIPPED INTERRUPTED].freeze

    def initialize(fault: nil)
      @socket = TCPServer.new("127.0.0.1", 0)
      @mutex = Mutex.new
      @state = { "launches" => {}, "items" => {}, "logs" => [], "requests" => [], "errors" => [] }
      @fault = fault
      @thread = Thread.new { serve }
    end

    def endpoint
      "http://127.0.0.1:#{@socket.addr[1]}"
    end

    def snapshot
      @mutex.synchronize { Marshal.load(Marshal.dump(@state)) }
    end

    def stop
      @stopping = true
      @socket.close
      raise "QA HTTP server failed to stop" unless @thread.join(3)

      @thread.value
    end

    def parent_request(method, path, payload)
      uri = URI("#{endpoint}/api/v1/qa/#{path}")
      request = (method == :post ? Net::HTTP::Post : Net::HTTP::Put).new(uri)
      request["Authorization"] = "Bearer #{TOKEN}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
      raise "QA parent HTTP #{response.code}: #{response.body}" unless response.code.to_i < 300

      JSON.parse(response.body)
    end

    private

    def serve
      loop do
        connection = @socket.accept
        handle(connection)
      rescue IOError, Errno::EBADF
        break if @stopping

        raise
      end
    rescue StandardError => error
      @mutex.synchronize { @state.fetch("errors") << "server thread: #{error.class}: #{error.message}" }
    end

    def handle(connection)
      method, target, = connection.gets("\r\n").to_s.split(" ")
      headers = {}
      while (line = connection.gets("\r\n")) && line != "\r\n"
        key, value = line.split(":", 2)
        headers[key.downcase] = value.strip
      end
      length = Integer(headers.fetch("content-length", "0"))
      body = connection.read(length).to_s.b
      path = URI(target).path
      status, response = @mutex.synchronize do
        begin
          check(headers["authorization"] == "Bearer #{TOKEN}", "missing/incorrect authentication")
          record = { "method" => method, "path" => path, "sequence" => @state.fetch("requests").length }
          @state.fetch("requests") << record
          route(method, path, headers, body, record)
        rescue StandardError => error
          @state.fetch("errors") << "#{method} #{path}: #{error.class}: #{error.message}"
          [422, { "message" => error.message }]
        end
      end
      encoded = JSON.generate(response)
      connection.write("HTTP/1.1 #{status} #{status == 422 ? 'Unprocessable Entity' : 'OK'}\r\n" \
                       "Content-Type: application/json\r\nContent-Length: #{encoded.bytesize}\r\nConnection: close\r\n\r\n#{encoded}")
    rescue StandardError => error
      @mutex.synchronize { @state.fetch("errors") << "connection: #{error.class}: #{error.message}" }
    ensure
      connection&.close
    end

    def route(method, path, headers, raw, record)
      base = "/api/v1/qa"
      if method == "POST" && path == "#{base}/log"
        entries, files = parse_logs(headers, raw)
        record.merge!("body" => entries, "files" => files)
        if @fault && @fault.call(record, @state)
          record["injectedStatus"] = 503
          return [503, { "message" => "QA controlled delivery fault" }]
        end
        entries.each do |entry|
          launch = open_launch(entry.fetch("launchUuid"))
          owner = entry["itemUuid"] ? @state.fetch("items").fetch(entry.fetch("itemUuid")) : launch
          check(!owner["finish"], "log targets a closed item/launch")
          check(owner.equal?(launch) || owner.fetch("launchUuid") == launch.fetch("uuid"), "log crosses launch ownership")
          check(timestamp(entry.fetch("time")) >= timestamp(owner.fetch("startTime")), "log predates owner")
          level = entry.fetch("level")
          check(%w[TRACE DEBUG INFO WARN ERROR FATAL].include?(level.to_s.upcase) ||
                [5000, 10000, 20000, 30000, 40000, 50000].include?(level), "invalid log level")
          file = entry["file"] && files.find { |part| part.fetch("name") == entry.fetch("file").fetch("name") }
          check(!entry["file"] || file, "log file descriptor missing multipart bytes")
          @state.fetch("logs") << entry.merge("wireFile" => file, "sequence" => record.fetch("sequence"))
        end
        check(files.length == entries.count { |entry| entry["file"] }, "orphan/duplicate multipart file")
        return [200, { "responses" => entries.map { { "id" => SecureRandom.uuid } } }]
      end

      body = JSON.parse(raw)
      record["body"] = body
      if @fault && @fault.call(record, @state)
        record["injectedStatus"] = 503
        return [503, { "message" => "QA controlled finish fault" }]
      end
      if method == "POST" && path == "#{base}/launch"
        uuid = body.fetch("uuid")
        check(uuid.match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i), "launch UUID is not a UUID")
        check(!@state.fetch("launches").key?(uuid), "duplicate launch UUID")
        timestamp(body.fetch("startTime"))
        check(!body.fetch("name").empty?, "empty launch name")
        @state.fetch("launches")[uuid] = body.merge("startSequence" => record.fetch("sequence"))
        return [201, { "id" => uuid }]
      end
      if method == "POST" && (match = path.match(%r{\A#{base}/item(?:/([^/]+))?\z}))
        launch = open_launch(body.fetch("launchUuid"))
        uuid = body.fetch("uuid")
        check(uuid.match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i), "item UUID is not a UUID")
        check(!@state.fetch("items").key?(uuid), "duplicate item UUID")
        check(timestamp(body.fetch("startTime")) >= timestamp(launch.fetch("startTime")), "item predates launch")
        parent_uuid = match[1]
        check(parent_uuid == body["parentUuid"], "child URL differs from parentUuid")
        if parent_uuid
          parent = @state.fetch("items").fetch(parent_uuid)
          check(!parent["finish"], "child created after parent finish")
          check(parent.fetch("launchUuid") == launch.fetch("uuid"), "child crosses launches")
          check(timestamp(body.fetch("startTime")) >= timestamp(parent.fetch("startTime")), "child predates parent")
        end
        check(%w[SUITE STEP BEFORE_METHOD AFTER_METHOD BEFORE_CLASS AFTER_CLASS].include?(body.fetch("type")), "invalid RP item type")
        check([true, false].include?(body.fetch("hasStats")), "hasStats must be Boolean")
        check([true, false].include?(body.fetch("retry")), "retry must be Boolean")
        @state.fetch("items")[uuid] = body.merge("startSequence" => record.fetch("sequence"))
        return [201, { "id" => uuid }]
      end
      if method == "PUT" && (match = path.match(%r{\A#{base}/item/([^/]+)\z}))
        item = @state.fetch("items").fetch(match[1])
        finish(item, body, record)
        return [200, { "id" => match[1], "message" => "finished" }]
      end
      if method == "PUT" && (match = path.match(%r{\A#{base}/launch/([^/]+)/finish\z}))
        launch = open_launch(match[1])
        launch_items = @state.fetch("items").values.select { |item| item["launchUuid"] == match[1] }
        check(launch_items.all? { |item| item["finish"] }, "launch finished before items")
        check(launch_items.all? { |item| timestamp(item.fetch("finish").fetch("endTime")) <= timestamp(body.fetch("endTime")) }, "launch endTime predates item finish")
        finish(launch, body, record)
        return [200, { "id" => match[1], "message" => "finished" }]
      end
      raise "Unexpected RP route #{method} #{path}"
    end

    def finish(item, body, record)
      check(!item["finish"], "duplicate finish")
      check(body.fetch("launchUuid") == item.fetch("launchUuid"), "finish crosses launch ownership") if item["launchUuid"]
      check(STATUSES.include?(body.fetch("status").upcase), "invalid RP status")
      check(timestamp(body.fetch("endTime")) >= timestamp(item.fetch("startTime")), "finish predates start")
      children = @state.fetch("items").values.select { |child| child["parentUuid"] == item.fetch("uuid") }
      check(children.all? { |child| child["finish"] }, "parent finished with open children")
      check(children.all? { |child| timestamp(child.fetch("finish").fetch("endTime")) <= timestamp(body.fetch("endTime")) }, "parent endTime predates child finish")
      item["finish"] = body
      item["finishSequence"] = record.fetch("sequence")
    end

    def parse_logs(headers, raw)
      type = headers.fetch("content-type")
      return [[JSON.parse(raw)].flatten, []] if type.start_with?("application/json")

      boundary = type[/boundary="([^"]+)"/, 1] || type[/boundary=([^;\s]+)/, 1]
      check(type.start_with?("multipart/form-data") && boundary, "unsupported log encoding")
      parts = raw.split("--#{boundary}".b).filter_map do |part|
        next unless part.start_with?("\r\n") && part.end_with?("\r\n")

        head, bytes = part.byteslice(2, part.bytesize - 4).split("\r\n\r\n".b, 2)
        check(bytes, "malformed multipart part")
        disposition = head[/Content-Disposition:\s*([^\r\n]+)/i, 1].to_s
        { "name" => disposition[/\bname="([^"]+)"/, 1],
          "filename" => disposition[/\bfilename="([^"]+)"/, 1],
          "mime" => head[/Content-Type:\s*([^\r\n]+)/i, 1], "bytes" => bytes }
      end
      json = parts.select { |part| part["name"] == "json_request_part" }
      check(json.length == 1, "expected one json_request_part")
      entries = JSON.parse(json.first.fetch("bytes"))
      check(entries.is_a?(Array), "multipart log JSON must be an array")
      files = parts.select { |part| part["filename"] }.map do |part|
        { "name" => part.fetch("filename"), "partName" => part.fetch("name"), "mime" => part.fetch("mime"),
          "base64" => Base64.strict_encode64(part.fetch("bytes")) }
      end
      [entries, files]
    end

    def open_launch(uuid)
      launch = @state.fetch("launches").fetch(uuid)
      check(!launch["finish"], "request targets finished launch")
      launch
    end

    def timestamp(value)
      check(value.to_s.match?(/\A\d{13,}\z/), "timestamp must be Unix milliseconds")
      Integer(value)
    end

    def check(condition, message)
      raise message unless condition
    end
  end
end
