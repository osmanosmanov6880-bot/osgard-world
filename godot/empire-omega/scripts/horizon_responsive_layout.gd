extends RefCounted
## HORIZON R7. Deterministic viewport geometry shared by the actual HUD and
## native tests. No device model sniffing, cookies or guessed browser zoom.
const MIN_PHONE_WIDTH := 290.0
const PHONE_BREAKPOINT := 940.0
const SHORT_SCREEN := 620.0

static func is_compact(viewport: Vector2) -> bool:
	return viewport.x < PHONE_BREAKPOINT or viewport.y < SHORT_SCREEN

static func compute(viewport: Vector2) -> Dictionary:
	var w: float = maxf(MIN_PHONE_WIDTH,viewport.x)
	var h: float = maxf(410.0,viewport.y)
	if not is_compact(viewport):
		return {"compact":false, "viewport":Vector2(w,h)}
	var head_w: float = clampf(w*0.42,128.0,192.0)
	var speed_w: float = clampf(w-head_w-36.0,130.0,205.0)
	var head := Rect2(12.0,12.0,head_w,64.0)
	var speed := Rect2(w-speed_w-12.0,12.0,speed_w,64.0)
	var objective := Rect2(12.0,84.0,w-24.0,94.0)
	var minimap := Rect2(w-160.0,185.0,148.0,149.0)
	var help_y: float = h-maxf(196.0,minf(242.0,h*0.275))
	var help := Rect2(12.0,help_y,w-24.0,52.0)
	var journal_height: float = maxf(130.0,minf(355.0,h-335.0))
	var journal := Rect2(12.0,185.0,w-24.0,journal_height)
	var diagnostics := Rect2(12.0,185.0,minf(w-24.0,330.0),96.0)
	var toast := Rect2(12.0,182.0,w-24.0,68.0)
	var panel_height: float = minf(670.0,h-24.0)
	var modal := Rect2(12.0,(h-panel_height)*0.5,w-24.0,panel_height)
	var quick_toggle := Rect2(12.0,190.0,124.0,44.0)
	var quick_panel := Rect2(12.0,241.0,minf(w-24.0,176.0),maxf(128.0,minf(h-265.0,344.0)))
	return {
		"compact":true, "viewport":Vector2(w,h),
		"header":head, "speed":speed, "objective":objective,
		"map":minimap, "map_default":w>=360.0 and h>=690.0,
		"help":help, "journal":journal, "diagnostics":diagnostics,
		"toast":toast, "modal":modal,
		"quick_toggle":quick_toggle, "quick_panel":quick_panel,
		"touch_safe_top":h-192.0
	}
