# frozen_string_literal: true

require_relative "focused_50b"

directory = File.join(Ledger202Focused50b::OUTPUT, "security-offline-proof")
raise "Never overwrite a security observation" if File.exist?(directory)
probe = File.join(__dir__, "deferred_malformed_url_probe.rb")
probe_sha = Digest::SHA256.file(probe).hexdigest
Ledger202Focused50b.verify("candidate")
argv = ["docker", "run", "--rm", "--name", "ledger-qa202-deferred-offline", "--network", "none", "--cpus", "1", "--memory", "2g",
  "-v", "#{Ledger202Focused50b::SOURCE}:/qa202-sdk:ro", "-v", "#{probe}:/qa202-probe.rb:ro",
  "-e", "SDK202_RUNTIME_ROOT=/qa202-sdk", Ledger202Host::IMAGE, "ruby", "/qa202-probe.rb"]
output, errors, status = Open3.capture3(*argv)
FileUtils.mkdir_p(directory)
{ "stdout.json" => output, "stderr.log" => errors }.each do |name, bytes|
  File.open(File.join(directory, name), File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(bytes) }
end
Ledger202Focused50b.verify("candidate")
raise "Probe source changed" unless Digest::SHA256.file(probe).hexdigest == probe_sha
result = JSON.parse(output)
equivalent = result.fetch("results").fetch("shared_default") == result.fetch("results").fetch("fresh_injected")
expected_fields = { "shared_default" => %w[backtrace baseline], "fresh_injected" => %w[backtrace baseline] }
confirmed = status.exitstatus == 1 && result["status"] == "BLOCKED" && equivalent && result["leaked_fields"] == expected_fields && result["safe_frame_count"] == 62
supplied = File.binread(File.join(__dir__, "deferred_malformed_url_probe_failure.log"))
supplied_json = JSON.parse(supplied.sub(/\nBLOCKED:.*\z/m, ""))
same_fixture = result["fixture"] == supplied_json["fixture"]
raise "Restored fixture differs from supplied failure" unless same_fixture
record = {
  status: confirmed ? "BLOCKED_CONFIRMED_OFFLINE" : "UNEXPECTED_RESULT_REVIEW_REQUIRED",
  source_sha: Ledger202Focused50b::FINAL, source_directory: Ledger202Focused50b::SOURCE,
  source_proof: File.join(Ledger202Focused50b::WINDOW, "source-proof.json"),
  source_proof_sha256: Digest::SHA256.file(File.join(Ledger202Focused50b::WINDOW, "source-proof.json")).hexdigest,
  probe: probe, probe_sha256: probe_sha, image_id: Ledger202Host::IMAGE, command: argv,
  exit: status.exitstatus, signal: status.termsig, all_result_fields_equal: equivalent,
  leaked_fields: result["leaked_fields"], safe_frames: result["safe_frame_count"], same_restored_fixture: same_fixture,
  fixture_sha256: Digest::SHA256.hexdigest(JSON.generate(result["fixture"])),
  network: "none", RP_credentials_forwarded: false, RP_traffic: false, new_launches: [],
  actual_RP_exposure_observed: false, performance_timing: "NOT_COLLECTED",
  stdout_sha256: Digest::SHA256.hexdigest(output), stderr_sha256: Digest::SHA256.hexdigest(errors),
  owner_disposition: "Security fix explicitly deferred; release blocker retained regardless of performance"
}
Ledger202Host.write_new(File.join(directory, "result.json"), record)
puts JSON.generate(record.slice(:status, :source_sha, :exit, :all_result_fields_equal, :leaked_fields, :safe_frames, :RP_traffic, :performance_timing))
abort "Unexpected standalone probe result" unless confirmed
