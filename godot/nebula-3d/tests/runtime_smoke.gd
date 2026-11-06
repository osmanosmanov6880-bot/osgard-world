extends SceneTree
const SurfaceLibraryR9Script = preload("res://scripts/surface_library_r9.gd")
const MaterialFabricR12Script = preload("res://scripts/material_fabric_r12.gd")
const MaterialStudioR11Script = preload("res://scripts/material_studio_r11.gd")
const CaptainRosterR42Script = preload("res://scripts/captain_roster_r42.gd")
const PilotAcademyR54Script = preload("res://scripts/pilot_academy_r54.gd")
const HangarWorkbenchR56Script = preload("res://scripts/hangar_workbench_r56.gd")
const PatrolContractsR57Script = preload("res://scripts/patrol_contracts_r57.gd")
const CareerPrestigeR58Script = preload("res://scripts/career_prestige_r58.gd")
const FleetCombatR15Script = preload("res://scripts/fleet_combat_r15.gd")
const MissionObjectivesR48Script = preload("res://scripts/mission_objectives_r48.gd")
const PortInvestigationR49Script = preload("res://scripts/port_investigation_r49.gd")
const ArchiveBreachR50Script = preload("res://scripts/archive_breach_r50.gd")
const CourierInterceptR51Script = preload("res://scripts/courier_intercept_r51.gd")
const StationBlackoutR52Script = preload("res://scripts/station_blackout_r52.gd")
const FleetTacticsR50Script = preload("res://scripts/fleet_combat_r15.gd")
const DroneR49TestScript = preload("res://scripts/drone.gd")
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
    if not check(world.garage_open_r39 and world.ship.controls_locked and
        is_instance_valid(world.garage_hub_r39) and
        world.garage_hub_r39.launch_button.text == "▶  ВЫЛЕТЕТЬ",
        "R39 campaign must open in a locked garage hub with an explicit sortie button"):return
    # R57: a real mobile FPS button must remain touchable even when a
    # physical crash returns to the garage. GarageHub is CanvasLayer 30,
    # so a visible profiler on layer 7 would still be occluded by its UI.
    if not check(is_instance_valid(world.performance_lab_r11) and
        world.performance_lab_r11.visible and
        world.performance_lab_r11.layer > world.garage_hub_r39.layer and
        world.performance_lab_r11.layer == 31,
        "R57 garage FPS layer must be above the dock's actual touch surface"):return
    if not check(world.garage_hub_r39.captain_label.text == "КАПИТАН · УРОВЕНЬ 1" and
        world.garage_hub_r39.resource_label.text.contains("950 CR"),
        "R39 captain level and campaign credits are not shown from live progression"):return
    # R44: inspect the real imported NX fighter in its own Godot 3D world.
    var r44_view = world.garage_hub_r39.ship_preview_r44
    if not check(is_instance_valid(r44_view) and
        is_instance_valid(r44_view.preview_viewport) and
        r44_view.preview_viewport.own_world_3d and
        is_instance_valid(r44_view.inspection_camera) and
        r44_view.inspection_camera.current and
        is_instance_valid(r44_view.real_airframe) and
        r44_view.real_airframe.get_child_count() > 0,
        "R44 garage needs the real imported NX mesh and an independent 3D camera"):return
    var real_nodes = r44_view.real_airframe.find_children("*", "MeshInstance3D", true, false)
    if not check(real_nodes.size() >= 1,
        "R44 must render a real imported in-game MeshInstance3D, not a flat art placeholder"):return
    if not check(r44_view.preview_viewport.get_world_3d() != world.get_world_3d(),
        "R44 preview world must be separate from live city collision and pilot physics"):return
    # R54: this must be a REAL 3D hangar, not a photograph or dark sphere.
    var zero_stage = r44_view.hangar_set_r54
    if not check(is_instance_valid(zero_stage) and
        zero_stage.name == "R54_AuroraEnclosedIndustrialHangar" and
        zero_stage.get_node_or_null("R54_Real72mHangarDeck") is MeshInstance3D and
        zero_stage.get_node_or_null("R54_RealRearHangarWall") is MeshInstance3D and
        zero_stage.get_node_or_null("R54_TravellingInspectionCrane") is Node3D and
        is_instance_valid(zero_stage.shadow_key) and
        zero_stage.shadow_key is SpotLight3D,
        "R54 must build actual enclosed 3D hangar with structural deck, real machinery and light"):return
    var zero_meshes: Array = zero_stage.find_children("*", "MeshInstance3D", true, false)
    if not check(zero_meshes.size() >= 80 and
        r44_view.stretch and r44_view.stretch_shrink == 1 and
        r44_view.preview_viewport.own_world_3d,
        "R54 true 3D hangar needs detail geometry and 1:1 resizable WebGL viewport"):return
    var orbit_safe_zoom: float = r44_view.camera_distance_r54
    world.garage_hub_r39.zoom_in_button_r54.pressed.emit()
    if not check(r44_view.camera_distance_r54 < orbit_safe_zoom and
        world.garage_open_r39 and world.ship.controls_locked,
        "R54 camera zoom must never move or unlock the real ship"):return
    world.garage_hub_r39.zoom_out_button_r54.pressed.emit()
    if not check(is_equal_approx(r44_view.camera_distance_r54, orbit_safe_zoom),
        "R54 service camera zoom-out must restore original distance"):return
    zero_stage.set_quality_tier(1)
    if not check(not zero_stage.shadow_key.shadow_enabled,
        "R54 touch tier must disable costly real-time maintenance shadow"):return
    zero_stage.set_quality_tier(0)
    if not check(zero_stage.shadow_key.shadow_enabled,
        "R54 desktop tier must restore real maintenance shadow"):return
    # The shop must be reachable without scrolling, while flight stays locked.
    var r54_wallet: int = world.credits
    var navigator = world.garage_hub_r39
    if not check(is_instance_valid(navigator.shop_header_button_r54) and
        navigator.shop_header_button_r54.visible and
        navigator.resource_label.text.contains("950 CR") and
        navigator.active_section_r54 == "fleet",
        "R54 must show live wallet and accessible shop in the fixed header"):return
    navigator.section_buttons_r54["crew"].pressed.emit()
    if not check(navigator.active_section_r54 == "crew" and
        navigator.captain_card_r54.visible and navigator.academy_panel_r54.visible and
        not navigator.ship_card_r54.visible,
        "R54 crew tab must show academy without piling all screens together"):return
    navigator.section_buttons_r54["operations"].pressed.emit()
    if not check(navigator.introductory_section_r54.visible and
        navigator.mission_card_r54.visible and
        not navigator.captain_card_r54.visible,
        "R54 operations tab must show focused real story briefing"):return
    navigator.section_buttons_r54["fleet"].pressed.emit()
    navigator.shop_header_button_r54.pressed.emit()
    if not check(world.store_r15.visible and not navigator.visible and
        world.credits == r54_wallet and world.garage_open_r39,
        "R54 fixed shop CTA must open existing real-credit shop without spending"):return
    world.store_r15.close()
    if not check(navigator.visible and not world.store_r15.visible and
        navigator.active_section_r54 == "fleet" and world.ship.controls_locked,
        "R54 closing shop must safely restore garage and retain selection"):return
    print("NEBULA_R54_REAL_HANGAR_LAYOUT_WALLET_AND_SHOP_SUCCESS")

    # R45: independent physically distinct geometry in actual dock and flight.
    if not check(is_instance_valid(r44_view.distinct_hull_r45) and
        is_instance_valid(world.ship.hull_kit_r45) and
        r44_view.distinct_hull_r45.selected_hull == "ship_scout" and
        world.ship.hull_kit_r45.selected_hull == "ship_scout",
        "R45 real 3D hull kits missing from dock or playable craft"):return
    var scout_parts: int = r44_view.distinct_hull_r45.visual_parts.size()
    r44_view.set_ship_type("ship_interceptor")
    var interceptor_parts: int = r44_view.distinct_hull_r45.visual_parts.size()
    var actual_twin_engines: int = 0
    for engine_part in r44_view.distinct_hull_r45.visual_parts:
        if is_instance_valid(engine_part) and str(engine_part.name).begins_with(
            "R45_InterceptorTwinThruster_") and engine_part.mesh is CylinderMesh:
            actual_twin_engines += 1
    if not check(interceptor_parts != scout_parts and actual_twin_engines == 2,
        "R45 interceptor must have physical twin engines and distinct geometry"):return
    r44_view.set_ship_type("ship_guardian")
    var guardian_parts: int = r44_view.distinct_hull_r45.visual_parts.size()
    if not check(guardian_parts > interceptor_parts and
        r44_view.distinct_hull_r45.get_node_or_null(
            "R45_GuardianDorsalBridge") != null,
        "R45 heavy guardian must have more substantial physical armored mesh"):return
    r44_view.set_ship_type("ship_scout")
    var starting_wallet: int = world.credits
    world.garage_hub_r39.ship_choice_buttons_r45["ship_interceptor"].pressed.emit()
    if not check(world.equipped_r15 == "ship_scout" and
        world.credits == starting_wallet and
        world.garage_hub_r39.ship_choice_buttons_r45["ship_interceptor"].disabled,
        "R45 disabled or unowned ship cannot be equipped for free"):return
    world.garage_hub_r39.ship_choice_buttons_r45["ship_scout"].pressed.emit()
    if not check(world.garage_open_r39 and world.ship.controls_locked and
        world.ship.hull_kit_r45.selected_hull == "ship_scout",
        "R45 garage selection must never bypass launch lock"):return
    print("NEBULA_R45_DISTINCT_HULLS_SUCCESS scout=%d interceptor=%d guardian=%d" %
        [scout_parts, interceptor_parts, guardian_parts])
    # R55: three genuinely distinct sculpted fuselages. The imported NX08
    # legacy template must NOT be the active mesh for NX12/NX21, either in
    # isolated garage inspection or real physics-driven flight.
    var r55_gallery = r44_view.primary_airframe_r55
    var r55_flight = world.ship.primary_airframe_r55
    if not check(is_instance_valid(r55_gallery) and
        is_instance_valid(r55_flight) and
        not r44_view.real_airframe.visible and
        not r44_view.distinct_hull_r45.visible and
        r55_gallery.core_mesh.mesh is ArrayMesh and
        r55_flight.core_mesh.mesh is ArrayMesh and
        r55_gallery.active_body.visible and
        r55_flight.active_body.visible and
        not world.ship.visual.get_node("HighDetailInterceptorR5").visible and
        not world.ship.hull_kit_r45.visible,
        "R55 must replace both old shared core airframes without deleting rollback data"):return
    var r55_core_meshes: Array[Mesh] = []
    var signatures: Array[String] = []
    var wing_spans: Array[float] = []
    var engine_counts: Array[int] = []
    var hull_choices: Array[String] = ["ship_scout","ship_interceptor","ship_guardian"]
    var prior_credits: int = world.credits
    var prior_ship: String = world.equipped_r15
    for hull_id in hull_choices:
        r44_view.set_ship_type(hull_id)
        world.ship.set_hull_variant(hull_id)
        if not check(r55_gallery.selected_hull == hull_id and
            r55_flight.selected_hull == hull_id and
            r55_gallery.real_parts.size() > 10 and
            r55_flight.real_parts.size() > 10 and
            r55_gallery.core_mesh.mesh is ArrayMesh and
            r55_flight.core_mesh.mesh is ArrayMesh and
            r55_gallery.core_mesh.get_parent() == r55_gallery.active_body,
            "R55 every hull must create actual multi-surface 3D parts"):return
        var real_mesh: Mesh = r55_gallery.core_mesh.mesh
        var mesh_arrays: Array = real_mesh.surface_get_arrays(0)
        var vertex_buffer: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
        if not check(vertex_buffer.size() > 130 and
            r55_gallery.visual_signature == r55_flight.visual_signature and
            r55_gallery.thruster_plumes.size() == r55_gallery.engine_count and
            r55_flight.thruster_plumes.size() == r55_flight.engine_count,
            "R55 unique hull must be a triangulated volume with correct engine count"):return
        signatures.append(r55_gallery.visual_signature)
        wing_spans.append(r55_gallery.half_span_m)
        engine_counts.append(r55_gallery.engine_count)
        r55_core_meshes.append(real_mesh)
        r55_flight.set_throttle(0.80, true)
        if not check(r55_flight.thruster_plumes[0].visible and
            r55_flight.thruster_plumes[0].scale.y > 1.5,
            "R55 real ship must have throttle-reactive engine light geometry"):return
    if not check(signatures.size() == 3 and
        signatures[0] != signatures[1] and signatures[1] != signatures[2] and
        signatures[0] != signatures[2] and
        wing_spans[0] < wing_spans[1] and wing_spans[1] < wing_spans[2] and
        engine_counts == [1,2,4] and
        r55_core_meshes[0] != r55_core_meshes[1] and
        r55_core_meshes[1] != r55_core_meshes[2] and
        world.credits == prior_credits and world.equipped_r15 == prior_ship,
        "R55 bodies, aerodynamic silhouettes and engines must differ without free purchases"):return
    r55_gallery.set_low_detail(true)
    if not check(not r55_gallery.detail_parts[0].visible and
        r55_gallery.core_mesh.visible,
        "R55 touch detail tier may hide only tiny service parts, never wing meshes"):return
    r55_gallery.set_low_detail(false)
    r44_view.set_ship_type("ship_scout")
    world.ship.set_hull_variant("ship_scout")
    if not check(r55_gallery.selected_hull == "ship_scout" and
        r55_flight.selected_hull == "ship_scout" and
        world.garage_open_r39 and world.ship.controls_locked,
        "R55 switching among full airframes must keep safe garage flight lock"):return
    print("NEBULA_R55_THREE_DISTINCT_3D_CORES_AND_REACTIVE_THRUSTERS_SUCCESS")
    # R46: the comparison must read the SAME fleet limits used by actual
    # combat, without inventing health, shields or premium ownership.
    var real_scout: Dictionary = FleetCombatR15Script.hull_profile("ship_scout")
    var real_interceptor: Dictionary = FleetCombatR15Script.hull_profile("ship_interceptor")
    var real_guardian: Dictionary = FleetCombatR15Script.hull_profile("ship_guardian")
    if not check(real_scout["hull"] == 100.0 and
        real_interceptor["turn_speed"] == 2.4 and
        real_guardian["hull"] == FleetCombatR15Script.hull_profile("ship_guardian")["hull"] and
        real_guardian["hull"] == 160.0 and real_guardian["shield"] == 140.0,
        "R46 ship comparison must be derived from real playable physics"):return
    if not check(not world.garage_hub_r39.comparison_detail_r46.visible and
        world.garage_hub_r39.readiness_label_r46.text.contains("УРОН 4.0") and
        world.garage_hub_r39.readiness_label_r46.text.contains("ВЕДОМЫЕ 0 ИЗ 2"),
        "R46 briefing must be concise and grounded in real equipment"):return
    world.garage_hub_r39.comparison_toggle_r46.pressed.emit()
    if not check(world.garage_hub_r39.comparison_detail_r46.visible and
        world.garage_hub_r39.comparison_detail_r46.text.contains("NX-21") and
        world.garage_hub_r39.comparison_detail_r46.text.contains("КОРПУС 160") and
        world.garage_hub_r39.comparison_detail_r46.text.contains("ЗАКРЫТ"),
        "R46 must reveal three real loadout profiles without granting ships"):return
    world.garage_hub_r39.comparison_toggle_r46.pressed.emit()
    if not check(not world.garage_hub_r39.comparison_detail_r46.visible and
        world.equipped_r15 == "ship_scout" and world.credits == starting_wallet and
        world.garage_open_r39 and world.ship.controls_locked,
        "R46 compare toggle must not spend money or start a sortie"):return
    print("NEBULA_R46_TRUE_FLEET_COMPARISON_SUCCESS")
    # R48: independent three-mechanic objective engine. These are real
    # proximity+time, moving vulnerable target and staged rescue conditions.
    var objectives_r48 = MissionObjectivesR48Script.new()
    world.add_child(objectives_r48)
    objectives_r48.configure("scan", Vector3(400, 37, 800))
    if not check(objectives_r48.marker_nodes.size() == 3 and
        objectives_r48.marker_nodes[0].get_node_or_null(
            "R48_RealSignalCore") is MeshInstance3D and
        objectives_r48.step(0.25, Vector3(0, 0, 0)) == "running" and
        objectives_r48.stage == 0,
        "R48 scan must create 3 actual 3D probes and reject remote completion"):return
    for point_index in 3:
        var scan_goal: Vector3 = objectives_r48.objective_position()
        var scan_result: String = ""
        for sample in 10:
            scan_result = objectives_r48.step(0.25, scan_goal)
            if scan_result == "success":
                break
        if not check(objectives_r48.stage == point_index + 1 and
            not objectives_r48.marker_nodes[point_index].visible and
            (scan_result == "success") == (point_index == 2),
            "R48 multi-probe scan must require three separate timed holds"):return
    if not check(objectives_r48.step(0.25, objectives_r48.destination) ==
        "inactive", "R48 completed scan must not award twice"):return
    objectives_r48.configure("evacuation", Vector3(650, 30, -330))
    var rescue_pickup: Vector3 = objectives_r48.objective_position()
    if not check(objectives_r48.step(0.25, objectives_r48.destination) ==
        "running" and objectives_r48.stage == 0,
        "R48 evac must not complete at its old one-shot destination"):return
    for sample in 10:
        objectives_r48.step(0.25, rescue_pickup)
    if not check(objectives_r48.stage == 1 and
        objectives_r48.marker_nodes[0].visible == false and
        objectives_r48.marker_nodes[1].visible and
        objectives_r48.step(0.25, rescue_pickup) == "running",
        "R48 rescue must pick up people before shelter delivery"):return
    var shelter: Vector3 = objectives_r48.objective_position()
    var evac_result: String = ""
    for sample in 10:
        evac_result = objectives_r48.step(0.25, shelter)
        if evac_result == "success":
            break
    if not check(evac_result == "success" and objectives_r48.stage == 2,
        "R48 rescue cannot finish without a real second hold at shelter"):return
    objectives_r48.configure("escort", Vector3(-500, 24, 670))
    var convoy_start: Vector3 = objectives_r48.global_position
    if not check(objectives_r48.moving_convoy.get_node_or_null(
        "R48_VisibleCivilianHull") is MeshInstance3D and
        objectives_r48.step(0.25, Vector3(2000, 0, 2000)) == "running" and
        objectives_r48.global_position == convoy_start,
        "R48 convoy must be an actual 3D craft that waits for the escort"):return
    objectives_r48.take_damage(-100.0)
    if not check(is_equal_approx(objectives_r48.escort_health, 200.0),
        "R48 convoy integrity must reject negative enemy damage"):return
    objectives_r48.step(0.25, convoy_start)
    if not check(objectives_r48.convoy_started and
        objectives_r48.global_position.distance_to(convoy_start) > 0.1,
        "R48 convoy must physically advance when the pilot joins"):return
    objectives_r48.take_damage(999.0)
    if not check(objectives_r48.step(0.25,
            objectives_r48.global_position) == "failed" and
        objectives_r48.escort_health == 0.0,
        "R48 destroyed convoy must fail rather than silently win"):return
    objectives_r48.configure("escort", Vector3(-500, 24, 670))
    var convoy_result: String = "running"
    for sample in 85:
        convoy_result = objectives_r48.step(
            0.25, objectives_r48.global_position)
        if convoy_result == "success":
            break
    if not check(convoy_result == "success" and
        objectives_r48.escort_health > 0.0,
        "R48 escort requires real convoy arrival with positive integrity"):return
    objectives_r48.queue_free()
    print("NEBULA_R48_THREE_REAL_OBJECTIVE_ENGINES_SUCCESS")
    # R47: two real 3D craft bays, empty until an owned crew is assigned.
    var bays_r47 = r44_view.formation_bays_r47
    if not check(is_instance_valid(bays_r47) and
        bays_r47.craft_nodes.size() == 2 and
        bays_r47.assigned_ids.is_empty() and
        not bays_r47.craft_nodes[0].visible and
        not bays_r47.craft_nodes[1].visible and
        bays_r47.get_node_or_null("R47_FormationBay_0/R47_RealLandingPad")
        is MeshInstance3D and
        bays_r47.get_node_or_null(
            "R47_FormationBay_1/R47_RealWingmanCraft_1/R47_ActualCombatWing")
        is MeshInstance3D,
        "R47 must create real 3D unoccupied bays in the isolated hangar"):return
    var r47_money_before: int = world.credits
    var locked_ace: Button = world.garage_hub_r39.wingman_choice_buttons_r47[
        "wingman_ace"]
    if not check(locked_ace.disabled, "R47 must visually lock unowned ACE"):return
    locked_ace.pressed.emit() # A programmatic signal must not bypass authorization.
    world._r47_toggle_owned_wingman("not_real_crew")
    if not check(world.wingmen_r15.is_empty() and
        world.fleet_r15.helper_ids.is_empty() and
        world.credits == r47_money_before and world.garage_open_r39,
        "R47 unowned wingmen cannot join via forged UI signals"):return
    # Temporary test ownership represents a previously completed honest
    # credit purchase. It is REMOVED and the old v1 save is restored below.
    world.owned_r15["wingman_escort"] = true
    world._r39_refresh_garage()
    var owned_escort: Button = world.garage_hub_r39.wingman_choice_buttons_r47[
        "wingman_escort"]
    if not check(not owned_escort.disabled,
        "R47 legitimate inventory must unlock its formation control"):return
    owned_escort.pressed.emit()
    if not check(not world.fleet_r15.combat_active,
        "R47 garage must inhibit ally weapons even after lawful squad selection"):return
    if not check(world.wingmen_r15.size() == 1 and
        world.wingmen_r15[0] == "wingman_escort" and
        world.fleet_r15.helper_ids.size() == 1 and
        world.fleet_r15.helper_ids[0] == "wingman_escort" and
        bays_r47.assigned_ids.size() == 1 and
        bays_r47.craft_nodes[0].visible and
        not bays_r47.craft_nodes[1].visible and
        world.credits == r47_money_before and
        world.ship.controls_locked,
        "R47 owned escort must synchronize UI, 3D bay and real flight ally"):return
    owned_escort.pressed.emit()
    if not check(world.wingmen_r15.is_empty() and
        world.fleet_r15.helper_ids.is_empty() and
        bays_r47.assigned_ids.is_empty() and
        not bays_r47.craft_nodes[0].visible and
        world.credits == r47_money_before and
        world.ship.controls_locked,
        "R47 removing wingman must update 3D and live combat without credits"):return
    world.owned_r15.erase("wingman_escort")
    world._r15_apply_loadout()
    world._r39_refresh_garage()
    world._save_progress()
    print("NEBULA_R47_ACTUAL_FORMATION_SUCCESS")
    var original_orbit: float = r44_view.orbit_angle
    world.garage_hub_r39.turn_right_r44.pressed.emit()
    if not check(r44_view.orbit_angle > original_orbit + 0.30 and
        world.ship.controls_locked and world.garage_open_r39,
        "R44 real 3D orbit control must not accidentally unlock or move the game ship"):return
    r44_view.set_ship_type("ship_interceptor")
    if not check(r44_view.selected_hull == "ship_interceptor" and
        is_instance_valid(r44_view.real_airframe),
        "R44 selection must preserve real model and reflect existing owned hull"):return
    r44_view.set_ship_type("unsupported_premium_ship")
    if not check(r44_view.selected_hull == "ship_scout",
        "R44 inspection must reject invented, unowned or unsupported hull ids"):return
    world._r39_refresh_garage()
    if not check(r44_view.selected_hull == world.equipped_r15,
        "R44 garage preview must follow saved equipped ship without changing purchases"):return
    print("NEBULA_R44_REAL_HANGAR_SUCCESS imported_meshes=%d orbit=%.3f" % [
        real_nodes.size(), r44_view.orbit_angle])
    # R42: selection is a real Godot Button signal, not a decorative mockup.
    var kai_button: Button = world.garage_hub_r39.captain_choice_buttons["kai"]
    kai_button.pressed.emit()
    if not check(world.selected_captain_r42 == "kai" and
        world.garage_hub_r39.captain_role_label.text.contains("КАЙ") and
        world.garage_hub_r39.captain_bonus_label.text.contains("8%"),
        "R42 interactive captain selection does not update the real garage"):return
    world._r42_select_captain("not_a_captain")
    if not check(world.selected_captain_r42 == "kai",
        "R42 illegal captain selection must fail closed"):return
    if not check(CaptainRosterR42Script.reward(350, "leya") == 392 and
        CaptainRosterR42Script.reward(350, "ada") == 350,
        "R42 free engineer mission credits must use the real deterministic bonus"):return
    world._r39_open_shop()
    if not check(world.store_r15.visible and not world.garage_hub_r39.visible and
        world.ship.controls_locked,
        "R39 shop must replace the garage while keeping flight locked"):return
    world.store_r15.close()
    if not check(world.garage_hub_r39.visible and world.ship.controls_locked,
        "R39 shop close must return to the locked garage"):return
    # R41: zero hostile objective actors while the first briefing is open.
    if not check(not world.mission_started and world.mission_enemies == 0,
        "R41 must defer mission spawning until an explicit sortie"):return
    if not check(world.garage_hub_r39.story_label.text.contains("АДА ВЕЙЛ") and
        world.garage_hub_r39.objective_label.text.contains("Долететь"),
        "R41 authored story and objective are missing from garage"):return
    world._r39_launch_sortie()
    if not check(world.r47_launch_camera_time > 1.0 and
        world.fleet_r15.combat_active and
        not world.garage_open_r39 and not world.ship.controls_locked,
        "R47 camera reveal must start with real unlocked immediate Godot flight"):return
    if not check(not world.garage_open_r39 and not world.ship.controls_locked,
        "R39 sortie action did not unlock flight"):return
    if not check(is_equal_approx(world.ship.thrust_multiplier, 1.08) and
        is_equal_approx(world.ship.damage_multiplier, 1.0),
        "R42 Kai's acceleration perk must apply to actual physics"):return
    # R21 approved Aurora: the ship starts in a physically clear corridor,
    # does respond to throttle, and the chase camera cannot remain behind
    # opaque collision geometry.
    if not check(world.ship.motion_mode == CharacterBody3D.MOTION_MODE_FLOATING and
        world.ship.FORWARD_ACCEL >= 65.0 and
        world.ship.NORMAL_SPEED >= 90.0 and
        world.ship.AFTERBURNER_SPEED >= 140.0,
        "R21 inertial spaceship movement was not installed"):return
    if not check(world.r21_ui_font is SystemFont and
        world.r21_objective_panel != null and
        world.get_node_or_null("PlayerShip/AnimatedShip/HighDetailInterceptorR5") != null,
        "R21 approved premium fonts, objective and real NX08 ship absent"):return
    if not check(world.r21_dashboard != null and
        world.r21_dashboard.cached_font is SystemFont and
        world.r21_touch != null and
        world.r21_touch.button_centres.size() == 9,
        "R21 mobile multi-touch and premium flight dashboard missing"):return
    var collider_probe := SphereShape3D.new()
    collider_probe.radius = 1.8
    var collision_query := PhysicsShapeQueryParameters3D.new()
    collision_query.shape = collider_probe
    collision_query.exclude = [world.ship.get_rid()]
    collision_query.transform = Transform3D(Basis.IDENTITY, world.ship.global_position)
    if not check(world.get_world_3d().direct_space_state.intersect_shape(collision_query, 1).is_empty(),
        "R21 player spawns stuck inside a building; flight cannot start"):return
    if not check(world.r21_safe_spawn == world.ship.global_position and
        world.r21_safe_spawn.y >= 30.0,
        "R21 collision-aware launch was not installed"):return
    var pad_position: Vector3 = world.ship.global_position
    # A real physics-frame test, not a fake velocity assignment.
    world.ship.set_touch_controls(Vector2.ZERO, 1.0, 0.0, false, false)
    for tick in 37:
        await physics_frame
    var travelled: float = world.ship.global_position.distance_to(pad_position)
    if not check(travelled >= 6.0 and world.ship.flight_distance >= travelled,
        "R21 ship still cannot move forward through the playable launch corridor"):return
    world.ship.clear_touch_controls()
    world.ship.velocity = Vector3.ZERO
    world.ship.global_position = pad_position
    var touch_r21 = world.r21_touch
    touch_r21.force_mobile_for_tests(true)
    touch_r21._set_touch(0, touch_r21.stick_center, true)
    touch_r21._drag_touch(0, touch_r21.stick_center + Vector2(20,-20))
    touch_r21._set_touch(1, touch_r21.button_centres["THRUST"], true)
    touch_r21._set_touch(2, touch_r21.button_centres["BOOST"], true)
    if not check(touch_r21.active_touch_count == 3 and
        world.ship.touch_throttle == 1.0 and world.ship.touch_boost and
        absf(world.ship.touch_steering.x) > 0.1,
        "R21 two-finger phone throttle, joystick and boost cannot be combined"):return
    for finger in 3:
        touch_r21._set_touch(finger, Vector2.ZERO, false)
    if not check(touch_r21.active_touch_count == 0 and
        not world.ship.touch_boost and
        absf(world.ship.touch_throttle) < 0.01,
        "R21 touch release left ship controls stuck"):return
    # R30: interrupted touches must never leave throttle, boost or fire stuck.
    touch_r21._set_touch(5, touch_r21.button_centres["THRUST"], true)
    touch_r21._set_touch(6, touch_r21.button_centres["BOOST"], true)
    touch_r21._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    if not check(touch_r21.active_touch_count == 0 and
        touch_r21.finger_roles.is_empty() and
        world.ship.touch_throttle == 0.0 and not world.ship.touch_boost,
        "R30 focus loss must release held mobile thrust and boost"):return
    touch_r21._set_touch(5, touch_r21.button_centres["THRUST"], true)
    touch_r21.set_shop_open(true)
    if not check(touch_r21.active_touch_count == 0 and
        world.ship.touch_throttle == 0.0,
        "R30 hangar must clear mobile touch counters and throttle"):return
    touch_r21.set_shop_open(false)
    # R34: opening a hangar cancels held controls. The next real touch
    # must not be swallowed when it was already finger-free at close.
    touch_r21.r34_ignore_until_all_released = true
    if not check(touch_r21._r34_gate_stale_contacts([[1, 12.0, 14.0]]) and
        touch_r21.r34_ignore_until_all_released,
        "R34 hangar must reject contacts that were held before closing"):return
    if not check(touch_r21._r34_gate_stale_contacts([]) and
        not touch_r21.r34_ignore_until_all_released,
        "R34 finger-free hangar close must allow the next independent tap"):return
    if not check(not touch_r21._r34_gate_stale_contacts([]),
        "R34 browser touch bridge remains blocked after hangar release"):return
    touch_r21.force_mobile_for_tests(false)
    if not check(world.r21_towers_moved >= 0,
        "R21 original tower count and spawn corridor audit missing"):return
    print("NEBULA_R21_REAL_FLIGHT_SUCCESS throttle_metres=%.1f mobile_3_touch=verified" % travelled)
    # R23: the production failure mode is real physical keyboard input,
    # especially Russian layouts. This test sends actual input events to Godot,
    # rather than setting velocity or calling ship._physics_process directly.
    if not check(world.ship.keyboard_samples > 0,
        "R23 ship physical input diagnostics missing"):return
    var physical_key := InputEventKey.new()
    physical_key.physical_keycode = KEY_W
    physical_key.pressed = true
    Input.parse_input_event(physical_key)
    var keyboard_start: Vector3 = world.ship.global_position
    for frame in 29:
        await physics_frame
    physical_key.pressed = false
    Input.parse_input_event(physical_key)
    await process_frame # Let Godot consume the release before enabling cruise.
    var keyboard_meters: float = world.ship.global_position.distance_to(keyboard_start)
    if not check(keyboard_meters > 2.0 and
        world.ship.keyboard_samples >= 29 and
        world.ship.flight_distance > travelled,
        "R23 real physical W key never moves ship: Cyrillic keyboard still blocked"):return
    world.ship.velocity = Vector3.ZERO
    world.ship.global_position = pad_position
    # Earlier touch checks intentionally yaw the craft. Reset heading so this
    # isolated R24 assertion always starts with an off-axis beacon.
    world.ship.rotation = Vector3.ZERO
    world.ship.yaw_rate = 0.0
    world.ship.pitch_rate = 0.0
    world.ship.clear_touch_controls()
    world.ship.touch_enabled = false
    # Test the actual clickable fallback signal, no fake throttle assignment.
    if not check(world.r23_cruise_button is Button and
        world.r23_cruise_button.text.begins_with("▶"),
        "R23 no visible start-flight button for desktop keyboard failures"):return
    world.r23_cruise_button.pressed.emit()
    if not check(world.ship.navigation_target_valid and
        world.ship.navigation_target == world.MISSIONS[0]["position"],
        "R24 start-flight must navigate toward actual mission beacon"):return
    if not check(world.ship.cruise_assist and
        world.r23_launch_button_events == 1,
        "R23 start-flight UI button not wired to real physics"):return
    var before_cruise: Vector3 = world.ship.global_position
    for frame in 28:
        await physics_frame
    var cruise_meters: float = world.ship.global_position.distance_to(before_cruise)
    if not check(world.ship.navigation_steer_frames > 0 and
        world.ship.last_pilot_yaw > 0.01,
        "R24 launch button must actively steer ship toward off-axis beacon"):return
    if not check(cruise_meters > 2.0 and
        world.ship.cruise_distance > 2.0,
        "R23 clicked START FLIGHT but the ship stayed at 000 km/h"):return
    world.r23_cruise_button.pressed.emit()
    if not check(not world.ship.cruise_assist and
        world.r23_launch_button_events == 2,
        "R23 launch button cannot disengage autopilot"):return
    world.ship.set_cruise_assist(true)
    var manual_key := InputEventKey.new()
    manual_key.physical_keycode = KEY_W
    manual_key.keycode = KEY_W
    manual_key.pressed = true
    Input.parse_input_event(manual_key)
    await physics_frame
    manual_key.pressed = false
    Input.parse_input_event(manual_key.duplicate())
    await process_frame
    if not check(not world.ship.cruise_assist and
        world.ship.last_pilot_throttle > 0.05,
        "Manual thrust must disengage autopilot"):return
    world.ship.velocity = Vector3.ZERO
    world.ship.global_position = pad_position
    touch_r21.force_mobile_for_tests(true)
    touch_r21._layout_for_size(Vector2(844.0,390.0))
    if not check(touch_r21.r23_landscape_layout and
        touch_r21.button_centres.size() == 9,
        "R23 responsive mobile landscape flight controls missing"):return
    var min_target_gap: float = touch_r21.base_radius * 1.4
    for a_key in touch_r21.button_centres:
        for b_key in touch_r21.button_centres:
            if str(a_key) < str(b_key):
                if not check(touch_r21.button_centres[a_key].distance_to(
                    touch_r21.button_centres[b_key]) > min_target_gap,
                    "R23 landscape controls overlap: phones cannot use gas and weapons"):return
    touch_r21._set_touch(7, touch_r21.button_centres["THRUST"], true)
    touch_r21._layout_for_size(Vector2(390.0,844.0))
    if not check(touch_r21.active_touch_count == 0 and
        world.ship.touch_throttle == 0.0 and
        touch_r21.finger_roles.is_empty(),
        "R30 orientation change must cancel stale touch controls"):return
    if not check(not touch_r21.r23_landscape_layout and
        touch_r21.button_centres.has("CRUISE"),
        "R23 portrait phone lacks touch start-flight control"):return
    touch_r21._set_touch(3, touch_r21.button_centres["CRUISE"], true)
    touch_r21._set_touch(3, touch_r21.button_centres["CRUISE"], false)
    if not check(world.ship.cruise_assist,
        "R23 phone START FLIGHT did not engage real physics"):return
    touch_r21._set_touch(3, touch_r21.button_centres["CRUISE"], true)
    touch_r21._set_touch(3, touch_r21.button_centres["CRUISE"], false)
    if not check(not world.ship.cruise_assist,
        "R23 phone cruise button cannot switch propulsion off"):return
    # R32: compact real phone landscapes previously used portrait geometry,
    # placing CRUISE on top of GAS at 568x320.
    touch_r21._layout_for_size(Vector2(568.0, 320.0))
    if not check(touch_r21.r23_landscape_layout and
        touch_r21.button_centres.size() == 9 and
        touch_r21._role_at(touch_r21.button_centres["THRUST"]) == "THRUST" and
        touch_r21._role_at(touch_r21.button_centres["CRUISE"]) == "CRUISE",
        "R32 compact landscape must distinguish GAS from CRUISE"):return
    var compact_button_gap: float = touch_r21.base_radius * 1.4
    for a_key in touch_r21.button_centres:
        var a_centre: Vector2 = touch_r21.button_centres[a_key]
        if not check(a_centre.x > 20.0 and a_centre.x < 548.0 and
            a_centre.y > 20.0 and a_centre.y < 300.0 and
            touch_r21._role_at(a_centre) == a_key,
            "R32 compact landscape has an unreachable action button"):return
        for b_key in touch_r21.button_centres:
            if str(a_key) < str(b_key):
                if not check(a_centre.distance_to(
                    touch_r21.button_centres[b_key]) > compact_button_gap,
                    "R32 compact landscape action hit targets overlap"):return
    touch_r21._set_touch(8, touch_r21.button_centres["THRUST"], true)
    if not check(world.ship.touch_throttle >= 0.9 and
        not world.ship.cruise_assist,
        "R32 small-landscape GAS accidentally triggers autopilot"):return
    touch_r21._set_touch(8, touch_r21.button_centres["THRUST"], false)
    if not check(world.ship.touch_throttle == 0.0,
        "R32 compact-landscape GAS release remains stuck"):return
    # R35: physical notch/system gesture cutouts must not swallow buttons.
    # Exercise the real Godot hit-testing map; no screenshot geometry guesses.
    var r35_cases: Array[Dictionary] = [
        {"size": Vector2(390, 844), "safe": Vector4(0, 62, 0, 34),
            "landscape": false, "compact": false},
        {"size": Vector2(568, 320), "safe": Vector4(59, 0, 59, 21),
            "landscape": true, "compact": false},
        {"size": Vector2(568, 320), "safe": Vector4(59, 60, 59, 34),
            "landscape": true, "compact": false},
        {"size": Vector2(320, 480), "safe": Vector4(0, 62, 0, 34),
            "landscape": false, "compact": true},
        {"size": Vector2(280, 420), "safe": Vector4(0, 55, 0, 34),
            "landscape": false, "compact": true},
        {"size": Vector2(844, 390), "safe": Vector4.ZERO,
            "landscape": true, "compact": false}
    ]
    var verified_r35: int = 0
    for setup in r35_cases:
        var dims: Vector2 = setup["size"]
        var safe: Vector4 = setup["safe"]
        touch_r21.set_safe_insets(safe)
        touch_r21._layout_for_size(dims)
        if not check(touch_r21.button_centres.size() == 9 and
            touch_r21.r23_landscape_layout == bool(setup["landscape"]) and
            touch_r21.r35_compact_portrait == bool(setup["compact"]),
            "R35 mobile orientation or compact portrait grid wrong"):return
        var radius: float = touch_r21.base_radius
        var margin: float = radius * 0.80
        var stick: Vector2 = touch_r21.stick_center
        if not check(stick.x - radius * 1.45 >= safe.x and
            stick.y - radius * 1.45 >= safe.y and
            stick.x + radius * 1.45 <= dims.x - safe.z and
            stick.y + radius * 1.45 <= dims.y - safe.w,
            "R35 joystick intersects physical safe-area cutout"):return
        for action in touch_r21.button_centres:
            var point: Vector2 = touch_r21.button_centres[action]
            if not check(point.x - margin >= safe.x and
                point.y - margin >= safe.y and
                point.x + margin <= dims.x - safe.z and
                point.y + margin <= dims.y - safe.w and
                touch_r21._role_at(point) == action,
                "R35 action button is hidden by screen notch/gesture bar"):return
            if not check(point.distance_to(stick) >
                radius * 1.45 + margin + 3.0,
                "R35 left steering stick overlaps action buttons"):return
            for other in touch_r21.button_centres:
                if str(action) < str(other):
                    if not check(point.distance_to(
                        touch_r21.button_centres[other]) > margin * 2.0,
                        "R35 two action hit targets overlap"):return
        touch_r21._set_touch(99, touch_r21.button_centres["THRUST"], true)
        if not check(world.ship.touch_throttle >= 0.9 and
            not world.ship.cruise_assist,
            "R35 GAS hits a different button on notched phone"):return
        touch_r21._set_touch(99, touch_r21.button_centres["THRUST"], false)
        if not check(world.ship.touch_throttle == 0.0,
            "R35 GAS sticks after finger release"):return
        verified_r35 += 1
    # Production mission HUD must not cover landscape GAS/ANGAR controls.
    touch_r21.set_safe_insets(Vector4(59, 0, 59, 21))
    world.r21_mobile_enabled = true
    world.r31_touch_web = true
    world.r31_mobile_css_size = Vector2i(568, 320)
    world._fit_hud()
    touch_r21._layout_for_size(Vector2(568, 320))
    if not check(world.hud_panel.offset_left >= 59.0 and
        world.hud_panel.offset_right + 2.0 <
        touch_r21.button_centres["HANGAR"].x - touch_r21.base_radius * 0.8,
        "R35 short-landscape HUD blocks the hangar touch target"):return
    touch_r21.set_safe_insets(Vector4(0, 62, 0, 34))
    world.r31_mobile_css_size = Vector2i(320, 480)
    world._fit_hud()
    if not check(world.hud_panel.offset_top >= 62.0 and
        world.hud_panel.offset_right <= 320.0 and
        world.hud_panel.offset_bottom < 230.0,
        "R35 portrait mission HUD is under camera notch"):return
    world.r21_mobile_enabled = false
    world.r31_touch_web = false
    world.r31_mobile_css_size = Vector2i.ZERO
    touch_r21.set_safe_insets(Vector4.ZERO)
    world._fit_hud()
    touch_r21.force_mobile_for_tests(false)
    print("NEBULA_R35_SAFE_AREA_SUCCESS viewports=%d buttons=9 HUD=verified" % verified_r35)
    print("NEBULA_R23_REAL_INPUT_SUCCESS physical_W_metres=%.1f clicked_cruise_metres=%.1f portrait_landscape=verified" % [
        keyboard_meters,cruise_meters])

    # R22: the approved second reference is implemented as *actual* Godot
    # scene meshes, not another image. Check dynamic geometry and collisions.
    var scenic = world.get_node_or_null("R22_PhysicalGoldenAurora")
    if not check(scenic != null and scenic.hero_towers == 18 and
        scenic.overpass_count == 3 and scenic.physical_structures == 21 and
        scenic.real_3d_windows >= 2000 and scenic.r23_glazed_hero_towers == 18 and
        scenic.r23_glass.albedo_texture != null and
        scenic.r23_glass.emission_texture != null,
        "R22 golden-hour Aurora real PBR buildings/bridges/windows missing"):return
    if not check(scenic.real_3d_windows == 11064 and
        scenic.r25_side_and_back_windows == 7837 and
        scenic.r25_window_faces == 1844,
        "R25 all-four-sides PBR windows absent from 18 real towers"):return
    if not check(world.has_method("_r25_emit_browser_flight_state") and
        world.r25_telemetry_samples == 0,
        "R25 browser-only true physics telemetry must not run in native editor"):return
    print("NEBULA_R25_FOUR_FACADES_SUCCESS: modeled_windows=%d back_side=%d faces=%d" % [
        scenic.real_3d_windows, scenic.r25_side_and_back_windows,
        scenic.r25_window_faces])
    if not check(scenic.moving_traffic == 16 and scenic.cloud_banks == 4 and
        scenic.cloud_nodes[0].mesh is Mesh,
        "R22 atmospheric scene still lacks actual 3D clouds and moving air traffic"):return
    if not check(scenic.get_node_or_null(
        "R22_AuroraPhysicalStructures/R22_PhysicalAuroraTower_00/R22_TowerBody")
        is StaticBody3D,
        "R22 skyline towers must have real physical collision bodies"):return
    if not check(scenic.get_node_or_null(
        "R22_AuroraPhysicalStructures/R22_SuspendedFlightway_00/R22_PhysicalFlightway")
        is StaticBody3D,
        "R22 real suspended flightways must have physical collision"):return
    var ambient_0: Vector3 = scenic.traffic_nodes[0].position
    scenic._process(0.1)
    if not check(scenic.traffic_nodes[0].position != ambient_0 and
        scenic.traffic_updates > 0,
        "R22 skyline traffic must move in the actual Godot world"):return
    var ion_drive = world.ship.get_node_or_null(
        "AnimatedShip/HighDetailInterceptorR5/R22_RealIonDrive")
    if not check(ion_drive != null and ion_drive.plume_count == 6 and
        ion_drive.nozzle_parts == 9 and
        ion_drive.heat_light is OmniLight3D,
        "R22 NX08 still lacks actual animated 3D propulsion geometry"):return
    world.ship.thruster_power = 0.0
    world.ship.velocity = Vector3.ZERO
    ion_drive._process(0.1)
    if not check(not ion_drive.flame_nodes[0].visible and
        ion_drive.heat_light.light_energy < 0.04,
        "R23 engine renders giant white/blue jet cones while ship stands still"):return
    world.ship.thruster_power = 1.0
    ion_drive._process(0.1)
    if not check(ion_drive.flame_nodes[0].visible and
        ion_drive.flame_nodes[0].scale.y > 0.60,
        "R23 realistic ion jets do not animate after actual throttle input"):return
    world.ship.thruster_power = 0.0
    var golden_sky = world.get_node("R11_CinematicWorldEnvironment").environment
    var sunset: ProceduralSkyMaterial = golden_sky.sky.sky_material
    var golden_sun := world.get_node("OrbitalSun") as DirectionalLight3D
    if not check(sunset.sky_horizon_color.b >= 0.50 and
        sunset.sky_horizon_color.b > sunset.sky_horizon_color.r and
        golden_sky.fog_light_color.b > golden_sky.fog_light_color.r and
        golden_sun.light_color.r > golden_sun.light_color.b,
        "R29 cool sky/fog must retain the warm golden sun rim"):return
    world._set_graphics_quality(2)
    if not check(scenic.quality_mode == 2 and
        not scenic.traffic_nodes[0].visible and
        scenic.cloud_nodes[0].visibility_range_end == 600.0,
        "R22 mobile ECO must cull distant atmospheric and air-traffic detail"):return
    world._set_graphics_quality(0)
    if not check(scenic.quality_mode == 0 and
        scenic.traffic_nodes[0].visible and
        scenic.cloud_nodes[0].visibility_range_end == 1700.0,
        "R22 MAX must restore approved 3D Aurora skyline"):return
    print("NEBULA_R22_AURORA_SCENE_SUCCESS: towers=%d windows=%d bridges=%d moving_craft=%d engine_plumes=%d" % [
        scenic.hero_towers,scenic.real_3d_windows,scenic.overpass_count,
        scenic.moving_traffic,ion_drive.plume_count])
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
    if not check(premium.r20_facade_baked,
        "R20 city facade still calculates 256x512 glazing pixels during browser load"):return
    var baked_glazing: StandardMaterial3D = premium.make_facade_material()
    if not check(baked_glazing.albedo_texture != null and
        baked_glazing.emission_texture != null and
        baked_glazing.albedo_texture.get_width() == 256 and
        baked_glazing.albedo_texture.get_height() == 512 and
        baked_glazing.emission_texture.get_width() == 256 and
        baked_glazing.emission_texture.get_height() == 512,
        "R20 baked emission/albedo texture dimensions differ from original glazing"):return
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
    if not check(MaterialStudioR11Script.baked_count() == 1,
        "R20 real player browser still computes 512x512 heavy weathered metal atlas"):return
    var r11_deck_material = r11_environment.deck_material
    if not check(r11_deck_material.albedo_texture.get_width() == 512 and
        r11_deck_material.normal_texture.get_height() == 512 and
        r11_deck_material.roughness_texture.get_width() == 512,
        "R20 original 512px PBR textures not imported into the scene"):return
    print("NEBULA_R20_BAKED_IMPORT_SUCCESS images=5 pixels=1048576")
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
    # R36: touch-accessible 20-second on-device profiler, no keyboard needed.
    # Native unit checks the actual controls and local JSON export. It does
    # NOT fabricate a physical-phone FPS score.
    touch_r21.force_mobile_for_tests(true)
    touch_r21.set_safe_insets(Vector4(59, 60, 59, 34))
    touch_r21._layout_for_size(Vector2(568, 320))
    monitor_r11.configure_mobile(true, touch_r21,
        Vector4(59, 60, 59, 34), Vector2(568, 320))
    if not check(monitor_r11.r36_mobile and
        monitor_r11.r36_launcher.visible and
        not monitor_r11.overlay.visible and
        monitor_r11.r36_launcher.offset_left >= 59.0 and
        monitor_r11.r36_launcher.offset_right <= 509.0 and
        monitor_r11.r36_launcher.offset_top >= 60.0,
        "R36 mobile FPS launcher is hidden under landscape camera notch"):return
    if not check((monitor_r11.overlay.offset_right <
        touch_r21.button_centres["CAMERA"].x - touch_r21.base_radius * 0.80 or
        not touch_r21.enabled) and
        monitor_r11.r38_mode_button.get_parent() == monitor_r11.r38_column,
        "R38 landscape quality control overlays live CAMERA hit target"):return
    monitor_r11.r36_launcher.pressed.emit()
    if not check(monitor_r11.overlay.visible and
        not monitor_r11.r36_launcher.visible and
        monitor_r11.r36_command_row.visible,
        "R36 mobile FPS launcher does not open live GPU/CPU metrics"):return
    # R38: genuine on-screen mode cycles affect all real 3D quality layers,
    # without F3/F11. The four-cycle returns to real AUTO hysteresis.
    world._set_graphics_quality(1)
    adaptive_r12.set_auto(true)
    monitor_r11.set_r38_auto_enabled(true)
    if not check(monitor_r11.r38_mode_button.text == "АВТО",
        "R38 touch panel must expose the real AUTO profile"):return
    var r38_states: Array[Dictionary] = [
        {"mode": 0, "auto": false, "label": "MAX"},
        {"mode": 1, "auto": false, "label": "HIGH"},
        {"mode": 2, "auto": false, "label": "ECO"},
        {"mode": 1, "auto": true, "label": "АВТО"}
    ]
    for wanted in r38_states:
        monitor_r11.r38_mode_button.pressed.emit()
        if not check(world.graphics_quality == wanted["mode"] and
            adaptive_r12.auto_enabled == wanted["auto"] and
            monitor_r11.r38_mode_button.text == wanted["label"] and
            monitor_r11.quality_mode == wanted["mode"],
            "R38 mobile quality toggle did not change real 3D scene"):return
    monitor_r11.r38_mode_button.pressed.emit() # AUTO -> MAX
    if not check(world.graphics_quality == 0 and
        not adaptive_r12.auto_enabled,
        "R38 manual MAX profile did not disable automatic switching"):return
    monitor_r11.r36_start_button.pressed.emit()
    if not check(monitor_r11.benchmarking and
        monitor_r11.r36_start_button.disabled and
        monitor_r11.r38_mode_button.disabled and
        monitor_r11.last_report.is_empty(),
        "R38 on-phone 20-second FPS benchmark did not lock graphics preset"):return
    monitor_r11.r38_mode_button.pressed.emit() # programmatic request while locked
    if not check(world.graphics_quality == 0 and
        not adaptive_r12.auto_enabled and
        not monitor_r11.profile_switched_during_test,
        "R38 graphics preset changed during benchmark"):return
    # End only the native UI regression (not an actual performance sample).
    monitor_r11.benchmarking = false
    monitor_r11.r36_start_button.disabled = false
    monitor_r11.r38_mode_button.disabled = false
    monitor_r11.last_timestamp_us = 0
    monitor_r11.last_report = {
        "schema": "R36_CI_EXPORT_FIXTURE_NOT_HARDWARE_MEASUREMENT",
        "avg_fps": 0
    }
    monitor_r11.download_report()
    var r36_export := FileAccess.open(
        "user://nebula-r36-real-device-performance.json", FileAccess.READ)
    if not check(r36_export != null,
        "R36 local-only JSON export did not create a device file"):return
    var r36_fixture: Variant = JSON.parse_string(r36_export.get_as_text())
    r36_export.close()
    if not check(r36_fixture is Dictionary and
        r36_fixture.get("schema", "") ==
        "R36_CI_EXPORT_FIXTURE_NOT_HARDWARE_MEASUREMENT",
        "R36 local performance JSON export was corrupted"):return
    monitor_r11.last_report.clear()
    monitor_r11.r36_close_button.pressed.emit()
    if not check(not monitor_r11.overlay.visible and
        monitor_r11.r36_launcher.visible,
        "R36 mobile performance overlay cannot be closed"):return
    touch_r21.set_safe_insets(Vector4(0, 55, 0, 34))
    touch_r21._layout_for_size(Vector2(280, 420))
    monitor_r11.configure_mobile(true, touch_r21,
        Vector4(0, 55, 0, 34), Vector2(280, 420))
    if not check(monitor_r11.r36_launcher.offset_left >= 0.0 and
        monitor_r11.r36_launcher.offset_right <
        touch_r21.button_centres["CRUISE"].x - touch_r21.base_radius * 0.8 and
        monitor_r11.overlay.offset_bottom <
        touch_r21.button_centres["CRUISE"].y - touch_r21.base_radius * 0.8 and
        monitor_r11.r38_mode_button.get_parent() == monitor_r11.r36_command_row,
        "R38 compact portrait quality button overlaps start-flight control"):return
    if not check(monitor_r11.r38_mode_button.custom_minimum_size.y >= 44.0 and
        monitor_r11.r36_start_button.custom_minimum_size.y >= 44.0 and
        monitor_r11.r36_export_button.custom_minimum_size.y >= 44.0 and
        monitor_r11.r36_close_button.custom_minimum_size.y >= 44.0,
        "R51 accessible phone quality and benchmark buttons must remain 44px"):return
    monitor_r11.configure_mobile(false, touch_r21,
        Vector4.ZERO, Vector2(1280, 720))
    adaptive_r12.set_auto(false)
    world._set_graphics_quality(0)
    monitor_r11.set_r38_auto_enabled(false)
    touch_r21.set_safe_insets(Vector4.ZERO)
    touch_r21.force_mobile_for_tests(false)
    if not check(not monitor_r11.r36_launcher.visible,
        "R36 phone FPS button leaked into desktop HUD"):return
    print("NEBULA_R36_REAL_DEVICE_UI_SUCCESS phone_launcher=1 local_json=1 benchmark_synthetic=0")
    print("NEBULA_R38_MOBILE_QUALITY_SUCCESS modes=4 benchmark_lock=true real_scene=true")
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
    if not check(world.ship.hull_kit_r45.selected_hull == "ship_interceptor" and
        world.ship.hull_kit_r45.visual_parts.size() == interceptor_parts,
        "R45 purchased interceptor must transform actual playable ship geometry"):return
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
    var prior_combat_beams: int = world.r16_beam_shots
    for i in 50:
        world._laser_effect_colored(Vector3(0,20,0),
            Vector3(float(i % 7) + 4.0, 20.0, -65.0),
            Color(1.0,0.26,0.39))
    if not check(beams.get_child_count() == 18 and
        world.r16_beam_shots - prior_combat_beams == 50,
        "R16 weapon fire is allocating new mesh nodes per shot"):return
    world._r16_update_beam_pool(0.2)
    for beam in world.r16_beams:
        if not check(not beam.visible,
            "R16 laser pool did not recycle expired effects"):return
    # A defeated enemy stays visible and falls before its impact flash.
    var falling_drone = load("res://scripts/drone.gd").new()
    world.add_child(falling_drone)
    falling_drone.global_position = Vector3(0, 30, 0)
    falling_drone.hit(100.0)
    if not check(falling_drone.crashing and not falling_drone.hostile and
        not falling_drone.is_queued_for_deletion(),
        "Defeated drone must remain visible and leave combat"):return
    var fall_start_y: float = falling_drone.global_position.y
    falling_drone._process(0.5)
    if not check(falling_drone.global_position.y < fall_start_y,
        "Defeated drone did not fall"):return
    falling_drone.global_position.y = 2.1
    falling_drone._process(0.5)
    if not check(falling_drone.crash_impacted,
        "Falling drone did not show impact feedback"):return
    falling_drone.queue_free()
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
    if not check(world.garage_open_r39 and world.ship.controls_locked and
        not world.mission_started and world.mission_enemies == 0 and
        is_instance_valid(world.garage_hub_r39),
        "R41 mission completion must return to garage and lock controls"):return
    if not check(world.garage_hub_r39.debrief_label.visible and
        world.garage_hub_r39.debrief_label.text.contains("350 CR") and
        world.garage_hub_r39.story_label.text.contains("АДА ВЕЙЛ"),
        "R41 reward debrief must be visible after successful sortie"):return
    world._r42_select_captain("leya")
    if not check(world.selected_captain_r42 == "leya" and
        world.garage_hub_r39.captain_bonus_label.text.contains("12%"),
        "R42 engineer captain cannot be chosen between sorties"):return
    var award_guard_credits: int = world.credits
    var award_guard_index: int = world.mission_index
    world._complete_mission()
    if not check(world.credits == award_guard_credits and
        world.mission_index == award_guard_index,
        "R41 duplicate mission completion double-awarded credits"):return
    if not check(world.r41_last_debrief.get("mission_index", -1) == 0 and
        world.r41_last_debrief.get("xp", 0) > 0,
        "R41 last mission reward data missing"):return
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
    if not check(parsed.get("r41_last_debrief", {}).get("mission_index", -1) == 0,
        "R41 debrief was not persisted in backward-compatible v1 save"):return
    if not check(parsed.get("captain_r42", "") == "leya",
        "R42 captain choice must persist in the additive version-1 save"):return
    var shield_before: float = world.ship.shield
    world.ship.take_damage(10.0)
    if not check(world.ship.shield < shield_before,"Damage does not reduce shield"):return
    if not check(previous_credits >= 0,"Invalid credits"):return
    # R43: actually destroy the ship, with a staged mission-drone bounty.
    # Neither the selected mission nor the player's wallet may advance.
    var retry_index: int = world.mission_index
    var before_failure_credits: int = world.credits
    world._r39_launch_sortie()
    if not check(not world.garage_open_r39 and
        not world.ship.controls_locked and world.mission_index == retry_index,
        "R43 retry test did not start the real next sortie"):return
    var mission_dummy := Node3D.new()
    world.add_child(mission_dummy)
    mission_dummy.add_to_group("nebula_mission_hostiles")
    world._on_drone_destroyed(mission_dummy)
    mission_dummy.queue_free()
    if not check(world.r43_pending_bounty == 45 and
        world.credits == before_failure_credits,
        "R43 mission bounty must remain unbanked before successful completion"):return
    world.ship.take_damage(10000.0)
    await process_frame
    if not check(world.garage_open_r39 and world.ship.controls_locked and
        world.mission_index == retry_index and
        world.credits == before_failure_credits and
        world.r43_pending_bounty == 0,
        "R43 crash must return to garage without progress or currency exploit"):return
    if not check(world.ship.hull >= 90.0 and world.ship.shield >= 90.0 and
        world.garage_hub_r39.debrief_label.visible and
        world.garage_hub_r39.debrief_label.text.contains("ВЫЛЕТ НЕ УДАЛСЯ"),
        "R43 crash must repair the ship and display explicit failure debrief"):return
    # Dock safety: no hostile fire, no destruction penalty while reading briefing.
    world.r21_launch_protection = 0.0
    var garage_shield: float = world.ship.shield
    world._on_drone_fire(world.ship.global_position, world.ship.global_position)
    if not check(is_equal_approx(world.ship.shield, garage_shield),
        "R43 garage must protect the player from ambient enemy weapons"):return
    world.ship.hull = 0.0
    await process_frame
    if not check(world.ship.hull >= 90.0 and
        world.credits == before_failure_credits and world.garage_open_r39,
        "R43 parked ship must be repaired without a hidden 220-CR penalty"):return
    world._save_progress()
    var fail_save := FileAccess.open(world.SAVE_PATH, FileAccess.READ)
    if not check(fail_save != null, "R43 failed sortie save missing"):return
    var fail_data: Variant = JSON.parse_string(fail_save.get_as_text())
    fail_save.close()
    if not check(fail_data is Dictionary and
        fail_data.get("r41_last_debrief", {}).get("status", "") == "failed",
        "R43 failed sortie status must persist without losing other v1 save fields"):return
    world._r39_launch_sortie()
    if not check(not world.garage_open_r39 and not world.ship.controls_locked and
        world.mission_index == retry_index and world.r43_pending_bounty == 0,
        "R43 second launch must retry exactly the failed mission"):return
    if not check(world.r21_launch_protection >= 6.5,
        "R43 retried sortie must restore a real temporary enemy-fire safe launch"):return
    var retry_shield: float = world.ship.shield
    world._on_drone_fire(world.ship.global_position, world.ship.global_position)
    if not check(is_equal_approx(world.ship.shield, retry_shield),
        "R43 enemy fire must not destroy the pilot instantly after an authentic retry"):return
    # R48 integrated mission 02: stale reach marker is not a free success.
    if not check(world.mission_index == 1 and
        world.MISSIONS[1]["type"] == "evacuation" and
        is_instance_valid(world.mission_objectives_r48) and
        world.mission_objectives_r48.stage == 0,
        "R48 mission 02 must use actual staged rescue in the live world"):return
    var rescue_balance: int = world.credits
    world.ship.global_position = world.MISSIONS[1]["position"]
    world._mission_tick(0.25)
    if not check(world.mission_index == 1 and
        world.credits == rescue_balance,
        "R48 cannot award mission 02 just for reaching old waypoint"):return
    var active_pickup: Vector3 = world.mission_objectives_r48.objective_position()
    world.ship.global_position = active_pickup
    for sample in 10:
        world._mission_tick(0.25)
    if not check(world.mission_index == 1 and
        world.mission_objectives_r48.stage == 1 and
        world.credits == rescue_balance,
        "R48 pickup cannot grant rewards until citizens reach the shelter"):return
    var active_shelter: Vector3 = world.mission_objectives_r48.objective_position()
    world.ship.global_position = active_shelter
    for sample in 10:
        world._mission_tick(0.25)
    if not check(world.mission_index == 2 and world.garage_open_r39 and
        world.credits > rescue_balance and
        world.r41_last_debrief.get("status", "") == "success" and
        not is_instance_valid(world.mission_objectives_r48),
        "R48 actual rescue success must grant exactly one reward and return to garage"):return
    var balance_after_rescue: int = world.credits
    world._complete_mission()
    if not check(world.credits == balance_after_rescue and world.mission_index == 2,
        "R48 cannot duplicate rescue awards from garage"):return
    # Integrated scan: three independent timed probes before the real reward.
    world.mission_index = 4 # Isolated CI setup only; not a player shortcut.
    world._r39_refresh_garage()
    world._r39_launch_sortie()
    if not check(is_instance_valid(world.mission_objectives_r48) and
        world.mission_objectives_r48.mission_type == "scan",
        "R48 scan mission did not instantiate in live campaign"):return
    for point_index in 3:
        world.ship.global_position = world.mission_objectives_r48.objective_position()
        for sample in 10:
            world._mission_tick(0.25)
        if point_index < 2 and not check(world.mission_index == 4,
            "R48 scan must not award credits before the final probe"):return
    if not check(world.garage_open_r39 and world.mission_index == 5 and
        world.r41_last_debrief.get("mission_index", -1) == 4,
        "R48 full three-probe scan must advance only one campaign mission"):return
    # Integrated vulnerable convoy: actual drones attack the target,
    # failure returns to garage with unchanged mission/wallet and no bounty.
    world.mission_index = 7 # Isolated CI setup only.
    world._r39_refresh_garage()
    var escort_balance: int = world.credits
    world._r39_launch_sortie()
    if not check(is_instance_valid(world.mission_objectives_r48) and
        world.mission_objectives_r48.mission_type == "escort",
        "R48 campaign convoy must be an actual moving 3D target"):return
    var escort_start: Vector3 = world.mission_objectives_r48.global_position
    world.ship.global_position = escort_start
    world._mission_tick(0.25)
    if not check(world.r48_escort_enemies_spawned and
        world.mission_enemies == 3 and
        world.mission_objectives_r48.global_position != escort_start,
        "R48 escort must move and spawn actual target-seeking hostile drones"):return
    var integrity_before: float = world.mission_objectives_r48.escort_health
    var hit_point: Vector3 = world.mission_objectives_r48.global_position
    world._on_drone_fire(hit_point + Vector3(0, 3, 60), hit_point)
    if not check(world.mission_objectives_r48.escort_health < integrity_before,
        "R48 convoy damage must derive from genuine drone-fire signal"):return
    world.mission_objectives_r48.take_damage(999.0)
    world._mission_tick(0.25)
    if not check(world.garage_open_r39 and world.mission_index == 7 and
        world.credits == escort_balance and
        world.r43_pending_bounty == 0 and
        world.r41_last_debrief.get("status", "") == "failed" and
        str(world.r41_last_debrief.get("reveal", "")).contains("Конвой"),
        "R48 lost convoy must permit replay without false hull crash or CR award"):return
    print("NEBULA_R48_INTEGRATED_RESCUE_SCAN_CONVOY_SUCCESS")
    # R49: tactical commands alter real wingman search, movement and attacks.
    var fleet_r49 = world.fleet_r15
    if not check(fleet_r49.SQUAD_COMMANDS == ["follow", "attack", "defend"] and
        not fleet_r49.set_command("invalid") and
        fleet_r49.set_command("attack") and
        fleet_r49.command_mode == "attack",
        "R49 squad must reject forged orders and accept real attack"):return
    fleet_r49.set_command("defend")
    if not check(fleet_r49.command_mode == "defend" and
        fleet_r49.set_command("follow") and
        fleet_r49.command_mode == "follow",
        "R49 defend and follow orders must be independently selectable"):return
    if not check(world.MISSIONS.size() == 14 and
        world.MISSIONS[10]["type"] == "investigation" and
        world.MISSIONS[10]["reward"] == 3200 and
        world.MISSIONS[11]["type"] == "archive" and
        world.MISSIONS[11]["reward"] == 3800 and
        world.MISSIONS[12]["type"] == "courier" and
        world.MISSIONS[12]["reward"] == 4400 and
        world.MISSIONS[13]["type"] == "blackout" and
        world.MISSIONS[13]["reward"] == 4900,
        "R49 must append mission 11 without renumbering the first 10"):return
    var investigation = PortInvestigationR49Script.new()
    world.add_child(investigation)
    investigation.configure(Vector3(0, 26, 0))
    if not check(investigation.terminals.size() == 3 and
        investigation.terminals[0].get_node_or_null("R49_LiveEvidenceScreen") is MeshInstance3D and
        investigation.step(0.25, investigation.destination, true) == "running" and
        investigation.stage == 0,
        "R49 genuine 3D terminals may not complete from old port waypoint"):return
    # An interrupted hold may never count as a completed interaction.
    var interrupted_goal: Vector3 = investigation.objective_position()
    for partial in 4:
        investigation.step(0.25, interrupted_goal, true)
    if not check(investigation.stage == 0 and investigation.hold_time >= 0.99,
        "R49 hold must accumulate from actual proximity and held input"):return
    investigation.step(0.25, Vector3(2000, 100, 2000), false)
    investigation.step(0.25, Vector3(2000, 100, 2000), false)
    if not check(investigation.stage == 0 and investigation.hold_time <= 0.01,
        "R49 leaving terminal must cancel a partial evidence transfer"):return
    for terminal_index in 3:
        var terminal_goal: Vector3 = investigation.objective_position()
        var status_r49 := "running"
        for tick in 9:
            status_r49 = investigation.step(0.25, terminal_goal, true)
            if status_r49 != "running":
                break
        if not check(investigation.stage == terminal_index + 1 and
            investigation.evidence_found.size() == terminal_index + 1,
            "R49 each separate terminal requires a real manual hold"):return
    if not check(not investigation.active and
        investigation.evidence_found.size() == 3 and
        investigation.step(0.25, investigation.destination, true) == "inactive",
        "R49 completed case cannot be awarded twice"):return
    investigation.configure(Vector3(0, 26, 0))
    investigation.report_weapon_discharge()
    if not check(investigation.step(0.25, investigation.objective_position(), true) == "failed" and
        investigation.stage == 0 and investigation.evidence_found.is_empty(),
        "R49 shots must fail a silent investigation without evidence"):return
    investigation.queue_free()
    print("NEBULA_R49_SQUAD_AND_PORT_CONTROLLER_SUCCESS")
    # R49 integrated last mission: success returns to garage, failure grants nothing.
    world.mission_index = 10
    world._r39_refresh_garage()
    var r49_balance: int = world.credits
    world._r39_launch_sortie()
    if not check(is_instance_valid(world.r49_investigation) and
        is_instance_valid(world.r49_terminal_button) and
        world.MISSIONS[10]["title"] == "ТЕНИ ПОРТА",
        "R49 must instantiate real terminal mission in the live world"):return
    # R49 regression: autopilot must fly to current terminal, not legacy port center.
    var real_goal_r49: Vector3 = world.r49_investigation.objective_position()
    world.ship.set_cruise_assist(false)
    world._r23_toggle_cruise()
    if not check(world.ship.cruise_assist and
        world.ship.navigation_target_valid and
        world.ship.navigation_target.distance_to(real_goal_r49) < 0.1 and
        world.ship.navigation_target.distance_to(
            world.MISSIONS[10]["position"]) > 30.0,
        "R49 autopilot must select the active terminal, never old mission center"):return
    world._r23_toggle_cruise()
    world.ship.global_position = world.MISSIONS[10]["position"]
    world._mission_tick(0.25)
    if not check(world.mission_index == 10 and world.credits == r49_balance,
        "R49 old arrival marker cannot unlock mission 11"):return
    world._on_ship_fire(world.ship.global_position, -world.ship.global_basis.z)
    world._mission_tick(0.25)
    if not check(world.garage_open_r39 and world.mission_index == 10 and
        world.credits == r49_balance and
        world.r41_last_debrief.get("status", "") == "failed",
        "R49 shoot-on-stealth fail must not pay rewards"):return
    # Attempt a real rocket in silent mode; all successful weapon types must fail.
    world._r39_launch_sortie()
    if not check(not world.fleet_r15.combat_active and
        world.r49_command_button.disabled,
        "R49 silent sortie must stop AI wingman weapons and disable attack orders"):return
    var rocket_target_r49 = DroneR49TestScript.new()
    rocket_target_r49.hostile = true
    rocket_target_r49.target = null
    world.add_child(rocket_target_r49)
    rocket_target_r49.global_position = world.ship.global_position + Vector3(0, 35, -110)
    world.drones.append(rocket_target_r49)
    world.fleet_r15.targets = world.drones
    world.fleet_r15.missiles = 1
    world.rockets_r15 = 1
    world.fleet_r15.cooldown = 0.0
    world._r21_launch_missile()
    if not check(world.rockets_r15 == 0 and world.r49_investigation.alarm,
        "R49 real rocket launch must trigger the silent-operation alarm"):return
    world._mission_tick(0.25)
    if not check(world.garage_open_r39 and world.mission_index == 10 and
        world.credits == r49_balance and world.r43_pending_bounty == 0,
        "R49 rocket-triggered alarm must fail without paying CR or XP"):return
    world.drones.erase(rocket_target_r49)
    rocket_target_r49.queue_free()
    world._r39_launch_sortie()
    for terminal_index in 3:
        world.ship.global_position = world.r49_investigation.objective_position()
        world.r49_interact_held = true
        for tick in 9:
            world._mission_tick(0.25)
            if world.garage_open_r39: break
    # Keyboard is not synthesized in native CI; the same real touch hold state is used.
    if not check(world.garage_open_r39 and world.mission_index == 11 and
        world.credits > r49_balance and
        world.r41_last_debrief.get("status", "") == "success",
        "R49 genuine three-terminal investigation must reward once and return to garage"):return
    var after_case: int = world.credits
    world._complete_mission()
    if not check(world.credits == after_case,
        "R49 mission 11 must reject double-award"):return
    print("NEBULA_R49_INTEGRATED_INVESTIGATION_SUCCESS")
    # R50 tactical test uses a separate squad, never a free owned-wingman save.
    var tactics := FleetTacticsR50Script.new()
    world.add_child(tactics)
    tactics.player_ship = world.ship
    tactics.set_loadout("ship_scout", "weapon_basic", 0, ["wingman_escort"])
    tactics.combat_active = true
    var dummy_a = DroneR49TestScript.new()
    var dummy_b = DroneR49TestScript.new()
    dummy_a.hostile = true
    dummy_b.hostile = true
    dummy_a.target = world.ship
    dummy_b.target = world.ship
    world.add_child(dummy_a)
    world.add_child(dummy_b)
    dummy_a.global_position = world.ship.global_position + Vector3(15, 4, -82)
    dummy_b.global_position = world.ship.global_position + Vector3(-16, 5, -95)
    tactics.targets.append(dummy_a)
    tactics.targets.append(dummy_b)
    if not check(tactics.helpers.size() == 1 and
        tactics.select_next_focus() and tactics.focus_target == dummy_a and
        tactics.set_command("attack") and tactics._command_enemy() == dummy_a,
        "R50 owned squad must select the first real hostile and focus attack"):return
    if not check(tactics.select_next_focus() and tactics.focus_target == dummy_b and
        tactics.focus_changes == 2 and tactics.focus_status().contains("ЦЕЛЬ"),
        "R50 focus must cycle among actual hostile actors"):return
    dummy_b.hostile = false
    if not check(tactics._command_enemy() == dummy_a and
        not tactics._valid_focus(dummy_b),
        "R50 destroyed enemy cannot be retained as active target"):return
    var convoy_target := Node3D.new()
    world.add_child(convoy_target)
    convoy_target.global_position = world.ship.global_position + Vector3(0, 1, 40)
    dummy_a.target = convoy_target
    dummy_b.hostile = true
    tactics.defend_anchor = convoy_target
    tactics.set_command("defend")
    if not check(tactics._command_enemy() == dummy_a,
        "R50 defend order must prioritize genuine enemy that targets the convoy"):return
    tactics.clear_focus()
    if not check(tactics.focus_status() == "НЕТ ЦЕЛИ",
        "R50 released target must clear combat HUD state"):return
    # Real focus ring follows the locked enemy; a real missile must obey
    # the chosen focus even when the other hostile is physically closer.
    tactics.set_command("attack")
    tactics.focus_target = dummy_b
    tactics._refresh_focus_marker()
    if not check(tactics.focus_marker.visible and
        tactics.focus_marker.global_position.distance_to(
        dummy_b.global_position + Vector3.UP * 4.5) < 0.1,
        "R50 target lock requires a real 3D reticle at the enemy location"):return
    tactics.missiles = 1
    tactics.cooldown = 0.0
    if not check(tactics.launch_missile() and tactics.missile_focus_launches == 1 and
        tactics.missile_pool[0].target == dummy_b and tactics.missiles == 0,
        "R50 guided missile must prioritize focused enemy and consume one rocket"):return
    tactics.missile_pool[0].deactivate()
    tactics.clear_focus()
    tactics._refresh_focus_marker()
    if not check(not tactics.focus_marker.visible,
        "R50 no lock reticle should be left after target release"):return

    # Own craft weapons must not shoot through real solid city geometry.
    var gun_from := Vector3(0.0, 4000.0, 0.0)
    var gun_to := Vector3(0.0, 4000.0, 32.0)
    if not check(tactics._has_clear_laser_path(gun_from, gun_to),
        "R50 unobstructed sky shot must be possible"):return
    var barrier := StaticBody3D.new()
    var collision := CollisionShape3D.new()
    var bulkhead := BoxShape3D.new()
    bulkhead.size = Vector3(14.0, 24.0, 8.0)
    collision.shape = bulkhead
    barrier.add_child(collision)
    world.add_child(barrier)
    barrier.collision_layer = 1
    barrier.global_position = Vector3(0.0, 4000.0, 16.0)
    await physics_frame
    if not check(not tactics._has_clear_laser_path(gun_from, gun_to),
        "R50 solid world obstacle must actually block wingman laser path"):return
    barrier.queue_free()
    await physics_frame
    if not check(tactics._has_clear_laser_path(gun_from, gun_to),
        "R50 removing obstacle must restore line of sight"):return
    dummy_a.queue_free()
    dummy_b.queue_free()
    convoy_target.queue_free()
    tactics.queue_free()
    print("NEBULA_R50_REAL_FOCUS_AND_CONVOY_THREAT_SUCCESS")

    # R50 pure objective: no old-waypoint completion, manual hold, damage gate.
    var archive = ArchiveBreachR50Script.new()
    world.add_child(archive)
    archive.configure(Vector3(-500, 32, 670))
    if not check(archive.nodes.size() == 3 and archive.stage == 0 and
        archive.step(0.25, archive.anchor, true) == "running" and
        archive.evidence.is_empty(),
        "R50 archive waypoint alone must not unlock two real key stations"):return
    var inactive_health: float = archive.security_health
    archive.take_damage(35.0)
    if not check(is_equal_approx(archive.security_health, inactive_health),
        "R50 server cannot be damaged before the archive defense begins"):return
    for key_index in 2:
        var key_point: Vector3 = archive.objective_position()
        for tick in 8:
            archive.step(0.25, key_point, true)
        if not check(archive.stage == key_index + 1 and
            archive.evidence.size() == key_index + 1,
            "R50 two separate real key probes must be completed in order"):return
    if not check(archive.combat_started and archive.is_active_server(),
        "R50 archive becomes vulnerable only after both keys"):return
    archive.take_damage(40.0)
    if not check(archive.security_health == archive.SERVER_CAPACITY - 40.0 and
        archive.repair_node.visible and archive.can_repair(),
        "R50 server damage must activate the physically separate repair option"):return
    var repair_place: Vector3 = archive.repair_point
    if not check(archive.set_repair_navigation(true) and
        archive.objective_position().distance_to(repair_place) < 0.01 and
        not archive.can_interact(repair_place),
        "R50 repair navigation must not pretend the repair cell is the server"):return
    for wrong in 8:
        archive.step(0.25, Vector3(2000, 2000, 2000), true)
    if not check(archive.repair_hold_time <= 0.01,
        "R50 repair cell cannot activate from a remote position"):return
    for repair_tick in 8:
        archive.step(0.25, repair_place, true)
    if not check(archive.repair_used and archive.repair_events == 1 and
        archive.security_health == archive.SERVER_CAPACITY and
        archive.objective_position().distance_to(archive.points[2]) < 0.1 and
        not archive.repair_node.visible,
        "R50 held physical battery access must heal once then return navigation to server"):return
    archive.take_damage(22.0)
    for repeat in 10:
        archive.step(0.25, repair_place, true)
    if not check(archive.repair_events == 1 and
        archive.security_health == archive.SERVER_CAPACITY - 22.0,
        "R50 one-use repair must never refill repeatedly"):return
    var archive_server: Vector3 = archive.objective_position()
    archive.step(0.25, archive_server, true)
    archive.step(0.25, archive_server, true)
    archive.step(0.25, Vector3(2000, 0, 2000), false)
    archive.step(0.25, Vector3(2000, 0, 2000), false)
    if not check(archive.stage == 2 and archive.hold_time <= 0.01,
        "R50 interrupted download may never finish remotely"):return
    for sample in 21:
        archive.step(0.25, archive_server, true)
    if not check(archive.completed_once and not archive.active and
        archive.stage == 3 and archive.evidence.size() == 3 and
        archive.step(0.25, archive_server, true) == "inactive",
        "R50 full server download must complete only once"):return
    archive.configure(Vector3(-500, 32, 670))
    for key_index in 2:
        for tick in 8:
            archive.step(0.25, archive.objective_position(), true)
    archive.take_damage(archive.SERVER_CAPACITY)
    if not check(archive.step(0.25, archive.objective_position(), true) == "failed" and
        not archive.completed_once and archive.evidence.size() == 2,
        "R50 destroyed archive must fail without completing the final transfer"):return
    archive.queue_free()
    print("NEBULA_R50_KEYS_ENCRYPTED_SERVER_CONTROLLER_SUCCESS")

    # R50 integrated real campaign: wipe does not grant any credits or XP.
    world.mission_index = 11
    world._r39_refresh_garage()
    var archive_wallet: int = world.credits
    var archive_xp: int = world.xp
    world._r39_launch_sortie()
    if not check(is_instance_valid(world.r50_archive) and
        world.MISSIONS[11]["title"] == "ЗАКРЫТЫЙ АРХИВ" and
        world.r49_terminal_button.visible,
        "R50 live mission must instantiate a visible interactive terminal"):return
    world.ship.global_position = world.MISSIONS[11]["position"]
    world._mission_tick(0.25)
    if not check(world.mission_index == 11 and world.credits == archive_wallet,
        "R50 old waypoint cannot grant mission 12 rewards"):return
    for key_index in 2:
        world.ship.global_position = world.r50_archive.objective_position()
        world.r49_interact_held = true
        for tick in 8:
            world._mission_tick(0.25)
    if not check(world.r50_archive_wave_spawned and world.mission_enemies == 3 and
        world.r50_archive.is_active_server() and
        world.fleet_r15.defend_anchor == world.r50_archive,
        "R50 two keys must trigger drones and anchor wingmen to real server"):return
    var health_before: float = world.r50_archive.security_health
    var target_archive: Vector3 = world.r50_archive.global_position
    world._on_drone_fire(target_archive + Vector3(0, 5, 70), target_archive)
    if not check(world.r50_archive.security_health < health_before,
        "R50 archive damage must come from actual drone shot signal"):return
    world._r49_refresh_buttons()
    if not check(world.r50_repair_button.visible,
        "R50 mobile repair button must appear once reactor is damaged"):return
    world._r50_toggle_repair_goal()
    if not check(world.r50_archive.focus_on_repair and
        world.ship.navigation_target.distance_to(
            world.r50_archive.repair_point) < 0.1,
        "R50 touch repair navigation must lead to actual secondary cell"):return
    world.ship.global_position = world.r50_archive.repair_point
    for repair_tick in 8:
        world._mission_tick(0.25)
    if not check(world.r50_archive.repair_used and
        world.r50_archive.security_health == world.r50_archive.SERVER_CAPACITY and
        world.ship.navigation_target.distance_to(
            world.r50_archive.points[2]) < 0.1,
        "R50 integrated touch hold must truly repair once and reset autopilot"):return
    world.r50_archive.take_damage(1000.0)
    world._mission_tick(0.25)
    if not check(world.garage_open_r39 and world.mission_index == 11 and
        world.credits == archive_wallet and world.xp == archive_xp and
        world.r43_pending_bounty == 0,
        "R50 failed archive must preserve progress and prevent credit farming"):return
    world._r39_launch_sortie()
    for key_index in 2:
        world.ship.global_position = world.r50_archive.objective_position()
        world.r49_interact_held = true
        for tick in 8:
            world._mission_tick(0.25)
    for actor in world.drones.duplicate():
        if is_instance_valid(actor) and actor.is_in_group("nebula_mission_hostiles"):
            actor.hit(10000.0)
    world.ship.global_position = world.r50_archive.objective_position()
    for tick in 21:
        world._mission_tick(0.25)
        if world.garage_open_r39: break
    if not check(world.garage_open_r39 and world.mission_index == 12 and
        world.credits > archive_wallet and world.xp > archive_xp and
        world.r41_last_debrief.get("status", "") == "success",
        "R50 archive must reward one real defended transfer and return to garage"):return
    var archive_paid: int = world.credits
    world._complete_mission()
    if not check(world.credits == archive_paid,
        "R50 archived campaign cannot duplicate the final reward"):return
    print("NEBULA_R50_INTEGRATED_ARCHIVE_AND_RETRY_SUCCESS")

    # R51 isolated gameplay: moving ship really changes coordinates, the
    # player must follow within range, and active signal jammers block escape.
    var courier_controller = CourierInterceptR51Script.new()
    world.add_child(courier_controller)
    courier_controller.configure(Vector3(1230.0, 29.0, -710.0))
    if not check(courier_controller.stage == 0 and courier_controller.active and
        not courier_controller.courier.visible and
        courier_controller.start_console.visible and
        courier_controller.captured_fragments == 0,
        "R51 receiver must start as real physical stage one"):return
    for scan in 9:
        courier_controller.step(0.25, courier_controller.courier_center, true)
    if not check(courier_controller.stage == 0 and
        courier_controller.hold_time <= 0.01,
        "R51 old waypoint cannot bypass physical receiver"):return
    for scan in 8:
        courier_controller.step(0.25, courier_controller.start_position, true)
    if not check(courier_controller.stage == 1 and
        courier_controller.courier.visible and
        courier_controller.captured_fragments == 1 and
        courier_controller.pursuit_trail.size() == 5,
        "R51 first receiver must reveal a moving courier and pooled 3D signal trail"):return
    var live_signal_points: int = 0
    for waypoint in courier_controller.pursuit_trail:
        if waypoint.visible:
            live_signal_points += 1
    if not check(live_signal_points == 5,
        "R51 pursuit must show all five actual in-world signal guide marks"):return
    var actual_signal_position: Vector3 = courier_controller.objective_position()
    var predicted_signal_position: Vector3 = courier_controller.navigation_position(
        Vector3(9000.0, 9000.0, 9000.0))
    if not check(predicted_signal_position.distance_to(actual_signal_position) > 2.0 and
        predicted_signal_position.distance_to(actual_signal_position) <= 32.01 and
        courier_controller.lead_guidance_updates > 0,
        "R51 intercept guidance must lead real courier by at most 32m, not fake proximity"):return
    if not check(courier_controller.navigation_position(actual_signal_position) ==
        actual_signal_position,
        "R51 nearby pilot guidance must track the actual courier without artificial lead"):return
    var prior_trail_position: Vector3 = courier_controller.pursuit_trail[0].global_position
    var prior_courier_point: Vector3 = courier_controller.courier.global_position
    for far_tick in 6:
        courier_controller.step(0.25, Vector3(9000, 9000, 9000), false)
    if not check(courier_controller.stage == 1 and
        courier_controller.courier.global_position.distance_to(
            prior_courier_point) > 3.0 and
        courier_controller.pursuit_trail[0].global_position.distance_to(
            prior_trail_position) > 3.0 and courier_controller.track_time <= 0.01,
        "R51 courier and 3D trail must move, with no remote signal acquisition"):return
    for follow_tick in 19:
        courier_controller.step(0.25, courier_controller.objective_position(), false)
    var invisible_signal_points: int = 0
    for waypoint in courier_controller.pursuit_trail:
        if not waypoint.visible:
            invisible_signal_points += 1
    if not check(courier_controller.stage == 2 and
        courier_controller.captured_fragments == 2 and
        not courier_controller.courier.visible and
        invisible_signal_points == 5 and
        courier_controller.extraction_console.visible,
        "R51 tracking real courier must hide guide marks and unlock extraction"):return
    var escape_pad: Vector3 = courier_controller.objective_position()
    for jammed_tick in 13:
        courier_controller.step(0.25, escape_pad, true, 2)
    if not check(courier_controller.stage == 2 and
        courier_controller.hold_time == 0.0 and
        courier_controller.interference_count == 2,
        "R51 signal jammers must actually prevent escape, not only change HUD text"):return
    for remote_tick in 13:
        courier_controller.step(0.25, courier_controller.start_position, true, 0)
    if not check(courier_controller.stage == 2 and
        courier_controller.hold_time <= 0.01,
        "R51 manual extraction cannot complete remotely"):return
    for final_tick in 13:
        courier_controller.step(0.25, escape_pad, true, 0)
    if not check(courier_controller.stage == 3 and
        courier_controller.completed_once and not courier_controller.active and
        courier_controller.captured_fragments == 3 and
        courier_controller.step(0.25, escape_pad, true, 0) == "inactive",
        "R51 three distinct real phases must award extraction at most once"):return
    courier_controller.configure(Vector3(1230.0, 29.0, -710.0))
    for scan in 8:
        courier_controller.step(0.25, courier_controller.start_position, true)
    courier_controller.pursuit_remaining = 0.05
    if not check(courier_controller.step(0.25,
            Vector3(9000, 9000, 9000), false) == "failed" and
        not courier_controller.completed_once and
        courier_controller.last_event.contains("КУРЬЕР") and
        courier_controller.captured_fragments == 1,
        "R51 moving courier must escape after real pursuit deadline without fake reward"):return
    courier_controller.configure(Vector3(1230.0, 29.0, -710.0))
    for scan in 8:
        courier_controller.step(0.25, courier_controller.start_position, true)
    for follow_tick in 19:
        courier_controller.step(0.25, courier_controller.objective_position(), false)
    courier_controller.extraction_remaining = 0.05
    if not check(courier_controller.step(0.25,
            courier_controller.extraction_position, true, 0) == "failed" and
        not courier_controller.completed_once and courier_controller.stage == 2,
        "R51 deadline expiry must fail with no fake extraction reward"):return
    courier_controller.queue_free()
    print("NEBULA_R51_MOVING_COURIER_JAMMED_EXTRACTION_CONTROLLER_SUCCESS")

    # R51 full campaign integration: jammers are actual killable drones,
    # physical T/hold and pursuit are required, and a failed run is retryable.
    world.mission_index = 12
    world._r39_refresh_garage()
    var courier_wallet: int = world.credits
    var courier_xp: int = world.xp
    world._r39_launch_sortie()
    if not check(is_instance_valid(world.r51_courier) and
        world.r51_courier.stage == 0 and
        world.MISSIONS[12]["title"] == "КУРЬЕР «ЭХО»",
        "R51 mission must be a real stage-13 sortie, not a story-only entry"):return
    world._r49_layout_buttons(Vector2(320.0, 480.0), Vector4.ZERO)
    if not check(world.r49_terminal_button.size.x >= 190.0 and
        world.r50_focus_button.position.y >=
        world.r49_terminal_button.position.y +
            world.r49_terminal_button.size.y + 6.0,
        "R51 compact portrait terminal and target controls must not overlap"):return
    world.ship.global_position = world.MISSIONS[12]["position"]
    world._mission_tick(0.25)
    if not check(world.mission_index == 12 and world.credits == courier_wallet,
        "R51 arriving at old waypoint must never grant new mission rewards"):return
    world.ship.global_position = world.r51_courier.start_position
    world.r49_interact_held = true
    for scan in 8:
        world._mission_tick(0.25)
    if not check(world.r51_courier.stage == 1 and
        world.r51_courier.courier.visible and not world.r49_interact_held,
        "R51 receiver must require real touch and clear stale held input after stage change"):return
    # Pilot is outside tracking range; world must aim its actual autopilot
    # at a bounded moving-target lead while the physical courier stays live.
    world._mission_tick(0.25)
    var real_courier_goal: Vector3 = world.r51_courier.objective_position()
    if not check(world.ship.navigation_target.distance_to(real_courier_goal) <= 32.01 and
        world.r51_courier.lead_guidance_updates > 0 and
        world.mission_beacon.global_position.distance_to(real_courier_goal) < 0.1,
        "R51 world steering may lead courier, but physical beacon cannot be spoofed"):return
    world.r51_courier.pursuit_remaining = 0.05
    world._mission_tick(0.25)
    if not check(world.garage_open_r39 and world.mission_index == 12 and
        world.credits == courier_wallet and world.xp == courier_xp and
        world.r41_last_debrief.get("status", "") == "failed" and
        str(world.r41_last_debrief.get("reveal", "")).contains("КУРЬЕР"),
        "R51 integrated courier escape must fail, show true reason and award nothing"):return
    world._r39_launch_sortie()
    world.ship.global_position = world.r51_courier.start_position
    world.r49_interact_held = true
    for scan in 8:
        world._mission_tick(0.25)
    for follow_tick in 19:
        world.ship.global_position = world.r51_courier.objective_position()
        world._mission_tick(0.25)
    if not check(world.r51_courier.stage == 2 and
        world.r51_jammer_wave_spawned and world.mission_enemies == 2 and
        not world.r49_interact_held and
        world._r51_active_interference() == 2,
        "R51 moving pursuit must spawn two actual jammer drone actors"):return
    world.ship.global_position = world.r51_courier.extraction_position
    for blocked_tick in 13:
        world._mission_tick(0.25)
    if not check(world.r51_courier.stage == 2 and
        world.r51_courier.hold_time == 0.0 and world.mission_index == 12,
        "R51 actual jammer drone actors must block physical pad until destroyed"):return
    world.r51_courier.extraction_remaining = 0.05
    world._mission_tick(0.25)
    if not check(world.garage_open_r39 and world.mission_index == 12 and
        world.credits == courier_wallet and world.xp == courier_xp and
        world.r43_pending_bounty == 0 and
        world.r41_last_debrief.get("status", "") == "failed",
        "R51 real timer failure must preserve v1 progress and pay zero rewards"):return
    world._r39_launch_sortie()
    world.ship.global_position = world.r51_courier.start_position
    world.r49_interact_held = true
    for scan in 8:
        world._mission_tick(0.25)
    for follow_tick in 19:
        world.ship.global_position = world.r51_courier.objective_position()
        world._mission_tick(0.25)
    for actor in world.drones.duplicate():
        if is_instance_valid(actor) and actor.is_in_group("nebula_r51_jammer"):
            actor.hit(10000.0)
    if not check(world._r51_active_interference() == 0 and
        world.mission_enemies == 0,
        "R51 signal interference must clear only after genuine enemies die"):return
    world.ship.global_position = world.r51_courier.extraction_position
    # A fresh manual press is necessary at the final extraction terminal.
    # An old receiver hold may NEVER carry across distinct mission stages.
    for forgotten_press_tick in 13:
        world._mission_tick(0.25)
    if not check(world.r51_courier.stage == 2 and
        world.r51_courier.hold_time <= 0.01 and
        world.mission_index == 12,
        "R51 extraction cannot auto-complete from stale previous hold"):return
    world.r49_interact_held = true
    for final_tick in 13:
        world._mission_tick(0.25)
        if world.garage_open_r39: break
    if not check(world.garage_open_r39 and world.mission_index == 13 and
        world.credits > courier_wallet and world.xp > courier_xp and
        world.r41_last_debrief.get("status", "") == "success",
        "R51 courier mission must reward a real timed extraction and garage return"):return
    var courier_paid: int = world.credits
    world._complete_mission()
    if not check(world.credits == courier_paid,
        "R51 finished mission must reject duplicated final payouts"):return
    print("NEBULA_R51_INTEGRATED_MOVING_COURIER_RETRY_SUCCESS")

    # R52 isolated physical emergency grid: two distinct manual breakers,
    # true attackable energy budget, one-use capacitor and 95s timeout.
    var grid = StationBlackoutR52Script.new()
    world.add_child(grid)
    grid.configure(Vector3(530.0, 32.0, 1060.0))
    if not check(grid.active and grid.stage == 0 and
        grid.relays.size() == 2 and grid.relays[0].visible and
        not grid.reactor.visible and not grid.can_repair() and
        is_equal_approx(grid.grid_health, grid.GRID_MAX),
        "R52 blackout must start with physical breaker and inert reactor"):return
    for remote_tick in 9:
        grid.step(0.25, Vector3(530, 32, 1060), true)
    if not check(grid.stage == 0 and grid.hold_time <= 0.01,
        "R52 old mission waypoint can never remotely flip the first breaker"):return
    grid.take_damage(60.0)
    if not check(grid.actual_damage_hits == 0 and
        is_equal_approx(grid.grid_health, grid.GRID_MAX),
        "R52 inactive station cannot receive enemy damage or use reserve"):return
    for key_tick in 7:
        grid.step(0.25, grid.relay_positions[0], true)
    if not check(grid.stage == 1 and grid.relays[1].visible and
        not grid.input_armed, "R52 first real breaker must require held access"):return
    for stale_tick in 9:
        grid.step(0.25, grid.relay_positions[1], true)
    if not check(grid.stage == 1 and grid.hold_time <= 0.01,
        "R52 held button from breaker A cannot arm the second breaker"):return
    grid.step(0.25, grid.relay_positions[1], false)
    for second_key in 7:
        grid.step(0.25, grid.relay_positions[1], true)
    if not check(grid.stage == 2 and grid.reactor_online and
        grid.reactor.visible and grid.capacitor.visible and
        grid.is_live_reactor(),
        "R52 two separately pressed real switches must activate defense"):return
    var untouched_charge: float = grid.grid_health
    for far_tick in 6:
        grid.step(0.25, Vector3(9000,9000,9000), false)
    if not check(grid.stabilization <= 0.01 and grid.grid_health < untouched_charge,
        "R52 autonomous station timer must drain actual energy without pilot presence"):return
    grid.take_damage(33.0)
    if not check(grid.actual_damage_hits == 1 and grid.can_repair() and
        grid.select_capacitor(true) and
        grid.objective_position() == grid.capacitor_position,
        "R52 hostile shot must damage grid and unlock distinct capacitor route"):return
    for far_repair in 8:
        grid.step(0.25, Vector3(9000,9000,9000), true)
    if not check(grid.capacitor_hold <= 0.01 and not grid.capacitor_used,
        "R52 power restoration cannot happen from outside real 30m area"):return
    grid.step(0.25, grid.capacitor_position, false)
    for reserve_tick in 8:
        grid.step(0.25, grid.capacitor_position, true)
    if not check(grid.capacitor_used and grid.capacitor_events == 1 and
        grid.grid_health <= grid.GRID_MAX and
        grid.objective_position() == grid.reactor.global_position and
        not grid.capacitor.visible,
        "R52 real capacitor must be one-use, capped and reset navigation"):return
    var healed_charge: float = grid.grid_health
    for exploit_tick in 8:
        grid.step(0.25, grid.capacitor_position, true)
    if not check(grid.capacitor_events == 1 and grid.grid_health < healed_charge,
        "R52 used backup capacitor must never generate repeatable energy"):return
    for stabilize_tick in 57:
        grid.step(0.25, grid.reactor.global_position, false)
    if not check(grid.completed_once and grid.stage == 3 and not grid.active and
        grid.step(0.25, grid.reactor.global_position, false) == "inactive",
        "R52 real physical proximity must stabilize reactor only once"):return
    grid.configure(Vector3(530.0, 32.0, 1060.0))
    for key_tick in 7:
        grid.step(0.25, grid.relay_positions[0], true)
    grid.step(0.25, grid.relay_positions[1], false)
    for key_tick in 7:
        grid.step(0.25, grid.relay_positions[1], true)
    grid.take_damage(1000.0)
    if not check(grid.step(0.25, grid.reactor.global_position, false) == "failed" and
        not grid.completed_once and grid.actual_damage_hits == 1,
        "R52 fully destroyed reactor must fail with no generated success"):return
    grid.configure(Vector3(530.0, 32.0, 1060.0))
    for key_tick in 7:
        grid.step(0.25, grid.relay_positions[0], true)
    grid.step(0.25, grid.relay_positions[1], false)
    for key_tick in 7:
        grid.step(0.25, grid.relay_positions[1], true)
    grid.defense_remaining = 0.05
    if not check(grid.step(0.25, grid.reactor.global_position, false) == "failed" and
        not grid.completed_once and grid.last_event.contains("ВРЕМЯ"),
        "R52 95-second stabilization deadline must cause genuine failure"):return
    grid.queue_free()
    print("NEBULA_R52_PHYSICAL_RELAY_GRID_CAPACITOR_CONTROLLER_SUCCESS")

    # R52 campaign integration: actual drone.fired hits the reactor,
    # failure pays zero and retry gives a one-time normal mission reward.
    world.mission_index = 13
    world._r39_refresh_garage()
    var station_wallet: int = world.credits
    var station_xp: int = world.xp
    world._r39_launch_sortie()
    if not check(is_instance_valid(world.r52_station) and
        world.MISSIONS[13]["title"] == "СТАНЦИЯ БЕЗ СВЕТА" and
        world.fleet_r15.defend_anchor == world.r52_station.reactor and
        world.r49_terminal_button.visible,
        "R52 must launch a real physical mission with reactor defend anchor"):return
    world.ship.global_position = world.MISSIONS[13]["position"]
    world._mission_tick(0.25)
    if not check(world.mission_index == 13 and world.credits == station_wallet,
        "R52 reaching the old static waypoint cannot award a mission"):return
    for key_index in 2:
        world.ship.global_position = world.r52_station.relay_positions[key_index]
        world.r49_interact_held = false
        world._mission_tick(0.25)
        world.r49_interact_held = true
        for tick in 7:
            world._mission_tick(0.25)
    if not check(world.r52_station.is_live_reactor() and
        world.r52_hostiles_spawned and world.mission_enemies == 3 and
        not world.r49_interact_held,
        "R52 real second breaker must spawn three attacking drone actors"):return
    var grid_before_shot: float = world.r52_station.grid_health
    var core_location: Vector3 = world.r52_station.reactor.global_position
    world._on_drone_fire(core_location + Vector3(0.0, 5.0, 75.0), core_location)
    if not check(world.r52_station.grid_health < grid_before_shot and
        world.r52_station.actual_damage_hits == 1,
        "R52 world drone fire signal must apply actual reactor damage"):return
    world._r49_refresh_buttons()
    if not check(world.r50_repair_button.visible,
        "R52 actual damaged core must show repair choice on touch HUD"):return
    world._r50_toggle_repair_goal()
    if not check(world.r52_station.focus_on_capacitor and
        world.ship.navigation_target.distance_to(
            world.r52_station.capacitor_position) < 0.01,
        "R52 mobile reserve button must navigate to actual physical capacitor"):return
    world.ship.global_position = world.r52_station.capacitor_position
    # A distinct capacitor requires a genuinely new touch after the relay:
    # the first frame releases the previously used button.
    world.r49_interact_held = false
    world._mission_tick(0.25)
    world.r49_interact_held = true
    for reserve_tick in 8:
        world._mission_tick(0.25)
    if not check(world.r52_station.capacitor_events == 1 and
        world.r52_station.capacitor_used and
        world.ship.navigation_target.distance_to(
            world.r52_station.reactor.global_position) < 0.01,
        "R52 actual touch hold must restore energy once and return to reactor"):return
    world.r52_station.take_damage(200.0)
    world._mission_tick(0.25)
    if not check(world.garage_open_r39 and world.mission_index == 13 and
        world.credits == station_wallet and world.xp == station_xp and
        world.r43_pending_bounty == 0,
        "R52 destroyed station must return to garage with no CR/XP farming"):return
    world._r39_launch_sortie()
    for key_index in 2:
        world.ship.global_position = world.r52_station.relay_positions[key_index]
        world.r49_interact_held = false
        world._mission_tick(0.25)
        world.r49_interact_held = true
        for tick in 7:
            world._mission_tick(0.25)
    for enemy in world.drones.duplicate():
        if is_instance_valid(enemy) and enemy.is_in_group("nebula_r52_reactor_attackers"):
            enemy.hit(10000.0)
    world.ship.global_position = world.r52_station.reactor.global_position
    for stabilize_tick in 57:
        world._mission_tick(0.25)
        if world.garage_open_r39:
            break
    if not check(world.garage_open_r39 and world.mission_index == 14 and
        world.credits > station_wallet and world.xp > station_xp and
        world.r41_last_debrief.get("status", "") == "success",
        "R52 14-second defense must reward once and return safely to hangar"):return
    var grid_payout: int = world.credits
    world._complete_mission()
    if not check(world.credits == grid_payout,
        "R52 finished mission cannot duplicate normal campaign reward"):return
    print("NEBULA_R52_REAL_REACTOR_COMBAT_RETRY_AND_REWARD_SUCCESS")
    # R56: workbench modules are paid local upgrades on three independent
    # real fleet bodies. Verify combat capacities, HUD and safe save semantics.
    if not check(world.garage_open_r39 and
        HangarWorkbenchR56Script.upgrade_cost("armor", 0) == 500 and
        HangarWorkbenchR56Script.upgrade_cost("armor", 1) == 900 and
        HangarWorkbenchR56Script.upgrade_cost("shield", 0) == 550 and
        HangarWorkbenchR56Script.upgrade_cost("radar", 0) == 400 and
        HangarWorkbenchR56Script.upgrade_cost("armor", 3) == 0 and
        HangarWorkbenchR56Script.upgrade_cost("unknown", 0) == -1 and
        is_equal_approx(HangarWorkbenchR56Script.hull_cap(100.0, 3), 160.0) and
        is_equal_approx(HangarWorkbenchR56Script.shield_cap(100.0, 3), 175.0) and
        is_equal_approx(HangarWorkbenchR56Script.radar_range(3), 760.0),
        "R56 paid module costs and real max combat stat bonuses must agree"):return
    var safe_roster_r56: Dictionary = HangarWorkbenchR56Script.safe_roster(
        {"ship_scout":{"armor":999, "shield":-6, "radar":"fake",
            "secret":100}, "ship_guardian":{"armor":2.5},
            "rogue_ship":{"armor":3, "shield":3}})
    if not check(safe_roster_r56["ship_scout"]["armor"] == 3 and
        safe_roster_r56["ship_scout"]["shield"] == 0 and
        safe_roster_r56["ship_scout"]["radar"] == 0 and
        safe_roster_r56["ship_guardian"]["armor"] == 2 and
        not safe_roster_r56.has("rogue_ship") and
        not safe_roster_r56["ship_scout"].has("secret"),
        "R56 must clamp saved module levels and reject unauthorized hulls"):return
    world.hangar_modules_r56 = HangarWorkbenchR56Script.default_roster()
    world.credits = 10000
    world.equipped_r15 = "ship_scout"
    world._r15_apply_loadout()
    world.ship.hull = world.fleet_r15.ship_hull_cap() - 31.0
    world.ship.shield = world.fleet_r15.ship_shield_cap() - 45.0
    var shop_in_garage = world.garage_hub_r39
    world._r39_refresh_garage()
    shop_in_garage.section_buttons_r54["workshop"].pressed.emit()
    if not check(shop_in_garage.active_section_r54 == "workshop" and
        shop_in_garage.r56_workshop_panel.visible and
        not shop_in_garage.ship_card_r54.visible and
        shop_in_garage.r56_workshop_status.text.contains("РАДАР 460 М") and
        shop_in_garage.r56_module_buttons.size() == 3,
        "R56 workshop must be a separate readable page, not a hidden shop"):return
    var scout_before_hull: float = world.ship.hull
    var scout_before_shield: float = world.ship.shield
    shop_in_garage.r56_module_buttons["armor"].pressed.emit()
    if not check(world.credits == 9500 and
        world.hangar_modules_r56["ship_scout"]["armor"] == 1 and
        is_equal_approx(world.fleet_r15.ship_hull_cap(), 120.0) and
        is_equal_approx(world.ship.hull, scout_before_hull + 20.0) and
        shop_in_garage.r56_module_buttons["armor"].text.contains("900 CR") and
        world.ship.primary_airframe_r55.armor_rank_r56 == 1 and
        world.ship.primary_airframe_r55.module_geometry_count_r56() >= 4 and
        shop_in_garage.ship_preview_r44.primary_airframe_r55.armor_rank_r56 == 1,
        "R56 armor must debit 500 CR and add exactly 20 true hull capacity"):return
    shop_in_garage.r56_module_buttons["shield"].pressed.emit()
    if not check(world.credits == 8950 and
        world.hangar_modules_r56["ship_scout"]["shield"] == 1 and
        is_equal_approx(world.fleet_r15.ship_shield_cap(), 125.0) and
        is_equal_approx(world.ship.shield, scout_before_shield + 25.0) and
        world.ship.primary_airframe_r55.module_visual_r56.find_children(
            "R56_ActualShieldEmitter_*", "MeshInstance3D", true, false).size() == 2,
        "R56 shield must debit 550 CR and alter actual combat protection"):return
    shop_in_garage.r56_module_buttons["radar"].pressed.emit()
    if not check(world.credits == 8550 and
        world.hangar_modules_r56["ship_scout"]["radar"] == 1 and
        is_equal_approx(world.fleet_r15.radar_range_r56(), 560.0) and
        is_equal_approx(world.radar.range_meters, 560.0) and
        world.ship.primary_airframe_r55.radar_rank_r56 == 1 and
        world.ship.primary_airframe_r55.module_visual_r56.get_node_or_null(
            "R56_RealRadarArray_L1") is MeshInstance3D and
        shop_in_garage.ship_preview_r44.primary_airframe_r55.radar_rank_r56 == 1,
        "R56 radar upgrade must debit 400 CR and change real in-flight radar"):return
    world._r56_purchase_workbench_module("unknown")
    if not check(world.credits == 8550,
        "R56 unknown workbench SKU must never debit a wallet"):return
    # Earlier R15 regression may already have bought NX-21; existing owners
    # must never be charged twice. New owners pay exactly the catalog cost.
    var guardian_was_owned: bool = world.owned_r15.has("ship_guardian") or (
        int(world.premium_r15.get("ship_guardian", 0)) > 0)
    var guardian_expected_wallet: int = 8550 - (
        0 if guardian_was_owned else 4200)
    world._r15_buy_credit("ship_guardian")
    if not check(world.credits == guardian_expected_wallet and
        world.equipped_r15 == "ship_guardian" and
        (world.owned_r15.has("ship_guardian") or (
            int(world.premium_r15.get("ship_guardian", 0)) > 0)) and
        is_equal_approx(world.fleet_r15.ship_hull_cap(), 160.0) and
        is_equal_approx(world.fleet_r15.radar_range_r56(), 460.0) and
        world.ship.primary_airframe_r55.module_geometry_count_r56() == 0,
        "R56 modules from scout cannot leak to paid or previously owned Guardian"):return
    world._r39_refresh_garage()
    shop_in_garage.r56_module_buttons["armor"].pressed.emit()
    if not check(world.credits == guardian_expected_wallet - 500 and
        world.hangar_modules_r56["ship_guardian"]["armor"] == 1 and
        is_equal_approx(world.fleet_r15.ship_hull_cap(), 180.0) and
        world.ship.primary_airframe_r55.armor_rank_r56 == 1 and
        world.ship.primary_airframe_r55.shield_rank_r56 == 0,
        "R56 paid heavy Guardian gets separate real hull upgrade"):return
    world._r45_select_owned_ship("ship_scout")
    if not check(is_equal_approx(world.fleet_r15.ship_hull_cap(), 120.0) and
        is_equal_approx(world.fleet_r15.ship_shield_cap(), 125.0) and
        is_equal_approx(world.fleet_r15.radar_range_r56(), 560.0) and
        world.hangar_modules_r56["ship_guardian"]["armor"] == 1,
        "R56 switching between owned craft must recall distinct module loadouts"):return
    world._save_progress()
    var wallet_after_modules: int = world.credits
    world.hangar_modules_r56 = HangarWorkbenchR56Script.default_roster()
    world._load_progress()
    world._r15_apply_loadout()
    if not check(world.credits == wallet_after_modules and
        world.hangar_modules_r56["ship_scout"]["armor"] == 1 and
        world.hangar_modules_r56["ship_scout"]["shield"] == 1 and
        world.hangar_modules_r56["ship_scout"]["radar"] == 1 and
        world.hangar_modules_r56["ship_guardian"]["armor"] == 1 and
        world.hangar_modules_r56["ship_interceptor"]["armor"] == 0 and
        is_equal_approx(world.radar.range_meters, 560.0),
        "R56 existing v1 save must preserve safe modules and actual radar"):return
    # No equipment purchases or progression can be executed mid-sortie.
    world.garage_hub_r39.visible = false
    world._r56_purchase_workbench_module("radar")
    if not check(world.credits == wallet_after_modules and
        world.hangar_modules_r56["ship_scout"]["radar"] == 1,
        "R56 module purchase needs visible and active home hangar"):return
    world.garage_hub_r39.visible = true
    world._r39_refresh_garage()
    print("NEBULA_R56_WORKSHOP_REAL_ARMOR_SHIELD_RADAR_PERSISTENT_CREDITS_SUCCESS")
    # R57: pure route contract requires a real ship position at EVERY
    # individual beacon for 1.5 seconds; accepting never pays currency.
    var patrol_unit = PatrolContractsR57Script.new()
    if not check(PatrolContractsR57Script.catalog().size() == 3 and
        PatrolContractsR57Script.safe_selection("hacked") == "" and
        PatrolContractsR57Script.reward_credits("aurora") == 380 and
        PilotAcademyR54Script.credit_bonus(380, "leya", 3) == 46 and
        PatrolContractsR57Script.reward_xp("neon") == 160 and
        PatrolContractsR57Script.checkpoint_count("rift") == 4 and
        not patrol_unit.begin("invalid") and patrol_unit.begin("aurora") and
        not patrol_unit.begin("neon"),
        "R57 contract board must offer exactly three valid repeatable routes"):return
    var untouched: String = patrol_unit.tick(0.25, Vector3.ZERO)
    if not check(untouched == "active" and
        patrol_unit.checkpoint_index == 0 and not patrol_unit.finished,
        "R57 selecting a contract without flying cannot complete any waypoint"):return
    for waypoint_index in PatrolContractsR57Script.checkpoint_count("aurora"):
        var target: Vector3 = patrol_unit.objective_position()
        for hold_index in 5:
            patrol_unit.tick(0.25, target)
        if not check(patrol_unit.checkpoint_index == waypoint_index,
            "R57 must require full 1.5 seconds at each 3D checkpoint"):return
        var result: String = patrol_unit.tick(0.25, target)
        if waypoint_index < 2 and not check(result == "checkpoint" and
            patrol_unit.checkpoint_index == waypoint_index + 1,
            "R57 partial route must advance navigation but never mark success"):return
        if waypoint_index == 2 and not check(result == "success" and
            patrol_unit.finished and not patrol_unit.active,
            "R57 only the final genuine waypoint can finish a timed contract"):return
    if not check(patrol_unit.tick(0.25, Vector3.ZERO) == "idle" and
        not patrol_unit.begin("untrusted"),
        "R57 completed sortie must not reopen reward or accept unknown IDs"):return
    var counts_safe: Dictionary = PatrolContractsR57Script.safe_finish_counts({
        "aurora": 999999999, "neon": -3, "rift":"free", "spoof":9})
    if not check(counts_safe["aurora"] == 99999 and
        counts_safe["neon"] == 0 and counts_safe["rift"] == 0 and
        not counts_safe.has("spoof"),
        "R57 v1 save must reject fake contract IDs/counts and clamp limits"):return
    if not check(patrol_unit.begin("neon"), "R57 contract replay must be selectable"):return
    patrol_unit.elapsed_seconds = 659.90
    var expired_result: String = patrol_unit.tick(0.25, Vector3.ZERO)
    if not check(expired_result == "failed" and not patrol_unit.active and
        not patrol_unit.finished and patrol_unit.last_result == "failed",
        "R57 time limit must fail unfinished route without any payout"):return
    print("NEBULA_R57_REAL_3D_WAYPOINTS_HOLD_TIMEOUT_AND_SAFE_COUNTS_SUCCESS")
    # R54: spend CR on an actual engine upgrade, purchase training for a
    # specific captain and persist through the existing version-1 save.
    if not check(world.garage_open_r39 and
        PilotAcademyR54Script.cost(0) == 650 and
        PilotAcademyR54Script.cost(1) == 1100 and
        PilotAcademyR54Script.cost(2) == 1800 and
        PilotAcademyR54Script.cost(3) == 0 and
        is_equal_approx(PilotAcademyR54Script.damage_multiplier("ada", 0.9, 1), 0.87) and
        is_equal_approx(PilotAcademyR54Script.thrust_multiplier("kai", 1.08, 2), 1.16) and
        PilotAcademyR54Script.credit_bonus(900, "leya", 3) == 108,
        "R54 captain academy must have bounded, actual ship and CR reward effects"):return
    var original_engine_rank: int = world.ship.engine_rank
    world.ship.engine_rank = 0
    world.credits = 3000
    world.selected_captain_r42 = "ada"
    world.pilot_training_r54 = {"ada":0, "kai":0, "leya":0}
    world._r39_refresh_garage()
    var new_hub = world.garage_hub_r39
    new_hub.engine_upgrade_r54.pressed.emit()
    if not check(world.credits == 2400 and world.ship.engine_rank == 1 and
        new_hub.engine_upgrade_r54.text.contains("1 100 CR"),
        "R54 garage engine workbench must spend 600 CR and install real rank"):return
    new_hub.section_buttons_r54["crew"].pressed.emit()
    new_hub.academy_train_button_r54.pressed.emit()
    if not check(world.credits == 1750 and
        int(world.pilot_training_r54.get("ada", -1)) == 1 and
        new_hub.academy_train_button_r54.text.contains("1 100 CR"),
        "R54 training must debit 650 CR and persist independent Ada rank"):return
    var training_wallet_after: int = world.credits
    world._save_progress()
    world.pilot_training_r54 = {"ada":0,"kai":0,"leya":0}
    world._load_progress()
    if not check(world.pilot_training_r54.get("ada", -1) == 1 and
        world.pilot_training_r54.get("kai", -1) == 0 and
        world.credits == training_wallet_after and
        world.ship.engine_rank == 1,
        "R54 version-1 local save must preserve credit wallet and academy separately"):return
    var sanitized: Dictionary = PilotAcademyR54Script.safe_roster(
        {"ada":999, "kai":-10, "leya":"free premium", "injected":"bad"})
    if not check(sanitized["ada"] == 3 and sanitized["kai"] == 0 and
        sanitized["leya"] == 0 and not sanitized.has("injected"),
        "R54 rank loading must clamp and reject unknown or spoofed captain data"):return
    world.mission_index = world.MISSIONS.size()
    new_hub.launch_button.pressed.emit()
    if not check(not world.garage_open_r39 and
        is_equal_approx(world.ship.damage_multiplier, 0.87) and
        world.ship.engine_rank == 1,
        "R54 actual departure must apply paid Ada training to combat damage"):return
    var wallet_before_no_reward: int = world.credits
    world._complete_mission()
    if not check(world.credits == wallet_before_no_reward,
        "R54 launch and training alone must never award campaign credits"):return
    # This runtime scenario exits immediately; do not certify hardware QA.
    print("NEBULA_R54_ACADEMY_REAL_SHIP_STATS_SAVE_AND_CREDITS_SUCCESS")
    # R58: earned reputation is derived from saved verified route counts,
    # not from XP, premium ownership, or a button that fabricates a rank.
    var rookie: Dictionary = CareerPrestigeR58Script.status({})
    var ranked_navigator_r58: Dictionary = CareerPrestigeR58Script.status({"aurora":3})
    var ace: Dictionary = CareerPrestigeR58Script.status({"aurora":4, "neon":5})
    var legend: Dictionary = CareerPrestigeR58Script.status({"aurora":12,"neon":9,"rift":3})
    if not check(rookie["rank"] == 0 and rookie["max_risk"] == 0 and
        rookie["remaining"] == 3 and ranked_navigator_r58["rank"] == 1 and
        ranked_navigator_r58["max_risk"] == 1 and ranked_navigator_r58["remaining"] == 6 and
        ace["rank"] == 2 and ace["max_risk"] == 2 and ace["remaining"] == 15 and
        legend["rank"] == 3 and legend["max_risk"] == 2 and
        legend["next_at"] == 0 and
        CareerPrestigeR58Script.total_completions(
            {"aurora":99999999, "neon":"free", "spoof":999}) == 99999,
        "R58 rank must be earned from validated completed-route counts"):return
    if not check(CareerPrestigeR58Script.safe_selected_tier("2", ace) == 0 and
        CareerPrestigeR58Script.safe_selected_tier(2, {"aurora":3}) == 0 and
        CareerPrestigeR58Script.safe_selected_tier(1, {"aurora":3}) == 1 and
        CareerPrestigeR58Script.safe_selected_tier(2, {"aurora":9}) == 2 and
        not CareerPrestigeR58Script.unlocked(2, {"aurora":3}) and
        CareerPrestigeR58Script.earned_credits("aurora", 0) == 380 and
        CareerPrestigeR58Script.earned_credits("aurora", 1) == 513 and
        CareerPrestigeR58Script.earned_credits("rift", 2) == 1715 and
        CareerPrestigeR58Script.earned_xp("neon", 2) == 264 and
        is_equal_approx(CareerPrestigeR58Script.available_seconds(
            "aurora", 1), 357.0),
        "R58 risk ranks must be locked and pay only bounded catalog rewards"):return
    var real_elite_points: Array[Vector3] = CareerPrestigeR58Script.challenge_route(
        "aurora", 2)
    if not check(real_elite_points.size() == 5 and
        real_elite_points[3].distance_to(
            real_elite_points[1]) < 0.01 and
        real_elite_points[4].distance_to(
            real_elite_points[0]) < 0.01,
        "R58 elite contract must add two genuine return-leg 3D waypoints"):return
    var accelerated_patrol = PatrolContractsR57Script.new()
    if not check(accelerated_patrol.begin("aurora") and
        not accelerated_patrol.configure_challenge_r58(
            real_elite_points, 357.0, 1) and
        accelerated_patrol.configure_challenge_r58(
            CareerPrestigeR58Script.challenge_route("aurora", 1),
            357.0, 1) and
        accelerated_patrol.route_size_r58() == 4 and
        is_equal_approx(accelerated_patrol.seconds_remaining(), 357.0),
        "R58 physical route engine must reject tampered extra points and timer"):return
    accelerated_patrol.tick(0.25, Vector3.ZERO)
    if not check(not accelerated_patrol.configure_challenge_r58(
        real_elite_points, 294.0, 2),
        "R58 live timed flight must reject changing tier mid-sortie"):return
    print("NEBULA_R58_EARNED_RANK_RISK_BOUNDED_PAY_AND_REAL_ROUTE_QA_SUCCESS")
    # R57 integrated career loop after story completion: the real hub button
    # arms a route; launch enables real 3D navigation; only the final
    # waypoint transitions back to the garage with exact once-paid credits.
    world._r39_create_garage_hub()
    world.credits = 1000
    world.xp = 0
    world.r57_selected_contract = ""
    world.r57_contract_counts = PatrolContractsR57Script.safe_finish_counts({})
    world.r58_risk_tier = 0
    world._r39_refresh_garage()
    var contract_hub = world.garage_hub_r39
    contract_hub.section_buttons_r54["operations"].pressed.emit()
    if not check(contract_hub.r57_contract_panel.visible and
        contract_hub.r57_contract_buttons.size() == 3 and
        world.mission_index == world.MISSIONS.size(),
        "R57 contract board must appear ONLY after the real story"):return
    contract_hub.r57_contract_buttons["aurora"].pressed.emit()
    if not check(world.r57_selected_contract == "aurora" and
        world.credits == 1000 and world.xp == 0 and
        contract_hub.launch_button.text.contains("КОНТРАКТ"),
        "R57 choosing a contract must only arm the job, not mint rewards"):return
    contract_hub.launch_button.pressed.emit()
    if not check(world.performance_lab_r11.layer == 7 and
        world.performance_lab_r11.visible,
        "R57 profiler must return to normal flight CanvasLayer after launching"):return
    if not check(world.r57_patrol.active and not world.garage_open_r39 and
        is_instance_valid(world.mission_beacon) and
        world.mission_beacon.get_node_or_null("R57_Genuine3DPhysicalBeacon") is MeshInstance3D and
        world.ship.navigation_target.distance_to(
            world.r57_patrol.objective_position()) < 0.01,
        "R57 sortie must create actual 3D beacon and flight navigation"):return
    world._r21_toggle_hangar()
    if not check(not world.store_r15.visible and
        not world.ship.controls_locked and world.r57_patrol.active,
        "R57 in-flight timed contract must prevent shop locking controls"):return
    world._r57_patrol_tick(0.25)
    if not check(world.credits == 1000 and world.xp == 0 and
        world.r57_patrol.checkpoint_index == 0,
        "R57 no immediate credit or XP for merely launching"):return
    for point_index in PatrolContractsR57Script.checkpoint_count("aurora"):
        var active_goal: Vector3 = world.r57_patrol.objective_position()
        world.ship.global_position = active_goal
        for hover_index in 6:
            world._r57_patrol_tick(0.25)
        if point_index < 2 and not check(world.credits == 1000 and
            not world.garage_open_r39 and
            world.r57_patrol.checkpoint_index == point_index + 1 and
            world.ship.navigation_target.distance_to(
                world.r57_patrol.objective_position()) < 0.01,
            "R57 partial real routes cannot pay out or skip the next goal"):return
    if not check(world.credits == 1380 and world.xp == 90 and
        world.r57_contract_counts["aurora"] == 1 and
        world.mission_index == world.MISSIONS.size() and
        world.garage_open_r39 and
        world.r57_last_report.contains("+380 CR") and
        not world.r57_patrol.active,
        "R57 finishing all three beacons must pay one bounded CR/XP reward"):return
    world._r57_end_patrol(true, "")
    if not check(world.credits == 1380 and
        world.r57_contract_counts["aurora"] == 1,
        "R57 duplicate reward trigger after returning to dock must be rejected"):return
    world.garage_hub_r39.section_buttons_r54["operations"].pressed.emit()
    world.garage_hub_r39.r57_contract_buttons["neon"].pressed.emit()
    world.garage_hub_r39.launch_button.pressed.emit()
    world.r57_patrol.elapsed_seconds = 659.90
    world._r57_patrol_tick(0.25)
    if not check(world.garage_open_r39 and world.credits == 1380 and
        world.xp == 90 and world.r57_contract_counts["neon"] == 0 and
        world.r57_last_report.contains("БЕЗ НАГРАДЫ"),
        "R57 timed-out route must safely return home without a bounty"):return
    world._save_progress()
    world.r57_selected_contract = ""
    world.r57_contract_counts = PatrolContractsR57Script.safe_finish_counts({})
    world._load_progress()
    if not check(world.r57_selected_contract == "neon" and
        world.r57_contract_counts["aurora"] == 1 and
        world.r57_contract_counts["neon"] == 0 and
        world.credits == 1380 and world.xp == 90,
        "R57 old v1 save must persist real contract selection/achievements and wallet"):return
    # Logistics academy must remain valuable after story completion:
    # previously trained Leya receives exactly 12% additional earned CR.
    world.selected_captain_r42 = "leya"
    world.pilot_training_r54["leya"] = 3
    world.garage_hub_r39.section_buttons_r54["operations"].pressed.emit()
    world.garage_hub_r39.r57_contract_buttons["aurora"].pressed.emit()
    world.garage_hub_r39.launch_button.pressed.emit()
    for route_index in PatrolContractsR57Script.checkpoint_count("aurora"):
        world.ship.global_position = world.r57_patrol.objective_position()
        for dwell_index in 6:
            world._r57_patrol_tick(0.25)
    if not check(world.garage_open_r39 and world.credits == 1806 and
        world.xp == 180 and world.r57_contract_counts["aurora"] == 2 and
        world.r57_last_report.contains("+426 CR") and
        world.mission_index == world.MISSIONS.size(),
        "R57 genuine career flight must include previously purchased Leya bonus once"):return
    if not check(world.performance_lab_r11.layer == 31 and
        world.performance_lab_r11.visible and world.garage_open_r39,
        "R57 after paid contract, FPS button must remain above the safe dock"):return
    print("NEBULA_R57_DOCK_PERF_CANVASLAYER_REAL_TOUCH_ACCESS_SUCCESS")
    print("NEBULA_R57_TRAINED_LOGISTICS_PILOT_REAL_CONTRACT_BONUS_SUCCESS")
    print("NEBULA_R57_REAL_REPEATABLE_PAYOUT_FAILURE_AND_CAREER_SAVE_SUCCESS")
    # R58 integrated reputation/tier game loop after R57 base regressions.
    # The user must complete three genuine contracts to unlock risk 1,
    # then nine to unlock risk 2. UI and world independently enforce this.
    world.selected_captain_r42 = "ada"
    world.r57_contract_counts = PatrolContractsR57Script.safe_finish_counts(
        {"aurora":3})
    world.r58_risk_tier = 0
    world.credits = 2000
    world.xp = 500
    world._r39_refresh_garage()
    var advanced_hub = world.garage_hub_r39
    advanced_hub.section_buttons_r54["operations"].pressed.emit()
    if not check(advanced_hub.r58_risk_buttons.size() == 3 and
        not advanced_hub.r58_risk_buttons[1].disabled and
        advanced_hub.r58_risk_buttons[2].disabled and
        advanced_hub.r58_reputation_label.text.contains("ШТУРМАН"),
        "R58 live garage must unlock acceleration only after three real routes"):return
    world._r58_select_risk_tier(2)
    if not check(world.r58_risk_tier == 0 and world.credits == 2000,
        "R58 illegal elite risk must not change a wallet or selected tier"):return
    advanced_hub.r58_risk_buttons[1].pressed.emit()
    if not check(world.r58_risk_tier == 1 and
        advanced_hub.r57_contract_buttons["aurora"].text.contains("513 CR") and
        advanced_hub.r57_contract_buttons["aurora"].text.contains("4 МАЯКА"),
        "R58 selected risk must update actual 3D contract offer and payment"):return
    advanced_hub.r57_contract_buttons["aurora"].pressed.emit()
    advanced_hub.launch_button.pressed.emit()
    if not check(world.r57_patrol.active and not world.garage_open_r39 and
        world.r57_patrol.risk_tier_r58 == 1 and
        world.r57_patrol.route_size_r58() == 4 and
        is_equal_approx(world.r57_patrol.seconds_remaining(), 357.0) and
        world.credits == 2000,
        "R58 risk-1 flight must use real extra waypoint without advance pay"):return
    for real_point in range(4):
        world.ship.global_position = world.r57_patrol.objective_position()
        for hold_frame in range(6):
            world._r57_patrol_tick(0.25)
        if real_point < 3 and not check(
                world.credits == 2000 and not world.garage_open_r39,
                "R58 intermediate elite return-leg waypoint must never pay"):return
    if not check(world.garage_open_r39 and world.credits == 2513 and
        world.xp == 617 and world.r57_contract_counts["aurora"] == 4 and
        world.r57_last_report.contains("+513 CR") and
        world.r57_last_report.contains("+117 XP"),
        "R58 risk-1 physical route must pay exact earned CR and XP once"):return
    world._r57_end_patrol(true, "")
    if not check(world.credits == 2513 and
        world.r57_contract_counts["aurora"] == 4,
        "R58 duplicate elite payout cannot replay after dock return"):return
    world.r57_contract_counts = PatrolContractsR57Script.safe_finish_counts(
        {"aurora":9})
    world._r39_refresh_garage()
    world.garage_hub_r39.section_buttons_r54["operations"].pressed.emit()
    var elite_hub = world.garage_hub_r39
    if not check(not elite_hub.r58_risk_buttons[2].disabled and
        elite_hub.r58_reputation_label.text.contains("АС"),
        "R58 elite challenge must unlock only after nine completed sorties"):return
    elite_hub.r58_risk_buttons[2].pressed.emit()
    elite_hub.r57_contract_buttons["rift"].pressed.emit()
    if not check(world.r58_risk_tier == 2 and
        elite_hub.r57_contract_buttons["rift"].text.contains("1715 CR") and
        elite_hub.r57_contract_buttons["rift"].text.contains("6 МАЯКА"),
        "R58 elite offer must show additional physical route and right credit"):return
    elite_hub.launch_button.pressed.emit()
    if not check(world.r57_patrol.risk_tier_r58 == 2 and
        world.r57_patrol.route_size_r58() == 6 and
        is_equal_approx(world.r57_patrol.seconds_remaining(), 700.0),
        "R58 high-risk real flight needs six beacons and genuine shorter timer"):return
    for elite_point in range(6):
        world.ship.global_position = world.r57_patrol.objective_position()
        for hover_frame in range(6):
            world._r57_patrol_tick(0.25)
    if not check(world.garage_open_r39 and world.credits == 4228 and
        world.xp == 1046 and world.r57_contract_counts["rift"] == 1 and
        world.r57_last_report.contains("+1715 CR") and
        world.r57_last_report.contains("+429 XP"),
        "R58 ace risk must award 1715 CR/429 XP only after six real points"):return
    world._save_progress()
    world.r58_risk_tier = 0
    world.r57_contract_counts = PatrolContractsR57Script.safe_finish_counts({})
    world._load_progress()
    if not check(world.r58_risk_tier == 2 and
        world.r57_contract_counts["aurora"] == 9 and
        world.r57_contract_counts["rift"] == 1 and
        world.credits == 4228 and world.xp == 1046,
        "R58 old v1 save must safely restore earned high-risk rights and wallet"):return
    world.r58_risk_tier = 2
    world.r57_contract_counts = PatrolContractsR57Script.safe_finish_counts({})
    world._save_progress()
    world._load_progress()
    if not check(world.r58_risk_tier == 0,
        "R58 saved elite risk with no earned completions must be downgraded"):return
    print("NEBULA_R58_REAL_HARDER_FLIGHTS_ONE_TIME_REWARDS_AND_SAFE_SAVE_SUCCESS")
    print("NEBULA_SMOKE_SUCCESS missions=1 upgrades=1 drones=%d premium3d=r21 physics-launch mobile-controls premium-hud controlled-lighting R20-baked-pbr" % world.drones.size())
    quit(0)
