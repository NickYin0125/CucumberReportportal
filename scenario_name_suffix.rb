# lib/scenario_name_suffix.rb
# frozen_string_literal: true

require "cucumber/core"
require "allure-cucumber"
require "digest"

module ScenarioNameSuffix
  module_function

  def suffix
    ENV.fetch("CUCUMBER_RUN_SUFFIX", "").strip
  end

  def append(name)
    return name if suffix.empty?
    return name if name.end_with?("[#{suffix}]")

    "#{name} [#{suffix}]"
  end
end

module CucumberScenarioNamePatch
  def name
    ScenarioNameSuffix.append(super)
  end
end

module AllureScenarioNamePatch
  def name
    ScenarioNameSuffix.append(super)
  end

  def id
    return super if ScenarioNameSuffix.suffix.empty?

    Digest::MD5.hexdigest(
      "#{super}|#{ScenarioNameSuffix.suffix}"
    )
  end
end

Cucumber::Core::Test::Case.prepend(
  CucumberScenarioNamePatch
) unless Cucumber::Core::Test::Case < CucumberScenarioNamePatch

AllureCucumber::Scenario.prepend(
  AllureScenarioNamePatch
) unless AllureCucumber::Scenario < AllureScenarioNamePatch
