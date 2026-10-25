#!/usr/bin/env bash
# EMPIRE Ω R79: four ACTUAL Godot 4.4.1 WebGL viewports, isolated Chromium.
# Does not generate imagery, weaken scene-diversity assertions or certify AAA.
# Requires npx Playwright, genuine exported localhost:4173 Godot WASM/PCK,
# Xvfb and Mesa GL packages preinstalled by the invoking GitHub Action.
set -euo pipefail

output_dir="omega-original-four-viewport-evidence"
mkdir -p "$output_dir"
tested=0

# Desktop Mesa runs first on a fresh runner; all four original browser scenes
# remain mandatory, no retries and no splash or fake pixel acceptance.
for viewport in desktop-1366x768 portrait-390x844 small-phone-320x568 landscape-phone-844x390; do
  echo "::group::Original Godot WebGL pixels: $viewport"
  failure=0
  if [ "$viewport" = "desktop-1366x768" ]; then
    OMEGA_CI_GL_BACKEND=mesa LIBGL_ALWAYS_SOFTWARE=1 \
      xvfb-run -a -s '-screen 0 1920x1080x24' \
      npx playwright test --config playwright.omega-portrait-preview.config.mjs \
        --project="$viewport" --workers=1 --retries=0 || failure=$?
  else
    npx playwright test --config playwright.omega-portrait-preview.config.mjs \
      --project="$viewport" --workers=1 --retries=0 || failure=$?
  fi
  mkdir -p "$output_dir/$viewport"
  if [ -d omega-portrait-preview-results ]; then
    cp -a omega-portrait-preview-results "$output_dir/$viewport/results"
  fi
  if [ -d omega-portrait-preview-report ]; then
    cp -a omega-portrait-preview-report "$output_dir/$viewport/report"
  fi
  if [ "$failure" -ne 0 ]; then
    echo "::error::Original WebGL scene proof FAILED for $viewport; no fake pixels or retries permitted"
    echo "::endgroup::"
    exit "$failure"
  fi
  tested=$((tested + 1))
  echo "::endgroup::"
done

test "$tested" -eq 4
echo "PASS: four independent original Godot WebGL2 viewports with 0 Playwright retries"
