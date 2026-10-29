extends RefCounted
## R163: physically driven turn indicator auto-cancel; hazards NEVER cancel.
## Uses actual vehicle yaw delta and actual world displacement, not a timer.
const TURN_THRESHOLD_RADIANS: float = 0.76
const MIN_MOVEMENT_METRES: float = 5.5
const MAX_RETURN_STEERING: float = 0.23
const MIN_DRIVE_SPEED: float = 2.0

static func progress(mode: String,previous_yaw: float,current_yaw: float,
        existing: float,covered: float,forward_speed: float) -> float:
    if mode!="left" and mode!="right":
        return 0.0
    if not is_finite(previous_yaw) or not is_finite(current_yaw) or not is_finite(existing) or not is_finite(covered) or not is_finite(forward_speed):
        return 0.0
    if forward_speed<MIN_DRIVE_SPEED or covered<=0.01:
        return clampf(existing,0.0,PI)
    # In the existing original controller, forward=-Z and +yaw turns LEFT.
    var yaw_step: float = wrapf(current_yaw-previous_yaw,-PI,PI)
    var direction: float = 1.0 if mode=="left" else -1.0
    return clampf(existing+yaw_step*direction,0.0,PI)

static func completed(mode: String,yaw_progress: float,travelled: float,
        steering: float,forward_speed: float) -> bool:
    if mode!="left" and mode!="right":
        return false
    if not is_finite(yaw_progress) or not is_finite(travelled) or not is_finite(steering) or not is_finite(forward_speed):
        return false
    return yaw_progress>=TURN_THRESHOLD_RADIANS and travelled>=MIN_MOVEMENT_METRES and (
        absf(steering)<=MAX_RETURN_STEERING and forward_speed>=MIN_DRIVE_SPEED)
