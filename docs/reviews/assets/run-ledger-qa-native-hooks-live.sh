#!/bin/sh
set -eu
: "${RP_API_KEY:?Master must securely inject RP_API_KEY}"
export RP_ENDPOINT=http://rp-2607.localhost:18080 RP_PROJECT=superadmin_personal
STAMP=${QA_LIVE_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}
JPEG=/Users/nick/Documents/crr-2.0.1/script/acceptance/presentation_ledger_developer/evidence/baseline2-all/media/jpeg.jpg
capture() {
  ENTRY=$1 SDK=$2 MODE=$3 SUFFIX=$4 SELECTED=$5
  docker run --rm --add-host rp-2607.localhost:host-gateway \
    -e RP_API_KEY -e RP_ENDPOINT -e RP_PROJECT \
    -v "$ROOT:$ROOT" -v "$BASE:$BASE:ro" \
    -v "/Users/nick/Documents/New project/.git:/Users/nick/Documents/New project/.git:ro" \
    -v "$(dirname "$JPEG"):$(dirname "$JPEG"):ro" \
    -v "/private/tmp/ledger-matrix-bundles/ruby$DIGITS:/bundle" -w "$ROOT" \
    "ruby:$RUBY-slim" ruby "spec/acceptance/ledger_qa/$ENTRY.rb" \
    --transport live --cucumber "$CUCUMBER" --gem-path "$GEMS" --jpeg "$JPEG" \
    --sdk-root "$SDK" --mode "$MODE" --fixtures "$SELECTED" \
    --output "$ROOT/docs/reviews/assets/ledger-qa-live/$STAMP-hooks-$CUCUMBER-$SUFFIX"
}
for CUCUMBER in 12.0.1 10.2.0 9.2.1; do
  if [ "$CUCUMBER" = 12.0.1 ]; then
    ROOT=/Users/nick/Documents/crr-qa-2.0.1 BASE=/Users/nick/Documents/crr-qa-baseline-2.0.0
    HEAD=ecf8c5aade5b6982f96083cb21c758db56b81b3f
    RUBY=3.4 DIGITS=34 GEMS=/bundle/ruby/3.4.0
  else
    ROOT=/Users/nick/Documents/crr-qa-1.3.2 BASE=/Users/nick/Documents/crr-qa-baseline-1.3.1
    HEAD=c27510547ace0d4baaf964a0575e5bec4344e11a
    RUBY=3.3 DIGITS=33 GEMS=/bundle/ruby/3.3.0
  fi
  [ "$(git -C "$ROOT" rev-parse HEAD)" = "$HEAD" ]
  printf '%s\n' "$STAMP" > "$ROOT/docs/reviews/assets/ledger-qa-native-hooks-stamp.txt"
  capture native_hooks "$BASE" plain baseline F15
  for MODE in plain rich; do
    for REPEAT in 1 2; do
      capture native_hooks "$ROOT" "$MODE" "$MODE-$REPEAT" F15
      capture isolated "$ROOT" "$MODE" "companions-$MODE-$REPEAT" F04,F15
      if [ "$CUCUMBER" = 12.0.1 ]; then
        capture parallel "$ROOT" "$MODE" "parallel-$MODE-$REPEAT" F06
      fi
    done
  done
done
printf 'QA_NATIVE_HOOK_CAPTURE_COMPLETE=%s (not a verdict)\n' "$STAMP"
