extends RefCounted
## Receiving-owned supplier access/mechanisms; presentation never grants custody.
const EPS := 0.000001
const FLOOR_Y := 1.02
const RAMP_TOP_Z := 3.085249243
const RAMP_GROUND_Z := 6.085249243
const REAR_Z := 6.685249243
const CLIP_SECONDS := 2.0
var _receiving_ref: WeakRef
var _packet_orders: Dictionary = {}

func _init(receiving: RefCounted) -> void:
	_receiving_ref = weakref(receiving)
	receiving.ledger.stock_changed.connect(_stock_changed)

func register(order: Dictionary) -> void:
	order.packet_by_stock = {}
	order.aboard_packets = {}
	for row: Dictionary in order.get("packet_manifest",[]):
		order.packet_by_stock[row.stock] = row
		order.aboard_packets[row.stock] = int(row.quantity)
		_packet_orders[row.stock] = order

func _stock_changed(stock_id: String) -> void:
	if not _packet_orders.has(stock_id): return
	var service: RefCounted = _receiving_ref.get_ref()
	if service == null: return
	var order: Dictionary = _packet_orders[stock_id]
	var stock: Dictionary = service.ledger.inspect_entity(stock_id,{},false)
	if int(stock.get("quantity",0)) <= 0 or stock.get("holder_id","") != order.id:
		order.aboard_packets.erase(stock_id)
		_packet_orders.erase(stock_id)
	else: order.aboard_packets[stock_id] = int(stock.quantity)
	service.supplier_state_changed.emit()

func begin(order: Dictionary) -> void:
	order.mechanism = "door_open"
	order.mechanism_started = float(_receiving_ref.get_ref()._time)
	order.mechanism_next = float(order.mechanism_started)+CLIP_SECONDS
	order.aisle_workers = []
	_receiving_ref.get_ref().supplier_state_changed.emit()

func next_boundary() -> float:
	var next := INF
	for order: Dictionary in _receiving_ref.get_ref()._active_suppliers.values():
		next = minf(next,float(order.get("mechanism_next",INF)))
	return next

func settle() -> bool:
	var service: RefCounted = _receiving_ref.get_ref()
	var changed := false
	for order: Dictionary in service._active_suppliers.values():
		if float(order.get("mechanism_next",INF)) > float(service._time)+EPS: continue
		var next: String = {"door_open":"ramp_deploy","ramp_deploy":"unloading","ramp_stow":"door_close","door_close":"closed"}.get(str(order.mechanism),"")
		if next.is_empty(): continue
		order.mechanism = next
		order.mechanism_started = float(service._time)
		order.mechanism_next = float(service._time)+CLIP_SECONDS if next in ["ramp_deploy","door_close"] else INF
		changed = true
	if changed: service.supplier_state_changed.emit()
	return changed

func can_unload(order: Dictionary) -> bool:
	return order.get("mechanism","") == "unloading"

func close(order: Dictionary) -> bool:
	if not can_unload(order) or not order.get("aisle_workers",[]).is_empty(): return false
	order.mechanism = "ramp_stow"
	order.mechanism_started = float(_receiving_ref.get_ref()._time)
	order.mechanism_next = float(order.mechanism_started)+CLIP_SECONDS
	_receiving_ref.get_ref().supplier_state_changed.emit()
	return true

func reserve_aisle(order: Dictionary, workers: Array) -> bool:
	if not can_unload(order): return false
	var occupied: Array = order.get("aisle_workers",[])
	if not occupied.is_empty() and occupied != workers: return false
	order.aisle_workers = workers.duplicate()
	return true

func release_aisle(order: Dictionary) -> void:
	order.aisle_workers = []
	var service: RefCounted = _receiving_ref.get_ref()
	for worker: Dictionary in service._workers.values():
		var job: Dictionary = worker.job
		if job.get("order_id","") == order.id and job.get("phase","") == "Source access": job.ends_at = float(service._time)
	service.supplier_state_changed.emit()

func packet(order: Dictionary, stock_id: String) -> Dictionary:
	return order.get("packet_by_stock",{}).get(stock_id,{})

func accessible(order: Dictionary, stock_id: String) -> bool:
	var selected := packet(order,stock_id)
	if selected.is_empty(): return true
	for blocker: String in selected.get("blocked_by",[]):
		if order.aboard_packets.has(str(order.id)+"-"+blocker): return false
	return true

func pickup_point(order: Dictionary, stock_id: String) -> Vector2:
	var selected := packet(order,stock_id)
	return to_world(order,Vector3(0,FLOOR_Y,float(selected.position.z))) if not selected.is_empty() else to_world(order,Vector3(0,0,REAR_Z))

func ingress(order: Dictionary, stock_id: String, origin: Vector2) -> Array:
	var service: RefCounted = _receiving_ref.get_ref()
	var rear: Vector2 = to_world(order,Vector3(0,0,REAR_Z))
	var path: Array = service._worker_path(origin,rear)
	if path.is_empty(): return []
	for z: float in [RAMP_GROUND_Z,RAMP_TOP_Z]: path.append(to_world(order,Vector3(0,0,z)))
	path.append(pickup_point(order,stock_id))
	return path

func egress(order: Dictionary, origin: Vector2) -> Array:
	var delta: Vector2 = origin-Vector2(order.world_position)
	var angle := deg_to_rad(-90.0-float(order.get("facing_degrees",0.0)))
	var z: float = sin(angle)*delta.x+cos(angle)*delta.y
	if z >= RAMP_GROUND_Z:
		return _receiving_ref.get_ref()._worker_path(origin,to_world(order,Vector3(0,0,REAR_Z)))
	if z > RAMP_TOP_Z: return [origin,to_world(order,Vector3(0,0,RAMP_GROUND_Z)),to_world(order,Vector3(0,0,REAR_Z))]
	return [origin,to_world(order,Vector3(0,0,RAMP_TOP_Z)),to_world(order,Vector3(0,0,RAMP_GROUND_Z)),to_world(order,Vector3(0,0,REAR_Z))]

static func to_world(order: Dictionary, at: Vector3) -> Vector2:
	var origin: Vector2 = order.world_position
	var angle := deg_to_rad(-90.0-float(order.get("facing_degrees",0.0)))
	return origin+Vector2(cos(angle)*at.x+sin(angle)*at.z,-sin(angle)*at.x+cos(angle)*at.z)

static func height(order: Dictionary, at: Vector2) -> float:
	var delta: Vector2 = at-Vector2(order.world_position)
	var angle := deg_to_rad(-90.0-float(order.get("facing_degrees",0.0)))
	var x: float = cos(angle)*delta.x-sin(angle)*delta.y
	if absf(x) > 0.45: return 0.0
	var z: float = sin(angle)*delta.x+cos(angle)*delta.y
	return FLOOR_Y*clampf((RAMP_GROUND_Z-z)/(RAMP_GROUND_Z-RAMP_TOP_Z),0.0,1.0)
