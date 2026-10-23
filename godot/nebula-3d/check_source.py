#!/usr/bin/env python3
"""Source-structure guard for NEBULA R5. Native engine tests follow this check."""
from pathlib import Path
import base64
import json

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
    'preload("res://scripts/ship_finish_r7.gd")',
    'finish_r7.name = "R7_PBRSurfaceFinish"',
    'preload("res://assets/models/nx08_interceptor_r8.gltf")',
    'imported_r8.name = "R8_ImportedHeroMesh"',
    'preload("res://scripts/ship_mechanics_r9.gd")',
    'mechanisms_r9.name = "R9_AnimatedAirframeMechanics"',
    'SurfaceLibraryR9Script.coat(',
)
world = require(
    "scripts/world.gd",
    "const MISSIONS",
    "const SAVE_PATH",
    'preload("res://scripts/city_set_dressing_r5.gd")',
    "detail_r5.build(tower_data, SECTOR_POSITIONS)",
    'preload("res://scripts/orbital_docks_r6.gd")',
    "docks_r6.build(SECTOR_POSITIONS, SECTOR_COLORS)",
    'preload("res://scripts/sculptural_skyline_r6.gd")',
    "skyline_r6.build(SECTOR_POSITIONS, SECTOR_COLORS)",
    'preload("res://scripts/capital_fleet_r7.gd")',
    "fleet_r7.build(SECTOR_POSITIONS)",
    'preload("res://scripts/orbital_industry_r9.gd")',
    "industry_r9.build(SECTOR_POSITIONS)",
    'preload("res://scripts/aegis_megadock_r10.gd")',
    "aegis_r10.build(SECTOR_POSITIONS)",
    'preload("res://scripts/city_cladding_r10.gd")',
    "city_cladding_r10.build(tower_data, SECTOR_POSITIONS)",
    "func _set_graphics_quality(",
    'preload("res://scripts/industrial_environment_r11.gd")',
    'preload("res://scripts/cinematic_post_r11.gd")',
    'preload("res://scripts/performance_lab_r11.gd")',
    "industrial_r11.build(SECTOR_POSITIONS)",
    "performance_lab_r11.start_benchmark()",
    "performance_lab_r11.copy_report()",
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
    'preload("res://assets/models/industrial_hangar_r8.gltf")',
    'imported_r8.name = "R8_IndustrialHangarAsset"',
    "roof_node.visibility_range_begin = 370.0",
    'SurfaceLibraryR9Script.coat(',
)
assert "st.generate_tangents()" in r6_ship
assert "st.generate_tangents()" in r6_docks
skyline = require(
    "scripts/sculptural_skyline_r6.gd",
    "func _body_mesh(",
    "func _window_atlas(",
    "R6_ArcologyExteriorMullions",
    "st.generate_tangents()",
)

fleet_r7 = require(
    "scripts/capital_fleet_r7.gd",
    "func _loft_hull(",
    "func _create_hull_pbr(",
    "func _carriers_bridge(",
    "R7_RailgunBattery",
    "st.generate_tangents()",
)
surface_r7 = require(
    "scripts/ship_finish_r7.gd",
    "func _create_painted_alloy(",
    "func _engine_heat_shielding(",
    "R7_ThrusterCoolingBlades",
    "R7_WingSerial",
)
assert "Image.create(512, 512" in fleet_r7
assert "Image.create(256, 256" in surface_r7

def check_gltf(path: str, min_vertices: int, min_materials: int) -> None:
    asset = json.loads((BASE / path).read_text(encoding="utf-8"))
    assert asset.get("asset", {}).get("version") == "2.0", path
    assert len(asset["materials"]) >= min_materials, path
    uri = asset["buffers"][0]["uri"]
    assert uri.startswith("data:application/octet-stream;base64,"), path
    actual = base64.b64decode(uri.split(",", 1)[1], validate=True)
    assert len(actual) == asset["buffers"][0]["byteLength"], path
    vertex_total = 0
    for mesh in asset["meshes"]:
        for primitive in mesh["primitives"]:
            attribs = primitive["attributes"]
            assert "NORMAL" in attribs and "TEXCOORD_0" in attribs
            vertex_total += asset["accessors"][attribs["POSITION"]]["count"]
    assert vertex_total >= min_vertices, (path, vertex_total)


check_gltf("assets/models/nx08_interceptor_r8.gltf", 14000, 7)
check_gltf("assets/models/industrial_hangar_r8.gltf", 25000, 6)
check_gltf("assets/models/aegis_megadock_r10.gltf", 60000, 7)


pbr_r9 = require(
    "scripts/surface_library_r9.gd",
    "static func _atlas(",
    "static func coat(",
    "static func maps(",
    "mat.roughness_texture_channel",
    "mat.metallic_texture_channel",
    "mat.ao_texture_channel",
)
industry_r9 = require(
    "scripts/orbital_industry_r9.gd",
    "func _lathe_vessel(",
    "func _make_mobile_loader(",
    "func build(centers: Array)",
    "R9_PBRPressureSilos_24",
    "SurfaceLibraryR9Script.coat(",
)
mechanics_r9 = require(
    "scripts/ship_mechanics_r9.gd",
    "func _landing_gear(",
    "func _animated_elevons(",
    "func _engine_iris(",
    "gear_requested",
)
r10_port = require(
    "scripts/aegis_megadock_r10.gd",
    "func _make_gate(",
    "func _make_loader(",
    "func set_quality(",
    "QUALITY_RANGES",
    "R10_BatchedTaxiwayMarkings",
    'preload("res://assets/models/aegis_megadock_r10.gltf")',
)
assert "SurfaceLibraryR9Script.coat(" in r10_port
r10_cladding = require(
    "scripts/city_cladding_r10.gd",
    "func build(tower_data: Array[Dictionary], centres: Array)",
    "func set_quality(",
    "R10_D%02d_DeepArchitecturalWindowBays",
    "SurfaceLibraryR9Script.coat(",
)
assert "QUALITY_RANGES" in r10_cladding
studio_r11 = require(
    "scripts/material_studio_r11.gd",
    "static func make_weathered_deck(",
    "Image.create(SIZE, SIZE",
    "material.ao_texture_channel",
    "material.roughness_texture_channel",
    "material.metallic_texture_channel",
)
industrial_r11 = require(
    "scripts/industrial_environment_r11.gd",
    "func _sculpted_landing_deck(",
    "func _make_gantry(",
    "func _make_cart(",
    "func set_quality(",
    "R11_D%02d_RivetAndBoltGrid",
)
post_r11 = require(
    "scripts/cinematic_post_r11.gd",
    "hint_screen_texture",
    "SCREEN_PIXEL_SIZE",
    "R11_FullscreenFilmGrade",
    "func set_quality(",
)
performance_r11 = require(
    "scripts/performance_lab_r11.gd",
    "Performance.TIME_FPS",
    "RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME",
    "NEBULA_R11_BENCHMARK_JSON:",
    "one_percent_low_fps",
    "p95_frame_ms",
    "p99_frame_ms",
    "user://nebula_r11_hardware_benchmark.json",
)
assert "MAX_SAMPLES" in performance_r11 and "WARMUP_SECONDS" in performance_r11
require("docs/R11-HARDWARE-BENCHMARK.md", "F7", "F9", "не является")
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
    "R6 sculptural skyline missing",
    "R7 monumental capital fleet missing",
    "R7 physical PBR surface details missing",
    "Importable R8 interceptor glTF missing",
    "R8 imported curved hangar geometry missing",
    "R9 physically packed ship textures missing",
    "R9 industrial spaceport absent",
    "R9 animated ship mechanics not instantiated",
    "R10 hero megadock parent absent",
    "R10 maximum quality was not restored",
    "R10 detailed city window facades missing",
    "R11 industrial hero environment absent",
    "R11 true multichannel physically based deck material incomplete",
    "R11 compatibility cinematic postprocess absent",
    "R11 live hardware profiler panel missing",
    "R11 performance telemetry is incorrectly fabricated at startup",
    "R11 low-GPU profile failed to disable heavy postprocess",
    "NEBULA_SMOKE_SUCCESS",
)
assert 'ship.position = Vector3(0,19,78)' in world, "Ship spawn must use a local transform before entering the tree"
assert 'ship.global_position = Vector3(0,19,78)\n    add_child(ship)' not in world, "Illegal pre-tree global transform on Godot Node3D"
assert "func _make_ship(" not in ship, "R3 low-poly ship builder is still active"
assert ship_visual.count("engine_flames.append(") == 1
assert "for x in [-1.24, 0.0, 1.24]:" in ship_visual, "three engine array missing"
assert "image.generate_mipmaps()" in ship_visual
assert premium.count("Image.create(") >= 2, "separate facade albedo/emission atlases missing"
assert "high-detail" not in project.lower(), "project identity may remain stable"
assert len(smoke) > 1500 and len(city) > 5000 and len(world) > 10000
print("NEBULA_R11_SOURCE_SUCCESS: cinematic GPU-safe renderer, industrial assets and real-device telemetry contract")
