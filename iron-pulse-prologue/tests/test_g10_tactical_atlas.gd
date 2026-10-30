extends SceneTree
## G10 native Godot truth tests: real compiled Main.tscn and original crisis engine.
## Synthetic test movements are not physical Windows/Android/iOS certification.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool,reason: String) -> void:
    checks += 1
    if not ok:
        failures.append(reason)

func _key(game: Node,key: Key) -> void:
    var input_event := InputEventKey.new()
    input_event.keycode = key
    input_event.pressed = true
    game._input(input_event)

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE G10 ACTUAL TACTICAL ATLAS PASS: %d scene, live-schematic, localization, pause, mobile and save checks" % checks)
        quit(0)
        return
    for fail in failures:
        push_error("G10 ATLAS FAIL: " + fail)
    quit(1)

func _run() -> void:
    var module := IPTacticalAtlas.new()
    root.add_child(module)
    await process_frame
    _assert(module.readout()["schema"] == IPTacticalAtlas.SCHEMA,
        "Actual native atlas class must exist with stable readout schema")
    _assert(module.readout()["local_only"] and not module.readout()["telemetry_uploaded"] and
        not module.readout()["route_solver_used"] and not module.readout()["simulated_player_progress"],
        "Native tactical atlas must never forge pathfinding, remote telemetry or progress")
    var source := IPCrisisEngine.new()
    var terminals: Array[Dictionary] = [
        {"id":"scan","position":Vector3(0.0,1.0,-12.0)},
        {"id":"repair","position":Vector3(-2.0,1.0,-34.0)},
        {"id":"bus_a","position":Vector3(-2.0,1.0,-45.0)},
        {"id":"bus_b","position":Vector3(2.0,1.0,-45.0)}
    ]
    var relay: Array[Dictionary] = [{"id":"medbay","position":Vector3(3,1,-30)}]
    var field: Array[Dictionary] = [{"id":"sink","position":Vector3(-4,1,-35)}]
    module.configure(terminals,relay,field)
    var before: Dictionary = source.checkpoint()
    module.capture(source,Vector3(0,1,2),"scan","reactor","ru",true)
    var readout: Dictionary = module.readout()
    _assert(readout["active"] and readout["target"] == "scan" and
        absf(float(readout["straight_line_m"])-14.0) < 0.01,
        "Actual player-to-scanner schematic distance must be derived from real X/Z")
    _assert(readout["marker_count"] == 6 and readout["markers"].size() == 6,
        "Marker inventory includes actual terminals, relay and field station")
    _assert(readout["heat_c"] == snappedf(source.heat,0.1) and
        readout["oxygen_pct"] == snappedf(source.oxygen,0.1),
        "Atlas indicators read the real crisis engine, never fixed example values")
    _assert(source.checkpoint() == before,
        "Read-only capture may never mutate the real crisis-engine checkpoint")
    _assert(module.line_summary().contains("НАПРЯМУЮ"),
        "Russian translation must disclose straight-line distance")
    module.capture(source,Vector3(0,1,2),"repair","service","en",true)
    _assert(module.line_summary().contains("DIRECT") and module.readout()["target"] == "repair" and
        module.readout()["sector"] == "service",
        "English atlas uses the current objective and actual sector")
    module.capture(source,Vector3(0,1,2),"INVALID","evacuation","en",true)
    _assert(module.readout()["target"] == "" and float(module.readout()["straight_line_m"]) == 0.0,
        "Unknown objective cannot create fictitious station or route")
    module.configure(terminals+terminals,relay+relay,field+field)
    _assert(module.readout()["marker_count"] == 6,
        "Duplicate marker IDs cannot create fake physical stations")
    module.capture(source,Vector3(0,1,2),"scan","reactor","en",false)
    _assert(not module.readout()["active"] and module.readout()["target"] == "",
        "Intro/paused/non-playable snapshots are never treated as active navigation")
    module.queue_free()

    var scene: PackedScene = load("res://Main.tscn")
    _assert(scene != null,"Original actual Godot Main.tscn must import and instantiate")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _assert(game.atlas_panel != null and game.tactical_atlas != null and
        not game.atlas_panel.visible,
        "Native real-game tactical atlas must be mounted and opt-in hidden on intro")
    _assert(game.atlas_close_button.custom_minimum_size.y >= 48 and
        game.touch_atlas_button != null and
        game.touch_atlas_button.get_rect().size.y >= 44,
        "Close and physical mobile MAP touch targets must be accessible")
    var intro_checkpoint: Dictionary = game.session.checkpoint()
    _key(game,KEY_F2)
    _assert(not game.atlas_panel.visible and not game.paused and
        game.session.checkpoint() == intro_checkpoint,
        "Atlas may not silently activate before real game start")
    game.start_run()
    var game_checkpoint: Dictionary = game.session.checkpoint()
    var start_pos: Vector3 = game.player.global_position
    _key(game,KEY_F2)
    _assert(game.atlas_panel.visible and game.paused and
        not game.pause_panel.visible and not game.cinematic_view,
        "F2 opens actual native overlay, safely pausing true campaign time")
    _assert(game.atlas_dimmer != null and game.atlas_dimmer.visible and
        game.atlas_dimmer.mouse_filter == Control.MOUSE_FILTER_STOP,
        "Native G10 atlas focuses the player and prevents touches reaching background cockpit")
    _assert(game.atlas_title.text.contains("ТАКТИЧЕСКАЯ") and
        game.atlas_summary.text.contains("НАПРЯМУЮ"),
        "Map panel contains localized real-data summaries, not a static fake image")
    var inside: Dictionary = game.tactical_atlas.readout()
    _assert(inside["source"] == "actual_godot_engine_and_physical_scene_coordinates" and
        inside["target"] == game.wayfinder.goal_id(game.session.objective_id(),game.player.global_position),
        "Atlas target must equal the actual 3D wayfinder target and use true coordinates")
    _assert(inside["marker_count"] == game.terminals.size()+game.relay_terminals.size()+game.field_stations.size(),
        "G10 maps all physically authored active reactor terminal, relay and protocol stations")
    _assert(game.session.checkpoint() == game_checkpoint and game.player.global_position == start_pos,
        "Opening the pause map must not move the player or change gameplay state")
    game._physics_process(2.0)
    _assert(game.session.checkpoint() == game_checkpoint,
        "Paused map must stop all engine tick and time consumption")
    _key(game,KEY_L)
    _assert(game.locale == "en" and game.atlas_title.text.contains("TACTICAL") and
        game.atlas_disclaimer.text.contains("NOT A WALKABLE ROUTE") and
        game.atlas_legend.text.contains("PLAYER"),
        "Language switch within opened atlas updates real-native labels safely")
    _key(game,KEY_ESCAPE)
    _assert(not game.atlas_panel.visible and not game.atlas_dimmer.visible and not game.paused and
        game.session.checkpoint() == game_checkpoint,
        "ESC must return to original gameplay and preserve checkpoint")
    _key(game,KEY_F2)
    _key(game,KEY_F2)
    _assert(not game.paused and not game.atlas_panel.visible,
        "F2 atlas toggling is reversible without starting a second mission")
    game._gamepad_button(JOY_BUTTON_DPAD_LEFT)
    _assert(game.paused and game.atlas_panel.visible,
        "Standard gamepad D-pad left physically opens the atlas")
    game._gamepad_button(JOY_BUTTON_B)
    _assert(not game.paused and not game.atlas_panel.visible,
        "Standard gamepad B closes atlas instead of triggering other overlays")

    game._browser_css_size = Vector2i(390,844)
    game._layout_hud()
    await process_frame
    _assert(game.touch_ui.visible and game.atlas_panel.offset_right - game.atlas_panel.offset_left <= 390.0,
        "390px viewport has native playable mobile controls and bounded atlas width")
    _assert(game.touch_atlas_button.get_rect().size.y >= 44 and
        game.touch_atlas_button.visible,
        "Physical MAP/F2 button remains at least 44px in mobile layout")
    game.touch_atlas_button.pressed.emit()
    _assert(game.paused and game.atlas_panel.visible,
        "Real native touch MAP press enters the pause-aware atlas")
    game.atlas_close_button.pressed.emit()
    _assert(not game.paused and not game.atlas_panel.visible and not game.atlas_dimmer.visible,
        "Actual close-button removes scrim and restores gameplay after mobile access")
    var before_pause: Dictionary = game.session.checkpoint()
    game._pause_toggle()
    _key(game,KEY_F2)
    _assert(not game.atlas_panel.visible and game.paused,
        "Atlas may not overlay normal pause menu or change existing pause semantics")
    game._pause_toggle()
    _assert(game.session.checkpoint() == before_pause and not game.paused,
        "Existing pause/recovery and real saved checkpoint remain unchanged")
    game.queue_free()
    _finish()
