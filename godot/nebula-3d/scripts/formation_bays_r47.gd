extends Node3D
## R47 two genuine 3D formation bays in the ISOLATED Aurora dock.
## Their visible craft geometry matches the R15 combat wingman silhouettes.
## This module is visual only; credit and premium ownership are authenticated
## separately by world.gd before setting or saving a real combat formation.
const VALID_CREW = ["wingman_escort", "wingman_ace"]
var assigned_ids: Array[String] = []
var craft_nodes: Array[Node3D] = []

func _material(color: Color, glowing: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.72
    mat.roughness = 0.35
    if glowing:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.4
    return mat

func _mesh(parent: Node3D, part_name: String, geometry: Mesh,
        offset: Vector3, finish: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    part.mesh = geometry
    part.position = offset
    part.material_override = finish
    parent.add_child(part)
    return part

func _box(size: Vector3) -> BoxMesh:
    var box := BoxMesh.new()
    box.size = size
    return box

func _ready() -> void:
    name = "R47_ActualWingmanDockBays"
    var floor_finish := _material(Color(0.04, 0.10, 0.14))
    var pad_glow := _material(Color(0.12, 0.65, 0.82), true)
    var metallic := _material(Color(0.27, 0.39, 0.50))
    for slot in 2:
        var pad := Node3D.new()
        pad.name = "R47_FormationBay_%d" % slot
        pad.position = Vector3(-6.8 if slot == 0 else 6.8, -1.77, 3.75)
        add_child(pad)
        var plinth := CylinderMesh.new()
        plinth.top_radius = 2.55
        plinth.bottom_radius = 2.55
        plinth.height = 0.22
        plinth.radial_segments = 28
        _mesh(pad, "R47_RealLandingPad", plinth, Vector3.ZERO, floor_finish)
        var rim := TorusMesh.new()
        rim.inner_radius = 2.16
        rim.outer_radius = 2.25
        rim.rings = 28
        rim.ring_segments = 6
        _mesh(pad, "R47_BayLightRim", rim, Vector3(0.0, 0.13, 0.0), pad_glow)
        for sign in [-1.0, 1.0]:
            _mesh(pad, "R47_GroundGuidance_%s" % str(sign),
                _box(Vector3(0.10, 0.04, 1.36)),
                Vector3(sign * 1.65, 0.13, 0.0), pad_glow)
        var craft := Node3D.new()
        craft.name = "R47_RealWingmanCraft_%d" % slot
        craft.position = Vector3(0.0, 1.18, 0.0)
        pad.add_child(craft)
        # R15 flight combat uses these exact box dimensions for its craft.
        _mesh(craft, "R47_ActualCombatHull", _box(Vector3(2.7, 0.6, 3.8)),
            Vector3.ZERO, metallic)
        _mesh(craft, "R47_ActualCombatWing", _box(Vector3(4.8, 0.16, 1.0)),
            Vector3.ZERO, metallic)
        _mesh(craft, "R47_EngineGuide", _box(Vector3(0.38, 0.12, 0.50)),
            Vector3(0.0, -0.03, 2.04), pad_glow)
        craft.visible = false
        craft_nodes.append(craft)

func set_formation(raw: Array) -> void:
    var normalized: Array[String] = []
    for entry in raw:
        var id: String = str(entry)
        if VALID_CREW.has(id) and not normalized.has(id) and normalized.size() < 2:
            normalized.append(id)
    if normalized == assigned_ids:
        return
    assigned_ids = normalized
    for slot in 2:
        var craft: Node3D = craft_nodes[slot]
        craft.visible = slot < assigned_ids.size()
        if craft.visible:
            var color: Color = (Color(0.75, 0.45, 0.20)
                if assigned_ids[slot] == "wingman_ace" else
                Color(0.22, 0.58, 0.65))
            var finish := _material(color)
            for part in craft.get_children():
                if part is MeshInstance3D and not str(part.name) == "R47_EngineGuide":
                    part.material_override = finish
