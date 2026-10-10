# frozen_string_literal: true

module ReportportalCucumber
  module ReportPortal
    # ReportPortal API wrapper that maps formatter/runtime events to REST endpoints.
    class API
      LogBatchResult = Struct.new(:body, :may_duplicate, keyword_init: true) do
        def initialize(**values)
          super
          freeze
        end
      end

      # @param config [ReportportalCucumber::Config]
      # @param client [ReportportalCucumber::Http::Client]
      def initialize(config:, client: Http::Client.new(config:))
        @config = config
        @client = client
      end

      # @param name [String]
      # @param start_time [Time, String, Integer, Float]
      # @param description [String, nil]
      # @param attributes [Array<Hash>, nil]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @param mode [String, nil]
      # @param rerun [Boolean]
      # @param rerun_of [String, nil]
      # @param uuid [String, nil]
      # @return [String]
      def start_launch(name:, start_time:, description:, attributes:, mode:, rerun:, rerun_of:, uuid:)
        body = Models.build_launch_start(
          name: name,
          start_time: start_time,
          description: description,
          attributes: attributes,
          mode: mode,
          rerun: rerun,
          rerun_of: rerun_of,
          uuid: uuid
        )
        response = @client.post_json(path: "#{@config.api_base_path}/launch", body: body)
        extract_id(response.body, fallback: uuid)
      end

      # @param launch_uuid [String]
      # @param end_time [Time, String, Integer, Float]
      # @param status [String, Symbol, nil]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @param attributes [Array<Hash>, nil]
      # @return [Hash, String]
      def finish_launch(launch_uuid:, end_time:, status: nil, attributes: nil, deadline: nil)
        body = Models.build_launch_finish(
          launch_uuid: launch_uuid,
          end_time: end_time,
          status: status,
          attributes: attributes
        )
        response = if deadline
                     @client.put_json(path: "#{@config.api_base_path}/launch/#{launch_uuid}/finish", body: body, deadline: deadline)
                   else
                     @client.put_json(path: "#{@config.api_base_path}/launch/#{launch_uuid}/finish", body: body)
                   end
        response.body
      end

      # Fetch the original v1 launch target without creating or changing it.
      # @param uuid [String]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [Hash, Array, String]
      def launch_by_uuid(uuid:, deadline: nil)
        lookup_by_uuid(resource: "launch", uuid: uuid, deadline: deadline)
      end

      # Fetch the original v1 item target without creating or changing it.
      # @param uuid [String]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [Hash, Array, String]
      def item_by_uuid(uuid:, deadline: nil)
        lookup_by_uuid(resource: "item", uuid: uuid, deadline: deadline)
      end

      # @param name [String]
      # @param start_time [Time, String, Integer, Float]
      # @param type [String]
      # @param launch_uuid [String]
      # @param parent_uuid [String, nil]
      # @param description [String, nil]
      # @param attributes [Array<Hash>, nil]
      # @param code_ref [String, nil]
      # @param parameters [Hash, Array<Hash>, nil]
      # @param has_stats [Boolean]
      # @param retry [Boolean]
      # @param uuid [String, nil]
      # @param test_case_id [String, nil]
      # @param unique_id [String, nil]
      # @return [String]
      def start_item(name:, start_time:, type:, launch_uuid:, parent_uuid: nil, description: nil, attributes: nil,
                     code_ref: nil, parameters: nil, has_stats: true, retry: false, uuid: nil, test_case_id: nil,
                     unique_id: nil)
        retry_flag = binding.local_variable_get(:retry)
        body = Models.build_item_start(
          name: name,
          start_time: start_time,
          type: type,
          launch_uuid: launch_uuid,
          description: description,
          attributes: attributes,
          code_ref: code_ref,
          parameters: parameters,
          parent_uuid: parent_uuid,
          has_stats: has_stats,
          retry: retry_flag,
          uuid: uuid,
          test_case_id: test_case_id,
          unique_id: unique_id
        )

        response =
          if parent_uuid
            start_child_item(body: body, parent_uuid: parent_uuid)
          else
            @client.post_json(path: "#{@config.api_base_path}/item", body: body)
          end

        extract_id(response.body, fallback: uuid)
      end

      # @param item_uuid [String]
      # @param launch_uuid [String]
      # @param end_time [Time, String, Integer, Float]
      # @param status [String, Symbol, nil]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [Hash, String]
      def finish_item(item_uuid:, launch_uuid:, end_time:, status: nil, deadline: nil)
        body = Models.build_item_finish(
          item_uuid: item_uuid,
          launch_uuid: launch_uuid,
          end_time: end_time,
          status: status
        )
        response = if deadline
                     @client.put_json(path: "#{@config.api_base_path}/item/#{item_uuid}", body: body, deadline: deadline)
                   else
                     @client.put_json(path: "#{@config.api_base_path}/item/#{item_uuid}", body: body)
                   end
        response.body
      end

      # @param entries [Array<Hash>]
      # @param files [Array<Hash>]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [Hash, Array]
      def log_batch(entries:, files:, deadline: nil)
        result = perform_log_batch(entries: entries, files: files, deadline: deadline)
        key = @log_batch_metadata_key
        Thread.current[key] = result.may_duplicate if key && Thread.current[key] == :collecting
        result.body
      end

      # @param entries [Array<Hash>]
      # @param files [Array<Hash>]
      # @param deadline [ReportportalCucumber::Service::ReportingDeadline, nil]
      # @return [ReportportalCucumber::ReportPortal::API::LogBatchResult]
      def log_batch_result(entries:, files:, deadline: nil)
        key = log_batch_metadata_key
        Thread.current[key] = :collecting
        body = log_batch(entries: entries, files: files, deadline: deadline)
        LogBatchResult.new(body: body, may_duplicate: !!Thread.current[key] && Thread.current[key] != :collecting)
      ensure
        Thread.current[key] = nil if key
      end

      private

      def lookup_by_uuid(resource:, uuid:, deadline: nil)
        raise ArgumentError, "Invalid ReportPortal UUID" unless uuid.is_a?(String) && uuid.match?(/\A[0-9a-f-]{16,64}\z/i)

        path = "/api/v1/#{@config.project}/#{resource}/uuid/#{URI.encode_www_form_component(uuid)}"
        response = @client.get_json(path: path, deadline: deadline)
        response.body
      end

      def perform_log_batch(entries:, files:, deadline: nil)
        if entries.length > batch_size_logs
          raise Transport::MultipartHelper::CountLimitError
        end
        raise Transport::MultipartHelper::SizeLimitError if Transport::MultipartHelper.log_batch_bytes(entries: entries, files: files) > batch_max_bytes

        if files.empty? && entries.length == 1
          response = if deadline
                       @client.post_json(path: "#{@config.api_base_path}/log", body: entries.first, deadline: deadline)
                     else
                       @client.post_json(path: "#{@config.api_base_path}/log", body: entries.first)
                     end
          return LogBatchResult.new(body: response.body, may_duplicate: !!response.may_duplicate)
        end

        parts = [{
          name: "json_request_part",
          content_type: "application/json",
          body: JSON.generate(entries)
        }]
        files.each do |file|
          part = {
            name: "file",
            filename: file.fetch(:name),
            content_type: file.fetch(:mime)
          }
          if file[:path]
            part[:path] = file.fetch(:path)
          else
            part[:body] = file.fetch(:bytes)
          end
          parts << part
        end
        response = if deadline
                     @client.post_multipart(path: "#{@config.api_base_path}/log", parts: parts, deadline: deadline)
                   else
                     @client.post_multipart(path: "#{@config.api_base_path}/log", parts: parts)
                   end
        LogBatchResult.new(body: response.body, may_duplicate: !!response.may_duplicate)
      end

      def log_batch_metadata_key
        @log_batch_metadata_key ||= "reportportal_log_batch_metadata_#{object_id}".to_sym
      end

      # @return [Integer]
      def batch_size_logs
        @config.respond_to?(:batch_size_logs) ? @config.batch_size_logs : 20
      end

      # @return [Integer]
      def batch_max_bytes
        @config.respond_to?(:batch_max_bytes) ? @config.batch_max_bytes : 8 * 1024 * 1024
      end

      # @param body [Hash, String]
      # @param fallback [String, nil]
      # @return [String]
      def extract_id(body, fallback:)
        return fallback unless body.is_a?(Hash)

        body["id"] || body.dig("data", "id") || body["uuid"] || fallback
      end

      # @param body [Hash]
      # @param parent_uuid [String]
      # @return [ReportportalCucumber::Transport::HTTPClient::Response]
      def start_child_item(body:, parent_uuid:)
        @client.post_json(path: "#{@config.api_base_path}/item/#{parent_uuid}", body: body)
      rescue Http::Client::Error => error
        raise error unless fallback_to_parent_uuid_body?(error)

        @client.post_json(path: "#{@config.api_base_path}/item", body: body)
      end

      # @param error [ReportportalCucumber::Transport::HTTPClient::Error]
      # @return [Boolean]
      def fallback_to_parent_uuid_body?(error)
        response = error.response
        return true if [404, 405].include?(response&.status)
        return false unless response&.status == 400 && response.body.is_a?(Hash)

        response.body["errorCode"] == 40016 ||
          response.body["message"].to_s.downcase.include?("nested step")
      end
    end
  end
end
