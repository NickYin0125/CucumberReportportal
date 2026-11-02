# frozen_string_literal: true

require "fileutils"
require "json"
require "playwright"

output_dir = ENV.fetch("M2_EVIDENCE_DIR")
FileUtils.mkdir_p(output_dir)

Playwright.create(playwright_cli_executable_path: ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH")) do |playwright|
  browser = playwright.chromium.launch
  context = browser.new_context
  page = context.new_page
  page.goto(ENV.fetch("TYPEWORDS_URL"), waitUntil: "domcontentloaded")
  page.wait_for_load_state(state: "networkidle", timeout: 15_000)
  visible_text = page.locator("body").inner_text
  File.write(
    File.join(output_dir, "dom-inspection.json"),
    JSON.pretty_generate(
      title: page.title,
      url: page.url,
      links: page.get_by_role("link").all_inner_texts,
      link_details: page.locator("a").evaluate_all("items => items.map(item => ({text: item.innerText, href: item.href, visible: item.getClientRects().length > 0}))"),
      buttons: page.get_by_role("button").all_inner_texts,
      button_details: page.locator("button").evaluate_all("items => items.map(item => ({text: item.innerText, label: item.getAttribute('aria-label'), disabled: item.disabled, visible: item.getClientRects().length > 0, html: item.outerHTML.slice(0, 500)}))"),
      clickable_text_details: page.locator("body").evaluate("body => Array.from(body.querySelectorAll('*')).filter(e => ['Words','词表','Review','开始学习','Start learning','Select Dictionary'].includes(e.innerText?.trim()) && e.children.length === 0).map(e => ({tag: e.tagName, text: e.innerText, role: e.getAttribute('role'), href: e.getAttribute('href'), cls: e.className?.toString().slice(0, 120)}))"),
      tabs: page.get_by_role("tab").all_inner_texts,
      body_excerpt: visible_text[0, 7000]
    )
  )
  page.get_by_role("button", name: "Close Tour").click(timeout: 3_000)
  raise "The transient tutorial dialog did not close" unless page.get_by_role("dialog").count.zero?
  page.screenshot(path: File.join(output_dir, "after-tour-dismissal.png"), fullPage: true)
  before_action = page.locator("body").inner_text
  page.get_by_text("Select Dictionary", exact: true).click(timeout: 3_000)
  page.wait_for_timeout(500)
  after_action = page.locator("body").inner_text
  File.write(
    File.join(output_dir, "start-learning-probe.json"),
    JSON.pretty_generate(
      url_before: "http://localhost:5567/words",
      url_after: page.url,
      body_changed: before_action != after_action,
      body_after_excerpt: after_action[0, 2500],
      dialogs: page.get_by_role("dialog").all_inner_texts,
      buttons_after: page.get_by_role("button").all_inner_texts,
      cet4_visible: page.get_by_text("CET-4", exact: true).count.positive?
    )
  )
ensure
  context&.close
  browser&.close
end
