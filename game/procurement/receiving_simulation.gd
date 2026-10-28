extends RefCounted
## G02's one predefined Receiving bay and independent Personnel pull-off.
## Timed service activities use G01's physical identities, never a staff-count grant.

const Ledger = preload("res://game/identity/identity_ledger.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Catalog = preload("res://game/procurement/resource_catalog.gd")
const PLAYER := "army-blue"
const SUPPLIER := "supplier"
const FREIGHT_LIMIT: int = 11
const PERSONNEL_LIMIT: int = 2
const REAR_LIMIT: int = 120
const STORAGE_KG: int = 5000
const STAFF_LIMIT: int = 4
const PASSENGER_EXIT_SECONDS: float = 1.0 # GDD 10.2, per stopped vehicle.
const RECEIVING := Vector2(45, 25)
const PERSONNEL := Vector2(20, 90)
const FREIGHT_GATE := Vector2(0, 25)
const FREIGHT_BERTH := Vector2(35, 25)
const FREIGHT_EXIT := Vector2(-12, 25)

var ledger := Ledger.new()
var receiving_position := RECEIVING
var personnel_position := PERSONNEL
var route: Callable
# Optional shared-store contract: returns currently legal free kilograms.
var receiving_room: Callable
var external_rear_reservations: Callable # G12 safety-return places held before lawful re-entry.
var _time: float = 0.0
var _money: float = 2500.0
var _income: float = 0.0
var _spent: int = 0
var _refunds: int = 0
var _order_sequence: int = 0
var _job_sequence: int = 0
var _orders: Array[Dictionary] = []
var _workers: Dictionary[String, Dictionary] = {}
var _walks: Array[Dictionary] = []
var _events: Array[Dictionary] = []


func _init(shared_ledger: RefCounted = null) -> void:
	if shared_ledger != null:
		ledger = shared_ledger
	if ledger.inspect_entity("receiving").is_empty():
		_must(ledger.add_place("receiving", "F02 Receiving storage (5000 kg)", RECEIVING))
	if ledger.inspect_entity("personnel").is_empty():
		_must(ledger.add_place("personnel", "F08 Personnel arrival point", PERSONNEL))
	receiving_position = ledger.inspect_entity("receiving").position
	personnel_position = ledger.inspect_entity("personnel").position
	_must(ledger.add_place("rear-lane", "Predefined rear access/handling lane", Vector2.ZERO))
	_must(ledger.add_place("supplier-transit", "Off-map external supply leg", Vector2.ZERO))


func quote_resources(cart: Dictionary) -> Dictionary:
	var quote := Catalog.quote(cart, FREIGHT_LIMIT)
	if quote.ok:
		quote.free_vehicle_places = FREIGHT_LIMIT - freight_admitted()
		quote.can_commit = quote.vehicle_count <= quote.free_vehicle_places and _money >= quote.cost
	return quote


func buy_resources(cart: Dictionary) -> Dictionary:
	var quote := quote_resources(cart)
	if not quote.ok:
		return quote
	if quote.vehicle_count > FREIGHT_LIMIT - freight_admitted():
		return _reject("FREIGHT_QUEUE_FULL", "All eleven freight commitments are reserved; wait for physical vehicle clearance or cancel an undispatched order.")
	if _money < quote.cost:
		return _reject("INSUFFICIENT_MONEY", "The complete goods and per-vehicle transport price exceeds current requisition.")
	var ids: Array[String] = []
	for vehicle in quote.vehicles:
		var order := _new_order("Freight", vehicle.cost, vehicle.cargo)
		ids.append(order.id)
	_money -= quote.cost
	_spent += quote.cost
	_event("Purchased freight; admission reserved before dispatch", ", ".join(ids))
	return _ok("Purchase committed. Cargo is incoming, not locally delivered.", ids)


func buy_people() -> Dictionary:
	if personnel_admitted() >= PERSONNEL_LIMIT:
		return _reject("PERSONNEL_QUEUE_FULL", "Both personnel vehicle commitments are occupied, including en-route/disembarking/clearing services.")
	if rear_population() + incoming_people() + _outside_rear_places() + 8 > REAR_LIMIT:
		return _reject("REAR_CAPACITY_FULL", "Eight incoming people need reserved places within the 120-place rear population limit.")
	if _money < 140:
		return _reject("INSUFFICIENT_MONEY", "Eight P00 cost 120 requisition plus the 20 transport fee.")
	var order := _new_order("Personnel", 140, {})
	order.people_reserved = 8
	_money -= 140.0
	_spent += 140
	_event("Purchased eight P00; independent admission and rear places reserved", order.id)
	return _ok("Eight people ordered. Their own disembarking needs no unloading labour.", [order.id])


func recovery_instructor_offer() -> Dictionary:
	for person in ledger.snapshot().entities:
		if person.kind == "PERSON" and person.owner == PLAYER and person.basic_training and person.health > 0 and Rect2(0,0,240,180).has_point(person.position):
			return {"available":false,"message":"A basic-trained person remains in the rear; assign an actual instructor."}
	for order in _orders:
		if order.get("recovery_instructor",false) and order.state != "Cancelled" and order.people_arrived < 1:
			return {"available":false,"message":"One recovery instructor is already pending; wait for physical Personnel receipt."}
	return {"available":true,"message":"Recovery P01: 100 requisition +20 transport, one population place, 90-second arrival plus physical handling."}


func buy_recovery_instructor() -> Dictionary:
	var offer := recovery_instructor_offer()
	if not offer.available: return _reject("RECOVERY_UNAVAILABLE",offer.message)
	if personnel_admitted() >= PERSONNEL_LIMIT: return _reject("PERSONNEL_QUEUE_FULL","Both shared personnel vehicle admissions are occupied/reserved.")
	if rear_population() + incoming_people() + _outside_rear_places() + 1 > REAR_LIMIT: return _reject("REAR_CAPACITY_FULL","One incoming instructor needs a reserved rear population place.")
	if _money < 120: return _reject("INSUFFICIENT_MONEY","Recovery instructor costs100 plus20 transport.")
	var order := _new_order("Personnel",120,{})
	order.recovery_instructor = true
	order.expected_people = 1
	order.people_reserved = 1
	_money -= 120.0
	_spent += 120
	_event("Recovery P01 purchased; one pending/personnel vehicle/rear population place reserved",order.id)
	return _ok("Recovery instructor purchased. Same person must disembark and reach Personnel; no unloading worker required.",[order.id])


func cancel_order(id: String) -> Dictionary:
	var order := _find_order(id)
	if order.is_empty() or order.state != "Ordered" or _time >= float(order.purchased_at) + 5.0:
		return _reject("CANNOT_CANCEL", "Only an undispatched order in its first five seconds can be refunded once.")
	_money += order.cost
	_refunds += order.cost
	order.people_reserved = 0
	order.admission = false
	_set_state(order, "Cancelled")
	order.next_at = INF
	_event("Cancelled once; money and this order's admission/population reservations returned", id)
	return _ok("Full refund completed; no goods or people were dispatched.", [id])


func assign_unloaders(count: int) -> Dictionary:
	if count <= 0 or count + _workers.size() > STAFF_LIMIT:
		return _reject("STAFF_POSITIONS_FULL", "The predefined F02 has four actual unloading positions.")
	var eligible: Array[String] = []
	for person in ledger.snapshot().entities:
		if person.kind == "PERSON" and person.owner == PLAYER and person.assignment == "Available" and person.pending_assignment == "None":
			eligible.append(person.id)
	eligible.sort()
	if eligible.size() < count:
		return _reject("MISSING_PEOPLE", "Not enough real, available player people. Incoming passengers and supplier drivers cannot unload.")
	var assigned: Array[String] = []
	for index in range(count):
		var id := eligible[index]
		_must(ledger.request_assignment(id, Records.Assignment.REAR_LABOUR, "Receiving"))
		_workers[id] = {"person_id": id, "job": {}}
		assigned.append(id)
	_pump()
	return _ok("Assigned real people; they must walk to the truck before unloading.", assigned)


func release_unloaders() -> Dictionary:
	if _workers.is_empty():
		return _reject("NO_UNLOADERS", "There are no Receiving assignments to release.")
	for id in _workers:
		var pending: String = ledger.inspect_entity(id).pending_assignment
		if pending not in ["None", "Available"]:
			return _reject("HANDOFF_PENDING", "Cancel or complete the existing pending duty request before replacing it.")
	for id in _workers.keys():
		if ledger.inspect_entity(id).pending_assignment == "None":
			_must(ledger.request_assignment(id, Records.Assignment.AVAILABLE, ""))
	_sync_workers()
	return _ok("Reassignment requested. Active carries finish safe deposit before becoming Available.")


func advance_time(seconds: float) -> Dictionary:
	if not is_finite(seconds) or seconds < 0.0 or not is_finite(_time + seconds):
		return _reject("INVALID_TIME", "Advance by a finite, nonnegative number of simulation seconds.")
	var target := _time + seconds
	_pump()
	while _time < target:
		var next := minf(target, next_boundary())
		_must(ledger.advance_time(next - _time))
		advance_clock_to(next)
		_pump()
	return _ok("Simulation advanced; only elapsed physical activities complete.")


func next_boundary() -> float:
	var boundary := INF
	for order in _orders:
		if order.next_at > _time: boundary = minf(boundary, order.next_at)
	for walk in _walks: boundary = minf(boundary, walk.ends_at)
	for worker in _workers.values():
		if not worker.job.is_empty(): boundary = minf(boundary, worker.job.ends_at)
	return boundary


func advance_clock_to(next: float) -> void:
	# The integrated rear advances its ledger once and calls this at each joint boundary.
	var delta := next - _time
	_income += delta * 6.0
	_money += delta * 6.0
	_time = next
	_move_activities()


func free_receiving_kg() -> int:
	var physical_room := STORAGE_KG - receiving_kg() - reserved_storage_kg()
	if receiving_room.is_valid():
		return mini(physical_room, maxi(0, int(receiving_room.call()) - reserved_storage_kg()))
	return physical_room


func freight_admitted() -> int:
	return _admitted("Freight")


func personnel_admitted() -> int:
	return _admitted("Personnel")


func incoming_people() -> int:
	var count: int = 0
	for order in _orders:
		count += order.people_reserved
	return count

func _outside_rear_places() -> int:
	return int(external_rear_reservations.call()) if external_rear_reservations.is_valid() else 0


func rear_population() -> int:
	# This bounded simulation owns rear people only. Forward/strategic membership
	# is deliberately not inferred; the shared-world policy remains D03.
	var count: int = 0
	for entity in ledger.snapshot().entities:
		if entity.kind == "PERSON" and entity.owner == PLAYER and entity.get("rear_place","None") in ["Occupied","Held Home"]:
			count += 1
	return count


func receiving_kg() -> int:
	return int(ledger.loose_stock_mass_at("receiving"))


func reserved_storage_kg() -> int:
	var mass: int = 0
	for worker in _workers.values():
		if not worker.job.is_empty():
			mass += worker.job.quantity
	return mass


func resource_counts(code: String) -> Dictionary:
	var result := {"purchased": 0, "ordered": 0, "incoming": 0, "onboard": 0, "carried": 0, "unloaded": 0, "available": 0}
	for order in _orders:
		if order.kind != "Freight" or order.state == "Cancelled":
			continue
		result.purchased += order.cargo.get(code, 0)
		result.unloaded += order.unloaded.get(code, 0)
		if order.state == "Ordered":
			result.ordered += order.cargo.get(code, 0)
		for source_id in order.stock_ids:
			var stock := ledger.inspect_entity(source_id)
			if stock.design_type == code:
				if order.state == "Incoming":
					result.incoming += stock.quantity
				else:
					result.onboard += stock.quantity
	for worker in _workers.values():
		if not worker.job.is_empty() and worker.job.phase in ["Carry", "Drop"] and worker.job.code == code:
			result.carried += worker.job.quantity
	result.available = ledger.available_stock_at("receiving", code)
	return result


func snapshot() -> Dictionary:
	var orders: Array[Dictionary] = []
	for order in _orders:
		var view := order.duplicate(true)
		view.blocked_reason = _order_blocker(order)
		orders.append(view)
	return {"time": _time, "money": _money, "income": _income, "spent": _spent, "refunds": _refunds,
		"orders": orders, "workers": _workers.duplicate(true), "walks": _walks.duplicate(true),
		"order_sequence": _order_sequence, "job_sequence": _job_sequence,
		"events": _events.duplicate(true), "ledger": ledger.snapshot(), "recovery_offer":recovery_instructor_offer()}


func audit() -> Array[String]:
	var failures := ledger.audit()
	if freight_admitted() > FREIGHT_LIMIT or personnel_admitted() > PERSONNEL_LIMIT:
		failures.append("Vehicle admission overbooked")
	if rear_population() + incoming_people() + _outside_rear_places() > REAR_LIMIT:
		failures.append("Rear population overbooked")
	if receiving_kg() + reserved_storage_kg() > STORAGE_KG:
		failures.append("Receiving storage overbooked")
	if not is_equal_approx(_money, 2500.0 + _income - _spent + _refunds):
		failures.append("Money does not reconcile")
	var pending_recovery := 0
	for order in _orders:
		if order.recovery_instructor and order.state != "Cancelled" and order.people_arrived < 1: pending_recovery += 1
		if order.recovery_instructor and order.expected_people != 1: failures.append("Recovery arrival must reserve one person")
		if order.admission != (order.state not in ["Cancelled", "Complete"]):
			failures.append("Invalid vehicle admission lifecycle: " + order.id)
		if order.people_reserved < 0 or order.people_reserved > 8:
			failures.append("Invalid incoming people reservation: " + order.id)
		if order.people_arrived < 0 or order.people_arrived > order.people_exited or order.people_exited > order.passenger_ids.size():
			failures.append("Invalid passenger exit/arrival progress: " + order.id)
		if order.kind == "Personnel" and order.state != "Cancelled" and order.people_reserved + order.people_arrived != order.expected_people:
			failures.append("Incoming places do not reconcile with actual arrivals: " + order.id)
	if pending_recovery > 1: failures.append("Multiple pending recovery instructors")
	return failures


func _new_order(kind: String, cost: int, cargo: Dictionary) -> Dictionary:
	_order_sequence += 1
	var id := "delivery-%04d" % _order_sequence
	var order := {"id": id, "kind": kind, "owner": PLAYER, "cost": cost,
		"cargo": cargo.duplicate(), "unloaded": {}, "stock_ids": [], "passenger_ids": [],
		"expected_people":8,"recovery_instructor":false,"people_reserved": 0, "people_exited": 0, "people_arrived": 0, "admission": true, "slot": -1,
		"state": "Ordered", "purchased_at": _time, "state_entered_at": _time,
		"arrival_at": _time + (60.0 if kind == "Freight" else 90.0),
		"next_at": _time + 5.0, "motion": {}}
	_orders.append(order)
	return order


func _pump() -> void:
	_sync_workers()
	var again := true
	while again:
		again = false
		for order in _orders:
			if order.next_at > _time:
				continue
			match order.state:
				"Ordered":
					_dispatch(order)
				"Incoming":
					_set_state(order, "Waiting")
					order.next_at = INF
					order.motion = {}
				"Berthing":
					order.motion = {}
					order.next_at = INF
					_set_state(order, "Berthed")
					if order.kind == "Personnel":
						_disembark(order)
				"Disembarking":
					_exit_passenger(order)
				"Departing":
					order.motion = {}
					order.next_at = INF
					order.admission = false
					_set_state(order, "Complete")
					_must(ledger.move_entity(order.id, "supplier-transit", _exit(order)))
					_event("Supplier vehicle physically cleared; its one admission released", order.id)
				_:
					continue
			again = true
		for walk in _walks.duplicate():
			if walk.ends_at <= _time:
				var order := _find_order(walk.order_id)
				_must(ledger.complete_person_arrival(walk.person_id, "personnel", PLAYER))
				order.people_reserved -= 1
				order.people_arrived += 1
				_walks.erase(walk)
				_event("Same arriving person disembarked; incoming place becomes one physical rear person", walk.person_id)
				again = true
		for id in _workers.keys():
			var job: Dictionary = _workers[id].job
			if not job.is_empty() and job.ends_at <= _time:
				_finish_worker_phase(id)
				again = true
		_sync_workers()
		for order in _orders:
			if order.state == "Waiting" and _slot_for(order.kind) != -1:
				order.slot = _slot_for(order.kind)
				_start_vehicle_motion(order, "Berthing", _berth(order))
				again = true
			if order.state == "Berthed" and _freight_finished(order):
				_start_vehicle_motion(order, "Departing", _exit(order))
				again = true
			if order.state == "Disembarking" and order.people_arrived == order.expected_people:
				_start_vehicle_motion(order, "Departing", _exit(order))
				again = true
		for id in _workers:
			if _workers[id].job.is_empty() and _start_worker_job(id):
				again = true


func _dispatch(order: Dictionary) -> void:
	_must(ledger.add_carrier(order.id, "supplier-transit", SUPPLIER, SUPPLIER))
	_must(ledger.add_person(order.id + "-driver", order.id, SUPPLIER,
		Records.Assignment.STRATEGIC_CREW, true, "P08"))
	if order.kind == "Freight":
		for code in order.cargo:
			var stock_id: String = order.id + "-" + code
			_must(ledger.add_stock(stock_id, code, order.cargo[code], 1.0, order.id, PLAYER))
			order.stock_ids.append(stock_id)
	else:
		for index in range(order.expected_people):
			var person_id := "%s-person-%02d" % [order.id, index + 1]
			_must(ledger.add_person(person_id, order.id, SUPPLIER, Records.Assignment.PASSENGER, order.recovery_instructor))
			order.passenger_ids.append(person_id)
	var gate := _gate(order)
	var origin := gate - Vector2(_speed(order) * (order.arrival_at - _time), 0)
	_must(ledger.move_entity(order.id, "supplier-transit", origin))
	order.motion = {"path": [origin, gate], "started_at": _time, "ends_at": order.arrival_at}
	order.next_at = order.arrival_at
	_set_state(order, "Incoming")
	_event("Dispatched real external carrier, driver and cargo/passengers", order.id)


func _disembark(order: Dictionary) -> void:
	_set_state(order, "Disembarking")
	order.next_at = _time + PASSENGER_EXIT_SECONDS
	_event("Stopped; one passenger exit per second, independently for this vehicle", order.id)


func _exit_passenger(order: Dictionary) -> void:
	# Keep each passenger physically aboard until their own handling completes.
	# Walking and population admission happen afterward, independently per person.
	var id: String = order.passenger_ids[order.people_exited]
	var origin: Vector2 = ledger.inspect_entity(order.id).position
	var path: Array = _worker_path(origin, personnel_position) if route.is_valid() else [origin, Vector2(20, 96), PERSONNEL]
	_must(ledger.move_entity(id, "rear-lane", origin))
	_walks.append({"order_id": order.id, "person_id": id, "path": path,
		"started_at": _time, "ends_at": _time + _path_length(path) / 1.5})
	order.people_exited += 1
	order.next_at = _time + PASSENGER_EXIT_SECONDS if order.people_exited < order.passenger_ids.size() else INF
	_event("One passenger completed exit and starts their own walk; incoming place remains reserved", id)


func _start_worker_job(id: String) -> bool:
	var room := free_receiving_kg()
	if room <= 0:
		return false
	for order in _orders:
		if order.kind != "Freight" or order.state != "Berthed":
			continue
		for source_id in order.stock_ids:
			var quantity := mini(25, mini(room, ledger.available(source_id)))
			if quantity <= 0:
				continue
			_job_sequence += 1
			var claim_id := "receiving-job-%04d" % _job_sequence
			_must(ledger.request_stock(claim_id, source_id, quantity, id, "Physical Receiving unload", PLAYER))
			var job := {"order_id": order.id, "source_id": source_id, "quantity": quantity,
				"code": ledger.inspect_entity(source_id).design_type, "claim_id": claim_id,
				"phase": "Approach", "started_at": _time}
			var origin: Vector2 = ledger.inspect_entity(id).position
			job.path = _worker_path(origin, FREIGHT_BERTH)
			job.ends_at = _time + _path_length(job.path) / 1.5
			_workers[id].job = job
			_event("Reserved source and destination before walking to pickup", claim_id)
			return true
	return false


func _finish_worker_phase(id: String) -> void:
	var job: Dictionary = _workers[id].job
	match job.phase:
		"Approach":
			job.phase = "Pickup"
			job.started_at = _time
			job.ends_at = _time + 2.0
			job.path = []
		"Pickup":
			_must(ledger.begin_carry(id, job.source_id, job.quantity, job.claim_id))
			job.phase = "Carry"
			job.path = _worker_path(FREIGHT_BERTH, receiving_position) if route.is_valid() else [FREIGHT_BERTH, RECEIVING]
			job.started_at = _time
			job.ends_at = _time + _path_length(job.path) / 1.2
		"Carry":
			job.phase = "Drop"
			job.path = []
			job.started_at = _time
			job.ends_at = _time + 2.0
		"Drop":
			_must(ledger.finish_carry(id, "receiving"))
			var order := _find_order(job.order_id)
			order.unloaded[job.code] = order.unloaded.get(job.code, 0) + job.quantity
			_must(ledger.release_claim(job.claim_id))
			_workers[id].job = {}
			_event("Actual carried stock deposited; destination reservation consumed once", id)


func _sync_workers() -> void:
	for id in _workers.keys():
		var person := ledger.inspect_entity(id)
		var still_assigned: bool = person.assignment == "Rear Labour" and person.duty_id in ["Receiving", "receiving"]
		var job: Dictionary = _workers[id].job
		if not job.is_empty() and job.phase in ["Carry", "Drop"]:
			continue # G01 retains the old duty until the carried freight is deposited.
		if not still_assigned or person.pending_assignment != "None":
			if not job.is_empty():
				_must(ledger.release_claim(job.claim_id))
			_workers.erase(id)


func _move_activities() -> void:
	for order in _orders:
		if not order.motion.is_empty():
			_must(ledger.move_entity(order.id, "supplier-transit" if order.state == "Incoming" else "rear-lane", _motion_position(order.motion)))
	for walk in _walks:
		_must(ledger.move_entity(walk.person_id, "rear-lane", _motion_position(walk)))
	for id in _workers:
		var job: Dictionary = _workers[id].job
		if not job.is_empty() and not job.path.is_empty():
			_must(ledger.move_entity(id, "rear-lane", _motion_position(job)))


func _start_vehicle_motion(order: Dictionary, state: String, destination: Vector2) -> void:
	var origin: Vector2 = ledger.inspect_entity(order.id).position
	_set_state(order, state)
	order.next_at = _time + origin.distance_to(destination) / _speed(order)
	order.motion = {"path": [origin, destination], "started_at": _time, "ends_at": order.next_at}


func _slot_for(kind: String) -> int:
	var count := 1 if kind == "Freight" else 2
	for slot in range(count):
		var occupied := false
		for order in _orders:
			if order.kind == kind and order.slot == slot and order.state in ["Berthing", "Berthed", "Disembarking", "Departing"]:
				occupied = true
		if not occupied:
			return slot
	return -1


func _freight_finished(order: Dictionary) -> bool:
	if order.kind != "Freight":
		return false
	for code in order.cargo:
		if order.unloaded.get(code, 0) < order.cargo[code]:
			return false
	return true


func _order_blocker(order: Dictionary) -> String:
	match order.state:
		"Ordered": return "Dispatch at five seconds; full refund is still available"
		"Incoming": return "Supplier still travelling; local stock/people unavailable"
		"Waiting": return "Waiting for physical berth/pull-off clearance"
		"Berthing": return "Vehicle is physically approaching its reserved place"
		"Disembarking":
			if order.people_exited < order.passenger_ids.size(): return "Passengers exit one per second from this stopped vehicle, then walk; no unloading worker is required"
			return "All passengers exited; remaining walks to Personnel still reserve incoming places"
		"Departing": return "Supplier vehicle still clearing; admission remains occupied"
		"Berthed":
			if _workers.is_empty(): return "Missing actual Receiving unloaders"
			if free_receiving_kg() <= 0: return "Receiving storage full or reserved; remainder stays aboard"
			return "Unloaders must approach, pick up, carry and deposit real freight"
		"Cancelled": return "Cancelled and refunded once"
		_: return "Complete; supplier service remains external"


func _admitted(kind: String) -> int:
	var count: int = 0
	for order in _orders:
		if order.kind == kind and order.admission:
			count += 1
	return count


func _find_order(id: String) -> Dictionary:
	for order in _orders:
		if order.id == id:
			return order
	return {}


func _set_state(order: Dictionary, state: String) -> void:
	order.state = state
	order.state_entered_at = _time


func _gate(order: Dictionary) -> Vector2:
	return FREIGHT_GATE if order.kind == "Freight" else Vector2(0, 100)


func _berth(order: Dictionary) -> Vector2:
	return FREIGHT_BERTH if order.kind == "Freight" else Vector2(16 + order.slot * 8, 100)


func _exit(order: Dictionary) -> Vector2:
	return FREIGHT_EXIT if order.kind == "Freight" else Vector2(-12, 100)


func _speed(order: Dictionary) -> float:
	return 12.0 if order.kind == "Freight" else 15.0 # GDD T01/T02 road values.


func _worker_path(origin: Vector2, destination: Vector2) -> Array:
	if route.is_valid(): return route.call(origin, destination)
	if origin.y > 31.0:
		return [origin, Vector2(32, origin.y), Vector2(32, destination.y), destination]
	return [origin, destination]


func _path_length(path: Array) -> float:
	var total: float = 0.0
	for index in range(1, path.size()):
		total += (path[index - 1] as Vector2).distance_to(path[index])
	return total


func _motion_position(motion: Dictionary) -> Vector2:
	var path: Array = motion.path
	var fraction := clampf((_time - motion.started_at) / (motion.ends_at - motion.started_at), 0.0, 1.0)
	var distance := _path_length(path) * fraction
	for index in range(1, path.size()):
		var from: Vector2 = path[index - 1]
		var to: Vector2 = path[index]
		var length := from.distance_to(to)
		if distance <= length and length > 0.0:
			return from.lerp(to, distance / length)
		distance -= length
	return path.back()


func _event(description: String, id: String) -> void:
	_events.append({"time": _time, "id": id, "description": description})


func _must(result: Dictionary) -> void:
	if not result.ok:
		push_error("Receiving activity invariant failed: " + str(result))


func _ok(message: String, ids: Array = []) -> Dictionary:
	return {"ok": true, "code": "OK", "message": message, "ids": ids}


func _reject(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "ids": []}
