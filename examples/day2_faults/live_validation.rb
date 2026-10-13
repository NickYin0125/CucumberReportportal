# frozen_string_literal: true

require_relative "session"
require_relative "process_run"

module Day2Faults
  class LiveValidation
    attr_reader :results

    def initialize(upstream:, token:, directory:, project: "superadmin_personal", upstream_ip: nil)
      @upstream, @token, @directory, @project, @upstream_ip = upstream, token, directory, project, upstream_ip
      @results = []
    end

    def check(condition, message)
      raise "Day2 validation: #{message}" unless condition
    end

    def run
      scenario("slow", steps: [{ action: :slow, delay: 0.12 }]) do |session, result|
        session.emit("day2 slow marker")
        result[:receipt] = session.flush.to_h
        check(result[:receipt][:confirmed] == 1, "slow acknowledgement")
      end
      scenario("transient", steps: [{ action: :status, status: 503 }, { action: :status, status: 504 }]) do |session, result|
        session.emit("day2 retry marker", attachment: png)
        result[:receipt] = session.flush.to_h
        check(result[:receipt][:confirmed] == 1 && result[:receipt][:possible_duplicates] == 1, "transient receipt")
        requests = log_events(session)
        check(requests.length == 3 && requests.map { |event| event[:request_sha256] }.uniq.length == 1,
              "multipart retry bytes/owner UUID reuse")
      end
      [400, 401].each do |status|
        scenario("refusal-#{status}", steps: [{ action: :status, status: status }], repeat: true) do |session, result|
          session.emit("day2 refusal marker")
          result[:receipt] = session.flush.to_h
          check(result[:receipt][:failed] == 1 && result[:receipt][:spooled] == 1 && log_events(session).length == 1,
                "fail-fast refusal")
        end
      end
      scenario("disconnect", steps: [{ action: :disconnect }], repeat: true, retry_attempts: 2) do |session, result|
        session.emit("day2 disconnected marker")
        result[:receipt] = session.flush.to_h
        check(result[:receipt][:ambiguous] == 1 && result[:receipt][:spooled] == 1, "disconnect retention")
      end
      scenario("timeout", steps: [{ action: :timeout, delay: 1.2 }], retry_attempts: 1) do |session, result|
        session.emit("day2 timed-out marker")
        result[:receipt] = session.flush(timeout: 1.4).to_h
        check(result[:receipt][:ambiguous] == 1 && result[:receipt][:spooled] == 1, "timeout retention")
      end
      scenario("hidden-ack", steps: [{ action: :hidden_ack }], retry_attempts: 2) do |session, result|
        session.emit("day2 possibly duplicated marker")
        result[:receipt] = session.flush.to_h
        result[:accepted_but_hidden] = true
        check(result[:receipt][:confirmed] == 1 && result[:receipt][:possible_duplicates] == 1, "hidden ack duplicate risk")
      end
      scenario("partial-ack", steps: [{ action: :partial_ack, keep: 1 }]) do |session, result|
        session.emit("day2 known-confirmed sibling")
        session.emit("day2 uncertain sibling", attachment: png)
        result[:receipt] = session.flush.to_h
        result[:accepted_but_hidden] = true
        check(result[:receipt].values_at(:confirmed, :ambiguous, :spooled) == [1, 1, 1], "partial receipt")
        result[:spool_before_replay] = session.spool_evidence
        result[:guarded_replay] = session.replay(execute: true)
        check(result[:guarded_replay].first[:ambiguous] == 1, "uncertain replay requires explicit duplicate consent")
        result[:controlled_duplicate_replay] = session.replay(execute: true, allow_duplicates: true)
        check(result[:controlled_duplicate_replay].first[:confirmed] == 1, "controlled replay acknowledgement")
        before = session.proxy.seen
        result[:checkpoint_second_replay] = session.replay(execute: true, allow_duplicates: true)
        check(session.proxy.seen == before, "confirmed checkpoint resends")
      end
      scenario("durable-replay", steps: [{ action: :status, status: 400 }], retry_attempts: 1) do |session, result|
        session.emit("day2 durable artifact", attachment: png)
        result[:receipt] = session.flush.to_h
        result[:spool_before_replay] = session.spool_evidence
        artifact = result[:spool_before_replay].first.fetch(:artifacts).first
        check(artifact[:bytes] == Session::PNG.bytesize && artifact[:sha256] == Digest::SHA256.hexdigest(Session::PNG),
              "durable artifact bytes/SHA")
        result[:dry_replay] = session.replay
        result[:controlled_replay] = session.replay(execute: true)
        check(result[:controlled_replay].first[:confirmed] == 1, "original-owner replay")
        before = session.proxy.seen
        session.replay(execute: true)
        check(session.proxy.seen == before, "checkpoint confirmed resend")
      end
      scenario("finish-outage", scope: :finish, steps: [{ action: :status, status: 503 }], repeat: true,
               retry_attempts: 2) do |session, result|
        session.emit("day2 finish outage marker")
        result[:receipt] = session.flush.to_h
        begin
          session.finish(deadline: ReportportalCucumber::Service::ReportingDeadline.new(timeout: 0.2))
          check(false, "finish unexpectedly succeeded")
        rescue ReportportalCucumber::ReportingError => error
          result[:finish_error_class] = error.class.name
        end
        session.proxy.clear_faults!
        result[:owner_before_controlled_cleanup] = session.api.item_by_uuid(uuid: session.item)
        check(result[:owner_before_controlled_cleanup]["status"] == "IN_PROGRESS", "outage falsely finished owner")
      end
      scenario("expired-budget", steps: [{ action: :disconnect }], repeat: true) do |session, result|
        session.emit("day2 expired budget marker")
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result[:receipt] = session.queue.shutdown_receipt(
          timeout: 1, deadline: ReportportalCucumber::Service::ReportingDeadline.new(timeout: 0)
        ).to_h
        result[:flush_elapsed] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        check(result[:flush_elapsed] < 0.2 && result[:receipt][:timed_out] && !result[:receipt][:complete], "expired total budget")
      end
      scenario("bounded-queue", queue_max_records: 4, queue_max_bytes: 4096,
               steps: [{ action: :timeout, delay: 1.2 }], repeat: true, retry_attempts: 1) do |session, result|
        result[:admitted] = 100.times.count { |index| session.emit("#{index}:#{'x' * 800}") }
        result[:receipt] = session.queue.shutdown_receipt(timeout: 0.1).to_h
        result[:diagnostics] = session.queue.diagnostics
        check(result[:diagnostics][:peak_records] <= 4 && result[:diagnostics][:peak_bytes] <= 4096 &&
              result[:admitted] < 100, "queue bounds")
      end
      native("sigint", steps: [{ action: :status, status: 503 }])
      native("business_failure", steps: [{ action: :status, status: 401 }], strict: true)
      results
    end

    private

    def png = { name: "day2.png", mime: "image/png", bytes: Session::PNG }
    def log_events(session) = session.proxy.events.select { |event| event[:path].end_with?("/log") }

    def scenario(label, **options)
      directory = File.join(@directory, label)
      session = Session.new(upstream: @upstream, token: @token, project: @project, upstream_ip: @upstream_ip,
                            directory: directory, label: label, **options)
      result = { label: label, launch_name: session.name, launch_uuid: session.launch, item_uuid: session.item,
                 exactly_once: false, sigkill_pending_memory_guaranteed: false }
      begin
        yield session, result
        result[:spool_after] = session.spool_evidence
        result[:diagnostics] ||= session.queue.diagnostics
        # Never turn late workers into successful delivery: snapshot their final honest state.
        session.queue.shutdown_receipt(timeout: 0.05)
        result[:receipt_after_shutdown] = session.queue.reporting_receipt(finalization_complete: false).to_h
        session.proxy.clear_faults! if options[:scope] == :finish
        artifacts = { "transient" => 1, "partial-ack" => 2, "durable-replay" => 1 }.fetch(label, 0)
        result[:reconciliation_before_finish] = reconcile(session, expected_artifacts: artifacts)
        validate_reconciliation(label, result)
        session.finish(status: "FAILED")
        result[:launch_after_cleanup] = session.api.launch_by_uuid(uuid: session.launch)
        result[:item_after_cleanup] = session.api.item_by_uuid(uuid: session.item)
        check(result[:launch_after_cleanup]["status"] != "IN_PROGRESS" && result[:item_after_cleanup]["status"] == "FAILED",
              "controlled owner cleanup")
        result[:validated] = true
      rescue StandardError => error
        result[:validated] = false
        result[:error_class] = error.class.name
        result[:error] = error.message.gsub(@token, "[REDACTED]").slice(0, 2048)
        begin
          session.proxy.clear_faults!
          session.finish(status: "FAILED")
          result[:cleanup] = "finished original owner"
        rescue StandardError => cleanup
          result[:cleanup_error_class] = cleanup.class.name
        end
      ensure
        result[:proxy_events] = session.proxy.events
        write(File.join(directory, "result.json"), result)
        results << result
        session.close
      end
      puts "#{label}: validated=#{result[:validated]}"
    end

    def reconcile(session, expected_artifacts: 0)
      deadline = ReportportalCucumber::Service::ReportingDeadline.new(timeout: 3)
      item = session.api.item_by_uuid(uuid: session.item, deadline: deadline)
      client = ReportportalCucumber::Http::Client.new(config: session.config)
      query = URI.encode_www_form("filter.eq.item" => item.fetch("id"), "page.size" => 100, "page.page" => 1)
      polls = 0
      logs = nil
      loop do
        polls += 1
        body = client.get_json(path: "/api/v1/#{@project}/log?#{query}", deadline: deadline).body
        logs = body.fetch("content")
        break if logs.count { |log| log.dig("binaryContent", "id") } >= expected_artifacts || deadline.expired?
        # RP can expose the log before its asynchronously stored artifact link.
        sleep([0.05, deadline.remaining].min)
      end
      artifacts = logs.filter_map do |log|
        binary_id = log.dig("binaryContent", "id")
        next unless binary_id
        response = client.get_json(path: "/api/v1/data/#{@project}/#{URI.encode_www_form_component(binary_id.to_s)}",
                                   deadline: deadline)
        bytes = response.body
        check(bytes.is_a?(String), "binary download is not bytes")
        { log_id: log.fetch("id"), bytes: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes) }
      end
      { owner: item, logs: logs, artifacts: artifacts, visibility_polls: polls,
        original_owner: logs.all? { |log| log["itemId"].to_s == item.fetch("id").to_s } }
    end

    def validate_reconciliation(label, result)
      reconciliation = result.fetch(:reconciliation_before_finish)
      check(reconciliation[:original_owner], "RP log ownership")
      logs = reconciliation.fetch(:logs)
      expected = { "slow" => 1, "transient" => 1, "refusal-400" => 0, "refusal-401" => 0,
                   "disconnect" => 0, "timeout" => 0, "partial-ack" => 3, "durable-replay" => 1,
                   "finish-outage" => 1, "expired-budget" => 0, "bounded-queue" => 0 }
      check(logs.length == expected.fetch(label), "RP count #{label}: #{logs.length}") if expected.key?(label)
      if label == "hidden-ack"
        # Server deduplication is not assumed; report its observed behavior.
        check(logs.length >= 1, "hidden accepted upload unavailable")
        result[:observed_duplicate_logs] = [logs.length - 1, 0].max
      end
      if label == "partial-ack"
        check(logs.count { |log| log["message"] == "day2 known-confirmed sibling" } == 1, "known-confirmed sibling resent")
        result[:observed_duplicate_logs] = logs.count { |log| log["message"] == "day2 uncertain sibling" } - 1
      end
      if %w[transient partial-ack durable-replay].include?(label)
        check(!reconciliation[:artifacts].empty? && reconciliation[:artifacts].all? do |artifact|
          artifact[:bytes] == Session::PNG.bytesize && artifact[:sha256] == Digest::SHA256.hexdigest(Session::PNG)
        end, "RP artifact integrity")
      end
    end

    def native(mode, steps:, strict: false)
      directory = File.join(@directory, "native-#{mode}")
      proxy = FaultProxy.new(upstream: @upstream, steps: steps, repeat: true, upstream_ip: @upstream_ip)
      result = { label: "native-#{mode}", exactly_once: false }
      begin
        result[:process] = ProcessRun.run(endpoint: proxy.endpoint, directory: directory, mode: mode, token: @token,
                                         project: @project, strict: strict, flush_ms: 1000, deadline: 12)
        receipt = result[:process].fetch("receipt")
        check(!receipt.fetch("complete") && receipt.fetch("spooled").positive?, "native incomplete retention")
        check(result[:process].fetch("signal_to_exit") < 3, "SIGINT exit deadline") if mode == "sigint"
        if mode == "business_failure"
          check(result[:process]["exit"] == 1 && result[:process]["stdout"].include?("DAY2_ORIGINAL_BUSINESS_FAILURE"),
                "business failure was replaced")
        end
        proxy.clear_faults!
        config = ReportportalCucumber::Config.new(endpoint: proxy.endpoint, project: @project, api_key: @token,
                                                retry_attempts: 1, debug_curl_mode: false)
        client = ReportportalCucumber::Http::Client.new(config: config)
        query = URI.encode_www_form("filter.eq.name" => result[:process].fetch("launch_name"), "page.size" => 10)
        launches = client.get_json(path: "/api/v1/#{@project}/launch?#{query}").body.fetch("content")
        owner = launches.find { |launch| launch["name"] == result[:process].fetch("launch_name") }
        check(!owner.nil?, "native RP launch missing")
        query = URI.encode_www_form("filter.eq.launchId" => owner.fetch("id"), "page.size" => 100)
        items = client.get_json(path: "/api/v1/#{@project}/item?#{query}").body.fetch("content")
        result[:rp_launch] = owner
        result[:rp_items] = items
        check(owner["status"] == "FAILED" && items.none? { |item| item["status"] == "IN_PROGRESS" }, "native RP completion")
        result[:spool] = ReportportalCucumber::Service::SpoolStore.new(config: ReportportalCucumber::Config.new(
          endpoint: proxy.endpoint, project: @project, spool_dir: File.join(directory, "spool")
        )).transactions
        check(!result[:spool].empty?, "native durable transaction missing")
        result[:validated] = true
      rescue StandardError => error
        result[:validated] = false
        result[:error_class] = error.class.name
        result[:error] = error.message.gsub(@token, "[REDACTED]").slice(0, 2048)
      ensure
        result[:proxy_events] = proxy.events
        write(File.join(directory, "result.json"), result)
        results << result
        proxy.stop
      end
      puts "native-#{mode}: validated=#{result[:validated]}"
    end

    def write(path, value) = Day2Faults.write_evidence(path, value, token: @token)
  end
end
