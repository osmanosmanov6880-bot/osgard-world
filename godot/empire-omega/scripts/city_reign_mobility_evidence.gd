extends RefCounted
## CITY REIGN R183: explicit opt-in 20s LOCAL-only aggregate of the
## ORIGINAL 12 traffic cars, 34 residents and one signal clock.
## 2Hz bounded sampling shares existing R36 real-frame benchmark. No
## positions, player IDs, device IDs, screenshots or raw traces are stored.
const REAL_SIGNAL=preload("res://scripts/city_reign_intersection_policy.gd")
const WARMUP_SECONDS: float=2.0
const CAPTURE_SECONDS: float=20.0
const SAMPLE_INTERVAL_SECONDS: float=0.5
const MAX_SNAPSHOTS: int=48
const EXPECTED_VEHICLES: int=12
const EXPECTED_WALKERS: int=34
var active: bool=false
var complete: bool=false
var aborted_reason: String=""
var elapsed: float=0.0
var pending_seconds: float=0.0
var captured_seconds: float=0.0
var snapshots: int=0
var ignored_invalid_frames: int=0
var ignored_blocked_frames: int=0
var invalid_entities: int=0
var car_population_low: int=9999
var car_population_high: int=0
var walker_population_low: int=9999
var walker_population_high: int=0
var total_car_snapshots: int=0
var stopped_car_snapshots: int=0
var car_crosswalk_yield_snapshots: int=0
var walker_wait_snapshots: int=0
var walker_walking_snapshots: int=0
var highest_original_car_stop_seconds: float=0.0
var highest_original_walker_wait_seconds: float=0.0
var x_green_snapshots: int=0
var z_green_snapshots: int=0
var x_amber_snapshots: int=0
var z_amber_snapshots: int=0

func begin() -> void:
	active=true
	complete=false
	aborted_reason=""
	elapsed=0.0
	pending_seconds=0.0
	captured_seconds=0.0
	snapshots=0
	ignored_invalid_frames=0
	ignored_blocked_frames=0
	invalid_entities=0
	car_population_low=9999
	car_population_high=0
	walker_population_low=9999
	walker_population_high=0
	total_car_snapshots=0
	stopped_car_snapshots=0
	car_crosswalk_yield_snapshots=0
	walker_wait_snapshots=0
	walker_walking_snapshots=0
	highest_original_car_stop_seconds=0.0
	highest_original_walker_wait_seconds=0.0
	x_green_snapshots=0
	z_green_snapshots=0
	x_amber_snapshots=0
	z_amber_snapshots=0

func observe(delta: float,cars: Array,residents: Array,
		signal_clock: float,unblocked: bool,foreground: bool) -> void:
	if not active:return
	if not foreground:
		active=false
		complete=false
		aborted_reason="browser-backgrounded"
		return
	if not unblocked:
		ignored_blocked_frames+=1
		return
	if (not is_finite(delta) or delta<=0.0 or delta>1.0 or
			not is_finite(signal_clock)):
		ignored_invalid_frames+=1
		return
	elapsed+=delta
	if elapsed<=WARMUP_SECONDS:return
	pending_seconds+=delta
	while pending_seconds>=SAMPLE_INTERVAL_SECONDS and active:
		pending_seconds-=SAMPLE_INTERVAL_SECONDS
		if snapshots>=MAX_SNAPSHOTS:
			active=false
			aborted_reason="sample-capacity-exceeded"
			return
		_sample_existing_agents(cars,residents,signal_clock)
		snapshots+=1
		captured_seconds+=SAMPLE_INTERVAL_SECONDS
		if captured_seconds>=CAPTURE_SECONDS:
			active=false
			complete=snapshots>=20 and invalid_entities==0
			if not complete:aborted_reason="invalid-actual-city-source"
			return

func _sample_existing_agents(cars: Array,residents: Array,clock: float) -> void:
	car_population_low=mini(car_population_low,cars.size())
	car_population_high=maxi(car_population_high,cars.size())
	walker_population_low=mini(walker_population_low,residents.size())
	walker_population_high=maxi(walker_population_high,residents.size())
	total_car_snapshots+=cars.size()
	if cars.size()!=EXPECTED_VEHICLES or residents.size()!=EXPECTED_WALKERS:
		invalid_entities+=1
	for car in cars:
		if not is_instance_valid(car):
			invalid_entities+=1
			continue
		var speed: float=float(car.get("speed"))
		var stopped_s: float=float(car.get("stopped_seconds"))
		if not is_finite(speed) or not is_finite(stopped_s):
			invalid_entities+=1
			continue
		if absf(speed)<0.35:stopped_car_snapshots+=1
		if bool(car.get("last_crosswalk_occupied")):
			car_crosswalk_yield_snapshots+=1
		highest_original_car_stop_seconds=maxf(
			highest_original_car_stop_seconds,maxf(0.0,stopped_s))
	for person in residents:
		if not is_instance_valid(person):
			invalid_entities+=1
			continue
		var velocity: Variant=person.get("planned_velocity")
		var wait_s: float=float(person.get("signal_wait_seconds"))
		if not velocity is Vector3 or not is_finite(wait_s):
			invalid_entities+=1
			continue
		var walk: Vector3=velocity
		if not walk.is_finite():
			invalid_entities+=1
			continue
		if str(person.get("signal_status"))=="wait":
			walker_wait_snapshots+=1
		if walk.length_squared()>0.04:
			walker_walking_snapshots+=1
		highest_original_walker_wait_seconds=maxf(
			highest_original_walker_wait_seconds,maxf(0.0,wait_s))
	var x_phase: String=REAL_SIGNAL.state_at(clock,Vector3.RIGHT)
	var z_phase: String=REAL_SIGNAL.state_at(clock,Vector3.BACK)
	if x_phase=="green":x_green_snapshots+=1
	if z_phase=="green":z_green_snapshots+=1
	if x_phase=="amber":x_amber_snapshots+=1
	if z_phase=="amber":z_amber_snapshots+=1

func report() -> Dictionary:
	if not complete:
		return {
			"status":"not-ready",
			"schema":"city-reign-r183-real-mobility-v1",
			"hardware_attested":false,
			"captured_samples":snapshots,
			"aborted":aborted_reason,
			"ignored_blocked_frames":ignored_blocked_frames
		}
	return {
		"schema":"city-reign-r183-real-mobility-v1",
		"status":"complete",
		"sampling":"Opt-in bounded 2Hz snapshots of original physical NPC runtime",
		"source":"Godot original traffic agents, pedestrians and traffic signal clock",
		"hardware_attested":false,
		"captures_raw_positions":false,
		"network_upload":false,
		"sample_count":snapshots,
		"capture_seconds":captured_seconds,
		"original_vehicles_min":car_population_low,
		"original_vehicles_max":car_population_high,
		"original_walkers_min":walker_population_low,
		"original_walkers_max":walker_population_high,
		"mean_stopped_cars_per_sample":float(stopped_car_snapshots)/float(maxi(1,snapshots)),
		"stopped_car_observations":stopped_car_snapshots,
		"real_crosswalk_yield_observations":car_crosswalk_yield_snapshots,
		"walker_walk_observations":walker_walking_snapshots,
		"walker_wait_observations":walker_wait_snapshots,
		"longest_original_car_stop_s":highest_original_car_stop_seconds,
		"longest_original_pedestrian_signal_wait_s":highest_original_walker_wait_seconds,
		"x_green_signal_observations":x_green_snapshots,
		"z_green_signal_observations":z_green_snapshots,
		"x_amber_signal_observations":x_amber_snapshots,
		"z_amber_signal_observations":z_amber_snapshots,
		"ignored_invalid_frames":ignored_invalid_frames,
		"ignored_blocked_frames":ignored_blocked_frames,
		"warning":"2Hz in-game source observations, not hardware-certified FPS or collision proof"
	}
