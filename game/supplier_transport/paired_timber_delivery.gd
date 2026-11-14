extends RefCounted
## Receiving-owned pair action; one claim, cell, deadline and shared load.
signal changed(id: String)
signal root_changed(id: String)
const Motion = preload("res://game/supplier_transport/paired_timber_motion.gd")
const Route = preload("res://game/supplier_transport/paired_timber_route.gd")
const Freight = preload("res://game/supplier_transport/supplier_freight.gd")
const ROOT := "res://game/supplier_transport/assets/timber_pair/"
const EPS := 0.00001
var rows: Dictionary = {}
var people: Dictionary = {}
var motion: RefCounted
var planner: RefCounted
var unavailable := "Paired timber motion handoff is not ready."
var _service: WeakRef
var _rear: WeakRef
var _epoch := 0
var _attempts: Dictionary = {}
var _pool_attempts: Dictionary = {}
var _sequence := 0

func _init(service: RefCounted, rear: RefCounted) -> void:
	_service = weakref(service)
	_rear = weakref(rear)
	var owner_ref: WeakRef = weakref(self)
	for event: Signal in [service.supplier_state_changed,rear.warehouse.space_changed,rear.state_changed]:
		event.connect(func() -> void:
			var owner: RefCounted = owner_ref.get_ref()
			if owner != null: owner.wake())
	var acceptance: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"integration.json")) if FileAccess.file_exists(ROOT+"integration.json") else {}
	if not acceptance is Dictionary or not acceptance.get("usable_for_playtest",false): return
	var contract: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motion_contract.json"))
	if not contract is Dictionary: return
	if not ResourceLoader.exists(ROOT+str(contract.planned_animation_library).get_file()): return
	var streams := {}
	var runtime_contract: Dictionary = contract.duplicate(true)
	var usable: Array = acceptance.get("usable_clips",[])
	runtime_contract.clips = contract.get("clips",[]).filter(func(entry: Dictionary) -> bool: return entry.name in usable)
	for entry: Dictionary in runtime_contract.clips:
		var file: String = str(entry.planned_sample_file).get_file()
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+file))
		if not data is Dictionary or not data.get("samples") is Array: return
		streams[str(entry.name)] = data.samples
	motion = Motion.new(runtime_contract,streams)
	if not motion.valid():
		unavailable = str(motion.error)
		return
	for required: String in ["pickup_lower","deposit_lower","shoulder_transition","shoulder_release","ramp","turn_left","turn_right","shoulder_ground_travel","underhand_walk","shoulder_walk_loop","underhand_walk_loop"]:
		if not motion.clips.has(required):
			unavailable = "Paired timber handoff lacks a required delivery motion."
			return
	planner = Route.new(rear,motion)
	unavailable = ""

func layout_blocker(vehicles: Array) -> String:
	var total := 0
	for vehicle: Dictionary in vehicles:
		for packet: Dictionary in vehicle.get("packages",[]):
			if packet.code != "M04": continue
			if not unavailable.is_empty(): return unavailable
			total += int(packet.quantity)
			if str(packet.support) != "deck-00" or not motion.clips.has("pickup_lower"):
				return "Upper-tier timber handling is unfinished. This first playtest supports lower-tier timber orders up to50kg; nothing has been purchased."
	if total > 50: return "This first playtest supports timber orders up to50kg. Quantities and truck packing are unchanged; nothing has been purchased."
	return ""

func wake() -> void:
	_epoch += 1
	_attempts.clear()
	_pool_attempts.clear()
	var service: RefCounted = _service.get_ref()
	if service == null: return
	for row: Dictionary in rows.values():
		row.staff_dirty = true
		if row.phase in ["Storage blocked","Receipt blocked","Access blocked"]: row.ends = float(service._time)

func start(candidates: Array) -> Array:
	if not unavailable.is_empty() or candidates.size() < 2: return []
	var pool_key: String = ",".join(candidates)
	if _pool_attempts.has(pool_key): return []
	_pool_attempts[pool_key] = true
	var service: RefCounted = _service.get_ref()
	var rear: RefCounted = _rear.get_ref()
	var offered := false
	for order: Dictionary in service._active_suppliers.values():
		if order.kind != "Freight" or order.state != "Berthed" or order.get("return_requested",false) or not service.freight.can_unload(order) or not order.get("aisle_workers",[]).is_empty(): continue
		for packet: Dictionary in order.packet_manifest:
			if packet.code == "M04" and int(order.aboard_packets.get(packet.stock,0)) > 0: offered = true
	if not offered: return []
	var eligible: Array[String] = []
	var duties := {}
	for id: String in candidates:
		if people.has(id): continue
		var status: Dictionary = service.ledger.inspect_person_status(id)
		if status.get("assignment","") != "Rear Labour" or status.pending_assignment != "None" or float(status.health) <= 0.0: continue
		if not str(status.carrying_stock_id).is_empty() or not str(status.joint_carry_id).is_empty() or not str(status.supplier_access_id).is_empty(): continue
		if not str(status.get("carrying_weapon_id","")).is_empty() or not str(status.get("crew_station","")).is_empty() or not str(status.get("construction_truck_id","")).is_empty(): continue
		if status.duty_id != "hauling" and status.duty_id not in service.freight_berths.map(func(berth: Dictionary) -> String: return berth.duty) and status.duty_id != "Receiving": continue
		eligible.append(id)
		duties[id] = str(status.duty_id)
	if eligible.size() < 2: return []
	for order: Dictionary in service._orders:
		if order.kind != "Freight" or order.state != "Berthed" or order.get("return_requested",false) or not service.freight.can_unload(order) or not order.get("aisle_workers",[]).is_empty(): continue
		var active := 0
		for worker: Dictionary in service._workers.values():
			if worker.job.get("order_id","") == order.id: active += 1
		if active+2 > service.STAFF_LIMIT: continue
		var applicable: Array[String] = []
		for person: String in eligible:
			if duties[person] == "hauling" or duties[person] == service.freight_berths[int(order.slot)].duty or int(order.slot) == 0 and duties[person] == "Receiving": applicable.append(person)
		if applicable.size() < 2: continue
		var key: String = str(order.id)+"/"+",".join(applicable)
		if int(_attempts.get(key,-1)) == _epoch: continue
		_attempts[key] = _epoch
		var packets: Array = order.packet_manifest.filter(func(packet: Dictionary) -> bool: return packet.code == "M04")
		packets.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.position.y > b.position.y)
		for packet: Dictionary in packets:
			var quantity := int(order.aboard_packets.get(packet.stock,0))
			if quantity <= 0 or quantity > 50 or service.ledger.available(str(packet.stock)) < quantity: continue
			if packet.support == "deck-01" and not motion.clips.has("pickup_upper"):
				_block(order,"Upper-tier timber handling is unfinished; this original cargo remains aboard and may be returned.")
				continue
			var members: Array[String] = [applicable[0],applicable[1]]
			var proposed := {}
			var filter: Callable = _candidate.bind(order,packet,members,proposed)
			var space: Dictionary = rear.warehouse.reserve(members[0],"M04",quantity,true,false,filter)
			if not space.ok:
				_block(order,"No reachable lower-tier timber storage — clear access or expand; upper-tier handling is unfinished.")
				continue
			_sequence += 1
			var id := "supplier-timber-%06d" % _sequence
			var claim := id+"-claim"
			var reserved: Dictionary = service.ledger.request_stock(claim,str(packet.stock),quantity,members[0],"Actual paired supplier timber delivery",service.PLAYER)
			if not reserved.ok or int(service.ledger.inspect_claim(claim).get("reserved",0)) != quantity:
				if reserved.ok: service.ledger.release_claim(claim)
				rear.warehouse.release(str(space.id))
				continue
			if not service.freight.reserve_aisle(order,members):
				service.ledger.release_claim(claim)
				rear.warehouse.release(str(space.id))
				continue
			var row := {"id":id,"order":order,"people":members,"source":str(packet.stock),"quantity":quantity,"claim":claim,"storage":str(space.id),"preparation_point":space.point,"plan":proposed.plan,"phase":"","started":float(service._time),"ends":INF,"walk":{},"boarded":{},"index":0,"lifted":false,"carry":id+"-load","deposited":"","source_cleared":false,"staff_dirty":false}
			rows[id] = row
			for person: String in members:
				people[person] = id
				rear.actors[person].phase = "Unloading"
				var shared: bool = service.ledger.person_has_duty(person,"hauling")
				service._workers[person] = {"person_id":person,"shared":shared,"job":{"timber_pair":id,"order_id":order.id,"slot":order.slot,"claim_id":claim,"source_id":str(packet.stock),"quantity":quantity,"code":"M04","destination":"receiving","phase":"Paired timber","path":[],"started_at":float(service._time),"ends_at":INF}}
			for person: String in members:
				var retained: Dictionary = service.ledger.retain_supplier_access(person,str(order.id))
				if not retained.ok:
					_cancel(row,true)
					return members
			if space.prepare: _walk(row,members[0],[service.ledger.inspect_person_status(members[0]).position,space.point],"Storage approach",true)
			else: _begin_board(row)
			order.storage_warning = "Preparing storage" if space.prepare else ""
			_notify(row)
			return members
	return []

func _candidate(bay: Dictionary, cell: Dictionary, order: Dictionary, packet: Dictionary, members: Array, proposed: Dictionary) -> bool:
	var plan: Dictionary = planner.build(order,packet,bay,cell,members)
	if plan.is_empty(): return false
	proposed.plan = plan
	return true

func next_boundary() -> float:
	var next := INF
	for row: Dictionary in rows.values():
		next = minf(next,float(row.ends))
		if row.phase == "Motion" and int(row.index) == 0 and not row.lifted:
			var clip: Dictionary = motion.clips[str(row.plan.commands[0].name)]
			next = minf(next,float(row.started)+float(clip.contact_landmarks.rack_support_release_s))
	return next

func settle() -> bool:
	var service: RefCounted = _service.get_ref()
	var did_work := false
	for id: String in rows.keys():
		var row: Dictionary = rows[id]
		if row.staff_dirty and not row.lifted and row.phase != "Motion" and not row.phase.begins_with("Cancel"):
			row.staff_dirty = false
			for person: String in row.people:
				var status: Dictionary = service.ledger.inspect_person_status(person)
				if status.pending_assignment != "None" or float(status.health) <= 0.0:
					_cancel(row,true)
					did_work = true
					break
		if row.phase == "Motion" and int(row.index) == 0 and not row.lifted:
			var clip: Dictionary = motion.clips[str(row.plan.commands[0].name)]
			if float(service._time)+EPS >= float(row.started)+float(clip.contact_landmarks.rack_support_release_s):
				if not _lift(row): continue
				did_work = true
		if float(row.ends) > float(service._time)+EPS: continue
		match str(row.phase):
			"Storage approach", "Storage blocked":
				var current: Vector2 = service.ledger.inspect_person_status(str(row.people[0])).position
				if current.distance_to(row.preparation_point) > 0.05:
					_walk(row,str(row.people[0]),[current,row.preparation_point],"Storage approach",true)
					continue
				var preparation: Dictionary = _rear.get_ref().warehouse.begin_preparation(str(row.storage))
				if not preparation.ok: _wait(row,"Storage blocked",str(preparation.message))
				elif preparation.ready: _begin_board(row)
				else: _phase(row,"Preparing storage",0.75)
			"Preparing storage":
				if _rear.get_ref().warehouse.reveal_preparation(str(row.storage)): _phase(row,"Storage settling",0.75)
				else: _wait(row,"Storage blocked","Shelf site occupied — waiting for clearance.")
			"Storage settling":
				if _rear.get_ref().warehouse.finish_preparation(str(row.storage)): _begin_board(row)
				else: _wait(row,"Storage blocked","Shelf site occupied — waiting for clearance.")
			"Access blocked": _begin_board(row)
			"Board aft":
				row.boarded[row.people[1]] = true
				_board(row,0)
			"Board fore":
				row.boarded[row.people[0]] = true
				_enter_motion(row,0)
			"Motion": _finish_motion(row)
			"Receipt blocked": _receipt(row)
			"Cancel fore": _walk(row,str(row.people[1]),row.cancel_paths[1],"Cancel aft")
			"Cancel aft": _complete(row)
			_: continue
		did_work = true
	return did_work

func advance_roots() -> void:
	for row: Dictionary in rows.values():
		_apply_roots(row)

func _apply_roots(row: Dictionary) -> void:
	var service: RefCounted = _service.get_ref()
	if row.phase == "Motion":
		var current: Dictionary = pose(str(row.id))
		if row.lifted:
			if not service.ledger.joint_carries.active.has(str(row.carry)):
				_wait(row,"Ground recovery","Paired carry interrupted — actual timber awaits recovery; delivery is not complete.")
				return
			var moved: Dictionary = service.ledger.joint_carries.move(str(row.carry),"rear-lane",[_planar(current.FORE.origin),_planar(current.AFT.origin)],_planar(current.payload.origin))
			if not moved.ok:
				_wait(row,"Ground recovery",str(moved.message))
				return
		else:
			for index in 2:
				var role := "FORE" if index == 0 else "AFT"
				var moved: Dictionary = service.ledger.move_entity(str(row.people[index]),"rear-lane",_planar(current[role].origin))
				if not moved.ok:
					_wait(row,"Handoff blocked",str(moved.message))
					return
		row.last_pose = current
		root_changed.emit(str(row.id))
	elif not row.walk.is_empty():
		var moved: Dictionary = service.ledger.move_entity(str(row.walk.person),"rear-lane",service._motion_position(row.walk))
		if not moved.ok: _wait(row,"Handoff blocked",str(moved.message))

func pose(id: String) -> Dictionary:
	if not rows.has(id) or rows[id].phase != "Motion": return {}
	var row: Dictionary = rows[id]
	return planner.pose(row.plan.commands[int(row.index)],float(_service.get_ref()._time)-float(row.started))

func animated(person: String) -> bool:
	return people.has(person) and rows[people[person]].phase == "Motion"

func height(person: String, at: Vector2) -> float:
	if not people.has(person): return 0.0
	var row: Dictionary = rows[people[person]]
	if row.phase == "Motion":
		var current: Dictionary = pose(str(row.id))
		return float(current.FORE.origin.y) if row.people[0] == person else float(current.AFT.origin.y)
	return Freight.height(row.order,at) if row.phase.begins_with("Board") or row.phase.begins_with("Cancel") else 0.0

func _begin_board(row: Dictionary) -> void:
	var warehouse: RefCounted = _rear.get_ref().warehouse
	if not warehouse.acquire_pair_access(str(row.storage),row.people,row.plan.stations):
		_wait(row,"Access blocked","Waiting for clear paired shelf access; timber remains aboard.")
		return
	_board(row,0 if row.boarded.has(row.people[1]) else 1)

func _board(row: Dictionary, index: int) -> void:
	var service: RefCounted = _service.get_ref()
	var person := str(row.people[index])
	var role := "FORE" if index == 0 else "AFT"
	var target: Vector2 = _planar(row.plan.pickup[role].origin)
	var origin: Vector2 = service.ledger.inspect_person_status(person).position
	var rear: Vector2 = Freight.to_world(row.order,Vector3(0,0,Freight.REAR_Z))
	var path: Array = service._worker_path(origin,rear)
	if path.is_empty():
		_wait(row,"Access blocked","Truck approach blocked; timber remains aboard.")
		return
	path.append(Freight.to_world(row.order,Vector3(0,0,Freight.RAMP_GROUND_Z)))
	path.append(Freight.to_world(row.order,Vector3(0,0,Freight.RAMP_TOP_Z)))
	# Enter deeper AFT station first. Neither person walks through their partner.
	var target_local_z: float = float(motion.sample(str(row.plan.commands[0].name),0.0)[role].origin.z)
	path.append(Freight.to_world(row.order,Vector3(0,0,target_local_z)))
	path.append(target)
	_walk(row,person,path,"Board fore" if index == 0 else "Board aft")

func _walk(row: Dictionary, person: String, path: Array, phase: String, route_ground: bool = false) -> void:
	var service: RefCounted = _service.get_ref()
	if route_ground: path = service._worker_path(path[0],path.back())
	if path.is_empty():
		_wait(row,"Storage blocked","Worker route is blocked; timber remains aboard.")
		return
	var duration: float = maxf(0.001,float(service._path_length(path))/1.5)
	_phase(row,phase,duration)
	row.walk = {"person":person,"path":path,"started_at":float(row.started),"ends_at":float(row.ends)}
	for member: String in row.people: service._workers[member].job.path = path if member == person else []
	_notify(row)

func _enter_motion(row: Dictionary, index: int) -> void:
	row.index = index
	_phase(row,"Motion",float(row.plan.commands[index].duration))
	_apply_roots(row)
	_notify(row)

func _lift(row: Dictionary) -> bool:
	var service: RefCounted = _service.get_ref()
	for person: String in row.people:
		service.ledger.register_handling_point(str(row.order.id),person,service.ledger.inspect_person_status(person).position)
	var current: Dictionary = pose(str(row.id))
	var result: Dictionary = service.ledger.joint_carries.begin(str(row.carry),row.people,str(row.source),int(row.quantity),str(row.claim),_planar(current.payload.origin))
	if not result.ok:
		_wait(row,"Handoff blocked",str(result.message))
		return false
	row.lifted = true
	_notify(row)
	return true

func _finish_motion(row: Dictionary) -> void:
	var command: Dictionary = row.plan.commands[int(row.index)]
	if command.get("clear_source",false) and not _release_source(row): return
	if command.get("warehouse_finish",false):
		_receipt(row)
		return
	_enter_motion(row,int(row.index)+1)

func _receipt(row: Dictionary) -> void:
	var service: RefCounted = _service.get_ref()
	if row.phase == "Motion": row.last_pose = pose(str(row.id))
	if str(row.deposited).is_empty():
		var result: Dictionary = service.ledger.joint_carries.finish(str(row.carry),"receiving")
		if not result.ok:
			_wait(row,"Receipt blocked",str(result.message))
			return
		row.deposited = str(result.entity_id)
		changed.emit(str(row.id))
	var committed: Dictionary = _rear.get_ref().warehouse.commit(str(row.storage),str(row.deposited))
	if not committed.ok:
		_wait(row,"Receipt blocked",str(committed.message))
		return
	# SupplierTimberHandoffs accounts only the exact warehouse event, once.
	_complete(row)

func _release_source(row: Dictionary) -> bool:
	if row.source_cleared: return true
	var service: RefCounted = _service.get_ref()
	for person: String in row.people:
		var status: Dictionary = service.ledger.inspect_person_status(person)
		if str(status.supplier_access_id).is_empty(): continue
		service.ledger.register_handling_point(str(row.order.id),person,status.position)
		var released: Dictionary = service.ledger.release_supplier_access(person,str(row.order.id))
		if not released.ok:
			_wait(row,"Handoff blocked",str(released.message))
			return false
		service.ledger.release_handling_points(person,str(row.order.id))
	if row.order.get("aisle_workers",[]) == row.people: service.freight.release_aisle(row.order)
	row.source_cleared = true
	return true

func _phase(row: Dictionary, name: String, duration: float) -> void:
	row.phase = name
	row.started = float(_service.get_ref()._time)
	row.ends = row.started+duration
	row.walk = {}
	for person: String in row.people:
		var job: Dictionary = _service.get_ref()._workers[person].job
		job.path = []
		job.phase = "Paired timber — "+name
		job.started_at = row.started

func _wait(row: Dictionary, phase: String, message: String) -> void:
	_phase(row,phase,INF)
	_block(row.order,message)
	_notify(row)

func _block(order: Dictionary, message: String) -> void:
	if str(order.get("storage_warning","")) == message: return
	order.storage_warning = message
	_service.get_ref().supplier_state_changed.emit()

func _notify(row: Dictionary) -> void:
	changed.emit(str(row.id))
	for person: String in row.people: _service.get_ref().worker_activity_changed.emit(person)

func _complete(row: Dictionary) -> void:
	var service: RefCounted = _service.get_ref()
	if not _release_source(row): return
	service.ledger.release_claim(str(row.claim))
	for person: String in row.people:
		service.ledger.release_handling_points(person,"receiving")
		service._workers[person].job = {}
		people.erase(person)
	rows.erase(str(row.id))
	changed.emit(str(row.id))
	for person: String in row.people: service.worker_activity_changed.emit(person)
	wake()

func return_plan(order: Dictionary) -> Dictionary:
	var result := {"ok":true,"claims":{},"rows":[]}
	for row: Dictionary in rows.values():
		if row.order.id != order.id or row.lifted: continue
		if row.phase == "Motion": return {"ok":false,"message":"Finish the active timber pickup before returning remaining cargo."}
		var paths: Array = _cancel_paths(row)
		if paths.is_empty(): return {"ok":false,"message":"The paired handlers need a clear empty withdrawal path before return."}
		result.claims[str(row.claim)] = str(row.people[0])
		result.rows.append({"id":str(row.id),"paths":paths})
	return result

func return_confirmed(plan: Dictionary) -> void:
	for entry: Dictionary in plan.get("rows",[]):
		if rows.has(entry.id): _cancel(rows[entry.id],false,entry.paths)

func _cancel(row: Dictionary, release_claim: bool, paths: Array = []) -> void:
	if paths.is_empty(): paths = _cancel_paths(row)
	if paths.is_empty():
		_wait(row,"Handoff blocked","Waiting for a safe paired withdrawal; original timber remains aboard.")
		return
	var service: RefCounted = _service.get_ref()
	if release_claim: service.ledger.release_claim(str(row.claim))
	_rear.get_ref().warehouse.release(str(row.storage))
	row.cancel_paths = paths
	_walk(row,str(row.people[0]),paths[0],"Cancel fore")

func _cancel_paths(row: Dictionary) -> Array:
	var service: RefCounted = _service.get_ref()
	var paths: Array = []
	var rear: Vector2 = Freight.to_world(row.order,Vector3(0,0,Freight.REAR_Z))
	for index in 2:
		var person := str(row.people[index])
		var origin: Vector2 = service.ledger.inspect_person_status(person).position
		var path: Array = [origin]
		var entered: bool = row.boarded.has(person)
		if row.walk.get("person","") == person and row.phase.begins_with("Board"):
			var full: Array = row.walk.path
			var rear_index := full.find(rear)
			var distance: float = float(service._path_length(full))*clampf((float(service._time)-float(row.started))/(float(row.ends)-float(row.started)),0.0,1.0)
			var reached := 0
			for point in range(1,full.size()):
				var length: float = Vector2(full[point-1]).distance_to(full[point])
				if distance < length-EPS: break
				distance -= length
				reached = point
			entered = rear_index >= 0 and reached >= rear_index
			if entered:
				for point in range(reached,rear_index-1,-1): path.append(full[point])
		elif entered: path = service.freight.egress(row.order,origin)
		if entered:
			var clear: Vector2 = Freight.to_world(row.order,Vector3(0,0,8.7 if index == 0 else 7.0))
			path.append(clear)
		elif index == 0 and origin.distance_to(rear) < 2.0:
			path = service._worker_path(origin,Freight.to_world(row.order,Vector3(0,0,8.7)))
			if path.is_empty(): return []
		paths.append(path)
	return paths

static func _planar(value: Vector3) -> Vector2:
	return Vector2(value.x,value.z)
