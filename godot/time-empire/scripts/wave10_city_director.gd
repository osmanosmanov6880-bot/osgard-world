extends Node3D
## OSGARD CHRONOS Wave10: clustered coastal foliage, stronger landmark readability,
## physically grounded reactor light, state-driven construction reveal.
var game: Node3D
var web := false
var tree_count := 0
var elapsed := 0.0
var build_pulse := 0.0
var reactor_light: OmniLight3D

func configure(origin: Node3D) -> void:
    game = origin

func _ready() -> void:
    web = OS.has_feature("web") or RenderingServer.get_current_rendering_method() != "forward_plus"
    _rebuild_coastal_foliage()
    _grade_world()
    _install_core_light()
    print("OSGARD_WAVE10_CHRONOS: ", JSON.stringify({"trees":tree_count,"batched_forest_draws":2,"web":web,"construction_animation":true}))

func _clustered_mesh() -> ArrayMesh:
    var sphere := SphereMesh.new()
    sphere.radius = 0.65
    sphere.height = 1.25
    sphere.radial_segments = 8 if web else 14
    sphere.rings = 5 if web else 9
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.append_from(sphere,0,Transform3D(Basis().scaled(Vector3(0.88,0.90,0.95)),Vector3.ZERO))
    surface.append_from(sphere,0,Transform3D(Basis().scaled(Vector3(0.65,0.75,0.75)),Vector3(0.34,0.25,0.06)))
    surface.append_from(sphere,0,Transform3D(Basis().scaled(Vector3(0.65,0.77,0.76)),Vector3(-0.32,0.19,-0.16)))
    return surface.commit()

func _rebuild_coastal_foliage() -> void:
    var region := game.get_node_or_null("Wave7Region") as Node3D
    if region == null:
        return
    var previous := region.get_node_or_null("CoastalTreeCanopies") as MultiMeshInstance3D
    if previous == null or previous.multimesh == null:
        return
    tree_count = previous.multimesh.instance_count
    var crowns := MultiMesh.new()
    crowns.transform_format = MultiMesh.TRANSFORM_3D
    crowns.use_colors = true
    crowns.mesh = _clustered_mesh()
    crowns.instance_count = tree_count
    var trunks := MultiMesh.new()
    trunks.transform_format = MultiMesh.TRANSFORM_3D
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.10
    cylinder.bottom_radius = 0.18
    cylinder.height = 1.60
    cylinder.radial_segments = 6 if web else 10
    trunks.mesh = cylinder
    trunks.instance_count = tree_count
    for i in range(tree_count):
        var tr: Transform3D = previous.multimesh.get_instance_transform(i)
        crowns.set_instance_transform(i,tr)
        crowns.set_instance_color(i,Color(0.17 + 0.025*float(i%5),0.34 + 0.016*float(i%7),0.25 + 0.015*float(i%3)))
        var h: float = tr.basis.get_scale().x
        trunks.set_instance_transform(i,Transform3D(Basis().scaled(Vector3(h,h,h)),tr.origin - Vector3(0,1.0*h,0)))
    var foliage := MultiMeshInstance3D.new()
    foliage.name = "Wave10ClusteredFoliageGPU"
    foliage.multimesh = crowns
    var leaves := StandardMaterial3D.new()
    leaves.vertex_color_use_as_albedo = true
    leaves.roughness = 0.90
    foliage.material_override = leaves
    foliage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if web else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    region.add_child(foliage)
    var bark := MultiMeshInstance3D.new()
    bark.name = "Wave10WoodTrunksGPU"
    bark.multimesh = trunks
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.32,0.25,0.21)
    wood.roughness = 0.95
    bark.material_override = wood
    region.add_child(bark)
    previous.visible = false
    var original_stems := region.get_node_or_null("CoastalTreeTrunks") as MultiMeshInstance3D
    if original_stems != null:
        original_stems.visible = false

func _grade_world() -> void:
    var world := game.get_node_or_null("ChronosAtmosphere") as WorldEnvironment
    if world != null and world.environment != null:
        var env: Environment = world.environment
        env.adjustment_enabled = true
        env.adjustment_contrast = 1.06
        env.adjustment_saturation = 0.94
        env.glow_intensity = 0.18 if web else 0.24
        env.fog_density = 0.0017
        env.fog_light_color = Color(0.43,0.49,0.51)
        if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
            var sky := env.sky.sky_material as ProceduralSkyMaterial
            sky.sky_top_color = Color(0.10,0.17,0.23)
            sky.sky_horizon_color = Color(0.53,0.56,0.55)
            sky.ground_horizon_color = Color(0.29,0.37,0.36)
    var sun := game.get_node_or_null("ChronosSun") as DirectionalLight3D
    if sun != null:
        sun.light_color = Color(1.0,0.89,0.77)
    game.camera_radius = 45.0

func _install_core_light() -> void:
    var root := game.get_node_or_null("LivingCity/ChronoCore") as Node3D
    if root == null:
        return
    reactor_light = OmniLight3D.new()
    reactor_light.name = "Wave10WarmReactorBounce"
    reactor_light.position = Vector3(0,8.7,0)
    reactor_light.omni_range = 12.0
    reactor_light.light_color = Color(0.97,0.79,0.50)
    reactor_light.light_energy = 0.17 if web else 0.36
    reactor_light.shadow_enabled = false
    root.add_child(reactor_light)

func on_district_constructed(index: int) -> void:
    build_pulse = 1.0
    var district := game.get_node_or_null("LivingCity/DistrictPlots/District_%02d" % (index + 1)) as Node3D
    if district == null:
        return
    var target: Vector3 = district.position
    district.position = target + Vector3(0,-1.8,0)
    var tween := create_tween()
    tween.tween_property(district,"position",target,1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
    elapsed += minf(delta,0.1)
    build_pulse = maxf(0.0,build_pulse - delta*0.8)
    if reactor_light != null:
        var base: float = 0.17 if web else 0.36
        reactor_light.light_energy = base*(1.0 + 0.10*sin(elapsed*1.2) + 0.45*build_pulse)
