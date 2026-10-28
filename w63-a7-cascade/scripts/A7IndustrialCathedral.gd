extends Node3D
class_name A7IndustrialCathedral
## W67 INDUSTRIAL CATHEDRAL: original two-zone 3D cinematic environment.
## A dramatic architectural playable extension of the fictional A7 complex.
## Built as actual Godot MeshInstance3D geometry: not photographs or mockups.
## GFX nodes may read game state, but can never mutate A7CascadeCore.

const COPPER := Color("ba9973")
const CERAMIC := Color("8596a2")
const ICE := Color("56d9e5")
const GOLD := Color("f4c687")
const WARNING := Color("f47663")
const SHALE := Color("394b59")
const OBSIDIAN := Color("263541")

var main_arch: Node3D
var bridge: Node3D
var relay_sector: Node3D
var high_detail: Node3D
var core_pulse: StandardMaterial3D
var hazard_pulse: StandardMaterial3D
var relay_signal: StandardMaterial3D
var sky_panel: StandardMaterial3D
var turbine_vane: MeshInstance3D
var sector_signs: Array[Label3D] = []
var mesh_instances: int = 0
var reactor_tower_count: int = 0
var catwalk_sections: int = 0
var relay_terminals: int = 0
var readouts: int = 0
var sector: int = 0
var energy: float = 0.85
var danger: float = 0.0
var signal_quality: float = 0.44

func _finish(tint: Color, metallic: float = 0.08, emission: float = 0.0) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = tint
    result.metallic = metallic
    result.roughness = 0.65
    if emission > 0.0:
        result.emission_enabled = true
        result.emission = tint
        result.emission_energy_multiplier = emission
        result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return result

func _b(parent: Node3D, id: String, dims: Vector3, at: Vector3,
        finish: Material) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = dims
    var unit := MeshInstance3D.new()
    unit.name = id
    unit.mesh = shape
    unit.material_override = finish
    unit.position = at
    parent.add_child(unit)
    mesh_instances += 1
    return unit

func _c(parent: Node3D, id: String, radius: float, height: float, at: Vector3,
        finish: Material) -> MeshInstance3D:
    var shape := CylinderMesh.new()
    shape.top_radius = radius
    shape.bottom_radius = radius
    shape.height = height
    shape.radial_segments = 14
    var unit := MeshInstance3D.new()
    unit.name = id
    unit.mesh = shape
    unit.material_override = finish
    unit.position = at
    parent.add_child(unit)
    mesh_instances += 1
    return unit

func _tag(parent: Node3D, id: String, content: String, pos: Vector3,
        tint: Color, pixels: int = 68) -> void:
    var sign := Label3D.new()
    sign.name = id
    sign.text = content
    sign.font_size = pixels
    sign.pixel_size = 0.0050
    sign.modulate = tint
    sign.position = pos
    sign.no_depth_test = false
    parent.add_child(sign)
    sector_signs.append(sign)

func build() -> void:
    name = "W67RealIndustrialCathedralAndRelayBay"
    var structural := _finish(CERAMIC, 0.11)
    var brushed := _finish(SHALE, 0.10)
    var blackened := _finish(OBSIDIAN, 0.08)
    var copper := _finish(COPPER, 0.14)
    var grating := _finish(Color("5d707c"), 0.12)
    var ice := _finish(ICE, 0.0, 2.4)
    var gold := _finish(GOLD, 0.0, 1.6)
    core_pulse = _finish(ICE, 0.0, 2.65)
    relay_signal = _finish(ICE, 0.0, 2.25)
    hazard_pulse = _finish(WARNING, 0.0, 1.9)
    sky_panel = _finish(Color("557484"), 0.05)

    main_arch = Node3D.new()
    main_arch.name = "CORE_CATHEDRAL_MONUMENTAL_CHAMBER"
    add_child(main_arch)
    bridge = Node3D.new()
    bridge.name = "REAL_SPATIAL_INSPECTION_CATWALK"
    add_child(bridge)
    relay_sector = Node3D.new()
    relay_sector.name = "SECOND_FULLY_MODELED_RELAY_SECTOR"
    add_child(relay_sector)
    high_detail = Node3D.new()
    high_detail.name = "HERO_ONLY_ARCHITECTURAL_DETAIL"
    add_child(high_detail)

    # Tall industrial cathedral extends up over the previously small lab.
    _b(main_arch, "NewAtriumFloor", Vector3(25.0, 0.18, 33.0),
        Vector3(0.0, -0.39, 9.5), blackened)
    for side in [-1, 1]:
        var sx: float = 9.4 * float(side)
        for bay in range(8):
            var z: float = -4.0 + float(bay) * 3.7
            _b(main_arch, "MonumentalSupport%d_%02d" % [side, bay],
                Vector3(0.65, 16.2, 0.65), Vector3(sx, 7.9, z), structural)
            _b(main_arch, "SupportGoldJoint%d_%02d" % [side, bay],
                Vector3(0.84, 0.19, 0.84), Vector3(sx, 8.2, z), copper)
            _b(main_arch, "VerticalLuminalLine%d_%02d" % [side, bay],
                Vector3(0.048, 12.0, 0.095),
                Vector3(sx + (-0.37 if side < 0 else 0.37), 7.9, z),
                ice if bay % 2 == 0 else gold)
            if bay < 6:
                _b(main_arch, "UpperSuspendedServiceTruss%d_%02d" % [side, bay],
                    Vector3(0.17, 0.12, 3.4),
                    Vector3(sx, 13.6, z + 1.7), copper)
    for bay in range(8):
        var z: float = -3.5 + float(bay) * 3.7
        _b(main_arch, "OverheadCathedralTruss%02d" % bay,
            Vector3(19.7, 0.30, 0.62), Vector3(0, 15.1, z), structural)
        _b(main_arch, "OverheadLuminousVein%02d" % bay,
            Vector3(18.6, 0.05, 0.11), Vector3(0, 14.92, z), gold)
    for tier in range(3):
        var height: float = 6.25 + float(tier) * 3.1
        _c(main_arch, "CoreMegaContainmentShaft%d" % tier,
            1.83 + float(tier) * 0.30, 0.36,
            Vector3(0, height, -0.25), structural)
        reactor_tower_count += 1
        for spoke in range(14):
            var angle: float = TAU * float(spoke) / 14.0
            var rr: float = 2.45 + float(tier) * 0.30
            var pos := Vector3(sin(angle) * rr, height, cos(angle) * rr - 0.25)
            var rim := _b(main_arch, "UpperContainmentHalo%d_%02d" % [tier, spoke],
                Vector3(0.085, 0.12, 0.66), pos,
                core_pulse if tier == 1 else copper)
            rim.rotation.y = angle

    # Industrial core bulkhead, depth planes and warm practical strips.
    for side in [-1, 1]:
        var xx: float = float(side) * 5.0
        for row in range(5):
            var y: float = 1.0 + float(row) * 1.95
            _b(main_arch, "CoreMainRiser%d_%02d" % [side, row],
                Vector3(0.27, 1.72, 0.49),
                Vector3(xx, y, -3.7), grating)
            _b(main_arch, "RiserCopperCoupling%d_%02d" % [side, row],
                Vector3(0.39, 0.12, 0.63),
                Vector3(xx, y + 0.79, -3.7), copper)
    _tag(main_arch, "CORE_SYSTEM_ID", "A7 / REACTOR CORE",
        Vector3(0, 10.9, -4.2), GOLD, 85)
    _tag(main_arch, "CORE_STATUS_LABEL", "CONTAINMENT ARRAY  /  01",
        Vector3(0, 10.1, -4.2), ICE, 38)

    # Walkable guided camera route, actually modeled as a broad modular deck.
    _b(bridge, "SuspendedInspectionDeck", Vector3(3.8, 0.33, 14.6),
        Vector3(6.40, 0.10, 12.4), brushed)
    for module in range(14):
        var z: float = 5.8 + float(module) * 1.02
        catwalk_sections += 1
        _b(bridge, "CatwalkGrate%02d" % module,
            Vector3(3.26, 0.035, 0.74), Vector3(6.40, 0.29, z),
            grating if module % 2 else blackened)
        _b(bridge, "CatwalkCenterMark%02d" % module,
            Vector3(0.055, 0.04, 0.48), Vector3(6.40, 0.33, z),
            ice if module % 3 == 0 else gold)
        for side in [-1, 1]:
            var x: float = 6.40 + 1.73 * float(side)
            _b(bridge, "RailPylon%d_%02d" % [side,module],
                Vector3(0.13, 1.1, 0.13), Vector3(x, 0.80, z), structural)
            _b(bridge, "UnderDeckCable%d_%02d" % [side,module],
                Vector3(0.08, 0.08, 1.02), Vector3(x, 0.03, z), copper)
    for side in [-1, 1]:
        var x: float = 6.40 + 1.73 * float(side)
        _b(bridge, "LongCatwalkGuardRail%d" % side,
            Vector3(0.12, 0.10, 14.4), Vector3(x, 1.25, 12.4), structural)
        _b(bridge, "GuidingLightRail%d" % side,
            Vector3(0.055, 0.04, 14.4), Vector3(x, 1.33, 12.4), gold)

    # SECOND ZONE physically exists, not another camera aimed at the core.
    var zone_pos := Vector3(8.0, 0, 19.0)
    var relay_shell := Node3D.new()
    relay_shell.name = "ZONE_B_POWER_RELAY_HALL"
    relay_shell.position = zone_pos
    relay_sector.add_child(relay_shell)
    _b(relay_shell, "RelayFoundation", Vector3(11.4, 0.38, 11.2),
        Vector3(0, -0.22, 0), blackened)
    _b(relay_shell, "RelayBackWall", Vector3(11.2, 8.2, 0.32),
        Vector3(0, 4.0, -5.38), brushed)
    _b(relay_shell, "RelayWestWall", Vector3(0.29, 8.2, 10.5),
        Vector3(-5.38, 4.0, 0), structural)
    _b(relay_shell, "RelayEastWall", Vector3(0.29, 8.2, 10.5),
        Vector3(5.38, 4.0, 0), structural)
    for i in range(5):
        var y: float = 0.8 + float(i) * 1.2
        _b(relay_shell, "RelaySupportSlat%02d" % i,
            Vector3(10.7, 0.10, 0.25), Vector3(0, y, -5.08), copper)
    for i in range(3):
        var x: float = -2.8 + float(i) * 2.8
        _c(relay_shell, "CapacitorStack%d" % i, 0.63, 3.6,
            Vector3(x, 2.45, -2.55), structural)
        relay_terminals += 1
        _c(relay_shell, "CapacitorChargeRing%d" % i, 0.71, 0.18,
            Vector3(x, 2.0, -2.55), relay_signal)
        _c(relay_shell, "CapacitorCrown%d" % i, 0.77, 0.25,
            Vector3(x, 4.35, -2.55), copper)
        _b(relay_shell, "CapacitorStatus%d" % i,
            Vector3(0.8, 0.14, 0.11), Vector3(x, 2.66, -1.85), relay_signal)
    for bank in range(2):
        var x: float = -3.2 + float(bank) * 6.4
        _b(relay_shell, "PowerBusTower%d" % bank,
            Vector3(1.25, 4.6, 1.35), Vector3(x, 2.48, 1.5), structural)
        for row in range(5):
            var y: float = 1.0 + float(row) * 0.70
            _b(relay_shell, "TowerDataScreen%d_%d" % [bank,row],
                Vector3(0.77, 0.18, 0.13),
                Vector3(x, y, 2.25), relay_signal if row % 2 == 0 else gold)
    for i in range(6):
        var x: float = -4.55 + float(i) * 1.8
        _b(relay_shell, "MainPowerDuct%02d" % i,
            Vector3(0.16, 0.12, 7.6), Vector3(x, 7.24, -0.6), structural)
        _b(relay_shell, "MainPowerLED%02d" % i,
            Vector3(0.09, 0.035, 7.1), Vector3(x, 7.15, -0.6), ice)
    for i in range(4):
        _b(relay_shell, "RelayWarningArch%d" % i,
            Vector3(10.7, 0.17, 0.22),
            Vector3(0, 7.1, -3.6 + float(i) * 2.1), gold)
    _tag(relay_shell, "RELAY_SYSTEM_ID", "SECTOR 02 / RELAY MATRIX",
        Vector3(0, 6.20, -5.0), GOLD, 70)
    _tag(relay_shell, "RELAY_SECONDARY_ID", "POWER TRANSFER - LIVE",
        Vector3(0, 5.57, -5.0), ICE, 34)

    # HERO optional detail intentionally high enough to see, but hidden in ECO.
    for i in range(40):
        var z: float = -2.4 + float(i % 10) * 2.65
        var x: float = -8.7 + float(i / 10) * 5.75
        _b(high_detail, "SuspendedWiringNode%02d" % i,
            Vector3(0.15, 0.06, 0.15), Vector3(x, 10.95, z),
            copper if i % 3 == 0 else ice)
    turbine_vane = _b(high_detail, "UpperMonitorAssembly",
        Vector3(0.9, 0.15, 2.85), Vector3(0, 11.0, -0.25), copper)
    sector = 0

func set_sector(index: int) -> void:
    sector = clampi(index, 0, 1)

func set_quality(mode: String) -> void:
    if high_detail != null:
        high_detail.visible = mode != "eco"

func present(snapshot: Dictionary) -> void:
    var values: Dictionary = snapshot.get("metrics", {})
    energy = clampf(float(values.get("energy", 85)) / 100.0, 0.0, 1.0)
    signal_quality = clampf(float(values.get("signal", 44)) / 100.0, 0.0, 1.0)
    var integrity: float = clampf(float(values.get("integrity", 100)) / 100.0, 0.0, 1.0)
    var heat: float = clampf(float(values.get("heat", 62)) / 100.0, 0.0, 1.0)
    danger = clampf((1.0 - integrity) + maxf(0.0, heat - 0.77) * 2.0, 0, 1)
    if str(snapshot.get("status", "playing")) in ["failed", "unstable"]:
        danger = 1.0
    if relay_signal != null:
        relay_signal.emission = WARNING.lerp(ICE, energy)
        relay_signal.albedo_color = relay_signal.emission
        relay_signal.emission_energy_multiplier = 0.9 + energy * 2.0
    if core_pulse != null:
        core_pulse.emission = ICE.lerp(WARNING, danger)
        core_pulse.albedo_color = core_pulse.emission
        core_pulse.emission_energy_multiplier = 1.3 + danger * 1.8
    if hazard_pulse != null:
        hazard_pulse.emission = GOLD.lerp(WARNING, danger)

func qa_readout() -> Dictionary:
    return {
        "schema": "A7_W67_INDUSTRIAL_CATHEDRAL_REAL_TWO_ZONES_V1",
        "native_meshes": mesh_instances,
        "tall_reactor_tiers": reactor_tower_count,
        "physical_catwalk_modules": catwalk_sections,
        "real_relay_machines": relay_terminals,
        "sector": sector,
        "has_two_spatially_separate_wings": main_arch != null and relay_sector != null,
        "real_native_3d_signs": sector_signs.size() == 4,
        "energy": energy, "danger": danger,
        "physical_equipment_connected": false,
        "imported_licensed_assets": false,
        "user_gpu_certified": false,
    }
