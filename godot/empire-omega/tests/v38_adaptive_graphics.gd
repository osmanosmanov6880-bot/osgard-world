extends SceneTree
## HORIZON R15 native regression: mobile governor and GL road materials.
const GOVERNOR = preload("res://scripts/horizon_adaptive_graphics.gd")
const MATERIALS = preload("res://scripts/horizon_road_materials.gd")
var count := 0
var failures := 0

func verify(condition: bool, message: String) -> void:
	count += 1
	if not condition:
		failures += 1
		push_error("R15 FAILED: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var governor = GOVERNOR.new()
	governor.configure("cinematic",true)
	verify(governor.effective_quality() == "cinematic","player ceiling preserved")
	for i in range(6):
		verify(not governor.observe(12.0,1.0),"warmup never reduces detail")
	for i in range(3):
		verify(not governor.observe(20.0,1.0),"hysteresis prevents transient downgrade")
	verify(governor.observe(20.0,1.0),"sustained FPS loss reduces one tier")
	verify(governor.effective_quality() == "standard","governor reduces one tier, not all tiers")
	for i in range(4):
		governor.observe(20.0,1.0)
	verify(governor.effective_quality() == "low","prolonged low FPS reaches safe lower tier")
	verify(governor.is_adapting(),"diagnostics identify real adaptation")
	verify(not governor.observe(120.0,0.0),"zero-time samples are ignored")
	verify(not governor.observe(NAN,1.0),"invalid frame samples are rejected")
	verify(not governor.observe(120.0,30.0),"long tab-resume samples are capped")
	for i in range(10):
		governor.observe(60.0,1.0)
	verify(governor.effective_quality() == "standard","sustained recovery restores one tier")
	for i in range(12):
		governor.observe(60.0,1.0)
	verify(governor.effective_quality() == "cinematic","recovery respects user's ceiling")
	governor.configure("standard",false)
	for i in range(40):
		governor.observe(10.0,1.0)
	verify(governor.effective_quality() == "standard","desktop quality never adapts")
	governor.configure("low",true)
	for i in range(40):
		governor.observe(10.0,1.0)
	verify(governor.effective_quality() == "low","low preset is always respected")
	governor.configure("invalid",true)
	verify(governor.effective_quality() == "standard","invalid setting is safe")
	governor.configure("cinematic",true)
	for i in range(10):
		governor.observe(10.0,1.0,false)
	verify(governor.effective_quality() == "cinematic","background tab never degrades quality")
	var asphalt: StandardMaterial3D = MATERIALS.asphalt()
	var concrete: StandardMaterial3D = MATERIALS.concrete()
	verify(asphalt.normal_enabled and asphalt.normal_texture != null,"PBR road texture retained")
	MATERIALS.apply_weather(asphalt,"rain")
	MATERIALS.apply_weather(concrete,"storm")
	verify(asphalt.roughness < 0.50,"wet road becomes less rough")
	verify(concrete.roughness < 0.55,"wet pavement becomes less rough")
	MATERIALS.apply_weather(asphalt,"clear")
	MATERIALS.apply_weather(concrete,"clear")
	verify(is_equal_approx(asphalt.roughness,0.81),"dry asphalt restores original roughness")
	verify(is_equal_approx(concrete.roughness,0.90),"dry pavement restores original roughness")
	# Load the world after SceneTree autoloads GameState. A top-level preload
	# executes before named autoload symbols are registered in --script mode.
	var game_state: Node = root.get_node_or_null("GameState")
	verify(game_state != null,"actual GameState autoload is ready")
	var world_script: Variant = load("res://scripts/world_builder.gd")
	verify(world_script != null,"real city world script parses after autoload")
	if world_script == null or game_state == null:
		print("HORIZON R15 NATIVE: %d passed, %d failed" % [count-failures,failures])
		quit(1)
		return
	var world: Node3D = world_script.new()
	root.add_child(world)
	world.apply_visual_budget("low")
	verify(world.visual_budget == "low","world accepts low quality")
	verify(world.horizon_scenic != null and not world.horizon_scenic.visible,"only decorative backdrop is hidden at low quality")
	verify(world.weather_particles != null and world.weather_particles.amount_ratio <= 0.26,"rain budget reduces particles")
	world.apply_visual_budget("cinematic")
	verify(world.horizon_scenic.visible and world.weather_particles.amount_ratio >= 0.99,"manual cinematic mode restores visuals")
	world.update_weather("rain")
	verify(world.asphalt_pbr.roughness < 0.50,"real game weather modifies actual asphalt")
	world.update_weather("clear")
	verify(is_equal_approx(world.asphalt_pbr.roughness,0.81),"weather reset restores road")
	world.queue_free()
	print("HORIZON R15 NATIVE: %d passed, %d failed" % [count-failures,failures])
	quit(0 if failures == 0 else 1)
