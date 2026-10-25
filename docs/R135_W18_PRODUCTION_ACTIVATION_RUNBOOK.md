# OSGARD R135 — protected W18 public activation, persistent release selector

**Default/active:** W14, selected by \`scripts/r135-active-release.json\`. All pushes to
\`master\` continue to deploy verified W14 until a separately reviewed W18 selector
PR is accepted. No version is published by merely creating this infrastructure.

## 1. Immutable W18 binary and actual visuals
1. Merge source features only after native Godot 4.4.1 and genuine Chromium
   desktop/mobile 3-fault gameplay, RU/EN, viewport and touch-target checks pass.
   Real iPhone/Android physical FPS remains separately untested.
2. Download the **exact successful** Actions artifact by RUN ID + ARTIFACT ID.
   Independently inspect and hash the actual WebGL ZIP, signed-off original PNGs,
   manifest, desktop/mobile three-case logs, native PBR GLBs and source commit.
3. Create reviewed \`scripts/r135-w18-release-pin.json\` with source SHA, artifact
   ID/name/run, archive+manifest SHA-256, 11 PNG SHA-256, positive desktop,
   portrait, bilingual and three-fault review flags, and explicit
   \`physical_phone_fps_verified: false\`.
4. Run workflow \`.github/workflows/r135-w18-promotion-gate.yml\` via
   **workflow_dispatch** on a protected review branch with that exact pin.
   The job **independently-accept-real-candidate** (not just contract-negative-tests)
   must finish SUCCESS, re-download and verify ZIP+screens, check luminance and
   real Nginx WASM gzip/PCK 206. Record its run ID and original source+pin bytes.

## 2. Durable public channel switch
5. Open a separate small promotion PR setting
   \`scripts/r135-active-release.json\` to:
   \`\`\`json
   {
     "channel": "w18",
     "pin_file": "scripts/r135-w18-release-pin.json",
     "promotion_gate_run_id": 12345678901
   }
   \`\`\`
   Replace the numeric ID with the exact successful **independently accepted**
   gate. This example is not a usable approval. The PR includes the **same
   pinned bytes** accepted by the gate and is reviewed before merging.
6. The normal protected \`master\` frontend deploy reads this selector (it is
   persistent across unrelated future deploys). If W18 was selected it rejects
   any missing/unsuccessful gate, skipped acceptance job, wrong gate workflow,
   changed pin bytes, wrong game-source SHA, expired artifact, ZIP mismatch,
   substituted PNG, unsafe archive or incorrect release version.
7. Before touching the public site, build the exact Godot binary into release
   tree; Nginx checks WASM gzip Content-Encoding and PCK HTTP206.
8. Protected SSH uploads one checksummed archive; remote activation confirms
   live container source/version/manifest SHA before committing. Public
   same-origin HTTPS smoke then checks exact version, related game routes and API.
   Any failure fails the job, keeping or restoring the verified previous release.
9. Capture successful deploy run ID, active release.json SHA, public screenshot
   and final rollback proof. Only here claim "W18 PUBLISHED"; still do not claim
   independent physical-phone/GPU acceptance or AAA render quality without proof.

## 3. Fail-closed rollback
- Revert only the selector PR to \`w14\` using a reviewed commit and protected
  frontend deploy; pin file W14 remains immutable. SSH activation itself keeps
  atomic rollback state for failed publishes.
- Never replace W18 with W14 inadvertently on unrelated frontend changes:
  selection persists in \`scripts/r135-active-release.json\`, not a one-time
  GitHub Actions input.
- The W14 original Actions artifact can expire; the verified same-byte live
  W14 recovery fallback is allowed ONLY while W14 is the selected channel.
  W18 has no public/stale server fallback before first successful promotion.
- This project remains a simulated industrial lesson, not live plant control.

## 4. Separate W16 hardware certification
Device matrix must include authorized physical Android Chrome and iPhone Safari,
portrait/landscape and ECO/HERO, at least two raw independently reviewed sessions
per cell, honest CPU/GPU FPS distinction, thermal notes and real touch outcomes.
CI fixtures, UA strings and Chromium emulation cannot satisfy that requirement.
