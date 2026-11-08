extends Node3D
## Permitted scene membership only. Ledger events update affected cached people.
signal changed(id: String)
signal removing(id: String, anchor: Node3D)
var anchors: Dictionary[String,Node3D] = {}
var views: Dictionary[String,Dictionary] = {}
var _ledger: RefCounted
var _owner: String = ""
var _ground: Callable
var _human_factory: Callable
var _ancestors: Dictionary = {}
var _dependents: Dictionary = {}

func bind(ledger: RefCounted, player_owner: String, ground: Callable, human_factory: Callable) -> void:
	_disconnect_ledger()
	for id: String in anchors.keys(): _remove(id)
	_ledger = ledger
	_owner = player_owner
	_ground = ground
	_human_factory = human_factory
	_ledger.entity_moved.connect(_on_entity_moved)
	_ledger.person_position_changed.connect(_on_person_changed)

func reconcile(permitted: Array) -> void:
	# Caller supplies its ONE current FieldPolicy result; never discover new IDs.
	if _ledger == null: return
	var present: Dictionary = {}
	for row: Dictionary in permitted:
		if row.kind != "PERSON" or bool(row.get("aboard",false)): continue
		var id: String = str(row.id)
		present[id] = true
		_refresh(id)
	for id: String in anchors.keys():
		if not present.has(id): _remove(id)

func _refresh(id: String) -> void:
	var row: Dictionary = _ledger.field_person_view(id,_owner)
	if row.is_empty():
		if anchors.has(id): _remove(id)
		return
	var at: Vector2 = row.position
	var grounded: Vector3 = Vector3(at.x,float(_ground.call(at)),at.y)
	if views.has(id) and views[id] == row and anchors[id].position.is_equal_approx(grounded): return
	if views.has(id) and bool(views[id].dead) != bool(row.dead): _remove(id)
	if not anchors.has(id):
		var anchor: Node3D = Node3D.new()
		anchor.set_meta("person_id",id)
		add_child(anchor)
		anchors[id] = anchor
		if not bool(row.dead):
			var human: Node3D = _human_factory.call(anchor)
			human.rotation.y = PI
			anchor.set_meta("model_path","res://game/preview_3d/assets/manager.fbx")
	_replace_dependencies(id,row.ancestors)
	views[id] = row
	anchors[id].position = grounded
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
	if anchors.has(id): _refresh(id)
	# A cached parent can move without a separate child endpoint event.
	var affected: Array = _dependents.get(id,{}).keys()
	for child: String in affected:
		if anchors.has(child): _refresh(child)

func _on_person_changed(id: String) -> void:
	if anchors.has(id): _refresh(id)
	# Admission of an uncached ID still belongs to the coalesced Policy boundary.

func _remove(id: String) -> void:
	var anchor: Node3D = anchors[id]
	removing.emit(id,anchor) # World and cue references go first, before any free.
	_clear_dependencies(id)
	views.erase(id)
	anchors.erase(id)
	remove_child(anchor)
	anchor.queue_free()

func _disconnect_ledger() -> void:
	if _ledger != null:
		if _ledger.entity_moved.is_connected(_on_entity_moved): _ledger.entity_moved.disconnect(_on_entity_moved)
		if _ledger.person_position_changed.is_connected(_on_person_changed): _ledger.person_position_changed.disconnect(_on_person_changed)
	_ledger = null

func _exit_tree() -> void:
	_disconnect_ledger()
	for id: String in anchors: removing.emit(id,anchors[id])
	anchors.clear()
	views.clear()
	_ancestors.clear()
	_dependents.clear()
	_ground = Callable()
	_human_factory = Callable()
