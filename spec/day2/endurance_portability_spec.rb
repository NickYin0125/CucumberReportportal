# frozen_string_literal: true

require "spec_helper"
require_relative "../../examples/day2_endurance/run"

RSpec.describe "Portable endurance authentication and paths" do
  it "uses a portable temporary default without requiring a precreated manager folder" do
    allow(Dir).to receive(:tmpdir).and_return("/tmp")
    expect(Day2Endurance.evidence_root(environment: {})).to eq("/tmp/reportportal-day2-endurance")
  end

  it "allows an explicitly configured absolute evidence root" do
    expect(Day2Endurance.evidence_root(environment: { "DAY2_EVIDENCE_DIR" => "/tmp/standalone-qa" })).to eq("/tmp/standalone-qa")
  end

  ["", "relative/path", "/tmp/qa\nother"].each do |path|
    it "rejects a malformed evidence root #{path.inspect}" do
      expect { Day2Endurance.evidence_root(environment: { "DAY2_EVIDENCE_DIR" => path }) }.to raise_error(ArgumentError)
    end
  end

  ["", " ", "key with spaces", "key\nsecond-line", "key\r", "key\0", "key\u2028"].each do |key|
    it "rejects empty or multiline credentials #{key.inspect}" do
      expect { Day2Endurance::Auth.resolve(endpoint: "http://rp.example", directory: Dir.tmpdir, environment: { "RP_API_KEY" => key }) }.to raise_error(ArgumentError, /RP_API_KEY/)
    end
  end

  ["", "..", "a/b", "a\nb", " p", "/project"].each do |project|
    it "rejects project path or header injection #{project.inspect}" do
      expect { Day2Endurance::Auth.validate_project!(project) }.to raise_error(ArgumentError)
    end
  end

  ["http://user:unit-secret@rp.example", "http://rp.example/\r\nheader", "relative", "http://rp.example/?token=unit"].each do |endpoint|
    it "rejects credential-bearing or malformed endpoint #{endpoint.inspect}" do
      expect { Day2Endurance::Auth.validate_endpoint!(endpoint) }.to raise_error(ArgumentError)
    end
  end

  it "never automatically loads a hardcoded helper for a local target" do
    expect(File).not_to receive(:file?)
    expect { Day2Endurance::Auth.resolve(endpoint: "http://localhost", directory: Dir.tmpdir, environment: {}) }.to raise_error(ArgumentError, /explicitly provide/)
  end

  it "rejects a relative helper path" do
    expect(File).not_to receive(:file?)
    expect { Day2Endurance::Auth.resolve(endpoint: "http://localhost", directory: Dir.tmpdir, environment: { "DAY2_AUTH_HELPER" => "helper.rb" }) }.to raise_error(ArgumentError, /absolute/)
  end

  %w[https://rp.example http://localhost.evil.example http://127.0.0.1.evil.example].each do |endpoint|
    it "refuses local-helper credentials to remote target #{endpoint}" do
      expect(File).not_to receive(:file?)
      expect { Day2Endurance::Auth.resolve(endpoint: endpoint, directory: Dir.tmpdir, environment: { "DAY2_AUTH_HELPER" => "/tmp/unit-helper.rb" }) }.to raise_error(ArgumentError, /loopback/)
    end
  end

  it "prefers explicitly supplied RP_API_KEY even when a helper setting is invalid" do
    expect(File).not_to receive(:file?)
    expect(Day2Endurance::Auth.resolve(endpoint: "https://rp.example", directory: Dir.tmpdir,
                                     environment: { "RP_API_KEY" => "unit-key", "DAY2_AUTH_HELPER" => "relative.rb" })).to eq(["unit-key", "RP_API_KEY environment"])
  end

  %w[http://localhost http://rp-latest.localhost http://127.0.0.1 http://[::1]].each do |endpoint|
    it "recognizes explicit loopback target #{endpoint}" do
      expect(Day2Endurance::Auth.local_target?(URI(endpoint))).to be(true)
    end
  end

  it "loads an explicitly provided absolute helper only on a local target" do
    helper = Module.new do
      def self.login; end
      def self.bearer = "unit-local-key"
    end
    stub_const("LatestRP", helper)
    allow(File).to receive(:file?).with("/tmp/unit-helper.rb").and_return(true)
    expect(Day2Endurance::Auth).to receive(:require).with("/tmp/unit-helper.rb")
    expect(helper).to receive(:login).once
    expect(Day2Endurance::Auth.resolve(endpoint: "http://localhost", directory: Dir.tmpdir,
                                     environment: { "DAY2_AUTH_HELPER" => "/tmp/unit-helper.rb" })).to eq(["unit-local-key", "explicit local helper"])
  end

  it "accepts the valid 500-iteration logging minimum" do
    expect(Day2Endurance.check_minimum_logs(receipt: { confirmed: 500 }, iterations: 500)).to be(true)
  end

  it "rejects 499 confirmed logs for 500 iterations" do
    expect { Day2Endurance.check_minimum_logs(receipt: { confirmed: 499 }, iterations: 500) }.to raise_error(Day2Endurance::InvariantError)
  end
end

RSpec.describe Day2Endurance::ProcessProbe do
  it "measures Darwin RSS and OS threads through Darwin ps switches" do
    allow(Open3).to receive(:capture3).with("ps", "-o", "rss=", "-p", "123").and_return(["102400\n", "", double(success?: true)])
    allow(Open3).to receive(:capture3).with("ps", "-M", "-p", "123").and_return(["HEADER\nTHREAD\nTHREAD\n", "", double(success?: true)])
    expect(described_class.read(platform: "arm64-darwin24", pid: 123)).to include(rss_mb: 100, process_threads: 2)
  end

  it "measures Linux RSS and thread count with an explicitly bounded proc read" do
    handle = double
    expect(File).to receive(:open).with("/proc/123/status", "rb").and_yield(handle)
    expect(handle).to receive(:read).with(16_384).and_return("Name:\truby\nVmRSS:\t204800 kB\nThreads:\t7\n")
    expect(Open3).not_to receive(:capture3)
    expect(described_class.read(platform: "x86_64-linux", pid: 123)).to include(rss_mb: 200, process_threads: 7, source: "bounded /proc status")
  end

  it "rejects missing Linux fields rather than inventing zero-valued measurements" do
    handle = double(read: "Name:\truby\n")
    allow(File).to receive(:open).with("/proc/123/status", "rb").and_yield(handle)
    expect { described_class.read(platform: "linux", pid: 123) }.to raise_error(/metrics unavailable/)
  end

  it "rejects unknown operating systems rather than using Darwin switches" do
    expect(Open3).not_to receive(:capture3)
    expect { described_class.read(platform: "unknown", pid: 123) }.to raise_error(/unsupported/)
  end
end
