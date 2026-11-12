extends RefCounted
signal convoy_changed
signal supplier_state_changed
signal worker_activity_changed(person_id: String)
## G02's one predefined Receiving bay and independent Personnel pull-off.
## Timed service activities use G01's physical identities, never a staff-count grant.

const Ledger = preload("res://game/identity/identity_ledger.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Catalog = preload("res://game/procurement/resource_catalog.gd")
const Packages = preload("res://game/warehousing/material_packages.gd")
const Packing = preload("res://game/supplier_transport/cargo_packing.gd")
const Freight = preload("res://game/supplier_transport/supplier_freight.gd")
const Seating = preload("res://game/supplier_transport/supplier_seating.gd")
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
var freight_berths: Array[Dictionary] = [{"store":"receiving","berth":FREIGHT_BERTH,"receiving_position":RECEIVING,"duty":"receiving","site":"initial-receiving"}]
var personnel_position := PERSONNEL
var supply_table_access := false
var development_convoys := false
var _convoy_sequence := 0
var _convoy_pending: Dictionary = {}
var _active_suppliers: Dictionary = {}
const ROAD_Y := 200.0
const DROP_OFF := Vector2(120,200)
var route: Callable
var work_point: Callable # Optional rear owner reserves distinct physical service points.
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
var warehouse: RefCounted
var _storage_attempts: Dictionary = {}
var _storage_warning_dirty := false
var freight: RefCounted
var road: RefCounted
var passengers: RefCounted
var returns: RefCounted
var _packing_key := ""
var _packing_quote: Dictionary = {}

func bind_warehouse(owner: RefCounted) -> void:
	warehouse = owner
	var service_ref: WeakRef = weakref(self)
	warehouse.space_changed.connect(func() -> void:
		var service: RefCounted = service_ref.get_ref()
		if service != null: service._warehouse_changed())

func _warehouse_changed() -> void:
	# Queue a boundary; never run the simulation inside a Ledger/Area3D signal.
	for worker: Dictionary in _workers.values():
		var job: Dictionary = worker.job
		if not job.is_empty() and job.phase in ["Storage blocked","Storage access","Carry blocked"]: job.ends_at = _time
	_storage_warning_dirty = true
	supplier_state_changed.emit()

func _refresh_storage_warnings() -> void:
	for order: Dictionary in _active_suppliers.values():
		if order.kind != "Freight" or order.state != "Berthed": continue
		var preparing := false
		var blocked := false
		for worker: Dictionary in _workers.values():
			var job: Dictionary = worker.job
			if job.get("order_id","") != order.id: continue
			if job.phase in ["Storage approach","Preparing storage","Storage settling"]: preparing = true
			if job.phase == "Storage blocked": blocked = true
		var has_cargo := false
		var has_space := false
		for source_id: String in order.stock_ids:
			var available: int = ledger.available(source_id)
			if available <= 0: continue
			has_cargo = true
			var code: String = str(ledger.inspect_entity(source_id,{},false).design_type)
			var state: String = warehouse.physical_space_status(code,mini(available,Packages.capacity(code)))
			if state in ["Ready","Unprepared"]: has_space = true
			elif state == "Preparing": preparing = true
		var message: String = str(order.get("storage_warning",""))
		if preparing: message = "Preparing storage — haulers are preparing positions"
		elif has_cargo and not has_space: message = "Warehouse full — free storage or expand"
		elif not blocked and (not has_cargo or message.begins_with("Warehouse full") or message.begins_with("Preparing storage")): message = ""
		if message != str(order.get("storage_warning","")):
			order.storage_warning = message
			supplier_state_changed.emit()


func _init(shared_ledger: RefCounted = null) -> void:
	if shared_ledger != null:
		ledger = shared_ledger
	if ledger.inspect_entity("receiving").is_empty():
		_must(ledger.add_place("receiving", "F02 Receiving storage (5000 kg)", RECEIVING))
	if ledger.inspect_entity("personnel").is_empty():
		_must(ledger.add_place("personnel", "F08 Personnel arrival point", PERSONNEL))
	receiving_position = ledger.inspect_entity("receiving").position
	freight_berths[0].receiving_position = receiving_position
	personnel_position = ledger.inspect_entity("personnel").position
	freight = Freight.new(self)
	returns = preload("res://game/supplier_transport/supplier_returns.gd").new(self)
	road = preload("res://game/supplier_transport/supplier_road.gd").new(self)
	passengers = preload("res://game/supplier_transport/supplier_passengers.gd").new(self)
	_must(ledger.add_place("rear-lane", "Predefined rear access/handling lane", Vector2.ZERO))
	_must(ledger.add_place("supplier-transit", "Off-map external supply leg", Vector2.ZERO))


func configure_supply_table() -> void:
	# Same purchase/admission/handling service, with no F02/F08 prerequisite.
	assert(_time == 0.0 and _orders.is_empty())
	supply_table_access = true
	development_convoys = true
	freight_berths[0].berth = Vector2(132,ROAD_Y)
	freight_berths[0].site = "supply-table"

func convoy_ready() -> bool:
	return _convoy_pending.is_empty()

func _spatial_quote(cart: Dictionary) -> Dictionary:
	var limit := freight_limit()
	var validated: Dictionary = Catalog.quote(cart,limit)
	if not validated.ok: return validated
	var keys: Array = cart.keys()
	keys.sort()
	var pieces := PackedStringArray([str(limit)])
	for code: String in keys: pieces.append("%s:%d" % [code,int(cart[code])])
	var key := "/".join(pieces)
	if key != _packing_key:
		_packing_quote = Packing.quote(cart,limit)
		_packing_key = key
	return _packing_quote.duplicate(true)

func quote_delivery(cart: Dictionary, workers: bool = false) -> Dictionary:
	var quote: Dictionary = {"ok":true,"vehicles":[],"vehicle_count":0,"mass_kg":0,"transport_fees":0,"cost":0,"message":"Choose resources or eight workers."}
	if not cart.is_empty(): quote = _spatial_quote(cart)
	if not quote.ok: return quote
	quote.workers = 8 if workers else 0
	quote.cost += 140 if workers else 0
	quote.transport_fees += 20 if workers else 0
	quote.total_vehicles = int(quote.vehicle_count)+(1 if workers else 0)
	var reason := ""
	if quote.total_vehicles == 0: reason = "Choose resources or eight workers."
	elif not convoy_ready(): reason = "Previous convoy is unloading or approaching. Ordering reopens when its last truck starts leaving."
	elif quote.vehicle_count > freight_limit()-freight_admitted(): reason = "Supplier freight places remain occupied by clearing vehicles."
	elif workers and personnel_admitted() >= PERSONNEL_LIMIT: reason = "Personnel vehicles are still clearing."
	elif workers and rear_population()+incoming_people()+_outside_rear_places()+8 > REAR_LIMIT: reason = "Eight workers need free rear population places."
	elif _money < quote.cost: reason = "Not enough requisition for the complete order."
	quote.can_commit = reason.is_empty()
	quote.message = reason if not reason.is_empty() else "Ready to confirm. Trucks appear at the south road and unload physically."
	return quote

func buy_delivery(cart: Dictionary, workers: bool = false) -> Dictionary:
	if not development_convoys: return _reject("UNAVAILABLE","Combined convoy orders belong to the development opening.")
	# Entire quote is validated before creating any order or debiting its account.
	var quote: Dictionary = quote_delivery(cart,workers)
	if not quote.ok: return quote
	if not quote.can_commit: return _reject("ORDER_UNAVAILABLE",str(quote.message))
	var created: Array[Dictionary] = []
	for vehicle: Dictionary in quote.vehicles: created.append(_new_order("Freight",vehicle.cost,vehicle.cargo,vehicle))
	if workers:
		var people: Dictionary = _new_order("Personnel",140,{})
		people.people_reserved = 8
		created.append(people)
	_money -= quote.cost
	_spent += quote.cost
	_begin_convoy(created)
	return _ok("Order confirmed. The paid convoy is at the south road; unloaders and passengers still act physically.",created.map(func(row: Dictionary) -> String: return row.id))

func _begin_convoy(created: Array[Dictionary]) -> void:
	_convoy_sequence += 1
	for index in created.size():
		var order: Dictionary = created[index]
		order.convoy = _convoy_sequence
		order.convoy_index = index
		_convoy_pending[order.id] = true
	for order: Dictionary in created: _dispatch(order)
	convoy_changed.emit()

func supplier_vehicle_views() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for order: Dictionary in _active_suppliers.values():
		rows.append({"id":order.id,"kind":order.kind,"state":order.state,"state_started":float(order.state_entered_at),"driver_id":str(order.id)+"-driver","position":ledger._world_position(order.id),"facing_degrees":float(order.get("facing_degrees",0.0)),"storage_warning":str(order.get("storage_warning","")),"moving":not order.motion.is_empty(),"mechanism":str(order.get("mechanism","")),"mechanism_started":float(order.get("mechanism_started",0.0)),"packages":order.packet_manifest.duplicate(true),"racks":order.rack_manifest.duplicate(true),"aboard":order.get("aboard_packets",{}).duplicate()})
	return rows

func worker_height(id: String, at: Vector2) -> float:
	var job: Dictionary = _workers.get(id,{}).get("job",{})
	if job.get("phase","") not in ["Approach","Pickup","Truck egress","Truck return"]: return 0.0
	var order: Dictionary = _find_order(str(job.order_id))
	return Freight.height(order,at) if not order.get("packet_manifest",[]).is_empty() else 0.0

func requisition_balance() -> float:
	return _money


func quote_resources(cart: Dictionary) -> Dictionary:
	var quote := Catalog.quote(cart, freight_limit())
	if quote.ok:
		quote.free_vehicle_places = freight_limit() - freight_admitted()
		quote.can_commit = quote.vehicle_count <= quote.free_vehicle_places and _money >= quote.cost
	return quote


func buy_resources(cart: Dictionary) -> Dictionary:
	if development_convoys: return buy_delivery(cart)
	var quote := quote_resources(cart)
	if not quote.ok:
		return quote
	if quote.vehicle_count > freight_limit() - freight_admitted():
		return _reject("FREIGHT_QUEUE_FULL", "All freight commitments are reserved; wait for physical vehicle clearance or cancel an undispatched order.")
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


func debug_pending_resource_mass(ids: Array = []) -> int:
	var mass := 0
	for order in _orders:
		if order.kind != "Freight" or order.state in ["Cancelled","Complete"] or (not ids.is_empty() and order.id not in ids): continue
		for code in order.cargo:
			mass += maxi(0,int(order.cargo[code])-int(order.unloaded.get(code,0)))
	return mass


func debug_order_raw_resources() -> Dictionary:
	var cart := {}
	for code in Catalog.MATERIALS: cart[code] = 1000
	var quote: Dictionary = Catalog.quote(cart,2)
	if not quote.ok: return quote
	var ids: Array[String] = []
	for vehicle in quote.vehicles:
		var order := _new_order("Freight",0,vehicle.cargo)
		order.debug_free = true
		ids.append(order.id)
	_event("DEBUG ordered1000 of each raw resource at zero cost",", ".join(ids))
	return _ok("Free debug resource batch ordered.",ids)


func debug_deliver_resources(destination: String, ids: Array = []) -> Dictionary:
	if ledger.entity_kind(destination) != "PLACE":
		return _reject("INVALID_DEBUG_STORAGE","Debug delivery needs an existing rear storage place.")
	var pending := {}
	for order in _orders:
		if order.kind == "Freight" and order.state not in ["Cancelled","Complete"] and (ids.is_empty() or order.id in ids):
			pending[order.id] = order
	for person_id: String in _workers:
		var job: Dictionary = _workers[person_id].job
		if not job.is_empty() and pending.has(job.order_id) and not str(ledger.inspect_person_status(person_id).get("joint_carry_id","")).is_empty():
			return _reject("JOINT_HANDOFF_REQUIRED","Finish the actual shared timber handoff before this debug delivery; nothing changed.")
	for order: Dictionary in pending.values(): returns.abandon_for_debug(order)
	# Release reserved source portions before transferring any remaining cargo.
	for worker in _workers.values():
		var job: Dictionary = worker.job
		if job.is_empty() or not pending.has(job.order_id): continue
		if not ledger.inspect_claim(str(job.claim_id)).get("cancelled",true):
			var released: Dictionary = ledger.release_claim(job.claim_id)
			if not released.ok: return released
	for person_id in _workers:
		var job: Dictionary = _workers[person_id].job
		if job.is_empty() or not pending.has(job.order_id): continue
		var person: Dictionary = ledger.inspect_person_status(person_id)
		if not str(person.get("carrying_stock_id","")).is_empty():
			var deposited: Dictionary = ledger.debug_deposit_stock(str(person.carrying_stock_id),destination,PLAYER)
			if not deposited.ok: return deposited
			var order: Dictionary = pending[job.order_id]
			order.unloaded[job.code] = int(order.unloaded.get(job.code,0))+int(deposited.quantity)
		if not str(person.get("supplier_access_id","")).is_empty():
			var order: Dictionary = pending[job.order_id]
			var exit_point := Freight.to_world(order,Vector3(0,0,Freight.REAR_Z))
			_must(ledger.move_entity(person_id,"rear-lane",exit_point)) # Explicit debug travel bypass.
			ledger.register_handling_point(str(order.id),person_id,exit_point)
			_must(ledger.release_supplier_access(person_id,str(order.id)))
			ledger.release_handling_points(person_id,str(order.id))
			freight.release_aisle(order)
		if warehouse != null:
			if job.has("storage"): warehouse.release(str(job.storage))
			warehouse.release_point(person_id)
		ledger.release_handling_points(person_id,destination)
		ledger.release_handling_points(person_id,"receiving")
		_workers[person_id].job = {}
	var completed: Array[String] = []
	for order: Dictionary in pending.values():
		if order.state == "Ordered": _dispatch(order)
		for stock_id in order.stock_ids:
			var deposited: Dictionary = ledger.debug_deposit_stock(stock_id,destination,PLAYER)
			if not deposited.ok: return deposited
			order.unloaded[deposited.type] = int(order.unloaded.get(deposited.type,0))+int(deposited.quantity)
		var moved: Dictionary = ledger.move_entity(order.id,"supplier-transit",_exit(order))
		if not moved.ok: return moved
		order.motion = {}
		order.next_at = INF
		order.admission = false
		order.debug_delivered = true
		order.departure_started = true # Explicit debug bypass includes road clearance.
		_set_state(order,"Complete")
		completed.append(order.id)
	_event("DEBUG incoming resource orders delivered immediately",", ".join(completed))
	var result := _ok("DEBUG: delivered %d pending resource order(s) immediately." % completed.size(),completed)
	result.changed = not completed.is_empty()
	return result


func debug_deliver_people() -> Dictionary:
	var ids: Array[String] = []
	var arrived := 0
	for order in _orders:
		if order.kind != "Personnel" or order.state == "Cancelled" or (order.state == "Complete" and int(order.people_arrived) == int(order.expected_people)): continue
		if order.state == "Ordered": _dispatch(order)
		for person_id in order.passenger_ids:
			var person: Dictionary = ledger.inspect_person_status(person_id)
			# Player-owned passengers already arrived, even if reassigned/deployed.
			if person.get("owner","") == PLAYER: continue
			if person.get("owner","") != SUPPLIER or person.get("assignment","") != "Passenger":
				return _reject("INVALID_DEBUG_PASSENGER","Only the same actual arriving passenger may be force-delivered.")
			var moved: Dictionary = ledger.move_entity(person_id,"personnel",personnel_position)
			if not moved.ok: return moved
			var completed: Dictionary = ledger.complete_person_arrival(person_id,"personnel",PLAYER)
			if not completed.ok: return completed
			_walks = _walks.filter(func(walk: Dictionary) -> bool: return walk.person_id != person_id)
			order.people_arrived += 1
			order.people_reserved -= 1
			order.people_exited = maxi(int(order.people_exited),int(order.people_arrived))
			arrived += 1
		if order.people_arrived != order.expected_people:
			return _reject("INCOMPLETE_DEBUG_ARRIVAL","Personnel arrival counts do not match the actual purchased passengers.")
		if development_convoys: passengers.debug_clear(order)
		var moved: Dictionary = ledger.move_entity(order.id,"supplier-transit",_exit(order))
		if not moved.ok: return moved
		order.people_exited = order.expected_people
		if order.has("aboard_people"): order.aboard_people.clear()
		order.motion = {}
		order.next_at = INF
		order.admission = false
		order.debug_delivered = true
		order.departure_started = true # Same explicit debug travel bypass.
		_set_state(order,"Complete")
		ids.append(order.id)
	_event("DEBUG same purchased personnel delivered immediately",", ".join(ids))
	var result := _ok("DEBUG: delivered %d arriving worker(s) immediately." % arrived,ids)
	result.people = arrived
	result.changed = not ids.is_empty()
	return result


func buy_people() -> Dictionary:
	if development_convoys: return buy_delivery({},true)
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
	if ledger.has_trained_person_in(PLAYER, Rect2(0,0,240,210 if development_convoys else 180)):
		return {"available":false,"message":"A basic-trained person remains in the rear; assign an actual instructor."}
	for order in _orders:
		if order.get("recovery_instructor",false) and order.state != "Cancelled" and order.people_arrived < 1:
			return {"available":false,"message":"One recovery instructor is already pending; wait for physical Personnel receipt."}
	return {"available":true,"message":"Recovery P01: 100 requisition +20 transport, one population place, 90-second arrival plus physical handling."}


func buy_recovery_instructor() -> Dictionary:
	if development_convoys and not convoy_ready(): return _reject("CONVOY_BUSY","Wait for the current convoy to leave its unloading berth.")
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
	if development_convoys: _begin_convoy([order])
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
	var boundary: float = freight.next_boundary() if development_convoys else INF
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

func credit_objective_income(amount: float) -> void:
	assert(is_finite(amount) and amount >= 0.0)
	_money += amount
	_income += amount


func freight_limit() -> int:
	return 10 + freight_berths.size()

func add_freight_berth(site: String, store: String, berth: Vector2, duty: String, storage_position: Vector2) -> Dictionary:
	for row in freight_berths:
		if row.site == site or row.store == store: return _reject("DUPLICATE_BERTH","This Receiving bay already exists.")
	freight_berths.append({"site":site,"store":store,"berth":berth,"duty":duty,"receiving_position":storage_position})
	return _ok("One physical F02 berth added to the shared ten-place waiting queue.")

func berth_committed(site: String) -> bool:
	for index in freight_berths.size():
		if freight_berths[index].site != site: continue
		for order in _orders:
			if order.kind == "Freight" and order.slot == index and order.state in ["Berthing","Berthed","Departing"]: return true
	return false

func remove_freight_berth(site: String) -> Dictionary:
	for index in freight_berths.size():
		if freight_berths[index].site != site: continue
		if index == 0 or berth_committed(site): return _reject("BERTH_COMMITTED","Fixed or currently committed Receiving berth cannot be dismantled.")
		freight_berths.remove_at(index)
		for order in _orders:
			if order.kind == "Freight" and order.slot > index: order.slot -= 1
		return _ok("One physical berth removed; the ten waiting places remain shared.")
	return _reject("NO_BERTH","No such physical Receiving berth.")

func free_receiving_kg(slot: int = 0) -> int:
	if warehouse != null: return int(warehouse.free_net_kg())
	if slot < 0 or slot >= freight_berths.size(): return 0
	var physical_room := STORAGE_KG - receiving_kg(slot) - reserved_storage_kg(slot)
	if receiving_room.is_valid():
		return mini(physical_room, maxi(0, int(receiving_room.call(slot)) - reserved_storage_kg(slot)))
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
	return ledger.count_rear_people(PLAYER)


func receiving_kg(slot: int = 0) -> int:
	return int(ledger.loose_stock_mass_at(freight_berths[slot].store))


func reserved_storage_kg(slot: int = -1) -> int:
	var mass: int = 0
	for worker in _workers.values():
		if not worker.job.is_empty() and (slot < 0 or worker.job.get("slot",0) == slot):
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
			if stock.design_type == code and stock.owner == PLAYER:
				if order.state == "Incoming":
					result.incoming += stock.quantity
				else:
					result.onboard += stock.quantity
	for worker in _workers.values():
		if not worker.job.is_empty() and worker.job.phase in ["Carry", "Drop"] and worker.job.code == code:
			result.carried += worker.job.quantity
	result.available = 0
	for berth in freight_berths: result.available += ledger.available_stock_at(berth.store, code)
	return result


func snapshot(include_diagnostics: bool = true) -> Dictionary:
	var orders: Array[Dictionary] = []
	for order in _orders:
		var view := order.duplicate(true)
		view.blocked_reason = _order_blocker(order)
		view.return_info = returns.quote(order)
		orders.append(view)
	return {"time": _time, "money": _money, "income": _income, "spent": _spent, "refunds": _refunds,
		"orders": orders, "workers": _workers.duplicate(true), "walks": _walks.duplicate(true),
		"order_sequence": _order_sequence, "job_sequence": _job_sequence,
		"events": _events.duplicate(true), "ledger": ledger.snapshot() if include_diagnostics else null, "recovery_offer":recovery_instructor_offer(),
		"freight_berths":freight_berths.duplicate(true),"freight_limit":freight_limit(),"convoy_ready":convoy_ready(),"development_convoys":development_convoys}


func audit() -> Array[String]:
	var failures := ledger.audit()
	if freight_admitted() > freight_limit() or personnel_admitted() > PERSONNEL_LIMIT:
		failures.append("Vehicle admission overbooked")
	if rear_population() + incoming_people() + _outside_rear_places() > REAR_LIMIT:
		failures.append("Rear population overbooked")
	if warehouse != null:
		var promised := 0
		for promise: Dictionary in warehouse.reservations.values(): promised += int(promise.quantity)
		if int(ledger.loose_stock_mass_at("receiving"))+promised > int(warehouse.structural_capacity()): failures.append("Warehouse net stock capacity overbooked")
	else:
		for index in freight_berths.size():
			if receiving_kg(index) + reserved_storage_kg(index) > STORAGE_KG: failures.append("Receiving storage overbooked")
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


func _new_order(kind: String, cost: int, cargo: Dictionary, layout: Dictionary = {}) -> Dictionary:
	_order_sequence += 1
	var id := "delivery-%04d" % _order_sequence
	var order := {"id": id, "kind": kind, "owner": PLAYER, "cost": cost,
		"cargo": cargo.duplicate(), "unloaded": {}, "stock_ids": [], "passenger_ids": [],
		"expected_people":8,"recovery_instructor":false,"people_reserved": 0, "people_exited": 0, "people_arrived": 0, "admission": true, "slot": -1,
		"state": "Ordered", "purchased_at": _time, "state_entered_at": _time,
		"arrival_at": _time + (60.0 if kind == "Freight" else 90.0),
		"next_at": _time + 5.0, "motion": {}}
	order.packet_manifest = layout.get("packages",[]).duplicate(true)
	order.rack_manifest = layout.get("racks",[]).duplicate(true)
	# Preserve the purchase receipt; returns never reprice or refund free/debug goods.
	order.paid_prices = {}
	var goods_cost := 0
	if kind == "Freight":
		for code: String in cargo: goods_cost += int(cargo[code])*int(Catalog.MATERIALS.get(code,{}).get("price",0))
		if cost > 0 and cost >= goods_cost:
			for code: String in cargo: order.paid_prices[code] = int(Catalog.MATERIALS.get(code,{}).get("price",0))
	order.transport_paid = maxi(0,cost-goods_cost) if not order.paid_prices.is_empty() else 0
	_orders.append(order)
	return order


func _pump() -> void:
	_sync_workers()
	var again := true
	while again:
		again = freight.settle() if development_convoys else false
		if development_convoys: again = road.settle() or again
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
					if not order.packet_manifest.is_empty(): freight.begin(order)
					if order.kind == "Personnel":
						_disembark(order)
				"Disembarking":
					if development_convoys: passengers.settle(order)
					else: _exit_passenger(order)
				"Departing":
					order.motion = {}
					order.next_at = INF
					_must(ledger.move_entity(order.id, "supplier-transit", _exit(order)))
					var returned: Dictionary = returns.complete(order)
					if not returned.ok:
						order.return_error = str(returned.message)
						supplier_state_changed.emit()
						continue # Do not release admission or pay for a failed custody handover.
					order.admission = false
					_set_state(order, "Complete")
					_event("Supplier vehicle physically cleared; its one admission released", order.id)
				_:
					continue
			again = true
		for walk in _walks.duplicate():
			if walk.ends_at <= _time:
				var order := _find_order(walk.order_id)
				if development_convoys: passengers.finish(str(walk.person_id))
				_must(ledger.complete_person_arrival(walk.person_id, "personnel", PLAYER))
				order.people_reserved -= 1
				order.people_arrived += 1
				_update_convoy_gate(order)
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
			if order.state == "Berthed" and (_freight_finished(order) or returns.ready(order)):
				if order.packet_manifest.is_empty() or order.get("mechanism","") == "closed":
					_start_vehicle_motion(order, "Departing", _exit(order))
					again = true
				else: again = freight.close(order) or again
			if order.state == "Disembarking" and (bool(order.get("rear_cleared",false)) if development_convoys else order.people_arrived == order.expected_people):
				_start_vehicle_motion(order, "Departing", _exit(order))
				again = true
		for id in _workers:
			if not _workers[id].get("shared",false) and _workers[id].job.is_empty() and _start_worker_job(id):
				again = true
		if warehouse != null and _storage_warning_dirty:
			_storage_warning_dirty = false
			_refresh_storage_warnings()


func _dispatch(order: Dictionary) -> void:
	_must(ledger.add_carrier(order.id, "supplier-transit", SUPPLIER, SUPPLIER))
	_must(ledger.add_person(order.id + "-driver", order.id, SUPPLIER,
		Records.Assignment.STRATEGIC_CREW, true, "P08"))
	if order.kind == "Freight":
		if not order.packet_manifest.is_empty():
			for packet: Dictionary in order.packet_manifest:
				var stock_id: String = str(order.id)+"-"+str(packet.id)
				_must(ledger.add_stock(stock_id,str(packet.code),int(packet.quantity),1.0,str(order.id),PLAYER))
				packet.stock = stock_id
				order.stock_ids.append(stock_id)
		else:
			for code in order.cargo:
				var stock_id: String = order.id + "-" + code
				_must(ledger.add_stock(stock_id, code, order.cargo[code], 1.0, order.id, PLAYER))
				order.stock_ids.append(stock_id)
		freight.register(order)
	else:
		order.aboard_people = {}
		for index in range(order.expected_people):
			var person_id := "%s-person-%02d" % [order.id, index + 1]
			_must(ledger.add_person(person_id, order.id, SUPPLIER, Records.Assignment.PASSENGER, order.recovery_instructor))
			order.passenger_ids.append(person_id)
			order.aboard_people[person_id] = index
	var gate := _gate(order)
	var origin := Vector2(-12-float(order.get("convoy_index",0))*30,ROAD_Y) if development_convoys else gate - Vector2(_speed(order) * (order.arrival_at - _time), 0)
	if development_convoys:
		order.arrival_at = _time+origin.distance_to(gate)/_speed(order)
		_active_suppliers[order.id] = order
	order.world_position = origin
	_must(ledger.move_entity(order.id, "supplier-transit", origin))
	if development_convoys:
		_position_supplier_occupants(order)
		if order.kind == "Personnel": passengers.register(order)
	order.motion = {"path": [origin, gate], "started_at": _time, "ends_at": order.arrival_at}
	order.next_at = order.arrival_at
	_set_state(order, "Incoming")
	_event("Dispatched real external carrier, driver and cargo/passengers", order.id)


func _disembark(order: Dictionary) -> void:
	_set_state(order, "Disembarking")
	if development_convoys:
		passengers.begin(order)
		_event("Stopped; passengers prepare their feet, then exit rear-to-front through the approved push-off and landing",order.id)
		return
	order.next_at = _time + PASSENGER_EXIT_SECONDS
	_event("Stopped; one passenger exit per second, independently for this vehicle", order.id)

func _position_supplier_occupants(order: Dictionary) -> void:
	_must(ledger.position_supplier_occupant(str(order.id)+"-driver",str(order.id),Freight.to_world(order,Seating.DRIVER)))
	for id: String in order.get("aboard_people",{}):
		var seat: Dictionary = Seating.seat(int(order.aboard_people[id]))
		_must(ledger.position_supplier_occupant(id,str(order.id),Freight.to_world(order,seat.hip)))


func _exit_passenger(order: Dictionary) -> void:
	# Keep each passenger physically aboard until their own handling completes.
	# Walking and population admission happen afterward, independently per person.
	var id: String = order.passenger_ids[order.people_exited]
	var origin: Vector2 = ledger.inspect_entity(order.id).position
	var destination: Vector2 = work_point.call(id,"personnel") if work_point.is_valid() else personnel_position
	if not destination.is_finite():
		order.next_at = _time+PASSENGER_EXIT_SECONDS
		return # No free standing point: remain physically aboard.
	var path: Array = _worker_path(origin, destination) if route.is_valid() else [origin, Vector2(20, 96), PERSONNEL]
	_must(ledger.move_entity(id, "rear-lane", origin))
	if order.has("aboard_people"): order.aboard_people.erase(id)
	_walks.append({"order_id": order.id, "person_id": id, "path": path,
		"started_at": _time, "ends_at": _time + _path_length(path) / 1.5})
	order.people_exited += 1
	order.next_at = _time + PASSENGER_EXIT_SECONDS if order.people_exited < order.passenger_ids.size() else INF
	_event("One passenger completed exit and starts their own walk; incoming place remains reserved", id)


func start_shared_unload(id: String) -> bool:
	if _orders.is_empty() or (development_convoys and convoy_ready()): return false
	if _workers.has(id): return false
	var person: Dictionary = ledger.inspect_person_status(id)
	if person.duty_id != "hauling" or person.pending_assignment != "None" or person.health <= 0: return false
	_workers[id] = {"person_id":id,"job":{},"shared":true}
	if _start_worker_job(id): return true
	_workers.erase(id)
	return false


func _start_worker_job(id: String) -> bool:
	for order in _orders:
		if order.kind != "Freight" or order.state != "Berthed" or order.get("return_requested",false): continue
		if not order.packet_manifest.is_empty() and not freight.can_unload(order): continue
		var slot: int = order.slot
		var berth: Dictionary = freight_berths[slot]
		var active := 0
		for worker: Dictionary in _workers.values():
			if not worker.job.is_empty() and worker.job.slot == slot: active += 1
		if active >= STAFF_LIMIT: continue
		var duty: String = ledger.inspect_entity(id).duty_id
		if not _workers[id].get("shared",false) and duty != berth.duty and not (slot == 0 and duty == "Receiving"): continue
		var room := free_receiving_kg(slot)
		if room <= 0:
			if warehouse != null and order.get("storage_warning","") != "Warehouse full — free storage or expand it":
				order.storage_warning = "Warehouse full — free storage or expand it"
				supplier_state_changed.emit()
			continue
		for source_id in order.stock_ids:
			if not freight.accessible(order,str(source_id)): continue
			var actual_packet: Dictionary = freight.packet(order,str(source_id))
			if actual_packet.get("code","") == "M04":
				order.storage_warning = "Timber requires two actual handlers"
				continue # Joint custody is connected in the next planned phase.
			var quantity := mini(25, mini(room, ledger.available(source_id)))
			if quantity <= 0:
				continue
			var origin: Vector2 = ledger.inspect_entity(id).position
			var pickup_at: Vector2 = Freight.to_world(order,Vector3(0,0,Freight.REAR_Z)) if not order.packet_manifest.is_empty() else work_point.call(id,order.id) if work_point.is_valid() else berth.berth
			if not pickup_at.is_finite(): continue
			var approach: Array = _worker_path(origin,pickup_at)
			if approach.is_empty(): continue
			var storage := {}
			if warehouse != null:
				var attempt_key := "%s/%s/%s" % [id,order.id,source_id]
				if int(_storage_attempts.get(attempt_key,-1)) == int(warehouse.revision): continue
				var code: String = str(ledger.inspect_entity(source_id,{},false).design_type)
				quantity = mini(quantity,Packages.capacity(code))
				storage = warehouse.reserve(id,code,quantity,true,true)
				if not storage.ok:
					_storage_attempts[attempt_key] = warehouse.revision
					if order.get("storage_warning","") != str(storage.message):
						order.storage_warning = str(storage.message)
						supplier_state_changed.emit()
					continue
			_job_sequence += 1
			var claim_id := "receiving-job-%04d" % _job_sequence
			var claimed: Dictionary = ledger.request_stock(claim_id, source_id, quantity, id, "Physical Receiving unload", PLAYER)
			if not claimed.ok:
				if not storage.is_empty(): warehouse.release(str(storage.id))
				continue
			var job := {"order_id": order.id, "source_id": source_id, "quantity": quantity,
				"code": ledger.inspect_entity(source_id).design_type, "claim_id": claim_id,
				"phase": "Approach", "started_at": _time, "slot":slot,"destination":berth.store}
			job.path = approach
			job.ends_at = _time + _path_length(job.path) / 1.5
			if not storage.is_empty():
				job.storage = str(storage.id)
				job.destination = "receiving"
				order.storage_warning = "Preparing storage" if storage.prepare else ""
				if storage.prepare:
					job.phase = "Storage approach"
					job.path = _worker_path(origin,storage.point)
					job.ends_at = _time+_path_length(job.path)/1.5
			_workers[id].job = job
			if not order.packet_manifest.is_empty() and (storage.is_empty() or not storage.prepare): _approach_truck(id,job)
			_event("Reserved source and destination before walking to pickup", claim_id)
			worker_activity_changed.emit(id)
			return true
	return false


func _finish_worker_phase(id: String) -> void:
	var job: Dictionary = _workers[id].job
	var previous_phase: String = str(job.phase)
	match job.phase:
		"Source access": _approach_truck(id,job)
		"Source queue":
			job.path = []
			job.phase = "Source access"
			job.ends_at = INF
			_approach_truck(id,job)
		"Truck egress", "Truck return":
			var order: Dictionary = _find_order(str(job.order_id))
			ledger.register_handling_point(str(order.id),id,job.get("return_exit_point",Freight.to_world(order,Vector3(0,0,Freight.REAR_Z))))
			_must(ledger.release_supplier_access(id,str(order.id)))
			ledger.release_handling_points(id,str(order.id))
			freight.release_aisle(order)
			if job.phase == "Truck return": _workers[id].job = {}
			else: _carry_from_rear(id,job)
		"Carry blocked": _carry_from_rear(id,job)
		"Storage approach", "Storage blocked":
			job.path = []
			var prepared: Dictionary = warehouse.begin_preparation(str(job.storage))
			if not prepared.ok:
				job.phase = "Storage blocked"
				job.ends_at = INF
				_find_order(job.order_id).storage_warning = str(prepared.message)
			elif prepared.ready:
				_approach_truck(id,job)
			else:
				job.phase = "Preparing storage"
				job.started_at = _time
				job.ends_at = _time+0.75
			_event("Real worker reached shelf site before fixture appearance",id)
		"Preparing storage":
			if warehouse.reveal_preparation(str(job.storage)):
				job.phase = "Storage settling"
				job.ends_at = _time+0.75
			else:
				job.phase = "Storage blocked"
				job.ends_at = INF
		"Storage settling":
			if warehouse.finish_preparation(str(job.storage)): _approach_truck(id,job)
			else:
				job.phase = "Storage blocked"
				job.ends_at = INF
				_find_order(job.order_id).storage_warning = "Shelf site occupied — waiting for clearance"
		"Approach":
			job.phase = "Pickup"
			job.started_at = _time
			job.ends_at = _time + 2.0
			job.path = []
		"Pickup", "Storage access":
			if job.has("storage") and not warehouse.acquire_access(str(job.storage)):
				job.phase = "Storage access"
				job.ends_at = INF
				_find_order(job.order_id).storage_warning = "Waiting for clear shelf access"
				return # Source claim stays aboard; no carry until a safe face is held.
			var origin: Vector2 = ledger.inspect_entity(id,{},false).position
			var destination: Vector2 = warehouse.destination_point(str(job.storage)) if job.has("storage") else work_point.call(id,job.destination) if work_point.is_valid() else freight_berths[job.slot].receiving_position
			var path: Array = _worker_path(origin,destination) if destination.is_finite() else []
			if path.is_empty():
				job.ends_at = _time+PASSENGER_EXIT_SECONDS
				return # Keep claim at the truck until a real safe path/point exists.
			_must(ledger.begin_carry(id, job.source_id, job.quantity, job.claim_id))
			var order: Dictionary = _find_order(str(job.order_id))
			job.phase = "Truck egress" if not order.packet_manifest.is_empty() else "Carry"
			job.path = freight.egress(order,origin) if not order.packet_manifest.is_empty() else path
			job.started_at = _time
			job.ends_at = _time + _path_length(job.path) / 1.2
		"Carry":
			job.phase = "Drop"
			job.path = []
			job.started_at = _time
			job.ends_at = _time + 2.0
		"Drop":
			var deposited: Dictionary = ledger.finish_carry(id, job.destination)
			_must(deposited)
			if job.has("storage"): _must(warehouse.commit(str(job.storage),str(deposited.entity_id)))
			var order := _find_order(job.order_id)
			order.unloaded[job.code] = order.unloaded.get(job.code, 0) + job.quantity
			_must(ledger.release_claim(job.claim_id))
			_workers[id].job = {}
			_event("Actual carried stock deposited; destination reservation consumed once", id)
	if _workers.has(id) and str(_workers[id].job.get("phase","")) != previous_phase: worker_activity_changed.emit(id)

func _carry_from_rear(id: String, job: Dictionary) -> void:
	var origin: Vector2 = ledger.inspect_person_status(id).position
	var target: Vector2 = warehouse.destination_point(str(job.storage)) if job.has("storage") else freight_berths[int(job.slot)].receiving_position
	var path: Array = _worker_path(origin,target) if target.is_finite() else []
	job.path = path
	job.phase = "Carry" if not path.is_empty() else "Carry blocked"
	job.started_at = _time
	job.ends_at = _time+_path_length(path)/1.2 if not path.is_empty() else INF

func _queue_at_source(id: String, job: Dictionary) -> void:
	# Cell capacity remains promised, but a worker waiting for another resource
	# must not hold its warehouse service face or physically stand across it.
	if warehouse != null: warehouse.release_point(id)
	ledger.release_handling_points(id,"receiving")
	job.phase = "Source access"
	job.path = []
	job.ends_at = INF
	if job.get("queued",false) or not work_point.is_valid(): return
	var point: Vector2 = work_point.call(id,str(job.order_id))
	var origin: Vector2 = ledger.inspect_person_status(id).position
	var path: Array = _worker_path(origin,point) if point.is_finite() else []
	if path.is_empty(): return
	job.queued = true
	job.phase = "Source queue"
	job.path = path
	job.started_at = _time
	job.ends_at = _time+_path_length(path)/1.5

func _approach_truck(id: String, job: Dictionary) -> void:
	var order: Dictionary = _find_order(job.order_id)
	if not order.packet_manifest.is_empty():
		var origin: Vector2 = ledger.inspect_person_status(id).position
		var route_in: Array = freight.ingress(order,str(job.source_id),origin)
		if route_in.is_empty() or not freight.reserve_aisle(order,[id]):
			_queue_at_source(id,job)
			return
		var retained: Dictionary = ledger.retain_supplier_access(id,str(order.id))
		if not retained.ok:
			freight.release_aisle(order)
			job.phase = "Source access"
			job.path = []
			job.ends_at = INF
			return
		ledger.register_handling_point(str(order.id),id,freight.pickup_point(order,str(job.source_id)))
		job.phase = "Approach"
		job.path = route_in
		job.started_at = _time
		job.ends_at = _time+_path_length(route_in)/1.5
		return
	var pickup: Vector2 = work_point.call(id,order.id) if work_point.is_valid() else freight_berths[job.slot].berth
	var origin: Vector2 = ledger.inspect_entity(id,{},false).position
	var path: Array = _worker_path(origin,pickup) if pickup.is_finite() else []
	if path.is_empty():
		job.phase = "Storage blocked"
		job.ends_at = INF
		order.storage_warning = "Route blocked"
		return
	job.phase = "Approach"
	job.path = path
	job.started_at = _time
	job.ends_at = _time+_path_length(path)/1.5
	order.storage_warning = ""


func _sync_workers() -> void:
	for id in _workers.keys():
		var person := ledger.inspect_person_status(id)
		var still_assigned: bool = person.assignment == "Rear Labour" and person.duty_id in (["Receiving"] + freight_berths.map(func(row: Dictionary) -> String: return row.duty))
		var job: Dictionary = _workers[id].job
		if _workers[id].get("shared",false): still_assigned = person.assignment == "Rear Labour" and person.duty_id == "hauling" and not job.is_empty()
		if not job.is_empty() and job.phase in ["Carry", "Drop","Truck egress","Carry blocked","Truck return"]:
			continue # G01 retains the old duty until the carried freight is deposited.
		if not still_assigned or person.pending_assignment != "None":
			if not job.is_empty() and not str(person.get("supplier_access_id","")).is_empty():
				_must(ledger.release_claim(str(job.claim_id)))
				if job.has("storage"):
					warehouse.release(str(job.storage))
					job.erase("storage")
				job.phase = "Truck return"
				job.path = freight.egress(_find_order(str(job.order_id)),person.position)
				job.started_at = _time
				job.ends_at = _time+_path_length(job.path)/1.5
				worker_activity_changed.emit(id)
				continue
			if not job.is_empty():
				_must(ledger.release_claim(job.claim_id))
				if job.has("storage"): warehouse.release(str(job.storage))
			_workers.erase(id)


func _move_activities() -> void:
	for order in _orders:
		if not order.motion.is_empty():
			var previous: Vector2 = order.world_position if development_convoys else ledger._world_position(str(order.id))
			order.world_position = _motion_position(order.motion)
			_must(ledger.move_entity(order.id, "supplier-transit" if order.state == "Incoming" else "rear-lane", order.world_position))
			var travel: Vector2 = Vector2(order.world_position)-previous
			if development_convoys and travel.length_squared() > 0.000001:
				var facing := rad_to_deg(travel.angle())
				if not is_equal_approx(facing,float(order.get("facing_degrees",0.0))):
					order.facing_degrees = facing
					_position_supplier_occupants(order)
	for walk in _walks:
		var at := _motion_position(walk)
		var direction: Vector2 = at-Vector2(walk.get("position",at))
		if not direction.is_zero_approx(): walk.facing = atan2(direction.x,direction.y)
		walk.position = at
		_must(ledger.move_entity(walk.person_id, "rear-lane", at))
	if development_convoys: passengers.advance_poses()
	for id in _workers:
		var job: Dictionary = _workers[id].job
		if not job.is_empty() and not job.path.is_empty():
			_must(ledger.move_entity(id, "rear-lane", _motion_position(job)))


func _start_vehicle_motion(order: Dictionary, state: String, destination: Vector2, planned_path: Array = [], planned_speed: float = -1.0) -> void:
	var origin: Vector2 = order.world_position if development_convoys else ledger.inspect_entity(order.id).position
	var path: Array = planned_path if not planned_path.is_empty() else road.plan(order,destination) if development_convoys else [origin,destination]
	if path.is_empty():
		order.traffic_resume = {"state":state,"destination":destination}
		order.motion = {}
		order.next_at = INF
		_set_state(order,"Traffic hold")
		return
	var speed: float = planned_speed if planned_speed > 0.0 else road.speed_for(order,path) if development_convoys else _speed(order)
	order.next_at = _time + _path_length(path) / speed
	order.motion = {"path":path,"started_at":_time,"ends_at":order.next_at,"speed":speed}
	_set_state(order,state)


func _slot_for(kind: String) -> int:
	if development_convoys:
		for order: Dictionary in _active_suppliers.values():
			if order.kind == kind and (order.state in ["Berthing","Berthed","Disembarking"] or (order.state == "Traffic hold" and order.get("traffic_resume",{}).get("state","") == "Berthing")): return -1
		return 0 # Separate actual material/personnel stops, one carrier each.
	var count := freight_berths.size() if kind == "Freight" else 2
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
	if order.get("return_requested",false): return str(returns.quote(order).message)
	match order.state:
		"Ordered": return "Dispatch at five seconds; full refund is still available"
		"Incoming": return "Supplier still travelling; local stock/people unavailable"
		"Waiting": return "Waiting for physical berth/pull-off clearance"
		"Berthing": return "Vehicle is physically approaching its reserved place"
		"Disembarking":
			if development_convoys: return "Passengers prepare, stand, walk and jump from the rear one at a time; actual arrival still reserves their places"
			if order.people_exited < order.passenger_ids.size(): return "Passengers exit one per second from this stopped vehicle, then walk; no unloading worker is required"
			return "All passengers exited; remaining walks to Personnel still reserve incoming places"
		"Departing": return "Supplier vehicle still clearing; admission remains occupied"
		"Traffic hold": return "Road blocked — waiting for actual vehicle or person clearance"
		"Berthed":
			if warehouse != null and not str(order.get("storage_warning","")).is_empty(): return str(order.storage_warning)
			if _workers.is_empty(): return "Waiting for free hauling/unloading workers, a safe route, or higher-priority work to finish"
			if free_receiving_kg(order.slot) <= 0: return "Receiving storage full or reserved; remainder stays aboard"
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
	if development_convoys and str(order.state) != state: road.invalidate()
	order.state = state
	if state == "Departing": order.departure_started = true
	if warehouse != null: _storage_warning_dirty = true
	order.state_entered_at = _time
	if development_convoys:
		_update_convoy_gate(order)
		if state in ["Complete","Cancelled"]: _active_suppliers.erase(order.id)
		supplier_state_changed.emit()


func _update_convoy_gate(order: Dictionary) -> void:
	if not development_convoys or not _convoy_pending.has(order.id): return
	var handed_over: bool = _freight_finished(order) if order.kind == "Freight" else int(order.people_arrived) == int(order.expected_people)
	if order.get("return_requested",false): handed_over = bool(order.get("return_completed",false))
	if order.state != "Cancelled" and not (handed_over and order.get("departure_started",false)): return
	_convoy_pending.erase(order.id)
	if _convoy_pending.is_empty(): convoy_changed.emit()


func _gate(order: Dictionary) -> Vector2:
	if development_convoys: return Vector2(96-float(order.get("convoy_index",0))*30,ROAD_Y)
	if supply_table_access: return Vector2(0,receiving_position.y-10 if order.kind == "Freight" else personnel_position.y+10)
	return FREIGHT_GATE if order.kind == "Freight" else Vector2(0, 100)


func _berth(order: Dictionary) -> Vector2:
	if development_convoys: return Vector2(132 if order.kind == "Freight" else 100,ROAD_Y)
	if supply_table_access and order.kind != "Freight": return personnel_position+Vector2(6+order.slot*8,10)
	return freight_berths[order.slot].berth if order.kind == "Freight" else Vector2(16 + order.slot * 8, 100)


func _exit(order: Dictionary) -> Vector2:
	if development_convoys: return Vector2(252,ROAD_Y)
	if supply_table_access: return _gate(order)-Vector2(12,0)
	return FREIGHT_EXIT if order.kind == "Freight" else Vector2(-12, 100)


func _speed(order: Dictionary) -> float:
	if development_convoys: return 12.0 # Keep the same-lane convoy spaced at its freight speed.
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
	if warehouse != null: supplier_state_changed.emit()


func _must(result: Dictionary) -> void:
	if not result.ok:
		push_error("Receiving activity invariant failed: " + str(result))


func _ok(message: String, ids: Array = []) -> Dictionary:
	return {"ok": true, "code": "OK", "message": message, "ids": ids}


func _reject(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "ids": []}
