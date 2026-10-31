# frozen_string_literal: true

require "base64"
require "digest"
require "json"
require "stringio"
require "zlib"

module IndependentCucumber12
  module_function

  def record(kind, values = {})
    row = { "kind" => kind, "timeMs" => (Time.now.to_r * 1000).to_i }.merge(values)
    File.open(ENV.fetch("INDEPENDENT_CALLS"), "a") { |file| file.puts(JSON.generate(row)) }
  end

  def native(world, message)
    record("log", "message" => message)
    world.log(message)
  end

  def chunk(type, body)
    [body.bytesize].pack("N") + type.b + body + [Zlib.crc32(type.b + body)].pack("N")
  end

  def png(seed)
    pixel = [seed * 19 % 256, seed * 47 % 256, seed * 83 % 256].pack("C*")
    scanlines = ("\0".b + pixel * 2) * 2
    "\x89PNG\r\n\x1a\n".b + chunk("IHDR", [2, 2, 8, 2, 0, 0, 0].pack("NNC5")) +
      chunk("IDAT", Zlib::Deflate.deflate(scanlines)) + chunk("IEND", "".b)
  end

  def payload(kind)
    case kind
    when "png" then [png(71), "image/png"]
    when "text" then ["independent text\r\nline two\n\x00end".b, "text/plain"]
    when "json" then ['{"source":"independent","values":[1,true,null]}'.b, "application/json"]
    else raise "unknown media #{kind}"
    end
  end

  def screenshot(world, seed, filename, mime: "image/png", path: nil)
    bytes = if path
              File.binread(path)
            elsif ENV["INDEPENDENT_PNG_DIR"]
              File.binread(File.join(ENV.fetch("INDEPENDENT_PNG_DIR"), filename))
            else
              png(seed)
            end
    signature = mime == "image/jpeg" ? "\xFF\xD8\xFF".b : "\x89PNG\r\n\x1a\n".b
    raise "INDEPENDENT_FIXTURE_IMAGE_MIME_MISMATCH: #{filename} #{mime}" unless bytes.start_with?(signature)

    record("attachment", "filename" => filename, "mime" => mime,
           "sha256" => Digest::SHA256.hexdigest(bytes), "base64" => Base64.strict_encode64(bytes))
    world.attach(bytes, mime, filename)
  end

  def deep_failure
    inner_failure
  end

  def inner_failure
    error = RuntimeError.new("INDEPENDENT_FULL_BACKTRACE")
    record("expectedBacktrace", "backtrace" => caller)
    raise error
  end
end

class IndependentRuntimeAudit
  def initialize(config)
    config.on_event(:attach_called) do |event|
      source = event.src
      IndependentCucumber12.record("attachCalled", "sourceClass" => source.class.name,
                                  "mime" => event.media_type.to_s, "filename" => event.filename,
                                  "encoding" => source.respond_to?(:encoding) ? source.encoding.name : nil)
    end
  end
end

BeforeAll(name: "independent global before") do
  if ENV["INDEPENDENT_GLOBAL"]
    IndependentCucumber12.native(self, "INDEPENDENT_BEFORE_ALL")
    raise "INDEPENDENT_BEFORE_ALL_ERROR" if ENV["INDEPENDENT_GLOBAL"] == "before_error"
  end
end

AfterAll(name: "independent global after last") do
  IndependentCucumber12.native(self, "INDEPENDENT_AFTER_ALL_LAST") if ENV["INDEPENDENT_GLOBAL"]
end

AfterAll(name: "independent global after") do
  if ENV["INDEPENDENT_GLOBAL"]
    IndependentCucumber12.native(self, "INDEPENDENT_AFTER_ALL")
    raise "INDEPENDENT_AFTER_ALL_ERROR" if ENV["INDEPENDENT_GLOBAL"] == "after_error"
  end
end

Before("@ind_hooks", name: "independent before") do |scenario|
  IndependentCucumber12.native(self, "INDEPENDENT_BEFORE")
  raise "INDEPENDENT_BEFORE_ERROR" if scenario.source_tag_names.include?("@ind_before_error")
end

After("@ind_hooks", name: "independent after") do |scenario|
  IndependentCucumber12.native(self, "INDEPENDENT_AFTER")
  raise "INDEPENDENT_AFTER_ERROR" if scenario.source_tag_names.include?("@ind_after_error")
end

AfterStep("@ind_hooks", name: "independent after step") do |_result|
  IndependentCucumber12.native(self, "INDEPENDENT_AFTER_STEP")
end

AfterStep("@ind_afterstep_error", name: "independent failing after step") { raise "INDEPENDENT_AFTER_STEP_ERROR" }

Around("@ind_around", name: "independent around") do |scenario, execute|
  IndependentCucumber12.native(self, "INDEPENDENT_AROUND_BEFORE")
  raise "INDEPENDENT_AROUND_BEFORE_ERROR" if scenario.source_tag_names.include?("@ind_around_before_error")

  execute.call
  IndependentCucumber12.native(self, "INDEPENDENT_AROUND_AFTER")
  raise "INDEPENDENT_AROUND_AFTER_ERROR" if scenario.source_tag_names.include?("@ind_around_after_error")
end

After("@ind_failure_artifact", name: "independent failed scenario artifact") do |scenario|
  if scenario.failed?
    IndependentCucumber12.native(self, "INDEPENDENT_AFTER_FAILURE_ARTIFACT")
    path = ENV["INDEPENDENT_AFTER_SCREENSHOT_PATH"]
    name = path ? ENV.fetch("INDEPENDENT_AFTER_SCREENSHOT_NAME", "after-failure.png") : "after-failure.png"
    mime = path ? ENV.fetch("INDEPENDENT_AFTER_SCREENSHOT_MIME", "image/png") : "image/png"
    IndependentCucumber12.screenshot(self, 99, name, mime: mime, path: path)
  end
end

Given("independent pass {string}") { |label| IndependentCucumber12.native(self, "INDEPENDENT_PASS:#{label}") }
Given("independent background") { IndependentCucumber12.native(self, "INDEPENDENT_BACKGROUND") }
Given("independent pending") { pending("INDEPENDENT_PENDING") }
Given("independent fail") { IndependentCucumber12.deep_failure }
Given("independent skip") { skip_this_scenario("INDEPENDENT_SKIP") }
Given("independent ambiguous phrase") { true }
Given(/^independent ambiguous (.+)$/) { |_word| true }

Given("independent document {string}:") do |label, document|
  raise "wrong document" unless document == "payload #{label}\nline two"

  IndependentCucumber12.record("document", "label" => label, "value" => document)
end

Given("independent table {string}:") do |label, table|
  raise "wrong table" unless table.raw == [%w[key value], [label, "a|b"]]

  IndependentCucumber12.record("table", "label" => label, "value" => table.raw)
end

Given("independent combined {string}:") do |order, first, second|
  document, table = order == "doc-first" ? [first, second] : [second, first]
  raise "combined doc lost" unless document.to_s == "INDEPENDENT_COMBINED_DOC"
  raise "combined table lost" unless table.raw == [%w[key value], %w[combined retained]]

  IndependentCucumber12.record("combined", "order" => order, "document" => document.to_s, "table" => table.raw)
end

Given("independent combined display {string}:") do |order, document|
  raise "native selected argument changed" unless document.to_s == "INDEPENDENT_COMBINED_DOC"

  IndependentCucumber12.record("combinedDisplay", "order" => order, "actualArgumentClass" => document.class.name,
                              "document" => document.to_s)
end

Given("independent native outputs") do
  IndependentCucumber12.native(self, "INDEPENDENT_NATIVE_LOG_ONE")
  sleep 0.025
  IndependentCucumber12.record("puts", "message" => "INDEPENDENT_NATIVE_PUTS")
  puts "INDEPENDENT_NATIVE_PUTS"
  sleep 0.025
  IndependentCucumber12.native(self, "INDEPENDENT_NATIVE_LOG_TWO")
end

Given("independent media {string} as {string}") do |kind, source|
  bytes, mime = IndependentCucumber12.payload(kind)
  filename = "#{source}-#{kind}.#{kind == 'text' ? 'txt' : kind}"
  path = File.join(ENV.fetch("INDEPENDENT_ARTIFACTS"), filename)
  File.binwrite(path, bytes)
  expected = source == "plain_base64" ? Base64.strict_encode64(bytes) : bytes
  IndependentCucumber12.record("attachment", "filename" => filename, "mime" => mime,
                              "expectedStep" => "independent media #{kind.inspect} as #{source.inspect}",
                              "sha256" => Digest::SHA256.hexdigest(expected),
                              "base64" => Base64.strict_encode64(expected), "source" => source)
  case source
  when "file" then File.open(path, "rb") { |file| attach(file, mime, filename) }
  when "path" then attach(path, mime, filename)
  when "binread" then attach(File.binread(path), mime, filename)
  when "binary" then attach(bytes, mime, filename)
  when "encoded" then attach(Base64.strict_encode64(bytes), "#{mime};base64", filename)
  when "plain_base64" then attach(Base64.strict_encode64(bytes), mime, filename)
  when "stringio" then attach(StringIO.new(bytes), mime, filename)
  when "pipe"
    reader, writer = IO.pipe
    writer.write(bytes)
    writer.close
    begin
      attach(reader, mime, filename)
    ensure
      reader.close
    end
  when "options_hash" then attach(Base64.strict_encode64(bytes), { media_type: mime, content_encoding: "base64" }, filename)
  else raise "unknown source #{source}"
  end
end

Given("independent screenshot {int}") do |number|
  IndependentCucumber12.screenshot(self, number, "screenshot-#{format('%02d', number)}.png")
end

Given("independent retry {string} fails {int} times") do |label, failures|
  $independent_attempts ||= Hash.new(0)
  $independent_attempts[label] += 1
  attempt = $independent_attempts[label]
  IndependentCucumber12.native(self, "INDEPENDENT_RETRY:#{label}:#{attempt}")
  IndependentCucumber12.screenshot(self, 100 + attempt, "retry-#{label}-#{attempt}.png")
  raise "INDEPENDENT_FLAKY:#{label}:#{attempt}" if attempt <= failures
end
