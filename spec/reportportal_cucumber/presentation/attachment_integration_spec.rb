# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Ledger attachment messages" do
  let(:builder) { ReportportalCucumber::Service::PayloadBuilder }
  let(:png_header) { "\x89PNG\r\n\x1a\n".b + [13].pack("N") + "IHDR" + [640, 360].pack("NN") }

  def batch(attachment = nil, message: "Attachment: original", style: "default", **attributes)
    attachment ||= attributes
    attachment = attachment.merge(caption_style: style) if style
    builder.build_log_batch([{ item_uuid: "owner", launch_uuid: "launch", timestamp: Time.utc(2026, 10, 31),
                               level: :info, message: message, attachment: attachment }])
  end

  it "matches the PNG, text and JSON goldens and preserves their exact file bytes" do
    png = png_header.ljust(5421, "\0").freeze
    text = ("a" * 34 + "\n" + "b" * 35 + "\n").freeze
    json = '{"source":"independent acceptance","synthetic":true,"values":[1,true,null]}'.freeze
    expected = ["`visible-fixture.png` \u00b7 PNG \u00b7 640 \u00d7 360 \u00b7 5.3 KB",
                "`visible-fixture.txt` \u00b7 Text \u00b7 2 lines \u00b7 71 B\n\n```text\n#{text.rstrip}\n```",
                "`visible-fixture.json` \u00b7 JSON \u00b7 75 B\n\n```json\n{\n  \"source\": \"independent acceptance\",\n  \"synthetic\": true,\n  \"values\": [1, true, null]\n}\n```"]
    [[png, "png", "image/png"], [text, "txt", "text/plain"], [json, "json", "application/json"]].each_with_index do |(bytes, ext, mime), index|
      result = batch(name: "visible-fixture.#{ext}", mime: mime, bytes: bytes)
      expect(result[:entries].first.fetch("message")).to eq(expected[index])
      expect(result[:files].first.fetch(:bytes)).to eq(bytes)
      expect(result[:files].first.fetch(:mime)).to eq(mime)
      expect(result[:entries].first).to include("itemUuid" => "owner", "level" => "info", "time" => "1793404800000")
    end
  end

  it "preserves literal caller text even when it resembles a removed client default" do
    attachment = { name: "x.png", mime: "image/png", bytes: "AAAA" }
    ["Attachment: x.png", "Failure evidence: x.png", "<raw> **Markdown**"].each do |message|
      result = batch(attachment, message: message, style: nil)
      expect(result[:entries].first["message"]).to eq("#{message}\n\n`x.png` \u00b7 PNG \u00b7 4 B")
    end
    result = batch(attachment, message: "Failure evidence: x.png", style: "evidence")
    expect(result[:entries].first["message"]).to eq("`x.png` \u00b7 PNG \u00b7 4 B \u00b7 failure evidence")
  end

  it "preserves the legacy raw-log bytes rather than importing newer raw-log normalization" do
    literal = "literal\0**Markdown**"
    entry = builder.build_log_entry(launch_uuid: "launch", item_uuid: "owner", time: Time.utc(2026, 10, 31),
                                    message: literal, level: :info)
    expect(entry["message"]).to eq(literal)
    expect(batch(name: "x.png", mime: "image/png", bytes: "AAAA", message: literal, style: nil)[:entries].first["message"])
      .to start_with("#{literal}\n\n`x.png`")
  end

  it "restores the exact legacy NUL preview on a helper failure" do
    expect(ReportportalCucumber::Presentation::MarkdownText).to receive(:fence).once.and_raise("SECRET123")
    expect(ReportportalCucumber.logger).to receive(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    expect(batch(name: "data.txt", mime: "text/plain", bytes: "before\0after")[:entries].first["message"])
      .to eq("Attachment: original\n\n```text\nbefore\0after\n```")
  end

  it "uses declared kinds, never sniffs a negative-control body or trusts a misleading extension" do
    control = Base64.strict_encode64(png_header).freeze
    result = batch(name: "plain_base64.png", mime: "image/png", bytes: control)
    expect(result[:entries].first["message"]).to eq("`plain_base64.png` \u00b7 PNG \u00b7 #{control.bytesize} B")
    expect(result[:files].first[:bytes]).to eq(control)
    result = batch(name: "misleading.json", mime: "image/png", bytes: '{"a":1}')
    expect(result[:entries].first["message"]).to eq("`misleading.json` \u00b7 PNG \u00b7 7 B")
    expect(batch(name: "data.json", mime: "application/vnd.api+json", bytes: '{"a":1}')[:entries].first["message"])
      .to include("JSON", "```json\n{ \"a\": 1 }\n```")
  end

  it "labels every declared P5 kind" do
    { "image/png" => "PNG", "image/jpeg" => "JPEG", "image/gif" => "GIF", "image/webp" => "WebP",
      "image/svg+xml" => "SVG", "application/json" => "JSON", "application/x+json" => "JSON",
      "text/plain" => "Text", "text/csv" => "CSV", "text/html" => "HTML", "application/xml" => "XML",
      "text/xml" => "XML", "application/pdf" => "PDF", "video/mp4" => "MP4", "video/webm" => "WebM",
      "application/zip" => "ZIP", "application/octet-stream" => "File" }.each do |mime, kind|
      expect(batch(name: "fixture.dat", mime: mime, bytes: "")[:entries].first["message"]).to include(" \u00b7 #{kind} \u00b7 ")
    end
  end

  it "uses the exact line and byte truncation notes, with no complete-line count on clipped data" do
    lines = (1..340).map { |index| "line #{index}" }.join("\n")
    result = batch(name: "large.txt", mime: "text/plain", bytes: lines)
    message = result[:entries].first["message"]
    expect(message).to end_with("_Preview \u00b7 first 100 lines \u00b7 full file attached_")
    expect(message).not_to include("line 101", "340 lines")
    bytes = "x" * (48 * 1024)
    result = batch(name: "large.txt", mime: "text/plain", bytes: bytes)
    expect(result[:entries].first["message"]).to end_with("_Preview \u00b7 first 16 KB of 48 KB \u00b7 full file attached_")
    expect(result[:files].first[:bytes]).to eq(bytes)
  end

  it "does not parse JSON outside either preview limit, even when compacting could make it fit" do
    line_limited = "[\n" + Array.new(110, "1").join(",\n") + "\n]"
    byte_limited = '{"data":"' + 'x' * (48 * 1024) + '"}'
    expect(JSON).not_to receive(:parse)
    [line_limited, byte_limited].each do |bytes|
      result = batch(name: "large.json", mime: "application/json", bytes: bytes)
      expect(result[:entries].first["message"]).to include("_Preview \u00b7 first")
      expect(result[:files].first[:bytes]).to eq(bytes)
    end
  end

  it "uses raw in-budget JSON rather than truncating pretty-print expansion" do
    bytes = JSON.generate(Array.new(100) { { a: 1, b: 2 } })
    result = batch(name: "large.json", mime: "application/json", bytes: bytes)
    expect(result[:entries].first["message"]).to include("```json\n#{bytes}\n```")
    expect(result[:entries].first["message"]).not_to include("_Preview")
  end

  it "keeps baseline pretty JSON for an unsupported value, but falls back the whole message on helper exceptions" do
    attachment = { name: "data.json", mime: "application/json", bytes: '{"a":1}' }
    allow(ReportportalCucumber::Presentation::LedgerJson).to receive(:format).and_return(nil)
    expect(batch(attachment)[:entries].first["message"])
      .to eq("`data.json` \u00b7 JSON \u00b7 7 B\n\n```json\n{\n  \"a\": 1\n}\n```")
    allow(ReportportalCucumber::Presentation::LedgerJson).to receive(:format).and_raise(JSON::GeneratorError, "SECRET123")
    expect(ReportportalCucumber.logger).to receive(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    expect(batch(attachment)[:entries].first["message"])
      .to eq("Attachment: original\n\n```json\n{\n  \"a\": 1\n}\n```")
  end

  it "restores the exact text baseline when line-count formatting raises" do
    expect(ReportportalCucumber::Presentation::Units).to receive(:count).once.and_raise("SECRET123")
    expect(ReportportalCucumber.logger).to receive(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    expect(batch(name: "data.txt", mime: "text/plain", bytes: "hello\n")[:entries].first["message"])
      .to eq("Attachment: original\n\n```text\nhello\n```")
  end

  it "uses the final collision-safe multipart name in each caption without changing explicit-name normalization" do
    records = ["visible-fixture.png", "visible-fixture.txt", "visible-fixture.json", "after-failure.jpg", "plain_base64.png",
               "literal `chip` | <tag>.txt", "\u4e2d\u6587.txt", "visible-fixture.png"].map do |name|
      { item_uuid: "owner", launch_uuid: "launch", timestamp: Time.utc(2026, 10, 31), level: :info, message: "caller",
        attachment: { name: name, mime: "application/octet-stream", bytes: "original" } }
    end
    result = builder.build_log_batch(records)
    result[:entries].zip(result[:files]).each do |entry, file|
      expect(entry.dig("file", "name")).to eq(file[:name])
      expect(entry["message"]).to start_with("caller\n\n#{ReportportalCucumber::Presentation::MarkdownText.code(file[:name])} \u00b7 File")
      expect(file[:bytes]).to eq("original")
    end
    expect(result[:files].first(7).map { |file| file[:name] })
      .to eq(records.first(7).map { |record| builder.normalize_attachment(record[:attachment])[:name] })
    expect(result[:files].last[:name]).to eq("visible-fixture-1.png")
  end

  it "reads only the bounded image header from paths and preserves the path-backed original" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "image.png")
      File.binwrite(path, png_header.ljust(100_000, "x"))
      digest = Digest::SHA256.file(path).hexdigest
      expect(File).not_to receive(:binread)
      expect(File).to receive(:open).with(path, "rb").and_wrap_original do |original, *args, &block|
        original.call(*args) do |io|
          expect(io).to receive(:read).with(64 * 1024).and_call_original
          block.call(io)
        end
      end
      result = batch(path: path, mime: "image/png")
      expect(result[:entries].first["message"]).to eq("`image.png` \u00b7 PNG \u00b7 640 \u00d7 360 \u00b7 98 KB")
      expect(result[:files].first).to include(path: path)
      expect(result[:files].first).not_to have_key(:bytes)
      expect(Digest::SHA256.hexdigest(File.read(path, mode: "rb"))).to eq(digest)
    end
  end

  [[:AttachmentCaption, :format], [:AttachmentCaption, :kind], [:ImageDimensions, :read],
   [:MarkdownText, :code], [:MarkdownText, :fence], [:LedgerJson, :format], [:Units, :bytes]].each do |helper, entry|
    it "restores the whole baseline with one sanitized warning when #{helper}.#{entry} raises" do
      attachment = { name: "data.json", mime: "application/json", bytes: '{"a":1}', caption_style: "default" }
      baseline = "Attachment: data.json\n\n```json\n{\n  \"a\": 1\n}\n```"
      logger = double("logger", warn: nil)
      allow(ReportportalCucumber).to receive(:logger).and_return(logger)
      expect(ReportportalCucumber::Presentation.const_get(helper)).to receive(entry).once.and_raise("SECRET123")
      result = batch(attachment, message: "Attachment: data.json")
      expect(result[:entries].first["message"]).to eq(baseline)
      expect(result[:files].first[:bytes]).to eq('{"a":1}')
      expect(logger).to have_received(:warn).with(ReportportalCucumber::Presentation::Fallback::WARNING).once
    end
  end

  it "retains original preview filenames during fallback after default-name presentation" do
    attachment = { name: "given-step.txt", baseline_name: "attachment.txt", mime: "text/plain", bytes: "x" * (48 * 1024) }
    allow(ReportportalCucumber::Presentation::AttachmentCaption).to receive(:format).and_raise("synthetic")
    allow(ReportportalCucumber.logger).to receive(:warn)
    result = batch(attachment, message: "Attachment: attachment.txt")
    expect(result[:entries].first["message"]).to end_with("Preview truncated. Full log is attached as `attachment.txt`.")
  end
end
