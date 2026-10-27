extends Node3D
class_name A7ArtKit
## W66 original procedural facility art. Never downloads assets or mutates
## simulation state. All values refer to a fictional 3D game environment.

const CHARCOAL := Color("17212d")
const TITANIUM := Color("627686")
const COPPER := Color("ccac7b")
const RIM := Color("40bed0")
const ICE := Color("9eece9")
const WARNING := Color("edaa65")
const DANGER := Color("ea6664")

var meshes_created: int = 0
var low_cost_meshes: int = 0
var reactive_updates: int = 0
var high_detail: Node3D
var circuit_material: StandardMaterial3D
var warm_material: StandardMaterial3D
var status_material: StandardMaterial3D
var coolant_material: StandardMaterial3D
var danger_material: StandardMaterial3D
var pressure_shutters: Array[MeshInstance3D] = []
var coolant_manifolds: Array[MeshInstance3D] = []
var safety_lamps: Array[MeshInstance3D] = []
var current_quality: String = "hero"
var cooling_fraction: float = 0.38
var pressure_fraction: float = 0.48

func _finish(tone: Color, metallic: float = 0.4, illumination: float = 0.0) -> StandardMaterial3D:
    var finish := StandardMaterial3D.new()
    finish.albedo_color = tone
    finish.metallic = metallic
    finish.roughness = 0.43 if metallic > 0.5 else 0.67
    if illumination > 0.0:
        finish.emission_enabled = true
        finish.emission = tone
        finish.emission_energy_multiplier = illumination
    return finish

func _block(parent: Node3D, label: String, at: Vector3,
            extents: Vector3, finish: StandardMaterial3D) -> MeshInstance3D:
    var geometry := BoxMesh.new()
    geometry.size = extents
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = geometry
    part.material_override = finish
    part.position = at
    parent.add_child(part)
    meshes_created += 1
    if parent != high_detail:
        low_cost_meshes += 1
    return part

func _pipe(parent: Node3D, label: String, at: Vector3,
           radius: float, length: float, finish: StandardMaterial3D) -> MeshInstance3D:
    var geometry := CylinderMesh.new()
    geometry.top_radius = radius
    geometry.bottom_radius = radius
    geometry.height = length
    geometry.radial_segments = 16
    var piece := MeshInstance3D.new()
    piece.name = label
    piece.mesh = geometry
    piece.material_override = finish
    piece.position = at
    parent.add_child(piece)
    meshes_created += 1
    if parent != high_detail:
        low_cost_meshes += 1
    return piece

func assemble() -> void:
    name = "A7W66PremiumModularFacilityArt"
    high_detail = Node3D.new()
    high_detail.name = "OptionalHighDetailArtForHeroMode"
    add_child(high_detail)

    var floor_titanium := _finish(CHARCOAL, 0.67)
    var brushed := _finish(TITANIUM, 0.81)
    var gold := _finish(COPPER, 0.75, 0.15)
    var shadows := _finish(Color("0d161f"), 0.49)
    circuit_material = _finish(RIM, 0.30, 2.45)
    warm_material = _finish(WARNING, 0.36, 1.90)
    status_material = _finish(ICE, 0.16, 2.70)
    coolant_material = _finish(Color("53cce5"), 0.38, 2.70)
    danger_material = _finish(DANGER, 0.2, 2.15)

    # Two visible, mechanically distinct auxiliary bays linked by the
    # floor guide, beyond the central reaction vessel.
    _block(self, "LeftCoolantWingFloor", Vector3(-4.9, -0.095, -2.55),
        Vector3(3.40, 0.08, 3.50), floor_titanium)
    _block(self, "RightPressureWingFloor", Vector3(4.9, -0.095, -2.55),
        Vector3(3.40, 0.08, 3.50), floor_titanium)
    _block(self, "LeftCoolantBackPanel", Vector3(-5.58, 2.10, -4.52),
        Vector3(2.40, 3.7, 0.08), brushed)
    _block(self, "RightPressureBackPanel", Vector3(5.58, 2.10, -4.52),
        Vector3(2.40, 3.7, 0.08), brushed)

    for i in range(6):
        var x: float = -6.1 + float(i) * 2.48
        _block(self, "OverheadPremiumDiffuser%d" % i, Vector3(x, 5.28, 0.15),
            Vector3(1.15, 0.08, 0.24), status_material)
        _block(self, "BackWallMarker%d" % i, Vector3(x, 4.70, -4.40),
            Vector3(0.70, 0.06, 0.05), warm_material)
    for i in range(9):
        var z: float = -3.4 + float(i) * 0.82
        _block(self, "CopperRunwayEdgeLeft%d" % i, Vector3(-1.96, -0.081, z),
            Vector3(0.08, 0.03, 0.40), gold)
        _block(self, "CopperRunwayEdgeRight%d" % i, Vector3(1.96, -0.081, z),
            Vector3(0.08, 0.03, 0.40), gold)
    for i in range(10):
        var a: float = TAU * float(i) / 10.0
        var sector := _block(self, "InnerCoreNeonMarker%d" % i,
            Vector3(sin(a) * 1.46, 2.35, cos(a) * 1.46 - 0.25),
            Vector3(0.09, 1.66, 0.12), circuit_material)
        sector.rotation.y = a

    # Coolant bay: parallel physical manifolds, copper brackets and local
    # feedback lights. The tubes react visually to the actual heat value.
    for i in range(5):
        var x: float = -6.30 + float(i) * 0.47
        _block(self, "CoolantBayTower%d" % i,
            Vector3(x, 1.52, -3.84), Vector3(0.32, 2.85, 0.36), shadows)
        var tube := _pipe(self, "CoolantBayVisibleManifold%d" % i,
            Vector3(x, 1.75, -3.51), 0.12, 2.17, coolant_material)
        coolant_manifolds.append(tube)
        _block(self, "CoolantBayBrassAnchor%d" % i,
            Vector3(x, 0.48, -3.38), Vector3(0.25, 0.14, 0.28), gold)
    _block(self, "CoolantWingStatusScreen",
        Vector3(-4.95, 3.52, -4.32), Vector3(1.90, 0.41, 0.10), circuit_material)

    # Pressure bay: a physical rack of directional shutters. The geometry
    # changes in reaction to the fictional pressure and seal values.
    for i in range(5):
        var x: float = 4.28 + float(i) * 0.43
        _block(self, "PressureBayFoundation%d" % i,
            Vector3(x, 1.26, -3.89), Vector3(0.34, 2.44, 0.32), shadows)
        var shutter := _block(self, "PressureBayMovingShutter%d" % i,
            Vector3(x, 1.40, -3.54), Vector3(0.30, 1.68, 0.11), brushed)
        pressure_shutters.append(shutter)
    _block(self, "PressureWingStatusScreen",
        Vector3(5.13, 3.52, -4.32), Vector3(2.00, 0.41, 0.11), warm_material)

    # Expressive luminous safety fixtures; not a flat screenshot overlay.
    for i in range(4):
        var x: float = -5.45 if i % 2 == 0 else 5.45
        var z: float = -3.55 if i < 2 else 2.25
        var light := _block(self, "A7VisibleEmergencyLight%d" % i,
            Vector3(x, 3.64, z), Vector3(0.13, 0.72, 0.22), warm_material)
        safety_lamps.append(light)

    # Detail tier is conditional: ECO removes these meshes from the real
    # GPU scene, preserving the fully playable original decision system.
    for i in range(24):
        var angle: float = TAU * float(i) / 24.0
        var at: Vector3 = Vector3(sin(angle) * 2.05,
            1.18 + 0.24 * float(i % 3), cos(angle) * 2.05 - 0.25)
        var fin := _block(high_detail, "HEROHelixFin%02d" % i,
            at, Vector3(0.11, 0.12, 0.52), gold)
        fin.rotation.y = angle
    for i in range(24):
        var x: float = -6.5 + float(i % 12) * 1.18
        var z: float = -3.90 if i < 12 else 3.84
        _block(high_detail, "HEROFloorHazardInlay%02d" % i,
            Vector3(x, -0.08, z), Vector3(0.55, 0.014, 0.08), warm_material)

func apply_metrics(stats: Dictionary, external_severity: float) -> void:
    var heat_value: float = clampf(float(stats.get("heat", 62)) / 100.0, 0.0, 1.0)
    pressure_fraction = clampf(float(stats.get("pressure", 48)) / 100.0, 0.0, 1.0)
    cooling_fraction = 1.0 - heat_value
    coolant_material.emission = DANGER.lerp(RIM, cooling_fraction)
    circuit_material.emission = RIM.lerp(ICE, cooling_fraction)
    warm_material.emission = WARNING.lerp(DANGER, clampf(external_severity, 0.0, 1.0))
    for i in range(pressure_shutters.size()):
        var hatch: MeshInstance3D = pressure_shutters[i]
        hatch.scale.y = 0.46 + pressure_fraction * 0.71
        hatch.position.y = 1.15 + pressure_fraction * 0.46
    for light in safety_lamps:
        light.material_override = danger_material if external_severity > 0.6 else warm_material
    reactive_updates += 1

func set_quality(mode: String) -> void:
    current_quality = "eco" if mode == "eco" else "hero"
    if high_detail != null:
        high_detail.visible = current_quality == "hero"

func qa_readout() -> Dictionary:
    return {
        "schema": "A7_W66_TRUE_PROCEDURAL_CINEMATIC_ART_V1",
        "actual_meshes": meshes_created,
        "base_meshes": low_cost_meshes,
        "extra_hero_meshes": high_detail.get_child_count() if high_detail != null else 0,
        "coolant_bay_reactive_tubes": coolant_manifolds.size(),
        "pressure_bay_reactive_shutters": pressure_shutters.size(),
        "safety_beacons": safety_lamps.size(),
        "real_reactive_updates": reactive_updates,
        "heat_cooling_fraction": cooling_fraction,
        "pressure_fraction": pressure_fraction,
        "quality": current_quality,
        "original_assets_only": true,
        "network_requests": false,
        "physically_certified": false,
    }
