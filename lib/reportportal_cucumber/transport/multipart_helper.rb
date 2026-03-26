# frozen_string_literal: true

require "mime/types"

module ReportportalCucumber
  module Transport
    # Helpers for building multipart/form-data request bodies.
    module MultipartHelper
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
        return declared_type.to_s unless declared_type.to_s.strip.empty?

        detected = MIME::Types.type_for(filename.to_s).first
        detected&.content_type || "application/octet-stream"
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
        filename = name.to_s.strip
        filename = fallback if filename.empty?
        return filename unless File.extname(filename).empty?

        detected = MIME::Types[content_type.to_s].first
        extension = detected&.preferred_extension
        extension.to_s.empty? ? filename : "#{filename}.#{extension}"
      end

      # @param parts [Array<Hash>]
      # @return [Array<Hash>]
      def normalize_parts(parts)
        Array(parts).map do |part|
          body = part.fetch(:body)
          filename = part[:filename]&.to_s
          {
            name: part.fetch(:name).to_s,
            filename: filename,
            content_type: filename ? content_type_for(filename: filename, declared_type: part[:content_type]) : part.fetch(:content_type, "text/plain"),
            body: body.is_a?(String) ? body.b : body.to_s.b
          }
        end
      end

      # @param buffer [String]
      # @param part [Hash]
      # @param boundary [String]
      # @return [void]
      def add_file_part(buffer:, part:, boundary:)
        disposition = %(form-data; name="#{part.fetch(:name)}"; filename="#{part.fetch(:filename)}")
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
        disposition = %(form-data; name="#{part.fetch(:name)}")
        buffer << "--#{boundary}\r\n".b
        buffer << "Content-Disposition: #{disposition}\r\n".b
        buffer << "Content-Type: #{part.fetch(:content_type)}\r\n\r\n".b
        buffer << part.fetch(:body)
        buffer << "\r\n".b
      end
    end
  end
end
