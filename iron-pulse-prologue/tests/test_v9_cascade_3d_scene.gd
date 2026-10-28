extends SceneTree
## V9: actual real 3D game actions and input; cannot be faked by direct
## manipulation of engine.progress without real physical operator terminals.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _press(game: Node,code: Key) -> void:
    var input := InputEventKey.new()
    input.keycode = code
    input.pressed = true
    game._input(input)

func _pad_a(game: Node) -> void:
    var event := InputEventJoypadButton.new()
    event.button_index = JOY_BUTTON_A
    event.pressed = true
    game._input(event)

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _check(scene != null, "Actual native Godot world still loads with V9")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    _check(game.cascade_world is IPCascadeStations, "Original player scene instantiates V9 physical route")
    _check(game.cascade_world.stations.size()==4, "Four actual 3D consoles distributed across playable sectors")
    var data: Dictionary = game.cascade_world.readout()
    _check(data.get("physical_3d_consoles")==4 and data.get("animated_3d_dials")==4,
        "Every cascade station is an independently authored real Godot node")
    _check(data.get("station_ids")==["start","bridge","sync","lock"],
        "Physical reactor/service/evacuation/return sequence is source-bound")
    for index in range(4):
        var station: Dictionary = game.cascade_world.stations[index]
        var node: Node3D = station["node"]
        _check(node != null and node.get_node_or_null("OperatorScreen") is MeshInstance3D,
            "Each physical console has a real screen in scene: "+str(index))
        _check(node.get_node_or_null("MachinedBrow") is MeshInstance3D and
            node.get_node_or_null("InWorldStationLabel") is Label3D,
            "Each console has machined environment mesh and physical 3D sign: "+str(index))
        _check((station["dial"] as Node3D).get_node_or_null("MachinedDialRotor") is MeshInstance3D,
            "Each real instrument contains mechanical circular rotor: "+str(index))
        _check((station["indicator"] as MeshInstance3D).mesh is BoxMesh,
            "Each actual console has a physical colored status band")
        _check(absf(node.position.x)<6.1 and node.position.z>=-58.0 and node.position.z<=-9.0,
            "Optional gameplay station placed in existing safe industrial corridor")
    _check(game.cascade_world.readout()["active_station"] == "start",
        "Idle world physically highlights operator START console")
    _check(game.terminals.size()==6 and game.relay_terminals.size()==3,
        "Previous 6 main stations and 3 rescue consoles are preserved")

    game._select_scenario("blackout")
    game.start_run()
    game.player.position = Vector3(4.5,1.1,-18.5)
    var before: int = game.session.faults
    _press(game,KEY_E)
    _check(game.session.cascade_state == "idle" and game.session.faults == before+1,
        "Genuine E at 3D start console cannot bypass old scanner/repair objectives")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    _press(game,KEY_E)
    _check(game.session.core_scanned, "Legacy scanner still works through real keyboard E")
    game.player.position = Vector3(3.0,1.1,-28.0)
    _press(game,KEY_E)
    _check(game.session.coolant_repaired, "Legacy repair still works despite nearby new V9 consoles")

    game.player.position = Vector3(4.5,1.1,-18.5)
    _press(game,KEY_E)
    _check(game.session.cascade_state == "active" and game.session.cascade_phase == 0,
        "Actual E at physical reactor ARM terminal starts game-mode cascade deadline")
    _check(game.story.latest_key == "cascade_started", "Physical station triggers authored radio dialogue")
    _check(game.allocation_label.text.contains("78") and game.guidance_label.text.contains("КАСКАД"),
        "Real RU HUD shows operating countdown and target guidance")
    _check(game.cascade_world.readout()["active_station"] == "bridge",
        "Physically highlighted active switch moves to distinct service-sector node")

    game.player.position = Vector3(-4.5,1.1,-40.5)
    _pad_a(game)
    _check(game.session.cascade_phase == 1 and game.story.latest_key == "cascade_bridge",
        "Gamepad A on physical BRIDGE console advances real time-critical challenge")
    _check(game.cascade_world.readout()["active_station"] == "sync",
        "World indicator and guidance advance to real evacuation synchronizer")

    game.player.position = Vector3(4.5,1.1,-52.0)
    _press(game,KEY_E)
    _check(game.session.cascade_phase == 2 and game.story.latest_key == "cascade_sync",
        "Physical E at EVACUATION console updates engine and original localized story")
    _check(game.cascade_world.readout()["active_station"] == "lock",
        "A7 reactor terminal becomes actual final target on return route")
    var heat_pre: float = game.session.heat
    game.player.position = Vector3(4.5,1.1,-25.0)
    _press(game,KEY_E)
    _check(game.session.cascade_state=="completed" and game.session.cascade_phase==3,
        "Actual final station ends three-stage side mission successfully")
    _check(game.session.heat < heat_pre-14.0 and game.session.door_charge>=15.0,
        "Player achievement yields real cooling/door capacity, not a trophy sticker")
    _check(game.story.latest_key == "cascade_complete" and game.allocation_label.text.contains("СТАБИЛИЗИРОВАН"),
        "Final original MARA radio and translated HUD acknowledge real rescue achievement")
    _check(game.cascade_world.readout()["active_station"] == "",
        "All four actual world consoles stop advertising fake new objectives")
    _check((game.cascade_world.stations[3]["indicator"] as MeshInstance3D).material_override ==
        game.cascade_world._done_mat,
        "Final physical operator console changes to true success state")

    # Actual offline persistence, same Continue entrypoint as earlier releases.
    var slot: String = "user://iron_pulse_v9_cascade_scene_ci.json"
    game.checkpoint_path = slot
    game.checkpoint_store.clear(slot)
    var saved_position: Vector3 = game.player.position
    _check(game.checkpoint_store.save(game._checkpoint_payload(),slot),
        "Real offline checkpoint records completed 3D cascade operation with SHA-256 wrapper")
    game.session.reset("thermal")
    game.story.reset("thermal")
    game.selected_scenario = "thermal"
    game.player.position = Vector3(0,1.1,2.0)
    _check(game._continue_checkpoint(),
        "Original physical Continue button handler restores complete V9 campaign")
    _check(game.session.cascade_state=="completed" and game.session.cascade_phase==3,
        "All three physically visited stations persist through actual save/load")
    _check(game.session.scenario_id=="blackout" and game.player.position.distance_to(saved_position)<0.01,
        "Real scenario and actual player position survive checkpoint recovery")
    _check(game.story.latest_key=="cascade_complete" and game.cascade_world.readout()["active_station"]=="",
        "Local narrative history and real 3D status are both restored")
    _check(game.checkpoint_store.clear(slot),"Temporary native test save cleaned")

    # NEW: non-destructive V9 side task must not break old normal escape path.
    game._restart()
    _check(game.session.cascade_state=="idle" and game.session.cascade_phase==0,
        "Restart resets optional cascade without inherited rewards")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    game.player.position = Vector3(3.0,1.1,-28.0)
    game._interact()
    _check(game.session.coolant_repaired and game.session.cascade_state=="idle",
        "Old scanner/repair route remains available without starting cascade")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 PHYSICAL CAMPAIGN PASS: %d real scene/input/save checks" % checks)
        quit(0)
    else:
        for item in failures:
            push_error("V9 PHYSICAL CASCADE FAIL: "+item)
        quit(1)
