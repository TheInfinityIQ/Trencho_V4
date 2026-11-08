extends Node3D
## Current permitted registered objectives only; presentation owns no control rules.
signal changed(id: String)
signal removing(id: String, anchor: Node3D)
const KINDS: Array[String] = ["Resource","Route Hub","Observation"]
var anchors: Dictionary[String,Node3D] = {}
var views: Dictionary[String,Dictionary] = {}
var _ground: Callable

func bind(ground: Callable) -> void:
	for id: String in anchors.keys(): _remove(id)
	_ground = ground

func reconcile(permitted: Array) -> void:
	var present: Dictionary = {}
	for row: Dictionary in permitted:
		if row.kind != "PLACE" or row.get("objective_kind","") not in KINDS or not row.has("objective_state"): continue
		var id: String = str(row.id)
		present[id] = true
		_refresh(row)
	for id: String in anchors.keys():
		if not present.has(id): _remove(id)

func _refresh(row: Dictionary) -> void:
	var id: String = str(row.id)
	var at: Vector2 = row.position
	if not at.is_finite():
		if anchors.has(id): _remove(id)
		return
	var height: float = float(_ground.call(at))
	if not is_finite(height):
		if anchors.has(id): _remove(id)
		return
	var grounded: Vector3 = Vector3(at.x,height,at.y)
	var view: Dictionary = {"id":id,"position":at,"objective_kind":str(row.objective_kind),
		"objective_state":str(row.objective_state),"ownership_label":str(row.ownership_label),
		"ownership_colour":row.ownership_colour}
	if views.has(id) and views[id] == view and anchors[id].position.is_equal_approx(grounded): return
	if not anchors.has(id):
		var anchor: Node3D = Node3D.new()
		anchor.set_meta("objective_id",id)
		add_child(anchor)
		anchors[id] = anchor
	views[id] = view
	anchors[id].position = grounded
	changed.emit(id)

func _remove(id: String) -> void:
	var anchor: Node3D = anchors[id]
	removing.emit(id,anchor)
	views.erase(id)
	anchors.erase(id)
	remove_child(anchor)
	anchor.queue_free()

func _exit_tree() -> void:
	for id: String in anchors: removing.emit(id,anchors[id])
	anchors.clear()
	views.clear()
	_ground = Callable()
