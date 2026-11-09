extends Node3D
## Permitted scene membership only. Ledger events update affected cached people.
signal changed(id: String)
signal removing(id: String, anchor: Node3D)
var anchors: Dictionary[String,Node3D] = {}
var views: Dictionary[String,Dictionary] = {}
var bodies: Dictionary[String,Node3D] = {}
var _model: RefCounted
var _armed: Dictionary = {}
var _reloads: Dictionary = {}
var _detailed := false
var _ledger: RefCounted
var _owner: String = ""
var _ground: Callable
var _human_factory: Callable
var _ancestors: Dictionary = {}
var _dependents: Dictionary = {}

func bind(ledger: RefCounted, player_owner: String, ground: Callable, human_factory: Callable, model: RefCounted = null) -> void:
	_disconnect_ledger()
	for id: String in anchors.keys(): _remove(id)
	_ledger = ledger
	_owner = player_owner
	_ground = ground
	_human_factory = human_factory
	_model = model
	_ledger.entity_moved.connect(_on_entity_moved)
	_ledger.person_position_changed.connect(_on_person_changed)
	_ledger.person_fired.connect(_on_shot)

func reconcile(permitted: Array) -> void:
	# Caller supplies its ONE current FieldPolicy result; never discover new IDs.
	if _ledger == null: return
	var present: Dictionary = {}
	var ids: Array = []
	for row: Dictionary in permitted:
		if row.kind == "PERSON" and not bool(row.get("aboard",false)): ids.append(str(row.id))
	_armed = _ledger.field_person_armament(ids,_owner)
	_reloads.clear()
	if _model != null:
		for reload: Dictionary in _model.rear.combat.reloads.values(): _reloads[str(reload.operator)] = reload
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
	var motion: Dictionary = _model.rear.battlefield_operations.motions.get(id,{}) if _model != null else {}
	row.moving = not motion.is_empty() and not bool(motion.get("pending",false))
	row.armed = bool(_armed.get(id,false))
	row.reload_due = float(_reloads.get(id,{}).get("due",-1.0))
	if views.has(id) and views[id] == row and anchors[id].position.is_equal_approx(grounded): return
	if not anchors.has(id):
		var anchor: Node3D = Node3D.new()
		anchor.set_meta("person_id",id)
		add_child(anchor)
		anchors[id] = anchor
		var human: Node3D = _human_factory.call(anchor)
		human.rotation.y = PI
		human.animation_enabled = _detailed
		bodies[id] = human
		anchor.set_meta("model_path","res://game/characters/assets/soldier.glb")
	_replace_dependencies(id,row.ancestors)
	if views.has(id):
		var direction: Vector2 = at-Vector2(anchors[id].position.x,anchors[id].position.z)
		if not direction.is_zero_approx(): anchors[id].rotation.y = atan2(-direction.x,-direction.y)
	views[id] = row
	anchors[id].position = grounded
	if _model != null:
		var speed := 0.0
		if row.moving:
			for part: Dictionary in motion.plan.parts:
				speed = (part.to as Vector2).distance_to(part.from)/maxf(0.000001,float(part.seconds))
				if speed > 0.0: break
		var action: StringName = &"death" if row.dead else (&"wounded" if row.caution else (&"run" if speed > 2.2 else (&"walk" if row.moving else &"idle")))
		var started: float = float(motion.get("started",row.state_entered_at))
		var seconds := 0.0
		if _reloads.has(id) and not row.dead and not row.caution:
			action = &"reload"
			started = float(_reloads[id].started)
			seconds = float(_reloads[id].seconds)
		bodies[id].set_activity(action,speed,started,seconds)
		bodies[id].set_armed(row.armed)
	changed.emit(id)

func _on_shot(id: String) -> void:
	if bodies.has(id): bodies[id].fire()

func sync_playback() -> void:
	for body: Node3D in bodies.values(): body.sync_playback()

func set_animation_detail(enabled: bool) -> void:
	if _detailed == enabled: return
	_detailed = enabled
	for body: Node3D in bodies.values():
		body.animation_enabled = enabled
		body.sync_playback()

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
	bodies.erase(id)
	anchors.erase(id)
	remove_child(anchor)
	anchor.queue_free()

func _disconnect_ledger() -> void:
	_model = null
	if _ledger != null:
		if _ledger.person_fired.is_connected(_on_shot): _ledger.person_fired.disconnect(_on_shot)
		if _ledger.entity_moved.is_connected(_on_entity_moved): _ledger.entity_moved.disconnect(_on_entity_moved)
		if _ledger.person_position_changed.is_connected(_on_person_changed): _ledger.person_position_changed.disconnect(_on_person_changed)
	_ledger = null

func _exit_tree() -> void:
	_disconnect_ledger()
	for id: String in anchors: removing.emit(id,anchors[id])
	anchors.clear()
	views.clear()
	bodies.clear()
	_armed.clear()
	_reloads.clear()
	_ancestors.clear()
	_dependents.clear()
	_ground = Callable()
	_human_factory = Callable()
