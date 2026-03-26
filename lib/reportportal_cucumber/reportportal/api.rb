# frozen_string_literal: true

module ReportportalCucumber
  module ReportPortal
    # ReportPortal API wrapper that maps formatter/runtime events to REST endpoints.
    class API
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
      # @param attributes [Array<Hash>, nil]
      # @return [Hash, String]
      def finish_launch(launch_uuid:, end_time:, status: nil, attributes: nil)
        body = Models.build_launch_finish(
          launch_uuid: launch_uuid,
          end_time: end_time,
          status: status,
          attributes: attributes
        )
        response = @client.put_json(path: "#{@config.api_base_path}/launch/#{launch_uuid}/finish", body: body)
        response.body
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
      # @return [Hash, String]
      def finish_item(item_uuid:, launch_uuid:, end_time:, status: nil)
        body = Models.build_item_finish(
          item_uuid: item_uuid,
          launch_uuid: launch_uuid,
          end_time: end_time,
          status: status
        )
        response = @client.put_json(path: "#{@config.api_base_path}/item/#{item_uuid}", body: body)
        response.body
      end

      # @param entries [Array<Hash>]
      # @param files [Array<Hash>]
      # @return [Hash, Array]
      def log_batch(entries:, files:)
        if files.empty? && entries.length == 1
          response = @client.post_json(path: "#{@config.api_base_path}/log", body: entries.first)
          return response.body
        end

        parts = [{
          name: "json_request_part",
          content_type: "application/json",
          body: JSON.generate(entries)
        }]
        files.each do |file|
          parts << {
            name: "file",
            filename: file.fetch(:name),
            content_type: file.fetch(:mime),
            body: file.fetch(:bytes)
          }
        end
        response = @client.post_multipart(path: "#{@config.api_base_path}/log", parts: parts)
        response.body
      end

      private

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
        child_body = body.reject { |key, _| key == "parentUuid" }
        @client.post_json(path: "#{@config.api_base_path}/item/#{parent_uuid}", body: child_body)
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
