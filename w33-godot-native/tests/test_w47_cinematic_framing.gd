extends SceneTree
## W47 native Godot cinema validation based on the real W43 Chromium frames.
## Visual-only: original W31-derived OSGARDCore missions remain unchanged.
const Core = preload("res://scripts/OSGARDCore.gd")
const SAVE = "user://osgard_w47_original_lens_qa.cfg"
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_inspect")

func _check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures.append(message)

func _inspect() -> void:
    var scene: PackedScene = load("res://Main.tscn") as PackedScene
    _check(scene != null, "Real Godot Main.tscn loads")
    if scene == null:
        _done()
        return
    var ui: OSGARDMain = scene.instantiate() as OSGARDMain
    _check(ui != null, "Actual native operator HUD instantiates")
    if ui == null:
        _done()
        return
    ui.core = Core.new(SAVE)
    ui.core.clear_data()
    root.add_child(ui)
    await process_frame
    await process_frame
    var rig: OSGARDRig = ui.scene_3d
    _check(rig != null, "True scene architecture exists")
    var qa: Dictionary = rig.w47_cinematic_framing_qa()
    _check(qa.get("actual_gallery_fill") == true, "Real additional left bay lighting exists")
    _check(qa.get("gallery_fill_shadow_disabled") == true, "Additional fill avoids expensive dynamic shadows")
    _check(float(qa.get("gallery_fill_energy", 0.0)) > 0.6, "Hero lights left side of real industrial 3D set")
    _check(absf(float(qa.get("lens_fov", 0.0)) - 44.0) < 0.1, "Real hero optical lens is 44 degrees")
    _check(rig._shot_target.distance_to(Vector3(4.70, 3.05, 6.80)) < 0.01, "Focal hero camera is genuinely closer")
    var initial_target: Vector3 = rig._shot_target
    rig.set_view(2)
    qa = rig.w47_cinematic_framing_qa()
    _check(int(qa["camera_view"]) == 2, "Inspection view is independent")
    _check(absf(float(qa["lens_fov"]) - 48.0) < 0.1, "Technical service lens remains 48 degrees")
    _check(initial_target.distance_to(rig._shot_target) > 1.0, "Camera genuinely changes position")
    rig.set_view(1)
    _check(int(rig.w47_cinematic_framing_qa()["camera_view"]) == 1, "Third actual view remains available")
    rig.set_quality("eco")
    qa = rig.w47_cinematic_framing_qa()
    _check(is_zero_approx(float(qa["gallery_fill_energy"])), "ECO actually disables extra light")
    _check(rig.cinematic_qa_readout().get("machined_fastener_batch_visible") == false, "ECO disables HERO microgeometry")
    rig.set_quality("hero")
    qa = rig.w47_cinematic_framing_qa()
    _check(float(qa["gallery_fill_energy"]) > 0.6, "HERO restores practical gallery illumination")
    _check(rig.cinematic_qa_readout().get("machined_fastener_batch_visible") == true, "HERO restores real 3D fasteners")
    _check(qa.get("hardware_fps_claimed") == false, "No false GPU certification")
    _check(ui.mission_btns.size() == 6, "All six original playable missions remain")
    _check(ui.view_btns.size() == 3 and ui.dial_a != null and ui.dial_b != null, "Real cameras, dials and safe calibration retained")
    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _done()

func _done() -> void:
    if failures.is_empty():
        print("OSGARD W47 CINEMATIC HERO SOURCE PASS: %d actual Godot checks" % assertions)
        quit(0)
    else:
        for item in failures:
            push_error("W47 FAILED: " + item)
        quit(1)
