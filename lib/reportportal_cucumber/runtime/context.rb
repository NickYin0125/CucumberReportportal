# frozen_string_literal: true

require "weakref"

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

      # Opaque capability identifying one open action item.
      class CaptureTarget
        def initialize(owner:)
          @owner = WeakRef.new(owner) if owner
          freeze
        end

        # @param target [Object]
        # @return [Object, nil]
        def self.owner_for(target)
          return unless target.is_a?(self)

          target.__send__(:owner)
        rescue WeakRef::RefError
          nil
        end

        private

        def owner
          @owner&.__getobj__
        end
      end

      # @return [void]
      def initialize
        @mutex = Mutex.new
        @capture_target_condition = ConditionVariable.new
        @feature_items = {}
        @feature_statuses = Hash.new { |hash, key| hash[key] = [] }
        @scenario_attempts = Hash.new(0)
        @test_case_items = {}
        @test_step_items = {}
        @capture_targets = {}
        Thread.current[STACK_KEY] = []
        thread_state[:current_feature_key] = nil
        thread_state[:current_scenario_key] = nil
        thread_state[:current_scenario_item] = nil
        thread_state[:active_parent] = nil
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
        sync_active_parent_from_stack!
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

      # @return [String, nil]
      def current_feature_uuid
        current_feature_item&.uuid
      end

      # @param feature_key [String]
      # @return [void]
      def finish_feature(feature_key)
        item = @mutex.synchronize { @feature_items.delete(feature_key) }
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
        sync_active_parent_from_stack!
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

      # @param item [ItemHandle]
      # @param launch_uuid [String]
      # @param owner [Object, nil]
      # @return [CaptureTarget]
      def register_capture_target(item, launch_uuid:, owner: nil)
        target = CaptureTarget.new(owner: owner)
        @mutex.synchronize do
          @capture_targets[target] = { item: item, launch_uuid: launch_uuid, open: true, writers: 0 }
        end
        target
      end

      # @param target [CaptureTarget]
      # @param launch_uuid [String]
      # @return [ItemHandle, nil]
      def acquire_capture_target(target, launch_uuid:)
        return unless target.is_a?(CaptureTarget)

        @mutex.synchronize do
          entry = @capture_targets[target]
          return unless entry && entry[:open] && entry[:launch_uuid] == launch_uuid

          entry[:writers] += 1
          entry[:item]
        end
      end

      # @param target [CaptureTarget]
      # @param launch_uuid [String]
      # @yield [item] Enqueue the complete evidence batch for the target.
      # @return [Boolean]
      def publish_capture_target(target, launch_uuid:)
        @mutex.synchronize do
          entry = @capture_targets[target]
          return false unless entry && entry[:open] && entry[:launch_uuid] == launch_uuid

          yield entry[:item]
          true
        end
      end

      # @param target [CaptureTarget]
      # @return [void]
      def release_capture_target(target)
        @mutex.synchronize do
          entry = @capture_targets[target]
          return unless entry && entry[:writers].positive?

          entry[:writers] -= 1
          @capture_target_condition.broadcast if entry[:writers].zero?
        end
      end

      # @param target [CaptureTarget]
      # @param launch_uuid [String]
      # @return [ItemHandle, nil]
      def validate_capture_target(target, launch_uuid:)
        return unless target.is_a?(CaptureTarget)

        @mutex.synchronize do
          entry = @capture_targets[target]
          entry[:item] if entry && entry[:open] && entry[:launch_uuid] == launch_uuid
        end
      end

      # @param target [CaptureTarget]
      # @param timeout [Numeric]
      # @return [Boolean]
      def close_capture_target(target, timeout: 5.0)
        @mutex.synchronize do
          entry = @capture_targets[target]
          return true unless entry

          entry[:open] = false
          deadline = monotonic_now + [timeout.to_f, 0].max
          while entry[:writers].positive?
            remaining = deadline - monotonic_now
            if remaining <= 0
              @capture_targets.delete(target)
              return false
            end
            @capture_target_condition.wait(@mutex, remaining)
          end
          @capture_targets.delete(target)
          true
        end
      end

      # @param item [ItemHandle]
      # @param timeout [Numeric]
      # @return [Boolean]
      def close_capture_target_for_item(item, timeout: 5.0)
        @mutex.synchronize do
          close_capture_targets_matching(timeout: timeout) do |_target, entry|
            entry[:item].equal?(item)
          end
        end
      end

      # @param launch_uuid [String, nil]
      # @param timeout [Numeric]
      # @return [Boolean]
      def close_capture_targets(launch_uuid: nil, timeout: 5.0)
        @mutex.synchronize do
          close_capture_targets_matching(timeout: timeout) do |_target, entry|
            launch_uuid.nil? || entry[:launch_uuid] == launch_uuid
          end
        end
      end

      # @param item [ItemHandle]
      # @param launch_uuid [String]
      # @return [CaptureTarget, nil]
      def capture_target_for(item, launch_uuid:)
        @mutex.synchronize do
          @capture_targets.find do |_target, entry|
            entry[:item].equal?(item) && entry[:launch_uuid] == launch_uuid && entry[:open]
          end&.first
        end
      end

      # @return [ItemHandle, nil]
      def current_item
        context_stack.last || current_feature_item
      end

      # @return [String, nil]
      def current_item_uuid
        current_item&.uuid
      end

      # @return [ItemHandle, nil]
      def active_parent
        thread_state[:active_parent] || current_item
      end

      # @return [String, nil]
      def active_parent_uuid
        active_parent&.uuid
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

      # @param item_uuid [String]
      # @return [Array<String>]
      def release_test_steps_for_item(item_uuid)
        @mutex.synchronize do
          removed = @test_step_items.select { |_id, item| item.uuid == item_uuid }.keys
          removed.each { |id| @test_step_items.delete(id) }
          removed
        end
      end

      private

      # @yield [target, entry]
      # @param timeout [Numeric]
      # @return [Boolean]
      def close_capture_targets_matching(timeout:)
        selected = @capture_targets.select { |target, entry| yield(target, entry) }
        selected.each_value { |entry| entry[:open] = false }
        deadline = monotonic_now + [timeout.to_f, 0].max
        selected.each do |target, entry|
          while entry[:writers].positive?
            remaining = deadline - monotonic_now
            if remaining <= 0
              selected.each_key { |selected_target| @capture_targets.delete(selected_target) }
              return false
            end
            @capture_target_condition.wait(@mutex, remaining)
          end
          @capture_targets.delete(target)
        end
        true
      end

      # @return [Float]
      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # @param item [ItemHandle]
      # @return [ItemHandle]
      def push_item(item)
        context_stack << item
        sync_active_parent_from_stack!
        item
      end

      # @param expected_uuid [String, nil]
      # @return [ItemHandle, nil]
      def pop_item(expected_uuid: nil)
        if expected_uuid.nil?
          popped = context_stack.pop
          sync_active_parent_from_stack!
          return popped
        end

        return nil unless context_stack.last&.uuid == expected_uuid

        popped = context_stack.pop
        sync_active_parent_from_stack!
        popped
      end

      # @return [Array<ItemHandle>]
      def context_stack
        Thread.current[STACK_KEY] ||= []
      end

      # @return [Hash]
      def thread_state
        Thread.current[:reportportal_cucumber_context_state] ||= {}
      end

      # @return [void]
      def sync_active_parent_from_stack!
        thread_state[:active_parent] = context_stack.last
      end
    end
  end
end
