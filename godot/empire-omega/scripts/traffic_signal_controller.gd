extends Node3D
## Simplified coordinated traffic signal network, governing ambient NPC cars.
## Signals are deterministic; real lane-aware driving AI is a later milestone.
const INTERSECTIONS = [-156.0, -52.0, 52.0, 156.0]
const CYCLE_SECONDS = 24.0
const CHANGE_SECONDS = 12.0
const SIGNAL_REACH = 9.0
const CINEMATIC_ART = preload("res://scripts/city_reign_signal_art.gd")
const AMBER_SECONDS: float = 1.5

var elapsed := 0.0
var lights: Array[Dictionary] = []
var last_phase := -1
var last_visual_state := -1
var legacy_signal_roots: Array[Node3D] = []
var cinematic_art: Node3D
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
		green_mat.albedo_color = Color("30dfb4") if last_phase == 1 else Color("174e42")
		red_mat.albedo_color = Color("802c34") if last_phase == 1 else Color("ff5965")
	if cinematic_art != null:
		cinematic_art.call("sync_phase",last_phase,_warning())

func set_quality(tier: String) -> void:
	quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	var use_source_art: bool = quality!="low"
	for original in legacy_signal_roots:
		original.visible = not use_source_art
	if cinematic_art!=null:
		cinematic_art.call("set_quality",quality)

func visual_state_is_consistent() -> bool:
	if cinematic_art==null or lights.size()!=16 or legacy_signal_roots.size()!=16:
		return false
	if not cinematic_art.call("geometry_is_bounded"):
		return false
	var indicators: Dictionary = cinematic_art.get("lamp_state")
	var x_go: bool = _phase()==0
	var yellow: bool = _warning()
	return (bool(indicators.get("x_red",true))==not x_go and
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
	return along_z if _phase() == 1 else not along_z
