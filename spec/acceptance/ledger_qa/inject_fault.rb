# frozen_string_literal: true

require "reportportal_cucumber"
require "base64"
require "digest"

if (entry = ENV["QA_FAULT_ENTRY"])
  module_name, method_name = entry.split(".")
  target = ReportportalCucumber::Presentation.const_get(module_name)
  original = target.method(method_name)
  raised = false
  serialize = lambda do |value|
    case value
    when Hash then value.to_h { |key, item| [key, serialize.call(item)] }
    when Array then value.map { |item| serialize.call(item) }
    when String
      value.dup.force_encoding(Encoding::UTF_8).valid_encoding? ? value.dup.force_encoding(Encoding::UTF_8) :
        { binary_bytes: value.bytesize, sha256: Digest::SHA256.hexdigest(value), base64: Base64.strict_encode64(value) }
    else value
    end
  end
  fallback = ReportportalCucumber::Presentation::Fallback
  render = fallback.method(:render)
  fallback.define_singleton_method(:render) do |fallback:, state: nil, &block|
    used = false
    expected = nil
    callable = lambda do
      expected = fallback.call
      used = true
      expected
    end
    actual = render.call(fallback: callable, state: state, &block)
    if raised && used && ENV["QA_FALLBACK_CAPTURE"]
      record = { entry: entry, baseline_callable_result: serialize.call(expected), actual_result: serialize.call(actual),
                 byte_equal: expected == actual, result_class: actual.class.name }
      File.open(ENV.fetch("QA_FALLBACK_CAPTURE"), "a") { |file| file.puts(JSON.generate(record)) }
    end
    actual
  end
  target.define_singleton_method(method_name) do |*args, **keywords, &block|
    unless raised
      raised = true
      warn "QA_FAULT_INVOKED #{entry}"
      raise StandardError, "QA injected presentation formatter fault"
    end
    original.call(*args, **keywords, &block)
  end
end
