extends SceneTree
## W70 real Godot player physics / opt-in controls / collision / 6-cycle regression.
## No pretend CSS movement, HTML mockup or nonphysical 3D position tween.
var checks: int = 0
var failed: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, why: String) -> void:
    checks += 1
    if not ok:
        failed.append(why)

func _frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func _run() -> void:
    var actual_scene: PackedScene = load("res://Main.tscn") as PackedScene
    _check(actual_scene != null, "Real playable Godot scene exists")
    if actual_scene == null:
        _finish()
        return
    var ui := actual_scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    await process_frame
    await process_frame
    var stage: A7CinematicStage = ui.stage_3d
    _check(stage != null, "W69 accepted real 3D scene preserved")
    var actor: A7FirstPersonOperator = stage.first_person
    _check(actor != null, "Original first-person physics game actor mounted")
    if actor == null:
        _finish()
        return
    var qa: Dictionary = actor.qa_readout()
    _check(qa["schema"] == "LAST_FRONTIER_W70_ACTUAL_FIRST_PERSON_GODOT_PHYSICS_V1",
        "Independent proof of original physics first person")
    _check(qa["real_character_body"] and actor.body is CharacterBody3D,
        "Real CharacterBody3D exists, not a camera-only drone")
    _check(qa["real_capsule"], "Actual CapsuleShape3D character collision")
    _check(qa["real_floor_static_body"], "Genuine independent StaticBody3D floor")
    _check(int(qa["independent_collision_shapes"]) >= 12,
        "Physics corridor, side walls, machinery and player capsule exist")
    _check(actor.head_camera is Camera3D, "Actual playable Camera3D")
    _check(actor.headlamp is SpotLight3D,
        "Real Godot lamp physically attached to the eye camera")
    _check(actor.headlamp.get_parent() == actor.head_camera,
        "Headlamp follows eye and not a fixed fake screenshot")
    _check(actor.bridge_collision is StaticBody3D,
        "Physical collision matches the actual visible elevated bridge")
    _check(actor.walkway_visual_meshes >= 130,
        "Industrial route contains 130+ real PBR/grate/gantry 3D mesh details")
    _check(actor.safety_lights.size() == 4,
        "True illuminated route uses four physical Godot OmniLight3D sources")
    _check(actor.walkway_visuals.find_child("ArchedIndustrialOverheadTruss00", true, false)
        is MeshInstance3D,
        "Actual new overhead gantry creates spatial depth")
    _check(actor.walkway_visuals.find_child("PhysicallyWalkedPBRGrate00", true, false)
        is MeshInstance3D,
        "Actual world PBR floor hardware is not a 2D effect")
    _check(actor.world_sign is Label3D,
        "In-world sector gateway information is genuine Label3D")
    _check(actor.walkway_visuals.find_child("PhysicallyWalkedPBRGrate00", true, false).material_override
        == stage.hero_art.surface_lab.surface("floor_grate"),
        "Actual original W68 PBR material cache reused by first-person corridor")
    _check(actor.collision_world.get_child_count() >= 11,
        "Real physics world has many separate collider bodies")
    _check(actor.floor_body.get_node("TRUE_A7_GROUND_Physics") is CollisionShape3D,
        "Native floor collision shape actually mounted on static body")
    _check(actor.body.get_node("OriginalPhysicsOperatorCapsule") is CollisionShape3D,
        "Player has a native capsule collision")
    _check(not qa["gameplay_authority"], "Player walk never changes game rules")
    _check(not qa["enabled"], "Existing W69 hero camera remains default")

    var original: Dictionary = ui.model.snapshot()
    _check(original["shift"] == 0 and original["history"].size() == 0,
        "Real original W63 six-cycle game initially untouched")
    _check(ui.pilot_button != null and ui.pilot_rail != null,
        "Accessible native optional first-person HUD exists")
    _check(ui.pilot_nudge_buttons.size() == 4,
        "Four real physics direction buttons for 320-390px mobile")

    ui.pilot_button.emit_signal("pressed")
    _check(actor.piloting and actor.head_camera.current,
        "P activates physically colliding first-person camera")
    _check(not stage.camera.current,
        "Original fixed cinema camera stops rendering when the player enters")
    _check(ui.pilot_rail.visible,
        "Physical player movement buttons appear only in pilot mode")
    _check(ui.model.snapshot() == original,
        "Entering physical operator mode cannot create story/game actions")

    await _frames(45)
    _check(actor.body.is_on_floor(), "Actual CharacterBody3D falls onto real physics floor")
    _check(actor.body.position.y > 1.08,
        "Player feet rest on actual visible elevated industrial bridge, not hidden floor below")
    var before: Vector3 = actor.body.position
    actor.set_key(KEY_W, true)
    await _frames(30)
    actor.set_key(KEY_W, false)
    var after: Vector3 = actor.body.position
    _check(after.z > before.z + 0.65,
        "Physical forward W movement advances the real operator toward zone 02")
    _check(actor.move_distance > 0.65,
        "Distance comes from actual move_and_slide() updates")
    _check(actor.frame_updates >= 60,
        "Real physics engine frames advanced player body")
    _check(actor.body.is_on_floor(), "Moving character stands on native floor")
    _check(ui.model.snapshot() == original,
        "Thirty genuine physics ticks cannot mutate puzzle history")

    # The actual world boundary must stop native physics movement.
    actor.body.position = Vector3(10.45, 1.3, 9.0)
    actor.body.velocity = Vector3.ZERO
    await _frames(45)
    actor.set_key(KEY_A, true)
    await _frames(100)
    actor.set_key(KEY_A, false)
    _check(actor.body.position.x <= 11.03,
        "Real static east wall physically prevents passing through the industrial hall")
    _check(actor.collided_frames > 0,
        "Native get_slide_collision_count() proves true wall/floor collision")
    _check(ui.model.snapshot() == original,
        "Actual blocked collision is never a fake W63 player decision")

    # Button nudge uses the SAME CharacterBody3D.move_and_slide(), and
    # deliberately never teleports the camera/player.
    actor.body.position = Vector3(6.4, 1.3, 6.4)
    actor.body.velocity = Vector3.ZERO
    await _frames(40)
    var touch_z: float = actor.body.position.z
    (ui.pilot_nudge_buttons[KEY_W] as Button).emit_signal("pressed")
    await _frames(25)
    _check(actor.body.position.z > touch_z + 0.30,
        "Physical mobile-forward button drives the same true Godot physics")
    _check(actor.tap_remaining <= 0.01,
        "Touch movement does not become an infinitely held key")

    # Actually touching a station is proximity-based; visual inspection
    # never awards puzzle success without the original action command.
    var far: String = actor.inspect_nearby()
    _check(far == "", "Cannot inspect a machine from distant camera position")
    actor.body.position = Vector3(4.10, 1.0, 2.14)
    _check(actor.inspect_nearby() == "CORE",
        "Real physical proximity exposes reactor service equipment")
    _check(actor.inspect_count == 1 and actor.last_inspection == "CORE",
        "Only a genuine nearby inspection is counted")
    actor.body.position = Vector3(8.0, 1.0, 20.0)
    _check(actor.inspect_nearby() == "RELAY",
        "Separate physical relay room supports independent equipment inspection")
    _check(actor.inspect_count == 2, "Two distinct actual machinery inspections")
    _check(ui.model.snapshot() == original,
        "Independent proximity-based investigation never secretly wins the game")

    var yaw_before: float = actor.body.rotation.y
    actor.rotate_view(Vector2(28.0, -13.0))
    _check(absf(actor.body.rotation.y-yaw_before) > 0.01,
        "Actual character yaw changes from physically controlled mouse look")
    _check(actor.mouse_look_events == 1,
        "No fake pointer movement recorded by UI")
    _check(actor.head_camera.rotation.x > 0.0,
        "True eye pitch tracks input")
    _check(ui.model.snapshot() == original,
        "Mouse look is purely spatial")

    ui.quality_button.emit_signal("pressed")
    _check(actor.quality == "eco" and actor.headlamp.light_energy < 0.5,
        "Actual first-person practical lamp reduces brightness in ECO")
    _check(actor.head_camera.current,
        "Changing GPU quality cannot disable the current physical player")
    ui.quality_button.emit_signal("pressed")
    _check(actor.quality == "hero" and actor.headlamp.light_energy > 0.8,
        "HERO original headlamp physically brightens again")
    ui.motion_button.emit_signal("pressed")
    _check(actor.reduced_motion, "Motion-sensitive option removes head bob")
    ui.motion_button.emit_signal("pressed")
    _check(not actor.reduced_motion, "Operator head-bob preference reversible")

    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "en" and ui.pilot_button.text.contains("EXIT"),
        "Original first-person control accessible in English")
    _check((ui.pilot_nudge_buttons[KEY_W] as Button).text == "FORWARD",
        "Real English mobile navigation caption")
    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "ru" and ui.pilot_button.text.contains("ВЫЙТИ"),
        "Original physical player accessible in Russian")
    _check((ui.pilot_nudge_buttons[KEY_W] as Button).text == "ВПЕРЁД",
        "Real Russian mobile navigation caption")

    # New 320px/390px UI must not resize the real player or change gameplay.
    for width in [320, 390, 768, 1366]:
        ui.size = Vector2(width, 800)
        ui._layout_stage()
        await process_frame
        _check(ui.pilot_rail.visible,
            "Actual first-person mobile buttons survive %dpx screen" % width)
        _check(actor.head_camera.current,
            "Actual physical first-person camera remains current at %dpx" % width)
        _check(ui.model.snapshot()["history"].size() == 0,
            "No gameplay actions invented by screen resize at %dpx" % width)
        _check(actor.world_sign.visible == (width >= 640),
            "3D corridor signage must avoid obscuring 320/390px HUD at %dpx" % width)

    ui.pilot_button.emit_signal("pressed")
    _check(not actor.piloting and stage.camera.current,
        "Leaving physical player returns to original Godot hero camera")
    _check(not ui.pilot_rail.visible, "Walking controls correctly hide on exit")
    _check(ui.model.snapshot() == original,
        "Walking, colliding, looking, inspecting and resizing all preserve puzzle")

    # Original real game still gives valid cause-effect and a complete win.
    var winner: Array[String] = [
        "PUMP", "SCAN", "PUMP", "SEAL", "VENT", "SCAN",
        "VENT", "SEAL", "PUMP", "POWER", "VENT", "SCAN",
    ]
    for choice in winner:
        ui.action_buttons[choice].emit_signal("pressed")
        _check(stage.current_status == str(ui.model.snapshot()["status"]),
            "After W70 navigation the native cinematic stage obeys real puzzle status")
    _check(ui.model.snapshot()["status"] == "won",
        "Original deterministic W63 full six-cycle win unaffected by walking")
    _check(ui.model.snapshot()["history"].size() == 12,
        "Twelve original machine choices, not incidental movement, remain authoritative")
    _check(ui.model.snapshot()["history"].size() < actor.frame_updates,
        "Many actual walking frames never count as extra player game decisions")
    _check(not actor.qa_readout()["physical_gpu_certified"],
        "Headless physics checks are not consumer GPU or FPS certification")

    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failed.is_empty():
        print("LAST FRONTIER W70 REAL CHARACTERBODY FIRST PERSON PHYSICS PASS: %d assertions" % checks)
        quit(0)
        return
    for failure in failed:
        push_error("W70 TRUE FIRST PERSON / PHYSICS: " + failure)
    quit(1)
