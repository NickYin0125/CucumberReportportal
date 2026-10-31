#!/bin/sh
set -eu
: "${RP_API_KEY:?Master must securely inject RP_API_KEY}"
export RP_ENDPOINT=http://rp-2607.localhost:18080 RP_PROJECT=superadmin_personal
STAMP=${QA_LIVE_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}
JPEG=/Users/nick/Documents/crr-2.0.1/script/acceptance/presentation_ledger_developer/evidence/baseline2-all/media/jpeg.jpg
capture() {
  ENTRY=$1
  SDK=$2
  MODE=$3
  SUFFIX=$4
  SELECTED=$5
  docker run --rm --add-host rp-2607.localhost:host-gateway \
    -e RP_API_KEY -e RP_ENDPOINT -e RP_PROJECT \
    -v "$ROOT:$ROOT" -v "$BASE:$BASE:ro" \
    -v "/Users/nick/Documents/New project/.git:/Users/nick/Documents/New project/.git:ro" \
    -v "$(dirname "$JPEG"):$(dirname "$JPEG"):ro" \
    -v "/private/tmp/ledger-matrix-bundles/ruby$DIGITS:/bundle" -w "$ROOT" \
    "ruby:$RUBY-slim" ruby "spec/acceptance/ledger_qa/$ENTRY.rb" \
    --transport live --cucumber "$CUCUMBER" --gem-path "$GEMS" --jpeg "$JPEG" \
    --sdk-root "$SDK" --mode "$MODE" --fixtures "$SELECTED" \
    --output "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-contract-gaps-$SUFFIX"
}
for VERSION in 2.0.1 1.3.2; do
  ROOT=/Users/nick/Documents/crr-qa-$VERSION
  if [ "$VERSION" = 2.0.1 ]; then
    HEAD=3d34a22b05189cda9fcfdb64ac51f904f60c3553
    BASE=/Users/nick/Documents/crr-qa-baseline-2.0.0
    BASEHEAD=79e5e9cfde4be6d29ca2293e549460c6c71fe87a
    RUBY=3.4 DIGITS=34 GEMS=/bundle/ruby/3.4.0 CUCUMBER=12.0.1
  else
    HEAD=64be0d50517504784d2ec10752a2244c961e260e
    BASE=/Users/nick/Documents/crr-qa-baseline-1.3.1
    BASEHEAD=4ca2f770e0a84e83688f165ba04b4db8ef855cf9
    RUBY=3.3 DIGITS=33 GEMS=/bundle/ruby/3.3.0 CUCUMBER=10.2.0
  fi
  [ "$(git -C "$ROOT" rev-parse HEAD)" = "$HEAD" ]
  [ "$(git -C "$BASE" rev-parse HEAD)" = "$BASEHEAD" ]
  printf '%s\n' "$STAMP" > "$ROOT/docs/reviews/assets/ledger-qa-contract-gaps-stamp.txt"
  capture contract_gaps "$BASE" plain baseline F14
  capture contract_gaps "$ROOT" plain plain F14
  capture contract_gaps "$ROOT" rich rich F14
  if [ "$VERSION" = 1.3.2 ]; then
    CUCUMBER=9.2.1
    capture isolated "$ROOT" plain c9-plain F15
    capture isolated "$ROOT" rich c9-rich F15
  fi
done
printf 'QA_CONTRACT_GAPS_CAPTURE_COMPLETE=%s (not a verdict)\n' "$STAMP"
