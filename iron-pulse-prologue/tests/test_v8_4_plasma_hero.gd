extends SceneTree
## V8.4 genuine Godot art regression: exposed central plasma must be legible.
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, meaning: String) -> void:
    checks += 1
    if not ok:
        failures.append(meaning)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Real playable Godot scene imports")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var core: MeshInstance3D = game.reactor_core
    _check(core != null and core.mesh is SphereMesh, "Animated original reactor has a true 3D sphere")
    _check((core.mesh as SphereMesh).radius >= 1.20,
        "The real core has been physically enlarged, not zoomed using a fake 2D overlay")
    var rig: Node3D = core.get_parent()
    var piers: int = 0
    var solid_midspan: bool = false
    for member in rig.get_children():
        if member is MeshInstance3D:
            if member.name.begins_with("OpenEnergySupport_"):
                piers += 1
                _check((member.mesh as BoxMesh).size.x < 0.5,
                    "Each real reactor support is slender and leaves the plasma sightline open")
            elif member.mesh is BoxMesh:
                var dims: Vector3 = (member.mesh as BoxMesh).size
                if dims.x > 3.4 and dims.z > 3.4 and dims.y > 0.3:
                    solid_midspan = true
    _check(piers == 4 and not solid_midspan,
        "Four real open support piers replace obstructing solid 5m stage beam")
    _check(game.reactor_rings.size() == 3, "All three original animated containment rings remain")
    for pivot in game.reactor_rings:
        var ring: MeshInstance3D = pivot.get_child(0) as MeshInstance3D
        _check(ring != null and ring.mesh is TorusMesh, "Original animated containment ring is physical geometry")
        if ring != null and ring.mesh is TorusMesh:
            var mesh: TorusMesh = ring.mesh as TorusMesh
            _check(mesh.outer_radius-mesh.inner_radius <= 0.061,
                "Emissive ring uses thin industrial filament instead of giant cyan crossing beam")
    var vault: IPReactorAtrium = game.reactor_atrium
    _check(vault.readout()["open_core_inspection"], "Earlier physical front armour throat remains genuinely open")
    _check(core.material_override == vault.core_plasma_material,
        "Existing original heat-driven GPU plasma shader is preserved")
    _check(vault._lights.size() == 5, "Lighting stays within existing physical light-count budget")
    if vault._lights.size() >= 2:
        _check(vault._lights[1].global_position.x < 9.0 and vault._lights[1].global_position.y < 9.0,
            "ECO-safe key light now lights camera-facing reactor armor instead of far wall")
        _check(vault._lights[1].light_energy > 2.0 and vault._lights[1].visible,
            "Real front reactor key light is bright and survives ECO quality budget")
    game._select_scenario("thermal")
    game.start_run()
    var saved: Dictionary = game.session.checkpoint()
    var button := InputEventKey.new()
    button.keycode = KEY_C
    button.pressed = true
    game._input(button)
    _check(game.cinematic_view and game.get_viewport().get_camera_3d() == vault.director_camera,
        "C uses genuine in-world cinematography instead of another fake UI card")
    _check(game.session.checkpoint() == saved,
        "Hero framing leaves real hazard timer and crew resources unchanged")
    game._input(button)
    _check(game.get_viewport().get_camera_3d() == game.camera and not game.cinematic_view,
        "Player returns to full first-person control after inspection")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.story.latest_key == "scan",
        "Original mission, scenario and radio story still work after art upgrades")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V8.4 PLASMA HERO PASS: %d real geometry and gameplay checks" % checks)
        quit(0)
    else:
        for entry in failures:
            push_error("V8.4 PLASMA HERO FAIL: "+entry)
        quit(1)
