# frozen_string_literal: true

When("the UI tester saves {string} using Enter") do |word|
  ui_action("Save practice word using Enter") do
    @page.get_by_label("Practice word").fill(word)
    @page.get_by_label("Practice word").press("Enter")
  end
end

When("the UI tester replaces the word with {string} using Enter") do |word|
  ui_action("Correct and resave practice word using Enter") do
    @page.get_by_label("Practice word").fill(word)
    @page.get_by_label("Practice word").press("Enter")
  end
end

Then("the UI tester records the {string} checkpoint") do |checkpoint|
  path = File.join("reports/ui-tester", "#{checkpoint}.png")
  FileUtils.mkdir_p(File.dirname(path))
  @page.screenshot(path: path, fullPage: true, timeout: 5000)
  AppLog.info("UI tester checkpoint: #{checkpoint}", report: true, file: path)
  AppLog.info("Checkpoint browser state", report: true,
              json: {checkpoint: checkpoint, url: @page.url,
                     word: @page.get_by_label("Practice word").input_value,
                     status: @page.get_by_role("status").inner_text})
end

When("the UI tester refreshes the practice page") do
  ui_action("Refresh the practice page") { @page.reload(waitUntil: "domcontentloaded") }
end

Then("the UI tester finds the restored word {string}") do |expected|
  check_equal("restored practice word after refresh", expected,
              @page.get_by_label("Practice word").input_value)
end
