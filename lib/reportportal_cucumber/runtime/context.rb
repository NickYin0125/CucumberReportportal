# frozen_string_literal: true

module ReportportalCucumber
  module Runtime
    # Thread-safe execution context for the current launch, feature, scenario, and nested steps.
    class Context
      ItemHandle = Struct.new(
        :uuid,
        :name,
        :kind,
        :parent_uuid,
        :type,
        :has_stats,
        :metadata,
        keyword_init: true
      )

      # @return [void]
      def initialize
        @thread_state_key = :"reportportal_cucumber_context_state_#{object_id}"
        @mutex = Mutex.new
        @feature_items = {}
        @feature_statuses = Hash.new { |hash, key| hash[key] = [] }
        @scenario_attempts = Hash.new(0)
        @test_case_items = {}
        @test_step_items = {}
      end

      # @param feature_key [String]
      # @param item [ItemHandle]
      # @return [ItemHandle]
      def register_feature(feature_key, item)
        @mutex.synchronize { @feature_items[feature_key] ||= item }
      end

      # @param feature_key [String]
      # @return [ItemHandle, nil]
      def feature_item(feature_key)
        @mutex.synchronize { @feature_items[feature_key] }
      end

      # @return [Hash<String, ItemHandle>]
      def feature_items
        @mutex.synchronize { @feature_items.dup }
      end

      # @param feature_key [String]
      # @param status [String]
      # @return [void]
      def record_feature_status(feature_key, status)
        @mutex.synchronize { @feature_statuses[feature_key] << status }
      end

      # @param feature_key [String]
      # @return [Array<String>]
      def feature_statuses(feature_key)
        @mutex.synchronize { @feature_statuses[feature_key].dup }
      end

      # @param feature_key [String]
      # @return [void]
      def set_current_feature(feature_key)
        thread_state[:current_feature_key] = feature_key
      end

      # @return [String, nil]
      def current_feature_key
        thread_state[:current_feature_key]
      end

      # @param scenario_key [String]
      # @return [Integer]
      def next_scenario_attempt(scenario_key)
        @mutex.synchronize do
          @scenario_attempts[scenario_key] += 1
        end
      end

      # @param scenario_key [String]
      # @param item [ItemHandle]
      # @return [ItemHandle]
      def start_scenario(scenario_key, item)
        state = thread_state
        state[:current_scenario_key] = scenario_key
        state[:current_scenario_item] = item
        state[:step_stack] = []
        item
      end

      # @return [ItemHandle, nil]
      def current_scenario_item
        thread_state[:current_scenario_item]
      end

      # @return [String, nil]
      def current_scenario_key
        thread_state[:current_scenario_key]
      end

      # @return [void]
      def clear_current_scenario
        state = thread_state
        state[:current_scenario_key] = nil
        state[:current_scenario_item] = nil
        state[:step_stack] = []
      end

      # @param item [ItemHandle]
      # @return [Array<ItemHandle>]
      def push_step(item)
        thread_state[:step_stack] << item
      end

      # @param expected_uuid [String, nil]
      # @return [ItemHandle, nil]
      def pop_step(expected_uuid: nil)
        stack = thread_state[:step_stack]
        return stack.pop if expected_uuid.nil?

        index = stack.rindex { |item| item.uuid == expected_uuid }
        return nil unless index

        stack.delete_at(index)
      end

      # @return [ItemHandle, nil]
      def current_step_item
        thread_state[:step_stack].last
      end

      # @return [Array<ItemHandle>]
      def current_step_stack
        thread_state[:step_stack].dup
      end

      # @return [ItemHandle, nil]
      def current_item
        current_step_item || current_scenario_item || feature_item(current_feature_key)
      end

      # @return [String, nil]
      def current_item_uuid
        current_item&.uuid
      end

      # @param test_case_started_id [String]
      # @param item [ItemHandle]
      # @return [void]
      def associate_test_case_started(test_case_started_id, item)
        @mutex.synchronize { @test_case_items[test_case_started_id] = item }
      end

      # @param test_case_started_id [String]
      # @return [ItemHandle, nil]
      def item_for_test_case_started(test_case_started_id)
        @mutex.synchronize { @test_case_items[test_case_started_id] }
      end

      # @param test_step_id [String]
      # @param item [ItemHandle]
      # @return [void]
      def associate_test_step(test_step_id, item)
        @mutex.synchronize { @test_step_items[test_step_id] = item }
      end

      # @param test_step_id [String]
      # @return [ItemHandle, nil]
      def item_for_test_step(test_step_id)
        @mutex.synchronize { @test_step_items[test_step_id] }
      end

      # @param test_step_id [String]
      # @return [ItemHandle, nil]
      def release_test_step(test_step_id)
        @mutex.synchronize { @test_step_items.delete(test_step_id) }
      end

      private

      # @return [Hash]
      def thread_state
        Thread.current[@thread_state_key] ||= {
          current_feature_key: nil,
          current_scenario_key: nil,
          current_scenario_item: nil,
          step_stack: []
        }
      end
    end
  end
end
