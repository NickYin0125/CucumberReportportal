# frozen_string_literal: true

require "net/http"
require "json"
require "digest"
require_relative "support"

module Day2Endurance
  class << self
    attr_accessor :wire_observer
  end

  class WireObserver
    class Capture
      attr_reader :bytes, :digest, :body

      def initialize(limit)
        @limit, @bytes = limit, 0
        @digest, @body = Digest::SHA256.new, +"".b
      end

      def add(chunk)
        return unless chunk
        @bytes += chunk.bytesize
        @digest.update(chunk)
        room = @limit + 1 - @body.bytesize
        @body << chunk.byteslice(0, room) if room.positive?
      end
    end

    # No to_io: IO.copy_stream must consume this counted reader, not bypass it.
    class CountedStream
      def initialize(source, capture)
        @source, @capture = source, capture
      end

      def read(*arguments)
        chunk = @source.read(*arguments)
        @capture.add(chunk)
        chunk
      end
    end

    attr_reader :records, :max_bytes, :max_entries

    def initialize(endpoint:, project:, directory:, max_bytes:, max_entries:)
      @target = URI.join(endpoint + "/", "api/v1/#{project}/log")
      @directory, @max_bytes, @max_entries = directory, max_bytes, max_entries
      @records, @mutex = [], Mutex.new
    end

    def matches?(http, request)
      http.address == @target.host && http.port == @target.port && request.method == "POST" && request.path.split("?", 2).first == @target.path
    end

    def entries_in(body, content_type)
      if content_type.start_with?("multipart/form-data")
        boundary = content_type.match(/boundary=(?:"([^"]+)"|([^;\s]+))/)&.captures&.compact&.first
        raise "Missing multipart boundary" unless boundary
        pieces = body.split("--#{boundary}")
        json = pieces.filter_map do |piece|
          headers, data = piece.split("\r\n\r\n", 2)
          data&.delete_suffix("\r\n") if headers.to_s.include?('name="json_request_part"')
        end
        raise "Expected exactly one serialized JSON part" unless json.size == 1
        entries = JSON.parse(json.first)
      else
        entries = JSON.parse(body)
      end
      entries = [entries] if entries.is_a?(Hash)
      raise "Invalid serialized log entries" unless entries.is_a?(Array) && !entries.empty? && entries.all? { |entry| entry.is_a?(Hash) }
      entries
    end

    def observe(request, supplied_body = nil)
      capture = Capture.new(max_bytes)
      original_stream = request.body_stream
      streamed = !original_stream.nil?
      response, transport_error = nil, nil
      if streamed
        request.body_stream = CountedStream.new(original_stream, capture)
      else
        capture.add(supplied_body || request.body || "".b)
      end
      begin
        response = yield
        response
      rescue Exception => error
        transport_error = error.class.name
        raise
      ensure
        request.body_stream = original_stream if streamed
        count, owners, parse_error = nil, [], nil
        begin
          entries = entries_in(capture.body, request["Content-Type"].to_s)
          count = entries.size
          owners = entries.map { |entry| entry["itemUuid"] }.compact
        rescue StandardError => error
          parse_error = error.class.name
        end
        row = { elapsed_seconds: Day2Endurance.session&.elapsed, body_bytes: capture.bytes,
                serialized_entries: count, body_sha256: capture.digest.hexdigest, streamed: streamed,
                content_length: request["Content-Length"]&.to_i, status: response&.code&.to_i,
                owner_uuids: owners, parse_error: parse_error, transport_error: transport_error,
                effective_max_body_bytes: max_bytes, effective_max_entries: max_entries }
        @mutex.synchronize do
          records << row
          File.open(File.join(@directory, "wire.ndjson"), "a", 0o600) { |file| file.puts(JSON.generate(row)) }
        end
      end
    end

    def summary
      rows = @mutex.synchronize { records.dup }
      { request_count: rows.size, streamed_requests: rows.count { |row| row[:streamed] },
        observed_max_body_bytes: rows.map { |row| row[:body_bytes] }.max,
        observed_max_entries: rows.filter_map { |row| row[:serialized_entries] }.max,
        observed_total_entries: rows.sum { |row| row[:serialized_entries].to_i },
        observed_total_body_bytes: rows.sum { |row| row[:body_bytes] },
        effective_max_body_bytes: max_bytes, effective_max_entries: max_entries,
        transport_errors: rows.count { |row| row[:transport_error] },
        scope: "Actual serialized HTTP entity bytes including multipart framing; HTTP headers excluded from SDK body limit" }
    end

    def validate!(receipt:, sent_batches:)
      rows = @mutex.synchronize { records.dup }
      Day2Endurance.check("actual upload requests observed", !rows.empty?)
      Day2Endurance.check("actual upload body byte bound", rows.all? { |row| row[:body_bytes] <= max_bytes })
      Day2Endurance.check("actual serialized batch entry bound", rows.all? { |row| row[:serialized_entries] && row[:serialized_entries].between?(1, max_entries) })
      Day2Endurance.check("actual upload transport completed", rows.all? { |row| !row[:transport_error] && !row[:parse_error] && row[:status]&.between?(200, 299) })
      Day2Endurance.check("actual uploaded content length", rows.all? { |row| row[:content_length] == row[:body_bytes] })
      Day2Endurance.check("wire request count matches sent batches", rows.size == sent_batches)
      Day2Endurance.check("wire entries match confirmed receipt", rows.sum { |row| row[:serialized_entries] } == receipt.fetch(:confirmed))
      Day2Endurance.check("actual CSV stream observed", rows.any? { |row| row[:streamed] })
      summary
    end
  end

  module WireHook
    def request(request, body = nil, &block)
      previous = Thread.current[:day2_wire_observing]
      observer = Day2Endurance.wire_observer
      return super unless observer && !previous && observer.matches?(self, request)
      Thread.current[:day2_wire_observing] = true
      observer.observe(request, body) { super }
    ensure
      Thread.current[:day2_wire_observing] = previous
    end
  end

  Net::HTTP.prepend(WireHook) unless Net::HTTP.ancestors.include?(WireHook)
end
