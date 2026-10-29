extends RefCounted
## CITY REIGN R165 / APEX DYNAMICS
## Bounded deterministic BRAKE-BY-INPUT envelope for the shipping original
## CharacterBody3D. This is an arcade vehicle response, NOT an ABS,
## ESP, force-based wheel solver, certified stopping distance, hydraulic
## pressure sensor or physically calibrated friction-circle.
## The player still commands throttle/steering/handbrake. This subsystem
## never reads or mutates money, health, fuel, mission, save or input bindings.
const BRAKE_THRESHOLD: float = 0.25
const PRESSURE_APPLY_RATE: float = 16.0
const PRESSURE_RELEASE_RATE: float = 11.5
const STEP_LIMIT: float = 0.10
const MAX_TORQUE_TRIM: float = 0.19
const MIN_CORNER_FACTOR: float = 0.58
const MAX_BRAKE_DEMAND: float = 0.78

static func request(throttle: float,speed: float,handbrake: bool) -> float:
    if handbrake:
        return 1.0
    if not is_finite(throttle) or not is_finite(speed):
        return 0.0
    var command: float = clampf(throttle,-1.0,1.0)
    if speed>BRAKE_THRESHOLD and command< -0.05:
        return -command
    if speed< -BRAKE_THRESHOLD and command>0.05:
        return command
    return 0.0

static func step(previous: float,target: float,dt: float) -> float:
    var safe: float = clampf(previous if is_finite(previous) else 0.0,0.0,1.0)
    if not is_finite(dt) or dt<=0.0:
        return safe
    var goal: float = clampf(target if is_finite(target) else 0.0,0.0,1.0)
    var rate: float = PRESSURE_APPLY_RATE if goal>safe else PRESSURE_RELEASE_RATE
    # Analytic exponential avoids frame-rate-dependent lerp coefficients.
    var alpha: float = 1.0-exp(-minf(dt,STEP_LIMIT)*rate)
    return clampf(lerpf(safe,goal,alpha),0.0,1.0)

static func effective_throttle(raw: float,speed: float,pressure: float) -> float:
    if not is_finite(raw) or not is_finite(speed):
        return 0.0
    var commanded: float = clampf(raw,-1.0,1.0)
    var intensity: float = clampf(pressure if is_finite(pressure) else 0.0,0.0,1.0)
    # Only a currently active BRAKE intention is pressure-shaped.
    # Reverse drive from a true stop and positive engine torque stay manual.
    if (speed>BRAKE_THRESHOLD and commanded< -0.05) or (
            speed< -BRAKE_THRESHOLD and commanded>0.05):
        return signf(commanded)*minf(absf(commanded),intensity)
    return commanded

static func power_factor(speed: float,forward_limit: float) -> float:
    if not is_finite(speed) or not is_finite(forward_limit) or forward_limit<=1.0:
        return 1.0
    if speed<1.0:
        return 1.0
    # Effective drive effort gradually falls at motorway speed rather than
    # maintaining identical acceleration until the speed governor.
    var ratio: float = clampf(speed/forward_limit,0.0,1.0)
    return clampf(1.0-MAX_TORQUE_TRIM*ratio*ratio,1.0-MAX_TORQUE_TRIM,1.0)

static func corner_yaw(original_yaw: float,speed: float,grip: float,
        pressure: float,handbrake: bool) -> float:
    if not is_finite(original_yaw) or not is_finite(speed):
        return 0.0
    if handbrake or absf(speed)<5.0:
        return original_yaw
    if not is_finite(grip) or not is_finite(pressure):
        return original_yaw
    var requested: float = clampf(pressure,0.0,1.0)
    if requested<0.04:
        return original_yaw
    var wetness: float = clampf(1.0-grip,0.0,0.65)
    var demand: float = clampf(requested*(0.58+wetness*0.30),0.0,MAX_BRAKE_DEMAND)
    var remaining: float = sqrt(maxf(0.0,1.0-demand*demand))
    return original_yaw*clampf(remaining,MIN_CORNER_FACTOR,1.0)

static func safety_bound(pressure: float,speed: float,yaw: float) -> bool:
    return is_finite(pressure) and pressure>=0.0 and pressure<=1.0 and (
        is_finite(speed) and is_finite(yaw) and absf(yaw)<=1.251)
