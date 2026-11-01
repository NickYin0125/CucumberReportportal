# frozen_string_literal: true

require_relative "final_wp5_driver"

abort "Master must inject RP_API_KEY through the invoking environment only" if ENV["RP_API_KEY"].to_s.empty?
load File.join(__dir__, "final_wp5_backslash.rb")
LedgerFinalWP5.live
