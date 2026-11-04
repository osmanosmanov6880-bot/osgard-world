# NEBULA R41 — owner-directed release evidence

**Date:** 2026-11-04. **Release status:** CANDIDATE until deployment workflow ends successfully. **Physical Android/iPhone testing:** NOT PERFORMED; **not** a hardware QA certification.

## Why this release is allowed, and what is not claimed

Repository owner repeatedly requested direct NEBULA publication, including the 2026-11-04 instruction. This file records a **new** R41 owner-directed risk acceptance without asserting R40's hardware signoff. The R40 evidence gate remains unchanged and continues to require its own 108 original reports, photos and human review.

### Verified pre-publish provenance

- R41 implementation PR #719 merged at `09413461988ae2aa68f1260fdad5d2de42d90f84`.
- R41 native Godot 4.7.2 export + runtime smoke and actual browser WebAssembly flight (including emulated mobile) passed:
  - PR QA: `https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41825606371`
  - master production export: `https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41842409047`
- The Web export produced master commit `3e2bc2f57209db101779b28afc24997522972174`.
- First isolated publish `41842542199` correctly failed **at the asset guard**, because the four hashed assets no longer all matched R39. It did not activate unapproved bytes.

### Exact file identities in the exported master

| Path suffix | Git blob SHA-1 | Result |
|---|---|---|
| `index.html` | `bc56c6cecf3977c8d7c2e8359f10f7b47afc8676` | R41 changed |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` | unchanged engine JS |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` | unchanged WebAssembly engine |
| `index.pck` | `ec4be6fcf21c4062d2f0eb8171b5112e472fab35` | R41 changed |

These are **Git blob hashes**, not ordinary SHA-1 digests of raw bytes. The release asset guard validates all four before SSH copying. The allowlist update alone is not proof of live activation.

## Required release workflow

1. Branch release policy PR passes negative guard test, validating R41 specific provenance and false hardware claims are rejected.
2. Merge policy PR with tested hashes; `deploy-remix-arena-static.yml` is triggered for the policy and guard change.
3. Isolated SSH deployment checks exact file hashes, staging space, backup, internal Nginx health, all mandatory game routes, and rollback on failure.
4. Public HTTP and (where practical) WebGL flight verified; documentation updated with actual run URL, not assumed success.
5. R42 is **separate** and not included in this release. Never treat a successful R41 release as R42.

### Outstanding risks / limitations

- No physical touch-device proof. Automated mobile browser emulation is not hardware testing.
- General OSGARD frontend validation on the source PR had failures in its unrelated Navigator/unified-shell test; this isolated game release does not certify those systems.
- Existing saves use `user://nebula_3d_save.json` v1 with additive R41 debrief data; premium entitlements are verified outside the game save.
- First-play experience can still be improved in R42+, especially interactive captains, full 3D hangar, visual polish and mobile hardware QA.
