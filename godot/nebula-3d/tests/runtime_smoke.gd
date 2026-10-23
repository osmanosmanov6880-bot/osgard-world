extends SceneTree
const SurfaceLibraryR9Script = preload("res://scripts/surface_library_r9.gd")
## Native Godot runtime test: parses real scene, creates procedural city, drives missions,
## validates persistent progression, shields, damage and the radar.
func _initialize() -> void:
    call_deferred("_run")

func fail(message: String) -> void:
    printerr("NEBULA_SMOKE_FAILURE: " + message)
    quit(1)

func check(condition: bool, message: String) -> bool:
    if not condition:
        fail(message)
        return false
    return true

func _run() -> void:
    var packed: PackedScene = load("res://scenes/world.tscn")
    if not check(packed != null, "Main scene resource did not load"):return
    var world: Node3D = packed.instantiate()
    root.add_child(world)
    await process_frame
    if not check(is_instance_valid(world.ship), "PlayerShip missing"):return
    if not check(world.ship is CharacterBody3D, "Ship is not a physics body"):return
    if not check(world.get_node_or_null("CityTowers_MultiMesh") != null, "City architecture missing"):return
    if not check(world.get_node_or_null("SkylineNeonCrowns") != null, "Neon skyline detail missing"):return
    var premium = world.get_node_or_null("PremiumArchitecture")
    if not check(premium != null,"Cinematic architecture not instantiated"):return
    if not check(premium.towers_built == 360,"Expected 360 textured high-rises"):return
    if not check(premium.window_instances == 1440,"Instanced metallic façade fins missing"):return
    if not check(premium.corridor_count == 5,"Sky transit corridors missing"):return
    if not check(premium.dock_count == 6,"Multilevel sector docks missing"):return
    if not check(premium.get_node_or_null("PremiumFacadeFins") != null,"Facade mesh absent"):return
    if not check(premium.get_node_or_null("NebulaDistantPlanet") != null,"Planet backdrop absent"):return
    var detail = world.get_node_or_null("HighDetailCityR5")
    if not check(detail != null, "R5 city dressing pass missing"):return
    if not check(detail.instanced_parts > 8000, "R5 skyscraper and dock detailing not instantiated"):return
    if not check(detail.landmark_count == 6, "Expected six signature R5 citadels"):return
    var interceptor = world.ship.get_node_or_null("AnimatedShip/HighDetailInterceptorR5")
    if not check(interceptor != null, "R5 ship visual model missing"):return
    if not check(interceptor.detail_count > 100, "R5 ship is not high detail"):return
    if not check(world.ship.engine_flames.size() == 3, "R5 player ship should have triple animated turbines"):return
    var hero_r6 = interceptor.get_node_or_null("R6_HeroHullDetail")
    if not check(hero_r6 != null, "R6 aircraft hero model missing"):return
    if not check(hero_r6.hero_parts > 170, "R6 ship detail budget not reached"):return
    if not check(hero_r6.fasteners >= 80, "R6 instanced aircraft fasteners absent"):return
    if not check(hero_r6.gun_count == 4, "Four magnetic accelerator barrels required"):return
    if not check(hero_r6.animated_rotors.size() == 3, "Three real internal turbines required"):return
    var finish_r7 = interceptor.get_node_or_null("R7_PBRSurfaceFinish")
    if not check(finish_r7 != null, "R7 physical PBR surface details missing"):return
    if not check(finish_r7.finish_instances >= 340, "R7 batched surface microgeometry missing"):return
    if not check(finish_r7.optical_sensors == 2, "Player navigation optical sensors missing"):return
    if not check(finish_r7.decal_count == 2, "Player wing serial insignia missing"):return
    var imported_r8 = interceptor.get_node_or_null("R8_ImportedHeroMesh")
    if not check(imported_r8 != null, "Importable R8 interceptor glTF missing"):return
    var r8_ship_vertices: int = 0
    var r8_ship_surfaces: int = 0
    for draw in imported_r8.find_children("*", "MeshInstance3D", true, false):
        if draw.mesh == null:continue
        r8_ship_surfaces += draw.mesh.get_surface_count()
        for surface in draw.mesh.get_surface_count():
            r8_ship_vertices += draw.mesh.surface_get_array_len(surface)
    if not check(r8_ship_vertices >= 8000, "R8 sculpted interceptor mesh resolution too low"):return
    if not check(r8_ship_surfaces >= 5, "R8 PBR material surfaces missing"):return
    var ship_normal_surfaces: int = 0
    for draw in imported_r8.find_children("*", "MeshInstance3D", true, false):
        if draw.mesh == null:continue
        for surface in draw.mesh.get_surface_count():
            var coated := draw.get_surface_override_material(surface) as StandardMaterial3D
            if coated != null and coated.normal_enabled:
                ship_normal_surfaces += 1
    if not check(ship_normal_surfaces >= 2, "R8 metal normal-map integration missing"):return
    var r9_ship_orm: int = 0
    for draw in imported_r8.find_children("*", "MeshInstance3D", true, false):
        if draw.mesh == null:continue
        for surface in draw.mesh.get_surface_count():
            var coated := draw.get_surface_override_material(surface) as StandardMaterial3D
            if coated != null and coated.roughness_texture != null and coated.metallic_texture != null and coated.ao_texture != null:
                r9_ship_orm += 1
    if not check(r9_ship_orm >= 3, "R9 physically packed ship textures missing"):return
    var mechanisms = interceptor.get_node_or_null("R9_AnimatedAirframeMechanics")
    if not check(mechanisms != null, "R9 animated ship mechanics not instantiated"):return
    if not check(mechanisms.gear_count == 3, "R9 hydraulic landing gear not present"):return
    if not check(mechanisms.control_surfaces == 6, "R9 animated elevons not present"):return
    if not check(mechanisms.compressor_shutters == 36, "R9 turbine shutters not present"):return
    var fleet_r7 = world.get_node_or_null("CapitalFleetR7")
    if not check(fleet_r7 != null, "R7 monumental capital fleet missing"):return
    if not check(fleet_r7.carrier_count == 6, "Expected six true 3D capital ships"):return
    if not check(fleet_r7.turret_count == 36, "Carrier turret assemblies missing"):return
    if not check(fleet_r7.engine_count == 24, "Capital ship engines missing"):return
    if not check(fleet_r7.armor_instances >= 3100, "Instanced capital ship armor details missing"):return
    if not check(fleet_r7.get_node_or_null("R7_CapitalCarrier_00/CarrierHullCollision") is StaticBody3D,
        "Hero ship collision volume missing"):return
    var megadocks = world.get_node_or_null("HeroMegadocksR6")
    if not check(megadocks != null, "R6 industrial orbital megadocks absent"):return
    if not check(megadocks.hangar_count == 12, "Twelve curved hangars missing"):return
    if not check(megadocks.crane_count == 12, "Twelve detailed cargo cranes missing"):return
    var imported_hangar = megadocks.get_node_or_null("R6_EnclosedHangar_00_0/R8_IndustrialHangarAsset")
    if not check(imported_hangar != null, "R8 imported curved hangar geometry missing"):return
    var r8_hangar_vertices: int = 0
    for draw in imported_hangar.find_children("*", "MeshInstance3D", true, false):
        if draw.mesh == null:continue
        for surface in draw.mesh.get_surface_count():
            r8_hangar_vertices += draw.mesh.surface_get_array_len(surface)
    if not check(r8_hangar_vertices >= 16000, "R8 architectural mesh resolution too low"):return
    var hangar_normal_surfaces: int = 0
    for draw in imported_hangar.find_children("*", "MeshInstance3D", true, false):
        if draw.mesh == null:continue
        for surface in draw.mesh.get_surface_count():
            var coated := draw.get_surface_override_material(surface) as StandardMaterial3D
            if coated != null and coated.normal_enabled:
                hangar_normal_surfaces += 1
    if not check(hangar_normal_surfaces >= 2, "R8 hangar normal-mapped alloy missing"):return
    var r9_hangar_orm: int = 0
    for draw in imported_hangar.find_children("*", "MeshInstance3D", true, false):
        if draw.mesh == null:continue
        for surface in draw.mesh.get_surface_count():
            var mat := draw.get_surface_override_material(surface) as StandardMaterial3D
            if mat != null and mat.ao_texture != null and mat.roughness_texture != null:
                r9_hangar_orm += 1
    if not check(r9_hangar_orm >= 3, "R9 port roughness/occlusion maps missing"):return
    var distant_roof = megadocks.get_node("R6_EnclosedHangar_00_0/SegmentedCurvedTitaniumRoof")
    if not check(distant_roof.visible and distant_roof.visibility_range_begin >= 350.0,
        "R9 distant roof LOD transition missing"):return
    if not check(megadocks.panels_instanced >= 1600, "PBR deck tiles not installed"):return
    if not check(megadocks.structural_instances >= 2100, "R6 GPU-instanced docking details missing"):return
    var skyline_r6 = world.get_node_or_null("SculpturalSkylineR6")
    if not check(skyline_r6 != null, "R6 sculptural skyline missing"):return
    if not check(skyline_r6.landmark_count == 6, "Six 3D arcologies required"):return
    if not check(skyline_r6.facade_fins >= 1000, "3D tower mullions insufficient"):return
    var industry = world.get_node_or_null("OrbitalIndustryR9")
    if not check(industry != null, "R9 industrial spaceport absent"):return
    if not check(industry.silo_count == 24, "R9 high-detail 24 pressure vessels missing"):return
    if not check(industry.docking_clamps == 12, "R9 animated dock loading platforms missing"):return
    if not check(industry.panel_instances >= 1700, "R9 industrial mesh instancing budget unmet"):return
    if not check(industry.work_lights.size() == 12, "R9 physically colored dock worklights missing"):return
    if not check(industry.get_node_or_null("R9_PressureVesselCollision_00") is StaticBody3D,
        "R9 pressure vessel physics body missing"):return
    if not check(SurfaceLibraryR9Script.atlas_count() >= 3,
        "R9 shared PBR textures not generated"):return
    var aegis_r10 = world.get_node_or_null("AegisMegadocksR10")
    if not check(aegis_r10 != null, "R10 hero megadock parent absent"):return
    if not check(aegis_r10.megadock_count == 6, "R10 six sculpted megadocks missing"):return
    if not check(aegis_r10.modeled_triangles > 160000,
        "R10 authored megadock triangle coverage below target"):return
    if not check(aegis_r10.loading_arms == 12,
        "R10 twelve animated loader arms missing"):return
    if not check(aegis_r10.instanced_details >= 1600,
        "R10 batched architectural tech details missing"):return
    var cladding_r10 = world.get_node_or_null("R10_ArchitecturalCladding")
    if not check(cladding_r10 != null, "R10 detailed city window facades missing"):return
    if not check(cladding_r10.serviced_towers >= 100,
        "R10 high-detail serviced skyscraper count too low"):return
    if not check(cladding_r10.facade_count >= 10000,
        "R10 physically extruded facade elements too few"):return
    if not check(cladding_r10.chunks.size() == 24,
        "R10 district-separated GPU instancing incorrect"):return
    var r10_first = aegis_r10.get_node_or_null("R10_AegisPort_00")
    if not check(r10_first != null, "First cinematic Aegis port missing"):return
    if not check(r10_first.get_node_or_null("R10_OverheadBridgeCollision") is StaticBody3D,
        "R10 accessible overhead bridge collision missing"):return
    if not check(r10_first.get_node_or_null("R10_ImportedHeroMegadock") != null,
        "R10 glTF superstructure not imported"):return
    if not check(world.graphics_quality == 0,
        "Maximum image quality must be default"):return
    world._set_graphics_quality(2)
    if not check(aegis_r10.quality_mode == 2 and world.graphics_quality == 2,
        "R10 selectable low-range LOD not working"):return
    if not check(cladding_r10.quality_mode == 2,
        "R10 cladding LOD ignores graphics quality"):return
    var first_r10_draw = aegis_r10.imports[0].find_children("*", "MeshInstance3D", true, false)
    if not check(first_r10_draw.size() > 0 and first_r10_draw[0].visibility_range_end < 400.0,
        "R10 geometry not responding to dynamic quality switch"):return
    world._set_graphics_quality(0)
    if not check(aegis_r10.quality_mode == 0 and first_r10_draw[0].visibility_range_end >= 800.0,
        "R10 maximum quality was not restored"):return
    var r11_environment = world.get_node_or_null("R11_IndustrialHeroEnvironment")
    if not check(r11_environment != null, "R11 industrial hero environment absent"):return
    if not check(r11_environment.docking_decks == 12,
        "R11 twelve PBR sculpted landing bays missing"):return
    if not check(r11_environment.service_gantries == 12,
        "R11 articulated cargo cranes missing"):return
    if not check(r11_environment.moving_carts == 12,
        "R11 autonomous loading transport missing"):return
    if not check(r11_environment.instanced_hardware >= 3300,
        "R11 GPU-batched detailed machinery below target"):return
    if not check(r11_environment.get_node_or_null(
        "R11_DetailDock_00/R11_LandingDockCollision") is StaticBody3D,
        "R11 physical landing collision absent"):return
    var r11_deck_material = r11_environment.deck_material
    if not check(r11_deck_material.normal_enabled and
        r11_deck_material.ao_texture != null and
        r11_deck_material.roughness_texture != null and
        r11_deck_material.metallic_texture != null,
        "R11 true multichannel physically based deck material incomplete"):return
    var film_r11 = world.get_node_or_null("R11_CinematicPost")
    if not check(film_r11 != null and film_r11.shader_compiled,
        "R11 compatibility cinematic postprocess absent"):return
    if not check(film_r11.is_active(), "R11 maximum-grade film treatment inactive"):return
    var monitor_r11 = world.get_node_or_null("R11_PerformanceLab")
    if not check(monitor_r11 != null and
        monitor_r11.get_node_or_null("R11_HardwarePerformancePanel") != null,
        "R11 live hardware profiler panel missing"):return
    var percentile_test: Array[float] = [10.0, 20.0, 30.0, 40.0]
    if not check(monitor_r11._percentile(percentile_test, 0.95) == 40.0,
        "R11 95th percentile calculation failed"):return
    if not check(not monitor_r11.benchmarking and monitor_r11.last_report.is_empty(),
        "R11 performance telemetry is incorrectly fabricated at startup"):return
    var cinematic_env = world.get_node_or_null("R11_CinematicWorldEnvironment")
    if not check(cinematic_env is WorldEnvironment and
        cinematic_env.environment.glow_enabled and
        cinematic_env.environment.adjustment_enabled,
        "R11 filmic tonemapping and controlled glare missing"):return
    world._set_graphics_quality(2)
    if not check(r11_environment.lod_mode == 2 and
        not film_r11.is_active() and monitor_r11.quality_mode == 2,
        "R11 low-GPU profile failed to disable heavy postprocess"):return
    world._set_graphics_quality(0)
    if not check(r11_environment.lod_mode == 0 and film_r11.is_active(),
        "R11 maximum-quality graphic stack not restored"):return
    var hangar_solid = world.get_node_or_null("HeroMegadocksR6/R6_EnclosedHangar_00_0/HangarLeftWallCollision")
    if not check(hangar_solid is StaticBody3D, "Hangar collision missing"):return
    var arcology_solid = world.get_node_or_null("SculpturalSkylineR6/R6_SculptedArcology_00/ArcologyCollision")
    if not check(arcology_solid is StaticBody3D, "Arcology navigation collision missing"):return
    if not check(is_instance_valid(world.hud_objective),"Cinematic HUD objective missing"):return
    if not check(world.drones.size() >= 22, "Traffic simulation missing"):return
    if not check(is_instance_valid(world.radar), "Mission radar missing"):return
    var start_credits: int = world.credits
    world.ship.global_position = world.MISSIONS[0]["position"]
    await process_frame
    await process_frame
    if not check(world.mission_index >= 1, "Waypoint mission did not complete"):return
    if not check(world.credits > start_credits, "Mission reward missing"):return
    var previous_credits: int = world.credits
    world.credits = 5000
    world.ship.global_position = Vector3(0,18,78)
    world._upgrade_docked(0)
    if not check(world.ship.engine_rank == 1, "Engine purchase failed"):return
    if not check(world.credits < 5000, "Engine was not charged"):return
    world._save_progress()
    var save: FileAccess = FileAccess.open(world.SAVE_PATH,FileAccess.READ)
    if not check(save != null,"Save file not created"):return
    var parsed = JSON.parse_string(save.get_as_text())
    save.close()
    if not check(parsed is Dictionary and parsed.get("engine_rank",-1) == 1,"Upgrade missing in save"):return
    var shield_before: float = world.ship.shield
    world.ship.take_damage(10.0)
    if not check(world.ship.shield < shield_before,"Damage does not reduce shield"):return
    if not check(previous_credits >= 0,"Invalid credits"):return
    print("NEBULA_SMOKE_SUCCESS missions=1 upgrades=1 drones=%d premium3d=r11 pbr=true gantries=12 performance-lab=real-device" % world.drones.size())
    quit(0)
