extends RefCounted
## Session-owned personal prototype transport; no workforce, freight or fuel grant.
var position := Vector3(136,0,190)
var heading := PI/2.0
var occupied := false
var speed := 0.0

func reset() -> void:
	position = Vector3(136,0,190)
	heading = PI/2.0
	occupied = false
	speed = 0.0
