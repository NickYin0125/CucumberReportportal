# frozen_string_literal: true

require_relative "markdown_text"
require_relative "units"
require_relative "image_dimensions"
require_relative "accent"

module ReportportalCucumber
  module Presentation
    # Pure formatting of attachment metadata. File access stays with the caller.
    module AttachmentCaption
      KINDS = {
        "image/png" => "PNG", "image/jpeg" => "JPEG", "image/gif" => "GIF",
        "image/webp" => "WebP", "image/svg+xml" => "SVG", "application/json" => "JSON",
        "text/plain" => "Text", "text/csv" => "CSV", "text/html" => "HTML",
        "application/xml" => "XML", "text/xml" => "XML", "application/pdf" => "PDF",
        "video/mp4" => "MP4", "video/webm" => "WebM", "application/zip" => "ZIP"
      }.freeze

      # @param mime [String] Declared MIME, never inferred from a filename or body.
      # @return [String] Stable attachment-kind label.
      def self.kind(mime)
        Fallback.render(fallback: -> { "File" }) do
          normalized = mime.to_s.split(";", 2).first.to_s.strip.downcase
          normalized.end_with?("+json") ? "JSON" : KINDS.fetch(normalized, "File")
        end
      end

      # @param name [String] Final multipart filename, after collision handling.
      # @param mime [String] Declared MIME.
      # @param size [Integer] Original byte count, not the formatted preview size.
      # @param header [String, nil] Optional first 64 KiB for PNG/JPEG dimensions.
      # @param lines [Integer, nil] Caller-verified complete text line count.
      # @param evidence [Boolean] Whether this artifact is failure evidence.
      # @param presentation [String] "plain" or RP-only "rich".
      # @param level [Symbol, String] Effective log level for first-line protection.
      # @return [String] A one-line Markdown caption with literal filename chip.
      def self.format(name:, mime:, size:, header: nil, lines: nil, evidence: false, presentation: "plain", level: :info)
        Fallback.render(fallback: -> { "Attachment: #{name}" }) do
          parts = [MarkdownText.code(name), kind(mime)]
          dimensions = ImageDimensions.read(header, mime: mime)
          parts << dimensions.join(" × ") if dimensions
          parts << Units.count(lines, "line") if lines
          parts << Units.bytes(size)
          parts << "failure evidence" if evidence
          plain = parts.join(" · ")
          next plain unless presentation == "rich"

          rich = ["#{Accent.pill(parts[1], tone: :info)} #{parts[0]}", *parts.drop(2)].join(" · ")
          Accent.guard(plain: plain, rich: rich, level: level)
        end
      end

      # @param name [String] Owning item's display name.
      # @return [String] ASCII slug bounded to 48 characters; never an empty name.
      def self.slug(name)
        Fallback.render(fallback: -> { "attachment" }) do
          value = name.to_s.byteslice(0, 4096).to_s.force_encoding(Encoding::UTF_8).scrub
          value = value.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "").slice(0, 48).sub(/-+\z/, "")
          value.empty? ? "attachment" : value
        end
      end
    end
  end
end
