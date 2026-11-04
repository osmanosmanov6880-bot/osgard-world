extends Node3D
## R45: three materially and geometrically distinct *authored procedural*
## airframe conversion kits built on the shared imported NX-08 core.
## These are real 3D meshes and light assemblies, never 2D thumbnails.
## Same geometry is attached to both playable ship and 3D garage preview.
## Ship entitlement and physics remain owned by R15/fleet and the server.

const VALID_HULLS = ["ship_scout", "ship_interceptor", "ship_guardian"]

var selected_hull: String = "ship_scout"
var visual_parts: Array[MeshInstance3D] = []

func _ready() -> void:
    set_hull(selected_hull)

func _metal(color: Color, luminous: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.75
    material.roughness = 0.33
    if luminous:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.2
    return material

func _box(part_name: String, dimensions: Vector3, origin: Vector3,
        material: Material, tilt: Vector3 = Vector3.ZERO) -> void:
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    var part := MeshInstance3D.new()
    part.name = part_name
    part.mesh = mesh
    part.position = origin
    part.rotation_degrees = tilt
    part.material_override = material
    add_child(part)
    visual_parts.append(part)

func _cylinder(part_name: String, radius: float, length: float,
        origin: Vector3, material: Material) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 16
    var part := MeshInstance3D.new()
    part.name = part_name
    part.mesh = mesh
    part.position = origin
    part.rotation_degrees = Vector3(90, 0, 0)
    part.material_override = material
    add_child(part)
    visual_parts.append(part)

func set_hull(id: String) -> void:
    selected_hull = id if VALID_HULLS.has(id) else "ship_scout"
    for part in visual_parts:
        if is_instance_valid(part):
            part.free()
    visual_parts.clear()
    var dark := _metal(Color(0.055, 0.11, 0.17))
    var trim := _metal(Color(0.35, 0.50, 0.59))
    if selected_hull == "ship_scout":
        # Narrow recon fins and a forward antenna distinguish the base scout.
        var cyan := _metal(Color(0.11, 0.70, 0.85), true)
        for side in [-1.0, 1.0]:
            _box("R45_ScoutReconFin_%s" % str(side), Vector3(0.22, 0.65, 3.6),
                Vector3(side * 3.2, 0.36, 0.7), trim,
                Vector3(0, -side * 12, -side * 18))
            _box("R45_ScoutBeacon_%s" % str(side), Vector3(0.14, 0.09, 1.3),
                Vector3(side * 3.30, 0.75, 0.4), cyan)
        _box("R45_ScoutLongRangeSensor", Vector3(0.15, 0.20, 2.5),
            Vector3(0, 1.07, -2.3), cyan)
    elif selected_hull == "ship_interceptor":
        # Twin swept blades and unmistakable amber powered nacelles.
        var amber := _metal(Color(0.97, 0.48, 0.15), true)
        for side in [-1.0, 1.0]:
            _box("R45_InterceptorBlade_%s" % str(side),
                Vector3(2.9, 0.22, 4.0), Vector3(side * 3.3, 0.17, 0.50),
                dark, Vector3(0, side * 25, side * 5))
            _box("R45_InterceptorLeadingEdge_%s" % str(side),
                Vector3(2.6, 0.11, 0.22), Vector3(side * 4.0, 0.26, -1.28),
                amber, Vector3(0, side * 25, 0))
            _cylinder("R45_InterceptorTwinThruster_%s" % str(side),
                0.63, 2.5, Vector3(side * 2.45, -0.18, 2.3), trim)
            _cylinder("R45_InterceptorGlow_%s" % str(side),
                0.41, 0.14, Vector3(side * 2.45, -0.18, 3.62), amber)
    else:
        # Broad defensive side armor, top dorsal bridge and four cyan lamps.
        # Size/silhouette visibly heavier; no modification to physics collider.
        var blue := _metal(Color(0.12, 0.62, 0.93), true)
        for side in [-1.0, 1.0]:
            _box("R45_GuardianShieldWing_%s" % str(side),
                Vector3(3.5, 1.05, 5.5), Vector3(side * 3.15, -0.05, 0.70),
                dark, Vector3(0, side * 8, 0))
            _box("R45_GuardianArmorRidge_%s" % str(side),
                Vector3(1.4, 0.55, 4.4), Vector3(side * 4.6, 0.63, 0.35), trim)
            _box("R45_GuardianShieldStrip_%s" % str(side),
                Vector3(0.24, 0.12, 3.5), Vector3(side * 5.15, 0.96, 0.1), blue)
            for slot in [-1.0, 1.0]:
                _box("R45_GuardianLamp_%s_%s" % [str(side), str(slot)],
                    Vector3(0.35, 0.19, 0.52),
                    Vector3(side * 5.15, 0.98, slot * 1.5), blue)
        _box("R45_GuardianDorsalBridge", Vector3(1.7, 1.2, 4.6),
            Vector3(0, 0.95, 0.38), trim)
        _box("R45_GuardianSpinalArmor", Vector3(0.62, 0.28, 5.5),
            Vector3(0, 1.62, 0.16), blue)
