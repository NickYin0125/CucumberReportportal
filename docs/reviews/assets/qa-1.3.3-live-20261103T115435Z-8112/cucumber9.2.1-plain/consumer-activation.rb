require "json"
gem "cucumber-cucumber-expressions", "=17.1.0"
gem "cucumber", "=9.2.1"
gem "reportportal-cucumber-ruby", "=1.3.3"
at_exit do
  File.write("/evidence/consumer-runtime.json", JSON.pretty_generate(
    ruby: RUBY_DESCRIPTION, gems: Gem.loaded_specs.sort.to_h.transform_values { |spec| spec.version.to_s },
    sdk_root: Gem.loaded_specs.fetch("reportportal-cucumber-ruby").full_gem_path) + "
")
end
