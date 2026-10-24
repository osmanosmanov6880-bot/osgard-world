extends Node3D
## R135 W5: visual pointers for the three entirely SIMULATED challenge faults.
## No live sensor, equipment command, or external telemetry is used.
var marker_roots: Array[Node3D] = []
var marker_materials: Array[StandardMaterial3D] = []
var marker_labels: Array[Label3D] = []
var current_state: String = "idle"
var active_index: int = -1

func configure(optical_head: Node3D) -> void:
    var optics_parent: Node3D = optical_head if optical_head != null else self
    _add_indicator(optics_parent, Vector3(0.0, 0.14, 0.31), "OPTICAL / 01")
    _add_indicator(self, Vector3(1.54, 3.67, 4.78), "AIRFLOW / 02")
    _add_indicator(self, Vector3(-4.95, 0.62, 6.20), "INTERLOCK / 03")
    update_visuals(0, false, false, 0, 0.0)

func _add_indicator(parent: Node3D, location: Vector3, title: String) -> void:
    var assembly := Node3D.new()
    assembly.name = "SimulatedFault_" + title.replace(" / ", "_")
    assembly.position = location
    parent.add_child(assembly)

    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.08, 0.25, 0.30)
    material.emission_enabled = true
    material.emission = Color(0.08, 0.25, 0.30)
    material.emission_energy_multiplier = 0.65

    var indicator := MeshInstance3D.new()
    indicator.name = "GlowingFaultTarget"
    var disc := CylinderMesh.new()
    disc.top_radius = 0.22
    disc.bottom_radius = 0.22
    disc.height = 0.045
    disc.radial_segments = 20
    indicator.mesh = disc
    indicator.rotation_degrees.x = 90.0
    indicator.material_override = material
    assembly.add_child(indicator)

    var tag := Label3D.new()
    tag.name = "ReadableFaultTag"
    tag.text = title + "  [SIM]"
    tag.font_size = 42
    tag.pixel_size = 0.0052
    tag.position = Vector3(0, 0.43, 0)
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    tag.modulate = Color(0.50, 0.78, 0.87)
    assembly.add_child(tag)

    marker_roots.append(assembly)
    marker_materials.append(material)
    marker_labels.append(tag)

func update_visuals(fault_index: int, is_active: bool, is_completed: bool, step: int, elapsed: float) -> void:
    active_index = clampi(fault_index, 0, 2) if (is_active or is_completed) else -1
    current_state = "idle"
    if is_completed:
        current_state = "cleared"
    elif is_active and step >= 3:
        current_state = "inspected"
    elif is_active:
        current_state = "active"
    for i in range(marker_roots.size()):
        var highlighted: bool = i == active_index
        var cleared: bool = highlighted and current_state in ["inspected", "cleared"]
        var color := Color(0.19, 0.42, 0.49)
        if highlighted:
            color = Color(0.28, 0.95, 0.62) if cleared else Color(1.00, 0.42, 0.16)
        var pulse: float = (0.5 + 0.5 * sin(elapsed * 4.0)) if (highlighted and is_active and not cleared) else 0.0
        marker_roots[i].visible = is_active or is_completed
        marker_roots[i].scale = Vector3.ONE * (1.0 + 0.075 * pulse)
        marker_materials[i].albedo_color = color.darkened(0.36)
        marker_materials[i].emission = color
        marker_materials[i].emission_energy_multiplier = 0.48 + (0.95 * pulse if highlighted else 0.0)
        marker_labels[i].modulate = color
        # Text, not color alone, communicates the diagnostic result.
        var status: String = "READY"
        if highlighted:
            status = "CLEARED" if cleared else "INSPECT"
        var text_value: String = ["OPTICAL 01", "AIRFLOW 02", "INTERLOCK 03"][i] + " / " + status + " [SIM]"
        if marker_labels[i].text != text_value:
            marker_labels[i].text = text_value

func snapshot() -> Dictionary:
    var visible_count: int = 0
    for marker in marker_roots:
        if marker.visible:
            visible_count += 1
    return {
        "fault_marker_count": marker_roots.size(),
        "fault_marker_visible_count": visible_count,
        "fault_marker_active_index": active_index,
        "fault_visual_state": current_state
    }
