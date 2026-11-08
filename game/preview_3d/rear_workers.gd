extends Node3D
## Read-only worker visuals. Ledger/service events own all physical state.
var visuals: Dictionary[String,Node3D] = {}
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
		_rows.erase(id)

func _create_visual(id: String) -> void:
	var visual: Node3D = Node3D.new()
	visual.set_meta("person_id",id)
	add_child(visual)
	visuals[id] = visual
	var body: Node3D = _human_factory.call(visual)
	body.rotation.y = PI
	_make_label(visual,"WorkerRole",2.15,Color("82e3b0"))
	_make_label(visual,"WorkerCargo",3.15,Color("f4cd7c"))
	var cue: MeshInstance3D = MeshInstance3D.new()
	cue.name = "CarryCue"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE*0.35
	cue.mesh = box
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("b79b69")
	material.roughness = 1.0
	cue.material_override = material
	cue.position = Vector3(0.5,1.0,0)
	visual.add_child(cue)

func _make_label(parent: Node3D, label_name: String, height: float, colour: Color) -> void:
	var label: Label3D = Label3D.new()
	label.name = label_name
	label.position.y = height
	label.pixel_size = 0.012
	label.modulate = colour
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	parent.add_child(label)

func _apply_row(row: Dictionary) -> void:
	var visual: Node3D = visuals[row.id]
	var at: Vector2 = row.position
	visual.position = Vector3(at.x,0,at.y)
	var role: Label3D = visual.get_node("WorkerRole") as Label3D
	var duty: String = str(row.duty_id)
	role.text = "Worker %s\n%s%s" % [row.id,row.assignment," · "+duty if not duty.is_empty() else ""]
	var count: int = int(row.carried_count)
	var cue: MeshInstance3D = visual.get_node("CarryCue") as MeshInstance3D
	var cargo: Label3D = visual.get_node("WorkerCargo") as Label3D
	cue.visible = count > 0
	cargo.visible = cue.visible
	cargo.text = "Carrying %s × %d" % [row.carried_type,count] if count > 0 else ""
	visual.set_meta("carried_id",str(row.carried_id))
	visual.set_meta("carried_count",count)

func _on_entity_moved(id: String, start: Vector2, finish: Vector2) -> void:
	if not visuals.has(id) or not finish.is_finite(): return
	var visual: Node3D = visuals[id]
	visual.position = Vector3(finish.x,0,finish.y)
	_rows[id].position = finish
	var direction: Vector2 = finish-start
	if not direction.is_zero_approx(): visual.rotation.y = atan2(-direction.x,-direction.y)

func _disconnect_ledger() -> void:
	if _ledger != null and _ledger.entity_moved.is_connected(_on_entity_moved):
		_ledger.entity_moved.disconnect(_on_entity_moved)
	_ledger = null
	_refresh_pending = false

func _exit_tree() -> void:
	_disconnect_ledger()
	_model = null
	_human_factory = Callable()
