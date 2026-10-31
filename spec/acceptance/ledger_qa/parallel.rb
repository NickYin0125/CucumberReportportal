# frozen_string_literal: true

require_relative "isolated"

module LedgerQA
  class ParallelRunner < IsolatedRunner
    def local_write(wire, method, path, value)
      uri = URI(wire.endpoint + path)
      request = Net::HTTP.const_get(method).new(uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(value)
      response = Net::HTTP.start(uri.hostname, uri.port, nil) { |http| http.request(request) }
      raise "QA orchestrator HTTP failure" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end

    def run
      @output = @options.fetch(:output)
      raise "New owned evidence directory required" unless @output.start_with?(File.join(ROOT, "docs/reviews/assets/") ) && !File.exist?(@output)
      @project = @options[:transport] == "live" ? ENV.fetch("RP_PROJECT") : "ledger_developer_offline"
      FileUtils.mkdir_p(@output)
      File.write(File.join(@output, "empty-config.yml"), "{}\n")
      probe = execute(environment, [@options[:ruby], "-I", File.join(@options[:sdk_root], "lib"), "-e", PROBE], ROOT)
      write(File.join(@output, "probe.json"), probe)
      raise "QA parallel source probe failed" unless probe[:exit] == 0
      @runtime = JSON.parse(probe.fetch(:stdout))
      raise "ParallelFormatter is not applicable on 1.x" unless @runtime["sdk"].start_with?("2.")
      write(File.join(@output, "probe-activation.json"), @runtime.fetch("activation"))
      media
      barrier = File.join(@output, "barrier")
      FileUtils.mkdir_p(barrier)
      wire = Wire.new(project: @project, upstream: @options[:transport] == "live" ? ENV.fetch("RP_ENDPOINT") : nil)
      launch = local_write(wire, "Post", "/api/v1/#{@project}/launch", { name: "ledger-developer-independent-QA-#{File.basename(@output)}-F06", startTime: (Time.now.to_f * 1000).to_i.to_s, mode: "DEFAULT" }).fetch("id")
      processes = (1..4).map do |worker|
        Thread.new do
          directory = File.join(@output, "worker-#{worker}")
          FileUtils.mkdir_p(directory)
          feature = File.join(ROOT, "features/presentation_ledger/qa_parallel/worker-#{worker}.feature")
          FileUtils.mkdir_p(File.dirname(feature))
          File.write(feature, "@reportportal_live @F06\nFeature: QA parallel worker #{worker}\n  Scenario: Worker #{worker}\n    Given QA parallel worker #{worker}\n    Then QA parallel work is complete\n")
          env = child_environment({ id: "F06" }, wire, directory).merge("RP_LAUNCH_UUID" => launch,
            "TEST_ENV_NUMBER" => worker.to_s, "PARALLEL_TEST_GROUPS" => "4", "QA_PARALLEL_BARRIER" => barrier)
          command = [@options[:ruby], "-I", File.join(@options[:sdk_root], "lib"), "-e", CLI, "--", "--no-profile", "--publish-quiet",
            "--require", File.join(ROOT, "spec/acceptance/ledger_qa/parallel_support.rb"), "--format", "progress",
            "--format", "json", "--out", File.join(directory, "native.json"), "--format", "message", "--out", File.join(directory, "native.ndjson"),
            "--format", "ReportPortal::Cucumber::ParallelFormatter", "--out", File.join(directory, "rp.out"),
            "--format", "LedgerDeveloper::Audit", "--out", File.join(directory, "audit.out"), feature.delete_prefix(ROOT + "/")]
          process = execute(env, command, ROOT)
          write(File.join(directory, "process.json"), process)
          process
        end
      end.map(&:value)
      status = processes.all? { |p| p[:exit] == 0 } ? "PASSED" : "FAILED"
      local_write(wire, "Put", "/api/v1/#{@project}/launch/#{launch}/finish", { endTime: (Time.now.to_f * 1000).to_i.to_s, status: status })
      wire.close
      write(File.join(@output, "wire.json"), wire.records)
      write(File.join(@output, "snapshot.json"), wire.snapshot)
      write(File.join(@output, "result.json"), status: status, workers: processes, evidence_scope: "F06 four real workers, external parent owns Launch lifecycle")
      puts "QA_PARALLEL_COMPLETE=#{@output} #{status}"
      status == "PASSED" ? 0 : 1
    rescue StandardError => error
      warn "QA parallel blocked: #{error.class}"
      2
    ensure
      wire&.close
    end
  end
end

exit LedgerQA::ParallelRunner.new(ARGV).run if $PROGRAM_NAME == __FILE__
