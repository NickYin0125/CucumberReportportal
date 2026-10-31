# frozen_string_literal: true

require "base64"
require "digest"
require "json"
require "reportportal_cucumber"

module Cucumber12LiveFixture
  PNG = Base64.strict_decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nXxkAAAAASUVORK5CYII=").b.freeze
  class << self
    attr_accessor :final_audit
  end
end

at_exit { Cucumber12LiveFixture.final_audit&.call }

class Cucumber12LiveAudit
  def initialize(config)
    runtime = ReportportalCucumber.current_runtime
    events = []
    pickle_tables = []
    config.on_event(:test_step_created) do |event|
      argument = event.pickle_step.argument
      table = argument&.data_table
      if table
        pickle_tables << { text: event.pickle_step.text, rows: table.rows.map { |row| row.cells.map(&:value) } }
      end
    end
    config.on_event(:test_step_started) do |event|
      events << { event: "step_started", at: Process.clock_gettime(Process::CLOCK_MONOTONIC),
                  native_id: event.test_step.id, hook: event.test_step.hook? }
    end
    config.on_event(:test_run_finished) do
      events << { event: "run_finished", at: Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    end
    config.on_event(:test_run_hook_started) do |event|
      events << { event: "run_hook_started", at: Process.clock_gettime(Process::CLOCK_MONOTONIC), hook: event.hook.name }
    end
    config.on_event(:test_run_hook_finished) do
      events << { event: "run_hook_finished", at: Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    end
    config.on_event(:test_step_finished) do
      exit(7) if ENV["C12_LIVE_FORCE_EXIT"] == "true"
    end
    Cucumber12LiveFixture.final_audit = lambda do
      root = ENV.fetch("C12_LIVE_EVIDENCE")
      worker = ENV.fetch("TEST_ENV_NUMBER", "single")
      diagnostics = runtime.reporting_diagnostics
      data = { pid: Process.pid, worker: worker, receipt: runtime.reporting_receipt.to_h,
               diagnostics: diagnostics, events: events, native_pickle_tables: pickle_tables,
               package_sha256: ENV.fetch("C12_PACKAGE_SHA256"),
               sdk: Gem.loaded_specs.fetch("reportportal-cucumber-ruby").full_gem_path,
               cucumber: Gem.loaded_specs.fetch("cucumber").version.to_s,
               loaded_sdk_files: $LOADED_FEATURES.grep(%r{/reportportal_cucumber(?:/|\.rb)}),
               afterall: File.file?(File.join(root, "afterall-called.json")) ? JSON.parse(File.read(File.join(root, "afterall-called.json"))) : nil,
               reportportal_threads: Thread.list.select { |thread| thread.name.to_s.start_with?("reportportal") }.map do |thread|
                 { name: thread.name, alive: thread.alive?, status: thread.status }
               end }
      File.write(File.join(root, "worker-#{worker}.json"), JSON.pretty_generate(data) + "\n")
    end
  end
end

AfterAll(name: "independent late AfterAll delivery") do
  if ENV["C12_LIVE_AFTERALL"] == "true"
    File.write(File.join(ENV.fetch("C12_LIVE_EVIDENCE"), "afterall-called.json"),
               JSON.generate(at: Process.clock_gettime(Process::CLOCK_MONOTONIC)))
    log("TC15 AFTERALL delayed final log")
  end
end

Before("@tc16") { log("TC16 BEFORE worker=#{ENV.fetch('TEST_ENV_NUMBER')}") }
After("@tc16") { log("TC16 AFTER worker=#{ENV.fetch('TEST_ENV_NUMBER')}") }

Given("I emit rapid record {int}") do |number|
  log("TC15 rapid record #{number}")
  if number <= 10
    bytes = ENV["C12_PNG_DIR"] ? File.binread(File.join(ENV.fetch("C12_PNG_DIR"), format("screenshot-%02d.png", number))) : Cucumber12LiveFixture::PNG
    attach(bytes, "image/png", "tc15-#{number}.png")
  end
end

Given("I emit worker {int} record {int}") do |feature, number|
  log("TC16 feature=#{feature} record=#{number} worker=#{ENV.fetch('TEST_ENV_NUMBER')}")
  screenshots = feature.even? ? 3 : 2
  if number <= screenshots
    index = [0, 0, 2, 5, 7].fetch(feature) + number
    bytes = ENV["C12_PNG_DIR"] ? File.binread(File.join(ENV.fetch("C12_PNG_DIR"), format("screenshot-%02d.png", index))) : Cucumber12LiveFixture::PNG
    attach(bytes, "image/png", "tc16-#{feature}-#{number}.png")
  end
  sleep 0.02
end

Given("I publish visible media fixture") do
  attach(File.binread(File.join(ENV.fetch("C12_PNG_DIR"), "screenshot-01.png")), "image/png", "visible-fixture.png")
  attach("Visible synthetic plain-text acceptance fixture.\nSecond line retained.\n", "text/plain", "visible-fixture.txt")
  attach(JSON.generate(source: "independent acceptance", synthetic: true, values: [1, true, nil]), "application/json", "visible-fixture.json")
end

Given("I publish text with a NUL byte") do
  attach("minimal\0NUL payload\n".b, "text/plain", "nul-repro.txt")
end

Given("I publish a native NUL log") do
  log("native log\0NUL message\n")
end

Given("I show combined {string}:") do |order, document|
  raise "Unexpected combined order" unless %w[doc-first table-first].include?(order)
  raise "Executed DocString changed" unless document == "CONSTANT_DOC"
end
