extends RefCounted
## CITY REIGN R168 / ATMOSPHERIC OPTICS.
## The real Godot GL Compatibility environment stays source-rendered:
## no SSR, post-processing impostors, new lights, cubemap downloads or physics.
const LIGHT_GRADE = preload("res://scripts/horizon_light_grade.gd")
const WEATHER_WET = ["rain","storm"]

static func hour_safe(hour: float) -> float:
	return fposmod(hour,24.0) if is_finite(hour) else 12.0

static func solar_fraction(hour: float) -> float:
	var h: float = hour_safe(hour)
	if h <= 5.75 or h >= 18.25:
		return 0.0
	var journey: float = (h-5.75)/12.5
	return maxf(0.0,sin(PI*journey))

static func daylight_brightness(hour: float) -> float:
	# Low illumination at sunset is resolved separately by the existing
	# measured R44 night exposure; daylight never owns mission physics.
	return clampf(0.72+0.40*solar_fraction(hour),0.72,1.12)

static func sun_orientation(hour: float) -> Vector3:
	var h: float = hour_safe(hour)
	var progress: float = clampf((h-5.75)/12.5,0.0,1.0)
	# Real DirectionalLight3D solar movement: horizontal azimuth changes
	# with clock time, not just the intensity of a fixed noon key light.
	return Vector3(-lerpf(9.0,56.0,solar_fraction(h)),
		lerpf(-119.0,47.0,progress),0.0)

static func twilight_fraction(hour: float) -> float:
	var h: float = hour_safe(hour)
	var dawn: float = clampf(1.0-absf(h-6.7)/2.0,0.0,1.0)
	var dusk: float = clampf(1.0-absf(h-18.0)/2.0,0.0,1.0)
	return maxf(dawn,dusk)*(1.0-LIGHT_GRADE.night_fraction(h)*0.72)

static func apply_sky(env: Environment,sun: DirectionalLight3D,
		sky: ProceduralSkyMaterial,hour: float,weather: String,tier: String) -> void:
	if env == null or sun == null or sky == null:
		return
	var h: float = hour_safe(hour)
	sun.rotation_degrees = sun_orientation(h)
	var twilight: float = twilight_fraction(h)
	if weather == "storm" or weather == "rain":
		twilight *= 0.36
	# RGB spectral direction on the same physically lit sky and sun. Existing
	# R44 night attenuation remains authoritative, never reset here.
	sun.light_color = sun.light_color.lerp(Color("ffd19c"),0.40*twilight)
	sky.sky_horizon_color = sky.sky_horizon_color.lerp(Color("d28b76"),0.34*twilight)
	env.fog_light_color = env.fog_light_color.lerp(Color("bc8a72"),0.24*twilight)
	# GL Compatibility already uses the existing procedural BG/SKY as its
	# environment reflection source. Never enable unsupported screen SSR.
	if env.reflected_light_source != Environment.REFLECTION_SOURCE_BG:
		env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	# No tier-specific extra radiance probe or shadow map is created.
	if tier == "low":
		env.fog_enabled = false

static func apply_road_finish(material: StandardMaterial3D,
		kind: String,tier: String) -> void:
	if material == null:
		return
	var wet: bool = WEATHER_WET.has(kind)
	var enabled: bool = wet and tier != "low"
	# Preserve R15 real dry/wet base roughness, normal textures, UV identity
	# and original shared road draw calls. This is genuine PBR clearcoat:
	# highlights reflect existing environment, NOT objects via screen SSR.
	if material.clearcoat_enabled != enabled:
		material.clearcoat_enabled = enabled
	if enabled:
		var asphalt: bool = material.resource_name == "HORIZON_ROAD_ASPHALT"
		var layer: float = 0.62 if asphalt else 0.42
		var micro_roughness: float = 0.15 if kind == "storm" else 0.21
		if not is_equal_approx(material.clearcoat,layer):
			material.clearcoat = layer
		if not is_equal_approx(material.clearcoat_roughness,micro_roughness):
			material.clearcoat_roughness = micro_roughness

static func puddle_tint(hour: float) -> Color:
	var night: float = LIGHT_GRADE.night_fraction(hour_safe(hour))
	var dusk: float = twilight_fraction(hour)
	# A shared 72-instance transparent surface changes light response;
	# these are NOT real reflected buildings or ray-traced water.
	return Color(clampf(lerpf(0.94,0.55,night)+0.025*dusk,0.0,1.0),
		clampf(lerpf(0.97,0.68,night)+0.011*dusk,0.0,1.0),
		clampf(lerpf(0.99,0.86,night),0.0,1.0),1.0)

static func headlamp_energy(hour: float,tier: String) -> float:
	if tier == "low":
		return 0.42
	var darkness: float = LIGHT_GRADE.night_fraction(hour_safe(hour))
	return lerpf(0.46,2.25 if tier == "cinematic" else 1.36,darkness)
