# frozen_string_literal: true

require "pathname"
require "uri"

module ReportportalCucumber
  module Service
    # Builds safe, optional navigation links for a Scenario description.
    module ScenarioLinks
      Result = Struct.new(:description, :links, :diagnostics, keyword_init: true)

      SOURCE_TOKENS = %w[commit path line].freeze
      MAX_URL_BYTES = 2_048
      MAX_BLOCK_BYTES = 8_192
      MAX_INPUT_BYTES = 8_192
      MAX_PATH_BYTES = 4_096
      DIAGNOSTIC_REASONS = %i[
        source_unavailable ci_run_url_unsafe tms_link_unavailable link_generation_failed
      ].freeze
      SECRET_QUERY_PARTS = %w[
        token password passwd secret credential signature sig authorization auth key apikey clientkey
        privatekey signingkey consumerkey accesskey
      ].freeze

      module_function

      # @param description [String, nil]
      # @param feature_uri [String, nil]
      # @param scenario_line [Integer, nil]
      # @param example_row_line [Integer, nil]
      # @param explicit_id [String, nil]
      # @param source_url_template [String, nil]
      # @param source_commit [String, nil]
      # @param source_root [String]
      # @param ci_run_url [String, nil]
      # @param tms_url_template [String, nil]
      # @return [Result]
      def build(description:, feature_uri:, scenario_line:, example_row_line: nil, explicit_id: nil,
                source_url_template: nil, source_commit: nil, source_root:, ci_run_url: nil,
                tms_url_template: nil)
        links = []
        diagnostics = []

        source_line = example_row_line.nil? ? valid_line(scenario_line) : valid_line(example_row_line)
        source = source_link(source_url_template, source_commit, source_root, feature_uri, source_line)
        add_link(links, diagnostics, "Source", source, :source_unavailable) if source_url_template

        ci = safe_final_url(ci_run_url) if ci_run_url.is_a?(String) && !ci_run_url.empty?
        add_link(links, diagnostics, "CI Run", ci, :ci_run_url_unsafe) if ci_run_url

        tms = tms_link(tms_url_template, explicit_id)
        add_link(links, diagnostics, "TMS", tms, :tms_link_unavailable) if tms_url_template

        description_result = links.empty? ? description : append_links(description, links)
        Result.new(
          description: deep_copy_freeze(description_result),
          links: deep_copy_freeze(links),
          diagnostics: deep_copy_freeze(diagnostics)
        ).freeze
      rescue StandardError
        # Metadata must never turn an otherwise reportable Scenario into a failure.
        Result.new(
          description: deep_copy_freeze(description),
          links: [].freeze,
          diagnostics: [:link_generation_failed].freeze
        ).freeze
      end

      def source_link(template, commit, root, feature_uri, line)
        return nil unless template.is_a?(String) && commit.is_a?(String) && root.is_a?(String)
        return nil unless commit.match?(/\A[0-9a-fA-F]{7,64}\z/) && line
        return nil unless valid_template?(template, SOURCE_TOKENS, required: SOURCE_TOKENS)
        return nil if template_authority_has_placeholder?(template)

        path = source_path(feature_uri, root)
        return nil unless path

        rendered = substitute(template, "commit" => commit, "path" => encode_path(path), "line" => line.to_s)
        safe_final_url(rendered)
      rescue StandardError
        nil
      end
      private_class_method :source_link

      def tms_link(template, explicit_id)
        return nil unless template.is_a?(String) && explicit_id.is_a?(String) && !explicit_id.empty?
        return nil unless valid_text?(explicit_id) && explicit_id.bytesize <= MAX_URL_BYTES
        return nil if explicit_id.match?(/[\\\x00-\x1f\x7f]/)
        return nil unless valid_template?(template, ["id"], required: ["id"])
        return nil if template_authority_has_placeholder?(template)

        safe_final_url(substitute(template, "id" => percent_encode(explicit_id)))
      rescue StandardError
        nil
      end
      private_class_method :tms_link

      def valid_template?(template, allowed, required:)
        return false unless valid_text?(template) && template.bytesize <= MAX_INPUT_BYTES
        return false if template.match?(/[\x00-\x1f\x7f]/)

        tokens = template.scan(/\{([^{}]+)\}/).flatten
        residue = template.gsub(/\{[^{}]+\}/, "")
        return false if residue.match?(/[{}]/)
        tokens.uniq.sort == required.sort && (tokens - allowed).empty?
      end
      private_class_method :valid_template?

      def template_authority_has_placeholder?(template)
        authority = template.match(%r{\Ahttps?://([^/?#]*)}i)&.captures&.first
        authority.nil? || authority.include?("{") || authority.include?("}")
      end
      private_class_method :template_authority_has_placeholder?

      def source_path(feature_uri, root)
        return nil unless feature_uri.is_a?(String) && root.is_a?(String)
        return nil unless valid_text?(feature_uri) && valid_text?(root)
        return nil if feature_uri.bytesize > MAX_PATH_BYTES || root.bytesize > MAX_PATH_BYTES
        return nil if feature_uri.match?(/[\\\x00-\x1f\x7f]/) || root.match?(/[\\\x00-\x1f\x7f]/)
        return nil if feature_uri.match?(/\A[A-Za-z]:[\\\/]/)
        return nil if feature_uri.split("/").any? { |segment| segment == ".." }
        return nil if feature_uri.split("/").any? { |segment| URI::DEFAULT_PARSER.unescape(segment) == ".." }

        root_path = Pathname.new(File.expand_path(root))
        if feature_uri.start_with?("/")
          candidate = Pathname.new(File.expand_path(feature_uri))
          relative = candidate.relative_path_from(root_path).to_s
          return nil if relative == ".." || relative.start_with?("../")
          relative
        else
          segments = feature_uri.split("/", -1)
          return nil if segments.include?("..") || feature_uri.start_with?("//")

          Pathname.new(feature_uri).cleanpath.to_s
        end.then do |path|
          return nil if path.empty? || path == "." || path.start_with?("../") || path == ".."
          return nil if path.split("/").any? { |segment| segment.empty? || segment == "." || segment == ".." }

          path
        end
      rescue ArgumentError, EncodingError
        nil
      end
      private_class_method :source_path

      def valid_line(value)
        value if value.is_a?(Integer) && value.positive?
      end
      private_class_method :valid_line

      def encode_path(path)
        path.split("/", -1).map { |segment| percent_encode(segment) }.join("/")
      end
      private_class_method :encode_path

      def substitute(template, values)
        template.gsub(/\{([^{}]+)\}/) { values.fetch(Regexp.last_match(1)) }
      end
      private_class_method :substitute

      def percent_encode(value)
        value.b.bytes.map do |byte|
          char = byte.chr
          char.match?(/[A-Za-z0-9\-._~]/) ? char : format("%%%02X", byte)
        end.join
      end
      private_class_method :percent_encode

      def safe_final_url(value)
        return nil unless value.is_a?(String) && valid_text?(value)
        return nil if value.bytesize > MAX_URL_BYTES
        return nil if value.match?(/[\x00-\x20\x7f\\<>"'`]/)
        return nil if value.match?(/%(?![0-9a-fA-F]{2})/)
        return nil if value.match?(/%(?:0[0-9a-f]|1[0-9a-f]|5c|7f)/i)

        normalized = value.encode(Encoding::UTF_8).bytes.map do |byte|
          if byte > 0x7e
            format("%%%02X", byte)
          else
            byte.chr
          end
        end.join.gsub(/[()]/) { |character| character == "(" ? "%28" : "%29" }
        uri = URI::DEFAULT_PARSER.parse(normalized)
        return nil unless %w[http https].include?(uri.scheme&.downcase) && uri.host && !uri.host.empty?
        return nil if uri.userinfo
        return nil if unsafe_query?(uri.query) || unsafe_fragment?(uri.fragment)
        return nil if normalized.bytesize > MAX_URL_BYTES

        normalized.freeze
      rescue URI::InvalidURIError, EncodingError, ArgumentError
        nil
      end
      private_class_method :safe_final_url

      def unsafe_query?(query)
        return false unless query

        query.split(/[&;]/, -1).any? do |pair|
          key = pair.split("=", 2).first
          decoded = URI::DEFAULT_PARSER.unescape(key).downcase
          sensitive_query_name?(decoded) || decoded.match?(/[\x00-\x20\x7f]/)
        rescue ArgumentError, EncodingError
          true
        end
      end
      private_class_method :unsafe_query?

      def unsafe_fragment?(fragment)
        return false unless fragment

        fragment.split(/[&;]/, -1).any? do |part|
          key = part.split("=", 2).first
          sensitive_query_name?(URI::DEFAULT_PARSER.unescape(key))
        rescue ArgumentError, EncodingError
          true
        end
      end
      private_class_method :unsafe_fragment?

      def sensitive_query_name?(decoded)
        parts = decoded.downcase.split(/[^a-z0-9]+/).reject(&:empty?)
        parts.any? do |part|
          SECRET_QUERY_PARTS.include?(part) ||
            %w[token secret password passwd credential signature authorization].any? { |word| part.end_with?(word) }
        end
      end
      private_class_method :sensitive_query_name?

      def valid_text?(value)
        value.is_a?(String) && [Encoding::UTF_8, Encoding::US_ASCII].include?(value.encoding) && value.valid_encoding?
      end
      private_class_method :valid_text?

      def add_link(links, diagnostics, label, url, reason)
        raise ArgumentError, "Unknown diagnostic reason" unless DIAGNOSTIC_REASONS.include?(reason)

        if url
          links << { label: label.dup, url: url }
        else
          diagnostics << reason
        end
      end
      private_class_method :add_link

      def append_links(description, links)
        block = "### References\n\n#{links.map { |link| "[#{link[:label]}](<#{link[:url]}>)" }.join(" | ")}"
        return description unless block.bytesize <= MAX_BLOCK_BYTES

        description.nil? || description.empty? ? block : "#{description}\n\n#{block}"
      end
      private_class_method :append_links

      def deep_copy_freeze(value)
        case value
        when String then value.dup.freeze
        when Array then value.map { |item| deep_copy_freeze(item) }.freeze
        when Hash
          value.each_with_object({}) do |(key, item), copy|
            copy[deep_copy_freeze(key)] = deep_copy_freeze(item)
          end.freeze
        else value
        end
      end
      private_class_method :deep_copy_freeze
    end
  end
end
