# frozen_string_literal: true

require_relative "http"
require "securerandom"

module Day2Faults
  # Deliberately small real HTTP v1 sandbox, never a production API emulator.
  class Sandbox < HTTPServer
    def initialize(artifact_visibility_delay: 0, **options)
      @artifact_visibility_delay = artifact_visibility_delay
      @artifact_times = {}
      @state_mutex = Mutex.new
      @launches, @items, @logs, @requests, @binaries = {}, {}, [], [], {}
      super(**options)
    end

    def snapshot
      @state_mutex.synchronize do
        JSON.parse(JSON.generate(launches: @launches, items: @items, logs: @logs, requests: @requests))
      end
    end

    private

    def handle(socket, method, target, headers, stream)
      raw = stream.collect
      path = target.split("?", 2).first
      query = URI.decode_www_form(target.split("?", 2).last.to_s).to_h
      @state_mutex.synchronize do
        @requests << { method: method, path: path, bytes: raw.bytesize, sha256: Digest::SHA256.hexdigest(raw),
                       content_type: headers["content-type"], trace: headers["x-day2-trace"], query: target.split("?", 2)[1] }
        if path.end_with?("/log") && method == "POST"
          entries, files = parse_logs(raw, headers)
          return self.class.respond(socket, 400, { message: "unknown owner" }) unless entries.all? do |entry|
            @launches.key?(entry.fetch("launchUuid")) && (!entry["itemUuid"] || @items.key?(entry["itemUuid"]))
          end
          saved = entries.map do |entry|
            stored = entry.merge("id" => SecureRandom.uuid, "files" => files,
                                 "itemId" => entry["itemUuid"] && @items.fetch(entry["itemUuid"]).fetch("id"))
            artifact = files.find { |file| file[:name] == entry.dig("file", "name") }
            stored["binaryContent"] = { "id" => artifact.fetch(:sha256) } if artifact
            @artifact_times[stored.fetch("id")] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            stored
          end
          @logs.concat(saved)
          ack = headers["content-type"].include?("multipart") ? { responses: saved.map { |log| { id: log.fetch("id") } } } :
            { id: saved.first.fetch("id") }
          self.class.respond(socket, 201, ack, "X-Day2-Upstream" => "sandbox")
        elsif method == "GET" && path.include?("/uuid/")
          resource = path.include?("/launch/") ? @launches : @items
          self.class.respond(socket, resource.key?(path.split("/").last) ? 200 : 404,
                             resource[path.split("/").last] || { message: "not found" })
        elsif method == "GET" && path == "/api/info"
          self.class.respond(socket, 200, { build: { repo: "reportportal/service-api", version: "5.15.4" },
                                           extensions: { result: { "server.details.instance" => "sandbox-instance" } } })
        elsif method == "GET" && path.match?(%r{/api/v1/data/[^/]+/[^/]+\z})
          self.class.respond(socket, 200, @binaries.fetch(path.split("/").last), "Content-Type" => "image/png")
        elsif method == "GET" && path.end_with?("/log")
          entries = @logs.select { |log| log["itemId"].to_s == query.fetch("filter.eq.item") }
          entries = entries.map do |log|
            if Process.clock_gettime(Process::CLOCK_MONOTONIC) - @artifact_times.fetch(log.fetch("id")) < @artifact_visibility_delay
              log.reject { |key, _| key == "binaryContent" }
            else
              log
            end
          end
          self.class.respond(socket, 200, { content: entries })
        elsif method == "GET" && path.end_with?("/launch")
          launches = @launches.values.select { |launch| launch["name"] == query.fetch("filter.eq.name") }
          self.class.respond(socket, 200, { content: launches })
        elsif method == "GET" && path.end_with?("/item")
          items = @items.values.select { |item| item["launchId"].to_s == query.fetch("filter.eq.launchId") }
          self.class.respond(socket, 200, { content: items })
        elsif method == "GET"
          self.class.respond(socket, 200, "\x00\xffbinary\r\n".b, "Content-Type" => "application/octet-stream",
                             "X-Day2-Upstream" => "sandbox")
        else
          body = JSON.parse(raw)
          resource = path.include?("/launch") ? @launches : @items
          if method == "POST"
            uuid = body.fetch("uuid")
            resource[uuid] ||= body.merge("uuid" => uuid, "id" => resource.length + 1, "status" => "IN_PROGRESS")
            if resource.equal?(@items)
              resource[uuid]["launchId"] = @launches.fetch(body.fetch("launchUuid")).fetch("id")
            end
            self.class.respond(socket, 201, { id: uuid })
          else
            uuid = path.end_with?("/finish") ? path.split("/")[-2] : path.split("/").last
            resource.fetch(uuid).merge!(body).merge!("status" => body.fetch("status", "PASSED").upcase)
            self.class.respond(socket, 200, { message: "finished", id: uuid })
          end
        end
      end
    end

    def parse_logs(raw, headers)
      return [[JSON.parse(raw)], []] unless headers.fetch("content-type").include?("multipart")

      boundary = headers.fetch("content-type")[/boundary=(?:"([^"]+)"|([^;]+))/, 1] ||
        headers.fetch("content-type")[/boundary=([^;]+)/, 1]
      parts = raw.split("--#{boundary}".b).filter_map do |part|
        next unless part.start_with?("\r\n") && part.include?("\r\n\r\n")
        head, bytes = part.delete_prefix("\r\n").split("\r\n\r\n", 2)
        [head, bytes.delete_suffix("\r\n")]
      end
      json = parts.find { |head, _| head.include?('name="json_request_part"') }.last
      files = parts.filter_map do |head, bytes|
        name = head[/filename="([^"]+)"/, 1]
        next unless name
        sha = Digest::SHA256.hexdigest(bytes)
        @binaries[sha] = bytes
        { name: name, bytes: bytes.bytesize, sha256: sha }
      end
      [JSON.parse(json), files]
    end
  end
end
