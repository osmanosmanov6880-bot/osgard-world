extends Node3D
## R11 close-range port art: 12 machined landing decks and autonomous gantries.
## Shared 48-sided lofted mesh, physically grounded PBR, batched fasteners,
## mechanical motion and optional distance culling for browser GPUs.

const MaterialStudioR11Script = preload("res://scripts/material_studio_r11.gd")
const LOD_RANGES = [830.0, 570.0, 330.0]

var docking_decks: int = 0
var service_gantries: int = 0
var moving_carts: int = 0
var instanced_hardware: int = 0
var lod_mode: int = 0
var elapsed: float = 0.0
var cranes: Array[Node3D] = []
var carts: Array[Node3D] = []
var lod_nodes: Array[GeometryInstance3D] = []
var deck_material: StandardMaterial3D
var steel: StandardMaterial3D
var graphite: StandardMaterial3D
var glass: StandardMaterial3D
var copper: StandardMaterial3D
var light: StandardMaterial3D

func _ready() -> void:
    deck_material = MaterialStudioR11Script.make_weathered_deck()
    steel = _metal(Color(0.31, 0.40, 0.45), 0.78, 0.35)
    graphite = _metal(Color(0.038, 0.049, 0.063), 0.53, 0.54)
    glass = _metal(Color(0.075, 0.18, 0.22), 0.19, 0.15)
    copper = _metal(Color(0.53, 0.35, 0.19), 0.80, 0.38)
    light = _metal(Color(0.67, 0.48, 0.27), 0.25, 0.45)
    light.emission_enabled = true
    light.emission = Color(0.66, 0.37, 0.12)
    light.emission_energy_multiplier = 0.36

func _metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    return material

func _tri(st: SurfaceTool, a: Vector3, uv_a: Vector2,
        b: Vector3, uv_b: Vector2, c: Vector3, uv_c: Vector2) -> void:
    st.set_uv(uv_a)
    st.add_vertex(a)
    st.set_uv(uv_b)
    st.add_vertex(b)
    st.set_uv(uv_c)
    st.add_vertex(c)

func _sculpted_landing_deck() -> ArrayMesh:
    # 48 radial segments x concentric rings with a beveled, load-bearing edge.
    var radial: int = 48
    var sections: Array[Vector2] = [
        Vector2(0.0, 2.40), Vector2(5.0, 2.42), Vector2(19.0, 2.36),
        Vector2(24.3, 2.28), Vector2(25.6, 1.92),
        Vector2(25.6, 1.0), Vector2(22.8, 0.65)
    ]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for segment in range(sections.size() - 1):
        for j in radial:
            var a: float = TAU * float(j) / float(radial)
            var b: float = TAU * float(j + 1) / float(radial)
            var r0: float = sections[segment].x
            var r1: float = sections[segment + 1].x
            var y0: float = sections[segment].y
            var y1: float = sections[segment + 1].y
            var p0 := Vector3(cos(a) * r0, y0, sin(a) * r0)
            var p1 := Vector3(cos(b) * r0, y0, sin(b) * r0)
            var p2 := Vector3(cos(b) * r1, y1, sin(b) * r1)
            var p3 := Vector3(cos(a) * r1, y1, sin(a) * r1)
            var u0: float = float(j) / float(radial) * 6.0
            var u1: float = float(j + 1) / float(radial) * 6.0
            var v0: float = r0 / 25.6 * 6.0
            var v1: float = r1 / 25.6 * 6.0
            _tri(st, p0, Vector2(u0, v0), p1, Vector2(u1, v0), p2, Vector2(u1, v1))
            _tri(st, p0, Vector2(u0, v0), p2, Vector2(u1, v1), p3, Vector2(u0, v1))
    st.generate_normals()
    st.generate_tangents()
    return st.commit()

func _box(parent: Node3D, name: String, where: Vector3,
        size: Vector3, material: Material) -> MeshInstance3D:
    var cube := BoxMesh.new()
    cube.size = size
    var render := MeshInstance3D.new()
    render.name = name
    render.mesh = cube
    render.position = where
    render.material_override = material
    parent.add_child(render)
    return render

func _beam(parent: Node3D, name: String, start: Vector3,
        finish: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var vector: Vector3 = finish - start
    var mesh := CylinderMesh.new()
    mesh.height = vector.length()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.radial_segments = 16
    var render := MeshInstance3D.new()
    render.name = name
    render.mesh = mesh
    render.position = (start + finish) * 0.5
    render.basis = Basis(Quaternion(Vector3.UP, vector.normalized()))
    render.material_override = material
    parent.add_child(render)
    return render

func _batch(label: String, instances: Array[Transform3D], material: Material) -> void:
    if instances.is_empty():
        return
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = BoxMesh.new()
    multi.instance_count = instances.size()
    for i in instances.size():
        multi.set_instance_transform(i, instances[i])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = multi
    node.material_override = material
    node.extra_cull_margin = 20.0
    add_child(node)
    instanced_hardware += instances.size()
    lod_nodes.append(node)

func _beam_tf(start: Vector3, finish: Vector3, thickness: float) -> Transform3D:
    var delta: Vector3 = finish - start
    return Transform3D(
        Basis(Quaternion(Vector3.UP, delta.normalized())).scaled(
            Vector3(thickness, delta.length(), thickness)),
        (start + finish) * 0.5
    )

func _make_gantry(root: Node3D, bay: int, side: float) -> void:
    var crane := Node3D.new()
    crane.name = "R11_ArticulatedServiceCrane_%02d" % bay
    crane.position = Vector3(side * 36.0, 4.0, -6.0)
    root.add_child(crane)
    for lateral in [-1.0, 1.0]:
        _box(crane, "ReinforcedCraneColumn",
             Vector3(lateral * 3.2, 18, 0), Vector3(1.4, 36, 1.6), steel)
        _box(crane, "CopperLoadingRail",
             Vector3(lateral * 3.2, 18, 0.93), Vector3(0.44, 32, 0.40), copper)
    _box(crane, "ServiceMachineHousing",
         Vector3(0, 38, 0), Vector3(12, 5, 9), graphite)
    var moving := Node3D.new()
    moving.name = "R11_RotatingCargoGantry"
    moving.position = Vector3(0, 39.0, 0)
    crane.add_child(moving)
    _box(moving, "ArmoredBoom", Vector3(-side * 14, 0, -2),
         Vector3(32, 2.1, 3.8), steel)
    _box(moving, "Counterweight", Vector3(side * 8, -1.4, 1),
         Vector3(11, 5.8, 7.4), graphite)
    for beam in range(6):
        var x: float = -side * (2.0 + float(beam) * 5.1)
        _beam(moving, "DiagonalBoomCrossBrace",
             Vector3(x, -0.5, -3.6),
             Vector3(x - side * 3.7, 3.8, 0.6), 0.23, copper)
    for cable in [-2.5, 2.5]:
        _beam(moving, "HardenedCargoCable",
             Vector3(-side * 26, -1, cable),
             Vector3(-side * 26, -18, cable), 0.075, graphite)
    _box(moving, "MagneticLiftClamp", Vector3(-side * 26, -18.1, 0),
         Vector3(7.5, 2.2, 8.0), steel)
    cranes.append(moving)
    service_gantries += 1

func _make_cart(root: Node3D, bay: int) -> void:
    var cart := Node3D.new()
    cart.name = "R11_AutonomousLoadingCart_%02d" % bay
    cart.position = Vector3(0, 3.65, 36.0)
    root.add_child(cart)
    _box(cart, "ElectricLoadChassis", Vector3.ZERO, Vector3(8.0, 1.6, 4.6), graphite)
    _box(cart, "CargoBattery", Vector3(0, 1.65, 0.0), Vector3(5.4, 1.5, 3.8), steel)
    _box(cart, "ForwardSensor", Vector3(0, 0.7, -2.36), Vector3(2.8, 0.6, 0.15), glass)
    for axle in [-2.5, 2.5]:
        for side in [-1.0, 1.0]:
            _box(cart, "SuspensionPod",
                 Vector3(axle, -0.9, side * 2.35), Vector3(1.6, 1.5, 0.65), copper)
    carts.append(cart)
    moving_carts += 1

func build(centres: Array) -> void:
    var deck_mesh: ArrayMesh = _sculpted_landing_deck()
    var struts: Array[Transform3D] = []
    var vents: Array[Transform3D] = []
    var markings: Array[Transform3D] = []
    var cargo: Array[Transform3D] = []
    var bolts: Array[Transform3D] = []
    for sector in centres.size():
        var center: Vector3 = centres[sector]
        for direction in [-1.0, 1.0]:
            var bay_id: int = sector * 2 + (0 if direction < 0.0 else 1)
            var loc: Vector3 = center + Vector3(direction * 132.0, 0, -121.0)
            var station := Node3D.new()
            station.name = "R11_DetailDock_%02d" % bay_id
            station.position = loc
            add_child(station)
            var platform := MeshInstance3D.new()
            platform.name = "R11_SculptedMachinedLandingDeck"
            platform.mesh = deck_mesh
            platform.material_override = deck_material
            station.add_child(platform)
            lod_nodes.append(platform)
            var body := StaticBody3D.new()
            body.name = "R11_LandingDockCollision"
            body.position.y = 1.0
            station.add_child(body)
            var cs := CollisionShape3D.new()
            var collision := CylinderShape3D.new()
            collision.radius = 25.6
            collision.height = 2.1
            cs.shape = collision
            body.add_child(cs)
            _make_gantry(station, bay_id, direction)
            _make_cart(station, bay_id)
            for j in 48:
                var theta: float = TAU * float(j) / 48.0
                var radial := Vector3(cos(theta), 0, sin(theta))
                var tangent := Vector3(-sin(theta), 0, cos(theta))
                var edge: Vector3 = loc + radial * 25.0
                struts.append(_beam_tf(edge + Vector3(0, 1.35, 0),
                                      edge + radial * 1.9 + Vector3(0, -1.4, 0), 0.46))
                markings.append(Transform3D(Basis(Vector3.UP, -theta).scaled(
                               Vector3(0.68, 0.15, 2.2)), edge + Vector3(0, 2.60, 0)))
                if j % 2 == 0:
                    bolts.append(Transform3D(Basis.IDENTITY.scaled(
                                Vector3(0.22, 0.14, 0.22)),
                                edge + Vector3(0, 2.54, 0)))
                if j % 3 == 0:
                    vents.append(Transform3D(Basis(Vector3.UP, theta).scaled(
                                 Vector3(1.4, 0.18, 1.6)),
                                 loc + radial * 20.4 + Vector3(0, 2.53, 0)))
                for ring in range(3):
                    var radius: float = 8.5 + float(ring) * 5.5
                    var angle: float = theta + float(ring) * 0.044
                    var pos := loc + Vector3(cos(angle) * radius, 2.58, sin(angle) * radius)
                    bolts.append(Transform3D(Basis.IDENTITY.scaled(
                                 Vector3(0.20, 0.095, 0.20)), pos))
            for row in range(4):
                for col in range(7):
                    var pos: Vector3 = loc + Vector3(
                        direction * (39.0 + float(col) * 3.8), 1.4,
                        12.0 + float(row) * 4.8)
                    cargo.append(Transform3D(Basis.IDENTITY.scaled(
                                 Vector3(3.1, 2.4, 3.7)), pos))
            docking_decks += 1
    _batch("R11_IndustrialPerimeterSupports", struts, steel)
    _batch("R11_DeckDrainageGrilles", vents, graphite)
    _batch("R11_WeatheredApproachGuides", markings, copper)
    _batch("R11_InstancedCargoModules", cargo, deck_material)
    _batch("R11_RivetAndBoltGrid", bolts, steel)
    set_quality(0)

func set_quality(mode: int) -> void:
    lod_mode = clampi(mode, 0, 2)
    for node in lod_nodes:
        if is_instance_valid(node):
            node.visibility_range_end = LOD_RANGES[lod_mode]
            node.visibility_range_end_margin = 90.0

func _process(delta: float) -> void:
    elapsed += delta
    for i in cranes.size():
        var arm: Node3D = cranes[i]
        if is_instance_valid(arm):
            arm.rotation.y = sin(elapsed * 0.19 + float(i) * 0.4) * 0.16
            arm.rotation.z = sin(elapsed * 0.13 + float(i) * 0.2) * 0.06
    for i in carts.size():
        var cart: Node3D = carts[i]
        if is_instance_valid(cart):
            cart.position.z = 36.0 + sin(elapsed * 0.38 + float(i) * 1.3) * 5.0
