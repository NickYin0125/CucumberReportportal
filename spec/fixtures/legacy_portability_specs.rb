# frozen_string_literal: true

require_relative "legacy_portability"

LegacyPortability.load_specs!(ENV.fetch("LEGACY_SOURCE_ROOT"))
