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

garage = require(
    "scripts/garage_hub_r39.gd",
    "R39_GarageRoot", "R39_CaptainCard", "R39_MissionCard",
    "R39_SortieButton", "func _layout_hub()", "func refresh(data: Dictionary)",
)
assert "GarageHubR39Script" in world
assert "func _r39_launch_sortie()" in world
assert "garage_hub_r39.visible = false" in world
assert "state[\"garage_sortie_x\"]" in world

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
    "R21 ship still cannot move forward through the playable launch corridor",
    "R21 two-finger phone throttle, joystick and boost cannot be combined",
    "R21 touch release left ship controls stuck",
    "R21 player spawns stuck inside a building; flight cannot start",
    "NEBULA_R21_REAL_FLIGHT_SUCCESS",
    "R22 golden-hour Aurora real PBR buildings/bridges/windows missing",
    "R22 atmospheric scene still lacks actual 3D clouds and moving air traffic",
    "R22 real suspended flightways must have physical collision",
    "R22 mobile ECO must cull distant atmospheric and air-traffic detail",
    "NEBULA_R22_AURORA_SCENE_SUCCESS",
    "R23 real physical W key never moves ship: Cyrillic keyboard still blocked",
    "R23 clicked START FLIGHT but the ship stayed at 000 km/h",
    "R23 landscape controls overlap: phones cannot use gas and weapons",
    "R23 phone START FLIGHT did not engage real physics",
    "R23 engine renders giant white/blue jet cones while ship stands still",
    "NEBULA_R23_REAL_INPUT_SUCCESS",
    "NEBULA_R17_PBR_IMPORT_SUCCESS",
    "NEBULA_SMOKE_SUCCESS",
)
assert 'ship.position = R21_LAUNCH_CANDIDATES[0]' in world, "R21 ship must use safe local transform until added to scene tree"
assert 'ship.global_position = Vector3(0,19,78)\n    add_child(ship)' not in world, "Illegal pre-tree global transform on Godot Node3D"
# R21: test playable flight and matching approved mobile control sources, not
# a static screenshot standing in for actual gameplay.
r21_mobile = require(
    "scripts/mobile_controls_r21.gd",
    "func _set_touch(",
    "func _drag_touch(",
    "func _refresh_inputs(",
    "func force_mobile_for_tests(",
    'set_touch_controls(joystick, forward, height,',
    "finger_roles",
    "rocket_requested.emit()",
    "hangar_requested.emit()",
)
r21_hud = require(
    "scripts/premium_hud_r21.gd",
    "R21_PremiumFlightDashboard",
    "SystemFont.new()",
    "func _gauge(",
    "func _panel(",
    "км/ч",
    "ЩИТ",
    "ФОРСАЖ",
)
r21_web = require(
    "../../scripts/nebula-r21-mobile-export.mjs",
    "viewport-fit=cover",
    "touch-action:none",
    "100dvh",
    "aria-label",
)
assert "func set_touch_controls(" in ship
assert "var collision_impacts: int = 0" in ship
assert "func _pilot_axes()" in ship
assert "move_and_slide()" in ship
assert "PhysicsRayQueryParameters3D.create(target, ideal)" in world
assert "func _r21_rescue_blocked_spawn()" in world
assert "r21_mobile_enabled = r21_touch.enabled" in world
assert "const R21_LAUNCH_CANDIDATES" in world
assert "r21_towers_moved += 1" in world
assert "func _r21_toggle_hangar()" in world
assert "func _r21_launch_missile()" in world
assert "r21_touch.set_shop_open(false)" in world
assert "SystemFont.new()" in world
require(
    "docs/R21-APPROVED-AURORA-MOBILE-FLIGHT.md",
    "37 real physics frames", "Inter", "F7", "F9", "F10", "Android", "iOS",
)
assert "NEBULA_R21_REAL_FLIGHT_SUCCESS" in smoke
assert "37" in smoke and "touch_r21._set_touch(0" in smoke
# R22: the approved user screenshot must become genuine realtime 3D,
# not any generated 2D artwork, frame overlay, backdrop or placeholder card.
r22_city = require(
    "scripts/aurora_scenic_r22.gd",
    "R22_PhysicalAuroraTower_",
    "R22_TowerBody",
    "R22_SuspendedFlightway_",
    "R22_PhysicalFlightway",
    "R22_CloudDeck_",
    "R22_LivingCityTraffic_",
    "func _build_tower(",
    "func _bridges(",
    "func _ambient_traffic(",
    "func _cloud_ribbon(",
    "func set_quality(",
    "real_3d_windows",
    "physical_structures",
    "moving_traffic",
)
r22_ion = require(
    "scripts/engine_cinema_r22.gd",
    "R22_CinematicPropulsion_",
    "R22_NearShipExhaustLight",
    "plume_count",
    "nozzle_parts",
    "ship.thruster_power",
    "func _process(",
)
assert 'preload("res://scripts/aurora_scenic_r22.gd")' in world
assert 'aurora_scenic_r22.build()' in world
assert 'aurora_scenic_r22.set_quality(graphics_quality)' in world
assert 'preload("res://scripts/engine_cinema_r22.gd")' in ship_visual
assert 'exhaust_r22.name = "R22_RealIonDrive"' in ship_visual
assert 'if mission_index > 0 and r21_launch_protection <= 0.0:' in world
assert "sky_shader.sky_horizon_color = Color(0.30, 0.42, 0.60)" in require(
    "scripts/cinematic_lighting_r12.gd")
assert "env.fog_light_color = Color(0.29, 0.37, 0.49)" in require(
    "scripts/cinematic_lighting_r12.gd")
assert 'nebula-r22-keyboard-focus' in r21_web
require(
    "docs/R22-REAL-AURORA-GOLDEN-HOUR.md",
    "18", "2,000", "16", "4", "golden-hour", "F7", "F9", "F10",
)
assert "NEBULA_R22_AURORA_SCENE_SUCCESS" in smoke
assert "R22 golden-hour Aurora real PBR buildings/bridges/windows missing" in smoke
# R23: fixes the user's specific 000 km/h image, not a simulated scene.
assert "func _browser_mask() -> int:" in ship
assert "browser_window = JavaScriptBridge.get_interface(\"window\")" in ship
assert "browser_window.__nebulaPilotMask" in ship
assert "Input.is_physical_key_pressed(code)" in ship
assert "var cruise_assist: bool = false" in ship
assert "func set_cruise_assist(" in ship
assert "last_pilot_throttle" in ship
assert "R23_StartRealFlight" in world
assert 'r23_cruise_button.pressed.connect(_r23_toggle_cruise)' in world
assert "r21_touch.cruise_requested.connect(_r23_toggle_cruise)" in world
assert 'ship.set_cruise_assist(not ship.cruise_assist)' in world
assert "func _layout_for_size(pixels: Vector2) -> void:" in r21_mobile
assert "r23_landscape_layout" in r21_mobile
assert 'cruise_requested.emit()' in r21_mobile
assert "nebula-r23-physical-keyboard" in r21_web
assert "window.__nebulaPilotMask" in r21_web
assert "KeyboardEvent.code" in r21_web
assert "window.addEventListener('blur'" in r21_web
assert 'r23_glazed_hero_towers' in r22_city
assert 'ResourceLoader.exists(albedo_path)' in r22_city
assert 'ResourceLoader.exists(lit_path)' in r22_city
assert "glow_core = _jet_material(Color(0.53,0.82,1.0),0.18,0.25)" in r22_ion
assert "flame.visible = force > 0.07" in r22_ion
require("docs/R23-WASD-PORTRAIT-LANDSCAPE-VISUAL-ACCEPTANCE.md",
    "R23", "physical", "W", "844x390", "390x844", "F7", "F9", "F10")
assert "NEBULA_R23_REAL_INPUT_SUCCESS" in smoke
assert "R23 clicked START FLIGHT but the ship stayed at 000 km/h" in smoke
# R25: live WebAssembly browser pilot testing instead of trusting Godot
# headless physics as proof of user's real keyboard and clickable controls.
r25_browser = require(
    "tests/browser_flight_r25.mjs",
    "__nebulaPilotTelemetry",
    "real Godot runtime initialized",
    "physical W drives real ship motion",
    "actual clickable cruise switch engaged",
    "real autopilot rotates ship toward off-axis mission",
    "real ship approaches mission objective in world units",
    "NEBULA_R25_BROWSER_FLIGHT_SUCCESS",
    "flight.json",
)
r25_workflow = require(
    "../../.github/workflows/nebula-r25-real-browser-flight.yml",
    "workflow_run:",
    "REMIX NEBULA 3D native Web release",
    "browser_flight_r25.mjs",
    # Hosted SwiftShader needs a bounded 480-second limit for real physics
    # sampling; never change this to a no-timeout or mock-GPU smoke.
    "timeout 480s",
)
assert "func _r25_emit_browser_flight_state() -> void:" in world
assert 'JavaScriptBridge.eval("window.__nebulaPilotTelemetry = "' in world
assert "var r25_telemetry_samples: int = 0" in world
assert "snappedf(ship.flight_distance, 0.01)" in world
assert "r11_capture_enabled" in world
# R30: input lifecycle events should cancel active movement, not keep a ghost finger.
assert "func _clear_active_touches()" in r21_mobile
assert "NOTIFICATION_APPLICATION_FOCUS_OUT" in r21_mobile
assert "changed_orientation" in r21_mobile
assert "r21_touch.ui_font = r21_ui_font" in world
assert "R30 focus loss must release held mobile thrust and boost" in smoke
assert "R30 hangar must clear mobile touch counters and throttle" in smoke
assert "R30 orientation change must cancel stale touch controls" in smoke
# R31: a visible touch UI alone is not sufficient evidence of actual movement.
r31_mobile = require(
    "tests/browser_mobile_r31.mjs",
    "Input.dispatchTouchEvent",
    "real browser touch activates throttle",
    "mobile throttle moves actual ship",
    "real two-finger throttle and boost",
    "landscape physical touch activates ship throttle",
    "multitouch release never sticks boost",
    "NEBULA_R31_MOBILE_TOUCH_SUCCESS",
)
# R32: prevent reintroducing portrait overlap on compact landscape phones.
assert "w > h and usable_w >= 335.0" in r21_mobile
assert "R32 compact landscape must distinguish GAS from CRUISE" in smoke
assert "R32 compact landscape action hit targets overlap" in smoke
assert "R32 small-landscape GAS accidentally triggers autopilot" in smoke
assert "r31_mobile_qa_enabled" in world
# Mobile QA must prove browser touches, layout and engine events separately.
assert "content_scale_size = css_size" in world
assert "r31_mobile_css_size" in world
assert "r31_raw_touch_events" in r21_mobile
# Hosted mobile CI must not silently change real-player graphics or physics.
assert "func _r33_trim_nonessential_qa_meshes(node: Node)" in world
assert "if r31_mobile_qa_enabled:" in world
assert "r33_swiftshader_qa_visuals_trimmed = true" in world
assert "if node == ship or node is CanvasLayer:" in world
assert 'state["qa_visuals_trimmed"] = r33_swiftshader_qa_visuals_trimmed' in world
assert "state.qa_visuals_trimmed === true" in r31_mobile
# R34: actual canvas-finger source, not fake engine input or synthetic motion.
r34_js = require(
    "../../scripts/nebula-r21-mobile-export.mjs",
    "nebula-r34-touch-bridge",
    "__nebulaDomTouchState",
    "touchcancel",
    "touchstart",
    "touchmove",
    "touchend",
    "window.addEventListener('blur'",
)
r34_dom_tests = require(
    "../../scripts/test-nebula-r34-dom-touch.mjs",
    "NEBULA_R34_DOM_TOUCH_SOURCE_SUCCESS",
    "both independent fingers remain held",
    "OS touchcancel clears held controls",
)
assert "r34_dom_bridge_active" in r21_mobile
assert "func _r34_poll_browser_contacts()" in r21_mobile
assert "r34_ignore_until_all_released" in r21_mobile
assert "func _r34_gate_stale_contacts(points: Array)" in r21_mobile
assert "R34 finger-free hangar close must allow the next independent tap" in smoke
assert "R34 browser touch bridge remains blocked after hangar release" in smoke
# R35: real CSS env() safe areas + 9 reachable controls across compact phones.
r35_probe = require(
    "../../scripts/nebula-r21-mobile-export.mjs",
    "nebula-r35-safe-area", "__nebulaSafeArea",
    "env(safe-area-inset-left, 0px)",
    "env(safe-area-inset-top, 0px)",
    "env(safe-area-inset-right, 0px)",
    "env(safe-area-inset-bottom, 0px)",
)
r35_js_test = require(
    "../../scripts/test-nebula-r35-safe-area.mjs",
    "NEBULA_R35_SAFE_AREA_JS_SUCCESS",
    "safe-area probe must register before Godot",
    "landscape cutout must be read from CSS env()",
    "portrait notch and home gesture bar detected",
)
assert "func set_safe_insets(insets: Vector4) -> bool:" in r21_mobile
assert "func _r35_refresh_safe_insets() -> bool:" in r21_mobile
assert "r35_compact_portrait" in r21_mobile
assert 'r21_touch._r35_refresh_safe_insets()' in world
assert 'state["touch_safe_left"] = r21_touch.r35_safe_insets.x' in world
assert "short_landscape: bool" in world
assert "hud_panel.offset_top = safe_top + 8.0" in world
assert "NEBULA_R35_SAFE_AREA_SUCCESS" in smoke
assert "R35 action button is hidden by screen notch/gesture bar" in smoke
assert "R35 two action hit targets overlap" in smoke
assert "R35 short-landscape HUD blocks the hangar touch target" in smoke
assert "compact portrait phone has reachable 3x3 flight controls" in r31_mobile
assert "compact portrait GAS drives real Godot ship" in r31_mobile
assert "compact portrait GAS release prevents ghost thrust" in r31_mobile
assert "actual DOM CSS safe-area probe and reachable GAS" in r31_mobile
# R36: actual smartphone-accessible benchmark + local-only real-device reports.
assert "last_event_ms" in r34_js
assert "performance.now()" in r34_js
assert "R36 real DOM touch timestamp must use monotonic performance.now" in r34_dom_tests
assert "r36_input_poll_latency_total_ms" in r21_mobile
assert "r36_input_poll_samples" in r21_mobile
assert "get_viewport().set_input_as_handled()" not in r21_mobile.split(
    "if r34_dom_bridge_active:", 1)[1].split("return", 1)[0]
assert "func configure_mobile(active: bool, touch_source: Node," in performance_r11
assert "func download_report() -> void:" in performance_r11
assert "R36_MobileFPSLauncher" in performance_r11
assert "R36_StartReal20SecondBenchmark" in performance_r11
assert "r36_browser_dom_to_engine_avg_ms" in performance_r11
assert "r36_touch_delay_scope" in performance_r11
assert "r36_data_policy" in performance_r11
assert "no network, identity or background upload" in performance_r11.lower()
assert "NEBULA_R36_REAL_DEVICE_UI_SUCCESS" in smoke
# R38: all graphic quality profiles must be selectable without keyboard.
assert "signal r38_quality_cycle_requested" in performance_r11
assert "R38_MobileGraphicsProfile" in performance_r11
assert "r38_mode_button.disabled = true" in performance_r11
assert "func _r38_cycle_quality() -> void:" in world
assert 'r38_quality_cycle_requested.connect(_r38_cycle_quality)' in world
assert 'state["r38_quality_mode"] = graphics_quality' in world
assert "NEBULA_R38_MOBILE_QUALITY_SUCCESS" in smoke
assert "R38 graphics preset changed during benchmark" in smoke
assert "R38 mobile quality touch enables real AUTO profile" in r31_mobile
assert "R38 mobile quality touch selects real MAX graphics" in r31_mobile
assert "R36 local performance JSON export was corrupted" in smoke
assert "R36 real mobile FPS button opens performance overlay" in r31_mobile
assert "R36 real mobile 20-second FPS benchmark starts" in r31_mobile
assert 'state["r36_perf_active"] = performance_lab_r11.benchmarking' in world
assert "performance_lab_r11.configure_mobile(" in world
require("docs/R36-REAL-MOBILE-PERFORMANCE-ACCEPTANCE.md",
    "20", "DOM", "Godot", "JSON", "Android", "iOS", "SwiftShader")
assert "if r34_dom_bridge_active:" in r21_mobile
assert 'state["touch_dom_bridge"] = r21_touch.r34_dom_bridge_active' in world
assert "s.touch_dom_bridge === true" in r31_mobile
assert "window.__nebulaDomTouchQA" in r31_mobile
assert "real mobile viewport and physics loop stabilized" in r31_mobile
assert "native browser touch dispatch" in r31_mobile
assert 'state["touch_throttle"] = snappedf(ship.touch_throttle, 0.01)' in world
assert "get_viewport().get_texture().get_image()" in world
assert "window.__nebulaR11CaptureData" in world
assert "URLSearchParams(window.location.search).get('r11-qa')" in world
r11_visual = require(
    "tests/browser_smoke_r11.mjs",
    "Godot viewport capture",
    "nebulaR11CaptureRequestId",
    "Hosted SwiftShader cannot confirm visual frame",
)
assert "r25_side_and_back_windows" in r22_city
assert "_r25_side_window_transform" in r22_city
assert "r25_window_faces" in r22_city
# R26: R25 E2E proved Godot runs in SwiftShader but window-level W input
# was missing. Register physical-key capture before engine JS (not </body>).
assert "const openHead = html.match(/<head[^>]*>/i)" in r21_web
assert "openHead[0] + '\\n' + pilotScript" in r21_web
assert "window.__nebulaKeyDebug" in r21_web
assert "DOM keyboard capture before Godot" in r25_browser
assert "keyInBrowser.mask & 1" in r25_browser
assert "NEBULA_R25_FOUR_FACADES_SUCCESS" in smoke
assert "11064" in smoke and "7837" in smoke
require(
    "docs/R25-BROWSER-FLIGHT-AND-FOUR-FACADE-PBR.md",
    "11,064", "7,837", "Chromium", "SwiftShader", "F7", "F9", "F10",
)
assert "func _make_ship(" not in ship, "R3 low-poly ship builder is still active"
assert ship_visual.count("engine_flames.append(") == 1
assert "for x in [-1.24, 0.0, 1.24]:" in ship_visual, "three engine array missing"
assert "image.generate_mipmaps()" in ship_visual
assert premium.count("Image.create(") >= 2, "separate facade albedo/emission atlases missing"
assert "high-detail" not in project.lower(), "project identity may remain stable"
assert len(smoke) > 1500 and len(city) > 5000 and len(world) > 10000
assert "world.store_r15.close()" in smoke
assert "R39 campaign must open in a locked garage hub" in smoke
# R44: the garage must use a real Godot scene and the SAME imported ship
# geometry as the live player, with isolated physics and explicit input.
r44_preview = require(
    "scripts/hangar_ship_preview_r44.gd",
    "extends SubViewportContainer",
    "res://assets/models/nx08_interceptor_r8.gltf",
    "preview_viewport.own_world_3d = true",
    "R44_ActualImportedNX08Mesh",
    "func rotate_step(",
    "func _gui_input(",
)
assert "R44 real 3D orbit control must not accidentally unlock" in smoke
assert "R44 actual imported 3D ship viewport is mounted at desktop startup" in r25_browser
assert "R44 real 3D aircraft stage exists on mobile" in r31_mobile
assert "garage sortie button unlocks real flight" in r25_browser
assert "mobile garage sortie touch unlocks flight" in r31_mobile

# R50: enforce actual tactical target acquisition and a playable, destructible archive.
r50_fleet = require(
    "scripts/fleet_combat_r15.gd",
    "func select_next_focus() -> bool:",
    "func focus_status() -> String:",
    "FOCUS_RANGE: float = 340.0",
    "enemy.target != defend_anchor",
    "R50_ActualEnemyFocusReticle",
    "func _has_clear_laser_path(origin: Vector3, destination: Vector3) -> bool:",
    "missile_focus_launches",
    "blocked_ally_shots",
)
r50_archive = require(
    "scripts/archive_breach_r50.gd",
    "extends Node3D",
    "func configure(location: Vector3) -> void:",
    "func can_interact(pilot: Vector3) -> bool:",
    "func take_damage(amount: float) -> void:",
    "func is_active_server() -> bool:",
    "func step(delta: float, pilot: Vector3, pressing: bool) -> String:",
    "R50_DestructibleArchiveReactor",
    "R50_OneUseEmergencyPowerCell",
    "func can_repair_here(pilot: Vector3) -> bool:",
    "func set_repair_navigation(enabled: bool) -> bool:",
    "REPAIR_HOLD: float = 2.0",
    "REPAIR_AMOUNT: float = 45.0",
)
assert 'ArchiveBreachR50Script = preload("res://scripts/archive_breach_r50.gd")' in world
assert '"title":"ЗАКРЫТЫЙ АРХИВ"' in world
assert 'mission_index == 12' in smoke
assert "NEBULA_R50_REAL_FOCUS_AND_CONVOY_THREAT_SUCCESS" in smoke
assert "NEBULA_R50_KEYS_ENCRYPTED_SERVER_CONTROLLER_SUCCESS" in smoke
assert "NEBULA_R50_INTEGRATED_ARCHIVE_AND_RETRY_SUCCESS" in smoke
assert "_r50_spawn_archive_threats()" in world
assert "r50_archive.take_damage(8.0)" in world
assert "r50_archive.objective_position()" in world
assert "r50_focus_button.pressed.connect(_r50_next_focus)" in world
assert "r50_repair_button.pressed.connect(_r50_toggle_repair_goal)" in world
assert "fleet_r15.defend_anchor = r50_archive" in world
assert "R50 solid world obstacle must actually block wingman laser path" in smoke
assert "R50 guided missile must prioritize focused enemy and consume one rocket" in smoke
assert "R50 one-use repair must never refill repeatedly" in smoke
assert "R50 integrated touch hold must truly repair once and reset autopilot" in smoke
assert 'SAVE_PATH = "user://nebula_3d_save.json"' in world
assert '"version": 1' in world or "'version': 1" in world or '"version":1' in world
assert "credits +=" not in r50_archive and "xp +=" not in r50_archive
assert "FileAccess.open(" not in r50_archive
require(
    "docs/R50-REAL-TARGET-ARCHIVE-QA.md",
    "NOT_PERFORMED", "1–11", "160", "ВВОД", "V", "38",
)

# R51: mission 13 is a physically moving ship, not a text-only waypoint.
r51_controller = require(
    "scripts/courier_intercept_r51.gd",
    "extends Node3D",
    "R51_PhysicallyMovingEncryptedCourier",
    "func configure(center: Vector3) -> void:",
    "func objective_position() -> Vector3:",
    "func is_extraction_active() -> bool:",
    "func can_hold(pilot: Vector3) -> bool:",
    "func step(delta: float, pilot: Vector3, holding: bool,",
    "EXTRACTION_DEADLINE: float = 90.0",
    "COURIER_RANGE: float = 95.0",
    "PURSUIT_DEADLINE: float = 105.0",
    "PURSUIT_TRAIL_SEGMENTS: int = 5",
    "LEAD_MAX_DISTANCE: float = 32.0",
    "func navigation_position(pilot_position: Vector3) -> Vector3:",
    "func _update_pursuit_trail() -> void:",
    "R51_ActualFutureSignalTrail_",
    "interference_count",
)
assert 'CourierInterceptR51Script = preload("res://scripts/courier_intercept_r51.gd")' in world
assert '"type":"courier"' in world
assert "mission_index == 13" in smoke
assert "NEBULA_R51_MOVING_COURIER_JAMMED_EXTRACTION_CONTROLLER_SUCCESS" in smoke
assert "NEBULA_R51_INTEGRATED_MOVING_COURIER_RETRY_SUCCESS" in smoke
assert "R51 moving pursuit must spawn two actual jammer drone actors" in smoke
assert "R51 real timer failure must preserve v1 progress and pay zero rewards" in smoke
assert "R51 integrated courier escape must fail, show true reason and award nothing" in smoke
assert "r38_genuine_button_presses" in world
assert "cruise_button_events" in world and "cruise_button_visible" in world
assert "actual clickable cruise switch engaged" in r25_browser
assert "pressRealCruise(true" in r25_browser
assert "cruise_button_events>before.cruise_button_events" in r25_browser
assert "r38_touch_button_presses" in require("scripts/performance_lab_r11.gd", "r38_touch_button_presses")
assert "nebula_r51_jammer" in world
assert "_r51_active_interference()" in world
assert "r51_courier.objective_position()" in world
assert "r51_courier.navigation_position(ship.global_position)" in world
assert "R51 world steering may lead courier, but physical beacon cannot be spoofed" in smoke
assert "R51 pursuit must show all five actual in-world signal guide marks" in smoke
assert "R51 courier and 3D trail must move" in smoke
assert "r49_interact_held" in world
assert "credits +=" not in r51_controller and "xp +=" not in r51_controller
assert "FileAccess.open(" not in r51_controller
require("docs/R51-REAL-COURIER-INTERCEPT-QA.md",
    "NOT_PERFORMED", "90", "95", "42", "4,5", "14–30")

# R52: real 14th mission is a destructible physical energy-defense system.
r52_controller = require(
    "scripts/station_blackout_r52.gd",
    "extends Node3D",
    "R52_RealPhysicalCircuitBreaker_",
    "R52_RealDestructiblePowerCore",
    "R52_OneUseBackupCapacitor",
    "func configure(center: Vector3) -> void:",
    "func is_live_reactor() -> bool:",
    "func can_repair() -> bool:",
    "func select_capacitor(enabled: bool) -> bool:",
    "func take_damage(amount: float) -> void:",
    "func step(delta: float, pilot: Vector3, pressing: bool) -> String:",
    "GRID_DEFENSE_SECONDS: float = 95.0",
    "STABILIZATION_SECONDS: float = 14.0",
    "CAPACITOR_RECOVERY: float = 40.0",
    "input_armed = false",
)
assert 'StationBlackoutR52Script = preload("res://scripts/station_blackout_r52.gd")' in world
assert '"type":"blackout"' in world
assert 'mission_index == 14' in smoke
assert "NEBULA_R52_PHYSICAL_RELAY_GRID_CAPACITOR_CONTROLLER_SUCCESS" in smoke
assert "NEBULA_R52_REAL_REACTOR_COMBAT_RETRY_AND_REWARD_SUCCESS" in smoke
assert "nebula_r52_reactor_attackers" in world
assert "_r52_spawn_reactor_threats()" in world
assert "r52_station.take_damage(9.0)" in world
assert "fleet_r15.defend_anchor = r52_station.reactor" in world
assert "r52_station.objective_position()" in world
assert "func _active_mission_goal() -> Vector3:" in world
assert "r52_station.can_repair()" in world
assert "R52 held button from breaker A cannot arm the second breaker" in smoke
assert "R52 world drone fire signal must apply actual reactor damage" in smoke
assert "R52 destroyed station must return to garage with no CR/XP farming" in smoke
assert "R52 used backup capacitor must never generate repeatable energy" in smoke
assert "credits +=" not in r52_controller and "xp +=" not in r52_controller
assert "FileAccess.open(" not in r52_controller
require("docs/R52-REAL-STATION-BLACKOUT-QA.md",
    "NOT_PERFORMED", "95", "78", "14", "40", "15", "Android")

# R54: a REAL enclosed 3D stage, no misleading 2D showroom cards.
r54_hangar = require(
    "scripts/hangar_environment_r54.gd",
    "extends Node3D",
    "R54_AuroraEnclosedIndustrialHangar",
    "R54_Real72mHangarDeck",
    "R54_RealRearHangarWall",
    "R54_ArmoredDoorLeaf_",
    "R54_TravellingInspectionCrane",
    "R54_RealHangarServiceVehicle_",
    "R54_ActualShadowCastingInspectionSpot",
    "func set_quality_tier(tier: int) -> void:",
)
assert 'AuroraHangarZeroR54Script = preload("res://scripts/hangar_environment_r54.gd")' in r44_preview
assert "hangar_set_r54 = AuroraHangarZeroR54Script.new()" in r44_preview
assert "preview_viewport.msaa_3d = Viewport.MSAA_4X" in r44_preview
assert "stretch_shrink = 1" in r44_preview
assert "preview_viewport.size = Vector2i(640, 350)" not in r44_preview
assert "func zoom_r54(direction: int) -> void:" in r44_preview
assert "func _r54_fit_quality() -> void:" in r44_preview
r54_academy = require(
    "scripts/pilot_academy_r54.gd",
    "extends RefCounted",
    "MAX_RANK: int = 3",
    "TRAINING_COSTS: Array[int] = [650, 1100, 1800]",
    "func damage_multiplier(",
    "func thrust_multiplier(",
    "func credit_bonus(",
    "func safe_roster(",
)
assert "R54_AlwaysVisibleRealCreditHangarShop" in garage
assert "R54_AlwaysAvailableHubSections" in garage
assert "R54_CreditBasedCaptainAcademy" in garage
assert "upgrade_requested_r54.emit(0)" in garage
assert "training_requested_r54.emit()" in garage
assert "garage_hub_r39.training_requested_r54.connect(_r54_train_selected_captain)" in world
assert "garage_hub_r39.upgrade_requested_r54.connect(_upgrade_docked)" in world
assert '"pilot_training_r54":pilot_training_r54' in world
assert "PilotAcademyR54Script.safe_roster(raw.get(" in world
assert "PilotAcademyR54Script.credit_bonus(" in world
assert "PilotAcademyR54Script.damage_multiplier(" in world
assert "PilotAcademyR54Script.thrust_multiplier(" in world
assert "NEBULA_R54_REAL_HANGAR_LAYOUT_WALLET_AND_SHOP_SUCCESS" in smoke
assert "NEBULA_R54_ACADEMY_REAL_SHIP_STATS_SAVE_AND_CREDITS_SUCCESS" in smoke
assert "R54 version-1 local save must preserve credit wallet" in smoke
assert "R54 actual departure must apply paid Ada training" in smoke
assert "R54 training must debit 650 CR" in smoke
assert "credits +=" not in r54_academy and "FileAccess.open(" not in r54_academy
require(
    "docs/R54-AURORA-HANGAR-ZERO-QA.md",
    "NOT_PERFORMED", "1700 CR", "4200 CR", "650/1100/1800 CR",
    "Godot", "Chromium", "4K/8K",
)

# R55: independent original sculpted mesh bodies for all three owned fleet types.
r55_fleet = require(
    "scripts/fleet_airframes_r55.gd",
    "extends Node3D",
    "func _loft(",
    "func _airfoil(",
    "func set_hull(id: String) -> void:",
    "func set_throttle(amount: float, afterburner: bool) -> void:",
    "R55_NX08_TrueNarrowFuselage",
    "R55_NX12_TrueWedgeRacerFuselage",
    "R55_NX21_TrueBroadArmoredCitadelHull",
    "R55_NX12_PairedThrust_",
    "R55_NX21_QuadDrive_",
    "visual_signature"
)
assert "ship_scout" in r55_fleet and "ship_interceptor" in r55_fleet
assert "ship_guardian" in r55_fleet
assert "RING_SEGMENTS: int = 14" in r55_fleet
assert "get_parent()" in smoke and "NEBULA_R55_THREE_DISTINCT_3D_CORES_AND_REACTIVE_THRUSTERS_SUCCESS" in smoke
assert "r55_flight.thruster_plumes[0].scale.y > 1.5" in smoke
assert "wing_spans[0] < wing_spans[1]" in smoke
assert "engine_counts == [1,2,4]" in smoke
assert "r55_flight.primary_airframe_r55" not in smoke
r55_ship = require(
    "scripts/ship.gd",
    'const FleetAirframesR55Script = preload("res://scripts/fleet_airframes_r55.gd")',
    "primary_airframe_r55 = FleetAirframesR55Script.new()",
    "model.visible = false",
    "hull_kit_r45.visible = false",
    "primary_airframe_r55.set_hull(id)",
    "primary_airframe_r55.set_throttle(thruster_power, afterburner)"
)
r55_preview = require(
    "scripts/hangar_ship_preview_r44.gd",
    'const FleetAirframesR55Script = preload("res://scripts/fleet_airframes_r55.gd")',
    "primary_airframe_r55.set_hull(selected_hull)",
    "real_airframe.visible = false",
    "distinct_hull_r45.visible = false",
)
assert "credits +=" not in r55_fleet and "FileAccess.open(" not in r55_fleet
require(
    "docs/R55-THREE-DISTINCT-AIRFRAMES-QA.md",
    "NX-08", "NX-12", "NX-21", "WebGL", "NOT_PERFORMED", "R54",
)

# R56: real owned-hull modules and exact paid wallet on existing save.
r56_workbench = require(
    "scripts/hangar_workbench_r56.gd",
    "extends RefCounted",
    'SHIP_IDS: Array[String] = ["ship_scout", "ship_interceptor", "ship_guardian"]',
    'MODULES: Array[String] = ["armor", "shield", "radar"]',
    "MAX_RANK: int = 3",
    "func safe_roster(raw: Variant) -> Dictionary:",
    "func upgrade_cost(module_id: String, current_rank: int) -> int:",
    "func hull_cap(base_cap: float, armor_rank: int) -> float:",
    "func shield_cap(base_cap: float, shield_rank: int) -> float:",
    "func radar_range(radar_rank: int) -> float:",
    "COST_BASE: Dictionary =",
)
assert "HangarWorkbenchR56Script = preload(" in world
assert "HangarWorkbenchR56Script = preload(" in require("scripts/fleet_combat_r15.gd",
    "func set_workbench_r56(roster: Dictionary) -> void:",
    "func radar_range_r56() -> float:",
    "HangarWorkbenchR56Script.hull_cap(",
    "HangarWorkbenchR56Script.shield_cap(")
assert "garage_hub_r39.module_requested_r56.connect(_r56_purchase_workbench_module)" in world
assert 'hangar_modules_r56 = HangarWorkbenchR56Script.safe_roster(raw.get(' in world
assert '"hangar_modules_r56":hangar_modules_r56' in world
assert "radar.range_meters = fleet_r15.radar_range_r56()" in world
assert 'func _r56_purchase_workbench_module(module_id: String) -> void:' in world
assert "ship.hull = minf(ship.hull + HangarWorkbenchR56Script.HULL_GAIN_PER_RANK" in world
assert "ship.shield = minf(ship.shield + HangarWorkbenchR56Script.SHIELD_GAIN_PER_RANK" in world
assert "R56_ActualShipModuleWorkbench" in garage
assert "module_requested_r56.emit(module_id)" in garage
assert 'for tab_id in ["fleet", "workshop", "crew", "operations"]:' in garage
assert "NEBULA_R56_WORKSHOP_REAL_ARMOR_SHIELD_RADAR_PERSISTENT_CREDITS_SUCCESS" in smoke
assert "R56 radar upgrade must debit 400 CR" in smoke
assert "R56 paid heavy Guardian gets separate real hull upgrade" in smoke
assert "R56 module purchase needs visible and active home hangar" in smoke
assert "FileAccess.open(" not in r56_workbench
assert "credits +=" not in r56_workbench
require(
    "docs/R56-MODULAR-WORKBENCH-QA.md",
    "NOT_PERFORMED", "500 CR", "550 CR", "400 CR",
    "WebAssembly", "HTTPS 4/4", "safe_roster",
)

# R56 installed modules must be visible REAL 3D armor/emitter/antenna parts
# on the same independently sculpted hull in flight and AURORA garage.
r56_visual = require(
    "scripts/fleet_airframes_r55.gd",
    "func set_modules_r56(armor_rank: int, shield_rank: int,",
    "R56_ActualPurchasedEquipmentGeometry",
    "R56_ActualShieldEmitter_L%d_",
    "R56_RealRadarArray_L%d",
    "R56_ArmorPlate_L%d_",
    "func module_geometry_count_r56() -> int:",
)
assert "ship.set_workbench_modules_r56(" in world
assert "set_workbench_modules_r56(" in require("scripts/ship.gd",
    "func set_workbench_modules_r56(armor: int, shield_rank: int,")
assert "ship_preview_r44.set_workbench_modules_r56(" in garage
assert "world.ship.primary_airframe_r55.module_geometry_count_r56() >= 4" in smoke
assert "R56_ActualShieldEmitter_*" in smoke
assert "R56_RealRadarArray_L1" in smoke

# R57: repeatable post-campaign sorties must be real-time, physical and paid
# only on verified completion (not upon accepting, failing or save load).
r57_patrol = require(
    "scripts/patrol_contracts_r57.gd",
    "extends RefCounted",
    'CONTRACT_IDS: Array[String] = ["aurora","neon","rift"]',
    "CHECKPOINT_RADIUS_M: float = 54.0",
    "CHECKPOINT_HOLD_SEC: float = 1.50",
    "func begin(id: String) -> bool:",
    "func tick(raw_dt: float, ship_position: Vector3) -> String:",
    "func objective_position() -> Vector3:",
    "func safe_finish_counts(candidate: Variant) -> Dictionary:",
    'return "success"',
    'return "failed"',
)
assert "credits +=" not in r57_patrol
assert "FileAccess.open(" not in r57_patrol
assert 'const PatrolContractsR57Script = preload("res://scripts/patrol_contracts_r57.gd")' in world
assert "garage_hub_r39.contract_selected_r57.connect(_r57_select_contract)" in world
assert "func _r57_patrol_tick(dt: float) -> void:" in world
assert "func _r57_end_patrol(success: bool, message: String) -> void:" in world
assert "if verified:" in world and "r57_reward_committed = true" in world
assert "r57_patrol.tick(dt, ship.global_position)" in world
assert "r57_patrol.objective_position()" in world
assert '"r57_selected_contract":r57_selected_contract' in world
assert "r57_contract_counts = PatrolContractsR57Script.safe_finish_counts(" in world
assert "r57_patrol.active and mission_index >= MISSIONS.size()" in world
assert "R57_ActualContractBeacon" in world
assert "R57_Genuine3DPhysicalBeacon" in world
assert "R57_RealPostCampaignContractBoard" in garage
assert "contract_selected_r57.emit(contract_id)" in garage
assert "r57_contract_panel.visible = operations" in garage
assert "R57_ChooseFreeFlight" in garage
assert "NEBULA_R57_REAL_3D_WAYPOINTS_HOLD_TIMEOUT_AND_SAFE_COUNTS_SUCCESS" in smoke
assert "NEBULA_R57_REAL_REPEATABLE_PAYOUT_FAILURE_AND_CAREER_SAVE_SUCCESS" in smoke
assert "R57 duplicate reward trigger after returning to dock" in smoke
assert "R57 timed-out route must safely return home without a bounty" in smoke
require(
    "docs/R57-PATROL-CAREER-QA.md",
    "NOT_PERFORMED", "14", "380", "650", "980",
    "Godot", "WebAssembly", "HTTPS 4/4",
)

print("NEBULA_R25_SOURCE_SUCCESS: true WASM browser telemetry, scripted physical W/click/waypoint check and 11k PBR four-sided windows")
