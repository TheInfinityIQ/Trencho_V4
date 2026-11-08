extends Node3D
## Actual player Rear T01 hulls only; a retained registry is not fleet ownership.
const T01Presentation = preload("res://game/preview_3d/t01_presentation.gd")
var bodies: Dictionary[String,AnimatableBody3D] = {}
var _model: RefCounted
var _ledger: RefCounted
var _scene: PackedScene
var _refresh_pending: bool = false

func bind(model: RefCounted) -> void:
	_disconnect_ledger()
	_model = model
	_ledger = model.rear.ledger
	_ledger.entity_moved.connect(_on_entity_moved)
	request_refresh()

func request_refresh() -> void:
	if _ledger == null or _refresh_pending: return
	_refresh_pending = true
	_refresh_membership.call_deferred()

func _refresh_membership() -> void:
	_refresh_pending = false
	if not is_inside_tree() or _ledger == null: return
	var registered: Array = _model.rear.vehicles.vehicles.values()
	var rows: Array[Dictionary] = _ledger.rear_t01_views(registered,_model.rear.PLAYER)
	var present: Dictionary = {}
	for row: Dictionary in rows:
		var id: String = row.id
		present[id] = true
		if not bodies.has(id):
			if _scene == null: _scene = load(T01Presentation.MODEL_PATH) as PackedScene
			bodies[id] = T01Presentation.create_body(self,id,_scene)
		T01Presentation.apply_pose(bodies[id],row)
		_apply_state(bodies[id],row)
	for id: String in bodies.keys():
		if not present.has(id): _remove_body(id)

func _apply_state(body: AnimatableBody3D, row: Dictionary) -> void:
	var condition: String = "Wreck" if int(row.health) <= 0 else ("Immobilized" if row.damage_immobilized else str(row.state))
	var label: Label3D = body.get_node("TruckState") as Label3D
	label.text = "%s\nRear fleet · T01\n%s" % [row.id,condition]

func _on_entity_moved(id: String, _start: Vector2, _finish: Vector2) -> void:
	if not bodies.has(id): return
	var pose: Dictionary = _ledger.rear_t01_pose(id,_model.rear.PLAYER)
	if pose.is_empty():
		_remove_body(id)
	else:
		T01Presentation.apply_pose(bodies[id],pose)

func _remove_body(id: String) -> void:
	var body: AnimatableBody3D = bodies[id]
	remove_child(body)
	body.queue_free()
	bodies.erase(id)

func _disconnect_ledger() -> void:
	if _ledger != null and _ledger.entity_moved.is_connected(_on_entity_moved):
		_ledger.entity_moved.disconnect(_on_entity_moved)
	_ledger = null
	_refresh_pending = false

func _exit_tree() -> void:
	_disconnect_ledger()
	_model = null
