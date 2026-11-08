extends RefCounted
## Scene-owned completed exterior adapter. Never writes ConstructionService rows.
const ROOT: String = "res://game/preview_3d/assets/industrial/"
const MODELS: Dictionary = {
	"construction":{"file":"building_a.glb","front_fraction":0.5},
	"workshop":{"file":"building_h.glb","front_fraction":0.8},
	"receiving":{"file":"building_k.glb","front_fraction":0.5},
	"dispatch":{"file":"building_k.glb","front_fraction":0.5},
	"depot":{"file":"building_k.glb","front_fraction":0.5},
	"materials":{"file":"building_l.glb","front_fraction":0.65},
}
# Authored source +Z facade faces west. Both quarter-turn reservations retain
# that facade and a common uniform fit; backend approach never rotates north.
const SOURCE_YAW: float = -PI / 2.0
const EDGE_INSET: float = 0.4
const OCCLUDER_LAYER: int = 4
var _scenes: Dictionary = {}
var _shapes: Dictionary = {}

func build(row: Dictionary) -> Dictionary:
	if row.state != "Complete": return {"ok":false,"reason":"unfinished"}
	if not MODELS.has(row.kind): return {"ok":false,"reason":"unmapped exterior"}
	var center: Vector2 = row.center
	var size: Vector2 = row.size
	var approach: Vector2 = row.door
	var west: float = center.x - size.x / 2.0
	if approach.x >= west or absf(approach.y-center.y) > size.y / 2.0:
		return {"ok":false,"reason":"exterior requires west service approach"}
	var spec: Dictionary = MODELS[row.kind]
	var file: String = spec.file
	if not _scenes.has(file):
		var scene: PackedScene = load(ROOT+file) as PackedScene
		if scene == null: return {"ok":false,"reason":"exterior import unavailable"}
		_scenes[file] = scene
	var packed: PackedScene = _scenes[file]
	var shell: Node3D = Node3D.new()
	shell.name = "CompletedExterior"
	var normalizer: Node3D = Node3D.new()
	normalizer.name = "UniformFit"
	shell.add_child(normalizer)
	var facing: Node3D = Node3D.new()
	facing.rotation.y = SOURCE_YAW
	normalizer.add_child(facing)
	var instance: Node3D = packed.instantiate() as Node3D
	facing.add_child(instance)
	var measured: Dictionary = _measure(instance,normalizer)
	if not measured.ok:
		shell.free()
		return {"ok":false,"reason":"exterior has no usable mesh bounds"}
	var bounds: AABB = measured.bounds
	# Same scale for both swapped Catalog rectangles, leaving a marked inset.
	var available: float = minf(size.x,size.y) - 2.0 * EDGE_INSET
	var factor: float = available / maxf(bounds.size.x,bounds.size.z)
	if factor <= 0.0:
		shell.free()
		return {"ok":false,"reason":"exterior cannot fit reservation"}
	normalizer.scale = Vector3.ONE * factor
	normalizer.position = -Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z) * factor
	var extent: Vector3 = bounds.size * factor
	var fitted: AABB = AABB(Vector3(-extent.x/2.0,0,-extent.z/2.0),extent)
	var entrance: Vector3 = Vector3(fitted.position.x,0,lerpf(fitted.position.z,fitted.end.z,float(spec.front_fraction)))
	_add_occluders(instance)
	shell.set_meta("site_id",str(row.id))
	shell.set_meta("model",file)
	shell.set_meta("fit_scale",factor)
	shell.set_meta("bounds",fitted)
	shell.set_meta("entrance",entrance)
	shell.position = Vector3(center.x,0,center.y)
	return {"ok":true,"node":shell,"bounds":fitted,"entrance":entrance}

func _measure(instance: Node3D, normalizer: Node3D) -> Dictionary:
	var bounds: AABB = AABB()
	var found: bool = false
	for child: Node in instance.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh.mesh == null: continue
		var at: Transform3D = Transform3D.IDENTITY
		var cursor: Node3D = mesh
		while cursor != normalizer:
			at = cursor.transform * at
			cursor = cursor.get_parent() as Node3D
		var box: AABB = at * mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	return {"ok":found and bounds.size.x > 0.00001 and bounds.size.y > 0.00001 and bounds.size.z > 0.00001,"bounds":bounds}

func _add_occluders(instance: Node3D) -> void:
	for child: Node in instance.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh.mesh == null: continue
		var key: int = mesh.mesh.get_instance_id()
		if not _shapes.has(key): _shapes[key] = mesh.mesh.create_trimesh_shape()
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "ExteriorOccluder"
		body.collision_layer = OCCLUDER_LAYER
		body.collision_mask = 0
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = _shapes[key]
		body.add_child(collision)
		mesh.add_child(body)
