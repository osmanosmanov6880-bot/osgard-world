extends RefCounted
## R37: actual shared PBR masonry surface family for the original Godot city.
## Three bounded 128px triplanar tiled textures: plaster, limestone, brick.
## Shared color, normal and roughness textures; distinct tint stays per building.
## No stock images, external API, per-building texture or hidden physics changes.
const SIZE: int = 128
const STYLES: int = 3
const MAX_TEXTURE_BYTES: int = STYLES*SIZE*SIZE*3*4
static var _colors: Dictionary = {}
static var _normals: Dictionary = {}
static var _roughness: Dictionary = {}

static func _noise(x: int,y: int,salt: int) -> float:
	var h: int = (x*1277+y*911+salt*71) & 0x7fffffff
	h = ((h << 13)^h) & 0x7fffffff
	return float((h*(h*h*15731+789221)+1376312589)&0x7fffffff)/2147483647.0

static func _sample(style: int,x: int,y: int) -> Dictionary:
	var grain: float = _noise(x,y,23)
	var block: float = _noise(x/8,y/8,77)
	var seam: float = 0.0
	var light: float = 0.91
	var rough: float = 0.79
	if style == 1:
		# Offset ashlar blocks, shallow mortar only; not flat grey concrete.
		var course: int = y/20
		var segment: int = posmod(x+(course%2)*16,32)
		seam = 0.12 if y%20<=1 or segment<=1 else 0.0
		light = 0.91+(block-0.5)*0.10+(grain-0.5)*0.052
		rough = 0.82+(grain-0.5)*0.065
	elif style == 2:
		# Small repeating clay bricks with staggered rows.
		var row: int = y/12
		var gap: int = posmod(x+(row%2)*16,32)
		seam = 0.18 if y%12<=1 or gap<=1 else 0.0
		light = 0.88+(block-0.5)*0.13+(grain-0.5)*0.062
		rough = 0.87+(grain-0.5)*0.08
	else:
		# Broad mineral plaster flecks and very faint horizontal trowel seams.
		seam = 0.018 if y%24<=1 else 0.0
		light = 0.94+(block-0.5)*0.10+(grain-0.5)*0.041
		rough = 0.79+(grain-0.5)*0.055
	var shade: float = clampf(light-seam,0.60,1.0)
	return {"albedo":shade,"roughness":clampf(rough,0.63,0.96)}

static func _ensure(style: int) -> void:
	if _colors.has(style):
		return
	var color := Image.create_empty(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	var normal := Image.create_empty(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	var rough := Image.create_empty(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var sample: Dictionary = _sample(style,x,y)
			var shade: float = sample["albedo"]
			# Keep white balance close to neutral; building tint provides warmth.
			color.set_pixel(x,y,Color(shade,shade*0.992,shade*0.982,1))
			var hdx: float = float(_sample(style,(x+1)%SIZE,y)["albedo"])-float(_sample(style,posmod(x-1,SIZE),y)["albedo"])
			var hdy: float = float(_sample(style,x,(y+1)%SIZE)["albedo"])-float(_sample(style,x,posmod(y-1,SIZE))["albedo"])
			normal.set_pixel(x,y,Color(clampf(0.5-hdx*0.16,0.33,0.67),clampf(0.5-hdy*0.16,0.33,0.67),0.996,1))
			var grit: float = sample["roughness"]
			rough.set_pixel(x,y,Color(grit,grit,grit,1))
	color.generate_mipmaps()
	normal.generate_mipmaps()
	rough.generate_mipmaps()
	_colors[style] = ImageTexture.create_from_image(color)
	_normals[style] = ImageTexture.create_from_image(normal)
	_roughness[style] = ImageTexture.create_from_image(rough)

static func facade(tint: Color,building_index: int) -> StandardMaterial3D:
	var style: int = posmod(building_index,STYLES)
	_ensure(style)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = _colors[style]
	mat.metallic = 0.015
	mat.roughness = 0.84
	mat.roughness_texture = _roughness[style]
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.normal_enabled = true
	mat.normal_texture = _normals[style]
	mat.normal_scale = 0.18 if style==0 else 0.28
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.18,0.18,0.18)
	return mat

static func allocation_budget_bytes() -> int:
	return MAX_TEXTURE_BYTES

static func cached_styles() -> int:
	return _colors.size()

static func textures_reused(a: StandardMaterial3D,b: StandardMaterial3D) -> bool:
	return a!=null and b!=null and a.albedo_texture==b.albedo_texture and a.normal_texture==b.normal_texture and a.roughness_texture==b.roughness_texture
