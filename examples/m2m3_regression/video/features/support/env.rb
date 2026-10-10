# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "time"
require "uri"
require "playwright"
require "reportportal_cucumber"

VIDEO_RESULTS = ENV.fetch("M2_VIDEO_RESULTS_DIR")
VIDEO_CANARY = "M2_VIDEO_PRIVATE_TEXT_5197"
FileUtils.mkdir_p(File.join(VIDEO_RESULTS, "recordings"))

module TypewordsVideoWorld
  def video_clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def video_elapsed_ms(started)
    ((video_clock - started) * 1_000).round(3)
  end

  def video_event(name, details = {})
    @video_events << { name: name, at_utc: Time.now.utc.iso8601(3), details: details }
  end

  def write_video_json(name, value)
    File.write(File.join(VIDEO_RESULTS, name), JSON.pretty_generate(value))
  end

  def media_command(*command)
    output, status = Open3.capture2e(*command)
    raise "Media command failed: #{command.first}: #{output.lines.last(8).join}" unless status.success?

    output
  end

  def probe_video(path, report_name)
    raw = media_command("ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", path)
    File.write(File.join(VIDEO_RESULTS, report_name), raw)
    JSON.parse(raw)
  end

  def video_file_record(path, probe)
    stream = probe.fetch("streams").find { |entry| entry["codec_type"] == "video" }
    {
      path: path, bytes: File.size(path), sha256: Digest::SHA256.file(path).hexdigest,
      duration_seconds: Float(probe.fetch("format").fetch("duration")),
      codec: stream.fetch("codec_name"), pixel_format: stream["pix_fmt"],
      width: stream["width"], height: stream["height"]
    }
  end
end

World(ReportportalCucumber::Cucumber::World, TypewordsVideoWorld)

Around do |_scenario, run|
  @video_scenario_started = video_clock
  @video_events = []
  @video_context_closed = false
  Playwright.create(playwright_cli_executable_path: ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH")) do |playwright|
    browser = nil
    begin
      browser = playwright.chromium.launch
      @video_context = browser.new_context(
        viewport: { width: 1280, height: 720 },
        record_video_dir: File.join(VIDEO_RESULTS, "recordings"),
        record_video_size: { width: 1280, height: 720 }
      )
      video_event("recording_context_created_before_navigation")
      @video_page = @video_context.new_page
      @playwright_video = @video_page.video
      raise "Playwright did not expose a recording Video" unless @playwright_video

      AppLog.with_logger(Automation::CucumberLogger.new(world: self)) { run.call }
    ensure
      @video_context.close if @video_context && !@video_context_closed
      browser&.close
    end
  end
end

After do |scenario|
  after_started = video_clock
  timings = {}
  raise "Expected original missing-button failure was not captured" unless @original_video_error
  raise "Cucumber did not preserve the original exception object" unless scenario.exception.equal?(@original_video_error)

  close_started = video_clock
  @video_context.close
  timings[:context_close_ms] = video_elapsed_ms(close_started)
  @video_context_closed = true
  video_event("context_closed_recording_finalized")
  saved_started = video_clock
  source_path = @playwright_video.path
  saved_path = File.join(VIDEO_RESULTS, "typewords-original.webm")
  @playwright_video.save_as(saved_path)
  timings[:official_video_path_and_save_as_ms] = video_elapsed_ms(saved_started)
  timings[:context_close_through_video_finalized_ms] = video_elapsed_ms(close_started)
  video_event("official_video_path_and_save_as_completed", source_path: source_path, saved_path: saved_path)
  raise "Official save_as changed the original recording bytes" unless Digest::SHA256.file(source_path).hexdigest == Digest::SHA256.file(saved_path).hexdigest

  source = video_file_record(source_path, probe_video(source_path, "source-ffprobe.json"))
  old_target_accepted = rp_evidence(
    action: "Rejected closed failed-step video publication probe",
    error: @original_video_error,
    details: { "api_key" => VIDEO_CANARY, "source_finalized" => true },
    target: @failed_video_target
  )
  raise "Closed failed-step target accepted late evidence" unless old_target_accepted == false

  lifecycle = {
    original_error_class: @original_video_error.class.name,
    original_error_message: @original_video_error.message,
    original_exception_object_id: @original_video_error.object_id,
    after_hook_exception_object_id: scenario.exception.object_id,
    same_original_exception_in_after: scenario.exception.equal?(@original_video_error),
    closed_failed_target_accepted: old_target_accepted,
    source: source,
    official_saved_copy: saved_path,
    context_closed_before_publication: @video_context_closed,
    timings: timings,
    events: @video_events
  }
  write_video_json("video-lifecycle.json", lifecycle)

  manual_started = video_clock
  manual_body_completed = nil
  enqueue_started = nil
  rp_step("Finalize and publish testcase recording") do
    publishing_target = rp_capture_target
    raise "No open manual publishing target" unless publishing_target

    video_event("manual_publishing_target_captured_after_finalization")
    mp4_path = File.join(VIDEO_RESULTS, "typewords-testcase-recording.mp4")
    transcode = ["ffmpeg", "-y", "-i", source_path, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", mp4_path]
    conversion_started = video_clock
    File.write(File.join(VIDEO_RESULTS, "ffmpeg-transcode.log"), media_command(*transcode))
    timings[:ffmpeg_conversion_ms] = video_elapsed_ms(conversion_started)
    mp4 = video_file_record(mp4_path, probe_video(mp4_path, "mp4-ffprobe.json"))
    raise "Recording is too short for identifiable navigation" unless source.fetch(:duration_seconds) >= 7.0
    raise "MP4 is not H.264/yuv420p" unless mp4[:codec] == "h264" && mp4[:pixel_format] == "yuv420p"

    new_target_accepted = rp_evidence(
      action: "Publish finalized testcase recording",
      error: @original_video_error,
      details: { "api_key" => VIDEO_CANARY, "source_sha256" => source.fetch(:sha256), "mp4_sha256" => mp4.fetch(:sha256) },
      target: publishing_target
    )
    raise "Open manual publishing target rejected diagnostic evidence" unless new_target_accepted

    # Video uses the existing streaming MinIO route, never rp_evidence multipart.
    enqueue_started = video_clock
    rp_attach(mp4_path, name: "typewords-testcase-recording.mp4", mime_type: "video/mp4",
              message: "Finalized Playwright testcase viewport recording", level: :info)
    timings[:rp_attach_enqueue_ms] = video_elapsed_ms(enqueue_started)
    video_event("rp_attach_mp4_queued_on_open_manual_node")
    lifecycle.merge!(mp4: mp4, transcode_command: transcode,
                     open_manual_target_accepted: new_target_accepted,
                     video_attach_called_after_finalization: true,
                     ui_observations: @video_ui_observations)
    write_video_json("video-lifecycle.json", lifecycle)
    manual_body_completed = video_clock
  end
  timings[:manual_node_total_ms] = video_elapsed_ms(manual_started)
  timings[:manual_node_return_and_flush_ms] = video_elapsed_ms(manual_body_completed)
  timings[:video_enqueue_through_manual_return_ms] = video_elapsed_ms(enqueue_started)
  timings[:after_hook_body_ms] = video_elapsed_ms(after_started)
  timings[:scenario_body_through_after_ms] = video_elapsed_ms(@video_scenario_started)
  lifecycle[:upload_timing_scope] = "S3 upload and RP flush cannot be separated by the public DSL; manual-node return/flush is an observed aggregate."
  write_video_json("video-lifecycle.json", lifecycle)
end
