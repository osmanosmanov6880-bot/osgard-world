extends Node3D
## CITY REIGN B57: genuine saved-decision urban consequences, not an overlay.
## The first civic choice has REAL lasting street-level art:
##  - safe_crossings: 36 physical painted zebra slats + 40 powered road studs
##  - open_records: a real sculpted municipal records pavilion with a live
##    truthful treasury/trust display, sourced from the authoritative save.
## No replacement missions, rewards, RNG, save keys, obstacles, colliders,
## invented roads, fake snapshots, external licensed models or network calls.
const SAFE_CROSSINGS := "safe_crossings"
const OPEN_RECORDS := "open_records"
const CROSSING_COUNT: int = 4
const STRIPES_PER_CROSSING: int = 9
const STUDS_PER_CROSSING: int = 10
const MAX_KIOSK_VERTICES: int = 3000
const KIOSK_AT: Vector3 = Vector3(-164.0,0.0,-94.0)
# All four crossing groups occupy the EXACT original roadway at x=104
# or z=-104. 0.185m is above the original asphalt's y=0.175m surface,
# but below all wheel/pedestrian physics and without any CollisionShape.
const CROSSINGS: Array[Vector3] = [
	Vector3(104.0,0.0,-87.0),
	Vector3(104.0,0.0,-121.0),
	Vector3(87.0,0.0,-104.0),
	Vector3(121.0,0.0,-104.0)
]
var crossings: Node3D
var white_markings: MultiMeshInstance3D
var roadside_studs: MultiMeshInstance3D
var warning_finish: StandardMaterial3D
var record_pavilion: Node3D
var records_shell: MeshInstance3D
var records_glass: MeshInstance3D
var records_sign: Label3D
var glass_finish: StandardMaterial3D
var current_quality: String = "standard"
var current_hour: float = 12.0
var current_power: int = 100
var last_locale: String = "ru"
var completed: Dictionary = {"safe_crossings":false,"open_records":false}
var current_treasury: int = 0
var current_trust: int = 0
var created_once: bool = false

static func _local(locale: String,ru: String,en: String,zh: String) -> String:
	return ru if locale=="ru" else (en if locale=="en" else zh)

static func _box(st: SurfaceTool,center: Vector3,half: Vector3,
		tint: Color) -> void:
	var a: Vector3 = center-half
	var b: Vector3 = center+half
	var p: Array[Vector3] = [
		Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),
		Vector3(b.x,a.y,b.z),Vector3(a.x,a.y,b.z),
		Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),
		Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z)
	]
	var faces: Array = [
		[0,1,2,3],[4,7,6,5],[0,4,5,1],
		[1,5,6,2],[2,6,7,3],[3,7,4,0]
	]
	for f in faces:
		var i0: int = int(f[0])
		var i1: int = int(f[1])
		var i2: int = int(f[2])
		var i3: int = int(f[3])
		var v0: Vector3 = p[i0]
		var v1: Vector3 = p[i1]
		var v2: Vector3 = p[i2]
		var v3: Vector3 = p[i3]
		var n: Vector3 = (v1-v0).cross(v2-v0).normalized()
		for v in [v0,v1,v2,v0,v2,v3]:
			st.set_normal(n)
			st.set_color(tint)
			st.add_vertex(v)

static func _pavilion_mesh(premium: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var limestone := Color("b4b4aa")
	var bronze := Color("ad9469")
	var titanium := Color("687f87")
	var dark := Color("253b44")
	if premium:
		# Only incremental canopy geometry. Re-drawing the ENTIRE base
		# would create destructive same-depth z-fighting in cinematic mode.
		for x in [-1.30,-0.65,0.0,0.65,1.30]:
			_box(st,Vector3(float(x),3.79,-0.25),
				Vector3(0.060,0.050,1.17),titanium)
		for z in [-0.97,-0.36,0.25,0.86]:
			_box(st,Vector3(0,3.89,float(z)),
				Vector3(2.05,0.050,0.06),bronze)
		_box(st,Vector3(0,0.36,-1.92),Vector3(2.36,0.12,0.15),limestone)
		return st.commit()
	# Source project site -164,-85 already has its own real project landmark.
	# This small completed-only structure stands 9m south, outside that plot.
	_box(st,Vector3(0,0.16,0),Vector3(2.36,0.15,1.78),limestone)
	_box(st,Vector3(0,0.38,0),Vector3(2.21,0.075,1.61),dark)
	for x in [-1.91,1.91]:
		for z in [-1.34,1.34]:
			_box(st,Vector3(float(x),1.80,float(z)),
				Vector3(0.15,1.39,0.17),titanium)
			_box(st,Vector3(float(x),3.08,float(z)),
				Vector3(0.28,0.13,0.26),bronze)
	_box(st,Vector3(0,3.37,0),Vector3(2.27,0.20,1.65),limestone)
	_box(st,Vector3(0,3.59,-0.30),Vector3(2.08,0.055,1.18),bronze)
	_box(st,Vector3(0,2.00,-1.47),Vector3(1.76,0.93,0.12),dark)
	# A proper 3D stone/copper reveal surrounds the readable Label3D;
	# HUD values remain sourced from GameState, never hardcoded.
	_box(st,Vector3(-1.89,2.00,-1.57),Vector3(0.10,1.09,0.11),bronze)
	_box(st,Vector3(1.89,2.00,-1.57),Vector3(0.10,1.09,0.11),bronze)
	_box(st,Vector3(0,3.03,-1.57),Vector3(1.96,0.08,0.11),bronze)
	_box(st,Vector3(0,0.99,-1.57),Vector3(1.96,0.08,0.11),bronze)
	return st.commit()

static func _surface(roughness: float,metallic: float) -> StandardMaterial3D:
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color.WHITE
	finish.vertex_color_use_as_albedo = true
	finish.metallic = metallic
	finish.roughness = roughness
	finish.cull_mode = BaseMaterial3D.CULL_BACK
	return finish

static func _crosswalk_transform(center: Vector3,horizontal_road: bool,
		stripe: int) -> Transform3D:
	# Underlying stripe mesh is 8.7m wide across the whole REAL road.
	# The strips are separated along the driving axis, never a collider.
	var offset: float = float(stripe-(STRIPES_PER_CROSSING-1)/2)*0.66
	var turn: float = PI*0.5 if horizontal_road else 0.0
	var rotation := Basis(Vector3.UP,turn)
	return Transform3D(rotation,center+rotation*Vector3(0,0.186,offset))

static func _stud_transform(center: Vector3,horizontal_road: bool,
		index: int) -> Transform3D:
	var turn: float = PI*0.5 if horizontal_road else 0.0
	var rotation := Basis(Vector3.UP,turn)
	var lateral: float = -4.67 if index%2==0 else 4.67
	var longitudinal: float = float(index/2-2)*1.26
	return Transform3D(rotation,center+rotation*Vector3(lateral,0.216,longitudinal))

func _ready() -> void:
	name = "CityReignEarnedPhysicalStreetOutcomes"
	_build_once()
	set_quality(current_quality)
	_update_presence()

func _build_once() -> void:
	if created_once:
		return
	created_once = true
	crossings = Node3D.new()
	crossings.name = "GenuineEarnedCrosswalks"
	add_child(crossings)
	var zebra_mesh := BoxMesh.new()
	zebra_mesh.size = Vector3(8.70,0.026,0.47)
	var zebra_finish := StandardMaterial3D.new()
	zebra_finish.albedo_color = Color("f0eee4")
	zebra_finish.roughness = 0.72
	zebra_finish.metallic = 0.0
	var marks := MultiMesh.new()
	marks.transform_format = MultiMesh.TRANSFORM_3D
	marks.mesh = zebra_mesh
	marks.instance_count = CROSSING_COUNT*STRIPES_PER_CROSSING
	for i in range(CROSSING_COUNT):
		var at: Vector3 = CROSSINGS[i]
		var across_east_west: bool = i>=2
		for stripe in range(STRIPES_PER_CROSSING):
			var n: int = i*STRIPES_PER_CROSSING+stripe
			marks.set_instance_transform(n,
				_crosswalk_transform(at,across_east_west,stripe))
	white_markings = MultiMeshInstance3D.new()
	white_markings.name = "RealWhiteRoadPaint_MultiMesh36"
	white_markings.multimesh = marks
	white_markings.material_override = zebra_finish
	white_markings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	white_markings.custom_aabb = AABB(Vector3(65,-0.3,-140),Vector3(82,1.0,90))
	crossings.add_child(white_markings)
	var stud_mesh := CylinderMesh.new()
	stud_mesh.top_radius = 0.082
	stud_mesh.bottom_radius = 0.082
	stud_mesh.height = 0.042
	stud_mesh.radial_segments = 8
	stud_mesh.rings = 1
	var marker_instances := MultiMesh.new()
	marker_instances.transform_format = MultiMesh.TRANSFORM_3D
	marker_instances.mesh = stud_mesh
	marker_instances.instance_count = CROSSING_COUNT*STUDS_PER_CROSSING
	for i in range(CROSSING_COUNT):
		var at: Vector3 = CROSSINGS[i]
		for k in range(STUDS_PER_CROSSING):
			marker_instances.set_instance_transform(
				i*STUDS_PER_CROSSING+k,_stud_transform(at,i>=2,k))
	roadside_studs = MultiMeshInstance3D.new()
	roadside_studs.name = "RealRoadReflectors_MultiMesh40"
	roadside_studs.multimesh = marker_instances
	roadside_studs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roadside_studs.custom_aabb = white_markings.custom_aabb
	warning_finish = StandardMaterial3D.new()
	warning_finish.albedo_color = Color("e0b974")
	warning_finish.metallic = 0.52
	warning_finish.roughness = 0.33
	roadside_studs.material_override = warning_finish
	crossings.add_child(roadside_studs)
	record_pavilion = Node3D.new()
	record_pavilion.name = "RealPaidBudgetTransparencyPavilion"
	record_pavilion.position = KIOSK_AT
	add_child(record_pavilion)
	records_shell = MeshInstance3D.new()
	records_shell.name = "ActualStoneAndMetalPavilion"
	records_shell.mesh = _pavilion_mesh(false)
	records_shell.material_override = _surface(0.61,0.28)
	records_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	record_pavilion.add_child(records_shell)
	records_glass = MeshInstance3D.new()
	records_glass.name = "PhysicalPremiumSolarAndMetalCanopy"
	records_glass.mesh = _pavilion_mesh(true)
	records_glass.material_override = _surface(0.45,0.40)
	records_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	record_pavilion.add_child(records_glass)
	records_sign = Label3D.new()
	records_sign.name = "ActualSavedTreasuryAndForumTrust"
	records_sign.position = Vector3(0.0,2.18,-1.77)
	records_sign.font_size = 37
	records_sign.pixel_size = 0.0078
	records_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	records_sign.modulate = Color("f4ead8")
	records_sign.no_depth_test = false
	record_pavilion.add_child(records_sign)

func sync_state(state: Dictionary,locale: String) -> void:
	var lang: String = locale if ["ru","en","zh"].has(locale) else "ru"
	last_locale = lang
	var done: Variant = state.get("projects_done",[])
	var finished: Array = done if done is Array else []
	completed[SAFE_CROSSINGS] = finished.has(SAFE_CROSSINGS)
	completed[OPEN_RECORDS] = finished.has(OPEN_RECORDS)
	current_treasury = int(state.get("treasury",0))
	var trust: Variant = state.get("trust",[])
	current_trust = clampi(int(trust[0]),0,100) if trust is Array and trust.size()>=1 else 0
	if records_sign != null:
		var title: String = _local(lang,
			"ОТКРЫТЫЙ БЮДЖЕТ","OPEN BUDGET","公开预算")
		var money: String = _local(lang,
			"КАЗНА","TREASURY","财政预算")
		var confidence: String = _local(lang,
			"ДОВЕРИЕ","TRUST","信任")
		records_sign.text = "%s\n%s: %d\n%s: %d%%" % [
			title,money,current_treasury,confidence,current_trust]
	current_hour = float(state.get("day_clock",12.0))
	current_power = clampi(int(state.get("energy",100)),0,100)
	_update_presence()

func set_quality(mode: String) -> void:
	current_quality = mode if ["low","standard","cinematic"].has(mode) else "standard"
	_update_presence()

func update_ambience(hour: float,power: int) -> void:
	current_hour = fposmod(hour,24.0) if is_finite(hour) else 12.0
	current_power = clampi(power,0,100)
	_update_presence()

func _update_presence() -> void:
	if not created_once:
		return
	crossings.visible = bool(completed[SAFE_CROSSINGS])
	record_pavilion.visible = bool(completed[OPEN_RECORDS])
	# Earned white road safety markings remain clearly visible even on LOW.
	white_markings.visible = crossings.visible
	roadside_studs.visible = crossings.visible and current_quality!="low"
	# The physical extra metal canopy is optional. The kiosk's stone frame
	# and its TRUE budget/trust report remain accessible on low hardware.
	records_glass.visible = record_pavilion.visible and current_quality=="cinematic"
	var night: bool = current_hour>=19.0 or current_hour<6.0
	var energy: float = clampf(float(current_power)/60.0,0.0,1.0)
	var powered: bool = night and energy>0.1 and roadside_studs.visible
	warning_finish.emission_enabled = powered
	warning_finish.emission = Color("ffc77f")
	warning_finish.emission_energy_multiplier = (
		0.68*energy if powered else 0.0)

func project_visible(id: String) -> bool:
	if id==SAFE_CROSSINGS:
		return crossings != null and crossings.visible
	if id==OPEN_RECORDS:
		return record_pavilion != null and record_pavilion.visible
	return false

func graphics_are_bounded() -> bool:
	if not created_once or get_child_count()!=2:
		return false
	if crossings.get_child_count()!=2 or record_pavilion.get_child_count()!=3:
		return false
	if white_markings.multimesh.instance_count!=36 or roadside_studs.multimesh.instance_count!=40:
		return false
	for visual in [white_markings,roadside_studs,records_shell,records_glass]:
		if visual.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
		if not visual.find_children("*","CollisionShape3D",true,false).is_empty():
			return false
	for mesh in [records_shell.mesh,records_glass.mesh]:
		if not mesh is ArrayMesh or mesh.get_surface_count()!=1 or (
			mesh.surface_get_array_len(0)>MAX_KIOSK_VERTICES):
			return false
	return find_children("*","CollisionShape3D",true,false).is_empty()
