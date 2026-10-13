# frozen_string_literal: true

require_relative "tooling"

begin
  command, tag, commit, directory = ARGV
  unless ARGV.length == 4 && %w[build publish].include?(command)
    raise ReleaseTooling::Error, "Usage: ruby script/release/cli.rb build|publish TAG COMMIT OUTPUT_DIRECTORY"
  end

  source = ReleaseTooling::Source.new(root: File.expand_path("../..", __dir__), tag: tag, commit: commit)
  if command == "build"
    ReleaseTooling::Bundle.new(source, directory).build!
  else
    raise ReleaseTooling::Error, "GITHUB_TOKEN is required" if ENV["GITHUB_TOKEN"].to_s.empty?

    ReleaseTooling::Publisher.new(source, directory, repository: ENV.fetch("GITHUB_REPOSITORY")).publish!
  end
rescue ReleaseTooling::Error, KeyError, ArgumentError, JSON::ParserError, Psych::Exception, SystemCallError => e
  warn "Release blocked: #{e.message}"
  exit 1
end
