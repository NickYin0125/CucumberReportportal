# frozen_string_literal: true

require "json"
require "open3"

Dir["/etc/apt/sources.list", "/etc/apt/sources.list.d/*"].select { |path| File.file?(path) }.each do |path|
  original = File.read(path)
  secure = original.gsub("http://deb.debian.org/", "https://deb.debian.org/")
  File.write(path, secure) unless secure == original
end
ENV["DEBIAN_FRONTEND"] = "noninteractive"
raise "apt metadata preparation failed" unless system("apt-get", "update", "-qq")
raise "jq installation failed" unless system("apt-get", "install", "-y", "--no-install-recommends", "jq")
if Gem::Specification.find_all_by_name("bundler", "= 2.6.6").empty?
  raise "Bundler installation failed" unless system("gem", "install", "bundler", "--version", "2.6.6", "--no-document")
end
raise "Linux jq is missing" unless File.binread("/usr/bin/jq", 4) == "\x7fELF".b
stdout, stderr, status = Open3.capture3("/usr/bin/jq", "-er", ".rows | map(select(.passed)) | length == 2",
  stdin_data: JSON.generate(rows: [{ passed: true }, { passed: false }, { passed: true }]))
raise "jq filter execution failed: #{stderr}" unless status.success? && stdout.strip == "true"
raise "apt cleanup failed" unless system("apt-get", "clean")
