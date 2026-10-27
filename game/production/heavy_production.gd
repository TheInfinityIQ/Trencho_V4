extends "res://game/production/selectable_production.gd"
## F10's one physical bay, accepted-order admissions and staged heavy output.
const CHOICES: Array[String] = ["R25","R28","R13","R29","R30","R31"]
const Specs = preload("res://game/production/vehicle_specs.gd")
const BAY := "heavy-bay"
const CLAIMANT := "F10 heavy production"
var bay_accessible := true
var parking_accessible := true
var bay_occupant := ""
var _order: Dictionary = {}
var _orders: Array[Dictionary] = []
var _order_sequence := 0

func _init(rear: RefCounted, declared_access: Array[String] = []) -> void:
	assert(rear.heavy_production == null, "F10 has exactly one production owner.")
	rear.ledger.add_place(BAY,"F10 one heavy object/vehicle output bay",rear.Layout.FACILITIES.vehicle_works[1])
	super(rear,"R25",CHOICES,["R25","R28"],declared_access)

func _access() -> bool:
	return recipe_accessible(_recipe) and bay_accessible and _rear_ref.get_ref().stores.vehicle_input.accessible

func _empty_bay() -> bool:
	return bay_occupant.is_empty() and _rear_ref.get_ref().ledger.entities_at(BAY,["CARRIER","HEAVY_OBJECT"]).is_empty()

func _parking_valid() -> bool:
	if _order.is_empty(): return false
	if _order.recipe == "R13": return true
	var rear: RefCounted = _rear_ref.get_ref()
	var slot: int = _order.parking_slot
	return parking_accessible and _slot_legal(slot) and rear.yard.occupied[slot].is_empty() and rear.yard.reserved[slot] == _order.id

func _slot_legal(slot: int) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if slot < 0 or slot >= rear.yard.PARKING_POSITIONS.size(): return false
	var size: Vector2 = Specs.TYPES[_spec.output_type].footprint
	var box := Rect2(rear.yard.PARKING_POSITIONS[slot] - size / 2.0,size)
	var park: Array = rear.Layout.FACILITIES.park
	if not Rect2(park[1]-park[2]/2.0,park[2]).encloses(box): return false
	for index in rear.yard.occupied.size():
		if index == slot: continue
		var id: String = rear.yard.occupied[index] if not rear.yard.occupied[index].is_empty() else rear.yard.reserved[index]
		if id.is_empty() or id == _order.get("id",""): continue
		var entity: Dictionary = rear.ledger.inspect_entity(id)
		var type: String = entity.get("design_type","T01")
		var other: Vector2 = Specs.TYPES[type].footprint if Specs.TYPES.has(type) else Vector2(8.5,3.5)
		if box.intersects(Rect2(rear.yard.PARKING_POSITIONS[index]-other/2.0,other)): return false
	return true

func _own_admission_valid() -> bool:
	if _recipe == "R13": return true
	if _order.is_empty(): return false
	var claim: Dictionary = _rear_ref.get_ref().ledger.inspect_rear_hull_claim(_order.id)
	return claim.get("claimant") == CLAIMANT and claim.get("owner") == "army-blue"

func accept_order() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	if not _order.is_empty(): return _result(false,"This heavy order is already accepted and owns its promises.")
	if not recipe_accessible(_recipe): return _result(false,"Selected heavy recipe is locked in this session.")
	if not enabled: return _result(false,"Enable the facility before accepting an order.")
	if _target_satisfied(): return _result(false,"Set a higher stock minimum or Continuous to request another heavy object.")
	if not _empty_bay(): return _result(false,"F10 bay occupied: the same finished object needs actual driving or heavy collection; no new order accepted.")
	if not _access(): return _result(false,"F10/input access blocked; no order accepted.")
	var slot := -1
	if _recipe != "R13":
		if not parking_accessible: return _result(false,"Parking route inaccessible; no order accepted.")
		for index in rear.yard.occupied.size():
			if rear.yard.occupied[index].is_empty() and rear.yard.reserved[index].is_empty() and _slot_legal(index):
				slot = index
				break
		if slot < 0: return _result(false,"No legal parking destination; no order accepted.")
	var id := "heavy-order-%04d" % (_order_sequence + 1)
	if _recipe != "R13":
		var admission: Dictionary = rear.ledger.reserve_rear_hull(id,rear.PLAYER,CLAIMANT)
		if not admission.ok: return admission
		# No intervening yield: reserve the destination and order with this admission.
		rear.yard.reserved[slot] = id
	_order_sequence += 1
	_order = {"id":id,"recipe":_recipe,"state":"Accepted","accepted_at":rear.time,"parking_slot":slot,"parking_position":rear.yard.PARKING_POSITIONS[slot] if slot >= 0 else rear.ledger.inspect_entity(BAY).position,"batch_id":"","output_id":""}
	_orders.append(_order)
	rear._settle()
	return _result(true,"Heavy order accepted; one bay" + (" and rear-fleet/parking admissions reserved before materials." if slot >= 0 else " reserved without a vehicle fleet slot."))

func _target_satisfied() -> bool:
	if not _order.is_empty() or not batch.is_empty(): return false
	return super._target_satisfied()

func settle() -> bool:
	if _order.is_empty(): return false # Requested target is distinct from accepted, reserved order.
	return super.settle()

func _reserve_output(id: String) -> Dictionary:
	if _order.is_empty() or _order.recipe != _recipe or not _empty_bay() or not _own_admission_valid() or not _parking_valid():
		return _result(false,"Own bay/fleet/parking promises must be legal before consumption.")
	_order.batch_id = id
	return _result(true,"Existing accepted order's whole bay promise retained.")

func _output_valid(id: String) -> bool:
	return not _order.is_empty() and _order.batch_id == id and _empty_bay()

func _create_output() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	if not _output_valid(batch.id) or not _own_admission_valid() or not _parking_valid():
		return _result(false,"Fully earned output waits for its own legal admission and parking/collection destination.")
	var properties: Dictionary = {"mass":180.0,"health":400} if _recipe == "R13" else Specs.TYPES[_spec.output_type]
	var result: Dictionary = rear.ledger.create_heavy_output(_order.id,CLAIMANT,batch.output_id,_spec.output_type,BAY,rear.PLAYER,properties)
	if not result.ok: return result
	bay_occupant = batch.output_id
	if _order.parking_slot >= 0: rear.yard.reserved[_order.parking_slot] = bay_occupant
	_order.state = "Completed"
	_order.output_id = bay_occupant
	_order.completed_at = rear.time
	_order = {} # Finished object and its parking/fleet place cannot be cancelled.
	return result

func _release_output(_id: String) -> void:
	_release_order()

func _release_order() -> void:
	if _order.is_empty(): return
	var rear: RefCounted = _rear_ref.get_ref()
	if _order.parking_slot >= 0:
		if rear.yard.reserved[_order.parking_slot] == _order.id: rear.yard.reserved[_order.parking_slot] = ""
		rear.ledger.release_rear_hull(_order.id,CLAIMANT)
	_order.state = "Cancelled"
	_order.cancelled_at = rear.time
	_order = {}

func cancel() -> Dictionary:
	var result := super.cancel()
	_release_order() # Includes accepted but still unconsumed orders.
	return result

func _select(recipe: String) -> Dictionary:
	if batch.is_empty(): _release_order() # No consumed loss for a waiting order.
	return super._select(recipe)

func set_access(bay: bool, parking: bool) -> Dictionary:
	bay_accessible = bay
	parking_accessible = parking
	_rear_ref.get_ref()._settle()
	return _result(true,"Access updated; consumed work and own promises retained.")

func set_parking_destination(slot: int) -> Dictionary:
	if _order.is_empty() or _order.recipe == "R13": return _result(false,"An accepted hull order is required to edit its parking destination.")
	var rear: RefCounted = _rear_ref.get_ref()
	if not _slot_legal(slot) or not rear.yard.occupied[slot].is_empty() or rear.yard.reserved[slot] not in ["",_order.id]:
		return _result(false,"Destination edit refused atomically: occupied or reserved parking.")
	var old: int = _order.parking_slot
	rear.yard.reserved[slot] = _order.id
	if old != slot and rear.yard.reserved[old] == _order.id: rear.yard.reserved[old] = ""
	_order.parking_slot = slot
	_order.parking_position = rear.yard.PARKING_POSITIONS[slot]
	rear._settle()
	return _result(true,"Own replacement parking promise secured before releasing the old one.")

func stock_coverage() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var available := 0
	if _spec.output_type == "E13":
		for object in rear.ledger.entities_at(BAY,["HEAVY_OBJECT"]):
			if object.owner == rear.PLAYER: available += 1
	else:
		for id in rear.ledger.rear_fleet_hulls(rear.PLAYER):
			if rear.ledger.inspect_entity(id).design_type == _spec.output_type: available += 1
	var planned := 1 if not _order.is_empty() else 0
	return {"available":available,"planned":planned,"projected":available+planned}

func clearance_reason() -> String:
	if bay_occupant.is_empty(): return ""
	var rear: RefCounted = _rear_ref.get_ref()
	var object: Dictionary = rear.ledger.inspect_entity(bay_occupant)
	if object.design_type == "E13": return "Occupied bay: awaiting two loaders / 20-second field-gun collection (G12)."
	var driver := false
	for id in object.get("crew",[]):
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if person.qualification == "P08" and person.crew_station == "Driver" and person.health > 0: driver = true
	return "Occupied bay: " + ("Awaiting Qualified Driver; " if not driver else "") + ("Fuel Empty; " if object.get("fuel",0.0) <= 0.0 else "") + "actual boarding/refuelling/physical clearance belongs to G07."

func snapshot() -> Dictionary:
	var view := super.snapshot()
	var rear: RefCounted = _rear_ref.get_ref()
	view.order = _order.duplicate(true)
	view.orders = _orders.duplicate(true)
	view.fleet = rear.ledger.rear_fleet_status(rear.PLAYER)
	view.bay = {"slots":1,"accessible":bay_accessible,"occupant":bay_occupant,"physical":rear.ledger.inspect_entity(bay_occupant),"promised_by":_order.get("id",""),"parking_accessible":parking_accessible,"clearance":clearance_reason()}
	view.output_promise = {} if _order.is_empty() else {"id":_order.id,"store":BAY,"slots":1,"mass":_spec.unit_mass}
	view.physical_output = 1 if not bay_occupant.is_empty() and rear.ledger.inspect_entity(bay_occupant).design_type == _spec.output_type else 0
	if not bay_occupant.is_empty(): view.status = clearance_reason()
	elif not enabled: view.status = "No Recipe — stopped"
	elif not recipe_accessible(_recipe): view.status = "Recipe access absent"
	elif _order.is_empty() and _target_satisfied(): view.status = "Target satisfied — no accepted heavy order"
	elif _order.is_empty(): view.status = "Request unaccepted — accept a heavy order to reserve its bay/fleet place"
	elif paused: view.status = "Paused — accepted promises retained"
	elif not _access(): view.status = "Access blocked — accepted promises/work retained"
	elif not _own_admission_valid() or not _parking_valid(): view.status = "Accepted — destination/admission blocked; earned work retained"
	elif not _missing().is_empty() and batch.is_empty(): view.status = "Accepted — Missing Inputs"
	elif operators().is_empty(): view.status = "Accepted — Missing Labour"
	else: view.status = "Accepted — Working"
	return view

func audit() -> Array[String]:
	var failures: Array[String] = []
	var rear: RefCounted = _rear_ref.get_ref()
	if rear.ledger.entities_at(BAY,["CARRIER","HEAVY_OBJECT"]).size() > 1: failures.append("F10 physical bay overbooked")
	if not bay_occupant.is_empty() and not _order.is_empty(): failures.append("F10 live output and promise overlap")
	if not _order.is_empty() and not _own_admission_valid(): failures.append("Accepted hull order lost its own fleet admission")
	return failures

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
