extends Node3D
## CITY REIGN R189 — real original NPC headlamps illuminate physical
## streets at night with native SpotLight3D, NOT fake yellow textures.
## SIX strictly pooled, real, unshadowed light sources follow at most
## 3 NEAREST of the 12 original collision-capable cars, plus the
## player's two EXISTING R33 headlights (unchanged). No 24 lights,
## no per-vehicle lights, no uploaded art, no physics/AI/save mutation.
const ORIGINAL_CARS: int=12
const MAX_PAIRS: int=3
const BEAMS_PER_PAIR: int=2
const MAX_NATIVE_BEAMS: int=6
const MAX_WORLD_LIGHTS_WITH_PLAYER: int=8
const RESELECT_INTERVAL_S: float=0.60
const MAX_SOURCE_DISTANCE_STANDARD_M: float=58.0
const MAX_SOURCE_DISTANCE_CINEMATIC_M: float=78.0
const SOURCE_BEAM_LOCAL_X_M: float=0.77
const SOURCE_BEAM_LOCAL_Y_M: float=0.42
const SOURCE_BEAM_LOCAL_Z_M: float=-2.05
const SOURCE_BEAM_DOWN_ANGLE_RAD: float=-0.075
const DARK_START_H: float=18.75
const DARK_END_H: float=6.75
var candidates: Array=[]
var selected: Array=[]
var beams: Array[SpotLight3D]=[]
var current_quality: String="standard"
var night_active: bool=false
var active_physical_pairs: int=0
var reselect_elapsed: float=RESELECT_INTERVAL_S
var selection_changes: int=0
var real_sync_frames: int=0
var recent_weather: String="clear"

func _ready() -> void:
	name="R189OriginalLiveNPCHeadlightPool"
	for pair_index in range(MAX_PAIRS):
		for side in [-1.0,1.0]:
			var beam:=SpotLight3D.new()
			beam.name="R189RealNPCBeam_%d_%s" % [
				pair_index,"Left" if side<0.0 else "Right"]
			beam.spot_angle=46.0
			beam.spot_range=18.0
			beam.spot_attenuation=1.25
			beam.light_color=Color("fff0cd")
			beam.light_energy=0.85
			beam.shadow_enabled=false
			beam.visible=false
			add_child(beam)
			beams.append(beam)

func set_sources(vehicles: Array) -> void:
	candidates.clear()
	for index in range(mini(ORIGINAL_CARS,vehicles.size())):
		var value: Variant=vehicles[index]
		if value is Node3D and is_instance_valid(value):
			candidates.append(value)
	selected.clear()
	reselect_elapsed=RESELECT_INTERVAL_S
	_hide_all()

func _hide_all() -> void:
	active_physical_pairs=0
	for beam in beams:
		beam.visible=false

static func is_actual_night(hour: float) -> bool:
	if not is_finite(hour):return false
	var h: float=fposmod(hour,24.0)
	return h>=DARK_START_H or h<DARK_END_H

static func source_budget_for(quality: String) -> int:
	if quality=="cinematic":return MAX_PAIRS
	if quality=="standard":return 1
	return 0

func _choose_nearest(focus: Vector3,tier: String) -> void:
	selected.clear()
	var used: Dictionary={}
	var limit: float=MAX_SOURCE_DISTANCE_STANDARD_M if tier=="standard" else MAX_SOURCE_DISTANCE_CINEMATIC_M
	for slot in range(source_budget_for(tier)):
		var closest: float=limit*limit
		var best: int=-1
		# Bounded 12*3 O(36) scan only once every 0.6 seconds,
		# stable tie ordering by original immutable native array index.
		for index in range(mini(ORIGINAL_CARS,candidates.size())):
			if used.has(index):continue
			var body: Node3D=candidates[index] as Node3D
			if (not is_instance_valid(body) or not body.visible or
					not body.global_position.is_finite()):
				continue
			var squared: float=focus.distance_squared_to(body.global_position)
			if squared<closest:
				closest=squared
				best=index
		if best<0:break
		used[best]=true
		selected.append(candidates[best])
	selection_changes+=1

func sync_real_city(camera_focus: Vector3,clock: float,
		tier: String,weather: String,delta: float) -> void:
	if (not camera_focus.is_finite() or not is_finite(clock) or
			not is_finite(delta) or delta<0.0):
		_hide_all()
		return
	var quality: String=tier if ["low","standard","cinematic"].has(tier) else "low"
	var dark: bool=is_actual_night(clock)
	recent_weather=weather if ["clear","rain","storm","snow"].has(weather) else "clear"
	var changed: bool=(quality!=current_quality or dark!=night_active)
	current_quality=quality
	night_active=dark
	if not dark or source_budget_for(quality)==0:
		selected.clear()
		_hide_all()
		return
	# Count authentic foreground elapsed time up to ONE selection period.
	# A long valid render frame may delay but never trigger multiple
	# reselect scans or allocate additional native light nodes.
	reselect_elapsed+=clampf(delta,0.0,RESELECT_INTERVAL_S)
	if changed or reselect_elapsed>=RESELECT_INTERVAL_S or selected.is_empty():
		_choose_nearest(camera_focus,quality)
		reselect_elapsed=0.0
	active_physical_pairs=mini(source_budget_for(quality),selected.size())
	var moisture: bool=recent_weather=="rain" or recent_weather=="storm"
	var strength: float=0.58 if quality=="standard" else 1.05
	var range_m: float=15.0 if quality=="standard" else 21.0
	if moisture:strength*=1.12
	for slot in range(MAX_PAIRS):
		var has_car: bool=slot<active_physical_pairs
		var car: Node3D=selected[slot] as Node3D if has_car else null
		if has_car and (not is_instance_valid(car) or not car.visible):
			has_car=false
		for lamp in range(BEAMS_PER_PAIR):
			var beam: SpotLight3D=beams[slot*BEAMS_PER_PAIR+lamp]
			beam.visible=has_car
			if not has_car:continue
			var side: float=-1.0 if lamp==0 else 1.0
			# Godot native vehicle forward is its true local -Z;
			# world-space SpotLight3D pose is attached without adding
			# ANY light nodes to each of the 12 original vehicles.
			var local_pose:=Transform3D(
				Basis(Vector3.RIGHT,SOURCE_BEAM_DOWN_ANGLE_RAD),
				Vector3(side*SOURCE_BEAM_LOCAL_X_M,
					SOURCE_BEAM_LOCAL_Y_M,SOURCE_BEAM_LOCAL_Z_M))
			beam.global_transform=car.global_transform*local_pose
			beam.light_energy=strength
			beam.spot_range=range_m
	real_sync_frames+=1

func source_integrity() -> bool:
	if beams.size()!=MAX_NATIVE_BEAMS or get_child_count()!=MAX_NATIVE_BEAMS:
		return false
	if (active_physical_pairs<0 or active_physical_pairs>MAX_PAIRS or
		MAX_NATIVE_BEAMS+2!=MAX_WORLD_LIGHTS_WITH_PLAYER or
		ORIGINAL_CARS!=12 or source_budget_for("low")!=0):
		return false
	for b in beams:
		if (b==null or not is_instance_valid(b) or b.shadow_enabled or
			b.spot_range>22.0 or b.get_child_count()!=0):
			return false
	return find_children("*","CollisionShape3D",true,false).is_empty()
