# frozen_string_literal: true

require_relative "analyze"

STAMPS = %w[20261031T072147Z 20261031T173014Z 20261031T174824Z 20261031T180948Z].freeze

def html_payload(path)
  html = File.read(path)
  match = html.match(/window\.CUCUMBER_MESSAGES = (\[.*?\]);\s*<\/script>/m)
  raise "Official HTML message block missing" unless match
  # The official formatter escapes '<' as JavaScript \x3C inside JSON strings.
  json = match[1].gsub(/(?<!\\)((?:\\\\)*)\\x3C/) { "#{Regexp.last_match(1)}<" }
  [JSON.parse(json), Digest::SHA256.hexdigest(html.sub(match[1], "<NATIVE_ENVELOPES>"))]
end

def normalize_rows(rows)
  ids = {}
  rewrite = lambda do |value|
    case value
    when Hash
      value.to_h { |k, v| [k, %w[timestamp duration start finish].include?(k) ? "<runtime-clock>" : rewrite.call(v)] }
    when Array then value.map { |v| rewrite.call(v) }
    when String
      value.gsub(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i) { |id| ids[id] ||= "<generated-id-#{ids.length}>" }
    else value
    end
  end
  rewrite.call(rows)
end

%w[2.0.1 1.3.2].each do |version|
  root = "/Users/nick/Documents/crr-qa-#{version}"
  study = LedgerQAAnalysis::Study.new(root, STAMPS.first)
  facts = []
  paths = STAMPS.flat_map { |stamp| Dir["#{root}/docs/reviews/assets/ledger-qa-live/#{stamp}-*/**/native.ndjson"] }
  paths.select { |path| path.match?(/-rich(?:-|\/)/) }.sort.each do |rich|
    plain = rich.sub(/-rich(?=-|\/)/, "-plain")
    next unless File.file?(plain)
    original_html = [plain, rich].map { |path| path.sub("native.ndjson", "native.html") }
    html_files = original_html.map do |path|
      next path if File.file?(path)
      input = path.sub("native.html", "native.ndjson")
      generated = path.sub("native.html", "native-postprocessed.html")
      unless File.file?(generated)
        code = 'require "json"; require "cucumber/html_formatter"; File.open(ARGV[1], "w") { |out| Cucumber::HTMLFormatter::Formatter.new(out).process_messages(File.readlines(ARGV[0]).map { |line| JSON.parse(line) }) }; puts Gem.loaded_specs.fetch("cucumber-html-formatter").version'
        stdout, stderr, status = Open3.capture3("docker", "run", "--rm", "--network", "none",
          "-v", "#{root}:#{root}", "-v", "/private/tmp/ledger-matrix-bundles/ruby34:/bundle:ro",
          "-e", "GEM_HOME=/bundle/ruby/3.4.0", "-e", "GEM_PATH=/bundle/ruby/3.4.0", "ruby:3.4-slim",
          "ruby", "-e", code, input, generated)
        File.write(generated + ".provenance.json", JSON.pretty_generate(
          method: "Official native cucumber-html-formatter postprocessing of captured parallel-worker NDJSON, not an original CLI HTML report. Network disabled; no RP calls or credentials.",
          version: stdout.strip, exit: status.exitstatus, stderr: stderr, input: input,
          input_sha256: Digest::SHA256.file(input).hexdigest, output_sha256: File.file?(generated) && Digest::SHA256.file(generated).hexdigest) + "\n")
        raise "Official native HTML postprocess failed" unless status.success?
      end
      generated
    end
    ndjson = [plain, rich].map { |path| normalize_rows(File.readlines(path).map { |line| JSON.parse(line) }) }
    html = html_files.map { |path| html_payload(path) }
    html_models = html.map { |rows, template| [normalize_rows(rows), template] }
    fact = { criterion: "G12/P10.7", plain_ndjson: plain.delete_prefix(root + "/"), rich_ndjson: rich.delete_prefix(root + "/"),
      html_files: html_files.map { |path| path.delete_prefix(root + "/") },
      ndjson_equal: ndjson[0] == ndjson[1], html_models_equal: html_models[0] == html_models[1],
      html_matches_original_ndjson: html_models.each_with_index.all? { |(rows, _), index| rows == ndjson[index] },
      native_tier2_hits: ndjson[1].to_json.scan(/<details|<summary|<span style/),
      normalized_ndjson_sha256: ndjson.map { |rows| Digest::SHA256.hexdigest(JSON.generate(rows)) },
      native_html_template_sha256: html_models.map(&:last) }
    fact[:verdict] = fact.values_at(:ndjson_equal, :html_models_equal, :html_matches_original_ndjson).all? && fact[:native_tier2_hits].empty? ? "PASS" : "FAIL"
    facts << fact
    File.write("#{root}/docs/reviews/assets/ledger-qa-native-output-#{version}.json", JSON.pretty_generate(facts) + "\n")
  end
  puts JSON.generate(version: version, native_pairs: facts.length, failures: facts.select { |fact| fact[:verdict] != "PASS" })
end
