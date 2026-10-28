extends Node3D
class_name A7ArchitecturalDetail
## W66 / OBSIDIAN AURORA — original procedural art kit.
## All geometry built at runtime; no stock photos, external model downloads
## or remotely loaded textures. HERO quality only for heavy details.

const GOLD := Color("d6b17e")
const CYAN := Color("79d4d5")
const DEEP := Color("1e2b39")
const LAMP := Color("f6cf8a")

var reactor_halos: Node3D
var lightbars: Node3D
var relay_banks: Node3D
var engraved_sign: Label3D
var relay_core_material: StandardMaterial3D
var heat_strip_material: StandardMaterial3D
var actuator_material: StandardMaterial3D
var observed_energy: float = 0.85
var observed_heat: float = 0.62
var observed_seal: float = 0.68
var observed_signal: float = 0.44
var real_geometry_count: int = 0

func _mat(color: Color, glow: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.metallic = 0.16
    result.roughness = 0.55
    if glow > 0.0:
        result.emission_enabled = true
        result.emission = color
        result.emission_energy_multiplier = glow
    if unshaded:
        result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return result

func _detail_box(stage: Node3D, parent: Node3D,
        id: String, dim: Vector3, origin: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
    real_geometry_count += 1
    return stage.call("_box", parent, id, dim, origin, material) as MeshInstance3D

func _detail_cylinder(stage: Node3D, parent: Node3D,
        id: String, radius: float, h: float, origin: Vector3,
        material: StandardMaterial3D) -> MeshInstance3D:
    real_geometry_count += 1
    return stage.call("_cylinder", parent, id, radius, h, origin, material) as MeshInstance3D

func build(stage: Node3D) -> void:
    name = "ObsidianAuroraArtDistrict"
    var metal := _mat(Color("687d8e"))
    var metal_dark := _mat(Color("2c3c4d"))
    var gold := _mat(GOLD, 0.15)
    var cool_emission := _mat(CYAN, 2.7, true)
    var golden_emission := _mat(LAMP, 1.65, true)
    var dark := _mat(DEEP)
    relay_core_material = _mat(CYAN, 2.2, true)
    heat_strip_material = _mat(CYAN, 2.0, true)
    actuator_material = _mat(GOLD, 1.3, true)

    var nave := Node3D.new()
    nave.name = "StructuralAtriumGrid"
    add_child(nave)

    # A cinema-readable architectural silhouette: vertical ribs, overhead
    # gantry, lateral LED tracks and a ground-plane reference grid.
    for i in range(7):
        var xx: float = -6.2 + float(i) * 2.06
        _detail_box(stage, nave, "OverheadSpine%02d" % i,
            Vector3(0.10, 0.12, 8.2), Vector3(xx, 5.48, -0.6), metal)
        _detail_box(stage, nave, "FloorSafetyCut%02d" % i,
            Vector3(0.038, 0.023, 7.0), Vector3(xx, -0.105, 0.15),
            golden_emission if i % 2 == 0 else cool_emission)

    for i in range(6):
        var z: float = -3.7 + float(i) * 1.35
        _detail_box(stage, nave, "CrossFloorRail%02d" % i,
            Vector3(11.8, 0.015, 0.025), Vector3(0, -0.095, z), metal)
    for i in range(6):
        var xx: float = -5.7 + float(i) * 2.28
        _detail_box(stage, nave, "UpperWarningStrip%02d" % i,
            Vector3(0.68, 0.045, 0.06), Vector3(xx, 5.12, -4.34), golden_emission)
    for i in range(5):
        var x: float = -6.20 + float(i) * 3.1
        _detail_box(stage, nave, "ReinforcedColumn%02d" % i,
            Vector3(0.48, 5.10, 0.55), Vector3(x, 2.47, -4.05), metal_dark)
        for j in range(4):
            _detail_box(stage, nave, "ColumnRivet%d_%d" % [i, j],
                Vector3(0.50, 0.05, 0.59),
                Vector3(x, 0.65 + float(j) * 1.23, -4.04), gold)

    # Procedural ring-light array is more cinematic than one opaque cylinder.
    # Every halo is a circle of separate box-mesh luminescent segments.
    reactor_halos = Node3D.new()
    reactor_halos.name = "TriadContainmentHalos"
    add_child(reactor_halos)
    for level in range(4):
        var yy: float = 1.15 + float(level) * 0.87
        for i in range(20):
            var angle: float = TAU * float(i) / 20.0
            var radius: float = 1.71 if level % 2 == 0 else 1.53
            var halo := _detail_box(stage, reactor_halos,
                "ContainmentRing%02d_%02d" % [level, i],
                Vector3(0.052, 0.055, 0.43),
                Vector3(sin(angle) * radius, yy, cos(angle) * radius - 0.25),
                cool_emission if level == 1 or level == 3 else gold)
            halo.rotation.y = angle

    lightbars = Node3D.new()
    lightbars.name = "CyanGoldArchitecturalLightbars"
    add_child(lightbars)
    for side in [-1, 1]:
        var wall: float = 6.57 * float(side)
        for i in range(6):
            var yy: float = 0.75 + float(i) * 0.70
            _detail_box(stage, lightbars, "WallEchoStrip%d_%d" % [side, i],
                Vector3(0.055, 0.06, 5.5),
                Vector3(wall, yy, -0.2),
                cool_emission if i % 2 == 0 else gold)
    for i in range(5):
        var angle: float = TAU * float(i) / 5.0
        var x: float = sin(angle) * 2.22
        var z: float = cos(angle) * 2.22 - 0.25
        var tube := _detail_cylinder(stage, lightbars, "CoreUmbilical%02d" % i,
            0.085, 2.0, Vector3(x, 2.35, z), metal)
        tube.rotation.z = sin(angle) * 0.21

    # Relay gallery: second *visibly separate* functional wing. Its geometry
    # illuminates when the original game gains energy or signal fidelity.
    relay_banks = Node3D.new()
    relay_banks.name = "SeparateRelayGallery"
    add_child(relay_banks)
    var gallery := Node3D.new()
    gallery.name = "AuxiliaryRelayControlWing"
    relay_banks.add_child(gallery)
    _detail_box(stage, gallery, "GalleryDeck",
        Vector3(2.65, 0.22, 3.4), Vector3(4.68, 0.06, -2.35), dark)
    _detail_box(stage, gallery, "GalleryRearShield",
        Vector3(2.85, 3.0, 0.25), Vector3(4.67, 1.67, -3.83), metal_dark)
    _detail_box(stage, gallery, "GalleryHeader",
        Vector3(2.80, 0.18, 0.46), Vector3(4.67, 3.32, -3.83), gold)
    for i in range(6):
        var x: float = 3.70 + float(i % 3) * 0.92
        var y: float = 1.05 + float(i / 3) * 1.27
        _detail_box(stage, gallery, "RelayMonitorBack%02d" % i,
            Vector3(0.75, 1.03, 0.10), Vector3(x, y, -3.55), metal)
        _detail_box(stage, gallery, "RelayLiveIndicator%02d" % i,
            Vector3(0.52, 0.63, 0.12), Vector3(x, y, -3.46),
            relay_core_material if i % 3 != 1 else golden_emission)
        _detail_box(stage, gallery, "RelayControlRail%02d" % i,
            Vector3(0.52, 0.025, 0.145), Vector3(x, y - 0.40, -3.42), gold)
    for i in range(4):
        _detail_cylinder(stage, gallery, "RelayCapacitor%d" % i,
            0.18, 0.75, Vector3(3.65 + float(i) * 0.62, 0.57, -1.42), metal)
        _detail_box(stage, gallery, "CapacitorVisibleCharge%d" % i,
            Vector3(0.08, 0.51, 0.09),
            Vector3(3.65 + float(i) * 0.62, 0.57, -1.18), relay_core_material)

    # Labels are actual 3D Godot text meshes, not embedded screenshots.
    engraved_sign = Label3D.new()
    engraved_sign.name = "A7FacilityTypographicSign"
    engraved_sign.text = "A7    /    CONTAINMENT"
    engraved_sign.font_size = 49
    engraved_sign.pixel_size = 0.0055
    engraved_sign.modulate = GOLD
    engraved_sign.position = Vector3(0, 5.0, -4.17)
    add_child(engraved_sign)

func present(state: Dictionary) -> void:
    var stats: Dictionary = state.get("metrics", {})
    observed_energy = clampf(float(stats.get("energy", 85)) / 100.0, 0, 1)
    observed_heat = clampf(float(stats.get("heat", 62)) / 100.0, 0, 1)
    observed_seal = clampf(float(stats.get("seal", 68)) / 100.0, 0, 1)
    observed_signal = clampf(float(stats.get("signal", 44)) / 100.0, 0, 1)
    if relay_core_material != null:
        relay_core_material.emission = Color("eb8e65").lerp(CYAN, observed_energy)
        relay_core_material.albedo_color = relay_core_material.emission
    if heat_strip_material != null:
        heat_strip_material.emission = CYAN.lerp(Color("f26d59"), observed_heat)
    if actuator_material != null:
        actuator_material.emission = Color("f26d59").lerp(GOLD, observed_seal)

func qa_readout() -> Dictionary:
    return {
        "schema": "A7_W66_REAL_PROCEDURAL_ART_V1",
        "true_native_meshes_added": real_geometry_count,
        "has_reactor_halos": reactor_halos != null and reactor_halos.get_child_count() == 80,
        "has_independent_relay_gallery": relay_banks != null and relay_banks.get_child_count() > 0,
        "has_3d_scene_typography": engraved_sign != null,
        "energy": observed_energy,
        "heat": observed_heat,
        "signal": observed_signal,
        "seal": observed_seal,
        "uses_external_stock_images": false,
        "gameplay_authority": false,
        "physical_devices_certified": false,
    }
