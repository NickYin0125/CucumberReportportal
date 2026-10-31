# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Owner-approved Ledger goldens" do
  let(:proposal) do
    File.read(File.expand_path("../../../docs/design/presentation-ledger-proposal.md", __dir__), encoding: "UTF-8")
  end

  def golden(section)
    block = proposal.split(section, 2).fetch(1)[/````markdown\n(.*?)\n````/m, 1]
    raise "Missing exact golden for #{section}" unless block

    block
  end

  it "matches the corrected P1 title and all 62 unmodified fixture frames" do
    frames = [
      "/outside/runtime-support.rb:65:in 'IndependentCucumber12.inner_failure'",
      "/outside/runtime-support.rb:59:in 'IndependentCucumber12.deep_failure'",
      "/outside/runtime-support.rb:136:in 'block in <top (required)>'",
      "/project/features/audit.feature:5:in 'independent fail'"
    ] + Array.new(56) { |i| "/ruby/gems/cucumber/runner.rb:#{i + 1}:in 'run'" } +
      ["-e:1:in 'run'", "<internal:kernel>:90:in 'require'"]
    raw = frames.join("\n")
    expected = golden("**Output (Launch 76 fixture):**")
    expected = expected.sub(/```text\n\/Users\/.*?\n```\z/m) { "```text\n#{raw}\n```" }
    error = RuntimeError.new("INDEPENDENT_FULL_BACKTRACE")
    actual = ReportportalCucumber::Presentation::FailureCard.format(
      error: error, message: error.message, backtrace: raw, cwd: "/project"
    )

    expect(frames.length).to eq(62)
    expect(actual).to eq(expected)
    expect(actual).to end_with("```text\n#{raw}\n```")
  end

  it "matches the corrected F11a golden including headers and input byte counts" do
    request = { account: "JPM-PRIME", side: "BUY", notional: 5_000_000 }
    response = { orderId: "ORD-20261031-0042", status: "ACCEPTED" }
    exchange = Automation::HttpExchange.new(
      method: "POST", url: "https://api.example.test/api/orders", duration_ms: 84,
      request: { headers: { "Content-Type" => "application/json", "Accept" => "application/json",
                            "X-Request-Id" => "ledger-42", "X-Fixture" => "F11a" }, body: request },
      response: { status: 201, headers: { "Content-Type" => "application/json" }, body: response }
    )

    expect([JSON.generate(request).bytesize, JSON.generate(response).bytesize]).to eq([55, 51])
    expect(exchange.to_markdown).to eq(golden("**HTTP exchange, INFO:**"))
  end
end

