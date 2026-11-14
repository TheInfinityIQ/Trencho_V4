extends Node3D
## Read-only view of the same two workers and one retained payload.
const ActorView = preload("res://game/supplier_transport/supplier_actor_view.gd")
const Assets = preload("res://game/warehousing/warehouse_assets.gd")
const Delivery = preload("res://game/supplier_transport/paired_timber_delivery.gd")
var actors: Dictionary = {}
var payloads: Dictionary = {}
var _service: RefCounted
var _model: RefCounted
var _scene: PackedScene

func bind(model: RefCounted) -> void:
	_model = model
	_service = model.receiving.timber_activity
	if _service == null or not str(_service.unavailable).is_empty(): return
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Delivery.ROOT+"motion_contract.json"))
	_scene = load(Delivery.ROOT+str(contract.planned_animation_library).get_file()) as PackedScene
	if _scene == null: return
	_service.changed.connect(_changed)
	_service.root_changed.connect(_roots_changed)
	visibility_changed.connect(sync_speed)
	# Initial actors are prepared before normal play; keep instances across trips.
	for person: String in model.rear.actors:
		var actor: ActorView = _actor(person)
		if actor == null:
			_service.unavailable = "Paired timber character export could not be bound."
			return
		for entry: Dictionary in _service.motion.clips.values():
			if not actor.has_clip(StringName(entry.fore_clip)) or not actor.has_clip(StringName(entry.aft_clip)):
				_service.unavailable = "Paired timber character export is missing a required role clip."
				actor.hide()
				return
		actor.hide()
	for id: String in _service.rows: _changed(id)

func _actor(person: String) -> ActorView:
	if actors.has(person): return actors[person]
	var actor := ActorView.new()
	add_child(actor)
	if not actor.bind(_model.receiving,_model,person,_scene):
		actor.queue_free()
		return null
	actors[person] = actor
	return actor

func _changed(id: String) -> void:
	if not _service.rows.has(id):
		if payloads.has(id):
			payloads[id].queue_free()
			payloads.erase(id)
		for person: String in actors:
			if not _service.people.has(person): actors[person].hide()
		return
	var row: Dictionary = _service.rows[id]
	for index in 2:
		var person := str(row.people[index])
		var actor: ActorView = _actor(person)
		if actor == null: continue
		actor.visible = row.phase == "Motion"
		if row.phase != "Motion": continue
		var command: Dictionary = row.plan.commands[int(row.index)]
		var descriptor: Dictionary = _service.motion.clips[str(command.name)]
		var role := "FORE" if index == 0 else "AFT"
		actor.root_sampler = _actor_pose.bind(id,role,person)
		var clip := StringName(descriptor.fore_clip if index == 0 else descriptor.aft_clip)
		var duration: float = float(descriptor.duration_s) if command.loop else float(command.duration)
		actor.set_activity(clip,float(row.started),duration,bool(command.loop),float(command.from),float(command.to))
	if row.lifted and not payloads.has(id):
		var payload: Node3D = Assets.model("timber_bundle.glb")
		add_child(payload)
		payloads[id] = payload
	_roots_changed(id)

func _actor_pose(id: String, role: String, person: String) -> Transform3D:
	var value: Dictionary = _service.pose(id)
	return value[role] if not value.is_empty() else actors[person].global_transform

func _roots_changed(id: String) -> void:
	if not is_visible_in_tree() or not _service.rows.has(id): return
	var row: Dictionary = _service.rows[id]
	var value: Dictionary = _service.pose(id)
	if value.is_empty(): value = row.get("last_pose",{})
	if value.is_empty(): return
	for person: String in row.people:
		if actors.has(person) and actors[person].visible: actors[person].refresh_root()
	if payloads.has(id):
		var transform: Transform3D = value.payload
		if row.phase == "Ground recovery": transform.origin.y = 0.0
		payloads[id].global_transform = transform

func sync_speed() -> void:
	if _service == null: return
	if is_visible_in_tree():
		for id: String in _service.rows: _roots_changed(id)
	for actor: ActorView in actors.values(): actor.sync_speed()
