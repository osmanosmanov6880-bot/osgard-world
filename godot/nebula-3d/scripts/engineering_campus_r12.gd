extends Node3D
## R12 real-time aerospace fabrication campus: original lofted pressure housings,
## structural fins, modular machined service bays, actuated hangar gates and
## rail-driven loaders. Six district chunks, 12 hero workshop sets. WebGL-safe.

const MaterialFabricR12Script = preload("res://scripts/material_fabric_r12.gd")
const DETAIL_END = [670.0, 435.0, 255.0]

var workshop_count: int = 0
var lofted_pressure_housings: int = 0
var articulated_gates: int = 0
var articulated_cranes: int = 0
var detail_instances: int = 0
var quality_mode: int = 0
var hero_mesh_vertices: int = 0
var painter_nodes: Array[GeometryInstance3D] = []
var distant_shells: Array[GeometryInstance3D] = []
var gates: Array[Node3D] = []
var cranes: Array[Node3D] = []
var active_groups: Array[Node3D] = []
var animation_clock: float = 0.0
var player_ship: Node3D
var titanium: StandardMaterial3D
var ceramic: StandardMaterial3D
var carbon: StandardMaterial3D
var bronze: StandardMaterial3D
var indicator: StandardMaterial3D

func _ready() -> void:
    titanium = MaterialFabricR12Script.get_material(0)
    ceramic = MaterialFabricR12Script.get_material(1)
    carbon = MaterialFabricR12Script.get_material(2)
    bronze = StandardMaterial3D.new()
    bronze.albedo_color = Color(0.49, 0.30, 0.16)
    bronze.metallic = 0.82
    bronze.roughness = 0.39
    indicator = StandardMaterial3D.new()
    indicator.albedo_color = Color(0.43, 0.32, 0.18)
    indicator.metallic = 0.43
    indicator.roughness = 0.50
    indicator.emission_enabled = true
    indicator.emission = Color(0.78, 0.39, 0.12)
    indicator.emission_energy_multiplier = 0.33

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
          ua: Vector2, ub: Vector2, uc: Vector2) -> void:
    st.set_uv(ua)
    st.add_vertex(a)
    st.set_uv(ub)
    st.add_vertex(b)
    st.set_uv(uc)
    st.add_vertex(c)

func _lofted_vessel() -> ArrayMesh:
    # Pressurized industrial housing with physically beveled shoulder profiles.
    # Mesh is shared by all 36 housings, with generated tangent basis for PBR.
    var profile: Array[Vector2] = [
        Vector2(0.4, 3.5), Vector2(1.3, 4.2), Vector2(3.0, 4.5),
        Vector2(3.5, 4.35), Vector2(12.7, 4.35), Vector2(13.4, 4.50),
        Vector2(18.2, 4.50), Vector2(20.0, 4.05),
        Vector2(21.6, 3.0), Vector2(22.5, 1.2), Vector2(22.7, 0.17)
    ]
    var faces: int = 48
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for row in range(profile.size() - 1):
        for side in faces:
            var a: float = TAU * float(side) / float(faces)
            var b: float = TAU * float(side + 1) / float(faces)
            var r0: float = profile[row].y
            var r1: float = profile[row + 1].y
            var y0: float = profile[row].x
            var y1: float = profile[row + 1].x
            var p0 := Vector3(cos(a) * r0, y0, sin(a) * r0)
            var p1 := Vector3(cos(b) * r0, y0, sin(b) * r0)
            var p2 := Vector3(cos(b) * r1, y1, sin(b) * r1)
            var p3 := Vector3(cos(a) * r1, y1, sin(a) * r1)
            var u0: float = float(side) / float(faces) * 5.0
            var u1: float = float(side + 1) / float(faces) * 5.0
            var v0: float = y0 / 22.7 * 4.0
            var v1: float = y1 / 22.7 * 4.0
            _tri(st, p0, p1, p2, Vector2(u0, v0),
                Vector2(u1, v0), Vector2(u1, v1))
            _tri(st, p0, p2, p3, Vector2(u0, v0),
                Vector2(u1, v1), Vector2(u0, v1))
    st.generate_normals()
    st.generate_tangents()
    return st.commit()

func _block(root: Node3D, label: String, location: Vector3,
            size: Vector3, material: Material, track_detail: bool = false) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var obj := MeshInstance3D.new()
    obj.name = label
    obj.mesh = mesh
    obj.position = location
    obj.material_override = material
    root.add_child(obj)
    if track_detail:
        painter_nodes.append(obj)
    return obj

func _rod(root: Node3D, label: String, a: Vector3, b: Vector3,
          diameter: float, material: Material) -> MeshInstance3D:
    var dir: Vector3 = b - a
    var mesh := CylinderMesh.new()
    mesh.top_radius = diameter * 0.5
    mesh.bottom_radius = diameter * 0.5
    mesh.height = dir.length()
    mesh.radial_segments = 18
    var draw := MeshInstance3D.new()
    draw.name = label
    draw.mesh = mesh
    draw.position = (a + b) * 0.5
    draw.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
    draw.material_override = material
    root.add_child(draw)
    painter_nodes.append(draw)
    return draw

func _collider(root: Node3D, label: String,
               location: Vector3, extents: Vector3) -> void:
    var block := StaticBody3D.new()
    block.name = label
    block.position = location
    root.add_child(block)
    var shape := BoxShape3D.new()
    shape.size = extents
    var child := CollisionShape3D.new()
    child.shape = shape
    block.add_child(child)

func _tf(center: Vector3, size: Vector3) -> Transform3D:
    return Transform3D(Basis.IDENTITY.scaled(size), center)

func _batch(label: String, instances: Array[Transform3D], material: Material) -> void:
    if instances.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = BoxMesh.new()
    mm.instance_count = instances.size()
    for k in instances.size():
        mm.set_instance_transform(k, instances[k])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = mm
    node.material_override = material
    node.extra_cull_margin = 20.0
    add_child(node)
    painter_nodes.append(node)
    detail_instances += instances.size()

func _make_port(root: Node3D, label: int, housing_mesh: ArrayMesh) -> void:
    _block(root, "R12_CeramicLoadBearingFoundation", Vector3(0, -0.8, 0),
        Vector3(36, 1.6, 31), ceramic)
    _block(root, "R12_RecessedServiceHall", Vector3(0, 11, -1),
        Vector3(33.4, 22, 29), carbon)
    _block(root, "R12_BevelledCrownBeam", Vector3(0, 23, 0),
        Vector3(37, 2.8, 33), titanium)
    _block(root, "R12_UpperTechnicalDeck", Vector3(0, 28.0, 0),
        Vector3(27, 6.4, 23), ceramic)
    _block(root, "R12_VentilatedRooftopVault", Vector3(0, 33.2, 0),
        Vector3(23, 2.8, 19), titanium)
    for side in [-1.0, 1.0]:
        _block(root, "R12_TitaniumCornerPier", Vector3(side * 15.9, 10.4, 0),
            Vector3(2.2, 21, 33), titanium)
        _block(root, "R12_CarbonWindowRecess", Vector3(side * 13.6, 27.8, 11.65),
            Vector3(8.2, 3.6, 0.4), carbon, true)
        for row in 3:
            _block(root, "R12_MultipaneObservationGlass",
                Vector3(side * (5.8 + 3.4 * float(row)), 28.2, 11.91),
                Vector3(2.65, 2.3, 0.18), ceramic, true)
    _collider(root, "R12_MainHallCollision", Vector3(0, 12, -1),
        Vector3(33.4, 24.0, 29.0))
    # Three independently modeled high-pressure cylindrical assemblies.
    for i in 3:
        var tank := MeshInstance3D.new()
        tank.name = "R12_LoftedPressureHousing_%d" % i
        tank.mesh = housing_mesh
        tank.position = Vector3(-10.2 + float(i) * 10.2, 25.8, -7.8)
        tank.material_override = titanium if i != 1 else ceramic
        root.add_child(tank)
        painter_nodes.append(tank)
        lofted_pressure_housings += 1
        for band in 4:
            var y: float = tank.position.y + 3.4 + float(band) * 4.5
            _rod(root, "R12_ExternalChromeStrut",
                Vector3(tank.position.x + 4.50, y, tank.position.z - 2.2),
                Vector3(tank.position.x + 4.50, y, tank.position.z + 2.2),
                0.33, bronze)
    # Articulated blast doors retract from a central inset facade.
    var left := Node3D.new()
    left.name = "R12_HydraulicGate_Left_%02d" % label
    left.position = Vector3(-4.3, 10.4, 15.2)
    root.add_child(left)
    var right := Node3D.new()
    right.name = "R12_HydraulicGate_Right_%02d" % label
    right.position = Vector3(4.3, 10.4, 15.2)
    root.add_child(right)
    for moving in [left, right]:
        _block(moving, "R12_ArmoredDoorPanel", Vector3.ZERO,
            Vector3(8.2, 17.8, 0.65), ceramic)
        _block(moving, "R12_RecessedGlazeGasket", Vector3(0, 0, 0.42),
            Vector3(7.4, 15.3, 0.12), carbon)
        for k in 8:
            _block(moving, "R12_HorizontalCompositeStiffener",
                Vector3(0, -7.3 + float(k) * 2.0, 0.57),
                Vector3(7.35, 0.18, 0.22), titanium)
        _block(moving, "R12_IndustrialDoorStripe",
            Vector3(0, 0.2, 0.67), Vector3(7.2, 0.28, 0.08), bronze)
        gates.append(moving)
        articulated_gates += 1
    # An elevated cargo crane with a real telescopic piston and hook arm.
    var crane := Node3D.new()
    crane.name = "R12_RailMountedCargoArm_%02d" % label
    crane.position = Vector3(0, 38.8, 0)
    root.add_child(crane)
    _block(crane, "R12_HollowLoadBeam", Vector3(0, 0, 4),
        Vector3(3.4, 3.2, 30), carbon)
    _rod(crane, "R12_TelescopicLiftPiston", Vector3(-1.25, 0, 1.5),
        Vector3(-1.25, -10.5, 14.0), 0.45, titanium)
    _block(crane, "R12_ElectromagneticCargoJaw", Vector3(0, -10.6, 16.8),
        Vector3(7.8, 3.2, 5.6), titanium)
    _block(crane, "R12_OpticalCraneSensor", Vector3(0, -8.4, 17.9),
        Vector3(3.1, 0.3, 0.18), indicator, true)
    cranes.append(crane)
    articulated_cranes += 1
    var label3d := Label3D.new()
    label3d.name = "R12_EmbossedEngineeringSign"
    label3d.text = "AEGIS  /  ENGINEERING BAY  %02d" % label
    label3d.font_size = 70
    label3d.pixel_size = 0.011
    label3d.modulate = Color(0.80, 0.72, 0.52)
    label3d.position = Vector3(0, 22.2, 17.3)
    root.add_child(label3d)

func build(centres: Array) -> void:
    var housing_mesh: ArrayMesh = _lofted_vessel()
    hero_mesh_vertices = housing_mesh.surface_get_array_len(0)
    for sector in centres.size():
        var center: Vector3 = centres[sector]
        var bolts: Array[Transform3D] = []
        var roof_fins: Array[Transform3D] = []
        var window_trims: Array[Transform3D] = []
        var danger_stripes: Array[Transform3D] = []
        for side in [-1.0, 1.0]:
            var site := Node3D.new()
            var bay: int = sector * 2 + (0 if side < 0.0 else 1)
            site.name = "R12_MachinedEngineeringHall_%02d" % bay
            site.position = center + Vector3(side * 58.0, 0, -44.0)
            add_child(site)
            _make_port(site, bay, housing_mesh)
            active_groups.append(site)
            workshop_count += 1
            _block(site, "R12_FarProxyArchitecturalSilhouette",
                Vector3(0, 20, 0), Vector3(34, 40, 30), carbon)
            var distant := site.get_node("R12_FarProxyArchitecturalSilhouette") as MeshInstance3D
            distant_shells.append(distant)
            for row in 34:
                var height: float = 1.0 + float(row) * 0.88
                for column in 12:
                    var x: float = -15.6 + float(column) * 2.84
                    var p: Vector3 = site.position + Vector3(x, height, 15.9)
                    bolts.append(_tf(p, Vector3(0.21, 0.21, 0.21)))
                    if row % 5 == 0:
                        window_trims.append(_tf(p + Vector3(0, 0, 0.42),
                            Vector3(1.2, 0.25, 0.45)))
                if row % 3 == 0:
                    danger_stripes.append(_tf(site.position +
                        Vector3(0, height, 16.3), Vector3(31, 0.18, 0.26)))
            for k in 24:
                var x: float = -13.8 + float(k) * 1.20
                roof_fins.append(_tf(site.position +
                    Vector3(x, 35.2, -2.3), Vector3(0.34, 2.8, 13.1)))
        _batch("R12_D%02d_BatchedPanelFasteners" % sector, bolts, bronze)
        _batch("R12_D%02d_RooftopHeatExchangerFins" % sector, roof_fins, titanium)
        _batch("R12_D%02d_LayeredWindowCassetteTrim" % sector, window_trims, carbon)
        _batch("R12_D%02d_DockSafetyStripeAssembly" % sector, danger_stripes, indicator)
    set_quality(0)

func set_quality(mode: int) -> void:
    quality_mode = clampi(mode, 0, 2)
    var range_end: float = DETAIL_END[quality_mode]
    for node in painter_nodes:
        if is_instance_valid(node):
            node.visibility_range_end = range_end
            node.visibility_range_end_margin = 60.0
    for proxy in distant_shells:
        if is_instance_valid(proxy):
            proxy.visibility_range_begin = range_end - 80.0
            proxy.visibility_range_begin_margin = 80.0

func _process(delta: float) -> void:
    animation_clock += delta
    if not is_instance_valid(player_ship):
        player_ship = get_parent().get_node_or_null("PlayerShip")
    # Only these 12 pivot transforms change; thousands of facade details remain
    # static GPU instances, not independent per-frame GDScript objects.
    for index in active_groups.size():
        var hall: Node3D = active_groups[index]
        var nearby: bool = is_instance_valid(player_ship) and
            player_ship.global_position.distance_squared_to(hall.global_position) < 17500.0
        var left: Node3D = gates[index * 2]
        var right: Node3D = gates[index * 2 + 1]
        var destination: float = 9.1 if nearby else 0.0
        left.position.x = move_toward(left.position.x, -4.3 - destination, delta * 6.0)
        right.position.x = move_toward(right.position.x, 4.3 + destination, delta * 6.0)
        var crane: Node3D = cranes[index]
        if nearby:
            crane.rotation.y = sin(animation_clock * 0.24 + float(index)) * 0.22
            crane.rotation.x = 0.08 * sin(animation_clock * 0.14 + float(index) * 0.7)
