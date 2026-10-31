#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "rubygems/package"
require "securerandom"
require "shellwords"
require "time"
require "timeout"
require_relative "cucumber12_cleanroom_config"

module Cucumber12Cleanroom
  ROOT = File.expand_path("../..", __dir__)
  EVIDENCE = File.join(ROOT, "tmp/cucumber12-independent/cleanroom")
  CASES = [
    ["tc17-ruby33", "ruby:3.3-slim", "install", "2.0.0", "12.0.1"],
    ["tc17-ruby34", "ruby:3.4-slim", "install", "2.0.0", "12.0.1"],
    ["tc18-ruby31", "ruby:3.1-slim", "resolve", "1.3.1", "9.2.1"],
    ["tc18-ruby33", "ruby:3.3-slim", "resolve", "2.0.0", "12.0.1"]
  ].freeze
  NOTICE = "Real Bundler resolution against an isolated PRIVATE candidate index containing both real packaged versions; NOT RubyGems publication or public-registry SDK selection."

  class Runner
    CONTAINER_FORMAT = '{"Id":{{json .Id}},"Name":{{json .Name}},"Image":{{json .Image}},"State":{{json .State}},"Mounts":{{json .Mounts}}}'
    IMAGE_FORMAT = '{"Id":{{json .Id}},"RepoDigests":{{json .RepoDigests}},"Architecture":{{json .Architecture}},"Os":{{json .Os}},"Size":{{json .Size}}}'
    RESOURCE_FORMAT = '{"ID":{{json .ID}},"Names":{{json .Names}},"Image":{{json .Image}},"State":{{json .State}}}'

    def initialize(config: Config.new)
      @config = config
      @run_id = "#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(3)}"
      @directory = File.join(EVIDENCE, @run_id)
      @prefix = "cucumber12-cleanroom-#{@run_id.downcase}"
      @network = "#{@prefix}-network"
      @owned = []
      @network_created = false
      @summary = { schema_version: 2, run_id: @run_id, started_at: Time.now.utc.iso8601, notice: NOTICE,
                   candidate_kind: @config.candidate_kind, cases: [], cleanup: [] }
      FileUtils.mkdir_p(@directory)
      @commands = File.join(@directory, "commands.jsonl")
    end

    def write_json(path, value)
      File.write(path, JSON.pretty_generate(value) + "\n")
    end

    def command(*argv, timeout: 60, allow_failure: false)
      started = Time.now.utc
      output = +""
      status = nil
      Open3.popen2e(*argv, pgroup: true) do |stdin, stdout, process|
        stdin.close
        reader = Thread.new { stdout.read }
        begin
          Timeout.timeout(timeout) { status = process.value }
        rescue Timeout::Error
          Process.kill("KILL", -process.pid)
          process.value
          raise "Host command exceeded #{timeout}s: #{Shellwords.join(argv)}"
        ensure
          output = reader.value
        end
      end
      File.open(@commands, "a") do |file|
        file.puts(JSON.generate(argv: argv, command: Shellwords.join(argv), started_at: started.iso8601,
                                seconds: Time.now.utc - started, exit: status.exitstatus, output: output))
      end
      unless status.success? || allow_failure
        raise "Command failed (#{status.exitstatus}): #{Shellwords.join(argv)}\n#{output[-12_000, 12_000] || output}"
      end
      [output, status.exitstatus]
    end

    def stage(label, versions: [])
      input = File.join(@directory, label, "inputs")
      output = File.join(@directory, label, "evidence")
      FileUtils.mkdir_p([input, output])
      %w[payload audit].each do |suffix|
        FileUtils.cp(File.join(__dir__, "cucumber12_cleanroom_#{suffix}.rb"), input)
      end
      staged = versions.to_h do |version|
        entry = @config.packages.fetch(version)
        destination = File.join(input, @config.filename(version))
        FileUtils.cp(entry.fetch(:path), destination)
        @config.verify_hash!(destination, entry.fetch(:sha256))
        File.chmod(0o444, destination)
        [File.basename(destination), entry.fetch(:sha256)]
      end
      write_json(File.join(input, "package-sha256.json"), staged)
      [input, output]
    end

    def environment
      ["HOME=/clean/home", "GEM_HOME=/clean/gems", "GEM_PATH=/clean/gems", "LANG=C.UTF-8",
       "PATH=/clean/gems/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
       "BUNDLE_IGNORE_CONFIG=true", "BUNDLE_APP_CONFIG=/clean/bundle-config", "BUNDLE_USER_HOME=/clean/bundler",
       "BUNDLE_SILENCE_ROOT_WARNING=1", "BUNDLE_JOBS=2", "BUNDLE_RETRY=1", "MAKEFLAGS=-j2",
       "DEBIAN_FRONTEND=noninteractive", "RP_ENABLED=false", "CUCUMBER_PUBLISH_QUIET=true", "NO_COLOR=1"]
    end

    def create(label, image, input, output, mode, *arguments)
      name = "#{@prefix}-#{label}"
      argv = ["docker", "create", "--name", name, "--label", "cucumber12.cleanroom.owner=#{@run_id}",
              "--network", @network, "--security-opt", "no-new-privileges=true", "--cpus", "2", "--memory", "1536m", "--pids-limit", "256",
              "--log-opt", "max-size=8m", "--log-opt", "max-file=1", "--workdir", "/work",
              "--mount", "type=bind,source=#{input},target=/inputs,readonly",
              "--mount", "type=bind,source=#{output},target=/evidence", "--entrypoint", "/usr/bin/env"]
      argv.concat(["--network-alias", "candidate-index"]) if mode == "registry"
      argv.concat([image, "-i", *environment, "ruby", "/inputs/cucumber12_cleanroom_payload.rb", mode, *arguments])
      command(*argv)
      @owned << name
      data = inspect_container(name)
      mounts = data.fetch("Mounts")
      raise "Unexpected volume/cache/project mount" unless mounts.size == 2 && mounts.all? { |m| m.fetch("Type") == "bind" }
      raise "Input mount is writable" if mounts.find { |m| m.fetch("Destination") == "/inputs" }.fetch("RW")
      write_json(File.join(output, "container-before.json"), data)
      name
    end

    def inspect_container(name)
      output, = command("docker", "inspect", "--format", CONTAINER_FORMAT, name)
      JSON.parse(output)
    end

    def resources
      output, = command("docker", "ps", "-a", "--no-trunc", "--filter", "name=reportportal-2607-",
                        "--filter", "name=rp2607-control-plane", "--format", RESOURCE_FORMAT)
      output
    end

    def remove(name)
      return unless @owned.include?(name)

      output, status = command("docker", "rm", "--force", name, allow_failure: true)
      @summary[:cleanup] << { container: name, exit: status, output: output }
      @owned.delete(name) if status.zero?
    end

    def inventory
      head, = command("git", "rev-parse", "HEAD")
      branch, = command("git", "branch", "--show-current")
      dirty, = command("git", "status", "--short")
      if @config.expected_source_head && head.strip != @config.expected_source_head
        raise "Wrong source revision"
      end
      raise "Wrong source branch" unless branch.strip == "codex/cucumber-12"

      @summary.merge!(source_head: head.strip, source_branch: branch.strip, status_before: dirty)
      @summary[:packages] = @config.manifest
      @summary[:images] = CASES.map { |item| item[1] }.uniq.to_h do |image|
        output, = command("docker", "image", "inspect", "--format", IMAGE_FORMAT, image)
        [image, JSON.parse(output)]
      end
      @summary[:resources_before] = resources
      @summary[:disk_before], = command("df", "-k", @directory)
      @summary[:harness_sha256] = Dir[File.join(__dir__, "cucumber12_cleanroom*.rb")].to_h do |path|
        [File.basename(path), Digest::SHA256.file(path).hexdigest]
      end
    end

    def run_case(item)
      label, image, mode, sdk, cucumber = item
      input, output = stage(label, versions: mode == "install" ? [sdk] : [])
      # Use the inspected immutable image ID, not a mutable tag between cases.
      name = create(label, @summary.fetch(:images).fetch(image).fetch("Id"), input, output, mode, sdk, cucumber,
                    @config.hashes.fetch(sdk))
      puts "#{label}: starting fresh #{image} (no inherited bundle, cache, lock or source tree)"
      command("docker", "start", name)
      waited, = command("docker", "wait", name, timeout: 1_200)
      logs, = command("docker", "logs", name)
      File.write(File.join(output, "container.log"), logs)
      write_json(File.join(output, "container-after.json"), inspect_container(name))
      result_path = File.join(output, "result.json")
      result = File.file?(result_path) ? JSON.parse(File.read(result_path)) : { "status" => "FAIL", "error" => "No result.json" }
      result["status"] = "FAIL" unless waited.strip == "0"
      result.merge!("case" => label, "image" => image, "container_exit" => waited.strip, "evidence" => output)
      @summary[:cases] << result
      puts "#{label}: #{result.fetch('status')}#{result['error'] ? ": #{result['error']}" : ''}"
    rescue StandardError => error
      @summary[:cases] << { "case" => label, "status" => "FAIL", "error" => "#{error.class}: #{error.message}" }
      warn "#{label}: FAIL: #{error.message}"
    ensure
      if name && @owned.include?(name)
        begin
          unless File.file?(File.join(output, "container.log"))
            logs, = command("docker", "logs", name, allow_failure: true)
            File.write(File.join(output, "container.log"), logs)
          end
          unless File.file?(File.join(output, "container-after.json"))
            write_json(File.join(output, "container-after.json"), inspect_container(name))
          end
        rescue StandardError => capture_error
          (@summary[:capture_errors] ||= []) << { container: name, error: capture_error.message }
        ensure
          remove(name)
        end
      end
      write_json(File.join(@directory, "summary.json"), @summary)
    end

    def run
      begin
        inventory
        command("docker", "network", "create", "--label", "cucumber12.cleanroom.owner=#{@run_id}", @network)
        @network_created = true
        input, output = stage("registry", versions: @config.packages.keys)
        registry = create("registry", @summary.fetch(:images).fetch("ruby:3.3-slim").fetch("Id"), input, output, "registry")
        command("docker", "start", registry)
        Timeout.timeout(40) do
          sleep 0.1 until File.file?(File.join(output, "ready.json"))
        end
        CASES.each { |item| run_case(item) }
      rescue StandardError => error
        @summary[:error] = "#{error.class}: #{error.message}"
        warn @summary[:error]
      ensure
        if registry
          logs, = command("docker", "logs", registry, allow_failure: true)
          File.write(File.join(@directory, "registry/evidence/container.log"), logs)
        end
        @owned.dup.reverse_each { |name| remove(name) }
        if @network_created
          output, status = command("docker", "network", "rm", @network, allow_failure: true)
          @summary[:cleanup] << { network: @network, exit: status, output: output }
        end
        @summary[:remaining_owned_resources], = command("docker", "ps", "-a", "--filter", "label=cucumber12.cleanroom.owner=#{@run_id}", "--format", "{{.Names}}")
        @summary[:remaining_owned_networks], = command("docker", "network", "ls", "--filter", "label=cucumber12.cleanroom.owner=#{@run_id}", "--format", "{{.Name}}")
        @summary[:resources_after] = resources
        @summary[:disk_after], = command("df", "-k", @directory)
        @summary[:package_hashes_after] = @config.packages.transform_values { |entry| Digest::SHA256.file(entry.fetch(:path)).hexdigest }
        @summary[:error] ||= "Source package changed during run" unless @summary[:package_hashes_after] == @config.hashes
        @summary[:finished_at] = Time.now.utc.iso8601
        %w[tc17 tc18].each do |id|
          cases = @summary[:cases].select { |item| item.fetch("case").start_with?(id) }
          @summary[id.upcase] = cases.size == 2 && cases.all? { |item| item.fetch("status") == "PASS" } ? "PASS" : "FAIL"
        end
        write_json(File.join(@directory, "summary.json"), @summary)
        write_json(File.join(EVIDENCE, @config.latest_pointer), run_id: @run_id, summary: File.join(@directory, "summary.json"))
        puts "TC17 #{@summary['TC17']}; TC18 #{@summary['TC18']}"
        puts NOTICE
        puts "Evidence: #{@directory}"
      end
      @summary["TC17"] == "PASS" && @summary["TC18"] == "PASS" && !@summary[:error] &&
        @summary[:remaining_owned_resources].empty? && @summary[:remaining_owned_networks].empty?
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    raise ArgumentError, "Usage: ruby #{$PROGRAM_NAME} [--preflight]" unless ARGV.empty? || ARGV == ["--preflight"]
    config = Cucumber12Cleanroom::Config.new
    if ARGV == ["--preflight"]
      puts JSON.pretty_generate(scope: "HOST PREFLIGHT ONLY: no containers, installs or TC17/18 rerun",
                                candidate_kind: config.candidate_kind, packages: config.manifest)
    else
      exit(Cucumber12Cleanroom::Runner.new(config: config).run ? 0 : 1)
    end
  rescue ArgumentError, SystemCallError, Gem::Package::Error => error
    warn "Preflight refused: #{error.message}"
    exit 2
  end
end
