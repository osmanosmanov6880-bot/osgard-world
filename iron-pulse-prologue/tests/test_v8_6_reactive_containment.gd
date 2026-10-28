extends SceneTree
## V8.6: actual 3D crisis-reactive vent models, CPU-configured vapor and
## GPU-instanced sparks. No fabricated screenshots or game-state mutation.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _input_key(game: Node, key: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = key
    event.pressed = true
    game._input(event)

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _check(scene != null, "Real original Godot scene still imports")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var fx: IPContainmentFX = game.containment_fx
    _check(fx != null and fx.name == "A7_ReactivePressureRelief",
        "Actual scene contains separate authored environmental event system")
    if fx == null:
        game.queue_free()
        await process_frame
        _finish()
        return
    _check(fx.vents.size() == 3 and fx.readout()["physical_vent_modules"] == 3,
        "Three independent 3D pressure purge stations exist behind core")
    _check(fx.readout()["steam_puffs_original"] == 18,
        "18 authored original 3D vapor meshes are present")
    _check(fx.spark_cluster is MultiMeshInstance3D and fx.readout()["thermal_spark_instances"] == 16,
        "16 emergency spark streaks use one real GPU MultiMesh draw group")
    for idx in range(3):
        var module: Dictionary = fx.vents[idx]
        var station: Node3D = module["unit"]
        _check(station.global_position.x > 16.0 and station.global_position.z < -9.0,
            "Physical purges mounted at the far industrial reactor wall: "+str(idx))
        _check(station.get_node_or_null("HighPressureMainPipe") is MeshInstance3D,
            "Real 3D pressure pipe and mechanical flange: "+str(idx))
        _check(station.get_node_or_null("TurbineReliefNozzle") is MeshInstance3D,
            "Actual pressure release nozzle exists: "+str(idx))
        _check((module["shutter"] as Node3D).get_child_count() == 3,
            "Three physically rotating shutter blades in every unit: "+str(idx))
        _check((module["vapor"] as Node3D).get_child_count() == 6,
            "Six real textured translucent steam spheres per nozzle: "+str(idx))
        _check(station.get_node_or_null("PurgeStationDesignation") is Label3D,
            "Diegetic industrial machinery signage in the world: "+str(idx))
    fx.update_from_crisis("blackout",48.0,93.0,0.0,false,0,false,true)
    _check(fx.readout()["hazard_risk"] <= 0.01 and not fx.readout()["vapor_visible"],
        "Healthy reactor produces no fake emergency steam")
    var no_risk_angle: float = float(fx.readout()["shutter_angle"])
    fx.update_from_crisis("thermal",96.0,82.0,10.0,false,0,false,true)
    _check(fx.readout()["hazard_risk"] > 0.85 and fx.readout()["shutter_angle"] > 55.0,
        "Critical HEAT mechanically opens real pressure valves")
    _check(fx.readout()["vapor_visible"] and (fx.vents[0]["vapor"] as Node3D).visible,
        "Actual HEAT makes original semi-transparent vapor geometry appear")
    _check((fx.vents[0]["shutter"] as Node3D).rotation_degrees.x < -50.0,
        "Real shutter mesh, not textual UI, responds to high temperature")
    _check((fx._vent_indicator as StandardMaterial3D).emission.r > 0.95,
        "Heat visibly changes real industrial warning materials to orange")
    var thermal_angle: float = float(fx.readout()["shutter_angle"])
    _check(thermal_angle > no_risk_angle+40.0,
        "Game hazard changes actual physical purge machinery")
    fx.update_from_crisis("thermal",96.0,82.0,10.0,false,0,true,true)
    _check(fx.readout()["shutter_angle"] < thermal_angle-10.0,
        "Real QUENCH rescue choice visibly dampens pressure release")
    fx.update_from_crisis("breach",52.0,12.0,11.0,false,0,false,true)
    _check(fx.readout()["hazard_risk"] > 0.75 and fx.readout()["vapor_visible"],
        "Low oxygen triggers distinct AIR atmosphere rather than HEAT-only art")
    _check(fx.readout()["warning_scenario"] == "breach" and fx._vent_indicator.emission.b > 0.90,
        "AIR warning physically switches to cooler spectral color")
    fx.update_from_crisis("thermal",95.0,80.0,20.0,false,1,false,true)
    _check(fx.readout()["spark_burst_visible"] and fx.readout()["actual_surge_count"] == 1,
        "An actual pulse event triggers GPU-instanced short emergency spark burst")
    var submitted: Array = fx.readout()["spark_0_render_submission"]
    var spark_location := Vector3(float(submitted[0]),float(submitted[1]),float(submitted[2]))
    _check(spark_location.distance_to(Vector3(12.6,7.2,-20.5)) < 3.0 and
        fx.spark_cluster.multimesh == fx._spark_meshes,
        "Actual spark position is submitted to original reactor GPU MultiMesh")
    fx.update_from_crisis("thermal",95.0,80.0,22.0,false,1,false,true)
    _check(not fx.readout()["spark_burst_visible"],
        "Surge animation self-terminates; no infinite looping false alarm")
    fx.update_from_crisis("thermal",95.0,80.0,23.0,false,0,false,true)
    fx.update_from_crisis("thermal",95.0,80.0,24.0,false,1,false,true)
    _check(fx.readout()["spark_burst_visible"] and fx.readout()["actual_surge_count"] == 1,
        "New run with reset pulse counter can trigger a fresh original burst")
    fx.update_from_crisis("thermal",95.0,80.0,25.0,true,1,false,true)
    _check(not fx.readout()["vapor_visible"] and not fx.readout()["spark_burst_visible"],
        "Reduced-motion hides particle animations while preserving warning state")
    _check(fx.readout()["shutter_angle"] > 55.0 and fx._vent_indicator.emission.r > 0.95,
        "Accessible safety warnings remain visible even when animations are reduced")
    fx.update_from_crisis("thermal",95.0,80.0,26.0,false,1,false,true)
    fx.set_quality("eco")
    _check(fx.readout()["quality"] == "eco" and not fx.readout()["vapor_visible"],
        "ECO renders machine hardware but suppresses costly vapor meshes")
    _check((fx.vents[0]["unit"] as Node3D).visible and (fx.vents[0]["shutter"] as Node3D).visible,
        "ECO preserves actual industrial pressure model and state")
    fx.set_quality("hero")
    _check(fx.readout()["quality"] == "hero" and fx.readout()["vapor_visible"],
        "HERO brings back detailed crisis atmosphere without rebuilding game state")
    var snap: Dictionary = fx.readout()
    fx.update_from_crisis("blackout",48.0,93.0,999.0,false,0,false,false)
    _check(fx.readout() == snap, "Paused/finished game cannot silently update world crisis FX")

    game._select_scenario("thermal")
    game.start_run()
    var checkpoint: Dictionary = game.session.checkpoint()
    game.session.heat = 95.0
    game.session.oxygen = 73.0
    game._process(0.016)
    _check(game.containment_fx.readout()["hazard_risk"] > 0.85 and game.containment_fx.readout()["warning_scenario"] == "thermal",
        "Actual main Godot game drives physical V8.6 FX from live IPCrisisEngine metrics")
    _check(game.session.checkpoint()["heat"] == 95.0 and game.session.checkpoint()["oxygen"] == 73.0,
        "Environmental FX never writes or cheats underlying emergency resources")
    _input_key(game,KEY_V)
    game._process(0.016)
    _check(game.reduced_motion and game.containment_fx.readout()["reduced_motion"],
        "Existing player V shortcut genuinely switches new atmosphere to accessibility mode")
    _input_key(game,KEY_G)
    _check(game.quality_mode == "eco" and game.containment_fx.readout()["quality"] == "eco",
        "Existing G key scales new atmosphere together with whole game")
    _input_key(game,KEY_G)
    _check(game.quality_mode == "hero" and game.containment_fx.readout()["quality"] == "hero",
        "Existing G key restores HERO visual quality")
    _check(game.terminals.size() == 6 and game.relay_terminals.size() == 3,
        "All six original scenario terminals and three strategic rescue relays preserved")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.story.latest_key == "scan",
        "Actual original 3D scanner, objective and MARA narrative still run")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V8.6 REACTIVE CONTAINMENT PASS: %d real Godot visual/game checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("V8.6 REACTIVE FX FAIL: "+failure)
        quit(1)
