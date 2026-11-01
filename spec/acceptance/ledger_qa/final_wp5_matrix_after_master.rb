# frozen_string_literal: true

require_relative "final_wp5_driver"

raise "Final matrix scheduling requires the frozen CI heads" unless LedgerFinalWP5::STAMP == "wp5-ci-final-20261101"
master = "/private/tmp/ledger-finalise-20261101-ci-diagnostics"
last = nil
loop do
  observations = LedgerFinalWP5::CELLS.map do |cell, version, _, _|
    path = File.join(master, cell, "result.json")
    next { cell: cell, status: "RUNNING_OR_QUEUED" } unless File.file?(path)
    data = JSON.parse(File.read(path))
    raise "Master matrix failed or belongs to a different head: #{cell}" unless data["status"] == "PASS" && data["source_head"] == LedgerFinalWP5::LINES.fetch(version).fetch(:sha)
    { cell: cell, status: data["status"], source_head: data["source_head"] }
  end
  if observations != last
    puts JSON.generate(scheduling_context_only: observations, developer_results_are_not_independent_proof: true)
    $stdout.flush
    last = observations
  end
  break if observations.all? { |row| row[:status] == "PASS" }
  sleep 30
end
LedgerFinalWP5.matrix
