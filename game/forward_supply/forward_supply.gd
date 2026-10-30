extends RefCounted
## Timed local handoff after a real load reaches a declared forward stop.
## The ledger owns all stock and holder changes; this service owns only commitments.

const ForwardTransport = preload("res://game/forward_supply/forward_transport.gd")
const EPS := 0.000001
const LOCAL_RADIUS := 20.0
const HANDOFF_RADIUS := 0.75
const HANDLING_SECONDS := 2.0
var _rear_ref: WeakRef
var jobs: Dictionary = {}
var transport: RefCounted
var delivery_stops: Dictionary = {}
var _sequence := 0


func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	transport = ForwardTransport.new(rear)


func register_delivery_stop(stop_id: String, outbound_points: Array = [], return_points: Array = []) -> Dictionary:
	var stop: Dictionary = _rear().ledger.inspect_entity(stop_id)
	var hq: Vector2 = _rear().ledger.inspect_entity("hq-berth").position
	if stop.get("kind","") != "PLACE" or stop.position.distance_to(hq) <= LOCAL_RADIUS:
		return _fail("Declare a real forward place outside the HQ issue area.")
	if outbound_points.is_empty() != return_points.is_empty():
		return _fail("Declare both physical route directions or use the previewed direct candidate.")
	if not outbound_points.is_empty():
		if outbound_points.size() < 2 or return_points.size() < 2:
			return _fail("Each authored route needs actual origin and destination waypoints.")
		for point in outbound_points + return_points:
			if typeof(point) != TYPE_VECTOR2 or not (point as Vector2).is_finite():
				return _fail("Every authored waypoint must be a finite metre position.")
		if not (outbound_points[0] as Vector2).is_equal_approx(hq) or not (outbound_points[-1] as Vector2).is_equal_approx(stop.position) or not (return_points[0] as Vector2).is_equal_approx(stop.position) or not (return_points[-1] as Vector2).is_equal_approx(hq):
			return _fail("Authored routes must connect actual HQ and this stop in both directions.")
	delivery_stops[stop_id] = {"outbound_points":outbound_points.duplicate(),"return_points":return_points.duplicate()}
	return {"ok":true,"message":"Physical forward stop and its route candidate declared."}


func request_delivery(hull_id: String, stock_id: String, quantity: int, stop_id: String,
		outbound_points: Array, return_points: Array, loader_id: String, unloader_id: String) -> Dictionary:
	return transport.request_delivery(hull_id,stock_id,quantity,stop_id,outbound_points,return_points,loader_id,unloader_id)


func preview_delivery(hull_id: String, stock_id: String, quantity: int, stop_id: String,
		outbound_points: Array, return_points: Array, loader_id: String, unloader_id: String) -> Dictionary:
	return transport.preview_delivery(hull_id,stock_id,quantity,stop_id,outbound_points,return_points,loader_id,unloader_id)


func resume_delivery(id: String, outbound_points: Array = [], return_points: Array = []) -> Dictionary:
	return transport.resume_delivery(id,outbound_points,return_points)


func interrupt_delivery(id: String) -> Dictionary:
	return transport.interrupt_delivery(id)


func hull_committed(id: String) -> bool:
	return transport.hull_committed(id)


func start_issue(stock_id: String, recipient_id: String, handler_id: String, quantity: int, stop_id: String) -> Dictionary:
	var rear: RefCounted = _rear()
	var ledger: RefCounted = rear.ledger
	var stop: Dictionary = ledger.inspect_entity(stop_id)
	var stock: Dictionary = ledger.inspect_entity(stock_id)
	var recipient: Dictionary = ledger.inspect_entity(recipient_id)
	var handler: Dictionary = ledger.inspect_entity(handler_id)
	if stop.get("kind","") != "PLACE" or stock.get("kind","") != "STOCK" or quantity <= 0:
		return _fail("A declared physical forward stop, real stock and positive whole quantity are required.")
	if not _at_stop(stock,stop) or stock.owner != rear.PLAYER or stock.available < quantity:
		return _fail("Only unreserved friendly stock actually arrived in a carrier or at this stop can be issued.")
	if handler_id == recipient_id or not _active_member(recipient_id) or not _active_member(handler_id):
		return _fail("Recipient and distinct handler must be active actual squad members.")
	if rear.military != null and (rear.military.person_committed(recipient_id) or rear.military.person_committed(handler_id)):
		return _fail("Timed troop boarding or dismount already owns one of these people.")
	if not _on_foot(recipient) or not _on_foot(handler) or _other_busy(recipient_id) or _other_busy(handler_id):
		return _fail("Both people must be healthy, dismounted and free of conflicting work.")
	if person_committed(recipient_id) or person_committed(handler_id):
		return _fail("A person already has one forward issue commitment.")
	if recipient.position.distance_to(stop.position) > LOCAL_RADIUS + EPS or handler.position.distance_to(stop.position) > LOCAL_RADIUS + EPS:
		return _fail("Both people must physically reach the local forward rendezvous first.")
	var mass: float = float(stock.unit_mass_kg) * quantity
	if handler.contents_mass_kg + mass > 25.0 + EPS or recipient.contents_mass_kg + mass > 25.0 + EPS:
		return _fail("The real carry and recipient must each fit the 25 kg personal limit.")
	var leg: Dictionary = _leg(handler,stock.position)
	if not leg.ok: return _fail("Handler cannot reach actual load: " + str(leg.reason))
	_sequence += 1
	var id := "forward-issue-%04d" % _sequence
	var claim: Dictionary = ledger.request_stock(id,stock_id,quantity,id,"Local forward issue",rear.PLAYER)
	if not claim.ok or ledger.inspect_claim(id).reserved != quantity:
		if claim.ok: ledger.release_claim(id)
		return _fail("The exact arrived stock portion cannot be reserved.")
	jobs[id] = {"id":id,"stock":stock_id,"source_holder":stock.holder_id,"recipient":recipient_id,
		"handler":handler_id,"stop":stop_id,"quantity":quantity,"type":stock.design_type,
		"claim":id,"carried_stock":"","issued_stock":"","state":"Walking Source" if leg.seconds > EPS else "Pickup",
		"started":rear.time,"deadline":rear.time+(float(leg.seconds) if leg.seconds > EPS else HANDLING_SECONDS),
		"from":handler.position,"to":stock.position,"expected":handler.position,"blocker":""}
	return {"ok":true,"id":id,"message":"Named local issue reserved; the handler must physically collect and deliver it."}


func interrupt(id: String) -> Dictionary:
	var row: Dictionary = jobs.get(id,{})
	if row.is_empty() or row.state in ["Complete","Interrupted","Interrupted Carry"]:
		return _fail("No active forward issue to interrupt.")
	_interrupt_row(row,"Forward issue interrupted; goods remain at their actual holder.")
	return {"ok":true,"message":row.blocker}


func resume_issue(id: String) -> Dictionary:
	var row: Dictionary = jobs.get(id,{})
	if row.is_empty() or row.state != "Interrupted Carry": return _fail("Only an interrupted carried portion can resume.")
	var rear: RefCounted = _rear()
	var handler: Dictionary = rear.ledger.inspect_entity(row.handler)
	var recipient: Dictionary = rear.ledger.inspect_entity(row.recipient)
	var carried: Dictionary = rear.ledger.inspect_entity(row.carried_stock)
	var stop: Dictionary = rear.ledger.inspect_entity(row.stop)
	if carried.get("holder_id","") != row.handler or carried.quantity != row.quantity or not _active_member(row.handler) or not _active_member(row.recipient):
		return _fail("The same real portion and active members must still exist; no stock is recreated.")
	if rear.military != null and (rear.military.person_committed(row.handler) or rear.military.person_committed(row.recipient)):
		return _fail("Timed troop boarding or dismount already owns one of these people.")
	if not _on_foot(handler) or not _on_foot(recipient) or _other_busy(row.handler) or _other_busy(row.recipient):
		return _fail("Handler and recipient must be dismounted and free of conflicting work.")
	if handler.position.distance_to(stop.position) > LOCAL_RADIUS + EPS or recipient.position.distance_to(stop.position) > LOCAL_RADIUS + EPS:
		return _fail("Resume only after both people reach the original local stop.")
	if recipient.contents_mass_kg + float(carried.unit_mass_kg)*row.quantity > 25.0 + EPS:
		return _fail("Recipient lacks personal capacity for the carried portion.")
	var leg: Dictionary = _leg(handler,recipient.position)
	if not leg.ok: return _fail("Handler cannot reach recipient: " + str(leg.reason))
	_begin(row,"Walking Recipient" if leg.seconds > EPS else "Drop",recipient.position,float(leg.seconds) if leg.seconds > EPS else HANDLING_SECONDS)
	return {"ok":true,"message":"Same carried portion resumes local delivery."}


func person_committed(person_id: String) -> bool:
	if transport.person_committed(person_id): return true
	for row in jobs.values():
		if row.state == "Interrupted Carry":
			if person_id == row.handler and _rear().ledger.inspect_entity(row.carried_stock).get("holder_id","") == row.handler: return true
		elif row.state not in ["Complete","Interrupted"] and person_id in [row.handler,row.recipient]: return true
	return false


func handler_committed(person_id: String) -> bool:
	return person_committed(person_id)


func next_boundary() -> float:
	var next: float = transport.next_boundary()
	for row in jobs.values():
		if row.state in ["Walking Source","Pickup","Walking Recipient","Drop"]: next = minf(next,float(row.deadline))
	return next


func advance_to(at: float) -> void:
	transport.advance_to(at)
	for row in jobs.values():
		if row.state not in ["Walking Source","Walking Recipient"]: continue
		var handler: Dictionary = _rear().ledger.inspect_entity(row.handler)
		if not _on_foot(handler) or not _active_member(row.handler) or _other_busy(row.handler) or not handler.position.is_equal_approx(row.expected):
			_interrupt_row(row,"Handler's activity or position changed; physical carry stopped.")
			continue
		var fraction: float = clampf((at-float(row.started))/maxf(EPS,float(row.deadline)-float(row.started)),0.0,1.0)
		var position: Vector2 = row.from.lerp(row.to,fraction)
		var moved: Dictionary = _rear().ledger.move_entity(row.handler,row.stop,position)
		if moved.ok: row.expected = position
		else: _interrupt_row(row,moved.message)


func settle() -> bool:
	var rear: RefCounted = _rear()
	var changed: bool = transport.settle()
	for row in jobs.values():
		if row.state not in ["Walking Source","Pickup","Walking Recipient","Drop"] or row.deadline > rear.time + EPS: continue
		var handler: Dictionary = rear.ledger.inspect_entity(row.handler)
		if not _on_foot(handler) or not _active_member(row.handler) or _other_busy(row.handler) or not handler.position.is_equal_approx(row.expected):
			_interrupt_row(row,"Handler's activity or position changed; physical carry stopped.")
			changed = true
			continue
		match row.state:
			"Walking Source":
				if not _at_stop(rear.ledger.inspect_entity(row.stock),rear.ledger.inspect_entity(row.stop)):
					_interrupt_row(row,"Arrived load moved before pickup; no stock transferred.")
				else: _begin(row,"Pickup",handler.position,HANDLING_SECONDS)
			"Pickup": _finish_pickup(row)
			"Walking Recipient":
				var recipient: Dictionary = rear.ledger.inspect_entity(row.recipient)
				if not _on_foot(recipient) or not _active_member(row.recipient) or handler.position.distance_to(recipient.position) > HANDOFF_RADIUS + EPS:
					_interrupt_row(row,"Recipient moved or became unavailable; actual stock remains with handler.")
				else: _begin(row,"Drop",handler.position,HANDLING_SECONDS)
			"Drop": _finish_drop(row)
		changed = true
	return changed


func _finish_pickup(row: Dictionary) -> void:
	var rear: RefCounted = _rear()
	var stock: Dictionary = rear.ledger.inspect_entity(row.stock)
	var handler: Dictionary = rear.ledger.inspect_entity(row.handler)
	var stop: Dictionary = rear.ledger.inspect_entity(row.stop)
	var recipient: Dictionary = rear.ledger.inspect_entity(row.recipient)
	if not _at_stop(stock,stop) or stock.holder_id != row.source_holder or handler.position.distance_to(stock.position) > HANDOFF_RADIUS + EPS:
		_interrupt_row(row,"Source or handler moved before pickup; no stock transferred.")
		return
	if not _on_foot(recipient) or not _active_member(row.recipient) or recipient.position.distance_to(stop.position) > LOCAL_RADIUS + EPS:
		_interrupt_row(row,"Recipient left the local stop before pickup.")
		return
	var moved: Dictionary = rear.ledger.transfer_stock(row.stock,row.quantity,row.handler,row.claim)
	if not moved.ok:
		_interrupt_row(row,moved.message)
		return
	row.carried_stock = moved.entity_id
	_release_claim(row)
	var leg: Dictionary = _leg(rear.ledger.inspect_entity(row.handler),recipient.position)
	if not leg.ok:
		_interrupt_row(row,"No safe local route to recipient: " + str(leg.reason))
		return
	_begin(row,"Walking Recipient" if leg.seconds > EPS else "Drop",recipient.position,float(leg.seconds) if leg.seconds > EPS else HANDLING_SECONDS)


func _finish_drop(row: Dictionary) -> void:
	var rear: RefCounted = _rear()
	var handler: Dictionary = rear.ledger.inspect_entity(row.handler)
	var recipient: Dictionary = rear.ledger.inspect_entity(row.recipient)
	var carried: Dictionary = rear.ledger.inspect_entity(row.carried_stock)
	var stop: Dictionary = rear.ledger.inspect_entity(row.stop)
	if carried.get("holder_id","") != row.handler or not _on_foot(recipient) or not _active_member(row.recipient) or recipient.position.distance_to(stop.position) > LOCAL_RADIUS + EPS or handler.position.distance_to(recipient.position) > HANDOFF_RADIUS + EPS:
		_interrupt_row(row,"Handoff interrupted; carried goods remain at their actual holder.")
		return
	if recipient.contents_mass_kg + float(carried.unit_mass_kg)*row.quantity > 25.0 + EPS:
		_interrupt_row(row,"Recipient lacks capacity; goods remain with handler.")
		return
	var issued: Dictionary = rear.ledger.transfer_stock(row.carried_stock,row.quantity,row.recipient)
	if not issued.ok:
		_interrupt_row(row,issued.message)
		return
	row.issued_stock = issued.entity_id
	row.state = "Complete"
	row.deadline = INF
	row.blocker = ""


func _begin(row: Dictionary, stage: String, destination: Vector2, seconds: float) -> void:
	var handler: Dictionary = _rear().ledger.inspect_entity(row.handler)
	row.state = stage
	row.started = _rear().time
	row.deadline = _rear().time + seconds
	row.from = handler.position
	row.to = destination
	row.expected = handler.position
	row.blocker = ""


func _interrupt_row(row: Dictionary, reason: String) -> void:
	_release_claim(row)
	row.state = "Interrupted Carry" if not str(row.carried_stock).is_empty() else "Interrupted"
	row.deadline = INF
	row.blocker = reason


func _release_claim(row: Dictionary) -> void:
	var claim: Dictionary = _rear().ledger.inspect_claim(row.claim)
	if not claim.is_empty() and not claim.cancelled: _rear().ledger.release_claim(row.claim)


func _at_stop(stock: Dictionary, stop: Dictionary) -> bool:
	if stock.get("kind","") != "STOCK" or stop.get("kind","") != "PLACE": return false
	var holder: Dictionary = _rear().ledger.inspect_entity(stock.holder_id)
	# A leased carrier can have a different owner, but its controller must be
	# the purchaser's army before that army's handler may unload the goods.
	var lawful_holder: bool = stock.holder_id == stop.id or (holder.get("kind","") == "CARRIER" and holder.get("controller","") == stock.owner)
	return lawful_holder and stock.position.distance_to(stop.position) <= 2.0 + EPS


func _active_member(id: String) -> bool:
	var rear: RefCounted = _rear()
	var person: Dictionary = rear.ledger.inspect_entity(id)
	if person.get("kind","") != "PERSON" or person.owner != rear.PLAYER or person.assignment != "Formation Duty": return false
	for row in rear.military.squads.values():
		if row.state == "Active" and id in row.roster and person.duty_id == row.id: return true
	return false


func _on_foot(person: Dictionary) -> bool:
	if person.get("kind","") != "PERSON" or person.health <= 0 or person.pending_assignment != "None" or not person.crew_station.is_empty() or not person.carrying_stock_id.is_empty() or not person.carrying_weapon_id.is_empty(): return false
	return _rear().ledger.inspect_entity(person.holder_id).get("kind","") == "PLACE"


func _other_busy(id: String) -> bool:
	var rear: RefCounted = _rear()
	if rear.combat != null:
		for row in rear.combat.reloads.values():
			if row.operator == id: return true
		for row in rear.combat.care.values():
			if row.get("active",false) and row.medic == id: return true
	if rear.field_structures != null and rear.field_structures.engineer_committed(id): return true
	if rear.bridges != null and rear.bridges.engineer_committed(id): return true
	if rear.mines != null and rear.mines.engineer_committed(id): return true
	if rear.demolition != null and rear.demolition.engineer_committed(id): return true
	if rear.recovery != null and rear.recovery.workers.has(id): return true
	return false


func _leg(person: Dictionary, destination: Vector2) -> Dictionary:
	if person.position.distance_to(destination) <= EPS: return {"ok":true,"seconds":0.0}
	return _rear().combat.world.route({"position":person.position,"facing":(destination-person.position).angle(),
		"size":Vector2(0.6,0.6),"movement_class":0,"base":2.0,"rate":0.0,
		"gross_mass_kg":80.0+float(person.contents_mass_kg)},destination)


func snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	for row in jobs.values(): rows.append(row.duplicate(true))
	return {"rows":rows,"transport":transport.snapshot()}


func audit() -> Array[String]:
	var errors: Array[String] = transport.audit()
	for row in jobs.values():
		var carried: Dictionary = _rear().ledger.inspect_entity(row.carried_stock)
		if row.state in ["Walking Recipient","Drop"] and (carried.is_empty() or carried.holder_id != row.handler or carried.quantity != row.quantity):
			errors.append("Forward issue active carry does not match actual holder: " + row.id)
		if row.state == "Complete" and not carried.is_empty() and carried.quantity > 0:
			errors.append("Completed forward issue left a duplicated carried portion: " + row.id)
	return errors


func _rear() -> RefCounted:
	return _rear_ref.get_ref()


func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
