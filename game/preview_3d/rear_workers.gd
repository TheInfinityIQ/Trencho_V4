extends Node3D
## Read-only worker visuals. Ledger/service events own all physical state.
var visuals: Dictionary[String,Node3D] = {}
var bodies: Dictionary[String,Node3D] = {}
var _roles: Dictionary[String,Label3D] = {}
var _numbers: Dictionary[String,int] = {}
var _next_number := 0
var _rows: Dictionary = {}
var _model: RefCounted
var _ledger: RefCounted
var _human_factory: Callable
var _refresh_pending: bool = false

func bind(model: RefCounted, human_factory: Callable) -> void:
	_disconnect_ledger()
	_model = model
	_ledger = model.rear.ledger
	_human_factory = human_factory
	_ledger.entity_moved.connect(_on_entity_moved)
	request_refresh()

func request_refresh() -> void:
	if _ledger == null or _refresh_pending: return
	_refresh_pending = true
	_refresh_membership.call_deferred()

func _refresh_membership() -> void:
	_refresh_pending = false
	if not is_inside_tree() or _ledger == null: return
	var ids: Array = _model.rear.actors.keys()
	var rows: Array[Dictionary] = _ledger.rear_worker_views(ids,_model.rear.PLAYER)
	var present: Dictionary = {}
	for row: Dictionary in rows:
		var id: String = row.id
		present[id] = true
		if not visuals.has(id): _create_visual(id)
		_rows[id] = row
		_apply_row(row)
	for id: String in visuals.keys():
		if present.has(id): continue
		var visual: Node3D = visuals[id]
		remove_child(visual)
		visual.queue_free()
		visuals.erase(id)
		bodies.erase(id)
		_roles.erase(id)
		_rows.erase(id)

func _create_visual(id: String) -> void:
	var visual: Node3D = Node3D.new()
	visual.set_meta("person_id",id)
	add_child(visual)
	visuals[id] = visual
	var body: Node3D = _human_factory.call(visual)
	body.rotation.y = PI
	bodies[id] = body
	if not _numbers.has(id):
		_next_number += 1
		_numbers[id] = _next_number
	_make_label(visual,"WorkerRole",2.15,Color("82e3b0"))
	_roles[id] = visual.get_node("WorkerRole") as Label3D
	_make_label(visual,"WorkerCargo",3.15,Color("f4cd7c"))

func _make_label(parent: Node3D, label_name: String, height: float, colour: Color) -> void:
	var label: Label3D = Label3D.new()
	label.name = label_name
	label.position.y = height
	label.pixel_size = 0.008
	label.font_size = 22
	label.modulate = colour
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	parent.add_child(label)

func _apply_row(row: Dictionary) -> void:
	var visual: Node3D = visuals[row.id]
	var at: Vector2 = row.position
	visual.position = Vector3(at.x,0,at.y)
	var count: int = int(row.carried_count)
	var cargo: Label3D = visual.get_node("WorkerCargo") as Label3D
	cargo.visible = count > 0
	cargo.text = "%s × %d" % [row.carried_type,count] if count > 0 else ""
	visual.set_meta("carried_id",str(row.carried_id))
	visual.set_meta("carried_count",count)
	_sync_activity(row.id)
	bodies[row.id].set_cargo(count)

func _sync_activity(id: String) -> void:
	var actor: Dictionary = _model.rear.actors[id]
	var job: Dictionary = _model.receiving._workers.get(id,{}).get("job",{})
	var phase: String = str(job.get("phase",actor.phase))
	var label := "Worker %d\n%s" % [_numbers[id],phase]
	if _roles[id].text != label: _roles[id].text = label
	var external: Dictionary = actor.get("external_work",{})
	var moving: bool = not job.get("path",[]).is_empty() if not job.is_empty() else bool(external.get("moving",not actor.motion.is_empty()))
	var next: StringName = &"idle"
	var speed := 0.0
	if moving:
		next = &"carry_walk" if phase.ends_with("Carry") or int(_rows[id].carried_count) > 0 else &"walk"
		speed = 1.2 if next == &"carry_walk" else 1.5
	elif phase.ends_with("Pickup"): next = &"pickup"
	elif phase.ends_with("Drop"): next = &"unload"
	elif int(_rows[id].carried_count) > 0: next = &"carry_idle"
	elif str(_rows[id].duty_id).begins_with("builders-"):
		var site: String = str(_rows[id].duty_id).trim_prefix("builders-")
		var construction: Dictionary = _model.rear.construction.instances.get(site,{})
		if construction.get("state","") == "Dismantling" or bool(construction.get("working",false)): next = &"construct"
	var started: float = float(job.get("started_at",external.get("started",actor.motion.get("started",-1.0))))
	bodies[id].set_activity(next,speed,started,2.0 if next in [&"pickup",&"unload"] else 0.0)

func sync_playback() -> void:
	for body: Node3D in bodies.values(): body.sync_playback()

func _on_entity_moved(id: String, start: Vector2, finish: Vector2) -> void:
	if not visuals.has(id) or not finish.is_finite(): return
	var visual: Node3D = visuals[id]
	visual.position = Vector3(finish.x,0,finish.y)
	_rows[id].position = finish
	var direction: Vector2 = finish-start
	if not direction.is_zero_approx(): visual.rotation.y = atan2(-direction.x,-direction.y)
	_sync_activity(id)

func _disconnect_ledger() -> void:
	if _ledger != null and _ledger.entity_moved.is_connected(_on_entity_moved):
		_ledger.entity_moved.disconnect(_on_entity_moved)
	_ledger = null
	_refresh_pending = false

func _exit_tree() -> void:
	_disconnect_ledger()
	_model = null
	_human_factory = Callable()
	bodies.clear()
	_roles.clear()
	_numbers.clear()
