extends RefCounted
## CITY REIGN B56: near-camera only genuine 3D aluminium window-frame render.
## Source provenance: original WorldBuilder.window_points, not a fake asset.
## ZERO additional draw nodes and ZERO new real city instances. The 3D glass
## stays in its original global batch and original order at ALL distances.
## Only the existing decorative frame MultiMesh's first visible transforms
## are packed into a hard-limited near-player draw range.
const MAX_CINEMATIC_WINDOW_FRAMES: int = 2000
const NEAR_FRAME_RADIUS_METRES: float = 104.0
const MAX_TRIANGLES_PER_REVEAL: int = 60

static func indices_near_focus(original: Array[Transform3D],
		focus: Vector3) -> PackedInt32Array:
	var selected := PackedInt32Array()
	if not focus.is_finite():
		return selected
	var r2: float = NEAR_FRAME_RADIUS_METRES*NEAR_FRAME_RADIUS_METRES
	for index in range(original.size()):
		var at: Vector3 = original[index].origin
		if not at.is_finite():
			continue
		var dx: float = at.x-focus.x
		var dz: float = at.z-focus.z
		if dx*dx+dz*dz <= r2:
			selected.append(index)
			if selected.size()>=MAX_CINEMATIC_WINDOW_FRAMES:
				break
	return selected

static func geometry_triangles(visible_frames: int) -> int:
	return maxi(0,mini(visible_frames,MAX_CINEMATIC_WINDOW_FRAMES))*MAX_TRIANGLES_PER_REVEAL

static func bounded(original_window_count: int,physical_instances: int,
		visible_frames: int) -> bool:
	return original_window_count>=0 and physical_instances==original_window_count and (
		visible_frames>=0 and visible_frames<=mini(original_window_count,MAX_CINEMATIC_WINDOW_FRAMES) and
		geometry_triangles(visible_frames)<=MAX_CINEMATIC_WINDOW_FRAMES*MAX_TRIANGLES_PER_REVEAL)
