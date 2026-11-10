extends RefCounted
## One physical manager pose, walking or seated; never a free worker/camera pose.
const SPAWN_GROUND := Vector2(126,186)
var _position := Vector3(126,0,186)
var _heading := PI/2.0
var heading: float:
	get: return _heading
	set(value):
		if is_finite(value): _heading = value

func reset(support_height: float) -> bool:
	return publish_resolved(Vector3(SPAWN_GROUND.x,support_height,SPAWN_GROUND.y),PI/2.0)

func ground_position() -> Vector2:
	return Vector2(_position.x,_position.z)

func scene_position() -> Vector3:
	return _position

func publish_ground(at: Vector2, support_height: float) -> bool:
	return publish_resolved(Vector3(at.x,support_height,at.y),_heading)

func publish_resolved(at: Vector3, yaw: float) -> bool:
	if not at.is_finite() or not is_finite(yaw): return false
	_position = at
	_heading = yaw
	return true
