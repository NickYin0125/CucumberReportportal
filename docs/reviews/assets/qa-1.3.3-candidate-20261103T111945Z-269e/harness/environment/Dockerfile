ARG BASE_IMAGE=local/crr-qa-1x-base:unset
FROM ${BASE_IMAGE}
COPY prepare_image.rb /tmp/qa-prepare-image.rb
RUN ruby /tmp/qa-prepare-image.rb
LABEL qa.purpose="Independent maintenance 1.x acceptance tools only"
