gem "cucumber-cucumber-expressions", "=17.1.0"
gem "cucumber", "9.2.1"
gem "reportportal-cucumber-ruby", "=1.3.3"
require "cucumber/cli/main"
exit Cucumber::Cli::Main.new(ARGV).execute!
