# frozen_string_literal: true

require "base64"
require "json"

module Cucumber12Fixture
  PNG = Base64.strict_decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nXxkAAAAASUVORK5CYII=").b.freeze
  TEXT = "native text\r\nsecond line\n\n".freeze
end

class Cucumber12EventAudit
  def initialize(config)
    events = []
    reporting = ReportportalCucumber.current_runtime
    receipt = ENV["QA_REPORTING_RECEIPT_PATH"]
    at_exit { File.write(receipt, JSON.generate(reporting.reporting_receipt.to_h)) } if receipt && reporting
    config.on_event(:attach_called) do |event|
      source = event.src.respond_to?(:read) ? "IO" : event.src.to_s
      events << { "class" => event.class.name, "base" => event.is_a?(Cucumber::Core::Event::Base),
                  "mime" => event.media_type, "filename" => event.filename,
                  "base64" => Base64.strict_encode64(source.b) }
    end
    config.on_event(:test_run_finished) do
      stream = config.out_stream
      stream.is_a?(String) ? File.write(stream, JSON.generate(events)) : stream.write(JSON.generate(events))
    end
  end
end

AfterAll { puts "QA_AFTERALL_LAST" }
AfterAll do
  puts "QA_AFTERALL_MIDDLE"
  raise "QA intentional AfterAll failure" if ENV["QA_AFTER_ALL_FAIL"] == "true"
end
AfterAll { puts "QA_AFTERALL_FIRST" }

Before do
  log("QA_BEFORE")
  attach("before hook\r\n", "text/plain", "before.txt")
end

Before("@qa_before_fail") { raise "QA intentional Before failure" }

After do
  log("QA_AFTER")
  attach("after hook\r\n", "text/plain", "after.txt")
end

After("@qa_after_fail") { raise "QA intentional After failure" }

AfterStep do
  log("QA_AFTERSTEP")
  attach("afterstep hook\r\n", "text/plain", "afterstep.txt")
end

AfterStep("@qa_afterstep_fail") { raise "QA intentional AfterStep failure" }

Around("@qa_around") do |scenario, block|
  log("QA_AROUND_BEFORE")
  raise "QA intentional Around before failure" if scenario.source_tag_names.include?("@qa_around_before_fail")

  block.call
  log("QA_AROUND_AFTER")
  raise "QA intentional Around after failure" if scenario.source_tag_names.include?("@qa_around_after_fail")
end

Given("QA passes") { log("QA_STEP_PASS") }
Given("QA fails") { raise "QA intentional step failure" }
Given("QA is pending") { pending("QA intentional pending") }
Given("QA is skipped") { skip_this_scenario }
Given("QA ambiguous phrase") { true }
Given(/^QA ambiguous (.+)$/) { |_phrase| true }
Given("QA feature background") { log("QA_FEATURE_BACKGROUND") }
Given("QA rule background") { log("QA_RULE_BACKGROUND") }

Given("QA native media") do
  log("QA_NATIVE_LOG exact message")
  attach(Cucumber12Fixture::PNG, "image/png", "native.png")
  attach(Cucumber12Fixture::TEXT, "text/plain", "native.txt")
end

Given("QA document for {string}:") do |name, document|
  raise "QA document not interpolated" unless JSON.parse(document) == { "name" => name, "value" => "A|B" }

  log("QA_DOC_#{name}")
end

Given("QA table for {string}:") do |name, table|
  raise "QA table not interpolated" unless table.raw == [%w[name value], [name, "line\nnext"]]

  log("QA_TABLE_#{name}")
end

Given("QA flaky {string}") do |label|
  $qa_attempts ||= Hash.new(0)
  $qa_attempts[label] += 1
  log("QA_RETRY_#{label}_#{$qa_attempts[label]}")
  attach("#{label}:#{$qa_attempts[label]}\r\n", "text/plain", "retry-#{label}.txt")
  raise "QA intentional first attempt #{label}" if $qa_attempts[label] == 1
end

Given("QA worker {string}") do |label|
  log("QA_WORKER_#{label}_#{ENV.fetch('TEST_ENV_NUMBER')}")
  attach("#{label}:#{ENV.fetch('TEST_ENV_NUMBER')}\r\n", "text/plain", "worker-#{label}.txt")
  sleep 0.15
end

Given("QA joined thread evidence") do
  Thread.new do
    log("QA_UNOWNED_CHILD_THREAD")
    attach("unowned child thread\r\n", "text/plain", "unowned-thread.txt")
  end.value
  log("QA_PARENT_THREAD_CONTINUES")
end
