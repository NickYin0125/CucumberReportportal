# frozen_string_literal: true

require "reportportal_cucumber"
require "reportportal_cucumber/service/spool_replay"
require "tmpdir"
require "base64"
require_relative "http"

module Day2Faults
  class Session
    PNG = Base64.strict_decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nXxkAAAAASUVORK5CYII=").b.freeze
    attr_reader :proxy, :config, :api, :queue, :store, :launch, :item, :name, :directory

    def initialize(upstream:, token: "local-synthetic", project: "day2", steps: [], scope: :logs,
                   repeat: false, directory: nil, upstream_ip: nil, **options)
      @directory = directory || Dir.mktmpdir("day2-fault-")
      @name = "day2-fault-#{options.delete(:label) || scope}-#{SecureRandom.hex(6)}"
      @proxy = FaultProxy.new(upstream: upstream, steps: steps, scope: scope, repeat: repeat,
                              upstream_ip: upstream_ip)
      @config = ReportportalCucumber::Config.new(
        endpoint: proxy.endpoint, api_key: token, project: project, spool_dir: File.join(@directory, "spool"),
        retry_attempts: 3, retry_base_interval: 0.01, retry_max_interval: 0.01,
        flush_interval: 10, batch_size_logs: 4, batch_max_bytes: 256 * 1024,
        queue_max_records: 16, queue_max_bytes: 512 * 1024, spool_max_bytes: 2 * 1024 * 1024,
        exit_flush_timeout_ms: 1500, open_timeout: 1, read_timeout: 1, write_timeout: 1,
        debug_curl_mode: false, **options
      )
      @api = ReportportalCucumber::ReportPortal::API.new(config: config)
      @queue = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, video_uploader: nil)
      @store = ReportportalCucumber::Service::SpoolStore.new(config: config)
      @launch = api.start_launch(name: name, start_time: Time.now, description: "Day2 controlled upload faults",
                                attributes: [{ key: "validation", value: "day2-fault" }], mode: "DEFAULT",
                                rerun: false, rerun_of: nil, uuid: SecureRandom.uuid)
      @item = api.start_item(name: name, start_time: Time.now, type: "STEP", launch_uuid: launch,
                            has_stats: true, uuid: SecureRandom.uuid)
    rescue StandardError
      close rescue nil
      raise
    end

    def emit(message = "day2 evidence", attachment: nil)
      queue.emit_log(launch_uuid: launch, item_uuid: item, message: message, level: :info,
                     timestamp: Time.now, attachment: attachment)
    end

    def flush(timeout: 1.5, deadline: nil)
      queue.flush_receipt(timeout: timeout, deadline: deadline)
    end

    def replay(execute: false, allow_duplicates: false)
      replay = ReportportalCucumber::Service::SpoolReplay.new(store: store, config: config)
      store.transactions.map do |id|
        replay.run(transaction_id: id, execute: execute, allow_duplicates: allow_duplicates, timeout: 2)
      end
    end

    def spool_evidence
      store.transactions.map do |id|
        tx = store.load_transaction(id: id)
        { id: id, entries: tx.fetch(:entries), checkpoint: tx.fetch(:checkpoint), manifest: tx.fetch(:manifest),
          artifacts: tx.fetch(:files).map do |file|
            path = file.fetch(:path)
            { name: file.fetch(:name), bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest }
          end }
      end
    end

    def finish(status: "FAILED", deadline: nil)
      api.finish_item(item_uuid: item, launch_uuid: launch, end_time: Time.now, status: status, deadline: deadline)
      api.finish_launch(launch_uuid: launch, end_time: Time.now, status: status, deadline: deadline)
      @finished = true
    end

    def close
      queue&.shutdown_receipt(timeout: 0.1)
      proxy&.stop
    end
  end

  def self.write_evidence(path, value, token: nil)
    bytes = JSON.pretty_generate(value)
    raise "Credential present in evidence" if token && !token.empty? && bytes.include?(token)
    FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
    File.open(path, "wb", 0o600) { |file| file.write(bytes) }
  end
end
