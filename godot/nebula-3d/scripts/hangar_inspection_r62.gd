extends Node3D
## R62: physically meshed inspection actuators on the actual chosen NX hull.
## Decorative inspection geometry only; never modifies CharacterBody3D flight.
const HULLS := ["ship_scout", "ship_interceptor", "ship_guardian"]
const MODES := ["overview", "cockpit", "engines", "underside"]

var selected_hull: String = "ship_scout"
var inspection_mode: String = "overview"
var low_detail: bool = false
var mounted_root: Node3D
var control_hinges: Array[Node3D] = []
var landing_stays: Array[Node3D] = []
var cosmetic_details: Array[MeshInstance3D] = []
var highlight_lenses: Array[MeshInstance3D] = []
var accent_material: StandardMaterial3D
var clock: float = 0.0

func _ready() -> void:
    name = "R62_ArticulatedAirframeInspection"
    _rebuild()
    set_process(true)

func _mat(tint: Color, metallic: float, rough: float,
        glow: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.metallic = metallic
    material.roughness = rough
    if glow > 0.0:
        material.emission_enabled = true
        material.emission = tint
        material.emission_energy_multiplier = glow
    return material

func _box(parent: Node3D, part_name: String, dims: Vector3,
        at: Vector3, material: Material, minor: bool = false) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    var geometry := BoxMesh.new()
    geometry.size = dims
    part.name = part_name
    part.mesh = geometry
    part.position = at
    part.material_override = material
    parent.add_child(part)
    if minor:
        cosmetic_details.append(part)
    return part

func _tube(parent: Node3D, part_name: String, radius: float,
        length: float, at: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    var geometry := CylinderMesh.new()
    geometry.top_radius = radius
    geometry.bottom_radius = radius
    geometry.height = length
    geometry.radial_segments = 24
    part.name = part_name
    part.mesh = geometry
    part.position = at
    part.rotation.x = PI * 0.5
    part.material_override = material
    parent.add_child(part)
    return part

func _profile() -> Dictionary:
    match selected_hull:
        "ship_interceptor":
            return {"span": 7.2, "length": 13.8,
                "drives": [-1.33, 1.33], "canopy_z": -2.65}
        "ship_guardian":
            return {"span": 8.9, "length": 15.0,
                "drives": [-2.1, -1.1, 1.1, 2.1], "canopy_z": -2.75}
        _:
            return {"span": 5.6, "length": 12.6,
                "drives": [0.0], "canopy_z": -1.85}

func _rebuild() -> void:
    if is_instance_valid(mounted_root):
        mounted_root.free()
    mounted_root = Node3D.new()
    mounted_root.name = "R62_RealVisibleInspectionMechanisms_" + selected_hull
    add_child(mounted_root)
    control_hinges.clear()
    landing_stays.clear()
    cosmetic_details.clear()
    highlight_lenses.clear()
    var spec: Dictionary = _profile()
    var span: float = float(spec["span"])
    var frame := _mat(Color(0.13, 0.19, 0.23), 0.86, 0.29)
    var hinge_metal := _mat(Color(0.44, 0.51, 0.55), 0.89, 0.23)
    var tire := _mat(Color(0.016, 0.025, 0.037), 0.12, 0.88)
    accent_material = _mat(Color(0.14, 0.72, 0.92), 0.18, 0.26, 1.35)
    # True two-sided control surfaces rotate about their actual hinge nodes.
    for side in [-1.0, 1.0]:
        var pivot := Node3D.new()
        pivot.name = "R62_ActualWingControlHinge_%s" % str(side)
        pivot.position = Vector3(side * span * 0.76, 0.03, 2.15)
        mounted_root.add_child(pivot)
        control_hinges.append(pivot)
        _box(pivot, "R62_PhysicalServoFlap_%s" % str(side),
            Vector3(span * 0.28, 0.11, 0.72),
            Vector3(side * span * 0.13, 0.0, 0.0), frame)
        _box(pivot, "R62_ActualActuatorRail_%s" % str(side),
            Vector3(span * 0.26, 0.045, 0.08),
            Vector3(side * span * 0.13, 0.09, -0.26), hinge_metal, true)
        var stay := Node3D.new()
        stay.name = "R62_ActualLandingStrut_%s" % str(side)
        stay.position = Vector3(side * minf(1.6, span * 0.24), -0.52, 1.30)
        mounted_root.add_child(stay)
        landing_stays.append(stay)
        _box(stay, "R62_TelescopicLandingLeg_%s" % str(side),
            Vector3(0.15, 1.22, 0.16), Vector3(0.0, -0.58, 0.0), hinge_metal)
        _tube(stay, "R62_ActualWheel_%s" % str(side), 0.32, 0.24,
            Vector3(0.0, -1.20, 0.0), tire).rotation = Vector3(0, 0, PI / 2.0)
        var bay_lens := _box(mounted_root,
            "R62_InspectionMarker_%s" % str(side),
            Vector3(0.24, 0.05, 1.0),
            Vector3(side * span * 0.60, 0.27, 0.24),
            accent_material, true)
        highlight_lenses.append(bay_lens)
    # Individual drive counts are bound to R55's real engine layout.
    var index: int = 0
    for drive_x in spec["drives"]:
        var x: float = float(drive_x)
        _tube(mounted_root, "R62_RealExhaustGuide_%d" % index, 0.69,
            0.075, Vector3(x, -0.20, 5.74), hinge_metal)
        var rear_lens := _tube(mounted_root,
            "R62_ExhaustInspectionLamp_%d" % index, 0.39, 0.06,
            Vector3(x, -0.20, 5.88), accent_material)
        highlight_lenses.append(rear_lens)
        index += 1
    # The canopy inspection ring changes with the three true cockpit sizes.
    var canopy_width: float = (1.19 if selected_hull == "ship_guardian"
        else 0.94 if selected_hull == "ship_interceptor" else 0.79)
    for side in [-1.0, 1.0]:
        _box(mounted_root, "R62_CockpitGlassFrame_%s" % str(side),
            Vector3(0.06, 0.09, 2.05),
            Vector3(side * canopy_width * 0.80, 0.83,
                float(spec["canopy_z"])), hinge_metal, true)
    set_inspection_mode(inspection_mode)
    set_low_detail(low_detail)

func set_hull(hull_id: String) -> void:
    selected_hull = hull_id if HULLS.has(hull_id) else "ship_scout"
    if is_inside_tree():
        _rebuild()

func set_livery_accent(color: Color) -> void:
    if is_instance_valid(accent_material):
        accent_material.albedo_color = color
        accent_material.emission = color

func set_low_detail(compact: bool) -> void:
    low_detail = compact
    for part in cosmetic_details:
        if is_instance_valid(part):
            part.visible = not compact
    # Critical moving surfaces remain visible on mobile.

func set_inspection_mode(mode: String) -> bool:
    if not MODES.has(mode):
        return false
    inspection_mode = mode
    for lamp in highlight_lenses:
        if is_instance_valid(lamp):
            lamp.visible = mode in ["cockpit", "engines", "underside"]
    return true

func physical_mesh_count() -> int:
    if not is_instance_valid(mounted_root):
        return 0
    return mounted_root.find_children("*", "MeshInstance3D", true, false).size()

func active_engine_guides() -> int:
    return int((_profile()["drives"] as Array).size())

func _process(delta: float) -> void:
    if not visible:
        return
    clock += minf(maxf(delta, 0.0), 0.05)
    var t: float = clampf(delta * 4.8, 0.0, 1.0)
    var target: float = (-0.31 if inspection_mode in ["engines", "underside"]
        else 0.03)
    for index in control_hinges.size():
        var hinge: Node3D = control_hinges[index]
        var side: float = -1.0 if index == 0 else 1.0
        hinge.rotation.z = lerpf(hinge.rotation.z, side * target, t)
    for stay in landing_stays:
        stay.rotation.x = lerpf(stay.rotation.x,
            0.58 if inspection_mode == "underside" else 0.0, t)
    if is_instance_valid(accent_material):
        accent_material.emission_energy_multiplier = (1.15 +
            0.13 * sin(clock * 2.4))
