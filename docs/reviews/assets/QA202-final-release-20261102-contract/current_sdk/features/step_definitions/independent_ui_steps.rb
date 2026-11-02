# frozen_string_literal: true

require "securerandom"

# Steps written by an independent consumer of SDK 2.0.1. Screenshots are taken
# inside the still-open step, so ReportPortal shows them under that step.

When("I submit the practice form without a word") do
  ui_action("Submit an empty practice form") do
    @page.get_by_role("button", name: "Save practice", exact: true).click
  end
end

When("I type {int} letters into the practice word field") do |count|
  ui_action("Type #{count} letters") do
    @page.get_by_label("Practice word").press_sequentially("a" * count)
  end
end

Then("the practice word field holds {int} characters") do |expected|
  value = @page.get_by_label("Practice word").input_value
  check_equal("practice word length", expected, value.length)
end

When("I practice these words in order:") do |table|
  rows = table.hashes
  AppLog.info("Practising #{rows.length} words", report: true, json: rows)
  rows.each do |row|
    word = row.fetch("word")
    ui_action("Save practice word #{word}") do
      @page.get_by_label("Practice word").fill(word)
      @page.get_by_role("button", name: "Save practice", exact: true).click
    end
  end
end

Then("I keep a screenshot of the page as evidence") do
  path = File.join(ENV.fetch("REPORT_DIR"), "evidence-#{SecureRandom.hex(4)}.png")
  @page.screenshot(path: path, fullPage: true, timeout: 5000)
  AppLog.info("Page after the last action", file: path, report: true)
end
