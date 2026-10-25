# OSGARD R135 W18 — long-term source and evidence archive

This is an independently verified **software WebGL** archive, not a public production release or physical Android/iPhone certification.

- Real Godot source: `5971112ef861afc257aeb0e054550c158c260b6a`; version `r135-premium-learning-w18-candidate-20261025`.
- Exact original Actions run: `40195425893`; artifact `12599976887`.
- Independently accepted binary and 11 original Chromium frames: Actions `40196880515`, both jobs success.
- Original Godot ZIP SHA-256: `518e9aba3e73368eda44bc06d6e80211bd2ae062a21a6a5fecb16cf1e32cca4b`.
- Manifest SHA-256: `9ba804724a840439871fe4de5e287058673d6f0ec974151ffdaee071500b3af1`.
- Original screenshot SHA values and explicit false physical GPU claim are in `scripts/r135-w18-release-pin.json`.

Workflow `.github/workflows/r135-w18-permanent-archive.yml` accepts only the exact reviewed Actions build and independent promotion gate, downloads the original files, validates the original 11 PNGs and all 8 Godot WebGL components, then uploads the original software ZIP, manifest and an original-evidence ZIP to GitHub Release. It re-downloads and re-verifies the release assets before publishing the release. It never overwrites an existing release.

Target GitHub tag: `r135-premium-learning-w18-reviewed-archive-20261025`. GitHub releases are not inherently immutable: every later recovery **must compare the downloaded bytes with the independently pinned SHA-256**. The protected production channel stays W14 until a separately approved W18 selector and successful SSH/live HTTPS acceptance. The established W14 rollback tag is `r135-case-progress-w14-verified-rollback-20261025`.

Physical Android Chrome/iPhone Safari FPS, thermal results and independent accessibility/AAA photorealism assessments remain **HOLD / NOT CERTIFIED**.
