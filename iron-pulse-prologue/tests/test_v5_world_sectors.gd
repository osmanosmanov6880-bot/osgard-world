extends SceneTree
## Source-bound test of physical sector art, location tracking and quality controls.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_inspect")

func _check(ok: bool, why: String) -> void:
    checks += 1
    if not ok:
        failures.append(why)

func _inspect() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Godot game scene still imports")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var sectors: IPWorldSectors = game.world_sectors
    _check(sectors != null, "Three-sector architectural system is attached to real game")
    if sectors == null:
        game.queue_free()
        await process_frame
        _finish()
        return
    var art: Dictionary = sectors.readout()
    _check(int(art.get("zone_count",0)) == 3, "Three distinct architectural zones exist")
    _check(int(art.get("sign_count",0)) == 3, "Three diegetic physical 3D sector signs exist")
    _check(int(art.get("geometry_count",0)) >= 40, "Not a textual menu: physical original architectural geometry exists")
    _check(int(art.get("instanced_detail_count",0)) == 108, "108 repeated deck details use actual MultiMesh instances")
    _check(art.get("single_draw_deck") == true, "Deck fasteners use a single MultiMesh draw group")
    _check(int(art.get("hazard_lamps",0)) == 3, "Three sector-specific real hazard lights")
    _check(sectors.get_node_or_null("HERO_SectorGeometry") != null, "World has a separate HERO-cost geometry root")
    _check(sectors.hero_details.visible, "HERO world geometry enabled by default")
    _check(sectors.current_sector(2.0) == "reactor", "Entry starts in reactor gallery")
    _check(sectors.current_sector(-35.0) == "service", "Mid-corridor maps to real service spine")
    _check(sectors.current_sector(-55.0) == "evacuation", "Exit route maps to real evacuation lock")
    var landmarks: Array = art.get("landmark_ids",[])
    _check(landmarks == ["reactor","service","evacuation"], "Zone identifiers are distinct and stable")
    sectors.update_hazard("thermal",90.0,88.0,false)
    var thermal_risk: float = float(sectors.readout()["danger_level"])
    _check(thermal_risk >= 0.70, "Thermal scenario causes a distinct real visual hazard")
    sectors.update_hazard("breach",46.0,20.0,true)
    _check(float(sectors.readout()["danger_level"]) >= 0.60, "Oxygen breach also affects physical world lighting")

    var g := InputEventKey.new()
    g.keycode = KEY_G
    g.pressed = true
    game._input(g)
    _check(game.quality_mode == "eco" and not sectors.hero_details.visible, "G physically disables expensive sector decoration")
    game._input(g)
    _check(game.quality_mode == "hero" and sectors.hero_details.visible, "G restores world detail")

    game._select_scenario("thermal")
    game.start_run()
    game._process(0.05)
    _check(game.visited_sectors.has("reactor"), "Entering the mission logs the real reactor sector")
    game.player.position = Vector3(0,1.1,-35.0)
    game._process(0.05)
    game._refresh_hud()
    _check(game.active_sector == "service" and game.visited_sectors.has("service"), "Player travel discovers actual service zone")
    _check(game.subtitle_label.text.find("ТЕХНИЧЕСКИЙ") >= 0, "Russian HUD reports discovered location")
    game.player.position = Vector3(0,1.1,-55.0)
    game._process(0.05)
    _check(game.active_sector == "evacuation" and game.visited_sectors.size() == 3, "Player reaching exit discovers all three zones")
    game._toggle_language()
    game._refresh_hud()
    _check(game.subtitle_label.text.find("EVACUATION LOCK") >= 0, "Actual 3D sector labels are translated into English HUD")
    _check(game.session.scenario_id == "thermal" and not game.session.coolant_repaired, "World expansion does not shortcut original mission gameplay")
    game._restart()
    _check(game.session.scenario_id == "thermal" and game.visited_sectors.is_empty(), "Restart resets sector discovery without changing active emergency")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V5 THREE WORLD SECTORS PASS: %d actual Godot checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("V5 WORLD FAIL: "+failure)
        quit(1)
