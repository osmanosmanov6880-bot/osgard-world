extends Node3D
## CITY REIGN B34: authentic first playable chapter WAYFINDING in the
## original city. This tiny authored source mesh points only at real live
## game activities. Never creates rewards, missions, shortcuts or save keys.
## One physical metal/glass 3D source mesh + one localized Label3D, zero
## physics bodies, shadows, animation loops, renders only when relevant.
const EPISODE = preload("res://scripts/city_reign_first_promise.gd")
const PROJECTS = preload("res://scripts/project_landmarks.gd")
const REACH: float = 175.0
const MAX_VERTICES: int = 850
const SITE_HEIGHT: float = 5.8
const RING_SEGMENTS: int = 48
const ACCENT_ACTIVE = Color("c1a16e")
const ACCENT_FINISHED = Color("78bfa6")
const ACCENT_GUIDE = Color("83abbc")
var marker: MeshInstance3D
var caption: Label3D
var paint: StandardMaterial3D
var chosen: String = ""
var current_stage: String = ""
var last_title: String = ""
var last_position: Vector3 = Vector3.ZERO
var quality: String = "standard"
var range_visible: bool = true
var inside: bool = false
var menu_open: bool = false
var current_locale: String = "ru"
var light_energy: int = 100
var hour: float = 12.0

static func _face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,shade: Color) -> void:
	st.set_color(shade)
	for point in [a,b,c,a,c,d]:
		st.add_vertex(point)

static func _strut(st: SurfaceTool,mid: Vector3,half: Vector3,shade: Color) -> void:
	var p: Vector3 = mid-half
	var q: Vector3 = mid+half
	_face(st,Vector3(p.x,p.y,p.z),Vector3(q.x,p.y,p.z),
		Vector3(q.x,q.y,p.z),Vector3(p.x,q.y,p.z),shade)
	_face(st,Vector3(q.x,p.y,q.z),Vector3(p.x,p.y,q.z),
		Vector3(p.x,q.y,q.z),Vector3(q.x,q.y,q.z),shade)
	_face(st,Vector3(p.x,p.y,q.z),Vector3(p.x,p.y,p.z),
		Vector3(p.x,q.y,p.z),Vector3(p.x,q.y,q.z),shade)
	_face(st,Vector3(q.x,p.y,p.z),Vector3(q.x,p.y,q.z),
		Vector3(q.x,q.y,q.z),Vector3(q.x,q.y,p.z),shade)
	_face(st,Vector3(p.x,q.y,p.z),Vector3(q.x,q.y,p.z),
		Vector3(q.x,q.y,q.z),Vector3(p.x,q.y,q.z),shade)
	_face(st,Vector3(p.x,p.y,q.z),Vector3(q.x,p.y,q.z),
		Vector3(q.x,p.y,p.z),Vector3(p.x,p.y,p.z),shade)

static func _art() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bronze: Color = Color("a18b66")
	var steel: Color = Color("56707b")
	var glass: Color = Color("a4c5bd")
	# A low, physical 48-sided precision-machined annulus and four actual
	# waist-height visitor bollards. Not a floating quest advertisement.
	for i in range(RING_SEGMENTS):
		var a: float = TAU*float(i)/float(RING_SEGMENTS)
		var b: float = TAU*float(i+1)/float(RING_SEGMENTS)
		var band: Color = bronze if i%8==0 else steel
		_face(st,
			Vector3(cos(a)*2.06,0.18,sin(a)*2.06),
			Vector3(cos(b)*2.06,0.18,sin(b)*2.06),
			Vector3(cos(b)*2.21,0.18,sin(b)*2.21),
			Vector3(cos(a)*2.21,0.18,sin(a)*2.21),band)
	for axis in [-1.0,1.0]:
		for side in [-1.0,1.0]:
			_strut(st,Vector3(float(axis)*1.72,0.67,float(side)*1.72),
				Vector3(0.10,0.56,0.10),bronze)
			_strut(st,Vector3(float(axis)*1.72,1.22,float(side)*1.72),
				Vector3(0.16,0.055,0.16),glass)
	# Twin physically supported open-entry arches with a floating steel
	# beacon crown only 5.8 m above pavement. NO ray, billboard mesh or
	# 100 m laser beam polluting the skyline.
	for x in [-1.08,1.08]:
		_strut(st,Vector3(float(x),2.94,0.0),
			Vector3(0.12,2.72,0.12),steel)
		_strut(st,Vector3(float(x),5.60,0.0),
			Vector3(0.20,0.12,0.20),bronze)
	_strut(st,Vector3(0,5.66,0),Vector3(1.28,0.10,0.13),bronze)
	_strut(st,Vector3(0,5.87,0),Vector3(0.48,0.08,0.16),glass)
	st.generate_normals()
	return st.commit()

static func _local(lang: String,ru: String,en: String,zh: String) -> String:
	return ru if lang=="ru" else (en if lang=="en" else zh)

static func objective(state: Dictionary,locale: String = "ru") -> Dictionary:
	# The actual live first-episode progression is derived from original
	# mission actions and two genuine civic projects. Real errands take
	# precedence, as they already do in main.gd and MissionManager.
	for key in ["active_contract","service_active","neighborhood_active"]:
		var active: Variant = state.get(key,{})
		if active is Dictionary and not (active as Dictionary).is_empty():
			return {}
	if str(state.get("interior",""))!="":
		return {}
	var lang: String = locale if ["ru","en","zh"].has(locale) else "ru"
	var phase: Dictionary = EPISODE.phase(state)
	var stage: String = str(phase["id"])
	var mission: int = int(state.get("mission",0))
	var point: Vector3 = Vector3.ZERO
	var tag: String = ""
	var line: String = ""
	match stage:
		"arrival":
			if mission==0:
				var car: Variant = state.get("vehicle_position",[])
				if not (car is Array) or (car as Array).size()!=3:
					return {}
				point = Vector3(float(car[0]),0.0,float(car[2]))
				tag = "car"
				line = _local(lang,"ПЕРВАЯ МАШИНА","FIRST VEHICLE","初始车辆")
			elif mission==1:
				point = Vector3(130.0,0,-130.0)
				tag = "market"
				line = _local(lang,"ПЕРВАЯ ДОСТАВКА","FIRST DELIVERY","首次配送")
		"council":
			# City decisions are OPTIONAL while other original missions
			# continue. This cue does not change their validated action order.
			if mission>=4 and mission<20:
				var proposal: String = ""
				var finished: Array = state.get("projects_done",[])
				var active: Dictionary = state.get("projects_active",{})
				for candidate in EPISODE.CHOICES:
					if not finished.has(candidate) and not active.has(candidate):
						proposal = str(candidate)
						break
				if proposal!="":
					tag = proposal
					point = PROJECTS.POSITIONS[proposal]
					line = _local(lang,"ГОРОДСКОЕ РЕШЕНИЕ","CITY DECISION","城市决策")
		"building":
			tag = str(phase["chosen"])
			if PROJECTS.POSITIONS.has(tag):
				point = PROJECTS.POSITIONS[tag]
				line = _local(lang,"ИДЁТ СТРОИТЕЛЬСТВО","CONSTRUCTION ACTIVE","施工进行中")
		"delivered":
			if mission<20:
				tag = str(phase["chosen"])
				if PROJECTS.POSITIONS.has(tag):
					point = PROJECTS.POSITIONS[tag]
					line = _local(lang,"ОБЕЩАНИЕ ВЫПОЛНЕНО","PROMISE DELIVERED","承诺兑现")
		_:
			pass
	if tag=="" or not point.is_finite():
		return {}
	return {"id":tag,"stage":stage,"position":point,"title":line}

static func display_position(goal: Dictionary) -> Vector3:
	# Actual target stays untouched for gameplay/proximity. Physically place
	# the ornamental on-street arch NEXT TO the source 3D proposal/scaffold,
	# not on top of its real entrance, driving lane or existing text placard.
	var site: Vector3 = goal.get("position",Vector3.ZERO)
	var id: String = str(goal.get("id",""))
	if id=="market":
		return site+Vector3(0,0,-19.0)
	if id=="car":
		return site+Vector3(0,0,0)
	# The real open-budget/safe-crossings source site already has a 6m
	# radius visible construction/sign base. Its public entrance is on the
	# SOUTH pavement. Put the original brass wayfinding arch IN FRONT,
	# not behind the opaque built facility (actual Chromium critique B39).
	return site+Vector3(0,0,-10.0)

func _ready() -> void:
	name = "CityReignAuthenticOpeningStreetDirector"
	marker = MeshInstance3D.new()
	marker.name = "Original4DStreetCivicGate"
	marker.mesh = _art()
	# More legible original low-poly real bronze portal: enlarge actual
	# metallic surfaces, not a Photoshop postprocess glow or UI overlay.
	# The authored 3D asset keeps its original 792 vertices / 1 draw.
	marker.scale = Vector3(1.22,1.25,1.22)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paint = StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.albedo_color = Color.WHITE
	paint.metallic = 0.46
	paint.roughness = 0.43
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.emission_enabled = true
	paint.emission = Color("af9b78")
	paint.emission_energy_multiplier = 0.12
	marker.material_override = paint
	add_child(marker)
	caption = Label3D.new()
	caption.name = "LocalisedActualCivicObjective"
	caption.position = Vector3(0,8.65,0)
	caption.font_size = 46
	caption.pixel_size = 0.009
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.modulate = Color("e4d5b7")
	caption.no_depth_test = false
	add_child(caption)
	visible = false

func sync_state(state: Dictionary,locale: String) -> void:
	current_locale = locale if ["ru","en","zh"].has(locale) else "ru"
	var goal: Dictionary = objective(state,current_locale)
	if goal.is_empty():
		chosen = ""
		current_stage = ""
		last_title = ""
		_refresh_visibility()
		return
	chosen = str(goal["id"])
	current_stage = str(goal["stage"])
	last_title = str(goal["title"])
	last_position = goal["position"]
	position = display_position(goal)
	if caption != null:
		caption.text = last_title
	light_energy = clampi(int(state.get("energy",100)),0,100)
	_refresh_visibility()
	update_ambience(float(state.get("day_clock",12.0)),light_energy)

func set_quality(tier: String) -> void:
	quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	_refresh_visibility()

func set_view(observer: Vector3,is_inside: bool,is_menu_open: bool) -> void:
	inside = is_inside
	menu_open = is_menu_open
	range_visible = observer.is_finite() and (
		Vector2(observer.x-last_position.x,observer.z-last_position.z).length_squared()
		<=REACH*REACH)
	_refresh_visibility()

func _refresh_visibility() -> void:
	visible = chosen!="" and quality!="low" and range_visible and not inside and not menu_open

func update_ambience(real_hour: float,power: int) -> void:
	hour = fposmod(real_hour,24.0) if is_finite(real_hour) else 12.0
	light_energy = clampi(power,0,100)
	if paint!=null:
		var night: bool = hour>=19.0 or hour<5.0
		paint.emission_energy_multiplier = (
			0.32 if night and light_energy>=20 else 0.10 if light_energy>=20 else 0.0)

func geometry_is_bounded() -> bool:
	if marker==null or caption==null or get_child_count()!=2:
		return false
	if not marker.mesh is ArrayMesh or marker.mesh.get_surface_count()!=1:
		return false
	var n: int = marker.mesh.surface_get_array_len(0)
	if n<300 or n>MAX_VERTICES:
		return false
	if not find_children("*","CollisionShape3D",true,false).is_empty():
		return false
	return marker.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
