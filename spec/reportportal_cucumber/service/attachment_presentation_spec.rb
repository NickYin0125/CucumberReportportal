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

  it "escapes NUL in byte and path previews while preserving exact original attachment hashes" do
    bytes = "before\0after\nvisible\\u0000\ninvalid\xFF".b.freeze
    original_sha = Digest::SHA256.hexdigest(bytes)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "nul.txt")
      File.binwrite(path, bytes)
      memory = batch(name: "nul.txt", mime: "text/plain", bytes: bytes)
      streamed = batch(path: path, mime: "text/plain")

      expect(memory[:entries].first["message"]).to eq(streamed[:entries].first["message"])
      [memory, streamed].each do |payload|
        message = payload[:entries].first["message"]
        expect(message).to include('before\\u0000after', 'visible\\u0000', "invalid?")
        expect(message).not_to include("\0")
        expect(message).to be_valid_encoding
      end
      expect(Digest::SHA256.hexdigest(memory[:files].first.fetch(:bytes))).to eq(original_sha)
      expect(streamed[:files].first).to include(path: path)
      expect(streamed[:files].first).not_to have_key(:bytes)
      expect(Digest::SHA256.file(path).hexdigest).to eq(original_sha)
      expect(Digest::SHA256.hexdigest(bytes)).to eq(original_sha)
    end
  end

  it "counts visible NUL expansion in the byte and line preview budgets" do
    ["\0" * builder::PREVIEW_MAX_BYTES, ("\0\n" * 120), ("\u754c\0" * 4000)].each do |bytes|
      message = batch(name: "nul.txt", mime: "text/plain", bytes: bytes)[:entries].first["message"]
      content = message.split("```text\n", 2).last.split("\n```", 2).first
      expect(content).not_to include("\0")
      expect(content).to include('\\u0000')
      expect(content.bytesize).to be <= builder::PREVIEW_MAX_BYTES
      expect(content.lines.length).to be <= builder::PREVIEW_MAX_LINES
      expect(content).to be_valid_encoding
      expect(message).to include("Preview truncated")
    end
  end

  it "does not modify binary attachments or unescape valid JSON NUL sequences" do
    binary = "\0\xFF\0".b.freeze
    payload = batch(name: "data.bin", mime: "application/octet-stream", bytes: binary)
    expect(payload[:entries].first["message"]).to eq("Evidence")
    expect(payload[:files].first[:bytes]).to eq(binary)

    json = '{"text":"before\\u0000after"}'.freeze
    payload = batch(name: "data.json", mime: "application/json", bytes: json)
    expect(payload[:entries].first["message"]).to include('before\\u0000after')
    expect(payload[:entries].first["message"]).not_to include("\0")
    expect(payload[:files].first[:bytes]).to eq(json)
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
