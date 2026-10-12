# frozen_string_literal: true

Given("I open the local practice page") do
  ui_action("Open local practice page") { @page.goto(CurrentSDK::FIXTURE.url, waitUntil: "domcontentloaded") }
  check_equal("practice heading", "Practice Studio", @page.get_by_role("heading", name: "Practice Studio").inner_text)
end

When("I practice the word {string}") do |word|
  ui_action("Save practice word") do
    @page.get_by_label("Practice word").fill(word)
    @page.get_by_role("button", name: "Save practice", exact: true).click
  end
end

Then("the practice status is {string}") do |expected|
  check_equal("practice status", expected, @page.get_by_role("status").inner_text)
end

When("I click the deliberately missing practice button") do
  ui_action("Click deliberately missing practice button") do
    @page.get_by_role("button", name: "Deliberately missing button", exact: true).click(timeout: 750)
  end
end

Given("I open Typewords") do
  url = ENV.fetch("TYPEWORDS_URL", "http://localhost:5567/")
  uri = URI(url)
  raise "Typewords must be a credential-free loopback HTTP target" unless uri.scheme == "http" &&
    %w[localhost 127.0.0.1].include?(uri.host) && !uri.userinfo && !uri.query && !uri.fragment

  ui_action("Open Typewords landing page") { @page.goto(url, waitUntil: "domcontentloaded") }
end

Then("the browser title contains {string}") do |expected|
  check_equal("Typewords title", true, @page.title.include?(expected))
  AppLog.info("Live Typewords title checked", json: {title: @page.title}, report: true)
  optional_live_snapshot
end
