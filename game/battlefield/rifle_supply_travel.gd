extends RefCounted
## Request-local Rifle collection travel. Execution owns foot motions; transport
## owns every actual vehicle job, seat, fuel burn and physical passenger handoff.
## Capture, current activity/knowledge queries and native copies are indivisible.
## Whole-lane geometry is delegated only to bounded route continuations.
const Routes = preload("res://game/routes/route_planner.gd")
const HANDLING_SECONDS := 2.0
const LOCAL_RADIUS := 20.0
var planning_revision: int = 0
var _rear_ref: WeakRef
var _authorize: Callable
var _sequence := 0
var _journeys: Dictionary = {}
var _queue: Array[Dictionary] = []

func _init(rear: RefCounted, authorize_hull: Callable) -> void:
	_rear_ref = weakref(rear)
	_authorize = authorize_hull

func request_journey(squad_id: String, cycle_key: String, leg: String, destination_id: String, current_intent: String) -> Dictionary:
	if cycle_key.is_empty() or leg not in ["Collect","Return"]: return {"ok":false,"message":"A named collection or return journey is required."}
	var previous: Dictionary = _journeys.get(squad_id,{})
	if not previous.is_empty() and previous.cycle == cycle_key and previous.leg == leg and previous.destination == destination_id and previous.intent == current_intent:
		if previous.state == "Interrupted" and _command_error(previous).is_empty() and _rear().vehicle_departures_allowed:
			_sync_jobs(previous)
			if _has_physical_job(previous):
				previous.retask = true
				_set_state(previous,"AwaitingACK","Current parent must authorize resuming the retained physical lift.")
			else: _reset(previous)
		_continue(previous)
		return {"ok":true,"key":previous.key,"state":previous.state}
	var retained := {}
	if not previous.is_empty():
		_sync_jobs(previous)
		_cancel_pure(previous)
		for job_id in [previous.pickup_job,previous.trip_job]:
			var job: Dictionary = _transport().jobs.get(job_id,{})
			if not job.is_empty() and job.state != "Complete":
				retained = {"hull":previous.hull,"pickup_job":previous.pickup_job,"trip_job":previous.trip_job,
					"pickup":previous.pickup,"origin_marker":previous.origin_marker,"anchor":previous.anchor,"cohort":job.people.duplicate() if job.kind != "Reposition" else previous.cohort.duplicate()}
				_transport().interrupt_trip(job_id)
		_set_state(previous,"Interrupted","A new acknowledged journey superseded this proposal; physical custody remains with its transport owner.")
	_sequence += 1
	var row := {"key":"%s:%s:%s:%d" % [squad_id,cycle_key,leg,_sequence],"squad":squad_id,"cycle":cycle_key,"leg":leg,
		"destination":destination_id,"intent":current_intent,"parent":"","owner":"","state":"Planning","mode":"",
		"blocker":"Measuring safe foot and eligible T02 journeys.","eta":-1.0,"foot_eta":-1.0,"lift_eta":-1.0,
		"world":null,"revision":-1,"phase":"Capture","work":null,"cohort":[],"people":{},"goals":{},"walks":{},
		"foot_ok":true,"foot_reason":"","foot_index":0,"fleet":[],"fleet_index":0,"choices":[],"candidate":{},
		"hull":"","pickup_job":"","trip_job":"","pickup_key":"","trip_key":"","resume_pending":false,
		"pickup":"rifle-pickup-%d-%d" % [get_instance_id(),_sequence],"origin_marker":"rifle-origin-%d-%d" % [get_instance_id(),_sequence],
		"anchor":Vector2.ZERO,"goal":Vector2.ZERO,"authority":{},"selected":{},"notes":[],"retask":false,"attempt":0,"queued":false,"planning_error":false,"selection_started":false}
	_journeys[squad_id] = row
	planning_revision += 1
	if not retained.is_empty():
		for key in retained: row[key] = retained[key]
		row.mode = "Transport"
		row.retask = true
		var squad: Dictionary = _rear().military.squads.get(squad_id,{})
		row.parent = str(squad.get("platoon",""))
		row.owner = str(squad.get("owner",""))
		_set_state(row,"AwaitingACK","Retained physical lift needs the current parent's named reassessment.")
	else: _enqueue(row)
	return {"ok":true,"key":row.key,"state":row.state}

func journey_status(squad_id: String) -> Dictionary:
	var row: Dictionary = _journeys.get(squad_id,{})
	if row.is_empty(): return {}
	var arrived: bool = _arrived(row)
	var pickup_job: String = _observed_job(row,"pickup")
	var trip_job: String = _observed_job(row,"trip")
	return {"key":row.key,"cycle":row.cycle,"leg":row.leg,"state":"Arrived" if arrived else row.state,"mode":row.mode,
		"destination":row.destination,"arrival":arrived,"eta":0.0 if arrived else _remaining_eta(row),"foot_eta":row.foot_eta,"lift_eta":row.lift_eta,
		"hull":row.hull,"pickup":row.pickup,"pickup_position":row.anchor,"pickup_job":pickup_job,"trip_job":trip_job,"blocker":"" if arrived else row.blocker,"intent":row.intent}

func has_planning_work() -> bool:
	for row in _queue:
		if row.state == "Planning": return true
	return false

func pump_planning(_allow_commit: bool, max_units: int = 128, budget_usec: int = 4000) -> bool:
	# Pure selection only. Ready/ACK waits must allow logical order delivery and
	# the next normal Execution decision; they never freeze the shared clock.
	if max_units <= 0 or budget_usec <= 0: return false
	var deadline: int = Time.get_ticks_usec()+budget_usec
	var units := 0
	while not _queue.is_empty() and _queue[0].state != "Planning":
		if units >= max_units or Time.get_ticks_usec() >= deadline: return false
		_queue[0].queued = false
		_queue.pop_front()
		units += 1
	if _queue.is_empty(): return false
	var row: Dictionary = _queue[0]
	while row.state == "Planning" and units < max_units and Time.get_ticks_usec() < deadline:
		if row.phase != "Capture" and (row.world != _rear().combat.world or row.revision != row.world.revision): _reset(row)
		if row.work != null:
			if row.work.invalidated: _reset(row); return false
			if row.work.done:
				units += 1
				_finish_work(row)
				continue
			var left: int = deadline-Time.get_ticks_usec()
			if left <= 0: return false
			row.work.step(max_units-units,left)
			return false # Entire remaining allowance charged to the child.
		units += 1
		match row.phase:
			"Capture": _capture(row)
			"Foot": _begin_foot(row)
			"Candidates": _candidate(row)
			"Approach": _begin_approach(row)
			"Vehicle": _begin_vehicle(row)
			"Choose": _choose(row)
	return false

func walk_routes(squad_id: String) -> Dictionary:
	var row: Dictionary = _journeys.get(squad_id,{})
	if row.is_empty() or row.state != "Ready" or row.mode != "Foot": return {}
	if not _capture_current(row): _reset(row); return {}
	var result := {}
	for id in row.cohort:
		var plan: Dictionary = row.walks[id]
		if float(plan.distance) <= 1.0: continue
		var person: Dictionary = row.people[id]
		result[id] = {"plan":plan,"captured_position":person.position,"captured_mass":float(person.unit_mass_kg)+float(person.contents_mass_kg),
			"world_revision":row.revision,"world_id":row.world.get_instance_id(),"intent":row.intent,"destination":row.goals[id],"place":row.destination}
	_set_state(row,"Walking","")
	return result

func interrupt_journey(squad_id: String, cycle_key: String, reason: String = "Collection travel interrupted.") -> void:
	var row: Dictionary = _journeys.get(squad_id,{})
	if row.is_empty() or row.cycle != cycle_key: return
	_sync_jobs(row)
	_cancel_pure(row)
	for job_id in [row.pickup_job,row.trip_job]:
		var job: Dictionary = _transport().jobs.get(job_id,{})
		if not job.is_empty() and job.state != "Complete": _transport().interrupt_trip(job_id)
	row.work = null
	_set_state(row,"Interrupted",reason)

func invalidate_planning() -> void:
	for row in _journeys.values():
		_sync_jobs(row)
		if row.state == "Walking" and not _has_owned_walk(row) and not _arrived(row):
			_reset(row)
			continue
		if row.state in ["Planning","Ready","AwaitingACK","Blocked"] and not _has_physical_job(row):
			_reset(row)

func cancel_planning() -> void:
	for row in _journeys.values():
		_sync_jobs(row)
		_cancel_pure(row)
		row.work = null
		row.queued = false
		_set_state(row,"Interrupted","Old session's pure travel planning cancelled; physical owners retain their jobs.")
	_queue.clear()

func _capture(row: Dictionary) -> void:
	var error: String = _command_error(row)
	if not error.is_empty(): _set_state(row,"Blocked",error); return
	var rear: RefCounted = _rear()
	var squad: Dictionary = rear.military.squads[row.squad]
	row.parent = squad.platoon
	row.owner = squad.owner
	row.world = rear.combat.world
	row.revision = row.world.revision
	row.goal = rear.ledger.inspect_entity(row.destination,{},false).position
	row.cohort = rear.military._active_roster_members(squad)
	if row.cohort.is_empty(): _set_state(row,"Blocked","No actual eligible Rifle cohort is available for travel."); return
	for id in row.cohort:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if not _free(id): _set_state(row,"Blocked","An actual cohort member must finish its existing movement or handling before this journey."); return
		row.people[id] = person
		var index: int = squad.roster.find(id)
		row.goals[id] = row.goal+Vector2((index%4-1.5)*2,(floori(index/4.0)-0.5)*2)
	row.anchor = row.people[row.cohort[0]].position
	row.fleet = rear.military.vehicles.keys()
	row.phase = "Foot"
	row.foot_eta = 0.0

func _begin_foot(row: Dictionary) -> void:
	if row.foot_index >= row.cohort.size(): row.phase = "Candidates"; return
	var id: String = row.cohort[row.foot_index]
	var person: Dictionary = row.people[id]
	var destination: Vector2 = row.goals[id]
	if not _safe_foot(person,destination):
		row.foot_ok = false
		row.foot_reason = "Delivered hostile fire excludes the declared collection foot route."
		row.foot_index += 1
		return
	if person.position.distance_to(destination) <= 1.0:
		row.walks[id] = {"ok":true,"parts":[],"distance":0.0,"seconds":0.0,"fuel":0.0}
		row.foot_index += 1
		return
	row.work = _foot_work(person,destination)

func _candidate(row: Dictionary) -> void:
	if row.fleet_index >= row.fleet.size(): row.phase = "Choose"; return
	var hull_id: String = str(row.fleet[row.fleet_index])
	row.fleet_index += 1
	var rear: RefCounted = _rear()
	if rear.ledger.entity_design_type(hull_id) != "T02": return
	var facts: Dictionary = _transport().supply_cohort_facts(hull_id,row.squad)
	if not facts.get("ok",false): row.notes.append(str(facts.get("message","T02 is not currently eligible."))); return
	if facts.people != row.cohort: row.notes.append("T02 quote does not match the exact current eligible cohort."); return
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	var candidate := {"hull":hull_id,"facts":facts,"body":hull,"approach":0,"approach_seconds":0.0,"route_index":0,"plans":[]}
	for person in facts.person_facts:
		if person.position.distance_to(row.anchor) > LOCAL_RADIUS:
			row.notes.append("Cohort is outside the real pickup's local boarding radius; a lift cannot assume instant gathering.")
			return
	row.candidate = candidate
	row.phase = "Approach"

func _begin_approach(row: Dictionary) -> void:
	var candidate: Dictionary = row.candidate
	if candidate.approach >= row.cohort.size(): row.phase = "Vehicle"; return
	var person: Dictionary = row.people[row.cohort[candidate.approach]]
	if not _safe_foot(person,row.anchor): _reject_candidate(row,"Actual boarding approach crosses delivered hostile fire."); return
	if person.position.distance_to(row.anchor) <= 0.000001: candidate.approach += 1; return
	row.work = _foot_work(person,row.anchor)

func _begin_vehicle(row: Dictionary) -> void:
	var candidate: Dictionary = row.candidate
	if candidate.route_index >= 4:
		var pickup: Dictionary = candidate.plans[0]
		var pickup_back: Dictionary = candidate.plans[1]
		var loaded: Dictionary = candidate.plans[2]
		var fallback: Dictionary = candidate.plans[3]
		var required: float = 1.25*maxf(float(pickup.fuel)+float(pickup_back.fuel),float(pickup.fuel)+float(loaded.fuel)+float(fallback.fuel))
		if float(candidate.body.fuel)+0.000001 < required: _reject_candidate(row,"Actual T02 tank cannot cover pickup, the loaded journey and fallback with reserve."); return
		var authority: Dictionary = _named_authority(row)
		var proposal := {"hull":candidate.hull,"parent":_rear().military.vehicles[candidate.hull].parent,"authority":authority}
		var approval: Dictionary = _authorize.call(proposal,false) if _authorize.is_valid() else {"ok":false,"message":"No actual-parent authorization owner is available."}
		if not approval.get("ok",false): _reject_candidate(row,str(approval.get("message","The actual parent has not made this T02 available."))); return
		candidate.eta = float(pickup.seconds)+float(candidate.approach_seconds)+HANDLING_SECONDS*row.cohort.size()+float(loaded.seconds)+HANDLING_SECONDS*row.cohort.size()+maxf(0.0,float(approval.get("delay_seconds",2.0)))
		row.choices.append(candidate)
		row.candidate = {}
		row.phase = "Candidates"
		return
	var points: Array = []
	var extra := 0.0
	match int(candidate.route_index):
		0: points = [candidate.body.position,row.anchor]
		1: points = [row.anchor,candidate.body.position]
		2: points = [row.anchor,row.goal]; extra = float(candidate.facts.passenger_mass_kg)
		3: points = [row.goal,row.anchor]; extra = float(candidate.facts.passenger_mass_kg)
	if (points[0] as Vector2).distance_to(points[1]) <= 0.000001:
		candidate.plans.append({"ok":true,"parts":[],"distance":0.0,"seconds":0.0,"fuel":0.0})
		candidate.route_index += 1
		return
	row.work = Routes.begin_plan(_rear().ledger,candidate.hull,points,{"world":row.world,"prospective_load_kg":extra})

func _finish_work(row: Dictionary) -> void:
	var plan: Dictionary = row.work.result
	row.work = null
	if row.phase == "Foot":
		if plan.get("ok",false):
			row.walks[row.cohort[row.foot_index]] = plan
			row.foot_eta = maxf(float(row.foot_eta),float(plan.seconds))
		else:
			row.foot_ok = false
			row.foot_reason = str(plan.get("reason","No supported safe physical foot route."))
		row.foot_index += 1
	elif row.phase == "Approach":
		if not plan.get("ok",false): _reject_candidate(row,"No actual boarding approach: "+str(plan.get("reason","Unsupported approach"))); return
		row.candidate.approach_seconds += float(plan.seconds)
		row.candidate.approach += 1
	else:
		if not plan.get("ok",false): _reject_candidate(row,str(plan.get("reason","No supported T02 route."))); return
		var danger: String = _transport()._known_route_danger(row.candidate.hull,plan.parts)
		if not danger.is_empty(): _reject_candidate(row,danger); return
		row.candidate.plans.append(plan)
		row.candidate.route_index += 1

func _choose(row: Dictionary) -> void:
	if not row.foot_ok: row.foot_eta = -1.0
	var best := {}
	for candidate in row.choices:
		if best.is_empty() or float(candidate.eta) < float(best.eta): best = candidate
	if not best.is_empty(): row.lift_eta = best.eta
	if row.foot_ok and (best.is_empty() or float(row.foot_eta) <= float(best.eta)):
		row.mode = "Foot"
		row.hull = ""
		row.selected = {}
		row.eta = row.foot_eta
		_set_state(row,"Ready","Measured safe foot journey is faster." if not best.is_empty() else "No currently eligible approved faster T02; measured safe foot journey remains available. "+_notes(row))
	elif not best.is_empty():
		row.mode = "Transport"
		row.hull = best.hull
		row.selected = best
		row.eta = best.eta
		_set_state(row,"Ready","Measured T02 pickup, boarding, loaded journey and dismount arrive sooner than the safe foot option.")
	else: _set_state(row,"Blocked",row.foot_reason+" "+_notes(row))

func _continue(row: Dictionary) -> void:
	if row.state in ["Planning","Interrupted"]: return
	var error: String = _command_error(row)
	if not error.is_empty(): interrupt_journey(row.squad,row.cycle,error); return
	if row.state == "Walking":
		if _arrived(row): _set_state(row,"Arrived","")
		elif not _has_owned_walk(row): _reset(row)
		return # Execution owns admitted same-intent walks; progress is not stale capture.
	if row.state == "Arrived": return
	if row.state == "Blocked" and row.mode.is_empty(): _reset(row); return
	if row.mode != "Transport" or not _rear().vehicle_departures_allowed: return
	_sync_jobs(row)
	if row.planning_error:
		if not _has_physical_job(row): _reset(row)
		return
	if not row.selection_started and row.pickup_job.is_empty() and row.trip_job.is_empty() and not _capture_current(row): _reset(row); return
	if not row.trip_job.is_empty():
		var trip: Dictionary = _transport().jobs.get(row.trip_job,{})
		if not trip.is_empty() and trip.state == "Complete":
			if row.retask or not _arrived(row):
				_reset(row) # Actual old-stop dismount completed; reassess from physical positions.
				return
			_set_state(row,"Arrived" if _arrived(row) else "Blocked","" if _arrived(row) else "Actual dismount does not match the current complete cohort and destination.")
			return
		if not row.retask:
			_observe_job(row,trip)
			return
	if not row.pickup_job.is_empty() and not row.retask:
		var pickup: Dictionary = _transport().jobs.get(row.pickup_job,{})
		if pickup.is_empty() or pickup.state != "Complete": _observe_job(row,pickup); return
	var proposal := {"hull":row.hull,"parent":_rear().military.vehicles.get(row.hull,{}).get("parent",""),"authority":_named_authority(row)}
	var approval: Dictionary = _authorize.call(proposal,true) if _authorize.is_valid() else {"ok":false,"message":"No actual-parent authorization owner is available."}
	if not approval.get("ok",false):
		if not _has_physical_job(row):
			if row.selection_started: _reset(row); return
			_cancel_pure(row)
			var remaining: Array = []
			for candidate in row.choices:
				if candidate.hull != row.hull: remaining.append(candidate)
			row.choices = remaining
			row.notes.append(str(approval.get("message","Actual parent withheld this lift.")))
			row.hull = ""; row.selected = {}; row.pickup_key = ""; row.trip_key = ""
			_choose(row)
		else: _set_state(row,"Blocked",str(approval.get("message","Parent approval is unavailable; existing physical custody is retained.")))
		return
	if approval.get("pending",false) or str(approval.get("hull_intent","")).is_empty(): _set_state(row,"AwaitingACK",str(approval.get("message","Waiting for the real named hull order acknowledgement."))); return
	row.authority = _named_authority(row)
	row.authority.hull_intent = str(approval.hull_intent)
	if not _markers(row): return
	row.selection_started = true
	if row.retask:
		var job_id: String = row.trip_job if not row.trip_job.is_empty() else row.pickup_job
		var hull: Dictionary = _rear().ledger.inspect_entity(row.hull,{},false)
		row.goal = _rear().ledger.inspect_entity(row.destination,{},false).position
		var destination: Vector2 = row.goal if not row.trip_job.is_empty() else row.anchor
		var resumed: Dictionary = _transport().resume_supply_job_deferred(job_id,[hull.position,destination],[destination,hull.position],row.authority)
		if resumed.get("ok",false): row.retask = false; row.resume_pending = true; _set_state(row,"Travelling","Fresh same-job route reassessment queued; actual custody retained.")
		else: _set_state(row,"Blocked",str(resumed.get("message","Same physical lift cannot yet resume.")))
		return
	var actual_hull: Dictionary = _rear().ledger.inspect_entity(row.hull,{},false)
	var at_pickup: bool = actual_hull.get("position",Vector2.INF).is_equal_approx(row.anchor) and _rear().ledger.entity_kind(str(actual_hull.get("holder_id",""))) == "PLACE"
	if row.pickup_job.is_empty() and not at_pickup:
		if row.pickup_key.is_empty():
			row.pickup_key = row.key+":%d:pickup" % row.attempt
			var body: Dictionary = _rear().ledger.inspect_entity(row.hull,{},false)
			var queued: Dictionary = _transport().request_reposition_deferred(row.pickup_key,row.hull,row.origin_marker,row.pickup,[body.position,row.anchor],[row.anchor,body.position],row.authority)
			if not queued.get("ok",false): row.planning_error = true; _set_state(row,"Blocked",str(queued.get("message","Actual pickup planning refused."))); return
		_set_state(row,"Pickup","Real pickup is queued with the existing transport owner.")
		return
	if not at_pickup: _set_state(row,"Blocked","The actual stopped hull must retain its pickup position."); return
	# Execution may still be gathering the actual cohort. Do not enqueue a request
	# that C would permanently deny while these owned short walks are in progress.
	for id in row.cohort:
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if not _free(id) or person.position.distance_to(row.anchor) > LOCAL_RADIUS:
			_set_state(row,"Boarding","Waiting for the actual eligible cohort to finish gathering within the stopped pickup radius.")
			return
	if row.trip_key.is_empty():
		row.trip_key = row.key+":%d:trip" % row.attempt
		var queued: Dictionary = _transport().request_supply_trip_deferred(row.trip_key,row.hull,row.squad,row.pickup,row.destination,[row.anchor,row.goal],[row.goal,row.anchor],row.authority)
		if not queued.get("ok",false): row.planning_error = true; _set_state(row,"Blocked",str(queued.get("message","Actual supply trip admission refused."))); return
	_set_state(row,"Boarding","Actual eligible cohort trip queued; passengers are not committed until admission.")

func _sync_jobs(row: Dictionary) -> void:
	for kind in ["pickup","trip"]:
		var key: String = row[kind+"_key"]
		if key.is_empty(): continue
		var current: Dictionary = _transport().planning_status(key)
		if current.get("state","") == "Admitted": row[kind+"_job"] = str(current.job)
		elif current.get("state","") in ["Blocked","Cancelled"]:
			row.planning_error = true
			_set_state(row,"Blocked",str(current.get("message","Named physical planning stopped.")))

func _markers(row: Dictionary) -> bool:
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull,{},false)
	for item in [[row.pickup,row.anchor],[row.origin_marker,hull.get("position",Vector2.INF)]]:
		var place: Dictionary = rear.ledger.inspect_entity(item[0],{},false)
		if place.is_empty():
			var created: Dictionary = rear.ledger.add_place(item[0],"Actual named Rifle lift rendezvous",item[1])
			if not created.ok: _set_state(row,"Blocked",created.message); return false
		elif place.get("kind","") != "PLACE" or place.position != item[1]:
			# The original hull-origin marker remains immutable after actual pickup.
			if str(item[0]) == row.origin_marker and (not row.pickup_job.is_empty() or not row.trip_job.is_empty()): continue
			_set_state(row,"Blocked","Existing lift marker does not match its captured actual physical position.")
			return false
	return true

func _observe_job(row: Dictionary, job: Dictionary) -> void:
	if job.is_empty(): _set_state(row,"Blocked","Owned physical transport job is unavailable; no replacement is fabricated."); return
	var state: String = str(job.state)
	if state in ["Paused","Blocked Route","Stranded"]: _set_state(row,"Blocked",str(job.get("blocker","Physical lift is stopped with actual custody retained."))); return
	var display: String = "Pickup" if row.trip_job.is_empty() else ("Travelling" if state in ["Outbound","Planning Route"] else state)
	_set_state(row,display,str(job.get("blocker","")))

func _command_error(row: Dictionary) -> String:
	var rear: RefCounted = _rear()
	var squad: Dictionary = rear.military.squads.get(row.squad,{})
	var intent: Dictionary = rear.orders.intents.get(row.squad,{})
	if squad.get("kind","") != "Rifle" or squad.get("state","") != "Active" or squad.get("owner","") != rear.PLAYER: return "An actual active own Rifle squad is required."
	if not row.parent.is_empty() and (squad.platoon != row.parent or squad.owner != row.owner): return "Actual Rifle parent or owner changed; this proposal cannot automatically reparent."
	if intent.get("id","") != row.intent or intent.get("state","") != "Acknowledged" or intent.get("parent","") != squad.platoon: return "The actual current Rifle parent operation must be acknowledged."
	var assigned: String = str(intent.get("constraints",{}).get("supply_rendezvous" if row.leg == "Collect" else "destination",""))
	if assigned != row.destination or rear.ledger.entity_kind(row.destination) != "PLACE": return "Journey destination no longer matches the current acknowledged operation."
	return ""

func _capture_current(row: Dictionary) -> bool:
	if not _command_error(row).is_empty() or row.world != _rear().combat.world or row.revision != row.world.revision: return false
	if _rear().ledger.inspect_entity(row.destination,{},false).position != row.goal: return false
	if _rear().military._active_roster_members(_rear().military.squads[row.squad]) != row.cohort: return false
	for id in row.cohort:
		if not _free(id): return false
		var current: Dictionary = _rear().ledger.inspect_entity(id)
		for key in ["owner","position","holder_id","assignment","duty_id","health","pending_assignment","crew_station","contents_mass_kg","unit_mass_kg"]:
			if current.get(key) != row.people[id].get(key): return false
		if row.mode == "Foot" and not _safe_foot(current,row.goals[id]): return false
	if row.mode == "Transport":
		var facts: Dictionary = _transport().supply_cohort_facts(row.hull,row.squad)
		if not facts.get("ok",false) or facts != row.selected.facts: return false
		var body: Dictionary = _rear().ledger.inspect_entity(row.hull)
		for key in ["position","holder_id","owner","fuel","health","crew_by_station","contents_mass_kg","damage_immobilized"]:
			if body.get(key) != row.selected.body.get(key): return false
	return true

func _arrived(row: Dictionary) -> bool:
	if row.cohort.is_empty() or not _command_error(row).is_empty(): return false
	var squad: Dictionary = _rear().military.squads[row.squad]
	if _rear().military._active_roster_members(squad) != row.cohort: return false
	if row.mode == "Transport":
		var job: Dictionary = _transport().jobs.get(_observed_job(row,"trip"),{})
		if job.get("state","") != "Complete" or not str(_rear().military.squads.get(row.squad,{}).get("vehicle","")).is_empty(): return false
	var place: Dictionary = _rear().ledger.inspect_entity(row.destination,{},false)
	if place.get("kind","") != "PLACE": return false
	for id in row.cohort:
		var person: Dictionary = _rear().ledger.inspect_person_status(id)
		if person.get("health",0) <= 0 or person.get("owner","") != squad.owner or person.get("assignment","") != "Formation Duty" or person.get("duty_id","") != row.squad or person.get("holder_id","") != row.destination or person.position.distance_to(place.position) > 8.0: return false
	return true

func _named_authority(row: Dictionary) -> Dictionary:
	return {"squad":row.squad,"cycle":row.cycle,"leg":row.leg,"operation_intent":row.intent,
		"pickup":row.pickup,"destination":row.destination,"cohort":row.cohort.duplicate()}

func _foot_work(person: Dictionary, destination: Vector2) -> RefCounted:
	return _rear().combat.world.begin_route({"position":person.position,"facing":(destination-person.position).angle(),"size":Vector2(0.6,0.6),
		"movement_class":0,"base":2.0,"rate":0.0,"gross_mass_kg":float(person.unit_mass_kg)+float(person.contents_mass_kg)},destination)

func _safe_foot(person: Dictionary, destination: Vector2) -> bool:
	if person.position.distance_squared_to(destination) <= 0.000000000001: return true
	return _rear().battlefield_operations != null and _rear().battlefield_operations._fallback_safe(person,destination)

func _free(id: String) -> bool:
	var rear: RefCounted = _rear()
	return not rear.forward_supply.person_committed(id) and not rear.forward_supply._other_busy(id) and not rear.military.person_committed(id) and (rear.battlefield_operations == null or not rear.battlefield_operations.person_committed(id))

func _reset(row: Dictionary) -> void:
	_sync_jobs(row)
	if _has_physical_job(row): return # Never replace an admitted physical owner with a fresh proposal.
	_cancel_pure(row)
	row.attempt += 1
	row.pickup_key = ""
	row.trip_key = ""
	row.pickup_job = ""
	row.trip_job = ""
	row.planning_error = false
	row.selection_started = false
	row.retask = false
	row.authority = {}
	# Old immutable markers remain historical metadata; a recapture gets new IDs.
	row.pickup = "rifle-pickup-%d-%s-%d" % [get_instance_id(),row.key,row.attempt]
	row.origin_marker = "rifle-origin-%d-%s-%d" % [get_instance_id(),row.key,row.attempt]
	row.work = null
	row.world = null
	row.phase = "Capture"
	row.people = {}
	row.goals = {}
	row.walks = {}
	row.cohort = []
	row.foot_index = 0
	row.foot_ok = true
	row.foot_reason = ""
	row.foot_eta = -1.0
	row.fleet_index = 0
	row.choices = []
	row.candidate = {}
	row.selected = {}
	row.notes = []
	row.mode = ""
	row.hull = ""
	row.eta = -1.0
	row.lift_eta = -1.0
	_set_state(row,"Planning","Inputs changed; measuring this current journey again.")
	_enqueue(row)

func _enqueue(row: Dictionary) -> void:
	if not row.queued:
		row.queued = true
		_queue.append(row)

func _observed_job(row: Dictionary, kind: String) -> String:
	var key: String = row[kind+"_key"]
	if not key.is_empty():
		var observed: Dictionary = _transport().planning_status(key)
		if observed.get("state","") == "Admitted": return str(observed.job)
	return str(row[kind+"_job"])

func _has_physical_job(row: Dictionary) -> bool:
	for kind in ["pickup","trip"]:
		var job: Dictionary = _transport().jobs.get(_observed_job(row,kind),{})
		if not job.is_empty() and job.state != "Complete": return true
	return false

func _has_owned_walk(row: Dictionary) -> bool:
	var execution: RefCounted = _rear().battlefield_operations
	if execution == null: return false
	for id in row.cohort:
		var motion: Dictionary = execution.motions.get(id,{})
		if motion.get("intent","") == row.intent and motion.get("place","") == row.destination and motion.get("purpose","") in ["Supply","Supply Return"]: return true
	return false

func _remaining_eta(row: Dictionary) -> float:
	# Quotes remain available as foot_eta/lift_eta. Do not present the original
	# full-trip quote as a live forecast once ACK/physical handling has begun.
	if row.state == "Ready": return float(row.eta)
	if row.state != "Walking" or not _has_owned_walk(row): return -1.0
	var remaining := 0.0
	for id in row.cohort:
		var motion: Dictionary = _rear().battlefield_operations.motions.get(id,{})
		if motion.get("intent","") == row.intent and motion.get("place","") == row.destination:
			remaining = maxf(remaining,maxf(0.0,float(motion.deadline)-_rear().time))
		else:
			var person: Dictionary = _rear().ledger.inspect_person_status(id)
			if person.get("holder_id","") != row.destination or person.position.distance_to(row.goals[id]) > 1.0: return -1.0
	return remaining

func _reject_candidate(row: Dictionary, reason: String) -> void:
	row.notes.append(reason)
	row.work = null
	row.candidate = {}
	row.phase = "Candidates"

func _cancel_pure(row: Dictionary) -> void:
	for key in [row.pickup_key,row.trip_key]:
		if not str(key).is_empty(): _transport().cancel_planning_request(key)
	row.work = null

func _set_state(row: Dictionary, state: String, blocker: String) -> void:
	if row.state != state or row.blocker != blocker:
		row.state = state
		row.blocker = blocker
		planning_revision += 1

func _notes(row: Dictionary) -> String:
	return str(row.notes[-1]) if not row.notes.is_empty() else "No eligible free own T02 is available."

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func _transport() -> RefCounted:
	return _rear().military.troop_transport
