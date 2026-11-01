# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Service::PayloadBuilder do
  describe ".build_launch_start" do
    it "keeps description and attributes explicit even when unset" do
      body = described_class.build_launch_start(
        name: "Launch",
        start_time: Time.utc(2026, 3, 26, 12, 0, 0),
        description: nil,
        attributes: nil,
        mode: "DEFAULT",
        rerun: false,
        rerun_of: nil,
        uuid: "launch-uuid"
      )

      expect(body).to include(
        "name" => "Launch",
        "description" => "",
        "attributes" => [],
        "mode" => "DEFAULT",
        "rerun" => false,
        "uuid" => "launch-uuid"
      )
    end
  end

  describe ".build_log_batch" do
    context "with a flush-local message cache" do
      let(:rendered_messages) { {} }
      let(:record) do
        ReportportalCucumber::Service::QueueProcessor::LogRecord.new(
          sequence: 2, item_uuid: "item-2", launch_uuid: "launch-1", timestamp: Time.utc(2026),
          message: "Caller **text**", level: :info,
          attachment: { name: "evidence.txt", mime: "text/plain", bytes: "preview\0bytes" }
        )
      end

      it "renders once for an unchanged sequence, final filename and mode" do
        expected = described_class.build_log_batch([record])
        expect(described_class).to receive(:enrich_log_message).once.and_call_original

        3.times do
          expect(described_class.build_log_batch([record], rendered_messages: rendered_messages)).to eq(expected)
        end

        expect(rendered_messages).to eq([2, "evidence.txt", "plain"] => expected[:entries].first["message"])
        expect(rendered_messages.values).to all(be_a(String))
        expect(rendered_messages.values).to all(be_frozen)
      end

      it "keys captions by the final collision-safe filename rather than the explicit filename" do
        prefix = record.dup
        prefix.sequence = 1
        expected = described_class.build_log_batch([prefix, record])
        expect(described_class).to receive(:enrich_log_message).exactly(3).times.and_call_original

        single = described_class.build_log_batch([record], rendered_messages: rendered_messages)
        combined = described_class.build_log_batch([prefix, record], rendered_messages: rendered_messages)
        repeated = described_class.build_log_batch([record], rendered_messages: rendered_messages)

        expect(combined).to eq(expected)
        expect(repeated).to eq(single)
        expect(combined[:entries].last["message"]).to include("`evidence-1.txt`")
        expect(single[:entries].first["message"]).to include("`evidence.txt`")
        expect(rendered_messages.keys).to contain_exactly(
          [1, "evidence.txt", "plain"], [2, "evidence.txt", "plain"], [2, "evidence-1.txt", "plain"]
        )
      end

      it "does not reuse another presentation mode's rendered message" do
        expected = %w[plain rich].to_h { |mode| [mode, described_class.build_log_batch([record], presentation: mode)] }
        expect(described_class).to receive(:enrich_log_message).exactly(2).times.and_call_original

        %w[plain rich plain rich].each do |mode|
          expect(described_class.build_log_batch([record], presentation: mode, rendered_messages: rendered_messages))
            .to eq(expected.fetch(mode))
        end

        expect(expected["plain"][:entries].first["message"]).not_to eq(expected["rich"][:entries].first["message"])
        expect(rendered_messages.keys).to contain_exactly([2, "evidence.txt", "plain"], [2, "evidence.txt", "rich"])
      end

      it "does not reuse a different record's message under the same filename and mode" do
        other = record.dup
        other.sequence = 3
        other.message = "Different caller"
        expect(described_class).to receive(:enrich_log_message).exactly(2).times.and_call_original

        first = described_class.build_log_batch([record], rendered_messages: rendered_messages)
        second = described_class.build_log_batch([other], rendered_messages: rendered_messages)

        expect(first[:entries].first["message"]).to start_with("Caller **text**")
        expect(second[:entries].first["message"]).to start_with("Different caller")
        expect(rendered_messages.keys).to contain_exactly([2, "evidence.txt", "plain"], [3, "evidence.txt", "plain"])
      end

      it "does not cache records without a sequence or alias them to a preceding sequenced record" do
        unsequenced = record.to_h.except(:sequence)
        other = unsequenced.transform_keys(&:to_s).merge("message" => "Unsequenced caller")
        expect(described_class).to receive(:enrich_log_message).exactly(3).times.and_call_original

        result = described_class.build_log_batch([record, unsequenced, other], rendered_messages: rendered_messages)

        expect(result[:entries].last["message"]).to start_with("Unsequenced caller")
        expect(rendered_messages.keys).to eq([[2, "evidence.txt", "plain"]])
      end

      it "rebuilds entry metadata and binary parts, without exposing the cached string to entry mutations" do
        record.attachment = { name: "evidence.bin", mime: "application/octet-stream", bytes: "a\0\xFFb".b }
        first = described_class.build_log_batch([record], rendered_messages: rendered_messages)
        first[:entries].first["message"].replace("mutated outbound entry")
        first[:files].first[:bytes].replace("mutated outbound file")
        other = record.dup
        other.item_uuid = "item-elsewhere"
        other.launch_uuid = "launch-elsewhere"
        other.timestamp = Time.utc(2026, 11, 1)
        other.level = :debug
        other.attachment = record.attachment.merge(bytes: "c\xFE\0d".b)
        expected = described_class.build_log_batch([other])
        expect(described_class).not_to receive(:enrich_log_message)

        result = described_class.build_log_batch([other], rendered_messages: rendered_messages)

        expect(result).to eq(expected)
        expect(result[:entries].first).not_to equal(first[:entries].first)
        expect(result[:entries].first).to include("itemUuid" => "item-elsewhere", "launchUuid" => "launch-elsewhere",
                                                "time" => described_class.unix_ms(other.timestamp), "level" => "debug")
        expect(result[:files].first).not_to equal(first[:files].first)
        expect(result[:files].first[:bytes]).to eq("c\xFE\0d".b)
        expect(result[:files].first[:bytes].encoding).to eq(Encoding::BINARY)
        expect(record.attachment[:bytes]).to eq("a\0\xFFb".b)
      end

      it "still validates path-backed attachments on a cache hit and retains their paths rather than bytes" do
        Dir.mktmpdir do |directory|
          path = File.join(directory, "evidence.bin")
          File.binwrite(path, "original\0bytes".b)
          record.attachment = { name: "evidence.bin", mime: "application/octet-stream", path: path }
          first = described_class.build_log_batch([record], rendered_messages: rendered_messages)
          repeated = described_class.build_log_batch([record], rendered_messages: rendered_messages)
          expect(repeated).to eq(first)
          expect(repeated[:files].first).to include(path: path)
          expect(repeated[:files].first).not_to have_key(:bytes)
          expect(repeated[:files].first).not_to equal(first[:files].first)
          File.unlink(path)

          expect { described_class.build_log_batch([record], rendered_messages: rendered_messages) }
            .to raise_error(ArgumentError, /Attachment file does not exist/)
        end
      end
    end

    it "escapes literal NUL only in outbound text, without recursively escaping visible sequences" do
      message = "\0actual\0 literal\\u0000 invalid\xFF\0".b.freeze
      expected = '\\u0000actual\\u0000 literal\\u0000 invalid?\\u0000'
      entry = described_class.build_log_entry(
        launch_uuid: "launch-1", item_uuid: "item-1", time: Time.utc(2026), message: message, level: :info
      )
      expect(entry.fetch("message")).to eq(expected)
      expect(JSON.parse(JSON.generate(entry)).fetch("message")).not_to include("\0")
      again = described_class.build_log_entry(
        launch_uuid: "launch-1", item_uuid: "item-1", time: Time.utc(2026), message: entry["message"], level: :info
      )
      expect(again["message"]).to eq(expected)
      batch = described_class.build_log_batch([
        { launch_uuid: "launch-1", item_uuid: "item-1", timestamp: Time.utc(2026), message: message, level: :info }
      ])
      expect(batch[:entries].first["message"]).to eq(expected)
      expect(message).to eq("\0actual\0 literal\\u0000 invalid\xFF\0".b)
    end

    it "keeps globally unique wire names and original bytes/owners in every collision permutation" do
      names = ["evidence.txt", "evidence.txt", "evidence-1.txt", "bad\r\nname.txt", "bad name.txt", "bad name-1.txt"]
      records = names.each_with_index.map do |name, index|
        { item_uuid: "item-#{index}", launch_uuid: "launch-1", timestamp: Time.utc(2026),
          level: :info, message: "owner-#{index}",
          attachment: { name: name, mime: "text/plain", bytes: "distinct-bytes-#{index}" } }
      end
      records.permutation.each do |ordered|
        payload = described_class.build_log_batch(ordered)
        wire_names = payload.fetch(:files).map { |file| file.fetch(:name) }
        expect(wire_names.uniq.length).to eq(records.length)
        expect(payload.fetch(:entries).map { |entry| entry.dig("file", "name") }).to eq(wire_names)
        payload.fetch(:entries).zip(payload.fetch(:files), ordered).each do |entry, file, original|
          expect(entry.fetch("itemUuid")).to eq(original.fetch(:item_uuid))
          expect(file.fetch(:bytes)).to eq(original.dig(:attachment, :bytes))
          expect(entry.fetch("message")).to include(original.fetch(:message))
        end
      end
    end

    it "rejects duplicated multipart names even when JSON and file lists align" do
      entries = 2.times.map { { "file" => { "name" => "duplicate.txt" } } }
      files = 2.times.map { { name: "duplicate.txt", bytes: "different" } }
      expect { described_class.send(:validate_log_batch!, entries: entries, files: files) }
        .to raise_error(ArgumentError, /Multipart log payload mismatch/)
    end

    it "keeps multipart file names aligned with json_request_part and de-duplicates duplicates" do
      payload = described_class.build_log_batch(
        [
          {
            item_uuid: "item-1",
            launch_uuid: "launch-1",
            message: "png",
            level: :info,
            timestamp: Time.utc(2026, 3, 26, 12, 0, 0),
            attachment: {
              name: "evidence.txt",
              mime: "text/plain",
              bytes: "one"
            }
          },
          {
            item_uuid: "item-1",
            launch_uuid: "launch-1",
            message: "duplicate",
            level: :info,
            timestamp: Time.utc(2026, 3, 26, 12, 0, 1),
            attachment: {
              name: "evidence.txt",
              mime: "text/plain",
              bytes: "two"
            }
          }
        ]
      )

      expect(payload.fetch(:entries).map { |entry| entry.dig("file", "name") }).to eq(["evidence.txt", "evidence-1.txt"])
      expect(payload.fetch(:files).map { |file| file.fetch(:name) }).to eq(["evidence.txt", "evidence-1.txt"])
    end

    it "preserves JSON attachment bytes and pretty prints only the markdown preview" do
      payload = described_class.build_log_batch(
        [
          {
            item_uuid: "item-1",
            launch_uuid: "launch-1",
            message: "Structured config snapshot",
            level: :debug,
            timestamp: Time.utc(2026, 3, 26, 12, 0, 0),
            attachment: {
              name: "config",
              mime: "application/json",
              bytes: '{"buyer":"JPM","amount":10}'
            }
          }
        ]
      )

      entry = payload.fetch(:entries).first
      file = payload.fetch(:files).first

      expect(file.fetch(:name)).to eq("config.json")
      expect(file.fetch(:bytes)).to eq('{"buyer":"JPM","amount":10}')
      expect(entry.fetch("message")).to include("Structured config snapshot")
      expect(entry.fetch("message")).to include("```json", "\"buyer\": \"JPM\"")
    end

    it "normalizes attachment filenames before building json_request_part file references" do
      payload = described_class.build_log_batch(
        [
          {
            item_uuid: "item-1",
            launch_uuid: "launch-1",
            message: "png",
            level: :info,
            timestamp: Time.utc(2026, 3, 26, 12, 0, 0),
            attachment: {
              name: "bad\r\nname",
              mime: "image/png\r\nX-Injected: yes",
              bytes: "png"
            }
          }
        ]
      )

      expect(payload.fetch(:entries).first.dig("file", "name")).to eq("bad name.png")
      expect(payload.fetch(:files).first.fetch(:name)).to eq("bad name.png")
      expect(payload.fetch(:files).first.fetch(:mime)).to eq("image/png")
    end

    it "truncates long text attachment previews after 100 lines" do
      payload = described_class.build_log_batch(
        [
          {
            item_uuid: "item-1",
            launch_uuid: "launch-1",
            message: "Transport trace",
            level: :info,
            timestamp: Time.utc(2026, 3, 26, 12, 0, 0),
            attachment: {
              name: "trace.log",
              mime: "text/plain",
              bytes: (1..120).map { |index| "line-#{index}" }.join("\n")
            }
          }
        ]
      )

      message = payload.fetch(:entries).first.fetch("message")

      expect(message).to include("line-100")
      expect(message).not_to include("line-101")
      expect(message).to include("_Preview · first 100 lines · full file attached_")
    end

    it "keeps file path backed mp4 attachments out of in-memory bytes payloads" do
      Dir.mktmpdir do |dir|
        video_path = File.join(dir, "failure-recording.mp4")
        File.binwrite(video_path, "mp4-bytes")

        payload = described_class.build_log_batch(
          [
            {
              item_uuid: "step-1",
              launch_uuid: "launch-1",
              message: "Failure recording",
              level: :info,
              timestamp: Time.utc(2026, 3, 26, 12, 0, 0),
              attachment: {
                path: video_path,
                mime: nil
              }
            }
          ]
        )

        file = payload.fetch(:files).first

        expect(payload.fetch(:entries).first.dig("file", "name")).to eq("failure-recording.mp4")
        expect(file).to include(name: "failure-recording.mp4", mime: "video/mp4", path: video_path)
        expect(file).not_to have_key(:bytes)
      end
    end
  end
end
