extends Node3D
## Wave 10: state-responsive receiver, legible flight path, polished cinematic fill.
## Mechanical iris uses one instanced draw group; neither ballistics nor save state change.

const JAWS := 12
var game: Node3D
var web := false
var elapsed := 0.0
var iris: MultiMeshInstance3D
var iris_mesh: MultiMesh
var ring: MeshInstance3D
var ring_mat: StandardMaterial3D
var signal_light: OmniLight3D
var last_polarity := 0

func configure(origin: Node3D) -> void:
    game = origin

func _ready() -> void:
    web = OS.has_feature("web") or RenderingServer.get_current_rendering_method() != "forward_plus"
    _build_field()
    _build_iris()
    _tune_cinematic_color()
    call_deferred("_move_tips_above_launcher")
    print("OSGARD_WAVE10_VECTOR: ", JSON.stringify({"jaws":JAWS,"gpu_draw_groups":1,"web":web,"reactive_to_polarity":true}))

func _material(color: Color, metal: float, rough: float, emission: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metal
    m.roughness = rough
    if emission > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = emission
    return m

func _build_field() -> void:
    var magnet := game.get_node_or_null("MagnetAssembly") as Node3D
    if magnet == null:
        return
    var torus := TorusMesh.new()
    torus.inner_radius = 2.69
    torus.outer_radius = 2.77
    torus.rings = 42 if web else 96
    torus.ring_segments = 8 if web else 16
    ring = MeshInstance3D.new()
    ring.name = "PolarityFeedbackRing"
    ring.mesh = torus
    ring.rotation.x = PI * 0.5
    ring.position.z = 1.0
    ring_mat = _material(Color(0.62,0.44,1.0),0.16,0.29,1.35)
    ring.material_override = ring_mat
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    magnet.add_child(ring)
    signal_light = OmniLight3D.new()
    signal_light.name = "MagneticFeedbackLight"
    signal_light.position = Vector3(0,0,1.1)
    signal_light.omni_range = 7.0
    signal_light.light_energy = 0.22 if web else 0.44
    signal_light.shadow_enabled = false
    magnet.add_child(signal_light)

func _build_iris() -> void:
    var receiver := game.get_node_or_null("ReceiverAssembly") as Node3D
    if receiver == null:
        return
    var node := Node3D.new()
    node.name = "Wave10PrecisionReceiver"
    receiver.add_child(node)
    var rim := TorusMesh.new()
    rim.inner_radius = 1.48
    rim.outer_radius = 1.62
    rim.rings = 48 if web else 96
    rim.ring_segments = 8 if web else 16
    var bearing := MeshInstance3D.new()
    bearing.name = "MachinedBearingRace"
    bearing.mesh = rim
    bearing.rotation.x = PI * 0.5
    bearing.position.z = 0.82
    bearing.material_override = _material(Color(0.46,0.54,0.61),0.92,0.33)
    node.add_child(bearing)
    var jaw_mesh := BoxMesh.new()
    jaw_mesh.size = Vector3(0.26,0.67,0.11)
    iris_mesh = MultiMesh.new()
    iris_mesh.transform_format = MultiMesh.TRANSFORM_3D
    iris_mesh.mesh = jaw_mesh
    iris_mesh.instance_count = JAWS
    iris = MultiMeshInstance3D.new()
    iris.name = "KineticTwelveJawIris"
    iris.multimesh = iris_mesh
    iris.material_override = _material(Color(0.70,0.78,0.80),0.91,0.34)
    iris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.add_child(iris)
    _update_jaws(0.0)

func _update_jaws(openness: float) -> void:
    if iris_mesh == null:
        return
    for i in range(JAWS):
        var angle := TAU * float(i) / float(JAWS)
        var radius := 1.26 + 0.26 * openness
        iris_mesh.set_instance_transform(i, Transform3D(Basis(Vector3(0,0,1),-angle), Vector3(cos(angle)*radius,sin(angle)*radius,0.94)))

func _tune_cinematic_color() -> void:
    var world := game.get_node_or_null("CinematicEnvironment") as WorldEnvironment
    if world != null and world.environment != null:
        world.environment.adjustment_enabled = true
        world.environment.adjustment_contrast = 1.045
        world.environment.adjustment_saturation = 0.93
        world.environment.glow_intensity = 0.18 if web else 0.24
        world.environment.fog_density = 0.0020 if web else 0.0028
    var bounce := SpotLight3D.new()
    bounce.name = "WarmCopperRimLight"
    bounce.position = Vector3(-5.1,11.5,5.3)
    bounce.light_color = Color(1.0,0.71,0.43)
    bounce.light_energy = 0.9 if web else 1.4
    bounce.spot_range = 18.0
    bounce.spot_angle = 55.0
    bounce.shadow_enabled = false
    game.add_child(bounce)
    bounce.look_at(Vector3(0,4.8,-1.0))

func _move_tips_above_launcher() -> void:
    var panel := game.get_node_or_null("RussianGameHUD/TipPanel") as PanelContainer
    if panel == null:
        return
    panel.anchor_left = 0.025
    panel.anchor_right = 0.315
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    panel.offset_top = 145.0
    panel.offset_bottom = 237.0

func _process(delta: float) -> void:
    if game == null:
        return
    elapsed += minf(delta,0.1)
    var polarity: int = int(game.get("polarity"))
    var state: String = str(game.get("state"))
    if polarity != last_polarity:
        last_polarity = polarity
        var tint := Color(0.64,0.46,1.0) if polarity > 0 else Color(1.0,0.63,0.28)
        if ring_mat != null:
            ring_mat.albedo_color = tint
            ring_mat.emission = tint
        if signal_light != null:
            signal_light.light_color = tint
    if ring != null:
        ring.rotation.z = 0.085 * sin(elapsed*0.55)
        ring.scale = Vector3.ONE * (1.0 + 0.012*sin(elapsed*2.3))
    if signal_light != null:
        signal_light.light_energy = (0.23 if web else 0.43)*(1.0+0.13*sin(elapsed*2.4))
    var opening := 1.0 if state == "flying" or state == "success" else 0.0
    _update_jaws(opening)
