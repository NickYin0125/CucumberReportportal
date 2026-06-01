# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Cucumber::World do
  after do
    ReportportalCucumber.current_runtime = nil
  end

  subject(:world) do
    Class.new do
      include ReportportalCucumber::Cucumber::World
    end.new
  end

  it "supports rp_attach(file_path, mime_type: nil) without reading the attachment into memory" do
    Dir.mktmpdir do |dir|
      video_path = File.join(dir, "failure.mp4")
      File.binwrite(video_path, "mp4-bytes")
      runtime = instance_double("runtime")
      ReportportalCucumber.current_runtime = runtime

      expect(runtime).to receive(:emit_world_attachment).with(
        hash_including(
          message: "Attachment: failure.mp4",
          attachment: {
            name: "failure.mp4",
            mime: "video/mp4",
            path: video_path
          }
        )
      )

      world.rp_attach(video_path, mime_type: nil)
    end
  end

  it "keeps backwards-compatible byte attachments with explicit name and mime" do
    runtime = instance_double("runtime")
    ReportportalCucumber.current_runtime = runtime

    expect(runtime).to receive(:emit_world_attachment).with(
      hash_including(
        message: "Attachment: trace.log",
        attachment: {
          name: "trace.log",
          mime: "text/plain",
          bytes: "trace"
        }
      )
    )

    world.rp_attach("trace", name: "trace.log", mime: "text/plain")
  end

  it "mirrors rp_log to stdout when console mirror mode is enabled" do
    config = instance_double("config", console_mirror?: true)
    runtime = instance_double("runtime", config: config)
    timestamp = Time.utc(2026, 3, 26, 0, 0, 0)
    ReportportalCucumber.current_runtime = runtime

    expect(runtime).to receive(:emit_world_log).with(
      message: "{\"ok\":true}",
      level: "INFO",
      timestamp: timestamp,
      attachment: nil
    )

    expect do
      world.rp_log("{\"ok\":true}", "INFO", timestamp: timestamp)
    end.to output("[RP-MIRROR] [INFO] {\"ok\":true}\n").to_stdout
  end

  it "does not mirror rp_log when console mirror mode is disabled" do
    config = instance_double("config", console_mirror?: false)
    runtime = instance_double("runtime", config: config)
    ReportportalCucumber.current_runtime = runtime

    expect(runtime).to receive(:emit_world_log).with(
      hash_including(message: "quiet", level: :debug, attachment: nil)
    )

    expect do
      world.rp_log("quiet", level: :debug)
    end.not_to output.to_stdout
  end
end
