# frozen_string_literal: true

require "mime/types"

module ReportportalCucumber
  module Transport
    # Helpers for building multipart/form-data request bodies.
    module MultipartHelper
      CONTENT_TYPE_PATTERN = %r{\A[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+(?:\s*;\s*[A-Za-z0-9!#$&^_.+-]+=[A-Za-z0-9!#$&^_.+:-]+)*\z}.freeze

      module_function

      # @param parts [Array<Hash>]
      # @param boundary [String]
      # @return [String]
      def encode(parts:, boundary:)
        normalized_parts = normalize_parts(parts)
        validate_alignment!(normalized_parts)

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

      # @param filename [String, nil]
      # @param declared_type [String, nil]
      # @return [String]
      def content_type_for(filename:, declared_type: nil)
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
        actual_files = parts.filter_map { |part| part[:filename] }
        return if referenced_files == actual_files

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
          body = part.fetch(:body)
          filename = part[:filename] ? safe_filename(part[:filename]) : nil
          {
            name: part.fetch(:name).to_s.gsub(/[\r\n]/, " ").strip,
            filename: filename,
            content_type: filename ? content_type_for(filename: filename, declared_type: part[:content_type]) : content_type_for(filename: nil, declared_type: part.fetch(:content_type, "text/plain")),
            body: body.is_a?(String) ? body.b : body.to_s.b
          }
        end
      end

      # @param buffer [String]
      # @param part [Hash]
      # @param boundary [String]
      # @return [void]
      def add_file_part(buffer:, part:, boundary:)
        disposition = %(form-data; name="#{quoted_parameter(part.fetch(:name))}"; filename="#{quoted_parameter(part.fetch(:filename))}")
        buffer << "--#{boundary}\r\n".b
        buffer << "Content-Disposition: #{disposition}\r\n".b
        buffer << "Content-Type: #{part.fetch(:content_type)}\r\n\r\n".b
        buffer << part.fetch(:body)
        buffer << "\r\n".b
      end

      # @param buffer [String]
      # @param part [Hash]
      # @param boundary [String]
      # @return [void]
      def add_form_part(buffer:, part:, boundary:)
        disposition = %(form-data; name="#{quoted_parameter(part.fetch(:name))}")
        buffer << "--#{boundary}\r\n".b
        buffer << "Content-Disposition: #{disposition}\r\n".b
        buffer << "Content-Type: #{part.fetch(:content_type)}\r\n\r\n".b
        buffer << part.fetch(:body)
        buffer << "\r\n".b
      end

      # @param value [String]
      # @return [String]
      def quoted_parameter(value)
        value.to_s.gsub(/[\r\n]/, " ").gsub("\\", "\\\\\\").gsub('"', '\"')
      end
    end
  end
end
