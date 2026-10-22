extends RefCounted
## OSGARD Wave 5: device-aware cinematic post-processing presets.
## Screen-space effects and volumetric fog only on Forward+ native hardware.

static func supports_ultra() -> bool:
    return RenderingServer.get_current_rendering_method() == "forward_plus" and not OS.has_feature("web")

static func initial_profile() -> String:
    return "ultra" if supports_ultra() else "web"

static func apply(environment: Environment, profile: String) -> void:
    if environment == null:
        return
    var native: bool = supports_ultra()
    var ultra: bool = native and profile == "ultra"
    var balanced: bool = native and profile == "balanced"
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.adjustment_enabled = true
    environment.adjustment_contrast = 1.035 if ultra else 1.015
    environment.adjustment_saturation = 1.06 if ultra else 1.02
    environment.glow_enabled = true
    environment.glow_intensity = 0.27 if ultra else 0.20
    environment.glow_bloom = 0.08 if ultra else 0.05
    environment.fog_enabled = true
    environment.fog_density = 0.0030 if ultra else 0.0020
    environment.ssao_enabled = ultra or balanced
    environment.ssao_radius = 2.1 if ultra else 1.15
    environment.ssao_intensity = 0.78 if ultra else 0.49
    environment.ssil_enabled = ultra
    environment.ssr_enabled = ultra
    environment.volumetric_fog_enabled = ultra
    if ultra:
        environment.volumetric_fog_density = 0.019
        environment.volumetric_fog_albedo = Color(0.68, 0.78, 0.90)
    # Do not enable unsupported Forward+ effects on Compatibility and Web.