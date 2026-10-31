# frozen_string_literal: true

require_relative "../../spec/support/cucumber12_wire_server"
require_relative "../../spec/support/cucumber12_cli"

When("a native Cucumber 12 process runs the {string} contract case") do |tag|
  @cucumber12_server = Cucumber12QA::WireServer.new
  @cucumber12_result = Cucumber12QA.run(@cucumber12_server, fixture: "outcomes.feature", tags: "@#{tag}", label: "bdd")
end

Then("its native exit is {int} and ReportPortal scenario status is {string}") do |code, status|
  expect(@cucumber12_result.fetch("exit")).to eq(code), @cucumber12_result.fetch("stdout") + @cucumber12_result.fetch("stderr")
  scenarios = @cucumber12_result.fetch("wire").fetch("items").values.select { |item| item["type"] == "STEP" && item["hasStats"] }
  expect(scenarios.length).to eq(1)
  expect(scenarios.first.fetch("finish").fetch("status").upcase).to eq(status)
end

Then("its complete ReportPortal item tree has no wire violations") do
  state = @cucumber12_result.fetch("wire")
  expect(state.fetch("errors")).to eq([])
  expect(state.fetch("items").values).to all(include("finish" => a_kind_of(Hash)))
  expect(state.fetch("launches").values).to all(include("finish" => a_kind_of(Hash)))
  expect(@cucumber12_result.fetch("stderr")).not_to match(/terminated with exception|report_on_exception|reporting incomplete/i)
end

After("@cucumber12_cli") { @cucumber12_server&.stop }
