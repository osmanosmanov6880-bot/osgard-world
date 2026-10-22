extends RefCounted
## Original deterministic grained road and concrete textures, 128px tiled.
## Runtime PBR resources: no external stock photography or trademark assets.
## Godot GL Compatibility & Forward+ share the same surface material.

const SIZE: int = 128

static func _hash_noise(x: int, y: int, salt: int) -> float:
	var n: int = x*15731 + y*789221 + salt*137
	n = ((n << 13) ^ n) & 0x7fffffff
	var h: int = (n*(n*n*15731+789221)+1376312589) & 0x7fffffff
	return float(h)/2147483647.0

static func _make_texture(concrete: bool, normals: bool) -> ImageTexture:
	var image := Image.create_empty(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var micro: float = _hash_noise(x,y,1)
			var macro: float = _hash_noise(int(x/9),int(y/9),5)
			var crack: float = _hash_noise(int(x/19),int(y/19),19)
			if normals:
				var ahead: float = _hash_noise((x+1)%SIZE,y,1)
				var below: float = _hash_noise(x,(y+1)%SIZE,1)
				var slope_x: float = clampf((micro-ahead)*0.26,-0.35,0.35)
				var slope_y: float = clampf((micro-below)*0.26,-0.35,0.35)
				image.set_pixel(x,y,Color(0.5+slope_x,0.5+slope_y,0.96,1.0))
			else:
				var shade: float = (0.57 if concrete else 0.20) + micro*(0.125 if concrete else 0.10) + macro*0.08
				shade += crack*0.025
				image.set_pixel(x,y,Color(shade*1.035,shade*1.02,shade,1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _make_material(concrete: bool) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color.WHITE
	surface.albedo_texture = _make_texture(concrete,false)
	surface.roughness = 0.90 if concrete else 0.77
	surface.metallic = 0.0
	surface.normal_enabled = true
	surface.normal_texture = _make_texture(concrete,true)
	surface.normal_scale = 0.38 if concrete else 0.52
	surface.uv1_triplanar = true
	surface.uv1_world_triplanar = true
	surface.uv1_scale = Vector3(0.22,0.22,0.22) if concrete else Vector3(0.38,0.38,0.38)
	return surface

static func asphalt() -> StandardMaterial3D:
	return _make_material(false)

static func concrete() -> StandardMaterial3D:
	return _make_material(true)
