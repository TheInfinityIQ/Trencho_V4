extends RefCounted
signal person_position_changed(person_id: String)
signal vehicle_damaged(vehicle_id: String)
signal entity_moved(entity_id: String, start: Vector2, finish: Vector2)
var route_hazard: Callable
## Authoritative, scene-owned G01 accounting. Movement methods commit a completed
## physical handling boundary; they do not simulate routes, loading time or courses.

const Records = preload("res://game/identity/identity_records.gd")
const BLAST_TOP_ARMOUR := {"T01":0,"T02":0,"T03":0,"T04":10,"T05":25}

var _entities: Dictionary[String, Records.Entity] = {}
var _claims: Dictionary[String, Records.Claim] = {}
var _created: Dictionary[String, int] = {}
var _consumed: Dictionary[String, int] = {}
var _lost: Dictionary[String, int] = {}
var _sequence: int = 0
var _time: float = 0.0
var _rear_hull_promises: Dictionary = {}
var _fuel_loaded: float = 0.0
var _fuel_initial: float = 0.0
var _fuel_burned: float = 0.0
var _fuel_lost: float = 0.0
const REAR_FLEET_LIMIT := 8
var _events: Array[Dictionary] = []


func advance_time(seconds: float) -> Dictionary:
	if not is_finite(seconds) or seconds < 0.0:
		return _reject("INVALID_TIME", "Simulation time must advance by a finite, nonnegative amount.")
	_time += seconds
	return _ok("Simulation clock advanced.")


func add_place(id: String, description: String, position: Vector2) -> Dictionary:
	if not _free_id(id) or not position.is_finite():
		return _reject("INVALID_ENTITY", "A place needs a unique ID and finite position.")
	var entity := _new_entity(id, Records.Kind.PLACE, "Place", "", "", "", description)
	entity.position = position
	return _ok("Place registered.", id)


func add_carrier(id: String, holder_id: String, owner: String, controller: String,
		design_type: String = "Carrier fixture", fleet_domain: String = "External service") -> Dictionary:
	if not _free_id(id) or not _is_place(holder_id) or owner.is_empty():
		return _reject("INVALID_ENTITY", "A carrier needs a unique ID, owner and physical place.")
	_new_entity(id, Records.Kind.CARRIER, design_type, owner, controller, holder_id,
		"Supplier-owned carrier; not a third combat faction.")
	_entities[id].fleet_domain = fleet_domain
	return _ok("Carrier registered.", id)


func add_initial_vehicle(id: String, type: String, holder: String, owner: String, properties: Dictionary, fuel: float, domain: String = "Rear") -> Dictionary:
	var canonical: Dictionary = preload("res://game/production/vehicle_specs.gd").TYPES
	var fleet := rear_fleet_status(owner)
	var military_count := 0
	for existing in _entities.values():
		if existing.kind == Records.Kind.CARRIER and existing.owner == owner and existing.fleet_domain == "Military" and existing.health > 0: military_count += 1
	if _time != 0.0 or not _free_id(id) or not _is_place(holder) or owner not in ["army-blue","army-red"] or domain not in ["Rear","Military"] or not canonical.has(type) or properties != canonical[type] or not is_finite(fuel) or fuel < 0.0 or fuel > float(properties.get("tank_capacity",-1)) or (domain == "Rear" and fleet.live+fleet.reserved >= REAR_FLEET_LIMIT) or (domain == "Military" and military_count >= 24):
		return _reject("INVALID_INITIAL_VEHICLE","Initial vehicles require time zero, canonical properties, bounded fuel and a free rear fleet place.")
	var entity := _new_entity(id,Records.Kind.CARRIER,type,owner,owner,holder,"Declared starting scenario vehicle")
	entity.vehicle_spec = properties.duplicate(true)
	entity.unit_mass_kg = properties.mass
	entity.health = properties.health
	entity.max_health = properties.health
	entity.fleet_domain = domain
	if domain == "Military": entity.controller = owner+"-hq"
	entity.fuel = fuel
	_fuel_initial += fuel
	return _ok("Initial vehicle and tank fuel recorded once.",id)


func assign_initial_vehicle_crew(person_id: String, hull_id: String, station: String) -> Dictionary:
	var person := _person(person_id)
	var hull: Records.Entity = _entities.get(hull_id)
	if _time != 0.0 or person == null or hull == null or hull.kind != Records.Kind.CARRIER or hull.health <= 0 or hull.fleet_domain != "Military" or station not in hull.vehicle_spec.get("stations",[]) or person.owner != hull.owner or person.health <= 0 or not person.basic_training or person.rear_place != "None" or person.assignment != Records.Assignment.AVAILABLE or person.pending_assignment != -1 or not person.crew_station.is_empty() or not person.carrying_stock_id.is_empty() or not person.carrying_weapon_id.is_empty() or not _colocated(person_id,hull_id):
		return _reject("INVALID_INITIAL_CREW","A time-zero military station requires its same-army qualified free person at the hull.")
	if person.qualification != "P08" and not (hull.design_type == "T03" and station == "Gunner" and person.qualification == "P04"):
		return _reject("UNQUALIFIED_INITIAL_CREW","The actual station requires P08, or P04 for a technical gunner.")
	for other in _entities.values():
		if other is Records.Person and other.holder_id == hull_id and other.crew_station == station: return _reject("STATION_OCCUPIED","Initial station already has its real occupant.")
	person.holder_id = hull_id
	person.position = Vector2.ZERO
	person.crew_station = station
	person.controller = hull.controller
	_set_assignment(person,Records.Assignment.FORMATION_DUTY,"vehicle:"+hull_id)
	return _ok("Initial crew station occupied by the same real person.",person_id)


func add_initial_hq_person(id: String, place: String, owner: String, assignment: int, qualification: String = "None") -> Dictionary:
	if _time != 0.0 or owner not in ["army-blue","army-red"] or assignment not in [Records.Assignment.HQ_DUTY,Records.Assignment.HQ_RESERVE] or not _is_place(place): return _reject("INVALID_INITIAL_HQ_PERSON","Initial HQ staff require a declared physical place and army at time zero.")
	var result := add_person(id,place,owner,Records.Assignment.AVAILABLE,true,qualification,"None")
	if not result.ok: return result
	_set_assignment(_person(id),assignment,"fixed-hq" if assignment == Records.Assignment.HQ_DUTY else "")
	return _ok("Initial HQ person registered once at their actual staging place.",id)


func create_heavy_output(admission: String, claimant: String, id: String, type: String, holder: String, owner: String, properties: Dictionary) -> Dictionary:
	if not _free_id(id) or not _is_place(holder) or owner.is_empty() or (type != "E13" and type not in ["T01","T02","T03","T04","T05"]):
		return _reject("INVALID_HEAVY_OUTPUT", "A heavy output needs its own identity, legal place and canonical type.")
	if not properties.has("mass") or not properties.has("health") or not _valid_mass(properties.mass) or properties.health <= 0:
		return _reject("INVALID_HEAVY_PROPERTIES", "Canonical physical output properties are required before creation.")
	if type != "E13":
		for key in ["stations","rack_capacity","passenger_seats","footprint","mechanisms","payload","tank_capacity"]:
			if not properties.has(key): return _reject("INVALID_HULL_PROPERTIES", "Complete hull properties are required.")
		var claim := inspect_rear_hull_claim(admission)
		var status := rear_fleet_status(owner)
		if claim.get("owner") != owner or claim.get("claimant") != claimant or status.live >= REAR_FLEET_LIMIT or status.live + status.reserved > REAR_FLEET_LIMIT:
			return _reject("NO_OWN_FLEET_ADMISSION", "A valid own rear-fleet admission is required immediately before hull creation.")
	var entity := _new_entity(id, Records.Kind.HEAVY_OBJECT if type == "E13" else Records.Kind.CARRIER, type, owner, owner, holder, "Manufactured empty field gun" if type == "E13" else "Manufactured empty, unfuelled and uncrewed hull")
	if type == "E13":
		entity.unit_mass_kg = properties.mass
		entity.health = properties.health
		entity.max_health = properties.health
	else:
		entity.vehicle_spec = properties.duplicate(true)
		entity.unit_mass_kg = entity.vehicle_spec.mass
		entity.health = entity.vehicle_spec.health
		entity.max_health = entity.vehicle_spec.health
		entity.fleet_domain = "Rear"
		_rear_hull_promises.erase(admission)
	_event("Physical heavy output created, without crew, fuel or ammunition", id)
	return _ok("One empty heavy output created.", id)


func rear_fleet_hulls(owner: String) -> Array[String]:
	var result: Array[String] = []
	for entity in _entities.values():
		if entity.kind == Records.Kind.CARRIER and entity.owner == owner and entity.fleet_domain == "Rear" and entity.design_type in ["T01","T02","T03","T04","T05"] and entity.health > 0:
			result.append(entity.id)
	return result


func reserve_rear_hull(id: String, owner: String, claimant: String) -> Dictionary:
	var status := rear_fleet_status(owner)
	if id.is_empty() or owner.is_empty() or claimant.is_empty() or _rear_hull_promises.has(id):
		return _reject("INVALID_FLEET_CLAIM", "A unique order and owning activity are required.")
	if status.live + status.reserved >= REAR_FLEET_LIMIT:
		return _reject("REAR_FLEET_FULL", "Rear fleet 8 is occupied/reserved; a military intention does not bypass it.")
	_rear_hull_promises[id] = {"id":id,"owner":owner,"claimant":claimant}
	return _ok("Rear fleet admission reserved before material consumption.", id)


func release_rear_hull(id: String, claimant: String) -> Dictionary:
	if not _rear_hull_promises.has(id) or _rear_hull_promises[id].claimant != claimant:
		return _reject("NOT_OWN_UNUSED_ADMISSION", "Only this order's unused admission can be released; live hulls are retained.")
	_rear_hull_promises.erase(id)
	return _ok("Only the unused fleet admission released.")


func inspect_rear_hull_claim(id: String) -> Dictionary:
	return _rear_hull_promises.get(id, {}).duplicate(true)


func rear_fleet_status(owner: String) -> Dictionary:
	var ids := rear_fleet_hulls(owner)
	var claims: Array[Dictionary] = []
	for claim in _rear_hull_promises.values():
		if claim.owner == owner: claims.append(claim.duplicate(true))
	return {"live":ids.size(),"reserved":claims.size(),"limit":REAR_FLEET_LIMIT,"live_ids":ids,"claims":claims}


func entities_at(holder: String, kinds: Array, include_mass: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entity in _entities.values():
		if entity.holder_id == holder and Records.Kind.keys()[entity.kind] in kinds: result.append(inspect_entity(entity.id,{},include_mass))
	return result

func entities_at_any(holders: Array, kinds: Array, include_mass: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if holders.is_empty() or kinds.is_empty(): return result
	# Membership exists only for this synchronous query. Ledger iteration keeps
	# canonical entity order and prevents repeated holders from duplicating goods.
	var selected := {}
	for holder in holders: selected[holder] = true
	for entity in _entities.values():
		if selected.has(entity.holder_id) and Records.Kind.keys()[entity.kind] in kinds:
			result.append(inspect_entity(entity.id,{},include_mass))
	return result

func entity_kind(id: String) -> String:
	return Records.Kind.keys()[_entities[id].kind] if _entities.has(id) else ""

func entities_of_type(type: String, kinds: Array, include_mass: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entity in _entities.values():
		if entity.design_type == type and Records.Kind.keys()[entity.kind] in kinds: result.append(inspect_entity(entity.id,{},include_mass))
	return result

func entities_of_kind(kind: Records.Kind, include_mass: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entity in _entities.values():
		if entity.kind == kind: result.append(inspect_entity(entity.id,{},include_mass))
	return result

func physical_quantity_at(holder: String, type: String, kinds: Array) -> int:
	# Quantity includes reserved portions, just as raw inspection does. This
	# count needs neither recursive mass nor weapon/carry inspection details.
	var total := 0
	for entity in _entities.values():
		if entity.holder_id == holder and entity.design_type == type and Records.Kind.keys()[entity.kind] in kinds:
			total += entity.quantity
	return total


func ammunition_quantity_at(holder: String, loose_type: String, weapon_types: Array) -> int:
	# Count physical loose portions and the contents of the selected held weapons
	# in one synchronous scan. Reservations, ownership and weapon health do not
	# change a physical count; no eligibility or availability is implied here.
	var total := 0
	for entity in _entities.values():
		if entity.holder_id == holder and entity.design_type == loose_type and entity.kind in [Records.Kind.STOCK,Records.Kind.WEAPON,Records.Kind.HEAVY_OBJECT]:
			total += entity.quantity
		if entity.kind != Records.Kind.STOCK: continue
		var parent: Records.Entity = _entities.get(entity.holder_id)
		if parent != null and parent.kind == Records.Kind.WEAPON and parent.holder_id == holder and parent.design_type in weapon_types:
			total += entity.quantity
	return total


func add_person(id: String, holder_id: String, owner: String,
		initial_assignment: int = Records.Assignment.AVAILABLE,
		basic_training: bool = false, qualification: String = "None", rear_place: String = "Occupied") -> Dictionary:
	if not _free_id(id) or not _is_person_holder(holder_id) or owner.is_empty():
		return _reject("INVALID_ENTITY", "A person needs a unique ID, owner and physical place or carrier.")
	if initial_assignment not in [Records.Assignment.AVAILABLE, Records.Assignment.PASSENGER,Records.Assignment.STRATEGIC_CREW,Records.Assignment.HQ_DUTY,Records.Assignment.HQ_RESERVE] or (initial_assignment == Records.Assignment.HQ_DUTY and holder_id != "hq-berth") or (initial_assignment == Records.Assignment.HQ_RESERVE and holder_id != "hq-reserve"):
		return _reject("INVALID_INITIAL_DUTY", "Initialize actual rear, arriving, service or fixed HQ people at their physical holder.")
	if qualification not in ["None", "P02", "P03", "P04", "P05", "P06", "P07", "P08"] or (qualification != "None" and not basic_training):
		return _reject("INVALID_QUALIFICATION", "A specialist's initial scenario data must include completed basic training.")
	var person := Records.Person.new()
	_fill_entity(person, id, Records.Kind.PERSON, "P00", owner, owner, holder_id, "Untrained person")
	person.unit_mass_kg = 80.0
	person.assignment = initial_assignment as Records.Assignment
	if initial_assignment == Records.Assignment.HQ_DUTY: person.duty_id = "fixed-hq"
	person.state = Records.ASSIGNMENT_NAMES[initial_assignment]
	person.basic_training = basic_training
	person.qualification = qualification
	person.rear_place = rear_place if owner == "army-blue" else "None"
	person.design_type = qualification if qualification != "None" else ("P01" if basic_training else "P00")
	_entities[id] = person
	return _ok("Person registered.", id)


func move_entity(id: String, place_id: String, world_position: Vector2) -> Dictionary:
	# Timed movement activities own eligibility and travel. This updates the
	# authoritative physical endpoint, with carried goods following their holder.
	if not _entities.has(id) or (_entities[id].kind not in [Records.Kind.PERSON, Records.Kind.CARRIER] and not (_entities[id].kind == Records.Kind.HEAVY_OBJECT and not _entities[id].towed_by.is_empty())):
		return _reject("INVALID_MOVING_ENTITY", "Only a physical person or carrier can move through this boundary.")
	if not _is_place(place_id) or not world_position.is_finite():
		return _reject("INVALID_DESTINATION", "Movement needs an existing place and finite world position.")
	var entity := _entities[id]
	if entity is Records.Person and not entity.crew_station.is_empty():
		return _reject("STATION_OCCUPIED", "Vacate the physical crew station before moving the person independently.")
	if entity.kind == Records.Kind.CARRIER and not entity.vehicle_spec.is_empty():
		var travel: Vector2 = world_position-_world_position(id)
		if travel.length_squared() > 0.000001: entity.facing_degrees = fposmod(rad_to_deg(travel.angle()),360.0)
	var previous := _world_position(id)
	entity.holder_id = place_id
	entity.position = world_position - _world_position(place_id)
	entity_moved.emit(id,previous,world_position)
	if entity is Records.Person: person_position_changed.emit(id)
	return _ok("Physical position updated by the timed activity.", id)


func complete_person_arrival(id: String, place_id: String, owner: String) -> Dictionary:
	var person := _person(id)
	if person == null or person.assignment != Records.Assignment.PASSENGER or owner.is_empty():
		return _reject("NOT_ARRIVING_PASSENGER", "Only an arriving passenger can complete this receiving boundary.")
	if not _is_place(person.holder_id) or not _is_place(place_id) or not _colocated(id, place_id):
		return _reject("NOT_DISEMBARKED", "The person must finish their own movement to the personnel arrival point.")
	person.holder_id = place_id
	person.position = Vector2.ZERO
	person.owner = owner
	person.controller = owner
	person.rear_place = "Occupied"
	_set_assignment(person, Records.Assignment.AVAILABLE, "")
	return _ok("The same disembarked person is now available in the receiving owner's rear.", id)


func set_rear_place(person_id: String, expected: String, next: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.rear_place != expected or next not in ["Occupied", "Held Home", "None"]:
		return _reject("INVALID_REAR_PLACE", "Only this person's current rear place may change once at the physical boundary.")
	person.rear_place = next
	return _ok("Same person's rear occupancy/home transition recorded.",person_id)


func board_dispatch_passenger(person_id: String, hull_id: String) -> Dictionary:
	var person := _person(person_id)
	var hull: Records.Entity = _entities.get(hull_id)
	if person == null or hull == null or hull.vehicle_spec.is_empty() or person.health <= 0 or not person.crew_station.is_empty() or not person.carrying_stock_id.is_empty() or not _colocated(person_id,hull_id):
		return _reject("INVALID_PASSENGER", "A healthy actual passenger must finish reporting to the stopped hull.")
	if person.holder_id == hull_id: return _reject("ALREADY_ONBOARD","The passenger is already aboard.")
	person.holder_id = hull_id
	person.position = Vector2.ZERO
	_set_assignment(person,Records.Assignment.PASSENGER,"")
	return _ok("Same person physically boarded one passenger seat.",person_id)


func disembark_dispatch_passenger(person_id: String, hull_id: String, place_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.holder_id != hull_id or not person.crew_station.is_empty() or not _is_place(place_id):
		return _reject("NOT_ONBOARD","Only this hull's actual passenger may finish disembarking.")
	person.holder_id = place_id
	person.position = _world_position(hull_id) - _world_position(place_id)
	_set_assignment(person,Records.Assignment.AWAITING_DEPLOYMENT,"")
	return _ok("Same passenger completed physical exit; receiving still pending.",person_id)


func complete_hq_reserve_receipt(person_id: String, place_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.AWAITING_DEPLOYMENT or not _is_place(place_id) or not _colocated(person_id,place_id):
		return _reject("NOT_AT_HQ","A disembarked person must reach their actual HQ receiver.")
	person.holder_id = place_id
	person.position = Vector2.ZERO
	person.controller = "army-blue"
	_set_assignment(person,Records.Assignment.HQ_RESERVE,"")
	return _ok("Same person joined HQ Reserve on actual receipt.",person_id)


func request_formation_report(person_id: String, squad_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.HQ_RESERVE or person.holder_id != "hq-reserve" or person.health <= 0 or not person.crew_station.is_empty() or not person.carrying_stock_id.is_empty() or not person.carrying_weapon_id.is_empty() or person.pending_assignment != -1 or squad_id.is_empty():
		return _reject("NOT_FREE_RESERVE", "Only one living, physically present and uncommitted HQ Reserve person may report to a formation.")
	person.pending_assignment = Records.Assignment.FORMATION_DUTY
	person.pending_duty = squad_id
	return _ok("Actual reserve person reserved for a named formation walk; duty remains HQ Reserve until arrival.", person_id)


func cancel_formation_report(person_id: String, squad_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.HQ_RESERVE or person.pending_assignment != Records.Assignment.FORMATION_DUTY or person.pending_duty != squad_id:
		return _reject("NO_FORMATION_REPORT", "Only this person's pending formation report may be cancelled.")
	person.pending_assignment = -1
	person.pending_duty = ""
	return _ok("Pending formation report released without moving or duplicating the person.", person_id)


func complete_formation_report(person_id: String, squad_id: String, place_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.HQ_RESERVE or person.pending_assignment != Records.Assignment.FORMATION_DUTY or person.pending_duty != squad_id or person.holder_id != place_id or not _colocated(person_id,place_id):
		return _reject("NOT_AT_FORMATION", "The same reserved person must finish the physical report before joining the squad.")
	_set_assignment(person,Records.Assignment.FORMATION_DUTY,squad_id)
	return _ok("Same person joined the named formation after actual travel.", person_id)


func set_formation_appointment(person_id: String, appointment: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.FORMATION_DUTY or not person.basic_training or person.health <= 0:
		return _reject("INELIGIBLE_LEADER", "Only a living trained formation member may hold an ordinary appointment.")
	person.leader_appointment = appointment
	return _ok("Existing trained person holds this appointment; no leader was created.", person_id)


func clear_formation_appointment(person_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null: return _reject("MISSING_PERSON", "Only an existing person's old appointment may be cleared.")
	person.leader_appointment = "None"
	return _ok("Old appointment cleared on the same identity.", person_id)

func set_acting_rifle_appointment(person_id: String, squad_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.FORMATION_DUTY or person.duty_id != squad_id or person.basic_training or person.health <= 0:
		return _reject("INELIGIBLE_ACTING_LEADER", "Only a living conscript on this real Rifle roster may act for its squad.")
	person.leader_appointment = "Acting Rifle Squad"
	return _ok("Same untrained person temporarily leads only the Rifle squad.", person_id)


func request_military_crew_report(person_id: String, hull_id: String, station: String) -> Dictionary:
	var person := _person(person_id)
	var hull: Records.Entity = _entities.get(hull_id)
	if person == null or hull == null or hull.kind != Records.Kind.CARRIER or hull.fleet_domain != "Military" or hull.holder_id != "hq-berth" or station not in hull.vehicle_spec.get("stations",[]):
		return _reject("INVALID_MILITARY_STATION", "A real stopped military hull and named station are required at HQ.")
	if person.assignment != Records.Assignment.HQ_RESERVE or person.holder_id != "hq-reserve" or person.health <= 0 or person.pending_assignment != -1 or not person.crew_station.is_empty() or not person.carrying_stock_id.is_empty() or not person.carrying_weapon_id.is_empty():
		return _reject("NOT_FREE_RESERVE", "A living, uncommitted HQ Reserve person must physically report to this crew station.")
	if not person.basic_training or not (person.qualification == "P08" or (hull.design_type == "T03" and station == "Gunner" and person.qualification == "P04")):
		return _reject("UNQUALIFIED_STATION", "This actual station needs a P08, or a T03 gunner may use P04.")
	for other in _entities.values():
		if other is Records.Person and other.holder_id == hull_id and other.crew_station == station:
			return _reject("STATION_OCCUPIED", "This hull's distinct station is already occupied.")
	person.pending_assignment = Records.Assignment.FORMATION_DUTY
	person.pending_duty = "vehicle:%s:%s" % [hull_id,station]
	return _ok("Same qualified HQ Reserve member is reserved for a physical crew report.",person_id)


func complete_military_crew_report(person_id: String, hull_id: String, station: String) -> Dictionary:
	var person := _person(person_id)
	var hull: Records.Entity = _entities.get(hull_id)
	var duty := "vehicle:%s:%s" % [hull_id,station]
	if person == null or hull == null or person.assignment != Records.Assignment.HQ_RESERVE or person.pending_assignment != Records.Assignment.FORMATION_DUTY or person.pending_duty != duty or person.holder_id != "hq-berth" or hull.holder_id != "hq-berth" or not _colocated(person_id,hull_id):
		return _reject("NOT_AT_CREW_STATION", "The same reserved person must finish the actual HQ report to the stopped hull.")
	for other in _entities.values():
		if other is Records.Person and other.holder_id == hull_id and other.crew_station == station:
			return _reject("STATION_OCCUPIED", "This station filled before the pending crew report arrived.")
	person.holder_id = hull_id
	person.position = Vector2.ZERO
	person.crew_station = station
	_set_assignment(person,Records.Assignment.FORMATION_DUTY,"vehicle:"+hull_id)
	return _ok("Same person occupies the physical crew station and leaves HQ Reserve duty.",person_id)


func board_formation_passenger(person_id: String, hull_id: String) -> Dictionary:
	var person := _person(person_id)
	var hull: Records.Entity = _entities.get(hull_id)
	if person == null or hull == null or hull.kind != Records.Kind.CARRIER or hull.fleet_domain != "Military" or person.assignment != Records.Assignment.FORMATION_DUTY or person.health <= 0 or not person.crew_station.is_empty() or person.holder_id == hull_id or not _colocated(person_id,hull_id):
		return _reject("INVALID_FORMATION_PASSENGER", "A living member on a separate squad roster must physically reach the military hull.")
	var occupied := 0
	for other in _entities.values():
		if other is Records.Person and other.holder_id == hull_id and other.crew_station.is_empty(): occupied += 1
	if occupied >= int(hull.vehicle_spec.get("passenger_seats",0)):
		return _reject("PASSENGER_SEATS_FULL", "Crew stations do not add passenger seats; this hull is full.")
	person.holder_id = hull_id
	person.position = Vector2.ZERO
	person_position_changed.emit(person_id)
	return _ok("Same formation member boarded one actual passenger seat without becoming crew.",person_id)


func exit_formation_passenger(person_id: String, hull_id: String, place_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.holder_id != hull_id or person.assignment != Records.Assignment.FORMATION_DUTY or not person.crew_station.is_empty() or not _is_place(place_id) or not _colocated(hull_id,place_id):
		return _reject("INVALID_FORMATION_EXIT", "Only an actual squad passenger may exit at the stopped hull's place.")
	person.holder_id = place_id
	person.position = _world_position(hull_id)-_world_position(place_id)
	person_position_changed.emit(person_id)
	return _ok("Same passenger physically exited; squad roster and exclusive duty persist.",person_id)


func complete_dispatch_cancel_person(person_id: String, place_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.AWAITING_DEPLOYMENT or not _is_place(place_id) or not _colocated(person_id,place_id):
		return _reject("NOT_RETURNED","Only a physically disembarked rear passenger can resume availability.")
	var position: Vector2 = _world_position(person_id)
	person.holder_id = place_id
	person.position = position - _world_position(place_id)
	_set_assignment(person,Records.Assignment.AVAILABLE,"")
	return _ok("Same rear person finished actual cancellation disembark.",person_id)


func complete_hq_hull_receipt(hull_id: String) -> Dictionary:
	var hull: Records.Entity = _entities.get(hull_id)
	if hull == null or hull.kind != Records.Kind.CARRIER or hull.fleet_domain != "Rear" or hull.holder_id != "hq-berth":
		return _reject("NOT_AT_HQ","Only the real stopped rear hull at HQ may transfer.")
	hull.fleet_domain = "Military"
	hull.controller = "army-blue-hq"
	for child in _entities.values():
		if child is Records.Person and child.holder_id == hull_id and not child.crew_station.is_empty():
			child.controller = "army-blue-hq"
			_set_assignment(child,Records.Assignment.FORMATION_DUTY,"vehicle:"+hull_id)
	return _ok("Same hull and its actual crew transferred at HQ once.",hull_id)


func transfer_field_gun(gun_id: String, source_id: String, destination_id: String) -> Dictionary:
	var gun: Records.Entity = _entities.get(gun_id)
	if gun == null or gun.kind != Records.Kind.HEAVY_OBJECT or gun.design_type != "E13" or gun.holder_id != source_id or not _entities.has(destination_id):
		return _reject("INVALID_GUN_TRANSFER","The same physical E13 must remain at its actual source until handled.")
	gun.holder_id = destination_id
	gun.position = Vector2.ZERO
	gun.state_entered_at = _time
	return _ok("Same packed field gun changed physical holder after active handling.",gun_id)


func move_field_gun(gun_id: String, place_id: String, world_position: Vector2) -> Dictionary:
	var gun: Records.Entity = _entities.get(gun_id)
	if gun == null or gun.kind != Records.Kind.HEAVY_OBJECT or gun.design_type != "E13" or not _is_place(place_id) or not world_position.is_finite():
		return _reject("INVALID_GUN_MOVE","An actual packed field gun needs a physical rear place and position.")
	gun.holder_id = place_id
	gun.position = world_position - _world_position(place_id)
	return _ok("The same packed field gun moved with its actual two-loader team.",gun_id)


func finish_carry_to_carrier(person_id: String, hull_id: String) -> Dictionary:
	var person := _person(person_id)
	var hull: Records.Entity = _entities.get(hull_id)
	if person == null or hull == null or hull.vehicle_spec.is_empty() or person.carrying_stock_id.is_empty() or not _colocated(person_id,hull_id):
		return _reject("INVALID_LOAD","A real worker and carried stock must reach this stopped hull.")
	var carried := _stock(person.carrying_stock_id)
	var invalid := _check_transfer(carried,carried.quantity,hull_id,"")
	if not invalid.is_empty(): return invalid
	var loaded := _split_stock(carried,carried.quantity,hull_id)
	person.carrying_stock_id = ""
	return _ok("Same carried stock physically loaded into the hull once.",loaded.id)


func add_stock(id: String, type: String, quantity: int, mass_kg: float,
		holder_id: String, owner: String) -> Dictionary:
	if not _free_id(id) or type.is_empty() or quantity <= 0 or not _valid_mass(mass_kg):
		return _reject("INVALID_STOCK", "Stock needs a unique ID, type, positive whole count and valid unit mass.")
	if not _can_hold_stock(holder_id) or owner.is_empty():
		return _reject("INVALID_HOLDER", "Stock needs an existing physical holder and owner.")
	var stock := _new_entity(id, Records.Kind.STOCK, type, owner, "", holder_id, type)
	stock.quantity = quantity
	stock.unit_mass_kg = mass_kg
	stock.origin_id = id
	_created[type] = _created.get(type, 0) + quantity
	return _ok("Stock created once.", id)


func add_weapon(id: String, type: String, mass_kg: float, holder_id: String,
		owner: String, ammo_type: String, capacity: int) -> Dictionary:
	if not _free_id(id) or type.is_empty() or ammo_type.is_empty() or capacity <= 0 or not _valid_mass(mass_kg):
		return _reject("INVALID_WEAPON", "A weapon needs a unique ID, types, valid mass and positive loaded capacity.")
	if not _can_hold_stock(holder_id) or owner.is_empty():
		return _reject("INVALID_HOLDER", "A weapon needs an existing physical holder and owner.")
	var weapon := _new_entity(id, Records.Kind.WEAPON, type, owner, "", holder_id, "Intact weapon")
	weapon.unit_mass_kg = mass_kg
	weapon.ammo_type = ammo_type
	weapon.loaded_capacity = capacity
	_created[type] = _created.get(type, 0) + 1
	return _ok("Empty weapon created once.", id)


func complete_training(person_id: String, course: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.TRAINING or person.duty_id != "students" or person.pending_assignment != -1 or not person.carrying_stock_id.is_empty():
		return _reject("NOT_ACTUAL_STUDENT","Only the same actual student may receive completed training.")
	if course == "P01":
		if person.basic_training: return _reject("ALREADY_TRAINED","Basic training already completed; no duplicate qualification granted.")
		person.basic_training = true
		person.design_type = "P01"
	elif course in ["P02","P03","P04","P05","P06","P07","P08"]:
		if not person.basic_training or person.qualification != "None": return _reject("INELIGIBLE_SPECIALIST","Completed basic and one unused specialist qualification slot are required.")
		person.qualification = course
		person.design_type = course
	else: return _reject("INVALID_COURSE","Choose a canonical basic/specialist course.")
	_event("Completed " + course + " on the same person without equipment grants",person_id)
	return _ok("Completed qualification retained on the same person.",person_id)


func request_assignment(person_id: String, assignment: int, duty_id: String) -> Dictionary:
	var person := _person(person_id)
	# G01 exercises rear duty boundaries only. Military, wounds and recovery belong
	# to later lifecycles; having an enum does not grant arbitrary transitions.
	if person == null or assignment not in [Records.Assignment.AVAILABLE, Records.Assignment.REAR_LABOUR, Records.Assignment.TRAINING]:
		return _reject("UNSUPPORTED_DUTY", "G01 supports Available, Rear Labour and Training fixture assignments.")
	if assignment != Records.Assignment.AVAILABLE and duty_id.is_empty():
		return _reject("MISSING_DUTY", "An assigned person needs a named duty.")
	if person.pending_assignment != -1:
		return _reject("HANDOFF_PENDING", "Cancel or complete the existing pending duty handoff first.")
	if not person.carrying_stock_id.is_empty() or not person.carrying_weapon_id.is_empty() or not person.crew_station.is_empty():
		person.pending_assignment = assignment
		person.pending_duty = duty_id
		_event("Duty requested; waiting for safe carry/station handoff", person_id)
		return _ok("Duty requested. Finish safe deposit or park and vacate the driver station first.", person_id)
	_set_assignment(person, assignment, duty_id)
	return _ok("Exclusive duty changed.", person_id)


func assign_initial_formation(person_id: String, squad_id: String) -> Dictionary:
	var person := _person(person_id)
	if _time != 0.0 or person == null or squad_id.is_empty() or person.rear_place != "None" or person.assignment != Records.Assignment.AVAILABLE or person.pending_assignment != -1 or person.health <= 0 or not person.crew_station.is_empty() or not person.carrying_stock_id.is_empty() or not person.carrying_weapon_id.is_empty() or not _is_place(person.holder_id):
		return _reject("INVALID_INITIAL_FORMATION","An uncommitted living person on foot may begin in a declared formation only at time zero.")
	_set_assignment(person,Records.Assignment.FORMATION_DUTY,squad_id)
	return _ok("Initial formation duty recorded on the same person.",person_id)


func cancel_assignment_request(person_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.pending_assignment == -1:
		return _reject("NO_PENDING_DUTY", "There is no pending duty request to cancel.")
	person.pending_assignment = -1
	person.pending_duty = ""
	_event("Pending duty cancelled; current duty and freight preserved", person_id)
	return _ok("Pending request cancelled; current duty and carried goods are unchanged.", person_id)


func begin_carry(person_id: String, stock_id: String, quantity: int, claim_id: String = "") -> Dictionary:
	var person := _person(person_id)
	if person == null or not (person.assignment == Records.Assignment.REAR_LABOUR or (person.assignment == Records.Assignment.HQ_DUTY and person.duty_id == "fixed-hq")):
		return _reject("NOT_LABOUR", "An actual rear or HQ logistics worker is required for this carry.")
	if not person.carrying_stock_id.is_empty() or not person.carrying_weapon_id.is_empty() or person.pending_assignment != -1 or not person.crew_station.is_empty():
		return _reject("PERSON_BUSY", "Finish the existing carry or pending handoff first.")
	var stock := _stock(stock_id)
	if stock != null and stock.unit_mass_kg * quantity + _contents_mass(person.id) > 25.0:
		return _reject("CARRY_TOO_HEAVY", "An ordinary carry is limited to 25 kg of one item type (GDD section 4).")
	var result := transfer_stock(stock_id, quantity, person_id, claim_id)
	if result.ok:
		person.carrying_stock_id = result.entity_id
	return result


func complete_driver_entry(person_id: String, carrier_id: String) -> Dictionary:
	# The yard activity establishes stationary three-second handling first.
	var person := _person(person_id)
	var carrier: Records.Entity = _entities.get(carrier_id)
	if person == null or carrier == null or carrier.kind != Records.Kind.CARRIER:
		return _reject("INVALID_STATION", "A real person and carrier are required.")
	if person.qualification != "P08" or not person.basic_training or person.owner != carrier.owner:
		return _reject("INELIGIBLE_DRIVER", "An owned hull requires its own qualified P08, never a supplier driver.")
	if person.assignment != Records.Assignment.REAR_LABOUR or person.duty_id != "yard" or person.pending_assignment != -1 or not person.carrying_stock_id.is_empty():
		return _reject("PERSON_BUSY", "The driver must report exclusively to this yard duty.")
	if not person.crew_station.is_empty() or not _colocated(person_id, carrier_id):
		return _reject("NOT_COLOCATED", "Finish reporting to the stationary hull before station entry.")
	for other in _entities.values():
		if other is Records.Person and other.holder_id == carrier_id and other.crew_station == "Driver":
			return _reject("STATION_OCCUPIED", "The one T01 driver station is occupied.")
	person.holder_id = carrier_id
	person.position = Vector2.ZERO
	person.crew_station = "Driver"
	return _ok("The same qualified person physically occupies the driver station.", person_id)


func complete_driver_exit(person_id: String, place_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.crew_station != "Driver" or not _is_place(place_id) or not _colocated(person_id, place_id):
		return _reject("INVALID_STATION_EXIT", "Park at the real exit place and finish stationary handling first.")
	person.holder_id = place_id
	person.position = Vector2.ZERO
	person.crew_station = ""
	if person.pending_assignment != -1:
		_set_assignment(person, person.pending_assignment, person.pending_duty)
	return _ok("Driver station vacated at the actual parking place; safe duty handoff completed.", person_id)


func complete_vehicle_station_entry(person_id: String, carrier_id: String, station: String) -> Dictionary:
	var person := _person(person_id)
	var carrier: Records.Entity = _entities.get(carrier_id)
	if person == null or carrier == null or carrier.kind != Records.Kind.CARRIER or carrier.vehicle_spec.is_empty() or station not in carrier.vehicle_spec.stations:
		return _reject("INVALID_STATION", "Choose a real manufactured hull and one of its distinct stations.")
	var qualified: bool = person.qualification == "P08" or (carrier.design_type == "T03" and station == "Gunner" and person.qualification == "P04")
	if not qualified or person.owner != carrier.owner or person.health <= 0:
		return _reject("UNQUALIFIED_STATION", "This station needs its actual qualified living person.")
	if person.assignment != Records.Assignment.REAR_LABOUR or person.duty_id != "crew:%s:%s" % [carrier_id, station] or person.pending_assignment != -1 or not person.carrying_stock_id.is_empty() or not person.crew_station.is_empty() or not _colocated(person_id, carrier_id):
		return _reject("PERSON_BUSY", "Finish exclusive reporting and stationary entry at this hull.")
	for other in _entities.values():
		if other is Records.Person and other.holder_id == carrier_id and other.crew_station == station:
			return _reject("STATION_OCCUPIED", "This physical station is already occupied.")
	person.holder_id = carrier_id
	person.position = Vector2.ZERO
	person.crew_station = station
	_event("Qualified person entered distinct vehicle station", person_id)
	return _ok("Same person occupies the real station.", person_id)


func complete_vehicle_station_exit(person_id: String, carrier_id: String) -> Dictionary:
	var person := _person(person_id)
	var carrier: Records.Entity = _entities.get(carrier_id)
	if person == null or carrier == null or person.holder_id != carrier_id or person.crew_station.is_empty():
		return _reject("INVALID_STATION_EXIT", "Only an actual stopped-hull occupant can leave this station.")
	var position := _world_position(carrier_id)
	person.holder_id = "rear"
	person.position = position
	person.crew_station = ""
	if person.pending_assignment != -1:
		_set_assignment(person, person.pending_assignment, person.pending_duty)
	_event("Vehicle station physically vacated", person_id)
	return _ok("Station vacated by the same person at the parked hull.", person_id)


func load_vehicle_fuel(person_id: String, carrier_id: String) -> Dictionary:
	var person := _person(person_id)
	var carrier: Records.Entity = _entities.get(carrier_id)
	if person == null or carrier == null or carrier.vehicle_spec.is_empty() or person.carrying_stock_id.is_empty() or not _colocated(person_id, carrier_id):
		return _reject("INVALID_REFUEL", "A real local fuel carry must reach this stopped hull.")
	var stock := _stock(person.carrying_stock_id)
	if stock == null or stock.design_type != "M08" or stock.holder_id != person_id or stock.quantity <= 0 or carrier.owner != person.owner:
		return _reject("INVALID_FUEL", "Only owned whole M08 units physically carried by this worker can enter the tank.")
	if float(stock.quantity) > float(carrier.vehicle_spec.tank_capacity) - carrier.fuel + 0.000001:
		return _reject("TANK_FULL", "Whole fuel units exceed the tank's remaining capacity.")
	carrier.fuel += float(stock.quantity)
	_fuel_loaded += float(stock.quantity)
	stock.quantity = 0
	stock.state = "Transferred to tank"
	stock.state_entered_at = _time
	person.carrying_stock_id = ""
	if person.pending_assignment != -1:
		_set_assignment(person, person.pending_assignment, person.pending_duty)
	_event("Whole local M08 moved from worker carry into this hull tank", carrier_id)
	return _ok("Whole purchased fuel units entered the same hull tank once.", carrier_id)


func burn_vehicle_fuel(carrier_id: String, amount: float) -> Dictionary:
	var carrier: Records.Entity = _entities.get(carrier_id)
	if carrier == null or carrier.vehicle_spec.is_empty() or not is_finite(amount) or amount < 0.0 or amount > carrier.fuel + 0.000001:
		return _reject("FUEL_EMPTY", "Travel cannot burn more fuel than this tank contains.")
	carrier.fuel = maxf(0.0, carrier.fuel - amount)
	_fuel_burned += amount
	return _ok("Actual fractional travel fuel burned.", carrier_id)


func finish_carry(person_id: String, safe_place_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.carrying_stock_id.is_empty():
		return _reject("NO_CARRY", "This person has no active carry to finish.")
	if not _is_place(safe_place_id):
		return _reject("INVALID_SAFE_STORAGE", "Complete the fixture carry into an existing safe storage place.")
	var carried := _entities[person.carrying_stock_id]
	var invalid := _check_transfer(carried, carried.quantity, safe_place_id, "")
	if not invalid.is_empty():
		return invalid
	var deposited := _split_stock(carried, carried.quantity, safe_place_id)
	_event("Carry physically deposited into safe storage", deposited.id)
	person.carrying_stock_id = ""
	if person.pending_assignment != -1:
		_set_assignment(person, person.pending_assignment, person.pending_duty)
	return _ok("Goods deposited once; safe duty handoff completed.", deposited.id)


func request_stock(id: String, source_id: String, quantity: int, claimant: String,
		purpose: String, owner: String) -> Dictionary:
	var source := _stock(source_id)
	if not _free_id(id) or source == null or quantity <= 0 or claimant.is_empty() or purpose.is_empty():
		return _reject("INVALID_REQUEST", "A claim needs a unique ID, source, positive quantity, claimant and purpose.")
	if source.owner != owner:
		return _reject("NOT_OWNED", "The request owner does not own this stock; its carrier's owner is separate.")
	if _entities[source.holder_id].kind == Records.Kind.WEAPON or _is_active_carry(source_id):
		return _reject("STOCK_COMMITTED", "Unload the weapon or finish the active carry before reserving this stock.")
	var claim := Records.Claim.new()
	claim.id = id
	claim.source_id = source_id
	claim.requested = quantity
	claim.claimant = claimant
	claim.purpose = purpose
	claim.created_at = _time
	claim.reserved = mini(quantity, available(source_id))
	_claims[id] = claim
	_event("Claim recorded without moving stock", id)
	return _ok("Claim recorded; any unfilled demand remains visible.", id)


func release_claim(id: String) -> Dictionary:
	if not _claims.has(id) or _claims[id].cancelled:
		return _reject("NO_ACTIVE_CLAIM", "There is no active claim to release.")
	var claim := _claims[id]
	claim.reserved = 0
	claim.cancelled = true
	_event("Claim cancelled; physical stock unchanged", id)
	return _ok("Claim released. Goods already moved stay at their physical destination.", id)

func consume_claimed_batch(claim_ids: Array, claimant: String, position: Vector2, radius: float, type: String, count: int, reason: String) -> Dictionary:
	var receipt: Array[Dictionary] = []
	var seen := {}
	var total := 0
	for id in claim_ids:
		var claim: Records.Claim = _claims.get(id)
		if seen.has(id) or claim == null or claim.cancelled or claim.claimant != claimant or claim.reserved <= 0: return _reject("INVALID_CLAIM_BATCH","Every consumed portion needs its unique active project claim.")
		seen[id] = true
		var source := _stock(claim.source_id)
		if source == null or source.design_type != type or not _is_place(source.holder_id) or _world_position(source.id).distance_to(position) > radius or source.quantity < claim.reserved: return _reject("CLAIM_NOT_LOCAL","Committed stock must remain physically staged at the project.")
		total += claim.reserved
		receipt.append({"id":source.id,"type":type,"count":claim.reserved,"claim":id})
	if total != count: return _reject("INCOMPLETE_CLAIM_BATCH","Exact authorized quantity must be exclusively committed before consumption.")
	for portion in receipt:
		var claim: Records.Claim = _claims[portion.claim]
		claim.fulfilled += portion.count
		claim.reserved = 0
		_remove_stock(portion.id,portion.count,reason,false)
	return {"ok":true,"receipt":receipt,"message":"Exact project-claimed physical batch consumed once."}


func reserve_remaining(id: String) -> Dictionary:
	if not _claims.has(id) or _claims[id].cancelled:
		return _reject("NO_ACTIVE_CLAIM", "There is no active claim to retry.")
	var claim := _claims[id]
	var needed := claim.requested - claim.fulfilled - claim.reserved
	claim.reserved += mini(needed, available(claim.source_id))
	_event("Explicit reservation retry; no automatic request arbitration", id)
	return _ok("Available stock reserved; unmet demand remains visible.", id)


func reserved(source_id: String) -> int:
	var count: int = 0
	for claim in _claims.values():
		if claim.source_id == source_id:
			count += claim.reserved
	return count


func available(source_id: String) -> int:
	var stock := _stock(source_id)
	if stock == null or _entities[stock.holder_id].kind == Records.Kind.WEAPON:
		return 0
	return stock.quantity - reserved(source_id)


func transfer_stock(source_id: String, quantity: int, destination_id: String,
		claim_id: String = "") -> Dictionary:
	var source := _stock(source_id)
	var invalid := _check_transfer(source, quantity, destination_id, claim_id)
	if not invalid.is_empty():
		return invalid
	if _is_active_carry(source_id):
		return _reject("CARRY_IN_PROGRESS", "Finish this person's carry through its safe deposit before moving that stock.")
	# A stack portion gets its own identity; the source (even when empty) remains
	# at its origin so unmet claims never silently follow the delivery elsewhere.
	var moved := _split_stock(source, quantity, destination_id)
	if not claim_id.is_empty():
		var claim := _claims[claim_id]
		claim.reserved -= quantity
		claim.fulfilled += quantity
	_event("Physical stock transferred", moved.id)
	return _ok("Physical transfer completed; ownership and total count preserved.", moved.id)


func transfer_weapon(weapon_id: String, destination_id: String) -> Dictionary:
	var weapon := _weapon(weapon_id)
	if weapon == null or not _can_hold_stock(destination_id):
		return _reject("INVALID_HOLDER", "An intact weapon and existing destination holder are required.")
	if weapon.holder_id == destination_id or not _colocated(weapon.id, destination_id):
		return _reject("NOT_COLOCATED", "Complete physical travel before handing this weapon to a different local holder.")
	weapon.holder_id = destination_id
	weapon.position = Vector2.ZERO
	weapon.state_entered_at = _time
	_event("Weapon moved with its existing loaded ammunition", weapon_id)
	return _ok("Same weapon and loaded-round identities now have the new physical holder.", weapon_id)


func begin_weapon_carry(person_id: String, weapon_id: String) -> Dictionary:
	var person := _person(person_id)
	var weapon := _weapon(weapon_id)
	if person == null or weapon == null or person.assignment != Records.Assignment.REAR_LABOUR or not person.carrying_stock_id.is_empty() or not person.carrying_weapon_id.is_empty() or person.pending_assignment != -1 or not person.crew_station.is_empty():
		return _reject("PERSON_BUSY","An actual free rear worker must carry this one intact weapon.")
	if weapon.unit_mass_kg + _contents_mass(weapon_id) + _contents_mass(person_id) > 25.0:
		return _reject("CARRY_TOO_HEAVY","Personal and weapon load must stay within 25 kg.")
	var moved := transfer_weapon(weapon_id,person_id)
	if moved.ok: person.carrying_weapon_id = weapon_id
	return moved


func finish_weapon_carry(person_id: String, destination_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.carrying_weapon_id.is_empty():
		return _reject("NO_WEAPON_CARRY","No active intact weapon carry exists.")
	var result := transfer_weapon(person.carrying_weapon_id,destination_id)
	if result.ok:
		person.carrying_weapon_id = ""
		if person.pending_assignment != -1: _set_assignment(person,person.pending_assignment,person.pending_duty)
	return result


func load_rounds(weapon_id: String, source_id: String, quantity: int) -> Dictionary:
	var weapon := _weapon(weapon_id)
	var source := _stock(source_id)
	if weapon == null or source == null or source.design_type != weapon.ammo_type:
		return _reject("WRONG_AMMUNITION", "The weapon and matching loose ammunition must exist.")
	if source.holder_id != weapon.holder_id or source.owner != weapon.owner:
		return _reject("AMMUNITION_NOT_CARRIED", "Reload from loose ammunition owned and physically held alongside this weapon.")
	if _is_active_carry(source_id):
		return _reject("STOCK_COMMITTED", "Finish the active carry through safe deposit before reloading from this stock.")
	if quantity <= 0 or quantity > available(source_id):
		return _reject("INSUFFICIENT_AVAILABLE", "Not enough unreserved loose rounds for this whole-count reload.")
	if quantity > weapon.loaded_capacity - loaded_rounds(weapon_id):
		return _reject("MAGAZINE_FULL", "The requested rounds exceed this weapon's documented loaded capacity.")
	var loaded := _split_stock(source, quantity, weapon_id)
	_event("Loose rounds moved into weapon; total unchanged", loaded.id)
	return _ok("Rounds loaded once; no additional ammunition was created.", loaded.id)


func unload_rounds(weapon_id: String) -> Dictionary:
	var weapon := _weapon(weapon_id)
	if weapon == null or loaded_rounds(weapon_id) == 0:
		return _reject("NO_LOADED_ROUNDS", "There are no loaded rounds to unload.")
	# Loaded stock cannot be reserved directly. Unload every loaded portion to
	# the weapon's current holder, not its former operator.
	for stock in _entities.values():
		if stock.kind == Records.Kind.STOCK and stock.holder_id == weapon_id and stock.quantity > 0:
			stock.holder_id = weapon.holder_id
			stock.state_entered_at = _time
	_event("Loaded rounds unloaded to current holder", weapon_id)
	return _ok("Existing rounds are now loose at the weapon's current holder.", weapon_id)


func record_consumption(source_id: String, quantity: int, reason: String) -> Dictionary:
	return _remove_stock(source_id, quantity, reason, false)


func fire_loaded_round(weapon_id: String) -> Dictionary:
	var weapon := _weapon(weapon_id)
	if weapon == null or weapon.health <= 0:
		return _reject("WEAPON_UNAVAILABLE", "A functional physical weapon is required.")
	for entity in _entities.values():
		if entity.kind == Records.Kind.STOCK and entity.holder_id == weapon_id and entity.design_type == weapon.ammo_type and entity.quantity > 0:
			entity.quantity -= 1
			if entity.quantity == 0:
				entity.state = "Depleted"
				entity.state_entered_at = _time
			_consumed[entity.design_type] = _consumed.get(entity.design_type,0) + 1
			_event("One loaded round fired from " + weapon_id, entity.id)
			return _ok("One actual loaded round consumed at release.", entity.id)
	return _reject("EMPTY_WEAPON", "No matching round is loaded in this weapon; stock elsewhere cannot fire it.")


func injure_person(person_id: String, injury: int) -> Dictionary:
	var person := _person(person_id)
	if person == null or injury <= 0 or person.assignment == Records.Assignment.DEAD:
		return _reject("INVALID_INJURY", "Positive injury to a living actual person is required.")
	if person.assignment == Records.Assignment.WOUNDED:
		return kill_person(person_id, "Further injury while incapacitated")
	person.health = maxi(0, person.health - injury)
	if person.health == 0:
		person.bleed_until = _time + 60.0
		_set_assignment(person, Records.Assignment.WOUNDED, person.duty_id)
		_drop_personal_gear(person)
		_event("Incapacitated; bleed-out in 60 seconds", person_id)
		return {"ok":true,"code":"INCAPACITATED","message":"Person incapacitated; physical gear dropped once.","id":person_id}
	_event("Injury %d" % injury, person_id)
	return _ok("Active person injured.", person_id)


func kill_person(person_id: String, reason: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment == Records.Assignment.DEAD or reason.is_empty():
		return _reject("INVALID_DEATH", "Only a living person can enter Dead once.")
	if person.assignment != Records.Assignment.WOUNDED: _drop_personal_gear(person)
	var death_holder := person.holder_id
	var holder: Records.Entity = _entities.get(death_holder)
	if holder == null or holder.kind != Records.Kind.CARRIER: death_holder = "casualty-drop:" + person.id
	for entity in _entities.values():
		if entity.holder_id == person.id and entity.design_type in ["E03", "E04"]:
			entity.personal_gear_owner = person.id
			entity.holder_id = death_holder
			entity.position = Vector2.ZERO
	person.health = 0
	person.bleed_until = INF
	_set_assignment(person, Records.Assignment.DEAD, "")
	person.loss_recorded = true
	_event("Person loss: " + reason, person_id)
	return {"ok":true,"code":"DEAD","message":"One person loss recorded; belongings remain physical.","id":person_id}


func destroy_carrier_on_bridge(carrier_id: String) -> Dictionary:
	var carrier: Records.Entity = _entities.get(carrier_id)
	if carrier == null or carrier.kind != Records.Kind.CARRIER or carrier.health <= 0:
		return _reject("INVALID_BRIDGE_COLLAPSE", "An actual surviving carrier on the water span is required.")
	var people: Array[String] = []
	for entity in _entities.values():
		if entity.kind == Records.Kind.PERSON and entity.holder_id == carrier_id and entity.assignment != Records.Assignment.DEAD:
			people.append(entity.id)
	carrier.health = 0
	carrier.submerged = true
	carrier.last_damage_at = _time
	carrier.state = "Destroyed by bridge collapse"
	if carrier.vehicle_spec.is_empty() or vehicle_damaged.get_connections().is_empty():
		for person_id in people: kill_person(person_id,"Bridge collapse on water span")
	vehicle_damaged.emit(carrier_id)
	_event("Carrier destroyed on collapsed water span",carrier_id)
	return _ok("Actual vehicle and its occupants lost on the water span.",carrier_id)


func bleed_out_person(person_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.WOUNDED or _time + 0.000001 < person.bleed_until:
		return _reject("BLEED_NOT_DUE", "Only an untreated incapacitated person at the actual bleed deadline dies.")
	return kill_person(person_id, "Bleed-out")


func pause_bleed_during_care(person_id: String, seconds: float) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.WOUNDED or not is_finite(seconds) or seconds <= 0.0:
		return _reject("INVALID_CARE_TIME", "Only active qualified care can pause a living patient's bleed timer for positive finite time.")
	person.bleed_until += seconds
	return _ok("Remaining bleed time held while active care was performed.",person_id)


func finish_field_care(person_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.WOUNDED or _time + 0.000001 >= person.bleed_until:
		return _reject("PATIENT_UNAVAILABLE", "Field care needs a living incapacitated patient before bleed-out.")
	person.health = 35
	person.bleed_until = INF
	_set_assignment(person, Records.Assignment.RECOVERY, person.duty_id)
	return _ok("Patient stabilized at 35 health and entered Recovery without regaining dropped gear.", person_id)


func set_person_stress(person_id: String, morale_delta: int, suppression_delta: int) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment == Records.Assignment.DEAD:
		return _reject("PERSON_UNAVAILABLE", "A living actual person is required.")
	person.morale = clampi(person.morale + morale_delta, 0, 100)
	person.suppression = clampi(person.suppression + suppression_delta, 0, 100)
	return _ok("Morale and suppression updated on the same person.", person_id)


func _drop_personal_gear(person: Records.Person) -> void:
	var destination := person.holder_id
	var holder: Records.Entity = _entities.get(destination)
	if holder == null or holder.kind != Records.Kind.CARRIER:
		destination = "casualty-drop:" + person.id
		if not _entities.has(destination): add_place(destination, "Recoverable gear of " + person.id, _world_position(person.id))
	for entity in _entities.values():
		if entity.holder_id != person.id or entity.kind not in [Records.Kind.WEAPON, Records.Kind.STOCK]: continue
		if entity.design_type in ["E03", "E04"]: continue
		entity.personal_gear_owner = person.id
		entity.holder_id = destination
		entity.position = Vector2.ZERO
		entity.state_entered_at = _time
	person.carrying_stock_id = ""
	person.carrying_weapon_id = ""


func consume_local_batch(holder: String, owner: String, ingredients: Dictionary, reason: String) -> Dictionary:
	# Validate the entire local input plan before any accounting mutation.
	if not _is_place(holder) or owner.is_empty() or ingredients.is_empty() or reason.strip_edges().is_empty():
		return _reject("INVALID_BATCH", "A physical local holder, owner, ingredients and receipt reason are required.")
	var receipt: Array[Dictionary] = []
	for type in ingredients:
		if not ingredients[type] is int or ingredients[type] <= 0:
			return _reject("INVALID_BATCH", "Ingredients must be positive whole counts.")
		var remaining: int = ingredients[type]
		for entity in _entities.values():
			if entity.kind != Records.Kind.STOCK or entity.holder_id != holder or entity.owner != owner or entity.design_type != type:
				continue
			var count := mini(remaining, available(entity.id))
			if count > 0: receipt.append({"id": entity.id, "type": type, "count": count})
			remaining -= count
			if remaining == 0: break
		if remaining > 0:
			return _reject("MISSING_LOCAL_INPUTS", "The complete owned unreserved batch must be physically local.")
	for portion in receipt:
		_remove_stock(portion.id, portion.count, reason, false)
	return {"ok": true, "code": "OK", "message": "Complete local batch consumed once.", "receipt": receipt}

func available_stock_near(position: Vector2, radius: float, owner: String, type: String) -> int:
	var total := 0
	for entity in _entities.values():
		if entity.kind == Records.Kind.STOCK and entity.owner == owner and entity.design_type == type and _is_place(entity.holder_id) and _world_position(entity.id).distance_to(position) <= radius:
			total += available(entity.id)
	return total

func recover_consumed_material(id: String, type: String, quantity: int, unit_mass_kg: float, holder: String, owner: String) -> Dictionary:
	# G19 cancellation returns the documented half of an already consumed batch.
	if quantity <= 0 or id.is_empty() or not _free_id(id) or not _is_place(holder) or owner.is_empty() or int(_consumed.get(type,0)) < quantity:
		return _reject("INVALID_MATERIAL_RECOVERY","Recovery needs a unique real pile and previously consumed material units.")
	var recovered: Dictionary = add_stock(id,type,quantity,unit_mass_kg,holder,owner)
	if not recovered.ok: return recovered
	_consumed[type] -= quantity
	_created[type] -= quantity
	_event("Previously consumed project material returned as one physical pile",id)
	return recovered

func apply_heavy_repair(id: String, health: int) -> Dictionary:
	var entity: Records.Entity = _entities.get(id)
	if entity == null or entity.kind not in [Records.Kind.CARRIER,Records.Kind.HEAVY_OBJECT] or health <= 0 or entity.health <= 0 or entity.health >= entity.max_health:
		return _reject("INVALID_HEAVY_REPAIR","Only an actually damaged vehicle or field gun can gain positive capped repair health.")
	entity.health = mini(entity.max_health,entity.health+health)
	_event("Field repair restored actual heavy-object health",id)
	return _ok("The same vehicle or gun regained capped health, without changing terrain support.",id)

func apply_heavy_damage(id: String, damage: int, penetration: int, reason: String) -> Dictionary:
	var entity: Records.Entity = _entities.get(id)
	if entity != null and entity.kind == Records.Kind.CARRIER and not entity.vehicle_spec.is_empty():
		return apply_vehicle_surface_damage(id,damage,penetration,"Top",reason)
	if entity == null or entity.kind not in [Records.Kind.CARRIER,Records.Kind.HEAVY_OBJECT] or entity.health <= 0 or damage <= 0 or reason.is_empty():
		return _reject("INVALID_HEAVY_DAMAGE","Positive damage requires an actual surviving vehicle or heavy object.")
	var armour: int = int(BLAST_TOP_ARMOUR.get(entity.design_type,0))
	if penetration < armour: return _ok("Blast failed to penetrate actual armour.",id)
	entity.health = maxi(0,entity.health-damage)
	if entity.health == 0: entity.state = "Destroyed by blast"
	_event(reason,id)
	return {"ok":true,"id":id,"health":entity.health,"penetrated":true,"message":"Actual heavy-object health reduced by blast."}

func set_vehicle_facing(id: String, degrees: float) -> Dictionary:
	var hull: Records.Entity = _entities.get(id)
	if hull == null or hull.kind != Records.Kind.CARRIER or hull.vehicle_spec.is_empty() or hull.health <= 0 or not is_finite(degrees):
		return _reject("INVALID_VEHICLE_FACING","An actual surviving hull and finite heading are required.")
	hull.facing_degrees = fposmod(degrees,360.0)
	_event("Actual hull facing changed",id)
	return _ok("Hull facing recorded for directional strikes.",id)


func apply_vehicle_surface_damage(id: String, damage: int, penetration: int, surface: String, reason: String) -> Dictionary:
	var hull: Records.Entity = _entities.get(id)
	var armour: Dictionary = {
		"T01":[0,0,0,0,0], "T02":[0,0,0,0,0], "T03":[0,0,0,0,0],
		"T04":[35,20,12,10,15], "T05":[100,65,40,25,45],
	}
	var surfaces: Array[String] = ["Front","Side","Rear","Top","Bottom"]
	if hull == null or hull.kind != Records.Kind.CARRIER or not armour.has(hull.design_type) or hull.health <= 0 or damage <= 0 or penetration < 0 or surface not in surfaces or reason.strip_edges().is_empty():
		return _reject("INVALID_VEHICLE_STRIKE","A surviving hull, valid struck surface and positive attack are required.")
	var rating: int = int(armour[hull.design_type][surfaces.find(surface)])
	if penetration < rating:
		return {"ok":true,"penetrated":false,"health":hull.health,"armour":rating,"surface":surface,"message":"Struck armour stopped the attack; zero hull damage."}
	hull.health = maxi(0,hull.health-damage)
	hull.last_damage_at = _time
	if hull.health <= hull.max_health/4: hull.damage_immobilized = true
	if hull.health == 0: hull.state = "Destroyed by vehicle strike"
	_event(reason,id)
	vehicle_damaged.emit(id)
	return {"ok":true,"penetrated":true,"health":hull.health,"armour":rating,"surface":surface,"message":"Actual hull health reduced by penetrating strike."}


func apply_device_damage(id: String, damage: int, penetration: int, reason: String) -> Dictionary:
	var hit := apply_vehicle_surface_damage(id,damage,penetration,"Bottom",reason)
	if hit.get("penetrated",false) and hit.health > 0: _entities[id].damage_immobilized = true
	return hit


func eject_destroyed_carrier_occupant(person_id: String, carrier_id: String, position: Vector2) -> Dictionary:
	var person := _person(person_id)
	var carrier: Records.Entity = _entities.get(carrier_id)
	if person == null or carrier == null or carrier.health > 0 or person.holder_id != carrier_id or not position.is_finite() or not _is_place(carrier.holder_id):
		return _reject("INVALID_EJECTION","A real occupant of a destroyed hull and safe ground are required.")
	person.holder_id = carrier.holder_id
	person.position = position-_world_position(carrier.holder_id)
	person.crew_station = ""
	if person.assignment == Records.Assignment.PASSENGER:
		_set_assignment(person,Records.Assignment.FORMATION_DUTY if not person.duty_id.is_empty() else Records.Assignment.AVAILABLE,person.duty_id)
	person_position_changed.emit(person_id)
	return _ok("Same person ejected onto actual adjacent ground.",person_id)


func resolve_vehicle_wreck(id: String, submerged: bool) -> Dictionary:
	var hull: Records.Entity = _entities.get(id)
	if hull == null or hull.kind != Records.Kind.CARRIER or hull.health > 0 or hull.destruction_resolved:
		return _reject("INVALID_WRECK","An unresolved destroyed hull is required.")
	hull.destruction_resolved = true # Set before callbacks or occupant processing.
	hull.submerged = submerged
	_fuel_lost += hull.fuel
	hull.fuel = 0.0
	hull.state = "Submerged wreck" if submerged else "Destroyed wreck"
	if not hull.towing.is_empty(): set_tow_pair(id,hull.towing,false)
	if not hull.towed_by.is_empty(): set_tow_pair(hull.towed_by,id,false)
	var pile := "wreck:"+id
	add_place(pile,"Owned salvage from "+id,_world_position(id))
	var totals: Dictionary = {}
	for child in _entities.values():
		if child.holder_id == id and child.kind == Records.Kind.STOCK and child.personal_gear_owner.is_empty():
			totals[child.design_type] = int(totals.get(child.design_type,0))+child.quantity
	var retained: Dictionary = {}
	for type in totals: retained[type] = 0 if submerged else int(totals[type])/2
	for child in _entities.values():
		if child.holder_id != id or child.kind != Records.Kind.STOCK or not child.personal_gear_owner.is_empty(): continue
		for claim in _claims.values():
			if claim.source_id == child.id and not claim.cancelled: release_claim(claim.id)
		var keep: int = mini(child.quantity,int(retained[child.design_type]))
		retained[child.design_type] -= keep
		var loss: int = child.quantity-keep
		if loss > 0: _remove_stock(child.id,loss,"Vehicle destruction",true)
		child.holder_id = pile
		child.position = Vector2.ZERO
	return {"ok":true,"pile":pile,"submerged":submerged}


func release_wreck_belongings(id: String, pile: String, submerged: bool) -> void:
	for child in _entities.values():
		if child.holder_id != id or child.kind not in [Records.Kind.WEAPON,Records.Kind.STOCK]: continue
		if submerged:
			if child.kind == Records.Kind.STOCK and child.quantity > 0:
				for claim in _claims.values():
					if claim.source_id == child.id and not claim.cancelled: release_claim(claim.id)
				_remove_stock(child.id,child.quantity,"Submerged belongings",true)
			elif child.kind == Records.Kind.WEAPON:
				child.health = 0
				child.state = "Lost underwater"
		else:
			child.holder_id = pile
			child.position = Vector2.ZERO


func _vehicle_material_sources(id: String) -> Array[String]:
	var sources: Array[String] = []
	var hull: Records.Entity = _entities.get(id)
	if hull == null or hull.vehicle_spec.is_empty(): return sources
	for item in _entities.values():
		if item.kind != Records.Kind.STOCK or item.design_type != "M11" or item.owner != hull.owner or available(item.id) <= 0 or _is_active_carry(item.id): continue
		var holder: Records.Entity = _entities.get(item.holder_id)
		if holder == null or holder.kind != Records.Kind.PLACE: continue
		var delta: Vector2 = (_world_position(item.id)-_world_position(id)).rotated(-deg_to_rad(hull.facing_degrees)).abs()-Vector2(hull.vehicle_spec.footprint)/2.0
		if Vector2(maxf(0,delta.x),maxf(0,delta.y)).length() <= 2.0: sources.append(item.id)
	return sources


func local_vehicle_material(id: String) -> int:
	var total := 0
	for source in _vehicle_material_sources(id): total += available(source)
	return total


func consume_local_vehicle_material(id: String, count: int) -> Dictionary:
	if count <= 0 or local_vehicle_material(id) < count: return _reject("MISSING_LOCAL_M11","The complete unreserved M11 cost must be on nearby ground.")
	var remaining := count
	for source in _vehicle_material_sources(id):
		var amount := mini(remaining,available(source))
		if amount > 0: _remove_stock(source,amount,"Vehicle recovery "+id,false)
		remaining -= amount
		if remaining == 0: break
	return _ok("Local M11 consumed once.",id)


func finish_vehicle_recovery(id: String, mode: String) -> Dictionary:
	var hull: Records.Entity = _entities.get(id)
	if hull == null or hull.kind != Records.Kind.CARRIER: return _reject("INVALID_RECOVERY","Actual hull required.")
	if mode == "Clear wreck":
		if hull.health > 0 or not hull.destruction_resolved or hull.submerged or hull.wreck_cleared: return _reject("INVALID_RECOVERY","Reachable uncleared land wreck required.")
		hull.wreck_cleared = true
		hull.state = "Cleared wreck"
		return _ok("Wreck footprint cleared without extra metal.",id)
	if hull.health <= 0: return _reject("INVALID_RECOVERY","Destroyed hulls cannot be repaired.")
	if mode == "Mobility": hull.damage_immobilized = false
	hull.health = mini(hull.max_health,hull.health+100)
	return _ok("Paid repair restored capped health; terrain remains unchanged.",id)


func set_tow_pair(tractor_id: String, target_id: String, attached: bool) -> Dictionary:
	var tractor: Records.Entity = _entities.get(tractor_id)
	var target: Records.Entity = _entities.get(target_id)
	if tractor == null or target == null: return _reject("INVALID_TOW","Actual pair required.")
	tractor.towing = target_id if attached else ""
	target.towed_by = tractor_id if attached else ""
	return _ok("Physical tow coupling updated.",tractor_id)


func record_loss(source_id: String, quantity: int, reason: String) -> Dictionary:
	return _remove_stock(source_id, quantity, reason, true)


func loaded_rounds(weapon_id: String) -> int:
	var total: int = 0
	for entity in _entities.values():
		if entity.kind == Records.Kind.STOCK and entity.holder_id == weapon_id:
			total += entity.quantity
	return total


func inspect_person_status(id: String) -> Dictionary:
	if not _entities.has(id) or not (_entities[id] is Records.Person): return {}
	return inspect_entity(id,{},false)

func inspect_entity(id: String, snapshot_masses: Dictionary = {}, include_mass: bool = true, snapshot_facts: Dictionary = {}) -> Dictionary:
	if not _entities.has(id):
		return {}
	var entity := _entities[id]
	var result := {
		"id": id, "kind": Records.Kind.keys()[entity.kind], "design_type": entity.design_type,
		"description": entity.description, "owner": entity.owner, "controller": entity.controller,
		"holder_id": entity.holder_id, "position": _world_position(id), "state": entity.state,
		"created_at": entity.created_at, "state_entered_at": entity.state_entered_at,
		"quantity": entity.quantity, "unit_mass_kg": entity.unit_mass_kg,
		"origin_id": entity.origin_id,
	}
	if include_mass: result.contents_mass_kg = snapshot_masses[id] if snapshot_masses.has(id) else _contents_mass(id)
	if entity.kind == Records.Kind.HEAVY_OBJECT:
		result.health = entity.health
		result.max_health = entity.max_health
		result.packed = true
		result.ammunition = {}
		result.towing = entity.towing
		result.towed_by = entity.towed_by
	if entity.kind == Records.Kind.CARRIER:
		result.fleet_domain = entity.fleet_domain
		if not entity.vehicle_spec.is_empty():
			result.vehicle_spec = entity.vehicle_spec.duplicate(true)
			result.fuel = entity.fuel
			result.facing_degrees = entity.facing_degrees
			result.health = entity.health
			result.max_health = entity.max_health
			result.damage_immobilized = entity.damage_immobilized
			result.last_damage_at = entity.last_damage_at
			result.destruction_resolved = entity.destruction_resolved
			result.submerged = entity.submerged
			result.wreck_cleared = entity.wreck_cleared
			result.towing = entity.towing
			result.towed_by = entity.towed_by
			result.crew = []
			result.crew_by_station = {}
			result.passengers = []
			result.ammunition = {}
			for child in _entities.values():
				if child.holder_id != id: continue
				if child is Records.Person:
					if not child.crew_station.is_empty():
						result.crew.append(child.id)
						result.crew_by_station[child.crew_station] = child.id
					else: result.passengers.append(child.id)
				if child.kind == Records.Kind.STOCK and entity.vehicle_spec.rack_capacity.has(child.design_type):
					result.ammunition[child.design_type] = int(result.ammunition.get(child.design_type, 0)) + child.quantity
	if entity.kind == Records.Kind.STOCK:
		result.reserved = reserved(id)
		result.available = available(id)
		result.loaded = _entities[entity.holder_id].kind == Records.Kind.WEAPON
		result.blocked_reason = "Unload weapon before allocating these rounds" if result.loaded else (
			"Finish the active carry before allocating this freight" if (snapshot_facts.carried.has(id) if snapshot_facts.has("carried") else _is_active_carry(id)) else "")
	if entity is Records.Person:
		var person := entity as Records.Person
		result.assignment = Records.ASSIGNMENT_NAMES[person.assignment]
		result.duty_id = person.duty_id
		result.pending_assignment = "None" if person.pending_assignment == -1 else Records.ASSIGNMENT_NAMES[person.pending_assignment]
		result.pending_duty = person.pending_duty
		result.carrying_stock_id = person.carrying_stock_id
		result.carrying_weapon_id = person.carrying_weapon_id
		result.blocked_reason = ("Park and finish stationary driver exit" if not person.crew_station.is_empty() else "Finish carry or deposit into safe storage") if person.pending_assignment != -1 else ""
		result.health = person.health
		result.morale = person.morale
		result.suppression = person.suppression
		result.basic_training = person.basic_training
		result.qualification = person.qualification
		result.rear_place = person.rear_place
		result.crew_station = person.crew_station
		result.service_seconds = person.service_seconds
		result.leader_appointment = person.leader_appointment
		result.bleed_remaining = maxf(0.0, person.bleed_until - _time) if person.assignment == Records.Assignment.WOUNDED else 0.0
		result.loss_recorded = person.loss_recorded
	if entity.kind == Records.Kind.WEAPON:
		result.loaded_rounds = int(snapshot_facts.loaded.get(id,0)) if snapshot_facts.has("loaded") else loaded_rounds(id)
		result.loaded_capacity = entity.loaded_capacity
		result.ammo_type = entity.ammo_type
		result.functional = entity.health > 0
	return result


func inspect_claim(id: String) -> Dictionary:
	if not _claims.has(id):
		return {}
	var claim := _claims[id]
	var unfilled := claim.requested - claim.reserved - claim.fulfilled
	return {
		"id": id, "claimant": claim.claimant, "purpose": claim.purpose,
		"source_id": claim.source_id, "requested": claim.requested, "reserved": claim.reserved,
		"fulfilled": claim.fulfilled, "unfilled": unfilled, "cancelled": claim.cancelled,
		"created_at": claim.created_at, "age": _time - claim.created_at,
		"blocked_reason": "Claim cancelled" if claim.cancelled else (
			"Insufficient unreserved stock at source; demand remains" if unfilled > 0 else ""),
	}


func snapshot(include_mass: bool = true) -> Dictionary:
	# Metadata readers retain all facts except the explicitly omitted load mass.
	# Physical admission/audit callers keep the complete default inspection.
	var entities: Array[Dictionary] = []
	var claims: Array[Dictionary] = []
	# This inspection is synchronous. Compute aggregate masses once for this call;
	# no cache survives a physical ledger change.
	var masses := {}
	var facts := {"loaded":{},"carried":{}}
	# This synchronous read sees one ledger state. Summing integer stock counts
	# and carry IDs once preserves the raw inspection semantics, including
	# interrupted carries. Nothing is cached across a ledger mutation.
	for entity in _entities.values():
		if entity.kind == Records.Kind.STOCK:
			facts.loaded[entity.holder_id] = int(facts.loaded.get(entity.holder_id,0))+entity.quantity
		if entity is Records.Person and not entity.carrying_stock_id.is_empty(): facts.carried[entity.carrying_stock_id] = true
	if include_mass:
		var children: Dictionary = _children_by_holder()
		for id in _entities: _indexed_contents_mass(id,children,masses)
	for id in _entities:
		entities.append(inspect_entity(id,masses,include_mass,facts))
	for id in _claims:
		claims.append(inspect_claim(id))
	return {"time": _time, "entities": entities, "claims": claims,
		"created": _created.duplicate(), "consumed": _consumed.duplicate(),
		"lost": _lost.duplicate(), "fuel_initial":_fuel_initial,"fuel_loaded":_fuel_loaded,"fuel_burned":_fuel_burned,"fuel_lost":_fuel_lost,
		"rear_hull_promises":_rear_hull_promises.duplicate(true), "events": _events.duplicate(true)}


func total_stock(type: String, owner: String = "") -> int:
	var total: int = 0
	for entity in _entities.values():
		if entity.design_type == type and entity.kind in [Records.Kind.STOCK, Records.Kind.WEAPON] and (owner.is_empty() or entity.owner == owner):
			total += entity.quantity
	return total


func loose_stock_mass_at(holder_id: String) -> float:
	var total: float = 0.0
	for entity in _entities.values():
		if entity.kind == Records.Kind.STOCK and entity.holder_id == holder_id:
			total += entity.quantity * entity.unit_mass_kg
	return total


func available_stock_at(holder_id: String, type: String) -> int:
	var total: int = 0
	for entity in _entities.values():
		if entity.kind == Records.Kind.STOCK and entity.holder_id == holder_id and entity.design_type == type:
			total += available(entity.id)
	return total


func audit() -> Array[String]:
	var failures: Array[String] = []
	var tank_total := 0.0
	var occupied_stations: Dictionary = {}
	var owners: Array[String] = []
	for claim in _rear_hull_promises.values():
		if claim.owner not in owners: owners.append(claim.owner)
	for entity in _entities.values():
		if entity.fleet_domain == "Rear" and entity.owner not in owners: owners.append(entity.owner)
	for owner in owners:
		var status := rear_fleet_status(owner)
		if status.live + status.reserved > REAR_FLEET_LIMIT: failures.append("Rear hull admission overbooked: " + owner)
	for entity in _entities.values():
		if entity.kind != Records.Kind.PLACE and not _entities.has(entity.holder_id):
			failures.append("Missing holder: " + entity.id)
		if entity.quantity < 0:
			failures.append("Negative physical count: " + entity.id)
		if entity.kind == Records.Kind.STOCK and (reserved(entity.id) < 0 or available(entity.id) < 0):
			failures.append("Overbooked stock: " + entity.id)
		if entity.kind == Records.Kind.WEAPON and loaded_rounds(entity.id) > entity.loaded_capacity:
			failures.append("Overfull weapon: " + entity.id)
		if entity is Records.Person and not entity.carrying_stock_id.is_empty():
			var carried := _stock(entity.carrying_stock_id)
			if carried == null or carried.holder_id != entity.id or carried.quantity <= 0:
				failures.append("Broken active carry: " + entity.id)
		if entity is Records.Person and not entity.carrying_weapon_id.is_empty():
			var weapon := _weapon(entity.carrying_weapon_id)
			if weapon == null or weapon.holder_id != entity.id: failures.append("Broken active weapon carry: " + entity.id)
		if entity.kind == Records.Kind.CARRIER and not entity.vehicle_spec.is_empty():
			tank_total += entity.fuel
			if entity.fuel < -0.000001 or entity.fuel > float(entity.vehicle_spec.tank_capacity) + 0.000001: failures.append("Invalid vehicle tank: " + entity.id)
		if entity is Records.Person and not entity.crew_station.is_empty():
			var hull: Records.Entity = _entities.get(entity.holder_id)
			var valid: bool = hull != null and hull.kind == Records.Kind.CARRIER and entity.assignment in [Records.Assignment.REAR_LABOUR,Records.Assignment.FORMATION_DUTY,Records.Assignment.WOUNDED,Records.Assignment.RECOVERY,Records.Assignment.DEAD] and entity.carrying_stock_id.is_empty()
			if valid and not hull.vehicle_spec.is_empty():
				valid = entity.crew_station in hull.vehicle_spec.stations and (entity.qualification == "P08" or (hull.design_type == "T03" and entity.crew_station == "Gunner" and entity.qualification == "P04"))
			else: valid = valid and entity.crew_station == "Driver" and entity.qualification == "P08"
			if not valid: failures.append("Invalid occupied vehicle station: " + entity.id)
			var key: String = entity.holder_id + ":" + entity.crew_station
			if occupied_stations.has(key): failures.append("Double-filled station: " + key)
			occupied_stations[key] = entity.id
	if not is_equal_approx(tank_total + _fuel_burned + _fuel_lost, _fuel_initial + _fuel_loaded): failures.append("Manufactured vehicle fuel conservation")
	for type in _created:
		if not is_equal_approx(float(_created[type]), float(total_stock(type) + _consumed.get(type, 0) + _lost.get(type, 0)) + (_fuel_loaded if type == "M08" else 0.0)):
			failures.append("Conservation failed: " + type)
	for claim in _claims.values():
		if claim.reserved < 0 or claim.fulfilled < 0 or claim.reserved + claim.fulfilled > claim.requested:
			failures.append("Invalid claim counts: " + claim.id)
	return failures


func _check_transfer(source: Records.Entity, quantity: int, destination_id: String, claim_id: String) -> Dictionary:
	if source == null or not _can_hold_stock(destination_id):
		return _reject("INVALID_HOLDER", "Source stock and an existing physical destination are required.")
	if _entities[source.holder_id].kind == Records.Kind.WEAPON:
		return _reject("LOADED_ROUNDS", "Unload rounds through the weapon before moving them as loose stock.")
	if source.holder_id == destination_id or not _colocated(source.id, destination_id):
		return _reject("NOT_COLOCATED", "Physical travel must complete before this local handling boundary.")
	if quantity <= 0 or quantity > source.quantity:
		return _reject("INVALID_QUANTITY", "Transfer a positive whole count within actual stock.")
	if not claim_id.is_empty():
		if not _claims.has(claim_id) or _claims[claim_id].cancelled:
			return _reject("NO_ACTIVE_CLAIM", "The transfer needs an active matching claim.")
		var claim := _claims[claim_id]
		if claim.source_id != source.id or claim.reserved < quantity:
			return _reject("CLAIM_MISMATCH", "This claim does not reserve the requested amount from this source.")
	elif quantity > available(source.id):
		return _reject("STOCK_RESERVED", "This stock is reserved for another request; release it or use its matching claim.")
	return {}


func _split_stock(source: Records.Entity, quantity: int, destination_id: String) -> Records.Entity:
	var new_id: String
	while true:
		_sequence += 1
		new_id = "portion-%04d" % _sequence
		if _free_id(new_id):
			break
	var portion := _new_entity(new_id, Records.Kind.STOCK, source.design_type, source.owner,
		"", destination_id, source.description)
	portion.origin_id = source.origin_id
	portion.personal_gear_owner = source.personal_gear_owner
	portion.quantity = quantity
	portion.unit_mass_kg = source.unit_mass_kg
	source.quantity -= quantity
	if source.quantity == 0:
		source.state = "Depleted"
		source.state_entered_at = _time
	return portion


func _remove_stock(id: String, quantity: int, reason: String, loss: bool) -> Dictionary:
	var stock := _stock(id)
	if stock == null or quantity <= 0 or reason.strip_edges().is_empty():
		return _reject("INVALID_REMOVAL", "Record a positive whole count, source and explicit consumption/loss reason.")
	if _entities[stock.holder_id].kind == Records.Kind.WEAPON or _is_active_carry(id) or quantity > available(id):
		return _reject("STOCK_COMMITTED", "Resolve loaded rounds and existing claims before recording this accounting event.")
	stock.quantity -= quantity
	if stock.quantity == 0:
		stock.state = "Depleted"
		stock.state_entered_at = _time
	var totals := _lost if loss else _consumed
	totals[stock.design_type] = totals.get(stock.design_type, 0) + quantity
	_event(("Loss: " if loss else "Consumption: ") + reason, id)
	return _ok("Count removed once with an explicit accounting reason.", id)


func _set_assignment(person: Records.Person, assignment: int, duty_id: String) -> void:
	person.assignment = assignment as Records.Assignment
	person.duty_id = "" if assignment == Records.Assignment.AVAILABLE else duty_id
	person.pending_assignment = -1
	person.pending_duty = ""
	person.state = Records.ASSIGNMENT_NAMES[assignment]
	person.state_entered_at = _time
	_event("Exclusive duty now " + person.state, person.id)


func _new_entity(id: String, kind: Records.Kind, type: String, owner: String,
		controller: String, holder: String, description: String) -> Records.Entity:
	var entity := Records.Entity.new()
	_fill_entity(entity, id, kind, type, owner, controller, holder, description)
	_entities[id] = entity
	return entity


func _fill_entity(entity: Records.Entity, id: String, kind: Records.Kind, type: String,
		owner: String, controller: String, holder: String, description: String) -> void:
	entity.id = id
	entity.kind = kind
	entity.design_type = type
	entity.owner = owner
	entity.controller = controller
	entity.holder_id = holder
	entity.description = description
	entity.created_at = _time
	entity.state_entered_at = _time


func _contents_mass(holder_id: String) -> float:
	# Stock is a leaf: all legal physical holders are places, carriers, people
	# or (for loaded rounds) weapons.
	if _entities.has(holder_id) and _entities[holder_id].kind == Records.Kind.STOCK: return 0.0
	return _indexed_contents_mass(holder_id,_children_by_holder(),{})

func _children_by_holder() -> Dictionary:
	var children := {}
	for entity in _entities.values():
		if not children.has(entity.holder_id): children[entity.holder_id] = []
		children[entity.holder_id].append(entity)
	return children

func _indexed_contents_mass(holder_id: String, children: Dictionary, masses: Dictionary) -> float:
	if masses.has(holder_id): return masses[holder_id]
	var total: float = 0.0
	# Original subtree/insertion addition order is preserved at exact carry limits.
	for entity in children.get(holder_id,[]):
		total += entity.unit_mass_kg*entity.quantity+_indexed_contents_mass(entity.id,children,masses)
	masses[holder_id] = total
	return total


func _world_position(id: String) -> Vector2:
	var entity := _entities[id]
	if entity.holder_id.is_empty():
		return entity.position
	return entity.position + _world_position(entity.holder_id)


func _colocated(first_id: String, second_id: String) -> bool:
	# Accounting fixture commits at the same physical point. Actual route and
	# timed handoff eligibility is supplied by later hauling/combat activities.
	return _world_position(first_id).is_equal_approx(_world_position(second_id))


func _free_id(id: String) -> bool:
	return not id.is_empty() and not _entities.has(id) and not _claims.has(id)


func _is_place(id: String) -> bool:
	return _entities.has(id) and _entities[id].kind == Records.Kind.PLACE


func _is_person_holder(id: String) -> bool:
	return _entities.has(id) and _entities[id].kind in [Records.Kind.PLACE, Records.Kind.CARRIER]


func _can_hold_stock(id: String) -> bool:
	return _entities.has(id) and _entities[id].kind in [Records.Kind.PLACE, Records.Kind.CARRIER, Records.Kind.PERSON]


func _stock(id: String) -> Records.Entity:
	return _entities[id] if _entities.has(id) and _entities[id].kind == Records.Kind.STOCK else null


func _weapon(id: String) -> Records.Entity:
	return _entities[id] if _entities.has(id) and _entities[id].kind == Records.Kind.WEAPON else null


func _person(id: String) -> Records.Person:
	return _entities.get(id) as Records.Person


func _is_active_carry(id: String) -> bool:
	for entity in _entities.values():
		if entity is Records.Person and entity.carrying_stock_id == id:
			return true
	return false


func _valid_mass(value: float) -> bool:
	return is_finite(value) and value > 0.0


func _event(description: String, id: String) -> void:
	_events.append({"time": _time, "entity_id": id, "description": description})


func _ok(message: String, id: String = "") -> Dictionary:
	return {"ok": true, "code": "OK", "message": message, "entity_id": id}


func _reject(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "entity_id": ""}
