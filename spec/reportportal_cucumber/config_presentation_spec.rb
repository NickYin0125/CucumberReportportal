# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Presentation configuration" do
  let(:logger) { double("logger", warn: nil) }
  before { allow(ReportportalCucumber).to receive(:logger).and_return(logger) }

  it "defaults to plain and accepts rich only through explicit configuration" do
    expect(ReportportalCucumber::Config.new.presentation).to eq("plain")
    expect(ReportportalCucumber::Config.load(env: {}, yaml_path: "/dev/null").presentation).to eq("plain")
    expect(ReportportalCucumber::Config.new(presentation: "rich").presentation).to eq("rich")
    expect(ReportportalCucumber::Config.load(env: { "RP_PRESENTATION" => "rich" }, yaml_path: "/dev/null").presentation).to eq("rich")
    expect(logger).not_to have_received(:warn)
  end

  ["fancy", "rich SECRET123", "RICH", " rich ", "", nil, true, :rich].each do |value|
    it "warns once without reflecting invalid #{value.inspect}, then stays plain" do
      config = ReportportalCucumber::Config.new(presentation: value)
      5.times { expect(config.presentation).to eq("plain") }
      expect(logger).to have_received(:warn).with("Invalid RP_PRESENTATION; using plain presentation").once
    end
  end

  it "honors YAML, environment and override precedence, and snapshots mutable input" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "reportportal.yml")
      File.write(path, "default:\n  presentation: rich\n")
      expect(ReportportalCucumber::Config.load(env: {}, yaml_path: path).presentation).to eq("rich")
      expect(ReportportalCucumber::Config.load(env: { "RP_PRESENTATION" => "plain" }, yaml_path: path).presentation).to eq("plain")
      expect(ReportportalCucumber::Config.load(env: { "RP_PRESENTATION" => "fancy" }, yaml_path: path,
        overrides: { presentation: "rich" }).presentation).to eq("rich")
    end
    value = +"rich"
    config = ReportportalCucumber::Config.new(presentation: value)
    value.replace("plain")
    expect(config.presentation).to eq("rich")
    expect(config.presentation).to be_frozen
    expect(logger).not_to have_received(:warn)
  end
end
