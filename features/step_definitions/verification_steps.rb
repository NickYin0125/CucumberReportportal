# frozen_string_literal: true

require "base64"
require "socket"

module VerificationArtifacts
  PNG_1X1_BASE64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nXxkAAAAASUVORK5CYII="
  SMALL_PDF = <<~PDF.freeze
    %PDF-1.4
    1 0 obj
    << /Type /Catalog /Pages 2 0 R >>
    endobj
    2 0 obj
    << /Type /Pages /Kids [3 0 R] /Count 1 >>
    endobj
    3 0 obj
    << /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>
    endobj
    4 0 obj
    << /Length 44 >>
    stream
    BT /F1 12 Tf 20 100 Td (ReportPortal PDF) Tj ET
    endstream
    endobj
    trailer
    << /Root 1 0 R >>
    %%EOF
  PDF

  def verification_tmp_dir
    @verification_tmp_dir ||= begin
      directory = File.expand_path("../../tmp/verification", __dir__)
      FileUtils.mkdir_p(directory)
      directory
    end
  end

  def verification_file(name, bytes)
    path = File.join(verification_tmp_dir, name)
    File.binwrite(path, bytes)
    path
  end

  def attach_path(path, mime:, message:, level: :info)
    @attachment_sequence ||= []
    @attachment_sequence << File.basename(path)
    File.open(path, "rb") do |io|
      rp_attach(io, name: File.basename(path), mime: mime, message: message, level: level)
    end
  end

  def build_text_attachment
    verification_file("verification-log.txt", "verification text attachment\n")
  end

  def build_png_attachment(name)
    verification_file(name, Base64.decode64(PNG_1X1_BASE64))
  end

  def build_pdf_attachment
    verification_file("verification-brochure.pdf", SMALL_PDF)
  end

  def build_binary_attachment
    verification_file("verification-payload.bin", [0xCA, 0xFE, 0xBA, 0xBE, 0x10, 0x20, 0x30].pack("C*"))
  end

  def build_trace_attachment
    verification_file("trace.log", "TRACE request\nTRACE response\n")
  end
end

World(VerificationArtifacts)

Given("a step that generates a text file attachment") do
  @text_path = build_text_attachment
  rp_log("Preparing plain-text attachment", level: :trace)
  attach_path(@text_path, mime: "text/plain", message: "plain text log attachment")
end

Given("a step that simulates a UI screenshot {string}") do |filename|
  @png_path = build_png_attachment(filename)
  rp_log("Captured simulated UI screenshot #{filename}", level: :debug)
  attach_path(@png_path, mime: "image/png", message: "ui screenshot capture")
end

Given("a step that generates a small PDF and binary attachment") do
  @pdf_path = build_pdf_attachment
  @bin_path = build_binary_attachment
  attach_path(@pdf_path, mime: "application/pdf", message: "small verification pdf")
  attach_path(@bin_path, mime: "application/octet-stream", message: "raw binary payload")
end

When("I upload ordered attachments within the same step") do
  @ordered_attachment_names = []
  rp_step("Ordered attachment upload") do
    [
      [@text_path || build_text_attachment, "text/plain", "ordered text upload"],
      [@png_path || build_png_attachment("verification_ui.png"), "image/png", "ordered png upload"],
      [@pdf_path || build_pdf_attachment, "application/pdf", "ordered pdf upload"]
    ].each do |path, mime, message|
      @ordered_attachment_names << File.basename(path)
      attach_path(path, mime: mime, message: message)
    end
  end
end

Then("all attachments should be ready for ReportPortal inspection") do
  expect(@attachment_sequence).to include(
    "verification-log.txt",
    "verification_ui.png",
    "verification-brochure.pdf",
    "verification-payload.bin"
  )
  expect(@ordered_attachment_names).to eq(
    ["verification-log.txt", "verification_ui.png", "verification-brochure.pdf"]
  )
end

Given("I perform a complex API transaction:") do |table|
  @api_transaction_rows = table.hashes
  @api_log_levels = []

  rp_step("Complex API transaction") do
    @api_transaction_rows.each do |row|
      rp_step(row.fetch("action")) do
        request_body = {
          endpoint: row.fetch("endpoint"),
          method: "POST",
          payload: {
            correlationId: SecureRandom.uuid,
            amount: row.fetch("status").to_i
          }
        }
        response_body = {
          endpoint: row.fetch("endpoint"),
          status: row.fetch("status").to_i,
          body: {
            result: "ok",
            action: row.fetch("action")
          }
        }

        rp_log("TRACE request: #{JSON.pretty_generate(request_body)}", level: :trace)
        rp_log("DEBUG response: #{JSON.pretty_generate(response_body)}", level: :debug)
        @api_log_levels << "trace" << "debug"
      end
    end
  end
end

Then("the technical log payload should be recorded") do
  expect(@api_transaction_rows.map { |row| row.fetch("action") }).to eq(%w[Login Order Pay])
  expect(@api_log_levels.count("trace")).to eq(3)
  expect(@api_log_levels.count("debug")).to eq(3)
end

Given("I execute a purchase flow for {string} with currency {string} and amount {string}") do |user, currency, amount|
  @outline_payload = {
    user: user,
    currency: currency,
    amount: amount
  }
  rp_step("Outline purchase flow") do
    rp_log("Running outline payload #{@outline_payload.to_json}", level: :info)
  end
end

Then("the outline metadata should be prepared for ReportPortal") do
  expect(@outline_payload.keys).to eq(%i[user currency amount])
  expect(@outline_payload.values).to all(be_a(String))
end

When("I emit a long formatted API debug log with 500 lines") do
  lines = (1..500).map do |index|
    {
      sequence: index,
      service: "orders",
      request: {
        endpoint: "/orders/#{index}",
        method: "POST",
        headers: {
          "X-Correlation-Id" => SecureRandom.uuid
        }
      },
      response: {
        status: 200,
        body: {
          ok: true,
          amount: index
        }
      }
    }
  end

  formatted = JSON.pretty_generate(lines)
  @long_debug_log = "```json\n#{formatted}\n```"
  @long_debug_line_count = formatted.lines.count

  rp_step("Large debug payload") do
    rp_log(@long_debug_log, level: :debug)
  end
end

Then("the long debug log payload should be prepared") do
  expect(@long_debug_line_count).to be >= 500
  expect(@long_debug_log).to start_with("```json\n")
  expect(@long_debug_log).to end_with("\n```")
end

When("I upload multiple mime attachments in the same step") do
  png_path = build_png_attachment("test.png")
  trace_path = build_trace_attachment
  @multi_mime_names = []

  rp_step("Dual attachment upload") do
    [
      [png_path, "image/png", "ui proof"],
      [trace_path, "text/plain", "transport trace"]
    ].each do |path, mime, message|
      @multi_mime_names << File.basename(path)
      attach_path(path, mime: mime, message: message, level: :info)
    end
  end
end

Then("the multi mime attachment payload should be prepared") do
  expect(@multi_mime_names).to eq(%w[test.png trace.log])
end

When("I perform a nested business flow with manual steps") do
  @nested_step_names = []
  @nested_log_messages = []

  rp_step("Checkout orchestration") do
    [
      ["Authenticate", "DEBUG auth payload"],
      ["Create order", "INFO order request accepted"],
      ["Capture payment", "TRACE payment gateway callback"]
    ].each do |step_name, message|
      rp_step(step_name) do
        @nested_step_names << step_name
        @nested_log_messages << message
        rp_log(message, level: :info)
      end
    end
  end
end

Then("the nested step hierarchy should be prepared") do
  expect(@nested_step_names).to eq(["Authenticate", "Create order", "Capture payment"])
  expect(@nested_log_messages.length).to eq(3)
end

Given("I record the current process identity for join verification") do
  @join_identity = {
    pid: Process.pid,
    host: Socket.gethostname
  }
  rp_log("Join verification process #{@join_identity.to_json}", level: :info)
end

Then("the scenario should be part of a shared launch when run in parallel") do
  expect(@join_identity.fetch(:pid)).to be > 0
  expect(@join_identity.fetch(:host)).not_to be_empty
end
