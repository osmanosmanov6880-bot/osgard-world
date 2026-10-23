extends Node3D
## Small test world carrying the same material and placement contracts as real world_builder.gd.
var building_chunks: Dictionary = {}
var window_points: Array[Transform3D] = []
var city_root: Node3D
var facade_windows: MultiMeshInstance3D
var sky_environment: WorldEnvironment
var sun: DirectionalLight3D

func _ready() -> void:
	city_root = Node3D.new()
	add_child(city_root)
	for quarter in range(6):
		var section := Node3D.new()
		section.name = "Quarter_%d" % quarter
		city_root.add_child(section)
		var x: float = -150.0+float(quarter%3)*100.0
		var z: float = -140.0+float(quarter/3)*200.0
		building_chunks[Vector2i(quarter,0)] = {"node":section,"center":Vector3(x,0,z),"active":true}
		for bay in range(2):
			var holder := StaticBody3D.new()
			holder.name = "Building_%03d" % (quarter*2+bay)
			holder.position = Vector3(x+float(bay)*16.0,10.0,z)
			section.add_child(holder)
			var geometry := MeshInstance3D.new()
			geometry.name = "VisualMesh"
			var block := BoxMesh.new()
			block.size = Vector3(12.0,20.0,12.0)
			geometry.mesh = block
			geometry.material_override = StandardMaterial3D.new()
			holder.add_child(geometry)
			for floor in range(5):
				for column in range(3):
					var y: float = 2.8+float(floor)*3.5
					var lateral: float = float(column-1)*3.15
					window_points.append(Transform3D(Basis(),Vector3(holder.position.x+lateral,y,z+6.12)))
					window_points.append(Transform3D(Basis(),Vector3(holder.position.x+lateral,y,z-6.12)))
					window_points.append(Transform3D(Basis(Vector3.UP,PI/2),Vector3(holder.position.x+6.12,y,z+lateral)))
					window_points.append(Transform3D(Basis(Vector3.UP,PI/2),Vector3(holder.position.x-6.12,y,z+lateral)))
	facade_windows = MultiMeshInstance3D.new()
	facade_windows.name = "LegacyWindows"
	add_child(facade_windows)
	sky_environment = WorldEnvironment.new()
	sky_environment.environment = Environment.new()
	sky_environment.environment.background_mode = Environment.BG_SKY
	sky_environment.environment.sky = Sky.new()
	sky_environment.environment.sky.sky_material = ProceduralSkyMaterial.new()
	add_child(sky_environment)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.0
	add_child(sun)
