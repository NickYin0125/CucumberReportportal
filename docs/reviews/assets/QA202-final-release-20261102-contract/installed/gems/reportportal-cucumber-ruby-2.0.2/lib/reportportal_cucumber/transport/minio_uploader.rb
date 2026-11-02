# frozen_string_literal: true

require "aws-sdk-s3"
require "cgi"
require "securerandom"
require "stringio"
require_relative "../service/evidence_presenter"

module ReportportalCucumber
  module Transport
    # Uploads large video artifacts to S3-compatible storage and returns public object URLs.
    class MinioUploader
      DIAGNOSTIC_LIMIT = 2048

      # @param config [ReportportalCucumber::Config]
      # @param client [Aws::S3::Client, nil]
      def initialize(config:, client: nil)
        @config = config
        @client = client || Aws::S3::Client.new(**client_options)
      end

      # @param path [String, nil]
      # @param bytes [String, #read, nil]
      # @param name [String]
      # @param content_type [String]
      # @return [String]
      def upload_video(path: nil, bytes: nil, name:, content_type: "video/mp4")
        key = object_key(name)
        body = upload_body(path: path, bytes: bytes)
        @client.put_object(
          bucket: @config.minio_bucket,
          key: key,
          body: body,
          content_type: normalized_video_content_type(content_type)
        )
        public_url_for(key)
      rescue StandardError => error
        diagnostic = safe_diagnostic(error)
        warn_video_upload_failure(diagnostic)
        fallback_message(name: name, diagnostic: diagnostic)
      ensure
        body.close if body.respond_to?(:close) && body.respond_to?(:path)
      end

      private

      def client_options
        options = {
          endpoint: @config.minio_endpoint,
          access_key_id: @config.minio_access_key_id,
          secret_access_key: @config.minio_secret_access_key,
          region: @config.minio_region,
          force_path_style: true,
          ssl_verify_peer: !(@config.respond_to?(:minio_ssl_verify_peer) && @config.minio_ssl_verify_peer == false)
        }
        ca_bundle = @config.minio_ssl_ca_bundle if @config.respond_to?(:minio_ssl_ca_bundle)
        options[:ssl_ca_bundle] = ca_bundle unless ca_bundle.nil?
        options
      end

      # @param name [String]
      # @return [String]
      def object_key(name)
        safe_name = MultipartHelper.ensure_filename_extension(
          name: MultipartHelper.safe_filename(name).gsub(/\s+/, "_"),
          content_type: "video/mp4",
          fallback: "recording.mp4"
        )
        "videos/#{Time.now.utc.strftime('%Y/%m/%d')}/#{SecureRandom.uuid}-#{safe_name}"
      end

      # @param path [String, nil]
      # @param bytes [String, #read, nil]
      # @return [IO, StringIO]
      def upload_body(path:, bytes:)
        return File.open(File.expand_path(path.to_s), "rb") if path && File.file?(File.expand_path(path.to_s))

        if bytes.respond_to?(:read)
          data = bytes.read
          bytes.rewind if bytes.respond_to?(:rewind)
          return StringIO.new(data.to_s)
        end

        StringIO.new(bytes.to_s)
      end

      # @param content_type [String]
      # @return [String]
      def normalized_video_content_type(content_type)
        MultipartHelper.content_type_for(filename: "recording.mp4", declared_type: content_type)
      end

      # @param key [String]
      # @return [String]
      def public_url_for(key)
        base = @config.minio_public_base_url.to_s.delete_suffix("/")
        bucket = escape_path_segment(@config.minio_bucket)
        object = key.split("/").map { |segment| escape_path_segment(segment) }.join("/")
        "#{base}/#{bucket}/#{object}"
      end

      # @param diagnostic [String] Already sanitized diagnostic.
      # @return [void]
      def warn_video_upload_failure(diagnostic)
        $stderr.puts("[WARN] Video upload failed: #{diagnostic}")
      rescue StandardError
        nil
      end

      # @param name [String]
      # @param diagnostic [String] Already sanitized diagnostic.
      # @return [String]
      def fallback_message(name:, diagnostic:)
        safe_name = Service::EvidencePresenter.sanitize_diagnostic(name, limit: 256)
          .gsub(/[\x00-\x1f\x7f]/, " ")
        "Video upload failed for #{safe_name}: #{diagnostic}. " \
          "The Cucumber run was not interrupted; inspect the local recording artifact if it is available."
      end

      def safe_diagnostic(error)
        Service::EvidencePresenter.sanitize_diagnostic(error.message, limit: DIAGNOSTIC_LIMIT)
          .gsub(/[\x00-\x1f\x7f]/, " ")
      rescue StandardError
        Service::EvidencePresenter::OMITTED
      end

      # @param value [String]
      # @return [String]
      def escape_path_segment(value)
        CGI.escape(value.to_s).gsub("+", "%20")
      end
    end
  end
end
