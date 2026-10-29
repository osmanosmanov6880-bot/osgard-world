extends Node3D
## CITY REIGN R175 — observable real-economy consequences in the PLAYABLE city.
## Four genuine procedural 3D meters attached to the original city locations.
## Reads only original GameState inventories/energy/stability. NEVER simulates
## production, money, property ownership, NPCs or missions. No physics bodies.
const SITES = ["forum","housing","lower","aqueduct"]
const SITE_ANCHORS = {
	"forum":Vector3(-113.2,0.0,-130.0),
	"housing":Vector3(113.2,0.0,-130.0),
	"lower":Vector3(-113.2,0.0,130.0),
	"aqueduct":Vector3(113.2,0.0,130.0)
}
const SOURCE_COORDS = {
	"forum":Vector3(-130.0,0.0,-130.0),
	"housing":Vector3(130.0,0.0,-130.0),
	"lower":Vector3(-130.0,0.0,130.0),
	"aqueduct":Vector3(130.0,0.0,130.0)
}
const LABELS = {
	"ru":{"forum":"УСТОЙЧИВОСТЬ ГОРОДА","housing":"ТОВАРНЫЕ ЗАПАСЫ",
		"lower":"СКЛАД МАТЕРИАЛОВ","aqueduct":"ЭЛЕКТРОЭНЕРГИЯ",
		"live":"ФАКТИЧЕСКИЙ ПОКАЗАТЕЛЬ","low":"НИЗКИЙ УРОВЕНЬ"},
	"en":{"forum":"CITY STABILITY","housing":"GOODS INVENTORY",
		"lower":"MATERIALS STOCK","aqueduct":"GRID ENERGY",
		"live":"ACTUAL SAVED VALUE","low":"LOW LEVEL"},
	"zh":{"forum":"城市稳定度","housing":"商品库存",
		"lower":"材料库存","aqueduct":"电网能源",
		"live":"真实已存数据","low":"库存偏低"}
}
const MAX_CHILDREN: int = 12
const MAX_MESH_VERTICES: int = 520
const REVEAL_DISTANCE_M: float = 118.0
const ROAD_CENTRE_SPACING_M: float = 52.0
var foundations: Dictionary = {}
var rotors: Dictionary = {}
var captions: Dictionary = {}
var finishes: Dictionary = {}
var last_snapshot: Dictionary = {}
var graphic_tier: String = "standard"
var current_language: String = "ru"
var last_observer: Vector3 = Vector3.ZERO
var current_hour: float = 12.0
var current_energy: int = 100
var reduced_motion: bool = false
var visible_sites: int = 0
var ready_once: bool = false

static func value_for(state: Dictionary,id: String) -> Dictionary:
	if not SITES.has(id):
		return {}
	var saved_inventories: Variant = state.get("inventories",{})
	var stocks: Dictionary = saved_inventories if saved_inventories is Dictionary else {}
	var number: int = 0
	var level: float = 0.0
	var is_percent: bool = id=="forum" or id=="aqueduct"
	match id:
		"forum":
			number=clampi(int(state.get("stability",0)),0,100)
			level=float(number)/100.0
		"housing":
			number=maxi(0,int(stocks.get("goods",0)))
			level=clampf(float(number)/160.0,0.0,1.0)
		"lower":
			number=maxi(0,int(stocks.get("materials",0)))
			level=clampf(float(number)/160.0,0.0,1.0)
		"aqueduct":
			number=clampi(int(state.get("energy",0)),0,100)
			level=float(number)/100.0
	return {"id":id,"value":number,"normalized":level,
		"percent":is_percent,"low":number<25 if is_percent else number<20}

static func original_anchor_is_safe(id: String,at: Vector3) -> bool:
	if not SITES.has(id) or not at.is_finite(): return false
	var origin: Vector3=SOURCE_COORDS[id]
	# Each original city service landmark is a real 25 m square.
	# WorldBuilder's real roadbed has half width 5m; reserve >8m.
	if absf(at.x-origin.x)<14.3 and absf(at.z-origin.z)<14.3:
		return false
	var street_x: float=roundf(at.x/ROAD_CENTRE_SPACING_M)*ROAD_CENTRE_SPACING_M
	var street_z: float=roundf(at.z/ROAD_CENTRE_SPACING_M)*ROAD_CENTRE_SPACING_M
	if absf(at.x-street_x)<8.0 or absf(at.z-street_z)<8.0:
		return false
	return at.distance_to(origin)<26.0

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
		d: Vector3,pigment: Color) -> void:
	var normal: Vector3=(b-a).cross(c-a).normalized()
	for point in [a,b,c,a,c,d]:
		st.set_normal(normal)
		st.set_color(pigment)
		st.add_vertex(point)

static func _box(st: SurfaceTool,lo: Vector3,hi: Vector3,pigment: Color) -> void:
	var p: Array[Vector3]=[
		Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),
		Vector3(hi.x,lo.y,hi.z),Vector3(lo.x,lo.y,hi.z),
		Vector3(lo.x,hi.y,lo.z),Vector3(hi.x,hi.y,lo.z),
		Vector3(hi.x,hi.y,hi.z),Vector3(lo.x,hi.y,hi.z)]
	for indices in [[0,3,2,1],[4,5,6,7],[0,1,5,4],
			[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		_quad(st,p[indices[0]],p[indices[1]],
			p[indices[2]],p[indices[3]],pigment)

static func static_mesh(id: String) -> ArrayMesh:
	if not SITES.has(id): return null
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var graphite:=Color("41505b")
	var silver:=Color("adb9ba")
	var accent:=Color("cfad79") if id=="forum" else (
		Color("9bc5a5") if id=="housing" else (
		Color("d4a38e") if id=="lower" else Color("84cbd3")))
	# Heavy cast base and open 3D machine frame, no hidden texture plane.
	_box(st,Vector3(-0.94,0.14,-0.48),
		Vector3(0.94,0.35,0.48),graphite)
	for side in [-1.0,1.0]:
		var x: float=float(side)*0.73
		_box(st,Vector3(x-0.07,0.34,-0.23),
			Vector3(x+0.07,2.16,0.25),silver)
	_box(st,Vector3(-0.84,2.14,-0.30),
		Vector3(0.84,2.28,0.32),accent)
	_box(st,Vector3(-0.72,0.48,0.18),
		Vector3(0.72,0.61,0.26),accent)
	# Four physically distinct site silhouettes, recognizable without labels.
	match id:
		"forum":
			for i in range(3):
				var y: float=0.70+float(i)*0.44
				_box(st,Vector3(-0.67,y,-0.27),
					Vector3(-0.51+float(i)*0.13,y+0.19,-0.16),accent)
		"housing":
			for i in range(4):
				var x: float=-0.56+float(i)*0.34
				_box(st,Vector3(x,0.68,-0.28),
					Vector3(x+0.21,0.86+float(i%3)*0.22,-0.17),accent)
		"lower":
			for i in range(3):
				var y: float=0.66+float(i)*0.49
				_box(st,Vector3(-0.63,y,-0.30),
					Vector3(0.60,y+0.11,-0.15),accent)
		"aqueduct":
			for i in range(4):
				var y: float=0.68+float(i)*0.39
				_box(st,Vector3(-0.68,y,-0.31),
					Vector3(0.68,y+0.06,-0.18),accent)
	return st.commit()

static func rotor_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var metal:=Color("d0dbe0")
	var core:=Color("d7b079")
	_box(st,Vector3(-0.14,-0.14,-0.14),
		Vector3(0.14,0.14,0.14),core)
	# Original real 3D three-spoke measuring wheel, one reusable GPU mesh.
	for i in range(3):
		var angle: float=float(i)*TAU/3.0
		var tip: Vector2=Vector2(cos(angle),sin(angle))
		var side: Vector2=Vector2(-tip.y,tip.x)
		var midpoint: Vector2=tip*0.38
		var a: Vector2=midpoint-side*0.085
		var b: Vector2=midpoint+side*0.085
		_box(st,Vector3(minf(a.x,b.x)-0.04,minf(a.y,b.y)-0.04,-0.10),
			Vector3(maxf(a.x,b.x)+0.04,maxf(a.y,b.y)+0.04,0.10),metal)
		var end: Vector2=tip*0.58
		_box(st,Vector3(end.x-0.12,end.y-0.12,-0.12),
			Vector3(end.x+0.12,end.y+0.12,0.12),core)
	return st.commit()

func _ready() -> void:
	name="CityReignR175LiveEconomicPulse"
	var rotor_asset: ArrayMesh=rotor_mesh()
	for id in SITES:
		assert(original_anchor_is_safe(id,SITE_ANCHORS[id]),
			"R175 economic art may not block real buildings or streets")
		var structure:=MeshInstance3D.new()
		structure.name="EconomicFrame_"+id
		structure.mesh=static_mesh(id)
		structure.position=SITE_ANCHORS[id]
		structure.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=StandardMaterial3D.new()
		material.vertex_color_use_as_albedo=true
		material.albedo_color=Color("d2b691")
		material.metallic=0.42
		material.roughness=0.40
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		structure.material_override=material
		add_child(structure)
		foundations[id]=structure
		finishes[id]=material
		var wheel:=MeshInstance3D.new()
		wheel.name="LiveRotor_"+id
		wheel.mesh=rotor_asset
		wheel.position=SITE_ANCHORS[id]+Vector3(0.0,1.52,-0.35)
		wheel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wheel.material_override=material
		add_child(wheel)
		rotors[id]=wheel
		var words:=Label3D.new()
		words.name="EconomicReading_"+id
		words.position=SITE_ANCHORS[id]+Vector3(0.0,3.02,0.0)
		words.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		words.no_depth_test=false
		words.font_size=36
		words.pixel_size=0.007
		words.modulate=Color("e6eef2")
		words.outline_modulate=Color("111c25")
		add_child(words)
		captions[id]=words
	ready_once=true
	set_quality(graphic_tier)
	sync_state(GameState.data,GameState.locale)
	update_view(last_observer)

func sync_state(state: Dictionary,language: String) -> void:
	current_language=language if LABELS.has(language) else "ru"
	if not ready_once: return
	current_energy=clampi(int(state.get("energy",0)),0,100)
	var local: Dictionary=LABELS[current_language]
	for id in SITES:
		var indicator: Dictionary=value_for(state,id)
		last_snapshot[id]=indicator
		var value: int=indicator["value"]
		var display: String=str(value)+("%" if bool(indicator["percent"]) else "")
		var warning: String=" · "+str(local["low"]) if indicator["low"] else ""
		var words: Label3D=captions[id]
		words.text=str(local[id])+"\n"+str(local["live"])+": "+display+warning
		var severity: float=float(indicator["normalized"])
		var paint: StandardMaterial3D=finishes[id]
		paint.albedo_color=Color("c37465") if severity<0.18 else (
			Color("d1b17f") if severity<0.47 else Color("a7c2b4"))
		words.modulate=Color("f3b5a9") if severity<0.18 else Color("d8e5e6")
		# The same one native source rotor becomes physically less active when
		# the real stock/energy/stability falls. No invented production.
		var rotor: MeshInstance3D=rotors[id]
		rotor.scale=Vector3.ONE*(0.78+severity*0.30)
	update_ambience(current_hour,current_energy)

func set_quality(tier: String) -> void:
	graphic_tier=tier if ["low","standard","cinematic"].has(tier) else "standard"
	update_view(last_observer)
	update_ambience(current_hour,current_energy)

func set_reduced_motion(value: bool) -> void:
	reduced_motion=value
	_recompute_process()

func update_ambience(hour: float,energy: int) -> void:
	current_hour=fposmod(hour,24.0) if is_finite(hour) else 12.0
	current_energy=clampi(energy,0,100)
	if not ready_once: return
	var twilight: float=0.0
	if current_hour>=19.0 or current_hour<5.5: twilight=1.0
	elif current_hour>=17.0:
		twilight=clampf((current_hour-17.0)/2.0,0.0,1.0)
	elif current_hour<7.0:
		twilight=clampf((7.0-current_hour)/1.5,0.0,1.0)
	var brightness: float=twilight*clampf(float(current_energy)/60.0,0.0,1.0)
	for id in SITES:
		var mat: StandardMaterial3D=finishes[id]
		mat.emission_enabled=brightness>0.02 and graphic_tier!="low"
		mat.emission=Color("baac88")
		mat.emission_energy_multiplier=brightness*(0.18 if graphic_tier=="standard" else 0.33)

func update_view(focus: Vector3) -> void:
	if focus.is_finite(): last_observer=focus
	visible_sites=0
	for id in SITES:
		var at: Vector3=SITE_ANCHORS[id]
		var dx: float=last_observer.x-at.x
		var dz: float=last_observer.z-at.z
		var is_near: bool=graphic_tier!="low" and
			dx*dx+dz*dz<=REVEAL_DISTANCE_M*REVEAL_DISTANCE_M
		for element in [foundations.get(id),rotors.get(id),captions.get(id)]:
			if element is Node3D: (element as Node3D).visible=is_near
		if is_near: visible_sites+=1
	_recompute_process()

func _recompute_process() -> void:
	set_process(ready_once and not reduced_motion and
		graphic_tier!="low" and visible_sites>0)

func _process(delta: float) -> void:
	# Native original moving metal (not a video). No save/physics changes and
	# no array or mesh allocation in this loop; pauses for Reduced Motion.
	var frame_delta: float=clampf(delta,0.0,0.065)
	for id in SITES:
		var wheel: MeshInstance3D=rotors[id]
		if not wheel.visible: continue
		var reading: Dictionary=last_snapshot.get(id,{})
		var fill: float=clampf(float(reading.get("normalized",0.0)),0.0,1.0)
		if fill<0.05: continue
		wheel.rotation.z=fposmod(wheel.rotation.z+frame_delta*(0.13+fill*1.05),TAU)

func geometry_is_bounded() -> bool:
	if not ready_once or get_child_count()!=MAX_CHILDREN: return false
	if foundations.size()!=4 or rotors.size()!=4 or captions.size()!=4:
		return false
	for id in SITES:
		if not original_anchor_is_safe(id,SITE_ANCHORS[id]): return false
		var original: MeshInstance3D=foundations[id]
		var wheel: MeshInstance3D=rotors[id]
		if original.mesh==null or wheel.mesh==null: return false
		if original.mesh.get_surface_count()!=1 or wheel.mesh.get_surface_count()!=1:
			return false
		if original.mesh.surface_get_array_len(0)>MAX_MESH_VERTICES:
			return false
		if wheel.mesh.surface_get_array_len(0)>MAX_MESH_VERTICES:
			return false
		if original.get_child_count()!=0 or wheel.get_child_count()!=0:
			return false
		if original.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
	return true
