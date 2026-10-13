# frozen_string_literal: true

require "json"
require "digest"
require "bigdecimal"
require "open3"
require "fileutils"

module Day2Endurance
  class InvariantError < StandardError; end

  def self.monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def self.check(name, condition)
    raise InvariantError, name unless condition
    session&.checks&.push(name)
    true
  end

  def self.check_minimum_logs(receipt:, iterations:)
    check("sustained confirmed AppLog minimum", receipt.fetch(:confirmed) >= iterations)
  end

  module ProcessProbe
    MAX_STATUS_BYTES = 16_384

    def self.read(platform: RUBY_PLATFORM, pid: Process.pid)
      if platform.include?("linux")
        status = File.open("/proc/#{Integer(pid)}/status", "rb") { |file| file.read(MAX_STATUS_BYTES) }
        rss = status&.match(/^VmRSS:\s+(\d+)\s+kB$/)&.captures&.first
        threads = status&.match(/^Threads:\s+(\d+)$/)&.captures&.first
        raise "Bounded Linux process metrics unavailable" unless rss && threads
        { rss_mb: Integer(rss) / 1024.0, process_threads: Integer(threads), source: "bounded /proc status" }
      elsif platform.include?("darwin")
        rss, _, status = Open3.capture3("ps", "-o", "rss=", "-p", pid.to_s)
        raise "Process RSS unavailable" unless status.success? && rss.strip.match?(/\A\d+\z/)
        threads, _, thread_status = Open3.capture3("ps", "-M", "-p", pid.to_s)
        raise "Process thread count unavailable" unless thread_status.success?
        { rss_mb: Integer(rss.strip) / 1024.0, process_threads: threads.lines.length - 1, source: "Darwin ps RSS and ps -M" }
      else
        raise "Process metrics unsupported on this platform"
      end
    end
  end

  def self.csv_rows(text)
    rows, row, cell, quoted = [], [], +"", false
    index = 0
    while index < text.length
      char = text[index]
      if char == '"'
        if quoted && text[index + 1] == '"'
          cell << '"'
          index += 1
        else
          quoted = !quoted
        end
      elsif char == "," && !quoted
        row << cell
        cell = +""
      elsif char == "\n" && !quoted
        row << cell.delete_suffix("\r")
        rows << row
        row, cell = [], +""
      else
        cell << char
      end
      index += 1
    end
    raise "Unterminated CSV quote" if quoted
    rows << (row << cell) unless row.empty? && cell.empty?
    rows
  end

  def self.json_value(value)
    case value
    when Hash
      value.to_h { |key, child| [key.to_s, json_value(child)] }
    when Array
      value.map { |child| json_value(child) }
    else
      value
    end
  end

  class << self
    attr_accessor :session, :formatter
  end

  class Session
    attr_reader :started, :samples, :checks, :artifacts, :directory, :target_seconds, :thresholds, :resource_result

    def initialize(directory:, target_seconds:, warmup: 120, rss_max_mb: 768, rss_slope_mb_min: 8, threads_max: 32)
      raise ArgumentError, "Resource thresholds must be finite and positive" unless [rss_max_mb, rss_slope_mb_min].all? { |value| value.finite? && value.positive? } && threads_max.positive?
      raise ArgumentError, "Warmup must be finite, nonnegative and shorter than acceptance" unless warmup.finite? && warmup >= 0 && (target_seconds.zero? || warmup < target_seconds)
      @directory = directory
      @target_seconds = target_seconds
      @started = Day2Endurance.monotonic
      @samples, @checks, @artifacts = [], [], []
      @thresholds = { warmup_seconds: warmup, rss_max_mb: rss_max_mb,
                      rss_slope_mb_min: rss_slope_mb_min, threads_max: threads_max }
    end

    def elapsed
      Day2Endurance.monotonic - started
    end

    def pace(iteration, iterations, began)
      deadline = began + [target_seconds - (began - started), 0].max * iteration / iterations
      remaining = deadline - Day2Endurance.monotonic
      sleep remaining if remaining.positive?
    end

    def sample(stage)
      process = ProcessProbe.read
      runtime = Day2Endurance.formatter
      diagnostics = runtime&.reporting_diagnostics || {}
      row = { elapsed_seconds: elapsed, stage: stage, pid: Process.pid,
              rss_mb: process.fetch(:rss_mb), process_threads: process.fetch(:process_threads),
              process_metrics_source: process.fetch(:source),
              ruby_threads: Thread.list.count(&:alive?), queue: diagnostics,
              receipt: runtime&.reporting_receipt&.to_h }
      samples << row
      File.open(File.join(directory, "metrics.ndjson"), "a", 0o600) { |file| file.puts(JSON.generate(row)) }
      if diagnostics.key?(:current_records)
        config = runtime.config
        Day2Endurance.check("queue record bound", diagnostics[:peak_records] <= config.queue_max_records)
        Day2Endurance.check("queue byte bound", diagnostics[:peak_bytes] <= config.queue_max_bytes)
      end
      row
    end

    def resource_checks
      post = samples.select { |row| row[:elapsed_seconds] >= thresholds[:warmup_seconds] }
      raise "Insufficient post-warmup metric samples" if post.size < 3
      xs = post.map { |row| row[:elapsed_seconds] / 60.0 }
      ys = post.map { |row| row[:rss_mb] }
      mean_x, mean_y = xs.sum / xs.size, ys.sum / ys.size
      denominator = xs.sum { |x| (x - mean_x)**2 }
      raise "Insufficient metric time span" unless denominator.positive?
      slope = xs.zip(ys).sum { |x, y| (x - mean_x) * (y - mean_y) } / denominator
      result = { post_warmup_samples: post.size, observed_rss_max_mb: ys.max,
                 observed_rss_slope_mb_min: slope, observed_threads_max: post.map { |row| row[:process_threads] }.max,
                 thresholds: thresholds, interpretation: "Bounded observation for this workload, not a universal zero-leak claim" }
      @resource_result = result
      Day2Endurance.check("post-warmup RSS maximum", ys.max <= thresholds[:rss_max_mb])
      Day2Endurance.check("post-warmup RSS trend", slope <= thresholds[:rss_slope_mb_min])
      Day2Endurance.check("post-warmup thread maximum", result[:observed_threads_max] <= thresholds[:threads_max])
      result
    end

    def artifact(path, owner_uuid:)
      record = { name: File.basename(path), path: path, bytes: File.size(path),
                 sha256: Digest::SHA256.file(path).hexdigest, owner_uuid: owner_uuid }
      artifacts << record
      record
    end
  end

  class PrivateOutput
    def initialize(io, bearer:)
      @io, @bearer = io, bearer
    end

    def write(value)
      text = value.to_s
      text = text.gsub(@bearer, "[REDACTED]") if @bearer && !@bearer.empty?
      @io.write(text)
    end

    def puts(*values)
      values.each { |value| write(value.to_s + "\n") }
    end

    def flush = @io.flush
    def close = flush
    def tty? = false
    def sync = @io.sync

    def sync=(value)
      @io.sync = value
    end

    def <<(value)
      write(value)
      self
    end

    def print(*values)
      values.each { |value| write(value) }
    end
  end

  # Independent decimal oracle; do not duplicate the server's Float arithmetic.
  def self.margin_oracle(payload)
    positions = payload[:positions] || payload[:trades] || []
    amount = positions.sum { |row| BigDecimal(row.fetch(:netNotional, row.fetch(:notional, 0)).to_s).abs }
    [amount / 10, BigDecimal("1000")].max.round(2)
  end

  def self.check_margin(payload, response)
    actual = BigDecimal(response.fetch("total_margin").to_s)
    expected = margin_oracle(payload)
    tolerance = [BigDecimal("0.01"), expected.abs * BigDecimal("1e-15")].max
    check("margin arithmetic and floor", actual.finite? && (actual - expected).abs <= tolerance)
    check("margin status", response["status"] == "CALCULATED")
    check("margin identifier", !response["margin_call_id"].to_s.empty?)
  end
end
