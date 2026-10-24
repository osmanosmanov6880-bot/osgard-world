extends Node
## R12 art-directed lighting presets for WebGL Compatibility.
## Uses one already-existing shadow casting sun and one non-shadow fill.
## Avoids unsupported screen-space GI, costly real-time probes and extra lights.

const LOOK_NAMES = ["РАССВЕТ АВРОРЫ", "ХОЛОДНЫЙ СУМРАК"]

var current_look: int = 0
var key_sun: DirectionalLight3D
var blue_fill: DirectionalLight3D
var world_environment: WorldEnvironment
var sky_shader: ProceduralSkyMaterial
var quality_mode: int = 0

func _ready() -> void:
    key_sun = get_parent().get_node_or_null("OrbitalSun") as DirectionalLight3D
    blue_fill = get_parent().get_node_or_null("DeepBlueFill") as DirectionalLight3D
    world_environment = get_parent().get_node_or_null(
        "R11_CinematicWorldEnvironment") as WorldEnvironment
    if is_instance_valid(world_environment):
        sky_shader = world_environment.environment.sky.sky_material as ProceduralSkyMaterial
    apply_look(0)

func apply_look(look: int) -> void:
    current_look = clampi(look, 0, 1)
    if not is_instance_valid(world_environment) or not is_instance_valid(key_sun):
        return
    var env: Environment = world_environment.environment
    if current_look == 0:
        # Steel-blue ambient with narrow golden edge lighting and controlled
        # specular reflections. Shadows preserve detail instead of crushed blacks.
        key_sun.rotation_degrees = Vector3(-24.0, -64.0, 0.0)
        key_sun.light_color = Color(1.0, 0.81, 0.65)
        key_sun.light_energy = 1.05
        blue_fill.light_color = Color(0.29, 0.43, 0.61)
        blue_fill.light_energy = 0.20
        sky_shader.sky_top_color = Color(0.052, 0.092, 0.14)
        sky_shader.sky_horizon_color = Color(0.34, 0.28, 0.24)
        sky_shader.ground_horizon_color = Color(0.17, 0.19, 0.20)
        env.fog_light_color = Color(0.23, 0.25, 0.28)
        env.fog_density = 0.00030
        env.adjustment_brightness = 0.86
        env.adjustment_contrast = 1.01
        env.adjustment_saturation = 0.88
    else:
        # Warm rim and cooler shadows with clear material separations.
        key_sun.rotation_degrees = Vector3(-21.0, -68.0, 0.0)
        key_sun.light_color = Color(1.00, 0.79, 0.58)
        key_sun.light_energy = 0.92
        blue_fill.light_color = Color(0.29, 0.47, 0.65)
        blue_fill.light_energy = 0.19
        sky_shader.sky_top_color = Color(0.025, 0.044, 0.088)
        sky_shader.sky_horizon_color = Color(0.37, 0.27, 0.22)
        sky_shader.ground_horizon_color = Color(0.20, 0.15, 0.13)
        env.fog_light_color = Color(0.29, 0.21, 0.17)
        env.fog_density = 0.00031
        env.adjustment_brightness = 0.86
        env.adjustment_contrast = 1.00
        env.adjustment_saturation = 0.96
    set_quality(quality_mode)

func set_quality(mode: int) -> void:
    quality_mode = clampi(mode, 0, 2)
    if is_instance_valid(world_environment):
        var env: Environment = world_environment.environment
        env.glow_enabled = quality_mode < 2
        env.glow_bloom = [0.028, 0.014, 0.0][quality_mode]
        env.fog_enabled = true

func toggle_look() -> String:
    apply_look((current_look + 1) % 2)
    return LOOK_NAMES[current_look]
