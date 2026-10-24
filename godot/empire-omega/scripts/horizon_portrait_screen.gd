extends RefCounted
## HORIZON R12: a real portrait viewport instead of a 16:9 strip with huge
## black letterboxes. No Web JS modifications to physics or stored game state.
## Godot canvas_items + expand grows the viewport; scale compensates for the
## 1600x900 desktop reference so the mobile HUD stays finger-readable.
const PHONE_SCALE: float = 2.4
const PORTRAIT_RATIO: float = 1.25
const MAX_PHONE_WIDTH: int = 900
const MIN_TOUCH_WIDTH: int = 260

static func is_phone_portrait(physical: Vector2i) -> bool:
	return physical.x >= MIN_TOUCH_WIDTH and physical.x <= MAX_PHONE_WIDTH and physical.y >= 400 and float(physical.y) >= float(physical.x)*PORTRAIT_RATIO

static func content_factor(physical: Vector2i) -> float:
	return PHONE_SCALE if is_phone_portrait(physical) else 1.0

static func web_css_size() -> Vector2i:
	if not OS.has_feature("web"):
		return DisplayServer.window_get_size()
	# The logical Godot viewport can remain 1600x900 even when Chromium has
	# resized the actual canvas to 390x844. Use CSS pixels on Web only.
	var w: Variant = JavaScriptBridge.eval("Math.round(window.innerWidth)",true)
	var h: Variant = JavaScriptBridge.eval("Math.round(window.innerHeight)",true)
	if (w is int or w is float) and (h is int or h is float):
		var physical := Vector2i(int(w),int(h))
		if physical.x >= MIN_TOUCH_WIDTH and physical.y >= 240:
			return physical
	return DisplayServer.window_get_size()

static func apply_to(window: Window, physical: Vector2i = Vector2i.ZERO) -> bool:
	if window == null:
		return false
	if physical == Vector2i.ZERO:
		physical = web_css_size()
	var desired: float = content_factor(physical)
	if window.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	# Always check first: content scale changes can emit size_changed.
	if not is_equal_approx(window.content_scale_factor,desired):
		window.content_scale_factor = desired
	return desired > 1.01
