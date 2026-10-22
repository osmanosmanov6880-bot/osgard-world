extends RefCounted
## Original seamless PBR asphalt and pavement: multi-scale cyclic value noise.
## 128x128 textures are generated once per material, no external source assets.
const SIZE: int = 128

static func _hash_noise(x: int, y: int, salt: int) -> float:
	var n: int = (x*15731 + y*789221 + salt*137) & 0x7fffffff
	n = ((n << 13) ^ n) & 0x7fffffff
	var h: int = (n*(n*n*15731+789221)+1376312589) & 0x7fffffff
	return float(h)/2147483647.0

static func _smooth_noise(x: int, y: int, cell: int, seed: int) -> float:
	var cells: int = SIZE/cell
	var xi: int = floori(float(posmod(x,SIZE))/float(cell))
	var yi: int = floori(float(posmod(y,SIZE))/float(cell))
	var fx: float = float(posmod(x,cell))/float(cell)
	var fy: float = float(posmod(y,cell))/float(cell)
	fx = fx*fx*(3.0-2.0*fx)
	fy = fy*fy*(3.0-2.0*fy)
	var a: float = _hash_noise(xi,yi,seed)
	var b: float = _hash_noise((xi+1)%cells,yi,seed)
	var c: float = _hash_noise(xi,(yi+1)%cells,seed)
	var d: float = _hash_noise((xi+1)%cells,(yi+1)%cells,seed)
	return lerpf(lerpf(a,b,fx),lerpf(c,d,fx),fy)

static func _height(x: int, y: int) -> float:
	var low: float = _smooth_noise(x,y,32,51)
	var mid: float = _smooth_noise(x,y,8,137)
	var fine: float = _smooth_noise(x,y,2,17)
	return low*0.52 + mid*0.32 + fine*0.16

static func _make_texture(concrete: bool, normals: bool) -> ImageTexture:
	var image := Image.create_empty(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var h: float = _height(x,y)
			if normals:
				var slope_x: float = (h-_height((x+1)%SIZE,y))*0.29
				var slope_y: float = (h-_height(x,(y+1)%SIZE))*0.29
				image.set_pixel(x,y,Color(0.5+slope_x,0.5+slope_y,0.98,1.0))
			else:
				var fine_grain: float = _hash_noise(x,y,379)
				var base: float = 0.51 if concrete else 0.29
				var shade: float = clampf(base+(h-0.5)*0.18+(fine_grain-0.5)*0.026,0.06,0.82)
				image.set_pixel(x,y,Color(shade*1.01,shade,shade*0.98,1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _make_material(concrete: bool) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color.WHITE
	surface.albedo_texture = _make_texture(concrete,false)
	surface.roughness = 0.90 if concrete else 0.81
	surface.metallic = 0.0
	surface.normal_enabled = true
	surface.normal_texture = _make_texture(concrete,true)
	surface.normal_scale = 0.26 if concrete else 0.37
	surface.uv1_triplanar = true
	surface.uv1_world_triplanar = true
	surface.uv1_scale = Vector3(0.22,0.22,0.22) if concrete else Vector3(0.38,0.38,0.38)
	return surface

static func asphalt() -> StandardMaterial3D:
	return _make_material(false)

static func concrete() -> StandardMaterial3D:
	return _make_material(true)
