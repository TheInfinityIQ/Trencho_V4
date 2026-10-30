extends RefCounted
## G14 local HQ issue. The ledger owns goods, claims, people, hulls and fuel.
const Records = preload("res://game/identity/identity_records.gd")
const EPS := 0.000001
const HQ := Vector2(1640.0,91.0)
const RESERVE := Vector2(1655.0,91.0)
const WALK_SPEED := 2.0
var _rear_ref: WeakRef
var jobs: Dictionary = {}
var weapon_promises: Dictionary = {}
var _sequence := 0
var auto_status := "Waiting for physically unloaded HQ stock and eligible recipients."
const HULL_TARGETS := {"T03":{"E02":900},"T04":{"E26":180},"T05":{"E25":30,"E02":900}}

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)

func request_person_stock(person_id: String, type: String, quantity: int) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var person: Dictionary = rear.ledger.inspect_entity(person_id)
	if not _person_ready(person): return _fail("Only an actual HQ Reserve person may collect equipment at HQ.")
	if _target_busy(person_id): return _fail("This person already has a physical issue job.")
	var source: Dictionary = _first_source(type)
	if source.is_empty(): return _fail("No unloaded, unreserved %s is physically at HQ stock." % type)
	if quantity <= 0 or person.contents_mass_kg+quantity*float(source.unit_mass_kg) > 25.0+EPS: return _fail("Whole issue must fit the person's 25 kg personal load.")
	return _reserve_job("Person Stock",person_id,type,quantity)

func request_person_weapon(person_id: String, weapon_id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var person: Dictionary = rear.ledger.inspect_entity(person_id)
	var weapon: Dictionary = rear.ledger.inspect_entity(weapon_id)
	if not _person_ready(person): return _fail("Only an actual HQ Reserve person may collect equipment at HQ.")
	if _target_busy(person_id): return _fail("This person already has a physical issue job.")
	if weapon.is_empty() or weapon.kind != "WEAPON" or weapon.holder_id != "hq-stock" or weapon.owner != rear.PLAYER or not weapon.functional or weapon_promises.has(weapon_id): return _fail("Select one unpromised intact weapon physically unloaded at HQ stock.")
	if person.contents_mass_kg+weapon.unit_mass_kg+weapon.contents_mass_kg > 25.0+EPS: return _fail("Intact weapon and retained rounds exceed this person's 25 kg load.")
	_sequence += 1
	var id := "hq-issue-%04d" % _sequence
	jobs[id] = _row(id,"Person Weapon",person_id,weapon.design_type,1,[],weapon_id)
	weapon_promises[weapon_id] = id
	return {"ok":true,"id":id,"message":"Same unloaded weapon promised; recipient must walk to staffed HQ issue before transfer."}

func request_vehicle_ammo(hull_id: String, type: String, quantity: int) -> Dictionary:
	var hull: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(hull_id)
	if not _vehicle_ready(hull): return _fail("The same stopped military hull must be at the HQ berth for local issue.")
	if _target_busy(hull_id): return _fail("This hull already has a physical HQ issue job.")
	var capacity: int = int(hull.vehicle_spec.rack_capacity.get(type,0))
	if capacity <= 0 or quantity <= 0 or quantity > capacity-int(hull.ammunition.get(type,0)): return _fail("Requested rounds exceed this hull's actual matching rack space.")
	return _reserve_job("Vehicle Ammo",hull_id,type,quantity)

func request_vehicle_fuel(hull_id: String, quantity: int) -> Dictionary:
	var hull: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(hull_id)
	if not _vehicle_ready(hull): return _fail("The same stopped military hull must be at the HQ berth for local refuelling.")
	if _target_busy(hull_id): return _fail("This hull already has a physical HQ issue job.")
	if quantity <= 0 or float(quantity) > floorf(float(hull.vehicle_spec.tank_capacity)-float(hull.fuel)+EPS): return _fail("Whole M08 must fit the actual free tank space.")
	return _reserve_job("Vehicle Fuel",hull_id,"M08",quantity)

func _reserve_job(kind: String, target: String, type: String, quantity: int) -> Dictionary:
	if quantity <= 0: return _fail("Request a positive whole quantity.")
	var rear: RefCounted = _rear_ref.get_ref()
	var sources: Array[Dictionary] = []
	var left := quantity
	for stock in rear.ledger.snapshot().entities:
		if stock.kind != "STOCK" or stock.holder_id != "hq-stock" or stock.owner != rear.PLAYER or stock.design_type != type or stock.available <= 0: continue
		var take: int = mini(left,int(stock.available))
		sources.append({"id":stock.id,"quantity":take,"remaining":take,"claim":""})
		left -= take
		if left == 0: break
	if left > 0: return _fail("HQ has only %d unreserved unloaded %s; %d requested. Arrived or onboard stock is not usable." % [quantity-left,type,quantity])
	if kind == "Person Stock":
		var total_mass: float = rear.ledger.inspect_entity(target).contents_mass_kg
		for source in sources: total_mass += float(source.quantity)*float(rear.ledger.inspect_entity(source.id).unit_mass_kg)
		if total_mass > 25.0+EPS: return _fail("Actual reserved stacks would exceed the person's 25 kg load.")
	_sequence += 1
	var id := "hq-issue-%04d" % _sequence
	for index in sources.size():
		var claim_id := "%s-source-%d" % [id,index]
		var claim: Dictionary = rear.ledger.request_stock(claim_id,sources[index].id,sources[index].quantity,id,"Physical HQ local issue",rear.PLAYER)
		if not claim.ok or int(rear.ledger.inspect_claim(claim_id).get("reserved",0)) != int(sources[index].quantity):
			for prior in sources:
				if not str(prior.claim).is_empty(): rear.ledger.release_claim(prior.claim)
			return _fail("HQ stock changed before the whole local issue could be reserved.")
		sources[index].claim = claim_id
	jobs[id] = _row(id,kind,target,type,quantity,sources,"")
	return {"ok":true,"id":id,"message":"Unloaded HQ stock reserved on its real stacks; named local handling remains."}

func _row(id: String, kind: String, target: String, type: String, quantity: int, sources: Array[Dictionary], weapon: String) -> Dictionary:
	return {"id":id,"kind":kind,"target":target,"type":type,"requested":quantity,"issued":0,"sources":sources,"weapon":weapon,"state":"Waiting","handler":"","deadline":INF,"started":0.0,"from":Vector2.ZERO,"portion":0,"cancel_pending":false,"blocker":"Waiting for actual HQ handler."}

func cancel(id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var row: Dictionary = jobs.get(id,{})
	if row.is_empty() or row.state in ["Complete","Cancelled"]: return _fail("Only a live HQ issue request can be cancelled once.")
	row.cancel_pending = true
	if row.kind.begins_with("Person"):
		if row.state in ["Walking","Pickup","Drop","Blocked Carry"]: _start_return(row)
		elif row.state == "Returning": row.blocker = "Recipient completes the real walk back to HQ Reserve."
		elif rear.ledger.inspect_entity(row.target).holder_id == "hq-stock": _start_return(row)
		else: _close(row,true)
	elif row.state in ["Drop","Blocked Carry"]:
		row.state = "Return Carry"
		row.started = _rear_ref.get_ref().time
		row.deadline = row.started+2.0
		row.blocker = "Actual carried stock returns to HQ before releasing unspent claims."
	else:
		_close(row,true)
	return {"ok":true,"message":"HQ issue cancellation retains any already issued goods; carried goods return physically."}

func next_boundary() -> float:
	var next := INF
	for row in jobs.values():
		if row.state in ["Walking","Pickup","Drop","Returning","Return Carry"]: next = minf(next,float(row.deadline))
	return next

func advance_to(next_time: float) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	for row in jobs.values():
		if row.state not in ["Walking","Returning"]: continue
		var fraction: float = clampf((next_time-float(row.started))/maxf(EPS,float(row.deadline)-float(row.started)),0.0,1.0)
		var destination: Vector2 = HQ if row.state == "Walking" else RESERVE
		rear.ledger.move_entity(row.target,"hq-reserve",row.from.lerp(destination,fraction))

func settle() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var changed := false
	for row in jobs.values():
		if row.state in ["Walking","Pickup","Drop","Returning","Return Carry"] and float(row.deadline) <= rear.time+EPS:
			_finish_step(row)
			changed = true
		elif row.state == "Waiting":
			if row.kind.begins_with("Person"):
				var person: Dictionary = rear.ledger.inspect_entity(row.target)
				if not _person_ready(person): row.blocker = "Recipient must remain a real HQ Reserve person."; continue
				if not person.position.is_equal_approx(HQ):
					row.from = person.position
					row.started = rear.time
					row.deadline = rear.time+person.position.distance_to(HQ)/WALK_SPEED
					row.state = "Walking"
					row.blocker = "Recipient walking to actual HQ stock."
					changed = true
					continue
			elif not _vehicle_ready(rear.ledger.inspect_entity(row.target)):
				row.blocker = "Hull must return and stop at HQ berth; reserved stock has not moved."
				continue
			var handler := _free_handler()
			if handler.is_empty(): row.blocker = "Four actual HQ logistics staff are busy or unavailable."; continue
			row.handler = handler
			row.state = "Pickup"
			row.started = rear.time
			row.deadline = rear.time+2.0
			row.blocker = "Named HQ staff handling local stock."
			changed = true
		elif row.state == "Blocked Carry" and _vehicle_ready(rear.ledger.inspect_entity(row.target)):
			_finish_drop(row)
			changed = row.state != "Blocked Carry" or changed
	changed = _auto_request() or changed
	return changed

func _auto_request() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	for row in jobs.values():
		if row.get("automatic",false) and row.state not in ["Complete","Cancelled"]:
			auto_status = "HQ command handling %s for %s: %s" % [row.kind,row.target,row.blocker]
			return false
	if rear.dispatch.military_hulls.is_empty() and rear.dispatch.hq_reserve.is_empty():
		auto_status = "Waiting for an admitted HQ recipient; incoming people and hulls are not eligible yet."
		return false
	var available: Dictionary = snapshot().available
	var first_shortage := ""
	var hull_ids: Array = rear.dispatch.military_hulls.keys()
	hull_ids.sort()
	for id in hull_ids:
		var hull: Dictionary = rear.ledger.inspect_entity(id)
		if not _vehicle_ready(hull) or _target_busy(id): continue
		for type in HULL_TARGETS.get(hull.design_type,{}):
			var needed: int = int(HULL_TARGETS[hull.design_type][type])-int(hull.ammunition.get(type,0))
			var quantity: int = mini(needed,int(available.get(type,0)))
			if quantity > 0 and _auto_accept(request_vehicle_ammo(id,type,quantity)):
				auto_status = "HQ command assigned %d unloaded %s to same stopped %s rack." % [quantity,type,id]
				return true
			if needed > 0 and quantity == 0 and first_shortage.is_empty(): first_shortage = "Need %d unloaded %s at HQ for stopped %s rack." % [needed,type,id]
		var fuel_units: int = mini(int(available.get("M08",0)),int(floorf(float(hull.vehicle_spec.tank_capacity)-float(hull.fuel)+EPS)))
		if fuel_units > 0 and _auto_accept(request_vehicle_fuel(id,fuel_units)):
			auto_status = "HQ command assigned %d unloaded M08 to same stopped %s tank." % [fuel_units,id]
			return true
		if fuel_units == 0 and float(hull.fuel)+1.0 <= float(hull.vehicle_spec.tank_capacity)+EPS and first_shortage.is_empty(): first_shortage = "Need unloaded M08 at HQ for stopped %s tank." % id
	var people_ids: Array = rear.dispatch.hq_reserve.keys()
	people_ids.sort()
	# Finish a named person's minimum ammunition before promising the next rifle.
	for id in people_ids:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if not _auto_person_ready(rear,id,person) or _target_busy(id) or not _held_weapon(rear,id,"E01"): continue
		var needed: int = 30-_held_rounds(rear,id)
		if needed > 0 and int(available.get("E02",0)) >= needed and _auto_accept(request_person_stock(id,"E02",needed)):
			auto_status = "HQ command assigned %d matching unloaded E02 to %s." % [needed,id]
			return true
		if needed > int(available.get("E02",0)) and first_shortage.is_empty(): first_shortage = "Need %d more unloaded E02 at HQ for %s's minimum rifle load." % [needed-int(available.get("E02",0)),id]
	for id in people_ids:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if not _auto_person_ready(rear,id,person) or _target_busy(id) or _held_weapon(rear,id,"E01"): continue
		if int(available.get("E02",0)) < 30-_held_rounds(rear,id): continue
		for weapon in rear.ledger.snapshot().entities:
			if weapon.kind == "WEAPON" and weapon.design_type == "E01" and weapon.holder_id == "hq-stock" and weapon.owner == rear.PLAYER and not weapon_promises.has(weapon.id):
				if _auto_accept(request_person_weapon(id,weapon.id)):
					auto_status = "HQ command assigned same unloaded %s to eligible reserve %s." % [weapon.id,id]
					return true
		if first_shortage.is_empty(): first_shortage = "Need one intact unloaded E01 at HQ for trained generic reserve %s." % id
	auto_status = first_shortage if not first_shortage.is_empty() else "Waiting for eligible stopped military hull or trained generic HQ Reserve person and matching unloaded HQ stock."
	return false

func _auto_accept(result: Dictionary) -> bool:
	if not result.ok: return false
	jobs[result.id].automatic = true
	return true

func _auto_person_ready(rear: RefCounted, id: String, person: Dictionary) -> bool:
	return rear.dispatch.military_people.has(id) and rear.dispatch.hq_reserve.get(id,"") == "Occupied" and _person_ready(person) and person.basic_training and person.qualification == "None"

func _held_weapon(rear: RefCounted, person_id: String, type: String) -> bool:
	for entity in rear.ledger.snapshot().entities:
		if entity.kind == "WEAPON" and entity.design_type == type and entity.holder_id == person_id: return true
	return false

func _held_rounds(rear: RefCounted, person_id: String) -> int:
	var count := 0
	for entity in rear.ledger.snapshot().entities:
		if entity.kind != "STOCK" or entity.design_type != "E02" or entity.quantity <= 0: continue
		if entity.holder_id == person_id: count += entity.quantity
		else:
			var holder: Dictionary = rear.ledger.inspect_entity(entity.holder_id)
			if holder.get("kind","") == "WEAPON" and holder.holder_id == person_id: count += entity.quantity
	return count

func _finish_step(row: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	if row.state == "Walking":
		rear.ledger.move_entity(row.target,"hq-stock",HQ)
		row.state = "Waiting"
		return
	if row.state == "Returning":
		rear.ledger.move_entity(row.target,"hq-reserve",RESERVE)
		_close(row,bool(row.cancel_pending))
		return
	if row.state == "Return Carry":
		var returned: Dictionary = rear.ledger.finish_carry(row.handler,"hq-stock")
		if not returned.ok: row.blocker = returned.message; row.deadline = rear.time+2.0; return
		_close(row,true)
		return
	if row.state == "Pickup":
		if row.cancel_pending:
			_close(row,true)
			return
		if row.kind.begins_with("Vehicle"):
			var source: Dictionary = _current_source(row)
			var stock: Dictionary = rear.ledger.inspect_entity(source.id)
			var handler: Dictionary = rear.ledger.inspect_entity(row.handler)
			row.portion = mini(int(source.remaining),maxi(0,int(floor((25.0-handler.contents_mass_kg)/stock.unit_mass_kg))))
			if row.portion <= 0: row.blocker = "HQ handler cannot carry one whole unit within 25 kg."; row.state = "Waiting"; row.handler = ""; return
			var picked: Dictionary = rear.ledger.begin_carry(row.handler,source.id,row.portion,source.claim)
			if not picked.ok: row.blocker = picked.message; row.state = "Waiting"; row.handler = ""; return
		else:
			row.portion = 1 if row.kind == "Person Weapon" else int(_current_source(row).remaining)
		row.state = "Drop"
		row.started = rear.time
		row.deadline = rear.time+2.0
		return
	if row.state == "Drop": _finish_drop(row)

func _finish_drop(row: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var result: Dictionary
	if row.kind == "Vehicle Ammo":
		var hull: Dictionary = rear.ledger.inspect_entity(row.target)
		if not _vehicle_ready(hull) or int(hull.ammunition.get(row.type,0))+row.portion > int(hull.vehicle_spec.rack_capacity.get(row.type,0)):
			row.state = "Blocked Carry"
			row.blocker = "Same hull must stop at HQ with real matching rack room; handler retains actual carried rounds."
			return
	if row.kind == "Person Stock":
		var stock: Dictionary = rear.ledger.inspect_entity(_current_source(row).id)
		var person: Dictionary = rear.ledger.inspect_entity(row.target)
		if not _person_ready(person) or person.contents_mass_kg+row.portion*stock.unit_mass_kg > 25.0+EPS:
			row.state = "Waiting"
			row.blocker = "Recipient must remain at HQ with 25 kg personal capacity."
			return
	if row.kind == "Person Weapon":
		var weapon: Dictionary = rear.ledger.inspect_entity(row.weapon)
		var person: Dictionary = rear.ledger.inspect_entity(row.target)
		if not _person_ready(person) or weapon.is_empty() or weapon.holder_id != "hq-stock" or person.contents_mass_kg+weapon.unit_mass_kg+weapon.contents_mass_kg > 25.0+EPS:
			row.state = "Waiting"
			row.blocker = "Same intact weapon must remain unloaded at HQ with 25 kg recipient capacity."
			return
	if row.kind == "Person Weapon": result = rear.ledger.transfer_weapon(row.weapon,row.target)
	elif row.kind == "Person Stock":
		var source: Dictionary = _current_source(row)
		result = rear.ledger.transfer_stock(source.id,row.portion,row.target,source.claim)
	elif row.kind == "Vehicle Fuel": result = rear.ledger.load_vehicle_fuel(row.handler,row.target)
	else: result = rear.ledger.finish_carry_to_carrier(row.handler,row.target)
	if not result.ok:
		row.state = "Blocked Carry" if row.kind.begins_with("Vehicle") else "Waiting"
		if row.kind.begins_with("Person") and row.cancel_pending: _start_return(row)
		row.blocker = result.message
		return
	row.issued += row.portion
	if row.kind != "Person Weapon":
		for source in row.sources:
			if source.remaining > 0:
				source.remaining -= row.portion
				break
	if row.cancel_pending:
		if row.kind.begins_with("Person"): _start_return(row)
		else: _close(row,true)
	elif row.issued >= row.requested:
		if row.kind.begins_with("Person"): _start_return(row)
		else: _close(row,false)
	else:
		row.state = "Pickup"
		row.started = rear.time
		row.deadline = rear.time+2.0
		row.blocker = "Named HQ staff handling next reserved whole-unit carry."

func _start_return(row: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var person: Dictionary = rear.ledger.inspect_entity(row.target)
	row.from = person.position
	row.state = "Returning"
	row.started = rear.time
	row.deadline = rear.time+person.position.distance_to(RESERVE)/WALK_SPEED
	row.handler = ""
	row.blocker = "Recipient walking back with actual issued goods."

func _close(row: Dictionary, cancelled: bool) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	for source in row.sources:
		var claim: Dictionary = rear.ledger.inspect_claim(source.claim)
		if not claim.is_empty() and not claim.cancelled: rear.ledger.release_claim(source.claim)
	if not row.weapon.is_empty(): weapon_promises.erase(row.weapon)
	row.handler = ""
	row.deadline = INF
	row.state = "Cancelled" if cancelled else "Complete"
	row.blocker = ""

func _current_source(row: Dictionary) -> Dictionary:
	for source in row.sources:
		if source.remaining > 0: return source
	return {}

func _first_source(type: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	for stock in rear.ledger.snapshot().entities:
		if stock.kind == "STOCK" and stock.holder_id == "hq-stock" and stock.design_type == type and stock.owner == rear.PLAYER and stock.available > 0: return stock
	return {}

func _person_ready(person: Dictionary) -> bool:
	return not person.is_empty() and person.kind == "PERSON" and person.assignment == "HQ Reserve" and person.pending_assignment == "None" and person.owner == _rear_ref.get_ref().PLAYER and person.holder_id in ["hq-reserve","hq-stock"] and person.health > 0 and person.crew_station.is_empty()

func _vehicle_ready(hull: Dictionary) -> bool:
	return not hull.is_empty() and hull.kind == "CARRIER" and hull.fleet_domain == "Military" and hull.owner == _rear_ref.get_ref().PLAYER and hull.holder_id == "hq-berth" and hull.position.is_equal_approx(HQ) and hull.health > 0

func _target_busy(target: String) -> bool:
	for row in jobs.values():
		if row.target == target and row.state not in ["Complete","Cancelled"]: return true
	return false

func _free_handler() -> String:
	var rear: RefCounted = _rear_ref.get_ref()
	var available: Array[String] = rear.dispatch.free_hq_handlers(1)
	return available[0] if not available.is_empty() else ""

func snapshot() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var available: Dictionary = {}
	var reserved: Dictionary = {}
	var weapons_available: Dictionary = {}
	var weapons_promised: Dictionary = {}
	for stock in rear.ledger.snapshot().entities:
		if stock.holder_id != "hq-stock" or stock.owner != rear.PLAYER or stock.quantity <= 0: continue
		if stock.kind == "STOCK":
			available[stock.design_type] = int(available.get(stock.design_type,0))+int(stock.available)
			reserved[stock.design_type] = int(reserved.get(stock.design_type,0))+int(stock.reserved)
		elif stock.kind == "WEAPON":
			var bucket: Dictionary = weapons_promised if weapon_promises.has(stock.id) else weapons_available
			bucket[stock.design_type] = int(bucket.get(stock.design_type,0))+1
	var rows: Array[Dictionary] = []
	for row in jobs.values(): rows.append(row.duplicate(true))
	return {"rows":rows,"available":available,"reserved":reserved,"weapons_available":weapons_available,"weapons_promised":weapons_promised,"occupied_stock_kg":rear.ledger.inspect_entity("hq-stock").contents_mass_kg,"stock_limit_kg":rear.dispatch.HQ_STOCK_KG,"auto_status":auto_status}

func audit() -> Array[String]:
	var errors: Array[String] = []
	var handlers: Dictionary = {}
	for row in jobs.values():
		if row.issued < 0 or row.issued > row.requested: errors.append("HQ issue overfilled "+row.id)
		if not row.handler.is_empty() and row.state not in ["Complete","Cancelled"]:
			if handlers.has(row.handler): errors.append("HQ handler double-booked "+row.handler)
			handlers[row.handler] = true
	return errors

func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
