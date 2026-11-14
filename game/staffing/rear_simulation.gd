extends RefCounted
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
signal state_changed
## G03 owns staffing, timed local jobs and space promises; G01 owns physical facts.

const Ledger = preload("res://game/identity/identity_ledger.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Layout = preload("res://game/staffing/rear_layout.gd")
const Yard = preload("res://game/staffing/yard_activity.gd")
const WorkPositions = preload("res://game/staffing/rear_work_positions.gd")
const HaulingPolicy = preload("res://game/staffing/hauling_policy.gd")
const Packages = preload("res://game/warehousing/material_packages.gd")
const PRIORITIES: Array[String] = ["Low", "Normal", "High", "Emergency"]
const PLAYER := "army-blue"
const EPS := 0.000001

var ledger := Ledger.new()
const SUPPLY_TABLE := Vector2(120,186)
const SUPPLY_TABLE_ACCESS := SUPPLY_TABLE+WorkPositions.ACCESS_OFFSET
var empty_field_opening := false
var warehouse: RefCounted
var work_positions: RefCounted
var hauling_policy: RefCounted
var yard: RefCounted
var time: float = 0.0
var vehicle_departures_allowed := true # Explicit-time callers own their clock; live Base gates Pause.
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
var dispatch: RefCounted # Optional G12 manifests on the same identities and event clock.
var hq: RefCounted # G14 physical HQ issue on the same ledger and event clock.
var construction: RefCounted # G05 physical facility sites, copies and builders.
var military: RefCounted # G15 actual HQ formation and hierarchy on the same identities.
var combat: RefCounted # G16 wounds, direct fire and care on the shared identities and clock.
var vehicle_combat: RefCounted # G23 mounted fire against actual people, stock and hulls.
var recovery: RefCounted # G24 physical repair, towing and once-only destruction.
var orders: RefCounted # G17 observed contacts, command links and local coordinated intent.
var objectives: RefCounted # G18 physical objective control and owned uncontested income.
var forward_supply: RefCounted # Timed local issue from arrived forward stock to an active formation.
var battlefield_operations: RefCounted # Delivered squad intent, movement and local action on this clock.
var field_structures: RefCounted # G19 local engineer projects and field services.
var bridges: RefCounted # G20 constructed crossing, traffic and repair owner.
var mines: RefCounted # G22 field devices, knowledge and clearance.
var demolition: RefCounted # G21 attached demolition on existing physical targets.
var additional_productions: Array[RefCounted] = []
var _output_promises: Dictionary = {}
var receiving: RefCounted # Optional integrated G02 activity; same ledger and joint boundaries.


func _init(fixture: String = "A05", include_yard_fixture: bool = true, empty_field: bool = false) -> void:
	empty_field_opening = empty_field
	hauling_policy = HaulingPolicy.new(self)
	if empty_field: work_positions = WorkPositions.new(self)
	ledger.add_place("rear", "Accessible rear working area", Vector2.ZERO)
	ledger.add_place("away", "Committed strategic trip outside the rear", Vector2(-1000, 0))
	for id in Layout.FACILITIES:
		# Dormant templates preserve recipe/diagnostic callers; only the edge
		# Supply Table has positions/storage until real construction completes.
		var f: Array = Layout.FACILITIES[id]
		var at: Vector2 = SUPPLY_TABLE if empty_field and id in ["receiving","personnel","depot"] else f[4]
		ledger.add_place("duty-" + id, f[0] + " staff entrance", at)
		requests[id] = {"id": id, "target": 0, "positions": (4 if id == "receiving" else 0) if empty_field else f[3], "priority": 1, "created": 0.0, "order": _next(), "place": "duty-" + id}
	requests.hauling = {"id": "hauling", "target": 0, "positions": 120, "priority": 1, "created": 0.0, "order": _next(), "place": "duty-depot"}
	if empty_field: requests.hauling.fallback = true
	requests.yard = {"id": "yard", "target": 0, "positions": 1, "priority": 1, "created": 0.0, "order": _next(), "place": "yard-start"}
	if empty_field: requests.yard.positions = 0
	for id in Layout.STORES:
		var definition: Array = Layout.STORES[id]
		var at: Vector2 = SUPPLY_TABLE if empty_field and id == "receiving" else Layout.door(definition[0])
		ledger.add_place(id, id + " physical storage", at)
		var active: bool = not empty_field or id == "receiving"
		stores[id] = {"id": id, "capacity": float(definition[1]) if active else 0.0, "accessible": active, "filter": [], "pile": false}
	yard = Yard.new(ledger,include_yard_fixture and not empty_field)
	if empty_field:
		yard.active_parking.fill(false)
		return
	if fixture == "Empty":
		return
	for i in range(1, 5):
		add_person("worker-%02d" % i)
	add_person("instructor-01", true)
	add_person("driver-01", true, "P08")
	ledger.add_person("away-crew", "away", PLAYER, Records.Assignment.STRATEGIC_CREW, true, "P08", "Held Home")
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
		if work_positions != null: ledger.move_entity(id,"rear",work_positions.point(id,at,true,true))
		_rebalance()
		_settle()
	return result


func set_target(id: String, count: int, priority: int = 1) -> Dictionary:
	CallLog.record(&"staffing/rear_simulation.gd::set_target")
	if construction != null and construction.is_office(id) and not construction._syncing_offices:
		return construction.set_office_staff(id,count,priority)
	if not requests.has(id) or count < 0 or count > int(requests[id].positions) or priority < 0 or priority > 3:
		return _result(false, "Target must fit actual catalogue positions and a valid priority.")
	var r: Dictionary = requests[id]
	r.erase("starter_request") # A successful player edit is now their ordinary instruction.
	if r.target != count or r.priority != priority:
		r.created = time
		r.order = _next()
	r.target = count
	r.priority = priority
	var pending_allowed := maxi(0, count - _retaining(id))
	for person_id in actors:
		var p: Dictionary = ledger.inspect_person_status(person_id)
		if p.pending_assignment != "None" and p.pending_duty == id:
			if pending_allowed > 0:
				pending_allowed -= 1
			else:
				ledger.cancel_assignment_request(person_id)
				reassign_person(person_id, "Available")
	_rebalance(true)
	_settle()
	return _result(true, "Target recorded; actual people must report before being present.")


func request_haul(source: String, destination: String, type: String, count: int, priority: int = 1, alternative_sources: Array = [], automatic_factory: RefCounted = null) -> Dictionary:
	if not stores.has(source) or not stores.has(destination) or source == destination or type.is_empty() or count <= 0 or priority < 0 or priority > 3:
		return _result(false, "Hauling needs distinct actual stores, one type, positive count and priority.")
	if stores[destination].get("source_only",false): return _result(false,"This is source-only storage, not an ordinary hauling destination.")
	if automatic_factory != null and (automatic_factory not in _production_activities() or automatic_factory._spec.input_store != destination or not automatic_factory._spec.inputs.has(type)):
		return _result(false,"Automatic input hauling needs its current actual production owner and ingredient store/type.")
	var result := _queue_haul(source, destination, type, count, priority)
	# Record provenance before internal settling can reserve an actual portion.
	if automatic_factory != null: _job(str(result.id)).automatic_factory = str(automatic_factory._spec.duty)
	for candidate in alternative_sources:
		add_haul_source(str(result.id),str(candidate))
	_settle()
	return result

func add_haul_source(id: String, source: String) -> bool:
	# Adding an allowed source changes only future selection. A current load
	# retains its captured stock/claim, holder and destination.
	var job := _job(id)
	if job.is_empty() or job.cancelled or not stores.has(source) or source == job.destination: return false
	if not job.has("alternative_sources"): job.alternative_sources = []
	if source == job.source or source in job.alternative_sources: return false
	job.alternative_sources.append(source)
	return true


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
	if job.has("warehouse_recovery"): return warehouse.recovery.stop()
	job.cancelled = true
	for actor in actors.values():
		if actor.load.get("job") == id:
			if actor.load.has("truck"):
				construction.trucks.cancel_actor(actor)
				continue
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
	var former_duty: String = p.duty_id
	if p.assignment == "Training" and destination not in ["Available","students"]:
		return _result(false,"Withdraw the unfinished course before assigning this student to another duty; completed qualifications stay.")
	if not _eligible(p, destination):
		return _result(false, "The person is not qualified/available for this duty.")
	if p.pending_assignment != "None":
		var same_handoff: bool = p.pending_duty == destination or (destination == "Available" and p.pending_duty == "")
		if same_handoff and not str(p.get("construction_truck_id","")).is_empty(): construction.trucks.cancel_actor(actors[id])
		return _result(same_handoff, "Existing safe handoff remains pending; no second assignment created.")
	if destination != "Available" and _committed(destination) >= int(requests[destination].positions):
		return _result(false, "Every actual/pending position in that duty is occupied.")
	var a: Dictionary = actors[id]
	if str(a.phase).begins_with("Dispatch "):
		return _result(false,"Finish the current outbound handling task before changing this person's job. Staffing targets apply at its safe completion.")
	var assignment := Records.Assignment.AVAILABLE if destination == "Available" else (Records.Assignment.TRAINING if destination == "students" else Records.Assignment.REAR_LABOUR)
	var duty := "" if destination == "Available" else destination
	if str(p.get("joint_carry_id","")).is_empty() and not a.load.is_empty() and not a.load.has("truck") and a.phase not in ["Carry", "Drop"]:
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
	if not p.get("construction_truck_id","").is_empty():
		construction.trucks.cancel_actor(a)
	elif not p.crew_station.is_empty():
		if vehicles != null and vehicles.vehicles.has(p.holder_id): vehicles.request_exit(id)
		else: yard.request_exit()
	elif not str(p.get("supplier_access_id","")).is_empty() or not str(p.get("joint_carry_id","")).is_empty():
		# Receiving owns the real aisle/ramp exit before the requested duty.
		if receiving != null: receiving._sync_workers()
	elif a.phase not in ["Carry", "Drop"] and ledger.inspect_entity(id).carrying_stock_id.is_empty():
		_report(a)
	if construction != null and not construction._transferring and construction.office_members.has(id) and former_duty.begins_with("builders-") and destination != former_duty:
		construction.on_builder_reassigned(id,former_duty)
	return _result(true, "Duty requested; carrying or driving retains the old actual duty until safe handoff.")


func set_store(id: String, accessible: bool, capacity: float = -1.0, filter: Variant = null) -> Dictionary:
	if warehouse != null and id == "receiving":
		return _result(false,"Supply Depot storage comes from completed warehouse modules and usable shelves. Free space or build an expansion.")
	if warehouse != null and id == warehouse.recovery.STORE:
		return _result(false,"Recovery staging is finite source-only space; clear it by physically collecting its goods.")
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
				_move(a, "Approach", walk_path(ledger.inspect_entity(a.id).position, ledger.inspect_entity(a.load.source).position), 1.5)
			a.blocked_since = -1.0
		elif a.phase in ["Approach", "Pickup"] and not _valid_destination(a.load.destination, a.load.type, a.load.mass, a.id):
			_release_load(a)
	_settle()
	return _result(true, "Storage edited without deleting or moving any contents.")


func _reconcile_store(id: String, summary: Dictionary = {}) -> bool:
	var changed := false
	var needed_types: Array = []
	# Existing contents survive every edit; disallowed/excess stock creates relocation demand.
	if summary.is_empty(): summary = ledger.loose_stock_summary(id,PLAYER)
	var excess := maxf(0.0, float(summary.mass) - float(stores[id].capacity))
	var contents: Dictionary = summary.contents
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
	activities.append_array(additional_productions)
	return activities


func heavy_owners() -> Array[RefCounted]:
	var owners: Array[RefCounted] = []
	if heavy_production != null: owners.append(heavy_production)
	if construction != null:
		for activity in construction.activities.values():
			if activity.has_method("accept_order"): owners.append(activity)
	return owners

func heavy_owner(bay_id: String) -> RefCounted:
	for activity in heavy_owners():
		if activity.bay_id == bay_id: return activity
	return heavy_production

func gun_owner(gun_id: String) -> RefCounted:
	for activity in heavy_owners():
		if activity.bay_occupant == gun_id: return activity
	return null


func advance_time(seconds: float, stop_on_planning: bool = false, work_budget_usec: int = 0) -> Dictionary:
	CallLog.record(&"staffing/rear_simulation.gd::advance_time")
	var advance_started: int = Time.get_ticks_usec() if work_budget_usec > 0 else 0
	if not is_finite(seconds) or seconds < 0.0:
		return _result(false, "Time must be finite and nonnegative.")
	var target := time + seconds
	var settle_started_usec: int = Time.get_ticks_usec() if CallLog.enabled else 0
	_settle()
	if CallLog.enabled: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle", Time.get_ticks_usec() - settle_started_usec)
	if stop_on_planning and _transport_planning_pending():
		return _result(true, "Transport planning is waiting at the settled clock boundary.")
	var reached_boundary := false
	var completed_interval := false
	var profile_stages := CallLog.enabled and OS.get_environment("TRENCHO_PROFILE_STAGES") == "1"
	var stage_started: int = 0
	while time < target - EPS:
		# A live owner may return only between complete settled transactions.
		# Its caller retains the unadvanced elapsed-time debt. Explicit domain
		# stepping keeps its original unlimited default and exact endpoints.
		# Initial settlement can itself exceed this cooperative allowance. Always
		# complete one positive interval before yielding, or every later call can
		# repeat the same settled state forever while elapsed-time debt grows.
		if completed_interval and work_budget_usec > 0 and Time.get_ticks_usec()-advance_started >= work_budget_usec: break
		if profile_stages: stage_started = Time.get_ticks_usec()
		var next: float = yard.deadline
		if vehicles != null: next = minf(next,vehicles.next_boundary())
		if dispatch != null: next = minf(next,dispatch.next_boundary())
		if hq != null: next = minf(next,hq.next_boundary())
		if construction != null: next = minf(next,construction.next_boundary())
		if military != null: next = minf(next,military.next_boundary())
		if combat != null: next = minf(next,combat.next_boundary())
		if vehicle_combat != null: next = minf(next,vehicle_combat.next_boundary())
		if recovery != null: next = minf(next,recovery.next_boundary())
		if orders != null: next = minf(next,orders.next_boundary())
		if objectives != null: next = minf(next,objectives.next_boundary())
		if forward_supply != null: next = minf(next,forward_supply.next_boundary())
		if battlefield_operations != null: next = minf(next,battlefield_operations.next_boundary())
		if field_structures != null: next = minf(next,field_structures.next_boundary())
		if bridges != null: next = minf(next,bridges.next_boundary())
		if mines != null: next = minf(next,mines.next_boundary())
		if demolition != null: next = minf(next,demolition.next_boundary())
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
		reached_boundary = reached_boundary or next <= target + EPS
		next = minf(target,next)
		if next <= time + EPS:
			next = minf(target, time + EPS)
		if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::advance_time/boundaries",Time.get_ticks_usec()-stage_started)
		if profile_stages: stage_started = Time.get_ticks_usec()
		for activity in _production_activities(): activity.advance_work(next - time)
		if construction != null: construction.advance_work(next - time)
		if training != null: training.advance_work(next - time)
		for a in actors.values():
			if not a.motion.is_empty():
				var distance: float = (next - a.motion.started) * a.motion.speed
				ledger.move_entity(a.id, "rear", Layout.position(a.motion.path, distance))
		yard.advance_to(next)
		if vehicles != null: vehicles.advance_to(next)
		if dispatch != null: dispatch.advance_to(next)
		if hq != null: hq.advance_to(next)
		if construction != null: construction.advance_to(next)
		if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::advance_time/rear_motion",Time.get_ticks_usec()-stage_started)
		if profile_stages: stage_started = Time.get_ticks_usec()
		if military != null: military.advance_to(next)
		if battlefield_operations != null: battlefield_operations.advance_to(next)
		if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::advance_time/military_motion",Time.get_ticks_usec()-stage_started)
		if profile_stages: stage_started = Time.get_ticks_usec()
		if combat != null: combat.advance_to(next)
		if orders != null: orders.advance_to(next)
		if objectives != null: objectives.advance_to(next)
		if forward_supply != null: forward_supply.advance_to(next)
		if field_structures != null: field_structures.advance_to(next)
		if bridges != null: bridges.advance_to(next)
		if mines != null: mines.advance_to(next)
		if demolition != null: demolition.advance_to(next)
		if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::advance_time/world",Time.get_ticks_usec()-stage_started)
		if profile_stages: stage_started = Time.get_ticks_usec()
		ledger.advance_time(next - time)
		time = next
		if vehicle_combat != null: vehicle_combat.advance_to(next)
		if recovery != null: recovery.advance_to(next)
		if receiving != null: receiving.advance_clock_to(next)
		if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::advance_time/receiving_combat",Time.get_ticks_usec()-stage_started)
		settle_started_usec = Time.get_ticks_usec() if CallLog.enabled else 0
		_settle()
		if CallLog.enabled: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle", Time.get_ticks_usec() - settle_started_usec)
		completed_interval = true
		if reached_boundary: state_changed.emit()
		if stop_on_planning and _transport_planning_pending(): break
	return _result(true, "Shared rear time advanced; each facility's prerequisites still govern operator work." if not _production_activities().is_empty() else "Only elapsed reporting, handling, walking and yard movement completed.")


func _transport_planning_pending() -> bool:
	return military != null and military.troop_transport.has_planning_work()


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


func walk_path(origin: Vector2, destination: Vector2) -> Array:
	if empty_field_opening:
		return construction.walking_path(origin,destination) if construction != null else [origin,destination]
	return Layout.path(origin,destination)

func work_point(person: String, holder: String, reserve: bool = true) -> Vector2:
	if warehouse != null and holder in ["receiving",warehouse.recovery.STORE]:
		var point: Vector2 = warehouse.work_point(person)
		if point.is_finite(): return point
	return work_positions.point(person,holder,reserve) if work_positions != null else ledger.inspect_entity(holder,{},false).position

func stock_work_point(person: String, stock: Dictionary, reserve: bool = false) -> Vector2:
	if warehouse != null and stock.holder_id in ["receiving",warehouse.recovery.STORE]:
		return warehouse.stock_point(str(stock.id),person,reserve)
	return work_point(person,str(stock.holder_id),reserve)

func warehouse_space_changed() -> void:
	if vehicles != null: vehicles.warehouse_access_changed()
	if construction != null: construction.trucks.warehouse_access_changed()
	for actor: Dictionary in actors.values():
		if actor.phase in ["Warehouse wait","Warehouse destination wait"]: actor.deadline = time

func _warehouse_approach_source(actor: Dictionary) -> void:
	var stock: Dictionary = ledger.inspect_entity(actor.load.stock,{},false)
	var point := stock_work_point(str(actor.id),stock,true)
	var origin: Vector2 = ledger.inspect_entity(actor.id,{},false).position
	var path: Array = walk_path(origin,point) if point.is_finite() else []
	if path.is_empty():
		actor.phase = "Warehouse wait"
		actor.deadline = INF
		_job(actor.load.job).blocker = "Route blocked; cargo remains at source"
	else: _move(actor,"Approach",path,1.5)

func _rebalance(player_edit: bool = false, fill_released: bool = true) -> void:
	# Plan counts by priority/share/age using actual eligible people, then retain
	# incumbents within those counts before requesting any safe transfers.
	var facts := {}
	if requests.hauling.get("fallback",false): requests.hauling.target = mini(120,actors.size())
	for id in actors: facts[id] = ledger.inspect_person_status(id)
	var pool: Array = []
	for id in actors:
		var p: Dictionary = facts[id]
		if str(actors[id].phase).begins_with("Dispatch "): continue
		if _eligible(p, "Available") and p.assignment != "Training" and p.pending_assignment == "None" and not p.duty_id.begins_with("crew:") and not p.duty_id.begins_with("fuel:") and (empty_field_opening or not p.duty_id.begins_with("builders-")):
			pool.append(id)
	var pending: Dictionary = {}
	# A pending handoff occupies its destination target vacancy even though
	# the person still physically serves the old duty until safe completion.
	for id in actors:
		var person: Dictionary = facts[id]
		if str(actors[id].phase).begins_with("Dispatch ") and requests.has(person.duty_id):
			pending[person.duty_id] = int(pending.get(person.duty_id,0))+1
		if person.pending_assignment != "None" and requests.has(person.pending_duty):
			pending[person.pending_duty] = int(pending.get(person.pending_duty, 0)) + 1
	var quotas: Dictionary = pending.duplicate()
	var planned: Dictionary = {}
	var remaining: Array = pool.duplicate()
	while not remaining.is_empty():
		var best: Dictionary = {}
		for r in requests.values():
			if r.get("manual",false): continue
			if int(quotas.get(r.id, 0)) >= int(r.target) or not _any_eligible(remaining, r.id, facts, not player_edit and r.get("starter_request",false)):
				continue
			if best.is_empty() or _staff_before(r, best, quotas):
				best = r
		if best.is_empty():
			break
		var candidate := _choose_person(remaining, best.id, facts, not player_edit and best.get("starter_request",false))
		remaining.erase(candidate)
		planned[candidate] = best.id
		quotas[best.id] = int(quotas.get(best.id, 0)) + 1
	# Preserve present/reporting incumbents wherever possible. Pending carries
	# remain their old duty and cannot be counted as a second destination worker.
	var keep: Dictionary = pending.duplicate()
	var free: Array = []
	for id in pool:
		var duty: String = facts[id].duty_id
		if not duty.is_empty() and planned.get(id, "") == duty and int(keep.get(duty, 0)) < int(quotas.get(duty, 0)):
			keep[duty] = int(keep.get(duty, 0)) + 1
		else:
			free.append(id)
	var ordered: Array = requests.values()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("fallback",false)) != bool(b.get("fallback",false)): return not bool(a.get("fallback",false))
		if a.priority != b.priority: return a.priority > b.priority
		# Qualified roles are filled from compatible free people first.
		if (a.id in ["yard", "training"]) != (b.id in ["yard", "training"]): return a.id in ["yard", "training"]
		return a.order < b.order)
	for r in ordered:
		while int(keep.get(r.id, 0)) < int(quotas.get(r.id, 0)) and _any_eligible(free, r.id, {}, not player_edit and r.get("starter_request",false)):
			var id := _choose_person(free, r.id, {}, not player_edit and r.get("starter_request",false))
			free.erase(id)
			reassign_person(id, r.id)
			keep[r.id] = int(keep.get(r.id, 0)) + 1
	var released := false
	for id in free:
		if ledger.inspect_person_status(id).assignment != "Available":
			reassign_person(id, "Available")
			released = released or ledger.inspect_person_status(id).assignment == "Available"
	# A genuinely completed release may fill an automatic request in this event.
	if released and fill_released:
		for request in requests.values():
			if request.get("starter_request",false) and int(request.target) > int(quotas.get(request.id,0)):
				_rebalance(player_edit,false)
				break # Exactly one extra pass, only for an unfilled automatic starter request.


func _staff_before(a: Dictionary, b: Dictionary, counts: Dictionary) -> bool:
	if bool(a.get("fallback",false)) != bool(b.get("fallback",false)): return not bool(a.get("fallback",false))
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
	if not Rect2(0, 0, 240, 210 if empty_field_opening else 180).has_point(p.position):
		return false
	if requests.has(duty) and requests[duty].get("manual",false):
		if duty.begins_with("builders-"): return true
		return vehicles != null and vehicles.eligible(p,duty)
	if duty == "yard":
		return p.basic_training and p.qualification == "P08"
	if duty == "training" or (construction != null and construction.instances.has(duty) and construction.instances[duty].kind == "training" and construction.instances[duty].state == "Complete"):
		return p.basic_training
	return true


func _any_eligible(ids: Array, duty: String, facts: Dictionary = {}, starter_only: bool = false) -> bool:
	for id in ids:
		var person: Dictionary = facts[id] if facts.has(id) else ledger.inspect_person_status(id)
		if starter_only and not _starter_candidate(person,duty): continue
		if _eligible(person,duty): return true
	return false

func _choose_person(ids: Array, duty: String, facts: Dictionary = {}, starter_only: bool = false) -> String:
	# Same lexicographic preference as the former sort, with one pass. Facts
	# are supplied only during pure quota planning, never across reassignment.
	var best := ""
	var best_rank := 100
	for id in ids:
		var person: Dictionary = facts[id] if facts.has(id) else ledger.inspect_person_status(id)
		if starter_only and not _starter_candidate(person,duty): continue
		if not _eligible(person,duty): continue
		var qualification := 2 if person.qualification != "None" else (1 if person.basic_training else 0)
		var rank: int = (0 if person.duty_id == duty else 6)+(0 if person.assignment == "Available" else 3)+qualification
		if rank < best_rank or (rank == best_rank and str(id) < best):
			best = id
			best_rank = rank
	return best


func _starter_candidate(person: Dictionary, duty: String) -> bool:
	if person.assignment == "Available" or person.duty_id == duty: return true
	# Default fallback is uncommitted labour; deliberately requested Hauling and
	# actual reserved handling/carries keep their existing exclusive commitment.
	return requests.hauling.get("fallback",false) and person.duty_id == "hauling" and actors[person.id].phase in ["Idle","Reporting","Available"]


func _report(a: Dictionary) -> void:
	var p: Dictionary = ledger.inspect_entity(a.id)
	if not str(p.get("supplier_access_id","")).is_empty() or not str(p.get("joint_carry_id","")).is_empty():
		return # Do not overwrite Receiving's physical safe-exit activity.
	a.load = {}
	a.motion = {}
	a.deadline = INF
	if work_positions != null: work_positions.release(a.id)
	if p.duty_id.is_empty():
		a.phase = "Available"
		return
	var path: Array = []
	if vehicles != null and requests[p.duty_id].get("manual",false) and not p.duty_id.begins_with("builders-"):
		path = vehicles.report_path(a.id,p.duty_id)
	else:
		var destination: Vector2 = ledger.inspect_entity("yard-t01").position if p.duty_id == "yard" else (training.student_position(a.id) if p.duty_id == "students" and training != null else ledger.inspect_entity(requests[p.duty_id].place).position)
		if work_positions != null and p.duty_id not in ["yard","students"]: destination = work_point(a.id,requests[p.duty_id].place)
		if not destination.is_finite():
			a.phase = "Route blocked"
			return
		path = _ordinary_report_path(p.position,destination)
	_move(a, "Reporting", path, 1.5)


func _ordinary_report_path(origin: Vector2, destination: Vector2) -> Array:
	# Resolve only current physical bays; the empty opening's legacy template
	# is not a built workshop, even if its coordinates match a placed bay.
	for owner in heavy_owners():
		if empty_field_opening and owner == heavy_production: continue
		var bay: Dictionary = ledger.inspect_entity(owner.bay_id,{},false)
		if bay.is_empty() or not origin.is_equal_approx(bay.position): continue
		var outward: Array = walk_path(owner.site_door,destination)
		if outward.is_empty(): return []
		# Preserve the interior exit after fuel handoff/crew extraction even if
		# its truck has since cleared the bay. Never report at just the door.
		var route: Array = [origin,owner.site_door]
		route.append_array(outward.slice(1))
		return route
	return walk_path(origin,destination)


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
	CallLog.record(&"staffing/rear_simulation.gd::_settle")
	var any_changed := false
	var profile_stages := CallLog.enabled and OS.get_environment("TRENCHO_PROFILE_STAGES") == "1"
	var stage_started: int = 0
	if profile_stages: stage_started = Time.get_ticks_usec()
	if receiving != null:
		receiving._pump()
		_sync_receiving_people()
	if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/receiving",Time.get_ticks_usec()-stage_started)
	for _iteration in 1000:
		var changed: bool = yard.complete_due()
		if vehicles != null:
			if profile_stages: stage_started = Time.get_ticks_usec()
			changed = vehicles.settle() or changed
			if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/vehicles", Time.get_ticks_usec()-stage_started)
		if profile_stages: stage_started = Time.get_ticks_usec()
		if dispatch != null: changed = dispatch.settle() or changed
		if hq != null: changed = hq.settle() or changed
		if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/dispatch_hq",Time.get_ticks_usec()-stage_started)
		if construction != null:
			if profile_stages: stage_started = Time.get_ticks_usec()
			changed = construction.settle() or changed
			if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/construction", Time.get_ticks_usec()-stage_started)
		if military != null:
			if profile_stages: stage_started = Time.get_ticks_usec()
			changed = military.settle() or changed
			if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/military", Time.get_ticks_usec()-stage_started)
		if combat != null:
			if profile_stages: stage_started = Time.get_ticks_usec()
			changed = combat.settle() or changed
			if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/combat", Time.get_ticks_usec()-stage_started)
		if orders != null:
			if profile_stages: stage_started = Time.get_ticks_usec()
			changed = orders.settle() or changed
			if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/orders", Time.get_ticks_usec()-stage_started)
		if profile_stages: stage_started = Time.get_ticks_usec()
		if objectives != null: changed = objectives.settle() or changed
		if forward_supply != null: changed = forward_supply.settle() or changed
		if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/objectives_supply",Time.get_ticks_usec()-stage_started)
		if battlefield_operations != null:
			if profile_stages: stage_started = Time.get_ticks_usec()
			changed = battlefield_operations.settle() or changed
			if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/battlefield_operations", Time.get_ticks_usec()-stage_started)
		if profile_stages: stage_started = Time.get_ticks_usec()
		if field_structures != null: changed = field_structures.settle() or changed
		if bridges != null: changed = bridges.settle() or changed
		if mines != null: changed = mines.settle() or changed
		if demolition != null: changed = demolition.settle() or changed
		if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/engineering",Time.get_ticks_usec()-stage_started)
		if profile_stages: stage_started = Time.get_ticks_usec()
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
		# Constraint reconciliation only records/extends relocation demand; it
		# does not move stock. Share one fresh physical scan for this whole pass.
		var storage_facts: Dictionary = ledger.loose_stock_summaries(stores.keys(),PLAYER)
		for id in stores.keys():
			changed = _reconcile_store(id,storage_facts[id]) or changed
		# Intent changes apply before ANY new haul selection in this transaction.
		changed = _reconcile_factory_hauls() or changed
		if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/actors_stores",Time.get_ticks_usec()-stage_started)
		if profile_stages: stage_started = Time.get_ticks_usec()
		if empty_field_opening: changed = hauling_policy.start_available(actors.values()) or changed
		for a in actors.values():
			if a.phase == "Idle" and ledger.person_has_duty(a.id,"hauling"):
				if not empty_field_opening: changed = _start_job(a) or changed
			elif empty_field_opening and a.phase == "Idle" and construction != null:
				changed = construction.start_builder_supply(a) or changed
		if receiving != null: _sync_receiving_staff()
		for activity in _production_activities(): changed = activity.settle() or changed
		if training != null: changed = training.settle() or changed
		if profile_stages: CallLog.record_duration(&"staffing/rear_simulation.gd::_settle/production_staff",Time.get_ticks_usec()-stage_started)
		any_changed = any_changed or changed
		if not changed:
			_refresh_contention()
			if any_changed: state_changed.emit()
			return
	push_error("Rear activity failed to settle finite immediate boundaries.")


func _sync_receiving_people() -> void:
	var added := false
	var released := false
	for id in ledger.available_person_ids(PLAYER):
		if not actors.has(id):
			actors[id] = {"id": id, "phase": "Available", "deadline": INF, "motion": {}, "load": {}, "blocked_since": -1.0}
			added = true
	for a in actors.values():
		if a.phase == "Unloading" and not receiving._workers.has(a.id):
			var status: Dictionary = ledger.inspect_person_status(a.id)
			if warehouse != null and status.duty_id == "hauling" and status.pending_assignment == "None":
				# A finished warehouse deposit is already a safe handoff. The
				# same hauler can select work here instead of reporting to the
				# distant Table between every truck-to-shelf trip.
				if work_positions != null: work_positions.release(a.id)
				a.phase = "Idle"
				a.motion = {}
				a.deadline = INF
				continue
			_report(a)
			# Match hauling: a released Available person fills outstanding targets;
			# a specific requested destination retains its direct handoff.
			released = released or ledger.inspect_entity(a.id).duty_id.is_empty()
	if added or released: _rebalance()


func _sync_receiving_staff() -> void:
	for a in actors.values():
		if a.phase != "Idle": continue
		var p: Dictionary = ledger.inspect_person_status(a.id)
		if (p.duty_id == "receiving" or (construction != null and construction.instances.has(p.duty_id) and construction.instances[p.duty_id].kind == "receiving" and construction.instances[p.duty_id].state == "Complete")) and p.pending_assignment == "None":
			receiving._workers[a.id] = {"person_id": a.id, "job": {}}
			a.phase = "Unloading"
	receiving._pump()


func _finish_phase(a: Dictionary) -> void:
	a.deadline = INF
	if not a.motion.is_empty():
		ledger.move_entity(a.id, "rear", a.motion.path.back())
	a.motion = {}
	match a.phase:
		"Clearing warehouse access":
			a.phase = "Idle"
		"Warehouse visit", "Warehouse wait":
			var prepared: Dictionary = warehouse.begin_preparation(str(a.load.storage))
			if not prepared.ok:
				a.phase = "Warehouse wait"
				a.deadline = INF
				_job(a.load.job).blocker = str(prepared.message)
			elif prepared.ready: _warehouse_approach_source(a)
			else:
				a.phase = "Warehouse smoke"
				a.deadline = time+0.75
		"Warehouse smoke":
			if warehouse.reveal_preparation(str(a.load.storage)):
				a.phase = "Warehouse settle"
				a.deadline = time+0.75
			else:
				a.phase = "Warehouse wait"
				a.deadline = INF
		"Warehouse settle":
			if warehouse.finish_preparation(str(a.load.storage)): _warehouse_approach_source(a)
			else:
				a.phase = "Warehouse wait"
				a.deadline = INF
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
				if requests.hauling.get("fallback",false): _rebalance()
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
		"Pickup", "Warehouse destination wait":
			if a.load.has("storage") and not warehouse.acquire_access(str(a.load.storage)):
				a.phase = "Warehouse destination wait"
				a.deadline = INF
				_job(a.load.job).blocker = "Waiting for clear reserved shelf access; package stays at source"
				return
			var destination: Vector2 = work_point(a.id,a.load.destination)
			var path: Array = walk_path(ledger.inspect_person_status(a.id).position,destination) if destination.is_finite() else []
			if a.load.has("storage") and path.is_empty():
				a.phase = "Warehouse destination wait"
				a.deadline = INF
				_job(a.load.job).blocker = "Reserved storage route blocked; package stays at source"
				return
			var result: Dictionary = ledger.begin_carry(a.id, a.load.stock, a.load.count, a.load.claim,a.load.has("warehouse_recovery"))
			if not result.ok:
				_job(a.load.job).blocker = result.message
				_release_load(a)
			else:
				a.load.carried = result.entity_id
				a.load.claim = ""
				_move(a, "Carry", path, 1.2)
		"Carry":
			a.phase = "Drop"
			a.deadline = time + 2.0
		"Drop":
			_deposit(a)
		"Source blocked":
			_job(a.load.job).blocker = "Source unreachable for 10 seconds; claim released, demand retained"
			_job(a.load.job).source_release_at = time
			_release_load(a)


func _reconcile_factory_hauls() -> bool:
	# Transaction-local facts, shared across every hauler/candidate below.
	# Untagged jobs retain their manual/other-owner intent; never guess origin.
	var captured := {}
	for actor in actors.values():
		var id: String = str(actor.load.get("job",""))
		if not id.is_empty(): captured[id] = int(captured.get(id,0))+int(actor.load.count)
	var totals := {}
	var groups := {}
	var affected := {}
	for job in jobs:
		if job.cancelled or int(job.requested) <= int(job.delivered): continue
		var destination: String = str(job.destination)
		var type: String = str(job.type)
		if not totals.has(destination): totals[destination] = {}
		totals[destination][type] = int(totals[destination].get(type,0))+int(job.requested)-int(job.delivered)
		var owner: String = str(job.get("automatic_factory",""))
		if owner.is_empty(): continue
		if not groups.has(owner): groups[owner] = {}
		if not groups[owner].has(destination): groups[owner][destination] = {}
		if not groups[owner][destination].has(type): groups[owner][destination][type] = []
		groups[owner][destination][type].append(job)
		if int(job.requested) > int(job.delivered)+int(captured.get(job.id,0)): affected[owner] = true
	if affected.is_empty(): return false
	var owners := {}
	for activity in _production_activities(): owners[str(activity._spec.duty)] = activity
	var changed := false
	for owner in affected:
		var activity: RefCounted = owners.get(owner)
		var intent: Dictionary = activity.automatic_input_intent() if activity != null else {}
		for destination in groups[owner]:
			for type in groups[owner][destination]:
				var owned: Array = groups[owner][destination][type]
				var own_promised := 0
				var own_captured := 0
				for job in owned:
					own_promised += int(job.requested)-int(job.delivered)
					own_captured += int(captured.get(job.id,0))
				var missing: int = int(intent.get("missing",{}).get(type,0)) if intent.get("destination","") == destination else 0
				var other_promised: int = maxi(0,int(totals[destination][type])-own_promised)
				var unselected: int = maxi(0,missing-other_promised-own_captured)
				for job in owned:
					var floor_count: int = int(job.delivered)+int(captured.get(job.id,0))
					var keep: int = mini(maxi(0,int(job.requested)-floor_count),unselected)
					unselected -= keep
					var target: int = floor_count+keep
					if target == int(job.requested): continue
					totals[destination][type] += target-int(job.requested)
					job.requested = target
					job.blocker = "Complete" if target == int(job.delivered) else "Captured input portions retained; obsolete unselected automatic remainder retired."
					changed = true
	return changed


func set_hauling_priorities(values: Array) -> Dictionary:
	var result: Dictionary = hauling_policy.set_order(values)
	if result.ok and result.get("changed",false):
		_settle()
		state_changed.emit()
	return result


func _start_job(a: Dictionary, category: String = "", destination: String = "") -> bool:
	var person: Dictionary = ledger.inspect_person_status(a.id)
	if person.pending_assignment != "None":
		return false
	var best: Dictionary = {}
	for job in jobs:
		if not destination.is_empty() and str(job.destination) != destination: continue
		if not category.is_empty() and hauling_policy.category(job) != category: continue
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
	var storage := {}
	if job.has("warehouse_recovery"):
		storage = warehouse.recovery.reserve_destination(str(a.id),best)
		if not storage.ok:
			job.blocker = str(storage.message)
			return false
	elif warehouse != null and job.destination == "receiving":
		storage = warehouse.reserve(str(a.id),str(job.type),int(best.count))
		if not storage.ok:
			job.blocker = str(storage.message)
			return false
	var claim := ""
	var batch: Array = best.get("batch",[{"stock":str(best.stock.id),"count":int(best.count),"claim":""}])
	var admitted: Array[String] = []
	for part: Dictionary in batch:
		if job.has("warehouse_recovery"):
			claim = str(best.claim)
			part.claim = claim
			continue
		var reservation := "haul-claim-%04d" % _next()
		var result: Dictionary = ledger.request_stock(reservation,part.stock,part.count,a.id,job.id,PLAYER)
		if result.ok: admitted.append(reservation)
		if not result.ok or ledger.inspect_claim(reservation).reserved != int(part.count):
			for retained: String in admitted: ledger.release_claim(retained)
			if not storage.is_empty(): warehouse.release(str(storage.id))
			job.blocker = "Physical source changed before reservation; no partial trip admitted."
			return false
		part.claim = reservation
		if claim.is_empty(): claim = reservation
	a.load = {"job": job.id, "claim": claim, "stock": best.stock.id,
		"source": best.stock.holder_id, "destination": job.destination,
		"type": job.type, "count": best.count, "mass": best.count * best.stock.unit_mass_kg, "carried": ""}
	if best.has("batch"): a.load.batch = batch
	if job.has("warehouse_recovery"): a.load.warehouse_recovery = job.warehouse_recovery
	if not storage.is_empty(): a.load.storage = str(storage.id)
	job.selected += 1
	if not storage.is_empty() and storage.prepare:
		_move(a,"Warehouse visit",walk_path(person.position,storage.point),1.5)
		return true
	if best.has("truck"):
		construction.trucks.start(a,best)
		return true
	job.blocker = str(best.get("fallback",""))+"Approach/pickup/carry/deposit required; reservation is not local stock"
	_move(a, "Approach", walk_path(person.position,stock_work_point(a.id,best.stock,true)) if work_positions != null else best.approach, 1.5)
	_events.append({"time": time, "person": a.id, "job": job.id, "priority": effective_priority(job), "description": "Selected real eligible haul"})
	return true


func _job_option(job: Dictionary, person: Dictionary) -> Dictionary:
	if str(job.type) == "M04":
		job.blocker = "Timber requires two handlers. Onward paired timber hauling is not available in this checkpoint."
		return {}
	if job.has("warehouse_recovery"): return warehouse.recovery.option(job,person)
	if not stores.has(job.destination) or not stores[job.destination].accessible:
		job.blocker = "Destination inaccessible; demand retained"
		return {}
	var best: Dictionary = {}
	var fallback := ""
	var source_ids: Array = [job.source]
	for source_id in job.get("alternative_sources",[]) + job.recovery_sources:
		if source_id not in source_ids: source_ids.append(source_id)
	for source_id in source_ids:
		if not stores.has(source_id) or not stores[source_id].accessible or source_id == job.destination:
			continue
		var stock_options: Array = _stock_at(source_id,false)
		var warehouse_drop := Vector2.INF
		if warehouse != null and source_id == "receiving" and job.destination != "receiving":
			warehouse_drop = work_point(str(person.id),str(job.destination),false)
			if not warehouse_drop.is_finite(): continue
			for stock: Dictionary in stock_options:
				var at: Vector2 = warehouse.stock_service_point(str(stock.id))
				if at.is_finite(): stock.warehouse_bound = person.position.distance_to(at)+at.distance_to(warehouse_drop)
			stock_options.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
				var first: float = float(a.get("warehouse_bound",INF))
				var second: float = float(b.get("warehouse_bound",INF))
				return str(a.id)<str(b.id) if is_equal_approx(first,second) else first<second)
		var utility_considered := false
		for stock in stock_options:
			if stock.design_type != job.type or stock.available <= 0:
				continue
			if not utility_considered and person.duty_id == "hauling" and construction != null and job.type == "M11" and construction.instances.has(job.destination):
				utility_considered = warehouse != null and source_id == "receiving"
				var utility: Dictionary = construction.trucks.option(job,person,stock)
				fallback = str(utility.get("reason",""))
				if utility.has("stock"):
					if best.is_empty() or not best.has("truck") or float(utility.distance) < float(best.distance): best = utility
					continue
			if best.has("truck"): continue
			# The exact service point gives an admissible Euclidean lower bound.
			# Skip only a candidate that cannot improve the best real walk route;
			# never truncate the source list or reuse stale route/stock snapshots.
			if best.has("distance") and stock.has("warehouse_bound") and float(stock.warehouse_bound) >= float(best.distance): continue
			# A shortage needs no carried-mass traversal. Inspect fresh mass only
			# once real freight is eligible; Emergency callers' detached adjusted
			# mass remains intact, and every physical reservation still rechecks.
			if not person.has("contents_mass_kg"): person = ledger.inspect_entity(person.id)
			var count := mini(stock.available, job.requested - job.delivered - _in_flight(job.id))
			if warehouse != null and Packages.TYPES.has(job.type): count = mini(count,Packages.capacity(job.type))
			count = mini(count, int(floor((25.0 - person.contents_mass_kg) / stock.unit_mass_kg)))
			count = mini(count, int(floor(_free_space(job.destination) / stock.unit_mass_kg)))
			if count <= 0 or not _valid_destination(job.destination, job.type, count * stock.unit_mass_kg):
				continue
			var pickup: Vector2 = stock_work_point(person.id,stock,false) if work_positions != null else stock.position
			var drop: Vector2 = warehouse.probe(person.id,job.type,count) if warehouse != null and job.destination == "receiving" else warehouse_drop if warehouse_drop.is_finite() else work_point(person.id,job.destination,false)
			if not pickup.is_finite() or not drop.is_finite(): continue
			var approach: Array = walk_path(person.position,pickup)
			var carry: Array = walk_path(pickup,drop)
			if approach.is_empty() or carry.is_empty():
				continue
			var distance := Layout.length(approach) + Layout.length(carry)
			if best.is_empty() or distance < float(best.distance):
				best = {"job": job, "stock": stock, "count": count, "approach": approach, "distance": distance, "fallback":fallback}
			# Warehouse pickup policy is nearest feasible geometric estimate.
			# Once a real source passes all physical checks, avoid routing every
			# other crate to optimize a small walking difference. Other source
			# stores still compete normally; no quantity or safety rule changes.
			if warehouse_drop.is_finite() and stock.has("warehouse_bound"): break
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
	if warehouse != null and id == warehouse.recovery.STORE:
		return warehouse.recovery.accepts(except_person,type,mass)
	return stores.has(id) and not stores[id].get("source_only",false) and stores[id].accessible and (stores[id].filter.is_empty() or type in stores[id].filter) and _free_space(id, except_person) + EPS >= mass


func _nearest_storage(origin: Vector2, type: String, mass: float, excluded: String = "", person: String = "") -> String:
	var selected := ""
	var distance: float = INF
	for id in stores:
		if id == excluded or stores[id].pile or not _valid_destination(id, type, mass, person):
			continue
		var destination: Vector2 = warehouse.probe(person,type,int(mass),false,origin) if warehouse != null and id == "receiving" else work_point(person,id,false) if work_positions != null else ledger.inspect_entity(id).position
		if not destination.is_finite(): continue
		if not destination.is_finite(): continue
		var route: Array = walk_path(origin,destination)
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
	var storage := {}
	if warehouse != null and destination == "receiving":
		storage = warehouse.reserve(str(a.id),str(a.load.type),int(a.load.count),false)
		if not storage.ok: destination = ""
	if warehouse != null and a.load.has("storage"):
		warehouse.release(str(a.load.storage))
		a.load.erase("storage")
	if not storage.is_empty() and storage.ok: a.load.storage = str(storage.id)
	if destination.is_empty():
		destination = "pile-%04d" % _next()
		ledger.add_place(destination, "Marked recoverable temporary pile; real handling required", origin)
		stores[destination] = {"id": destination, "capacity": a.load.mass, "accessible": true, "filter": [a.load.type], "pile": true}
	a.load.destination = destination
	_job(a.load.job).blocker = "Destination changed; safe delivery to " + destination + ", original demand remains"
	_move(a, "Carry", walk_path(origin,work_point(a.id,destination)), 1.2)


func _deposit(a: Dictionary) -> void:
	if not _valid_destination(a.load.destination, a.load.type, a.load.mass, a.id):
		_reroute(a)
		return
	var load: Dictionary = a.load.duplicate(true)
	var result: Dictionary = ledger.finish_carry(a.id, load.destination,load.has("warehouse_recovery"))
	if not result.ok:
		push_error("Safe hauling deposit failed: " + str(result))
		return
	if load.has("storage"):
		var stored: Dictionary = warehouse.commit(str(load.storage),str(result.entity_id))
		assert(stored.ok,str(stored))
	if warehouse != null: warehouse.release_point(str(a.id))
	var job := _job(load.job)
	if load.destination == job.destination and not job.cancelled:
		job.delivered += load.count
		job.blocker = "Complete" if job.delivered == job.requested else "Remaining physical demand"
	elif not job.cancelled and load.destination not in job.recovery_sources:
		job.recovery_sources.append(load.destination)
	_events.append({"time": time, "person": a.id, "job": load.job, "destination": load.destination, "count": load.count, "description": "Physical deposit"})
	a.load = {}
	if load.has("warehouse_recovery"): warehouse.recovery.deposited(str(result.entity_id))
	var person: Dictionary = ledger.inspect_entity(a.id)
	if person.duty_id != "hauling":
		_report(a)
		if person.duty_id.is_empty(): _rebalance()
	else:
		a.phase = "Idle"
		a.motion = {}
		a.deadline = INF


func _release_load(a: Dictionary) -> void:
	if a.load.has("batch") and construction != null: construction.trucks.release_source_claims(a)
	if warehouse != null:
		if a.load.has("storage"): warehouse.release(str(a.load.storage))
		warehouse.release_point(str(a.id))
	if not a.load.get("claim", "").is_empty() and not a.load.has("warehouse_recovery"):
		ledger.release_claim(a.load.claim)
	a.load = {}
	a.phase = "Idle"
	a.motion = {}
	a.deadline = INF
	a.blocked_since = -1.0


func _stock_at(holder: String, include_mass: bool = true) -> Array:
	return ledger.entities_at(holder,["STOCK"],include_mass).filter(func(e: Dictionary) -> bool: return e.owner == PLAYER and e.quantity > 0)


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


func workforce_snapshot() -> Dictionary:
	# One synchronous read of the real rear pool; no shared-world ledger export
	# or retained cache. Counts use the same assignment/pending predicates.
	var people: Array[Dictionary] = []
	var counts := {}
	for id in actors:
		var person: Dictionary = ledger.inspect_person_status(id)
		person.phase = actors[id].phase
		people.append(person)
		var duty: String = person.duty_id
		if not counts.has(duty): counts[duty] = {"assigned":0,"present":0,"pending":0,"retaining":0}
		counts[duty].assigned += 1
		if actors[id].phase in ["Idle","Unloading"]: counts[duty].present += 1
		if person.pending_assignment == "None" or person.pending_duty == duty: counts[duty].retaining += 1
		if person.pending_assignment != "None":
			var destination: String = person.pending_duty
			if not counts.has(destination): counts[destination] = {"assigned":0,"present":0,"pending":0,"retaining":0}
			counts[destination].pending += 1
	var staffing: Array[Dictionary] = []
	for request in requests.values():
		var row: Dictionary = counts.get(request.id,{"assigned":0,"present":0,"pending":0,"retaining":0})
		staffing.append({"id":request.id,"target":request.target,"positions":request.positions,
			"assigned":row.assigned,"present":row.present,"pending_in":row.pending,
			"reporting_or_active":row.assigned-row.present,
			"shortage":maxi(0,request.target-row.retaining-row.pending),
			"priority":PRIORITIES[request.priority],"requested_at":request.created})
	return {"people":people,"staffing":staffing}

func hauling_snapshot() -> Array[Dictionary]:
	var inspected_jobs: Array[Dictionary] = jobs.duplicate(true)
	for job in inspected_jobs:
		job.age = time - job.created
		job.effective_priority = PRIORITIES[effective_priority(job)]
		job.in_flight = _in_flight(job.id)
		job.emergency_wait_seconds = maxf(0.0, time - job.emergency_contention_since) if job.emergency_contention_since >= 0.0 else 0.0
		job.starved = job.emergency_contention_since >= 0.0 and job.emergency_wait_seconds >= 120.0
		if job.starved: job.blocker = "Starved by explicit Emergency work for at least 120 seconds"
	return inspected_jobs


func snapshot(include_diagnostics: bool = true) -> Dictionary:
	CallLog.record(&"staffing/rear_simulation.gd::snapshot")
	var staffing: Array[Dictionary] = []
	for r in requests.values():
		var assigned := _assigned(r.id)
		var present := _present(r.id)
		var pending := _pending_in(r.id)
		staffing.append({"id": r.id, "target": r.target, "positions": r.positions,
			"assigned": assigned, "pending_in": pending, "present": present, "reporting_or_active": assigned - present,
			"shortage": maxi(0, r.target - _retaining(r.id) - pending), "priority": PRIORITIES[r.priority], "requested_at": r.created})
	var ledger_view: Dictionary = ledger.snapshot(include_diagnostics)
	var people: Array[Dictionary] = []
	for entity in ledger_view.entities:
		if entity.kind != "PERSON": continue
		var p: Dictionary = entity.duplicate(true)
		p.phase = actors[p.id].phase if actors.has(p.id) else "External/away — ineligible"
		p.load = actors[p.id].load.duplicate(true) if actors.has(p.id) else {}
		people.append(p)
	var storage: Array[Dictionary] = []
	for store in stores.values():
		var row: Dictionary = store.duplicate(true)
		row.position = ledger.inspect_entity(store.id,{},false).position
		row.physical_kg = ledger.loose_stock_mass_at(store.id)
		row.reserved_inbound_kg = _reserved_space(store.id, "", false)
		row.reserved_output_kg = _reserved_space(store.id) - row.reserved_inbound_kg
		row.free_kg = _free_space(store.id)
		row.stocks = _stock_at(store.id)
		row.reserved_outbound = 0
		for stock in row.stocks: row.reserved_outbound += stock.reserved
		storage.append(row)
	return {"time": time, "staffing": staffing, "people": people, "stores": storage,
		"jobs": hauling_snapshot(), "workshop": workshop_readiness() if include_diagnostics else {}, "yard": yard.snapshot(),
		"audit": audit() if include_diagnostics else null, "ledger": ledger_view, "events": _events.duplicate(true)}


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
		var actor: Dictionary = actors[id]
		if actor.load.is_empty() or actor.phase == "Source blocked": continue
		if _job(actor.load.job).get("priority",-1) != 3: continue
		var status: Dictionary = ledger.inspect_person_status(id)
		if status.duty_id != "hauling" or status.pending_assignment != "None":
			continue
		# Only an actual Emergency contender needs its fresh retained/carry mass.
		var p: Dictionary = ledger.inspect_entity(id)
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
			if not a.load.has("truck") and a.load.mass + p.contents_mass_kg > 25.0 + EPS and a.phase not in ["Carry", "Drop"]:
				failures.append("Reserved load exceeds retained gear allowance: " + a.id)
			if p.contents_mass_kg > 25.0 + EPS: failures.append("Overweight person: " + a.id)
			if a.phase in ["Carry", "Drop"] and p.carrying_stock_id.is_empty(): failures.append("Carry lacks physical goods: " + a.id)
	for job in jobs:
		if job.delivered < 0 or job.delivered + _in_flight(job.id) > job.requested:
			failures.append("Demand overfilled: " + job.id)
	for r in requests.values():
		if _assigned(r.id) > int(r.positions): failures.append("Too many actual staff positions: " + r.id)
		if _retaining(r.id) + _pending_in(r.id) > int(r.positions): failures.append("Overbooked pending staff positions: " + r.id)
	if not is_equal_approx(yard.fuel + yard.burned, 40.0 if yard.fixture_hull else 0.0) or yard.fuel < 0.0:
		failures.append("Yard fuel conservation")
	return failures


func _assigned(duty: String) -> int:
	var count: int = 0
	for id in actors:
		if ledger.person_has_duty(id, duty): count += 1
	return count


func _committed(duty: String) -> int:
	var count := _assigned(duty)
	for id in actors:
		if ledger.duty_status(id).pending_duty == duty: count += 1
	return count


func _pending_in(duty: String) -> int:
	var count: int = 0
	for id in actors:
		var p: Dictionary = ledger.duty_status(id)
		if p.pending_assignment != "None" and p.pending_duty == duty: count += 1
	return count


func _retaining(duty: String) -> int:
	var count: int = 0
	for id in actors:
		var p: Dictionary = ledger.duty_status(id)
		if p.duty_id == duty and (p.pending_assignment == "None" or p.pending_duty == duty): count += 1
	return count


func _present(duty: String) -> int:
	var count: int = 0
	for id in actors:
		if ledger.person_has_duty(id, duty) and actors[id].phase in ["Idle", "Unloading"]: count += 1
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
