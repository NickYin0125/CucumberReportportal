gem "cucumber-cucumber-expressions", "=18.1.0"
gem "cucumber", "10.2.0"
gem "reportportal-cucumber-ruby", "=1.3.3"
require "cucumber/cli/main"
exit Cucumber::Cli::Main.new(ARGV).execute!
