# frozen_string_literal: true

require "rbconfig"
require_relative "markdown_text"
require_relative "units"
require_relative "accent"
require_relative "../automation/evidence_redactor"

module ReportportalCucumber
  module Presentation
    # A short project-first view followed by the complete original failure evidence.
    class FailureCard
      TITLE_LIMIT = 200
      PROJECT_LIMIT = 8
      FRAMEWORK_LIMIT = 3
      LOCATION_LIMIT = 40
      BYTE_LIMIT = Automation::EvidenceRedactor::MAX_INPUT_BYTES

      class << self
        # Redacts the entire original message before adding Markdown. This order
        # keeps generated Markdown escapes out of raw-diagnostic JSON validation.
        # The original evidence is never clipped to make room for presentation.
        # @param error [Object] Original failure; only Exceptions get a class title.
        # @param message [String] Original extracted exception message.
        # @param backtrace [String] Original joined backtrace, without normalization.
        # @param cwd [String] Project root used only for displayed locations.
        # @param presentation [String] "plain" or RP-only "rich".
        # @return [String] Bounded card, or the exact redacted baseline on failure.
        def format(error:, message:, backtrace:, cwd: Dir.pwd, presentation: "plain")
          redactor = Automation::EvidenceRedactor.new
          raw = [message, backtrace].reject(&:empty?).join("\n")
          baseline = redactor.redact_text(raw)
          baseline = "Step failed" if baseline.empty?
          Fallback.render(fallback: -> { baseline }) do
            next baseline if baseline == Automation::EvidenceRedactor::OMITTED

            safe_message = redactor.redact_text(message)
            safe_backtrace = redactor.redact_text(backtrace)
            joined = [safe_message, safe_backtrace].reject(&:empty?).join("\n")
            # If redaction changed structure across the boundary, retain exactly
            # what the baseline would have sent rather than reconstructing it.
            next baseline unless joined == (raw.empty? ? "" : baseline)

            card = render(error, safe_message, safe_backtrace, cwd)
            next baseline if card.bytesize > BYTE_LIMIT
            next card unless presentation == "rich"

            rich = render(error, safe_message, safe_backtrace, cwd, accent: true)
            Accent.guard(plain: card, rich: rich, level: :error)
          end
        end

        private

        def render(error, message, backtrace, cwd, accent: false)
          message_lines = message.lines(chomp: true)
          first = message_lines.index { |line| !line.strip.empty? }
          headline = first ? message_lines[first] : ""
          continuation = first ? message_lines[(first + 1)..].join("\n") : ""
          klass = error.is_a?(Exception) ? error.class.name.to_s : ""
          title_text = [klass, headline].reject(&:empty?).join(": ")
          return "Step failed" if title_text.empty? && backtrace.empty?

          sections = [title(title_text.empty? ? "Step failed" : title_text)]
          frames = backtrace.lines(chomp: true).map { |line| frame(line, cwd) }
          feature = frames.find { |entry| entry[:feature] }
          projects = frames.select { |entry| entry[:kind] == :project && !entry[:feature] }
          shown = projects.first(PROJECT_LIMIT)
          shown = frames.select { |entry| entry[:kind] == :framework }.first(FRAMEWORK_LIMIT) if shown.empty?
          shown << feature if feature && !shown.include?(feature)
          meta = [feature, projects.first].compact.map { |entry| MarkdownText.code(entry[:location]) }.join(" \u2192 ")
          sections << meta unless meta.empty?
          sections << fenced(continuation) unless continuation.empty?
          unless shown.empty?
            sections << "_Project frames_" unless continuation.empty?
            width = shown.map { |entry| entry[:location].length }.max + 2
            aligned = shown.map do |entry|
              entry[:method].empty? ? entry[:location] : entry[:location].ljust(width) + entry[:method]
            end.join("\n")
            sections << fenced(aligned)
          end
          unless backtrace.empty?
            caption = tail_caption(frames, shown)
            if accent
              sections << Accent.details(summary: caption, body: backtrace, limit: BYTE_LIMIT)
            else
              sections << "_#{caption}_"
              sections << fenced(backtrace)
            end
          end
          sections.join("\n\n")
        end

        def title(value)
          line = "## \u2717 #{MarkdownText.inline(value, limit: BYTE_LIMIT)}"
          return line if line.length <= TITLE_LIMIT

          # Do not cut through an entity or Markdown escape when bounding a title.
          prefix = +""
          line.scan(/&(?:amp|lt|gt);|\\.|./m).each do |token|
            break if prefix.length + token.length > TITLE_LIMIT - 1

            prefix << token
          end
          prefix + "\u2026"
        end

        def frame(line, cwd)
          match = line.match(/\A(.+?):(\d+)(?::in ['`](.*)['`])?\z/)
          path = match ? match[1] : line
          location = display_path(path, cwd)
          location += ":#{match[2]}" if match
          location = bounded_location(location)
          kind = if line.start_with?("-e:", "<internal:")
                   :runner
                 elsif path.include?("/gems/") || path.start_with?(RbConfig::CONFIG.fetch("rubylibdir"))
                   :framework
                 else
                   :project
                 end
          { location: location, method: match ? match[3].to_s : "", kind: kind,
            feature: line.match?(/\.feature:\d+/) }
        end

        def display_path(path, cwd)
          prefix = cwd.end_with?("/") ? cwd : cwd + "/"
          return path.delete_prefix(prefix) if path.start_with?(prefix)

          features = path.index("/features/")
          features ? path[(features + 1)..] : File.basename(path)
        end

        def bounded_location(location)
          return location if location.length <= LOCATION_LIMIT

          filename = File.basename(location)
          if location.include?("/")
            shortened = "#{location.split('/', 2).first}/\u2026/#{filename}"
            return shortened if shortened.length <= LOCATION_LIMIT
          end
          return filename if filename.length <= LOCATION_LIMIT

          line = filename[/:\d+\z/].to_s
          name = filename.delete_suffix(line)
          extension = File.extname(name)
          stem = name.delete_suffix(extension)
          budget = LOCATION_LIMIT - extension.length - line.length - 1
          # Impossible suffixes fall back to the intact redacted evidence.
          raise ArgumentError, "Location suffix exceeds display budget" if budget < 1

          left = (budget + 1) / 2
          right = budget / 2
          "#{stem[0, left]}\u2026#{right.zero? ? '' : stem[-right, right]}#{extension}#{line}"
        end

        def tail_caption(frames, shown)
          hidden = frames.reject { |entry| shown.any? { |visible| visible.equal?(entry) } }
          counts = %i[framework runner project].filter_map do |kind|
            number = hidden.count { |entry| entry[:kind] == kind }
            "#{number} #{kind}" if number.positive?
          end
          caption = "Full backtrace \u00b7 #{Units.count(frames.length, 'frame')}"
          unless counts.empty?
            noun = hidden.length == 1 ? "frame" : "frames"
            caption += " \u00b7 #{counts.join(' and ')} #{noun} not shown above"
          end
          caption
        end

        def fenced(content)
          MarkdownText.fence(content, "text", limit: BYTE_LIMIT) || raise(ArgumentError, "No bounded fence")
        end
      end
    end
  end
end
