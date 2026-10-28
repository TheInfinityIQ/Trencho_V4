extends RefCounted
## G03 owns staffing, timed local jobs and space promises; G01 owns physical facts.

const Ledger = preload("res://game/identity/identity_ledger.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Layout = preload("res://game/staffing/rear_layout.gd")
const Yard = preload("res://game/staffing/yard_activity.gd")
const PRIORITIES: Array[String] = ["Low", "Normal", "High", "Emergency"]
const PLAYER := "army-blue"
const EPS := 0.000001

var ledger := Ledger.new()
var yard: RefCounted
var time: float = 0.0
var stores: Dictionary = {}
var requests: Dictionary = {}
var actors: Dictionary = {}
var jobs: Array[Dictionary] = []
var _sequence: int = 0
var _events: Array[Dictionary] = []
var production: RefCounted # Optional G04 owner; null keeps the accepted G03 fixtures staged.
var munitions_production: RefCounted # Optional exclusive R02/R27 F05 owner on this same clock.
var materials_production: RefCounted # Optional fixed R26/F13 owner on this same clock.
var support_production: RefCounted # Explicit F09 owner; null in retained diagnostics.
var heavy_production: RefCounted # One F10 heavy bay/admission owner.
var training: RefCounted # Optional F06 elapsed-time courses; separate from operator-work.
var vehicles: RefCounted # Optional G07 handling on this same clock and actor pool.
var _output_promises: Dictionary = {}
var receiving: RefCounted # Optional integrated G02 activity; same ledger and joint boundaries.


func _init(fixture: String = "A05") -> void:
	ledger.add_place("rear", "Accessible rear working area", Vector2.ZERO)
	ledger.add_place("away", "Committed strategic trip outside the rear", Vector2(-1000, 0))
	for id in Layout.FACILITIES:
		var f: Array = Layout.FACILITIES[id]
		ledger.add_place("duty-" + id, f[0] + " staff entrance", f[4])
		requests[id] = {"id": id, "target": 0, "positions": f[3], "priority": 1, "created": 0.0, "order": _next(), "place": "duty-" + id}
	requests.hauling = {"id": "hauling", "target": 0, "positions": 120, "priority": 1, "created": 0.0, "order": _next(), "place": "duty-depot"}
	requests.yard = {"id": "yard", "target": 0, "positions": 1, "priority": 1, "created": 0.0, "order": _next(), "place": "yard-start"}
	for id in Layout.STORES:
		var definition: Array = Layout.STORES[id]
		ledger.add_place(id, id + " physical storage", Layout.door(definition[0]))
		stores[id] = {"id": id, "capacity": float(definition[1]), "accessible": true, "filter": [], "pile": false}
	yard = Yard.new(ledger)
	if fixture == "Empty":
		return
	for i in range(1, 5):
		add_person("worker-%02d" % i)
	add_person("instructor-01", true)
	add_person("driver-01", true, "P08")
	ledger.add_person("away-crew", "away", PLAYER, Records.Assignment.STRATEGIC_CREW, true, "P08")
	ledger.add_carrier("supplier-hull", "rear", "supplier", "supplier")
	ledger.add_person("supplier-driver", "supplier-hull", "supplier", Records.Assignment.STRATEGIC_CREW, true, "P08")
	if fixture == "Driver":
		ledger.move_entity("driver-01", "rear", Yard.START)
		set_target("yard", 1, 2)
	elif fixture in ["Carry", "Approach"]:
		ledger.move_entity("worker-01", "rear", Layout.door("depot"))
		var source := "depot" if fixture == "Carry" else "receiving"
		ledger.add_stock("fixture-metal", "M01", 50, 1.0, source, PLAYER)
		request_haul(source, "workshop_input", "M01", 50)
		set_target("hauling", 1)
	else:
		ledger.add_stock("fixture-metal", "M01", 2, 1.0, "depot", PLAYER)
		ledger.add_stock("fixture-components", "M02", 1, 1.0, "depot", PLAYER)
		request_haul("depot", "workshop_input", "M01", 2)
		request_haul("depot", "workshop_input", "M02", 1)
		set_target("workshop", 2)


func add_person(id: String, basic: bool = false, qualification: String = "None", at: String = "duty-personnel") -> Dictionary:
	var result: Dictionary = ledger.add_person(id, at, PLAYER, Records.Assignment.AVAILABLE, basic, qualification)
	if result.ok:
		actors[id] = {"id": id, "phase": "Available", "deadline": INF, "motion": {}, "load": {}, "blocked_since": -1.0}
		_rebalance()
		_settle()
	return result


func set_target(id: String, count: int, priority: int = 1) -> Dictionary:
	if not requests.has(id) or count < 0 or count > int(requests[id].positions) or priority < 0 or priority > 3:
		return _result(false, "Target must fit actual catalogue positions and a valid priority.")
	var r: Dictionary = requests[id]
	if r.target != count or r.priority != priority:
		r.created = time
		r.order = _next()
	r.target = count
	r.priority = priority
	var pending_allowed := maxi(0, count - _retaining(id))
	for person_id in actors:
		var p: Dictionary = ledger.inspect_entity(person_id)
		if p.pending_assignment != "None" and p.pending_duty == id:
			if pending_allowed > 0:
				pending_allowed -= 1
			else:
				ledger.cancel_assignment_request(person_id)
				reassign_person(person_id, "Available")
	_rebalance()
	_settle()
	return _result(true, "Target recorded; actual people must report before being present.")


func request_haul(source: String, destination: String, type: String, count: int, priority: int = 1) -> Dictionary:
	if not stores.has(source) or not stores.has(destination) or source == destination or type.is_empty() or count <= 0 or priority < 0 or priority > 3:
		return _result(false, "Hauling needs distinct actual stores, one type, positive count and priority.")
	var result := _queue_haul(source, destination, type, count, priority)
	_settle()
	return result


func _queue_haul(source: String, destination: String, type: String, count: int, priority: int, relocation: bool = false) -> Dictionary:
	var id := "job-%04d" % _next()
	jobs.append({"id": id, "source": source, "destination": destination, "type": type,
		"requested": count, "delivered": 0, "priority": priority, "created": time, "order": _sequence,
		"blocker": "", "cancelled": false, "recovery_sources": [], "selected": 0,
		"emergency_contention_since": -1.0, "relocation": relocation, "constraint_active": relocation})
	return {"ok": true, "message": "Demand recorded; no physical stock moved.", "id": id}


func cancel_job(id: String) -> Dictionary:
	var job := _job(id)
	if job.is_empty() or job.cancelled:
		return _result(false, "No active demand to cancel.")
	job.cancelled = true
	for actor in actors.values():
		if actor.load.get("job") == id:
			if actor.phase in ["Carry", "Drop"]:
				_reroute(actor)
			else:
				_release_load(actor)
	_settle()
	return _result(true, "Demand cancelled; real carried/deposited goods remain owned and recoverable.")


func reassign_person(id: String, destination: String) -> Dictionary:
	if not actors.has(id) or (destination != "Available" and not requests.has(destination)):
		return _result(false, "Choose an actual rear person and legal duty.")
	var p: Dictionary = ledger.inspect_entity(id)
	if p.assignment == "Training" and destination not in ["Available","students"]:
		return _result(false,"Withdraw the unfinished course before assigning this student to another duty; completed qualifications stay.")
	if not _eligible(p, destination):
		return _result(false, "The person is not qualified/available for this duty.")
	if p.pending_assignment != "None":
		return _result(p.pending_duty == destination or (destination == "Available" and p.pending_duty == ""), "Existing safe handoff remains pending; no second assignment created.")
	if destination != "Available" and _committed(destination) >= int(requests[destination].positions):
		return _result(false, "Every actual/pending position in that duty is occupied.")
	var a: Dictionary = actors[id]
	var assignment := Records.Assignment.AVAILABLE if destination == "Available" else (Records.Assignment.TRAINING if destination == "students" else Records.Assignment.REAR_LABOUR)
	var duty := "" if destination == "Available" else destination
	if not a.load.is_empty() and a.phase not in ["Carry", "Drop"]:
		_release_load(a)
	if a.phase == "Yard" and yard.state == "Entering station":
		yard.cancel_entry(id)
	if vehicles != null and vehicles.fuel_jobs.has(id) and destination != "fuel:" + vehicles.fuel_jobs[id].hull:
		vehicles.cancel_unpicked_fuel(id)
	if a.phase == "Vehicle Board":
		a.deadline = INF
	var result: Dictionary = ledger.request_assignment(id, assignment, duty)
	if not result.ok:
		return result
	if vehicles != null and p.duty_id.begins_with("crew:") and p.crew_station.is_empty() and requests.has(p.duty_id): requests[p.duty_id].target = 0
	if not p.crew_station.is_empty():
		if vehicles != null and vehicles.vehicles.has(p.holder_id): vehicles.request_exit(id)
		else: yard.request_exit()
	elif a.phase not in ["Carry", "Drop"] and ledger.inspect_entity(id).carrying_stock_id.is_empty():
		_report(a)
	return _result(true, "Duty requested; carrying or driving retains the old actual duty until safe handoff.")


func set_store(id: String, accessible: bool, capacity: float = -1.0, filter: Variant = null) -> Dictionary:
	if not stores.has(id) or not is_finite(capacity) or (filter != null and not filter is Array):
		return _result(false, "An actual store and finite capacity are required.")
	if receiving != null and id == "receiving":
		var edited_capacity: float = stores[id].capacity if capacity < 0 else capacity
		if edited_capacity + EPS < ledger.loose_stock_mass_at(id) + _reserved_space(id):
			return _result(false, "Edit refused: Receiving must retain its physical goods and complete inbound promises.")
		if receiving.reserved_storage_kg() > 0 and (not accessible or (filter != null and not filter.is_empty())):
			return _result(false, "Edit refused: unloaders retain promised Receiving access/type until safe deposit; wait for handling to finish.")
	for claim in _output_promises.values():
		if claim.store != id: continue
		var edited_capacity: float = stores[id].capacity if capacity < 0 else capacity
		var edited_filter: Array = stores[id].filter if filter == null else filter
		if edited_capacity + EPS < ledger.loose_stock_mass_at(id) + _reserved_space(id) or (not edited_filter.is_empty() and claim.type not in edited_filter):
			return _result(false, "Edit refused: active output promise " + claim.id + " requires its complete capacity/type; no part of the edit applied.")
	stores[id].accessible = accessible
	if capacity >= 0.0:
		stores[id].capacity = capacity
	if filter != null:
		stores[id].filter = filter.duplicate()
	for a in actors.values():
		if a.load.is_empty():
			continue
		if a.phase in ["Carry", "Drop"] and not _valid_destination(a.load.destination, a.load.type, a.load.mass, a.id):
			_reroute(a)
		elif a.phase in ["Approach", "Pickup"] and not stores[a.load.source].accessible:
			a.blocked_phase = a.phase
			a.blocked_remaining = maxf(0.0, a.deadline - time)
			a.phase = "Source blocked"
			a.motion = {}
			a.blocked_since = time
			a.deadline = time + 10.0
		elif a.phase == "Source blocked" and stores[a.load.source].accessible:
			if a.blocked_phase == "Pickup":
				a.phase = "Pickup"
				a.deadline = time + a.blocked_remaining
			else:
				_move(a, "Approach", Layout.path(ledger.inspect_entity(a.id).position, ledger.inspect_entity(a.load.source).position), 1.5)
			a.blocked_since = -1.0
		elif a.phase in ["Approach", "Pickup"] and not _valid_destination(a.load.destination, a.load.type, a.load.mass, a.id):
			_release_load(a)
	_settle()
	return _result(true, "Storage edited without deleting or moving any contents.")


func _reconcile_store(id: String) -> bool:
	var changed := false
	var needed_types: Array = []
	# Existing contents survive every edit; disallowed/excess stock creates relocation demand.
	var excess := maxf(0.0, ledger.loose_stock_mass_at(id) - float(stores[id].capacity))
	var contents: Dictionary = {}
	for stock in _stock_at(id):
		if not contents.has(stock.design_type): contents[stock.design_type] = {"quantity": 0, "mass": stock.unit_mass_kg, "position": stock.position}
		contents[stock.design_type].quantity += stock.quantity
	for type in contents:
		var stock: Dictionary = contents[type]
		var disallowed: bool = not stores[id].filter.is_empty() and type not in stores[id].filter
		if disallowed or excess > EPS:
			needed_types.append(type)
			var count: int = stock.quantity if disallowed else mini(stock.quantity, int(ceil(excess / stock.mass)))
			var destination := _nearest_storage(stock.position, type, minf(25.0, count * stock.mass), id)
			if destination.is_empty(): destination = "depot" if id != "depot" else "receiving"
			changed = _reconcile_relocation(id, destination, type, count) or changed
			excess = maxf(0.0, excess - count * stock.mass)
	for job in jobs:
		if job.relocation and job.source == id and job.type not in needed_types:
			job.constraint_active = false
	return changed


func _production_activities() -> Array[RefCounted]:
	# Explicit facility owners; one selected batch per facility.
	var activities: Array[RefCounted] = []
	if production != null: activities.append(production)
	if munitions_production != null: activities.append(munitions_production)
	if materials_production != null: activities.append(materials_production)
	if support_production != null: activities.append(support_production)
	if heavy_production != null: activities.append(heavy_production)
	return activities


func advance_time(seconds: float) -> Dictionary:
	if not is_finite(seconds) or seconds < 0.0:
		return _result(false, "Time must be finite and nonnegative.")
	var target := time + seconds
	_settle()
	while time < target - EPS:
		var next := minf(target, yard.deadline)
		if vehicles != null: next = minf(next,vehicles.next_boundary())
		if receiving != null: next = minf(next, receiving.next_boundary())
		if training != null: next = minf(next, training.next_boundary())
		for activity in _production_activities(): next = minf(next, activity.next_boundary())
		for a in actors.values():
			next = minf(next, a.deadline)
		for job in jobs:
			if not job.cancelled and job.delivered < job.requested and effective_priority(job) < 2:
				var boundary: float = job.created + (floor((time - job.created) / 60.0) + 1.0) * 60.0
				next = minf(next, boundary)
			if job.emergency_contention_since >= 0.0 and job.emergency_contention_since + 120.0 > time + EPS:
				next = minf(next, job.emergency_contention_since + 120.0)
		if next <= time + EPS:
			next = minf(target, time + EPS)
		for activity in _production_activities(): activity.advance_work(next - time)
		if training != null: training.advance_work(next - time)
		for a in actors.values():
			if not a.motion.is_empty():
				var distance: float = (next - a.motion.started) * a.motion.speed
				ledger.move_entity(a.id, "rear", Layout.position(a.motion.path, distance))
		yard.advance_to(next)
		if vehicles != null: vehicles.advance_to(next)
		ledger.advance_time(next - time)
		time = next
		if receiving != null: receiving.advance_clock_to(next)
		_settle()
	return _result(true, "Shared rear time advanced; each facility's prerequisites still govern operator work." if not _production_activities().is_empty() else "Only elapsed reporting, handling, walking and yard movement completed.")


func effective_priority(job: Dictionary) -> int:
	return 3 if job.priority == 3 else mini(2, job.priority + int(floor((time - job.created) / 60.0)))


func workshop_readiness() -> Dictionary:
	if production != null:
		var view: Dictionary = production.snapshot()
		return {"reference": "R01 physical production", "status": view.status, "missing": view.missing_local,
			"operators_present": view.operators.size(), "hauling_shortage": view.haul_shortage,
			"work": view.batch.get("work", 0.0), "consumed": ledger.snapshot().consumed,
			"output": view.physical_output, "complete_A05_passed": false}
	var missing: Dictionary = {}
	for type in {"M01": 2, "M02": 1}:
		var short: int = {"M01": 2, "M02": 1}[type] - ledger.available_stock_at("workshop_input", type)
		if short > 0:
			missing[type] = short
	var status := "Missing Inputs" if not missing.is_empty() else ("Missing Labour" if _present("workshop") == 0 else "Local inputs ready — G04 production not implemented")
	return {"reference": "R01 inputs only: 2 M01 + 1 M02", "status": status, "missing": missing,
		"operators_present": _present("workshop"), "hauling_shortage": _assigned("hauling") == 0 and not missing.is_empty(),
		"work": 0, "consumed": 0, "output": 0, "complete_A05_passed": false}


func _rebalance() -> void:
	# Plan counts by priority/share/age using actual eligible people, then retain
	# incumbents within those counts before requesting any safe transfers.
	var pool: Array = []
	for id in actors:
		var p: Dictionary = ledger.inspect_entity(id)
		if _eligible(p, "Available") and p.assignment != "Training" and p.pending_assignment == "None" and not p.duty_id.begins_with("crew:") and not p.duty_id.begins_with("fuel:"):
			pool.append(id)
	var pending: Dictionary = {}
	# A pending handoff occupies its destination target vacancy even though
	# the person still physically serves the old duty until safe completion.
	for id in actors:
		var person: Dictionary = ledger.inspect_entity(id)
		if person.pending_assignment != "None" and requests.has(person.pending_duty):
			pending[person.pending_duty] = int(pending.get(person.pending_duty, 0)) + 1
	var quotas: Dictionary = pending.duplicate()
	var planned: Dictionary = {}
	var remaining: Array = pool.duplicate()
	while not remaining.is_empty():
		var best: Dictionary = {}
		for r in requests.values():
			if r.get("manual",false): continue
			if int(quotas.get(r.id, 0)) >= int(r.target) or not _any_eligible(remaining, r.id):
				continue
			if best.is_empty() or _staff_before(r, best, quotas):
				best = r
		if best.is_empty():
			break
		var candidate := _choose_person(remaining, best.id)
		remaining.erase(candidate)
		planned[candidate] = best.id
		quotas[best.id] = int(quotas.get(best.id, 0)) + 1
	# Preserve present/reporting incumbents wherever possible. Pending carries
	# remain their old duty and cannot be counted as a second destination worker.
	var keep: Dictionary = pending.duplicate()
	var free: Array = []
	for id in pool:
		var duty: String = ledger.inspect_entity(id).duty_id
		if not duty.is_empty() and planned.get(id, "") == duty and int(keep.get(duty, 0)) < int(quotas.get(duty, 0)):
			keep[duty] = int(keep.get(duty, 0)) + 1
		else:
			free.append(id)
	var ordered: Array = requests.values()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority: return a.priority > b.priority
		# Qualified roles are filled from compatible free people first.
		if (a.id in ["yard", "training"]) != (b.id in ["yard", "training"]): return a.id in ["yard", "training"]
		return a.order < b.order)
	for r in ordered:
		while int(keep.get(r.id, 0)) < int(quotas.get(r.id, 0)) and _any_eligible(free, r.id):
			var id := _choose_person(free, r.id)
			free.erase(id)
			reassign_person(id, r.id)
			keep[r.id] = int(keep.get(r.id, 0)) + 1
	for id in free:
		if ledger.inspect_entity(id).assignment != "Available":
			reassign_person(id, "Available")


func _staff_before(a: Dictionary, b: Dictionary, counts: Dictionary) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	var a_share: float = float(a.target - int(counts.get(a.id, 0))) / a.target
	var b_share: float = float(b.target - int(counts.get(b.id, 0))) / b.target
	if not is_equal_approx(a_share, b_share):
		return a_share > b_share
	return a.order < b.order


func _eligible(p: Dictionary, duty: String) -> bool:
	if p.is_empty() or p.owner != PLAYER or p.assignment not in (["Available", "Rear Labour", "Training"] if duty in ["Available","students"] else ["Available", "Rear Labour"]) or p.health <= 0 or not actors.has(p.id):
		return false
	if not Rect2(0, 0, 240, 180).has_point(p.position):
		return false
	if requests.has(duty) and requests[duty].get("manual",false):
		return vehicles != null and vehicles.eligible(p,duty)
	if duty == "yard":
		return p.basic_training and p.qualification == "P08"
	if duty == "training":
		return p.basic_training
	return true


func _any_eligible(ids: Array, duty: String) -> bool:
	for id in ids:
		if _eligible(ledger.inspect_entity(id), duty): return true
	return false


func _choose_person(ids: Array, duty: String) -> String:
	var candidates: Array = ids.filter(func(id: String) -> bool: return _eligible(ledger.inspect_entity(id), duty))
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var first: Dictionary = ledger.inspect_entity(a)
		var second: Dictionary = ledger.inspect_entity(b)
		var rank_a := (2 if first.qualification != "None" else (1 if first.basic_training else 0))
		var rank_b := (2 if second.qualification != "None" else (1 if second.basic_training else 0))
		if (first.duty_id == duty) != (second.duty_id == duty): return first.duty_id == duty
		if (first.assignment == "Available") != (second.assignment == "Available"): return first.assignment == "Available"
		if rank_a != rank_b: return rank_a < rank_b
		return a < b)
	return candidates[0]


func _report(a: Dictionary) -> void:
	var p: Dictionary = ledger.inspect_entity(a.id)
	a.load = {}
	a.motion = {}
	a.deadline = INF
	if p.duty_id.is_empty():
		a.phase = "Available"
		return
	var path: Array = []
	if vehicles != null and requests[p.duty_id].get("manual",false):
		path = vehicles.report_path(a.id,p.duty_id)
	else:
		var destination: Vector2 = ledger.inspect_entity("yard-t01").position if p.duty_id == "yard" else (training.student_position(a.id) if p.duty_id == "students" and training != null else ledger.inspect_entity(requests[p.duty_id].place).position)
		if heavy_production != null and heavy_production.bay_occupant != "" and p.position.is_equal_approx(ledger.inspect_entity(heavy_production.bay_occupant).position):
			path = [p.position,Layout.door("vehicle_works")]
			var outward: Array = Layout.path(Layout.door("vehicle_works"),destination)
			if not outward.is_empty(): path.append_array(outward.slice(1))
		else: path = Layout.path(p.position,destination)
	_move(a, "Reporting", path, 1.5)


func _move(a: Dictionary, phase: String, points: Array, speed: float) -> void:
	a.phase = phase
	if points.is_empty():
		a.motion = {}
		a.deadline = INF
		a.phase = "Route blocked"
		return
	a.motion = {"path": points, "started": time, "speed": speed}
	a.deadline = time + Layout.length(points) / speed


func _settle() -> void:
	if receiving != null:
		receiving._pump()
		_sync_receiving_people()
	for _iteration in 1000:
		var changed: bool = yard.complete_due()
		if vehicles != null: changed = vehicles.settle() or changed
		for a in actors.values():
			if a.deadline <= time + EPS:
				_finish_phase(a)
				changed = true
			if a.phase == "Yard" and yard.driver.is_empty():
				_report(a)
				if ledger.inspect_entity(a.id).duty_id.is_empty(): _rebalance()
				changed = true
		# Resolve physical constraints after every promise/handling boundary,
		# before selecting new work. No per-frame or recursive scheduling loop.
		for id in stores.keys():
			changed = _reconcile_store(id) or changed
		for a in actors.values():
			var p: Dictionary = ledger.inspect_entity(a.id)
			if a.phase == "Idle" and p.duty_id == "hauling":
				changed = _start_job(a) or changed
		if receiving != null: _sync_receiving_staff()
		for activity in _production_activities(): changed = activity.settle() or changed
		if training != null: changed = training.settle() or changed
		if not changed:
			_refresh_contention()
			return
	push_error("Rear activity failed to settle finite immediate boundaries.")


func _sync_receiving_people() -> void:
	var added := false
	var released := false
	for p in ledger.snapshot().entities:
		if p.kind == "PERSON" and p.owner == PLAYER and not actors.has(p.id) and p.assignment == "Available":
			actors[p.id] = {"id": p.id, "phase": "Available", "deadline": INF, "motion": {}, "load": {}, "blocked_since": -1.0}
			added = true
	for a in actors.values():
		if a.phase == "Unloading" and not receiving._workers.has(a.id):
			_report(a)
			# Match hauling: a released Available person fills outstanding targets;
			# a specific requested destination retains its direct handoff.
			released = released or ledger.inspect_entity(a.id).duty_id.is_empty()
	if added or released: _rebalance()


func _sync_receiving_staff() -> void:
	for a in actors.values():
		var p: Dictionary = ledger.inspect_entity(a.id)
		if p.duty_id == "receiving" and p.pending_assignment == "None" and a.phase == "Idle":
			receiving._workers[a.id] = {"person_id": a.id, "job": {}}
			a.phase = "Unloading"
	receiving._pump()


func _finish_phase(a: Dictionary) -> void:
	a.deadline = INF
	if not a.motion.is_empty():
		ledger.move_entity(a.id, "rear", a.motion.path.back())
	a.motion = {}
	match a.phase:
		"Reporting":
			if ledger.inspect_entity(a.id).duty_id == "yard":
				var result: Dictionary = yard.board(a.id)
				a.phase = "Yard" if result.ok else "Yard blocked"
			elif vehicles != null and ledger.inspect_entity(a.id).duty_id.begins_with("crew:"):
				var result: Dictionary = vehicles.begin_board(a.id)
				if not result.ok: a.phase = "Vehicle Blocked"
			elif vehicles != null and ledger.inspect_entity(a.id).duty_id.begins_with("fuel:"):
				vehicles.begin_fuel_pickup(a.id)
			else:
				a.phase = "Idle"
		"Vehicle Board":
			var result: Dictionary = vehicles.complete_board(a.id)
			a.phase = "Vehicle Station" if result.ok else "Vehicle Blocked"
		"Vehicle Exit":
			var result: Dictionary = vehicles.complete_exit(a.id)
			if result.ok:
				_report(a)
				if ledger.inspect_entity(a.id).duty_id.is_empty(): _rebalance()
			else: a.phase = "Vehicle Station"
		"Vehicle Fuel Pickup":
			var result: Dictionary = vehicles.complete_fuel_pickup(a.id)
			if not result.ok: a.phase = "Vehicle Fuel Blocked"
		"Vehicle Fuel Carry":
			vehicles.begin_fuel_deposit(a.id)
		"Vehicle Fuel Deposit":
			var result: Dictionary = vehicles.complete_fuel_deposit(a.id)
			if result.ok:
				if ledger.inspect_entity(a.id).duty_id.begins_with("fuel:"): reassign_person(a.id,"Available")
				else: _report(a)
			else: a.phase = "Vehicle Fuel Blocked"
		"Approach":
			a.phase = "Pickup"
			a.deadline = time + 2.0
		"Pickup":
			var result: Dictionary = ledger.begin_carry(a.id, a.load.stock, a.load.count, a.load.claim)
			if not result.ok:
				_job(a.load.job).blocker = result.message
				_release_load(a)
			else:
				a.load.carried = result.entity_id
				a.load.claim = ""
				_move(a, "Carry", Layout.path(ledger.inspect_entity(a.id).position, ledger.inspect_entity(a.load.destination).position), 1.2)
		"Carry":
			a.phase = "Drop"
			a.deadline = time + 2.0
		"Drop":
			_deposit(a)
		"Source blocked":
			_job(a.load.job).blocker = "Source unreachable for 10 seconds; claim released, demand retained"
			_job(a.load.job).source_release_at = time
			_release_load(a)


func _start_job(a: Dictionary) -> bool:
	var person: Dictionary = ledger.inspect_entity(a.id)
	if person.pending_assignment != "None":
		return false
	var best: Dictionary = {}
	for job in jobs:
		if job.cancelled or job.delivered + _in_flight(job.id) >= job.requested:
			continue
		var option := _job_option(job, person)
		if option.is_empty():
			continue
		if best.is_empty() or _job_before(option, best):
			best = option
	if best.is_empty():
		return false
	var job: Dictionary = best.job
	var claim := "haul-claim-%04d" % _next()
	var result: Dictionary = ledger.request_stock(claim, best.stock.id, best.count, a.id, job.id, PLAYER)
	if not result.ok or ledger.inspect_claim(claim).reserved != best.count:
		push_error("Atomic haul reservation failed: " + str(result))
		return false
	a.load = {"job": job.id, "claim": claim, "stock": best.stock.id,
		"source": best.stock.holder_id, "destination": job.destination,
		"type": job.type, "count": best.count, "mass": best.count * best.stock.unit_mass_kg, "carried": ""}
	job.selected += 1
	job.blocker = "Approach/pickup/carry/deposit required; reservation is not local stock"
	_move(a, "Approach", best.approach, 1.5)
	_events.append({"time": time, "person": a.id, "job": job.id, "priority": effective_priority(job), "description": "Selected real eligible haul"})
	return true


func _job_option(job: Dictionary, person: Dictionary) -> Dictionary:
	if not stores.has(job.destination) or not stores[job.destination].accessible:
		job.blocker = "Destination inaccessible; demand retained"
		return {}
	var best: Dictionary = {}
	var source_ids: Array = [job.source]
	source_ids.append_array(job.recovery_sources)
	for source_id in source_ids:
		if not stores.has(source_id) or not stores[source_id].accessible or source_id == job.destination:
			continue
		for stock in _stock_at(source_id):
			if stock.design_type != job.type or stock.available <= 0:
				continue
			var count := mini(stock.available, job.requested - job.delivered - _in_flight(job.id))
			count = mini(count, int(floor((25.0 - person.contents_mass_kg) / stock.unit_mass_kg)))
			count = mini(count, int(floor(_free_space(job.destination) / stock.unit_mass_kg)))
			if count <= 0 or not _valid_destination(job.destination, job.type, count * stock.unit_mass_kg):
				continue
			var approach: Array = Layout.path(person.position, stock.position)
			var carry: Array = Layout.path(stock.position, ledger.inspect_entity(job.destination).position)
			if approach.is_empty() or carry.is_empty():
				continue
			var distance := Layout.length(approach) + Layout.length(carry)
			if best.is_empty() or distance < float(best.distance):
				best = {"job": job, "stock": stock, "count": count, "approach": approach, "distance": distance}
	if best.is_empty():
		job.blocker = ("Source unreachable for 10 seconds; claim released, demand retained. " if job.has("source_release_at") else "") + "No accessible unreserved source, remaining personal allowance or accepting destination space"
	return best


func _job_before(a: Dictionary, b: Dictionary) -> bool:
	var first := effective_priority(a.job)
	var second := effective_priority(b.job)
	if first != second: return first > second
	if not is_equal_approx(a.distance, b.distance): return a.distance < b.distance
	return a.job.order < b.job.order


func _in_flight(job_id: String) -> int:
	var count: int = 0
	for a in actors.values():
		if a.load.get("job") == job_id: count += a.load.count
	return count


func _reserved_space(destination: String, except_person: String = "", include_output: bool = true) -> float:
	var total: float = receiving.reserved_storage_kg() if receiving != null and destination == "receiving" else 0.0
	for a in actors.values():
		if a.id != except_person and a.load.get("destination") == destination:
			total += a.load.mass
	if include_output:
		for claim in _output_promises.values():
			if claim.store == destination: total += claim.mass
	return total


func reserve_output_space(id: String, destination: String, type: String, mass: float) -> Dictionary:
	if id.is_empty() or _output_promises.has(id) or not is_finite(mass) or mass <= 0 or not _valid_destination(destination, type, mass):
		return _result(false, "Output Full: complete valid output capacity must be free before consumption.")
	_output_promises[id] = {"id": id, "store": destination, "type": type, "mass": mass}
	return _result(true, "Full output capacity promised to " + id)


func release_output_space(id: String) -> void:
	_output_promises.erase(id)


func output_space_valid(id: String) -> bool:
	if not _output_promises.has(id): return false
	var claim: Dictionary = _output_promises[id]
	var store: Dictionary = stores[claim.store]
	return store.accessible and (store.filter.is_empty() or claim.type in store.filter) and ledger.loose_stock_mass_at(claim.store) + _reserved_space(claim.store) <= float(store.capacity) + EPS


func _free_space(id: String, except_person: String = "") -> float:
	return maxf(0.0, float(stores[id].capacity) - ledger.loose_stock_mass_at(id) - _reserved_space(id, except_person))


func _valid_destination(id: String, type: String, mass: float, except_person: String = "") -> bool:
	return stores.has(id) and stores[id].accessible and (stores[id].filter.is_empty() or type in stores[id].filter) and _free_space(id, except_person) + EPS >= mass


func _nearest_storage(origin: Vector2, type: String, mass: float, excluded: String = "", person: String = "") -> String:
	var selected := ""
	var distance: float = INF
	for id in stores:
		if id == excluded or stores[id].pile or not _valid_destination(id, type, mass, person):
			continue
		var route: Array = Layout.path(origin, ledger.inspect_entity(id).position)
		if route.is_empty(): continue
		var length := Layout.length(route)
		if length < distance - EPS or (is_equal_approx(length, distance) and (selected.is_empty() or id < selected)):
			distance = length
			selected = id
	return selected


func _reroute(a: Dictionary) -> void:
	if a.load.is_empty(): return
	var origin: Vector2 = ledger.inspect_entity(a.id).position
	var destination := _nearest_storage(origin, a.load.type, a.load.mass, a.load.destination, a.id)
	if destination.is_empty():
		destination = "pile-%04d" % _next()
		ledger.add_place(destination, "Marked recoverable temporary pile; real handling required", origin)
		stores[destination] = {"id": destination, "capacity": a.load.mass, "accessible": true, "filter": [a.load.type], "pile": true}
	a.load.destination = destination
	_job(a.load.job).blocker = "Destination changed; safe delivery to " + destination + ", original demand remains"
	_move(a, "Carry", Layout.path(origin, ledger.inspect_entity(destination).position), 1.2)


func _deposit(a: Dictionary) -> void:
	if not _valid_destination(a.load.destination, a.load.type, a.load.mass, a.id):
		_reroute(a)
		return
	var load: Dictionary = a.load.duplicate(true)
	var result: Dictionary = ledger.finish_carry(a.id, load.destination)
	if not result.ok:
		push_error("Safe hauling deposit failed: " + str(result))
		return
	var job := _job(load.job)
	if load.destination == job.destination and not job.cancelled:
		job.delivered += load.count
		job.blocker = "Complete" if job.delivered == job.requested else "Remaining physical demand"
	elif not job.cancelled and load.destination not in job.recovery_sources:
		job.recovery_sources.append(load.destination)
	_events.append({"time": time, "person": a.id, "job": load.job, "destination": load.destination, "count": load.count, "description": "Physical deposit"})
	a.load = {}
	var person: Dictionary = ledger.inspect_entity(a.id)
	if person.duty_id != "hauling":
		_report(a)
		if person.duty_id.is_empty(): _rebalance()
	else:
		a.phase = "Idle"
		a.motion = {}
		a.deadline = INF


func _release_load(a: Dictionary) -> void:
	if not a.load.get("claim", "").is_empty():
		ledger.release_claim(a.load.claim)
	a.load = {}
	a.phase = "Idle"
	a.motion = {}
	a.deadline = INF
	a.blocked_since = -1.0


func _stock_at(holder: String) -> Array:
	return ledger.snapshot().entities.filter(func(e: Dictionary) -> bool: return e.kind == "STOCK" and e.owner == PLAYER and e.holder_id == holder and e.quantity > 0)


func _reconcile_relocation(source: String, destination: String, type: String, physical_needed: int) -> bool:
	var existing: Dictionary = {}
	for job in jobs:
		if job.relocation and not job.cancelled and job.source == source and job.type == type and (job.delivered < job.requested or job.constraint_active):
			existing = job
			break
	var carried: int = 0
	var other_promised: int = 0
	for actor in actors.values():
		var load: Dictionary = actor.load
		if load.is_empty() or load.source != source or load.type != type:
			continue
		if not existing.is_empty() and load.job == existing.id:
			if not load.carried.is_empty(): carried += load.count
		elif load.carried.is_empty():
			other_promised += load.count
	# Physical source contents already include unpicked claims, but exclude
	# freight carried away. Extend total demand, never add that same claim twice.
	var needed := maxi(0, physical_needed - other_promised)
	if existing.is_empty():
		if needed == 0: return false
		_queue_haul(source, destination, type, needed, 1, true)
		return true
	else:
		# A nominally delivered subrequest retains lineage while the source
		# constraint still relies on another outgoing promise. Only physical
		# compliance ends that constraint, so withdrawn promises cannot reset age.
		existing.constraint_active = true
		var requested: int = maxi(existing.requested, existing.delivered + carried + needed)
		var changed: bool = requested != existing.requested
		existing.requested = requested
		return changed


func snapshot() -> Dictionary:
	var staffing: Array[Dictionary] = []
	for r in requests.values():
		var assigned := _assigned(r.id)
		var present := _present(r.id)
		var pending := _pending_in(r.id)
		staffing.append({"id": r.id, "target": r.target, "positions": r.positions,
			"assigned": assigned, "pending_in": pending, "present": present, "reporting_or_active": assigned - present,
			"shortage": maxi(0, r.target - _retaining(r.id) - pending), "priority": PRIORITIES[r.priority], "requested_at": r.created})
	var people: Array[Dictionary] = []
	for entity in ledger.snapshot().entities:
		if entity.kind != "PERSON": continue
		var p: Dictionary = entity.duplicate(true)
		p.phase = actors[p.id].phase if actors.has(p.id) else "External/away — ineligible"
		p.load = actors[p.id].load.duplicate(true) if actors.has(p.id) else {}
		people.append(p)
	var storage: Array[Dictionary] = []
	for store in stores.values():
		var row: Dictionary = store.duplicate(true)
		row.position = ledger.inspect_entity(store.id).position
		row.physical_kg = ledger.loose_stock_mass_at(store.id)
		row.reserved_inbound_kg = _reserved_space(store.id, "", false)
		row.reserved_output_kg = _reserved_space(store.id) - row.reserved_inbound_kg
		row.free_kg = _free_space(store.id)
		row.stocks = _stock_at(store.id)
		row.reserved_outbound = 0
		for stock in row.stocks: row.reserved_outbound += stock.reserved
		storage.append(row)
	var inspected_jobs: Array[Dictionary] = jobs.duplicate(true)
	for job in inspected_jobs:
		job.age = time - job.created
		job.effective_priority = PRIORITIES[effective_priority(job)]
		job.in_flight = _in_flight(job.id)
		job.emergency_wait_seconds = maxf(0.0, time - job.emergency_contention_since) if job.emergency_contention_since >= 0.0 else 0.0
		job.starved = job.emergency_contention_since >= 0.0 and job.emergency_wait_seconds >= 120.0
		if job.starved: job.blocker = "Starved by explicit Emergency work for at least 120 seconds"
	return {"time": time, "staffing": staffing, "people": people, "stores": storage,
		"jobs": inspected_jobs, "workshop": workshop_readiness(), "yard": yard.snapshot(),
		"audit": audit(), "ledger": ledger.snapshot(), "events": _events.duplicate(true)}


func _refresh_contention() -> void:
	for job in jobs:
		var contended: bool = not job.cancelled and job.priority != 3 and job.delivered + _in_flight(job.id) < job.requested and _waiting_job_viable(job)
		if contended and job.emergency_contention_since < 0.0:
			job.emergency_contention_since = time
		elif not contended:
			job.emergency_contention_since = -1.0


func _waiting_job_viable(job: Dictionary) -> bool:
	# Count actual eligible Emergency contention, not unrelated demand age or
	# missing staff/access/capacity. Active freight is removed only from this
	# detached eligibility view, never from the actual personal holder.
	for id in actors:
		var p: Dictionary = ledger.inspect_entity(id)
		var actor: Dictionary = actors[id]
		if p.duty_id != "hauling" or actor.load.is_empty() or actor.phase == "Source blocked" or p.pending_assignment != "None" or _job(actor.load.job).priority != 3:
			continue
		if not p.carrying_stock_id.is_empty():
			var freight: Dictionary = ledger.inspect_entity(p.carrying_stock_id)
			p.contents_mass_kg -= freight.quantity * freight.unit_mass_kg
		if not _job_option(job.duplicate(true), p).is_empty(): return true
	return false


func audit() -> Array[String]:
	var failures: Array[String] = ledger.audit()
	if heavy_production != null: failures.append_array(heavy_production.audit())
	if vehicles != null: failures.append_array(vehicles.audit())
	if training != null: failures.append_array(training.audit())
	for a in actors.values():
		var p: Dictionary = ledger.inspect_entity(a.id)
		if not a.load.is_empty():
			if a.load.mass + p.contents_mass_kg > 25.0 + EPS and a.phase not in ["Carry", "Drop"]:
				failures.append("Reserved load exceeds retained gear allowance: " + a.id)
			if p.contents_mass_kg > 25.0 + EPS: failures.append("Overweight person: " + a.id)
			if a.phase in ["Carry", "Drop"] and p.carrying_stock_id.is_empty(): failures.append("Carry lacks physical goods: " + a.id)
	for job in jobs:
		if job.delivered < 0 or job.delivered + _in_flight(job.id) > job.requested:
			failures.append("Demand overfilled: " + job.id)
	for r in requests.values():
		if _assigned(r.id) > int(r.positions): failures.append("Too many actual staff positions: " + r.id)
		if _retaining(r.id) + _pending_in(r.id) > int(r.positions): failures.append("Overbooked pending staff positions: " + r.id)
	if not is_equal_approx(yard.fuel + yard.burned, 40.0) or yard.fuel < 0.0:
		failures.append("Yard fuel conservation")
	return failures


func _assigned(duty: String) -> int:
	var count: int = 0
	for id in actors:
		if ledger.inspect_entity(id).duty_id == duty: count += 1
	return count


func _committed(duty: String) -> int:
	var count := _assigned(duty)
	for id in actors:
		if ledger.inspect_entity(id).pending_duty == duty: count += 1
	return count


func _pending_in(duty: String) -> int:
	var count: int = 0
	for id in actors:
		var p: Dictionary = ledger.inspect_entity(id)
		if p.pending_assignment != "None" and p.pending_duty == duty: count += 1
	return count


func _retaining(duty: String) -> int:
	var count: int = 0
	for id in actors:
		var p: Dictionary = ledger.inspect_entity(id)
		if p.duty_id == duty and (p.pending_assignment == "None" or p.pending_duty == duty): count += 1
	return count


func _present(duty: String) -> int:
	var count: int = 0
	for id in actors:
		if ledger.inspect_entity(id).duty_id == duty and actors[id].phase in ["Idle", "Unloading"]: count += 1
	return count


func _job(id: String) -> Dictionary:
	for job in jobs:
		if job.id == id: return job
	return {}


func _next() -> int:
	_sequence += 1
	return _sequence


func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
