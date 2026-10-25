extends RefCounted
## HORIZON R18: WebGL-friendly cinematic daylight and atmospheric grading.
## Avoids expensive postprocess bloom/volumetric fog and never modifies
## input, physics, game saves, or mission rewards.
const CLEAR_SKY_TOP = Color("6586a5")
const CLEAR_HORIZON = Color("b8a79a")
const RAIN_SKY_TOP = Color("506c87")
const RAIN_HORIZON = Color("899aa5")
const STORM_SKY_TOP = Color("344557")
const STORM_HORIZON = Color("758694")

static func sky_top(kind: String) -> Color:
	if kind == "storm": return STORM_SKY_TOP
	if kind == "rain" or kind == "cloudy": return RAIN_SKY_TOP
	return CLEAR_SKY_TOP

static func sky_horizon(kind: String) -> Color:
	if kind == "storm": return STORM_HORIZON
	if kind == "rain" or kind == "cloudy": return RAIN_HORIZON
	return CLEAR_HORIZON

static func fog_density(kind: String, tier: String) -> float:
	if tier == "low": return 0.0
	if kind == "storm": return 0.0030
	if kind == "rain" or kind == "cloudy": return 0.0014
	return 0.00055

static func sun_multiplier(kind: String) -> float:
	if kind == "storm": return 0.57
	if kind == "rain" or kind == "cloudy": return 0.78
	return 1.0

static func apply_to(env: Environment, sun: DirectionalLight3D, sky: ProceduralSkyMaterial,
		kind: String, tier: String, brightness: float) -> void:
	if env == null or sun == null or sky == null: return
	# Keep highlights warm; sky/horizon stay neutral. Reduces flat, overbright
	# ambient light without introducing an expensive screen-space pass.
	var safe_brightness: float = clampf(brightness if is_finite(brightness) else 1.0,0.6,1.25)
	var valid_kind: String = kind if ["clear","rain","cloudy","storm"].has(kind) else "clear"
	sky.sky_top_color = sky_top(valid_kind)
	sky.sky_horizon_color = sky_horizon(valid_kind)
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.97
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.97
	env.ambient_light_energy = clampf(0.62+0.28*safe_brightness,0.62,0.98)
	env.fog_enabled = tier != "low"
	env.fog_density = fog_density(valid_kind,tier)
	env.fog_light_color = Color("758b98") if valid_kind == "storm" else Color("a5b5bd")
	sun.light_color = Color("e2e8ea") if valid_kind == "storm" else (Color("edf0ec") if valid_kind == "rain" or valid_kind == "cloudy" else Color("ffe1bb"))
	sun.light_energy = clampf(safe_brightness*1.02*sun_multiplier(valid_kind),0.30,1.10)


# R44.1: actual clock-driven night sky, ambient and sun, never a CSS/filter
# overlay. Lower energy lets the existing four warm OmniLight3D nodes provide
# local visible illumination; daylight remains unchanged.
static func night_fraction(hour: float) -> float:
	if not is_finite(hour):
		return 0.0
	var local_hour: float = fposmod(hour,24.0)
	if local_hour>=20.0 or local_hour<5.5:
		return 1.0
	if local_hour>=18.0:
		return clampf((local_hour-18.0)/2.0,0.0,1.0)
	if local_hour<7.5:
		return clampf((7.5-local_hour)/2.0,0.0,1.0)
	return 0.0

static func apply_night_overlay(env: Environment, sun: DirectionalLight3D,
		sky: ProceduralSkyMaterial, hour: float) -> void:
	if env==null or sun==null or sky==null:
		return
	var amount: float = night_fraction(hour)
	if amount<=0.0:
		return
	# No full-screen postprocess, HDR glow, fake static background or shadows.
	# Ambient 0.20 at 22:00 is deliberately not zero: silhouettes stay visible.
	sun.light_energy = lerpf(sun.light_energy,0.018,amount)
	env.ambient_light_energy = lerpf(env.ambient_light_energy,0.20,amount)
	env.adjustment_brightness = lerpf(env.adjustment_brightness,0.86,amount)
	env.adjustment_saturation = lerpf(env.adjustment_saturation,0.91,amount)
	sky.sky_top_color = sky.sky_top_color.lerp(Color("0b182a"),amount)
	sky.sky_horizon_color = sky.sky_horizon_color.lerp(Color("1e3045"),amount)
	sky.ground_bottom_color = sky.ground_bottom_color.lerp(Color("101923"),amount)
	sky.ground_horizon_color = sky.ground_horizon_color.lerp(Color("253344"),amount)
	env.fog_light_color = env.fog_light_color.lerp(Color("273749"),amount)
