extends Node3D
## Incoming supplier service only; Receiving owns identities, motion and unloading.
const Freight = preload("res://game/preview_3d/t01_presentation.gd")
const Personnel = preload("res://game/preview_3d/t02_presentation.gd")
const SupplierView = preload("res://game/supplier_transport/supplier_vehicle_view.gd")
var bodies: Dictionary = {}
var _receiving: RefCounted
var _ledger: RefCounted
var _pending := false
var _model: RefCounted

func bind(receiving: RefCounted, simulation: RefCounted = null) -> void:
	_receiving = receiving
	_model = simulation
	_ledger = receiving.ledger
	_receiving.supplier_state_changed.connect(_request_refresh)
	_ledger.entity_moved.connect(_moved)
	_request_refresh()

func _request_refresh() -> void:
	if _pending: return
	_pending = true
	_refresh.call_deferred()

func _refresh() -> void:
	_pending = false
	if not is_inside_tree() or _receiving == null: return
	var present := {}
	for row: Dictionary in _receiving.supplier_vehicle_views():
		present[row.id] = true
		if not bodies.has(row.id):
			if _receiving.development_convoys and _model != null:
				var supplier := SupplierView.new()
				add_child(supplier)
				supplier.bind(_receiving,_model,row)
				bodies[row.id] = supplier
			else:
				var freight: bool = row.kind == "Freight"
				var scene: PackedScene = load(Freight.MODEL_PATH if freight else Personnel.MODEL_PATH)
				bodies[row.id] = Freight.create_body(self,row.id,scene) if freight else Personnel.create_body(self,row.id,scene)
		var body: AnimatableBody3D = bodies[row.id]
		if body is SupplierView:
			(body as SupplierView).refresh(row)
			(body as SupplierView).apply_pose(row.position)
		else: Freight.apply_pose(body,row)
		var label: Label3D = body.get_node("TruckState") as Label3D
		label.text = "%s · Supplier\n%s · %s" % [row.id,row.kind,row.get("mechanism","") if not str(row.get("mechanism","")).is_empty() else row.state]
		var warning: Label3D = body.get_node_or_null("StorageWarning") as Label3D
		if warning == null:
			warning = Label3D.new()
			warning.name = "StorageWarning"
			warning.position = Vector3(0,4.5,0)
			warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			warning.pixel_size = 0.025
			warning.modulate = Color("ffbe56")
			body.add_child(warning)
		var reason: String = str(row.get("storage_warning","")) if row.state == "Berthed" else ""
		warning.visible = not reason.is_empty()
		warning.text = "⚠ " + reason if not reason.is_empty() else ""
	for id: String in bodies.keys():
		if present.has(id): continue
		var body: Node3D = bodies[id]
		remove_child(body)
		body.queue_free()
		bodies.erase(id)

func _moved(id: String, _start: Vector2, finish: Vector2) -> void:
	if not bodies.has(id): return
	var body: AnimatableBody3D = bodies[id]
	if body is SupplierView:
		(body as SupplierView).apply_pose(finish)
		return
	# Convoy lane always runs west to east; this view never advances its motion.
	body.transform = Transform3D(Basis(Vector3.UP,PI/2.0),Vector3(finish.x,0,finish.y))

func sync_speed() -> void:
	for body: Node3D in bodies.values():
		if body is SupplierView: (body as SupplierView).sync_speed()

func _exit_tree() -> void:
	if _receiving != null and _receiving.supplier_state_changed.is_connected(_request_refresh): _receiving.supplier_state_changed.disconnect(_request_refresh)
	if _ledger != null and _ledger.entity_moved.is_connected(_moved): _ledger.entity_moved.disconnect(_moved)
	_receiving = null
	_ledger = null
	_model = null
