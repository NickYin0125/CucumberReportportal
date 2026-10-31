#!/bin/sh
set -eu
: "${RP_API_KEY:?Master must inject RP_API_KEY securely in the invoking environment}"
export RP_ENDPOINT=http://rp-2607.localhost:18080
export RP_PROJECT=superadmin_personal
STAMP=${QA_LIVE_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}
JPEG=/Users/nick/Documents/crr-2.0.1/script/acceptance/presentation_ledger_developer/evidence/baseline2-all/media/jpeg.jpg
run_fixture() {
  ENTRY=$1
  shift
  docker run --rm --add-host rp-2607.localhost:host-gateway \
    -e RP_API_KEY -e RP_ENDPOINT -e RP_PROJECT \
    -v "$ROOT:$ROOT" -v "$SDK_BASE:$SDK_BASE:ro" \
    -v "/Users/nick/Documents/New project/.git:/Users/nick/Documents/New project/.git:ro" \
    -v "$(dirname "$JPEG"):$(dirname "$JPEG"):ro" \
    -v "/private/tmp/ledger-matrix-bundles/ruby$RUBY_DIGITS:/bundle" \
    -w "$ROOT" "ruby:$RUBY_VERSION-slim" ruby "$ROOT/spec/acceptance/ledger_qa/$ENTRY.rb" \
    --transport live --cucumber "$CUCUMBER" --gem-path "$GEMS" --jpeg "$JPEG" "$@"
}
for VERSION in 2.0.1 1.3.2; do
  ROOT=/Users/nick/Documents/crr-qa-$VERSION
  if [ "$VERSION" = 2.0.1 ]; then
    EXPECTED=cd0b400a2046e4b7958777165d77b67fcaf56577
    CUCUMBER=12.0.1
    SDK_BASE=/Users/nick/Documents/crr-qa-baseline-2.0.0
    RUBY_VERSION=3.4
    RUBY_DIGITS=34
    GEMS=/bundle/ruby/3.4.0
  else
    EXPECTED=f8872fa76c75024da01cc32c9746eb0a243f8389
    CUCUMBER=10.2.0
    SDK_BASE=/Users/nick/Documents/crr-qa-baseline-1.3.1
    RUBY_VERSION=3.3
    RUBY_DIGITS=33
    GEMS=/bundle/ruby/3.3.0
  fi
  [ "$(git -C "$ROOT" rev-parse HEAD)" = "$EXPECTED" ] || { printf '%s\n' 'QA worktree has not adopted the pinned repaired head'; exit 2; }
  for MODE in plain rich; do
    for REPEAT in 1 2; do
      run_fixture isolated --mode "$MODE" --fixtures all --sdk-root "$ROOT" --output "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-$MODE-$REPEAT"
      if [ "$VERSION" = 2.0.1 ]; then
        run_fixture parallel --mode "$MODE" --sdk-root "$ROOT" --output "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-parallel-$MODE-$REPEAT"
      fi
    done
  done
  run_fixture isolated --mode plain --fixtures all --sdk-root "$SDK_BASE" --output "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-baseline"
  if [ "$VERSION" = 2.0.1 ]; then
    run_fixture parallel --mode plain --sdk-root "$SDK_BASE" --output "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-parallel-baseline"
  fi
  run_fixture isolated --mode default --fixtures F01,F17,F20 --sdk-root "$ROOT" --batch-size 1 --output "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-default-batch1"
done
