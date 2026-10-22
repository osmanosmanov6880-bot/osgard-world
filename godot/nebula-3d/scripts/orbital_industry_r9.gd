extends Node3D
## NEBULA R9: physical fuel handling and orbital maintenance infrastructure.
## Curved 48-sided storage vessels + repeated details are real meshes.
## Repeated geometry is batched for the Web Compatibility renderer.

const SurfaceLibraryR9Script = preload("res://scripts/surface_library_r9.gd")

var silo_count: int = 0
var docking_clamps: int = 0
var panel_instances: int = 0
var work_lights: Array[OmniLight3D] = []
var animated_gantry: Array[Node3D] = []
var elapsed: float = 0.0

var vessel_material: StandardMaterial3D
var graphite: StandardMaterial3D
var steel: StandardMaterial3D
var copper: StandardMaterial3D
var lights: StandardMaterial3D

func _ready() -> void:
    vessel_material = SurfaceLibraryR9Script.coat(_mat(Color(0.76, 0.82, 0.86), 0.81, 0.45), 1)
    graphite = _mat(Color(0.030, 0.043, 0.058), 0.42, 0.60)
    steel = _mat(Color(0.42, 0.46, 0.48), 0.84, 0.37)
    copper = _mat(Color(0.54, 0.32, 0.15), 0.85, 0.44)
    lights = _mat(Color(0.68, 0.39, 0.14), 0.15, 0.50)
    lights.emission_enabled = true
    lights.emission = Color(0.80, 0.34, 0.12)
    lights.emission_energy_multiplier = 0.33

func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func _tri(st: SurfaceTool, a: Vector3, uva: Vector2, b: Vector3, uvb: Vector2, c: Vector3, uvc: Vector2) -> void:
    st.set_uv(uva)
    st.add_vertex(a)
    st.set_uv(uvb)
    st.add_vertex(b)
    st.set_uv(uvc)
    st.add_vertex(c)

func _lathe_vessel() -> ArrayMesh:
    # Actual revolution geometry with shoulder creases and tapered pressure cap.
    var sections: Array[Vector2] = [
        Vector2(0.0, 6.8), Vector2(1.5, 7.65), Vector2(3.2, 8.10),
        Vector2(6.0, 8.10), Vector2(19.0, 8.10), Vector2(21.5, 7.90),
        Vector2(24.5, 6.70), Vector2(26.6, 4.90), Vector2(28.0, 2.25),
        Vector2(28.5, 0.15)
    ]
    var sides: int = 48
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for k in range(sections.size() - 1):
        var y0: float = sections[k].x
        var y1: float = sections[k + 1].x
        var r0: float = sections[k].y
        var r1: float = sections[k + 1].y
        for i in sides:
            var a: float = TAU * float(i) / float(sides)
            var b: float = TAU * float(i + 1) / float(sides)
            var p00 := Vector3(r0 * cos(a), y0, r0 * sin(a))
            var p01 := Vector3(r0 * cos(b), y0, r0 * sin(b))
            var p10 := Vector3(r1 * cos(a), y1, r1 * sin(a))
            var p11 := Vector3(r1 * cos(b), y1, r1 * sin(b))
            var u0: float = float(i) / float(sides) * 4.0
            var u1: float = float(i + 1) / float(sides) * 4.0
            var v0: float = y0 / 28.5 * 5.0
            var v1: float = y1 / 28.5 * 5.0
            _tri(st, p00, Vector2(u0, v0), p11, Vector2(u1, v1), p01, Vector2(u1, v0))
            _tri(st, p00, Vector2(u0, v0), p10, Vector2(u0, v1), p11, Vector2(u1, v1))
    st.generate_normals()
    st.generate_tangents()
    return st.commit()

func _batch(name: String, mesh: Mesh, transforms: Array[Transform3D], mat: Material) -> void:
    if transforms.is_empty():
        return
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = transforms.size()
    for i in transforms.size():
        multi.set_instance_transform(i, transforms[i])
    var draw := MultiMeshInstance3D.new()
    draw.name = name
    draw.multimesh = multi
    draw.material_override = mat
    draw.extra_cull_margin = 40.0
    add_child(draw)
    panel_instances += transforms.size()

func _box_mesh(name: String, positions: Array[Transform3D], mat: Material) -> void:
    _batch(name, BoxMesh.new(), positions, mat)

func _beam(a: Vector3, b: Vector3, width: float) -> Transform3D:
    var vector: Vector3 = b - a
    return Transform3D(Basis(Quaternion(Vector3.UP, vector.normalized())).scaled(
        Vector3(width, vector.length(), width)), (a + b) * 0.5)

func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var block := MeshInstance3D.new()
    block.name = name
    var geometry := BoxMesh.new()
    geometry.size = size
    block.mesh = geometry
    block.position = pos
    block.material_override = mat
    parent.add_child(block)
    return block

func _make_collider(index: int, location: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = "R9_PressureVesselCollision_%02d" % index
    body.position = location + Vector3(0, 14, 0)
    add_child(body)
    var shape := CollisionShape3D.new()
    var cylinder := CylinderShape3D.new()
    cylinder.height = 28.0
    cylinder.radius = 7.6
    shape.shape = cylinder
    body.add_child(shape)

func _make_mobile_loader(pos: Vector3, index: int) -> void:
    var loader := Node3D.new()
    loader.name = "R9_IndustrialLoader_%02d" % index
    loader.position = pos
    add_child(loader)
    _box(loader, "LoadBearingChassis", Vector3(0, 1.4, 0), Vector3(8.5, 2.7, 5.1), graphite)
    _box(loader, "ServiceCabin", Vector3(-1.5, 3.65, -0.9), Vector3(3.4, 2.2, 3.1), steel)
    _box(loader, "PolarizedWindshield", Vector3(-1.5, 3.85, -2.48), Vector3(2.8, 1.1, 0.21), graphite)
    _box(loader, "BatteryBank", Vector3(2.1, 3.0, 0.0), Vector3(3.2, 1.8, 3.7), steel)
    for side in [-1.0, 1.0]:
        for axle in [-2.3, 2.3]:
            _box(loader, "HeavyAxleGuard", Vector3(axle, 0.7, side * 2.65), Vector3(1.9, 1.8, 0.6), graphite)
        _box(loader, "DockingGrabber", Vector3(5.1, 2.0, side * 1.58), Vector3(2.7, 0.5, 0.9), copper)
    var boom := Node3D.new()
    boom.name = "HydraulicLoadingBoom"
    boom.position = Vector3(1.4, 3.3, 0)
    loader.add_child(boom)
    _box(boom, "SteelSegmentOne", Vector3(2.3, 1.0, 0), Vector3(6.4, 0.85, 1.0), steel)
    _box(boom, "SteelSegmentTwo", Vector3(5.8, 1.0, 0), Vector3(1.0, 0.95, 5.3), graphite)
    _box(boom, "HardenedClampHead", Vector3(6.5, 0.8, 0), Vector3(1.8, 2.3, 5.7), copper)
    animated_gantry.append(boom)
    docking_clamps += 1

func build(centers: Array) -> void:
    var tank_locations: Array[Transform3D] = []
    var pipes: Array[Transform3D] = []
    var collars: Array[Transform3D] = []
    var handrails: Array[Transform3D] = []
    var warning_bands: Array[Transform3D] = []
    var service_ladders: Array[Transform3D] = []
    var valve_housings: Array[Transform3D] = []
    var industrial_light_strips: Array[Transform3D] = []
    var pressure_mesh: ArrayMesh = _lathe_vessel()
    var ring := TorusMesh.new()
    ring.inner_radius = 7.78
    ring.outer_radius = 8.11
    ring.rings = 48
    ring.ring_segments = 8
    var collar_transforms: Array[Transform3D] = []
    var idx: int = 0
    for hub in centers.size():
        var center: Vector3 = centers[hub]
        for side in [-1.0, 1.0]:
            for lane in 2:
                var p: Vector3 = center + Vector3(side * (75.0 + 30.0 * float(lane)), 0.0,
                                                 -22.0 + 65.0 * float(lane))
                tank_locations.append(Transform3D(Basis.IDENTITY, p))
                _make_collider(idx, p)
                for band in 6:
                    var y: float = 3.5 + float(band) * 3.8
                    collar_transforms.append(Transform3D(Basis.IDENTITY, p + Vector3(0, y, 0)))
                for level in 16:
                    var y: float = 3.0 + float(level) * 1.19
                    service_ladders.append(_beam(p + Vector3(side * -8.1, y, -1.05),
                                                  p + Vector3(side * -8.1, y, 1.05), 0.16))
                    if level % 3 == 0:
                        valve_housings.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.61, 0.62, 0.55)),
                            p + Vector3(-side * 8.35, y, 0.0)))
                for ring_section in 24:
                    var angle: float = TAU * float(ring_section) / 24.0
                    var a: Vector3 = p + Vector3(cos(angle) * 9.2, 2.4, sin(angle) * 9.2)
                    var b: Vector3 = p + Vector3(cos(angle) * 9.2, 3.4, sin(angle) * 9.2)
                    warning_bands.append(_beam(a, b, 0.20))
                    if ring_section % 2 == 0:
                        industrial_light_strips.append(Transform3D(
                            Basis.IDENTITY.scaled(Vector3(0.18, 0.14, 0.34)),
                            p + Vector3(cos(angle) * 8.3, 23.5, sin(angle) * 8.3)))
                # Pipes route toward the perimeter, never across the central flight lane.
                for pipe_num in 3:
                    var y: float = 5.5 + float(pipe_num) * 2.8
                    var start: Vector3 = p + Vector3(-side * 8.5, y, 0)
                    var end: Vector3 = p + Vector3(-side * 17.0, y, -17.0)
                    pipes.append(_beam(start, end, 0.24))
                    pipes.append(_beam(end, end + Vector3(0, -y + 1.8, -3.5), 0.22))
                for terrace in 2:
                    var y: float = 10.0 + float(terrace) * 12.0
                    handrails.append(_beam(p + Vector3(-10, y, -10),
                                            p + Vector3(10, y, -10), 0.20))
                    handrails.append(_beam(p + Vector3(10, y, -10),
                                            p + Vector3(10, y, 10), 0.20))
                idx += 1
        for loader_index in 2:
            var x: float = -57.0 if loader_index == 0 else 57.0
            var location: Vector3 = center + Vector3(x, 0, 44.0)
            _make_mobile_loader(location, hub * 2 + loader_index)
        for lamp_index in 2:
            var pos: Vector3 = center + Vector3(-44.0 if lamp_index == 0 else 44.0, 10.5, 23)
            var worklight := OmniLight3D.new()
            worklight.name = "R9_ShadowFreeWorklight_%02d_%d" % [hub, lamp_index]
            worklight.position = pos
            worklight.light_color = Color(0.95, 0.69, 0.41)
            worklight.light_energy = 0.30
            worklight.omni_range = 28.0
            worklight.shadow_enabled = false
            add_child(worklight)
            work_lights.append(worklight)
        var port_sign := Label3D.new()
        port_sign.name = "R9_IndustrialPortSign_%02d" % hub
        port_sign.text = "OSGARD  /  INDUSTRIAL DOCK  %02d" % (hub + 1)
        port_sign.font_size = 88
        port_sign.pixel_size = 0.012
        port_sign.modulate = Color(0.70, 0.72, 0.67)
        port_sign.position = center + Vector3(0, 13, -87)
        add_child(port_sign)
    _batch("R9_PBRPressureSilos_24", pressure_mesh, tank_locations, vessel_material)
    _batch("R9_MachinedTankCollars", ring, collar_transforms, steel)
    _box_mesh("R9_HighPressurePiping", pipes, copper)
    _box_mesh("R9_RaisedServiceHandrails", handrails, steel)
    _box_mesh("R9_LadderRungArray", service_ladders, steel)
    _box_mesh("R9_HardenedValveHousings", valve_housings, graphite)
    _box_mesh("R9_IndustrialSafetyBands", warning_bands, copper)
    _box_mesh("R9_AmberTankIndicators", industrial_light_strips, lights)
    silo_count = idx

func _process(delta: float) -> void:
    elapsed += delta
    for j in animated_gantry.size():
        var boom: Node3D = animated_gantry[j]
        if is_instance_valid(boom):
            boom.rotation.y = sin(elapsed * 0.21 + float(j) * 0.9) * 0.17
    for light in work_lights:
        if is_instance_valid(light):
            light.light_energy = 0.29 + 0.03 * sin(elapsed * 1.1)
