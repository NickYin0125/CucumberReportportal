# frozen_string_literal: true

require_relative "final_wp5_analyze"

study = LedgerQAAnalysis::WP5Study.new("/Users/nick/Documents/crr-qa-2.0.1", LedgerWP5Context.stamp, "12.0.1")
a = { "key" => "sdk", "value" => "2.0.1", "system" => false }
b = { "key" => "ruby", "value" => "3.4.12" }
cases = [
  ["attribute multiset reordered without losing multiplicity", [a, a, b], [b, a, a], "PASS"],
  ["duplicate attribute lost", [a, a, b], [a, b], "FAIL"],
  ["system member lost", [a], [a.reject { |key, _| key == "system" }], "FAIL"],
  ["system member changed", [a], [a.merge("system" => true)], "FAIL"],
  ["attribute value changed", [a], [a.merge("value" => "wrong")], "FAIL"]
]
cases.each do |label, left, right, wanted|
  study.check("P10.7", "#{label} unchanged Launch metadata plain/rich", [["description", left]], [["description", right]], method: "C")
  raise "Comparator invariant failed: #{label}" unless study.checks.last[:verdict] == wanted
end
study.check("P10.7", "Submitted ordered attribute JSON bytes remain strict", JSON.generate([a, b]), JSON.generate([b, a]), method: "C")
raise "Ordered wire comparison lost order" unless study.checks.last[:verdict] == "FAIL"
puts JSON.generate(checks: cases.length + 1, failures: 0, attribute_multiplicity_and_all_keys_preserved: true, ordered_wire_bytes_strict: true)
