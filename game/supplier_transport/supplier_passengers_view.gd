extends Node3D
## One visible actor per actual supplier passenger, including independent walks.
const ActorView = preload("res://game/supplier_transport/supplier_actor_view.gd")
const ART := "res://game/supplier_transport/assets/supplier_passenger.glb"
var actors: Dictionary = {}
var _service: RefCounted
var _model: RefCounted
var _convoys: Node3D
var _scene: PackedScene

func bind(model: RefCounted, convoys: Node3D) -> void:
	_model = model
	_convoys = convoys
	_service = model.receiving.passengers
	_scene = load(ART) as PackedScene
	_service.changed.connect(_changed)
	_service.root_changed.connect(_root_changed)
	_model.receiving.ledger.entity_moved.connect(_moved)
	for id: String in _service.rows: _changed(id)

func _changed(id: String) -> void:
	if not _service.rows.has(id):
		if actors.has(id):
			actors[id].hide() # Remove before the normal rear-worker handover.
			actors[id].queue_free()
			actors.erase(id)
		return
	var row: Dictionary = _service.rows[id]
	if not actors.has(id):
		var actor := ActorView.new()
		add_child(actor)
		assert(actor.bind(_model.receiving,_model,id,_scene),"Approved supplier passenger export failed to bind")
		actor.root_sampler = _pose.bind(id)
		actors[id] = actor
	var actor: ActorView = actors[id]
	if int(row.index) >= 8 and actor.get_parent() != self: actor.reparent(self,false)
	var clip: StringName = &"walk" if int(row.index) == 11 else StringName(row.phases[int(row.index)].clip)
	actor.set_activity(clip,float(row.started),float(row.duration),int(row.index) in [0,2,11])

func attach_hull(id: String, pivot: Node3D) -> void:
	var order: Dictionary = _model.receiving._active_suppliers.get(id,{})
	for person: String in order.get("aboard_people",{}):
		if not actors.has(person) or int(_service.rows[person].index) >= 8: continue
		var actor: ActorView = actors[person]
		if actor.get_parent() == pivot: continue
		actor.reparent(pivot,false)
		actor.refresh_root()

func _pose(id: String) -> Transform3D:
	var order: Dictionary = _service.rows[id].order
	var body: Node3D = _convoys.bodies.get(str(order.id))
	var attached := Transform3D.IDENTITY
	if body != null and body.get("_pivot") != null: attached = body._pivot.global_transform
	return _service.pose(id,attached)

func sync_speed() -> void:
	for actor: ActorView in actors.values(): actor.sync_speed()

func _moved(id: String, _from: Vector2, _to: Vector2) -> void:
	# Supported occupants inherit the real hull's physics-synchronized transform.
	# Detached people still follow actual motion when skeletal playback is hidden.
	if actors.has(id) and int(_service.rows[id].index) == 11:
		actors[id].refresh_root()
		return

func _root_changed(id: String) -> void:
	if actors.has(id): actors[id].refresh_root()

func _exit_tree() -> void:
	if _service != null and _service.changed.is_connected(_changed): _service.changed.disconnect(_changed)
	if _service != null and _service.root_changed.is_connected(_root_changed): _service.root_changed.disconnect(_root_changed)
	if _model != null and _model.receiving.ledger.entity_moved.is_connected(_moved): _model.receiving.ledger.entity_moved.disconnect(_moved)
	_service = null
	_model = null
	_convoys = null
