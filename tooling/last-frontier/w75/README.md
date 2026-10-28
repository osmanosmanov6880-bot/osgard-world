# LAST FRONTIER W75 — Evidence Collection Gate

This directory is **real executable offline Python code**, not a fictional certification. It cannot recruit human participants or measure a physical device by itself. It detects missing/forged-looking evidence and will never publish or merge a build.

## Usage

Requires Python 3.10+ (no external packages):

```sh
python3 tooling/last-frontier/w75/release_gate.py \
  --template playtest-evidence/W75_BLANK_MANIFEST.json

python3 tooling/last-frontier/w75/release_gate.py \
  --manifest playtest-evidence/W75_BLANK_MANIFEST.json \
  --evidence-root playtest-evidence \
  --out playtest-evidence/W75_RELEASE_HOLD_REPORT.json
```

The second command **intentionally exits 3** until evidence is collected. It reports `PRODUCTION_HOLD` rather than awarding fake points for a blank form.

Test its refusal of invented participants, forged hashes, duplicate pseudonyms, symlinks, impossible FPS, impossible duration, fake device classes, missing name clearance or absence of explicit authorization:

```sh
python3 -m unittest discover -s tooling/last-frontier/w75 \
  -p 'test_release_gate.py' -v
```

## Supplying actual, independent evidence

Start with **the exact accepted W74 source SHA** `73ef81b54cb42831cafd9ac8fa69c5807cd8dc8d`, not a new or untested build. Get verified QA artifacts from [CI 40650956529](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40650956529). Copy `W74_SOURCE_AUDIT.json`, the original binary `index.wasm` and `index.pck`, and `evidence.json` to the evidence folder; set their true local SHA-256 in the JSON manifest. The gate verifies original source-audit fields and exported binary byte hashes against `evidence.json`; it cannot be satisfied by an unrelated JSON document with a self-matching hash.

Real player sessions: find at least **12 unique consented first-time users** independent from the developer. Use anonymous participant codes; do not enter their names, phone, addresses, medical information, speech recordings or emails. Each session record needs actual observer code, real time observed, win/lose outcome, confusion events, exact source SHA and SHA-256 checked local evidence file. The collector does NOT generate any such sessions or pretend to validate real human identity. Target median 600–900 seconds, >=9 actual completions and average <=2 confusion events.

Physical hardware: submit at least one truly observed tested Windows PC, one Android device and one iOS device, each with actual GPU/device label, >=300 measured actual original game render samples, median FPS >=60 and p95 <=20ms, with local hashed measurement file. **Software-rendered CI/SwiftShader does not qualify**. Those are release TARGETS, not achieved benchmark claims.

Quality review: actual independent professional environment/animation/audio/narrative approval and original asset license review, with a source-hashed signed evidence file. Legal: a DISTINCT trademark-cleared title, clearance in relevant jurisdictions, and documented audio/art licensing. Owner: explicit signed human GO, never automatically implied.

Even after all supplied evidence passes shape/digest validation, output is only `FINAL_MANUAL_REVIEW_REQUIRED`, **not permission to ship**. A local script can validate bytes and threshold calculations; it cannot verify that a person truly attended a session or that a lawyer made a valid determination. No network, email, publication or merge actions exist in the tool.

## Strict limitations

- Existing game on W74 remains unchanged.
- File paths are confined to the selected local evidence root; absolute paths, traversal and symlinks leaving the folder are rejected.
- No artificial users, fake performance benchmarks, AI-generated human comments, made-up approval signatures or automatic commercial releases.
- The currently known name LAST FRONTIER / ПОСЛЕДНИЙ РУБЕЖ is a *working title*, not cleared for sale.
