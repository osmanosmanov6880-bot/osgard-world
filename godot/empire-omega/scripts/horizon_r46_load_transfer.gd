extends RefCounted
## EMPIRE Ω R46 — bounded longitudinal weight transfer and brake-contact loss.
## This is a calibrated CharacterBody3D approximation, NOT a 4-body rigid-car.
## Units: m/s² acceleration, physical wheel support, metres and m/s.
const GRAVITY_MPS2: float = 9.81
const WHEELBASE_M: float = 3.35
const CENTER_GRAVITY_HEIGHT_M: float = 0.55
const STATIC_FRONT_FRACTION: float = 0.52
const MAX_ACCEL_MPS2: float = 14.0
const MIN_EFFECTIVE_GRIP: float = 0.35
const MAX_EFFECTIVE_GRIP: float = 1.15
const BRAKE_ACCEL_MPS2: float = 10.5

static func front_axle_fraction(longitudinal_accel_mps2: float) -> float:
	var acceleration: float = clampf(longitudinal_accel_mps2 if is_finite(longitudinal_accel_mps2) else 0.0,-MAX_ACCEL_MPS2,MAX_ACCEL_MPS2)
	# Deceleration (negative acceleration) shifts normal load to front axle.
	var transfer: float = -acceleration*CENTER_GRAVITY_HEIGHT_M/(GRAVITY_MPS2*WHEELBASE_M)
	return clampf(STATIC_FRONT_FRACTION+transfer,0.30,0.75)

static func contact_fraction(wheels: Array[bool],front_fraction: float) -> float:
	# Order of existing R21 tyre contacts: LF, LR, RF, RR.
	# No contacts => minimum residual aerodynamic / ground-free deceleration.
	if wheels.size()!=4:
		return 0.0
	var front: float = clampf(front_fraction if is_finite(front_fraction) else STATIC_FRONT_FRACTION,0.30,0.75)
	var supported: float = 0.0
	for index in range(4):
		if wheels[index]:
			supported += front*0.5 if index==0 or index==2 else (1.0-front)*0.5
	return clampf(supported,0.0,1.0)

static func braking_grip(base_grip: float,wheels: Array[bool],front_fraction: float) -> float:
	var safe_grip: float = clampf(base_grip if is_finite(base_grip) else MIN_EFFECTIVE_GRIP,MIN_EFFECTIVE_GRIP,MAX_EFFECTIVE_GRIP)
	# A fully planted car has the EXACT previous grip. Loss of contact reduces
	# braking force progressively; effects never increase the old brake power.
	var support: float = contact_fraction(wheels,front_fraction)
	return clampf(safe_grip*support,MIN_EFFECTIVE_GRIP,MAX_EFFECTIVE_GRIP)

static func estimated_brake_distance(speed_mps: float,grip: float) -> float:
	# Diagnostic only: speed² / (2a), under uninterrupted maximal braking.
	# Not a measured tyre curve, ABS, reaction time or certified distance.
	if not is_finite(speed_mps):
		return 0.0
	var mu: float = clampf(grip if is_finite(grip) else MIN_EFFECTIVE_GRIP,MIN_EFFECTIVE_GRIP,MAX_EFFECTIVE_GRIP)
	var v: float = minf(absf(speed_mps),80.0)
	return v*v/(2.0*BRAKE_ACCEL_MPS2*mu)

static func diagnostics(speed: float, longitudinal_accel: float, grip: float,wheels: Array[bool]) -> Dictionary:
	var front: float = front_axle_fraction(longitudinal_accel)
	var supported: float = contact_fraction(wheels,front)
	var available_grip: float = braking_grip(grip,wheels,front)
	return {
		"front_axle_load_ratio":front,
		"rear_axle_load_ratio":1.0-front,
		"supported_normal_load_fraction":supported,
		"available_brake_grip":available_grip,
		"estimated_full_brake_m":estimated_brake_distance(speed,available_grip),
		"measured_physical_road_stopping_distance":false,
		"model":"kinematic-four-contact-load-transfer-r46"
	}
