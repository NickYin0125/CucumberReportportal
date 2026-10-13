# frozen_string_literal: true

When("I publish day2 evidence during a business action") do
  $day2_formatter = ReportportalCucumber.current_runtime
  rp_log("day2 native first marker", mirror: false)
  rp_attach(Day2Faults::Session::PNG, name: "native.png", mime: "image/png")
  if $day2_mode == "sigint"
    puts "DAY2_SIGNAL_READY"
    STDOUT.flush
    sleep 0.3
  end
  raise "DAY2_ORIGINAL_BUSINESS_FAILURE" if $day2_mode == "business_failure"
end

Then("I publish the second day2 marker") do
  rp_log("day2 native second marker", mirror: false)
end

AfterAll do
  $day2_after_all_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
