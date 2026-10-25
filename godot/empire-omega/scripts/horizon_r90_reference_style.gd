extends RefCounted
## R97 real Godot command language: restrained graphite, champagne brass,
## readable editorial type, quiet surfaces and a visible keyboard focus ring.
## One engine font stack for every dashboard element (no device-specific font).
const GOLD := Color("d9bb83")
const SILVER := Color("eeeae3")
const BG := Color("080d13",0.97)
const RIM := Color("ad9771",0.65)
const SOFT := Color("242c36",0.78)
const MUTED := Color("c3c2bd")

static func card_style(active: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b1018",0.965 if active else 0.925)
	box.border_color = RIM if active else Color("797c7e",0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 17
	box.content_margin_right = 17
	box.content_margin_top = 15
	box.content_margin_bottom = 15
	box.shadow_color = Color(0,0,0,0.34)
	box.shadow_size = 9
	return box

static func panel_style() -> StyleBoxFlat:
	var box := card_style(true)
	box.bg_color = BG
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 19
	box.content_margin_bottom = 19
	box.shadow_size = 16
	return box

static func style_button(button: Button) -> void:
	var normal := card_style()
	normal.bg_color = Color("111821",0.95)
	normal.border_color = Color("898276",0.40)
	var hover := card_style(true)
	hover.bg_color = Color("242b31",0.98)
	var pressed := card_style(true)
	pressed.bg_color = Color("31343a",0.99)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0,0,0,0)
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",pressed)
	button.add_theme_stylebox_override("focus",focus)
	button.add_theme_color_override("font_color",SILVER)
	button.add_theme_color_override("font_hover_color",SILVER)
	button.add_theme_color_override("font_pressed_color",SILVER)
	button.add_theme_color_override("font_focus_color",SILVER)
	button.add_theme_color_override("font_disabled_color",MUTED)
	button.focus_mode = Control.FOCUS_ALL

static func command_center_frame(size: Vector2) -> Rect2:
	var side: float = clampf(size.x*0.012,12.0,22.0)
	var top: float = clampf(size.y*0.016,10.0,18.0)
	return Rect2(side,top,maxf(300.0,size.x-side*2.0),
		maxf(340.0,size.y-top*2.0))
