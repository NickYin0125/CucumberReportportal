# frozen_string_literal: true

require "json"
require "uri"
require "reportportal_cucumber"

Given("Typewords is open in a fresh browser context") do
  @typewords_initial_url = page.url
  @typewords_initial_text = page.locator("body").inner_text
  @typewords_initial_title = page.title
end

When("I inspect and use the visible word-study navigation") do
  dismiss_first_tour
  page.get_by_text("Select Dictionary", exact: true).click
  page.get_by_text("Dictionary List", exact: true).wait_for(state: "visible", timeout: 10_000)
  @dictionary_picker_state = {
    "path" => URI(page.url).path,
    "heading_visible" => page.get_by_text("Dictionary List", exact: true).count.positive?,
    "cet4_visible" => page.get_by_text("CET-4", exact: true).count.positive?
  }
end

Then("the word-study interface visibly changes") do
  expected = { "path" => "/dict-list", "heading_visible" => true, "cet4_visible" => true }
  raise "The dictionary picker did not reach the expected visible state: #{@dictionary_picker_state.inspect}" unless @dictionary_picker_state == expected
end

When("I report a manual diagnostic group and passing assertion") do
  rp_step("M2 manual grouping") do
    links = page.get_by_role("link").all_inner_texts
    observed = { "word_link" => links.find { |label| label == "Words" }, "path" => URI(page.url).path }
    expected = { "word_link" => "Words", "path" => "/words" }
    passed = observed == expected
    AppLog.assertion(
      name: "Typewords navigation is available",
      expected: expected,
      actual: observed,
      passed: passed,
      details: { "source" => "live Typewords UI", "api_key" => "M2_CANARY_PRIVATE_TEXT_7391" }
    )
    raise "Observed navigation did not match expected values: #{observed.inspect}" unless passed
  end
  @manual_group_recorded = true
end

Then("the manual group action is recorded") do
  raise "Manual reporting block did not complete" unless @manual_group_recorded
end

When("I deliberately wait for a missing locator and report browser evidence") do
  dismiss_first_tour
  captured_target = rp_capture_target
  begin
    page.get_by_role("button", name: "M2 intentionally absent control").click(timeout: 1_200)
  rescue Playwright::TimeoutError => error
    @m2_failure_target = captured_target
    original_exception_object_id = error.object_id
    screenshot_path = File.join(M2_EVIDENCE_DIR, "missing-locator.png")
    begin
      page.screenshot(path: screenshot_path, fullPage: true)
    rescue StandardError
      screenshot_path = nil
    end
    console_excerpt = @m2_console_messages.last(20).join("\n")
    details = { "console_excerpt" => console_excerpt, "api_key" => "M2_CANARY_PRIVATE_TEXT_7391" }
    begin
      AppLog.assertion(
        name: "Intentionally absent control becomes visible",
        expected: "A visible button named M2 intentionally absent control",
        actual: error.message,
        passed: false,
        details: details
      )
      artifacts = screenshot_path ? [{ path: screenshot_path, name: "typewords-missing-locator.png", mime: "image/png" }] : []
      @m2_evidence_result = rp_evidence(
        action: "Wait for intentionally absent Typewords control",
        error: error,
        url: page.url,
        details: details,
        artifacts: artifacts,
        target: captured_target
      )
      File.write(
        File.join(M2_EVIDENCE_DIR, "failure-evidence.json"),
        JSON.pretty_generate(
          original_error_class: error.class.name,
          original_error_message: error.message,
          original_exception_object_id: original_exception_object_id,
          target_captured_while_open: !captured_target.nil?,
          evidence_queued: @m2_evidence_result,
          url: page.url,
          screenshot: screenshot_path && File.basename(screenshot_path),
          console_excerpt_lines: console_excerpt.lines.count
        )
      )
    rescue StandardError => reporting_error
      File.write(
        File.join(M2_EVIDENCE_DIR, "failure-evidence.json"),
        JSON.pretty_generate(original_error_class: error.class.name,
                             original_exception_object_id: original_exception_object_id,
                             target_captured_while_open: !captured_target.nil?,
                             reporting_error_class: reporting_error.class.name,
                             evidence_queued: false)
      )
    end
    raise
  end
end
