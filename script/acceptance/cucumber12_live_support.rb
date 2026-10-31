# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "rbconfig"
require "rubygems/package"
require "securerandom"
require "shellwords"
require "socket"
require "stringio"
require "time"
require "timeout"
require "uri"
require "zlib"

module Cucumber12Live
  ROOT = File.expand_path("../..", __dir__)
  ENDPOINT = ENV.fetch("RP_ENDPOINT", "http://rp-2607.localhost:18080").delete_suffix("/")
  PROJECT = ENV.fetch("RP_PROJECT", "")
  CREDENTIAL_FILE = ENV["C12_CREDENTIAL_FILE"]
  SDK_HOME = ENV["C12_SDK_HOME"]
  CACHED_GEMS = ENV["C12_DEPENDENCIES"]
  BASELINE_GEM_SHA = "68b1ab8889f1e3448f6809b498c0aa7ff9ef9a03f4f1f5ae6d4e01fe2f6d17b3"
  GEM_SHA = (ENV["C12_PACKAGE_SHA256"] || ENV["C12_EXPECTED_SHA256"] || BASELINE_GEM_SHA).downcase
  RUBY = ENV.fetch("C12_RUBY", RbConfig.ruby)
  FIXTURES = File.join(__dir__, "cucumber12_live_features")
  PNG_SHA = Digest::SHA256.hexdigest(Base64.strict_decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nXxkAAAAASUVORK5CYII="))

  def self.now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def self.write(path, value)
    File.write(path, JSON.pretty_generate(value) + "\n")
  end

  def self.local_endpoint!(endpoint = ENDPOINT)
    uri = URI(endpoint)
    host = uri.hostname.to_s.downcase
    local = host == "localhost" || host.end_with?(".localhost") || host == "127.0.0.1" || host == "::1"
    raise "Live acceptance refuses non-local endpoints or URL credentials" unless local && %w[http https].include?(uri.scheme) && !uri.userinfo && !uri.query && !uri.fragment && ["", "/"].include?(uri.path)
    raise "Set RP_PROJECT explicitly" unless PROJECT.match?(/\A[a-zA-Z0-9_-]+\z/)
    uri
  end

  def self.preflight!
    local_endpoint!
    primary, legacy = ENV.values_at("C12_PACKAGE_SHA256", "C12_EXPECTED_SHA256")
    raise "Conflicting C12_PACKAGE_SHA256 and legacy C12_EXPECTED_SHA256" if primary && legacy && primary.downcase != legacy.downcase
    raise "C12_PACKAGE_SHA256 must contain exactly 64 hexadecimal characters" unless GEM_SHA.match?(/\A[0-9a-f]{64}\z/)
    raise "Set C12_SDK_HOME to the candidate's installed GEM_HOME" unless SDK_HOME && File.directory?(SDK_HOME)
    raise "Set C12_DEPENDENCIES to the cached dependency GEM_HOME" unless CACHED_GEMS && File.directory?(CACHED_GEMS)
    raise "C12_RUBY is not executable" unless File.executable?(RUBY)
    artifact = File.join(SDK_HOME, "cache/reportportal-cucumber-ruby-2.0.0.gem")
    raise "Wrong installed candidate package SHA256" unless File.file?(artifact) && Digest::SHA256.file(artifact).hexdigest == GEM_SHA
    Gem::Package.new(artifact).verify
    verified = []
    Gem::Package::TarReader.new(File.open(artifact, "rb")) do |archive|
      archive.each do |entry|
        next unless entry.full_name == "data.tar.gz"
        compressed = StringIO.new(entry.read)
        Gem::Package::TarReader.new(Zlib::GzipReader.new(compressed)) do |data|
          data.each do |file|
            next unless file.file? && file.full_name.start_with?("lib/") && file.full_name.end_with?(".rb")
            installed = File.join(SDK_HOME, "gems/reportportal-cucumber-ruby-2.0.0", file.full_name)
            raise "Installed candidate source differs from verified package" unless File.file?(installed) && Digest::SHA256.file(installed).hexdigest == Digest::SHA256.hexdigest(file.read)
            verified << file.full_name
          end
        end
      end
    end
    raise "Incomplete installed SDK library verification" unless verified.length == 37
    verified
  end

  def self.image_input!(path, mime:, name:)
    bytes = File.binread(path)
    actual = if bytes.start_with?("\x89PNG\r\n\x1a\n".b)
               "image/png"
             elsif bytes.start_with?("\xFF\xD8\xFF".b)
               "image/jpeg"
             end
    extension = File.extname(name).downcase
    matching_name = actual == "image/png" ? extension == ".png" : %w[.jpg .jpeg].include?(extension)
    raise "Capture bytes, declared MIME and filename extension must agree" unless actual && actual == mime && matching_name
    { "path" => File.expand_path(path), "mime" => mime, "name" => name,
      "bytes" => bytes.bytesize, "sha256" => Digest::SHA256.hexdigest(bytes) }
  end

  def self.token
    local_endpoint!
    supplied = ENV["RP_API_KEY"].to_s
    return supplied unless supplied.empty?
    raise "Supply RP_API_KEY, or explicitly set C12_CREDENTIAL_FILE for local acceptance" unless CREDENTIAL_FILE && File.file?(CREDENTIAL_FILE)
    raise "Credential file permissions must be 0600" unless File.stat(CREDENTIAL_FILE).mode & 0o777 == 0o600

    uri = URI(ENDPOINT + "/uat/sso/oauth/token")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth("ui", "uiman")
    request.set_form_data(grant_type: "password", username: "superadmin",
                          password: JSON.parse(File.read(CREDENTIAL_FILE)).fetch("RP_INITIAL_ADMIN_PASSWORD"))
    response = Net::HTTP.start(uri.host, uri.port, nil, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { |http| http.request(request) }
    raise "Authentication refused (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("access_token")
  end

  # A transparent local observer forwards actual bytes to the existing RP. It does
  # not stub acknowledgements, patch SDK methods, or record authentication headers.
  class Observer
    attr_reader :endpoint

    def initialize(directory)
      Cucumber12Live.local_endpoint!
      @directory = directory
      @mutex = Mutex.new
      @records = []
      @threads = []
      @launches = []
      @items = []
      @item_launches = {}
      @server = TCPServer.new("127.0.0.1", 0)
      @endpoint = "http://127.0.0.1:#{@server.addr[1]}"
      @acceptor = Thread.new do
        loop do
          socket = @server.accept
          @mutex.synchronize { @threads << Thread.new { serve(socket) } }
        end
      rescue IOError, Errno::EBADF
        nil
      end
    end

    def records
      @mutex.synchronize { Marshal.load(Marshal.dump(@records)) }
    end

    def close
      @server.close
      @acceptor.join(2)
      @threads.each { |thread| thread.join(2) }
      Cucumber12Live.write(File.join(@directory, "wire.json"), records)
    end

    private

    def serve(socket)
      while (line = socket.gets("\r\n"))
        method, path, = line.split(" ")
        headers = {}
        while (header = socket.gets("\r\n")) && header != "\r\n"
          name, value = header.split(":", 2)
          headers[name.downcase] = value.strip
        end
        raise "Unexpected chunked request" if headers.key?("transfer-encoding")

        json = entries = files = nil
        body = socket.read(headers.fetch("content-length", "0").to_i).to_s.b
        json = JSON.parse(body) if headers["content-type"].to_s.include?("application/json") && !body.empty?
        entries, files = multipart(body, headers.fetch("content-type")) if headers["content-type"].to_s.include?("multipart/form-data")
        entries ||= json.is_a?(Array) ? json : [json] if path.end_with?("/log")
        allowed!(method, path, json, entries: entries)
        record = { "method" => method, "path" => path, "started" => Cucumber12Live.now,
                   "actor" => headers.fetch("x-c12-actor", "worker"),
                   "content_type" => headers["content-type"], "request_bytes" => body.bytesize,
                   "request_sha256" => Digest::SHA256.hexdigest(body), "json" => json }
        if headers["content-type"].to_s.include?("multipart/form-data")
          record["body_base64"] = Base64.strict_encode64(body)
          record["entries"], record["files"] = entries, files
        elsif path.end_with?("/log")
          record["entries"] = json.is_a?(Array) ? json : [json]
        end
        @mutex.synchronize { record["sequence"] = @records.length + 1; @records << record }
        uri = URI(Cucumber12Live::ENDPOINT + path)
        request = Net::HTTP.const_get(method.capitalize).new(uri)
        %w[authorization accept content-type].each { |key| request[key] = headers[key] if headers[key] }
        request.body = body unless body.empty?
        response = Net::HTTP.start(uri.host, uri.port, nil, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 20) { |http| http.request(request) }
        response_body = response.body.to_s.b
        result = JSON.parse(response_body) rescue response_body.force_encoding("UTF-8")
        @mutex.synchronize do
          record["finished"] = Cucumber12Live.now
          record["status"] = response.code.to_i
          record["response"] = result
          if method == "POST" && path.end_with?("/launch") && response.is_a?(Net::HTTPSuccess)
            @launches << result.fetch("id")
          elsif method == "POST" && path.match?(%r{/item(?:/[^/]+)?$}) && response.is_a?(Net::HTTPSuccess)
            @items << result.fetch("id")
            @item_launches[result.fetch("id")] = json.fetch("launchUuid")
          end
        end
        socket.write("HTTP/1.1 #{response.code} #{response.message}\r\nContent-Type: #{response['content-type']}\r\nContent-Length: #{response_body.bytesize}\r\nConnection: keep-alive\r\n\r\n")
        socket.write(response_body)
      end
    rescue StandardError => error
      @mutex.synchronize { @records << { "observer_error" => error.class.name, "message" => error.message } }
    ensure
      socket.close
    end

    def allowed!(method, path, json, entries: nil)
      raise "Refusing unrelated API" unless path.start_with?("/api/v1/#{PROJECT}/", "/api/v2/#{PROJECT}/")
      return if method == "GET"
      if method == "POST" && path.end_with?("/launch")
        raise "Refusing non-acceptance launch" unless json.fetch("name").start_with?("c12-independent-C-")
      elsif method == "PUT" && path.match?(%r{/launch/([^/]+)/finish$})
        raise "Refusing unowned launch" unless @mutex.synchronize { @launches.include?(path.split("/")[-2]) }
      elsif method == "POST" && path.match?(%r{/item(?:/[^/]+)?$})
        raise "Refusing unowned item" unless @mutex.synchronize { @launches.include?(json.fetch("launchUuid")) }
        parent = path.split("/item/", 2)[1] || json["parentUuid"]
        raise "Refusing unowned parent" if parent && !@mutex.synchronize { @item_launches[parent] == json.fetch("launchUuid") }
      elsif method == "PUT" && path.match?(%r{/item/([^/]+)$})
        raise "Refusing unowned finish" unless @mutex.synchronize { @item_launches[path.split("/").last] == json.fetch("launchUuid") }
      elsif method == "POST" && path.end_with?("/log")
        raise "Refusing empty log batch" unless entries.is_a?(Array) && !entries.empty?
        entries.each do |entry|
          valid = entry.is_a?(Hash) && @mutex.synchronize do
            launch = entry["launchUuid"]
            @launches.include?(launch) && (!entry["itemUuid"] || @item_launches[entry["itemUuid"]] == launch)
          end
          raise "Refusing unowned log or media" unless valid
        end
      else
        raise "Refusing unsupported write"
      end
    end

    def multipart(body, type)
      boundary = type.split("boundary=", 2).last.delete('"')
      parts = body.split("--#{boundary}".b).filter_map do |part|
        next if part.empty? || part == "--\r\n" || part == "--"
        header, data = part.delete_prefix("\r\n").split("\r\n\r\n", 2)
        next unless data
        [header, data.delete_suffix("\r\n")]
      end
      json = parts.find { |header, _| header.include?('name="json_request_part"') }
      files = parts.filter_map do |header, data|
        filename = header[/filename="([^"]+)"/, 1]
        next unless filename
        { "name" => filename, "bytes" => data.bytesize, "sha256" => Digest::SHA256.hexdigest(data),
          "mime" => header[/Content-Type: ([^\r]+)/i, 1] }
      end
      [JSON.parse(json.fetch(1)), files]
    end
  end

  class Client
    attr_reader :queries

    def initialize(token, endpoint: ENDPOINT)
      Cucumber12Live.local_endpoint!(endpoint)
      @token, @endpoint, @queries = token, endpoint, []
    end

    def call(method, path, body = nil)
      uri = URI(@endpoint + path)
      request = Net::HTTP.const_get(method.capitalize).new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["X-C12-Actor"] = "orchestrator"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body) if body
      attempts = 0
      begin
        attempts += 1
        @http ||= Net::HTTP.start(uri.host, uri.port, nil, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 20)
        response = @http.request(request)
      rescue IOError, EOFError, Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout
        @http&.finish rescue nil
        @http = nil
        raise unless method == "GET" && attempts < 3
        sleep 0.2
        retry
      end
      result = if path.start_with?("/api/v1/data/")
                 { "bytes" => response.body.to_s.bytesize, "sha256" => Digest::SHA256.hexdigest(response.body.to_s.b),
                   "content_type" => response["content-type"] }
               elsif response["content-type"].to_s.include?("json")
                 JSON.parse(response.body)
               else
                 { "bytes" => response.body.to_s.bytesize, "sha256" => Digest::SHA256.hexdigest(response.body.to_s.b) }
               end
      @queries << { "method" => method, "path" => path, "status" => response.code.to_i,
                    "response" => result, "at" => Cucumber12Live.now }
      raise "RP #{method} #{path} HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      result
    end

    def get(path)
      call("GET", path.start_with?("/") ? path : "/api/v1/#{PROJECT}/#{path}")
    end

    def pages(path)
      all = []
      page = 1
      loop do
        result = get("#{path}#{path.include?('?') ? '&' : '?'}page.size=25&page.page=#{page}")
        all.concat(result.fetch("content"))
        break if page >= result.fetch("page").fetch("totalPages")
        page += 1
      end
      all
    end

    def snapshot(uuid, created_uuids)
      launch = get("launch/uuid/#{uuid}")
      items = created_uuids.map { |item| get("item/uuid/#{item}") }
      listed = pages("item?filter.eq.launchId=#{launch.fetch('id')}")
      nested = pages("item?filter.eq.launchId=#{launch.fetch('id')}&filter.eq.hasStats=false")
      logs = items.flat_map { |item| pages("log?filter.eq.item=#{item.fetch('id')}") }.uniq { |log| log.fetch("id") }
      logs = (logs + pages("log?filter.eq.launch=#{launch.fetch('id')}")).uniq { |log| log.fetch("id") }
      files = logs.filter_map do |log|
        next unless log["binaryContent"]
        digest = get("/api/v1/data/#{PROJECT}/#{log.fetch('binaryContent').fetch('id')}")
        digest.merge("logId" => log.fetch("id"), "itemId" => log.fetch("itemId"),
                     "mime" => log.fetch("binaryContent")["contentType"], "message" => log["message"])
      end
      { "launch" => launch, "items" => items, "listed_items" => listed, "nested_items" => nested,
        "logs" => logs, "downloaded_files" => files }
    end
  end
end
