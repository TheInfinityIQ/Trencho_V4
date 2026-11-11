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
	var clip: StringName = &"walk" if int(row.index) == 11 else StringName(row.phases[int(row.index)].clip)
	actor.set_activity(clip,float(row.started),float(row.duration),int(row.index) in [0,2,11])

func _pose(id: String) -> Transform3D:
	var order: Dictionary = _service.rows[id].order
	var body: Node3D = _convoys.bodies.get(str(order.id))
	var attached := Transform3D.IDENTITY
	if body != null and body.get("_pivot") != null: attached = body._pivot.global_transform
	return _service.pose(id,attached)

func sync_speed() -> void:
	for actor: ActorView in actors.values(): actor.sync_speed()

func _exit_tree() -> void:
	if _service != null and _service.changed.is_connected(_changed): _service.changed.disconnect(_changed)
	_service = null
	_model = null
	_convoys = null
