extends RefCounted
## Provisional closed commercial exterior for actual T02; no seating/capability claim.
const MODEL_PATH: String = "res://game/preview_3d/assets/car_kit/delivery.glb"
const MODEL_SCALE: float = 5.0/3.0
const SOURCE_ORIGIN: Vector3 = Vector3(0,-0.000000011920928966,-0.025)
const LOW_SIZE: Vector3 = Vector3(2.5,1.500000019868215,5.416666269302368)
const LOW_CENTER: Vector3 = Vector3(0,0.7500000099341075,0)
const UPPER_SIZE: Vector3 = Vector3(2.5,1.2499998013178508,4.433333202203116)
const UPPER_CENTER: Vector3 = Vector3(0,2.12499992052714,-0.40833327968915256)

static func create_body(parent: Node3D, id: String, scene: PackedScene) -> AnimatableBody3D:
	var body: AnimatableBody3D = AnimatableBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.sync_to_physics = true
	body.set_meta("hull_id",id)
	body.set_meta("model_path",MODEL_PATH)
	parent.add_child(body)
	var normalizer: Node3D = Node3D.new()
	normalizer.name = "TruckArt"
	body.add_child(normalizer)
	normalizer.scale = Vector3.ONE*MODEL_SCALE
	normalizer.position = -SOURCE_ORIGIN*MODEL_SCALE
	# Keep all six source roots, including the static closed door and wheel pivots.
	normalizer.add_child(scene.instantiate())
	_add_box(body,"LowerEnvelope",LOW_SIZE,LOW_CENTER)
	_add_box(body,"CoveredUpper",UPPER_SIZE,UPPER_CENTER)
	var label: Label3D = Label3D.new()
	label.name = "TruckState"
	label.position.y = 3.0
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
