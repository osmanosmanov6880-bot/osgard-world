extends RefCounted
## R90 signed-off charcoal / brass reference tokens.
## This is a real Godot style system, never an image-based fake UI.
const GOLD := Color("e5bb72")
const SILVER := Color("e9ecf1")
const BG := Color("0a111b",0.955)
const RIM := Color("bc9454",0.76)
const SOFT := Color("223044",0.70)

static func card_style(active: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b1119",0.93 if active else 0.87)
	box.border_color = GOLD if active else Color("778391",0.46)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 13
	box.content_margin_right = 13
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.shadow_color = Color(0,0,0,0.26)
	box.shadow_size = 7
	return box

static func panel_style() -> StyleBoxFlat:
	var box := card_style(true)
	box.bg_color = BG
	box.content_margin_left = 17
	box.content_margin_right = 17
	box.content_margin_top = 15
	box.content_margin_bottom = 15
	box.shadow_size = 12
	return box

static func style_button(button: Button) -> void:
	var normal := card_style()
	normal.bg_color = Color("0d1925",0.89)
	normal.border_color = Color("637180",0.48)
	var hover := card_style(true)
	hover.bg_color = Color("243244",0.95)
	var pressed := card_style(true)
	pressed.bg_color = Color("37414a",0.99)
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",pressed)
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	button.add_theme_color_override("font_color",SILVER)
	button.add_theme_color_override("font_hover_color",Color("ffe6ad"))
	button.add_theme_color_override("font_disabled_color",Color("8c949d"))

static func command_center_frame(size: Vector2) -> Rect2:
	var side: float = clampf(size.x*0.012,12.0,22.0)
	var top: float = clampf(size.y*0.016,10.0,18.0)
	return Rect2(side,top,maxf(300.0,size.x-side*2.0),
		maxf(340.0,size.y-top*2.0))
