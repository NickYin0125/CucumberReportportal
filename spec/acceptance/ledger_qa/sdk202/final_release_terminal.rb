# frozen_string_literal: true

require_relative "final_release_common"

module FinalRelease202
  def self.terminal
    verify
    baseline = "3f20313c20b25071fbc49b31e1c6bc772bd599e4"
    directory = File.join(OUT, "terminal-baseline-source")
    raise "Baseline staging exists" if File.exist?(directory)
    FileUtils.mkdir_p(directory)
    archive, _, status = Open3.capture3("git", "-C", SDK, "archive", baseline, "lib", "reportportal-cucumber-ruby.gemspec")
    raise "Baseline export failed" unless status.success?
    _, _, status = Open3.capture3("tar", "-xf", "-", "-C", directory, stdin_data: archive)
    raise "Baseline unpack failed" unless status.success?
    results = [directory, SOURCE].map do |root|
      command(RbConfig.ruby, File.join(__dir__, "final_release_terminal_child.rb"), root, File.join(OUT, "fixtures-plain-v3"))
    end
    write(File.join(OUT, "terminal-compatibility.json"), baseline_sha: baseline, candidate_sha: SHA, results: results,
      stdout_equal: results.all? { |r| r[:exit] == 0 } && JSON.parse(results[0][:stdout])["stdout"] == JSON.parse(results[1][:stdout])["stdout"],
      scope: "F10/F11 terminal output from fresh recorded arguments; F12 emits no terminal line in native rp_evidence routing")
    puts JSON.generate(terminal: results.all? { |r| r[:exit] == 0 } && JSON.parse(results[0][:stdout])["stdout"] == JSON.parse(results[1][:stdout])["stdout"] ? "PASS" : "FAIL")
  end
end

FinalRelease202.terminal if $PROGRAM_NAME == __FILE__
