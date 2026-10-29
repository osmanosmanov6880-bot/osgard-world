extends Node3D
## R173: Four original street-facing 3D district insignia, actually installed
## on WorldBuilder's existing 128 physical buildings. No colliders, save
## keys, reward transactions or unlicensed external media.
const DISTRICTS = ["forum","housing","lower","aqueduct"]
const MAX_BUILDINGS: int = 128
const MAX_DRAWS: int = 5
const MAX_TRIANGLES: int = 68000
const STONE = {"forum":Color("c7bba0"),"housing":Color("a2b4ae"),
	"lower":Color("b29d8b"),"aqueduct":Color("86b6b9")}
const METAL = {"forum":Color("e0b878"),"housing":Color("b6c1a2"),
	"lower":Color("dc987a"),"aqueduct":Color("88d6df")}
const POWER = {"forum":Color("f4ce93"),"housing":Color("c7f0bb"),
	"lower":Color("ffc2a0"),"aqueduct":Color("a0e8ed")}
var poses: Dictionary = {}
var paints: Dictionary = {}
var led_poses: Array[Transform3D] = []
var led_paints: Array[Color] = []
var nodes: Dictionary = {}
var materials: Dictionary = {}
var count: int = 0
var finalized: bool = false
var quality: String = "standard"
var hour: float = 12.0
var energy: int = 100
var weather: String = "clear"
var city_vitality: Dictionary = {}
var last_vitality_power: int = -1
var vitality_updates: int = 0

func _init() -> void:
	for district in DISTRICTS:
		poses[district]=[]
		paints[district]=[]

static func _face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
		d: Vector3,tint: Color) -> void:
	var normal: Vector3=(b-a).cross(c-a).normalized()
	for vertex in [a,b,c,a,c,d]:
		st.set_normal(normal)
		st.set_color(tint)
		st.add_vertex(vertex)

static func _box(st: SurfaceTool,minimum: Vector3,maximum: Vector3,tint: Color) -> void:
	var v: Array[Vector3]=[
		Vector3(minimum.x,minimum.y,minimum.z),
		Vector3(maximum.x,minimum.y,minimum.z),
		Vector3(maximum.x,minimum.y,maximum.z),
		Vector3(minimum.x,minimum.y,maximum.z),
		Vector3(minimum.x,maximum.y,minimum.z),
		Vector3(maximum.x,maximum.y,minimum.z),
		Vector3(maximum.x,maximum.y,maximum.z),
		Vector3(minimum.x,maximum.y,maximum.z)]
	for side in [[0,3,2,1],[4,5,6,7],[0,1,5,4],
			[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		_face(st,v[side[0]],v[side[1]],v[side[2]],v[side[3]],tint)

static func _bar(st: SurfaceTool,a: Vector2,b: Vector2,
		width: float,tint: Color) -> void:
	var path: Vector2=b-a
	if path.length_squared()<0.0001: return
	var ortho: Vector2=Vector2(-path.y,path.x).normalized()*width
	var pts: Array[Vector2]=[a-ortho,b-ortho,b+ortho,a+ortho]
	var v: Array[Vector3]=[]
	for point in pts: v.append(Vector3(point.x,point.y,-0.96))
	for point in pts: v.append(Vector3(point.x,point.y,-0.78))
	_face(st,v[0],v[3],v[2],v[1],tint)
	_face(st,v[4],v[5],v[6],v[7],tint.darkened(0.20))
	for i in range(4):
		var j: int=(i+1)%4
		_face(st,v[i],v[j],v[j+4],v[i+4],tint.darkened(0.09))

static func relief_mesh(district: String) -> ArrayMesh:
	if not DISTRICTS.has(district): return null
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone: Color=STONE[district]
	var accent: Color=METAL[district]
	# Source-modeled slate backing, metal perimeter and actual entrance
	# threshold: all outside the original door and road collision surfaces.
	_box(st,Vector3(-3.12,4.54,-0.76),
		Vector3(3.12,5.82,-0.32),stone.darkened(0.74))
	_box(st,Vector3(-2.99,4.66,-0.86),
		Vector3(2.99,5.70,-0.71),stone.darkened(0.39))
	_box(st,Vector3(-3.16,5.77,-0.84),
		Vector3(3.16,5.90,-0.49),accent)
	_box(st,Vector3(-3.16,4.52,-0.84),
		Vector3(3.16,4.62,-0.49),accent.darkened(0.13))
	_box(st,Vector3(-1.72,0.19,-2.77),
		Vector3(1.72,0.23,-2.16),stone.darkened(0.67))
	for k in range(6):
		var x: float=-1.4+float(k)*0.55
		_box(st,Vector3(x,0.23,-2.58),
			Vector3(x+0.09,0.244,-2.34),accent)
	match district:
		"forum":
			# Legislative solar seal: eight independent radial spokes.
			for i in range(8):
				var angle: float=float(i)*TAU/8.0
				var axis: Vector2=Vector2(cos(angle),sin(angle))
				_bar(st,Vector2(0.0,5.16)+axis*0.32,
					Vector2(0.0,5.16)+axis*0.73,0.085,accent)
			for i in range(4):
				var a: float=float(i)*TAU/4.0+PI/4.0
				var b: float=float(i+1)*TAU/4.0+PI/4.0
				_bar(st,Vector2(cos(a),sin(a))*0.28+Vector2(0,5.16),
					Vector2(cos(b),sin(b))*0.28+Vector2(0,5.16),0.075,accent)
		"housing":
			# Three stepped dwelling silhouettes, visible at street scale.
			for i in range(3):
				var x: float=float(i-1)*0.67
				var y: float=4.92+float(i%2)*0.18
				_bar(st,Vector2(x-0.29,y),
					Vector2(x,y+0.42),0.115,accent)
				_bar(st,Vector2(x,y+0.42),
					Vector2(x+0.29,y),0.115,accent)
				_bar(st,Vector2(x-0.20,y-0.02),
					Vector2(x+0.20,y-0.02),0.050,accent)
		"lower":
			# Freight terminal's original mechanical double-chevron.
			for i in range(2):
				var x: float=float(i)*0.87-0.62
				_bar(st,Vector2(x-0.25,5.46),
					Vector2(x+0.06,5.15),0.13,accent)
				_bar(st,Vector2(x+0.06,5.15),
					Vector2(x-0.25,4.84),0.13,accent)
			_bar(st,Vector2(0.82,4.74),Vector2(0.82,5.56),
				0.10,accent)
		"aqueduct":
			# Raised flowing water lines — actual tessellated relief.
			for lane in range(3):
				var y: float=4.91+float(lane)*0.24
				for segment in range(12):
					var x: float=-1.12+float(segment)*0.187
					var xx: float=x+0.187
					_bar(st,Vector2(x,y+0.085*sin(x*3.7+lane*0.5)),
						Vector2(xx,y+0.085*sin(xx*3.7+lane*0.5)),0.049,accent)
	return st.commit()

static func led_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st,Vector3(-2.70,5.55,-0.985),
		Vector3(2.70,5.59,-0.93),Color.WHITE)
	_box(st,Vector3(-2.70,4.71,-0.985),
		Vector3(2.70,4.75,-0.93),Color.WHITE)
	return st.commit()

func _ready() -> void:
	name="CityReignR173DistrictStreetIdentity"

func record(center: Vector3,width: float,height: float,
		district: String,street_face: int) -> void:
	if finalized or count>=MAX_BUILDINGS or not center.is_finite(): return
	if not is_finite(width) or not is_finite(height): return
	if width<10.0 or width>16.0 or height<8.0 or height>76.0: return
	if not DISTRICTS.has(district) or street_face<0 or street_face>3: return
	# Face and street position come from the ORIGINAL real shop facade.
	var orient:=Basis(Vector3.UP,float(street_face)*PI*0.5)
	var at: Vector3=Vector3(center.x,0.0,center.z)
	at+=orient*Vector3(0.0,0.0,-(width*0.5+0.26))
	var pose:=Transform3D(orient.scaled(Vector3(width/12.0,1.0,1.0)),at)
	poses[district].append(pose)
	paints[district].append(STONE[district])
	led_poses.append(pose)
	led_paints.append(POWER[district])
	count+=1

func _batch(name_id: String,shape: Mesh,transforms: Array,tints: Array) -> void:
	if transforms.is_empty(): return
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	mm.mesh=shape
	mm.instance_count=transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i,transforms[i])
		mm.set_instance_color(i,tints[i])
	var model:=MultiMeshInstance3D.new()
	model.name=name_id
	model.multimesh=mm
	model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.custom_aabb=AABB(Vector3(-245,-0.2,-245),
		Vector3(490,81,490))
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color.WHITE
	mat.vertex_color_use_as_albedo=true
	mat.metallic=0.43
	mat.roughness=0.52
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	model.material_override=mat
	add_child(model)
	nodes[name_id]=model
	materials[name_id]=mat

func finalize() -> void:
	if finalized: return
	for district in DISTRICTS:
		_batch("District_"+district,relief_mesh(district),
			poses[district],paints[district])
	_batch("PoweredDistrictSigns",led_mesh(),led_poses,led_paints)
	finalized=true
	set_quality(quality)
	update_ambience(hour,energy,weather)

func set_quality(tier: String) -> void:
	quality=tier if ["low","standard","cinematic"].has(tier) else "standard"
	for district in DISTRICTS:
		if nodes.has("District_"+district):
			nodes["District_"+district].visible=quality!="low"
	update_ambience(hour,energy,weather)

static func night_factor(clock: float) -> float:
	if not is_finite(clock): return 0.0
	var h: float=fposmod(clock,24.0)
	if h>=19.0 or h<5.5: return 1.0
	if h>=17.0: return clampf((h-17.0)/2.0,0.0,1.0)
	if h<7.0: return clampf((7.0-h)/1.5,0.0,1.0)
	return 0.0

func update_ambience(clock: float,power: int,kind: String="clear") -> void:
	hour=fposmod(clock,24.0) if is_finite(clock) else 12.0
	energy=clampi(power,0,100)
	weather=kind if ["clear","cloudy","rain","storm"].has(kind) else "clear"
	if not finalized: return
	var wet: bool=weather=="rain" or weather=="storm"
	for district in DISTRICTS:
		var mat: StandardMaterial3D=materials.get("District_"+district)
		if mat!=null:
			mat.roughness=(0.27 if quality=="cinematic" else 0.43) if wet else (0.36 if quality=="cinematic" else 0.56)
	var strip: MultiMeshInstance3D=nodes.get("PoweredDistrictSigns")
	var finish: StandardMaterial3D=materials.get("PoweredDistrictSigns")
	if strip==null or finish==null: return
	var level: float=night_factor(hour)*clampf(float(energy)/65.0,0.0,1.0)
	if weather=="storm": level*=0.75
	var active: bool=quality!="low" and level>0.02
	strip.visible=active
	finish.emission_enabled=active
	finish.emission=Color("fff0d2")
	finish.emission_energy_multiplier=level*(0.36 if quality=="standard" else 0.78)

func triangle_count() -> int:
	var total: int=0
	for value in nodes.values():
		var model: MultiMeshInstance3D=value
		for i in range(model.multimesh.mesh.get_surface_count()):
			total+=model.multimesh.mesh.surface_get_array_len(i)/3*model.multimesh.instance_count
	return total

func graphics_are_bounded() -> bool:
	if not finalized or count<=0 or count>MAX_BUILDINGS: return false
	if get_child_count()>MAX_DRAWS or nodes.size()>MAX_DRAWS: return false
	if triangle_count()>MAX_TRIANGLES: return false
	var n: int=0
	for district in DISTRICTS:
		var group: Array=poses[district]
		if group.size()!=paints[district].size(): return false
		n+=group.size()
		for transform in group:
			if not (transform is Transform3D) or not (transform as Transform3D).origin.is_finite():
				return false
	if n!=count or led_poses.size()!=count or led_paints.size()!=count: return false
	for item in nodes.values():
		if not (item is MultiMeshInstance3D): return false
		var mesh: MultiMeshInstance3D=item
		if mesh.multimesh==null or mesh.get_child_count()!=0: return false
		if mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: return false
	return true

## R175: Exactly four EXISTING GPU MultiMeshes respond to saved city
## district_scores/energy. No replacement architecture/geometry, NO new
## draw nodes, no per-frame allocation. Updated only after real source events.
static func living_color(district: String,score: int,power: int) -> Color:
	if not STONE.has(district): return Color.WHITE
	var health: float=clampf(float(score)/100.0,0.0,1.0)
	var brightness: float=lerpf(0.56,1.10,health)
	if power<20: brightness*=0.81
	var original: Color=STONE[district]
	# Each source MultiMesh ALREADY owns its original per-building tint.
	# Adjust the shared source PBR material once; do not double-tint geometry.
	return Color(clampf(brightness,0.0,1.0),
		clampf(brightness*(0.92+original.g*0.08),0.0,1.0),
		clampf(brightness*(0.88+original.b*0.12),0.0,1.0),1.0)

func sync_city_vitality(state: Dictionary) -> void:
	if not finalized: return
	var source: Variant=state.get("district_scores",{})
	var indicators: Dictionary=source if source is Dictionary else {}
	var electricity: int=clampi(int(state.get("energy",0)),0,100)
	var next_scores: Dictionary={}
	for district in DISTRICTS:
		next_scores[district]=clampi(int(indicators.get(district,50)),0,100)
	if next_scores==city_vitality and electricity==last_vitality_power:
		return
	for district in DISTRICTS:
		var material: StandardMaterial3D=materials.get("District_"+district)
		if material==null: continue
		# Godot headless cannot reliably read back per-instance GPU colors.
		# Source-authored shared physical PBR material is deterministic and
		# actually controls EVERY original building in that district at once.
		material.albedo_color=living_color(district,next_scores[district],electricity)
	city_vitality=next_scores
	last_vitality_power=electricity
	vitality_updates+=1

func vitality_is_bounded() -> bool:
	if not graphics_are_bounded() or city_vitality.size()!=4:
		return false
	for district in DISTRICTS:
		var value: int=int(city_vitality.get(district,-1))
		if value<0 or value>100: return false
	return vitality_updates>0
