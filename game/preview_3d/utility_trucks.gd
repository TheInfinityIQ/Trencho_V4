extends Node3D
## Read-only actual Construction hulls; services retain movement and custody.
const T01Presentation = preload("res://game/preview_3d/t01_presentation.gd")
const MODEL_PATH: String = T01Presentation.MODEL_PATH
const MODEL_SCALE: float = T01Presentation.MODEL_SCALE
const SOURCE_ORIGIN: Vector3 = T01Presentation.SOURCE_ORIGIN
const LOW_SIZE: Vector3 = T01Presentation.LOW_SIZE
const LOW_CENTER: Vector3 = T01Presentation.LOW_CENTER
const CAB_SIZE: Vector3 = T01Presentation.CAB_SIZE
const CAB_CENTER: Vector3 = T01Presentation.CAB_CENTER
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
	var registered: Array = _model.rear.construction.trucks.trucks.values()
	var rows: Array[Dictionary] = _ledger.construction_truck_views(registered,_model.rear.PLAYER)
	var present: Dictionary = {}
	for row: Dictionary in rows:
		var id: String = row.id
		present[id] = true
		if not bodies.has(id): _create_body(id)
		_apply_pose(bodies[id],row)
		_apply_state(bodies[id],row)
	for id: String in bodies.keys():
		if present.has(id): continue
		var body: AnimatableBody3D = bodies[id]
		remove_child(body)
		body.queue_free()
		bodies.erase(id)

func _create_body(id: String) -> void:
	if _scene == null: _scene = load(MODEL_PATH) as PackedScene
	bodies[id] = T01Presentation.create_body(self,id,_scene)

func _apply_pose(body: AnimatableBody3D, pose: Dictionary) -> void:
	T01Presentation.apply_pose(body,pose)

func _apply_state(body: AnimatableBody3D, row: Dictionary) -> void:
	var condition: String = "Wreck" if int(row.health) <= 0 else ("Immobilized" if row.damage_immobilized else str(row.state))
	if row.recovering: condition += " · Recovering"
	var crew: String = ""
	if not str(row.driver_id).is_empty(): crew = "\nDriver: "+str(row.driver_id)
	elif not str(row.retained_person_id).is_empty(): crew = "\nRetained hauler: "+str(row.retained_person_id)+" · outside cab"
	var label: Label3D = body.get_node("TruckState") as Label3D
	label.text = "%s\nConstruction utility · %s\n%s%s" % [row.id,row.phase,condition,crew]
	if not str(row.blocker).is_empty(): label.text += "\n"+str(row.blocker)

func _on_entity_moved(id: String, _start: Vector2, _finish: Vector2) -> void:
	if not bodies.has(id): return
	var pose: Dictionary = _ledger.construction_truck_pose(id,_model.rear.PLAYER)
	if not pose.is_empty(): _apply_pose(bodies[id],pose)

func _disconnect_ledger() -> void:
	if _ledger != null and _ledger.entity_moved.is_connected(_on_entity_moved):
		_ledger.entity_moved.disconnect(_on_entity_moved)
	_ledger = null
	_refresh_pending = false

func _exit_tree() -> void:
	_disconnect_ledger()
	_model = null
