extends Node3D
## Provisional T03 shapes for IDs admitted by the existing player policy.
signal changed(id: String)
signal removing(id: String, anchor: Node3D)

var anchors: Dictionary[String, Node3D] = {}
var views: Dictionary[String, Dictionary] = {}
var _ledger: RefCounted
var _ground: Callable
var _inspect: Callable

func bind(ledger: RefCounted, ground: Callable, permitted_inspect: Callable) -> void:
	_disconnect_ledger()
	for id: String in anchors.keys(): _remove(id)
	_ledger = ledger
	_ground = ground
	_inspect = permitted_inspect
	if _ledger != null:
		_ledger.entity_moved.connect(_on_moved)
		_ledger.vehicle_facing_changed.connect(_on_hull_changed)
		_ledger.vehicle_damaged.connect(_on_hull_changed)

func reconcile(permitted: Array) -> void:
	var present: Dictionary = {}
	for row: Dictionary in permitted:
		if not _eligible(row): continue
		var id := str(row.id)
		if not _inspect.is_valid(): continue
		var current: Dictionary = _inspect.call(id)
		if not _eligible(current) or str(current.get("id", "")) != id or not current.has("facing_degrees"): continue
		present[id] = true
		_refresh(current)
	for id: String in anchors.keys():
		if not present.has(id): _remove(id)

func _eligible(row: Dictionary) -> bool:
	return row.get("kind", "") == "CARRIER" and row.get("design_type", "") == "T03" and not str(row.get("id", "")).is_empty()

func _refresh(row: Dictionary) -> void:
	var id := str(row.id)
	var at: Vector2 = row.get("position", Vector2.INF)
	var facing := float(row.get("facing_degrees", NAN))
	if not at.is_finite() or not is_finite(facing) or not _ground.is_valid():
		if anchors.has(id): _remove(id)
		return
	var height := float(_ground.call(at))
	if not is_finite(height):
		if anchors.has(id): _remove(id)
		return
	# The existing view hides rear-zone carrier proxies.
	if at.x < 240.0:
		if anchors.has(id): _remove(id)
		return
	var pose := Transform3D(Basis(Vector3.UP, deg_to_rad(90.0 - facing)), Vector3(at.x, height, at.y))
	var view := {"id": id, "position": at, "facing_degrees": facing,
		"health": int(row.get("health", 0)), "state": str(row.get("state", ""))}
	if views.has(id) and views[id] == view and anchors[id].transform.is_equal_approx(pose): return
	if not anchors.has(id):
		var anchor := Node3D.new()
		anchor.set_meta("carrier_id", id)
		add_child(anchor)
		anchors[id] = anchor
		_add_standin(anchor)
	views[id] = view
	anchors[id].transform = pose
	changed.emit(id)

func _add_standin(anchor: Node3D) -> void:
	# Internal stand-in: canonical footprint, not an approved vehicle model.
	_box(anchor, Vector3(0, 0.8, 0), Vector3(5.2, 1.0, 2.1), Color("6e8068"))
	_box(anchor, Vector3(-1.4, 1.6, 0), Vector3(1.8, 0.8, 1.9), Color("596c59"))
	_box(anchor, Vector3(0.7, 1.6, 0), Vector3(0.6, 0.35, 0.6), Color("303c30"))
	var label := Label3D.new()
	label.text = "T03 · provisional"
	label.position.y = 2.8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.02
	anchor.add_child(label)

func _box(parent: Node3D, at: Vector3, extent: Vector3, colour: Color) -> void:
	var instance := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = extent
	instance.mesh = shape
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	instance.material_override = material
	parent.add_child(instance)

func _refresh_id(id: String) -> void:
	if not anchors.has(id) or not _inspect.is_valid(): return
	var row: Dictionary = _inspect.call(id)
	if _eligible(row): _refresh(row)
	else: _remove(id)

func _on_moved(id: String, _from: Vector2, _to: Vector2) -> void:
	_refresh_id(id)

func _on_hull_changed(id: String) -> void:
	_refresh_id(id)

func _remove(id: String) -> void:
	var anchor: Node3D = anchors[id]
	removing.emit(id, anchor)
	anchors.erase(id)
	views.erase(id)
	remove_child(anchor)
	anchor.queue_free()

func _disconnect_ledger() -> void:
	if _ledger != null:
		if _ledger.entity_moved.is_connected(_on_moved): _ledger.entity_moved.disconnect(_on_moved)
		if _ledger.vehicle_facing_changed.is_connected(_on_hull_changed): _ledger.vehicle_facing_changed.disconnect(_on_hull_changed)
		if _ledger.vehicle_damaged.is_connected(_on_hull_changed): _ledger.vehicle_damaged.disconnect(_on_hull_changed)
	_ledger = null

func _exit_tree() -> void:
	_disconnect_ledger()
	for id: String in anchors: removing.emit(id, anchors[id])
	anchors.clear()
	views.clear()
	_ground = Callable()
	_inspect = Callable()
