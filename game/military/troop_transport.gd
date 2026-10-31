extends RefCounted
## Timed formation transport and empty reposition of attached military hulls.
const Routes = preload("res://game/routes/route_planner.gd")
const EPS := 0.000001
const HANDLING_SECONDS := 2.0
const LOCAL_RADIUS := 20.0
const THREAT_RANGE := {"T03":250.0,"T04":450.0,"T05":700.0}
var _rear_ref: WeakRef
var _organization_ref: WeakRef
var jobs: Dictionary = {}
var _sequence := 0


func _init(rear: RefCounted, organization: RefCounted) -> void:
	_rear_ref = weakref(rear)
	_organization_ref = weakref(organization)
	if rear.ledger.inspect_entity("troop-transit").is_empty():
		rear.ledger.add_place("troop-transit","Military personnel hull on its declared route",Vector2.ZERO)


func request_trip(hull_id: String, squad_ids: Array, board_place_id: String, dismount_place_id: String,
		outbound_points: Array, return_points: Array) -> Dictionary:
	var rear: RefCounted = _rear()
	var organization: RefCounted = _organization()
	var ledger: RefCounted = rear.ledger
	var hull: Dictionary = ledger.inspect_entity(hull_id)
	var board_place: Dictionary = ledger.inspect_entity(board_place_id)
	var dismount_place: Dictionary = ledger.inspect_entity(dismount_place_id)
	if hull_committed(hull_id) or (rear.forward_supply != null and rear.forward_supply.hull_committed(hull_id)):
		return _fail("Another physical transport activity already owns this hull.")
	if hull.get("kind","") != "CARRIER" or hull.get("design_type","") != "T02" or hull.get("fleet_domain","") != "Military" or not organization.vehicles.has(hull_id):
		return _fail("Choose one actually attached military T02.")
	if board_place.get("kind","") != "PLACE" or dismount_place.get("kind","") != "PLACE" or board_place_id == dismount_place_id or hull.holder_id != board_place_id or not hull.position.is_equal_approx(board_place.position):
		return _fail("Same stopped T02 must meet its passengers at a declared physical origin distinct from the dismount point.")
	if squad_ids.is_empty() or squad_ids.size() > 2 or not hull.passengers.is_empty() or not str(organization.vehicles[hull_id].passenger_squad).is_empty():
		return _fail("One T02 carries one or two separate unboarded squads, with no prior passenger commitment.")
	var checked: Dictionary = _manifest_people(hull,squad_ids,board_place_id)
	if not checked.ok: return checked
	var blocker: String = _movement_blocker(hull_id,hull)
	if not blocker.is_empty(): return _fail(blocker)
	var error: String = _validate_points(outbound_points,hull.position,dismount_place.position)
	if error.is_empty(): error = _validate_points(return_points,dismount_place.position,board_place.position)
	if not error.is_empty(): return _fail(error)
	var outward: Dictionary = Routes.plan(ledger,hull_id,outbound_points,{"world":rear.combat.world})
	var home: Dictionary = Routes.plan(ledger,hull_id,return_points,{"world":rear.combat.world})
	if not outward.ok: return _fail("No legal outward route: " + str(outward.reason))
	if not home.ok: return _fail("No legal return route: " + str(home.reason))
	blocker = _known_route_danger(hull_id,outward.parts)
	if blocker.is_empty(): blocker = _known_route_danger(hull_id,home.parts)
	if not blocker.is_empty(): return _fail(blocker)
	if float(hull.fuel)+EPS < 1.25*(float(outward.fuel)+float(home.fuel)):
		return _fail("Actual T02 tank cannot cover the full trip and 25 percent reserve.")
	var reserved: Dictionary = organization._reserve_transport_manifest(hull_id,squad_ids)
	if not reserved.ok: return reserved
	_sequence += 1
	var id := "troop-trip-%04d" % _sequence
	jobs[id] = {"id":id,"kind":"Troop Trip","hull":hull_id,"owner":hull.owner,"squads":squad_ids.duplicate(),"people":checked.people,
		"board_place":board_place_id,"dismount_place":dismount_place_id,"outbound_points":outbound_points.duplicate(),
		"return_points":return_points.duplicate(),"boarded":0,"dismounted":0,"state":"Boarding","task":{},
		"route_plan":{},"route_points":[],"route_started":INF,"route_deadline":INF,"route_distance":0.0,
		"route_fuel":0.0,"route_expected":hull.position,"world_revision":rear.combat.world.revision,
		"paused_state":"","stopped_phase":"","blocker":"","return_completed":false}
	return {"ok":true,"id":id,"message":"The same T02 and its actual squad members are committed to timed boarding and travel."}


func request_reposition(hull_id: String, destination_place_id: String, route_points: Array, fallback_points: Array) -> Dictionary:
	var rear: RefCounted = _rear()
	var organization: RefCounted = _organization()
	var ledger: RefCounted = rear.ledger
	var hull: Dictionary = ledger.inspect_entity(hull_id)
	var destination: Dictionary = ledger.inspect_entity(destination_place_id)
	if hull_committed(hull_id) or (rear.forward_supply != null and rear.forward_supply.hull_committed(hull_id)):
		return _fail("Another physical activity already owns this hull.")
	if hull.get("kind","") != "CARRIER" or hull.get("fleet_domain","") != "Military" or not organization.vehicles.has(hull_id):
		return _fail("Choose an actually attached military vehicle.")
	var origin_id: String = str(hull.holder_id)
	var origin: Dictionary = ledger.inspect_entity(origin_id)
	if origin.get("kind","") != "PLACE" or destination.get("kind","") != "PLACE" or origin_id == destination_place_id or not hull.position.is_equal_approx(origin.position):
		return _fail("An empty stopped military vehicle needs distinct declared physical origin and destination places.")
	if not hull.passengers.is_empty() or not str(organization.vehicles[hull_id].passenger_squad).is_empty():
		return _fail("Empty reposition cannot move a passenger manifest.")
	var error: String = _movement_blocker(hull_id,hull)
	if error.is_empty(): error = _validate_points(route_points,hull.position,destination.position)
	if error.is_empty(): error = _validate_points(fallback_points,destination.position,origin.position)
	if not error.is_empty(): return _fail(error)
	var outward: Dictionary = Routes.plan(ledger,hull_id,route_points,{"world":rear.combat.world})
	var fallback: Dictionary = Routes.plan(ledger,hull_id,fallback_points,{"world":rear.combat.world})
	if not outward.ok: return _fail("No legal reposition route: " + str(outward.reason))
	if not fallback.ok: return _fail("No legal fallback route: " + str(fallback.reason))
	error = _known_route_danger(hull_id,outward.parts)
	if error.is_empty(): error = _known_route_danger(hull_id,fallback.parts)
	if not error.is_empty(): return _fail(error)
	if float(hull.fuel)+EPS < 1.25*(float(outward.fuel)+float(fallback.fuel)):
		return _fail("Actual tank cannot cover reposition, validated fallback and 25 percent reserve.")
	_sequence += 1
	var id := "military-reposition-%04d" % _sequence
	jobs[id] = {"id":id,"kind":"Reposition","hull":hull_id,"owner":hull.owner,"squads":[],"people":[],
		"board_place":origin_id,"dismount_place":destination_place_id,"outbound_points":route_points.duplicate(),
		"return_points":fallback_points.duplicate(),"boarded":0,"dismounted":0,"state":"Outbound","task":{},
		"route_plan":outward,"route_points":route_points.duplicate(),"route_started":rear.time,
		"route_deadline":rear.time+float(outward.seconds),"route_distance":0.0,"route_fuel":0.0,
		"route_expected":hull.position,"world_revision":rear.combat.world.revision,
		"paused_state":"","stopped_phase":"","blocker":"","return_completed":false}
	return {"ok":true,"id":id,"message":"Empty military vehicle is moving toward its declared destination with fallback fuel retained."}


func interrupt_trip(id: String) -> Dictionary:
	var row: Dictionary = jobs.get(id,{})
	if row.is_empty() or row.state not in ["Boarding","Outbound","Dismounting","Returning"]:
		return _fail("Only an active physical troop trip can be interrupted.")
	row.paused_state = row.state
	row.state = "Paused"
	if not row.task.is_empty():
		row.task.remaining_seconds = maxf(0.0,float(row.task.deadline)-_rear().time)
		row.task.deadline = INF
	row.route_deadline = INF
	row.blocker = "Movement paused. Passengers remain at their actual holders."
	return {"ok":true,"message":row.blocker}


func resume_trip(id: String, route_points: Array = []) -> Dictionary:
	var row: Dictionary = jobs.get(id,{})
	if row.is_empty() or row.state not in ["Paused","Blocked Route","Stranded"]:
		return _fail("Only a paused or physically blocked trip can resume.")
	var phase: String = row.paused_state if row.state == "Paused" else row.stopped_phase
	if phase in ["Boarding","Dismounting"]:
		if not row.task.is_empty():
			var remaining: float = maxf(EPS,float(row.task.get("remaining_seconds",HANDLING_SECONDS)))
			if phase == "Boarding" and row.task.get("phase","") == "Approach":
				var person: Dictionary = _rear().ledger.inspect_entity(row.task.person)
				if person.holder_id != row.board_place or person.health <= 0 or not person.position.is_equal_approx(row.task.expected):
					return _fail("Same living passenger must remain at the physical approach position.")
				row.task.from = person.position
				row.task.started = _rear().time
				row.task.expected = person.position
			row.task.deadline = _rear().time+remaining
		row.state = phase
		row.blocker = ""
		return {"ok":true,"message":"Same physical passenger handling resumed."}
	if phase not in ["Outbound","Returning"]: return _fail("No route phase is available to resume.")
	var hull: Dictionary = _rear().ledger.inspect_entity(row.hull)
	var error: String = _movement_blocker(row.hull,hull)
	if not error.is_empty(): return _fail(error)
	var destination: Vector2 = _rear().ledger.inspect_entity(row.dismount_place).position if phase == "Outbound" else _rear().ledger.inspect_entity(row.board_place).position
	error = _validate_points(route_points,hull.position,destination)
	if not error.is_empty(): return _fail(error)
	if not _begin_route(row,route_points,phase): return _fail(row.blocker)
	return {"ok":true,"message":"Same military hull resumes on a newly validated route from its actual position."}


func hull_committed(hull_id: String) -> bool:
	for row in jobs.values():
		if row.hull == hull_id and row.state != "Complete": return true
	return false


func person_committed(person_id: String) -> bool:
	for row in jobs.values():
		if row.state in ["Boarding","Dismounting","Paused"] and person_id in row.people: return true
	return false


func next_boundary() -> float:
	var next := INF
	for row in jobs.values():
		if row.state in ["Boarding","Dismounting"] and not row.task.is_empty(): next = minf(next,float(row.task.deadline))
		if row.state in ["Outbound","Returning"]: next = minf(next,minf(float(row.route_deadline),_rear().time+1.0))
	return next


func advance_to(at: float) -> void:
	for row in jobs.values():
		if row.state in ["Outbound","Returning"]: _advance_route(row,at)
		elif row.state == "Boarding" and row.task.get("phase","") == "Approach": _advance_boarder(row,at)


func settle() -> bool:
	var changed := false
	for row in jobs.values():
		match row.state:
			"Boarding":
				if row.task.is_empty(): changed = _schedule_board(row) or changed
				elif float(row.task.deadline) <= _rear().time+EPS: _finish_board(row); changed = true
			"Dismounting":
				if row.task.is_empty(): changed = _schedule_dismount(row) or changed
				elif float(row.task.deadline) <= _rear().time+EPS: _finish_dismount(row); changed = true
			"Outbound","Returning":
				if float(row.route_deadline) <= _rear().time+EPS: _finish_route(row); changed = true
	return changed


func _manifest_people(hull: Dictionary, squad_ids: Array, board_place_id: String) -> Dictionary:
	var organization: RefCounted = _organization()
	var rear: RefCounted = _rear()
	var people: Array[String] = []
	var passenger_mass := 0.0
	var distinct := {}
	for squad_id in squad_ids:
		if distinct.has(squad_id): return _fail("A squad may occupy this T02 only once.")
		distinct[squad_id] = true
		var squad: Dictionary = organization.squads.get(squad_id,{})
		if squad.is_empty() or squad.get("owner",rear.PLAYER) != hull.owner or squad.state != "Active" or not squad.vehicle.is_empty() or squad.roster.is_empty() or squad.roster.size() > 8:
			return _fail("Every selected squad must be active, separate, unboarded and owned by the T02 army.")
		for id in squad.roster:
			var person: Dictionary = rear.ledger.inspect_entity(id)
			if rear.battlefield_operations != null and rear.battlefield_operations.person_committed(id): return _fail("Passenger must stop tactical foot movement before boarding.")
			if person.get("kind","") != "PERSON" or person.owner != hull.owner or person.assignment != "Formation Duty" or person.duty_id != squad_id or person.health <= 0 or person.holder_id != board_place_id or person.position.distance_to(hull.position) > LOCAL_RADIUS+EPS or person.pending_assignment != "None" or not str(person.crew_station).is_empty() or (rear.forward_supply != null and rear.forward_supply.person_committed(id)):
				return _fail("Every real, living squad passenger must be free within 20 m of this stopped T02.")
			if not _foot_leg(person,hull.position).ok: return _fail("A selected passenger lacks a safe physical approach to the T02.")
			people.append(id)
			passenger_mass += float(person.unit_mass_kg)+float(person.contents_mass_kg)
	if people.size() > int(hull.vehicle_spec.passenger_seats): return _fail("Separate crew stations cannot increase the T02's 16 passenger seats.")
	if float(hull.contents_mass_kg)+passenger_mass > float(hull.vehicle_spec.payload)+EPS:
		return _fail("Actual passengers and their gear exceed the T02 payload mass.")
	return {"ok":true,"people":people}


func _schedule_board(row: Dictionary) -> bool:
	if row.boarded >= row.people.size():
		_begin_route(row,row.outbound_points,"Outbound")
		return true
	var hull: Dictionary = _rear().ledger.inspect_entity(row.hull)
	var person: Dictionary = _rear().ledger.inspect_entity(row.people[row.boarded])
	if hull.holder_id != row.board_place or person.holder_id != row.board_place or person.position.distance_to(hull.position) > LOCAL_RADIUS+EPS or person.health <= 0:
		_pause_handling(row,"Next named passenger or T02 moved before boarding.")
		return true
	var leg: Dictionary = _foot_leg(person,hull.position)
	if not leg.ok: _pause_handling(row,"No safe local approach to stopped T02: " + str(leg.reason)); return true
	var walking: bool = float(leg.seconds) > EPS
	row.task = {"person":person.id,"phase":"Approach" if walking else "Board","started":_rear().time,
		"from":person.position,"to":hull.position,"expected":person.position,
		"deadline":_rear().time+(float(leg.seconds) if walking else HANDLING_SECONDS)}
	row.blocker = "Approaching and boarding actual passenger %d/%d." % [row.boarded+1,row.people.size()]
	return true


func _finish_board(row: Dictionary) -> void:
	var person_id: String = row.task.person
	var hull: Dictionary = _rear().ledger.inspect_entity(row.hull)
	var person: Dictionary = _rear().ledger.inspect_entity(person_id)
	if hull.holder_id != row.board_place or person.holder_id != row.board_place or person.health <= 0 or not person.position.is_equal_approx(hull.position):
		_pause_handling(row,"Passenger or T02 moved during timed boarding.")
		return
	if row.task.phase == "Approach":
		row.task.phase = "Board"
		row.task.deadline = _rear().time+HANDLING_SECONDS
		return
	var boarded: Dictionary = _rear().ledger.board_formation_passenger(person_id,row.hull)
	if not boarded.ok: _pause_handling(row,boarded.message); return
	row.boarded += 1
	row.task = {}
	row.blocker = ""


func _advance_boarder(row: Dictionary, at: float) -> void:
	var task: Dictionary = row.task
	var person: Dictionary = _rear().ledger.inspect_entity(task.person)
	if person.holder_id != row.board_place or person.health <= 0 or not person.position.is_equal_approx(task.expected):
		_pause_handling(row,"Passenger changed position or activity during boarding approach.")
		return
	var fraction: float = clampf((at-float(task.started))/maxf(EPS,float(task.deadline)-float(task.started)),0.0,1.0)
	var position: Vector2 = task.from.lerp(task.to,fraction)
	var moved: Dictionary = _rear().ledger.move_entity(task.person,row.board_place,position)
	if moved.ok: task.expected = _rear().ledger.inspect_entity(task.person).position
	else: _pause_handling(row,moved.message)


func _foot_leg(person: Dictionary, destination: Vector2) -> Dictionary:
	if person.position.distance_to(destination) <= EPS: return {"ok":true,"seconds":0.0}
	return _rear().combat.world.route({"position":person.position,"facing":(destination-person.position).angle(),
		"size":Vector2(0.6,0.6),"movement_class":0,"base":2.0,"rate":0.0,
		"gross_mass_kg":float(person.unit_mass_kg)+float(person.contents_mass_kg)},destination)


func _schedule_dismount(row: Dictionary) -> bool:
	if row.dismounted >= row.people.size():
		for squad_id in row.squads: _organization()._release_transport_squad(row.hull,squad_id)
		_begin_route(row,row.return_points,"Returning")
		return true
	var hull: Dictionary = _rear().ledger.inspect_entity(row.hull)
	var person: Dictionary = _rear().ledger.inspect_entity(row.people[row.dismounted])
	if hull.holder_id != row.dismount_place or person.holder_id != row.hull or person.assignment != "Formation Duty":
		_pause_handling(row,"Same T02 and living rostered passenger must stop at the declared dismount place.")
		return true
	row.task = {"person":person.id,"deadline":_rear().time+HANDLING_SECONDS}
	row.blocker = "Dismounting actual passenger %d/%d." % [row.dismounted+1,row.people.size()]
	return true


func _finish_dismount(row: Dictionary) -> void:
	var person_id: String = row.task.person
	var hull: Dictionary = _rear().ledger.inspect_entity(row.hull)
	if hull.holder_id != row.dismount_place or _rear().ledger.inspect_entity(person_id).holder_id != row.hull:
		_pause_handling(row,"Passenger or T02 moved during timed dismount.")
		return
	var exited: Dictionary = _rear().ledger.exit_formation_passenger(person_id,row.hull,row.dismount_place)
	if not exited.ok: _pause_handling(row,exited.message); return
	row.dismounted += 1
	row.task = {}
	row.blocker = ""


func _begin_route(row: Dictionary, points: Array, phase: String) -> bool:
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	var destination: Vector2 = rear.ledger.inspect_entity(row.dismount_place).position if phase == "Outbound" else rear.ledger.inspect_entity(row.board_place).position
	var error: String = _movement_blocker(row.hull,hull)
	if error.is_empty(): error = _validate_points(points,hull.position,destination)
	if not error.is_empty(): _block_route(row,phase,error); return false
	var plan: Dictionary = Routes.plan(rear.ledger,row.hull,points,{"world":rear.combat.world})
	if not plan.ok: _block_route(row,phase,str(plan.reason)); return false
	var danger: String = _known_route_danger(row.hull,plan.parts)
	if not danger.is_empty(): _block_route(row,phase,danger); return false
	var required: float = float(plan.fuel)
	if phase == "Outbound":
		var home: Dictionary = Routes.plan(rear.ledger,row.hull,row.return_points,{"world":rear.combat.world})
		if not home.ok: _block_route(row,phase,"HQ return became illegal: " + str(home.reason)); return false
		required += float(home.fuel)
	if float(hull.fuel)+EPS < required*1.25:
		_block_route(row,phase,"Actual tank lacks travel fuel plus 25 percent reserve.")
		return false
	row.state = phase
	row.route_plan = plan
	row.route_points = points.duplicate()
	row.route_started = rear.time
	row.route_deadline = rear.time+float(plan.seconds)
	row.route_distance = 0.0
	row.route_fuel = 0.0
	row.route_expected = hull.position
	row.world_revision = rear.combat.world.revision
	row.stopped_phase = ""
	row.blocker = ""
	return true


func _advance_route(row: Dictionary, at: float) -> void:
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull,{},false)
	var phase: String = row.state
	var blocker: String = _movement_blocker(row.hull,hull)
	if not hull.position.is_equal_approx(row.route_expected): blocker = "Military hull moved outside its owned route."
	if rear.combat.world.revision != row.world_revision: blocker = "Terrain or crossing changed; revalidate the remaining route."
	if blocker.is_empty() and rear.ledger.route_hazard.is_valid(): blocker = str(rear.ledger.route_hazard.call(hull.owner,row.route_points))
	if blocker.is_empty(): blocker = _known_route_danger(row.hull,_remaining_parts(row))
	if not blocker.is_empty(): _block_route(row,phase,blocker); return
	var progress: Dictionary = _route_progress(row.route_plan,maxf(0.0,at-float(row.route_started)))
	var distance_delta: float = maxf(0.0,float(progress.distance)-float(row.route_distance))
	var fuel_delta: float = maxf(0.0,float(progress.fuel)-float(row.route_fuel))
	if distance_delta <= EPS: return
	var fraction := 1.0
	if fuel_delta > float(hull.fuel)+EPS: fraction = minf(fraction,float(hull.fuel)/fuel_delta)
	if rear.mines != null: fraction = minf(fraction,float(rear.mines.movement_limit(row.hull,hull.position,progress.position)))
	var point: Vector2 = hull.position.lerp(progress.position,fraction)
	var burned: Dictionary = rear.ledger.burn_vehicle_fuel(row.hull,fuel_delta*fraction)
	if not burned.ok: _block_route(row,phase,burned.message); return
	row.route_fuel += fuel_delta*fraction
	row.route_distance += distance_delta*fraction
	var moved: Dictionary = rear.ledger.move_entity(row.hull,"troop-transit",point)
	if not moved.ok: _block_route(row,phase,moved.message); return
	var actual: Dictionary = rear.ledger.inspect_entity(row.hull,{},false)
	row.route_expected = actual.position
	if actual.health <= 0 or actual.get("damage_immobilized",false):
		_block_route(row,phase,"Actual route damage immobilized this military hull with its real contents.","Stranded")
	elif fraction < 1.0-EPS:
		_block_route(row,phase,"Actual hazard or fuel shortage stopped the military hull with its real contents.")


func _finish_route(row: Dictionary) -> void:
	if row.route_distance+EPS < float(row.route_plan.distance):
		_block_route(row,row.state,"Route stopped short of the measured destination; replan from the actual hull.")
		return
	var rear: RefCounted = _rear()
	var arrival_place: String = row.dismount_place if row.state == "Outbound" else row.board_place
	var destination: Vector2 = rear.ledger.inspect_entity(arrival_place).position
	var moved: Dictionary = rear.ledger.move_entity(row.hull,arrival_place,destination)
	if not moved.ok: _block_route(row,row.state,moved.message); return
	if row.kind == "Reposition":
		row.state = "Complete"
		row.return_completed = true
		row.blocker = ""
	elif row.state == "Outbound":
		row.state = "Dismounting"
		row.blocker = "Same passengers must leave this stopped T02 one by one."
	else:
		row.state = "Complete"
		row.return_completed = true
		row.blocker = ""
	row.route_deadline = INF
	row.route_expected = rear.ledger.inspect_entity(row.hull).position


func _movement_blocker(hull_id: String, hull: Dictionary) -> String:
	var rear: RefCounted = _rear()
	if hull.is_empty() or hull.get("health",0) <= 0 or hull.get("damage_immobilized",false) or float(hull.health) <= 0.25*float(hull.vehicle_spec.health):
		return "Damaged or immobilized military hull cannot move or burn travel fuel."
	if not str(hull.get("towing","")).is_empty() or not str(hull.get("towed_by","")).is_empty(): return "Towing cannot share this military movement."
	if rear.recovery != null and (rear.recovery.jobs.has(hull_id) or rear.recovery.journeys.has(hull_id) or rear.recovery.couplings.has(hull_id)):
		return "Vehicle recovery already owns this hull."
	if _organization()._living_crew_id(hull,"Driver").is_empty(): return "Living qualified driver must occupy the same hull before movement."
	return ""


func _validate_points(points: Array, start: Vector2, finish: Vector2) -> String:
	if points.size() < 2: return "Route needs explicit origin and destination positions."
	for point in points:
		if typeof(point) != TYPE_VECTOR2 or not (point as Vector2).is_finite(): return "Waypoints must be finite metre positions."
	if not (points[0] as Vector2).is_equal_approx(start) or not (points[-1] as Vector2).is_equal_approx(finish):
		return "Route waypoints must meet the actual hull and declared destination."
	return ""


func _known_route_danger(hull_id: String, parts: Array) -> String:
	var rear: RefCounted = _rear()
	var parent: String = str(_organization().vehicles[hull_id].parent)
	var company: String = str(_organization().platoons[parent].company) if _organization().platoons.has(parent) else parent
	for target_id in rear.orders.contacts.get(company,{}):
		var contact: Dictionary = rear.orders.contact(company,target_id)
		if contact.is_empty() or float(contact.confidence) <= EPS or not contact.position.is_finite(): continue
		# Public objectives and unarmed transport hulls do not supply hostile
		# effective fire. Unknown people/armed contacts retain the conservative margin.
		if contact.get("class","") in ["Resource","Route Hub","Observation","T01","T02"]: continue
		var radius: float = float(THREAT_RANGE.get(str(contact.get("class","")),300.0))+float(contact.uncertainty_m)
		for part in parts:
			var from: Vector2 = part.from
			var to: Vector2 = part.to
			var along: float = clampf((contact.position-from).dot(to-from)/maxf(EPS,from.distance_squared_to(to)),0.0,1.0)
			if contact.position.distance_to(from.lerp(to,along)) <= radius+EPS:
				return "Observed hostile effective fire blocks an ordinary troop route; use a safe declared path."
	return ""


func _route_progress(plan: Dictionary, elapsed: float) -> Dictionary:
	if elapsed >= float(plan.seconds)-EPS: return {"position":plan.parts[-1].to,"distance":plan.distance,"fuel":plan.fuel}
	var left: float = elapsed
	var distance := 0.0
	var fuel := 0.0
	var position: Vector2 = plan.parts[0].from
	for part in plan.parts:
		var fraction: float = clampf(left/maxf(EPS,float(part.seconds)),0.0,1.0)
		position = part.from.lerp(part.to,fraction)
		distance += float(part.distance)*fraction
		fuel += float(part.fuel)*fraction
		if fraction < 1.0-EPS: break
		left -= float(part.seconds)
	return {"position":position,"distance":distance,"fuel":fuel}


func _remaining_parts(row: Dictionary) -> Array:
	var result: Array = []
	var distance := 0.0
	for part in row.route_plan.parts:
		distance += float(part.distance)
		if distance+EPS >= float(row.route_distance): result.append(part)
	return result


func _block_route(row: Dictionary, phase: String, reason: String, state: String = "Blocked Route") -> void:
	row.state = state
	row.stopped_phase = phase
	row.route_deadline = INF
	row.blocker = reason


func _pause_handling(row: Dictionary, reason: String) -> void:
	row.paused_state = row.state
	row.state = "Paused"
	if not row.task.is_empty():
		row.task.remaining_seconds = HANDLING_SECONDS
		row.task.deadline = INF
	row.blocker = reason


func snapshot(owner: String = "") -> Dictionary:
	var rows: Array[Dictionary] = []
	for row in jobs.values():
		if owner.is_empty() or row.owner == owner: rows.append(row.duplicate(true))
	return {"rows":rows}


func audit() -> Array[String]:
	var errors: Array[String] = []
	for row in jobs.values():
		if row.boarded < 0 or row.dismounted < 0 or row.dismounted > row.boarded or row.boarded > row.people.size():
			errors.append("Troop trip passenger counters exceed its actual roster: " + row.id)
		if row.state == "Complete" and (row.dismounted != row.people.size() or not row.return_completed):
			errors.append("Completed military movement lacks its exact destination or dismount: " + row.id)
	return errors


func _rear() -> RefCounted:
	return _rear_ref.get_ref()


func _organization() -> RefCounted:
	return _organization_ref.get_ref()


func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
