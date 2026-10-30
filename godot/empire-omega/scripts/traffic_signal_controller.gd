extends Node3D
## Simplified coordinated traffic signal network, governing ambient NPC cars.
## Signals are deterministic; real lane-aware driving AI is a later milestone.
const INTERSECTIONS = [-156.0, -52.0, 52.0, 156.0]
const CYCLE_SECONDS = 24.0
const CHANGE_SECONDS = 12.0
const SIGNAL_REACH = 9.0
const CINEMATIC_ART = preload("res://scripts/city_reign_signal_art.gd")
const R178_STOP_BARS = preload("res://scripts/city_reign_intersection_stopbars.gd")
const R180_WALK_ART = preload("res://scripts/city_reign_pedestrian_signal_art.gd")
const R180_WALK_RULE = preload("res://scripts/city_reign_pedestrian_right_of_way.gd")
const R182_ZEBRA_ART = preload("res://scripts/city_reign_real_zebra_crossings.gd")
const AMBER_SECONDS: float = 1.5

var elapsed := 0.0
var lights: Array[Dictionary] = []
var last_phase := -1
var last_visual_state := -1
var legacy_signal_roots: Array[Node3D] = []
var cinematic_art: Node3D
var stop_bars: Node3D
var pedestrian_signs: Node3D
var real_zebra_crossings: Node3D
var quality: String = "standard"

func _ready() -> void:
	name = "TrafficSignalGrid"
	for x in INTERSECTIONS:
		for z in INTERSECTIONS:
			var junction := Node3D.new()
			junction.name = "Signal_%d_%d" % [int(x),int(z)]
			junction.position = Vector3(x + 7.5,0.0,z + 7.5)
			add_child(junction)
			legacy_signal_roots.append(junction)
			_add_mesh(junction,Vector3(0.25,3.7,0.25),Vector3(0,1.9,0),Color("687784"))
			_add_mesh(junction,Vector3(0.78,1.3,0.58),Vector3(0,3.9,0),Color("12222c"))
			var green: MeshInstance3D = _add_mesh(junction,Vector3(0.38,0.3,0.16),Vector3(0,3.6,-0.36),Color("2a7e68"))
			var red: MeshInstance3D = _add_mesh(junction,Vector3(0.38,0.3,0.16),Vector3(0,4.2,-0.36),Color("822b36"))
			lights.append({"green":green,"red":red})
	# Source-authored directional 3D sign body/three-lens appearance,
	# in nine shared GPU batches rather than 16x2 individually drawn LEDs.
	# All 16 original intersections, collision-free junction positions and
	# AI timers are unchanged; the original box art stays as LOW fallback.
	cinematic_art = CINEMATIC_ART.new()
	add_child(cinematic_art)
	stop_bars=R178_STOP_BARS.new()
	add_child(stop_bars)
	# Two original direction-specific walk/wait heads at every REAL
	# road intersection, no separate timer or pedestrian collision geometry.
	pedestrian_signs=R180_WALK_ART.new()
	add_child(pedestrian_signs)
	# R182: 384 native real road zebra strips from the exact same
	# 16 intersections, two shared GPU batches, no new traffic clock.
	real_zebra_crossings=R182_ZEBRA_ART.new()
	add_child(real_zebra_crossings)
	set_quality("standard")
	_update_lights()

func _add_mesh(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	material.metallic = 0.12
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _phase() -> int:
	return int(floor(fposmod(elapsed,CYCLE_SECONDS) / CHANGE_SECONDS))

func _warning() -> bool:
	return fposmod(elapsed,CHANGE_SECONDS)>=CHANGE_SECONDS-AMBER_SECONDS

func _visual_state() -> int:
	return _phase()*2+(1 if _warning() else 0)

func _process(delta: float) -> void:
	if not is_finite(delta) or delta<=0.0:
		return
	elapsed += delta
	if _visual_state() != last_visual_state:
		_update_lights()
	elif pedestrian_signs!=null and not bool(
			pedestrian_signs.call("matches_source",elapsed)):
		# Vehicle GREEN is not automatically WALK: once insufficient
		# crossing time remains the actual physical head must show WAIT.
		var source: Node=get_node_or_null("/root/GameState")
		var state: Dictionary=source.get("data") if source!=null else {}
		sync_city_power(state)

func _update_lights() -> void:
	last_phase = _phase()
	last_visual_state = _visual_state()
	# The original driver's permission is X on phase0, Z on phase1.
	# This one LOW-mode old face points toward -Z. Previously phase0
	# appeared green here even though Z vehicles were braking on RED.
	# Rendering now follows the exact authoritative original direction.
	for record in lights:
		var green: MeshInstance3D = record["green"]
		var red: MeshInstance3D = record["red"]
		var green_mat: StandardMaterial3D = green.material_override as StandardMaterial3D
		var red_mat: StandardMaterial3D = red.material_override as StandardMaterial3D
		green_mat.albedo_color = (Color("d5a044") if _warning() else Color("30dfb4")) if last_phase == 1 else Color("174e42")
		red_mat.albedo_color = Color("802c34") if last_phase == 1 else Color("ff5965")
	if cinematic_art != null:
		cinematic_art.call("sync_phase",last_phase,_warning())
	var game: Node=get_node_or_null("/root/GameState")
	var current: Dictionary=game.get("data") if game!=null else {}
	sync_city_power(current)

func set_quality(tier: String) -> void:
	quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	var use_source_art: bool = quality!="low"
	for original in legacy_signal_roots:
		original.visible = not use_source_art
	if cinematic_art!=null:
		cinematic_art.call("set_quality",quality)
	if stop_bars!=null:
		stop_bars.call("set_quality",quality)
	if pedestrian_signs!=null:
		pedestrian_signs.call("set_quality",quality)
	if real_zebra_crossings!=null:
		real_zebra_crossings.call("set_quality",quality)

func sync_city_power(state: Dictionary) -> void:
	if stop_bars!=null:
		stop_bars.call("sync_phase",elapsed,int(state.get("energy",100)),
			float(state.get("day_clock",12.0)))
	if pedestrian_signs!=null:
		pedestrian_signs.call("sync_phase",elapsed,int(state.get("energy",100)),
			float(state.get("day_clock",12.0)))
	if real_zebra_crossings!=null:
		real_zebra_crossings.call("sync_world",int(state.get("energy",100)),
			float(state.get("day_clock",12.0)))

func visual_state_is_consistent() -> bool:
	if cinematic_art==null or lights.size()!=16 or legacy_signal_roots.size()!=16:
		return false
	if not cinematic_art.call("geometry_is_bounded"):
		return false
	var indicators: Dictionary = cinematic_art.get("lamp_state")
	var x_go: bool = _phase()==0
	var yellow: bool = _warning()
	return (stop_bars!=null and pedestrian_signs!=null and
		real_zebra_crossings!=null and
		bool(real_zebra_crossings.call("source_geometry_valid")) and
		bool(pedestrian_signs.call("batches_are_bounded")) and
		bool(pedestrian_signs.call("matches_source",elapsed)) and
		bool(stop_bars.call("source_budget_ok")) and
		bool(stop_bars.call("phases_match",elapsed)) and
		bool(indicators.get("x_red",true))==not x_go and
		bool(indicators.get("z_red",true))==x_go and
		bool(indicators.get("x_amber",false))==(x_go and yellow) and
		bool(indicators.get("z_amber",false))==((not x_go) and yellow) and
		bool(indicators.get("x_green",false))==(x_go and not yellow) and
		bool(indicators.get("z_green",false))==((not x_go) and not yellow))

func permitted(waypoint: Vector3, direction: Vector3) -> bool:
	var closest: float = INF
	for x in INTERSECTIONS:
		for z in INTERSECTIONS:
			closest = minf(closest,Vector2(waypoint.x-x,waypoint.z-z).length())
	if closest > SIGNAL_REACH:
		return true
	if absf(direction.x) + absf(direction.z) < 0.001:
		return true
	var along_z: bool = absf(direction.z) > absf(direction.x)
	# Amber is a real caution/stop phase, not an unconditional green pass.
	if _warning(): return false
	return along_z if _phase() == 1 else not along_z
