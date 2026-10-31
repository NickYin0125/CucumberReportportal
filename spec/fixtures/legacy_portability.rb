# frozen_string_literal: true

require "digest"

# Normalize only fixture inputs in the released specs; never patch legacy SDK code.
module LegacyPortability
  SPEC_HASHES = {
    "spec/reportportal_cucumber/cucumber/world_spec.rb" =>
      "b7917f17040be398fa51ff6f392a690c47cbb65d32cf96829734439b89b8549e",
    "spec/reportportal_cucumber/cucumber/m4a_public_delivery_integration_spec.rb" =>
      "0ff7c8d8660bcbf21d80fc255767b0dcec8b22f273d4cf90d96380af28b57d05"
  }.freeze

  def self.replace_once(source, original, replacement)
    raise "Legacy portability fixture anchor drift" unless source.scan(original).length == 1

    source.sub(original) { replacement }
  end

  def self.source(root, relative)
    expected = SPEC_HASHES.fetch(relative)
    original = File.binread(File.join(root, relative))
    unless Digest::SHA256.hexdigest(original) == expected
      raise "Legacy portability overlay requires the unchanged immutable v1.3.1 original spec: #{relative}"
    end

    if relative.end_with?("/world_spec.rb")
      replace_once(original, '    expect(reader).not_to receive(:path)', <<~RUBY.chomp)
            reader.define_singleton_method(:path) { raise "IO.pipe path must never be probed" }
            expect(reader).not_to receive(:path)
      RUBY
    else
      bounded_delivery(original)
    end
  end

  def self.bounded_delivery(source)
    source = replace_once(source, '          raise "intentional first attempt failure" if attempt == 1', <<~'RUBY'.chomp)
              if attempt == 1
                failure = RuntimeError.new("intentional first attempt failure")
                failure.set_backtrace(["m4a_fixture.rb:1:in `bounded_failure'"])
                raise failure
              end
    RUBY
    source = replace_once(source, '      expected_extra = capture.fetch("cucumber_version").start_with?("9.") ? 1 : 0', <<~'RUBY'.chomp)
          # The deliberately bounded native failure must be delivered, not discarded.
          failure_logs = capture.fetch("logs").select do |entry|
            entry.fetch("message").start_with?("intentional first attempt failure")
          end
          expect(failure_logs.length).to eq(1)
          expect(failure_logs.first.fetch("message")).to include("m4a_fixture.rb:1:in `bounded_failure'")
          expect(failure_logs.first.fetch("itemUuid")).to eq(step_uuids.first)
          expect(failure_logs.first.fetch("level")).to eq("error")
          expect(counters.fetch("rejected_oversized")).to eq(2)
          other_rejections = counters.select { |key, _| key.start_with?("rejected_") && key != "rejected_oversized" }
          expect(other_rejections.values).to all(eq(0))
          expect(counters.fetch("worker_failed")).to eq(0)
          expected_extra = 0
    RUBY
    source
  end

  def self.load_specs!(root)
    root = File.realpath(root)
    # Validate every original before registering any examples.
    sources = SPEC_HASHES.keys.to_h { |relative| [relative, source(root, relative)] }
    sources.each { |relative, contents| eval(contents, TOPLEVEL_BINDING, File.join(root, relative), 1) }
  end
end
