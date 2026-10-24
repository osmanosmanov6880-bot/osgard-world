extends RefCounted
## HORIZON R13. A genuinely touch-specific first playable objective.
## Only display text changes; missions and rewards stay authoritative.
const FIRST_TOUCH_GOAL = {
	"ru":"Подойдите к машине и нажмите АВТО",
	"en":"Walk to the car and tap CAR",
	"zh":"靠近车辆并点击车辆按钮"
}

static func title(official: String, mission_stage: int, compact: bool, has_touch: bool, locale: String = "ru") -> String:
	if mission_stage != 0 or not compact or not has_touch:
		return official
	return str(FIRST_TOUCH_GOAL.get(locale,FIRST_TOUCH_GOAL["ru"]))
