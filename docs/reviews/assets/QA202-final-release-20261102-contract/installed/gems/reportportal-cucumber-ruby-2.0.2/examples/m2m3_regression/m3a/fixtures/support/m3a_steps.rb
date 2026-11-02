# frozen_string_literal: true

require "json"
require "cucumber/glue/dsl"

module M3AFixtureSteps
  extend Cucumber::Glue::Dsl

  EXPECTED_TABLE = [
    %w[key value escaped newline trailing],
    ["ordinary", "plain", "A|B", "line\nnext", ""],
    ["alpha", "first", "A|B", "line\nnext", ""],
    ["beta", "second", "A|B", "line\nnext", ""],
    ["gamma", "third", "A|B", "line\nnext", ""],
    ["delta", "fourth", "A|B", "line\nnext", ""],
    ["一组", "first", "A|B", "line\nnext", ""],
    ["二组", "second", "A|B", "line\nnext", ""]
  ].freeze

  EXPECTED_DOCUMENT = {
    "message" => "line one\nline two",
    "slash" => "path\\leaf",
    "fence" => "```json"
  }.freeze

  EXPECTED_TEMPLATES = {
    "ordinary" => "<not-a-parameter>",
    "alpha" => "token-a",
    "beta" => "token-b",
    "gamma" => "token-c",
    "delta" => "token-d",
    "一组" => "token-1",
    "二组" => "token-2"
  }.freeze

  Given("the shared M3A context") do
    raise "M3A feature context was not established" unless @m3a_feature_context_seen

    @m3a_context_seen = true
  end

  Given("共享的 M3A 上下文") do
    raise "未建立 M3A 功能上下文" unless @m3a_feature_context_seen

    @m3a_context_seen = true
  end

  Given("the shared M3A feature context") do
    @m3a_feature_context_seen = true
  end

  Given("共享的 M3A 功能上下文") do
    @m3a_feature_context_seen = true
  end

  When('I verify the M3A table for {string}:') do |record, table|
    raise "M3A context was not established" unless @m3a_context_seen

    expected = EXPECTED_TABLE.find { |row| row.first == record }
    raise "Unexpected M3A table for #{record.inspect}: #{table.raw.inspect}" unless expected && table.raw == [EXPECTED_TABLE.first, expected]

  end

  When('我验证 M3A 表格 {string}:') do |record, table|
    raise "未建立 M3A 上下文" unless @m3a_context_seen

    expected = EXPECTED_TABLE.find { |row| row.first == record }
    raise "Unexpected Chinese M3A table for #{record.inspect}: #{table.raw.inspect}" unless expected && table.raw == [EXPECTED_TABLE.first, expected]

  end

  Then("I verify the M3A document:") do |doc_string|
    parsed = JSON.parse(doc_string)
    record = parsed.fetch("record")
    raise "Unexpanded M3A document parameter: #{record.inspect}" if record != "ordinary" && record.match?(/\A<.*>\z/)

    expected = EXPECTED_DOCUMENT.merge("record" => record, "template" => EXPECTED_TEMPLATES.fetch(record))
    raise "Unexpected M3A document: #{parsed.inspect}" unless parsed == expected

  end

  Then("我验证 M3A 文档:") do |doc_string|
    parsed = JSON.parse(doc_string)
    record = parsed.fetch("record")
    raise "未展开的 M3A 文档参数: #{record.inspect}" if record != "ordinary" && record.match?(/\A<.*>\z/)

    expected = EXPECTED_DOCUMENT.merge("record" => record, "template" => EXPECTED_TEMPLATES.fetch(record))
    raise "中文 M3A 文档不符合预期: #{parsed.inspect}" unless parsed == expected

  end
end

World(M3AFixtureSteps)
