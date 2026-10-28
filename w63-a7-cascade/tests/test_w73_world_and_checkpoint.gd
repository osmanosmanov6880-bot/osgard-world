extends SceneTree
## W73 native acceptance: authentic eye ray against seven real collision
## bodies; full deterministic file restore of original core and three station
## games; malformed + forged event journal rejected in sandbox without
## changing the live game. No fake screenshots or simulated GPU.
var passed: int = 0
var failed: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, info: String) -> void:
    passed += 1
    if not ok:
        failed.append(info)

func _write_test_content(text: String) -> void:
    var file: FileAccess = FileAccess.open(
        A7SessionCheckpoint.FILE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(text)
        file.close()

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn") as PackedScene
    _check(scene != null,"Original full W72 Godot native scene must exist")
    if scene == null:
        _finish()
        return
    var ui := scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    await process_frame
    await process_frame
    var stage: A7CinematicStage = ui.stage_3d
    var actor: A7FirstPersonOperator = stage.first_person
    var equipment: A7FieldOperations = stage.field_operations
    var mission: A7SpatialMission = stage.spatial_mission
    var world: A7WorldInteraction = stage.world_interaction
    _check(world != null and world.ray is RayCast3D,
        "Actual native Godot physics RayCast3D exists inside game")
    _check(world.ray.get_parent() == actor.head_camera,
        "Game ray begins at actual native first-person Camera3D not UI")
    _check(world.targets.size() == 7,
        "Seven physically separate world-collision selectable components")
    _check(world.target_pieces.size() == 7,
        "All valve/relay/sync world ray colliders are individually identifiable")
    for obj in world.targets:
        _check(obj is StaticBody3D and obj.get_node(
            "NativeRaycastable3DCollision") is CollisionShape3D,
            "Actual machine hit target uses a physics collision shape")
        _check(obj.get_meta("w73_device_kind") in ["valve","relay","sync"],
            "Original machine ray target is bound to actual known field mechanic")
    _check(world.qa_readout()["actual_world_collision_layer"] == 8 and
        not world.qa_readout()["external_network"],
        "Native ray uses isolated collision layer, never remote resource")
    _check(world.look_at_active_target().is_empty(),
        "Real ray cannot select machine before entering physical operator mode")
    _check(world.interact(ui.model.snapshot()).is_empty(),
        "Off-world G input cannot fabricate an accepted machine choice")
    _check(equipment.qa_readout()["gameplay_authority"] == false,
        "Raycast only manipulates fictional A7 station not core rules")

    ui.field_start_button.emit_signal("pressed")
    ui.pilot_button.emit_signal("pressed")
    _check(mission.extended_mode and actor.piloting,
        "Opt-in W72 field mode and true Godot CharacterBody3D activated")
    _check(ui.world_reticle.visible and ui.world_use_button.visible,
        "Compact original 3D reticle and accessible G world button present")
    actor.body.position = A7FirstPersonOperator.START_POSITION
    _check(world.interact(ui.model.snapshot()).is_empty(),
        "Distant physical cast cannot set thermal valve out of range")
    _check(equipment.valve_index == 0,
        "Unobserved ray attempts never mutate actual valve or game")

    # Reproduce actual Chromium operator pose + W72 auto-camera focus
    # BEFORE manually aiming: the in-game camera itself must acquire the
    # physics target in its exact live first-person path.
    actor.body.position = Vector3(6.4,0.706,3.40)
    actor.body.rotation.y = PI
    actor.head_camera.rotation.x = 0.0
    ui._focus_physical_field_device("thermal",
        A7FieldOperations.CORE+Vector3(0,1.0,0))
    await create_timer(0.40).timeout
    var auto_hit: Dictionary = world.look_at_active_target()
    _check(auto_hit.get("kind","") == "valve",
        "W72 real in-game auto-focus from actual browser pose must point W73 ray at native physical valve")
    ui.field_focused_devices.clear()

    # Look directly at actual valve with the ORIGINAL native Camera3D.
    actor.body.position = Vector3(5.50,1.33,2.90)
    await physics_frame
    actor.head_camera.look_at(A7FieldOperations.CORE+Vector3(0,1.0,0.15),Vector3.UP)
    await physics_frame
    var hit: Dictionary = world.look_at_active_target()
    _check(not hit.is_empty() and hit.get("kind","") == "valve",
        "Actual original RayCast3D hits physical thermal valve when player aims at it")
    _check(str(hit.get("collider_name","")).contains("ThermalValve"),
        "First-person ray selected real valve collider not floating HUD")
    _check(float(hit.get("ray_distance",999.0)) <= 5.2,
        "Actual 3D ray physical hit is within allowed meters")
    var original_snapshot: Dictionary = ui.model.snapshot()
    ui._world_use()
    _check(equipment.valve_index == 1 and world.accepted_world_uses == 1,
        "Real G/world interaction rotates exactly one original Godot machine detent")
    _check(ui.model.snapshot() == original_snapshot,
        "Real RayCast3D mechanic never secretly issues original game action")
    _check(ui.checkpoint.events.size() == 2,
        "Accepted field start and true world-ray actuation both logged")
    for i in range(5):
        (ui.field_buttons["valve_plus"] as Button).emit_signal("pressed")
    _check(equipment.valve_solved and equipment.valve_index == 6,
        "Native world tool and accessible control act on same real valve model")
    actor.body.position = Vector3(5.50,1.33,2.90)
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 1,
        "True 3D solved valve and authenticated E advance first mission goal")
    ui.action_buttons["PUMP"].emit_signal("pressed")
    ui.action_buttons["SCAN"].emit_signal("pressed")
    _check(mission.phase == 2 and ui.model.snapshot()["history"].size() == 2,
        "Original two actions and incident are still actually required")
    _check(ui.checkpoint.events.size() == 10,
        "Checkpoint journal has genuine player actions, never arbitrary save state")
    _check(ui.checkpoint.write_packet(ui),
        "Real local user:// file save with bounded canonical event journal succeeds")
    _check(FileAccess.file_exists(A7SessionCheckpoint.FILE_PATH),
        "Actual physical persistent local Godot file exists")
    var packet: Dictionary = ui.checkpoint.create_packet(ui)
    var checkpoint_proof: Dictionary = ui.checkpoint._proof(ui)
    var file: FileAccess = FileAccess.open(
        A7SessionCheckpoint.FILE_PATH, FileAccess.READ)
    var original_data: String = file.get_as_text()
    file.close()
    _check(original_data.contains(A7SessionCheckpoint.SCHEMA),
        "Real saved JSON explicitly versioned with deterministic replay schema")
    _check(original_data.length() < A7SessionCheckpoint.LIMIT_BYTES,
        "Source-tested serialized local save remains under 64KB")
    _check(not ui.checkpoint.qa_readout()["checksum_is_tamper_protection"],
        "Unkeyed SHA256 is correctly described as corruption detection only")

    ui.action_buttons["PUMP"].emit_signal("pressed")
    _check(ui.model.snapshot()["history"].size() == 3,
        "Live original game can continue after checkpoint without freezing")
    _check(ui.checkpoint.restore_into(ui),
        "Valid saved shift replays all ten events in an isolated preflight scene")
    _check(ui.model.snapshot()["history"].size() == 2 and
        ui.checkpoint._proof(ui) == checkpoint_proof,
        "Restoration exactly recovers original game + five-stage spatial mission")
    _check(equipment.valve_index == 6 and equipment.valve_solved,
        "Loaded real 3D valve rotation and source parameters exactly match")
    _check(mission.phase == 2 and mission.extended_mode,
        "Loaded story remains in real second-hall relay objective")
    _check(ui.checkpoint.successful_restores == 1 and
        ui.checkpoint.last_replay_steps == 10,
        "Independent restore validates each actual accepted event once")
    _check(ui.checkpoint.events.size() == 10,
        "Restored journal retains exact deterministic continuation")
    _check(actor.piloting,
        "Physical operator mode restored after checkpoint when it was active")

    # Invalid checksum must not mutate current gameplay.
    var preserved_before: Dictionary = ui.checkpoint._proof(ui)
    _write_test_content(original_data.replace('"sha256":"','"sha256":"x'))
    _check(not ui.checkpoint.restore_into(ui),
        "Corrupt persisted SHA must fail before touching any live game")
    _check(ui.checkpoint._proof(ui) == preserved_before,
        "Failed integrity read leaves original live shift 100% untouched")

    # Rehash a plausible but forged step. Independent sandbox replay must
    # detect the false stage/metric proof and reject while leaving UI intact.
    var forged: Dictionary = packet.duplicate(true)
    var content: Dictionary = JSON.parse_string(str(forged["payload"]))
    (content["events"] as Array)[3]["proof_sha256"] = "0".repeat(64)
    var fake_payload: String = JSON.stringify(content)
    forged["payload"] = fake_payload
    forged["sha256"] = fake_payload.sha256_text()
    _write_test_content(JSON.stringify(forged))
    _check(not ui.checkpoint.restore_into(ui),
        "Rehashed but forged journal fails real sandbox gameplay replay proof")
    _check(ui.checkpoint._proof(ui) == preserved_before,
        "Rehashed malicious-looking save does not rewrite current original game")
    _write_test_content(original_data)

    # Continue the original already loaded real mission into the second
    # sector: solve physical routing, original full win, final contact sync.
    actor.body.position = Vector3(8.0,1.33,20.0)
    for i in range(3):
        if (equipment.relay_target & (1 << i)) != 0:
            (ui.field_buttons["relay_%d" % i] as Button).emit_signal("pressed")
    _check(equipment.relay_solved,
        "Three physical relays can be solved correctly AFTER checkpoint restore")
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 3,
        "Loaded physical relay inspection authorizes real subsequent game shift")
    var path: Array[String] = [
        "PUMP","SEAL","VENT","SCAN","VENT","SEAL",
        "PUMP","POWER","VENT","SCAN",
    ]
    for choice in path:
        (ui.action_buttons[choice] as Button).emit_signal("pressed")
    _check(ui.model.snapshot()["status"] == "won" and mission.phase == 4,
        "Full deterministic original twelve-decision win after restored relay")
    actor.body.position = Vector3(4.10,1.33,2.14)
    for i in equipment.sync_order:
        (ui.field_buttons["sync_%d" % i] as Button).emit_signal("pressed")
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 5 and equipment.sync_solved,
        "Full original six-cycle and three-mechanic advanced game finished")
    var completed: Dictionary = ui.checkpoint._proof(ui)
    _check(ui.checkpoint.write_packet(ui),
        "Finished original game + final physical interaction persist correctly")
    ui._restart()
    _check(not mission.active and ui.model.snapshot()["history"].is_empty(),
        "A live restart truly resets original core after finished checkpoint")
    _check(ui.checkpoint.restore_into(ui),
        "Completed 3D session reconstructs full win from bounded input journal")
    _check(ui.checkpoint._proof(ui) == completed,
        "Restored completed game has identical original metrics and spatial progression")
    _check(mission.phase == 5 and ui.model.snapshot()["status"] == "won",
        "Native replay doesn't mistake saved finished mission for fresh game")
    _check(ui.checkpoint.events.size() <= A7SessionCheckpoint.MAX_EVENTS,
        "Entire campaign replay journal remains within audited bound")

    ui.restart_button.emit_signal("pressed")
    _check(ui.checkpoint.events.is_empty() and not mission.active,
        "Restart clears only current active journal, not outside user files")
    ui.mission_button.emit_signal("pressed")
    _check(mission.active and not mission.extended_mode,
        "Original simpler W71 gameplay still works after all W73 restore tests")
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failed.is_empty():
        print("LAST FRONTIER W73 TRUE WORLD RAYCAST AND TRANSACTIONAL CHECKPOINT PASS: %d assertions" % passed)
        quit(0)
        return
    for message in failed:
        push_error("W73 NATIVE GAMEPLAY / FILE CHECKPOINT: " + message)
    quit(1)
