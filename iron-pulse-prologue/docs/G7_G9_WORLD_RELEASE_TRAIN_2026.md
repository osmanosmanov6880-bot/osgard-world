# IRON PULSE WORLD — G7 → G9 INTERNATIONAL RELEASE TRAIN

**Base:** G6 exact-source engineering CI SUCCESS, commit \`ebecfb6ce090b9837b43b542c38fd28a062caa89\`, [Actions #41020249762](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41020249762).
**Scope:** only \`iron-pulse-prologue\` and its existing GitHub Actions workflow. We do NOT claim production deployment, live traffic, verified iOS hardware, authenticated humans, commercial rights, signed Windows executables or external AAA art/audio approval.

## Launch principles — unconditional

1. **Keep master and live systems untouched** during the remaining readiness work. Each candidate is exact-source and reproducible. G5 vault staging does not activate production.
2. The SHA-256 of a package confirms integrity only against an independently trusted digest. SHA-256 of an operator-supplied JSON record is NOT a hardware certificate, proof of consent or signature.
3. G6–G9 CLI tools require a verified existing Godot Windows/WebGL Release Vault archive. They can output only **RELEASE_HOLD** or a request for **independent human review**. They never return \`production_approved=true\`, grant a launch GO, sign Windows binaries, deploy websites or change DNS/CDN.
4. No participant identity, name, email, phone, IP, hardware UUID or exact address belongs in public QA evidence. Use only anonymous participant codes in the local private evidence directory. If consent is withdrawn, promptly remove their data and rerun review.
5. All CI test fixtures are synthetic; they cannot be used as evidence of human/device/commercial testing. CI deliberately verifies real binaries with *missing* physical / human evidence and requires a HOLD.

## B1 — G6 physical readiness (existing validated engineering base)

Sources: \`ci/device_acceptance_g6.py\`, \`docs/G6_PHYSICAL_DEVICE_ACCEPTANCE_2026.md\`.
Must actually test integrated/discrete Windows, midrange/entry Android Chrome, and real iPhone Safari. Run GRID, HEAT, AIR twice each per device class, plus 30 active minutes soak broken into <=10 minute G4 reports. Check controls, input, sound, checkpoints, app resume and heat. The G6 p95 goals (16.7 ms HERO discrete, 33.3 ms ECO) are **provisional main-loop targets**, not achieved GPU measurements. Independent owner needs to witness, retest and document known unsupported devices.

**Exit criterion:** the reviewer independently confirms the real devices and approves acceptance *outside* the CLI, with a signed/human-traceable decision kept privately. CI alone is insufficient.

## B2 — G7 actual player study & campaign quality

Code: \`ci/human_playtest_g7.py\`, \`ci/test_human_playtest_g7.py\`.

- Recruit at least **20 independently consenting real players who finish all three acts**. Report all failed and withdrawn sessions too, not just successes. Completion rate target >=80% over included sessions, and >=5 RU + >=5 EN participants, with representation across Windows/Android/iOS as available.
- Separate participant codes \`P-xxxxxxxxxxxx\` only, not identities. Each code has exactly one GRID, HEAT, AIR report: completion, time, retries, controls/clarity/engagement/accessibility ratings (1–5) and an anonymized feedback code. Consent and withdrawal flags are required, but are not remotely authenticated.
- Every P0/P1 bug must be fixed, verified and covered by a regression test. P2/P3 issues require explicit triage. Preserve adverse feedback, including device failures and failed campaign completions.
- Run human follow-up interviews only with informed consent; avoid recording voice/video or collecting contact details in code artifacts without separate consent and secure storage.
- Independent visual/audio quality review is distinct from code correctness. Assessment categories: lighting & navigation, physical controller/phone comfort, readability, coherent three-act narrative, original artwork, soundtrack/mix, localization, accessibility, crashes/thermal performance.

Private operator procedure:

\`\`\`bash
cd iron-pulse-prologue
python3 ci/human_playtest_g7.py --init \
  --archive /trusted/IRON_PULSE_WORLD_G5_RELEASE_HOLD.zip \
  --source-sha <TRUSTED_FULL_40_HEX_SOURCE> \
  --bundle-sha256 <TRUSTED_FULL_64_HEX_ARCHIVE> \
  --evidence-dir /private/iron-pulse/g7
# Fill /private/iron-pulse/g7/trials.json only with consented, anonymous actual sessions.
python3 ci/human_playtest_g7.py \
  --archive /trusted/IRON_PULSE_WORLD_G5_RELEASE_HOLD.zip \
  --source-sha <TRUSTED_FULL_40_HEX_SOURCE> \
  --bundle-sha256 <TRUSTED_FULL_64_HEX_ARCHIVE> \
  --evidence-dir /private/iron-pulse/g7 \
  --output /private/iron-pulse/g7-review.json
\`\`\`

An internally consistent packet gives only \`READY_FOR_INDEPENDENT_REVIEW\`, **not** 20 authenticated humans.

**Exit criterion:** witnessed 20-player three-act study, severity-reviewed bugs, agreed design/audio improvements, external reviewer signoff.

## B3 — G8 global legal/security/distribution and release-control review

Code: \`ci/world_launch_gate_g8.py\`, \`ci/test_world_launch_gate_g8.py\`.

The gate independently invokes G6/G7/G9 validations against the *same actual source-bound release archive*. The local \`g8/checklist.json\` has 27 explicit checkboxes in five groups:

- **Rights and legal:** all authored assets, third-party licenses, audio/voice, marks, notices, age ratings and jurisdiction-specific consumer/refund terms.
- **Security and privacy:** RU/EN privacy notices, minimum telemetry, file retention, dependency review, vulnerability triage, unambiguous download provenance.
- **Platform and accessibility:** real Safari verification, actual input/visual/audio accessibility, independent art/audio judgement.
- **Distribution and recovery:** Windows code signing, pinned external SHA and receipt, TLS/HTTP headers, real-host staging, real-host rollback, backup restore, customer support.
- **Governance:** independent legal, security, hardware and playtest auditors, authorized named release owner held privately.

\`\`\`bash
python3 ci/world_launch_gate_g8.py --init \
  --archive /trusted/IRON_PULSE_WORLD_G5_RELEASE_HOLD.zip \
  --source-sha <TRUSTED_SOURCE_SHA> \
  --bundle-sha256 <TRUSTED_ARCHIVE_SHA> \
  --evidence-root /private/iron-pulse
python3 ci/world_launch_gate_g8.py \
  --archive /trusted/IRON_PULSE_WORLD_G5_RELEASE_HOLD.zip \
  --source-sha <TRUSTED_SOURCE_SHA> \
  --bundle-sha256 <TRUSTED_ARCHIVE_SHA> \
  --evidence-root /private/iron-pulse \
  --ops-head <EXTERNALLY_TRUSTED_G9_LEDGER_HEAD_SHA>
\`\`\`

The best result is \`READY_FOR_INDEPENDENT_LAUNCH_AUDIT\`. It is not a production GO, even with every flag true. Require a separate authenticated responsible-human authorization outside CI before any production changes.

**Release protocol once independently authorized (NOT performed):** frozen source -> signed binaries and verified web artifact -> staging on real distribution infrastructure -> independent smoke test -> limited canary -> monitor agreed objective signals -> hold/rollback on breach -> widened distribution after explicit approval. Do not promise instant rollback for DNS caches, app downloads or offline clients; test actual behavior. Rehearse restore from backed-up state and rollback of service-worker caches. Do not collect telemetry without policy/consent.

## B4 — G9 support, incident management, resilience and postlaunch

Code: \`ci/operations_g9.py\`, \`ci/test_operations_g9.py\`.

Implement a **local offline rehearsal ledger**, not a fictitious production operations center. Events follow exactly \`OPEN -> TRIAGE -> MITIGATE -> RECOVER -> CLOSE\`. Each JSONL event has fixed non-identifying codes, exact source/build SHAs, sequence number, previous event digest and SHA-256. The writer uses an exclusive lock, compare-and-swap expected last hash, flush and atomic file replacement. To demonstrate integrity against ledger rewrite, pin the latest head **independently** of the ledger under a trusted operator process. An internal chain without a trusted head is not tamper-proof.

\`\`\`bash
python3 ci/operations_g9.py --init \
  --archive /trusted/IRON_PULSE_WORLD_G5_RELEASE_HOLD.zip \
  --source-sha <TRUSTED_SOURCE_SHA> \
  --bundle-sha256 <TRUSTED_ARCHIVE_SHA> \
  --ops-dir /private/iron-pulse/g9
# After an authorized manual drill, append each next event with the PREVIOUS
# known head. Start the first with --expected-head none.
python3 ci/operations_g9.py --append OPEN \
  --incident DRILL-0001 --note-code DRILL_START \
  --expected-head none \
  --archive /trusted/IRON_PULSE_WORLD_G5_RELEASE_HOLD.zip \
  --source-sha <TRUSTED_SOURCE_SHA> \
  --bundle-sha256 <TRUSTED_ARCHIVE_SHA> \
  --ops-dir /private/iron-pulse/g9
# Repeat TRIAGE, MITIGATE, RECOVER, CLOSE with the newly returned head each time.
# Complete the ten private ops.json checkboxes only after performing each step.
\`\`\`

G9 also requires support intake, incident severity/triage rules, an independently agreed backup on-call, localized RU/EN incident communication templates, safe data retention, rollback/restore drills and scheduled review at 30/60/90 days. No actual SLO or uptime is claimed without production measurements.

**Exit criterion:** live support channels verified, operator practices rehearsed, traceable incident ownership and independently reviewed runbooks. Post-release follow-up must be based on genuine production incidents, support tickets and opted-in aggregate observability.

## Release decision register

| Gate | What CI can prove | What only real humans/infrastructure can prove | Current default |
|---|---|---|---|
| G6 | Format/metrics integrity + Godot archive hold | Physical Windows/Android/iPhone results | HOLD |
| G7 | Consent-code/trial schema and 3-act structural completeness | 20 real people, authentic consent and independent narrative QA | HOLD |
| G8 | Source, G6/G7/G9 evidence coherence and 27 controls | Licensed assets, Windows signed binary, real host, actual commercial legal approval | HOLD |
| G9 | Incident-ledger hashes/state order, tamper and CAS checks | Support operations, real restore, response ownership and production SLO | HOLD |
| Commercial GO | **No code path grants this** | Signed accountable decision + real-host staged release approval | HOLD |

## Roadmap through stable global operations

1. **R0 — Engineering candidate (G5/G6):** source-bound CI, reproducible packaged binaries, strict offline staging. Already verified on G6 exact source; later commits must pass CI again.
2. **R1 — Independent device lab (G6):** schedule five physical device classes, at least 10 clean act runs per class including soak, two quality profiles where relevant, 30m uninterrupted stress.
3. **R2 — Player discovery and repair (G7):** independently observed sample, real first-run success, campaign replay and engagement; fix P0/P1 and do an independent AAA visual/audio quality evaluation.
4. **R3 — Security/legal release readiness (G8):** complete licenses, rights, localization/accessibility, Windows signing, trust chain and privacy/terms. Make a real staging-host smoke test and rollback drill with backups.
5. **R4 — Controlled canary (G8):** only after external GO; staged rollout with SLO rollback policy, audit log and explicit operator ownership.
6. **R5 — Operating service (G9):** RU/EN help, issue intake/bugfix releases, genuine crash/performance aggregates, weekly integrity/restore drills and 30/60/90-day product review.
7. **R6 — International growth:** only after reliable operations, assess additional languages, regional distributors, storefront requirements, support capacity and commercial conversion from observed data; no invented monthly users or revenue.

### Minimum organizational accountability

- **Tech/release lead:** source commit, packaging, device results and documented rollback.
- **Independent QA:** campaign and accessibility, physical witnesses and regression test evidence.
- **Art/audio reviewer:** visual read, lighting, animation, narrative and original sound rights.
- **Legal/IP reviewer:** asset provenance, trademarks, localization, jurisdiction-specific compliance.
- **Operations owner:** support, security incident response and recovery exercises.
- **Business release owner:** external GO/NO-GO decision and record; no script may silently replace this role.

### Stop/rollback rules

Block GO for unresolved P0/P1, invalid package hash, unsupported required hardware, missing rights, incomplete legal/privacy, unverified Windows signing, failed host rollback/restore, missing release accountability or no independent art quality review. During canary, stop and roll back where safe on severe crashes, data loss, broken startup, licensing claims, privacy breach or meaningful regression against tested performance budgets. Signed binary downloads already in users' hands cannot be retracted: publish a revocation/replacement advisory and fixed signed build.

**Status by design:** the full G7–G9 implementation is an *engineering readiness system*; no actual independent physical test, 20-player study, external release audit, production service or revenue is claimed by creating this code.
