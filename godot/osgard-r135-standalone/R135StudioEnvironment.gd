extends Node3D
## R135 W7. Quiet industrial studio: physically grounded matte surfaces and
## two batched floor grids. Purely visual; no simulated machinery is moved.
## ECO avoids costly reflections or hot emissive surfaces.
var grid_instances: int = 0
var grid_draw_batches: int = 0
var detail_instances: int = 0
var detail_draw_batches: int = 0
var luxury_draw_batches: int = 0
var luxury_instances: int = 0
var single_mesh_nodes: int = 0
var quality: int = 0
var stripe_material: StandardMaterial3D
var copper_material: StandardMaterial3D
var fastener_material: StandardMaterial3D
var architectural_led: StandardMaterial3D
# W23 real-source HERO-only PBR: reuse original 1024px textures and the Godot
# StandardMaterial3D shading pipeline. ECO never creates new draw calls.
var pbr_targets: Array[StandardMaterial3D] = []
var pbr_original_albedos: Array[Color] = []
var pbr_file_sets: Array[String] = ["epoxy_floor", "service_paint", "galvanized_steel", "warm_copper"]
var pbr_texture_cache: Dictionary = {}
var pbr_loaded_sets: int = 0
var pbr_load_failures: int = 0
var hero_only_nodes: Array[MultiMeshInstance3D] = []
var hero_only_batch_count: int = 0
var hero_only_instance_count: int = 0

func configure() -> void:
    var stage_mat: StandardMaterial3D = _surface(Color(0.085, 0.098, 0.115), 0.20, 0.83)
    var wall_mat: StandardMaterial3D = _surface(Color(0.065, 0.078, 0.094), 0.12, 0.90)
    var frame_mat: StandardMaterial3D = _surface(Color(0.14, 0.17, 0.19), 0.40, 0.62)
    stripe_material = _surface(Color(0.20, 0.28, 0.31), 0.38, 0.74)
    copper_material = _surface(Color(0.48, 0.24, 0.115), 0.42, 0.57, true)
    fastener_material = _surface(Color(0.31, 0.35, 0.39), 0.66, 0.42)
    architectural_led = _surface(Color(0.14, 0.42, 0.49), 0.24, 0.32, true)
    pbr_targets = [stage_mat, wall_mat, frame_mat, copper_material]
    for mat in pbr_targets:
        pbr_original_albedos.append(mat.albedo_color)

    _box("MatteIndustrialFloor", Vector3(0, -0.20, 4.90), Vector3(22, 0.29, 14), stage_mat)
    # W18: continue the matte architectural wall upward into the portrait
    # composition instead of leaving a large black void over the actual rig.
    _box("RearStudioCyclorama", Vector3(0, 7.4, -3.1), Vector3(22, 15.0, 0.22), wall_mat)
    _box("StructuralPillarLeft", Vector3(-10.25, 7.4, -2.9), Vector3(0.36, 14.8, 0.44), frame_mat)
    _box("StructuralPillarRight", Vector3(10.25, 7.4, -2.9), Vector3(0.36, 14.8, 0.44), frame_mat)
    _box("UpperStudioTruss", Vector3(0, 4.28, -2.9), Vector3(20.7, 0.18, 0.38), frame_mat)
    _box("W18OverheadServiceRail", Vector3(0, 10.5, -2.86), Vector3(20.7, 0.28, 0.46), frame_mat)
    _box("LowVisibilitySafetyBandFront", Vector3(0, -0.029, 11.60), Vector3(21.0, 0.013, 0.045), copper_material)
    _box("LowVisibilitySafetyBandRear", Vector3(0, -0.029, -1.75), Vector3(21.0, 0.013, 0.045), copper_material)

    var x_positions: Array[Vector3] = []
    for x in range(-10, 11, 2):
        x_positions.append(Vector3(float(x), -0.044, 4.9))
    _batch("MatteFloorGridX", Vector3(0.018, 0.008, 13), x_positions, stripe_material)

    var z_positions: Array[Vector3] = []
    for z in range(-1, 13, 2):
        z_positions.append(Vector3(0, -0.044, float(z)))
    _batch("MatteFloorGridZ", Vector3(20.5, 0.008, 0.018), z_positions, stripe_material)

    # W15: quiet industrial set dressing in THREE extra instanced batches.
    # Details sit BEHIND the rig or almost flush with the deck; no collisions,
    # no new shadow casters and no opaque element in an inspection sightline.
    var rear_fasteners: Array[Vector3] = []
    for row in [1.0, 3.4]:
        for x in range(-9, 10, 2):
            rear_fasteners.append(Vector3(float(x), float(row), -2.96))
    _batch("W15RearWallFasteners", Vector3(0.12, 0.12, 0.035), rear_fasteners, fastener_material, true)

    var deck_fasteners: Array[Vector3] = []
    for z in [9.0, 10.5]:
        for x in range(-8, 9, 2):
            deck_fasteners.append(Vector3(float(x), -0.038, float(z)))
    _batch("W15DeckFasteners", Vector3(0.075, 0.012, 0.075), deck_fasteners, fastener_material, true)

    var boundary_marks: Array[Vector3] = []
    for x in range(-8, 9, 2):
        boundary_marks.append(Vector3(float(x), -0.035, 11.35))
    _batch("W15DeckBoundaryMarks", Vector3(0.32, 0.009, 0.032), boundary_marks, copper_material, true)

    # Approved AAA-direction environmental pass. Physically believable
    # structure, repeat modules and restrained emissive accents are batched:
    # exactly FIVE extra GPU-instance groups; no simulated collisions, no
    # additional real-time shadows, no change to original mechanical GLBs.
    var rear_pilasters: Array[Vector3] = []
    for x in range(-9, 10, 2):
        rear_pilasters.append(Vector3(float(x), 6.2, -2.72))
    _batch("LuxuryRearArchitecturalPilasters", Vector3(0.17, 10.8, 0.21),
        rear_pilasters, frame_mat, false, true)

    var ceiling_ribs: Array[Vector3] = []
    for x in range(-9, 10, 3):
        ceiling_ribs.append(Vector3(float(x), 11.78, 3.20))
    _batch("LuxuryCeilingServiceRibs", Vector3(0.16, 0.19, 11.3),
        ceiling_ribs, frame_mat, false, true)

    var side_brackets: Array[Vector3] = []
    for z in [0.0, 2.0, 4.0, 6.0, 8.0, 10.0]:
        side_brackets.append(Vector3(-10.04, 4.4, z))
        side_brackets.append(Vector3(10.04, 4.4, z))
    _batch("LuxurySideWallBrackets", Vector3(0.22, 6.8, 0.19),
        side_brackets, frame_mat, false, true)

    var safety_inlays: Array[Vector3] = [
        Vector3(-9.45, -0.026, 5.0),
        Vector3(9.45, -0.026, 5.0)
    ]
    _batch("LuxuryCopperWayfindingInlays", Vector3(0.035, 0.008, 11.8),
        safety_inlays, copper_material, false, true)

    var service_leds: Array[Vector3] = []
    for x in range(-9, 10, 2):
        service_leds.append(Vector3(float(x), 10.9, -2.52))
    _batch("LuxurySoftCyanServiceLEDs", Vector3(0.63, 0.05, 0.06),
        service_leds, architectural_led, false, true)

    # Subtle environmental identity on the rear wall, not a floating UI HUD.
    # Label3D is intentionally counted separately from physical MeshInstance
    # draw budgets, allowing the original W11/15 baseline tests to remain exact.
    var wall_brand := Label3D.new()
    wall_brand.name = "LuxuryRearWallOSGARDIdentity"
    wall_brand.text = "O S G A R D  /  SERVICE LAB"
    wall_brand.font_size = 46
    wall_brand.pixel_size = 0.008
    wall_brand.modulate = Color(0.83, 0.88, 0.91, 0.88)
    # Original Chromium frame had the overhead lettering clipped at y=0;
    # lower the brand to a real wall-sign sightline, behind the machine.
    wall_brand.position = Vector3(6.9, 6.80, -2.59)
    wall_brand.no_depth_test = false
    wall_brand.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    add_child(wall_brand)

    # W23: three HERO-only instanced architectural details, placed behind
    # inspection sightlines. ECO draws zero of these and retains all W19
    # geometry numbers, original GLBs and mobile-friendly shadow budget.
    var overhead_conduits: Array[Vector3] = []
    for x in [-8.0, -5.0, -2.0, 1.0, 4.0, 7.0]:
        overhead_conduits.append(Vector3(x, 9.6, -2.66))
    _hero_only_batch("HeroOverheadCableTrays", Vector3(0.16, 0.11, 1.8),
        overhead_conduits, frame_mat)

    var panel_frames: Array[Vector3] = []
    for x in [-8.0, -5.0, -2.0, 1.0, 4.0, 7.0]:
        panel_frames.append(Vector3(x, 3.65, -2.52))
    _hero_only_batch("HeroRearCabinetMetalBorders", Vector3(0.75, 0.21, 0.07),
        panel_frames, frame_mat)

    var side_conduits: Array[Vector3] = []
    for z in [1.0, 3.5, 6.0, 8.5]:
        side_conduits.append(Vector3(-9.98, 5.2, z))
        side_conduits.append(Vector3(9.98, 5.2, z))
    _hero_only_batch("HeroCopperServiceConduits", Vector3(0.09, 0.08, 1.7),
        side_conduits, copper_material)
    set_quality(0)


func _hero_only_batch(label: String, extents: Vector3,
        points: Array[Vector3], material: Material) -> void:
    var primitive := BoxMesh.new()
    primitive.size = extents
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = primitive
    instances.instance_count = points.size()
    for i in range(points.size()):
        instances.set_instance_transform(i, Transform3D(Basis(), points[i]))
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = instances
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.visible = false
    add_child(node)
    hero_only_nodes.append(node)
    hero_only_batch_count += 1
    hero_only_instance_count += points.size()


func _ensure_real_pbr() -> void:
    if pbr_loaded_sets > 0 or pbr_load_failures > 0:
        return
    for family in pbr_file_sets:
        var loaded: Array[Texture2D] = []
        for suffix in ["albedo", "normal", "orm"]:
            var path: String = "res://textures/r135/%s_%s.png" % [family, suffix]
            var texture: Texture2D = load(path) as Texture2D
            if texture == null:
                pbr_load_failures += 1
                push_error("W23 original PBR map not found: " + path)
                return
            loaded.append(texture)
        pbr_texture_cache[family] = loaded
        pbr_loaded_sets += 1


func _apply_real_pbr() -> void:
    _ensure_real_pbr()
    if pbr_load_failures > 0:
        return
    for i in range(pbr_targets.size()):
        var surface: StandardMaterial3D = pbr_targets[i]
        var images: Array = pbr_texture_cache[pbr_file_sets[i]]
        # Authored ORM uses AO red, roughness green, metallic blue.
        surface.albedo_texture = images[0]
        surface.normal_texture = images[1]
        surface.normal_enabled = true
        surface.normal_scale = 0.42
        surface.ao_texture = images[2]
        surface.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
        surface.ao_enabled = true
        surface.roughness_texture = images[2]
        surface.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
        surface.metallic_texture = images[2]
        surface.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
        # Triplanar UVs avoid stretched detail on the primitive wall and floor
        # while HERO alone accepts the extra shader cost.
        surface.uv1_triplanar = true
        surface.uv1_scale = Vector3(4.0, 4.0, 4.0)
        surface.albedo_color = Color(0.73, 0.76, 0.78)


func _clear_hero_pbr() -> void:
    for i in range(pbr_targets.size()):
        var surface: StandardMaterial3D = pbr_targets[i]
        surface.albedo_texture = null
        surface.normal_texture = null
        surface.normal_enabled = false
        surface.ao_texture = null
        surface.ao_enabled = false
        surface.roughness_texture = null
        surface.metallic_texture = null
        surface.uv1_triplanar = false
        surface.albedo_color = pbr_original_albedos[i]


func _surface(color: Color, metal: float, rough: float, illuminated: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metal
    mat.roughness = rough
    if illuminated:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 0.15
    return mat

func _box(label: String, center: Vector3, extents: Vector3, material: Material) -> void:
    var instance := MeshInstance3D.new()
    instance.name = label
    var mesh := BoxMesh.new()
    mesh.size = extents
    instance.mesh = mesh
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    instance.position = center
    add_child(instance)
    single_mesh_nodes += 1

func _batch(label: String, extents: Vector3, coordinates: Array[Vector3], material: Material, detail: bool = false, luxury: bool = false) -> void:
    var box := BoxMesh.new()
    box.size = extents
    var group := MultiMesh.new()
    group.transform_format = MultiMesh.TRANSFORM_3D
    group.mesh = box
    group.instance_count = coordinates.size()
    for i in range(coordinates.size()):
        group.set_instance_transform(i, Transform3D(Basis(), coordinates[i]))
    var instance := MultiMeshInstance3D.new()
    instance.name = label
    instance.multimesh = group
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)
    if luxury:
        luxury_instances += coordinates.size()
        luxury_draw_batches += 1
    elif detail:
        detail_instances += coordinates.size()
        detail_draw_batches += 1
    else:
        grid_instances += coordinates.size()
        grid_draw_batches += 1

func set_quality(new_quality: int) -> void:
    quality = clampi(new_quality, 0, 2)
    if stripe_material != null:
        stripe_material.albedo_color = Color(0.17, 0.24, 0.27) if quality == 0 else Color(0.23, 0.30, 0.33)
    if copper_material != null:
        copper_material.emission_energy_multiplier = 0.12 if quality == 0 else 0.35
    if fastener_material != null:
        fastener_material.roughness = 0.68 if quality == 0 else 0.42
        fastener_material.metallic = 0.38 if quality == 0 else 0.66
    if architectural_led != null:
        # No bloom/SSR-dependent gimmicks in WebGL Compatibility ECO.
        architectural_led.emission_energy_multiplier = 0.15 if quality == 0 else 0.52
    for node in hero_only_nodes:
        node.visible = quality == 2
    if quality == 2:
        _apply_real_pbr()
    else:
        _clear_hero_pbr()

func render_budget() -> Dictionary:
    return {
        "grid_instances": grid_instances,
        "grid_draw_batches": grid_draw_batches,
        "detail_draw_batches": detail_draw_batches,
        "detail_instances": detail_instances,
        "luxury_draw_batches": luxury_draw_batches,
        "luxury_instances": luxury_instances,
        "luxury_emission": architectural_led.emission_energy_multiplier if architectural_led != null else 0.0,
        "fastener_roughness": fastener_material.roughness if fastener_material != null else -1.0,
        "single_mesh_nodes": single_mesh_nodes,
        "stage_quality": quality,
        "accent_emission": copper_material.emission_energy_multiplier if copper_material != null else 0.0,
        "visual_only": true,
        "real_pbr_source_sets": pbr_loaded_sets,
        "real_pbr_maps": pbr_loaded_sets * 3,
        "real_pbr_load_failures": pbr_load_failures,
        "hero_pbr_active": quality == 2 and pbr_loaded_sets == 4 and pbr_load_failures == 0,
        "hero_extra_instanced_batches": hero_only_batch_count if quality == 2 else 0,
        "hero_extra_instances": hero_only_instance_count if quality == 2 else 0,
        "hero_extra_casters": 0
    }
