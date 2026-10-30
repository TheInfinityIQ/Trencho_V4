extends RefCounted
## One common-clock owner for physical forward ammunition pickup/walk/deposit.
const EPS := 0.000001
const RADIUS := 20.0
const HANDLING := 2.0
var _rear_ref: WeakRef
var jobs: Dictionary = {}
var _sequence := 0

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func request(stock_id: String, hull_id: String, handler_id: String, quantity: int, stop_id: String) -> Dictionary:
	var rear: RefCounted = _rear()
	var stock: Dictionary = rear.ledger.inspect_entity(stock_id)
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	var handler: Dictionary = rear.ledger.inspect_entity(handler_id)
	var stop: Dictionary = rear.ledger.inspect_entity(stop_id)
	if not rear.forward_supply.delivery_stops.has(stop_id) or stop.get("kind","") != "PLACE": return _fail("Choose a declared physical forward stop.")
	if stock.get("kind","") != "STOCK" or stock.get("design_type","") != "E26" or stock.owner != rear.PLAYER or quantity <= 0 or stock.available < quantity or not rear.forward_supply._at_stop(stock,stop): return _fail("Actual unreserved own E26 must have arrived at this stop.")
	if rear.forward_supply.hull_committed(hull_id) or rear.forward_supply.person_committed(handler_id): return _fail("Hull or named handler already has forward work.")
	var error: String = _hull_error(hull_id,stop_id)
	if error.is_empty(): error = _handler_error(handler_id,stop_id)
	if not error.is_empty(): return _fail(error)
	if int(hull.ammunition.get("E26",0))+quantity > 240: return _fail("Actual rack maximum is 240 including its loaded rounds.")
	if float(hull.contents_mass_kg)+quantity*float(stock.unit_mass_kg) > float(hull.vehicle_spec.payload)+EPS: return _fail("Actual ammunition exceeds vehicle payload.")
	if int(floorf((25.0-float(handler.contents_mass_kg))/float(stock.unit_mass_kg))) < 1: return _fail("Handler cannot carry one real round within 25 kg.")
	var leg: Dictionary = rear.forward_supply._leg(handler,stock.position)
	if not leg.ok: return _fail("No legal local source approach.")
	_sequence += 1
	var id := "rack-issue-%04d" % _sequence
	var claim: Dictionary = rear.ledger.request_stock(id,stock_id,quantity,id,"Physical forward vehicle rack issue",rear.PLAYER)
	if not claim.ok or rear.ledger.inspect_claim(id).get("reserved",0) != quantity:
		if claim.ok: rear.ledger.release_claim(id)
		return _fail("The exact arrived ammunition cannot be reserved.")
	jobs[id] = {"id":id,"owner":rear.PLAYER,"stock":stock_id,"source_holder":stock.holder_id,"hull":hull_id,"handler":handler_id,"stop":stop_id,"quantity":quantity,"issued":0,"claim":id,"carry":"","portion":0,"state":"","deadline":INF,"blocker":"","hull_position":hull.position,"expected":handler.position}
	_begin(jobs[id],"Walking Source" if leg.seconds > EPS else "Pickup",stock.position,float(leg.seconds) if leg.seconds > EPS else HANDLING)
	return {"ok":true,"id":id,"message":"Actual E26 reserved for timed local pickup, carry and rack deposit."}

func hull_committed(id: String) -> bool:
	for row in jobs.values():
		if row.hull == id and row.state not in ["Complete","Interrupted"]: return true
	return false

func person_committed(id: String) -> bool:
	for row in jobs.values():
		if row.handler == id and row.state not in ["Complete","Interrupted"]: return true
	return false

func interrupt(id: String) -> Dictionary:
	if not jobs.has(id) or jobs[id].state in ["Complete","Interrupted","Interrupted Carry"]: return _fail("No active rack issue to interrupt.")
	_stop(jobs[id],"Rack issue interrupted; actual goods retain their holders.")
	return {"ok":true,"message":jobs[id].blocker}

func resume(id: String) -> Dictionary:
	var row: Dictionary = jobs.get(id,{})
	if row.is_empty() or row.state not in ["Interrupted","Interrupted Carry"]: return _fail("Only interrupted physical rack handling can resume.")
	for other in jobs.values():
		if other.id != id and other.state not in ["Complete","Interrupted"] and (other.hull == row.hull or other.handler == row.handler): return _fail("Another rack issue owns this hull or handler.")
	if _rear().forward_supply.transport.person_committed(row.handler): return _fail("Forward delivery handling already owns this courier.")
	for other in _rear().forward_supply.jobs.values():
		if other.state not in ["Complete","Interrupted"] and row.handler in [other.handler,other.recipient]: return _fail("Local personal issue already owns this courier.")
	var error: String = _hull_error(row.hull,row.stop)
	if error.is_empty(): error = _handler_error(row.handler,row.stop)
	if not error.is_empty(): return _fail(error)
	var carried: Dictionary = _rear().ledger.inspect_entity(row.carry)
	if row.state == "Interrupted Carry" and (carried.get("holder_id","") != row.handler or carried.get("quantity",0) != row.portion): return _fail("The same carried portion must still exist.")
	var remaining: int = row.quantity-row.issued-(row.portion if row.state == "Interrupted Carry" else 0)
	if remaining > 0:
		_sequence += 1
		var claim_id: String = row.id+"-resume-%04d" % _sequence
		var claim: Dictionary = _rear().ledger.request_stock(claim_id,row.stock,remaining,row.id,"Resume physical rack issue",row.owner)
		if not claim.ok or _rear().ledger.inspect_claim(claim_id).get("reserved",0) != remaining:
			if claim.ok: _rear().ledger.release_claim(claim_id)
			return _fail("Remaining original source ammunition cannot be reserved.")
		row.claim = claim_id
	var destination: Vector2 = _rear().ledger.inspect_entity(row.hull).position if not carried.is_empty() else _rear().ledger.inspect_entity(row.stock).position
	var leg: Dictionary = _rear().forward_supply._leg(_rear().ledger.inspect_entity(row.handler),destination)
	if not leg.ok: _rear().ledger.release_claim(row.claim); return _fail("No legal local resume route.")
	row.hull_position = _rear().ledger.inspect_entity(row.hull).position
	row.blocker = ""
	_begin(row,("Walking Hull" if not carried.is_empty() else "Walking Source") if leg.seconds > EPS else ("Drop" if not carried.is_empty() else "Pickup"),destination,float(leg.seconds) if leg.seconds > EPS else HANDLING)
	return {"ok":true,"message":"Same actual rack issue resumed."}

func next_boundary() -> float:
	var next := INF
	for row in jobs.values():
		if _active(row): next = minf(next,minf(float(row.deadline),_rear().time+1.0))
	return next

func advance_to(at: float) -> void:
	for row in jobs.values():
		if not _active(row): continue
		var error: String = _valid(row)
		if not error.is_empty(): _stop(row,error); continue
		if row.state not in ["Walking Source","Walking Hull"]: continue
		var fraction: float = clampf((at-float(row.started))/maxf(EPS,float(row.deadline)-float(row.started)),0,1)
		var point: Vector2 = row.from.lerp(row.to,fraction)
		var moved: Dictionary = _rear().ledger.move_entity(row.handler,row.stop,point)
		if moved.ok: row.expected = _rear().ledger.inspect_entity(row.handler).position
		else: _stop(row,moved.message)

func settle() -> bool:
	var changed := false
	for row in jobs.values():
		if not _active(row) or float(row.deadline) > _rear().time+EPS: continue
		changed = true
		var error: String = _valid(row)
		if not error.is_empty(): _stop(row,error); continue
		match row.state:
			"Walking Source": _begin(row,"Pickup",row.to,HANDLING)
			"Pickup": _pickup(row)
			"Walking Hull": _begin(row,"Drop",row.to,HANDLING)
			"Drop": _drop(row)
	return changed

func _pickup(row: Dictionary) -> void:
	var rear: RefCounted = _rear()
	var source: Dictionary = rear.ledger.inspect_entity(row.stock)
	var person: Dictionary = rear.ledger.inspect_entity(row.handler)
	if source.get("holder_id","") != row.source_holder or not rear.forward_supply._at_stop(source,rear.ledger.inspect_entity(row.stop)) or person.position.distance_to(source.position) > 0.75+EPS: _stop(row,"Actual source moved before pickup."); return
	row.portion = mini(row.quantity-row.issued,int(floorf((25.0-float(person.contents_mass_kg))/float(source.unit_mass_kg))))
	if row.portion <= 0: _stop(row,"Actual handler has no remaining carry capacity."); return
	var result: Dictionary = rear.ledger.transfer_stock(row.stock,row.portion,row.handler,row.claim)
	if not result.ok: _stop(row,result.message); return
	row.carry = result.entity_id
	var leg: Dictionary = rear.forward_supply._leg(rear.ledger.inspect_entity(row.handler),row.hull_position)
	if not leg.ok: _stop(row,"No legal loaded local walk to the stopped hull."); return
	_begin(row,"Walking Hull" if leg.seconds > EPS else "Drop",row.hull_position,float(leg.seconds) if leg.seconds > EPS else HANDLING)

func _drop(row: Dictionary) -> void:
	var rear: RefCounted = _rear()
	var carried: Dictionary = rear.ledger.inspect_entity(row.carry)
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	var person: Dictionary = rear.ledger.inspect_entity(row.handler)
	if carried.get("holder_id","") != row.handler or carried.quantity != row.portion or person.position.distance_to(hull.position) > 0.75+EPS: _stop(row,"Same real portion must reach this stopped hull."); return
	if int(hull.ammunition.get("E26",0))+int(row.portion) > 240 or float(hull.contents_mass_kg)+float(carried.unit_mass_kg)*row.portion > float(hull.vehicle_spec.payload)+EPS: _stop(row,"Actual rack or payload capacity changed before deposit."); return
	var result: Dictionary = rear.ledger.transfer_stock(row.carry,row.portion,row.hull)
	if not result.ok: _stop(row,result.message); return
	row.issued += row.portion
	row.carry = ""
	if row.issued == row.quantity:
		row.state = "Complete"
		row.deadline = INF
		rear.ledger.release_claim(row.claim)
		return
	var source: Dictionary = rear.ledger.inspect_entity(row.stock)
	var leg: Dictionary = rear.forward_supply._leg(rear.ledger.inspect_entity(row.handler),source.position)
	if not leg.ok: _stop(row,"No legal return walk to remaining actual ammunition."); return
	_begin(row,"Walking Source" if leg.seconds > EPS else "Pickup",source.position,float(leg.seconds) if leg.seconds > EPS else HANDLING)

func _hull_error(id: String, stop_id: String) -> String:
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(id)
	var stop: Dictionary = rear.ledger.inspect_entity(stop_id)
	if hull.get("kind","") != "CARRIER" or hull.get("design_type","") != "T04" or hull.get("fleet_domain","") != "Military" or hull.owner != rear.PLAYER or not rear.military.vehicles.has(id) or hull.health <= 0: return "Choose one attached living own military T04."
	if hull.holder_id != stop_id or hull.position.distance_to(stop.position) > RADIUS+EPS or rear.military.hull_committed(id) or rear.forward_supply.transport.hull_committed(id): return "The same T04 must stop locally without another movement or issue commitment."
	for issue in rear.hq.jobs.values():
		if issue.target == id and issue.state not in ["Complete","Cancelled"]: return "Actual HQ issue already owns this hull."
	if not str(hull.get("towing","")).is_empty() or not str(hull.get("towed_by","")).is_empty() or (rear.recovery != null and (rear.recovery.jobs.has(id) or rear.recovery.journeys.has(id) or rear.recovery.couplings.has(id))): return "Recovery or towing already owns this hull."
	if not rear.vehicle_combat._mount(id).reload_due.is_empty(): return "Mounted reload must finish before local rack handling."
	return ""

func _handler_error(id: String, stop_id: String) -> String:
	var rear: RefCounted = _rear()
	var person: Dictionary = rear.ledger.inspect_entity(id)
	if not rear.forward_supply._active_member(id) or person.health <= 0 or not str(person.crew_station).is_empty() or person.pending_assignment != "None" or not str(person.carrying_stock_id).is_empty() or not str(person.carrying_weapon_id).is_empty() or rear.ledger.inspect_entity(person.holder_id).get("kind","") != "PLACE" or person.position.distance_to(rear.ledger.inspect_entity(stop_id).position) > RADIUS+EPS: return "Named actual formation handler must be healthy and on foot within 20 m."
	if rear.military.person_committed(id) or rear.forward_supply._other_busy(id) or (rear.battlefield_operations != null and rear.battlefield_operations.person_committed(id)): return "Named handler must stop movement, boarding, reload, care and other physical work."
	return ""

func _valid(row: Dictionary) -> String:
	var error: String = _hull_error(row.hull,row.stop)
	if error.is_empty(): error = _handler_error(row.handler,row.stop)
	if not error.is_empty(): return error
	if _rear().combat.world.revision != row.revision: return "Terrain changed; revalidate the local carry route before resuming."
	if not _rear().ledger.inspect_entity(row.hull).position.is_equal_approx(row.hull_position) or not _rear().ledger.inspect_entity(row.handler).position.is_equal_approx(row.expected): return "Hull or handler moved outside its owned local issue."
	return ""

func _begin(row: Dictionary, state: String, destination: Vector2, seconds: float) -> void:
	row.state = state
	row.from = _rear().ledger.inspect_entity(row.handler).position
	row.expected = row.from
	row.to = destination
	row.started = _rear().time
	row.deadline = _rear().time+seconds
	row.revision = _rear().combat.world.revision

func _stop(row: Dictionary, reason: String) -> void:
	_rear().ledger.release_claim(row.claim)
	var carry: Dictionary = _rear().ledger.inspect_entity(row.carry)
	var retained: bool = carry.get("holder_id","") == row.handler and carry.get("quantity",0) == row.portion
	row.state = "Interrupted Carry" if retained else "Interrupted"
	if not retained: row.carry = ""
	row.deadline = INF
	row.blocker = reason

func _active(row: Dictionary) -> bool:
	return row.state in ["Walking Source","Pickup","Walking Hull","Drop"]

func snapshot(owner: String = "army-blue") -> Dictionary:
	var rows: Array[Dictionary] = []
	for row in jobs.values():
		if row.owner == owner: rows.append(row.duplicate(true))
	return {"rows":rows}

func audit() -> Array[String]:
	var errors: Array[String] = []
	for row in jobs.values():
		if row.issued < 0 or row.issued > row.quantity: errors.append("Rack issue count outside its actual request: "+row.id)
		if row.state in ["Walking Hull","Drop","Interrupted Carry"]:
			var carry: Dictionary = _rear().ledger.inspect_entity(row.carry)
			if carry.get("holder_id","") != row.handler or carry.get("quantity",0) != row.portion: errors.append("Rack issue actual carry mismatch: "+row.id)
	return errors

func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
