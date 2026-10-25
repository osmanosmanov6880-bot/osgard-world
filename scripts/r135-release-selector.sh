#!/usr/bin/env bash
# Select an immutable reviewed R135 public release; this file is source-controlled.
# Output ONLY pin path. No floating Actions runs or implicit W18 promotion.
set -euo pipefail
SELECTOR=scripts/r135-active-release.json
test -s "$SELECTOR" || { echo 'R135 selector missing' >&2; exit 1; }
channel="$(jq -er '.channel' "$SELECTOR")"
pin="$(jq -er '.pin_file' "$SELECTOR")"
case "$channel" in
  w14)
    test "$pin" = scripts/r135-w14-release-pin.json
    test "$(jq -r '.promotion_gate_run_id' "$SELECTOR")" = null
    test "$(jq -er '.version' "$pin")" = r135-case-progress-w14-20261025
    ;;
  w18)
    test "$pin" = scripts/r135-w18-release-pin.json
    # W18 activation MUST be backed by a distinct successful reviewed gate run.
    gate_run="$(jq -er '.promotion_gate_run_id' "$SELECTOR")"
    [[ "$gate_run" =~ ^[1-9][0-9]+$ ]]
    test "$(jq -er '.version' "$pin")" = r135-premium-learning-w18-candidate-20261025
    ;;
  w19)
    # A W19 selector is valid only after an independent exact-source
    # promotion gate has passed. No floating latest or inferred promotion.
    test "$pin" = scripts/r135-w19-release-pin.json
    gate_run="$(jq -er '.promotion_gate_run_id' "$SELECTOR")"
    [[ "$gate_run" =~ ^[1-9][0-9]+$ ]]
    test "$(jq -er '.version' "$pin")" = r135-luxury-academy-w19-candidate-20261025
    ;;
  w20)
    # W20 is an explicit manually reviewed exact-source upgrade, never latest.
    test "$pin" = scripts/r135-w20-release-pin.json
    gate_run="$(jq -er '.promotion_gate_run_id' "$SELECTOR")"
    [[ "$gate_run" =~ ^[1-9][0-9]+$ ]]
    test "$(jq -er '.version' "$pin")" = r135-player-settings-w20-candidate-20261025
    ;;
  w21)
    # W21 is an explicit source-pinned full causal-training release. No
    # automatic upgrade from a success-only build or floating latest tag.
    test "$pin" = scripts/r135-w21-release-pin.json
    gate_run="$(jq -er '.promotion_gate_run_id' "$SELECTOR")"
    [[ "$gate_run" =~ ^[1-9][0-9]+$ ]]
    test "$(jq -er '.version' "$pin")" = r135-explainable-training-w21-candidate-20261025
    ;;
  w27)
    # W27 may be explicitly activated ONLY after independent exact-source
    # 29 original PNGs, actual native and browser tests and a fixed gate run.
    test "$pin" = scripts/r135-w27-release-pin.json
    gate_run="$(jq -er '.promotion_gate_run_id' "$SELECTOR")"
    [[ "$gate_run" =~ ^[1-9][0-9]+$ ]]
    test "$(jq -er '.version' "$pin")" = r135-integrated-w27-candidate-20261025
    ;;
  *)
    echo "Unexpected R135 release channel" >&2
    exit 1
    ;;
esac
test -s "$pin"
source="$(jq -er '.source_commit' "$pin")"
digest="$(jq -er '.manifest_sha256' "$pin")"
[[ "$source" =~ ^[0-9a-f]{40}$ && "$digest" =~ ^[0-9a-f]{64}$ ]]
printf '%s\n' "$pin"
