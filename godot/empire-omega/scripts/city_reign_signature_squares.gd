extends Node3D
## CITY REIGN A2: four unique source-authored real sculptural civic squares.
## Each distinctive solid 3D object is a ONE-drawcall ArrayMesh with colored
## surfaces; all are outside the original 25m city service building footprints
## and outside the 10m roadbeds. No StaticBody/Area/mission/reward overrides.
const SITES = {
	"cityhall": {"position":Vector3(-113.5,0.0,-113.5),
		"ru":"ПЛОЩАДЬ ЗАКОНА","en":"CIVIC FORUM","zh":"市政广场"},
	"market": {"position":Vector3(113.5,0.0,-113.5),
		"ru":"ТОРГОВАЯ ПЛОЩАДЬ","en":"MARKET PLAZA","zh":"商业广场"},
	"depot": {"position":Vector3(-113.5,0.0,113.5),
		"ru":"ГРУЗОВОЙ УЗЕЛ","en":"LOGISTICS EXCHANGE","zh":"物流枢纽"},
	"power": {"position":Vector3(113.5,0.0,113.5),
		"ru":"ЭНЕРГОУЗЕЛ","en":"ENERGY COMMONS","zh":"能源中心"}
}
const MAX_SITES: int = 4
const ACCENTS_PER_SITE: int = 3
var sites: Dictionary = {}
var site_labels: Dictionary = {}
var accent: MultiMeshInstance3D
var accent_finish: StandardMaterial3D
var quality: String = "standard"
var current_language: String = "ru"
var last_power: int = 100
var last_hour: float = 12.0

static func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
	st.set_color(tint)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color) -> void:
	_triangle(st,a,b,c,tint)
	_triangle(st,a,c,d,tint)

static func _box(st: SurfaceTool,center: Vector3,half: Vector3,tint: Color) -> void:
	var p: Vector3 = center-half
	var q: Vector3 = center+half
	var a := Vector3(p.x,p.y,p.z)
	var b := Vector3(q.x,p.y,p.z)
	var c := Vector3(q.x,p.y,q.z)
	var d := Vector3(p.x,p.y,q.z)
	var e := Vector3(p.x,q.y,p.z)
	var f := Vector3(q.x,q.y,p.z)
	var g := Vector3(q.x,q.y,q.z)
	var h := Vector3(p.x,q.y,q.z)
	_quad(st,a,b,c,d,tint)
	_quad(st,e,h,g,f,tint)
	_quad(st,a,e,f,b,tint)
	_quad(st,b,f,g,c,tint)
	_quad(st,a,d,h,e,tint)
	_quad(st,d,c,g,h,tint)

static func authored_geometry(site_id: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mineral := Color("aeb8b6")
	var stone := Color("8e9da5")
	var deep := Color("233946")
	var brass := Color("b79d73")
	var steel := Color("697e87")
	var aqua := Color("5caaa8")
	# Plinth is always a physically modelled mineral object, not a decal.
	_box(st,Vector3(0,0.19,0),Vector3(2.42,0.18,2.42),deep)
	match site_id:
		"cityhall":
			# The Charter: civic portal and four carved architrave members.
			for x in [-1.50,1.50]:
				_box(st,Vector3(float(x),2.35,0),Vector3(0.27,2.15,0.51),mineral)
				_box(st,Vector3(float(x),4.64,0),Vector3(0.48,0.25,0.66),brass)
			_box(st,Vector3(0,4.79,0),Vector3(2.01,0.30,0.64),mineral)
			_box(st,Vector3(0,3.24,0),Vector3(0.43,1.18,0.14),aqua)
			for x in [-0.82,0.82]:
				_box(st,Vector3(float(x),1.02,-0.51),Vector3(0.14,0.64,0.11),brass)
		"market":
			# The Exchange: rising retail canopy + crossed market arch.
			for x in [-1.60,1.60]:
				_box(st,Vector3(float(x),2.13,0),Vector3(0.24,1.91,0.36),stone)
			_box(st,Vector3(0,4.17,0),Vector3(2.28,0.24,1.55),mineral)
			_box(st,Vector3(0,4.49,0),Vector3(1.43,0.08,1.20),aqua)
			for z in [-1.0,1.0]:
				_box(st,Vector3(0,2.26,float(z)),Vector3(1.22,0.095,0.12),brass)
			_box(st,Vector3(0,1.61,-0.20),Vector3(0.62,1.30,0.16),deep)
		"depot":
			# The Gantry: honest freight engineering silhouette, not an obelisk.
			for x in [-1.64,1.64]:
				_box(st,Vector3(float(x),2.35,0),Vector3(0.22,2.13,0.34),steel)
				_box(st,Vector3(float(x),0.66,0),Vector3(0.44,0.26,0.51),mineral)
			_box(st,Vector3(0,4.61,0),Vector3(2.05,0.22,0.43),brass)
			for z in [-0.86,0.86]:
				_box(st,Vector3(0,3.55,float(z)),Vector3(1.79,0.10,0.15),steel)
			_box(st,Vector3(0,2.07,-0.55),Vector3(0.89,0.75,0.48),deep)
		"power":
			# Energy commons: twin converter masts and equipment bridge.
			for x in [-1.37,1.37]:
				_box(st,Vector3(float(x),2.38,0),Vector3(0.35,2.11,0.35),stone)
				_box(st,Vector3(float(x),4.48,0),Vector3(0.52,0.12,0.51),aqua)
				_box(st,Vector3(float(x),1.04,0),Vector3(0.59,0.60,0.51),steel)
			_box(st,Vector3(0,3.71,0),Vector3(1.33,0.19,0.21),brass)
			for x in [-0.48,0.48]:
				_box(st,Vector3(float(x),1.51,-0.76),Vector3(0.29,1.03,0.22),aqua)
		_:
			_box(st,Vector3(0,1.0,0),Vector3(0.3,0.7,0.3),stone)
	st.generate_normals()
	return st.commit()

func _ready() -> void:
	name = "CityReignFourDistinctCivicSquares"
	for site_id in SITES:
		var spec: Dictionary = SITES[site_id]
		var holder := Node3D.new()
		holder.name = "CivicSquare_" + site_id
		holder.position = spec["position"]
		add_child(holder)
		var solid := MeshInstance3D.new()
		solid.name = "OriginalSculpted_" + site_id
		solid.mesh = authored_geometry(site_id)
		solid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color.WHITE
		mat.metallic = 0.29
		mat.roughness = 0.45
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		solid.material_override = mat
		holder.add_child(solid)
		var title := Label3D.new()
		title.name = "CivicSquareName"
		title.position = Vector3(0,5.83,0)
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.font_size = 40
		title.pixel_size = 0.008
		title.modulate = Color("e3d3af")
		holder.add_child(title)
		sites[site_id] = holder
		site_labels[site_id] = title
	_create_accent_batch()
	sync_language(current_language)
	set_quality(quality)
	sync_ambience(last_hour,last_power)

func _create_accent_batch() -> void:
	var bar := BoxMesh.new()
	bar.size = Vector3.ONE
	var grid := MultiMesh.new()
	grid.transform_format = MultiMesh.TRANSFORM_3D
	grid.use_colors = true
	grid.mesh = bar
	grid.instance_count = MAX_SITES*ACCENTS_PER_SITE
	var i: int = 0
	for site_id in SITES:
		var here: Vector3 = SITES[site_id]["position"]
		for step in range(ACCENTS_PER_SITE):
			var offset: float = float(step-1)*1.18
			grid.set_instance_transform(i,Transform3D(
				Basis().scaled(Vector3(0.66,0.08,0.10)),
				here+Vector3(offset,0.47,-2.15)))
			grid.set_instance_color(i,Color("c5a777") if site_id == "cityhall" or site_id == "depot" else Color("82c1bd"))
			i += 1
	accent = MultiMeshInstance3D.new()
	accent.name = "CivicSquareNightWayfinding"
	accent.multimesh = grid
	accent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	accent.custom_aabb = AABB(Vector3(-120.0,0.0,-120.0),Vector3(240.0,8.0,240.0))
	accent_finish = StandardMaterial3D.new()
	accent_finish.vertex_color_use_as_albedo = true
	accent_finish.albedo_color = Color.WHITE
	accent_finish.metallic = 0.20
	accent_finish.roughness = 0.40
	accent.material_override = accent_finish
	add_child(accent)

func sync_language(lang: String) -> void:
	current_language = lang if ["ru","en","zh"].has(lang) else "ru"
	for id in site_labels:
		var title: Label3D = site_labels[id]
		title.text = str(SITES[id][current_language])

func set_quality(tier: String) -> void:
	quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	for id in sites:
		(sites[id] as Node3D).visible = quality != "low"
	if accent != null:
		accent.visible = quality == "cinematic"
	sync_ambience(last_hour,last_power)

func sync_ambience(hour: float,power: int) -> void:
	last_hour = hour
	last_power = clampi(power,0,100)
	if accent_finish == null: return
	var night: float = 0.0
	if is_finite(hour):
		var h: float = fposmod(hour,24.0)
		if h >= 19.5 or h < 5.5: night = 1.0
		elif h >= 17.5: night = clampf((h-17.5)/2.0,0.0,1.0)
		elif h < 7.0: night = clampf((7.0-h)/1.5,0.0,1.0)
	var glow: float = night*clampf(float(last_power)/50.0,0.0,1.0)
	glow *= 0.65 if quality == "cinematic" else 0.0
	accent_finish.emission_enabled = glow > 0.001
	accent_finish.emission = Color("e8ca96")
	accent_finish.emission_energy_multiplier = glow

func graphics_are_bounded() -> bool:
	if sites.size() != MAX_SITES or site_labels.size() != MAX_SITES:
		return false
	if accent == null or accent.multimesh.instance_count != MAX_SITES*ACCENTS_PER_SITE:
		return false
	for id in sites:
		var root_node: Node3D = sites[id]
		var mesh: MeshInstance3D = root_node.get_node_or_null("OriginalSculpted_"+id) as MeshInstance3D
		var title: Label3D = site_labels[id]
		if mesh == null or not (mesh.mesh is ArrayMesh) or title == null:
			return false
		if root_node.find_children("*","CollisionShape3D",true,false).size() != 0:
			return false
		if not root_node.position.is_finite():
			return false
	return true
