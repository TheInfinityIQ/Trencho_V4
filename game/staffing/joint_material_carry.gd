extends RefCounted
## Ledger-owned two-person custody. Activities own routes and timing.
signal custody_changed(state: String, details: Dictionary)
const Records = preload("res://game/identity/identity_records.gd")
var active: Dictionary = {}
var _ledger_ref: WeakRef

func _init(ledger: RefCounted) -> void:
	_ledger_ref = weakref(ledger)

func begin(id: String, people: Array, source_id: String, quantity: int, claim_id: String, payload_position: Vector2) -> Dictionary:
	var ledger: RefCounted = _ledger_ref.get_ref()
	var source: Records.Entity = ledger._stock(source_id)
	if not ledger._free_id(id) or people.size() != 2 or people[0] == people[1] or source == null or source.design_type != "M04" or quantity <= 0 or quantity > source.quantity or not payload_position.is_finite():
		return ledger._reject("INVALID_JOINT_CARRY","One timber portion and two distinct workers are required.")
	if not ledger._claims.has(claim_id): return ledger._reject("NO_ACTIVE_CLAIM","Reserve the shared source once before pickup.")
	var claim: Records.Claim = ledger._claims[claim_id]
	if claim.cancelled or claim.source_id != source_id or claim.reserved < quantity:
		return ledger._reject("CLAIM_MISMATCH","The shared timber portion must remain reserved.")
	var place := ""
	for person_id: String in people:
		var person: Records.Person = ledger._person(person_id)
		if person == null or person.owner != source.owner or person.assignment != Records.Assignment.REAR_LABOUR or person.health <= 0 or (person.pending_assignment != -1 and person.supplier_access_id != source.holder_id) or not person.joint_carry_id.is_empty() or not person.carrying_stock_id.is_empty() or not person.carrying_weapon_id.is_empty() or not person.crew_station.is_empty() or not person.construction_truck_id.is_empty() or not ledger._is_place(person.holder_id):
			return ledger._reject("PERSON_BUSY","Both actual handlers must be free for this exclusive carry.")
		if not ledger._at_handling_point(person_id,source_id): return ledger._reject("NOT_AT_GRIP","Both workers must reach registered source stations.")
		if source.unit_mass_kg*float(quantity)/2.0+ledger._contents_mass(person_id) > 25.0:
			return ledger._reject("CARRY_TOO_HEAVY","Each actual carrier retains the25kg allowance.")
		if not place.is_empty() and place != person.holder_id: return ledger._reject("DIFFERENT_PLACES","Handlers must occupy the same physical area.")
		place = person.holder_id
	if ledger._world_position(str(people[0])).distance_to(ledger._world_position(str(people[1]))) < 1.2:
		return ledger._reject("STATIONS_OVERLAP","The actual two handling stations must be distinct.")
	var holder: Records.Entity = ledger._new_entity(id,Records.Kind.JOINT_CARRY,"Two-person timber carry",source.owner,source.controller,place,"One timber portion retained by two actual people.")
	holder.position = payload_position-ledger._world_position(place)
	for person_id: String in people: ledger._person(person_id).joint_carry_id = id
	var stock: Records.Entity = ledger._split_stock(source,quantity,id,false)
	active[id] = {"id":id,"people":people.duplicate(),"stock":stock.id,"place":place,"origin":source.origin_id}
	claim.reserved -= quantity
	claim.fulfilled += quantity
	ledger._event("Two handlers picked up one shared timber portion",id)
	ledger.stock_changed.emit(source_id)
	ledger.stock_changed.emit(stock.id)
	custody_changed.emit("Carrying",{"id":id,"stock":stock.id,"source":source_id,"origin":source.origin_id,"source_holder":source.holder_id})
	return ledger._ok("One shared timber load committed once.",id)

func move(id: String, place: String, stations: Array, payload_position: Vector2) -> Dictionary:
	var ledger: RefCounted = _ledger_ref.get_ref()
	if not active.has(id) or not ledger._is_place(place) or stations.size() != 2 or not payload_position.is_finite():
		return ledger._reject("INVALID_JOINT_MOVE","An active pair and three real endpoints are required.")
	if not stations[0] is Vector2 or not stations[1] is Vector2 or not stations[0].is_finite() or not stations[1].is_finite() or stations[0].distance_to(stations[1]) < 1.2:
		return ledger._reject("INVALID_JOINT_STATIONS","Both roots must retain distinct finite stations.")
	var row: Dictionary = active[id]
	var previous: Array = []
	for person_id: String in row.people:
		if ledger._person(person_id).health <= 0: return ledger._reject("JOINT_MEMBER_LOST","Resolve the real ground put-down before moving.")
		previous.append(ledger._world_position(person_id))
	var holder: Records.Entity = ledger._entities[id]
	var old_payload: Vector2 = ledger._world_position(id)
	holder.holder_id = place
	holder.position = payload_position-ledger._world_position(place)
	row.place = place
	for index in 2:
		var person: Records.Person = ledger._person(str(row.people[index]))
		person.holder_id = place
		person.position = stations[index]-ledger._world_position(place)
	# No observer sees one root updated without its partner and payload.
	ledger.entity_moved.emit(id,old_payload,payload_position)
	for index in 2:
		ledger.entity_moved.emit(str(row.people[index]),previous[index],stations[index])
		ledger.person_position_changed.emit(str(row.people[index]))
	return ledger._ok("Both people and one shared load moved atomically.",id)

func finish(id: String, destination: String) -> Dictionary:
	var ledger: RefCounted = _ledger_ref.get_ref()
	if not active.has(id) or not ledger._is_place(destination): return ledger._reject("NO_JOINT_CARRY","Choose an active shared carry and actual storage.")
	var row: Dictionary = active[id]
	for person_id: String in row.people:
		if ledger._person(person_id).health <= 0 or not ledger._at_handling_point(person_id,destination):
			return ledger._reject("JOINT_DEPOSIT_NOT_READY","Both handlers must reach their reserved destination stations.")
	var source: Records.Entity = ledger._stock(str(row.stock))
	if source == null or source.holder_id != id or source.quantity <= 0: return ledger._reject("BROKEN_JOINT_CARRY","The one retained load must exist.")
	var deposited: Records.Entity = ledger._split_stock(source,source.quantity,destination,false)
	_clear(id,"Complete")
	ledger._event("Shared timber physically deposited once",deposited.id)
	ledger.stock_changed.emit(source.id)
	ledger.stock_changed.emit(deposited.id)
	custody_changed.emit("Deposited",{"id":id,"stock":deposited.id,"origin":str(row.origin)})
	return ledger._ok("One load deposited; both commitments released.",deposited.id)

func put_down(id: String) -> Dictionary:
	var ledger: RefCounted = _ledger_ref.get_ref()
	if not active.has(id): return ledger._reject("NO_JOINT_CARRY","No shared load exists.")
	var row: Dictionary = active[id]
	var source: Records.Entity = ledger._stock(str(row.stock))
	var at: Vector2 = ledger._world_position(id)
	var ground := id+"/ground"
	ledger.add_place(ground,"Recoverable timber at actual interrupted position",at)
	source.holder_id = ground
	source.position = Vector2.ZERO
	_clear(id,"Put down")
	ledger._event("Shared timber put down at its actual position",source.id)
	ledger.stock_changed.emit(source.id)
	custody_changed.emit("Ground",{"id":id,"stock":source.id,"origin":str(row.origin)})
	return ledger._ok("One recoverable ground load; no receipt fabricated.",source.id)

func _clear(id: String, state: String) -> void:
	var ledger: RefCounted = _ledger_ref.get_ref()
	var row: Dictionary = active[id]
	for person_id: String in row.people:
		var person: Records.Person = ledger._person(person_id)
		person.joint_carry_id = ""
		if person.health > 0 and person.pending_assignment != -1 and person.supplier_access_id.is_empty(): ledger._set_assignment(person,person.pending_assignment,person.pending_duty)
	ledger._entities[id].state = state
	active.erase(id)

func snapshot(id: String) -> Dictionary:
	return active[id].duplicate(true) if active.has(id) else {}
