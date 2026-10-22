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
    if not check(world.ship.engine_flames.size() == 2,"Player ship should have dual animated thrusters"):return
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
    print("NEBULA_SMOKE_SUCCESS missions=1 upgrades=1 drones=%d premium3d=true fins=1440 docks=6" % world.drones.size())
    quit(0)
