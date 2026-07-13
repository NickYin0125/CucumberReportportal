# features/support/scenario_name_suffix.rb
# frozen_string_literal: true

require "allure-cucumber"
require "digest"

module ReportScenarioSuffix
  ENV_KEY = "CUCUMBER_RUN_SUFFIX"

  module_function

  def value
    ENV.fetch(ENV_KEY, "").strip
  end

  def append_to(name)
    suffix = value
    return name if suffix.empty?

    "#{name} [#{suffix}]"
  end
end

# Cucumber JSON formatter读取 test_case.name。
module CucumberTestCaseNameSuffix
  def name
    ReportScenarioSuffix.append_to(super)
  end
end

unless Cucumber::Core::Test::Case.ancestors.include?(
  CucumberTestCaseNameSuffix
)
  Cucumber::Core::Test::Case.prepend(
    CucumberTestCaseNameSuffix
  )
end

# Allure Cucumber formatter不直接使用 test_case.name 作为测试名称，
# 而是通过 AllureCucumber::Scenario#name 重新生成名称。
module AllureScenarioNameSuffix
  def name
    ReportScenarioSuffix.append_to(super)
  end

  # 同时修改 history_id，防止 Allure 把十次执行识别成
  # 同一个测试的 retry。
  def id
    suffix = ReportScenarioSuffix.value
    return super if suffix.empty?

    Digest::MD5.hexdigest("#{super}|#{suffix}")
  end
end

unless AllureCucumber::Scenario.ancestors.include?(
  AllureScenarioNameSuffix
)
  AllureCucumber::Scenario.prepend(
    AllureScenarioNameSuffix
  )
end
