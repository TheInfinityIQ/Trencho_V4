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
var incremental_planning: bool = false
var planning_revision: int = 0
var _planning_generation := 0
var _planning_sequence := 0
var _planning_requests: Dictionary = {}
var _planning_fifo: Array[Dictionary] = []
var _departure_requests: Dictionary = {}


func _init(rear: RefCounted, organization: RefCounted) -> void:
	_rear_ref = weakref(rear)
	_organization_ref = weakref(organization)
	if rear.ledger.inspect_entity("troop-transit").is_empty():
		rear.ledger.add_place("troop-transit","Military personnel hull on its declared route",Vector2.ZERO)


func request_trip_deferred(key: String, hull_id: String, squad_ids: Array, board: String, dismount: String,
		outbound: Array, return_points: Array, intent_ids: Dictionary = {}) -> Dictionary:
	if key.is_empty(): return _fail("A deferred trip needs a stable request key.")
	if not _planning_requests.has(key):
		var request: Dictionary = _planning_descriptor(key,hull_id,squad_ids,board,dismount,outbound,return_points,intent_ids)
		_planning_requests[key] = request
		_planning_fifo.append(request)
		planning_revision += 1
	var status: Dictionary = planning_status(key)
	status.ok = true
	status.pending = status.state in ["Pending","Ready"]
	status.request_id = key
	return status


func supply_cohort_facts(hull_id: String, squad_id: String) -> Dictionary:
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	var squad: Dictionary = _organization().squads.get(squad_id,{})
	if hull.get("design_type","") != "T02" or hull.get("fleet_domain","") != "Military" or not _organization().vehicles.has(hull_id): return _fail("Select an actual attached military T02.")
	if squad.get("kind","") != "Rifle" or squad.get("state","") != "Active" or squad.get("owner","") != hull.owner or _company_of(_organization().vehicles[hull_id].parent) != str(squad.get("company","")): return _fail("A same-army same-company active Rifle cohort is required.")
	var capability: Dictionary = _organization().capability(squad_id,"Supply Collection")
	if not capability.ok: return capability
	var blocker := _supply_hull_error(hull_id,hull)
	if not blocker.is_empty(): return _fail(blocker)
	var people: Array[String] = _organization()._active_roster_members(squad)
	var facts: Array[Dictionary] = []
	var mass := 0.0
	for id in people:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if not _supply_person_free(id,person): return _fail("Each actual eligible passenger must finish its other physical work.")
		var armed := false
		for weapon in rear.ledger.entities_at(id,["WEAPON"],false):
			if weapon.design_type == "E01" and weapon.get("functional",false) and weapon.get("health",0) > 0: armed = true; break
		if not armed: return _fail("Each eligible Rifle carrier needs its actual functional rifle; ammunition is not required to collect supply.")
		facts.append(_planning_person_facts(person))
		mass += float(person.unit_mass_kg)+float(person.contents_mass_kg)
	if people.is_empty() or people.size() > 8 or people.size() > int(hull.vehicle_spec.passenger_seats): return _fail("Current eligible cohort exceeds the actual available seats.")
	var payload: float = float(hull.contents_mass_kg)+mass
	if payload > float(hull.vehicle_spec.payload)+EPS: return _fail("Actual cohort and gear exceed the T02 payload.")
	return {"ok":true,"message":"Actual eligible Rifle cohort fits this free same-company T02.","people":people,"person_facts":facts,"passenger_mass_kg":mass,"seats_used":people.size(),"payload_kg":payload}

func request_reposition_deferred(key: String, hull_id: String, origin_place_id: String, destination_place_id: String,
		points: Array, fallback: Array, authority: Dictionary) -> Dictionary:
	return _request_supply(key,"Supply Reposition",hull_id,origin_place_id,destination_place_id,points,fallback,authority)

func request_supply_trip_deferred(key: String, hull_id: String, squad_id: String, pickup_place_id: String, destination_place_id: String,
		points: Array, fallback: Array, authority: Dictionary) -> Dictionary:
	if authority.get("squad","") != squad_id: return _fail("Named transport and actual Rifle squad must match.")
	return _request_supply(key,"Supply Admission",hull_id,pickup_place_id,destination_place_id,points,fallback,authority)

func _request_supply(key: String, kind: String, hull: String, board: String, destination: String,
		points: Array, fallback: Array, authority: Dictionary) -> Dictionary:
	if key.is_empty(): return _fail("Supply transport requires a private request key.")
	if _planning_requests.has(key):
		var existing: Dictionary = _planning_requests[key]
		if existing.kind != kind or existing.hull != hull or existing.get("authority",{}) != authority or existing.board != board or existing.dismount != destination or existing.out != points or existing.home != fallback: return _fail("An existing private key cannot be reused for another supply movement.")
	else:
		var request := _planning_descriptor(key,hull,[str(authority.get("squad",""))],board,destination,points,fallback,{})
		request.kind = kind
		request.phase = "Outbound"
		request.authority = authority.duplicate(true)
		_planning_requests[key] = request
		_planning_fifo.append(request)
		planning_revision += 1
	var status := planning_status(key)
	status.ok = true
	status.request_id = key
	status.pending = status.state in ["Pending","Ready"]
	return status

func cancel_planning_request(key: String) -> Dictionary:
	var request: Dictionary = _planning_requests.get(key,{})
	if request.is_empty(): return _fail("No such private planning request.")
	if request.state == "Admitted": return _fail("An admitted physical job must be interrupted through its existing owner.")
	if request.state in ["Pending","Ready"]:
		request.state = "Cancelled"
		request.message = "This private pure request was cancelled; physical custody is retained."
		_drop_planning_work(request)
		planning_revision += 1
		if not str(request.job).is_empty():
			var row: Dictionary = jobs.get(request.job,{})
			if row.get("state","") == "Planning Route": _block_route(row,str(request.phase),request.message)
	return {"ok":true,"message":request.message}

func _company_of(parent: String) -> String:
	if _organization().companies.has(parent): return parent
	return str(_organization().platoons.get(parent,{}).get("company",""))

func _supply_hull_error(id: String, hull: Dictionary, owned_job: String = "") -> String:
	for row in jobs.values():
		if row.hull == id and row.id != owned_job and row.state != "Complete": return "Another physical military activity owns this T02."
	if _rear().forward_supply.hull_committed(id) or _rear().hq._target_busy(id): return "Freight or HQ handling owns this T02."
	if not str(hull.get("towing","")).is_empty() or not str(hull.get("towed_by","")).is_empty(): return "A tow or recovery commitment excludes routine supply transport."
	for item in _rear().ledger.entities_at(id,["STOCK","WEAPON","HEAVY_OBJECT"],false):
		if item.quantity > 0: return "Actual freight must be resolved by its owner before personnel transport."
	if owned_job.is_empty() and (not hull.get("passengers",[]).is_empty() or not _organization()._vehicle_squads(id).is_empty()): return "Existing passengers or squad places already own this T02."
	return _movement_blocker(id,hull)

func _supply_person_free(id: String, person: Dictionary) -> bool:
	return _supply_person_available(id,person) and _rear().ledger.entity_kind(str(person.get("holder_id",""))) == "PLACE" and not person_committed(id)

func _supply_person_available(id: String, person: Dictionary, require_stopped: bool = false) -> bool:
	var rear: RefCounted = _rear()
	if person.get("health",0) <= 0 or person.get("assignment","") != "Formation Duty" or person.get("pending_assignment","") != "None" or not str(person.get("crew_station","")).is_empty() or not str(person.get("carrying_stock_id","")).is_empty() or not str(person.get("carrying_weapon_id","")).is_empty(): return false
	if rear.combat.pinned.has(id) or rear.combat.broken.has(id): return false
	if rear.forward_supply.person_committed(id) or rear.forward_supply._other_busy(id): return false
	return not require_stopped or rear.battlefield_operations == null or not rear.battlefield_operations.person_committed(id)

func _supply_authority_error(hull_id: String, authority: Dictionary, physical: Dictionary = {}) -> String:
	if authority.size() != 8: return "Supply movement requires the exact named authority fields."
	for key in ["squad","cycle","leg","operation_intent","hull_intent","pickup","destination","cohort"]:
		if not authority.has(key): return "Supply movement lacks named authority: "+key
	if authority.leg not in ["Collect","Return"] or str(authority.cycle).is_empty(): return "Supply movement needs a named Collect or Return leg."
	if not physical.is_empty():
		for key in ["squad","cycle","leg"]:
			if authority[key] != physical.supply_authority[key]: return "An interrupted job must retain its actual squad, cycle and journey leg."
		if physical.kind == "Troop Trip" and authority.pickup != physical.board_place: return "The same loaded job retains its real original pickup."
	var military: RefCounted = _organization()
	var squad: Dictionary = military.squads.get(authority.squad,{})
	var attachment: Dictionary = military.vehicles.get(hull_id,{})
	var hull: Dictionary = _rear().ledger.inspect_entity(hull_id,{},false)
	if squad.get("kind","") != "Rifle" or squad.get("state","") != "Active" or attachment.get("owner","") != squad.get("owner","missing") or hull.get("owner","") != squad.get("owner","missing") or _company_of(str(attachment.get("parent",""))) != str(squad.get("company","")): return "Current transport and Rifle parents must belong to the same actual army and company."
	var parent: Dictionary = military.platoons.get(attachment.parent,military.companies.get(attachment.parent,{}))
	var rifle_parent: Dictionary = military.platoons.get(squad.platoon,{})
	if parent.is_empty() or rifle_parent.is_empty() or parent.get("owner",_rear().PLAYER) != hull.owner or rifle_parent.get("owner",_rear().PLAYER) != hull.owner or rifle_parent.get("company","") != squad.company: return "Both current actual parents must retain the same army and company ownership."
	var operation: Dictionary = _rear().orders.intents.get(authority.squad,{})
	if operation.get("id","") != authority.operation_intent or operation.get("state","") != "Acknowledged" or operation.get("parent","") != squad.platoon or operation.get("action","") == "Defend HQ": return "The current actual-parent Rifle operation must remain acknowledged and eligible for supply travel."
	var destination: String = str(operation.get("constraints",{}).get("supply_rendezvous" if authority.leg == "Collect" else "destination",""))
	if destination != authority.destination: return "The supply leg must match the current rendezvous or latest operational destination."
	var intent: Dictionary = _rear().orders.intents.get(hull_id,{})
	var named := authority.duplicate(true)
	named.erase("hull_intent")
	if intent.get("id","") != authority.hull_intent or intent.get("state","") != "Acknowledged" or intent.get("action","") != "Move by Transport" or intent.get("parent","") != attachment.get("parent","") or intent.get("constraints",{}).get("supply_transport",{}) != named: return "The actual vehicle parent must acknowledge this exact named hull movement."
	if not str(squad.get("vehicle","")).is_empty() and (physical.get("kind","") != "Troop Trip" or squad.vehicle != hull_id): return "Another physical passenger owner holds this squad."
	var members: Array[String] = military._active_roster_members(squad,not physical.is_empty())
	if members != authority.cohort or members.size() < 4 or members.size() > 8: return "The current eligible physical Rifle cohort no longer matches the named movement."
	if not physical.is_empty() and physical.kind == "Troop Trip" and physical.people != members: return "The same physical passenger manifest must be retained for reassessment."
	if str(squad.get("leader","")) not in members: return "The actual living Rifle leader must remain in the eligible cohort."
	var leader: Dictionary = _rear().ledger.inspect_person_status(squad.leader)
	if not leader.get("basic_training",false) and not squad.get("acting",false): return "The actual Rifle leader must retain training or its existing acting exception."
	for id in members:
		var person: Dictionary = _rear().ledger.inspect_person_status(id)
		if person.get("owner","") != hull.owner or not _supply_person_available(id,person,physical.get("kind","") == "Troop Trip"): return "A current cohort member is unavailable, pinned, broken, or committed to another activity; retain actual custody."
	return ""

func _supply_planning_guard(request: Dictionary) -> Dictionary:
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(request.hull)
	var row: Dictionary = jobs.get(request.job,{})
	if hull.get("design_type","") != "T02" or hull.get("fleet_domain","") != "Military" or not _organization().vehicles.has(request.hull): return _fail("Select an actual attached military T02.")
	if request.kind in ["Supply Departure","Supply Handling"] and (row.is_empty() or not row.get("supply_mode",false) or row.state != "Planning Route" or row.planning_phase != request.phase): return _fail("The same supply job must retain this queued physical continuation.")
	var error := _supply_authority_error(request.hull,request.authority,row)
	if error.is_empty(): error = _supply_hull_error(request.hull,hull,str(request.job))
	if not error.is_empty(): return _fail(error)
	var board: Dictionary = rear.ledger.inspect_entity(request.board,{},false)
	var dismount: Dictionary = rear.ledger.inspect_entity(request.dismount,{},false)
	if board.get("kind","") != "PLACE" or dismount.get("kind","") != "PLACE" or request.board == request.dismount: return _fail("A supply movement needs distinct real origin and destination markers.")
	var people: Array = []
	var mass := 0.0
	if request.kind == "Supply Admission":
		if request.board != request.authority.pickup or request.dismount != request.authority.destination: return _fail("The exact acknowledged pickup and destination are required.")
		var facts := supply_cohort_facts(request.hull,str(request.authority.squad))
		if not facts.ok: return facts
		people = facts.people
		mass = float(facts.passenger_mass_kg)
		if not hull.position.is_equal_approx(board.position) or rear.ledger.entity_kind(hull.holder_id) != "PLACE": return _fail("The real stopped T02 must reach the named pickup position.")
		for id in people:
			var person: Dictionary = rear.ledger.inspect_entity(id)
			if not _supply_person_available(id,person,true): return _fail("Actual admission requires each passenger to stop tactical foot movement and finish other work.")
			if person.position.distance_to(hull.position) > LOCAL_RADIUS+EPS or not _foot_leg(person,hull.position).ok: return _fail("Every actual eligible passenger needs a safe local approach within 20 m of the stopped T02.")
	elif request.kind == "Supply Reposition":
		var facts := supply_cohort_facts(request.hull,str(request.authority.squad))
		if not facts.ok: return facts
		if request.dismount != request.authority.pickup or not hull.position.is_equal_approx(board.position) or rear.ledger.entity_kind(hull.holder_id) != "PLACE": return _fail("Empty reposition must start at the actual stopped hull and end at its acknowledged pickup.")
	else:
		people = row.people
		error = _supply_custody_error(row,hull)
		if not error.is_empty(): return _fail(error)
		if request.kind == "Supply Handling":
			var approach_seconds := 0.0
			if request.phase not in ["Boarding","Dismounting"]: return _fail("No interrupted physical handling remains.")
			if request.phase == "Boarding" and (not hull.position.is_equal_approx(board.position) or rear.ledger.entity_kind(hull.holder_id) != "PLACE"): return _fail("The same hull must retain the actual boarding stop.")
			if request.phase == "Dismounting" and (hull.holder_id != row.dismount_place or not hull.position.is_equal_approx(rear.ledger.inspect_entity(row.dismount_place).position)): return _fail("Finish partial dismount at the actual old stop before reassessing the new destination.")
			if not row.task.is_empty() and row.task.get("phase","") == "Approach":
				var person: Dictionary = rear.ledger.inspect_entity(row.task.person)
				if not person.position.is_equal_approx(row.task.expected): return _fail("The same passenger must retain the actual interrupted approach position.")
				var leg: Dictionary = _foot_leg(person,hull.position)
				if not leg.ok: return _fail("The remaining actual local boarding approach is unsafe.")
				approach_seconds = float(leg.seconds)
			return {"ok":true,"hull":hull,"people":people,"board":board,"dismount":dismount,"passenger_mass_kg":0.0,"approach_seconds":approach_seconds}
		if request.phase != "Outbound": return _fail("A supply leg never invents an automatic empty return.")
		if row.kind == "Troop Trip":
			if request.dismount != request.authority.destination: return _fail("The resumed loaded leg must reach the latest acknowledged destination.")
			error = _departure_manifest_error(row,hull,"Outbound")
		else:
			if request.dismount != request.authority.pickup or not hull.passengers.is_empty() or not _organization()._vehicle_squads(request.hull).is_empty(): error = "Empty reposition must retain an empty actual hull and its acknowledged pickup."
		if not error.is_empty(): return _fail(error)
	error = _validate_points(request.out,hull.position,dismount.position)
	if error.is_empty(): error = _validate_points(request.home,dismount.position,board.position)
	if not error.is_empty(): return _fail(error)
	return {"ok":true,"hull":hull,"people":people,"board":board,"dismount":dismount,"passenger_mass_kg":mass}

func _supply_custody_error(row: Dictionary, hull: Dictionary) -> String:
	if row.kind != "Troop Trip":
		return "Empty reposition cannot acquire passengers or squad places." if not hull.passengers.is_empty() or not _organization()._vehicle_squads(row.hull).is_empty() else ""
	if row.boarded > row.people.size() or row.dismounted > row.boarded: return "Actual handling counters no longer match the retained manifest."
	if _organization()._vehicle_squads(row.hull) != row.squads: return "The same physical squad place must remain reserved to the supply hull."
	var aboard: Array = []
	for index in row.people.size():
		var id: String = row.people[index]
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if not _supply_person_available(id,person,true): return "A retained passenger is unavailable or committed to another activity; preserve actual custody."
		if index >= int(row.dismounted) and index < int(row.boarded):
			if person.holder_id != row.hull: return "A boarded passenger no longer occupies this same hull."
			aboard.append(id)
		elif index < int(row.dismounted):
			if person.holder_id != row.dismount_place: return "A dismounted passenger no longer occupies the actual destination stop."
		elif _rear().ledger.entity_kind(person.holder_id) != "PLACE" or person.position.distance_to(hull.position) > LOCAL_RADIUS+EPS:
			return "An unboarded passenger left the actual local pickup."
	if hull.passengers.size() != aboard.size(): return "The actual passenger count must match this job's boarded and dismounted identities."
	for id in hull.passengers:
		if id not in aboard: return "The actual passengers must match this job's boarded and dismounted identities."
	return ""

func _supply_live_error(row: Dictionary) -> String:
	var error := _supply_authority_error(row.hull,row.supply_authority,row)
	if error.is_empty(): error = _supply_hull_error(row.hull,_rear().ledger.inspect_entity(row.hull),row.id)
	if error.is_empty(): error = _supply_custody_error(row,_rear().ledger.inspect_entity(row.hull))
	return error

func resume_supply_job_deferred(job_id: String, route_points: Array, fallback_points: Array, authority: Dictionary) -> Dictionary:
	var row: Dictionary = jobs.get(job_id,{})
	if row.is_empty() or not row.get("supply_mode",false) or row.state not in ["Paused","Blocked Route","Stranded","Planning Route"]: return _fail("Only the same interrupted supply job may resume through fresh named authority.")
	var phase: String = row.paused_state if row.state == "Paused" else row.get("stopped_phase","")
	if row.state == "Planning Route" or phase == "Planning Route": phase = str(row.get("planning_phase","Outbound"))
	if phase not in ["Boarding","Dismounting","Outbound"]: return _fail("The same supply leg has no resumable physical phase.")
	var error := _supply_authority_error(row.hull,authority,row)
	if not error.is_empty(): return _fail(error)
	var destination: String = str(authority.pickup if row.kind == "Reposition" else authority.destination)
	# Partial dismount always finishes at its actual old stop, even with a new order.
	if phase == "Dismounting": destination = row.dismount_place
	_discard_departure(job_id)
	return _queue_supply_continuation(row,route_points,fallback_points,authority,phase,destination)

func _queue_supply_continuation(row: Dictionary, points: Array, fallback: Array, authority: Dictionary, phase: String, destination: String) -> Dictionary:
	_planning_sequence += 1
	var key := "supply-continuation-%d" % _planning_sequence
	var request := _planning_descriptor(key,row.hull,row.squads,row.board_place,destination,points,fallback,{})
	request.kind = "Supply Handling" if phase in ["Boarding","Dismounting"] else "Supply Departure"
	request.authority = authority.duplicate(true)
	request.job = row.id
	request.phase = phase
	_planning_requests[key] = request
	_departure_requests[row.id] = request
	_planning_fifo.append(request)
	row.state = "Planning Route"
	row.planning_phase = phase
	row.planning_state = "Pending"
	row.planning_points = points.duplicate()
	row.route_deadline = INF
	row.blocker = "Validating the same supply job; actual passenger custody is retained."
	planning_revision += 1
	return {"ok":true,"pending":true,"request_id":key,"job":row.id,"message":row.blocker}

func _commit_supply_route(request: Dictionary, guarded: Dictionary) -> bool:
	var row: Dictionary
	if request.kind in ["Supply Admission","Supply Reposition"]:
		var loaded: bool = request.kind == "Supply Admission"
		if loaded:
			var reserved: Dictionary = _organization()._reserve_transport_manifest(request.hull,request.squads)
			if not reserved.ok: return _deny_planning(request,reserved.message)
		_sequence += 1
		var id := ("troop-trip-%04d" if loaded else "military-reposition-%04d") % _sequence
		row = {"id":id,"kind":"Troop Trip" if loaded else "Reposition","hull":request.hull,"owner":guarded.hull.owner,
			"squads":request.squads.duplicate() if loaded else [],"people":guarded.people.duplicate() if loaded else [],
			"board_place":request.board,"dismount_place":request.dismount,"outbound_points":request.out.duplicate(),"return_points":request.home.duplicate(),
			"boarded":0,"dismounted":0,"state":"Boarding" if loaded else "Outbound","task":{},"route_plan":{},"route_points":[],
			"route_started":INF,"route_deadline":INF,"route_distance":0.0,"route_fuel":0.0,"route_expected":guarded.hull.position,
			"world_revision":request.revision,"paused_state":"","stopped_phase":"","blocker":"","return_completed":false,
			"return_required":false,"supply_mode":true,"supply_authority":request.authority.duplicate(true),"intent_ids":{}}
		jobs[id] = row
		request.job = id
		if not loaded: _start_supply_route(row,request,guarded.hull)
	else:
		row = jobs[request.job]
		row.supply_authority = request.authority.duplicate(true)
		row.dismount_place = request.dismount
		row.outbound_points = request.out.duplicate()
		row.return_points = request.home.duplicate()
		_start_supply_route(row,request,guarded.hull)
	_admit_supply_request(request,"Same supply hull and actual cohort committed without an automatic empty return.")
	return true

func _start_supply_route(row: Dictionary, request: Dictionary, hull: Dictionary) -> void:
	row.state = "Outbound"
	row.route_plan = request.outward
	row.route_points = request.out.duplicate()
	row.route_started = _rear().time
	row.route_deadline = _rear().time+float(request.outward.seconds)
	row.route_distance = 0.0
	row.route_fuel = 0.0
	row.route_expected = hull.position
	row.world_revision = request.revision
	row.paused_state = ""
	row.stopped_phase = ""
	row.planning_phase = ""
	row.planning_state = ""
	row.planning_points = []
	row.blocker = ""

func _commit_supply_handling(request: Dictionary, guarded: Dictionary) -> bool:
	var row: Dictionary = jobs[request.job]
	row.supply_authority = request.authority.duplicate(true)
	if request.phase == "Boarding":
		row.dismount_place = request.dismount
		row.outbound_points = request.out.duplicate()
		row.return_points = request.home.duplicate()
	if not row.task.is_empty():
		var remaining: float = maxf(EPS,float(row.task.get("remaining_seconds",HANDLING_SECONDS)))
		if row.task.get("phase","") == "Approach":
			var person: Dictionary = _rear().ledger.inspect_entity(row.task.person)
			remaining = maxf(EPS,float(guarded.approach_seconds))
			row.task.from = person.position
			row.task.started = _rear().time
			row.task.expected = person.position
		row.task.deadline = _rear().time+remaining
	row.state = request.phase
	row.paused_state = ""
	row.stopped_phase = ""
	row.planning_phase = ""
	row.planning_state = ""
	row.blocker = ""
	_admit_supply_request(request,"The same actual partial handling resumed at its real stop.")
	return true

func _admit_supply_request(request: Dictionary, message: String) -> void:
	request.state = "Admitted"
	request.admitted_at = _rear().time
	request.message = message
	_departure_requests.erase(request.job)
	_drop_planning_work(request)
	planning_revision += 1

func planning_status(key: String) -> Dictionary:
	var request: Dictionary = _planning_requests.get(key,{})
	if request.is_empty(): return {}
	var status := {"state":request.state,"message":request.message}
	if request.state == "Admitted":
		status.job = request.job
		status.admitted_at = request.admitted_at
	return status


func has_planning_work() -> bool:
	for request in _planning_fifo:
		if request.state in ["Pending","Ready"]: return true
	return false


func invalidate_planning() -> void:
	_planning_generation += 1
	for request in _planning_fifo:
		if request.state in ["Pending","Ready"]: _reset_planning(request)


func cancel_planning() -> void:
	_planning_generation += 1
	for request in _planning_fifo:
		if request.state not in ["Pending","Ready"]: continue
		request.state = "Cancelled"
		request.message = "Pure route planning cancelled; existing physical ownership is retained."
		_drop_planning_work(request)
		planning_revision += 1
		if not str(request.job).is_empty():
			var row: Dictionary = jobs.get(request.job,{})
			if not row.is_empty() and row.state == "Planning Route":
				row.planning_state = ""
				_block_route(row,request.phase,request.message)
	_planning_fifo.clear()
	_departure_requests.clear()


func pump_planning(allow_commit: bool, max_units: int = 128, budget_usec: int = 4000) -> bool:
	# Invoke only outside _settle at a fully settled shared-clock boundary.
	# Guards/capture/local approaches and hazard/danger callbacks are indivisible.
	if max_units <= 0 or budget_usec <= 0: return false
	var deadline: int = Time.get_ticks_usec()+budget_usec
	var units := 0
	while not _planning_fifo.is_empty() and _planning_fifo[0].state not in ["Pending","Ready"]:
		if units >= max_units or Time.get_ticks_usec() >= deadline: return false
		_planning_fifo.pop_front()
		units += 1
	if _planning_fifo.is_empty(): return false
	var request: Dictionary = _planning_fifo[0]
	while units < max_units and Time.get_ticks_usec() < deadline:
		if request.stage != "Capture" and (request.generation != _planning_generation or request.world != _rear().combat.world or request.revision != _rear().combat.world.revision):
			_reset_planning(request)
		if request.state == "Ready":
			if not allow_commit: return false
			return _commit_planning(request)
		if request.stage == "Capture":
			units += 1
			var guarded: Dictionary = _planning_guard(request)
			if not guarded.ok: return _deny_planning(request,guarded.message)
			request.capture = _planning_capture(request,guarded)
			request.world = _rear().combat.world
			request.revision = request.world.revision
			request.generation = _planning_generation
			if request.kind == "Supply Handling":
				request.state = "Ready"
				request.message = "Same physical handling captured; awaiting running-state continuation."
				planning_revision += 1
			else: request.stage = "Outward"
			continue
		if request.work == null:
			units += 1
			var points: Array = request.home if request.stage == "Homeward" else request.out
			var profile: Dictionary = {"world":request.world}
			if request.kind == "Supply Admission": profile.prospective_load_kg = request.capture.passenger_mass_kg
			request.work = Routes.begin_plan(_rear().ledger,request.hull,points,profile)
			continue
		if request.work.done:
			units += 1
			return _complete_planning_leg(request)
		var remaining_usec: int = deadline-Time.get_ticks_usec()
		if remaining_usec <= 0: return false
		var remaining: int = max_units-units
		request.work.step(remaining,remaining_usec)
		units += remaining # Conservative shared allowance; never reset per leg.
		if request.work.invalidated:
			_reset_planning(request)
		return false
	return false


func _complete_planning_leg(request: Dictionary) -> bool:
	var plan: Dictionary = request.work.result
	if not plan.ok:
		var prefix := "No legal outward route: " if request.stage == "Outward" else "No legal return route: "
		if request.kind == "Departure": prefix = "" if request.stage == "Outward" else "HQ return became illegal: "
		return _deny_planning(request,prefix+str(plan.reason))
	if request.stage == "Outward":
		request.outward = plan
		request.out_facts = request.work.input_facts
		request.work = null
		# Existing departure checks outward danger before planning its reserve.
		if request.kind == "Departure":
			var danger: String = _known_route_danger(request.hull,plan.parts)
			if not danger.is_empty(): return _deny_planning(request,danger)
		if request.kind == "Admission" or request.phase == "Outbound":
			request.stage = "Homeward"
		else: request.state = "Ready"
	else:
		request.homeward = plan
		request.home_facts = request.work.input_facts
		request.work = null
		request.state = "Ready"
	if request.state == "Ready":
		request.message = "Pure route plans ready; waiting for fresh running-state admission."
		if request.kind == "Departure":
			var row: Dictionary = jobs.get(request.job,{})
			if not row.is_empty() and row.state == "Planning Route":
				row.planning_state = "Ready"
				row.blocker = "Route ready; awaiting physical departure."
		planning_revision += 1
	return false


func _planning_descriptor(key: String, hull: String, squads: Array, board: String, dismount: String,
		out: Array, home: Array, intents: Dictionary) -> Dictionary:
	return {"key":key,"kind":"Admission","hull":hull,"squads":squads.duplicate(),"board":board,"dismount":dismount,
		"out":out.duplicate(),"home":home.duplicate(),"intents":intents.duplicate(true),"job":"","phase":"",
		"state":"Pending","message":"Waiting for pure route planning.","stage":"Capture","work":null,
		"capture":{},"outward":{},"homeward":{},"out_facts":{},"home_facts":{},"world":null,
		"revision":-1,"generation":_planning_generation}


func _reset_planning(request: Dictionary) -> void:
	if request.state != "Pending" or request.message != "Waiting for fresh route capture.": planning_revision += 1
	request.state = "Pending"
	request.stage = "Capture"
	request.message = "Waiting for fresh route capture."
	if request.kind == "Departure":
		var row: Dictionary = jobs.get(request.job,{})
		if not row.is_empty() and row.state == "Planning Route":
			row.planning_state = "Pending"
			row.blocker = "Planning a fresh route; existing physical trip remains committed."
	_drop_planning_work(request)
	request.generation = _planning_generation


func _drop_planning_work(request: Dictionary) -> void:
	request.work = null
	request.capture = {}
	request.outward = {}
	request.homeward = {}
	request.out_facts = {}
	request.home_facts = {}
	request.world = null


func _planning_guard(request: Dictionary) -> Dictionary:
	if request.has("authority"): return _supply_planning_guard(request)
	var rear: RefCounted = _rear()
	var organization: RefCounted = _organization()
	var hull: Dictionary = rear.ledger.inspect_entity(request.hull)
	var board: Dictionary = rear.ledger.inspect_entity(request.board,{},false)
	var dismount: Dictionary = rear.ledger.inspect_entity(request.dismount,{},false)
	if request.kind == "Admission":
		if hull_committed(request.hull) or (rear.forward_supply != null and rear.forward_supply.hull_committed(request.hull)):
			return _fail("Another physical transport activity already owns this hull.")
		if hull.get("kind","") != "CARRIER" or hull.get("design_type","") != "T02" or hull.get("fleet_domain","") != "Military" or not organization.vehicles.has(request.hull):
			return _fail("Choose one actually attached military T02.")
		if board.get("kind","") != "PLACE" or dismount.get("kind","") != "PLACE" or request.board == request.dismount or hull.holder_id != request.board or not hull.position.is_equal_approx(board.position):
			return _fail("Same stopped T02 must meet its passengers at a declared physical origin distinct from the dismount point.")
		if request.squads.is_empty() or request.squads.size() > 2 or not hull.passengers.is_empty() or not str(organization.vehicles[request.hull].passenger_squad).is_empty():
			return _fail("One T02 carries one or two separate unboarded squads, with no prior passenger commitment.")
		var checked: Dictionary = _manifest_people(hull,request.squads,request.board)
		if not checked.ok: return checked
		if rear.forward_supply != null:
			for id in checked.people:
				if rear.forward_supply._other_busy(id): return _fail("Passenger must finish its existing physical activity before transport commitment.")
		var admission_blocker: String = _movement_blocker(request.hull,hull)
		if not admission_blocker.is_empty(): return _fail(admission_blocker)
		var admission_error: String = _validate_points(request.out,hull.position,dismount.position)
		if admission_error.is_empty(): admission_error = _validate_points(request.home,dismount.position,board.position)
		if admission_error.is_empty(): admission_error = _planning_intent_error(request)
		if not admission_error.is_empty(): return _fail(admission_error)
		return {"ok":true,"hull":hull,"people":checked.people,"board":board,"dismount":dismount}
	var row: Dictionary = jobs.get(request.job,{})
	if row.is_empty() or row.state != "Planning Route" or row.planning_phase != request.phase:
		return _fail("This physical trip no longer owns the queued route departure.")
	if hull.get("kind","") != "CARRIER" or hull.get("design_type","") != "T02" or hull.get("fleet_domain","") != "Military" or not organization.vehicles.has(request.hull):
		return _fail("Choose one actually attached military T02.")
	for other in jobs.values():
		if other.id != row.id and other.hull == row.hull and other.state != "Complete": return _fail("Another physical transport activity already owns this hull.")
	if rear.forward_supply != null and rear.forward_supply.hull_committed(row.hull): return _fail("Another physical transport activity already owns this hull.")
	var blocker: String = _movement_blocker(request.hull,hull)
	if not blocker.is_empty(): return _fail(blocker)
	var destination: Dictionary = dismount if request.phase == "Outbound" else board
	if destination.get("kind","") != "PLACE": return _fail("The declared physical route destination no longer exists.")
	var error: String = _validate_points(request.out,hull.position,destination.position)
	if error.is_empty() and request.phase == "Outbound": error = _validate_points(request.home,dismount.position,board.get("position",Vector2.INF))
	if error.is_empty(): error = _planning_intent_error(request)
	if error.is_empty(): error = _departure_manifest_error(row,hull,request.phase)
	if not error.is_empty(): return _fail(error)
	return {"ok":true,"hull":hull,"people":row.people if request.phase == "Outbound" else [],"board":board,"dismount":dismount}


func _departure_manifest_error(row: Dictionary, hull: Dictionary, phase: String) -> String:
	if float(hull.contents_mass_kg) > float(hull.vehicle_spec.payload)+EPS:
		return "Actual passengers and their gear exceed the T02 payload mass."
	if phase == "Returning":
		if row.dismounted != row.people.size() or not hull.passengers.is_empty() or not _organization()._vehicle_squads(row.hull).is_empty():
			return "Same T02 must finish the actual dismount and release its passenger places before returning."
		return ""
	if row.boarded != row.people.size() or row.dismounted != 0 or hull.passengers.size() != row.people.size():
		return "Same T02 must retain its exact physically boarded passenger manifest."
	for squad_id in row.squads:
		var squad: Dictionary = _organization().squads.get(squad_id,{})
		if squad.get("vehicle","") != row.hull or squad.get("state","") != "Active" or squad.get("owner",_rear().PLAYER) != hull.owner:
			return "The same active owned passenger squads must remain reserved to this T02."
	for id in row.people:
		var person: Dictionary = _rear().ledger.inspect_person_status(id)
		if id not in hull.passengers or person.get("holder_id","") != row.hull or person.get("owner","") != hull.owner or person.get("assignment","") != "Formation Duty" or person.get("health",0) <= 0 or person.get("duty_id","") not in row.squads:
			return "Every named passenger must remain a living actual formation member aboard the same T02."
		if id not in _organization().squads[person.duty_id].roster:
			return "Every named passenger must remain in its actual reserved squad roster."
	return ""


func _planning_intent_error(request: Dictionary) -> String:
	for squad_id in request.intents:
		var intent: Dictionary = _rear().orders.intents.get(squad_id,{})
		if squad_id not in request.squads or intent.get("id","") != request.intents[squad_id] or intent.get("state","") != "Acknowledged" or intent.get("action","") != "Move by Transport":
			return "The same acknowledged Move by Transport intent is required before commitment."
	return ""


func _planning_capture(request: Dictionary, guarded: Dictionary) -> Dictionary:
	var people := {}
	for id in guarded.people: people[id] = _planning_person_facts(_rear().ledger.inspect_entity(id))
	var attachment := {}
	for key in ["owner","parent","passenger_squad","passenger_squads"]:
		var value: Variant = _organization().vehicles[request.hull].get(key)
		attachment[key] = value.duplicate() if value is Array else value
	return {"people":people,"people_order":guarded.people.duplicate(),"passenger_mass_kg":guarded.get("passenger_mass_kg",0.0),
		"attachment":attachment,"board":{"kind":guarded.board.get("kind",""),"position":guarded.board.get("position",Vector2.INF)},
		"dismount":{"kind":guarded.dismount.get("kind",""),"position":guarded.dismount.get("position",Vector2.INF)}}


func _planning_person_facts(person: Dictionary) -> Dictionary:
	var facts := {}
	for key in ["id","owner","holder_id","position","health","assignment","duty_id","pending_assignment","crew_station","qualification","basic_training","unit_mass_kg","contents_mass_kg"]:
		facts[key] = person.get(key)
	return facts


func _route_facts_match(facts: Dictionary, hull: Dictionary) -> bool:
	for key in ["kind","design_type","owner","controller","holder_id","position","unit_mass_kg","contents_mass_kg","fuel","health","damage_immobilized","towing","towed_by","vehicle_spec","crew_by_station","passengers","fleet_domain"]:
		if hull.get(key) != facts.hull.get(key): return false
	if _rear().ledger.route_hazard != facts.route_hazard: return false
	for id in facts.crew:
		var person: Dictionary = _rear().ledger.inspect_person_status(id)
		for key in facts.crew[id]:
			if person.get(key) != facts.crew[id][key]: return false
	return true


func _commit_planning(request: Dictionary) -> bool:
	var guarded: Dictionary = _planning_guard(request)
	if not guarded.ok: return _deny_planning(request,guarded.message)
	if request.world != _rear().combat.world or request.revision != request.world.revision:
		_reset_planning(request)
		return false
	if request.kind == "Supply Handling":
		if _planning_capture(request,guarded) != request.capture: return _deny_planning(request,"The actual interrupted passengers or stop changed before continuation.")
		return _commit_supply_handling(request,guarded)
	if not _route_facts_match(request.out_facts,guarded.hull) or (not request.home_facts.is_empty() and not _route_facts_match(request.home_facts,guarded.hull)) or _planning_capture(request,guarded) != request.capture:
		return _deny_planning(request,"Captured hull, load, crew, roster or endpoints changed; request fresh route planning.")
	var error := ""
	if _rear().ledger.route_hazard.is_valid(): error = str(_rear().ledger.route_hazard.call(guarded.hull.owner,request.out))
	if error.is_empty() and request.kind == "Departure": error = _known_route_danger(request.hull,request.outward.parts)
	if error.is_empty() and not request.homeward.is_empty() and _rear().ledger.route_hazard.is_valid(): error = str(_rear().ledger.route_hazard.call(guarded.hull.owner,request.home))
	if error.is_empty() and request.kind == "Admission":
		error = _known_route_danger(request.hull,request.outward.parts)
		if error.is_empty(): error = _known_route_danger(request.hull,request.homeward.parts)
	if error.is_empty() and request.has("authority"):
		error = _known_route_danger(request.hull,request.outward.parts)
		if error.is_empty() and not request.homeward.is_empty(): error = _known_route_danger(request.hull,request.homeward.parts)
	if not error.is_empty(): return _deny_planning(request,error)
	var required: float = float(request.outward.fuel)
	if not request.homeward.is_empty(): required += float(request.homeward.fuel)
	if float(guarded.hull.fuel)+EPS < required*1.25:
		return _deny_planning(request,"Actual T02 tank cannot cover the full trip and 25 percent reserve." if request.kind == "Admission" else "Actual tank lacks travel fuel plus 25 percent reserve.")
	if request.has("authority"): return _commit_supply_route(request,guarded)
	if request.kind == "Admission":
		var reserved: Dictionary = _organization()._reserve_transport_manifest(request.hull,request.squads)
		if not reserved.ok: return _deny_planning(request,reserved.message)
		_sequence += 1
		var id := "troop-trip-%04d" % _sequence
		jobs[id] = {"id":id,"kind":"Troop Trip","hull":request.hull,"owner":guarded.hull.owner,"squads":request.squads.duplicate(),"people":guarded.people,
			"board_place":request.board,"dismount_place":request.dismount,"outbound_points":request.out.duplicate(),"return_points":request.home.duplicate(),
			"boarded":0,"dismounted":0,"state":"Boarding","task":{},"route_plan":{},"route_points":[],"route_started":INF,
			"route_deadline":INF,"route_distance":0.0,"route_fuel":0.0,"route_expected":guarded.hull.position,"world_revision":request.revision,
			"paused_state":"","stopped_phase":"","blocker":"","return_completed":false,"intent_ids":request.intents.duplicate(true)}
		request.job = id
		request.admitted_at = _rear().time
		request.message = "The same T02 and its actual squad members are committed to timed boarding and travel."
	else:
		var row: Dictionary = jobs[request.job]
		row.state = request.phase
		row.route_plan = request.outward
		row.route_points = request.out.duplicate()
		row.route_started = _rear().time
		row.route_deadline = _rear().time+float(request.outward.seconds)
		row.route_distance = 0.0
		row.route_fuel = 0.0
		row.route_expected = guarded.hull.position
		row.world_revision = request.revision
		row.stopped_phase = ""
		row.planning_phase = ""
		row.planning_state = ""
		row.planning_points = []
		row.blocker = ""
		_departure_requests.erase(row.id)
		request.message = "Fresh physical route started."
	request.state = "Admitted"
	_drop_planning_work(request)
	planning_revision += 1
	return true


func _deny_planning(request: Dictionary, message: String) -> bool:
	request.state = "Blocked"
	request.message = message
	_drop_planning_work(request)
	planning_revision += 1
	if str(request.job).is_empty(): return false
	_departure_requests.erase(request.job)
	var row: Dictionary = jobs.get(request.job,{})
	if row.is_empty() or row.state != "Planning Route": return false
	row.planning_state = ""
	_block_route(row,request.phase,message)
	return true


func _queue_departure(row: Dictionary, points: Array, phase: String) -> bool:
	_discard_departure(row.id)
	if row.get("supply_mode",false):
		_queue_supply_continuation(row,points,row.return_points,row.supply_authority,phase,row.dismount_place)
		return true
	_planning_sequence += 1
	var request: Dictionary = _planning_descriptor("departure-%d" % _planning_sequence,row.hull,row.squads,row.board_place,row.dismount_place,points,row.return_points,
		row.get("intent_ids",{}) if phase == "Outbound" else {})
	request.kind = "Departure"
	request.job = row.id
	request.phase = phase
	_departure_requests[row.id] = request
	_planning_fifo.append(request)
	planning_revision += 1
	row.state = "Planning Route"
	row.planning_phase = phase
	row.planning_state = "Pending"
	row.planning_points = points.duplicate()
	row.route_deadline = INF
	row.blocker = "Planning a fresh route; existing physical trip remains committed."
	return true


func _discard_departure(job_id: String) -> void:
	var request: Dictionary = _departure_requests.get(job_id,{})
	if request.is_empty(): return
	request.state = "Cancelled"
	request.message = "Private departure planning interrupted; physical trip retained."
	var row: Dictionary = jobs.get(job_id,{})
	if not row.is_empty(): row.planning_state = ""
	_drop_planning_work(request)
	planning_revision += 1
	_departure_requests.erase(job_id)


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
	if row.is_empty() or row.state not in ["Boarding","Outbound","Dismounting","Returning","Planning Route"]:
		return _fail("Only an active physical troop trip can be interrupted.")
	if row.state == "Planning Route": _discard_departure(id)
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
	if row.get("supply_mode",false): return _fail("Supply movement needs resume_supply_job_deferred with the current exact acknowledged authority.")
	if row.is_empty() or row.state not in ["Paused","Blocked Route","Stranded"]:
		return _fail("Only a paused or physically blocked trip can resume.")
	var phase: String = row.paused_state if row.state == "Paused" else row.stopped_phase
	if phase == "Planning Route":
		_queue_departure(row,route_points if not route_points.is_empty() else row.planning_points,str(row.planning_phase))
		return {"ok":true,"pending":true,"message":"Fresh planning of the same physical departure queued."}
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
	if row.state == "Planning Route": return {"ok":true,"pending":true,"message":"Fresh route planning queued; the physical trip remains committed."}
	return {"ok":true,"message":"Same military hull resumes on a newly validated route from its actual position."}


func hull_committed(hull_id: String) -> bool:
	for row in jobs.values():
		if row.hull == hull_id and row.state != "Complete": return true
	return false


func person_committed(person_id: String) -> bool:
	for row in jobs.values():
		if row.get("supply_mode",false) and row.state != "Complete" and person_id in row.people: return true
		if row.state == "Planning Route" and row.planning_phase == "Outbound" and person_id in row.people: return true
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
		if row.get("supply_mode",false) and row.state in ["Boarding","Outbound","Dismounting"]:
			var error := _supply_live_error(row)
			if not error.is_empty():
				if row.state == "Outbound": _block_route(row,row.state,error)
				else: _pause_handling(row,error)
				continue
		if row.state in ["Outbound","Returning"]: _advance_route(row,at)
		elif row.state == "Boarding" and row.task.get("phase","") == "Approach": _advance_boarder(row,at)


func settle() -> bool:
	var changed := false
	for row in jobs.values():
		if row.get("supply_mode",false) and row.state in ["Boarding","Outbound","Dismounting"]:
			var error := _supply_live_error(row)
			if not error.is_empty():
				if row.state == "Outbound": _block_route(row,row.state,error)
				else: _pause_handling(row,error)
				changed = true
				continue
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
	var at_pickup: bool = hull.holder_id == row.board_place and person.holder_id == row.board_place
	if row.get("supply_mode",false): at_pickup = _rear().ledger.entity_kind(hull.holder_id) == "PLACE" and _rear().ledger.entity_kind(person.holder_id) == "PLACE" and hull.position.is_equal_approx(_rear().ledger.inspect_entity(row.board_place).position)
	if not at_pickup or person.position.distance_to(hull.position) > LOCAL_RADIUS+EPS or person.health <= 0:
		_pause_handling(row,"Next named passenger or T02 moved before boarding.")
		return true
	var leg: Dictionary = _foot_leg(person,hull.position)
	if not leg.ok: _pause_handling(row,"No safe local approach to stopped T02: " + str(leg.reason)); return true
	var walking: bool = float(leg.seconds) > EPS
	row.task = {"person":person.id,"phase":"Approach" if walking else "Board","started":_rear().time,
		"from":person.position,"to":hull.position,"expected":person.position,
		"holder":person.holder_id,"deadline":_rear().time+(float(leg.seconds) if walking else HANDLING_SECONDS)}
	row.blocker = "Approaching and boarding actual passenger %d/%d." % [row.boarded+1,row.people.size()]
	return true


func _finish_board(row: Dictionary) -> void:
	var person_id: String = row.task.person
	var hull: Dictionary = _rear().ledger.inspect_entity(row.hull)
	var person: Dictionary = _rear().ledger.inspect_entity(person_id)
	var at_pickup: bool = hull.holder_id == row.board_place and person.holder_id == row.board_place
	if row.get("supply_mode",false): at_pickup = _rear().ledger.entity_kind(hull.holder_id) == "PLACE" and _rear().ledger.entity_kind(person.holder_id) == "PLACE" and hull.position.is_equal_approx(_rear().ledger.inspect_entity(row.board_place).position)
	if not at_pickup or person.health <= 0 or not person.position.is_equal_approx(hull.position):
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
	var expected_holder: String = str(task.get("holder",row.board_place)) if row.get("supply_mode",false) else str(row.board_place)
	if person.holder_id != expected_holder or person.health <= 0 or not person.position.is_equal_approx(task.expected):
		_pause_handling(row,"Passenger changed position or activity during boarding approach.")
		return
	var fraction: float = clampf((at-float(task.started))/maxf(EPS,float(task.deadline)-float(task.started)),0.0,1.0)
	var position: Vector2 = task.from.lerp(task.to,fraction)
	var moved: Dictionary = _rear().ledger.move_entity(task.person,row.board_place,position)
	if moved.ok:
		task.expected = _rear().ledger.inspect_entity(task.person).position
		task.holder = row.board_place
	else: _pause_handling(row,moved.message)


func _foot_leg(person: Dictionary, destination: Vector2) -> Dictionary:
	if person.position.distance_to(destination) <= EPS: return {"ok":true,"seconds":0.0}
	return _rear().combat.world.route({"position":person.position,"facing":(destination-person.position).angle(),
		"size":Vector2(0.6,0.6),"movement_class":0,"base":2.0,"rate":0.0,
		"gross_mass_kg":float(person.unit_mass_kg)+float(person.contents_mass_kg)},destination)


func _schedule_dismount(row: Dictionary) -> bool:
	if row.dismounted >= row.people.size():
		for squad_id in row.squads: _organization()._release_transport_squad(row.hull,squad_id)
		if row.get("supply_mode",false):
			row.state = "Complete"
			row.return_completed = false
			row.blocker = "Actual cohort dismounted and squad place released at the real stop."
			return true
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
	if row.get("supply_mode",false): return _queue_departure(row,points,phase)
	if incremental_planning and row.kind == "Troop Trip" and rear.ledger.entity_design_type(row.hull) == "T02": return _queue_departure(row,points,phase)
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
		row.return_completed = not row.get("supply_mode",false)
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
	var bounds := {}
	var bounds_checked := false
	for target_id in rear.orders.contacts.get(company,{}):
		var contact: Dictionary = rear.orders.contact(company,target_id)
		if contact.is_empty() or float(contact.confidence) <= EPS or not contact.position.is_finite(): continue
		# Public objectives and unarmed transport hulls do not supply hostile
		# effective fire. Unknown people/armed contacts retain the conservative margin.
		if contact.get("class","") in ["Resource","Route Hub","Observation","T01","T02"]: continue
		var radius: float = float(THREAT_RANGE.get(str(contact.get("class","")),300.0))+float(contact.uncertainty_m)
		if not bounds_checked:
			bounds = _danger_bounds(parts)
			bounds_checked = true
		if not bounds.is_empty():
			var nearest: Vector2 = contact.position.clamp(bounds.low,bounds.high)
			if contact.position.distance_to(nearest) > radius+EPS: continue
		for part in parts:
			var from: Vector2 = part.from
			var to: Vector2 = part.to
			var along: float = clampf((contact.position-from).dot(to-from)/maxf(EPS,from.distance_squared_to(to)),0.0,1.0)
			if contact.position.distance_to(from.lerp(to,along)) <= radius+EPS:
				return "Observed hostile effective fire blocks an ordinary troop route; use a safe declared path."
	return ""


func _danger_bounds(parts: Array) -> Dictionary:
	if parts.is_empty(): return {}
	var low := Vector2.INF
	var high := -Vector2.INF
	for part in parts:
		if not (part is Dictionary) or not (part.get("from") is Vector2) or not (part.get("to") is Vector2): return {}
		var from: Vector2 = part.from
		var to: Vector2 = part.to
		if not from.is_finite() or not to.is_finite(): return {}
		# The pinned engine's component lerp is monotone over [0,1]. Use its
		# computed endpoints, including cancellation at weight one, rather than
		# assuming that endpoint equals `to`. Nonfinite arithmetic falls back.
		var first := from.lerp(to,0.0)
		var last := from.lerp(to,1.0)
		if not first.is_finite() or not last.is_finite(): return {}
		low = low.min(first).min(last)
		high = high.max(first).max(last)
	return {"low":low,"high":high}


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
		row.task.remaining_seconds = maxf(0.0,float(row.task.deadline)-_rear().time) if row.get("supply_mode",false) else HANDLING_SECONDS
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
		if row.state == "Complete" and (row.dismounted != row.people.size() or (row.get("return_required",true) and not row.return_completed)):
			errors.append("Completed military movement lacks its exact destination or dismount: " + row.id)
	return errors


func _rear() -> RefCounted:
	return _rear_ref.get_ref()


func _organization() -> RefCounted:
	return _organization_ref.get_ref()


func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
