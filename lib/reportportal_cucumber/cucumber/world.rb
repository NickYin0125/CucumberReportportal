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
      # @param name [String]
      # @param mime [String]
      # @param message [String, nil]
      # @param level [String, Symbol]
      # @return [void]
      def rp_attach(io_or_bytes, name:, mime:, message: nil, level: :info)
        bytes =
          if io_or_bytes.respond_to?(:read)
            data = io_or_bytes.read
            io_or_bytes.rewind if io_or_bytes.respond_to?(:rewind)
            data
          else
            io_or_bytes.to_s
          end

        rp_log(
          message || "Attachment: #{name}",
          level: level,
          attachment: {
            name: name,
            mime: mime,
            bytes: bytes
          }
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
    end
  end
end
