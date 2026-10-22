extends Node3D
## R5 authored procedural interceptor model. GL Compatibility friendly, no external assets.
## Mesh geometry is real: beveled planform, inset armor, turbine housings and service details.
## Gameplay physics remain in ship.gd; this node provides visual geometry only.

var engine_flames: Array[MeshInstance3D] = []
var detail_count: int = 0
var mats: Dictionary = {}

func _ready() -> void:
    mats = {
        "carbon": _pbr(Color(0.028, 0.040, 0.064), 0.46, 0.70),
        "titanium": _pbr(Color(0.31, 0.38, 0.45), 0.31, 0.82),
        "ceramic": _pbr(Color(0.67, 0.71, 0.72), 0.42, 0.34),
        "armor": _pbr(Color(0.085, 0.14, 0.205), 0.34, 0.80),
        "glass": _pbr(Color(0.025, 0.16, 0.24), 0.075, 0.76),
        "gold": _pbr(Color(0.61, 0.39, 0.16), 0.23, 0.86),
        "seams": _pbr(Color(0.014, 0.024, 0.034), 0.58, 0.31),
        "light": _pbr(Color(0.14, 0.68, 0.85), 0.42, 0.16, 1.15),
        "amber": _pbr(Color(0.96, 0.45, 0.14), 0.41, 0.18, 0.72)
    }
    _build_airframe()
    _build_wings()
    _build_canopy()
    _build_propulsion()
    _build_surface_details()

func _pbr(tint: Color, roughness: float, metallic: float, glow: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = metallic
    mat.roughness = roughness
    if glow > 0.0:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = glow
    return mat

func _box(name: String, size: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
    var box := BoxMesh.new()
    box.size = size
    var part := MeshInstance3D.new()
    part.name = name
    part.mesh = box
    part.material_override = material
    part.position = offset
    add_child(part)
    detail_count += 1
    return part

func _cylinder(name: String, top: float, bottom: float, length: float, where: Vector3, material: Material, segments: int = 20) -> MeshInstance3D:
    var shape := CylinderMesh.new()
    shape.top_radius = top
    shape.bottom_radius = bottom
    shape.height = length
    shape.radial_segments = segments
    shape.rings = 1
    var part := MeshInstance3D.new()
    part.name = name
    part.mesh = shape
    part.rotation.x = PI * 0.5
    part.position = where
    part.material_override = material
    add_child(part)
    detail_count += 1
    return part

func _torus(name: String, radius: float, ring_width: float, where: Vector3, material: Material) -> MeshInstance3D:
    var shape := TorusMesh.new()
    shape.inner_radius = radius - ring_width
    shape.outer_radius = radius
    shape.rings = 32
    shape.ring_segments = 8
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = shape
    node.rotation.x = PI * 0.5
    node.position = where
    node.material_override = material
    add_child(node)
    detail_count += 1
    return node

func _poly(name: String, contour: Array[Vector2], bottom: float, top: float, material: Material) -> MeshInstance3D:
    # Extrude a convex x/z silhouette to give wings and plates real thickness.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(1, contour.size() - 1):
        _tri(st, Vector3(contour[0].x, top, contour[0].y), Vector3(contour[i].x, top, contour[i].y), Vector3(contour[i + 1].x, top, contour[i + 1].y))
        _tri(st, Vector3(contour[i + 1].x, bottom, contour[i + 1].y), Vector3(contour[i].x, bottom, contour[i].y), Vector3(contour[0].x, bottom, contour[0].y))
    for i in contour.size():
        var k: int = (i + 1) % contour.size()
        var a := Vector3(contour[i].x, bottom, contour[i].y)
        var b := Vector3(contour[k].x, bottom, contour[k].y)
        var c := Vector3(contour[k].x, top, contour[k].y)
        var d := Vector3(contour[i].x, top, contour[i].y)
        _tri(st, a, b, c)
        _tri(st, a, c, d)
    st.generate_normals()
    var surface := MeshInstance3D.new()
    surface.name = name
    surface.mesh = st.commit()
    surface.material_override = material
    add_child(surface)
    detail_count += 1
    return surface

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    for v in [a, b, c]:
        st.set_uv(Vector2(v.x * 0.17 + 0.5, v.z * 0.17 + 0.5))
        st.add_vertex(v)

func _build_airframe() -> void:
    # Continuous fighter silhouette: narrow armored nose, waist, flared aft body.
    _poly("CentralChineArmor", [
        Vector2(0, -6.4), Vector2(0.62, -5.2), Vector2(1.32, -2.35),
        Vector2(1.28, 1.95), Vector2(0.95, 3.52), Vector2(-0.95, 3.52),
        Vector2(-1.28, 1.95), Vector2(-1.32, -2.35), Vector2(-0.62, -5.2)
    ], -0.49, 0.26, mats["titanium"])
    _poly("VentralBelly", [
        Vector2(0, -5.9), Vector2(0.84, -2.4), Vector2(1.04, 2.3),
        Vector2(-1.04, 2.3), Vector2(-0.84, -2.4)
    ], -0.72, -0.43, mats["carbon"])
    _poly("UpperSpine", [
        Vector2(0, -4.7), Vector2(0.43, -3.1), Vector2(0.63, 1.8),
        Vector2(0.38, 3.2), Vector2(-0.38, 3.2), Vector2(-0.63, 1.8),
        Vector2(-0.43, -3.1)
    ], 0.27, 0.53, mats["armor"])
    _poly("NoseCeramicInlay", [
        Vector2(0, -6.46), Vector2(0.17, -5.35), Vector2(0.10, -4.65),
        Vector2(-0.10, -4.65), Vector2(-0.17, -5.35)
    ], 0.28, 0.32, mats["ceramic"])
    _box("SpineTensionBeam", Vector3(0.12, 0.085, 3.7), Vector3(0, 0.57, 0.40), mats["gold"])
    for side in [-1.0, 1.0]:
        _box("ForwardSideArmor", Vector3(0.17, 0.25, 3.1), Vector3(side * 1.15, 0.08, -1.0), mats["carbon"])
        _box("NoseSensor", Vector3(0.14, 0.095, 0.44), Vector3(side * 0.32, 0.29, -4.65), mats["light"])
        _box("CheekIntake", Vector3(0.22, 0.31, 1.5), Vector3(side * 1.23, 0.21, 1.08), mats["seams"])

func _build_wings() -> void:
    for side in [-1.0, 1.0]:
        # Outboard planform is NOT a rectangular slab.
        _poly("SweptArmorWing", [
            Vector2(side * 0.98, -2.32), Vector2(side * 2.45, -1.25),
            Vector2(side * 6.48, 0.18), Vector2(side * 6.12, 2.15),
            Vector2(side * 2.26, 2.80), Vector2(side * 0.94, 2.05)
        ], -0.39, 0.02, mats["armor"])
        _poly("InsetWingTile", [
            Vector2(side * 2.02, -0.93), Vector2(side * 3.35, -0.55),
            Vector2(side * 5.77, 0.37), Vector2(side * 5.55, 1.55),
            Vector2(side * 2.28, 1.76)
        ], 0.025, 0.115, mats["titanium"])
        _poly("CeramicLeadingEdge", [
            Vector2(side * 1.50, -1.97), Vector2(side * 3.3, -0.73),
            Vector2(side * 5.85, 0.19), Vector2(side * 5.57, 0.27),
            Vector2(side * 3.17, -0.50), Vector2(side * 1.39, -1.67)
        ], 0.04, 0.105, mats["ceramic"])
        _poly("TrailingCarbonFlap", [
            Vector2(side * 2.58, 2.15), Vector2(side * 5.86, 1.86),
            Vector2(side * 5.77, 2.24), Vector2(side * 2.57, 2.56)
        ], -0.24, 0.015, mats["carbon"])
        _poly("VerticalWinglet", [
            Vector2(side * 5.82, 1.52), Vector2(side * 6.35, 0.55),
            Vector2(side * 6.45, 1.83), Vector2(side * 6.12, 2.35)
        ], 0.09, 0.62, mats["titanium"])
        for j in 5:
            var a: float = float(j)
            _box("FlushWingInspectionTile", Vector3(0.57, 0.03, 0.24),
                 Vector3(side * (2.2 + a * 0.63), 0.13, 0.73 + a * 0.04), mats["carbon"])
        for j in 4:
            var a: float = float(j)
            _box("LeadingEdgeSeam", Vector3(0.045, 0.043, 0.29),
                 Vector3(side * (2.38 + a * 0.76), 0.14, -0.41 + a * 0.21), mats["seams"])
        _box("NavigationLamp", Vector3(0.25, 0.14, 0.36), Vector3(side * 6.26, 0.21, 0.34), mats["light"] if side > 0.0 else mats["amber"])
        _box("UnderwingPylon", Vector3(0.21, 0.29, 1.25), Vector3(side * 4.03, -0.57, 1.48), mats["carbon"])
        _cylinder("UnderwingServicePod", 0.19, 0.28, 2.30, Vector3(side * 4.03, -0.68, 1.45), mats["titanium"], 14)
        _box("AileronActuator", Vector3(0.30, 0.14, 0.52), Vector3(side * 3.4, -0.46, 2.0), mats["gold"])

func _build_canopy() -> void:
    var rim := SphereMesh.new()
    rim.radius = 1.0
    rim.height = 2.0
    rim.radial_segments = 32
    rim.rings = 16
    var frame := MeshInstance3D.new()
    frame.name = "MultiPaneCockpitRim"
    frame.mesh = rim
    frame.position = Vector3(0, 0.52, -1.72)
    frame.scale = Vector3(0.98, 0.56, 1.70)
    frame.material_override = mats["carbon"]
    add_child(frame)
    var glazing := MeshInstance3D.new()
    glazing.name = "CeramicCoatedCanopy"
    glazing.mesh = rim
    glazing.position = Vector3(0, 0.61, -1.73)
    glazing.scale = Vector3(0.86, 0.52, 1.54)
    glazing.material_override = mats["glass"]
    add_child(glazing)
    _box("CanopyCentralStrut", Vector3(0.065, 0.07, 3.0), Vector3(0, 1.12, -1.70), mats["titanium"])
    for side in [-1.0, 1.0]:
        _box("CockpitSideRail", Vector3(0.13, 0.07, 2.6), Vector3(side * 0.73, 0.50, -1.70), mats["gold"])
        _box("CockpitRetentionLatch", Vector3(0.14, 0.10, 0.22), Vector3(side * 0.81, 0.38, -0.83), mats["titanium"])

func _build_propulsion() -> void:
    # Recessed triple-nozzle array with visible turbine rings and small flame cores.
    for x in [-1.24, 0.0, 1.24]:
        var outer: float = 0.58 if absf(x) > 0.1 else 0.46
        _cylinder("EngineNacelle", outer * 0.94, outer, 2.6, Vector3(x, -0.22, 3.03), mats["carbon"], 28)
        _cylinder("CeramicHeatLiner", outer * 0.79, outer * 0.79, 0.18, Vector3(x, -0.22, 4.39), mats["ceramic"], 28)
        _cylinder("ExhaustDarkCore", outer * 0.61, outer * 0.61, 0.25, Vector3(x, -0.22, 4.50), mats["seams"], 28)
        _torus("MachinedTurbineLip", outer * 0.81, 0.09, Vector3(x, -0.22, 4.48), mats["gold"])
        for j in 8:
            var a: float = TAU * float(j) / 8.0
            var p := Vector3(x + cos(a) * outer * 0.68, -0.22 + sin(a) * outer * 0.68, 4.48)
            var strut := _box("ExhaustStator", Vector3(0.045, 0.23, 0.06), p, mats["titanium"])
            strut.rotation.z = a
        var flame := _cylinder("AnimatedIonCore", outer * 0.11, outer * 0.37, 1.25, Vector3(x, -0.22, 5.08), mats["light"], 20)
        engine_flames.append(flame)
        for side in [-1.0, 1.0]:
            _box("ThrusterMount", Vector3(0.12, 0.16, 1.83),
                 Vector3(x + side * outer * 0.9, -0.19, 2.80), mats["titanium"])
    var engine_light := OmniLight3D.new()
    engine_light.name = "ThreeEngineFill"
    engine_light.position = Vector3(0, -0.22, 4.8)
    engine_light.light_color = Color(0.25, 0.61, 0.95)
    engine_light.light_energy = 0.8
    engine_light.omni_range = 10.0
    engine_light.shadow_enabled = false
    add_child(engine_light)

func _build_surface_details() -> void:
    for side in [-1.0, 1.0]:
        # Two armored aft shoulders, segmented heat shields, raised sensor masts.
        _box("MainFuselageShoulder", Vector3(0.46, 0.39, 2.5), Vector3(side * 1.04, 0.24, 2.48), mats["carbon"])
        for j in 8:
            var z: float = -2.4 + float(j) * 0.52
            _box("CeramicMaintenanceHatch", Vector3(0.14, 0.018, 0.22),
                 Vector3(side * 1.01, 0.296, z), mats["ceramic"])
        for j in 6:
            _box("RadiatorLouver", Vector3(0.25, 0.09, 0.065),
                 Vector3(side * 0.70, 0.60, 1.42 + float(j) * 0.18), mats["seams"])
        _box("SensorFin", Vector3(0.12, 0.58, 0.74), Vector3(side * 1.03, 0.78, 2.83), mats["titanium"])
        _box("LandingSkidHousing", Vector3(0.17, 0.12, 2.4), Vector3(side * 1.22, -0.79, 1.2), mats["carbon"])
        _box("RearNavIndicator", Vector3(0.16, 0.10, 0.20), Vector3(side * 1.45, 0.31, 3.37), mats["amber"])
    for j in 6:
        _box("VentralHeatShield", Vector3(0.45, 0.037, 0.32),
             Vector3(0, -0.74, -2.14 + float(j) * 0.65), mats["ceramic"])
