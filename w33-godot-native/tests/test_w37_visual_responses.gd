extends SceneTree
## Real Godot W37/W38 integration: cinematic incident light, reduced motion
## and accessible camera changes, without modifying the simulator itself.
const Core = preload("res://scripts/OSGARDCore.gd")
const TEST_SAVE = "user://osgard_w37_light_motion_test.cfg"
var checks: int = 0
var failed: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _verify(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failed.append(label)

func _run() -> void:
    var pack: PackedScene = load("res://Main.tscn") as PackedScene
    _verify(pack != null, "Actual Godot project scene exists")
    if pack == null:
        _done()
        return
    var ui: OSGARDMain = pack.instantiate() as OSGARDMain
    _verify(ui != null, "Actual native HUD")
    if ui == null:
        _done()
        return
    ui.core = Core.new(TEST_SAVE)
    ui.core.clear_data()
    root.add_child(ui)
    await process_frame
    await process_frame
    var complex: Node3D = ui.scene_3d.obsidian_stage
    _verify(complex != null, "Actual A7 architecture exists")
    if complex == null:
        ui.queue_free()
        _done()
        return
    var report: Dictionary = ui.scene_3d.cinematic_qa_readout()
    _verify(report.get("emergency_lighting") == false, "Idle reactor has no simulated emergency lamp")
    complex.set_alarm(true)
    report = ui.scene_3d.cinematic_qa_readout()
    _verify(report.get("emergency_lighting") == true, "A real 3D incident light is activated")
    complex.set_reduced_motion(false)
    complex._process(0.13)
    var first: float = float(ui.scene_3d.cinematic_qa_readout()["emergency_light_energy"])
    complex._process(0.38)
    var second: float = float(ui.scene_3d.cinematic_qa_readout()["emergency_light_energy"])
    _verify(absf(second-first) > 0.01, "Alarm lighting responds over real time")
    complex.set_reduced_motion(true)
    complex._process(0.2)
    var steady: float = float(ui.scene_3d.cinematic_qa_readout()["emergency_light_energy"])
    complex._process(0.7)
    _verify(is_equal_approx(float(ui.scene_3d.cinematic_qa_readout()["emergency_light_energy"]), steady), "Reduced motion removes alarm strobe")
    ui.scene_3d.apply_simulation({"view": 2, "quality": "eco", "drive_on": false, "hatch": 0.0, "rotor_angle": 0.0, "incident_triggered": true, "last_error": false, "reduced_motion": true})
    report = ui.scene_3d.cinematic_qa_readout()
    _verify(report.get("reduced_motion") == true, "Core accessibility flags reach native facility")
    _verify(report.get("hero_vs_eco") == "eco", "Emergency effects obey ECO mode")
    _verify(ui.scene_3d.camera.position.distance_to(ui.scene_3d._shot_target) < 0.01, "Accessible camera cuts avoid nausea-inducing travel")
    ui.scene_3d.apply_simulation({"view": 0, "quality": "hero", "drive_on": true, "hatch": 0.0, "rotor_angle": 0.1, "incident_triggered": false, "last_error": false, "reduced_motion": false})
    report = ui.scene_3d.cinematic_qa_readout()
    _verify(report.get("emergency_lighting") == false, "Resolved incident switches off original 3D light")
    _verify(report.get("running") == true, "Recovery reflects actual simulator running state")
    _verify(report.get("photorealistic_aaa_certified") == false, "Software tests do not masquerade as AAA certification")
    _verify(ui.mission_btns.size() == 6, "Six preserved interactive missions")
    _verify(ui.dial_a != null and ui.dial_b != null, "W36 physical A/B calibrators retained")
    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _done()

func _done() -> void:
    if failed.is_empty():
        print("OSGARD W37/W38 ACTUAL GODOT VISUAL RESPONSE PASS: %d checks" % checks)
        quit(0)
    else:
        for issue in failed:
            push_error("W37/W38: " + issue)
        quit(1)
