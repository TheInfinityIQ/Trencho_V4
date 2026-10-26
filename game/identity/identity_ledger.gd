extends RefCounted
## Authoritative, scene-owned G01 accounting. Movement methods commit a completed
## physical handling boundary; they do not simulate routes, loading time or courses.

const Records = preload("res://game/identity/identity_records.gd")

var _entities: Dictionary[String, Records.Entity] = {}
var _claims: Dictionary[String, Records.Claim] = {}
var _created: Dictionary[String, int] = {}
var _consumed: Dictionary[String, int] = {}
var _lost: Dictionary[String, int] = {}
var _sequence: int = 0
var _time: float = 0.0
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


func add_carrier(id: String, holder_id: String, owner: String, controller: String) -> Dictionary:
	if not _free_id(id) or not _is_place(holder_id) or owner.is_empty():
		return _reject("INVALID_ENTITY", "A carrier needs a unique ID, owner and physical place.")
	_new_entity(id, Records.Kind.CARRIER, "Carrier fixture", owner, controller, holder_id,
		"Supplier-owned carrier; not a third combat faction.")
	return _ok("Carrier registered.", id)


func add_person(id: String, holder_id: String, owner: String) -> Dictionary:
	if not _free_id(id) or not _is_place(holder_id) or owner.is_empty():
		return _reject("INVALID_ENTITY", "A person needs a unique ID, owner and physical place.")
	var person := Records.Person.new()
	_fill_entity(person, id, Records.Kind.PERSON, "P00", owner, owner, holder_id, "Untrained person")
	person.unit_mass_kg = 80.0
	person.state = "Available"
	_entities[id] = person
	return _ok("Person registered.", id)


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
	if not person.carrying_stock_id.is_empty():
		person.pending_assignment = assignment
		person.pending_duty = duty_id
		_event("Duty requested; waiting for safe deposit", person_id)
		return _ok("Duty requested. Finish the carry or deposit it into valid safe storage first.", person_id)
	_set_assignment(person, assignment, duty_id)
	return _ok("Exclusive duty changed.", person_id)


func cancel_assignment_request(person_id: String) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.pending_assignment == -1:
		return _reject("NO_PENDING_DUTY", "There is no pending duty request to cancel.")
	person.pending_assignment = -1
	person.pending_duty = ""
	_event("Pending duty cancelled; current duty and freight preserved", person_id)
	return _ok("Pending request cancelled; current duty and carried goods are unchanged.", person_id)


func begin_carry(person_id: String, stock_id: String, quantity: int) -> Dictionary:
	var person := _person(person_id)
	if person == null or person.assignment != Records.Assignment.REAR_LABOUR:
		return _reject("NOT_LABOUR", "A rear labour assignment is required for this carry fixture.")
	if not person.carrying_stock_id.is_empty() or person.pending_assignment != -1:
		return _reject("PERSON_BUSY", "Finish the existing carry or pending handoff first.")
	var stock := _stock(stock_id)
	if stock != null and stock.unit_mass_kg * quantity > 25.0:
		return _reject("CARRY_TOO_HEAVY", "An ordinary carry is limited to 25 kg of one item type (GDD section 4).")
	var result := transfer_stock(stock_id, quantity, person_id)
	if result.ok:
		person.carrying_stock_id = result.entity_id
	return result


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


func load_rounds(weapon_id: String, source_id: String, quantity: int) -> Dictionary:
	var weapon := _weapon(weapon_id)
	var source := _stock(source_id)
	if weapon == null or source == null or source.design_type != weapon.ammo_type:
		return _reject("WRONG_AMMUNITION", "The weapon and matching loose ammunition must exist.")
	if source.holder_id != weapon.holder_id or source.owner != weapon.owner:
		return _reject("AMMUNITION_NOT_CARRIED", "Reload from loose ammunition owned and physically held alongside this weapon.")
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


func record_loss(source_id: String, quantity: int, reason: String) -> Dictionary:
	return _remove_stock(source_id, quantity, reason, true)


func loaded_rounds(weapon_id: String) -> int:
	var total: int = 0
	for entity in _entities.values():
		if entity.kind == Records.Kind.STOCK and entity.holder_id == weapon_id:
			total += entity.quantity
	return total


func inspect_entity(id: String) -> Dictionary:
	if not _entities.has(id):
		return {}
	var entity := _entities[id]
	var result := {
		"id": id, "kind": Records.Kind.keys()[entity.kind], "design_type": entity.design_type,
		"description": entity.description, "owner": entity.owner, "controller": entity.controller,
		"holder_id": entity.holder_id, "position": _world_position(id), "state": entity.state,
		"created_at": entity.created_at, "state_entered_at": entity.state_entered_at,
		"quantity": entity.quantity, "unit_mass_kg": entity.unit_mass_kg,
		"contents_mass_kg": _contents_mass(id), "origin_id": entity.origin_id,
	}
	if entity.kind == Records.Kind.STOCK:
		result.reserved = reserved(id)
		result.available = available(id)
		result.loaded = _entities[entity.holder_id].kind == Records.Kind.WEAPON
		result.blocked_reason = "Unload weapon before allocating these rounds" if result.loaded else (
			"Finish the active carry before allocating this freight" if _is_active_carry(id) else "")
	if entity is Records.Person:
		var person := entity as Records.Person
		result.assignment = Records.ASSIGNMENT_NAMES[person.assignment]
		result.duty_id = person.duty_id
		result.pending_assignment = "None" if person.pending_assignment == -1 else Records.ASSIGNMENT_NAMES[person.pending_assignment]
		result.pending_duty = person.pending_duty
		result.carrying_stock_id = person.carrying_stock_id
		result.blocked_reason = "Finish carry or deposit into safe storage" if person.pending_assignment != -1 else ""
		result.health = person.health
		result.morale = person.morale
		result.suppression = person.suppression
		result.basic_training = person.basic_training
		result.qualification = person.qualification
		result.service_seconds = person.service_seconds
		result.leader_appointment = person.leader_appointment
	if entity.kind == Records.Kind.WEAPON:
		result.loaded_rounds = loaded_rounds(id)
		result.loaded_capacity = entity.loaded_capacity
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


func snapshot() -> Dictionary:
	var entities: Array[Dictionary] = []
	var claims: Array[Dictionary] = []
	for id in _entities:
		entities.append(inspect_entity(id))
	for id in _claims:
		claims.append(inspect_claim(id))
	return {"time": _time, "entities": entities, "claims": claims,
		"created": _created.duplicate(), "consumed": _consumed.duplicate(),
		"lost": _lost.duplicate(), "events": _events.duplicate(true)}


func total_stock(type: String) -> int:
	var total: int = 0
	for entity in _entities.values():
		if entity.design_type == type and entity.kind in [Records.Kind.STOCK, Records.Kind.WEAPON]:
			total += entity.quantity
	return total


func audit() -> Array[String]:
	var failures: Array[String] = []
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
	for type in _created:
		if _created[type] != total_stock(type) + _consumed.get(type, 0) + _lost.get(type, 0):
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
	var total: float = 0.0
	for entity in _entities.values():
		if entity.holder_id == holder_id:
			total += entity.unit_mass_kg * entity.quantity + _contents_mass(entity.id)
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
