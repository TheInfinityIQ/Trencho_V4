extends RefCounted
## Selected T01 art and query geometry only; callers own membership and labels.
const MODEL_PATH: String = "res://game/preview_3d/assets/car_kit/truck_flat.glb"
const MODEL_SCALE: float = 1.8
const SOURCE_ORIGIN: Vector3 = Vector3(0,-0.000000011920928966,-0.00000005960464544)
const LOW_SIZE: Vector3 = Vector3(2.7,1.0980000214576722,4.94120557308197)
const LOW_CENTER: Vector3 = Vector3(0,0.549000010728836,0)
const CAB_SIZE: Vector3 = Vector3(2.7,1.2419999570846556,2.1329999570846865)
const CAB_CENTER: Vector3 = Vector3(0,1.719,1.197102971613422)

static func create_body(parent: Node3D, id: String, scene: PackedScene) -> AnimatableBody3D:
	var body: AnimatableBody3D = AnimatableBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.sync_to_physics = true
	body.set_meta("hull_id",id)
	parent.add_child(body)
	var normalizer: Node3D = Node3D.new()
	normalizer.name = "TruckArt"
	body.add_child(normalizer)
	normalizer.scale = Vector3.ONE*MODEL_SCALE
	normalizer.position = -SOURCE_ORIGIN*MODEL_SCALE
	# Preserve all five original wheel/body translations and pivots.
	normalizer.add_child(scene.instantiate())
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
	return body

static func _add_box(body: AnimatableBody3D, shape_name: String, size: Vector3, centre: Vector3) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = shape_name
	collision.shape = shape
	collision.position = centre
	body.add_child(collision)

static func apply_pose(body: AnimatableBody3D, pose: Dictionary) -> void:
	var at: Vector2 = pose.position
	var heading: Basis = Basis(Vector3.UP,deg_to_rad(90.0-float(pose.facing_degrees)))
	body.transform = Transform3D(heading,Vector3(at.x,0,at.y))
