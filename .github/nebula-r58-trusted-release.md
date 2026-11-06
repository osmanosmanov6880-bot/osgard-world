# NEBULA R58: verified source and exact four-file Web release candidate

**State: RELEASE CANDIDATE ONLY.** This metadata does not certify the public deployment or physical-device rendering.

## Independent provenance and exact tree

- Accepted source: PR #762, source head `a8940a165a3ebc05e85b0538441a56c0b4c19cc4`, six source checks successful.
- Source merge: `7cd605966387b20dedc16c247ebc907a75139283`.
- Original native Godot 4.7.2 verification/export: successful run `42181630680` (GDScript, native smoke, WebAssembly).
- Output: `9a1234655a6edc349a753d08246c89d9a11f16e1`, direct sole-child of source merge; inspected via GitHub Git objects, not approximated.
- Independent real Chromium WebAssembly flight run `42181762186`: **SUCCESS**.
- Independent hosted SwiftShader visual capture run `42181762157`: **FAILURE / no trustworthy 720p frame**. Do not mark visual QA as passed; no actual Android/iPhone hardware QA.

| Exact game blob | Git blob SHA-1 |
| --- | --- |
| `index.html` | `7fc62f5ec765f32916783cde6e1f44d9a9a2851c` |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` |
| `index.pck` | `03181634177b0ee2a9a719cb8dc061018b0698fa` |

## Changes versus last public verified R57

- `index.html` and `index.pck` changed. `index.js` and `index.wasm` remain byte-identical.
- R58 adds earned pilot career rank and live physical 3D patrol risk tiers; only successful verified route completion grants CR/XP.
- Last independently verified R57 HTTPS 4/4 parity: run `42150893844`.

## Release conditions — never bypass

1. Ensure four exact Git blobs match the checked-out Web export and all production guard *negative tests* pass.
2. Review unresolved independent SwiftShader capture failure; physical phone QA stays `NOT_PERFORMED`, no fake approval.
3. Keep R58 source and export SHA distinct; reject extra fifth asset, unexpected bytes, false phone attestation and provenance edits.
4. Upon explicit approval of this release PR, run rollback-safe SSH publish, then independent public HTTPS byte parity for all four assets.
5. Until the deploy and public parity pass, publicly verified release remains R57; do not promote R59/R60.

**Important:** this candidate includes a proposed owner-directed software-only risk override. It is not a hardware/visual quality certification; the actual production authorization is the separately reviewed and merged release PR.
