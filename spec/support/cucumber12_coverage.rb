# frozen_string_literal: true

require "coverage"
require "digest"
require "fileutils"
require "json"

if ENV["RP_QA_COVERAGE_DIR"]
  coverage_root = File.realpath(ENV.fetch("RP_QA_SOURCE_ROOT", File.expand_path("../..", __dir__)))
  compiled_hashes = {}
  compilation = TracePoint.new(:script_compiled) do |event|
    path = event.instruction_sequence.absolute_path
    next unless path && path.start_with?(File.join(coverage_root, "lib/")) && File.file?(path)

    compiled_hashes[File.realpath(path)] = Digest::SHA256.file(path).hexdigest
  end
  compilation.enable
  Coverage.start(lines: true) unless Coverage.running?
  coverage_process = Process.pid
  at_exit do
    if Process.pid == coverage_process && Coverage.running?
      compilation.disable
      root = coverage_root
      measured = Coverage.result.filter_map do |path, data|
        next unless File.file?(path) && File.realpath(path).start_with?(File.join(root, "lib/"))

        lines = data.fetch(:lines)
        [File.realpath(path).delete_prefix(root + "/"), {
          executable: lines.count { |count| !count.nil? },
          covered: lines.count { |count| count && count.positive? },
          sha256: Digest::SHA256.file(path).hexdigest,
          compiled_sha256: compiled_hashes[File.realpath(path)],
          lines: lines
        }]
      end.to_h
      directory = ENV.fetch("RP_QA_COVERAGE_DIR")
      FileUtils.mkdir_p(directory)
      File.write(File.join(directory, "#{Process.pid}.json"), JSON.pretty_generate(
        pid: Process.pid, program: $PROGRAM_NAME, ruby: RUBY_VERSION, root: root,
        cucumber: Gem.loaded_specs["cucumber"]&.version&.to_s, files: measured
      ) + "\n")
    end
  end
end
