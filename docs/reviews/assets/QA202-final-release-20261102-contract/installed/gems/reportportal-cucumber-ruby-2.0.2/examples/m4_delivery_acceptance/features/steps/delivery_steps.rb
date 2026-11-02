# frozen_string_literal: true

require "base64"
require "json"
require_relative "../../png_fixture"

Given("the M4 acceptance evidence table") do |table|
  @m4_table = table.hashes
end

When("I emit the M4 JSON and screenshot evidence") do
  json = JSON.pretty_generate("acceptance" => "m4", "checks" => @m4_table)
  rp_log("M4 structured evidence\n\n```json\n#{json}\n```", level: :info, mirror: false)
  png = M4DeliveryPNG.bytes
  rp_attach(png, name: "m4-acceptance.png", mime: "image/png", message: "M4 screenshot fixture")
end

Then("the M4 passing business assertion holds") do
  expect(@m4_table).not_to be_empty
  expect(@m4_table.first).to include("check" => "ownership", "result" => "stable")
end

Then("the deliberate M4 business failure is raised") do
  raise "Deliberate M4 acceptance failure after evidence capture"
end
