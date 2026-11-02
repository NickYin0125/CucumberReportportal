# frozen_string_literal: true

require_relative "../../../script/acceptance/presentation_ledger_developer/support"

BeforeAll { log("QA parallel BeforeAll") }
AfterAll { log("QA parallel AfterAll") }
Before do
  File.write(File.join(ENV.fetch("QA_PARALLEL_BARRIER"), "ready-#{ENV.fetch('TEST_ENV_NUMBER')}"), Process.pid.to_s)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
  until Dir[File.join(ENV.fetch("QA_PARALLEL_BARRIER"), "ready-*")].length == 4
    raise "QA parallel barrier timeout" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    sleep 0.02
  end
  log("QA parallel Before #{ENV.fetch('TEST_ENV_NUMBER')}")
end
After { log("QA parallel After #{ENV.fetch('TEST_ENV_NUMBER')}") }
AfterStep { log("QA parallel AfterStep #{ENV.fetch('TEST_ENV_NUMBER')}") }

Given("QA parallel worker {int}") do |worker|
  LedgerDeveloper::Input.record("parallel_worker", worker: worker, pid: Process.pid)
  log("QA parallel business #{worker}")
  LedgerDeveloper::Input.attachment(self, LedgerDeveloper::Input.png(worker), "image/png", "worker-#{worker}.png")
end
Then("QA parallel work is complete") { log("QA parallel complete #{ENV.fetch('TEST_ENV_NUMBER')}") }
