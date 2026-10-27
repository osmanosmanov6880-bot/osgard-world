# IRON PULSE — naming migration (review only)

Approved public-facing game title: **IRON PULSE**. Previous identity: OSGARD / OBSIDIAN PROTOCOL.

This isolated branch is based on immutable 9/9-software-accepted W58 source `ef570cf6c406cc14ec180585ee2c5d64c667c658`.

Scope: Godot application title and description; native desktop/mobile visible HUD branding, footer and accessible status. **Internal** OSGARD class names, scripts, CI labels, repository slug, historical release archives and evidence are deliberately retained as compatibility/provenance identifiers. No mechanical/mission/physics changes.

## Release identity policy
- Display/store-facing name: IRON PULSE.
- Original W57/W58 builds and SHA manifests remain immutable under their original historical names.
- Future preview release should use IRON_PULSE in *new* archive filenames and visible release notes, with a compatibility note `formerly OSGARD / OBSIDIAN PROTOCOL`. Do not rename/rewrite existing signed-like checksums or pretend old binaries carry new text.
- Generate and test a new exact-source Godot Windows/WebGL export before saying the new title appears in downloadable binaries.
- Rerun native Godot + all six missions, 320/390/1366px RU/EN, original W49 protected-source gate, and full 9/9 W42/W52 source-bound CI for the resulting reviewed/merged SHA. Existing W58 green evidence does **not** transfer to this branding commit.
- Keep production HOLD: real hardware, human visual approval, upstream review, rollback and owner GO missing.

**No master merge, no existing GitHub release asset rewrite, no live website/VPS/CDN/DNS deployment.**