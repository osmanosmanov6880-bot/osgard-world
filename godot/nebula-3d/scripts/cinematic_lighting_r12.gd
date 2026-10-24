extends Node
## R12 art-directed lighting presets for WebGL Compatibility.
## Uses one already-existing shadow casting sun and one non-shadow fill.
## Avoids unsupported screen-space GI, costly real-time probes and extra lights.

const LOOK_NAMES = ["АВРОРА · ЗОЛОТОЙ ЧАС", "АВРОРА · СИНИЙ ЧАС"]

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
        key_sun.rotation_degrees = Vector3(-24.0, -70.0, 0.0)
        key_sun.light_color = Color(1.0, 0.88, 0.71)
        key_sun.light_energy = 1.48
        blue_fill.light_color = Color(0.48, 0.66, 0.90)
        blue_fill.light_energy = 0.41
        sky_shader.sky_top_color = Color(0.048, 0.12, 0.26)
        sky_shader.sky_horizon_color = Color(0.68, 0.51, 0.43)
        sky_shader.ground_horizon_color = Color(0.27, 0.29, 0.36)
        env.fog_light_color = Color(0.36, 0.37, 0.42)
        env.fog_density = 0.00031
        env.adjustment_brightness = 0.94
        env.adjustment_contrast = 1.10
        env.adjustment_saturation = 0.95
    else:
        # Warm rim and cooler shadows with clear material separations.
        key_sun.rotation_degrees = Vector3(-25.0, -81.0, 0.0)
        key_sun.light_color = Color(0.79, 0.86, 1.00)
        key_sun.light_energy = 0.92
        blue_fill.light_color = Color(0.39, 0.53, 0.76)
        blue_fill.light_energy = 0.19
        sky_shader.sky_top_color = Color(0.035, 0.075, 0.15)
        sky_shader.sky_horizon_color = Color(0.32, 0.25, 0.31)
        sky_shader.ground_horizon_color = Color(0.23, 0.21, 0.28)
        env.fog_light_color = Color(0.31, 0.29, 0.38)
        env.fog_density = 0.00031
        env.adjustment_brightness = 0.86
        env.adjustment_contrast = 1.06
        env.adjustment_saturation = 1.00
    set_quality(quality_mode)

func set_quality(mode: int) -> void:
    quality_mode = clampi(mode, 0, 2)
    if is_instance_valid(world_environment):
        var env: Environment = world_environment.environment
        env.glow_enabled = quality_mode < 2
        env.glow_bloom = [0.018, 0.009, 0.0][quality_mode]
        env.fog_enabled = true

func toggle_look() -> String:
    apply_look((current_look + 1) % 2)
    return LOOK_NAMES[current_look]
