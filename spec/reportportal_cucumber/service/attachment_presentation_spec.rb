# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Bounded attachment presentation" do
  let(:builder) { ReportportalCucumber::Service::PayloadBuilder }

  def batch(attachment)
    ReportportalCucumber::Service::PayloadBuilder.build_log_batch([
      { item_uuid: "step-1", launch_uuid: "launch-1", message: "Evidence", level: :debug,
        timestamp: Time.utc(2026, 9, 23), attachment: attachment }
    ])
  end

  it "renders matching small JSON previews for paths and bytes without materializing the file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "evidence.json")
      bytes = '{"status":"ok","amount":12}'
      File.write(path, bytes)
      expect(File).not_to receive(:binread)
      streamed = batch(path: path)
      memory = batch(name: "evidence.json", mime: "application/json", bytes: bytes)

      expect(streamed[:entries].first["message"]).to eq(memory[:entries].first["message"])
      expect(streamed[:entries].first["message"]).to include('"status": "ok"')
      expect(streamed[:files].first).to include(path: path)
      expect(streamed[:files].first).not_to have_key(:bytes)
      expect(memory[:files].first[:bytes]).to eq(bytes)
    end
  end

  it "reads at most the byte budget plus one byte for a large single-line JSON file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "large.json")
      File.write(path, JSON.generate(data: "x" * 100_000))
      expect(File).to receive(:open).with(path, "rb").and_wrap_original do |original, *args, &block|
        original.call(*args) do |io|
          expect(io).to receive(:read).with(builder::PREVIEW_MAX_BYTES + 1).and_call_original
          block.call(io)
        end
      end

      payload = batch(path: path)
      message = payload[:entries].first["message"]
      expect(message).to include("Preview truncated", "Full log is attached as `large.json`.")
      expect(message.bytesize).to be < builder::PREVIEW_MAX_BYTES + 256
      expect(payload[:files].first).to include(path: path)
      expect(File.size(path)).to be > 100_000
    end
  end

  it "bounds byte-backed JSON without modifying the full oversized attachment" do
    original = JSON.generate(data: "x" * 100_000).freeze
    payload = batch(name: "large.json", mime: "application/json", bytes: original)

    expect(payload[:entries].first["message"]).to include("Preview truncated")
    expect(payload[:entries].first["message"].bytesize).to be < builder::PREVIEW_MAX_BYTES + 256
    expect(payload[:files].first[:bytes]).to eq(original)
  end

  it "enforces the line limit and retains the complete text file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "trace.log")
      File.write(path, (1..500).map { |index| "line-#{index}" }.join("\n"))
      message = batch(path: path)[:entries].first["message"]

      expect(message).to include("line-100", "Preview truncated")
      expect(message).not_to include("line-101")
      expect(File.readlines(path).size).to eq(500)
    end
  end

  it "preserves non-ASCII UTF-8 characters and safely handles a split final character" do
    bytes = ("\u754c" * 10_000).freeze
    message = batch(name: "unicode.txt", mime: "text/plain", bytes: bytes)[:entries].first["message"]

    expect(message).to be_valid_encoding
    expect(message).to include("\u754c", "Preview truncated")
    expect(message.bytesize).to be < builder::PREVIEW_MAX_BYTES + 256
  end

  it "prevents embedded backticks from prematurely closing a text preview" do
    message = batch(name: "code.txt", mime: "text/plain", bytes: "```\n<script>ignored()</script>")[:entries].first["message"]

    expect(message).to include("~~~text\n```\n<script>ignored()</script>\n~~~")
  end

  it "includes a normal video link without reading a binary preview" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "video.mp4")
      File.write(path, "binary")
      expect(File).not_to receive(:open)
      expect(batch(path: path)[:entries].first["message"]).to eq("Evidence")
    end

    url = "https://rp.example.test/automation-videos/clip.mp4?part=1&version=2"
    message = builder.build_video_markdown_message(message: "Recording", url: url)
    expect(message).to include("<video", "part=1&amp;version=2", "[Open video](<#{url}>)")
  end

  it "rejects script URLs instead of adding an unsafe fallback link" do
    expect do
      builder.build_video_markdown_message(message: nil, url: "javascript:alert(1)")
    end.to raise_error(ArgumentError, /HTTP/)
  end
end
