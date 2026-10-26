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
	var pending_allowed := maxi(0, count - _assigned(id))
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
	var id := "job-%04d" % _next()
	jobs.append({"id": id, "source": source, "destination": destination, "type": type,
		"requested": count, "delivered": 0, "priority": priority, "created": time, "order": _sequence,
		"blocker": "", "cancelled": false, "recovery_sources": [], "selected": 0})
	_settle()
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
	if not _eligible(p, destination):
		return _result(false, "The person is not qualified/available for this duty.")
	if p.pending_assignment != "None":
		return _result(p.pending_duty == destination or (destination == "Available" and p.pending_duty == ""), "Existing safe handoff remains pending; no second assignment created.")
	if destination != "Available" and _committed(destination) >= int(requests[destination].positions):
		return _result(false, "Every actual/pending position in that duty is occupied.")
	var a: Dictionary = actors[id]
	var assignment := Records.Assignment.AVAILABLE if destination == "Available" else Records.Assignment.REAR_LABOUR
	var duty := "" if destination == "Available" else destination
	if not a.load.is_empty() and a.phase not in ["Carry", "Drop"]:
		_release_load(a)
	if a.phase == "Yard" and yard.state == "Entering station":
		yard.cancel_entry(id)
	var result: Dictionary = ledger.request_assignment(id, assignment, duty)
	if not result.ok:
		return result
	if not p.crew_station.is_empty():
		yard.request_exit()
	elif a.phase not in ["Carry", "Drop"]:
		_report(a)
	return _result(true, "Duty requested; carrying or driving retains the old actual duty until safe handoff.")


func set_store(id: String, accessible: bool, capacity: float = -1.0, filter: Array = []) -> Dictionary:
	if not stores.has(id) or not is_finite(capacity):
		return _result(false, "An actual store and finite capacity are required.")
	stores[id].accessible = accessible
	if capacity >= 0.0:
		stores[id].capacity = capacity
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
	# Existing contents survive every edit; disallowed/excess stock creates relocation demand.
	var excess := maxf(0.0, ledger.loose_stock_mass_at(id) - float(stores[id].capacity))
	for stock in _stock_at(id):
		if (not filter.is_empty() and stock.design_type not in filter) or excess > EPS:
			var count: int = stock.quantity if not filter.is_empty() and stock.design_type not in filter else mini(stock.quantity, int(ceil(excess / stock.unit_mass_kg)))
			var destination := _nearest_storage(stock.position, stock.design_type, minf(25.0, count * stock.unit_mass_kg), id)
			if not destination.is_empty() and not _has_relocation(id, stock.design_type):
				var demand := request_haul(id, destination, stock.design_type, count)
				_job(demand.id).relocation = true
			excess = maxf(0.0, excess - count * stock.unit_mass_kg)
	_settle()
	return _result(true, "Storage edited without deleting or moving any contents.")


func advance_time(seconds: float) -> Dictionary:
	if not is_finite(seconds) or seconds < 0.0:
		return _result(false, "Time must be finite and nonnegative.")
	var target := time + seconds
	_settle()
	while time < target - EPS:
		var next := minf(target, yard.deadline)
		for a in actors.values():
			next = minf(next, a.deadline)
		for job in jobs:
			if not job.cancelled and job.delivered < job.requested and effective_priority(job) < 2:
				var boundary: float = job.created + (floor((time - job.created) / 60.0) + 1.0) * 60.0
				next = minf(next, boundary)
		if next <= time + EPS:
			next = minf(target, time + EPS)
		for a in actors.values():
			if not a.motion.is_empty():
				var distance: float = (next - a.motion.started) * a.motion.speed
				ledger.move_entity(a.id, "rear", Layout.position(a.motion.path, distance))
		yard.advance_to(next)
		ledger.advance_time(next - time)
		time = next
		_settle()
	return _result(true, "Only elapsed reporting, handling, walking and yard movement completed.")


func effective_priority(job: Dictionary) -> int:
	return 3 if job.priority == 3 else mini(2, job.priority + int(floor((time - job.created) / 60.0)))


func workshop_readiness() -> Dictionary:
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
		if _eligible(p, "Available") and p.pending_assignment == "None":
			pool.append(id)
	var quotas: Dictionary = {}
	var planned: Dictionary = {}
	var remaining: Array = pool.duplicate()
	while not remaining.is_empty():
		var best: Dictionary = {}
		for r in requests.values():
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
	var keep: Dictionary = {}
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
	if p.is_empty() or p.owner != PLAYER or p.assignment not in ["Available", "Rear Labour"] or p.health <= 0 or not actors.has(p.id):
		return false
	if not Rect2(0, 0, 240, 180).has_point(p.position):
		return false
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
		if rank_a != rank_b: return rank_a < rank_b
		if (first.duty_id == duty) != (second.duty_id == duty): return first.duty_id == duty
		if (first.assignment == "Available") != (second.assignment == "Available"): return first.assignment == "Available"
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
	var destination: Vector2 = ledger.inspect_entity(requests[p.duty_id].place).position
	_move(a, "Reporting", Layout.path(p.position, destination), 1.5)


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
	for _iteration in 1000:
		var changed: bool = yard.complete_due()
		for a in actors.values():
			if a.deadline <= time + EPS:
				_finish_phase(a)
				changed = true
			if a.phase == "Yard" and yard.driver.is_empty():
				_report(a)
				if ledger.inspect_entity(a.id).duty_id.is_empty(): _rebalance()
				changed = true
		for a in actors.values():
			var p: Dictionary = ledger.inspect_entity(a.id)
			if a.phase == "Idle" and p.duty_id == "hauling":
				changed = _start_job(a) or changed
		if not changed:
			return
	push_error("Rear activity failed to settle finite immediate boundaries.")


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
			else:
				a.phase = "Idle"
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


func _reserved_space(destination: String, except_person: String = "") -> float:
	var total: float = 0.0
	for a in actors.values():
		if a.id != except_person and a.load.get("destination") == destination:
			total += a.load.mass
	return total


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


func _has_relocation(source: String, type: String) -> bool:
	for job in jobs:
		if job.get("relocation", false) and not job.cancelled and job.source == source and job.type == type and job.delivered < job.requested:
			return true
	return false


func snapshot() -> Dictionary:
	var staffing: Array[Dictionary] = []
	for r in requests.values():
		var assigned := _assigned(r.id)
		var present := _present(r.id)
		staffing.append({"id": r.id, "target": r.target, "positions": r.positions,
			"assigned": assigned, "present": present, "reporting_or_active": assigned - present,
			"shortage": maxi(0, r.target - assigned), "priority": PRIORITIES[r.priority], "requested_at": r.created})
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
		row.reserved_inbound_kg = _reserved_space(store.id)
		row.free_kg = _free_space(store.id)
		row.stocks = _stock_at(store.id)
		row.reserved_outbound = 0
		for stock in row.stocks: row.reserved_outbound += stock.reserved
		storage.append(row)
	var inspected_jobs: Array[Dictionary] = jobs.duplicate(true)
	var emergency := false
	for a in actors.values():
		if not a.load.is_empty() and _job(a.load.job).priority == 3: emergency = true
	for job in inspected_jobs:
		job.age = time - job.created
		job.effective_priority = PRIORITIES[effective_priority(job)]
		job.in_flight = _in_flight(job.id)
		job.starved = not job.cancelled and job.delivered + job.in_flight < job.requested and job.age >= 120.0 and emergency and job.priority != 3 and _waiting_job_viable(job)
		if job.starved: job.blocker = "Starved by explicit Emergency work for at least 120 seconds"
	return {"time": time, "staffing": staffing, "people": people, "stores": storage,
		"jobs": inspected_jobs, "workshop": workshop_readiness(), "yard": yard.snapshot(),
		"audit": audit(), "ledger": ledger.snapshot(), "events": _events.duplicate(true)}


func _waiting_job_viable(job: Dictionary) -> bool:
	# Report Emergency contention only when some actual hauler could otherwise
	# perform this job, accounting for their retained gear rather than active load.
	for id in actors:
		var p: Dictionary = ledger.inspect_entity(id)
		if p.duty_id != "hauling": continue
		if not p.carrying_stock_id.is_empty():
			var freight: Dictionary = ledger.inspect_entity(p.carrying_stock_id)
			p.contents_mass_kg -= freight.quantity * freight.unit_mass_kg
		if not _job_option(job.duplicate(true), p).is_empty(): return true
	return false


func audit() -> Array[String]:
	var failures: Array[String] = ledger.audit()
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


func _present(duty: String) -> int:
	var count: int = 0
	for id in actors:
		if ledger.inspect_entity(id).duty_id == duty and actors[id].phase == "Idle": count += 1
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
