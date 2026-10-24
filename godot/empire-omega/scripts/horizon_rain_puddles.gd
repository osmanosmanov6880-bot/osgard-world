extends MultiMeshInstance3D
## HORIZON R26: a single bounded Godot GPU instancing batch of rainy puddles.
## This is transparent polygonal geometry, not physical water simulation.
## No extra physics colliders, no input changes, and no expensive reflections.
const COUNT: int = 72
const MASK_SIZE: int = 48
var weather := "clear"
var detail := "standard"

static func _hash(x: int,y: int,seed: int) -> float:
	var n: int = (x*15731+y*789221+seed*137) & 0x7fffffff
	n = ((n<<13)^n) & 0x7fffffff
	return float((n*(n*n*15731+789221)+1376312589)&0x7fffffff)/2147483647.0

static func make_mask() -> ImageTexture:
	var img:=Image.create_empty(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_RGBA8)
	for y in range(MASK_SIZE):
		for x in range(MASK_SIZE):
			var nx: float = (float(x)+0.5)/float(MASK_SIZE)*2.0-1.0
			var ny: float = (float(y)+0.5)/float(MASK_SIZE)*2.0-1.0
			var distance: float = sqrt(nx*nx/0.92+ny*ny/0.77)
			var edge: float = clampf((1.0-distance+(_hash(x,y,68)-0.5)*0.17)*5.5,0.0,1.0)
			var grain: float = 0.85+0.15*_hash(x,y,12)
			img.set_pixel(x,y,Color(0.26*grain,0.38*grain,0.44*grain,0.47*edge))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _ready() -> void:
	name="RoadsideRainPuddleBatch"
	var polygon:=PlaneMesh.new()
	polygon.size=Vector2.ONE
	var surface:=StandardMaterial3D.new()
	surface.albedo_color=Color.WHITE
	surface.albedo_texture=make_mask()
	surface.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.roughness=0.19
	surface.metallic=0.07
	surface.cull_mode=BaseMaterial3D.CULL_DISABLED
	polygon.material=surface
	var instances:=MultiMesh.new()
	instances.transform_format=MultiMesh.TRANSFORM_3D
	instances.mesh=polygon
	instances.instance_count=COUNT
	for i in range(COUNT):
		var road_line: int = i/8-4
		var stage: int = i%8
		var along: float = -181.0+float(stage)*49.5+float((i*13)%7)*0.31
		var road: float = float(road_line)*52.0
		var side: float = 3.3 if i%2==0 else -3.3
		var cross: bool = (i/8)%2==1
		var size_x: float = 1.15+float(i%5)*0.17
		var size_z: float = 2.20+float((i*7)%6)*0.14
		var center:=Vector3(road+side,0.183,along) if cross else Vector3(along,0.183,road+side)
		var angle: float = 0.08*float(i%7)
		var b:=Basis(Vector3.UP,angle).scaled(Vector3(size_x,1.0,size_z))
		instances.set_instance_transform(i,Transform3D(b,center))
	multimesh=instances
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb=AABB(Vector3(-230.0,0.12,-230.0),Vector3(460.0,0.30,460.0))
	set_conditions("clear","standard")

func set_conditions(current_weather: String,quality: String) -> void:
	weather=current_weather if ["clear","rain","storm","cloudy","wind","drought"].has(current_weather) else "clear"
	detail=quality if ["low","standard","cinematic"].has(quality) else "standard"
	visible=(weather=="rain" or weather=="storm") and detail!="low"

func material_is_bounded() -> bool:
	return multimesh != null and multimesh.instance_count<=COUNT
