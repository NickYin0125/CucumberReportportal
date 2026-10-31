# frozen_string_literal: true

require_relative "../../../script/acceptance/presentation_ledger_developer/support"

Given("QA authored raw logger controls") do
  values = ["literal *star* _under_ `tick`", "literal <other> <b>x</b> &amp;",
    "literal first line\nsecond line", "literal CJK \u4e2d\u6587 emoji \u{1F7E2}"]
  values.each do |value|
    LedgerDeveloper::Input.record("authored_user_log", api: "rp_log", message: "rp_log #{value}")
    rp_log("rp_log #{value}")
    LedgerDeveloper::Input.record("authored_user_log", api: "AppLog.info", message: "AppLog #{value}")
    LedgerDeveloper::Input.app_log(self) { AppLog.info("AppLog #{value}", report: true) }
  end
end
