extends RefCounted
## CITY REIGN R184 — the original player speeding offence, the driver
## warning and every physically authored road sign share ONE legal limit.
## This preserves the original CityLaw 90-credit first fine and cooldown.
## Game-only km/h, no claim about real-world law in any jurisdiction.
const LAW=preload("res://scripts/city_law.gd")
const LIMIT_MPS: float=25.0
const LIMIT_KMH: int=90
const MPS_TO_KMH: float=3.6
const CITATION_SECONDS: float=4.0
const PREWARNING_RATIO: float=0.90
const CLEAR_DECAY_RATE: float=2.0
const MAX_PHYSICS_STEP: float=0.25

static func displayed_limit() -> int:
	return LIMIT_KMH

static func above_limit(speed: float) -> bool:
	return is_finite(speed) and absf(speed)>LIMIT_MPS

static func timer_step(previous: float,speed: float,delta: float) -> float:
	# A long resuming browser frame must NEVER fabricate four seconds
	# of unlawful movement or skip an existing citation's time gate.
	if not is_finite(previous) or not is_finite(speed) or not is_finite(delta):
		return 0.0
	var step: float=clampf(delta,0.0,MAX_PHYSICS_STEP)
	if above_limit(speed):
		return minf(CITATION_SECONDS,maxf(0.0,previous)+step)
	return maxf(0.0,previous-step*CLEAR_DECAY_RATE)

static func citation_ready(seconds: float) -> bool:
	return is_finite(seconds) and seconds>=CITATION_SECONDS

static func player_warning(speed: float) -> Dictionary:
	if not is_finite(speed) or absf(speed)<LIMIT_MPS*PREWARNING_RATIO:
		return {}
	return {
		"kind":"speed_limit",
		"urgency":"caution",
		"limit_kmh":LIMIT_KMH,
		"observed_kmh":roundi(absf(speed)*MPS_TO_KMH),
		"over_limit":above_limit(speed)
	}

static func source_rule_valid() -> bool:
	return (LIMIT_MPS*MPS_TO_KMH==float(LIMIT_KMH) and
		LIMIT_KMH==90 and
		LAW.OFFENCES.has("speeding") and LAW.OFFENCES["speeding"]==90 and
		LAW.OFFENCE_COOLDOWN==18.0 and
		PREWARNING_RATIO>0.0 and PREWARNING_RATIO<1.0)
