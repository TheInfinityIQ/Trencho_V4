extends Node3D
## One detailed military T01 per supplied permitted ID; no transport authority.
signal changed(id: String)
signal removing(id: String, body: Node3D)
const T01Presentation = preload("res://game/preview_3d/t01_presentation.gd")
var bodies: Dictionary[String,AnimatableBody3D] = {}
var views: Dictionary[String,Dictionary] = {}
var poses: Dictionary[String,Transform3D] = {}
var _ledger: RefCounted
var _owner: String = ""
var _ground: Callable
var _release_rear: Callable
var _scene: PackedScene
var _ancestors: Dictionary = {}
var _dependents: Dictionary = {}

func bind(ledger: RefCounted, player_owner: String, ground: Callable, release_rear: Callable) -> void:
	_disconnect_ledger()
	for id: String in bodies.keys(): _remove(id)
	_ledger = ledger
	_owner = player_owner
	_ground = ground
	_release_rear = release_rear
	_ledger.entity_moved.connect(_on_entity_moved)
	_ledger.vehicle_facing_changed.connect(_on_hull_changed)
	_ledger.vehicle_damaged.connect(_on_hull_changed)

func reconcile(permitted: Array) -> void:
	if _ledger == null: return
	var present: Dictionary = {}
	for row: Dictionary in permitted:
		if row.kind != "CARRIER": continue
		var id: String = str(row.id)
		present[id] = true
		_refresh(id)
	for id: String in bodies.keys():
		if not present.has(id): _remove(id)

func _refresh(id: String) -> void:
	var row: Dictionary = _ledger.field_t01_view(id,_owner)
	if row.is_empty():
		if bodies.has(id): _remove(id)
		return
	var at: Vector2 = row.position
	var height: float = float(_ground.call(at))
	if not is_finite(height):
		if bodies.has(id): _remove(id)
		return
	var pose: Transform3D = Transform3D(Basis(Vector3.UP,deg_to_rad(90.0-float(row.facing_degrees))),Vector3(at.x,height,at.y))
	if views.has(id) and views[id] == row and poses[id].is_equal_approx(pose): return
	if not bodies.has(id):
		if not bool(_release_rear.call(id)): return
		if _scene == null: _scene = load(T01Presentation.MODEL_PATH) as PackedScene
		bodies[id] = T01Presentation.create_body(self,id,_scene)
	_replace_dependencies(id,row.ancestors)
	views[id] = row
	poses[id] = pose # Derived committed presentation pose; body sync may lag a step.
	bodies[id].transform = pose
	var label: Label3D = bodies[id].get_node("TruckState") as Label3D
	label.text = "%s\nMilitary T01\n%s" % [id,"Immobilized" if row.damage_immobilized else str(row.state)]
	changed.emit(id)

func _replace_dependencies(id: String, parents: Array) -> void:
	if _ancestors.get(id,[]) == parents: return
	_clear_dependencies(id)
	_ancestors[id] = parents.duplicate()
	for parent: String in parents:
		if not _dependents.has(parent): _dependents[parent] = {}
		_dependents[parent][id] = true

func _clear_dependencies(id: String) -> void:
	for parent: String in _ancestors.get(id,[]):
		_dependents[parent].erase(id)
		if _dependents[parent].is_empty(): _dependents.erase(parent)
	_ancestors.erase(id)

func _on_entity_moved(id: String, _start: Vector2, _finish: Vector2) -> void:
	if bodies.has(id): _refresh(id)
	var affected: Array = _dependents.get(id,{}).keys()
	for child: String in affected:
		if bodies.has(child): _refresh(child)

func _on_hull_changed(id: String) -> void:
	if bodies.has(id): _refresh(id)

func _remove(id: String) -> void:
	var body: AnimatableBody3D = bodies[id]
	removing.emit(id,body)
	_clear_dependencies(id)
	views.erase(id)
	poses.erase(id)
	bodies.erase(id)
	remove_child(body)
	body.queue_free()

func _disconnect_ledger() -> void:
	if _ledger != null:
		if _ledger.entity_moved.is_connected(_on_entity_moved): _ledger.entity_moved.disconnect(_on_entity_moved)
		if _ledger.vehicle_facing_changed.is_connected(_on_hull_changed): _ledger.vehicle_facing_changed.disconnect(_on_hull_changed)
		if _ledger.vehicle_damaged.is_connected(_on_hull_changed): _ledger.vehicle_damaged.disconnect(_on_hull_changed)
	_ledger = null

func _exit_tree() -> void:
	_disconnect_ledger()
	for id: String in bodies: removing.emit(id,bodies[id])
	bodies.clear()
	views.clear()
	poses.clear()
	_ancestors.clear()
	_dependents.clear()
	_ground = Callable()
	_release_rear = Callable()
