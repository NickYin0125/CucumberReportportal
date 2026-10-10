# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Transport::MultipartHelper do
  it "counts the exact UTF-8 JSON body size for a single attachment-free log" do
    entries = [{ "message" => "雪と café", "level" => "info", "itemUuid" => "item-1" }]

    expect(described_class.log_batch_bytes(entries: entries, files: [])).to eq(JSON.generate(entries.first).bytesize)
  end

  it "matches emitted bytes for multipart framing, escaped headers, and mixed MIME files" do
    entries = [
      { "message" => "雪と café", "level" => "info", "file" => { "name" => "quote\".png" } },
      { "message" => "trace", "level" => "debug", "file" => { "name" => "trace.log" } }
    ]
    files = [
      { name: "quote\".png", mime: "image/png", bytes: "\x89PNG\r\n\x00".b },
      { name: "trace.log", mime: "text/plain", bytes: "line\r\n".b }
    ]
    boundary = "----rp" + ("a" * 24)
    parts = [{ name: "json_request_part", content_type: "application/json", body: JSON.generate(entries) }]
    files.each do |file|
      parts << { name: "file", filename: file.fetch(:name), content_type: file.fetch(:mime), body: file.fetch(:bytes) }
    end

    expected = described_class.encode(parts: parts, boundary: boundary).bytesize
    estimate = described_class.encoded_length(parts: parts, boundary: boundary)
    public_estimate = described_class.log_batch_bytes(entries: entries, files: files)

    expect(estimate).to eq(expected)
    expect(public_estimate).to eq(expected)
  end

  it "sizes path-backed files with stat and streams file bytes instead of reading them all at once" do
    Dir.mktmpdir("m4a-multipart-") do |directory|
      path = File.join(directory, "payload.bin")
      File.binwrite(path, "x" * (described_class::FILE_CHUNK_SIZE + 17))
      entries = [{ "message" => "file", "level" => "info", "file" => { "name" => "payload.bin" } }]
      files = [{ name: "payload.bin", mime: "application/octet-stream", path: path }]

      expect(File).to receive(:read).never
      estimate = described_class.log_batch_bytes(entries: entries, files: files)
      expect(estimate).to be > File.size(path)

      source = described_class.body_source(
        parts: [
          { name: "json_request_part", content_type: "application/json", body: JSON.generate(entries) },
          { name: "file", filename: "payload.bin", content_type: "application/octet-stream", path: path }
        ],
        boundary: "----rp" + ("b" * 24),
        max_bytes: estimate + 1_000
      )
      expect(source.stream).not_to be_nil
      expect(source.length).to be > File.size(path)
      expect(source.stream.read.bytesize).to eq(source.length)
    ensure
      source&.tempfile&.close!
    end
  end

  it "aborts bounded path construction if a file grows past the wire cap and closes its tempfile" do
    Dir.mktmpdir("m4a-growth-") do |directory|
      path = File.join(directory, "growing.bin")
      File.binwrite(path, "a" * 32)
      parts = [
        { name: "json_request_part", content_type: "application/json", body: '[{"file":{"name":"growing.bin"}}]' },
        { name: "file", filename: "growing.bin", content_type: "application/octet-stream", path: path }
      ]
      initial_length = described_class.encoded_length(parts: parts, boundary: "fixed")
      original_open = File.method(:open)
      tempfiles = []
      tempfile_paths = []
      reads = []
      allow(Tempfile).to receive(:new).and_wrap_original do |original, *arguments|
        tempfile = original.call(*arguments)
        tempfiles << tempfile
        tempfile_paths << tempfile.path
        tempfile
      end
      allow(File).to receive(:open).and_wrap_original do |original, opened_path, *arguments, **keywords, &block|
        if opened_path == path && arguments.first == "rb"
          original_open.call(path, "ab") { |file| file.write("b" * 256) }
          io = original_open.call(opened_path, *arguments, **keywords)
          bounded_reader = Object.new
          bounded_reader.define_singleton_method(:read) do |length|
            reads << length
            io.read(length)
          end
          bounded_reader.define_singleton_method(:close) { io.close }
          begin
            block.call(bounded_reader)
          ensure
            io.close unless io.closed?
          end
        else
          original.call(opened_path, *arguments, **keywords, &block)
        end
      end

      expect do
        described_class.body_source(parts: parts, boundary: "fixed", max_bytes: initial_length)
      end.to raise_error(described_class::SizeLimitError)
      expect(reads).to all(be_a(Integer).and(be > 0).and(be <= described_class::FILE_CHUNK_SIZE + 1))
      expect(tempfiles).not_to be_empty
      expect(tempfiles.last).to be_closed
      expect(File.exist?(tempfile_paths.last)).to be(false)
    end
  end
end

RSpec.describe ReportportalCucumber::Transport::HTTPClient do
  it "rejects oversized JSON and multipart log bodies before WebMock sees an HTTP request" do
    config = ReportportalCucumber::Config.new(
      endpoint: "https://rp-wire-limit.example.test",
      api_key: "test-token",
      batch_max_bytes: 128,
      retry_attempts: 4,
      retry_base_interval: 0,
      retry_max_interval: 0
    )
    client = described_class.new(config: config)
    entry = { "message" => "x" * 1_000, "level" => "info", "itemUuid" => "item-1" }

    expect do
      client.post_json(path: "api/v1/demo/log", body: entry)
    end.to raise_error(ReportportalCucumber::Transport::MultipartHelper::SizeLimitError)
    expect do
      client.post_multipart(
        path: "api/v1/demo/log",
        parts: [
          { name: "json_request_part", content_type: "application/json", body: JSON.generate([entry.merge("file" => { "name" => "large.txt" })]) },
          { name: "file", filename: "large.txt", content_type: "text/plain", body: "y" * 1_000 }
        ]
      )
    end.to raise_error(ReportportalCucumber::Transport::MultipartHelper::SizeLimitError)

    expect(a_request(:post, %r{rp-wire-limit\.example\.test/.*/log})).not_to have_been_made
  ensure
    client&.close
  end
end
