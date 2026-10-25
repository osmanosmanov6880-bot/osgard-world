# OSGARD R135 W11 — controlled release completion

## Verified gameplay, not invented hardware data

R135 is a Godot 4.4.1 WebGL 2 industrial service-training simulation with a maintenance mission, three diagnostic faults, and local score persistence. There is no connected physical equipment telemetry. W11 improves the dark optical inspection and caption. It must keep both original HERO/ECO GLBs, all eight touch controls and safety interlocks.

Never label SwiftShader Chromium tests as physical phone FPS, thermals or AAA photorealism. Physical tests remain independently necessary. Android Chrome evidence capture was merged via PR #341; that instrument does not itself prove hardware measurements.

## Independent immutable publication steps

The live W6.4 is a known-good package pinned to source SHA:
947b4627080636543ae5e873b88b50e61f13beb4
and manifest SHA-256:
0638f1ad5c0ab26d2d112e63bd1759923e5401a85ad4f2cedd450bbb7def2f61.
Never overwrite the W6 package.

1. The final W11 game-source SHA must pass the entire optimized-web candidate CI: real Godot native mission, desktop and simulated-Pixel Chromium WebGL, W11 real screenshot luminance, SHA-256 of ZIP contents, genuine WASM compression, and Nginx HTTP 206 PCK range.
2. Download only the successful exact run artifact, inspect untouched original screenshots with human eyes for 3D machine visibility, caption placement and unobstructed controls, and independently compute the manifest/ZIP hashes. Reject any screenshot with hidden caption, blocked machine view or invented pixels.
3. Fill scripts/r135-w11-release-pin.json with reviewed candidate source_commit, manifest_sha256, archive_sha256, artifact_run_id, release_tag, software_only flag and explicit reviewed_desktop/reviewed_portrait approval. Reject placeholder hashes or an unreviewed build.
4. Push that pin JSON to the isolated release branch. The r135-w11-artifact-gate workflow verifies upstream success and exact SHA, member digests, real PNG provenance, brightness, visible 3D optical caption and real Nginx gzip/PCK 206 responses.
5. A successful release gate preserves the exact ZIP and JSON as immutable GitHub Release tag r135-web-legibility-w11-20261025. It downloads them again and verifies both original SHA-256 hashes before making the draft public. The gate never touches production SSH.
6. In a separate protected promotion PR, update deploy-frontend.yml to download that exact permanent release rather than a floating Actions artifact; stage the files with the explicit reviewed W11 pin; align public smoke expected version/SHA/digest and catalog copy with the verified release.
7. Only after the promotion gate, full platform validation, and production safety checks, merge the promotion PR; verify exact published public bytes, runnable WebGL game and all adjacent game routes via SSH deploy logs. On any failed verification, rollback or keep known-good W6.4.
8. Collect real Android and iPhone gameplay, FPS, touch and thermal measurements independently if the product is to be called device-certified. No performance estimate is a substitute for an actual test.

## Security and compatibility contracts

- The optional W11 release pin changes staging only when explicitly provided. Without a pin, the previous W6.4 SHA/version/source remain the defaults.
- A successful standalone candidate build does not authorize public deployment or an AAA label.
- The visual proof rejects manipulated PNG hash, invalid viewport/DPR geometry, fake fault active state, unsupported capture method or a missing live Godot canvas.
- SHA-256 values are digests and integrity assertions, not cryptographic signatures or proof of individual authorship.
- Physical hardware and unaudited future graphics quality are outside the software-emulation verification scope.

## Rollback

Keep the immutable W6.4 archive and its source/manifest identifiers unchanged. Existing atomic SSH frontend activation and recovery mechanisms remain the only authorized production rollback path. Never silently replace the known-good W6.4 with a failed W11 build.
