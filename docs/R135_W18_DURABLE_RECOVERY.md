# OSGARD R135 W18 — verified long-term artifact recovery

## Purpose
Prevent the real WebGL W18 public channel from becoming undeployable when GitHub Actions retires the original run artifact. This is a **post-publication durability improvement**, not another claim of a live W18 deployment.

## Trust boundaries (fail closed)
1. The published selector `scripts/r135-active-release.json` must still choose W18 with reviewed independent gate `40196880515`; the production deploy verifies this gate includes an actual successful `independently-accept-real-candidate` job and that its W18 source pin has identical bytes to current master.
2. The original game build must remain source `5971112ef861afc257aeb0e054550c158c260b6a`, run `40195425893`, artifact ID `12599976887`, version `r135-premium-learning-w18-candidate-20261025`. The game binary SHA remains `518e9aba3e73368eda44bc06d6e80211bd2ae062a21a6a5fecb16cf1e32cca4b` and manifest SHA remains `9ba804724a840439871fe4de5e287058673d6f0ec974151ffdaee071500b3af1`.
3. If that original Actions artifact remains available, the deploy retains the proven Actions download path. If it expires, fallback is **only** the explicitly named previously reviewed GitHub Release `r135-premium-learning-w18-reviewed-archive-20261025`; no web scraping, mutable "latest" or recovery from the live server.
4. Before even downloading release assets, verify release published/draft=false and its GitHub-reported original binary and manifest SHA digests and sizes. Download game ZIP, manifest, and original-evidence ZIP only to GitHub runner temp. Never stage unverified bytes in production.
5. `scripts/r135-w18-evidence-member-pin.json` independently pins **all 18 original source files** (the 11 PNGs, other real captures and all native/browser reports). `scripts/r135-w18-release-recover.py` refuses unknown member names, symlinks, path traversal, duplicate/oversized entries, invalid member sizes, wrong origin or modified bytes, and extracts into isolated runner temp only after every byte is validated.
6. Re-run the existing `scripts/r135-w18-promotion-qa.py` full 11-PNG CRC check, game ZIP 8-file SHA and full three-fault reports, then `r135-release-stage.py`; afterward the existing protected Nginx gzip WASM/206 PCK, SSH atomic rollback and exact public HTTPS acceptance are unchanged.

## Verification required before merge
- The separate `.github/workflows/r135-w18-release-recovery-qa.yml` must successfully execute synthetic negative tests and original artifact source-roundtrip on a fresh runner.
- PR #438 must have finished creating **all three durable source assets**, and actual GitHub Release metadata and original SHA must be independently checked.
- The currently queued W18 public protected deploy must have a success and exact external HTTPS provenance check; **do not merge this change to master while that deploy is pending**.
- Retain W14 permanent source archive with immutable SHA check; do not widen rollback to unsigned files.

## Remaining limitations
Physical Android Chrome/iPhone Safari (FPS, touch and thermals), independent WCAG and AAA photorealism remain unverified. GitHub Actions run/gate metadata can also be subject to finite retention. This fallback protects against *artifact expiration*, not deletion of every upstream trust record; longer-term fully offline signed release attestation would be a separate audited change.