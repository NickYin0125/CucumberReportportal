# frozen_string_literal: true

module ReportportalCucumber
  module Runtime
    # Thread-safe execution context backed by a thread-local ReportPortal UUID stack.
    class Context
      STACK_KEY = :rp_context_stack

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
        @mutex = Mutex.new
        @feature_items = {}
        @feature_statuses = Hash.new { |hash, key| hash[key] = [] }
        @scenario_attempts = Hash.new(0)
        @test_case_items = {}
        @test_step_items = {}
        Thread.current[STACK_KEY] = []
        thread_state[:current_feature_key] = nil
        thread_state[:current_scenario_key] = nil
        thread_state[:current_scenario_item] = nil
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
      # @param item [ItemHandle]
      # @return [ItemHandle]
      def activate_feature(feature_key, item)
        state = thread_state
        stack = context_stack
        stack.reject! { |handle| handle.kind == :feature && handle.uuid != item.uuid }
        stack << item unless stack.any? { |handle| handle.uuid == item.uuid }
        state[:current_feature_key] = feature_key
        item
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

      # @return [ItemHandle, nil]
      def current_feature_item
        context_stack.reverse.find { |item| item.kind == :feature } || feature_item(current_feature_key)
      end

      # @param feature_key [String]
      # @return [void]
      def finish_feature(feature_key)
        item = feature_item(feature_key)
        return unless item

        pop_item(expected_uuid: item.uuid)
        thread_state[:current_feature_key] = nil if current_feature_key == feature_key
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
        push_item(item)
      end

      # @return [ItemHandle, nil]
      def current_scenario_item
        thread_state[:current_scenario_item]
      end

      # @return [String, nil]
      def current_scenario_key
        thread_state[:current_scenario_key]
      end

      # @param expected_uuid [String, nil]
      # @return [ItemHandle, nil]
      def finish_scenario(expected_uuid: nil)
        target_uuid = expected_uuid || current_scenario_item&.uuid
        popped = target_uuid ? pop_item(expected_uuid: target_uuid) : nil
        state = thread_state
        state[:current_scenario_key] = nil
        state[:current_scenario_item] = nil
        popped
      end

      # @return [void]
      def clear_current_scenario
        finish_scenario
        context_stack.reject! { |item| item.kind == :step || item.kind == :hook || item.kind == :manual_step }
      end

      # @param item [ItemHandle]
      # @return [ItemHandle]
      def push_step(item)
        push_item(item)
      end

      # @param expected_uuid [String, nil]
      # @return [ItemHandle, nil]
      def pop_step(expected_uuid: nil)
        pop_item(expected_uuid: expected_uuid)
      end

      # @return [ItemHandle, nil]
      def current_step_item
        context_stack.reverse.find { |item| %i[step hook manual_step].include?(item.kind) }
      end

      # @return [Array<ItemHandle>]
      def current_step_stack
        context_stack.select { |item| %i[step hook manual_step].include?(item.kind) }
      end

      # @return [ItemHandle, nil]
      def current_item
        context_stack.last || current_feature_item
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

      # @param test_case_started_id [String]
      # @return [ItemHandle, nil]
      def release_test_case_started(test_case_started_id)
        @mutex.synchronize { @test_case_items.delete(test_case_started_id) }
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

      # @param item [ItemHandle]
      # @return [ItemHandle]
      def push_item(item)
        context_stack << item
        item
      end

      # @param expected_uuid [String, nil]
      # @return [ItemHandle, nil]
      def pop_item(expected_uuid: nil)
        return context_stack.pop if expected_uuid.nil?

        index = context_stack.rindex { |item| item.uuid == expected_uuid }
        return nil unless index

        context_stack.delete_at(index)
      end

      # @return [Array<ItemHandle>]
      def context_stack
        Thread.current[STACK_KEY] ||= []
      end

      # @return [Hash]
      def thread_state
        Thread.current[:reportportal_cucumber_context_state] ||= {}
      end
    end
  end
end
