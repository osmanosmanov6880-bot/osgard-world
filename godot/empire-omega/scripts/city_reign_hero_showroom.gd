extends VBoxContainer
## CITY REIGN AAA A11: actual interactive source-car turntable INSIDE the real
## in-game garage. No PNG, branded car import, purchased-vehicle mutation,
## physics body, shadow maps, external network or per-frame render loop.
## The same HORIZON_BODY and A7 profiles as the driving player are used.
const CAR_VISUAL = preload("res://scripts/horizon_vehicle_art.gd")
const CAR_CATALOG = preload("res://scripts/vehicle_catalog.gd")
const REFERENCE = preload("res://scripts/horizon_r90_reference_style.gd")
const LANG = {
	"ru":{"title":"АТЕЛЬЕ АВТОМОБИЛЕЙ","hint":"Оригинальная 3D-модель · проверка перед выбором",
		"open":"ОСМОТРЕТЬ В 3D","left":"↶  ПОВЕРНУТЬ","right":"ПОВЕРНУТЬ  ↷",
		"low":"3D-предпросмотр отключён в режиме низкой графики"},
	"en":{"title":"AUTOMOTIVE ATELIER","hint":"Original playable 3D model · inspect before choosing",
		"open":"INSPECT IN 3D","left":"↶  ROTATE","right":"ROTATE  ↷",
		"low":"3D preview is disabled in low-graphics mode"},
	"zh":{"title":"车辆设计展厅","hint":"真实游戏3D模型 · 选择前查看",
		"open":"查看3D模型","left":"↶  旋转","right":"旋转  ↷",
		"low":"低画质模式下禁用3D预览"}
}
const ROTATE_STEP: float = PI / 12.0
const MAX_SOURCE_VIEWS: int = 1
const DESKTOP_SIZE := Vector2i(620,282)
const MOBILE_SIZE := Vector2i(340,184)
var current_vehicle: String = "compact"
var locale: String = "ru"
var mobile: bool = false
var enabled: bool = true
var renderer: SubViewport
var spin: Node3D
var original_car: Node3D
var name_label: Label
var viewport_host: SubViewportContainer
var start_button: Button
var turn_left: Button
var turn_right: Button

func _ui_label(parent: Node, words: String, size: int, accent: bool) -> Label:
	var label := Label.new()
	label.text = words
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",REFERENCE.GOLD if accent else REFERENCE.SILVER)
	parent.add_child(label)
	return label

func _ui_button(parent: Node, words: String, action: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = words
	button.disabled = disabled
	button.custom_minimum_size.y = 46.0
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size",14)
	REFERENCE.style_button(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func build(display_locale: String,compact: bool,preview_enabled: bool,selected_id: String) -> void:
	locale = display_locale if LANG.has(display_locale) else "ru"
	mobile = compact
	enabled = preview_enabled
	current_vehicle = selected_id if CAR_CATALOG.available(selected_id) else "compact"
	var content := PanelContainer.new()
	content.name = "CityReignShowroomFrame"
	content.add_theme_stylebox_override("panel",REFERENCE.panel_style())
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",9)
	content.add_child(column)
	_ui_label(column,str(LANG[locale]["title"]),20,true)
	name_label = _ui_label(column,"",17,true)
	_ui_label(column,str(LANG[locale]["hint"]),13,false)
	viewport_host = SubViewportContainer.new()
	viewport_host.name = "CityReignReal3DShowroomHost"
	viewport_host.stretch = true
	viewport_host.visible = false
	# The viewport container must NEVER expand beyond the 620px offscreen
	# GPU budget, even when the command center is extremely wide. A 320px
	# phone reserves its margins rather than forcing a 340px horizontal scroll.
	var outer_width: float = get_viewport().get_visible_rect().size.x
	var target_width: float = 340.0 if compact else 620.0
	var safe_width: float = maxf(220.0,minf(target_width,outer_width-(28.0 if compact else 80.0)))
	viewport_host.custom_minimum_size = Vector2(safe_width,184 if compact else 282)
	viewport_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(viewport_host)
	var controls := HBoxContainer.new()
	controls.name = "CityReignShowroomControls"
	controls.add_theme_constant_override("separation",9)
	column.add_child(controls)
	start_button = _ui_button(controls,str(LANG[locale]["open"]),
		Callable(self,"_activate"),not enabled)
	start_button.name = "CityReignShowroomOpen"
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_left = _ui_button(controls,str(LANG[locale]["left"]),
		Callable(self,"rotate_model").bind(-1),true)
	turn_left.name = "CityReignShowroomRotateLeft"
	turn_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_right = _ui_button(controls,str(LANG[locale]["right"]),
		Callable(self,"rotate_model").bind(1),true)
	turn_right.name = "CityReignShowroomRotateRight"
	turn_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_label()
	if not enabled:
		_ui_label(column,str(LANG[locale]["low"]),12,false)
	elif not mobile:
		_activate()

func _update_label() -> void:
	if name_label == null:
		return
	var name_info: Dictionary = CAR_CATALOG.VEHICLES.get(current_vehicle,{})
	name_label.text = str(name_info.get(locale,name_info.get("ru","CITY REIGN")))

func _activate() -> void:
	if not enabled:
		return
	if renderer == null:
		_create_original_3d_scene()
	if renderer != null:
		viewport_host.visible = true
		start_button.visible = false
		turn_left.disabled = false
		turn_right.disabled = false
		_apply_source_car()

func _create_original_3d_scene() -> void:
	# Only one genuine source-driven preview viewport per open garage. The
	# R90 live-city atlas viewport remains separate and entirely unmodified.
	renderer = SubViewport.new()
	renderer.name = "CityReignActualCarViewport"
	renderer.size = MOBILE_SIZE if mobile else DESKTOP_SIZE
	# Headless + actual WebGL do not automatically allocate World3D for a
	# dynamically created SubViewport. Bind one real dedicated physics-free
	# scene world, rather than relying on the inherited Viewport property.
	renderer.world_3d = World3D.new()
	renderer.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport_host.add_child(renderer)
	var scene := Node3D.new()
	scene.name = "CityReignAuthoredStudioScene"
	renderer.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.name = "CityReignStudioEnvironment"
	var room := Environment.new()
	room.background_mode = Environment.BG_COLOR
	room.background_color = Color("0a121b")
	room.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room.ambient_light_color = Color("c2d0d7")
	room.ambient_light_energy = 0.97
	environment.environment = room
	scene.add_child(environment)
	var key := DirectionalLight3D.new()
	key.name = "CityReignStudioKeyNoShadows"
	key.rotation_degrees = Vector3(-38.0,39.0,0)
	key.light_energy = 1.55
	key.shadow_enabled = false
	scene.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "CityReignStudioFillNoShadows"
	fill.rotation_degrees = Vector3(-26.0,-71.0,0)
	fill.light_energy = 0.58
	fill.shadow_enabled = false
	scene.add_child(fill)
	var platform := MeshInstance3D.new()
	platform.name = "CityReignTurntablePodium"
	var disk := CylinderMesh.new()
	disk.top_radius = 3.5
	disk.bottom_radius = 3.6
	disk.height = 0.14
	disk.radial_segments = 36
	platform.mesh = disk
	platform.position.y = -0.91
	var basalt := StandardMaterial3D.new()
	basalt.albedo_color = Color("202831")
	basalt.metallic = 0.35
	basalt.roughness = 0.44
	platform.material_override = basalt
	scene.add_child(platform)
	spin = Node3D.new()
	spin.name = "CityReignOriginalCarTurntable"
	spin.rotation.y = deg_to_rad(26.0)
	scene.add_child(spin)
	original_car = CAR_VISUAL.new()
	spin.add_child(original_car)
	original_car.call("set_detail_quality","standard")
	var camera := Camera3D.new()
	camera.name = "CityReignStudioCamera"
	camera.position = Vector3(4.2,2.35,-5.1)
	camera.fov = 36.0
	camera.near = 0.1
	camera.far = 48.0
	scene.add_child(camera)
	camera.look_at(Vector3(0.0,-0.15,0.0),Vector3.UP)
	camera.current = true

func _apply_source_car() -> void:
	if renderer==null or original_car==null:
		return
	# The exact real player vehicle sculpt, not a reimagined concept mesh.
	var spec: Dictionary = CAR_CATALOG.VEHICLES[current_vehicle]
	original_car.call("set_paint",Color(str(spec["paint"])))
	original_car.call("set_visual_variant",current_vehicle)
	renderer.render_target_update_mode = SubViewport.UPDATE_ONCE

func preview_vehicle(id: String) -> bool:
	if not CAR_CATALOG.available(id):
		return false
	current_vehicle = id
	_update_label()
	# Compact mobile uses zero preview passes UNTIL the user explicitly
	# requests a named car. LOW always shows authoritative text instead.
	if enabled:
		_activate()
	return true

func rotate_model(direction: int) -> void:
	if not enabled or renderer==null or spin==null:
		return
	spin.rotation.y = fposmod(spin.rotation.y + ROTATE_STEP*signi(direction),TAU)
	# No timer: this is a single demand-driven real Godot render frame.
	renderer.render_target_update_mode = SubViewport.UPDATE_ONCE

func graphics_are_bounded() -> bool:
	if renderer==null:
		return true
	if renderer.get_parent()!=viewport_host or renderer.get_child_count()!=1:
		return false
	if renderer.size.x>DESKTOP_SIZE.x or renderer.size.y>DESKTOP_SIZE.y:
		return false
	if renderer.get_world_3d()==null:
		return false
	if original_car==null or spin==null:
		return false
	if not original_car.find_children("*","CollisionShape3D",true,false).is_empty():
		return false
	return renderer.render_target_update_mode != SubViewport.UPDATE_ALWAYS
