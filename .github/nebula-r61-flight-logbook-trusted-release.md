# NEBULA R61 — verified Web export and protected four-blob release

**RELEASE CANDIDATE ONLY.** R60 is the independently verified public software version until this release passes SSH publish and subsequent public HTTPS 4/4 exact-byte verification.

## Source and immutable export provenance

- R61 gameplay source [PR #770](https://github.com/osmanosmanov6880-bot/osgard-world/pull/770), final source head `93d134f8dfaf036c28e7df27979c2bfcbebbc751`; 5/5 GitHub source checks SUCCESS.
- Source merge commit `c990e29cff2b42763f520fab821499f438893b9f`.
- Post-merge Godot 4.7.2 native validation/export [run #42319552726](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42319552726): SUCCESS.
- Git-object verified original Web export `8a76c7d4907913f44a7091677603886ba6468f08`: **exact single parent** is the source merge; release guard requires it in release-PR history.
- Native source PR runtime printed `NEBULA_R61_REAL_PILOT_FLIGHT_LOGBOOK_SAVE_NO_MINT_SUCCESS`, `NEBULA_R61_FREEFLIGHT_REARM_TWO_REAL_CRASHES_NO_DOUBLE_REWARD_SUCCESS`, and real R60 crash physics smoke.
- Source PR actual WebAssembly PC Chromium and mobile touch CI: SUCCESS; this is not phone hardware QA.

| Original export asset | Exact Git blob SHA-1 |
| --- | --- |
| `index.html` | `409a5ad9049681ef331ff3a7953ced5850d3dc83` |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` |
| `index.pck` | `e76e49ae74077dd380c8e5c8a370b7222cb56710` |

R61 changes exported HTML and PCK. JS and WASM original Git blobs are unchanged from R60. No file is rebuilt or edited in this release PR.

## Four blocks included in R61 gameplay

1. **Flight records:** Ada/Kai/Leya get earned successes, failures, launch counts, simulated physical distance and in-flight seconds; zero forged CR or XP.
2. **Safe lifecycle:** successful mission or contract closes exactly one record; real R60 physical crash closes one failed flight; automatic free-flight repair for exactly 220 CR rearms a second independently tracked flight.
3. **Persistent records:** existing local save v1 remains readable; defensive metrics parsing rejects unknown captains, invalid/infinite/negative counters and fake qualifications.
4. **Garage interface and QA:** Russian pilot logbook displayed under R54 training; native tests check two genuine crashes and browser PC/mobile games dispatch real input. Existing owner-owned CR cosmetics remain unchanged.

## Release conditions and known QA limitations

- Previous public R60 rollback was verified [HTTPS 4/4 run #42257923099](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42257923099) SUCCESS.
- All latest-head identity/lineage/negative-test/frontend/readiness/launcher CI checks must pass on this candidate before PR merge.
- The independently triggered R25 Web flight run for this export must be assessed on its own merits; absence/cancel is not a pass.
- Hosted R11 SwiftShader WebGL screenshot remains **unverified**; do not claim AAA graphics, validated physical GPU FPS or mobile hardware.
- Android and iPhone physical-device hardware testing: **NOT_PERFORMED**; `hardware_qa_certified=false`.
- Do not claim the actual public site is R61 until rollback-safe SSH deploy reports SUCCESS and an independent HTTPS download of all four exact bytes confirms 4/4.
