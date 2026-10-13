#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "http"
require "optparse"

options = { scope: :logs, steps: [] }
parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby examples/day2_faults/proxy.rb --upstream ORIGIN [options]"
  opts.on("--upstream URL") { |value| options[:upstream] = value }
  opts.on("--port N", Integer) { |value| options[:port] = value }
  opts.on("--scope SCOPE", %w[logs finish all]) { |value| options[:scope] = value.to_sym }
  opts.on("--plan JSON", "Array of action/status/delay/keep objects") do |value|
    options[:steps] = JSON.parse(value, symbolize_names: true).map { |step| step.merge(action: step.fetch(:action).to_sym) }
  end
  opts.on("--repeat", "Repeat the last fault until stopped") { options[:repeat] = true }
  opts.on("--upstream-ip IP") { |value| options[:upstream_ip] = value }
  opts.on("--max-body N", Integer) { |value| options[:max_body] = value }
  opts.on("--help") { puts opts; exit }
end
parser.parse!
abort parser.to_s unless options[:upstream]
proxy = Day2Faults::FaultProxy.new(**options)
puts "Loopback proxy endpoint: #{proxy.endpoint}; scope=#{options[:scope]}"
STDOUT.flush
stop = false
Signal.trap("INT") { stop = true }
Signal.trap("TERM") { stop = true }
sleep 0.1 until stop
proxy.stop
puts JSON.pretty_generate(proxy.events)
