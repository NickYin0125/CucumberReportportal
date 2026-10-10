# frozen_string_literal: true

Given('an M3C attribute case {string}') do |case_name|
  rp_log("M3C_CASE #{case_name}", level: :info)
end

When("an M3C fail-once action runs") do
  marker = ENV.fetch("M3C_RETRY_MARKER")
  attempts = File.exist?(marker) ? File.read(marker).to_i : 0
  attempts += 1
  File.write(marker, attempts.to_s)
  rp_log("M3C_RETRY_ATTEMPT #{attempts}", level: :info)
  raise "M3C intentional first-attempt failure" if attempts == 1
end
