#!/usr/bin/env python3
"""R84 fail-closed static contract for independent original public Godot G0.

The contract only checks workflow wiring. CI executes real HTTP, original
WASM/PCK hash validation, real Chromium, and R83 as separate jobs after merge.
No generated or synthetic image is eligible as production evidence.
"""
from pathlib import Path

WORKFLOW = Path(".github/workflows/omega-r84-real-g0-evidence.yml")


def insist(value: bool, reason: str) -> None:
    if not value:
        raise ValueError("R84 unsafe G0 release workflow: " + reason)


def validate(source: str) -> None:
    insist("  pull_request:" in source, "missing isolated pull request contract")
    insist("  push:\n    branches: [master]" in source, "master-only reviewed auto recheck missing")
    insist("      - '.github/workflows/omega-r84-real-g0-evidence.yml'" in source,
           "automatic checks must not run on every unrelated portal commit")
    insist("  workflow_dispatch:" in source, "missing manual master recheck")
    insist("  contents: read" in source, "GitHub workflow requires read-only token")
    insist("  real-public-g0-verified-full-release-HOLD:" in source,
           "missing explicit G0 review versus full AAA HOLD boundary")
    live = source.split("  real-public-g0-verified-full-release-HOLD:", 1)[-1]
    insist(live is not source, "missing actual R83 G0 job")
    condition = live.split("    runs-on:", 1)[0]
    insist("github.event_name == 'push'" in condition and
           "github.event_name == 'workflow_dispatch'" in condition and
           "github.ref == 'refs/heads/master'" in condition,
           "unreviewed PR/feature branch must never attest public production")
    insist("github.event_name == 'pull_request'" not in condition,
           "pull request may run tests but not live release attestation")
    insist("git fetch --no-tags origin \"$source_sha\"" in live and
           "omega-build-freshness.py \"$source_sha\" HEAD" in live,
           "original released commit must remain pinned")
    insist("validate_manifest(m,Path('public/games/omega-3d-preview'),strict_bytes=True)" in live,
           "must verify actual binary bytes, not manifest success flag")
    insist("scripts/omega-live-integrity.py" in live and
           "--expected public/games/omega-3d-preview/release.json" in live and
           "--base https://osgard.world/games/omega-3d-preview" in live,
           "seven independently downloaded public binary hashes required")
    insist("assert d['status']=='PASS' and d['verified_files']==7" in live and
           "assert len(d['results'])==7 and all(x['sha256']=='matched' for x in d['results'])" in live,
           "original R50 verified_files/results schema must attest all seven assets")
    insist("npm ci" in live and "npx playwright install --with-deps chromium" in live,
           "need real pinned browser, not fake pixels")
    insist("OMEGA_CI_GL_BACKEND: mesa" in live and
           "xvfb-run -a" in live and "LIBGL_ALWAYS_SOFTWARE:" in live,
           "Mesa/Xvfb original WebGL path missing")
    insist("playwright.omega-live-webgl.config.mjs" in live and
           "--retries=0 --reporter=json" in live,
           "must exercise real desktop+touch game without flaky retries")
    insist("scripts/omega_r83_release_gate.py" in live and
           "--r50-live omega-r84-evidence/live-integrity.json" in live and
           "--r50-browser omega-r84-evidence/playwright.json" in live,
           "genuine HTTP/browser results must be passed to original R83")
    insist("v['machine_verified_components']==['source_bound_public_webgl']" in live,
           "no unverified human / physical / art fields may be checked")
    insist("v['technical_web_ready'] is True" in live and
           "v['status']=='HOLD'" in live and
           "v['production_go'] is False" in live and
           "v['aaa_quality_certified'] is False" in live,
           "R84 may never declare full AAA Production GO")
    insist("'physical_android_original_telemetry'" in live and
           "'physical_ios_original_telemetry'" in live and
           "'forty_human_mission_evidence'" in live and
           "'twenty_consented_player_sessions'" in live and
           "'original_art_frames_and_licences'" in live,
           "all five independent human/physical/art gates must remain HOLD")
    insist("if: always()" in live and "actions/upload-artifact@v4" in live,
           "original public WebGL traces and hashes must be retained even on failure")
    insist("retention-days: 14" in live, "evidence retention must be explicit")
    insist("secrets." not in source and "scp " not in source and "ssh " not in source,
           "independent read-only QA must never acquire deploy credentials")
    insist("production_go=True" not in source and "'production_go': True" not in source,
           "cannot use an unconditional GO override")


def main() -> int:
    validate(WORKFLOW.read_text(encoding="utf-8"))
    print("PASS R84: master-only real public Godot WebGL, source+seven hashes, R83 G0, strict AAA HOLD")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
