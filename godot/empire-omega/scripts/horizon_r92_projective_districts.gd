extends RefCounted
## R92: native projection of four actual city quadrants through the SAME 3D camera.
## No screen-coordinate fixture, fake UI target or arbitrary static % positions.
const DISTRICT_WORLD = {
	"forum":Vector3(-82.0,6.0,-82.0),
	"housing":Vector3(82.0,6.0,-82.0),
	"lower":Vector3(-82.0,6.0,82.0),
	"aqueduct":Vector3(82.0,6.0,82.0)
}

static func project_district(camera: Camera3D, id: String, render_size: Vector2) -> Dictionary:
	if camera == null or not DISTRICT_WORLD.has(id):
		return {"visible":false,"anchor":Vector2.ZERO}
	if not render_size.is_finite() or render_size.x<1.0 or render_size.y<1.0:
		return {"visible":false,"anchor":Vector2.ZERO}
	var world_at: Vector3 = DISTRICT_WORLD[id]
	if camera.is_position_behind(world_at):
		return {"visible":false,"anchor":Vector2.ZERO}
	var image_at: Vector2 = camera.unproject_position(world_at)
	if not image_at.is_finite():
		return {"visible":false,"anchor":Vector2.ZERO}
	var normalized := Vector2(image_at.x/render_size.x,image_at.y/render_size.y)
	# Keep a selected district reachable even near the outside edge.
	var safe := Vector2(clampf(normalized.x,0.15,0.85),clampf(normalized.y,0.20,0.84))
	return {"visible":true,"anchor":safe,"unclamped":normalized,"world_position":world_at}
