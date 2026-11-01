# frozen_string_literal: true

require "reportportal_cucumber"
require "json"
require "fileutils"

output = ENV.fetch("QA_CACHE_PROBE_OUT")
FileUtils.mkdir_p(File.dirname(output))
errors, delivered, accepted = [], [], []
api = Object.new
api.define_singleton_method(:log_batch) do |entries:, files:|
  delivered << { entries: entries, filenames: files.map { |file| file[:name] } }
  { "responses" => entries.map { { "id" => "confirmed" } } }
end
config = ReportportalCucumber::Config.new(presentation: "plain", batch_size_logs: 2, queue_max_records: 100,
  queue_max_bytes: 1_000_000, flush_interval: 10, spool_dir: output.delete_suffix(".json") + "-spool")
processor = ReportportalCucumber::Service::QueueProcessor.new(api: api, config: config, on_error: lambda do |error|
  errors << { class: error.class.name, message: error.message, backtrace: error.backtrace&.first(12) }
end)
2.times do |index|
  accepted << processor.emit_log(item_uuid: "owner-#{index}", launch_uuid: "launch", level: :info,
    timestamp: Time.utc(2026, 11, 1) + index, message: "Caller #{index}\0 literal\\u0000",
    attachment: { name: "#{index}.txt", mime: "text/plain", bytes: "preview-#{index}\0 original bytes" })
end
shutdown = processor.shutdown(timeout: 2)
result = { ruby: RUBY_DESCRIPTION, cucumber: Gem.loaded_specs["cucumber"]&.version&.to_s,
  sdk: ReportportalCucumber::VERSION, loaded_queue: $LOADED_FEATURES.grep(%r{/service/queue_processor\.rb\z}),
  accepted: accepted, shutdown: shutdown, diagnostics: processor.diagnostics, errors: errors, delivered: delivered }
File.write(output, JSON.pretty_generate(result) + "\n")
puts JSON.generate(result)
