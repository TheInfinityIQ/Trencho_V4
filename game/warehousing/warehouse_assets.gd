extends RefCounted
## Metric Artist assets: never stretch an exterior to impersonate an interior.
const ROOT := "res://game/warehousing/assets/"
static var _palette: Dictionary = {}
static var _scenes: Dictionary = {}

static func model(file: String) -> Node3D:
	var path := ROOT+file
	if not ResourceLoader.exists(path): return null
	if not _scenes.has(path): _scenes[path] = load(path) as PackedScene
	var scene: PackedScene = _scenes[path]
	if scene == null: return null
	var node := scene.instantiate() as Node3D
	prepare(node)
	return node

static func prepare(node: Node3D) -> void:
	var meshes: Array[Node] = node.find_children("*","MeshInstance3D",true,false)
	if node is MeshInstance3D: meshes.push_front(node)
	for child: Node in meshes:
		var mesh := child as MeshInstance3D
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original == null: continue
			var key := original.get_instance_id()
			if not _palette.has(key):
				var material := original.duplicate() as BaseMaterial3D
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				_palette[key] = material
			mesh.set_surface_override_material(surface,_palette[key])

static func shell(row: Dictionary) -> Dictionary:
	var visual := model("warehouse_shell.glb")
	if visual == null: return {"ok":false,"reason":"Warehouse Artist export pending integration"}
	var shell := Node3D.new()
	shell.name = "WarehouseShell"
	shell.set_meta("warehouse_model",visual)
	shell.add_child(visual)
	visual.rotation.y = -PI/2.0 if bool(row.quarter_turn) else PI
	# A visual-only centimetre bias prevents coplanar fighting with the existing
	# outdoor ground mesh. The actual walking plane remains flat atY0.
	var floor := visual.find_child("Floor",true,false) as Node3D
	if floor != null: floor.position.y += 0.01
	var boxes: Array[AABB] = []
	_bounds(visual,Transform3D.IDENTITY,boxes)
	if boxes.is_empty():
		shell.free()
		return {"ok":false,"reason":"Warehouse export has no mesh"}
	var bounds: AABB = boxes[0]
	for box: AABB in boxes: bounds = bounds.merge(box)
	var at: Vector2 = row.door-row.center
	return {"ok":true,"node":shell,"bounds":bounds,"entrance":Vector3(at.x,0,at.y),
		"label_anchor":Vector3(at.x,4.3,at.y),"warehouse":true}

static func _bounds(node: Node3D, parent: Transform3D, result: Array[AABB]) -> void:
	var transform: Transform3D = parent*node.transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.append(transform*(node as MeshInstance3D).get_aabb())
	for child: Node in node.get_children():
		if child is Node3D: _bounds(child,transform,result)
