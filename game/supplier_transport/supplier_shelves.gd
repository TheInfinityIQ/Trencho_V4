extends RefCounted
## Receiving-owned manual shelf work. No animation callback grants cargo.
const OPEN_END := 1276.0/30.0
const CLOSE_START := 1306.0/30.0
const CLOSE_END := 2585.0/30.0
const CLOSE_SECONDS := CLOSE_END-CLOSE_START
const FLOOR_Y := 1.02
static var _roots: Array = []
var _owner: WeakRef

func _init(receiving: RefCounted) -> void:
	_owner = weakref(receiving)
	if _roots.is_empty():
		_roots = JSON.parse_string(FileAccess.get_file_as_string("res://game/supplier_transport/assets/s4_operator/root_positions.json"))

func register(order: Dictionary) -> void:
	order.shelf_states = {}
	for rack: Dictionary in order.rack_manifest:
		if rack.family == "S4" and rack.get("manual_bale",false): order.shelf_states[rack.id] = {"state":"Closed","operator":"","started":0.0}

func rack(order: Dictionary, id: String) -> Dictionary:
	for row: Dictionary in order.rack_manifest:
		if str(row.id) == id: return row
	return {}

static func module_pose(row: Dictionary) -> Transform3D:
	var size: Vector3 = row.size
	return Transform3D(Basis(Vector3.UP,PI if int(row.side) < 0 else 0.0),Vector3(row.origin)+Vector3(size.x/2.0,0,size.z/2.0))

func needs_open(order: Dictionary, packet: Dictionary) -> bool:
	var id := str(packet.get("rack",""))
	return order.get("shelf_states",{}).has(id) and float(packet.position.y) < FLOOR_Y+0.70 and order.shelf_states[id].state == "Closed"

func close_candidate(order: Dictionary) -> String:
	if not order.get("aisle_workers",[]).is_empty(): return ""
	for id: String in order.get("shelf_states",{}):
		if order.shelf_states[id].state != "Parked": continue
		var lower_remains := false
		for packet: Dictionary in order.packet_manifest:
			if packet.rack == id and float(packet.position.y) < FLOOR_Y+0.70 and order.aboard_packets.has(str(packet.stock)):
				lower_remains = true
				break
		if not lower_remains or order.get("return_requested",false): return id
	return ""

func pending_close() -> bool:
	for order: Dictionary in _owner.get_ref()._active_suppliers.values():
		if not close_candidate(order).is_empty(): return true
	return false

func all_closed(order: Dictionary) -> bool:
	for row: Dictionary in order.get("shelf_states",{}).values():
		if row.state != "Closed": return false
	return true

func root_at(seconds: float) -> Vector3:
	var frame := clampf(seconds*30.0,0.0,float(_roots.size()-1))
	var index := int(frame)
	var a: Array = _roots[index]
	var b: Array = _roots[mini(index+1,_roots.size()-1)]
	return Vector3(float(a[0]),0,float(a[1])).lerp(Vector3(float(b[0]),0,float(b[1])),frame-float(index))

func world_root(order: Dictionary, rack_id: String, seconds: float) -> Vector2:
	var local := module_pose(rack(order,rack_id))*root_at(seconds)
	return _owner.get_ref().freight.to_world(order,local)

func approach_point(order: Dictionary, job: Dictionary) -> Vector2:
	if job.get("s4_action","") == "close": return world_root(order,str(job.s4_rack),CLOSE_START)
	var packet: Dictionary = _owner.get_ref().freight.packet(order,str(job.source_id))
	if needs_open(order,packet): return world_root(order,str(packet.rack),0.0)
	return _owner.get_ref().freight.pickup_point(order,str(job.source_id))

func begin(order: Dictionary, job: Dictionary, person: String, closing: bool) -> void:
	var service: RefCounted = _owner.get_ref()
	var id: String = str(job.s4_rack) if closing else str(service.freight.packet(order,str(job.source_id)).rack)
	job.s4_rack = id
	job.phase = "Shelf closing" if closing else "Shelf opening"
	job.started_at = float(service._time)
	job.ends_at = float(service._time)+(CLOSE_SECONDS if closing else OPEN_END)
	job.path = []
	order.shelf_states[id] = {"state":"Closing" if closing else "Opening","operator":person,"started":float(service._time)}
	service.supplier_state_changed.emit()
	service.worker_activity_changed.emit(person)

func finish(order: Dictionary, job: Dictionary, person: String) -> void:
	var service: RefCounted = _owner.get_ref()
	var closing: bool = job.phase == "Shelf closing"
	order.shelf_states[str(job.s4_rack)] = {"state":"Closed" if closing else "Parked","operator":"","started":float(service._time)}
	service.supplier_state_changed.emit()
	if not closing and order.get("return_requested",false):
		begin(order,job,person,true)
		return
	var origin: Vector2 = service.ledger.inspect_person_status(person).position
	job.started_at = float(service._time)
	if closing:
		job.phase = "Truck return"
		job.path = service.freight.egress(order,origin)
	else:
		job.phase = "Approach"
		var pickup: Vector2 = service.freight.pickup_point(order,str(job.source_id))
		job.path = [origin,pickup]
	job.ends_at = float(service._time)+maxf(0.001,float(service._path_length(job.path))/1.5)

func active_position(order: Dictionary, job: Dictionary) -> Vector2:
	var seconds := float(_owner.get_ref()._time)-float(job.started_at)
	if job.phase == "Shelf closing": seconds += CLOSE_START
	return world_root(order,str(job.s4_rack),seconds)

func start_close_job(person: String, order: Dictionary, slot: int) -> bool:
	var id := close_candidate(order)
	if id.is_empty(): return false
	var service: RefCounted = _owner.get_ref()
	var job := {"order_id":order.id,"source_id":"","quantity":0,"code":"","claim_id":"","phase":"Source access","started_at":float(service._time),"ends_at":INF,"slot":slot,"destination":"","path":[],"s4_rack":id,"s4_action":"close"}
	service._workers[person].job = job
	service._approach_truck(person,job)
	service.worker_activity_changed.emit(person)
	return true
