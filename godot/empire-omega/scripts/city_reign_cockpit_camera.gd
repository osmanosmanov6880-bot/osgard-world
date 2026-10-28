extends RefCounted
## R164 - true interior camera offsets in the EXISTING physical Godot car.
## No new Camera3D or fake cockpit screenshot. Transform3D tracks actual yaw,
## without head bob or forced phone motion. The existing car collision is
## authoritative; camera never modifies speed, money, missions or saved state.
const DESKTOP_EYE: Vector3 = Vector3(-0.52,0.51,0.27)
const PHONE_EYE: Vector3 = Vector3(-0.47,0.51,0.27)
const TARGET_LOCAL: Vector3 = Vector3(-0.38,0.41,-21.0)

static func enabled(mode: String,driving: bool,cabinet: bool,inside: bool) -> bool:
    return driving and mode=="cockpit" and not cabinet and not inside

static func eye(vehicle_pose: Transform3D,phone: bool) -> Vector3:
    if not vehicle_pose.origin.is_finite() or not vehicle_pose.basis.is_finite():
        return Vector3.ZERO
    var local: Vector3 = PHONE_EYE if phone else DESKTOP_EYE
    return vehicle_pose * local

static func target(vehicle_pose: Transform3D,phone: bool) -> Vector3:
    if not vehicle_pose.origin.is_finite() or not vehicle_pose.basis.is_finite():
        return Vector3(0,0,-1)
    var sight: Vector3 = vehicle_pose * TARGET_LOCAL
    var position: Vector3 = eye(vehicle_pose,phone)
    if sight.distance_squared_to(position)<1.0:
        return position+Vector3(0,0,-1)
    return sight

static func fov(phone: bool) -> float:
    # A grounded eye-level perspective, without speed-fisheye or camera shake.
    return 73.0 if phone else 70.0

static func valid_transform(vehicle_pose: Transform3D,phone: bool) -> bool:
    var position: Vector3 = eye(vehicle_pose,phone)
    var sight: Vector3 = target(vehicle_pose,phone)
    return position.is_finite() and sight.is_finite() and (
        sight.distance_to(position)>12.0 and sight.distance_to(position)<30.0)
