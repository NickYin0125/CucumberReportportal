# frozen_string_literal: true

require "spec_helper"
require "objspace"
require "weakref"
require "reportportal_cucumber/automation/failure_redactor"

RSpec.describe Automation::FailureRedactor, "default policy reuse" do
  let(:mask) { Automation::EvidenceRedactor::MASK }
  let(:omitted) { Automation::EvidenceRedactor::OMITTED }
  let(:sanitizer) { described_class.new }

  def fresh_result(message:, frames:, sensitive_keys: [])
    policy = Automation::EvidenceRedactor.new(sensitive_keys: sensitive_keys)
    described_class.new(redactor: policy).redact(message: message, frames: frames)
  end

  def safe_frames(tag = "safe")
    ["/project/#{tag}/support.rb:65:in 'inner_failure'",
     "/project/#{tag}/support.rb:59:in 'deep_failure'",
     "/project/#{tag}/support.rb:136:in 'step'",
     "/project/#{tag}/features/audit.feature:5:in 'failure'"] +
      Array.new(56) { |index| "/ruby/gems/cucumber/#{tag}/runner.rb:#{index + 1}:in 'run'" } +
      ["-e:1:in 'run'", "<internal:kernel>:90:in 'require'"]
  end

  def corpus(tag)
    frames = safe_frames(tag)
    message_secret = "#{tag}_MESSAGE_SECRET"
    frame_secret = "#{tag}_FRAME_SECRET"
    encoded = JSON.generate(%q|{"pass\u0077ord":"| + message_secret + %q|"}|)
    prefix, suffix = encoded.split(message_secret, 2)
    fragment = URI.encode_www_form_component(%q|{"pass\u0077ord":"| + frame_secret + %q|"}|)
    probes = {
      safe62: ["#{tag} safe diagnostic\ntoken_count=12 password_policy=business-only", frames, []],
      local_secrets: ["api_key=#{message_secret}\nAuthorization: Bearer #{message_secret}",
                      ["password=#{frame_secret}", *frames], [message_secret, frame_secret]],
      safe_backslashes: ['expected "ABC" to match /\d+/', frames, []],
      unsafe_message: [%q|failure {"\u0070assword":"| + message_secret + %q|"}|, frames, [message_secret]],
      multiline_diff: ["expected: \"first\\nsecond\"\n     got: \"first\\nchanged\"\nDiff:\n- second\n+ changed", frames, []],
      malformed_json: [%q|{"pass\u0077ord":"| + message_secret, frames, [message_secret]],
      message_frame: ["failure password=", [message_secret, *frames], [message_secret]],
      frame_frame: ["\u6d4b\u8bd5 #{tag}", ["password=", frame_secret, *frames], [frame_secret]],
      quoted_boundary: ['failure password="' + message_secret,
                        [frame_secret + '"', *frames], [message_secret, frame_secret]],
      encoded_boundary: [%q|{"pass\u0077ord":|, ['"' + message_secret + '"}'], [message_secret]],
      encoded_with_stack: [%q|{"pass\u0077ord": "|, [message_secret + '"}', *frames], [message_secret]],
      malformed_key: [%q|{"pa\ss\u0077ord": "|, [message_secret + '"}', *frames], [message_secret]],
      malformed_value: [%q|{"pass\u0077ord": "\q|, [message_secret + '"}', *frames], [message_secret]],
      split_escape: [%q|{"pass\u00|, [%q|77ord": "| + message_secret + '"}', *frames], [message_secret]],
      split_key: [%q|{"pass|, ['word": "' + message_secret + '"}', *frames], [message_secret]],
      outer_encoded: [prefix, [message_secret + suffix, *frames], [message_secret]],
      encoded_frames: ["#{tag} failure", [%q|{"pass\u0077ord": "|, frame_secret + '"}', *frames], [frame_secret]],
      structured_array: [%q|{"pass\u0077ord": [|, ['"' + message_secret + '"]}'], [message_secret]],
      structured_object: [%q|{"pass\u0077ord": {|, ['"nested":"' + message_secret + '"}}'], [message_secret]],
      windows_frames: ["#{tag} failure", ["C:\\project\\#{tag}.rb:1:in 'call'", "token=#{frame_secret}", *frames], [frame_secret]],
      unsafe_frame: ["#{tag} failure", [frames.first, %q|failure {"\u0070assword":"| + frame_secret + '"}', frames.last], [frame_secret]],
      embedded_frame_newline: ["#{tag} failure", ["C:\\project\\#{tag}.rb:1\npassword=#{frame_secret}", *frames], [frame_secret]],
      url_credentials: ["request https://alice:#{message_secret}@example.test/path?token=#{message_secret}&count=12",
                        ["https://alice:#{frame_secret}@[broken/path##{fragment}", *frames], [message_secret, frame_secret]],
      whitespace_url_credentials: ["request https://alice:#{message_secret}@example.test/path?token=#{message_secret}&count=12",
                                   ["https://example.test/bad path##{fragment}", *frames], [message_secret, frame_secret]],
      binary: [("#{tag}\xFF\npassword=#{message_secret}".b), [("frame\xFE token=#{frame_secret}".b), *frames], [message_secret, frame_secret]],
      trailing_empty: ["#{tag} headline\n", [*frames, ""], []],
      empty: ["", [], []],
      encoded_empty: ['""', [], []]
    }
    probes.map do |name, (message, original_frames, secrets)|
      { name: "#{tag}/#{name}", message: message.freeze,
        frames: original_frames.each(&:freeze).freeze, secrets: secrets }
    end
  end

  def record_result(sanitizer, probe, sensitive_keys: [])
    input = { message: probe.fetch(:message), frames: probe.fetch(:frames) }
    expected = fresh_result(**input, sensitive_keys: sensitive_keys).to_h
    { probe: probe, expected: expected, actual: sanitizer.redact(**input).to_h }
  end

  def expect_safe_record(record)
    probe = record.fetch(:probe)
    aggregate_failures(probe.fetch(:name)) do
      expect(record.fetch(:actual)).to eq(record.fetch(:expected))
      probe.fetch(:secrets).each do |secret|
        expect(record.fetch(:actual).inspect).not_to include(secret)
        expect(record.fetch(:expected).inspect).not_to include(secret)
      end
    end
  end

  def in_threads(count)
    ready = Queue.new
    release = Queue.new
    workers = count.times.map do |index|
      Thread.new do
        ready << true
        release.pop
        yield index
      end
    end
    count.times { ready.pop }
    count.times { release << true }
    workers.map(&:value)
  ensure
    workers&.each { |worker| worker.kill if worker.alive? }
    workers&.each(&:join)
  end

  def owned_objects(root)
    seen = {}.compare_by_identity
    pending = [root]
    until pending.empty?
      object = pending.pop
      # Class/global roots include the test's own references, not retained policy state.
      next if seen.key?(object) || object.is_a?(Module) || object.is_a?(ObjectSpace::InternalObjectWrapper)

      seen[object] = true
      pending.concat(object.instance_variables.map { |name| object.instance_variable_get(name) })
      pending.concat(ObjectSpace.reachable_objects_from(object) || [])
    end
    seen.keys
  end

  def transient_input_references(sanitizer)
    corpus("REUSE_RETENTION").flat_map do |probe|
      message = probe.fetch(:message).dup
      frames = probe.fetch(:frames).map(&:dup)
      references = [message, frames, *frames].map { |input| WeakRef.new(input) }
      sanitizer.redact(message: message, frames: frames)
      references
    end
  end

  def encoded_text(layers)
    layers.times.reduce("b" * (Automation::EvidenceRedactor::MAX_INPUT_BYTES / 2)) do |text, _|
      JSON.generate(text)
    end
  end

  it "shares one frozen default with only frozen reachable policy fields before and after use" do
    first = described_class.new
    second = described_class.new
    policy = first.instance_variable_get(:@redactor)
    expect(policy).to be_an_instance_of(Automation::EvidenceRedactor)
    expect(second.instance_variable_get(:@redactor)).to equal(policy)
    before = owned_objects(policy)
    expect(before).to all(be_frozen)
    expect(before.grep(Array)).not_to be_empty
    expect(before.grep(Regexp)).not_to be_empty
    expect(before.grep(String)).not_to be_empty

    corpus("FROZEN").each { |probe| expect_safe_record(record_result(first, probe)) }

    after = owned_objects(policy)
    expect(after).to all(be_frozen)
    expect(after.map(&:object_id).sort).to eq(before.map(&:object_id).sort)
    expect(described_class.new.instance_variable_get(:@redactor)).to equal(policy)
  end

  it "keeps separately injected real redactors distinct and does not freeze caller-owned instances" do
    first_policy = Automation::EvidenceRedactor.new(sensitive_keys: ["private-id"])
    second_policy = Automation::EvidenceRedactor.new(sensitive_keys: ["tenant-pin"])
    first = described_class.new(redactor: first_policy)
    second = described_class.new(redactor: second_policy)

    expect(first.instance_variable_get(:@redactor)).to equal(first_policy)
    expect(second.instance_variable_get(:@redactor)).to equal(second_policy)
    expect(first_policy).not_to equal(second_policy)
    expect(first_policy).not_to equal(sanitizer.instance_variable_get(:@redactor))
    expect(second_policy).not_to equal(sanitizer.instance_variable_get(:@redactor))
    expect(first_policy).not_to be_frozen
    expect(second_policy).not_to be_frozen
  end

  it "matches fresh injected policies on every result field across a deterministic diverse corpus" do
    3.times do |round|
      corpus("CORPUS_#{round}").rotate(round * 7).each do |probe|
        expect_safe_record(record_result(sanitizer, probe))
      end
    end
  end

  it "matches fresh policies at every split through encoded credential keys and value openers" do
    secret = "SPLIT_REUSE_SECRET"
    sources = [
      %q|{"pass\u0077ord": "| + secret + %q|"}|,
      %q|{\"pass\u0077ord\": \"| + secret + %q|\"}|,
      JSON.generate(%q|{"pass\u0077ord": "| + secret + %q|"}|),
      %q|{"p\u0061ss word": "| + secret + %q|"}|
    ]
    sources.each_with_index do |source, source_index|
      (1...source.index(secret)).each do |cut|
        remainder = [source[cut..], "/project/support.rb:1:in 'call'"]
        [[source[0...cut], remainder], ["\u6d4b\u8bd5 failure", [source[0...cut], *remainder]]].each do |message, frames|
          probe = { name: "source #{source_index} split #{cut}: #{message.inspect}",
                    message: message, frames: frames, secrets: [secret] }
          expect_safe_record(record_result(sanitizer, probe))
        end
      end
    end
  end

  %i[separate_wrappers same_wrapper].each do |mode|
    it "isolates simultaneous mixed failures with #{mode} using the shared default" do
      wrappers = mode == :same_wrapper ? [sanitizer] * 8 : Array.new(8) { described_class.new }
      records = in_threads(8) do |index|
        2.times.flat_map do |round|
          corpus("WORKER_#{index}_ROUND_#{round}").rotate(index * 3).map do |probe|
            Thread.pass
            record_result(wrappers.fetch(index), probe)
          end
        end
      end.flatten(1)

      records.each { |record| expect_safe_record(record) }
      safe_records = records.select { |record| record.fetch(:probe).fetch(:name).end_with?("/safe62") }
      expect(safe_records.length).to eq(16)
      safe_records.each do |record|
        expect(record.fetch(:actual).fetch(:message)).to eq(record.fetch(:probe).fetch(:message))
        expect(record.fetch(:actual).fetch(:backtrace)).to eq(record.fetch(:probe).fetch(:frames).join("\n"))
        expect(record.fetch(:actual).fetch(:backtrace).lines.length).to eq(62)
        expect(record.fetch(:actual).fetch(:fallback_only)).to be(false)
      end
    end
  end

  it "preserves exact message withholding and all 62 safe frames after unrelated failures" do
    corpus("PRIOR").each { |probe| sanitizer.redact(message: probe.fetch(:message), frames: probe.fetch(:frames)) }
    message = %q|failure {"\u0070assword":"WITHHELD_REUSE_SECRET"}|
    frames = safe_frames
    result = sanitizer.redact(message: message, frames: frames)
    expect(result.to_h).to eq(message: omitted, backtrace: frames.join("\n"),
                             baseline: [omitted, *frames].join("\n"), fallback_only: false)
    %w[plain rich].each do |mode|
      output = ReportportalCucumber::Presentation::FailureCard.format(
        error: RuntimeError.new(message), message: result.message, backtrace: result.backtrace,
        baseline: result.baseline, presentation: mode, cwd: "/project"
      )
      expect(output).to start_with("## \u2717 RuntimeError\n\nMessage withheld: unsafe or ambiguous input\n\n")
      expect(output.scan("Message withheld: unsafe or ambiguous input").length).to eq(1)
      expect(output).to end_with("```text\n#{frames.join("\n")}\n```")
      expect(output).not_to include("WITHHELD_REUSE_SECRET")
    end
  end

  it "keeps configured keys independent of other instances and later caller configuration mutations" do
    key = +"private-id"
    keys = [key]
    first = described_class.new(redactor: Automation::EvidenceRedactor.new(sensitive_keys: keys))
    second = described_class.new(redactor: Automation::EvidenceRedactor.new(sensitive_keys: ["tenant-pin"]))
    key.replace("tenant-pin")
    keys << "visible-label"
    message = "private_id=PRIVATE tenant_pin=TENANT visible_label=PUBLIC password=COMMON"
    expectations = [
      [first, "private_id=#{mask} tenant_pin=TENANT visible_label=PUBLIC password=#{mask}"],
      [second, "private_id=PRIVATE tenant_pin=#{mask} visible_label=PUBLIC password=#{mask}"],
      [sanitizer, "private_id=PRIVATE tenant_pin=TENANT visible_label=PUBLIC password=#{mask}"]
    ]
    3.times do
      expectations.each do |wrapper, expected|
        result = wrapper.redact(message: message, frames: [])
        expect(result.to_h).to eq(message: expected, backtrace: "", baseline: expected, fallback_only: false)
      end
    end
  end

  it "isolates default and conflicting custom policies across concurrent encoded boundaries" do
    policies = [[], ["private-id"], ["tenant-pin"]]
    wrappers = policies.map do |keys|
      keys.empty? ? described_class.new : described_class.new(redactor: Automation::EvidenceRedactor.new(sensitive_keys: keys))
    end
    records = in_threads(3) do |index|
      8.times.flat_map do |round|
        tag = "CUSTOM_#{index}_#{round}"
        probes = [
          { name: tag, message: "private_id=PRIVATE tenant_pin=TENANT password=COMMON",
            frames: ["private_id=PRIVATE_FRAME tenant_pin=TENANT_FRAME"], secrets: ["COMMON"] },
          { name: "#{tag}/private-boundary", message: %q|{"pr\u0069vate id":|,
            frames: ['"PRIVATE_BOUNDARY"}'], secrets: index == 1 ? ["PRIVATE_BOUNDARY"] : [] },
          { name: "#{tag}/tenant-boundary", message: "#{tag} failure",
            frames: [%q|{"ten\u0061nt pin":|, '"TENANT_BOUNDARY"}'], secrets: index == 2 ? ["TENANT_BOUNDARY"] : [] }
        ]
        probes.map do |probe|
          Thread.pass
          record_result(wrappers.fetch(index), probe, sensitive_keys: policies.fetch(index))
        end
      end
    end.flatten(1)
    records.each { |record| expect_safe_record(record) }
    expect(wrappers.first.redact(message: "private_id=PRIVATE tenant_pin=TENANT", frames: []).message)
      .to eq("private_id=PRIVATE tenant_pin=TENANT")
  end

  { nodes: -> { JSON.generate(Array.new(Automation::EvidenceRedactor::MAX_STRUCTURE_NODES - 8, 1)) },
    bytes: -> { encoded_text(6) } }.each do |budget, payload|
    it "starts a fresh #{budget} budget for each message, backtrace and successive invocation" do
      text = instance_exec(&payload)
      expected = budget == :bytes ? "b" * (Automation::EvidenceRedactor::MAX_INPUT_BYTES / 2) : text
      3.times do
        [sanitizer, described_class.new].each do |wrapper|
          result = wrapper.redact(message: text, frames: [text])
          expect(result.to_h).to eq(message: expected, backtrace: expected,
                                   baseline: "#{expected}\n#{expected}", fallback_only: false)
        end
      end
    end
  end

  it "starts a fresh traversal budget for each frame when the combined backtrace is omitted" do
    frame = JSON.generate(Array.new(Automation::EvidenceRedactor::MAX_STRUCTURE_NODES - 8, 1))
    frames = [frame, frame, "token=FRAME_BUDGET_SECRET"]
    expected_backtrace = [frame, frame, "token=#{mask}"].join("\n")
    expect(Automation::EvidenceRedactor.new.redact_text(frames.join("\n"))).to eq(omitted)

    3.times do
      result = sanitizer.redact(message: "safe message", frames: frames)
      expect(result.to_h).to eq(message: "safe message", backtrace: expected_backtrace,
                               baseline: "safe message\n#{expected_backtrace}", fallback_only: false)
    end
  end

  %i[nodes bytes depth input].each do |budget|
    it "resets all per-call state after exhausting the #{budget} bound" do
      oversized = case budget
                  when :nodes then JSON.generate(Array.new(Automation::EvidenceRedactor::MAX_STRUCTURE_NODES + 1, 1))
                  when :bytes then encoded_text(8)
                  when :depth then 12.times.reduce("safe") { |text, _| JSON.generate(text) }
                  when :input then "password=" + "x" * Automation::EvidenceRedactor::MAX_INPUT_BYTES
                  end
      frames = safe_frames
      2.times do
        result = sanitizer.redact(message: oversized, frames: frames)
        expect(result.to_h).to eq(message: omitted, backtrace: frames.join("\n"),
                                 baseline: [omitted, *frames].join("\n"), fallback_only: false)
        [sanitizer, described_class.new].each do |wrapper|
          input = { message: "password=AFTER_EXHAUSTION", frames: ["token=FRAME_AFTER_EXHAUSTION", *frames] }
          recovered = wrapper.redact(**input)
          expect(recovered.to_h).to eq(fresh_result(**input).to_h)
          expect(recovered.message).to eq("password=#{mask}")
          expect(recovered.backtrace).to eq(["token=#{mask}", *frames].join("\n"))
          expect(recovered.fallback_only).to be(false)
        end
      end
    end
  end

  %i[default injected].each do |mode|
    it "does not retain message strings, frame strings, their arrays or copied evidence with #{mode} policy" do
      wrapper = mode == :default ? sanitizer : described_class.new(redactor: Automation::EvidenceRedactor.new)
      references = transient_input_references(wrapper)
      retained_strings = owned_objects(wrapper).grep(String)
      expect(retained_strings.grep(/REUSE_RETENTION/)).to be_empty

      3.times { GC.start(full_mark: true, immediate_sweep: true) }

      expect(references.any?(&:weakref_alive?)).to be(false)
    end
  end

  it "rechecks mutable messages, frame entries and frame arrays instead of caching earlier output" do
    message = +"first safe message"
    frame = +"/project/first.rb:1:in 'call'"
    frames = [frame]
    history = []
    check = lambda do
      input = { message: message, frames: frames }
      result = sanitizer.redact(**input)
      expect(result.to_h).to eq(fresh_result(**input).to_h)
      history << [result, result.to_h.transform_values { |value| value.is_a?(String) ? value.dup : value }]
      result
    end
    check.call
    message.replace("password=MUTATED_MESSAGE_SECRET")
    frame.replace("token=MUTATED_FRAME_SECRET")
    frames << "/project/second.rb:2:in 'step'"
    changed = check.call
    expect(changed.message).to eq("password=#{mask}")
    expect(changed.backtrace).to eq("token=#{mask}\n/project/second.rb:2:in 'step'")

    message.replace(%q|{"pass\u0077ord":|)
    frames.replace(['"MUTATED_BOUNDARY_SECRET"}'])
    boundary = check.call
    expect(boundary.to_h).to eq(message: "", backtrace: "", baseline: '{"password":"[REDACTED]"}', fallback_only: true)

    message.replace(%q|failure {"pass\u0077ord":"MUTATED_UNSAFE_SECRET"}|)
    frames.replace(safe_frames)
    expect(check.call.message).to eq(omitted)

    message.replace("last safe message")
    frames.clear
    expect(check.call.to_h).to eq(message: "last safe message", backtrace: "", baseline: "last safe message", fallback_only: false)
    history.each { |result, snapshot| expect(result.to_h).to eq(snapshot) }
  end

  it "does not let mutation of a returned result poison later calls or another default instance" do
    input = { message: "password=RESULT_MESSAGE_SECRET", frames: ["token=RESULT_FRAME_SECRET", *safe_frames] }
    expected = fresh_result(**input).to_h
    result = sanitizer.redact(**input)
    result.message.replace("poisoned message")
    result.backtrace.replace("poisoned frames")
    result.baseline.replace("poisoned baseline")
    result.fallback_only = true

    expect(sanitizer.redact(**input).to_h).to eq(expected)
    expect(described_class.new.redact(**input).to_h).to eq(expected)
  end
end
