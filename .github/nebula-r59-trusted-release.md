# NEBULA R59: original verified Web export / 4-blob protected release

**RELEASE CANDIDATE. Not live until release PR, rollback-safe SSH publish and public HTTPS byte parity are successful.**

## Original trusted source and export
- Source PR #763, all six checks successful: `2b3dfb07095ba17c5d5bc219437c46c1fa57acfc`.
- Source merge commit: `a9b345a5571a57de71eff8e6b59bc047da5cf7d6`.
- Pinned native Godot 4.7.2 CI run #42218366293: SUCCESS, includes native smoke and WebAssembly export.
- Exact Web export commit: `3ee4bc1b8fd6ced97bce6ad38289821858cb71b9`, sole child of source merge.
- Independent Chromium R25 / hosted SwiftShader R11 triggered from export; record actual outcome before deployment approval.

| Web file | Original exported Git blob SHA-1 |
| --- | --- |
| `index.html` | `f2cea6c6fa2591505728b127c60bf1b6e01e783d` |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` |
| `index.pck` | `6ae3427b7fa75fe933eef5155deccb7d746bbf69` |

R59 changes HTML and PCK versus R58; JS and WASM are byte-identical to the publicly accepted R58 export. Protect all four nevertheless.

## Actual player features
- Four metallic liveries, with hull-bound ownership, real distinct physical material geometry, and purchase/selection in the hangar.
- Existing R58 earned career and CR/XP rewards retained. UI works with local user:// wallet, not a certified payment backend.
- Never claim full AAA visual quality from a procedure-based 3D renderer.

## Hard release rules
1. Verify exact source merge and export ancestry in the Git DAG and compare all four Git blob identities; no asset rewrite or unapproved fifth blob.
2. Run native Godot and real Chromium flight tests. Record separately whether hosted SwiftShader renders pixels and whether any real Android/iPhone hardware QA was performed. Hardware QA is **NOT_PERFORMED**.
3. Keep the last public R58 4/4 match as rollback: [R58 public parity #42218250171](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42218250171).
4. Review and merge the exact R59 candidate only after latest-head CI. Trigger protected SSH release; require subsequent independent public 4/4 HTTPS match.
5. Do not promote R60 source while public R59 release remains unverified.
