extends SceneTree
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
    var megadocks = world.get_node_or_null("HeroMegadocksR6")
    if not check(megadocks != null, "R6 industrial orbital megadocks absent"):return
    if not check(megadocks.hangar_count == 12, "Twelve curved hangars missing"):return
    if not check(megadocks.crane_count == 12, "Twelve detailed cargo cranes missing"):return
    if not check(megadocks.panels_instanced >= 1600, "PBR deck tiles not installed"):return
    if not check(megadocks.structural_instances >= 2100, "R6 GPU-instanced docking details missing"):return
    var skyline_r6 = world.get_node_or_null("SculpturalSkylineR6")
    if not check(skyline_r6 != null, "R6 sculptural skyline missing"):return
    if not check(skyline_r6.landmark_count == 6, "Six 3D arcologies required"):return
    if not check(skyline_r6.facade_fins >= 1000, "3D tower mullions insufficient"):return
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
    print("NEBULA_SMOKE_SUCCESS missions=1 upgrades=1 drones=%d premium3d=r6 fins=1440 docks=6 triple-engine=true curved-hangars=12" % world.drones.size())
    quit(0)
