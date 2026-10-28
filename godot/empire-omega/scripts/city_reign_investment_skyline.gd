extends Node3D
## CITY REIGN AAA B27: 12 REAL paid construction identities in the ACTUAL city.
## The source WorldBuilder's existing 12 building StaticBody3D colliders,
## four upgrade levels, project ownership and GameState.build() are untouched.
## This read-only source art adds exactly one mesh renderer per built lot.
## Each original municipal tower gets 4 architecturally distinct REAL meshes.
## Zero imported meshes, external images, shadows, new collisions or save keys.
const ORDER = ["council","clinic","academy","homes","gardens","school",
	"market","factory","depot","plant","purifier","reservoir"]
const DISTRICTS = ["forum","housing","lower","aqueduct"]
const MAX_TOWERS: int = 12
const MAX_LEVEL: int = 4
const MAX_CACHE: int = 48
const MAX_VERTICES_PER_TOWER: int = 7000
const BASE_WIDTH: float = 7.55
const LEVEL_HEIGHT: float = 8.0
const HEIGHT_BASE: float = 6.0
const STONE = Color("aaa9a1")
const CHALK = Color("d5c6ae")
const TITANIUM = Color("586d78")
const GLASS = Color("396875")
const BRONZE = Color("c1a278")
const EMERALD = Color("39887b")
const BRICK = Color("a17a69")
const DARK = Color("283845")
const DISTRICT_PALETTE = {
	"forum":Color("b9b5ab"),
	"housing":Color("a6b9b3"),
	"lower":Color("8e969b"),
	"aqueduct":Color("9cb9b9")
}

var sites: Dictionary = {}
var facades: Dictionary = {}
var levels: Dictionary = {}
var _cache: Dictionary = {}
var _finish: Dictionary = {}
var quality: String = "standard"

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color) -> void:
	st.set_color(tint)
	for v in [a,b,c,a,c,d]:
		st.add_vertex(v)

static func _box(st: SurfaceTool,mid: Vector3,half: Vector3,tint: Color) -> void:
	var p: Vector3 = mid-half
	var q: Vector3 = mid+half
	_quad(st,Vector3(p.x,p.y,p.z),Vector3(q.x,p.y,p.z),
		Vector3(q.x,q.y,p.z),Vector3(p.x,q.y,p.z),tint)
	_quad(st,Vector3(q.x,p.y,q.z),Vector3(p.x,p.y,q.z),
		Vector3(p.x,q.y,q.z),Vector3(q.x,q.y,q.z),tint)
	_quad(st,Vector3(p.x,p.y,q.z),Vector3(p.x,p.y,p.z),
		Vector3(p.x,q.y,p.z),Vector3(p.x,q.y,q.z),tint)
	_quad(st,Vector3(q.x,p.y,p.z),Vector3(q.x,p.y,q.z),
		Vector3(q.x,q.y,q.z),Vector3(q.x,q.y,p.z),tint)
	_quad(st,Vector3(p.x,q.y,p.z),Vector3(q.x,q.y,p.z),
		Vector3(q.x,q.y,q.z),Vector3(p.x,q.y,q.z),tint)
	_quad(st,Vector3(p.x,p.y,q.z),Vector3(q.x,p.y,q.z),
		Vector3(q.x,p.y,p.z),Vector3(p.x,p.y,p.z),tint)

static func _tube(st: SurfaceTool,center: Vector3,radius: float,height: float,
		tint: Color,segments: int = 12) -> void:
	# ORIGINAL twelve-segment fully closed physical tank/turbine geometry.
	for i in range(segments):
		var a: float = float(i)*TAU/float(segments)
		var b: float = float(i+1)*TAU/float(segments)
		var q0 := Vector3(cos(a)*radius,0.0,sin(a)*radius)
		var q1 := Vector3(cos(b)*radius,0.0,sin(b)*radius)
		var bottom: Vector3 = center+Vector3(0,-height*0.5,0)
		var top: Vector3 = center+Vector3(0,height*0.5,0)
		_quad(st,bottom+q0,bottom+q1,top+q1,top+q0,tint)
		st.set_color(tint)
		for v in [top,top+q1,top+q0,bottom,bottom+q0,bottom+q1]:
			st.add_vertex(v)

static func _identity(st: SurfaceTool,id: String,height: float,level: int) -> void:
	# Every one of the twelve original funded municipal services has an
	# unmistakable silhouette that ACTUALLY changes when its saved level grows.
	match id:
		"council":
			for x in [-5.9,-2.0,2.0,5.9]:
				_box(st,Vector3(float(x),height*0.50,-7.88),
					Vector3(0.40,height*0.42,0.38),CHALK)
			_box(st,Vector3(0,height-1.6,-8.10),Vector3(7.1,0.35,0.43),BRONZE)
			# Actual Chromium proof exposed an oversized solid cyan panel:
			# it completely occluded the civic entrance. Replace that flat
			# rectangle with three separated true stone-mullion glass bays,
			# an inset central dark door, bronze handles and stepped lintel.
			# Source colored glass stays PBR/opaque but is no longer a wall.
			for x in [-3.2,0.0,3.2]:
				_box(st,Vector3(float(x),4.25,-8.13),
					Vector3(0.92,2.64,0.10),GLASS)
				_box(st,Vector3(float(x),7.00,-8.18),
					Vector3(1.13,0.14,0.18),BRONZE)
			for x in [-1.60,1.60]:
				_box(st,Vector3(float(x),4.38,-8.27),
					Vector3(0.14,3.21,0.14),CHALK)
			_box(st,Vector3(0,2.65,-8.40),
				Vector3(1.14,1.81,0.07),DARK)
			for x in [-0.62,0.62]:
				_box(st,Vector3(float(x),2.30,-8.49),
					Vector3(0.045,0.44,0.055),BRONZE)
			_box(st,Vector3(0,7.46,-8.23),Vector3(4.90,0.26,0.41),STONE)
			_box(st,Vector3(0,height+0.62,0),Vector3(5.8,0.38,5.5),CHALK)
		"clinic":
			_box(st,Vector3(0,height*0.58,-8.02),
				Vector3(1.0,2.35,0.14),EMERALD)
			_box(st,Vector3(0,height*0.58,-8.17),
				Vector3(2.40,0.82,0.16),EMERALD)
			for x in [-5.5,5.5]:
				_box(st,Vector3(float(x),height+0.64,0),
					Vector3(0.30,0.52,5.6),CHALK)
			_box(st,Vector3(0,height+0.72,0),Vector3(5.9,0.18,5.3),GLASS)
		"academy":
			for x in [-5.5,5.5]:
				_box(st,Vector3(float(x),height+1.25,-4.5),
					Vector3(1.35,1.18,1.20),STONE)
				_box(st,Vector3(float(x),height+2.30,-4.5),
					Vector3(1.48,0.14,1.38),BRONZE)
			_box(st,Vector3(0,height-0.8,-8.08),Vector3(5.8,0.35,0.38),BRONZE)
		"homes":
			for f in range(level+1):
				var y: float = 3.15+float(f)*7.60
				for x in [-4.9,0.0,4.9]:
					_box(st,Vector3(float(x),y,-8.00),
						Vector3(1.22,0.15,1.50),CHALK)
					_box(st,Vector3(float(x),y+0.48,-9.10),
						Vector3(1.23,0.46,0.11),TITANIUM)
		"gardens":
			for x in [-5.3,0.0,5.3]:
				_box(st,Vector3(float(x),height+0.54,-3.5),
					Vector3(1.62,0.42,2.4),STONE)
				_box(st,Vector3(float(x),height+0.96,-3.5),
					Vector3(1.42,0.40,2.0),EMERALD)
			_box(st,Vector3(0,3.30,-8.10),Vector3(6.9,0.15,0.6),EMERALD)
		"school":
			for x in [-6.0,6.0]:
				_box(st,Vector3(float(x),height+1.35,-5.5),
					Vector3(0.26,1.26,0.28),STONE)
				_box(st,Vector3(float(x),height+2.44,-5.5),
					Vector3(0.56,0.20,0.46),BRONZE)
			_box(st,Vector3(0,height+2.47,-5.5),Vector3(6.3,0.12,0.32),CHALK)
			_box(st,Vector3(0,3.28,-8.10),Vector3(3.4,2.7,0.10),GLASS)
		"market":
			_box(st,Vector3(0,7.3,-8.65),Vector3(7.1,0.26,1.58),BRONZE)
			for x in [-6.6,-2.1,2.1,6.6]:
				_box(st,Vector3(float(x),4.9,-8.05),
					Vector3(0.17,4.6,0.14),TITANIUM)
			_box(st,Vector3(0,height+0.45,0),Vector3(6.8,0.38,6.6),GLASS)
		"factory":
			for x in [-4.8,4.8]:
				_tube(st,Vector3(float(x),height+1.95,0),0.91,3.8,TITANIUM)
				_tube(st,Vector3(float(x),height+3.65,0),1.08,0.25,BRONZE)
			for y in [4.8,9.3]:
				_box(st,Vector3(0,float(y),-8.03),Vector3(7.05,0.18,0.32),DARK)
		"depot":
			for x in [-6.3,6.3]:
				_box(st,Vector3(float(x),height+1.16,-4.0),
					Vector3(0.37,1.08,3.0),BRONZE)
			_box(st,Vector3(0,height+2.22,-4.0),Vector3(6.65,0.28,3.0),TITANIUM)
			for x in [-5.0,0.0,5.0]:
				_box(st,Vector3(float(x),3.10,-7.99),Vector3(1.42,2.54,0.12),GLASS)
		"plant":
			for x in [-4.5,4.5]:
				_tube(st,Vector3(float(x),height+1.50,-1.0),1.72,2.8,TITANIUM)
				_tube(st,Vector3(float(x),height+2.86,-1.0),1.80,0.20,BRONZE)
			_box(st,Vector3(0,height+0.95,-1.0),Vector3(3.5,0.25,0.38),EMERALD)
		"purifier":
			for x in [-4.5,0.0,4.5]:
				_tube(st,Vector3(float(x),height+1.33,-0.8),1.06,2.4,STONE)
				_tube(st,Vector3(float(x),height+2.60,-0.8),1.22,0.16,EMERALD)
			_box(st,Vector3(0,height+0.28,-4.1),Vector3(6.2,0.26,0.34),TITANIUM)
		"reservoir":
			for x in [-4.4,4.4]:
				_tube(st,Vector3(float(x),height+1.15,0),2.25,2.2,GLASS)
				_tube(st,Vector3(float(x),height+2.34,0),2.40,0.18,BRONZE)
			_box(st,Vector3(0,height+0.32,-5.2),Vector3(6.7,0.15,0.18),EMERALD)

static func original_tower_mesh(id: String,level: int) -> ArrayMesh:
	if not ORDER.has(id) or level<1 or level>MAX_LEVEL:
		return null
	var height: float = HEIGHT_BASE+float(level)*LEVEL_HEIGHT
	var district: String = _district_for(id)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall: Color = DISTRICT_PALETTE[district]
	# All facades sit outside the saved 15m original collision box by
	# only 0.05-0.20m, with no physical walking/driving hazard.
	_box(st,Vector3(0,0.68,-7.66),Vector3(7.35,0.35,0.14),BRONZE)
	for x in [-7.49,7.49]:
		_box(st,Vector3(float(x),height*0.5,-7.57),
			Vector3(0.17,height*0.47,0.19),STONE)
		_box(st,Vector3(float(x),height*0.5,7.57),
			Vector3(0.17,height*0.47,0.19),wall)
	for z in [-7.49,7.49]:
		_box(st,Vector3(-7.57,height*0.5,float(z)),
			Vector3(0.19,height*0.47,0.17),wall)
		_box(st,Vector3(7.57,height*0.5,float(z)),
			Vector3(0.19,height*0.47,0.17),STONE)
	for f in range(level+1):
		var y: float = 4.30+float(f)*7.50
		for x in [-5.15,-1.65,1.85,5.35]:
			_box(st,Vector3(float(x),y,-7.64),Vector3(1.20,1.30,0.085),GLASS)
			_box(st,Vector3(float(x),y,7.64),Vector3(1.20,1.30,0.085),GLASS)
			_box(st,Vector3(float(x),y-1.45,-7.78),Vector3(1.48,0.10,0.11),BRONZE)
			_box(st,Vector3(float(x),y+1.40,-7.78),Vector3(1.48,0.10,0.11),TITANIUM)
		for z in [-5.15,-1.65,1.85,5.35]:
			_box(st,Vector3(-7.64,y,float(z)),Vector3(0.085,1.21,1.16),GLASS)
			_box(st,Vector3(7.64,y,float(z)),Vector3(0.085,1.21,1.16),GLASS)
		for z in [-7.54,7.54]:
			_box(st,Vector3(0,y-2.10,float(z)),Vector3(7.25,0.14,0.17),wall)
	_box(st,Vector3(0,height+0.16,0),Vector3(7.30,0.26,7.30),BRONZE)
	for x in [-6.8,6.8]:
		_box(st,Vector3(float(x),height-0.3,0),Vector3(0.22,0.76,7.25),DARK)
	_identity(st,id,height,level)
	st.generate_normals()
	return st.commit()

static func _district_for(id: String) -> String:
	if ["council","clinic","academy"].has(id):
		return "forum"
	if ["homes","gardens","school"].has(id):
		return "housing"
	if ["market","factory","depot"].has(id):
		return "lower"
	return "aqueduct"

static func _make_material(district: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.metallic = 0.28 if district=="forum" else 0.36
	m.roughness = 0.51 if district=="housing" else 0.43
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func configure(real_sites: Dictionary) -> void:
	assert(sites.is_empty() and not is_inside_tree())
	for id in ORDER:
		assert(real_sites.has(id))
		var spec: Dictionary = real_sites[id]
		var district: String = _district_for(id)
		assert(str(spec.get("district",""))==district)
		var point: Vector3 = spec["position"]
		assert(point.is_finite() and absf(point.x)<=209.0 and
			absf(point.z)<=209.0)
		var holder := MeshInstance3D.new()
		holder.name = "ActuallyPurchased_"+id
		holder.position = point
		holder.visible = false
		holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not _finish.has(district):
			_finish[district] = _make_material(district)
		holder.material_override = _finish[district]
		add_child(holder)
		sites[id] = spec.duplicate(true)
		facades[id] = holder
		levels[id] = 0
	name = "CityReignTwelvePaid3DBuildings"

func sync_state(state: Dictionary) -> void:
	var owned: Variant = state.get("buildings",{})
	if not (owned is Dictionary):
		return
	for id in ORDER:
		if not facades.has(id):
			return
		var level: int = clampi(int(owned.get(id,0)),0,MAX_LEVEL)
		var facade: MeshInstance3D = facades[id]
		if level!=int(levels[id]):
			if level>0:
				var key: String = id+"@"+str(level)
				if not _cache.has(key):
					assert(_cache.size()<MAX_CACHE)
					_cache[key] = original_tower_mesh(id,level)
				facade.mesh = _cache[key]
			levels[id]=level
		facade.visible = level>0 and quality!="low"

func set_quality(tier: String) -> void:
	quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	for id in ORDER:
		if facades.has(id):
			(facades[id] as MeshInstance3D).visible = (
				int(levels[id])>0 and quality!="low")

func geometry_is_bounded() -> bool:
	if (sites.size()!=MAX_TOWERS or facades.size()!=MAX_TOWERS or
		levels.size()!=MAX_TOWERS or get_child_count()!=MAX_TOWERS):
		return false
	if _finish.size()!=DISTRICTS.size() or _cache.size()>MAX_CACHE:
		return false
	if not find_children("*","CollisionShape3D",true,false).is_empty():
		return false
	for id in ORDER:
		var visual: MeshInstance3D = facades[id]
		if (visual==null or visual.get_parent()!=self or
			visual.position!=sites[id]["position"]):
			return false
		if visual.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
		if int(levels[id])>0:
			if not visual.mesh is ArrayMesh:
				return false
			var n: int = visual.mesh.surface_get_array_len(0)
			if n<200 or n>MAX_VERTICES_PER_TOWER:
				return false
	return true
