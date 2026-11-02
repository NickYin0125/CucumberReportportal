# frozen_string_literal: true

require "digest"
require "json"
require "reportportal_cucumber"

module M4DeliveryHTTPAudit
  @mutex = Mutex.new
  @requests = []

  def self.snapshot
    @mutex.synchronize { Marshal.load(Marshal.dump(@requests)) }
  end

  def self.record(method, arguments)
    request = { "method" => method, "path" => arguments.fetch(:path) }
    if request["path"].end_with?("/log")
      parts = arguments[:parts]
      entries = parts ? JSON.parse(parts.find { |part| part[:name] == "json_request_part" }.fetch(:body)) : [arguments.fetch(:body)]
      request["entries"] = entries
      request["files"] = Array(parts).filter_map do |part|
        next unless part[:filename]

        bytes = part[:path] ? File.binread(part[:path]) : part.fetch(:body).b
        { "name" => part[:filename], "mime" => part[:content_type], "bytes" => bytes.bytesize,
          "sha256" => Digest::SHA256.hexdigest(bytes) }
      end
    elsif arguments[:body]
      request["uuid"] = arguments[:body]["uuid"]
    end
    response = yield
    request["status"] = response.status
    if request["path"].end_with?("/log")
      body = response.body
      request["ack_ids"] = body.is_a?(Hash) ? [body["id"], *Array(body["responses"]).map { |entry| entry["id"] }].compact : []
    end
    response
  rescue StandardError => error
    request["status"] = error.response.status if error.respond_to?(:response) && error.response
    request["error_class"] = error.class.name
    raise
  ensure
    @mutex.synchronize { @requests << request } if request
  end

  module Methods
    %i[get_json post_json put_json post_multipart].each do |name|
      define_method(name) do |**arguments|
        M4DeliveryHTTPAudit.record(name.to_s, arguments) { super(**arguments) }
      end
    end
  end
end

ReportportalCucumber::Transport::HTTPClient.prepend(M4DeliveryHTTPAudit::Methods)

if ENV["M4_HTTP_AUDIT_PATH"]
  at_exit do
    File.open(ENV.fetch("M4_HTTP_AUDIT_PATH"), "wb", 0o600) do |file|
      file.write(JSON.pretty_generate(M4DeliveryHTTPAudit.snapshot) + "\n")
    end
  end
end
