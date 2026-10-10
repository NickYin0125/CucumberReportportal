# frozen_string_literal: true

require "json"

Given('an M3B case {string} with amount {string}') do |case_name, amount|
  @m3b_case = { "case" => case_name, "amount" => amount }
  rp_log("M3B_CASE #{JSON.generate(@m3b_case)}", level: :info)
end

When("an M3B fail-once action runs") do
  marker = ENV.fetch("M3B_RETRY_MARKER")
  attempts = File.exist?(marker) ? File.read(marker).to_i : 0
  attempts += 1
  File.write(marker, attempts.to_s)
  rp_log("M3B_RETRY_ATTEMPT #{attempts}", level: :info)
  raise "M3B intentional first-attempt failure" if attempts == 1
end
