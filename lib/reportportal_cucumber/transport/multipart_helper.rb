# frozen_string_literal: true

require "mime/types"
require "tempfile"

module ReportportalCucumber
  module Transport
    # Helpers for building multipart/form-data request bodies.
    module MultipartHelper
      CONTENT_TYPE_PATTERN = %r{\A[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+(?:\s*;\s*[A-Za-z0-9!#$&^_.+-]+=[A-Za-z0-9!#$&^_.+:-]+)*\z}.freeze
      FILE_CHUNK_SIZE = 1024 * 1024
      BodySource = Struct.new(:body, :stream, :length, :tempfile, keyword_init: true)

      class SizeLimitError < ArgumentError
        # @param message [String]
        # @return [void]
        def initialize(message = "ReportPortal log request exceeds configured byte limit")
          super(message)
        end
      end

      class CountLimitError < SizeLimitError
        # @return [void]
        def initialize
          super("ReportPortal log batch exceeds configured count limit")
        end
      end

      module_function

      # @param parts [Array<Hash>]
      # @param boundary [String]
      # @return [String]
      def encode(parts:, boundary:)
        normalized_parts = normalize_parts(parts)
        validate_alignment!(normalized_parts)
        raise ArgumentError, "Path-backed multipart parts require streaming body construction" if streaming_required?(normalized_parts)

        buffer = String.new(capacity: 1024, encoding: Encoding::BINARY)
        normalized_parts.each do |part|
          if part[:filename]
            add_file_part(buffer: buffer, part: part, boundary: boundary)
          else
            add_form_part(buffer: buffer, part: part, boundary: boundary)
          end
        end
        buffer << "--#{boundary}--\r\n".b
        buffer
      end

      # @param entries [Array<Hash>]
      # @param files [Array<Hash>]
      # @return [Integer]
      def log_batch_bytes(entries:, files:)
        return JSON.generate(entries.first).bytesize if files.empty? && entries.length == 1

        parts = [{ name: "json_request_part", content_type: "application/json", body: JSON.generate(entries) }]
        Array(files).each do |file|
          part = { name: "file", filename: file.fetch(:name), content_type: file.fetch(:mime) }
          file[:path] ? part[:path] = file.fetch(:path) : part[:body] = file.fetch(:bytes)
          parts << part
        end
        encoded_length(parts: parts, boundary: standard_boundary)
      end

      # @param parts [Array<Hash>]
      # @param boundary [String]
      # @return [Integer]
      def encoded_length(parts:, boundary:)
        normalized_parts = normalize_parts(parts)
        validate_alignment!(normalized_parts)
        encoded_length_normalized(normalized_parts, boundary)
      end

      # @return [String]
      def standard_boundary
        "----rp#{SecureRandom.hex(12)}"
      end

      # @param filename [String, nil]
      # @param declared_type [String, nil]
      # @return [String]
      def content_type_for(filename:, declared_type: nil)
        forced = forced_content_type_for(filename)
        return forced if forced

        declared = declared_type.to_s.strip
        return declared if valid_content_type?(declared)

        safe_declared = declared.split(/[\r\n]/).first.to_s.strip
        return safe_declared if valid_content_type?(safe_declared)

        detected = preferred_mime_type(filename)
        detected&.content_type || "application/octet-stream"
      end

      # @param filename [String, nil]
      # @return [MIME::Type, nil]
      def preferred_mime_type(filename)
        candidates = MIME::Types.type_for(filename.to_s)
        preferred_prefix =
          case File.extname(filename.to_s).downcase
          when ".mp4", ".m4v", ".mov", ".webm"
            "video/"
          end
        return candidates.find { |type| type.content_type.start_with?(preferred_prefix) } if preferred_prefix

        candidates.first
      end

      # @param filename [String, nil]
      # @return [String, nil]
      def forced_content_type_for(filename)
        case File.extname(filename.to_s).downcase
        when ".mp4", ".m4v"
          "video/mp4"
        when ".mov"
          "video/quicktime"
        when ".webm"
          "video/webm"
        end
      end

      # @param value [String]
      # @return [Boolean]
      def valid_content_type?(value)
        !value.empty? && !value.match?(/[\r\n]/) && value.match?(CONTENT_TYPE_PATTERN)
      end

      # @param parts [Array<Hash>]
      # @return [void]
      def validate_alignment!(parts)
        json_part = parts.find { |part| part[:name] == "json_request_part" }
        return unless json_part

        entries =
          case json_part[:body]
          when Array
            json_part[:body]
          else
            JSON.parse(json_part[:body].to_s)
          end

        referenced_files = Array(entries).filter_map do |entry|
          hash = entry.respond_to?(:to_h) ? entry.to_h : entry
          hash.dig("file", "name") || hash.dig(:file, :name)
        end
        actual_files = parts.filter_map { |part| safe_filename(part[:filename]) if part[:filename] }
        return if referenced_files == actual_files && actual_files.uniq.length == actual_files.length

        raise ArgumentError, "Multipart log payload mismatch between json_request_part and file parts"
      rescue JSON::ParserError => error
        raise ArgumentError, "Invalid json_request_part for multipart payload: #{error.message}"
      end

      # @param name [String]
      # @param content_type [String]
      # @param fallback [String]
      # @return [String]
      def ensure_filename_extension(name:, content_type:, fallback: "attachment")
        filename = safe_filename(name)
        filename = fallback if filename.empty?
        return filename unless File.extname(filename).empty?

        detected = MIME::Types[content_type.to_s].first
        extension = detected&.preferred_extension
        extension.to_s.empty? ? filename : "#{filename}.#{extension}"
      end

      # @param value [String, nil]
      # @return [String]
      def safe_filename(value)
        candidate = value.to_s.tr("\\", "/")
        name = File.basename(candidate).gsub(/[\r\n]+/, " ")
        name = name.gsub(/[[:cntrl:];]/, "_").gsub(/\s+/, " ").strip
        return "attachment" if name.empty? || name == "." || name == ".."

        name
      end

      # @param parts [Array<Hash>]
      # @return [Array<Hash>]
      def normalize_parts(parts)
        Array(parts).map do |part|
          path = part[:path] || part[:file_path]
          body = part[:body]
          filename = part[:filename] ? safe_filename(part[:filename]) : nil
          path = normalize_file_path(path) if path
          {
            name: part.fetch(:name).to_s.gsub(/[\r\n]/, " ").strip,
            filename: filename,
            content_type: filename ? content_type_for(filename: filename, declared_type: part[:content_type]) : content_type_for(filename: nil, declared_type: part.fetch(:content_type, "text/plain")),
            body: path ? nil : normalize_body(body),
            path: path
          }.compact
        end
      end

      # @param parts [Array<Hash>]
      # @return [Boolean]
      def streaming_required?(parts)
        Array(parts).any? { |part| part[:path] }
      end

      # @param parts [Array<Hash>]
      # @param boundary [String]
      # @param max_bytes [Integer, nil]
      # @return [BodySource]
      def body_source(parts:, boundary:, max_bytes: nil)
        normalized_parts = normalize_parts(parts)
        validate_alignment!(normalized_parts)
        expected_length = encoded_length_normalized(normalized_parts, boundary)
        raise SizeLimitError if max_bytes && expected_length > max_bytes

        unless streaming_required?(normalized_parts)
          body = encode_normalized(normalized_parts, boundary)
          raise SizeLimitError if max_bytes && body.bytesize > max_bytes

          return BodySource.new(body: body, length: nil)
        end

        tempfile = Tempfile.new(["reportportal-multipart", ".body"])
        tempfile.binmode
        write_parts(io: tempfile, parts: normalized_parts, boundary: boundary, max_bytes: max_bytes)
        tempfile.flush
        raise SizeLimitError if max_bytes && tempfile.size > max_bytes

        tempfile.rewind
        BodySource.new(stream: tempfile, length: tempfile.size, tempfile: tempfile)
      rescue StandardError
        tempfile&.close!
        raise
      end

      # @param buffer [String]
      # @param part [Hash]
      # @param boundary [String]
      # @return [void]
      def add_file_part(buffer:, part:, boundary:)
        buffer << part_header(part, boundary)
        buffer << part.fetch(:body)
        buffer << "\r\n".b
      end

      # @param buffer [String]
      # @param part [Hash]
      # @param boundary [String]
      # @return [void]
      def add_form_part(buffer:, part:, boundary:)
        buffer << part_header(part, boundary)
        buffer << part.fetch(:body)
        buffer << "\r\n".b
      end

      # @param parts [Array<Hash>]
      # @param boundary [String]
      # @return [String]
      def encode_normalized(parts, boundary)
        buffer = String.new(capacity: 1024, encoding: Encoding::BINARY)
        write_parts(io: buffer, parts: parts, boundary: boundary)
        buffer
      end

      # @param io [#<<, #write]
      # @param parts [Array<Hash>]
      # @param boundary [String]
      # @return [void]
      def write_parts(io:, parts:, boundary:, max_bytes: nil)
        parts.each do |part|
          if part[:filename]
            write_file_part(io: io, part: part, boundary: boundary, max_bytes: max_bytes)
          else
            write_form_part(io: io, part: part, boundary: boundary, max_bytes: max_bytes)
          end
        end
        write_bytes(io, "--#{boundary}--\r\n".b, max_bytes: max_bytes)
      end

      # @param io [#<<, #write]
      # @param part [Hash]
      # @param boundary [String]
      # @return [void]
      def write_file_part(io:, part:, boundary:, max_bytes: nil)
        write_bytes(io, part_header(part, boundary), max_bytes: max_bytes)
        if part[:path]
          File.open(part.fetch(:path), "rb") do |file|
            if max_bytes
              while (chunk = file.read([FILE_CHUNK_SIZE, max_bytes - io.pos + 1].min))
                raise SizeLimitError if chunk.bytesize > max_bytes - io.pos

                write_bytes(io, chunk, max_bytes: max_bytes)
              end
            else
              IO.copy_stream(file, io)
            end
          end
        else
          write_bytes(io, part.fetch(:body), max_bytes: max_bytes)
        end
        write_bytes(io, "\r\n".b, max_bytes: max_bytes)
      end

      # @param io [#<<, #write]
      # @param part [Hash]
      # @param boundary [String]
      # @return [void]
      def write_form_part(io:, part:, boundary:, max_bytes: nil)
        write_bytes(io, part_header(part, boundary), max_bytes: max_bytes)
        write_bytes(io, part.fetch(:body), max_bytes: max_bytes)
        write_bytes(io, "\r\n".b, max_bytes: max_bytes)
      end

      # @param io [#<<, #write]
      # @param bytes [String]
      # @return [void]
      def write_bytes(io, bytes, max_bytes: nil)
        raise SizeLimitError if max_bytes && io.pos + bytes.bytesize > max_bytes

        io.respond_to?(:write) ? io.write(bytes) : io << bytes
      end

      # @param part [Hash]
      # @param boundary [String]
      # @return [String]
      def part_header(part, boundary)
        disposition = %(form-data; name="#{quoted_parameter(part.fetch(:name))}")
        disposition += %(; filename="#{quoted_parameter(part.fetch(:filename))}") if part[:filename]
        "--#{boundary}\r\nContent-Disposition: #{disposition}\r\nContent-Type: #{part.fetch(:content_type)}\r\n\r\n".b
      end

      # @param parts [Array<Hash>]
      # @param boundary [String]
      # @return [Integer]
      def encoded_length_normalized(parts, boundary)
        parts.sum do |part|
          part_header(part, boundary).bytesize +
            (part[:path] ? File.size(part.fetch(:path)) : part.fetch(:body).bytesize) + 2
        end + "--#{boundary}--\r\n".b.bytesize
      end

      # @param body [Object]
      # @return [String]
      def normalize_body(body)
        body.is_a?(String) ? body.b : body.to_s.b
      end

      # @param path [String]
      # @return [String]
      def normalize_file_path(path)
        expanded = File.expand_path(path.to_s)
        raise ArgumentError, "Multipart file does not exist: #{expanded}" unless File.file?(expanded)
        raise ArgumentError, "Multipart file is not readable: #{expanded}" unless File.readable?(expanded)

        expanded
      end

      # @param value [String]
      # @return [String]
      def quoted_parameter(value)
        value.to_s.gsub(/[\r\n]/, " ").gsub("\\", "\\\\\\").gsub('"', '\"')
      end
    end
  end
end
