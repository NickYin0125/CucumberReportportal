# frozen_string_literal: true

require "spec_helper"
require "open3"
require_relative "../../examples/logger_parameters_demo"

RSpec.describe LoggerParametersDemo do
  it "reports only cases 02-06 and makes explicit report:false override legacy attach:true" do
    cases = described_class.cases(file: "tmp/evidence.txt")
    reporting = cases.each_index.select do |index|
      options = cases.fetch(index).fetch(:options)
      options[:report].nil? ? options.fetch(:attach, false) : options[:report]
    end

    expect(reporting.map { |index| index + 1 }).to eq((2..6).to_a)
    expect(cases.last.fetch(:options)).to include(attach: true, report: false, file: "tmp/evidence.txt")
  end

  it "runs real Cucumber offline, with compact terminal output and correctly attributed native evidence" do
    environment = ENV.keys.grep(/\A(?:RP_|CUCUMBER_)/).to_h { |key| [key, nil] }.merge(
      "RP_ENABLED" => "true", "RP_API_KEY" => "ignored-offline-canary", "NO_COLOR" => "1"
    )
    script = File.join(described_class::ROOT, "examples/logger_parameters_demo.rb")
    terminal, status = Open3.capture2e(environment, RbConfig.ruby, script, chdir: described_class::ROOT)

    expect(status.exitstatus).to eq(0), terminal
    expect(terminal).to include("Mode: offline", "Cucumber exit: 0")
    expect(terminal).not_to include("ignored-offline-canary", "[APPLOG]", "```json", '"order_id":')
    summaries = terminal.lines.grep(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}  INFO   /)
    expect(summaries.length).to eq(9)
    expect(summaries.count { |line| line.include?("(Attached to Report)") }).to eq(5)
    expect(summaries.last).to include("report:false overrides attach:true", "(json payload)")
    expect(summaries.last).not_to include("(Attached to Report)")

    directory = terminal.match(/^Reports: (.+)$/).captures.first
    messages = File.readlines(File.join(directory, "messages.ndjson")).map { |line| JSON.parse(line) }
    attachments = messages.filter_map { |entry| entry["attachment"] }
    logs = attachments.select { |entry| entry["mediaType"] == "text/x.cucumber.log+plain" }
    expect(logs.map { |entry| entry.fetch("body")[0, 2] }).to eq(%w[02 03 04 05 06])
    expect(logs[2].fetch("body")).to include("```json", JSON.pretty_generate(described_class::PAYLOAD))
    expect(logs[3].fetch("body")).to include("```json", JSON.pretty_generate(described_class::PAYLOAD))
    expect(logs.map { |entry| entry.fetch("testStepId") }.uniq.length).to eq(5)
    file = attachments.find { |entry| entry["fileName"] == "evidence.txt" }
    expect(file).to include("mediaType" => "text/plain", "testStepId" => logs.last.fetch("testStepId"))
    expect(attachments.length).to eq(6)
    file_bytes = file.fetch("contentEncoding") == "BASE64" ? Base64.strict_decode64(file.fetch("body")) : file.fetch("body")
    expect(file_bytes).to include("Order: ORD-123")
    expect(File.read(File.join(directory, "report.html"))).to include(JSON.generate("attachment" => file))
    expect(messages.any? { |entry| entry.dig("testRunFinished", "success") == true }).to eq(true)
    expect(JSON.parse(File.read(File.join(directory, "run.json")))).to include("mode" => "offline", "launch_name" => nil)
    expect(File.exist?(File.join(directory, "spool"))).to eq(false)
  end

  it "refuses live mode without credentials before creating artifacts or making a request" do
    environment = %w[RP_ENDPOINT RP_PROJECT RP_API_KEY].to_h { |key| [key, nil] }
    script = File.join(described_class::ROOT, "examples/logger_parameters_demo.rb")
    terminal, status = Open3.capture2e(environment, RbConfig.ruby, script, "--live", chdir: described_class::ROOT)

    expect(status.exitstatus).to eq(2)
    expect(terminal).to include("Live mode requires: RP_ENDPOINT, RP_PROJECT, RP_API_KEY")
    expect(terminal).not_to include("Reports:", "RP launch:")
  end
end
