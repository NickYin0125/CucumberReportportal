# frozen_string_literal: true

require "spec_helper"
require "open3"
require_relative "../fixtures/legacy_portability"

RSpec.describe "Immutable legacy test fixture portability" do
  let(:baseline) { "4ca2f770e0a84e83688f165ba04b4db8ef855cf9" }
  let(:root) { File.expand_path("../..", __dir__) }

  def with_originals
    Dir.mktmpdir("legacy-portability-") do |directory|
      LegacyPortability::SPEC_HASHES.each_key do |relative|
        source, error, status = Open3.capture3("git", "show", "#{baseline}:#{relative}", chdir: root)
        raise error unless status.success?

        path = File.join(directory, relative)
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, source)
      end
      yield directory
    end
  end

  it "retains all nine original cases and leaves both original files byte-identical" do
    with_originals do |directory|
      counts = LegacyPortability::SPEC_HASHES.map do |relative, digest|
        normalized = LegacyPortability.source(directory, relative)
        original = File.binread(File.join(directory, relative))
        expect(Digest::SHA256.hexdigest(original)).to eq(digest)
        expect(normalized.scan(/^  it .*/)).to eq(original.scan(/^  it .*/))
        normalized.scan(/^  it .*/).length
      end
      expect(counts).to eq([8, 1])
    end
  end

  it "adds an instance-only path tripwire without relaxing verified negative expectations" do
    with_originals do |directory|
      source = LegacyPortability.source(directory, LegacyPortability::SPEC_HASHES.keys.first)
      expect(source).to include('reader.define_singleton_method(:path) { raise "IO.pipe path must never be probed" }',
                               'expect(reader).not_to receive(:path)', 'expect(reader).not_to receive(:read)')
      expect(source).not_to include("verify_partial_doubles = false", "allow(reader).to receive(:path)")
    end
  end

  it "bounds the actual raised failure and asserts its delivery with exactly two artifact rejections" do
    with_originals do |directory|
      source = LegacyPortability.source(directory, LegacyPortability::SPEC_HASHES.keys.last)
      expect(source).to include('failure.set_backtrace(["m4a_fixture.rb:1:in `bounded_failure\'"])',
                               'raise failure', 'expect(failure_logs.length).to eq(1)',
                               'expect(failure_logs.first.fetch("itemUuid")).to eq(step_uuids.first)',
                               'expect(counters.fetch("rejected_oversized")).to eq(2)',
                               'expect(other_rejections.values).to all(eq(0))')
      expect(source).to include('"RP_QUEUE_MAX_BYTES" => "1400"', 'bytes: "z" * 4_096',
                               'expect(extra_oversized_rejections).to eq(expected_extra)',
                               'expect(counters.fetch("accepted")).to eq(capture.fetch("logs").length)')
    end
  end

  LegacyPortability::SPEC_HASHES.each_key do |relative|
    it "fails closed if #{File.basename(relative)} changes" do
      with_originals do |directory|
        File.open(File.join(directory, relative), "a") { |file| file.puts "# drift" }
        expect { LegacyPortability.source(directory, relative) }.to raise_error(/unchanged immutable v1.3.1/)
      end
    end
  end

  it "rejects missing or duplicate fixture anchors" do
    expect { LegacyPortability.replace_once("absent", "needle", "new") }.to raise_error(/anchor drift/)
    expect { LegacyPortability.replace_once("needle needle", "needle", "new") }.to raise_error(/anchor drift/)
  end
end
