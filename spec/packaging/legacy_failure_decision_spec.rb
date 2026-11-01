# frozen_string_literal: true

require "rspec"

RSpec.describe "The simplified 1.x failure-content decision" do
  let(:decisions) do
    File.read(File.expand_path("../../docs/design/presentation-ledger-owner-decisions.md", __dir__))
  end

  it "records the owner's replacement Decision 19 verbatim" do
    expected = <<~'TEXT'
      ## Decision 19: 1.x Failure-Log Content

      Owner-confirmed on 2026-11-01.

      19. On 1.x, the failure log carries the same text v1.3.1 sent, shown in the
          Ledger failure card. Failure-log redaction is not added in 1.3.2: the 2.x
          redactor omits the whole failure for common inputs (any backslash in the
          message), which hid failures that v1.3.1 showed (Launch 3778 versus
          Launches 3637 and 3731). Decision 15's P1.2 exception is withdrawn on 1.x,
          and G8 on 1.x means "nothing is sent that v1.3.1 would not have sent".
          2.x is unchanged; its whole-failure omission is a separate backlog item.
    TEXT
    section = decisions[/^## Decision 19:.*?(?=^## |\z)/m]
    expect(section&.strip).to eq(expected.strip)
  end

  it "does not leave superseded follow-up approvals as active acceptance gates" do
    expect(decisions).to include("remain historical records, not additional work or acceptance requirements")
    expect(decisions).to include("the 2.0.2 draft is paused")
  end
end
