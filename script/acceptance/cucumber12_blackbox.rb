# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "shellwords"
require "time"
require "timeout"
require_relative "../../spec/support/cucumber12_wire_server"

module Cucumber12Independent
  ROOT = File.expand_path("../..", __dir__)
  RUBY = ENV.fetch("C12_RUBY", RbConfig.ruby)
  DEPENDENCIES = ENV.fetch("C12_DEPENDENCIES", Gem.path.join(File::PATH_SEPARATOR))
  PACKAGE = File.expand_path(ENV.fetch("C12_PACKAGE", File.join(ROOT, "pkg/reportportal-cucumber-ruby-2.0.0.gem")))
  PACKAGE_HASH = ENV.fetch("C12_PACKAGE_SHA256", "68b1ab8889f1e3448f6809b498c0aa7ff9ef9a03f4f1f5ae6d4e01fe2f6d17b3")
  EVIDENCE = File.expand_path(ENV.fetch("C12_EVIDENCE_ROOT", File.join(ROOT, "tmp/cucumber12-independent/runtime")))
  SUPPORT = File.join(ROOT, "spec/acceptance/cucumber12_independent/support.rb")

  class Collector < Cucumber12QA::WireServer
    private

    def route(method, path, headers, raw, record)
      record["rawBodyBase64"] = Base64.strict_encode64(raw)
      record["contentType"] = headers["content-type"]
      super
    end
  end

  class Audit
    attr_reader :report

    def initialize
      @run_stamp = "audit-#{Time.now.utc.strftime('%Y%m%dT%H%M%S%6N')}-#{Process.pid}"
      @report = { "scope" => "independent installed-gem real Cucumber/HTTP TC01-14; not live RP",
                  "cohort" => @run_stamp,
                  "cases" => {}, "runs" => [], "hardGates" => {} }
    end

    def setup
      raise "candidate hash mismatch" unless Digest::SHA256.file(PACKAGE).hexdigest == PACKAGE_HASH

      FileUtils.mkdir_p(EVIDENCE)
      archive = File.join(EVIDENCE, "packages", PACKAGE_HASH, File.basename(PACKAGE))
      FileUtils.mkdir_p(File.dirname(archive))
      FileUtils.cp(PACKAGE, archive)
      raise "copied package hash mismatch" unless Digest::SHA256.file(archive).hexdigest == PACKAGE_HASH

      @gem_home = File.join(EVIDENCE, "installed", PACKAGE_HASH)
      environment = clean_environment.merge("GEM_HOME" => @gem_home, "GEM_PATH" => DEPENDENCIES)
      command = [RUBY, "-S", "gem", "install", "--local", archive, "--install-dir", @gem_home,
                 "--ignore-dependencies", "--no-document"]
      stdout, stderr, status = Open3.capture3(environment, *command)
      @report["installation"] = { "command" => command, "exit" => status.exitstatus, "stdout" => stdout,
                                  "stderr" => stderr, "packageSha256" => PACKAGE_HASH, "sourcePackage" => PACKAGE,
                                  "retainedArchive" => archive, "installedHome" => @gem_home }
      raise "isolated gem installation failed" unless status.success?

      @installed_lib = File.join(@gem_home, "gems/reportportal-cucumber-ruby-2.0.0/lib")
      write_json(File.join(EVIDENCE, "installation.json"), @report.fetch("installation"))
      self
    end

    def run_case(id)
      @current = { "id" => id, "status" => "PASS", "supportedContractStatus" => "PASS", "requestedGaps" => [],
                   "assertions" => [], "failures" => [], "runs" => [] }
      @report.fetch("cases")[id] = @current
      send(id.downcase)
    rescue StandardError => error
      @current.fetch("failures") << "verification exception: #{error.class}: #{error.message}\n#{error.backtrace.first(4).join("\n")}"
    ensure
      @current["status"] = "FAIL" unless @current.fetch("failures").empty?
      @current["supportedContractStatus"] = "FAIL" unless @current.fetch("failures").empty?
      persist
    end

    def run
      setup
      (1..14).each do |number|
        id = format("TC%02d", number)
        run_case(id)
        puts "#{id}: #{@current.fetch('status')} (#{@current.fetch('assertions').length} assertions)"
        @current.fetch("failures").each { |failure| puts "  #{failure}" }
      end
      finish
      @report
    end

    def finish
      runs = @report.fetch("runs")
      wire_runs = runs.reject { |run| run.fetch("control") }
      unfinished = wire_runs.flat_map do |run|
        [*run.fetch("wire").fetch("launches").values, *run.fetch("wire").fetch("items").values]
          .reject { |item| item["finish"] && item.fetch("finish")["status"] != "IN_PROGRESS" }
          .map { |item| { "run" => run.fetch("label"), "uuid" => item["uuid"] } }
      end
      exceptions = runs.select { |run| [run["stdout"], run["stderr"]].join("\n").match?(/terminated with exception|report_on_exception|Exception in thread|unhandled.*thread/i) }
      screenshots = @report.dig("cases", "TC09", "screenshots") || []
      @report["hardGates"] = {
        "noInProgress" => { "pass" => unfinished.empty?, "unfinished" => unfinished,
                            "launches" => wire_runs.sum { |run| run.fetch("wire").fetch("launches").size },
                            "items" => wire_runs.sum { |run| run.fetch("wire").fetch("items").size } },
        "noUnhandledThreadExceptions" => { "pass" => exceptions.empty?, "runCount" => runs.length,
                                            "runs" => exceptions.map { |run| run.fetch("label") }, "Thread.report_on_exception" => true },
        "tenDistinctScreenshots" => { "pass" => screenshots.length == 10 && screenshots.map { |row| row["sha256"] }.uniq.length == 10 &&
                                               screenshots.map { |row| row["itemUuid"] }.uniq.length == 10,
                                      "screenshots" => screenshots }
      }
      @report["result"] = @report.fetch("cases").length == 14 &&
                           @report.fetch("cases").values.none? { |row| row["status"] == "FAIL" } &&
                           @report.fetch("hardGates").values.all? { |row| row["pass"] } ? "SUPPORTED_CONTRACTS_PASS_WITH_REQUESTED_GAPS" : "FAIL"
      @report["fullLiteralAcceptance"] = false
      persist
      @report
    end

    private

    def clean_environment
      ENV.keys.grep(/\A(?:RP_|CUCUMBER_|BUNDLE_|BUNDLER_|INDEPENDENT_)/).to_h { |key| [key, nil] }.merge(
        "RUBYOPT" => nil, "RUBYLIB" => nil, "GEM_HOME" => @gem_home,
        "GEM_PATH" => [@gem_home, DEPENDENCIES].compact.join(File::PATH_SEPARATOR),
        "NO_COLOR" => "1", "CUCUMBER_PUBLISH_QUIET" => "true", "TEST_ENV_NUMBER" => nil
      )
    end

    def execute(label, feature, options: [], control: false, environment: {}, relative_path: "features/audit.feature")
      directory = File.join(EVIDENCE, @run_stamp, @current.fetch("id"), label)
      FileUtils.mkdir_p(File.join(directory, "artifacts"))
      path = File.join(directory, relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, feature)
      support_snapshot = File.join(directory, "support.rb")
      FileUtils.cp(SUPPORT, support_snapshot)
      support_sha256 = Digest::SHA256.file(support_snapshot).hexdigest
      boot = File.join(directory, "boot.rb")
      provenance = File.join(directory, "provenance.json")
      File.write(boot, <<~'RUBY')
        require "rubygems"
        require "json"
        Thread.report_on_exception = true
        gem "cucumber", "=12.0.1"
        gem "reportportal-cucumber-ruby", "=2.0.0" if ENV["C12_USE_SDK"] == "true"
        at_exit do
          data = { "ruby" => RUBY_VERSION, "reportOnException" => Thread.report_on_exception,
                   "gems" => Gem.loaded_specs.transform_values { |spec| { "version" => spec.version.to_s, "path" => spec.full_gem_path } },
                   "sdkFeatures" => $LOADED_FEATURES.grep(%r{/lib/reportportal_cucumber(?:/|\.rb)}) }
          File.write(ENV.fetch("INDEPENDENT_PROVENANCE"), JSON.pretty_generate(data))
        end
        load Gem.bin_path("cucumber", "cucumber", "12.0.1")
      RUBY
      collector = Collector.new
      env = clean_environment.merge(
        "INDEPENDENT_CALLS" => File.join(directory, "calls.ndjson"), "INDEPENDENT_ARTIFACTS" => File.join(directory, "artifacts"),
        "INDEPENDENT_PROVENANCE" => provenance, "C12_USE_SDK" => (!control).to_s, "RP_ENDPOINT" => collector.endpoint,
        "RP_PROJECT" => "qa", "RP_API_KEY" => Cucumber12QA::WireServer::TOKEN,
        "RP_LAUNCH" => "Independent #{label}", "RP_CLIENT_JOIN" => "false", "RP_RULE_SUITES" => "true",
        "RP_IDENTITY_STRATEGY" => "stable_v1", "RP_IDENTITY_ROOT" => directory,
        "RP_BATCH_SIZE_LOGS" => "1", "RP_FLUSH_INTERVAL" => "0.01", "RP_HTTP_RETRY_ATTEMPTS" => "1",
        "RP_EXIT_FLUSH_TIMEOUT_MS" => "5000", "RP_FAIL_ON_REPORTING_ERROR" => "true",
        "RP_REQUIRE_COMPLETE_REPORTING" => "true", "RP_SPOOL_DIR" => File.join(directory, "spool")
      ).merge(environment)
      args = ["--no-profile", "--backtrace"]
      args.concat(["--require", File.join(@installed_lib, "reportportal_cucumber.rb")]) unless control
      args.concat(["--require", support_snapshot, "--format", "progress", "--format", "IndependentRuntimeAudit", "--out", File.join(directory, "observer.out"),
                   "--format", "message", "--out", File.join(directory, "native.ndjson")])
      args.concat(["--format", "ReportPortal::Cucumber::Formatter", "--out", File.join(directory, "rp.out")]) unless control
      args.concat(options).push(path)
      command = [RUBY, boot, *args]
      started = Time.now.utc.iso8601(6)
      stdout = stderr = status = nil
      Open3.popen3(env, *command, chdir: directory, pgroup: true) do |input, output, errors, process|
        input.close
        readers = [Thread.new { output.read }, Thread.new { errors.read }]
        begin
          Timeout.timeout(40) { status = process.value }
        rescue Timeout::Error
          Process.kill("KILL", -process.pid)
          raise "native Cucumber exceeded 40 seconds"
        ensure
          stdout, stderr = readers.map(&:value)
        end
      end
      collector.stop
      collector_stopped = true
      result = { "label" => label, "case" => @current.fetch("id"), "control" => control, "command" => command,
                 "supportPath" => support_snapshot, "supportSha256" => support_sha256,
                 "started" => started, "exit" => status.exitstatus, "stdout" => stdout, "stderr" => stderr,
                 "directory" => directory, "featurePath" => path, "options" => options, "fixtureEnvironment" => environment,
                 "provenance" => read_json(provenance), "native" => read_lines(File.join(directory, "native.ndjson")),
                 "calls" => read_lines(File.join(directory, "calls.ndjson")), "wire" => collector.snapshot }
      File.write(File.join(directory, "stdout.txt"), stdout)
      File.write(File.join(directory, "stderr.txt"), stderr)
      write_json(File.join(directory, "wire.json"), result.fetch("wire"))
      write_json(File.join(directory, "run.json"), result)
      @report.fetch("runs") << result
      @current.fetch("runs") << File.join(directory, "run.json")
      check(result.dig("provenance", "ruby") == "3.4.2", "actual Ruby 3.4.2", label)
      %w[cucumber cucumber-core cucumber-gherkin cucumber-messages].zip(%w[12.0.1 20.0.0 42.0.1 34.2.1]).each do |name, version|
        check(result.dig("provenance", "gems", name, "version") == version, "actual #{name} #{version}", label)
      end
      sdk_features = result.fetch("provenance").fetch("sdkFeatures")
      check(control ? sdk_features.empty? : sdk_features.any? && sdk_features.all? { |file| file.start_with?(@installed_lib + "/") || file == File.join(@installed_lib, "reportportal_cucumber.rb") },
            control ? "control has no SDK loaded" : "all SDK code loaded from installed archive, not repository lib", label)
      sdk_spec = result.dig("provenance", "gems", "reportportal-cucumber-ruby")
      check(control ? sdk_spec.nil? : sdk_spec && sdk_spec["version"] == "2.0.0" && sdk_spec["path"] == File.dirname(@installed_lib),
            control ? "control does not activate SDK gem" : "activated SDK gemspec belongs to isolated installed package", label)
      check(result.dig("provenance", "reportOnException") == true, "thread exception reporting enabled", label)
      verify_wire(result) unless control
      result
    ensure
      collector&.stop unless collector_stopped
    end

    def check(condition, message, label = nil)
      @current.fetch(condition ? "assertions" : "failures") << [label, message].compact.join(": ")
      !!condition
    end

    def expect_exit(run, code)
      check(run.fetch("exit") == code, "native exit #{code}, got #{run.fetch('exit')}", run.fetch("label"))
    end

    def verify_wire(run)
      wire = run.fetch("wire")
      label = run.fetch("label")
      check(wire.fetch("errors").empty?, "HTTP collector accepted every request: #{wire.fetch('errors').inspect}", label)
      nodes = wire.fetch("launches").values + wire.fetch("items").values
      check(nodes.all? { |item| item["finish"] }, "every emitted launch/item has one terminal finish", label)
      check(nodes.none? { |item| item.dig("finish", "status") == "IN_PROGRESS" }, "no IN_PROGRESS", label)
      check(nodes.map { |item| item["uuid"] }.uniq.size == nodes.size, "UUID uniqueness", label)
      nodes.each do |item|
        next unless item["finish"]

        check(item.fetch("startTime").to_i <= item.fetch("finish").fetch("endTime").to_i && item.fetch("startSequence") < item.fetch("finishSequence"),
              "monotonic lifecycle #{item.fetch('uuid')}", label)
        next unless item["parentUuid"]

        parent = wire.fetch("items").fetch(item.fetch("parentUuid"))
        check(parent.fetch("startSequence") < item.fetch("startSequence") && item.fetch("finishSequence") < parent.fetch("finishSequence"),
              "child fully nested in parent lifecycle #{item.fetch('uuid')}", label)
      end
      wire.fetch("logs").each do |log|
        owner = log["itemUuid"] ? wire.fetch("items")[log["itemUuid"]] : wire.fetch("launches")[log["launchUuid"]]
        check(owner && owner["finish"] && owner.fetch("startSequence") < log.fetch("sequence") && log.fetch("sequence") < owner.fetch("finishSequence") &&
              owner.fetch("startTime").to_i <= log.fetch("time").to_i && log.fetch("time").to_i <= owner.fetch("finish").fetch("endTime").to_i,
              "log UUID/sequence/timestamp lies within open owner #{log['itemUuid'] || 'launch'}", label)
      end
    end

    def items(run)
      run.fetch("wire").fetch("items").values
    end

    def scenarios(run)
      items(run).select { |item| item["type"] == "STEP" && item["hasStats"] }
    end

    def actions(run)
      items(run).reject { |item| item["hasStats"] }
    end

    def logs(run, message = nil)
      rows = run.fetch("wire").fetch("logs")
      message ? rows.select { |log| log.fetch("message", "").include?(message) } : rows
    end

    def envelopes(run, key)
      run.fetch("native").filter_map { |entry| entry[key] }
    end

    def status(item)
      item.fetch("finish").fetch("status").upcase
    end

    def one_feature(body, tags: "", name: "Independent acceptance")
      "#{tags}\nFeature: #{name}\n#{body}"
    end

    def one_scenario(steps = 'Given independent pass "control"', tags: "", name: "Independent scenario")
      one_feature("  #{tags}\n  Scenario: #{name}\n    #{steps}\n")
    end

    def tc01
      feature = <<~GHERKIN
        @inherited_feature @component:payments
        Feature: Deep international settlement
          Feature description first line.
          Feature description second line.

          @inherited_rule
          Rule: Independent jurisdiction rule
            Rule description retained.

            @local_scenario
            Scenario: Description and parent ancestry
              Scenario description retained.
              Given independent pass "hierarchy"
      GHERKIN
      run = execute("deep-rule-metadata", feature, relative_path: "features/payments/settlement/international/deep.feature")
      expect_exit(run, 0)
      suites = items(run).select { |item| item["type"] == "SUITE" }
      scenario = scenarios(run).first
      rule = suites.find { |item| item["name"].include?("jurisdiction") }
      root = suites.find { |item| item["name"].include?("Deep international") }
      check(suites.length == 2 && scenarios(run).length == 1, "only Feature and Rule SUITEs, one stats STEP; directory depth is not fabricated suites")
      check(root && rule && rule["parentUuid"] == root["uuid"] && scenario["parentUuid"] == rule["uuid"], "URL/payload Feature > Rule > Scenario parent UUIDs")
      [[root, "Feature description first line.", "Feature description second line."], [rule, "Rule description retained."], [scenario, "Scenario description retained."]].each do |item, *texts|
        check(item && texts.all? { |text| item.fetch("description", "").include?(text) }, "descriptions retained: #{texts.join(' / ')}")
      end
      serialized = JSON.generate(scenario.fetch("attributes", []))
      native_tags = envelopes(run, "pickle").first.fetch("tags").map { |tag| tag.fetch("name") }
      %w[@inherited_feature @component:payments @inherited_rule @local_scenario].each { |tag| check(native_tags.include?(tag), "native Cucumber inherits tag #{tag}") }
      check(serialized == "[]", "documented default does not export arbitrary/inherited tags as RP attributes")
      @current["literalTagGap"] = "Arbitrary inherited @tags are present in native pickles, but not automatically exported as RP attributes; opt-in allowlisted @key:value is the documented RP contract"
      @current["status"] = "APPLICABILITY"
      @current["requestedGaps"] = ["Directory names are not RP SUITEs: only Feature and optional Rule are suites",
                                   "Arbitrary inherited tags are not automatically exported as RP attributes"]
      check(actions(run).all? { |action| action["parentUuid"] == scenario["uuid"] }, "Gherkin action noStats child of scenario")
      scoped = feature.sub("@inherited_feature @component:payments", "@inherited_feature @component:payments @team:global")
                      .sub("@inherited_rule", "@inherited_rule @owner:rule-owner")
                      .sub("@local_scenario", "@local_scenario @priority:high @team:scenario-team")
      enabled = execute("deep-rule-safe-attributes-enabled", scoped, relative_path: "features/payments/settlement/international/deep.feature",
                        environment: { "RP_SCENARIO_ATTRIBUTES_ENABLED" => "true" })
      expect_exit(enabled, 0)
      attributes = scenarios(enabled).first.fetch("attributes").to_h { |entry| [entry.fetch("key"), entry.fetch("value")] }
      check(attributes == { "component" => "payments", "team" => "scenario-team", "owner" => "rule-owner", "priority" => "high" }, "opt-in safe Feature/Rule/Scenario attributes inherit with later-scope override")
    end

    def tc02
      run = execute("background-two-scenarios", <<~GHERKIN)
        Feature: Independent Background
          Background: Common prerequisite
            Given independent background
          Scenario: First background owner
            Given independent pass "first"
          Scenario: Second background owner
            Given independent pass "second"
      GHERKIN
      expect_exit(run, 0)
      background = actions(run).select { |item| item["name"].include?("independent background") }
      check(scenarios(run).length == 2 && background.length == 2, "Background executes as a real action in both scenarios")
      check(background.map { |item| item["uuid"] }.uniq.length == 2 && background.map { |item| item["parentUuid"] }.sort == scenarios(run).map { |item| item["uuid"] }.sort, "Background action UUIDs and parents isolated")
      check(logs(run, "INDEPENDENT_BACKGROUND").map { |log| log["itemUuid"] }.sort == background.map { |item| item["uuid"] }.sort, "each Background log owns its own real action")
    end

    def tc03
      run = execute("outline-multiple-examples", <<~'GHERKIN')
        @outline_feature
        Feature: Independent multiple Examples
          @outline_tag
          Scenario Outline: Dataset <name>
            Outline description for <name>.
            Given independent document "<name>":
              """text/plain
              payload <name>
              line two
              """
            And independent table "<name>":
              | key    | value |
              | <name> | a\|b  |
            @examples_first @browser:firefox @layer:first
            Examples: Alpha collection
              | name  |
              | amber |
              | birch |
            @examples_second @browser:chromium @layer:second
            Examples: Beta collection
              | name  |
              | coral |
              | delta |
      GHERKIN
      expect_exit(run, 0)
      rows = scenarios(run)
      enabled_run = execute("outline-safe-attributes-enabled", File.read(run.fetch("featurePath")), environment: { "RP_SCENARIO_ATTRIBUTES_ENABLED" => "true" })
      expect_exit(enabled_run, 0)
      check(rows.length == 4 && rows.map { |item| item["uuid"] }.uniq.length == 4, "four independently identified expanded Examples")
      %w[amber birch coral delta].each do |name|
        row = rows.find { |item| item["name"].include?(name) }
        check(!!row, "expanded scenario name #{name}")
        next unless row

        check(JSON.generate(row["parameters"]).include?(name), "expanded parameter #{name}")
        attrs = scenarios(enabled_run).find { |item| item["name"].include?(name) }.fetch("attributes").to_h { |entry| [entry.fetch("key"), entry.fetch("value")] }
        own = %w[amber birch].include?(name) ? "examples_first" : "examples_second"
        other = own == "examples_first" ? "examples_second" : "examples_first"
        native_tags = envelopes(run, "pickle").find { |pickle| pickle["name"].include?(name) }.fetch("tags").map { |tag| tag.fetch("name") }
        check(native_tags.include?("@#{own}") && !native_tags.include?("@#{other}") && native_tags.include?("@outline_tag") && native_tags.include?("@outline_feature"), "native Examples tag inheritance/isolation #{name}")
        expected_attrs = own == "examples_first" ? { "browser" => "firefox", "layer" => "first" } : { "browser" => "chromium", "layer" => "second" }
        check(attrs == expected_attrs, "opt-in RP Examples safe-attribute isolation #{name}")
        check(row.fetch("attributes") == [], "default false does not export Examples tags #{name}")
        children = actions(run).select { |action| action["parentUuid"] == row["uuid"] }
        check(children.length == 2 && children.all? { |action| action["name"].include?(name) }, "expanded DocString/DataTable action names #{name}")
        check(children.any? { |action| action.fetch("description", "").include?("payload #{name}") } && children.any? { |action| action.fetch("description", "").include?("a") && action.fetch("description", "").include?("b") }, "argument descriptions retained #{name}")
      end
      check(rows.map { |item| item["testCaseId"] }.uniq.length == 4, "Examples have distinct stable test-case identities")
      @current["literalTagGap"] = "Native Examples tags are inherited and isolated; RP exports allowlisted key:value tags only with explicit opt-in, not arbitrary tag names"
      @current["status"] = "APPLICABILITY"
      @current["requestedGaps"] = ["RP Examples attributes support only opt-in allowlisted @key:value tags, not all literal arbitrary Examples tags"]
    end

    def tc04
      %w[doc-first table-first].each do |order|
        document = "      \"\"\"\n      INDEPENDENT_COMBINED_DOC\n      \"\"\"\n"
        table = "      | key | value |\n      | combined | retained |\n"
        combined = one_scenario("Given independent combined \"#{order}\":\n" + (order == "doc-first" ? document + table : table + document), name: "Combined #{order}")
        control = execute("combined-#{order}-upstream-control", combined, control: true)
        sdk = execute("combined-#{order}-installed-sdk", combined)
        retained = control.fetch("calls").any? { |row| row["kind"] == "combined" }
        native_arg = envelopes(control, "pickle").first.fetch("steps").first.fetch("argument")
        check(native_arg["docString"] && native_arg["dataTable"], "installed Gherkin42 grammar retains both arguments #{order}")
        check([native_arg.dig("docString", "argumentIndex"), native_arg.dig("dataTable", "argumentIndex")] == (order == "doc-first" ? [1, 2] : [2, 1]), "actual installed grammar argument order #{order}")
        check(sdk["exit"] == control["exit"], "SDK does not change native combined-argument exit #{order}")
        if control["exit"] == 0 && retained
          check(sdk.fetch("calls").any? { |row| row["kind"] == "combined" }, "runtime receives both positional arguments #{order}")
          description = actions(sdk).map { |row| row["description"].to_s }.join("\n")
          check(description.include?("INDEPENDENT_COMBINED_DOC") && description.include?("retained"), "RP description retains BOTH argument bodies #{order}")
          @current["applicability"] = "Installed Gherkin42.0.1 and Cucumber12.0.1 support both arguments; not an unsupported syntax claim"
        else
          check(control["exit"] != 0 && sdk["exit"] != 0, "unsupported combined arguments fail with formatter disabled too #{order}")
          check(control.fetch("stdout").include?("Your block takes 3 arguments, but the Regexp matched 2 arguments") && sdk.fetch("stdout").include?("ArityMismatchError"), "Core20 execution supplies only one multiline argument, not a grammar parse error #{order}")
          @current["status"] = "UNSUPPORTED"
          @current["supportedContractStatus"] = "NOT_APPLICABLE"
          @current["requestedGaps"] = ["Both multiline arguments parse but cannot both reach a Cucumber12.0.1 Ruby step definition"]
          @current["applicability"] = "Gherkin42.0.1 accepts both and records argumentIndex; Core20.0.0 supplies only one multiline argument. Cucumber12.0.1 execution fails identically without SDK (arity mismatch), so combined execution is UNSUPPORTED, not invalid grammar"
        end

        display_feature = combined.sub("independent combined ", "independent combined display ")
        display_control = execute("combined-#{order}-display-upstream-control", display_feature, control: true)
        display_sdk = execute("combined-#{order}-display-installed-sdk", display_feature)
        expect_exit(display_control, 0)
        expect_exit(display_sdk, 0)
        check(display_control.fetch("calls").any? { |row| row["kind"] == "combinedDisplay" }, "one-argument compatible real native definition executes #{order}")
        display_description = actions(display_sdk).map { |row| row["description"].to_s }.join("\n")
        check(display_description.include?("INDEPENDENT_COMBINED_DOC") && display_description.include?("retained"), "plain combined Step description displays BOTH DocString and DataTable #{order}")
        check(logs(display_sdk).any? { |row| row["message"].to_s.include?("INDEPENDENT_COMBINED_DOC") && row["message"].to_s.include?("retained") }, "plain combined rich log displays BOTH arguments #{order}")

        argument_body = order == "doc-first" ? document + table : table + document
        outline = one_feature("  Scenario Outline: Combined display #{order}\n    Given independent combined display \"#{order}\":\n" +
                              argument_body.sub("retained", "<value>") +
                              "    Examples: Table-only substitution\n      | value |\n      | TABLE_ONLY_AMBER |\n      | TABLE_ONLY_BIRCH |\n")
        outline_control = execute("combined-#{order}-outline-display-upstream-control", outline, control: true)
        outline_sdk = execute("combined-#{order}-outline-display-installed-sdk", outline)
        expect_exit(outline_control, 0)
        expect_exit(outline_sdk, 0)
        %w[TABLE_ONLY_AMBER TABLE_ONLY_BIRCH].each do |value|
          native_rows = envelopes(outline_control, "pickle").flat_map { |pickle| pickle.fetch("steps") }.map { |step| JSON.generate(step["argument"]) }
          check(native_rows.any? { |row| row.include?(value) && !row.include?("<value>") }, "native Gherkin expands table-only #{value} #{order}")
          scenario = scenarios(outline_sdk).find { |row| row.fetch("parameters").any? { |param| param["key"] == "value" && param["value"] == value } }
          action = scenario && actions(outline_sdk).find { |row| row["parentUuid"] == scenario["uuid"] }
          description = action && action.fetch("description", "")
          check(description && description.include?("INDEPENDENT_COMBINED_DOC") && description.include?(value) && !description.include?("<value>"),
                "combined Outline description interpolates source-fallback table #{value} #{order}")
          check(action && logs(outline_sdk).any? { |row| row["itemUuid"] == action["uuid"] && row["message"].to_s.include?(value) && !row["message"].to_s.include?("<value>") },
                "combined Outline rich log interpolates table #{value} #{order}")
        end
      end
      source_run = @report.fetch("runs").find { |run| run["case"] == "TC04" && run["control"] }
      parser = File.join(source_run.dig("provenance", "gems", "cucumber-gherkin", "path"), "lib/gherkin/parser.rb")
      @current["grammar"] = { "path" => parser, "sha256" => Digest::SHA256.file(parser).hexdigest,
                              "rules" => File.readlines(parser).grep(/StepArg :=|DataTableAndMaybeDocString :=|DocStringAndMaybeDataTable :=/).map(&:strip),
                              "issue" => "https://github.com/cucumber/common/issues/2315" }
    end

    def tc05
      { "undefined" => "Given independent nonexistent step", "pending" => "Given independent pending" }.each do |name, step|
        run = execute(name, one_scenario("#{step}\n    Then independent pass \"should-not-run\""))
        expect_exit(run, 1)
        check(scenarios(run).all? { |item| status(item) == "FAILED" }, "#{name} scenario FAILED without removed strict option")
        check(actions(run).map { |item| status(item) } == %w[FAILED SKIPPED], "#{name} action FAILED, following action SKIPPED")
        check(logs(run, "INDEPENDENT_PASS:should-not-run").empty?, "#{name} following step not executed")
        check(envelopes(run, "testStepFinished").any? { |row| row.dig("testStepResult", "status") == name.upcase }, "native #{name.upcase} observed")
      end
    end

    def tc06
      run = execute("ambiguous", one_scenario('Given independent ambiguous phrase'))
      expect_exit(run, 1)
      check(envelopes(run, "testStepFinished").any? { |row| row.dig("testStepResult", "status") == "AMBIGUOUS" }, "real native AMBIGUOUS")
      check(scenarios(run).all? { |item| status(item) == "FAILED" } && actions(run).all? { |item| status(item) == "FAILED" }, "ambiguous action and scenario FAILED")
      check(logs(run).any? { |row| row["message"].to_s.include?("Ambiguous") }, "ambiguity diagnostic retained")
    end

    def tc07
      run = execute("mixed-status-full-backtrace", <<~GHERKIN)
        Feature: Independent outcomes
          Scenario: Passed scenario
            Given independent pass "passed"
          Scenario: Failed then skipped
            Given independent fail
            Then independent pass "not-reached"
          Scenario: Explicitly skipped scenario
            Given independent skip
            Then independent pass "not-reached-either"
      GHERKIN
      expect_exit(run, 1)
      check(scenarios(run).map { |item| status(item) } == %w[PASSED FAILED SKIPPED], "scenario passed/failed/skipped mappings")
      check(actions(run).map { |item| status(item) } == %w[PASSED FAILED SKIPPED SKIPPED SKIPPED], "action passed/failed/skipped mappings")
      native = envelopes(run, "testStepFinished").find { |row| row.dig("testStepResult", "status") == "FAILED" }
      native_error = native && native.fetch("testStepResult").fetch("message", "")
      diagnostic = logs(run, "INDEPENDENT_FULL_BACKTRACE").find { |row| row["level"].to_s.upcase == "ERROR" }
      check(!!diagnostic, "native original business exception is an ERROR log")
      recorded = run.fetch("calls").find { |row| row["kind"] == "expectedBacktrace" }
      frames = recorded ? recorded.fetch("backtrace") : []
      check(frames.length > 10 && diagnostic && frames.all? { |frame| diagnostic.fetch("message").include?(frame) }, "full actual Ruby caller backtrace retained, #{frames.length} frames")
      check(native_error.to_s.include?("INDEPENDENT_FULL_BACKTRACE"), "native failure agrees with RP failure")
      check(logs(run, "INDEPENDENT_PASS:not-reached").empty?, "skipped steps do not create business logs")
    end

    def tc08
      run = execute("native-log-and-puts", one_scenario("Given independent native outputs\n    Then independent pass \"later-owner\""))
      expect_exit(run, 0)
      first_action = actions(run).find { |item| item["name"].include?("native outputs") }
      %w[INDEPENDENT_NATIVE_LOG_ONE INDEPENDENT_NATIVE_LOG_TWO].each do |message|
        matches = logs(run, message)
        check(matches.length == 1 && matches.first["itemUuid"] == first_action["uuid"], "#{message} once and native action owner")
        call = run.fetch("calls").find { |row| row["message"] == message && row["kind"] == "log" }
        check(matches.length == 1 && (matches.first.fetch("time").to_i - call.fetch("timeMs")).between?(0, 25), "#{message} preserves emission time (within 25ms)")
      end
      check(run.fetch("stdout").include?("INDEPENDENT_NATIVE_PUTS"), "real puts reaches stdout without Kernel interception")
      native_puts = envelopes(run, "attachment").select { |row| row["body"].to_s.include?("INDEPENDENT_NATIVE_PUTS") }
      check(native_puts.empty? && logs(run, "INDEPENDENT_NATIVE_PUTS").empty?, "native puts has no attachment event or RP log; no invented capture")
      @current["status"] = "APPLICABILITY"
      @current["requestedGaps"] = ["Ruby puts is stdout-only and has no native Cucumber attachment ownership or timestamp to export"]
      @current["applicability"] = "Native log is owned/timestamped; Ruby puts is stdout-only, not a Cucumber12 native log event"
    end

    def verify_media(run)
      expected = run.fetch("calls").select { |row| row["kind"] == "attachment" }
      expected.each do |row|
        matches = logs(run).select { |log| log.dig("wireFile", "name") == row["filename"] }
        check(matches.length == 1, "exactly one multipart upload #{row['filename']}", run["label"])
        next unless matches.length == 1

        log = matches.first
        bytes = Base64.strict_decode64(log.fetch("wireFile").fetch("base64"))
        owner = items(run).find { |item| item["uuid"] == log["itemUuid"] }
        check(Digest::SHA256.hexdigest(bytes) == row["sha256"] && log.dig("wireFile", "base64") == row["base64"], "exact bytes/SHA256, no double encoding #{row['filename']}", run["label"])
        check(log.dig("wireFile", "mime") == row["mime"], "normalized correct MIME #{row['filename']}", run["label"])
        check(!log.fetch("message", "").include?("\0"), "RP preview excludes PostgreSQL-incompatible NUL while attachment bytes remain exact #{row['filename']}", run["label"])
        check(owner && !owner["hasStats"] && owner["type"] == "STEP", "attachment owned by real noStats STEP #{row['filename']}", run["label"])
        if row["expectedStep"]
          check(owner && owner.fetch("name").include?(row.fetch("expectedStep")), "exact emitting action owns #{row['filename']}", run["label"])
        end
        if (match = row["filename"].match(/\Ascreenshot-(\d+)\.png\z/))
          number = Integer(match[1], 10)
          scenario = owner && items(run).find { |item| item["uuid"] == owner["parentUuid"] }
          check(owner && owner["name"] == "Given independent screenshot #{number}" && scenario && scenario["name"] == "Scenario: Screenshot owner #{number}", "screenshot #{number} UUID maps to its own exact step and scenario", run["label"])
        end
      end
      check(logs(run).count { |log| log["wireFile"] } == expected.length, "no orphan or duplicate media uploads", run["label"])
    end

    def tc09
      sources = %w[file path binread binary encoded plain_base64]
      body = sources.product(%w[png text json]).map do |source, kind|
        "  Scenario: #{source} #{kind}\n    Given independent media \"#{kind}\" as \"#{source}\"\n"
      end.join
      run = execute("native-media-supported-types", one_feature(body))
      expect_exit(run, 0)
      verify_media(run)
      @current["unsupportedContracts"] = []
      %w[stringio pipe].each do |source|
        feature = one_scenario("Given independent media \"png\" as \"#{source}\"")
        control = execute("media-#{source}-upstream-control", feature, control: true)
        sdk = execute("media-#{source}-installed-sdk", feature)
        check(control["exit"] != 0 && sdk["exit"] == control["exit"], "unsupported #{source} has same failure with formatter disabled")
        native_message = envelopes(control, "testStepFinished").map { |row| row.dig("testStepResult", "message").to_s }.join("\n")
        @current.fetch("unsupportedContracts") << { "source" => source, "controlExit" => control["exit"], "sdkExit" => sdk["exit"], "nativeMessage" => native_message }
      end
      feature = one_scenario('Given independent media "png" as "options_hash"')
      hash_control = execute("media-options_hash-upstream-control", feature, control: true)
      hash_sdk = execute("media-options_hash-installed-sdk", feature)
      native_attachment = envelopes(hash_control, "attachment").first
      uploaded = logs(hash_sdk).find { |log| log["wireFile"] }
      check(hash_control["exit"] == 0 && hash_sdk["exit"] == 0 && native_attachment["mediaType"].is_a?(Hash), "extra invalid Hash-media-type probe: upstream accepts but emits non-string schema field, not a valid Ruby native attach contract")
      check(uploaded && Base64.strict_decode64(uploaded.dig("wireFile", "base64")) == native_attachment["body"], "extra Hash-media-type probe preserves literal base64 text, not requested decoded PNG")
      @current["extraInvalidSignature"] = { "status" => "APPLICABILITY", "source" => "options_hash", "upstreamExit" => hash_control["exit"],
                                            "sdkExit" => hash_sdk["exit"], "nativeMediaType" => native_attachment["mediaType"],
                                            "finding" => "Ruby attach second positional argument is a MIME String, not JS-style options. Upstream does not reject the Hash at runtime; its message mediaType is a Hash and contentEncoding is IDENTITY. Not counted as a supported File/binary/base64 SDK regression." }
      shots = execute("ten-distinct-screenshots", one_feature((1..10).map { |number| "  Scenario: Screenshot owner #{number}\n    Given independent screenshot #{number}\n" }.join))
      expect_exit(shots, 0)
      verify_media(shots)
      @current["screenshots"] = logs(shots).filter_map do |log|
        next unless log["wireFile"]

        owner = items(shots).find { |item| item["uuid"] == log["itemUuid"] }
        { "filename" => log.dig("wireFile", "name"), "sha256" => Digest::SHA256.hexdigest(Base64.strict_decode64(log.dig("wireFile", "base64"))),
          "itemUuid" => log["itemUuid"], "scenarioUuid" => owner["parentUuid"], "launchUuid" => log["launchUuid"] }
      end
      check(@current.fetch("screenshots").map { |row| row["scenarioUuid"] }.uniq.length == 10, "10 PNG screenshots have 10 distinct scenario/action owners")
      @current["applicability"] = "File (not equivalent to arbitrary IO), path, File.binread, binary Strings supported; ;base64 decodes once; plain MIME preserves literal base64 text. Unsupported forms are controlled independently."
    end

    def tc10
      run = execute("failed-step-after-artifact", one_scenario("Given independent fail\n    Then independent pass \"unreached\"", tags: "@ind_failure_artifact"))
      expect_exit(run, 1)
      image = logs(run).find { |log| log.dig("wireFile", "name") == "after-failure.png" }
      owner = image && items(run).find { |item| item["uuid"] == image["itemUuid"] }
      failure = actions(run).find { |item| item["name"].include?("independent fail") }
      check(image && owner && owner["type"] == "AFTER_METHOD" && owner["parentUuid"] == failure["parentUuid"] && owner["uuid"] != failure["uuid"], "After screenshot on actual AFTER_METHOD hook, not closed failed action")
      expected = run.fetch("calls").find { |row| row["filename"] == "after-failure.png" && row["kind"] == "attachment" }
      check(image && image.dig("wireFile", "base64") == expected["base64"], "After failure artifact exact PNG bytes")
      check(status(failure) == "FAILED" && owner && status(owner) == "PASSED" && scenarios(run).all? { |item| status(item) == "FAILED" }, "original failure survives successful artifact hook")
    end

    def tc11
      { "hooks-success" => "@ind_hooks", "before-failure" => "@ind_hooks @ind_before_error", "after-failure" => "@ind_hooks @ind_after_error",
        "afterstep-failure" => "@ind_hooks @ind_afterstep_error", "around-success" => "@ind_around",
        "around-before-failure" => "@ind_around @ind_around_before_error", "around-after-failure" => "@ind_around @ind_around_after_error" }.each do |label, tags|
        feature = one_scenario('Given independent pass "hook-body"', tags: tags)
        run = execute(label, feature)
        code = label.include?("failure") ? 1 : 0
        expect_exit(run, code)
        check(scenarios(run).all? { |item| status(item) == (code == 0 ? "PASSED" : "FAILED") }, "#{label} scenario outcome matches native hooks")
        if tags.include?("@ind_hooks")
          native_hooks = envelopes(run, "testCase").sum { |row| row.fetch("testSteps").count { |step| step["hookId"] } }
          rp_hooks = actions(run).select { |item| %w[BEFORE_METHOD AFTER_METHOD].include?(item["type"]) }
          check(rp_hooks.length == native_hooks, "#{label} exact native hook count, not invented steps")
          if code != 0
            marker = { "before-failure" => "INDEPENDENT_BEFORE_ERROR", "after-failure" => "INDEPENDENT_AFTER_ERROR", "afterstep-failure" => "INDEPENDENT_AFTER_STEP_ERROR" }.fetch(label)
            error = logs(run, marker).find { |log| log["level"].to_s.upcase == "ERROR" }
            owner = error && items(run).find { |item| item["uuid"] == error["itemUuid"] }
            check(owner && %w[BEFORE_METHOD AFTER_METHOD].include?(owner["type"]) && status(owner) == "FAILED", "#{label} error owned by actually failing hook")
          end
        else
          control = execute("#{label}-upstream-control", feature, control: true)
          expect_exit(control, code)
          check(actions(run).none? { |item| item["name"].include?("Around") }, "#{label} no fabricated Around HookStep when native runtime supplies none")
          check(envelopes(run, "testCaseFinished").length == envelopes(control, "testCaseFinished").length, "#{label} native closure matches formatter-disabled execution")
          @current["aroundApplicability"] = "Around is not a native HookStep; inspect native result and scenario diagnostic, not fabricated timing"
        end
      end
    end

    def tc12
      %w[success before_error after_error].each do |mode|
        run = execute("global-#{mode}", one_scenario, environment: { "INDEPENDENT_GLOBAL" => mode })
        expect_exit(run, mode == "success" ? 0 : 1)
        %w[INDEPENDENT_BEFORE_ALL INDEPENDENT_AFTER_ALL INDEPENDENT_AFTER_ALL_LAST].each do |message|
          matches = logs(run).select { |log| log["message"] == message }
          check(matches.length == 1 && matches.first["itemUuid"].nil?, "#{mode} #{message} exactly once, launch owned")
        end
        launch = run.fetch("wire").fetch("launches").values.first
        check(launch && status(launch) == (mode == "success" ? "PASSED" : "FAILED"), "#{mode} global-hook launch status")
        check(scenarios(run).empty?, "BeforeAll error runs no fabricated scenario") if mode == "before_error"
        if mode != "success"
          message = mode == "before_error" ? "INDEPENDENT_BEFORE_ALL_ERROR" : "INDEPENDENT_AFTER_ALL_ERROR"
          check(logs(run, message).any? { |log| log["itemUuid"].nil? && log["level"].to_s.upcase == "ERROR" }, "#{mode} original native error remains launch owned")
        end
      end
    end

    def verify_retries(run, expected, flags)
      rows = scenarios(run)
      check(rows.map { |item| status(item) } == expected, "attempt outcomes #{expected.join(' > ')}")
      check(rows.length == expected.length && rows.map { |item| item["uuid"] }.uniq.length == expected.length, "one distinct UUID per real native attempt")
      check(rows.map { |item| item["testCaseId"] }.uniq.length == 1 && rows.map { |item| item["uniqueId"] }.uniq.length == 1, "retry attempts share stable testCaseId/uniqueId")
      check(rows.map { |item| item["retry"] } == flags, "retry flags #{flags.inspect}")
      native = envelopes(run, "testCaseStarted")
      check(native.map { |row| row["attempt"] } == (1..expected.length).to_a, "actual native one-based attempt indexes, no invented retries")
      rows.each_with_index do |row, index|
        evidence = logs(run, "INDEPENDENT_RETRY:").select { |log| actions(run).any? { |action| action["uuid"] == log["itemUuid"] && action["parentUuid"] == row["uuid"] } }
        check(evidence.length == 1 && evidence.first["message"].end_with?(":#{index + 1}"), "retry #{index + 1} log isolated on own attempt")
      end
      verify_media(run)
    end

    def tc13
      feature = one_scenario('Given independent retry "eventual" fails 2 times')
      control = execute("retry-two-then-pass-upstream-control", feature, options: ["--retry", "2"], control: true)
      run = execute("retry-two-then-pass", feature, options: ["--retry", "2"])
      expect_exit(run, 0)
      expect_exit(control, 0)
      check(envelopes(run, "testCaseStarted").map { |row| row["attempt"] } == envelopes(control, "testCaseStarted").map { |row| row["attempt"] }, "retry attempt indexes agree with independent SDK-disabled control")
      verify_retries(run, %w[FAILED FAILED PASSED], [false, true, true])
      check(items(run).select { |item| item["type"] == "SUITE" }.all? { |item| status(item) == "PASSED" } && run.fetch("wire").fetch("launches").values.all? { |item| status(item) == "PASSED" }, "earlier failed attempts do not poison final suite/launch")
      check(envelopes(run, "testCaseFinished").map { |row| row["willBeRetried"] } == [true, true, false], "native willBeRetried true/true/false")
    end

    def tc14
      feature = one_feature(<<~GHERKIN)
          Scenario: Exhaust retry budget first
            Given independent retry "exhausted" fails 5 times
          Scenario: No total retries left
            Given independent retry "second" fails 5 times
      GHERKIN
      run = execute("retry-one-total-one-exhausted", feature, options: ["--retry", "1", "--retry-total", "1"])
      control = execute("retry-one-total-one-exhausted-upstream-control", feature, options: ["--retry", "1", "--retry-total", "1"], control: true)
      expect_exit(run, 1)
      expect_exit(control, 1)
      rows = scenarios(run)
      first = rows.select { |item| item["name"].include?("Exhaust") }
      second = rows.select { |item| item["name"].include?("No total") }
      check(first.length == 2 && second.length == 1 && rows.all? { |item| status(item) == "FAILED" }, "exactly two first-scenario attempts, one later scenario after total budget exhausted")
      check(rows.map { |item| item["uuid"] }.uniq.length == 3, "exhausted attempts have distinct UUIDs")
      check(envelopes(run, "testCaseStarted").map { |row| row["attempt"] } == [1, 2, 1], "native one-based attempts [1,2,1], no phantom retry")
      check(envelopes(run, "testCaseStarted").map { |row| row["attempt"] } == envelopes(control, "testCaseStarted").map { |row| row["attempt"] }, "exhausted attempts agree with SDK-disabled control")
      check(envelopes(run, "testCaseFinished").map { |row| row["willBeRetried"] } == [true, false, false], "native exhausted retry closure flags")
      check(run.fetch("wire").fetch("launches").values.all? { |item| status(item) == "FAILED" }, "exhausted failure launch FAILED")
      verify_media(run)
    end

    def read_lines(path)
      File.file?(path) ? File.readlines(path).reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) } : []
    end

    def read_json(path)
      File.file?(path) ? JSON.parse(File.read(path)) : {}
    end

    def write_json(path, data)
      File.write(path, JSON.pretty_generate(data) + "\n")
    end

    def persist
      FileUtils.mkdir_p(EVIDENCE)
      summary = @report.reject { |key, _| key == "runs" }
      summary["runs"] = @report.fetch("runs").map do |run|
        run.slice("case", "label", "exit", "control", "featurePath", "options", "fixtureEnvironment", "directory", "supportPath", "supportSha256").merge("evidence" => File.join(run.fetch("directory"), "run.json"))
      end
      write_json(File.join(EVIDENCE, "report.json"), summary)
      write_json(File.join(EVIDENCE, "#{@run_stamp}.json"), summary)
      write_json(File.join(EVIDENCE, "live-replay-manifest.json"), {
        "installedLib" => @installed_lib, "support" => SUPPORT, "ruby" => RUBY, "dependencyGemPath" => DEPENDENCIES,
        "supportSha256" => Digest::SHA256.file(SUPPORT).hexdigest,
        "instructions" => "Use own unique live RP launch names and credential environment; never write credentials. Require installed SDK and support, set INDEPENDENT_CALLS and INDEPENDENT_ARTIFACTS to own writable paths, retain native message output. Do not load offline boot.rb: it overwrites provenance. Options/featurePath are listed per run. Controls intentionally load no SDK. Expected media bytes and owners are recorded in each run.json calls/wire.",
        "runs" => summary.fetch("runs")
      })
    end
  end
end

if $PROGRAM_NAME == __FILE__
  report = Cucumber12Independent::Audit.new.run
  puts "Result: #{report.fetch('result')}"
  puts "Evidence: #{Cucumber12Independent::EVIDENCE}/report.json"
  exit(report.fetch("result") == "FAIL" ? 1 : 0)
end
