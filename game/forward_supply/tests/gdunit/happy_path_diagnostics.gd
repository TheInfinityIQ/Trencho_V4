extends RefCounted
## Read-only evidence for the selected ordinary Supply delivery. No route parts,
## worker captures, world arrays, admission, pumping or physical mutation.
const MAX_JOBS := 8
const MAX_REQUESTS := 12
const MAX_SCAN := 64

static func capture(session: RefCounted, delivery_id: String) -> Dictionary:
	var rear: RefCounted = session.rear
	var transport: RefCounted = rear.military.troop_transport
	var delivery: Dictionary = rear.forward_supply.transport.jobs.get(delivery_id,{})
	var result := {"time":rear.time,"speed":session.speed,"owed_seconds":session.owed_simulation_seconds,
		"world_revision":rear.combat.world.revision,"delivery_id":delivery_id,"delivery_missing":delivery.is_empty()}
	if delivery.is_empty(): return result
	result.delivery = _fields(delivery,["id","state","blocker","hull","stop","loader","unloader","quantity","loaded","unloaded","route_started","route_deadline","route_distance"])
	result.delivery.task = _task(delivery.get("task",{}))
	result.delivery.hull_actual = _hull(rear,str(delivery.hull))
	var person_id: String = str(delivery.unloader)
	var person: Dictionary = rear.ledger.inspect_person_status(person_id)
	result.unloader = _fields(person,["id","owner","health","assignment","duty_id","holder_id","position","pending_assignment","crew_station","carrying_stock_id","carrying_weapon_id"])
	var stop: Dictionary = rear.ledger.inspect_entity(str(delivery.stop),{},false)
	result.stop = _fields(stop,["id","kind","position"])
	if not person.is_empty() and not stop.is_empty(): result.unloader.distance_to_stop = person.position.distance_to(stop.position)
	result.unloader.pinned = rear.combat.pinned.has(person_id)
	result.unloader.broken = rear.combat.broken.has(person_id)
	if not person.is_empty():
		result.commitments = {"troop":transport.person_committed(person_id),"tactical":rear.battlefield_operations != null and rear.battlefield_operations.person_committed(person_id),
			"forward_supply":rear.forward_supply.person_committed(person_id),"other_work":rear.forward_supply._other_busy(person_id)}
	var squad_id: String = str(person.get("duty_id",""))
	var squad: Dictionary = rear.military.squads.get(squad_id,{})
	result.squad = _fields(squad,["id","kind","state","owner","platoon","company","vehicle","leader"])
	result.squad.order = _order(rear,squad_id)
	result.squad.parent_order = _order(rear,str(squad.get("platoon","")))
	result.squad.company_order = _order(rear,str(squad.get("company","")))
	result.tactical_motion = {}
	var policy: RefCounted = null
	if rear.battlefield_operations != null:
		result.tactical_motion = _fields(rear.battlefield_operations.motions.get(person_id,{}),["purpose","place","destination","expected","started","deadline","revision","squad","intent"])
		policy = rear.battlefield_operations.policy
	var opening: Array[Dictionary] = []
	var hull_ids := {}
	var job_ids := {}
	var request_keys := {}
	if not str(squad.get("vehicle","")).is_empty(): hull_ids[str(squad.vehicle)] = true
	if policy != null:
		var scanned := 0
		for trip in policy.trips.values():
			if scanned >= MAX_SCAN or opening.size() >= MAX_JOBS: break
			scanned += 1
			if squad_id.is_empty() or squad_id not in trip.get("squads",[]): continue
			var summary: Dictionary = _fields(trip,["id","hull","board","dismount","request","job","started","admitted_at","dismounted","blocker"])
			if not str(trip.get("request","")).is_empty():
				request_keys[str(trip.request)] = true
				summary.admission = transport.planning_status(str(trip.request))
			opening.append(summary)
			hull_ids[str(trip.hull)] = true
			if not str(trip.get("job","")).is_empty(): job_ids[str(trip.job)] = true
	result.opening_trips = opening
	# Prefer the actual opening owner and its current departure before scanning
	# bounded history, so an old completed request cannot hide the live phase.
	var jobs: Array[Dictionary] = []
	var seen_jobs := {}
	for id in job_ids:
		if not transport.jobs.has(id) or jobs.size() >= MAX_JOBS: continue
		jobs.append(_job(rear,transport.jobs[id]))
		seen_jobs[id] = true
	var jobs_scanned := 0
	for id in transport.jobs:
		if jobs_scanned >= MAX_SCAN or jobs.size() >= MAX_JOBS: break
		jobs_scanned += 1
		var job: Dictionary = transport.jobs[id]
		if seen_jobs.has(id) or (person_id not in job.get("people",[]) and not hull_ids.has(str(job.get("hull","")))): continue
		jobs.append(_job(rear,job))
		seen_jobs[id] = true
		job_ids[id] = true
	result.troop_jobs = jobs
	var departures: Dictionary = transport.get("_departure_requests")
	var direct_departures: Array[Dictionary] = []
	for id in job_ids:
		var departure: Dictionary = departures.get(id,{})
		if not departure.is_empty() and direct_departures.size() < MAX_JOBS: direct_departures.append(departure)
	var planning: Dictionary = transport.get("_planning_requests")
	var requests: Array[Dictionary] = []
	var seen_requests := {}
	# Generic physical departures live in _departure_requests/FIFO rather than
	# the named admission map. Capture that current owner directly.
	for departure in direct_departures:
		requests.append(_request(rear,departure))
		seen_requests[str(departure.key)] = true
	for key in request_keys:
		if not planning.has(key) or seen_requests.has(key) or requests.size() >= MAX_REQUESTS: continue
		requests.append(_request(rear,planning[key]))
		seen_requests[key] = true
	var requests_scanned := 0
	for key in planning:
		if requests_scanned >= MAX_SCAN or requests.size() >= MAX_REQUESTS: break
		requests_scanned += 1
		var request: Dictionary = planning[key]
		if seen_requests.has(key) or (not job_ids.has(str(request.get("job",""))) and not hull_ids.has(str(request.get("hull","")))): continue
		requests.append(_request(rear,request))
		seen_requests[key] = true
	result.planning_requests = requests
	result.planning_generation = transport.get("_planning_generation")
	result.limits = {"max_jobs":MAX_JOBS,"max_requests":MAX_REQUESTS,"max_scan":MAX_SCAN,
		"total_jobs":transport.jobs.size(),"jobs_scanned":jobs_scanned,"job_history_truncated":jobs_scanned < transport.jobs.size(),
		"total_requests":planning.size(),"requests_scanned":requests_scanned,"request_history_truncated":requests_scanned < planning.size()}
	return result

static func _fields(row: Dictionary, keys: Array) -> Dictionary:
	var result := {}
	for key in keys:
		if row.has(key):
			var value: Variant = row[key]
			result[key] = str(value) if typeof(value) == TYPE_FLOAT and not is_finite(value) else value
	return result

static func _task(row: Dictionary) -> Dictionary:
	return _fields(row,["phase","person","actor","source","carry","portion","started","deadline","remaining_seconds","expected","from","to"])

static func _hull(rear: RefCounted, id: String) -> Dictionary:
	return _fields(rear.ledger.inspect_entity(id,{},false),["id","owner","holder_id","position","fuel","health","damage_immobilized"])

static func _order(rear: RefCounted, id: String) -> Dictionary:
	var intent: Dictionary = rear.orders.intents.get(id,{})
	var result: Dictionary = _fields(intent,["id","state","action","parent","issued_at","received_at","acknowledged_at","blocked_reason"])
	result.constraints = _fields(intent.get("constraints",{}),["destination","role","opening_key","objective","opening_version","relayed_from"])
	return result

static func _intent_checks(rear: RefCounted, intents: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for squad_id in intents:
		if result.size() >= MAX_JOBS: break
		var current: Dictionary = _order(rear,str(squad_id))
		result.append({"squad":squad_id,"saved_intent":intents[squad_id],"matches_current":intents[squad_id] == current.get("id",""),"current":current})
	return result

static func _job(rear: RefCounted, row: Dictionary) -> Dictionary:
	var result: Dictionary = _fields(row,["id","kind","hull","state","paused_state","stopped_phase","planning_phase","planning_state","board_place","dismount_place","boarded","dismounted","blocker","route_started","route_deadline","route_distance","world_revision","supply_mode"])
	result.manifest_count = row.get("people",[]).size()
	result.task = _task(row.get("task",{}))
	result.route = _fields(row.get("route_plan",{}),["distance","seconds","fuel"])
	result.hull_actual = _hull(rear,str(row.get("hull","")))
	result.intent_checks = _intent_checks(rear,row.get("intent_ids",{}))
	return result

static func _request(rear: RefCounted, row: Dictionary) -> Dictionary:
	var result: Dictionary = _fields(row,["key","kind","job","hull","state","stage","phase","message","revision","generation","admitted_at"])
	result.intent_checks = _intent_checks(rear,row.get("intents",{}))
	var work: RefCounted = row.get("work")
	if work != null:
		result.work = {"done":work.done,"invalidated":work.invalidated,"phase":work.get("_phase"),"waypoint_index":work.get("_index"),"last_step_units":work.last_step_units,
			"result":_fields(work.result,["ok","reason","unsupported"])}
		var child: RefCounted = work.get("_child")
		if child != null:
			result.work.terrain = {"done":child.done,"invalidated":child.invalidated,"phase":child.phase,"index":child.index,"last_step_units":child.last_step_units}
	return result
