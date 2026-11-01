# frozen_string_literal: true

require_relative "final_wp5_driver"

pre_heads = { "2.0.1" => "d363c87a29dbaf7db1c02169ac3650d0cd3caa93", "1.3.2" => "7761384a682cbaac66e31a09a477342612c0debb" }
stamp = LedgerFinalWP5::STAMP
LedgerFinalWP5::LINES.each do |version, config|
  qa = "/Users/nick/Documents/crr-qa-#{version}"
  final = LedgerFinalWP5.guard(version)
  prefix = File.join(qa, "docs/reviews/assets", stamp, "backslash")
  pre = File.join(prefix, "pre-wp1-source")
  manifest = File.join(prefix, "pre-wp1-source.json")
  unless File.file?(manifest)
    FileUtils.mkdir_p(pre)
    archive = File.join(prefix, "pre-wp1-source.tar")
    raise "Archive failed" unless system("git", "-C", qa, "archive", "--format=tar", "--output", archive, pre_heads.fetch(version), "lib", "reportportal-cucumber-ruby.gemspec")
    raise "Extraction failed" unless system("tar", "-xf", archive, "-C", pre)
    LedgerFinalWP5.write(manifest, source_sha: pre_heads.fetch(version), meaning: "Immediate parent of WP1 displayed-location change; original feature tree, not QA HEAD",
      lib_sha256: Dir[File.join(pre, "lib/**/*.rb")].sort.to_h { |path| [path.delete_prefix(pre + "/"), Digest::SHA256.file(path).hexdigest] })
  end
  next if ARGV.first == "prepare"
  abort "Master must inject RP_API_KEY in the environment only" if ENV["RP_API_KEY"].to_s.empty?
  baseline = "/Users/nick/Documents/crr-qa-baseline-#{version == '1.3.2' ? '1.3.1' : '2.0.0'}"
  config[:cucumbers].each do |cucumber|
    ruby = config[:rubies].first
    { "baseline" => baseline, "pre-wp1" => pre, "final" => final }.each do |label, source|
      output = File.join(prefix, "c#{cucumber}-#{label}")
      tail = ["--transport", "live", "--mode", "plain", "--fixtures", "F14-negative", "--sdk-root", source,
        "--cucumber", cucumber, "--gem-path", "/bundle/ruby/#{ruby}.0", "--jpeg", LedgerFinalWP5::JPEG, "--output", output]
      args = LedgerFinalWP5.container(qa, final, version, ruby, cucumber, "isolated", tail, live: true)
      raise "Comparative capture failed; retain all output" unless LedgerFinalWP5.execute(qa, "backslash-#{cucumber}-#{label}", args)
    end
  end
end
