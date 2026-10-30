extends RefCounted
## One real military T01 load from HQ to a forward stop and back on the shared clock.
## The ledger owns the hull, fuel and every stock portion; this service owns tasks.

const Routes = preload("res://game/routes/route_planner.gd")
const EPS := 0.000001
const HANDLING_SECONDS := 2.0
const LOCAL_RADIUS := 20.0
const HQ := Vector2(1640.0,91.0)
const THREAT_RANGE := {"T03":250.0,"T04":450.0,"T05":700.0}
var hq_position: Vector2
var _rear_ref: WeakRef
var jobs: Dictionary = {}
var _sequence := 0


func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	hq_position = rear.ledger.inspect_entity("hq-berth").position
	if rear.ledger.inspect_entity("forward-transit").is_empty():
		rear.ledger.add_place("forward-transit","Military supply hull travelling on its declared route",Vector2.ZERO)


func request_delivery(hull_id: String, stock_id: String, quantity: int, stop_id: String,
		outbound_points: Array, return_points: Array, loader_id: String, unloader_id: String) -> Dictionary:
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	var stock: Dictionary = rear.ledger.inspect_entity(stock_id)
	var stop: Dictionary = rear.ledger.inspect_entity(stop_id)
	if hull_committed(hull_id): return _fail("This physical hull already has an unfinished forward delivery.")
	var ready: String = _hq_hull_blocker(hull_id,hull)
	if not ready.is_empty(): return _fail(ready)
	if stock.get("kind","") != "STOCK" or stock.holder_id != "hq-stock" or stock.owner != rear.PLAYER or quantity <= 0 or stock.available < quantity:
		return _fail("Reserve a positive whole quantity of the player's unloaded, unpromised HQ stock.")
	if stop.get("kind","") != "PLACE" or stop_id in ["hq-stock","hq-berth","hq-reserve"] or stop.position.distance_to(hq_position) <= LOCAL_RADIUS:
		return _fail("A distinct physical forward destination outside the HQ issue area is required.")
	if not _loader_free(loader_id) or rear.forward_supply.person_committed(loader_id):
		return _fail("The named actual HQ logistics loader is unavailable.")
	if not _active_member(unloader_id): return _fail("Name one actual active formation member to unload at the destination.")
	if not _empty_freight_hull(hull_id): return _fail("This one-type mission requires an empty T01 freight hold before loading.")
	if float(quantity)*float(stock.unit_mass_kg) > float(hull.vehicle_spec.payload)+EPS:
		return _fail("The requested physical freight exceeds the T01 payload.")
	var route_error: String = _validate_points(outbound_points,hull.position,stop.position)
	if route_error.is_empty(): route_error = _validate_points(return_points,stop.position,hq_position)
	if not route_error.is_empty(): return _fail(route_error)
	var outward: Dictionary = Routes.plan(rear.ledger,hull_id,outbound_points,{"world":rear.combat.world})
	var home: Dictionary = Routes.plan(rear.ledger,hull_id,return_points,{"world":rear.combat.world})
	if not outward.ok: return _fail("No legal physical outward route: " + str(outward.reason))
	if not home.ok: return _fail("No legal physical HQ return: " + str(home.reason))
	var danger: String = _known_route_danger(hull_id,outward.parts)
	if danger.is_empty(): danger = _known_route_danger(hull_id,home.parts)
	if not danger.is_empty(): return _fail(danger)
	if float(hull.fuel)+EPS < 1.25*(float(outward.fuel)+float(home.fuel)):
		return _fail("Actual tank fuel cannot cover the outward leg, HQ return and 25 percent reserve.")
	_sequence += 1
	var id := "forward-delivery-%04d" % _sequence
	var claimed: Dictionary = rear.ledger.request_stock(id,stock_id,quantity,id,"Forward T01 delivery",rear.PLAYER)
	if not claimed.ok or rear.ledger.inspect_claim(id).reserved != quantity:
		if claimed.ok: rear.ledger.release_claim(id)
		return _fail("Exact HQ freight could not be committed without competing claims.")
	jobs[id] = {"id":id,"hull":hull_id,"stock":stock_id,"type":stock.design_type,"quantity":quantity,
		"stop":stop_id,"loader":loader_id,"unloader":unloader_id,"outbound_points":outbound_points.duplicate(),
		"return_points":return_points.duplicate(),"claim":id,"loaded":0,"unloaded":0,"loaded_items":[],
		"delivered_items":[],"state":"Loading","task":{},"route_plan":{},"route_points":[],
		"route_started":INF,"route_deadline":INF,"route_distance":0.0,"route_fuel":0.0,
		"route_expected":hull.position,"world_revision":rear.combat.world.revision,"paused_state":"","blocker":""}
	jobs[id].return_completed = false
	return {"ok":true,"id":id,"message":"Named HQ stock reserved; real staff loading, route travel and local unloading still remain."}


func interrupt_delivery(id: String) -> Dictionary:
	var row: Dictionary = jobs.get(id,{})
	if row.is_empty() or row.state not in ["Loading","Unloading","Outbound","Returning"]: return _fail("No active forward delivery to interrupt.")
	row.paused_state = row.state
	row.state = "Paused"
	if not row.task.is_empty(): row.task.remaining_seconds = maxf(0.0,float(row.task.deadline)-_rear().time); row.task.deadline = INF
	row.route_deadline = INF
	row.blocker = "Delivery paused; stock, carry and hull remain at their actual holders."
	return {"ok":true,"message":row.blocker}


func resume_delivery(id: String, outbound_points: Array = [], return_points: Array = []) -> Dictionary:
	var row: Dictionary = jobs.get(id,{})
	if row.is_empty() or row.state not in ["Paused","Blocked Route","Stranded","Fuel Empty"]: return _fail("Only a paused or stopped real delivery can resume.")
	var phase: String = row.paused_state if row.state == "Paused" else str(row.get("stopped_phase",""))
	if phase in ["Loading","Unloading"]:
		if not row.task.is_empty():
			var actor: String = row.loader if phase == "Loading" else row.unloader
			if not _task_actor_valid(row,actor): return _fail("The named handler must recover with the same physical carry before work resumes.")
			row.task.deadline = _rear().time+maxf(EPS,float(row.task.get("remaining_seconds",HANDLING_SECONDS)))
		row.state = phase
		row.blocker = ""
		return {"ok":true,"message":"Same physical handling task resumed."}
	if phase not in ["Outbound","Returning"]: return _fail("No resumable route or handling phase was recorded.")
	var hull: Dictionary = _rear().ledger.inspect_entity(row.hull)
	var movable: String = _movement_blocker(row.hull,hull)
	if not movable.is_empty(): return _fail(movable)
	var destination: Vector2 = _rear().ledger.inspect_entity(row.stop).position if phase == "Outbound" else hq_position
	var points: Array = outbound_points if phase == "Outbound" else return_points
	if points.is_empty(): return _fail("Resume requires explicit waypoints from the hull's current position.")
	var error: String = _validate_points(points,hull.position,destination)
	if not error.is_empty(): return _fail(error)
	if phase == "Outbound":
		if not return_points.is_empty(): row.return_points = return_points.duplicate()
		var home_error: String = _validate_points(row.return_points,_rear().ledger.inspect_entity(row.stop).position,hq_position)
		if not home_error.is_empty(): return _fail(home_error)
	row.state = phase
	if not _begin_route(row,points,phase): return _fail(row.blocker)
	return {"ok":true,"message":"Same hull resumes a newly validated physical route."}


func hull_committed(hull_id: String) -> bool:
	for row in jobs.values():
		if row.hull == hull_id and row.state not in ["Complete","Cancelled"]: return true
	return false


func person_committed(person_id: String) -> bool:
	for row in jobs.values():
		var task: Dictionary = row.task
		if task.is_empty() or row.state == "Complete": continue
		if task.get("actor","") == person_id and (row.state != "Paused" or not str(task.get("carry","")).is_empty()): return true
	return false


func next_boundary() -> float:
	var next := INF
	for row in jobs.values():
		if row.state in ["Outbound","Returning"]: next = minf(next,minf(float(row.route_deadline),_rear().time+1.0))
		if row.state in ["Loading","Unloading"] and not row.task.is_empty(): next = minf(next,float(row.task.deadline))
	return next


func advance_to(at: float) -> void:
	for row in jobs.values():
		if row.state in ["Outbound","Returning"]: _advance_route(row,at)
		elif row.state == "Unloading" and row.task.get("phase","") == "Unload Approach": _advance_unloader(row,at)


func settle() -> bool:
	var changed := false
	for row in jobs.values():
		if row.state == "Loading":
			if row.task.is_empty(): changed = _schedule_load(row) or changed
			elif float(row.task.deadline) <= _rear().time+EPS: _finish_load(row); changed = true
		elif row.state == "Unloading":
			if row.task.is_empty(): changed = _schedule_unload(row) or changed
			elif float(row.task.deadline) <= _rear().time+EPS: _finish_unload(row); changed = true
		elif row.state in ["Outbound","Returning"] and float(row.route_deadline) <= _rear().time+EPS:
			_finish_route(row)
			changed = true
	return changed


func _schedule_load(row: Dictionary) -> bool:
	if row.loaded >= row.quantity:
		_rear().ledger.release_claim(row.claim)
		_begin_route(row,row.outbound_points,"Outbound")
		return true
	if not _loader_free(row.loader) or _rear().forward_supply.person_committed(row.loader):
		row.blocker = "Waiting for the named actual HQ loader."
		return false
	var stock: Dictionary = _rear().ledger.inspect_entity(row.stock)
	var loader: Dictionary = _rear().ledger.inspect_entity(row.loader)
	var portion: int = mini(row.quantity-row.loaded,int(floorf((25.0-float(loader.contents_mass_kg))/float(stock.unit_mass_kg))))
	if portion <= 0:
		row.blocker = "HQ loader cannot carry one whole unit within 25 kg."
		return false
	row.task = {"phase":"Load Pickup","actor":row.loader,"source":row.stock,"portion":portion,"carry":"","deadline":_rear().time+HANDLING_SECONDS}
	row.blocker = "Named HQ loader handling actual reserved freight."
	return true


func _finish_load(row: Dictionary) -> void:
	var task: Dictionary = row.task
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	if hull.holder_id != "hq-berth" or not hull.position.is_equal_approx(hq_position): _pause_task(row,"Hull moved during physical HQ loading."); return
	if task.phase == "Load Pickup":
		if not _loader_free(row.loader): _pause_task(row,"Named HQ loader became unavailable before pickup."); return
		var stock: Dictionary = rear.ledger.inspect_entity(row.stock)
		if stock.holder_id != "hq-stock": _pause_task(row,"Reserved HQ source moved before pickup."); return
		var picked: Dictionary = rear.ledger.begin_carry(row.loader,row.stock,task.portion,row.claim)
		if not picked.ok: _pause_task(row,picked.message); return
		task.carry = picked.entity_id
		task.phase = "Load Drop"
		task.deadline = rear.time+HANDLING_SECONDS
		return
	if not _task_actor_valid(row,row.loader): _pause_task(row,"HQ loader interrupted while holding real freight."); return
	var loaded: Dictionary = rear.ledger.finish_carry_to_carrier(row.loader,row.hull)
	if not loaded.ok: _pause_task(row,loaded.message); return
	row.loaded_items.append(loaded.entity_id)
	row.loaded += int(task.portion)
	row.task = {}
	row.blocker = ""


func _schedule_unload(row: Dictionary) -> bool:
	if row.unloaded >= row.quantity:
		_begin_route(row,row.return_points,"Returning")
		return true
	var hull: Dictionary = _rear().ledger.inspect_entity(row.hull)
	var stop: Dictionary = _rear().ledger.inspect_entity(row.stop)
	if hull.holder_id != row.stop or not hull.position.is_equal_approx(stop.position): row.blocker = "Same loaded hull must be stopped at the declared destination."; return false
	var handler: Dictionary = _rear().ledger.inspect_entity(row.unloader)
	if not _active_member(row.unloader) or not _on_foot(handler) or handler.position.distance_to(stop.position) > LOCAL_RADIUS+EPS or _rear().forward_supply.person_committed(row.unloader) or _other_work(row.unloader):
		row.blocker = "Waiting for the named active dismounted destination handler within 20 m."
		return false
	var source := ""
	for id in row.loaded_items:
		var item: Dictionary = _rear().ledger.inspect_entity(id)
		if item.holder_id == row.hull and item.available > 0: source = id; break
	if source.is_empty(): row.blocker = "The named loaded freight is no longer aboard this hull."; return false
	var stock: Dictionary = _rear().ledger.inspect_entity(source)
	var portion: int = mini(int(stock.available),int(floorf((25.0-float(handler.contents_mass_kg))/float(stock.unit_mass_kg))))
	if portion <= 0: row.blocker = "Destination handler cannot carry one whole unit."; return false
	var leg: Dictionary = _foot_leg(handler,stop.position)
	if not leg.ok: row.blocker = "No safe local foot path to the carrier: " + str(leg.reason); return false
	row.task = {"phase":"Unload Approach" if leg.seconds > EPS else "Unload Pickup","actor":row.unloader,"source":source,
		"portion":portion,"carry":"","started":_rear().time,"from":handler.position,"to":stop.position,
		"expected":handler.position,"deadline":_rear().time+(float(leg.seconds) if leg.seconds > EPS else HANDLING_SECONDS)}
	row.blocker = "Named destination handler collecting actual freight."
	return true


func _finish_unload(row: Dictionary) -> void:
	var task: Dictionary = row.task
	var rear: RefCounted = _rear()
	var handler: Dictionary = rear.ledger.inspect_entity(row.unloader)
	var stop: Dictionary = rear.ledger.inspect_entity(row.stop)
	if not _active_member(row.unloader) or not _on_foot(handler) or not handler.position.is_equal_approx(stop.position) or _other_work(row.unloader):
		_pause_task(row,"Destination handler moved or became unavailable; real freight stays at its holder.")
		return
	if task.phase == "Unload Approach":
		task.phase = "Unload Pickup"
		task.deadline = rear.time+HANDLING_SECONDS
		return
	if task.phase == "Unload Pickup":
		var source: Dictionary = rear.ledger.inspect_entity(task.source)
		if source.holder_id != row.hull or rear.ledger.inspect_entity(row.hull).holder_id != row.stop:
			_pause_task(row,"Carrier or named freight moved before local pickup.")
			return
		var picked: Dictionary = rear.ledger.transfer_stock(task.source,task.portion,row.unloader)
		if not picked.ok: _pause_task(row,picked.message); return
		task.carry = picked.entity_id
		task.phase = "Unload Drop"
		task.deadline = rear.time+HANDLING_SECONDS
		return
	var carried: Dictionary = rear.ledger.inspect_entity(task.carry)
	if carried.get("holder_id","") != row.unloader: _pause_task(row,"Physical unload carry changed holder before deposit."); return
	var dropped: Dictionary = rear.ledger.transfer_stock(task.carry,task.portion,row.stop)
	if not dropped.ok: _pause_task(row,dropped.message); return
	row.delivered_items.append(dropped.entity_id)
	row.unloaded += int(task.portion)
	row.task = {}
	row.blocker = ""


func _advance_unloader(row: Dictionary, at: float) -> void:
	var task: Dictionary = row.task
	var handler: Dictionary = _rear().ledger.inspect_entity(row.unloader)
	if not _active_member(row.unloader) or not _on_foot(handler) or _other_work(row.unloader) or not handler.position.is_equal_approx(task.expected):
		_pause_task(row,"Unloading helper's activity or position changed during approach.")
		return
	var fraction: float = clampf((at-float(task.started))/maxf(EPS,float(task.deadline)-float(task.started)),0.0,1.0)
	var position: Vector2 = task.from.lerp(task.to,fraction)
	var moved: Dictionary = _rear().ledger.move_entity(row.unloader,row.stop,position)
	if moved.ok: task.expected = position
	else: _pause_task(row,moved.message)


func _begin_route(row: Dictionary, points: Array, phase: String) -> bool:
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	var destination: Vector2 = rear.ledger.inspect_entity(row.stop).position if phase == "Outbound" else hq_position
	var error: String = _validate_points(points,hull.position,destination)
	if error.is_empty(): error = _movement_blocker(row.hull,hull)
	if not error.is_empty(): _block_route(row,phase,error); return false
	var plan: Dictionary = Routes.plan(rear.ledger,row.hull,points,{"world":rear.combat.world})
	if not plan.ok: _block_route(row,phase,"Route blocked: " + str(plan.reason)); return false
	var danger: String = _known_route_danger(row.hull,plan.parts)
	if not danger.is_empty(): _block_route(row,phase,danger); return false
	var required: float = float(plan.fuel)
	if phase == "Outbound":
		var home: Dictionary = Routes.plan(rear.ledger,row.hull,row.return_points,{"world":rear.combat.world})
		if not home.ok: _block_route(row,phase,"No legal return to HQ: " + str(home.reason)); return false
		danger = _known_route_danger(row.hull,home.parts)
		if not danger.is_empty(): _block_route(row,phase,danger); return false
		required += float(home.fuel)
	if float(hull.fuel)+EPS < required*1.25:
		_block_route(row,phase,"Insufficient actual tank fuel for destination, HQ return and 25 percent reserve.")
		return false
	row.state = phase
	row.route_plan = plan
	row.route_points = points.duplicate()
	row.route_started = rear.time
	row.route_deadline = rear.time+float(plan.seconds)
	row.route_distance = 0.0
	row.route_fuel = 0.0
	row.route_expected = rear.ledger.inspect_entity(row.hull).position
	row.world_revision = rear.combat.world.revision
	row.stopped_phase = ""
	row.blocker = ""
	return true


func _advance_route(row: Dictionary, at: float) -> void:
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	var phase: String = row.state
	var blocker: String = _movement_blocker(row.hull,hull)
	if not hull.position.is_equal_approx(row.route_expected): blocker = "Hull moved outside its owned supply route."
	if rear.combat.world.revision != row.world_revision: blocker = "Terrain or crossing changed; revalidate the remaining route."
	if blocker.is_empty() and rear.ledger.route_hazard.is_valid():
		blocker = str(rear.ledger.route_hazard.call(hull.owner,row.route_points))
	if blocker.is_empty(): blocker = _known_route_danger(row.hull,_remaining_parts(row))
	if not blocker.is_empty(): _block_route(row,phase,blocker); return
	var progress: Dictionary = _route_progress(row.route_plan,maxf(0.0,at-float(row.route_started)))
	var fuel_delta: float = maxf(0.0,float(progress.fuel)-float(row.route_fuel))
	var distance_delta: float = maxf(0.0,float(progress.distance)-float(row.route_distance))
	if distance_delta <= EPS: return
	var fraction := 1.0
	if fuel_delta > float(hull.fuel)+EPS: fraction = minf(fraction,float(hull.fuel)/fuel_delta)
	if rear.mines != null: fraction = minf(fraction,float(rear.mines.movement_limit(row.hull,hull.position,progress.position)))
	var moved_to: Vector2 = hull.position.lerp(progress.position,fraction)
	var burned: Dictionary = rear.ledger.burn_vehicle_fuel(row.hull,fuel_delta*fraction)
	if not burned.ok: _block_route(row,phase,burned.message); return
	row.route_fuel += fuel_delta*fraction
	row.route_distance += distance_delta*fraction
	var moved: Dictionary = rear.ledger.move_entity(row.hull,"forward-transit",moved_to)
	if not moved.ok: _block_route(row,phase,moved.message); return
	row.route_expected = moved_to
	var actual: Dictionary = rear.ledger.inspect_entity(row.hull)
	if actual.health <= 0 or actual.get("damage_immobilized",false):
		_block_route(row,phase,"Hull destroyed or immobilized by actual route damage; same cargo remains aboard.","Stranded")
	elif fraction < 1.0-EPS:
		_block_route(row,phase,"Actual route contact or fuel shortage stopped the hull with its real cargo.","Fuel Empty" if hull.fuel <= fuel_delta+EPS else "Blocked Route")


func _finish_route(row: Dictionary) -> void:
	var rear: RefCounted = _rear()
	if row.route_distance+EPS < float(row.route_plan.distance):
		_block_route(row,row.state,"Route stopped short of its measured destination; replan from actual hull position.")
		return
	if row.state == "Outbound":
		var arrival: Dictionary = rear.ledger.move_entity(row.hull,row.stop,rear.ledger.inspect_entity(row.stop).position)
		if not arrival.ok: _block_route(row,"Outbound",arrival.message); return
		row.state = "Unloading"
		row.task = {}
		row.blocker = "Waiting for the named local handler to unload real freight."
	else:
		var home: Dictionary = rear.ledger.move_entity(row.hull,"hq-berth",hq_position)
		if not home.ok: _block_route(row,"Returning",home.message); return
		row.state = "Complete"
		row.return_completed = true
		row.blocker = ""
	row.route_deadline = INF
	row.route_expected = rear.ledger.inspect_entity(row.hull).position


func _route_progress(plan: Dictionary, elapsed: float) -> Dictionary:
	if elapsed >= float(plan.seconds)-EPS:
		return {"position":plan.parts[-1].to,"distance":plan.distance,"fuel":plan.fuel}
	var time_left: float = elapsed
	var total_distance := 0.0
	var total_fuel := 0.0
	var point: Vector2 = plan.parts[0].from
	for part in plan.parts:
		var fraction: float = clampf(time_left/maxf(EPS,float(part.seconds)),0.0,1.0)
		point = part.from.lerp(part.to,fraction)
		total_distance += float(part.distance)*fraction
		total_fuel += float(part.fuel)*fraction
		if fraction < 1.0-EPS: break
		time_left -= float(part.seconds)
	return {"position":point,"distance":total_distance,"fuel":total_fuel}


func _remaining_parts(row: Dictionary) -> Array:
	var result: Array = []
	var passed := 0.0
	for part in row.route_plan.parts:
		passed += float(part.distance)
		if passed+EPS >= float(row.route_distance): result.append(part)
	return result


func _block_route(row: Dictionary, phase: String, reason: String, state: String = "Blocked Route") -> void:
	row.state = state
	row.stopped_phase = phase
	row.route_deadline = INF
	row.blocker = reason


func _pause_task(row: Dictionary, reason: String) -> void:
	row.paused_state = row.state
	row.state = "Paused"
	row.task.remaining_seconds = HANDLING_SECONDS
	row.task.deadline = INF
	row.blocker = reason


func _hq_hull_blocker(id: String, hull: Dictionary) -> String:
	var rear: RefCounted = _rear()
	if hull.get("kind","") != "CARRIER" or hull.get("design_type","") != "T01" or hull.get("fleet_domain","") != "Military" or not rear.dispatch.military_hulls.has(id) or not rear.military.vehicles.has(id):
		return "Forward freight requires one admitted, attached actual military T01."
	if hull.holder_id != "hq-berth" or not hull.position.is_equal_approx(hq_position): return "Same T01 must stop at the actual HQ berth before loading."
	if rear.hq._target_busy(id): return "HQ has an unfinished physical issue or refuel job on this hull."
	if not str(rear.military.vehicles[id].get("passenger_squad","")).is_empty() or not hull.passengers.is_empty(): return "Military boarding occupies this hull; freight mission requires no passengers."
	return _movement_blocker(id,hull)


func _movement_blocker(id: String, hull: Dictionary) -> String:
	var rear: RefCounted = _rear()
	if hull.is_empty() or hull.get("health",0) <= 0 or hull.get("damage_immobilized",false) or float(hull.health) <= 0.25*float(hull.vehicle_spec.health): return "Damaged or immobilized hull cannot move or burn route fuel."
	if not str(hull.get("towing","")).is_empty() or not str(hull.get("towed_by","")).is_empty(): return "Towing and forward delivery cannot own the same hull."
	if rear.recovery != null and (rear.recovery.jobs.has(id) or rear.recovery.journeys.has(id) or rear.recovery.couplings.has(id)):
		return "Vehicle recovery already owns this hull."
	if not hull.get("passengers",[]).is_empty(): return "Passenger boarding owns this hull."
	if rear.military._living_crew_id(hull,"Driver").is_empty(): return "A living qualified driver must occupy the same T01 before movement."
	return ""


func _empty_freight_hull(id: String) -> bool:
	for item in _rear().ledger.entities_at(id,["STOCK","WEAPON","HEAVY_OBJECT"]):
		if item.quantity > 0: return false
	return true


func _loader_free(id: String) -> bool:
	return id in _rear().dispatch.free_hq_handlers(4,true)


func _active_member(id: String) -> bool:
	var person: Dictionary = _rear().ledger.inspect_entity(id)
	if person.get("kind","") != "PERSON" or person.owner != _rear().PLAYER or person.assignment != "Formation Duty" or person.health <= 0: return false
	for row in _rear().military.squads.values():
		if row.state == "Active" and id in row.roster and person.duty_id == row.id: return true
	return false


func _on_foot(person: Dictionary) -> bool:
	if person.get("kind","") != "PERSON" or person.health <= 0 or person.pending_assignment != "None" or not str(person.crew_station).is_empty(): return false
	return _rear().ledger.inspect_entity(person.holder_id).get("kind","") == "PLACE"


func _task_actor_valid(row: Dictionary, id: String) -> bool:
	var task: Dictionary = row.task
	var person: Dictionary = _rear().ledger.inspect_entity(id)
	if row.paused_state == "Loading" or row.state == "Loading":
		return person.get("kind","") == "PERSON" and person.health > 0 and person.assignment == "HQ Duty" and person.holder_id == "hq-berth" and (str(task.get("carry","")).is_empty() or person.carrying_stock_id == task.carry)
	return _active_member(id) and _on_foot(person) and (str(task.get("carry","")).is_empty() or _rear().ledger.inspect_entity(task.carry).get("holder_id","") == id)


func _other_work(id: String) -> bool:
	return _rear().forward_supply._other_busy(id)


func _foot_leg(person: Dictionary, destination: Vector2) -> Dictionary:
	if person.position.distance_to(destination) <= EPS: return {"ok":true,"seconds":0.0}
	return _rear().combat.world.route({"position":person.position,"facing":(destination-person.position).angle(),
		"size":Vector2(0.6,0.6),"movement_class":0,"base":2.0,"rate":0.0,
		"gross_mass_kg":80.0+float(person.contents_mass_kg)},destination)


func _validate_points(points: Array, start: Vector2, finish: Vector2) -> String:
	if points.size() < 2: return "Route needs at least two declared physical waypoints."
	for point in points:
		if typeof(point) != TYPE_VECTOR2 or not (point as Vector2).is_finite(): return "Route waypoints must be finite metre positions."
	if not (points[0] as Vector2).is_equal_approx(start) or not (points[-1] as Vector2).is_equal_approx(finish):
		return "Route waypoints must begin at this actual hull and end at the declared destination."
	return ""


func _known_route_danger(hull_id: String, parts: Array) -> String:
	var rear: RefCounted = _rear()
	var parent: String = str(rear.military.vehicles[hull_id].parent)
	var company: String = str(rear.military.platoons[parent].company) if rear.military.platoons.has(parent) else parent
	for target_id in rear.orders.contacts.get(company,{}):
		var contact: Dictionary = rear.orders.contact(company,target_id)
		if contact.is_empty() or float(contact.confidence) <= EPS or not contact.position.is_finite(): continue
		var radius: float = float(THREAT_RANGE.get(str(contact.get("class","")),300.0))+float(contact.uncertainty_m)
		for part in parts:
			var from: Vector2 = part.from
			var to: Vector2 = part.to
			var along: float = clampf((contact.position-from).dot(to-from)/maxf(EPS,from.distance_squared_to(to)),0.0,1.0)
			if contact.position.distance_to(from.lerp(to,along)) <= radius+EPS:
				return "Unsafe ordinary supply route near delivered hostile contact %s; no implicit combat convoy." % target_id
	return ""


func snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	for row in jobs.values(): rows.append(row.duplicate(true))
	return {"rows":rows}


func audit() -> Array[String]:
	var errors: Array[String] = []
	for row in jobs.values():
		if row.loaded < 0 or row.unloaded < 0 or row.unloaded > row.loaded or row.loaded > row.quantity:
			errors.append("Forward transport counters exceed their actual manifest: " + row.id)
		if row.state == "Complete" and (row.unloaded != row.quantity or not row.return_completed):
			errors.append("Completed forward delivery lacks full physical unload and HQ return: " + row.id)
	return errors


func _rear() -> RefCounted:
	return _rear_ref.get_ref()


func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
