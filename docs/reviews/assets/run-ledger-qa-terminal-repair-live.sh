#!/bin/sh
set -eu
: "${RP_API_KEY:?Master must inject RP_API_KEY securely in the invoking environment}"
export RP_ENDPOINT=http://rp-2607.localhost:18080
export RP_PROJECT=superadmin_personal
STAMP=${QA_LIVE_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}
JPEG=/Users/nick/Documents/crr-2.0.1/script/acceptance/presentation_ledger_developer/evidence/baseline2-all/media/jpeg.jpg
FIXTURES=F10a,F10b,F10c,F10d,F10e,F11a,F11b,F11c,F11d,F11e,F11f,F12
run_capture() {
  ENTRY=$1
  SELECTED=$2
  OUTPUT=$3
  docker run --rm --add-host rp-2607.localhost:host-gateway \
    -e RP_API_KEY -e RP_ENDPOINT -e RP_PROJECT \
    -v "$ROOT:$ROOT" \
    -v "/Users/nick/Documents/New project/.git:/Users/nick/Documents/New project/.git:ro" \
    -v "$(dirname "$JPEG"):$(dirname "$JPEG"):ro" \
    -v "/private/tmp/ledger-matrix-bundles/ruby$RUBY_DIGITS:/bundle" \
    -w "$ROOT" "ruby:$RUBY_VERSION-slim" ruby "$ROOT/spec/acceptance/ledger_qa/$ENTRY.rb" \
    --transport live --cucumber "$CUCUMBER" --gem-path "$GEMS" --jpeg "$JPEG" \
    --mode "$MODE" --fixtures "$SELECTED" --sdk-root "$ROOT" --output "$OUTPUT"
}
for VERSION in 2.0.1 1.3.2; do
  ROOT=/Users/nick/Documents/crr-qa-$VERSION
  if [ "$VERSION" = 2.0.1 ]; then
    EXPECTED=3d34a22b05189cda9fcfdb64ac51f904f60c3553
    CUCUMBER=12.0.1
    RUBY_VERSION=3.4
    RUBY_DIGITS=34
    GEMS=/bundle/ruby/3.4.0
  else
    EXPECTED=64be0d50517504784d2ec10752a2244c961e260e
    CUCUMBER=10.2.0
    RUBY_VERSION=3.3
    RUBY_DIGITS=33
    GEMS=/bundle/ruby/3.3.0
  fi
  [ "$(git -C "$ROOT" rev-parse HEAD)" = "$EXPECTED" ] || { printf '%s\n' 'QA worktree does not match the pinned terminal repair'; exit 2; }
  printf '%s\n' "$STAMP" > "$ROOT/docs/reviews/assets/ledger-qa-terminal-repair-stamp.txt"
  for MODE in plain rich; do
    for REPEAT in 1 2; do
      run_capture isolated "$FIXTURES" "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-terminal-repair-$MODE-$REPEAT"
      run_capture framework_shape F16b "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-framework-replay-$MODE-$REPEAT"
    done
  done
done
printf 'QA_TERMINAL_REPAIR_CAPTURE_COMPLETE=%s (not a verdict)\n' "$STAMP"
