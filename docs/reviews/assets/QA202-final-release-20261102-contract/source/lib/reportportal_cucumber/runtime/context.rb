# frozen_string_literal: true

require "weakref"

module ReportportalCucumber
  module Runtime
    # Instance-owned execution state; thread locals expose only compatibility snapshots.
    # The legacy stack/state mirrors describe the most recently accessed context.
    # Direct mutation of those detached mirrors is unsupported and cannot retarget ownership.
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
        @thread_state_mutex = Mutex.new
        @thread_states = {}
        @capture_mutex = Mutex.new
        @capture_close_requests = Queue.new
        @capture_target_condition = ConditionVariable.new
        @feature_items = {}
        @feature_statuses = Hash.new { |hash, key| hash[key] = [] }
        @scenario_attempts = Hash.new(0)
        @test_case_items = {}
        @test_step_items = {}
        @capture_targets = {}
        mirror_thread_state(empty_thread_state)
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
        state = thread_state
        state[:current_feature_key] = feature_key
        finish_thread_state_access(state)
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
        set_current_feature(nil) if current_feature_key == feature_key
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
        finish_thread_state_access(state)
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
        @capture_mutex.synchronize do
          revoke_pending_capture_targets
          @capture_targets[target] = { item: item, launch_uuid: launch_uuid, open: true, writers: 0 }
        end
        target
      end

      # @param target [CaptureTarget]
      # @param launch_uuid [String]
      # @return [ItemHandle, nil]
      def acquire_capture_target(target, launch_uuid:)
        return unless target.is_a?(CaptureTarget)

        @capture_mutex.synchronize do
          revoke_pending_capture_targets
          entry = @capture_targets[target]
          return unless entry && entry[:open] && entry[:launch_uuid] == launch_uuid

          entry[:writers] += 1
          entry[:item]
        end
      end

      # @param target [CaptureTarget]
      # @param launch_uuid [String]
      # @yield [item, cancelled] Publish outside the lock; check cancellation before admission.
      # @yieldparam item [ItemHandle] Original item, never a replacement target.
      # @yieldparam cancelled [Proc] Whether close has revoked this publication.
      # @return [Boolean]
      def publish_capture_target(target, launch_uuid:)
        item = acquire_capture_target(target, launch_uuid: launch_uuid)
        return false unless item

        reserved = true
        cancelled = -> { validate_capture_target(target, launch_uuid: launch_uuid).nil? }
        yield item, cancelled
        !cancelled.call
      ensure
        release_capture_target(target) if reserved
      end

      # @param target [CaptureTarget]
      # @return [void]
      def release_capture_target(target)
        @capture_mutex.synchronize do
          revoke_pending_capture_targets
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

        @capture_mutex.synchronize do
          revoke_pending_capture_targets
          entry = @capture_targets[target]
          entry[:item] if entry && entry[:open] && entry[:launch_uuid] == launch_uuid
        end
      end

      # @param target [CaptureTarget]
      # @param timeout [Numeric]
      # @return [Boolean]
      def close_capture_target(target, timeout: 5.0)
        deadline = monotonic_now + [timeout.to_f, 0].max
        @capture_close_requests << ->(candidate, _entry) { candidate.equal?(target) }
        with_capture_lock(deadline) do
          close_capture_targets_matching(deadline: deadline) do |candidate, _entry|
            candidate.equal?(target)
          end
        end
      end

      # @param item [ItemHandle]
      # @param timeout [Numeric]
      # @return [Boolean]
      def close_capture_target_for_item(item, timeout: 5.0)
        deadline = monotonic_now + [timeout.to_f, 0].max
        @capture_close_requests << ->(_target, entry) { entry[:item].equal?(item) }
        with_capture_lock(deadline) do
          close_capture_targets_matching(deadline: deadline) do |_target, entry|
            entry[:item].equal?(item)
          end
        end
      end

      # @param launch_uuid [String, nil]
      # @param timeout [Numeric]
      # @return [Boolean]
      def close_capture_targets(launch_uuid: nil, timeout: 5.0)
        deadline = monotonic_now + [timeout.to_f, 0].max
        @capture_close_requests << ->(_target, entry) { launch_uuid.nil? || entry[:launch_uuid] == launch_uuid }
        with_capture_lock(deadline) do
          close_capture_targets_matching(deadline: deadline) do |_target, entry|
            launch_uuid.nil? || entry[:launch_uuid] == launch_uuid
          end
        end
      end

      # @param item [ItemHandle]
      # @param launch_uuid [String]
      # @return [CaptureTarget, nil]
      def capture_target_for(item, launch_uuid:)
        @capture_mutex.synchronize do
          revoke_pending_capture_targets
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
      # @param deadline [Float] Absolute monotonic cutoff, including lock acquisition.
      # @return [Boolean]
      def close_capture_targets_matching(deadline:)
        revoke_pending_capture_targets
        selected = @capture_targets.select { |target, entry| yield(target, entry) }
        selected.each_value { |entry| entry[:open] = false }
        selected.each do |target, entry|
          while entry[:writers].positive?
            remaining = deadline - monotonic_now
            if remaining <= 0
              selected.each_key { |selected_target| @capture_targets.delete(selected_target) }
              return false
            end
            @capture_target_condition.wait(@capture_mutex, remaining)
          end
          @capture_targets.delete(target)
        end
        true
      end

      # Apply revocations even when a closing caller exhausted its lock budget.
      # @return [void]
      def revoke_pending_capture_targets
        loop do
          matches = @capture_close_requests.pop(true)
          @capture_targets.each do |target, entry|
            entry[:open] = false if matches.call(target, entry)
          end
        end
      rescue ThreadError
        nil
      end

      # @param deadline [Float]
      # @yield Execute capture bookkeeping within the caller's absolute budget.
      # @return [Boolean]
      def with_capture_lock(deadline)
        until @capture_mutex.try_lock
          remaining = deadline - monotonic_now
          return false if remaining <= 0

          sleep([remaining, 0.001].min)
        end
        begin
          yield
        ensure
          @capture_mutex.unlock
        end
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
        thread_state.fetch(:stack)
      end

      # @return [Hash]
      def thread_state
        state = @thread_state_mutex.synchronize do
          @thread_states.delete_if { |_key, entry| !execution_owner_alive?(entry) }
          entry = @thread_states[execution_key] ||= {
            thread: WeakRef.new(Thread.current), fiber: WeakRef.new(Fiber.current), state: empty_thread_state
          }
          entry.fetch(:state)
        end
        mirror_thread_state(state)
        state
      end

      # @return [Array<Integer>]
      def execution_key
        [Thread.current.object_id, Fiber.current.object_id]
      end

      # @param entry [Hash]
      # @return [Boolean]
      def execution_owner_alive?(entry)
        entry.fetch(:thread).alive? && entry.fetch(:fiber).alive?
      rescue WeakRef::RefError
        false
      end

      # @return [Hash]
      def empty_thread_state
        { stack: [], current_feature_key: nil, current_scenario_key: nil,
          current_scenario_item: nil, active_parent: nil }
      end

      # @param state [Hash]
      # @return [void]
      def mirror_thread_state(state)
        Thread.current[STACK_KEY] = state.fetch(:stack).dup
        Thread.current[:reportportal_cucumber_context_state] = state.reject { |key, _value| key == :stack }
      end

      # @param state [Hash]
      # @return [void]
      def finish_thread_state_access(state)
        mirror_thread_state(state)
        return unless state.fetch(:stack).empty? && state.values_at(:current_feature_key, :current_scenario_key,
                                                                   :current_scenario_item, :active_parent).all?(&:nil?)

        @thread_state_mutex.synchronize { @thread_states.delete(execution_key) }
      end

      # @return [void]
      def sync_active_parent_from_stack!
        state = thread_state
        state[:active_parent] = state.fetch(:stack).last
        finish_thread_state_access(state)
      end
    end
  end
end
