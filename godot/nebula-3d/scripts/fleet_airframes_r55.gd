extends Node3D
## NEBULA R55: three original, independently sculpted 3D airframe geometries.
## Each hull replaces the imported NX-08 silhouette, not just a paint or wing kit.
## Common R15 ownership, damage and movement rules remain untouched.
const VALID_HULLS := ["ship_scout", "ship_interceptor", "ship_guardian"]
const HangarLiveriesR59Script = preload("res://scripts/hangar_liveries_r59.gd")
const RING_SEGMENTS: int = 14

var selected_hull: String = "ship_scout"
var active_body: Node3D
var core_mesh: MeshInstance3D
var real_parts: Array[MeshInstance3D] = []
var detail_parts: Array[MeshInstance3D] = []
var thruster_plumes: Array[MeshInstance3D] = []
var half_span_m: float = 5.4
var length_m: float = 12.4
var engine_count: int = 1
var visual_signature: String = ""
var last_throttle: float = 0.0
var module_visual_r56: Node3D
var armor_rank_r56: int = 0
var shield_rank_r56: int = 0
var radar_rank_r56: int = 0
var livery_style_r59: String = "factory"
var livery_materials_r59: Dictionary = {}
var livery_trim_r59: Node3D

func _ready() -> void:
    set_hull(selected_hull)

func _paint(color: Color, rough: float = 0.34, metal: float = 0.82,
        glow: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metal
    mat.roughness = rough
    mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
    if glow > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = glow
    return mat

func _mesh_part(label: String, geometry: Mesh,
        at: Vector3, material: Material, small: bool = false) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = geometry
    part.position = at
    part.material_override = material
    active_body.add_child(part)
    real_parts.append(part)
    if small:
        detail_parts.append(part)
    return part

func _box(label: String, size: Vector3, at: Vector3,
        material: Material, tilt: Vector3 = Vector3.ZERO,
        small: bool = false) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    var part := _mesh_part(label, shape, at, material, small)
    part.rotation_degrees = tilt
    return part

func _tube(label: String, radius: float, length: float, at: Vector3,
        material: Material, glow: bool = false) -> MeshInstance3D:
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = length
    cylinder.radial_segments = 20
    var part := _mesh_part(label, cylinder, at, material, glow)
    part.rotation.x = PI * 0.5
    return part

func _sphere(label: String, scale3d: Vector3, at: Vector3,
        material: Material) -> MeshInstance3D:
    var ellipsoid := SphereMesh.new()
    ellipsoid.radius = 1.0
    ellipsoid.height = 2.0
    ellipsoid.radial_segments = 28
    ellipsoid.rings = 14
    var part := _mesh_part(label, ellipsoid, at, material)
    part.scale = scale3d
    return part

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    for v in [a, b, c]:
        st.set_uv(Vector2(v.x * 0.11 + 0.5, v.z * 0.11 + 0.5))
        st.add_vertex(v)

func _loft(label: String, rings: Array,
        material: Material) -> MeshInstance3D:
    # Genuine 3D fuselage geometry, not a rectangular BoxMesh or flat decal.
    # (ring.x, ring.y, ring.z) = horizontal radius, vertical radius, axial Z.
    var vertices: Array[Vector3] = []
    for ring in rings:
        var dims: Vector3 = ring
        for segment in RING_SEGMENTS:
            var angle: float = TAU * float(segment) / float(RING_SEGMENTS)
            vertices.append(Vector3(cos(angle) * dims.x,
                sin(angle) * dims.y, dims.z))
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for ring_index in range(rings.size() - 1):
        for segment in RING_SEGMENTS:
            var next_segment: int = (segment + 1) % RING_SEGMENTS
            var a: Vector3 = vertices[ring_index * RING_SEGMENTS + segment]
            var b: Vector3 = vertices[ring_index * RING_SEGMENTS + next_segment]
            var c: Vector3 = vertices[(ring_index + 1) * RING_SEGMENTS + next_segment]
            var d: Vector3 = vertices[(ring_index + 1) * RING_SEGMENTS + segment]
            _triangle(st, a, b, c)
            _triangle(st, a, c, d)
    st.generate_normals()
    st.generate_tangents()
    core_mesh = _mesh_part(label, st.commit(), Vector3.ZERO, material)
    return core_mesh

func _airfoil(label: String, outline: Array, top: float,
        bottom: float, material: Material,
        small: bool = false) -> MeshInstance3D:
    # Authored planform coordinates in the X/Z plane with true thickness.
    var winding: float = 0.0
    for i in outline.size():
        var p: Vector2 = outline[i]
        var q: Vector2 = outline[(i + 1) % outline.size()]
        winding += p.x * q.y - q.x * p.y
    var clockwise: bool = winding < 0.0
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(1, outline.size() - 1):
        var p0: Vector2 = outline[0]
        var p1: Vector2 = outline[i]
        var p2: Vector2 = outline[i + 1]
        var a := Vector3(p0.x, top, p0.y)
        var b := Vector3(p1.x, top, p1.y)
        var c := Vector3(p2.x, top, p2.y)
        var a_low := Vector3(p0.x, bottom, p0.y)
        var b_low := Vector3(p1.x, bottom, p1.y)
        var c_low := Vector3(p2.x, bottom, p2.y)
        if clockwise:
            _triangle(st, a, b, c)
            _triangle(st, a_low, c_low, b_low)
        else:
            _triangle(st, a, c, b)
            _triangle(st, a_low, b_low, c_low)
    for i in outline.size():
        var p: Vector2 = outline[i]
        var q: Vector2 = outline[(i + 1) % outline.size()]
        var a := Vector3(p.x, bottom, p.y)
        var b := Vector3(q.x, bottom, q.y)
        var c := Vector3(q.x, top, q.y)
        var d := Vector3(p.x, top, p.y)
        if clockwise:
            _triangle(st, a, b, c)
            _triangle(st, a, c, d)
        else:
            _triangle(st, a, c, b)
            _triangle(st, a, d, c)
    st.generate_normals()
    st.generate_tangents()
    return _mesh_part(label, st.commit(), Vector3.ZERO, material, small)

func _nacelle(label: String, x: float, y: float, rear_z: float,
        radius: float, armor: Material, dark: Material,
        glower: Material) -> void:
    _tube(label + "_OuterNacelle", radius, 2.7,
        Vector3(x, y, rear_z - 1.4), armor)
    _tube(label + "_CeramicHeatShield", radius * 0.79, 0.18,
        Vector3(x, y, rear_z), dark)
    _tube(label + "_RealIonEmitter", radius * 0.42, 0.14,
        Vector3(x, y, rear_z + 0.15), glower)
    var plume := _tube(label + "_ReactiveExhaust",
        radius * 0.29, 1.25, Vector3(x, y, rear_z + 0.89), glower, true)
    thruster_plumes.append(plume)
    for side in [-1.0, 1.0]:
        _box(label + "_Mount_%s" % str(side),
            Vector3(0.12, 0.22, 2.1),
            Vector3(x + side * radius * 0.83, y + 0.06, rear_z - 1.24),
            armor, Vector3.ZERO, true)

func _build_scout(titanium: Material, armor: Material,
        dark: Material, light: Material, glass: Material) -> void:
    visual_signature = "R55_NX08_LONG_NOSE_NARROW_RECON_WINGS_SINGLE_DRIVE"
    half_span_m = 5.6
    length_m = 12.6
    engine_count = 1
    _loft("R55_NX08_TrueNarrowFuselage",
        [Vector3(0.07, 0.06, -7.0), Vector3(0.42, 0.28, -5.4),
         Vector3(0.86, 0.56, -3.0), Vector3(1.02, 0.67, -0.5),
         Vector3(1.1, 0.71, 2.3), Vector3(0.81, 0.54, 4.1),
         Vector3(0.45, 0.37, 5.6)], titanium)
    for side in [-1.0, 1.0]:
        _airfoil("R55_NX08_RealSlenderWing_%s" % str(side), [
            Vector2(side * 0.92, -2.15), Vector2(side * 2.45, -1.12),
            Vector2(side * 5.62, 0.88), Vector2(side * 5.10, 2.12),
            Vector2(side * 1.0, 2.64)
        ], 0.18, -0.30, armor)
        _airfoil("R55_NX08_ActualSensorCanard_%s" % str(side), [
            Vector2(side * 0.65, -3.7), Vector2(side * 1.75, -2.9),
            Vector2(side * 1.60, -2.2), Vector2(side * 0.67, -2.3)
        ], 0.25, 0.07, titanium)
        _box("R55_NX08_ProbeRail_%s" % str(side),
            Vector3(0.09, 0.09, 3.1),
            Vector3(side * 3.0, 0.28, 0.15), light,
            Vector3(0.0, side * 16.0, 0.0), true)
        _box("R55_NX08_SurveyTail_%s" % str(side),
            Vector3(0.18, 1.55, 2.1),
            Vector3(side * 1.15, 0.68, 3.5), dark,
            Vector3(0.0, 0.0, side * 19.0))
    _sphere("R55_NX08_GlassCockpit", Vector3(0.79, 0.45, 1.72),
        Vector3(0, 0.64, -1.85), glass)
    _box("R55_NX08_NoseActiveArray", Vector3(0.20, 0.15, 1.35),
        Vector3(0, 0.29, -5.7), light, Vector3.ZERO, true)
    _nacelle("R55_NX08_CentralIonDrive", 0.0, -0.20, 5.2, 0.66,
        armor, dark, light)

func _build_interceptor(titanium: Material, armor: Material,
        dark: Material, light: Material, glass: Material,
        amber: Material) -> void:
    visual_signature = "R55_NX12_TWIN_ENGINE_DELTA_DART_ARMED_INTERCEPTOR"
    half_span_m = 7.2
    length_m = 13.8
    engine_count = 2
    _loft("R55_NX12_TrueWedgeRacerFuselage",
        [Vector3(0.10, 0.07, -6.5), Vector3(0.68, 0.31, -5.05),
         Vector3(1.18, 0.55, -3.4), Vector3(1.50, 0.61, -0.6),
         Vector3(1.83, 0.68, 2.3), Vector3(1.8, 0.59, 4.35),
         Vector3(0.91, 0.37, 6.1)], armor)
    for side in [-1.0, 1.0]:
        _airfoil("R55_NX12_RealForwardSweptDelta_%s" % str(side), [
            Vector2(side * 1.05, -3.62), Vector2(side * 1.92, -3.03),
            Vector2(side * 7.15, 0.72), Vector2(side * 6.45, 2.06),
            Vector2(side * 2.10, 3.20), Vector2(side * 1.03, 1.70)
        ], 0.12, -0.37, titanium)
        _airfoil("R55_NX12_ActualTailElevon_%s" % str(side), [
            Vector2(side * 2.0, 2.9), Vector2(side * 4.3, 3.6),
            Vector2(side * 4.1, 5.0), Vector2(side * 1.4, 4.9)
        ], 0.18, -0.13, armor)
        _airfoil("R55_NX12_BrightLeadingEdge_%s" % str(side), [
            Vector2(side * 2.1, -2.76), Vector2(side * 6.7, 0.72),
            Vector2(side * 6.45, 0.93), Vector2(side * 2.0, -2.39)
        ], 0.15, 0.135, amber, true)
        _box("R55_NX12_RealCannonPylon_%s" % str(side),
            Vector3(0.32, 0.38, 2.85),
            Vector3(side * 4.1, -0.50, 0.5), dark)
        _tube("R55_NX12_ArmoredMissileTube_%s" % str(side),
            0.31, 2.6, Vector3(side * 4.1, -0.54, 0.5), armor)
        _box("R55_NX12_VerticalStabilizer_%s" % str(side),
            Vector3(0.23, 1.85, 2.2),
            Vector3(side * 1.78, 0.91, 3.8),
            titanium, Vector3(0, 0, side * 24.0))
    _sphere("R55_NX12_StealthCanopy", Vector3(0.93, 0.38, 1.48),
        Vector3(0.0, 0.61, -2.65), glass)
    _box("R55_NX12_CanopyStructuralKeel",
        Vector3(0.12, 0.11, 2.4),
        Vector3(0.0, 0.99, -2.59), titanium, Vector3.ZERO, true)
    for side in [-1.0, 1.0]:
        _nacelle("R55_NX12_PairedThrust_%s" % str(side),
            side * 1.33, -0.20, 5.55, 0.72,
            armor, dark, amber)

func _build_guardian(titanium: Material, armor: Material,
        dark: Material, light: Material, glass: Material,
        amber: Material) -> void:
    visual_signature = "R55_NX21_HEAVY_ARMORED_WING_DUAL_COCKPIT_QUAD_REACTOR"
    half_span_m = 8.9
    length_m = 15.0
    engine_count = 4
    _loft("R55_NX21_TrueBroadArmoredCitadelHull",
        [Vector3(0.10, 0.11, -7.15), Vector3(0.94, 0.61, -5.6),
         Vector3(1.79, 0.88, -3.75), Vector3(2.33, 1.13, -0.95),
         Vector3(2.60, 1.18, 2.8), Vector3(2.35, 1.09, 5.14),
         Vector3(1.62, 0.75, 6.45)], titanium)
    for side in [-1.0, 1.0]:
        _airfoil("R55_NX21_ActualArmorWing_%s" % str(side), [
            Vector2(side * 2.1, -3.52), Vector2(side * 4.25, -2.48),
            Vector2(side * 8.85, -0.75), Vector2(side * 8.65, 3.18),
            Vector2(side * 5.16, 4.38), Vector2(side * 2.2, 4.54)
        ], 0.31, -0.76, armor)
        _airfoil("R55_NX21_ThickCeramicShield_%s" % str(side), [
            Vector2(side * 3.27, -1.42), Vector2(side * 7.6, 0.06),
            Vector2(side * 7.56, 2.72), Vector2(side * 4.2, 3.15)
        ], 0.43, 0.30, dark)
        _box("R55_NX21_BallisticArmorDeck_%s" % str(side),
            Vector3(1.28, 0.52, 3.8),
            Vector3(side * 5.25, 0.60, 1.05), titanium,
            Vector3(0.0, side * 6.0, 0.0))
        for plate in 3:
            _box("R55_NX21_ArmorFin_%s_%d" % [str(side), plate],
                Vector3(0.17, 0.22, 0.8),
                Vector3(side * (4.0 + float(plate) * 1.2), 0.85, 2.1),
                light, Vector3.ZERO, true)
        _box("R55_NX21_RaisedArmoredFin_%s" % str(side),
            Vector3(0.47, 2.2, 3.1),
            Vector3(side * 3.0, 1.25, 3.2),
            armor, Vector3(0.0, 0.0, side * 15.0))
        _box("R55_NX21_PlasmaTurretHousing_%s" % str(side),
            Vector3(1.35, 0.88, 2.4),
            Vector3(side * 4.45, 0.68, -0.20), titanium)
        _tube("R55_NX21_DorsalCannon_%s" % str(side),
            0.23, 3.2, Vector3(side * 4.45, 1.05, -1.76), dark)
    _box("R55_NX21_TrueRaisedBridge",
        Vector3(2.40, 1.02, 4.6), Vector3(0, 1.3, 0.32),
        armor)
    _sphere("R55_NX21_ArmoredDualCockpit",
        Vector3(1.22, 0.52, 1.70),
        Vector3(0, 1.42, -2.75), glass)
    _box("R55_NX21_CommandBridgeSensor",
        Vector3(0.43, 0.20, 3.70),
        Vector3(0, 1.98, 1.44), light, Vector3.ZERO, true)
    for side in [-1.0, 1.0]:
        for tandem in [-1.0, 1.0]:
            _nacelle("R55_NX21_QuadDrive_%s_%s" % [
                str(side), str(tandem)], side * (1.1 if tandem < 0.0 else 2.1),
                -0.30, 5.68, 0.63 if tandem < 0.0 else 0.50,
                titanium, dark, amber)

func _build_precision_r62(titanium: Material, armor: Material,
        light: Material) -> void:
    # The SAME physically meshed details are generated on the actual flight
    # airframe and the garage gallery, never a painted UI-only illustration.
    match selected_hull:
        "ship_scout":
            for side in [-1.0, 1.0]:
                _box("R62_NX08_RealNavigationPod_%s" % str(side),
                    Vector3(0.24, 0.20, 1.18),
                    Vector3(side * 2.34, -0.11, -0.60), titanium,
                    Vector3(0, side * 15.0, 0), true)
                _box("R62_NX08_SurveyWingRib_%s" % str(side),
                    Vector3(0.15, 0.12, 1.75),
                    Vector3(side * 4.10, 0.23, 0.75), armor,
                    Vector3(0, side * 9.0, 0), true)
                _box("R62_NX08_GenuineWingtipStrobe_%s" % str(side),
                    Vector3(0.16, 0.08, 0.30),
                    Vector3(side * 5.43, 0.23, 0.99), light,
                    Vector3.ZERO, true)
        "ship_interceptor":
            for side in [-1.0, 1.0]:
                _box("R62_NX12_TwinDriveHeatBaffle_%s" % str(side),
                    Vector3(0.80, 0.18, 1.75),
                    Vector3(side * 1.36, 0.53, 4.30), armor,
                    Vector3(0, side * 13.0, 0), true)
                _box("R62_NX12_ArmoredCanopyRail_%s" % str(side),
                    Vector3(0.12, 0.12, 2.1),
                    Vector3(side * 0.79, 0.92, -2.70), titanium,
                    Vector3.ZERO, true)
                _box("R62_NX12_ActualPylonStatusLight_%s" % str(side),
                    Vector3(0.24, 0.08, 0.74),
                    Vector3(side * 4.10, -0.25, 0.40), light,
                    Vector3.ZERO, true)
        "ship_guardian":
            for side in [-1.0, 1.0]:
                for plate in range(3):
                    _box("R62_NX21_SlopedArmorPanel_%s_%d" %
                        [str(side), plate], Vector3(0.36, 0.15, 1.48),
                        Vector3(side * (3.32 + float(plate) * 1.44),
                            0.49, 1.05), armor,
                        Vector3(0, side * 14.0, side * 8.0), true)
                _box("R62_NX21_HeavyBridgeSpine_%s" % str(side),
                    Vector3(0.19, 0.16, 3.45),
                    Vector3(side * 1.12, 1.99, -0.6), titanium,
                    Vector3.ZERO, true)
                _box("R62_NX21_QuadEngineServiceRail_%s" % str(side),
                    Vector3(0.24, 0.13, 2.35),
                    Vector3(side * 1.96, 0.25, 4.41), light,
                    Vector3.ZERO, true)

func _refresh_lod() -> void:
    for detail in detail_parts:
        if is_instance_valid(detail):
            detail.visible = not low_detail

var low_detail: bool = false
func set_low_detail(enabled: bool) -> void:
    low_detail = enabled
    _refresh_lod()

func set_hull(id: String) -> void:
    selected_hull = id if VALID_HULLS.has(id) else "ship_scout"
    if is_instance_valid(active_body):
        active_body.free()
    active_body = Node3D.new()
    active_body.name = "R55_Exclusive_" + selected_hull
    add_child(active_body)
    real_parts.clear()
    detail_parts.clear()
    thruster_plumes.clear()
    var titanium := _paint(Color(0.40, 0.47, 0.52), 0.28, 0.88)
    var armor := _paint(Color(0.070, 0.12, 0.18), 0.36, 0.79)
    var dark := _paint(Color(0.015, 0.038, 0.065), 0.43, 0.67)
    var light := _paint(Color(0.20, 0.75, 0.93), 0.22, 0.28, 2.0)
    var glass := _paint(Color(0.046, 0.18, 0.27), 0.09, 0.67)
    var amber := _paint(Color(0.97, 0.49, 0.17), 0.23, 0.20, 1.6)
    livery_materials_r59 = {
        "body":titanium, "armor":armor, "dark":dark,
        "light":light, "glass":glass, "amber":amber}
    match selected_hull:
        "ship_scout":
            _build_scout(titanium, armor, dark, light, glass)
        "ship_interceptor":
            _build_interceptor(titanium, armor, dark, light, glass, amber)
        "ship_guardian":
            _build_guardian(titanium, armor, dark, light, glass, amber)
    _build_precision_r62(titanium, armor, light)
    _refresh_lod()
    set_modules_r56(armor_rank_r56, shield_rank_r56, radar_rank_r56)
    set_livery_r59(livery_style_r59)
    set_throttle(last_throttle, false)

func _livery_detail_r59(label: String, size3d: Vector3,
        pos: Vector3, mat: Material, roll_deg: float = 0.0) -> void:
    if not is_instance_valid(livery_trim_r59):
        return
    var geometry := BoxMesh.new()
    geometry.size = size3d
    var detail := MeshInstance3D.new()
    detail.name = label
    detail.mesh = geometry
    detail.position = pos
    detail.rotation_degrees = Vector3(0.0, 0.0, roll_deg)
    detail.material_override = mat
    livery_trim_r59.add_child(detail)

func set_livery_r59(style: String) -> void:
    livery_style_r59 = (
        style if HangarLiveriesR59Script.valid_style(style) else "factory")
    if not is_instance_valid(active_body) or livery_materials_r59.is_empty():
        return
    var palette: Dictionary = HangarLiveriesR59Script.palette(
        livery_style_r59)
    var color_map: Dictionary = {
        "body":"body", "armor":"armor", "dark":"dark",
        "light":"accent", "glass":"glass"}
    for slot in color_map:
        var surface: StandardMaterial3D = livery_materials_r59.get(slot) as StandardMaterial3D
        if not is_instance_valid(surface):
            continue
        surface.albedo_color = palette[color_map[slot]]
        if slot == "body":
            surface.roughness = float(palette["roughness"])
        if slot == "light" and surface.emission_enabled:
            surface.emission = palette["accent"]
    # Existing individual physical ship geometries and paid R56 equipment
    # stay intact: paint changes their REAL materials, not a texture screenshot.
    if is_instance_valid(livery_trim_r59):
        livery_trim_r59.free()
    livery_trim_r59 = Node3D.new()
    livery_trim_r59.name = "R59_PhysicalPaintTrim_" + livery_style_r59
    active_body.add_child(livery_trim_r59)
    if livery_style_r59 == "factory":
        return
    var accent_mat := _paint(palette["accent"], 0.24, 0.67, 1.4)
    var outline_mat := _paint(palette["body"], 0.20, 0.90)
    # Each purchased style carries actual visible 3D strips with real
    # depth and highlights, placed on top of native wing/cockpit surfaces.
    var ratio: float = half_span_m / 5.6
    for side in [-1.0, 1.0]:
        for section in range(3):
            var x: float = side * (1.65 + float(section) * 1.14) * ratio
            var z: float = -0.28 + float(section) * 0.78
            _livery_detail_r59(
                "R59_PurchasedAccent_%s_%d" % [str(side), section + 1],
                Vector3(0.14, 0.055, 1.46),
                Vector3(x, -0.11, z), accent_mat, side * 8.0)
            _livery_detail_r59(
                "R59_ActualMetalStripe_%s_%d" % [str(side), section + 1],
                Vector3(0.27, 0.045, 1.50),
                Vector3(x + side * 0.16, -0.12, z), outline_mat,
                side * 8.0)
    # The upper centerline gives the chosen livery a clear silhouette even
    # while the wing underside is occluded in the cinematic hangar camera.
    _livery_detail_r59("R59_PurchasedTopSpineAccent",
        Vector3(0.13, 0.07, 4.9), Vector3(0, 0.83, -1.7), accent_mat)

func livery_geometry_count_r59() -> int:
    if not is_instance_valid(livery_trim_r59):
        return 0
    return livery_trim_r59.get_child_count()

func _module_box(label: String, size: Vector3, at: Vector3,
        material: Material, tilt: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.mesh = shape
    mesh.material_override = material
    mesh.position = at
    mesh.rotation_degrees = tilt
    module_visual_r56.add_child(mesh)
    return mesh

func set_modules_r56(armor_rank: int, shield_rank: int,
        radar_rank: int) -> void:
    armor_rank_r56 = clampi(armor_rank, 0, 3)
    shield_rank_r56 = clampi(shield_rank, 0, 3)
    radar_rank_r56 = clampi(radar_rank, 0, 3)
    if not is_instance_valid(active_body):
        return
    if is_instance_valid(module_visual_r56):
        module_visual_r56.free()
    module_visual_r56 = Node3D.new()
    module_visual_r56.name = "R56_ActualPurchasedEquipmentGeometry"
    active_body.add_child(module_visual_r56)
    var carbon := _paint(Color(0.09, 0.15, 0.19), 0.34, 0.82)
    var metal := _paint(Color(0.47, 0.57, 0.61), 0.31, 0.89)
    var emitter := _paint(Color(0.17, 0.83, 0.96), 0.19, 0.28, 2.5)
    var scale_width: float = half_span_m / 5.6
    for rank_index in armor_rank_r56:
        var offset: float = float(rank_index)
        var z: float = -0.7 + offset * 1.8
        for side in [-1.0, 1.0]:
            _module_box("R56_ArmorPlate_L%d_%s" % [
                rank_index + 1, str(side)], Vector3(0.85, 0.13, 2.0),
                Vector3(side * 1.75 * scale_width, 0.66, z),
                carbon, Vector3(0, side * 8.0, side * 3.0))
            _module_box("R56_ArmorRivet_L%d_%s" % [
                rank_index + 1, str(side)], Vector3(0.28, 0.08, 0.25),
                Vector3(side * 1.73 * scale_width, 0.76, z - 0.50),
                metal)
    for rank_index in shield_rank_r56:
        for side in [-1.0, 1.0]:
            var x: float = side * (
                2.15 + float(rank_index) * 1.12) * scale_width
            _module_box("R56_ActualShieldEmitter_L%d_%s" % [
                rank_index + 1, str(side)],
                Vector3(0.33, 0.16, 1.50),
                Vector3(x, 0.40, 1.08), emitter)
            _module_box("R56_ShieldGeneratorArmor_L%d_%s" % [
                rank_index + 1, str(side)],
                Vector3(0.53, 0.20, 1.62),
                Vector3(x, 0.26, 1.08), carbon)
    for rank_index in radar_rank_r56:
        var z: float = -4.1 + float(rank_index) * 0.82
        _module_box("R56_RealRadarArray_L%d" % (rank_index + 1),
            Vector3(0.49 + float(rank_index) * 0.12, 0.23, 0.65),
            Vector3(0, 1.26, z), emitter)
        _module_box("R56_SensorAntenna_L%d" % (rank_index + 1),
            Vector3(0.12, 0.58 + float(rank_index) * 0.25, 0.12),
            Vector3(0, 1.63 + float(rank_index) * 0.12, z),
            metal)

func module_geometry_count_r56() -> int:
    if not is_instance_valid(module_visual_r56):
        return 0
    return module_visual_r56.find_children("*", "MeshInstance3D", true, false).size()

func set_throttle(amount: float, afterburner: bool) -> void:
    last_throttle = clampf(amount, 0.0, 1.0)
    for jet in thruster_plumes:
        if is_instance_valid(jet):
            jet.scale.y = 0.55 + last_throttle * 1.30 + (
                0.65 if afterburner else 0.0)
            jet.visible = last_throttle > 0.02

func genuine_body_mesh_count() -> int:
    var result: int = 0
    for part in real_parts:
        if is_instance_valid(part) and part.mesh != null:
            result += 1
    return result
