extends SceneTree
## W48: real Godot compatibility-renderer optimization, not an invented FPS number.
## 84 original hand-placed box segments must render through 1 retained legacy
## drawable and 3 GPU MultiMesh batches. Scene, materials and core unchanged.
const Core = preload("res://scripts/OSGARDCore.gd")
const SAVE = "user://osgard_w48_ring_batch_qa.cfg"
var assertions: int = 0
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        errors.append(label)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    _check(packed != null, "Actual original Godot scene imports")
    if packed == null:
        _done()
        return
    var ui: OSGARDMain = packed.instantiate() as OSGARDMain
    _check(ui != null, "Real operator game UI instantiated")
    if ui == null:
        _done()
        return
    ui.core = Core.new(SAVE)
    ui.core.clear_data()
    root.add_child(ui)
    await process_frame
    await process_frame
    var rig: OSGARDRig = ui.scene_3d
    var stage: Node3D = rig.obsidian_stage
    _check(stage != null, "Real 3D reactor stage exists")
    _check(stage.has_node("A7PrecisionRing_0_00"), "Legacy physical first ring segment preserved")
    _check(not stage.has_node("A7PrecisionRing_0_01"), "Other outer segments are not wasted MeshInstance drawables")
    _check(not stage.has_node("A7PrecisionRing_1_00"), "Middle ring is actually instanced")
    _check(not stage.has_node("A7PrecisionRing_2_00"), "Inner rim is actually instanced")
    var batches: Array = stage.get("_precision_ring_batches")
    _check(batches.size() == 3, "Exactly three grouped ring surfaces")
    if batches.size() == 3:
        var count: int = 0
        for index in range(3):
            var part: MultiMeshInstance3D = batches[index] as MultiMeshInstance3D
            _check(part != null, "Each batch is a true Godot MultiMeshInstance3D")
            if part == null:
                continue
            _check(part.multimesh != null and part.multimesh.mesh is BoxMesh, "Original real box profile preserved on batch %d" % index)
            _check(part.material_override != null, "Original PBR rim material preserved on batch %d" % index)
            _check(part.multimesh.instance_count == (27 if index == 0 else 28), "All original segment positions included in batch %d" % index)
            var start: int = 1 if index == 0 else 0
            var expected_radius: float = 1.46 - float(index) * 0.19
            var expected_depth: float = 1.25 + float(index) * 0.10
            var first: Transform3D = part.multimesh.get_instance_transform(0)
            var theta: float = TAU * float(start) / 28.0
            var position: Vector3 = Vector3(cos(theta) * expected_radius, 2.32 + sin(theta) * expected_radius, expected_depth)
            _check(first.origin.distance_to(position) < 0.0001, "Original ring transform position preserved for %d" % index)
            var expected_basis: Basis = Basis(Vector3.BACK, -theta)
            _check(first.basis.x.distance_to(expected_basis.x) < 0.0001, "Original segment angle and handedness preserved for ring %d" % index)
            count += part.multimesh.instance_count
        _check(count == 83, "One legacy segment + 83 instanced segments exactly matches original 84")
    var readout: Dictionary = rig.cinematic_qa_readout()
    _check(readout.get("precision_ring_gpu_batches") == 3, "Original renderer reports 3 actual instanced batches")
    _check(readout.get("precision_ring_drawable_nodes") == 4, "84 original box drawable nodes reduced to four")
    _check(readout.get("precision_ring_segments_total") == 84, "No mechanical ring detail visually discarded")
    _check(int(readout.get("hero_details",0)) >= 75, "Historical W35 HERO visual quality budget retained")
    _check(int(readout.get("visible_hero_details",0)) >= 75, "Original W35 HERO detail availability retained")
    rig.set_quality("eco")
    readout = rig.cinematic_qa_readout()
    _check(int(readout.get("visible_hero_details",-1)) == 0, "ECO hides the complete instanced inner optical rim")
    _check(not (batches[2] as MultiMeshInstance3D).visible, "True inner rim GPU submission switches off in ECO")
    rig.set_quality("hero")
    readout = rig.cinematic_qa_readout()
    _check(int(readout.get("visible_hero_details",0)) >= 75, "All HERO segments return without remeshing")
    _check((batches[2] as MultiMeshInstance3D).visible, "Hero inner ring GPU batch restored")
    _check(ui.mission_btns.size() == 6 and ui.view_btns.size() == 3, "All six real missions and three cameras remain")
    _check(ui.dial_a != null and ui.dial_b != null, "Real safety-checked A/B dials remain")
    _check(rig.w47_cinematic_framing_qa().get("hardware_fps_claimed") == false, "No synthetic GPU benchmark claim")
    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _done()

func _done() -> void:
    if errors.is_empty():
        print("W48 BATCHED REACTOR ORIGINAL GODOT PASS: %d native checks / 84 visual segments in 4 drawables" % assertions)
        quit(0)
    else:
        for problem in errors:
            push_error("W48 GEOMETRY QA FAILED: "+problem)
        quit(1)
