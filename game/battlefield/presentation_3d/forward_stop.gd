extends Node3D
## Physical place cues only for policy-permitted friendly forward stops.
signal changed(id: String)
signal removing(id: String, anchor: Node3D)
var anchors: Dictionary[String, Node3D] = {}
var _ground: Callable

func bind(ground: Callable) -> void:
	for id: String in anchors.keys(): _remove(id)
	_ground = ground

func reconcile(permitted: Array) -> void:
	var present: Dictionary = {}
	for row: Dictionary in permitted:
		if row.get("kind","") != "PLACE" or not bool(row.get("friendly_forward_stop",false)) or row.has("objective_kind"): continue
		var id := str(row.get("id",""))
		var at: Vector2 = row.get("position",Vector2.INF)
		if id.is_empty() or not at.is_finite() or not _ground.is_valid(): continue
		var height := float(_ground.call(at))
		if not is_finite(height): continue
		present[id] = true
		var grounded := Vector3(at.x,height,at.y)
		var changed_view := not anchors.has(id)
		if changed_view:
			var anchor := Node3D.new()
			anchor.set_meta("forward_stop_id",id)
			add_child(anchor)
			anchors[id] = anchor
			_add_cue(anchor)
		if not anchors[id].position.is_equal_approx(grounded):
			anchors[id].position = grounded
			changed_view = true
		if changed_view: changed.emit(id)
	for id: String in anchors.keys():
		if not present.has(id): _remove(id)

func _add_cue(anchor: Node3D) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(20.0,1.5,20.0)
	mesh.mesh = shape
	mesh.position.y = 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8bd5ca")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	anchor.add_child(mesh)
	var label := Label3D.new()
	label.text = "FORWARD SUPPLY"
	label.position.y = 9.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.1
	anchor.add_child(label)

func _remove(id: String) -> void:
	var anchor: Node3D = anchors[id]
	removing.emit(id,anchor)
	anchors.erase(id)
	remove_child(anchor)
	anchor.queue_free()

func _exit_tree() -> void:
	for id: String in anchors: removing.emit(id,anchors[id])
	anchors.clear()
	_ground = Callable()
