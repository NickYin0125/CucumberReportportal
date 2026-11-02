# frozen_string_literal: true

require "json"

Given("final encoded probe {word}") do |id|
  inputs = JSON.parse(File.read(ENV.fetch("QA_FINAL_SECURITY_INPUTS")))
  probe = inputs.fetch("cases").find { |r| r.fetch("id") == id }
  raise "Unknown independent probe" unless probe
  LedgerDeveloper::Input.app_log(self) do
    AppLog.info(inputs.fetch("raw_curl"), report: true)
    AppLog.http(method: "GET", url: probe.fetch("url"), response: { status: 200, body: { outcome: "synthetic URL evidence only; no network request" } })
  end
  rp_evidence(action: "Final encoded #{id}", error: RuntimeError.new("synthetic encoded URL"), url: probe.fetch("url"), details: { api_key: "SECRET123" })
  error = RuntimeError.new(probe.fetch("message", "Final encoded #{id}"))
  error.set_backtrace([probe.fetch("url"), *inputs.fetch("safe_frames")])
  raise error
end
