extends RefCounted
## HORIZON R25: lightweight procedural masonry for existing city geometry.
## Generates two 64x64 shared textures ONCE per game; one material per tint.
## Never creates a new texture per building and adds no collision geometry.
const SIZE: int = 64
static var _color_texture: ImageTexture
static var _normal_texture: ImageTexture

static func _noise(x: int, y: int, salt: int) -> float:
	var n: int = (x*1277+y*911+salt*71) & 0x7fffffff
	n = ((n<<13)^n) & 0x7fffffff
	return float((n*(n*n*15731+789221)+1376312589)&0x7fffffff)/2147483647.0

static func _ensure_textures() -> void:
	if _color_texture != null and _normal_texture != null:
		return
	var albedo := Image.create_empty(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	var normal := Image.create_empty(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			# Subtle plaster and brick-course irregularity, not repeating
			# high contrast noise or fake neon architectural patterns.
			var coarse: float = _noise(x/4,y/4,23)
			var fine: float = _noise(x,y,71)
			var mortar: float = 0.035 if y%16<=1 else 0.0
			var shade: float = clampf(0.91+(coarse-0.5)*0.13+(fine-0.5)*0.055-mortar,0.75,1.0)
			albedo.set_pixel(x,y,Color(shade,shade*0.995,shade*0.983,1.0))
			var nx: float = clampf((_noise(x+1,y,71)-_noise(x-1,y,71))*0.035,-0.08,0.08)
			var ny: float = clampf((_noise(x,y+1,71)-_noise(x,y-1,71))*0.035,-0.08,0.08)
			normal.set_pixel(x,y,Color(0.5+nx,0.5+ny,0.996,1.0))
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	_color_texture = ImageTexture.create_from_image(albedo)
	_normal_texture = ImageTexture.create_from_image(normal)

static func facade(tint: Color) -> StandardMaterial3D:
	_ensure_textures()
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = _color_texture
	material.roughness = 0.79
	material.metallic = 0.025
	material.normal_enabled = true
	material.normal_texture = _normal_texture
	material.normal_scale = 0.16
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.28,0.28,0.28)
	return material

static func textures_reused(a: StandardMaterial3D,b: StandardMaterial3D) -> bool:
	return a != null and b != null and a.albedo_texture==b.albedo_texture and a.normal_texture==b.normal_texture
