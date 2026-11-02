# frozen_string_literal: true

require_relative "final_release_common"
require "base64"

module FinalRelease202
  def self.closeout
    proof = verify
    %w[plain rich].each do |mode|
      receipt = File.join(OUT, "p1-#{mode}/F16c/adapter-scope.json")
      next if File.file?(receipt)
      write(receipt, source_sha: SHA,
        native_classification: "N/A: Ruby raise requires an Exception; original unsupported classification preserved",
        scope: "Supplementary UNIT/protocol event-adapter replay only, not native Cucumber non-Exception execution",
        outcome: "Native Exception failure is unchanged; only the supplied formatter error-field shape is adapted")
    end
    preserved = JSON.parse(File.read(File.join(OUT, "preexisting-files.json")))
    working_scopes = %r{\A(?:spec/acceptance/ledger_qa/sdk202/(?:final_release_|release_perf_)|docs/reviews/assets/QA202-final-release-20261102-(?:visual|performance)/)}
    concurrent = preserved.select { |r| r["path"].match?(working_scopes) }
    originals = preserved - concurrent
    changed = originals.reject { |r| File.file?(File.join(QA, r["path"])) && Digest::SHA256.file(File.join(QA, r["path"])).hexdigest == r["sha256"] }
    write(File.join(OUT, "preservation-check-v2.json"), preexisting_files: originals.length, changed: changed.map { |r| r["path"] },
      excluded_concurrent_working_files: concurrent.map { |r| r["path"] },
      source_after_manifest_sha256: proof[:manifest_sha256], sdk_sha: SHA, scope: "Original captured QA files hashed only, never read for verdicts")
    raise "Preexisting evidence changed" unless changed.empty?
    report = File.join(QA, "docs/reviews/2026-11-02-final-release-contract-acceptance.md")
    scripts = Dir[File.join(__dir__, "final_release_*")].select { |p| File.file?(p) }.sort
    files = (Dir[File.join(OUT, "**/*")].select { |p| File.file?(p) } + scripts + [report]).uniq.sort
    protected_values = JSON.parse(File.read("/private/tmp/reportportal-2607-mYdyRWqN/credentials.json")).values.grep(String).reject { |s| s.empty? }
    protected_values << ENV["RP_API_KEY"] unless ENV["RP_API_KEY"].to_s.empty?
    hits = []
    jwt_files = []
    files.each do |file|
      bytes = File.binread(file)
      hits << file if protected_values.any? { |s| bytes.include?(s.b) }
      jwt_files << file if bytes.match?(/eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{20,}/n)
      if file.end_with?(".json", ".ndjson")
        parts = file.end_with?(".ndjson") ? File.readlines(file) : [bytes]
        parts.each do |part|
          parsed = JSON.parse(part) rescue next
          visit = lambda do |value|
            case value
            when Hash
              value.each do |key, data|
                if key.to_s.end_with?("base64") && data.is_a?(String)
                  raw = Base64.strict_decode64(data) rescue ""
                  hits << file if protected_values.any? { |s| raw.b.include?(s.b) }
                end
                visit.call(data)
              end
            when Array then value.each { |v| visit.call(v) }
            end
          end
          visit.call(parsed)
        end
      end
    end
    scan = { status: hits.empty? && jwt_files.empty? ? "PASS" : "FAIL", files: files.length,
      protected_value_hits: hits.uniq.map { |p| p.delete_prefix(QA + "/") }, jwt_candidate_files: jwt_files.uniq.map { |p| p.delete_prefix(QA + "/") },
      scope: "Exact protected local credential values and any inherited token; raw bytes and decoded JSON base64 fields; JWT-shaped token scan. No secret values recorded.",
      credentials_created: false, git_staging_performed: false, commits_performed: false }
    write(File.join(OUT, "secret-scan.json"), scan)
    raise "Secret scan needs investigation" unless scan[:status] == "PASS"
    digests = files.map { |p| { path: p.delete_prefix(QA + "/"), sha256: Digest::SHA256.file(p).hexdigest, bytes: File.size(p) } }
    write(File.join(OUT, "evidence-sha256.json"), files: digests, manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(digests)),
      excludes: "Self and subsequently written owned-files index; secret-scan content is independently inspectable")
    index = (files + %w[secret-scan.json evidence-sha256.json owned-files.json].map { |n| File.join(OUT, n) }).uniq.sort
    write(File.join(OUT, "owned-files.json"), files: index, count: index.length, git_instruction: "Master serializes staging/commit; only this exact list, never git add whole worktree")
    puts JSON.generate(secret_scan: scan[:status], owned_files: index.length, existing_evidence_unchanged: true, source_sha: SHA, commits: 0)
  end
end

FinalRelease202.closeout if $PROGRAM_NAME == __FILE__
