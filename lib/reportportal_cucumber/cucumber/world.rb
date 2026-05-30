# frozen_string_literal: true

module ReportportalCucumber
  module Cucumber
    # World DSL exposed to step definitions.
    module World
      # @param message [String]
      # @param level [String, Symbol]
      # @param attachment [Hash, nil]
      # @param timestamp [Time]
      # @return [void]
      def rp_log(message, level: :info, attachment: nil, timestamp: Time.now)
        runtime = ReportportalCucumber.current_runtime
        return unless runtime

        runtime.emit_world_log(message: message, level: level, timestamp: timestamp, attachment: attachment)
      end

      # @param io_or_bytes [#read, String]
      # @param name [String, nil]
      # @param mime [String, nil]
      # @param mime_type [String, nil]
      # @param message [String, nil]
      # @param level [String, Symbol]
      # @return [void]
      def rp_attach(io_or_bytes, name: nil, mime: nil, mime_type: nil, message: nil, level: :info)
        runtime = ReportportalCucumber.current_runtime
        return unless runtime

        attachment = build_attachment_payload(io_or_bytes, name: name, mime: mime_type || mime)

        runtime.emit_world_attachment(
          message: message || "Attachment: #{attachment.fetch(:name)}",
          level: level,
          timestamp: Time.now,
          attachment: attachment
        )
      end

      # @param name [String]
      # @yieldreturn [Object]
      # @return [Object]
      def rp_step(name, &block)
        runtime = ReportportalCucumber.current_runtime
        return block.call unless runtime && block

        runtime.with_manual_step(name, &block)
      end

      private

      # @param source [#read, String]
      # @param name [String, nil]
      # @param mime [String, nil]
      # @return [Hash]
      def build_attachment_payload(source, name:, mime:)
        if (path = attachment_path(source))
          filename = name || File.basename(path)
          content_type = Transport::MultipartHelper.content_type_for(
            filename: mime_detection_filename(filename: filename, path: path),
            declared_type: mime
          )
          return {
            name: filename,
            mime: content_type,
            path: path
          }
        end

        bytes =
          if source.respond_to?(:read)
            data = source.read
            source.rewind if source.respond_to?(:rewind)
            data
          else
            source.to_s
          end
        filename = name || Service::PayloadBuilder.default_attachment_name(mime)
        content_type = Transport::MultipartHelper.content_type_for(filename: filename, declared_type: mime)

        {
          name: filename,
          mime: content_type,
          bytes: bytes
        }
      end

      # @param source [Object]
      # @return [String, nil]
      def attachment_path(source)
        path =
          if source.is_a?(String)
            source
          elsif source.respond_to?(:path)
            source.path.to_s
          end
        return nil unless path && File.file?(File.expand_path(path))

        File.expand_path(path)
      rescue ArgumentError
        nil
      end

      # @param filename [String]
      # @param path [String]
      # @return [String]
      def mime_detection_filename(filename:, path:)
        File.extname(filename.to_s).empty? ? File.basename(path) : filename
      end
    end
  end
end
