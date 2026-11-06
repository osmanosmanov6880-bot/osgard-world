# NEBULA R60 — trusted real physical crash Web release

**DRAFT RELEASE CANDIDATE. R59 remains latest verified public release until protected publish + independent HTTPS 4/4 acceptance.**

## Original source, native validation and export lineage

- Source development PR #765 exact head `7ab51f490cef0e21b70c10ffa6bdc941f522226d`: six source CI checks SUCCESS (native Godot tests, Chromium real WASM flight, mobile controls, backend/frontend/readiness).
- Merge commit `5a218c3a21f1ecf58e3365861f0edf14abdc3bd0`; exact Web export sole-child `e4996cba72f7817dd6b41666d45c9bd2455c7cab`.
- Godot 4.7.2 post-merge native build & Web export workflow [#42221692070](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42221692070). Status must be confirmed SUCCESS before release approval.
- All four SHA-1 values below are ORIGINAL Git blob objects from exported commit, not locally regenerated or guessed.

| Web asset | Original Git blob SHA-1 |
| --- | --- |
| `index.html` | `0b46ddef49aebcf49a8bc9f0cc72eaa53d656ee2` |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` |
| `index.pck` | `cce6546ad402b04140b10e529845c9ed9da5a4c5` |

## Physical game behavior

- Nine individually simulated RigidBody3D aircraft fragments spawned at crash point, visible 1.6-second crash-hold sequence and real burnt/impact effects.
- Ship intact mesh hidden only during wreck; player controls locked; failed sortie returns to dock; free-flight recovery debits exactly 220 CR with no XP/reward mint.
- Regression tests reject bounties during wreck/dock; legitimate 45 CR active-flight kills resume after recovery.
- Source R60 native smoke logs `NEBULA_R60_REAL_PHYSICS_9_SHARDS_WRECK_HOLD_DAMAGE_AND_RECOVERY_SUCCESS`.

## Strict conditions / limitations

- Last public version before release: **R59**; [HTTPS 4/4 verified #42221558386](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42221558386). Use for rollback.
- Verify exact PR source as second parent of merge, export as sole child, SHA-pinned four binary assets, negative tamper/false-attestation scenarios.
- Record actual outcome of separate R25 Chromium flight and R11 hosted SwiftShader screenshot. Incomplete/canceled work is **not** a pass. Source PR did run real Chromium and mobile WASM E2E.
- **Real Android/iPhone hardware QA NOT_PERFORMED; hardware_qa_certified=false.** No AAA/real-GPU FPS or visual-quality certification from hosted SwiftShader; no real-money payments from local CR wallet.
- After 5/5 latest-head release gate success and source/export evidence review, merge only this protected release PR. Then verify SSH publish SUCCESS and independent 4/4 public HTTPS parity before calling R60 live.
