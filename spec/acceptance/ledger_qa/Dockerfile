ARG RUBY_VERSION=3.3
FROM ruby:${RUBY_VERSION}-slim
RUN ruby -e 'Dir["/etc/apt/sources.list", "/etc/apt/sources.list.d/*"].select { |p| File.file?(p) }.each { |p| File.write(p, File.read(p).gsub("http://deb.debian.org/", "https://deb.debian.org/")) }'
RUN apt-get update -qq
RUN apt-get install -y --no-install-recommends gcc make libc6-dev libffi-dev git curl ca-certificates
RUN gem install bundler -v 2.6.6 --no-document
