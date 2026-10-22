# OSGARD EMPIRE Ω — ORIGINAL GODOT SOURCE v0.22

This directory is imported directly from the developer's v0.22 FULL_SOURCE archive.
It contains the real Godot 4.x city game, not the prior standalone HTML strategy or custom WebGL mockup.

Start project: `godot --path godot/empire-omega --editor` (Godot 4.4.1).
Input: WASD, E in/out vehicle, Space parking brake, F interactions, T trial, Tab governance, F5 save, F9 load.

Audio assets are deterministic, original synthesized PCM and are regenerated from
`tools/generate_audio.py` + `tools/generate_patrol_audio.py` during CI.

Native CI and Web export: `.github/workflows/omega-godot-web.yml`.
The Godot source currently has only portable preflight coverage locally;
public Web deployment must pass real Godot import, native smoke and export checks.
The original WebGL experiment at `/games/omega-3d-preview/` will be replaced
only after a successful native workflow run.
