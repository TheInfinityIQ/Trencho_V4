extends RefCounted
## The rear manager is a player pose, never an available logistics worker.
var ground_position := Vector2(16, 90)
var heading := PI/2.0

func reset() -> void:
	ground_position = Vector2(16, 90)
	heading = PI/2.0

func scene_position(ground_height: float = 0.0) -> Vector3:
	return Vector3(ground_position.x, ground_height, ground_position.y)

func publish_resolved(at: Vector3, yaw: float) -> void:
	ground_position = Vector2(at.x, at.z)
	heading = yaw
