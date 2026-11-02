# frozen_string_literal: true

require "json"

module ReleasePerfModeAudit
  CONFIGS = []
  PASSED = []
  EXPECTED = ENV.fetch("QA_RELEASE_EXPECTED_MODE")
  CONFIG_WRAPPER = Module.new do
    def initialize(*args, **kwargs, &block)
      super
      ReleasePerfModeAudit::CONFIGS << presentation
    end
  end
  RENDERER_WRAPPER = Module.new do
    def format(*args, **kwargs, &block)
      ReleasePerfModeAudit::PASSED << kwargs.fetch(:presentation)
      super
    end
  end
end

ReportportalCucumber::Config.prepend(ReleasePerfModeAudit::CONFIG_WRAPPER)
ReportportalCucumber::Presentation::FailureCard.singleton_class.prepend(ReleasePerfModeAudit::RENDERER_WRAPPER)
at_exit do
  ReleasePerfModeAudit::CONFIG_WRAPPER.send(:remove_method, :initialize)
  ReleasePerfModeAudit::RENDERER_WRAPPER.send(:remove_method, :format)
  modes = ReleasePerfModeAudit::CONFIGS
  passed = ReleasePerfModeAudit::PASSED
  valid = !modes.empty? && (modes + passed).all? { |m| m == ReleasePerfModeAudit::EXPECTED }
  File.write(File.join(ENV.fetch("LEDGER_EVIDENCE"), "release-mode-proof.json"), JSON.pretty_generate(
    expected: ReleasePerfModeAudit::EXPECTED, resolved: modes, passed_to_renderer: passed, passed: valid,
    replay_note: "Audit wrappers removed before original wrapper-free Presentation replay") + "\n")
  raise "Presentation mode audit failed" unless valid
end
