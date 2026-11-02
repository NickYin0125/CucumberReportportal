# frozen_string_literal: true

require_relative "final_release_common"
require "uri"

module FinalRelease202
  def self.decode(value)
    4.times { value = URI::DEFAULT_PARSER.unescape(value) }
    value
  end

  def self.security
    verify
    $LOAD_PATH.unshift(File.join(SOURCE, "lib"))
    require "reportportal_cucumber"
    require "reportportal_cucumber/automation/failure_redactor"
    require "reportportal_cucumber/automation/http_exchange"
    policy = Automation::EvidenceRedactor.new
    safe_frames = ["/project/FROZEN/support.rb:65:in 'inner_failure'", "/project/FROZEN/support.rb:59:in 'deep_failure'",
      "/project/FROZEN/support.rb:136:in 'step'", "/project/FROZEN/features/audit.feature:5:in 'failure'"] +
      Array.new(56) { |i| "/ruby/gems/cucumber/FROZEN/runner.rb:#{i + 1}:in 'run'" } + ["-e:1:in 'run'", "<internal:kernel>:90:in 'require'"]
    secret = "QA_FINAL_ENCODED_SECRET"
    cases = []
    ["password", "pass word", 'pass\u0077ord'].each do |key|
      ["", "[REDACTED]"].each do |prefix|
        (1..3).each do |layers|
          raw = JSON.generate(key => prefix + secret)
          layers.times { raw = raw.bytes.map { |b| format("%%%02X", b) }.join }
          { path: "https://example.test/#{raw}", query: "https://example.test/?#{raw}",
            fragment: "https://example.test/#x=#{raw}", malformed: "https://example.test/bad path##{raw}" }.each do |location, url|
            cases << { id: "encoded-#{cases.length}", key: key, prefix: prefix, layers: layers, location: location, url: url, secret: secret }
          end
        end
      end
    end
    (1..3).each do |layers|
      raw = "Bearer #{secret}"
      layers.times { raw = raw.bytes.map { |b| format("%%%02X", b) }.join }
      ["https://example.test/#{raw}", "https://example.test/?#{raw}", "https://example.test/bad path##{raw}"].each do |url|
        cases << { id: "bearer-#{cases.length}", layers: layers, url: url, secret: secret }
      end
    end
    results = cases.map do |input|
      url = input[:url]
      exchange = Automation::HttpExchange.new(method: "GET", url: url, response: { status: 200 })
      shared = Automation::FailureRedactor.new.redact(message: "request failed", frames: [url, *safe_frames]).to_h
      fresh = Automation::FailureRedactor.new(redactor: Automation::EvidenceRedactor.new).redact(message: "request failed", frames: [url, *safe_frames]).to_h
      channels = { redact_url: policy.redact_url(url), redact_text: policy.redact_text(url), failure: shared[:baseline],
        http_summary: exchange.summary, http_plain: exchange.to_markdown(presentation: "plain"), http_rich: exchange.to_markdown(presentation: "rich"),
        evidence: ReportportalCucumber::Service::EvidencePresenter.failure(action: "request", error: RuntimeError.new("request failed"), url: url).values.join("\n") }
      checks = { no_decoded_secret: channels.values.none? { |s| decode(s).include?(secret) }, shared_equals_fresh: shared == fresh,
        safe_62_frames_preserved: shared[:backtrace].split("\n").last(62) == safe_frames }
      { input: input, channels: channels, shared: shared, fresh: fresh, checks: checks, status: checks.values.all? ? "PASS" : "FAIL" }
    end
    original = File.join(__dir__, "deferred_malformed_url_probe.rb")
    deferred = command(RbConfig.ruby, original, env: { "SDK202_RUNTIME_ROOT" => SOURCE })
    write(File.join(OUT, "original-deferred-probe.json"), deferred.merge(script_sha256: Digest::SHA256.file(original).hexdigest, source_sha: SHA))
    write(File.join(OUT, "encoded-security-matrix.json"), source_sha: SHA, count: results.length, safe_frame_count: safe_frames.length,
      results: results, status: results.all? { |r| r[:status] == "PASS" } && deferred[:exit] == 0 ? "PASS" : "FAIL")
    live = [results[0], results[15], results[23], results[47], results[71], results[72], results[80]].map { |r| r[:input] }
    live.unshift(id: "original-deferred", url: "https://example.test/bad path#%7B%22pass%5Cu0077ord%22%3A%22FROZEN_FRAME_SECRET%22%7D",
      message: "request https://alice:FROZEN_MESSAGE_SECRET@example.test/path?token=FROZEN_MESSAGE_SECRET&count=12", secret: "FROZEN_FRAME_SECRET")
    write(File.join(OUT, "live-security-inputs.json"), cases: live, safe_frames: safe_frames,
      raw_curl: "curl --request GET 'https://api.example.test/words?token=SAFE_CURL_FIXTURE' --header 'Authorization: Bearer SAFE_CURL_FIXTURE'")
    puts JSON.generate(security: results.all? { |r| r[:status] == "PASS" } ? "PASS" : "FAIL", encoded_cases: results.length,
      original_deferred_exit: deferred[:exit], safe_frames: safe_frames.length)
  end
end

FinalRelease202.security if $PROGRAM_NAME == __FILE__
