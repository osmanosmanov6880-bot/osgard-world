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
    var legacy: MeshInstance3D = stage.get_node_or_null("A7PrecisionRing_0_00") as MeshInstance3D
    _check(legacy != null, "Original first segment is still native mesh geometry")
    if legacy != null:
        var legacy_mesh: BoxMesh = legacy.mesh as BoxMesh
        _check(legacy_mesh != null, "Legacy original profile is still a BoxMesh")
        if legacy_mesh != null:
            _check(legacy_mesh.size.distance_to(Vector3(0.095, 0.43, 0.14)) < 0.00001, "Legacy box size unchanged")
        _check(legacy.position.distance_to(Vector3(1.46, 2.32, 1.25)) < 0.00001, "Legacy box position unchanged")
        _check(legacy.basis.x.distance_to(Vector3.RIGHT) < 0.00001, "Legacy segment orientation unchanged")
        _check(legacy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Outer legacy segment still casts its shadow")
    # All 83 replaced nodes MUST be absent, not only the first of each ring.
    for ring_index in range(3):
        for segment in range(28):
            if ring_index == 0 and segment == 0:
                continue
            _check(not stage.has_node("A7PrecisionRing_%d_%02d" % [ring_index, segment]), "Legacy drawable removed for %d/%d" % [ring_index, segment])
    var batches: Array = stage.get("_precision_ring_batches")
    var authored_batches: Array = stage.get("_precision_ring_authored")
    _check(batches.size() == 3, "Exactly three grouped ring surfaces")
    _check(authored_batches.size() == 3, "All authored GPU write transforms preserved independently of the headless renderer")
    if batches.size() == 3:
        var count: int = 0
        for index in range(3):
            var part: MultiMeshInstance3D = batches[index] as MultiMeshInstance3D
            _check(part != null, "Each batch is a true Godot MultiMeshInstance3D")
            if part == null:
                continue
            _check(part.multimesh != null, "A real MultiMesh is allocated for ring %d" % index)
            if part.multimesh == null:
                continue
            _check(part.multimesh.transform_format == MultiMesh.TRANSFORM_3D, "True 3D instance transforms for ring %d" % index)
            _check(part.multimesh.visible_instance_count == -1, "All instances submitted for ring %d" % index)
            var profile: BoxMesh = part.multimesh.mesh as BoxMesh
            _check(profile != null, "Original box profile preserved on batch %d" % index)
            var original_size: Vector3 = Vector3(0.042 if index == 2 else 0.095, 0.43 if index == 0 else 0.34, 0.14)
            if profile != null:
                _check(profile.size.distance_to(original_size) < 0.00001, "Exact W47 box dimensions retained for ring %d" % index)
            var material: StandardMaterial3D = part.material_override as StandardMaterial3D
            _check(material != null, "W47 StandardMaterial3D shader retained for ring %d" % index)
            if material != null:
                var original_color: Color = Color("414c53") if index == 0 else Color("b9a17c") if index == 1 else Color("77c4b4")
                var original_metal: float = 0.90 if index == 0 else 0.80 if index == 1 else 0.12
                var original_rough: float = 0.24 if index == 0 else 0.29 if index == 1 else 0.30
                _check(material.albedo_color.is_equal_approx(original_color), "Original W47 PBR albedo retained for ring %d" % index)
                _check(is_equal_approx(material.metallic, original_metal), "Original W47 PBR metallic retained for ring %d" % index)
                _check(is_equal_approx(material.roughness, original_rough), "Original W47 PBR roughness retained for ring %d" % index)
                _check(material.emission_enabled == (index == 2), "Original W47 rim emission unchanged for ring %d" % index)
                if index == 2:
                    _check(is_equal_approx(material.emission_energy_multiplier, 1.35), "Inner teal optical emission power remains exactly W47")
            var expected_shadow: int = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if index == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
            _check(part.cast_shadow == expected_shadow, "Original HERO/structural shadow settings retained for ring %d" % index)
            var start_segment: int = 1 if index == 0 else 0
            _check(part.multimesh.instance_count == (27 if index == 0 else 28), "All original instances preserved for ring %d" % index)
            count += part.multimesh.instance_count
            var authored: Array = authored_batches[index] if authored_batches.size() == 3 else []
            _check(authored.size() == 28 - start_segment, "Every original W47 ring transform was passed to MultiMesh.set_instance_transform")
            if authored.size() != 28 - start_segment:
                continue
            # Independently reconstruct EVERY original W47 MeshInstance3D
            # location and rotation.z, including the last segment and Z axis.
            for i in range(start_segment, 28):
                var angle: float = TAU * float(i) / 28.0
                var original_radius: float = 1.46 - float(index) * 0.19
                var original_depth: float = 1.25 + float(index) * 0.10
                var original_position: Vector3 = Vector3(cos(angle) * original_radius, 2.32 + sin(angle) * original_radius, original_depth)
                var c: float = cos(-angle)
                var s: float = sin(-angle)
                var original_rotation: Basis = Basis(Vector3(c, s, 0.0), Vector3(-s, c, 0.0), Vector3.BACK)
                # --headless uses Godot's dummy RenderingServer; its
                # get_instance_transform() returns identity even though the
                # authored values were submitted. Validate those actual write
                # arguments here; W48 browser tests separately require true
                # WebGL RenderingServer readback for all 83 instances.
                var slot: int = i - start_segment
                var placed: Transform3D = authored[slot]
                if DisplayServer.get_name() != "headless":
                    var gpu: Transform3D = part.multimesh.get_instance_transform(slot)
                    _check(gpu.origin.distance_to(placed.origin) < 0.0001 and gpu.basis.x.distance_to(placed.basis.x) < 0.0001 and gpu.basis.y.distance_to(placed.basis.y) < 0.0001 and gpu.basis.z.distance_to(placed.basis.z) < 0.0001, "Actual native renderer retains GPU transform %d/%d" % [index, i])
                _check(placed.origin.distance_to(original_position) < 0.0001, "W47 absolute centre preserved %d/%d" % [index, i])
                _check(placed.basis.x.distance_to(original_rotation.x) < 0.0001, "W47 local X basis preserved %d/%d" % [index, i])
                _check(placed.basis.y.distance_to(original_rotation.y) < 0.0001, "W47 local Y basis preserved %d/%d" % [index, i])
                _check(placed.basis.z.distance_to(original_rotation.z) < 0.0001, "W47 normal and handedness preserved %d/%d" % [index, i])
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
    if batches.size() == 3 and batches[2] is MultiMeshInstance3D:
        _check(not (batches[2] as MultiMeshInstance3D).visible, "True inner rim GPU submission switches off in ECO")
        _check((batches[2] as MultiMeshInstance3D).multimesh.instance_count == 28, "ECO never deletes original inner ring geometry")
    rig.set_quality("hero")
    readout = rig.cinematic_qa_readout()
    _check(int(readout.get("visible_hero_details",0)) >= 75, "All HERO segments return without remeshing")
    if batches.size() == 3 and batches[2] is MultiMeshInstance3D:
        _check((batches[2] as MultiMeshInstance3D).visible, "Hero inner ring GPU batch restored")
        _check((batches[2] as MultiMeshInstance3D).multimesh.instance_count == 28, "HERO restores without remeshing the original 28 segments")
    _check(ui.mission_btns.size() == 6 and ui.view_btns.size() == 3, "All six real missions and three cameras remain")
    _check(ui.dial_a != null and ui.dial_b != null, "Real safety-checked A/B dials remain")
    _check(rig.w47_cinematic_framing_qa().get("hardware_fps_claimed") == false, "No synthetic GPU benchmark claim")
    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _done()

func _done() -> void:
    if errors.is_empty():
        print("W48 BATCHED REACTOR NATIVE SOURCE PASS: %d structural, PBR and 84 authored-transform checks; Godot headless GPU readback is NOT certified and must be confirmed by W48 Chromium" % assertions)
        quit(0)
    else:
        for problem in errors:
            push_error("W48 GEOMETRY QA FAILED: "+problem)
        quit(1)
