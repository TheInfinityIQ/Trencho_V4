extends "res://game/construction/construction_service.gd"
## Instrument the real implementation without replacing its rules or state.
var full_previews := 0
var path_queries := 0
var hints := 0

func placement_hint(kind: String, center: Vector2, quarter_turn: bool = false) -> Dictionary:
	hints += 1
	return super.placement_hint(kind,center,quarter_turn)

func preview(kind: String, center: Vector2, quarter_turn: bool = false) -> Dictionary:
	full_previews += 1
	return super.preview(kind,center,quarter_turn)

func _clearance_path(start: Vector2, goal: Vector2, ignored: Array, candidate: Rect2, clearance: float) -> Array:
	path_queries += 1
	return super._clearance_path(start,goal,ignored,candidate,clearance)
