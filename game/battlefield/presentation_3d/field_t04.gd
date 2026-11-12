extends "res://game/battlefield/presentation_3d/field_t03.gd"
## Provisional T04 silhouette; all membership and pose come from the shared policy.

func _eligible(row: Dictionary) -> bool:
	return row.get("kind", "") == "CARRIER" and row.get("design_type", "") == "T04" and not str(row.get("id", "")).is_empty()

func _refresh(row: Dictionary) -> void:
	# Lightweight marker rows omit facing; inspect the admitted ID for real pose.
	if not row.has("facing_degrees"):
		if not _inspect.is_valid(): return
		var current: Dictionary = _inspect.call(str(row.id))
		if not _eligible(current):
			if anchors.has(str(row.id)): _remove(str(row.id))
			return
		super._refresh(current)
		return
	super._refresh(row)

func _add_standin(anchor: Node3D) -> void:
	# Internal stand-in: 7.5 × 3 m canonical footprint, not approved art.
	_box(anchor, Vector3(0, 0.9, 0), Vector3(7.5, 1.4, 3.0), Color("637762"))
	_box(anchor, Vector3(-0.5, 1.85, 0), Vector3(3.4, 0.6, 2.4), Color("536850"))
	_box(anchor, Vector3(0.3, 2.3, 0), Vector3(1.6, 0.4, 1.4), Color("465b45"))
	_box(anchor, Vector3(1.7, 2.3, 0), Vector3(1.4, 0.18, 0.18), Color("303c30"))
	var label := Label3D.new()
	label.text = "T04 · provisional"
	label.position.y = 3.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.02
	anchor.add_child(label)
