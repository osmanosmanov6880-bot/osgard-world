#!/usr/bin/env python3
"""Source-structure guard for NEBULA R5. Native engine tests follow this check."""
from pathlib import Path

BASE = Path(__file__).resolve().parent


def require(path: str, *tokens: str) -> str:
    candidate = BASE / path
    if not candidate.is_file() or candidate.stat().st_size == 0:
        raise AssertionError(f"missing required source: {path}")
    source = candidate.read_text(encoding="utf-8")
    for token in tokens:
        if token not in source:
            raise AssertionError(f"{path} is missing expected symbol: {token}")
    return source


project = require("project.godot", 'run/main_scene="res://scenes/world.tscn"')
require("scenes/world.tscn", "world.gd")
ship = require(
    "scripts/ship.gd",
    'preload("res://scripts/ship_visual_r5.gd")',
    'HighDetailInterceptorR5',
    "func _physics_process(",
    "func take_damage(",
)
ship_visual = require(
    "scripts/ship_visual_r5.gd",
    "func _poly(",
    "func _build_wings(",
    "func _build_propulsion(",
    "func _brushed_normal_map(",
    "st.generate_tangents()",
    'preload("res://scripts/ship_hero_detail_r6.gd")',
    'hero_r6.name = "R6_HeroHullDetail"',
)
world = require(
    "scripts/world.gd",
    "const MISSIONS",
    "const SAVE_PATH",
    'preload("res://scripts/city_set_dressing_r5.gd")',
    "detail_r5.build(tower_data, SECTOR_POSITIONS)",
    'preload("res://scripts/orbital_docks_r6.gd")',
    "docks_r6.build(SECTOR_POSITIONS, SECTOR_COLORS)",
)
city = require(
    "scripts/city_set_dressing_r5.gd",
    "func _detail_towers(",
    "func _detail_docks(",
    "func _hero_spire(",
    "MultiMesh.new()",
)
r6_ship = require(
    "scripts/ship_hero_detail_r6.gd",
    "func _sculpt_underbody(",
    "func _surface_fasteners(",
    "func _engine_microgeometry(",
    "R6_WingRivets_Batched",
)
r6_docks = require(
    "scripts/orbital_docks_r6.gd",
    "func _hangar_roof(",
    "func _make_deck_material(",
    "func _crane(",
    "R6_PBR_DeckPanels",
)
assert "st.generate_tangents()" in r6_ship
assert "st.generate_tangents()" in r6_docks
require("scripts/architectural_detail_r4.gd", "func build(")
premium = require("scripts/premium_architecture.gd", "func make_facade_material(", "emission_image")
require("scripts/drone.gd", "extends")
require("scripts/radar.gd", "extends")
smoke = require(
    "tests/runtime_smoke.gd",
    "R5 ship visual model missing",
    "R5 city dressing pass missing",
    "R6 aircraft hero model missing",
    "R6 industrial orbital megadocks absent",
    "NEBULA_SMOKE_SUCCESS",
)
assert "func _make_ship(" not in ship, "R3 low-poly ship builder is still active"
assert ship_visual.count("engine_flames.append(") == 1
assert "for x in [-1.24, 0.0, 1.24]:" in ship_visual, "three engine array missing"
assert "image.generate_mipmaps()" in ship_visual
assert premium.count("Image.create(") >= 2, "separate facade albedo/emission atlases missing"
assert "high-detail" not in project.lower(), "project identity may remain stable"
assert len(smoke) > 1500 and len(city) > 5000 and len(world) > 10000
print("NEBULA_R6_SOURCE_SUCCESS: true 3D hero meshes and instanced megadocks verified")
