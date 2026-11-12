extends Node3D
## Only current player-permitted contact reports, never enemy identities as bodies.
signal changed(id: String)
signal removing(id: String, anchor: Node3D)

var anchors: Dictionary[String, Node3D] = {}
var views: Dictionary[String, Dictionary] = {}
var _ground: Callable

func bind(ground: Callable) -> void:
	for id: String in anchors.keys(): _remove(id)
	_ground = ground

func reconcile(permitted: Array) -> void:
	var present: Dictionary = {}
	for row: Dictionary in permitted:
		if row.get("kind", "") != "CONTACT": continue
		var id := str(row.get("id", ""))
		var at: Vector2 = row.get("position", Vector2.INF)
		if id.is_empty() or not at.is_finite() or not _ground.is_valid(): continue
		var height := float(_ground.call(at))
		if not is_finite(height): continue
		present[id] = true
		var view := {"position": at, "class": str(row.get("class", "Unknown")),
			"age": float(row.get("age", 0.0)), "uncertainty_m": float(row.get("uncertainty_m", 0.0))}
		var grounded := Vector3(at.x, height, at.y)
		if views.has(id) and views[id] == view and anchors[id].position.is_equal_approx(grounded): continue
		if not anchors.has(id):
			var anchor := Node3D.new()
			anchor.set_meta("contact_id", id)
			add_child(anchor)
			anchors[id] = anchor
			_add_report_cue(anchor)
		views[id] = view
		anchors[id].position = grounded
		changed.emit(id)
	for id: String in anchors.keys():
		if not present.has(id): _remove(id)

func _add_report_cue(anchor: Node3D) -> void:
	# An amber diamond represents a report, not its uncertainty footprint.
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(16.0, 2.0, 16.0)
	mesh.mesh = shape
	mesh.rotation.y = PI / 4.0
	mesh.position.y = 3.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e4a47c")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	anchor.add_child(mesh)
	var label := Label3D.new()
	label.text = "REPORT"
	label.position.y = 9.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.1
	anchor.add_child(label)

func _remove(id: String) -> void:
	var anchor: Node3D = anchors[id]
	removing.emit(id, anchor)
	anchors.erase(id)
	views.erase(id)
	remove_child(anchor)
	anchor.queue_free()

func _exit_tree() -> void:
	for id: String in anchors: removing.emit(id, anchors[id])
	anchors.clear()
	views.clear()
	_ground = Callable()
