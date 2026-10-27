# OSGARD W59 — offline handoff W58, production HOLD

This kit is an **independent, read-only download-integrity helper** for the exact
W58 source `ef570cf6c406cc14ec180585ee2c5d64c667c658`. It is not a new game
build, physical-GPU benchmark, hardware certificate or permission to merge.

## Exact official test prerelease

https://github.com/osmanosmanov6880-bot/osgard-world/releases/tag/osgard-w58-9of9-preview-ef570cf-20261027

The release contains four ZIPs and `SHA256SUMS.txt`. Download **all five** from
that one release to a new, otherwise empty folder; do not rename anything.

Run on Windows with Python 3 (no pip dependencies):

    py -3 tooling/osgard-w59/release_handoff.py --asset-dir C:\OSGARD\W58 --output C:\OSGARD\W58-review.json

Or on Linux/macOS:

    python3 tooling/osgard-w59/release_handoff.py --asset-dir ./W58 --output ./W58-review.json

Run synthetic tests:

    python3 -m unittest discover -s tooling/osgard-w59 -p test_release_handoff.py -v

The CLI checks the four ZIP hashes against `SHA256SUMS.txt`, independently pins
the candidate ZIP hash to W52's exact-source evidence
`d38390b6bc483431193ada34382330f101bb2aee3923f1eb619029f212fe7684`,
rejects unsafe archive entries and duplicate paths, checks all original candidate
manifest member digests and genuine Windows `MZ`, Godot `GDPC` and WebAssembly
`\0asm` headers. It **never extracts or executes** untrusted binaries, connects to
GitHub, requests credentials or modifies production.

`offline_integrity=PASS` means **only** that downloaded bytes and internal
structure match recorded software evidence. The W52 software acceptance still
belongs to its original exact GitHub run #40549670648. **No machine-created PASS
can approve production.** Even on integrity PASS the emitted JSON always says
`production_decision=HOLD` and all approval flags are false. On mismatch the CLI
exits with code 2 and produces FAIL/HOLD.

## Physical device test matrix (NOT TESTED until conducted)

Each observation must reference the **same W58 40-character SHA** and **exact
candidate build** from the prerelease. Keep original files, screenshots and
raw frame-time logs unmodified. Never use SwiftShader/Chromium emulation to claim
consumer GPU or phone certification.

| Platform | Required REAL device evidence | Gate |
|---|---|---|
| Windows GPU | Hardware model, driver, display resolution, actual EXE+PCK start; all six missions, 3 cameras, HERO/ECO, RU/EN, long-session crashes and frametimes | Human reviewer |
| Physical desktop WebGL | Browser/version, GPU details, actual game input, HERO/ECO, real frame-time capture | Human reviewer |
| Android | Exact phone/OS/Chrome, actual touch and safe areas, RU/EN glyphs, cameras, missions, 30-minute thermal/memory observation | Human reviewer |
| iPhone | Exact iPhone/iOS/Safari, real gestures and safe areas, RU/EN glyphs, cameras, missions, 30-minute thermal/memory observation | Human reviewer |

For each mode and supported device, include at least a 30-minute uninterrupted
capture, median FPS, **1%-low FPS calculated from actual frame times**, observed
thermal and memory behavior, any stalls/crashes, testing time, named tester,
original evidence files and SHA256 values. Test visual quality and accessibility
with actual native RU/EN screenshots. Performance acceptance thresholds and
supported device classes must be approved by the product owner; do not invent
60 FPS or AAA certification from desktop emulation.

Use the **existing source-bound W56 offline reviewer** for device JSONs:

    python3 tooling/osgard-w56/hardware_review_gate.py --expected-sha ef570cf6c406cc14ec180585ee2c5d64c667c658 --windows win.json --webgl web.json --android android.json --ios ios.json --output W56-physical-review.json

This W56 helper also **always** emits HOLD/HUMAN_HARDWARE_REVIEW_REQUIRED even if
all four self-reports look complete. Review original evidence independently.

## Final independent gates (cannot be bypassed by W59)

- Real-device GPU/Android/iPhone acceptance and original RU/EN art signoff.
- Independent 30-minute median and 1%-low/per-frame validation, thermal/memory,
  safe-area and accessibility review.
- Reconcile upstream W33-W58 draft PR stack with current `master`, test the
  **proposed integrated merge tree**, and repeat exact-merged-source CI; the
  current W58 isolated branch CI is not a master merge test.
- Rehearse production rollback on staging; preserve current live site.
- Named owner signs a **separate**, explicit release GO after all evidence.

Until then, **HOLD**: do not merge into `master`, deploy `osgard.world`, touch
DNS/CDN/VPS/SSH, publish a production release or claim physical certification.
This W59 branch/PR only introduces review tools, not a new signed W58 build.
