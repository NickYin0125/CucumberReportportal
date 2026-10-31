#!/bin/sh
set -eu
: "${RP_API_KEY:?Master must securely inject RP_API_KEY}"
: "${QA_LIVE_STAMP:?Set the main acceptance run stamp explicitly}"
export RP_ENDPOINT=http://rp-2607.localhost:18080
export RP_PROJECT=superadmin_personal
STAMP=$QA_LIVE_STAMP
JPEG=/Users/nick/Documents/crr-2.0.1/script/acceptance/presentation_ledger_developer/evidence/baseline2-all/media/jpeg.jpg
run_fixture() {
  docker run --rm --add-host rp-2607.localhost:host-gateway \
    -e RP_API_KEY -e RP_ENDPOINT -e RP_PROJECT \
    -v "$ROOT:$ROOT" -v "$SDK_BASE:$SDK_BASE:ro" \
    -v "/Users/nick/Documents/New project/.git:/Users/nick/Documents/New project/.git:ro" \
    -v "$(dirname "$JPEG"):$(dirname "$JPEG"):ro" \
    -v "/private/tmp/ledger-matrix-bundles/ruby$RUBY_DIGITS:/bundle" \
    -w "$ROOT" "ruby:$RUBY_VERSION-slim" ruby "$ROOT/spec/acceptance/ledger_qa/frozen.rb" \
    --transport live --cucumber "$CUCUMBER" --gem-path "$GEMS" --jpeg "$JPEG" "$@"
}
for VERSION in 2.0.1 1.3.2; do
  ROOT=/Users/nick/Documents/crr-qa-$VERSION
  if [ "$VERSION" = 2.0.1 ]; then
    EXPECTED=cd0b400a2046e4b7958777165d77b67fcaf56577
    SDK_BASE=/Users/nick/Documents/crr-qa-baseline-2.0.0
    CUCUMBER=12.0.1
    RUBY_VERSION=3.4
    RUBY_DIGITS=34
    GEMS=/bundle/ruby/3.4.0
  else
    EXPECTED=f8872fa76c75024da01cc32c9746eb0a243f8389
    SDK_BASE=/Users/nick/Documents/crr-qa-baseline-1.3.1
    CUCUMBER=10.2.0
    RUBY_VERSION=3.3
    RUBY_DIGITS=33
    GEMS=/bundle/ruby/3.3.0
  fi
  [ "$(git -C "$ROOT" rev-parse HEAD)" = "$EXPECTED" ] || { printf '%s\n' 'Unexpected tested head'; exit 2; }
  for MODE in plain rich; do
    for REPEAT in 1 2; do
      run_fixture --mode "$MODE" --fixtures F02,F04,F16c --sdk-root "$ROOT" --output "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-supplement-$MODE-$REPEAT"
    done
  done
  run_fixture --mode plain --fixtures F01,F02,F04,F16c --sdk-root "$SDK_BASE" --output "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-supplement-baseline"
  run_fixture --mode plain --fixtures F01 --sdk-root "$SDK_BASE" --output "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-supplement-baseline-repeat"
done
