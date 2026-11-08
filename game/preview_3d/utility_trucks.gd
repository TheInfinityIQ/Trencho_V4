extends Node3D
## Read-only actual Construction hulls; services retain movement and custody.
const MODEL_PATH: String = "res://game/preview_3d/assets/car_kit/truck_flat.glb"
const MODEL_SCALE: float = 1.8
const SOURCE_ORIGIN: Vector3 = Vector3(0,-0.000000011920928966,-0.00000005960464544)
const LOW_SIZE: Vector3 = Vector3(2.7,1.0980000214576722,4.94120557308197)
const LOW_CENTER: Vector3 = Vector3(0,0.549000010728836,0)
const CAB_SIZE: Vector3 = Vector3(2.7,1.2419999570846556,2.1329999570846865)
const CAB_CENTER: Vector3 = Vector3(0,1.719,1.197102971613422)
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
	var body: AnimatableBody3D = AnimatableBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.sync_to_physics = true
	body.set_meta("hull_id",id)
	add_child(body)
	bodies[id] = body
	if _scene == null: _scene = load(MODEL_PATH) as PackedScene
	var normalizer: Node3D = Node3D.new()
	normalizer.name = "TruckArt"
	body.add_child(normalizer)
	normalizer.scale = Vector3.ONE*MODEL_SCALE
	normalizer.position = -SOURCE_ORIGIN*MODEL_SCALE
	# Preserve all five original wheel/body translations and pivots.
	normalizer.add_child(_scene.instantiate())
	_add_box(body,"LowDeck",LOW_SIZE,LOW_CENTER)
	_add_box(body,"UpperCab",CAB_SIZE,CAB_CENTER)
	var label: Label3D = Label3D.new()
	label.name = "TruckState"
	label.position.y = 2.6
	label.pixel_size = 0.011
	label.modulate = Color("f4cd7c")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	body.add_child(label)

func _add_box(body: AnimatableBody3D, shape_name: String, size: Vector3, centre: Vector3) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = shape_name
	collision.shape = shape
	collision.position = centre
	body.add_child(collision)

func _apply_pose(body: AnimatableBody3D, pose: Dictionary) -> void:
	var at: Vector2 = pose.position
	var heading: Basis = Basis(Vector3.UP,deg_to_rad(90.0-float(pose.facing_degrees)))
	body.transform = Transform3D(heading,Vector3(at.x,0,at.y))

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
