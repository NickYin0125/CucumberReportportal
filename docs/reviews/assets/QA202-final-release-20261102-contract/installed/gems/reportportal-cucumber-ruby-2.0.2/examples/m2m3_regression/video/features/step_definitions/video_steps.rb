# frozen_string_literal: true

Given("I record Typewords dictionary navigation and return to Words") do
  @video_ui_observations = []
  video_event("navigate_words")
  @video_page.goto(ENV.fetch("TYPEWORDS_URL"), waitUntil: "domcontentloaded")
  @video_page.wait_for_load_state(state: "networkidle", timeout: 15_000)
  close_tour = @video_page.get_by_role("button", name: "Close Tour", exact: true)
  close_tour.click if close_tour.count.positive?
  @video_page.get_by_role("link", name: "Words", exact: true).wait_for(state: "visible")
  @video_page.get_by_text("Select Dictionary", exact: true).wait_for(state: "visible")
  @video_page.screenshot(path: File.join(VIDEO_RESULTS, "01-words.png"))
  @video_ui_observations << { state: "words", path: URI(@video_page.url).path }
  @video_page.wait_for_timeout(1_800)

  @video_page.get_by_text("Select Dictionary", exact: true).click
  @video_page.get_by_text("Dictionary List", exact: true).wait_for(state: "visible")
  @video_page.get_by_text("CET-4", exact: true).wait_for(state: "visible")
  raise "Dictionary picker URL did not change" unless URI(@video_page.url).path == "/dict-list"

  @video_page.screenshot(path: File.join(VIDEO_RESULTS, "02-dictionary-picker.png"))
  @video_ui_observations << { state: "dictionary_picker", path: URI(@video_page.url).path, heading: "Dictionary List", entry: "CET-4" }
  video_event("dictionary_picker_visible")
  @video_page.wait_for_timeout(2_000)

  @video_page.go_back(waitUntil: "domcontentloaded")
  @video_page.get_by_text("Select Dictionary", exact: true).wait_for(state: "visible")
  raise "Return navigation did not reach Words" unless URI(@video_page.url).path == "/words"

  @video_page.screenshot(path: File.join(VIDEO_RESULTS, "03-returned-words.png"))
  @video_ui_observations << { state: "returned_words", path: URI(@video_page.url).path }
  video_event("returned_words_visible")
  @video_page.wait_for_timeout(1_800)
end

When("I click an intentionally absent Typewords control") do
  @failed_video_target = rp_capture_target
  raise "Failed Gherkin step has no open capture target" unless @failed_video_target

  begin
    @video_page.get_by_role("button", name: "M2 video intentionally absent control", exact: true).click(timeout: 1_200)
  rescue Playwright::TimeoutError => error
    @original_video_error = error
    video_event("original_missing_button_timeout_captured", error_class: error.class.name, object_id: error.object_id)
    write_video_json("original-failure.json", error_class: error.class.name, error_message: error.message, object_id: error.object_id)
    begin
      AppLog.assertion(name: "Intentionally absent Typewords control can be clicked",
                       expected: "click succeeds", actual: error.message, passed: false,
                       details: { "api_key" => VIDEO_CANARY, "recording" => "Playwright viewport recording is still active" })
      accepted = rp_evidence(action: "Missing Typewords control while recording", error: error, url: @video_page.url,
                             details: { "api_key" => VIDEO_CANARY }, target: @failed_video_target)
      write_video_json("failed-step-evidence.json", target_captured_open: true, accepted: accepted)
    rescue StandardError => reporting_error
      write_video_json("failed-step-evidence.json", accepted: false, reporting_error_class: reporting_error.class.name)
    end
    raise
  end
end
