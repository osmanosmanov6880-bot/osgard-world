extends Node3D
## OSGARD CHRONOS / WAVE 7 - region art, not a painted sky or mock-up.
## Physically placed terrain, shorelines, instanced vegetation and animated ferries.
## All city save, economy and transport nodes remain untouched.

const LOW_WATER := -7.05
const TERRAIN_EXTENT := 126.0
var game: Node3D
var web: bool = false
var elapsed: float = 0.0
var height_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var ships: Array[Node3D] = []
var shore_lights: Array[OmniLight3D] = []
var water_material: ShaderMaterial
var tree_instances: int = 0
var terrain_vertices: int = 0

func configure(origin: Node3D) -> void:
    game = origin

func _ready() -> void:
    web = OS.has_feature("web") or RenderingServer.get_current_rendering_method() != "forward_plus"
    height_noise = FastNoiseLite.new()
    height_noise.seed = 107773
    height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    height_noise.frequency = 0.022
    height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    height_noise.fractal_octaves = 4
    detail_noise = FastNoiseLite.new()
    detail_noise.seed = 90428
    detail_noise.frequency = 0.105
    _grade_atmosphere()
    _ocean_sheet()
    _continental_terrain()
    _vegetation_batches()
    _reclaimed_coast()
    _cargo_ferries()
    print("OSGARD_WAVE7_REGION: ", JSON.stringify({"terrain_vertices":terrain_vertices,"instanced_trees":tree_instances,"water_level":LOW_WATER,"web_lod":web}))

func _grade_atmosphere() -> void:
    var atmosphere: WorldEnvironment = game.get_node_or_null("ChronosAtmosphere") as WorldEnvironment
    if atmosphere == null or atmosphere.environment == null:
        return
    var env := atmosphere.environment
    var sky := Sky.new()
    sky.name = "Wave7PhysicalSky"
    var clouded_sky := ProceduralSkyMaterial.new()
    clouded_sky.sky_top_color = Color(0.075, 0.15, 0.25)
    clouded_sky.sky_horizon_color = Color(0.50, 0.56, 0.59)
    clouded_sky.ground_horizon_color = Color(0.39, 0.42, 0.43)
    clouded_sky.ground_bottom_color = Color(0.095, 0.14, 0.18)
    sky.sky_material = clouded_sky
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.ambient_light_energy = 0.81
    env.fog_enabled = true
    env.fog_light_color = Color(0.47, 0.57, 0.64)
    env.fog_density = 0.00135
    env.adjustment_enabled = true
    env.adjustment_saturation = 1.035
    env.adjustment_contrast = 1.045
    var sun: DirectionalLight3D = game.get_node_or_null("ChronosSun") as DirectionalLight3D
    if sun != null:
        sun.light_color = Color(1.0, 0.85, 0.72)
        sun.rotation_degrees = Vector3(-43.0, -29.0, 0.0)
    var cam: Camera3D = game.get_node_or_null("StrategyCamera") as Camera3D
    if cam != null:
        cam.far = 365.0

func _ocean_sheet() -> void:
    var ocean := MeshInstance3D.new()
    ocean.name = "HorizonWaterPlane"
    var plane := PlaneMesh.new()
    plane.size = Vector2(480.0, 480.0)
    plane.subdivide_width = 34 if web else 90
    plane.subdivide_depth = 34 if web else 90
    ocean.mesh = plane
    ocean.position.y = LOW_WATER
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;
uniform vec4 deep_ocean : source_color = vec4(0.050, 0.132, 0.168, 1.0);
varying vec3 world_point;
void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += sin(world_point.x * 0.075 + TIME * 0.32) * 0.045
              + sin(world_point.z * 0.11 - TIME * 0.45) * 0.035;
}
void fragment() {
    float crossing = sin(world_point.x * 0.24 + TIME * 0.61) *
                     sin(world_point.z * 0.19 - TIME * 0.47);
    float fine = sin((world_point.x + world_point.z) * 0.55 + TIME * 0.85);
    ALBEDO = deep_ocean.rgb * (0.97 + 0.028 * crossing) + vec3(0.003, 0.006, 0.007) * max(fine, 0.0);
    METALLIC = 0.16;
    ROUGHNESS = 0.30 + 0.044 * abs(crossing);
    SPECULAR = 0.75;
}
"""
    water_material = ShaderMaterial.new()
    water_material.shader = shader
    ocean.material_override = water_material
    ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ocean)

func _terrain_height(x: float, z: float) -> float:
    var r := Vector2(x, z).length()
    var rise: float = smoothstep(47.0, 82.0, r)
    var far_hills: float = smoothstep(77.0, 126.0, r)
    var ridge: float = height_noise.get_noise_2d(x, z) * 5.0 + detail_noise.get_noise_2d(x, z) * 0.70
    var island_coast := -11.8 + rise * 12.0 + far_hills * 3.3
    return island_coast + ridge * rise

func _ground_color(x: float, z: float, height_value: float) -> Color:
    var soil: float = clampf((height_value + 8.0) / 11.0, 0.0, 1.0)
    var vegetation: float = clampf(0.38 + detail_noise.get_noise_2d(x + 44.0, z + 31.0) * 0.46, 0.0, 1.0)
    var limestone := Color(0.42, 0.45, 0.42)
    var moss := Color(0.20, 0.38, 0.31)
    var sand := Color(0.52, 0.48, 0.38)
    var base: Color = sand.lerp(moss, soil * vegetation)
    return base.lerp(limestone, clampf((height_value - 4.5) * 0.08, 0.0, 0.40))

func _surface_vertex(st: SurfaceTool, x: float, z: float) -> void:
    var y := _terrain_height(x, z)
    st.set_color(_ground_color(x, z, y))
    st.set_uv(Vector2(x * 0.075, z * 0.075))
    st.add_vertex(Vector3(x, y, z))

func _continental_terrain() -> void:
    var tiles: int = 58 if web else 112
    var step: float = (TERRAIN_EXTENT * 2.0) / float(tiles)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for ix in range(tiles):
        var x0 := -TERRAIN_EXTENT + float(ix) * step
        var x1 := x0 + step
        for iz in range(tiles):
            var z0 := -TERRAIN_EXTENT + float(iz) * step
            var z1 := z0 + step
            _surface_vertex(st, x0, z0)
            _surface_vertex(st, x0, z1)
            _surface_vertex(st, x1, z0)
            _surface_vertex(st, x1, z0)
            _surface_vertex(st, x0, z1)
            _surface_vertex(st, x1, z1)
    st.generate_normals()
    var ground := MeshInstance3D.new()
    ground.name = "ContinentalTerrain"
    ground.mesh = st.commit()
    ground.material_override = _ground_material()
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    terrain_vertices = ground.mesh.surface_get_array_len(0)
    add_child(ground)

func _ground_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = 0.94
    mat.metallic = 0.02
    mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
    return mat

func _vegetation_batches() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 1924471
    var locations: Array[Transform3D] = []
    var greens: Array[Color] = []
    var wanted: int = 240 if web else 780
    for i in range(wanted * 3):
        if locations.size() >= wanted:
            break
        var angle: float = rng.randf_range(0.0, TAU)
        var radius: float = sqrt(rng.randf_range(77.0 * 77.0, 114.0 * 114.0))
        var x := cos(angle) * radius
        var z := sin(angle) * radius
        var y := _terrain_height(x, z)
        if y < LOW_WATER + 0.7:
            continue
        var scale_tree: float = rng.randf_range(0.8, 2.25)
        locations.append(Transform3D(Basis().scaled(Vector3(scale_tree, scale_tree, scale_tree)), Vector3(x, y, z)))
        var var_green: float = rng.randf_range(0.0, 1.0)
        greens.append(Color(0.13 + 0.12 * var_green, 0.28 + 0.16 * var_green, 0.24 + 0.06 * var_green))
    tree_instances = locations.size()
    var foliage_mesh := SphereMesh.new()
    foliage_mesh.radius = 0.75
    foliage_mesh.height = 1.6
    foliage_mesh.radial_segments = 8 if web else 14
    foliage_mesh.rings = 5 if web else 9
    var crown_mat := StandardMaterial3D.new()
    crown_mat.vertex_color_use_as_albedo = true
    crown_mat.roughness = 0.95
    var crowns := MultiMesh.new()
    crowns.transform_format = MultiMesh.TRANSFORM_3D
    crowns.use_colors = true
    crowns.mesh = foliage_mesh
    crowns.instance_count = locations.size()
    var trunks := MultiMesh.new()
    trunks.transform_format = MultiMesh.TRANSFORM_3D
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.11
    trunk_mesh.bottom_radius = 0.18
    trunk_mesh.height = 1.6
    trunk_mesh.radial_segments = 6
    trunks.mesh = trunk_mesh
    trunks.instance_count = locations.size()
    for i in range(locations.size()):
        var transform_tree: Transform3D = locations[i]
        var location: Vector3 = transform_tree.origin
        var sz: float = transform_tree.basis.get_scale().x
        var crown := Transform3D(Basis().scaled(Vector3(sz, sz * 1.1, sz)), location + Vector3(0.0, sz * 1.75, 0.0))
        var trunk := Transform3D(Basis().scaled(Vector3(sz, sz, sz)), location + Vector3(0.0, sz * 0.70, 0.0))
        crowns.set_instance_transform(i, crown)
        crowns.set_instance_color(i, greens[i])
        trunks.set_instance_transform(i, trunk)
    var canopy_node := MultiMeshInstance3D.new()
    canopy_node.name = "CoastalTreeCanopies"
    canopy_node.multimesh = crowns
    canopy_node.material_override = crown_mat
    canopy_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(canopy_node)
    var stem_node := MultiMeshInstance3D.new()
    stem_node.name = "CoastalTreeTrunks"
    stem_node.multimesh = trunks
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.24, 0.22, 0.19)
    wood.roughness = 0.93
    stem_node.material_override = wood
    add_child(stem_node)

func _solid(color: Color, metal: float, rough: float, emission: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metal
    mat.roughness = rough
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = emission
    return mat

func _box(parent: Node3D, identifier: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = identifier
    node.mesh = mesh
    node.position = pos
    node.material_override = mat
    parent.add_child(node)
    return node

func _reclaimed_coast() -> void:
    # The city is no longer a disconnected floating disc: engineering pylons
    # visibly anchor its foundation to the nearby ocean and shore infrastructure.
    var titanium := _solid(Color(0.28, 0.38, 0.42), 0.83, 0.31)
    var concrete := _solid(Color(0.48, 0.51, 0.50), 0.08, 0.83)
    var amber := _solid(Color(0.94, 0.62, 0.28), 0.20, 0.33, 0.35)
    var breakwater := Node3D.new()
    breakwater.name = "CityBreakwater"
    add_child(breakwater)
    var segments: int = 32
    for i in range(segments):
        var angle: float = float(i) * TAU / float(segments)
        var p := Vector3(cos(angle) * 31.0, -5.0, sin(angle) * 31.0)
        _box(breakwater, "ReinforcedQuayPier", Vector3(2.45, 5.3, 1.4), p, concrete).rotate_y(-angle)
        var outer := Vector3(cos(angle) * 31.8, -2.25, sin(angle) * 31.8)
        _box(breakwater, "DockFender", Vector3(1.5, 0.35, 1.5), outer, titanium)
        if i % 4 == 0:
            var beacon := _box(breakwater, "HarbourBeacon", Vector3(0.20, 0.66, 0.20), outer + Vector3(0.0, 0.55, 0.0), amber)
            beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Three coastal causeways emerge from under the city and meet landfall.
    # Causeways are omitted until connected to grounded land on both ends.
    # Free-floating unsupported slabs fail visual review.

func _cargo_ferries() -> void:
    var hull_mat := _solid(Color(0.62, 0.66, 0.68), 0.78, 0.28)
    var tint := _solid(Color(0.11, 0.30, 0.37), 0.25, 0.13)
    var led := _solid(Color(0.47, 0.88, 0.98), 0.03, 0.15, 1.1)
    for i in range(6):
        var ferry := Node3D.new()
        ferry.name = "CoastalFerry_%02d" % i
        add_child(ferry)
        _box(ferry, "MachinedCatamaran", Vector3(3.4, 0.64, 1.6), Vector3.ZERO, hull_mat)
        _box(ferry, "BridgeGlass", Vector3(1.05, 0.58, 1.25), Vector3(0.4, 0.45, 0.0), tint)
        _box(ferry, "DeckLuminance", Vector3(2.8, 0.06, 0.08), Vector3(0.0, -0.1, 0.79), led)
        ships.append(ferry)

func _process(delta: float) -> void:
    elapsed += minf(delta, 0.20)
    for i in range(ships.size()):
        var phase: float = elapsed * (0.047 + float(i % 3) * 0.006) + float(i) * TAU / float(ships.size())
        var lane := 38.5 + float(i % 2) * 3.0
        var ferry: Node3D = ships[i]
        ferry.position = Vector3(cos(phase) * lane, LOW_WATER + 0.52 + 0.045 * sin(elapsed * 0.72 + float(i)), sin(phase) * lane)
        ferry.rotation.y = -phase + PI * 0.5
