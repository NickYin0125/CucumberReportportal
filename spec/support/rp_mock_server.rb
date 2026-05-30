# frozen_string_literal: true

require "cgi"

module ReportportalCucumber
  module SpecSupport
    # Stateful WebMock-backed ReportPortal v1 API sandbox.
    class RPMockServer
      attr_reader :endpoint, :launches, :items, :logs, :multipart_requests

      # @param endpoint [String]
      def initialize(endpoint: "https://rp-mock.example.com")
        @endpoint = endpoint.sub(%r{/+\z}, "")
        reset!
      end

      # @return [void]
      def reset!
        @launches = {}
        @items = {}
        @logs = []
        @multipart_requests = []
        @sequence = 0
      end

      # @return [self]
      def install!
        stub_launch_routes
        stub_item_routes
        stub_log_routes
        stub_query_routes
        self
      end

      private

      # @return [void]
      def stub_launch_routes
        WebMock.stub_request(:post, %r{\A#{Regexp.escape(endpoint)}/(?:api/)?v1/([^/]+)/launch\z}).to_return do |request|
          project = request.uri.path.split("/")[-2]
          body = parse_json(request.body)
          uuid = body["uuid"] || next_uuid("launch")
          @launches[uuid] ||= {
            "id" => next_id,
            "uuid" => uuid,
            "project" => project,
            "name" => body.fetch("name"),
            "description" => body["description"].to_s,
            "attributes" => Array(body["attributes"]),
            "startTime" => body.fetch("startTime"),
            "status" => "IN_PROGRESS",
            "items" => []
          }
          json_response(201, "id" => uuid)
        end

        WebMock.stub_request(:put, %r{\A#{Regexp.escape(endpoint)}/(?:api/)?v1/([^/]+)/launch/([^/]+)/finish\z}).to_return do |request|
          launch_uuid = request.uri.path.split("/")[-2]
          body = parse_json(request.body)
          launch = @launches.fetch(launch_uuid)
          leaf_items = @items.values.select { |item| item["launchUuid"] == launch_uuid && item["hasStats"] == true }
          status = body["status"] || bubble_status(leaf_items)
          launch.merge!(
            "endTime" => body.fetch("endTime"),
            "status" => status.upcase,
            "statistics" => statistics_for(leaf_items)
          )
          json_response(200, "message" => "Launch finished", "id" => launch_uuid)
        end
      end

      # @return [void]
      def stub_item_routes
        WebMock.stub_request(:post, %r{\A#{Regexp.escape(endpoint)}/(?:api/)?v1/([^/]+)/item(?:/([^/]+))?\z}).to_return do |request|
          body = parse_json(request.body)
          parent_uuid = request.uri.path.split("/").last == "item" ? body["parentUuid"] : request.uri.path.split("/").last
          launch = @launches.fetch(body.fetch("launchUuid"))
          uuid = body["uuid"] || next_uuid("item")
          @items[uuid] ||= body.merge(
            "id" => next_id,
            "uuid" => uuid,
            "parentUuid" => parent_uuid,
            "status" => "IN_PROGRESS"
          )
          launch["items"] << uuid unless launch["items"].include?(uuid)
          json_response(201, "id" => uuid)
        end

        WebMock.stub_request(:put, %r{\A#{Regexp.escape(endpoint)}/(?:api/)?v1/([^/]+)/item/([^/]+)\z}).to_return do |request|
          item_uuid = request.uri.path.split("/").last
          body = parse_json(request.body)
          item = @items.fetch(item_uuid)
          item.merge!(
            "endTime" => body.fetch("endTime"),
            "status" => body["status"].to_s.empty? ? "passed" : body["status"]
          )
          bubble_item_status(item)
          json_response(200, "message" => "Item finished", "id" => item_uuid)
        end
      end

      # @return [void]
      def stub_log_routes
        WebMock.stub_request(:post, %r{\A#{Regexp.escape(endpoint)}/(?:api/)?v1/([^/]+)/log\z}).to_return do |request|
          if request.headers.fetch("Content-Type", "").include?("multipart/form-data")
            payload = parse_multipart(request)
            @multipart_requests << payload
            entries = payload.fetch(:entries)
            files = payload.fetch(:files)
            referenced_files = entries.filter_map { |entry| entry.dig("file", "name") }
            actual_files = files.map { |file| file.fetch(:filename) }
            return json_response(400, "errorCode" => 40035, "message" => "Multipart file mismatch") unless referenced_files == actual_files

            entries.each { |entry| store_log(entry) }
            json_response(201, "responses" => entries.map { |_entry| { "id" => next_uuid("log") } })
          else
            entry = parse_json(request.body)
            store_log(entry)
            json_response(201, "id" => next_uuid("log"))
          end
        end
      end

      # @return [void]
      def stub_query_routes
        WebMock.stub_request(:get, %r{\A#{Regexp.escape(endpoint)}/(?:api/)?v1/project/([^/]+)/launch/([^/?]+)}).to_return do |request|
          launch_uuid = request.uri.path.split("/").last
          json_response(200, @launches.fetch(launch_uuid))
        end

        WebMock.stub_request(:get, %r{\A#{Regexp.escape(endpoint)}/(?:api/)?v1/([^/]+)/launch/([^/?]+)}).to_return do |request|
          launch_uuid = request.uri.path.split("/").last
          json_response(200, @launches.fetch(launch_uuid))
        end
      end

      # @param request [WebMock::RequestSignature]
      # @return [Hash]
      def parse_multipart(request)
        boundary = request.headers.fetch("Content-Type").match(/boundary=([^;]+)/)[1]
        parts = request.body.split("--#{boundary}").filter_map do |raw_part|
          part = raw_part.sub(/\A\r\n/, "").sub(/\r\n\z/, "")
          next if part.empty? || part == "--"

          headers, body = part.split("\r\n\r\n", 2)
          header_lines = headers.to_s.split("\r\n")
          disposition = header_lines.find { |line| line.start_with?("Content-Disposition:") }.to_s
          content_type = header_lines.find { |line| line.start_with?("Content-Type:") }.to_s.split(":", 2).last.to_s.strip
          {
            name: disposition[/name="((?:\\"|[^"])*)"/, 1].to_s.gsub('\"', '"'),
            filename: disposition[/filename="((?:\\"|[^"])*)"/, 1]&.gsub('\"', '"'),
            content_type: content_type,
            body: body.to_s
          }
        end

        json_part = parts.find { |part| part[:name] == "json_request_part" }
        {
          entries: JSON.parse(json_part.fetch(:body)),
          files: parts.select { |part| part[:filename] }.map do |part|
            {
              filename: part.fetch(:filename),
              content_type: part.fetch(:content_type),
              bytes: part.fetch(:body)
            }
          end
        }
      end

      # @param entry [Hash]
      # @return [void]
      def store_log(entry)
        item_uuid = entry["itemUuid"]
        raise KeyError, "unknown item #{item_uuid}" if item_uuid && !@items.key?(item_uuid)

        @logs << entry.merge("id" => next_id)
      end

      # @param item [Hash]
      # @return [void]
      def bubble_item_status(item)
        return unless item["status"].to_s.downcase == "failed"

        parent_uuid = item["parentUuid"]
        while parent_uuid && @items[parent_uuid]
          @items[parent_uuid]["status"] = "failed"
          parent_uuid = @items[parent_uuid]["parentUuid"]
        end
      end

      # @param items [Array<Hash>]
      # @return [String]
      def bubble_status(items)
        statuses = items.map { |item| item["status"].to_s.downcase }
        return "FAILED" if statuses.include?("failed")
        return "SKIPPED" if statuses.include?("skipped")

        "PASSED"
      end

      # @param items [Array<Hash>]
      # @return [Hash]
      def statistics_for(items)
        executions = Hash.new(0)
        items.each { |item| executions[item["status"].to_s.downcase] += 1 }
        executions["total"] = items.length
        { "executions" => executions }
      end

      # @param body [String]
      # @return [Hash]
      def parse_json(body)
        JSON.parse(body.to_s)
      end

      # @param status [Integer]
      # @param body [Hash]
      # @return [Hash]
      def json_response(status, body)
        {
          status: status,
          headers: { "Content-Type" => "application/json" },
          body: JSON.generate(body)
        }
      end

      # @param prefix [String]
      # @return [String]
      def next_uuid(prefix)
        "#{prefix}-#{next_id}"
      end

      # @return [Integer]
      def next_id
        @sequence += 1
      end
    end
  end
end
