extends SceneTree
const SurfaceLibraryR9Script = preload("res://scripts/surface_library_r9.gd")
const MaterialFabricR12Script = preload("res://scripts/material_fabric_r12.gd")
## Native Godot runtime test: parses real scene, creates procedural city, drives missions,
## validates persistent progression, shields, damage and the radar.
func _initialize() -> void:
    print("NEBULA_R16_SMOKE_BOOT")
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
    print("NEBULA_R16_SCENE_CREATED")
    await process_frame
    if not check(is_instance_valid(world.ship), "PlayerShip missing"):return
    if not check(world.ship is CharacterBody3D, "Ship is not a physics body"):return
    if not check(world.get_node_or_null("CityTowers_MultiMesh") != null, "City architecture missing"):return
    if not check(world.get_node_or_null("SkylineNeonCrowns") != null, "Neon skyline detail missing"):return
    # R18 world-wide 360+360 GPU draw packages are now six independent
    # per-sector local bounding boxes; baseline tower geometry stays intact.
    if not check(world.r18_base_tower_instances == 360 and
        world.r18_city_district_chunks == 6,
        "R18 original 360 base skyscrapers not sharded into six GPU districts"):return
    if not check(world.r18_city_batches.size() == 6 and
        world.r18_neon_batches.size() == 6,
        "R18 city/neon independent frustum bounds missing"):return
    for district in 6:
        var tower_draw = world.r18_city_batches[district]
        var neon_draw = world.r18_neon_batches[district]
        if not check(tower_draw is MultiMeshInstance3D and
            neon_draw is MultiMeshInstance3D and
            tower_draw.multimesh.instance_count == 60 and
            neon_draw.multimesh.instance_count == 60,
            "R18 GPU subbatch must hold 60 towers and 60 neon caps"):return
        if not check(tower_draw.position == world.SECTOR_POSITIONS[district] and
            neon_draw.position == world.SECTOR_POSITIONS[district],
            "R18 GPU district geometry not placed at its physical origin"):return
        var local_transform: Transform3D = tower_draw.multimesh.get_instance_transform(0)
        if not check(local_transform.origin.length() < 390.0,
            "R18 supposedly local GPU bounds still contain absolute world positions"):return
    var premium = world.get_node_or_null("PremiumArchitecture")
    if not check(premium != null,"Cinematic architecture not instantiated"):return
    if not check(premium.towers_built == 360,"Expected 360 textured high-rises"):return
    if not check(premium.window_instances == 1440,"Instanced metallic façade fins missing"):return
    if not check(premium.r19_facade_instance_count == 1440 and
        premium.r19_roof_instance_count == 360 and
        premium.r19_facade_chunks.size() == 6 and premium.r19_roof_chunks.size() == 6,
        "R19 facade and roof batch sharding lost original premium instances"):return
    for district in 6:
        var facades = premium.r19_facade_chunks[district]
        var roofs = premium.r19_roof_chunks[district]
        if not check(facades.multimesh.instance_count == 240 and
            roofs.multimesh.instance_count == 60,
            "R19 each premium building district should own 240 fins and 60 roofs"):return
        if not check(facades.position == world.SECTOR_POSITIONS[district] and
            roofs.position == world.SECTOR_POSITIONS[district],
            "R19 premium architecture GPU positions must be district-local"):return
        if not check(facades.multimesh.get_instance_transform(0).origin.length() < 400.0 and
            roofs.multimesh.get_instance_transform(0).origin.length() < 400.0,
            "R19 premium GPU bounds are still all-world-sized"):return
    if not check(premium.corridor_count == 5,"Sky transit corridors missing"):return
    if not check(premium.dock_count == 6,"Multilevel sector docks missing"):return
    if not check(premium.get_node_or_null("PremiumFacadeFins") != null,"Facade mesh absent"):return
    if not check(premium.get_node_or_null("NebulaDistantPlanet") != null,"Planet backdrop absent"):return
    var detail = world.get_node_or_null("HighDetailCityR5")
    if not check(detail != null, "R5 city dressing pass missing"):return
    if not check(detail.instanced_parts > 8000, "R5 skyscraper and dock detailing not instantiated"):return
    if not check(detail.landmark_count == 6, "Expected six signature R5 citadels"):return
    if not check(detail.original_batch_groups == 16 and
        detail.sharded_groups >= 80 and detail.per_sector_batch_count() >= 80,
        "R18 distant R5 facades still drawn as world-wide GPU batches"):return
    if not check(detail.drawn_instances == detail.instanced_parts and
        detail.district_roots.size() == 6,
        "R18 district shading lost any original R5 architectural instances"):return
    for cluster in detail.detail_chunks:
        if not check(cluster.get_parent() is Node3D and
            cluster.visibility_range_end > 0.0,
            "R18 R5 facade group missing district-local LOD range"):return
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
    if not check(skyline_r6.facade_batches == 18 and
        skyline_r6.exterior_beam_instances > skyline_r6.facade_fins and
        skyline_r6.segment_hubs.size() == 6,
        "R18 original R6 skyline still uses giant all-world steel beam batch"):return
    if not check(skyline_r6.detail_draws[0].visibility_range_end >= 900.0,
        "R18 first arcology lacks maximum-range facade geometry"):return
    var industry = world.get_node_or_null("OrbitalIndustryR9")
    if not check(industry != null, "R9 industrial spaceport absent"):return
    if not check(industry.silo_count == 24, "R9 high-detail 24 pressure vessels missing"):return
    if not check(industry.r19_batch_groups == 8 and
        industry.r19_sharded_groups == 48 and
        industry.r19_batches.size() == 48 and
        industry.r19_original_instances == industry.panel_instances,
        "R19 industrial batches must be independent per district with no lost assets"):return
    if not check(industry.get_node_or_null(
        "R9_PBRPressureSilos_24/R19_IndustrialSector_00") is MultiMeshInstance3D,
        "R19 original pressure silos must be visible in original scene group"):return
    var visible_silos: int = 0
    var silo_parent = industry.get_node_or_null("R9_PBRPressureSilos_24")
    for sector in 6:
        var draw: MultiMeshInstance3D = silo_parent.get_node(
            "R19_IndustrialSector_%02d" % sector)
        visible_silos += draw.multimesh.instance_count
        if not check(draw.position == world.SECTOR_POSITIONS[sector],
            "R19 industry GPU batch centres must use local sector coordinates"):return
        if not check(draw.multimesh.get_instance_transform(0).origin.length() < 150.0,
            "R19 industrial instance still uses absolute world coordinates"):return
    if not check(visible_silos == 24, "R19 silo geometry count incorrect"):return
    industry._r19_refresh_lights()
    var locally_lit: int = 0
    for light in industry.work_lights:
        if light.visible:
            locally_lit += 1
    if not check(locally_lit == 2,
        "R19 player near Aurora should see exactly two local industrial worklights"):return
    industry.set_quality(2)
    for light in industry.work_lights:
        if not check(not light.visible, "R19 ECO profile must remove expensive practical lights"):return
    if not check(industry.r19_batches[0].visibility_range_end == 420.0,
        "R19 ECO distant industry culling range not applied"):return
    industry.set_quality(0)
    if not check(industry.r19_batches[0].visibility_range_end == 1020.0,
        "R19 MAX industrial LOD not restored"):return
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
    # Check R18 GPU detail LOD responds to the same F3/F11 and automatic
    # quality events without deleting collision bodies or core skyline.
    world._set_graphics_quality(2)
    if not check(world.r18_city_batches[0].visibility_range_end == 1400.0 and
        world.r18_neon_batches[0].visibility_range_end == 470.0 and
        detail.quality_mode == 2 and skyline_r6.quality_mode == 2 and
        detail.detail_chunks[0].visibility_range_end == 330.0 and
        skyline_r6.detail_draws[0].visibility_range_end == 390.0,
        "R18 ECO quality fails to cull distant buildings/architectural micro-detail"):return
    world._set_graphics_quality(0)
    if not check(detail.quality_mode == 0 and skyline_r6.quality_mode == 0 and
        detail.detail_chunks[0].visibility_range_end == 900.0 and
        skyline_r6.detail_draws[0].visibility_range_end == 950.0 and
        world.r18_city_batches[0].visibility_range_end == 2500.0,
        "R18 MAX quality restoration must keep detailed city visible"):return
    print("NEBULA_R18_DISTRICT_CULLING_SUCCESS city=360 facade=%d sharded=%d arcology=%d" % [
        detail.drawn_instances, detail.sharded_groups, skyline_r6.facade_batches])
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
    if not check(r11_environment.lod_nodes.size() == 42,
        "R11 industrial assets must be chunked by district for GPU culling"):return
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
    var r12 = world.get_node_or_null("R12_AerospaceEngineeringCampus")
    if not check(r12 != null, "R12 aerospace campus not instantiated"):return
    if not check(r12.workshop_count == 12,
        "R12 engineering halls missing across six districts"):return
    if not check(r12.lofted_pressure_housings == 36,
        "R12 sculpted curved housing mesh count incorrect"):return
    if not check(r12.hero_mesh_vertices >= 2800,
        "R12 reusable high-detail pressure mesh resolution too low"):return
    if not check(r12.articulated_gates == 24 and r12.articulated_cranes == 12,
        "R12 functional animated blast doors or gantries missing"):return
    if not check(r12.detail_instances >= 6000,
        "R12 instanced PBR fasteners and structural layers below target"):return
    if not check(r12.get_node_or_null(
        "R12_MachinedEngineeringHall_00/R12_MainHallCollision") is StaticBody3D,
        "R12 engineering hall collisions missing"):return
    if not check(MaterialFabricR12Script.atlas_count() == 3,
        "R12 three physically based shared atlases not generated"):return
    for profile in 3:
        var mat: StandardMaterial3D = MaterialFabricR12Script.get_material(profile)
        if not check(mat.normal_enabled and mat.ao_texture != null and
            mat.metallic_texture != null and mat.roughness_texture != null,
            "R12 PBR maps missing for industrial surface"):return
    var light_r12 = world.get_node_or_null("R12_CinematicLighting")
    if not check(light_r12 != null and light_r12.current_look == 0,
        "R12 professional blue-hour lighting setup missing"):return
    light_r12.apply_look(1)
    if not check(light_r12.current_look == 1,
        "R12 alternate warm cinematic look not working"):return
    light_r12.apply_look(0)
    var adaptive_r12 = world.get_node_or_null("R12_AdaptiveQuality")
    if not check(adaptive_r12 != null and not adaptive_r12.auto_enabled,
        "R12 automatic performance quality must be opt-in"):return
    adaptive_r12.set_auto(true)
    if not check(adaptive_r12.observe_fps(20.0, 9.0) == 1 and
        world.graphics_quality == 1,
        "R12 measured low-FPS downshift logic failed"):return
    if not check(adaptive_r12.observe_fps(21.0, 5.0, true) == -1,
        "R12 benchmark lockout did not suppress quality shifting"):return
    adaptive_r12.set_auto(false)
    world._set_graphics_quality(0)
    if not check(r12.quality_mode == 0 and light_r12.quality_mode == 0,
        "R12 maximum-quality view not restored after adaptive test"):return
    var r12_post = world.get_node_or_null("R11_CinematicPost")
    r12_post.set_flight_velocity(65.0)
    if not check(r12_post.motion_hint > 0.0,
        "R12 dynamic film-streak control missing"):return
    if not check(monitor_r11.last_report.is_empty(),
        "R12 actual physical hardware results must never be invented in CI"):return
    var r14 = world.get_node_or_null("R14_SculptedCinematicPorts")
    if not check(r14 != null, "R14 cinematic ports not loaded into real game scene"):return
    if not check(r14.site_count == 6 and r14.sculpted_decks == 6,
        "R14 sculpted decks not distributed across six game districts"):return
    if not check(r14.sculpted_vertices >= 2600,
        "R14 truly sculpted flight deck geometry below minimum resolution"):return
    if not check(r14.hydraulic_gantries == 12 and r14.detailed_truss_assemblies >= 200,
        "R14 articulated loading gear and braced megastructure details absent"):return
    if not check(r14.instanced_hardware >= 3000,
        "R14 GPU instancing for micro-scale architecture insufficient"):return
    if not check(r14.physical_barriers >= 24,
        "R14 collisions missing on platforms and towers"):return
    if not check(r14.get_node_or_null("R14_CinematicPort_00/R14_FlightDeckPhysics") is StaticBody3D,
        "R14 first playable launch platform is not collidable"):return
    if not check(r14.get_node_or_null("R14_CinematicPort_00/R14_OverheadBridgePhysics") is StaticBody3D,
        "R14 physical skybridge is missing"):return
    var ship_trim_r14 = world.ship.get_node_or_null(
        "AnimatedShip/HighDetailInterceptorR5/R14_AirframeRefinement")
    if not check(ship_trim_r14 != null, "R14 real player interceptor refinement missing"):return
    if not check(ship_trim_r14.engine_cowls == 3 and
        ship_trim_r14.wing_armor_panels == 12 and
        ship_trim_r14.animated_iris_rings == 3,
        "R14 shaped engine cases and pressure armor were not built"):return
    if not check(ship_trim_r14.fastener_instances >= 190,
        "R14 GPU-instanced aerospace hardware missing"):return
    world._set_graphics_quality(2)
    if not check(r14.quality_mode == 2 and ship_trim_r14.quality_mode == 2,
        "R14 ECO rendering range not applied to both world and airframe"):return
    if not check(r14.fine_draws[0].visibility_range_end <= 245.0,
        "R14 ECO should cull expensive near-field sculpted models"):return
    world._set_graphics_quality(0)
    if not check(r14.quality_mode == 0 and ship_trim_r14.quality_mode == 0,
        "R14 maximum-quality restored state inconsistent"):return
    if not check(monitor_r11.last_report.is_empty(),
        "R14 CI must not invent physical hardware FPS values"):return
    # R17: quality is identical but all seven 384px material atlases must
    # load from actual CI-imported PNG textures in production instead of
    # generating >1M pixels on the player's WebGL main thread.
    for kind in 4:
        var r17_maps: Dictionary = SurfaceLibraryR9Script.maps(kind)
        for channel in ["albedo", "normal", "orm"]:
            var map: Texture2D = r17_maps.get(channel)
            if not check(map != null and map.get_width() == 384 and map.get_height() == 384,
                "R17 prebaked R9 384px physical texture maps unavailable"):return
    if not check(SurfaceLibraryR9Script.baked_count() == 4,
        "R17 R9 WebGL still dynamically computes PBR atlas pixels"):return
    for profile in 3:
        var atlas_material: StandardMaterial3D = MaterialFabricR12Script.get_material(profile)
        if not check(atlas_material.albedo_texture != null and
            atlas_material.normal_texture != null and
            atlas_material.ao_texture != null,
            "R17 R12 loaded physically based texture channels incomplete"):return
    if not check(MaterialFabricR12Script.baked_count() == 3,
        "R17 R12 WebGL still dynamically computes PBR atlas pixels"):return
    print("NEBULA_R17_PBR_IMPORT_SUCCESS profiles=7 png=21 size=384x384")
    var hangar_r15 = world.get_node_or_null("R15_HangarShop")
    if not check(hangar_r15 != null and hangar_r15.tabs.get_tab_count() == 5,
        "R15 in-game ship/weapon/missile/ally/premium shop missing"):return
    if not check(world.MISSIONS.size() >= 10, "R15 storyline is shorter than ten missions"):return
    var combat_r15 = world.get_node_or_null("R15_FleetCombat")
    if not check(combat_r15 != null, "R15 purchasable player fleet absent"):return
    var fulfillment_r15 = world.get_node_or_null("R15_VerifiedPaymentFulfillment")
    if not check(fulfillment_r15 != null and fulfillment_r15.inventory.is_empty(),
        "R15 real-money entitlements must not be fabricated in Godot CI"):return
    world.ship.global_position = Vector3(0,19,78)
    world.credits = 10000
    world._r15_buy_credit("ship_interceptor")
    if not check(world.equipped_r15 == "ship_interceptor" and
        world.fleet_r15.active_ship == "ship_interceptor" and world.ship.turn_speed > 2.3,
        "R15 credit-funded ship has no effect on player flight"):return
    world._r15_buy_credit("weapon_plasma")
    if not check(world.fleet_r15.weapon_damage() >= 10.0,
        "R15 bought plasma gun has no combat damage effect"):return
    world._r15_buy_credit("missiles_6")
    if not check(world.rockets_r15 == 6 and world.fleet_r15.missiles == 6,
        "R15 credit-funded rockets are not loaded"):return
    world._r15_buy_credit("wingman_escort")
    if not check(world.fleet_r15.helpers.size() == 1,
        "R15 purchasable wingman was not spawned"):return
    print("NEBULA_R16_COMBAT_TESTS_BEGIN")
    # R16: repeated loadout refresh must never destroy/recreate wingmen.
    var escort_instance: int = world.fleet_r15.helpers[0].get_instance_id()
    var rebuild_count: int = world.fleet_r15.helper_rebuilds
    for i in 8:
        world._r15_apply_loadout()
    if not check(world.fleet_r15.helper_rebuilds == rebuild_count and
        world.fleet_r15.helpers[0].get_instance_id() == escort_instance,
        "R16 ammo/receipt refresh is rebuilding combat allies and causing stutter"):return
    if not check(world.fleet_r15.missile_pool.size() == 8,
        "R16 guided missile projectile pool missing"):return
    if not check(world.fleet_r15.missile_pool[0].get_child_count() >= 5,
        "R16 missile mesh lacks detailed 3D fins and propulsion"):return
    var beams: Node3D = world.get_node_or_null("R16_PooledCombatBeams")
    if not check(beams != null and beams.get_child_count() == 18,
        "R16 reusable combat laser beam pool missing"):return
    for i in 50:
        world._laser_effect_colored(Vector3(0,20,0),
            Vector3(float(i % 7) + 4.0, 20.0, -65.0),
            Color(1.0,0.26,0.39))
    if not check(beams.get_child_count() == 18 and world.r16_beam_shots == 50,
        "R16 weapon fire is allocating new mesh nodes per shot"):return
    world._r16_update_beam_pool(0.2)
    for beam in world.r16_beams:
        if not check(not beam.visible,
            "R16 laser pool did not recycle expired effects"):return
    var target_r16 = load("res://scripts/drone.gd").new()
    target_r16.name = "R16_MissileFlightTarget"
    target_r16.hostile = true
    target_r16.health = 40.0
    target_r16.target = world.ship
    world.add_child(target_r16)
    target_r16.global_position = world.ship.global_position + Vector3(0,0,-28)
    var practice_targets: Array[Node3D] = [target_r16]
    world.fleet_r15.targets = practice_targets
    var missile_ammo_before: int = world.fleet_r15.missiles
    if not check(world.fleet_r15.launch_missile(),
        "R16 purchased missiles cannot launch"):return
    if not check(world.fleet_r15.missiles == missile_ammo_before - 1 and
        target_r16.health == 40.0,
        "R16 missile must spend ammo and fly visibly, not instant-hit"):return
    var projectile_r16 = world.fleet_r15.missile_pool[0]
    if not check(bool(projectile_r16.get("armed")) and projectile_r16.visible,
        "R16 homing missile is not visible during flight"):return
    for i in 30:
        if not bool(projectile_r16.get("armed")):
            break
        projectile_r16._process(0.05)
    if not check(world.fleet_r15.missile_impacts == 1 and
        target_r16.health < 40.0 and not bool(projectile_r16.get("armed")),
        "R16 missile did not navigate to the enemy and apply delayed damage"):return
    world.fleet_r15.targets = world.drones
    world.rockets_r15 = world.fleet_r15.missiles
    world.store_r15.open(world.credits, world.owned_r15, world.equipped_r15)
    world.ship.controls_locked = true
    world.store_r15.close()
    if not check(not world.ship.controls_locked,
        "R16 closing hangar failed to restore player flight controls"):return
    if not check(world.R16_RADAR_PERIOD >= 0.10 and
        world.R16_HUD_PERIOD >= 0.09,
        "R16 radar/HUD must not re-render at full display FPS"):return
    print("NEBULA_R16_COMBAT_TESTS_PASSED")
    world._r15_premium_synced({"ship_guardian": 1, "weapon_plasma": 1})
    world._r15_buy_credit("ship_guardian")
    if not check(world.equipped_r15 == "ship_guardian" and
        not world.owned_r15.has("ship_guardian"),
        "R15 paid ship proof incorrectly saved as credit ownership"):return
    world._r15_premium_synced({})
    if not check(world.equipped_r15 == "ship_scout" and
        world.premium_r15.is_empty(),
        "R15 revoked server entitlement failed to remove premium ship"):return
    # R16 guardian repairs must restore purchased heavy-ship capacity.
    world._r15_buy_credit("ship_guardian")
    if not check(world.equipped_r15 == "ship_guardian" and
        world.fleet_r15.ship_hull_cap() == 160.0,
        "R16 heavy ship upgrade did not restore physical hull limits"):return
    world.ship.hull = 115.0
    world.ship.shield = 105.0
    world.credits = 1000 # Prior purchases left insufficient funds for a repair.
    world._upgrade_docked(2)
    if not check(world.ship.hull == 160.0 and world.ship.shield == 140.0 and world.credits == 400,
        "R16 guardian repairs incorrectly capped at scout hull and shields"):return
    var hangar_solid = world.get_node_or_null("HeroMegadocksR6/R6_EnclosedHangar_00_0/HangarLeftWallCollision")
    if not check(hangar_solid is StaticBody3D, "Hangar collision missing"):return
    # R19: existing F3/F11 quality pipeline must update both new layers.
    world._set_graphics_quality(2)
    if not check(premium.r19_quality == 2 and industry.r19_quality == 2 and
        premium.r19_facade_chunks[0].visibility_range_end == 460.0 and
        premium.r19_roof_chunks[0].visibility_range_end == 600.0 and
        industry.r19_batches[0].visibility_range_end == 420.0,
        "R19 auto / manual ECO change did not disable distant architecture"):return
    world._set_graphics_quality(0)
    if not check(premium.r19_quality == 0 and industry.r19_quality == 0 and
        premium.r19_facade_chunks[0].visibility_range_end == 1180.0 and
        industry.r19_batches[0].visibility_range_end == 1020.0,
        "R19 MAX restoration failed"):return
    print("NEBULA_R19_NEAR_SECTOR_SUCCESS premium=%d roofs=%d industrial=%d chunks=%d" % [
        premium.r19_facade_instance_count, premium.r19_roof_instance_count,
        industry.r19_original_instances, industry.r19_sharded_groups])
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
    print("NEBULA_SMOKE_SUCCESS missions=1 upgrades=1 drones=%d premium3d=r16 guided-missiles pooled-beams stable-wingmen throttled-HUD checkout-server-gated" % world.drones.size())
    quit(0)
