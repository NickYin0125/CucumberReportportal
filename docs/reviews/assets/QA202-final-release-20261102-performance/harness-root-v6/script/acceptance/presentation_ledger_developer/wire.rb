# frozen_string_literal: true

require "base64"
require "digest"
require "json"
require "net/http"
require "securerandom"
require "socket"
require "uri"

module LedgerDeveloper
  # A local wire stub offline, or a transparent live observer. Never records
  # headers except Content-Type, never authenticates except with RP_API_KEY.
  # Only UUIDs created through this instance can receive writes.
  class Wire
    attr_reader :endpoint, :records, :launches, :items

    def initialize(project:, upstream: nil)
      @project, @upstream = project, upstream && URI(upstream)
      if @upstream
        local = %w[localhost 127.0.0.1 ::1].include?(@upstream.hostname) || @upstream.hostname.to_s.end_with?(".localhost")
        raise "Only local RP endpoints without URL credentials/path/query are supported" unless local &&
          %w[http https].include?(@upstream.scheme) && !@upstream.userinfo && !@upstream.query && !@upstream.fragment && ["", "/"].include?(@upstream.path)
        raise "Live mode requires RP_API_KEY" if ENV["RP_API_KEY"].to_s.empty?
      end
      raise "Invalid project" unless project.match?(/\A[a-zA-Z0-9_-]+\z/)
      @records, @launches, @items, @threads = [], [], {}, []
      @mutex = Mutex.new
      @server = TCPServer.new("127.0.0.1", 0)
      @endpoint = "http://127.0.0.1:#{@server.addr[1]}"
      @acceptor = Thread.new do
        loop do
          socket = @server.accept
          @threads << Thread.new { serve(socket) }
        end
      rescue IOError, Errno::EBADF
        nil
      end
    end

    def close
      return if @closed
      @closed = true
      @server.close
      @acceptor.join
      @threads.each(&:join)
    end

    def self.multipart(body, content_type)
      boundary = content_type[/boundary=(?:"([^"]+)"|([^;\s]+))/, 1] || content_type[/boundary=([^;\s]+)/, 1]
      raise "Missing multipart boundary" unless boundary
      entries, files = [], []
      body.split("--#{boundary}".b).each do |part|
        header, bytes = part.delete_prefix("\r\n").split("\r\n\r\n", 2)
        next unless bytes
        bytes = bytes.delete_suffix("\r\n")
        if header.include?('name="json_request_part"')
          entries = JSON.parse(bytes)
        elsif (name = header[/filename="([^"]+)"/, 1])
          files << { name: name, mime: header[/Content-Type:\s*([^\r\n]+)/i, 1], bytes: bytes.bytesize,
                     sha256: Digest::SHA256.hexdigest(bytes), base64: Base64.strict_encode64(bytes) }
        end
      end
      [entries, files]
    end

    # Read-only retrieval of IDs and persisted evidence. No mutation/replay API.
    def snapshot
      return { persistence: "not_applicable_offline_stub", launch_uuids: @launches, item_uuids: @items.keys } unless @upstream
      launches = @launches.map { |id| get("launch/uuid/#{id}") }
      items = @items.keys.map { |id| get("item/uuid/#{id}") }
      logs = (items.flat_map { |item| pages("log?filter.eq.item=#{item.fetch('id')}") } +
              launches.flat_map { |launch| pages("log?filter.eq.launch=#{launch.fetch('id')}") }).uniq { |log| log.fetch("id") }
      files = logs.filter_map do |log|
        binary = log["binaryContent"]
        next unless binary
        code, type, bytes = upstream("GET", "/api/v1/data/#{@project}/#{binary.fetch('id')}", "", nil)
        raise "Attachment read failed HTTP #{code}" unless code == 200
        { log_id: log["id"], item_id: log["itemId"], binary: binary, content_type: type,
          bytes: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes), base64: Base64.strict_encode64(bytes) }
      end
      { persistence: "live_readback", launches: launches, items: items, logs: logs, files: files }
    end

    private

    def get(path)
      code, _, body = upstream("GET", "/api/v1/#{@project}/#{path}", "", nil)
      raise "RP read failed HTTP #{code}" unless code == 200
      JSON.parse(body)
    end

    def pages(path)
      page, rows = 1, []
      loop do
        data = get("#{path}&page.size=100&page.page=#{page}")
        rows.concat(data.fetch("content"))
        break if page >= data.fetch("page").fetch("totalPages")
        page += 1
      end
      rows
    end

    def upstream(method, path, body, type)
      uri = URI("#{@upstream.to_s.delete_suffix('/')}#{path}")
      request = Net::HTTP.const_get(method.capitalize).new(uri)
      request["Authorization"] = "Bearer #{ENV.fetch('RP_API_KEY')}"
      request["Content-Type"] = type if type
      request.body = body unless body.empty?
      response = Net::HTTP.start(uri.hostname, uri.port, nil, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 20) { |http| http.request(request) }
      [response.code.to_i, response["content-type"], response.body.to_s.b]
    end

    def allowed!(method, path, json, entries)
      raise "Unrelated API blocked" unless path.start_with?("/api/v1/#{@project}/")
      case [method, path.split("/")[4]]
      when ["POST", "launch"]
        raise "Existing/unrelated launch blocked" unless path == "/api/v1/#{@project}/launch" && json.fetch("name").start_with?("ledger-developer-") && !json["rerun"]
      when ["PUT", "launch"]
        raise "Unowned launch finish blocked" unless path.match?(%r{/launch/[^/]+/finish$}) && @launches.include?(path.split("/")[-2])
      when ["POST", "item"]
        parent = path.split("/item/", 2)[1] || json["parentUuid"]
        raise "Unowned parent/launch blocked" unless @launches.include?(json["launchUuid"]) && (!parent || @items[parent] == json["launchUuid"])
      when ["PUT", "item"]
        raise "Unowned item finish blocked" unless @items[path.split("/").last] && @items[path.split("/").last] == json["launchUuid"]
      when ["POST", "log"]
        raise "Empty logs blocked" unless entries.is_a?(Array) && !entries.empty?
        entries.each do |entry|
          raise "Unowned log blocked" unless @launches.include?(entry["launchUuid"]) && (!entry["itemUuid"] || @items[entry["itemUuid"]] == entry["launchUuid"])
        end
      else
        raise "Unsupported write blocked"
      end
    end

    def serve(socket)
      line = socket.gets("\r\n")
      return unless line
      method, path, = line.split(" ")
      headers = {}
      while (line = socket.gets("\r\n")) && line != "\r\n"
        key, value = line.split(":", 2)
        headers[key.downcase] = value.strip
      end
      raise "Chunked requests are unsupported" if headers["transfer-encoding"]
      body = socket.read(Integer(headers.fetch("content-length", "0"))).to_s.b
      type = headers["content-type"].to_s
      json = JSON.parse(body) if type.include?("application/json") && !body.empty?
      entries, files = type.include?("multipart/form-data") ? self.class.multipart(body, type) : [nil, []]
      entries ||= json.is_a?(Array) ? json : [json] if path.end_with?("/log")
      record = { method: method, path: path, content_type: type, request_bytes: body.bytesize,
                 request_sha256: Digest::SHA256.hexdigest(body), body_base64: Base64.strict_encode64(body),
                 json: json, entries: entries, files: files, offline_stub: !@upstream }
      # Serialize acceptance and ownership registration, not the SDK itself.
      @mutex.synchronize do
        @records << record
        allowed!(method, path, json, entries)
        code, response_type, response_body = if @upstream
                                             upstream(method, path, body, type)
                                           else
                                             payload = entries ? { "responses" => entries.map { { "id" => SecureRandom.uuid } } } :
                                               { "id" => SecureRandom.uuid, "message" => "offline stub" }
                                             [201, "application/json", JSON.generate(payload)]
                                           end
        response = JSON.parse(response_body) rescue nil
        record.merge!(status: code, response: response, response_content_type: response_type,
                      response_base64: Base64.strict_encode64(response_body))
        if (200..299).cover?(code) && method == "POST"
          @launches << response.fetch("id") if path.end_with?("/launch")
          @items[response.fetch("id")] = json.fetch("launchUuid") if path.match?(%r{/item(?:/[^/]+)?$})
        end
        socket.write("HTTP/1.1 #{code} Response\r\nContent-Type: #{response_type}\r\nContent-Length: #{response_body.bytesize}\r\nConnection: close\r\n\r\n")
        socket.write(response_body)
      end
    rescue StandardError => error
      # Class only: arbitrary exception text can contain connection credentials.
      @mutex.synchronize { @records << { observer_error: error.class.name } }
      socket.write("HTTP/1.1 500 Observer error\r\nContent-Length: 0\r\nConnection: close\r\n\r\n") rescue nil
    ensure
      socket.close
    end
  end
end
