extends RefCounted
## W23: bounded real-time art direction for the original industrial Godot scene.
## Physically plausible copper/cyan hierarchy, with no external assets.
## Purely visual. No hardware IO, physics intervention or postprocess bloom.
## Both ECO and HERO use the same three EXISTING lights and material instances.

const PROFILE_ECO = {
    "ambient_color": Color(0.68, 0.72, 0.77),
    "ambient_energy": 1.10,
    "key_color": Color(1.00, 0.94, 0.87),
    "key_energy": 1.55,
    "rim_color": Color(0.62, 0.73, 0.81),
    "rim_energy": 0.70,
    "fill_color": Color(0.96, 0.95, 0.89),
    "fill_energy": 3.80,
    "fill_range": 12.50
}
const PROFILE_HERO = {
    # Warmer copper-facing industrial key and cooler edge separation;
    # maintain optical marker luminance and sufficient camera fill.
    "ambient_color": Color(0.61, 0.69, 0.75),
    "ambient_energy": 1.18,
    "key_color": Color(1.00, 0.88, 0.76),
    "key_energy": 1.90,
    "rim_color": Color(0.54, 0.82, 0.89),
    "rim_energy": 0.98,
    "fill_color": Color(0.97, 0.94, 0.88),
    "fill_energy": 4.20,
    "fill_range": 12.50
}

static func apply(quality: int, environment: Environment,
        key_light: DirectionalLight3D, rim_light: DirectionalLight3D,
        inspection_light: OmniLight3D) -> Dictionary:
    var mode: int = 0 if quality == 0 else 2
    var settings: Dictionary = PROFILE_ECO if mode == 0 else PROFILE_HERO
    if environment == null or key_light == null or rim_light == null or inspection_light == null:
        return {"valid": false, "mode": mode}
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.014, 0.019, 0.025)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = settings["ambient_color"]
    environment.ambient_light_energy = float(settings["ambient_energy"])
    key_light.light_color = settings["key_color"]
    key_light.light_energy = float(settings["key_energy"])
    rim_light.light_color = settings["rim_color"]
    rim_light.light_energy = float(settings["rim_energy"])
    inspection_light.light_color = settings["fill_color"]
    inspection_light.light_energy = float(settings["fill_energy"])
    inspection_light.omni_range = float(settings["fill_range"])
    inspection_light.omni_attenuation = 0.65
    # No extra shadow casters and no unsupported Godot WebGL SSR / bloom.
    # Preserve the existing W11 design of a shadow-free inspection lamp.
    key_light.shadow_enabled = false
    rim_light.shadow_enabled = false
    inspection_light.shadow_enabled = false
    return snapshot(mode, environment, key_light, rim_light, inspection_light)


static func snapshot(mode: int, environment: Environment,
        key_light: DirectionalLight3D, rim_light: DirectionalLight3D,
        inspection_light: OmniLight3D) -> Dictionary:
    if environment == null or key_light == null or rim_light == null or inspection_light == null:
        return {"valid": false, "mode": mode}
    return {
        "valid": true,
        "mode": 0 if mode == 0 else 2,
        "profile": "ECO" if mode == 0 else "HERO",
        "ambient_energy": environment.ambient_light_energy,
        "key_energy": key_light.light_energy,
        "rim_energy": rim_light.light_energy,
        "fill_energy": inspection_light.light_energy,
        "fill_shadow_enabled": inspection_light.shadow_enabled,
        "key_shadow_enabled": key_light.shadow_enabled,
        "rim_shadow_enabled": rim_light.shadow_enabled,
        "physical_telemetry": false,
        "gpu_bloom_or_ssr_enabled": false
    }
