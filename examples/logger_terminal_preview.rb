# frozen_string_literal: true

require_relative "../lib/reportportal_cucumber/automation/app_log"

AppLog.with_logger(Automation::CucumberLogger.new) do
  AppLog.info("Order submitted")
  AppLog.warn("Retrying request")
  AppLog.error("Payment failed")
  AppLog.debug("Order response", json: { order_id: "ORD-123", status: "ok" })
end
