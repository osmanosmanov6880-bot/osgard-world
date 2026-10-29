extends Node3D
## CITY REIGN R174: 3 real owned-business consequences in the ACTUAL city.
## Reads the original GameState.businesses only. Does not own or alter money,
## mission indices, transactions, saves, collisions, input or original shops.
const INSIGNIAS = ["market_stall","logistics","workshop"]
const ANCHORS = {
	# On existing Market and Freight plaza forecourts; these are pedestrian
	# edges OUTSIDE the original 25m landmark building and 10m roadbed.
	"market_stall":Vector3(114.0,0.0,-123.0),
	"logistics":Vector3(-114.0,0.0,123.0),
	"workshop":Vector3(-114.0,0.0,136.0)
}
const TRANSLATIONS = {
	"ru":{"market_stall":"ТОРГОВАЯ ГАЛЕРЕЯ","logistics":"ЛОГИСТИЧЕСКАЯ КОМПАНИЯ",
		"workshop":"ПРОМЫШЛЕННАЯ МАСТЕРСКАЯ","owned":"ВАШ БИЗНЕС",
		"available":"НЕ ПРИОБРЕТЁН","base":"БАЗОВЫЙ ДОХОД / ТАКТ",
		"price":"СТОИМОСТЬ"},
	"en":{"market_stall":"MARKET GALLERY","logistics":"LOGISTICS COMPANY",
		"workshop":"INDUSTRIAL WORKSHOP","owned":"OWNED BUSINESS",
		"available":"NOT PURCHASED","base":"BASE INCOME / TURN",
		"price":"PURCHASE PRICE"},
	"zh":{"market_stall":"市场商铺","logistics":"物流公司",
		"workshop":"工业工坊","owned":"已拥有的企业",
		"available":"尚未购买","base":"每回合基本收入",
		"price":"购买价格"}
}
const MAX_DRAW_GROUPS: int = 6
const MAX_VERTICES_PER_SIGN: int = 750
const MAX_REVEAL_METRES: float = 112.0
var models: Dictionary={}
var captions: Dictionary={}
var owned: Dictionary={}
var mode: String="standard"
var locale: String="ru"
var clock: float=12.0
var grid_power: int=100
var last_focus: Vector3=Vector3.ZERO
var built: bool=false
var matte: StandardMaterial3D
var brass: StandardMaterial3D

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
		d: Vector3,tint: Color) -> void:
	var norm: Vector3=(b-a).cross(c-a).normalized()
	for p in [a,b,c,a,c,d]:
		st.set_normal(norm)
		st.set_color(tint)
		st.add_vertex(p)

static func _box(st: SurfaceTool,lo: Vector3,hi: Vector3,tint: Color) -> void:
	var v: Array[Vector3]=[
		Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),
		Vector3(hi.x,lo.y,hi.z),Vector3(lo.x,lo.y,hi.z),
		Vector3(lo.x,hi.y,lo.z),Vector3(hi.x,hi.y,lo.z),
		Vector3(hi.x,hi.y,hi.z),Vector3(lo.x,hi.y,hi.z)]
	for e in [[0,3,2,1],[4,5,6,7],[0,1,5,4],
			[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		_quad(st,v[e[0]],v[e[1]],v[e[2]],v[e[3]],tint)

static func _spoke(st: SurfaceTool,a: Vector2,b: Vector2,width: float,
		tint: Color) -> void:
	var delta: Vector2=b-a
	if delta.length_squared()<0.001: return
	var across: Vector2=Vector2(-delta.y,delta.x).normalized()*width
	var corners: Array[Vector2]=[a-across,b-across,b+across,a+across]
	var left: Array[Vector3]=[]
	var right: Array[Vector3]=[]
	for p in corners:
		left.append(Vector3(p.x,p.y,-0.31))
		right.append(Vector3(p.x,p.y,-0.15))
	_quad(st,left[0],left[3],left[2],left[1],tint)
	_quad(st,right[0],right[1],right[2],right[3],tint.darkened(0.22))
	for i in range(4):
		var k: int=(i+1)%4
		_quad(st,left[i],left[k],right[k],right[i],tint.darkened(0.13))

static func original_mesh(id: String) -> ArrayMesh:
	if not INSIGNIAS.has(id): return null
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone:=Color("384955")
	var metal:=Color("d2b98b")
	# Real two-metre tall street-mounted brass frame, no physics body.
	_box(st,Vector3(-0.95,0.23,-0.45),
		Vector3(0.95,0.41,0.45),stone)
	_box(st,Vector3(-0.81,0.40,-0.31),
		Vector3(0.81,2.23,0.31),stone.darkened(0.17))
	_box(st,Vector3(-1.04,2.15,-0.40),
		Vector3(1.04,2.95,0.35),stone.darkened(0.58))
	_box(st,Vector3(-0.94,2.24,-0.49),
		Vector3(0.94,2.84,-0.35),metal.darkened(0.43))
	_box(st,Vector3(-1.00,2.91,-0.42),
		Vector3(1.00,3.03,0.38),metal)
	_box(st,Vector3(-0.06,0.50,-0.40),
		Vector3(0.06,2.17,-0.30),metal.darkened(0.18))
	match id:
		"market_stall":
			# Original circular exchange mark: eight machined bronze ticks.
			for i in range(8):
				var a: float=float(i)*TAU/8.0
				var unit: Vector2=Vector2(cos(a),sin(a))
				_spoke(st,Vector2(0,2.52)+unit*0.16,
					Vector2(0,2.52)+unit*0.28,0.047,metal)
		"logistics":
			# Original connected path / active freight trade symbol.
			for i in range(3):
				var x: float=-0.45+float(i)*0.37
				_spoke(st,Vector2(x,2.36),Vector2(x+0.19,2.51),
					0.055,metal)
				_spoke(st,Vector2(x+0.19,2.51),Vector2(x,2.66),
					0.055,metal)
		"workshop":
			# Original raised industrial sprocket rather than a brand logo.
			for i in range(6):
				var angle: float=float(i)*TAU/6.0
				var uv: Vector2=Vector2(cos(angle),sin(angle))
				_spoke(st,Vector2(0,2.52)+uv*0.16,
					Vector2(0,2.52)+uv*0.31,0.070,metal)
			_box(st,Vector3(-0.12,2.40,-0.54),
				Vector3(0.12,2.64,-0.46),metal)
	return st.commit()

static func safe_curb(location: Vector3) -> bool:
	if not location.is_finite(): return false
	# Original service buildings occupy a 25m square; the road network
	# is centered on 52m lanes with a 10m width. Exclude both footprints.
	var ax: float=roundf(location.x/52.0)*52.0
	var az: float=roundf(location.z/52.0)*52.0
	if absf(location.x-ax)<=7.0 or absf(location.z-az)<=7.0:
		return false
	for lot in [Vector3(130,0,-130),Vector3(-130,0,130)]:
		if absf(location.x-lot.x)<13.5 and absf(location.z-lot.z)<13.5:
			return false
	return true

func _ready() -> void:
	name="CityReignR174OwnedBusinesses"
	_build_once()

func _build_once() -> void:
	if built: return
	matte=StandardMaterial3D.new()
	matte.vertex_color_use_as_albedo=true
	matte.albedo_color=Color("5f7480")
	matte.roughness=0.81
	matte.metallic=0.06
	matte.cull_mode=BaseMaterial3D.CULL_DISABLED
	brass=StandardMaterial3D.new()
	brass.vertex_color_use_as_albedo=true
	brass.albedo_color=Color("e6cfad")
	brass.roughness=0.31
	brass.metallic=0.52
	brass.cull_mode=BaseMaterial3D.CULL_DISABLED
	for id in INSIGNIAS:
		assert(safe_curb(ANCHORS[id]),"R174 must not obstruct an original real lane or building")
		var sign:=MeshInstance3D.new()
		sign.name="Owned_"+id
		sign.mesh=original_mesh(id)
		sign.position=ANCHORS[id]
		sign.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sign.material_override=matte
		add_child(sign)
		models[id]=sign
		var caption:=Label3D.new()
		caption.name="OwnedLabel_"+id
		caption.position=ANCHORS[id]+Vector3(0,3.64,0)
		caption.font_size=35
		caption.pixel_size=0.0075
		caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		caption.no_depth_test=false
		caption.modulate=Color("bfcfd3")
		caption.outline_modulate=Color("0d1821")
		add_child(caption)
		captions[id]=caption
		owned[id]=false
	built=true
	update_quality(mode)
	update_power(clock,grid_power)

func sync_state(state: Dictionary,language: String,catalog: Dictionary) -> void:
	locale=language if TRANSLATIONS.has(language) else "ru"
	if not built: return
	var raw: Variant=state.get("businesses",{})
	if not (raw is Dictionary):
		return
	var portfolio: Dictionary=raw
	var caption_words: Dictionary=TRANSLATIONS[locale]
	for id in INSIGNIAS:
		var active: bool=portfolio.get(id,false)==true
		owned[id]=active
		var model: MeshInstance3D=models[id]
		model.material_override=brass if active else matte
		var label: Label3D=captions[id]
		var spec: Dictionary=catalog.get(id,{})
		var amount: int=int(spec.get("income",0)) if active else int(spec.get("cost",0))
		var category: String=caption_words["base"] if active else caption_words["price"]
		var status: String=str(caption_words["owned"] if active else caption_words["available"])
		label.text=str(caption_words[id])+"\n"+status+"\n"+str(category)+" · "+str(amount)
		label.modulate=Color("f1dfbd") if active else Color("a6bcc5")
	update_power(clock,grid_power)
	update_view(last_focus)

func update_quality(tier: String) -> void:
	mode=tier if ["low","standard","cinematic"].has(tier) else "standard"
	update_view(last_focus)
	update_power(clock,grid_power)

func update_power(hour: float,energy: int) -> void:
	clock=fposmod(hour,24.0) if is_finite(hour) else 12.0
	grid_power=clampi(energy,0,100)
	if not built: return
	var dusk: float=0.0
	if clock>=19.0 or clock<5.5: dusk=1.0
	elif clock>=17.0: dusk=clampf((clock-17.0)/2.0,0.0,1.0)
	elif clock<7.0: dusk=clampf((7.0-clock)/1.5,0.0,1.0)
	var light: float=dusk*clampf(float(grid_power)/65.0,0.0,1.0)
	brass.emission_enabled=light>0.025 and mode!="low"
	brass.emission=Color("e3b97d")
	brass.emission_energy_multiplier=light*(0.27 if mode=="standard" else 0.56)

func update_view(focus: Vector3) -> void:
	if focus.is_finite():
		last_focus=focus
	for id in INSIGNIAS:
		var near: bool=mode!="low" and last_focus.is_finite() and (
			Vector2(last_focus.x,last_focus.z).distance_to(
				Vector2(ANCHORS[id].x,ANCHORS[id].z))<=MAX_REVEAL_METRES)
		if models.has(id): models[id].visible=near
		if captions.has(id): captions[id].visible=near

func graphics_are_bounded() -> bool:
	if not built or models.size()!=3 or captions.size()!=3 or get_child_count()>MAX_DRAW_GROUPS:
		return false
	for id in INSIGNIAS:
		var model: MeshInstance3D=models[id]
		var label: Label3D=captions[id]
		if model.mesh==null or model.mesh.get_surface_count()!=1 or model.mesh.surface_get_array_len(0)>MAX_VERTICES_PER_SIGN:
			return false
		if model.get_child_count()!=0 or label.get_child_count()!=0:
			return false
		if not safe_curb(model.position):
			return false
	return true
