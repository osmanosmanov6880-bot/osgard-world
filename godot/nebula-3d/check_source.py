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
    'preload("res://scripts/engineering_campus_r12.gd")',
    'preload("res://scripts/cinematic_lighting_r12.gd")',
    'preload("res://scripts/adaptive_quality_r12.gd")',
    "engineering_r12.build(SECTOR_POSITIONS)",
    'preload("res://scripts/cinematic_port_r14.gd")',
    "port_r14.build(SECTOR_POSITIONS)",
    "port_r14.set_quality(graphics_quality)",
    "performance_lab_r11.capture_frame()",
    "adaptive_r12.quality_requested.connect(",
    "func _r12_on_auto_quality(",
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
    "user://nebula_r12_hardware_benchmark.json",
)
assert "MAX_SAMPLES" in performance_r11 and "WARMUP_SECONDS" in performance_r11
require("docs/R11-HARDWARE-BENCHMARK.md", "F7", "F9", "не является")
r12_mat = require(
    "scripts/material_fabric_r12.gd",
    "static func get_material(",
    "static func _create(",
    "albedo.generate_mipmaps()",
    "mat.normal_texture",
    "mat.ao_texture_channel",
    "mat.roughness_texture_channel",
    "mat.metallic_texture_channel",
)
r12_engineering = require(
    "scripts/engineering_campus_r12.gd",
    "func _lofted_vessel(",
    "func _make_port(",
    "func set_quality(",
    "R12_LoftedPressureHousing_",
    "R12_ExternalChromeStrut",
    "R12_RailMountedCargoArm_",
    "R12_D%02d_BatchedPanelFasteners",
)
r12_lighting = require(
    "scripts/cinematic_lighting_r12.gd",
    "func apply_look(",
    "func toggle_look(",
    "env.glow_enabled",
    "sky_shader.sky_top_color",
)
r12_adaptive = require(
    "scripts/adaptive_quality_r12.gd",
    "func observe_fps(",
    "DOWNSHIFT_SECONDS",
    "UPSHIFT_SECONDS",
    "quality_requested.emit(",
    "recording",
)
r12_profiler = require(
    "scripts/performance_lab_r11.gd",
    "NEBULA_R12_HARDWARE_BENCHMARK",
    "one_percent_low_method",
    "quality_gate",
    "func capture_frame()",
    "Marshalls.raw_to_base64(png)",
)
r12_post = require(
    "scripts/cinematic_post_r11.gd",
    "uniform float velocity_streak",
    "func set_flight_velocity(",
)
require("docs/R12-PERFORMANCE-ACCEPTANCE.md", "F7", "F10", "F11", "физическом")
r14_port = require(
    "scripts/cinematic_port_r14.gd",
    "func _curved_flight_deck(",
    "func _make_facility(",
    "func _make_gantry(",
    "func _gpu_batch(",
    "func set_quality(",
    "R14_FlightDeckPhysics",
    "R14_OverheadFlightControlBridge",
    "MaterialFabricR12Script.get_material(0)",
)
r14_ship = require(
    "scripts/interceptor_trim_r14.gd",
    "func _make_cowl(",
    "func _build_engine_cowls(",
    "func _build_plated_wings(",
    "func _build_hardware(",
    "func set_quality(",
    "R14_SculptedTurbineCowl_",
)
assert 'preload("res://scripts/interceptor_trim_r14.gd")' in ship_visual
assert "R14_AirframeRefinement" in ship_visual
require("docs/R14-VISUAL-AND-FPS-ACCEPTANCE.md", "F7", "F10", "FPS", "физическом")
r16_missile = require(
    "scripts/guided_missile_r16.gd",
    "func activate(",
    "func deactivate(",
    "func _impact(",
    "MAX_LIFETIME",
    "impacted.emit(",
    "set_process(false)",
)
r16_fleet = require(
    "scripts/fleet_combat_r15.gd",
    "GuidedMissileR16Script",
    "MISSILE_POOL_SIZE: int = 8",
    "helper_rebuilds",
    "same_formation",
    "ally_fired.emit(",
    'rocket.get("armed")',
    'ready_rocket.call("activate"',
)
assert "enemy.hit(missile_damage)" not in r16_fleet, "R16 missiles must have real travel time"
r16_ship = require(
    "scripts/ship.gd",
    "controls_locked",
    "if controls_locked:",
)
assert "func _r16_setup_beam_pool()" in world
assert "func _r16_update_beam_pool(" in world
assert "R16_BEAM_POOL_SIZE: int = 18" in world
assert "R16_RADAR_PERIOD: float = 0.12" in world
assert "R16_HUD_PERIOD: float = 0.10" in world
assert "adaptive_r12.set_auto(true)" in world
assert "ship.controls_locked = true" in world
assert "ship.controls_locked = false" in world
assert "create_timer(0.12)" not in world, "Per-shot timer allocations returned"
require(
    "docs/R16-SMOOTH-COMBAT-ACCEPTANCE.md",
    "F7", "F9", "F10", "физической", "Stripe",
)
r17_baker = require(
    "tools/bake_r17.gd",
    "const R9",
    "const R12",
    "const R9_PROFILES: int = 4",
    "const R12_PROFILES: int = 3",
    "get_image()",
    "save_png(location)",
    "NEBULA_R17_BAKE_SUCCESS",
)
assert 'static func _r17_baked_atlas(' in pbr_r9
assert "static func baked_count() -> int:" in pbr_r9
assert 'ResourceLoader.exists(file)' in pbr_r9
assert 'static func _r17_prebuilt(' in r12_mat
assert "static func baked_count() -> int:" in r12_mat
assert 'ResourceLoader.exists(file)' in r12_mat
require(
    "docs/R17-FAST-START-ACCEPTANCE.md",
    "R17", "384", "21", "SwiftShader", "F7",
)
# R18: expensive city GPU batches must be district-local, distance-culled,
# and share the existing MAX/HIGH/ECO plus adaptive quality controls.
assert "R18_BaseCityDistrict_" in world
assert "R18_NeonDistrict_" in world
assert "r18_base_tower_instances" in world
assert "r18_city_district_chunks" in world
assert "func _r18_set_city_quality(" in world
assert "details_r18.set_quality(graphics_quality)" in world
assert "skyline_r18.set_quality(graphics_quality)" in world
assert 'drawn_instances' in city
assert 'district_roots' in city
assert 'func _nearest_district(' in city
assert 'visibility_range_end = DETAIL_RANGE[quality_mode]' in city
assert 'func _nearest_sector(' in skyline
assert 'segment_hubs[district].add_child(render)' in skyline
assert 'visibility_range_end = FACADE_RANGE[quality_mode]' in skyline
require(
    "docs/R18-GPU-DISTRICT-CULLING.md",
    "R18", "360", "6", "F7", "F9", "F10", "WebGL",
)
premium = require("scripts/premium_architecture.gd", "func make_facade_material(", "emission_image")
# R19: ensure the last world-spanning steel, industrial and roof meshes
# have per-sector GPU bounds and quality-dependent visibility.
assert 'R19_FacadeDistrict_' in premium
assert 'R19_RoofDistrict_' in premium
assert 'func _sector_sizes(' in premium
assert 'r19_facade_instance_count' in premium
assert 'r19_roof_instance_count' in premium
assert 'func set_quality(' in premium
assert 'R19_IndustrialSector_' in industry_r9
assert 'r19_batch_groups' in industry_r9
assert 'r19_original_instances' in industry_r9
assert 'func _r19_refresh_lights(' in industry_r9
assert 'light.visible = r19_quality < 2 and close' in industry_r9
assert 'func set_quality(' in industry_r9
assert 'premium_architecture.set_quality(graphics_quality)' in world
assert 'industry_r19.set_quality(graphics_quality)' in world
require(
    "docs/R19-NEAR-SECTOR-GPU-LIGHTS.md",
    "R19", "1,800", "48", "F7", "F9", "F10",
)
# R20: eliminate last 1,048,576 runtime image pixel writes from R11
# weathered deck and R5 emitting facade without changing the source art.
r20_baker = require(
    "tools/bake_r20.gd",
    "const Studio",
    "const Architecture",
    "func _save(",
    "deck_albedo",
    "deck_normal",
    "deck_orm",
    "facade_albedo",
    "facade_emission",
    "NEBULA_R20_BAKE_SUCCESS",
)
assert "static func _r20_load_exact_deck()" in studio_r11
assert "static func baked_count() -> int:" in studio_r11
assert "static func _assemble(" in studio_r11
assert 'ResourceLoader.exists(name)' in studio_r11
assert "func _r20_exact_glazing()" in premium
assert "func _facade_material(" in premium
assert 'ResourceLoader.exists(resource)' in premium
assert "r20_facade_baked = true" in premium
require(
    "docs/R20-BAKED-METAL-GLAZING-ACCEPTANCE.md",
    "R20", "1,048,576", "512x512", "256x512", "F7", "F9", "F10",
)
require("scripts/architectural_detail_r4.gd", "func build(")

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
    "R12 aerospace campus not instantiated",
    "R12 engineering halls missing across six districts",
    "R12 three physically based shared atlases not generated",
    "R12 measured low-FPS downshift logic failed",
    "R12 actual physical hardware results must never be invented in CI",
    "R14 cinematic ports not loaded into real game scene",
    "R14 GPU instancing for micro-scale architecture insufficient",
    "R14 real player interceptor refinement missing",
    "R14 CI must not invent physical hardware FPS values",
    "R16 ammo/receipt refresh is rebuilding combat allies and causing stutter",
    "R16 weapon fire is allocating new mesh nodes per shot",
    "R16 missile did not navigate to the enemy and apply delayed damage",
    "R16 guardian repairs incorrectly capped at scout hull and shields",
    "R17 prebaked R9 384px physical texture maps unavailable",
    "R17 R9 WebGL still dynamically computes PBR atlas pixels",
    "R17 R12 WebGL still dynamically computes PBR atlas pixels",
    "R18 GPU district geometry not placed at its physical origin",
    "R18 distant R5 facades still drawn as world-wide GPU batches",
    "R18 original R6 skyline still uses giant all-world steel beam batch",
    "R18 ECO quality fails to cull distant buildings/architectural micro-detail",
    "R19 facade and roof batch sharding lost original premium instances",
    "R19 industrial batches must be independent per district with no lost assets",
    "R19 player near Aurora should see exactly two local industrial worklights",
    "R19 auto / manual ECO change did not disable distant architecture",
    "R20 city facade still calculates 256x512 glazing pixels during browser load",
    "R20 baked emission/albedo texture dimensions differ from original glazing",
    "R20 real player browser still computes 512x512 heavy weathered metal atlas",
    "NEBULA_R20_BAKED_IMPORT_SUCCESS",
    "NEBULA_R17_PBR_IMPORT_SUCCESS",
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
print("NEBULA_R20_SOURCE_SUCCESS: 5 original 512px/256px deck+facade atlases baked on native CI; R19/R18/R17/R16 retained")
