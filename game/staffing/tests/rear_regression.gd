extends SceneTree

const Simulation = preload("res://game/staffing/rear_simulation.gd")
const Layout = preload("res://game/staffing/rear_layout.gd")
const Yard = preload("res://game/staffing/yard_activity.gd")
const Records = preload("res://game/identity/identity_records.gd")
var checks: int = 0
var failures: int = 0
var cases: int = 0


func _initialize() -> void:
	_run("staff priorities, unfilled shares, age and eligibility", _staffing)
	_run("A05 requires present people and local deposited ingredients", _input_gate)
	_run("real source/destination reservations and timed one-type carry", _timed_carry)
	_run("retained gear reduces ordinary carry allowance", _gear)
	_run("before-pickup release and ten-second blocked-source expiry", _source_release)
	_run("A06 safe pending carry handoff and repeated requests", _handoff)
	_run("invalid destination selects nearest storage or recoverable pile", _reroute)
	_run("job priority, complete distance and oldest actual demand", _job_selection)
	_run("waiting age boundaries and explicit Emergency starvation", _aging)
	_run("A06 actual P08 stationary entry, fuel, reserved parking and exit", _driver)
	_run("small layout routes avoid actual footprints", _layout)
	_run("partitioned time and detached inspection preserve facts", _partitioning)
	_run("source restoration preserves claims and unfinished handling", _source_restore)
	_run("storage edits retain contents and generate physical relocation", _storage_edits)
	_run("competing workers never overbook finite destination space", _space_competition)
	_run("qualified incumbent can move to needed instructor duty", _qualified_incumbent)
	_run("station-entry cancellation and repeated driver requests are safe", _entry_interruption)
	_run("aged work wins an actual competing selection", _aged_selection)
	_run("pending release later fills an existing staffing shortage", _post_handoff_staffing)
	_run("finite parking and qualified station cannot be bypassed", _parking_guards)
	_run("actual approach can release only its own claims", _approach)
	_run("staffing priority stays explicit while work ages", _staff_age)
	_run("new duty prefers eligible idle person over a busy incumbent", _idle_selection)
	_run("Emergency warning measures actual contention, not old shortage", _contention_cause)
	_run("access edits retain filters and blocked relocation survives", _filter_and_relocation)
	_run("pending destination handoffs fill target vacancies once", _pending_target_quota)
	_run("repeated storage edits reconcile outstanding physical relocation", _repeated_relocation)
	_run("yard re-entry reports to the current parked hull", _parked_reentry)
	print("G03 regression: %d cases, %d checks, %d failures" % [cases, checks, failures])
	quit(0 if failures == 0 else 1)


func _run(title: String, test: Callable) -> void:
	var before := failures
	var before_checks := checks
	test.call()
	_check(checks > before_checks, "Case executed assertions: " + title)
	cases += 1
	print("%s: %s" % ["PASS" if before == failures else "FAIL", title])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _audit(s: RefCounted) -> void:
	_check(s.audit().is_empty(), "Physical counts, duties, claims and fuel reconcile: " + str(s.audit()))


func _staff(s: RefCounted, duty: String) -> Dictionary:
	for row in s.snapshot().staffing:
		if row.id == duty: return row
	return {}


func _empty(count: int = 1) -> RefCounted:
	var s := Simulation.new("Empty")
	for i in count:
		s.add_person("p%d" % i, false, "None", "duty-depot")
	return s


func _haul(count: int = 50) -> RefCounted:
	var s := _empty()
	s.ledger.add_stock("metal", "M01", count, 1.0, "depot", "army-blue")
	s.request_haul("depot", "workshop_input", "M01", count)
	s.set_target("hauling", 1)
	return s


func _staffing() -> void:
	var s := _empty(3)
	_check(not s.set_target("workshop", 5).ok, "Cannot request a nonexistent fifth F04 position")
	s.set_target("workshop", 4)
	s.set_target("construction", 4)
	_check(_staff(s, "workshop").assigned == 2 and _staff(s, "construction").assigned == 1, "Equal unfilled shares fill oldest request first with limited real people")
	s.set_target("construction", 4, 3)
	_check(_staff(s, "construction").assigned == 3 and _staff(s, "workshop").assigned == 0, "Emergency actually wins competing staffing")
	_check(_staff(s, "construction").present == 0, "Assigned/reporting is not physical presence")
	s.advance_time(300)
	_check(_staff(s, "construction").present == 3, "Three actual people report physically")
	s.set_target("construction", 0)
	s.set_target("workshop", 0)
	s.set_target("training", 2)
	_check(_staff(s, "training").assigned == 0, "Untrained people cannot instruct")
	s.add_person("trained", true)
	s.add_person("qualified", true, "P08")
	s.set_target("yard", 1, 2)
	s.set_target("training", 2)
	_check(_staff(s, "yard").assigned == 1 and _staff(s, "training").assigned == 1, "P08 is eligible for driving and basic-trained people for instruction without doubling one person")
	_check(not s.reassign_person("p0", "yard").ok, "Unqualified person cannot become yard driver")
	_audit(s)


func _input_gate() -> void:
	var s := Simulation.new()
	s.advance_time(300)
	_check(_staff(s, "workshop").present == 2, "Operators actually arrive")
	_check(s.workshop_readiness().status == "Missing Inputs", "Remote depot stock is refused as local input")
	_check(s.workshop_readiness().hauling_shortage, "Missing hauler is actionable")
	_check(s.ledger.available_stock_at("workshop_input", "M01") == 0, "No operator teleports ingredients")
	s.set_target("hauling", 1)
	s.advance_time(300)
	_check(s.workshop_readiness().missing.is_empty(), "Both ingredient types are actually deposited")
	_check(s.workshop_readiness().work == 0 and s.workshop_readiness().consumed == 0 and s.workshop_readiness().output == 0, "G04 production not simulated")
	_check(not s.workshop_readiness().complete_A05_passed, "Full A05 remains G04 integration")
	_check(s.ledger.total_stock("M01") == 2 and s.ledger.total_stock("M02") == 1, "Reference ingredients conserved")
	_audit(s)


func _timed_carry() -> void:
	var s := _haul()
	_check(s.ledger.reserved("metal") == 25, "One real source claim reserves at most 25 kg")
	_check(s._reserved_space("workshop_input") == 25, "Destination space claimed before pickup")
	_check(s.ledger.available_stock_at("workshop_input", "M01") == 0, "Inbound reservation does not grant local material")
	s.advance_time(1.999)
	_check(s.ledger.inspect_entity("p0").carrying_stock_id == "", "Two-second pickup is not skipped")
	s.advance_time(0.001)
	_check(s.actors.p0.phase == "Carry", "Pickup completes at its actual boundary")
	var end: float = s.actors.p0.deadline
	s.advance_time(end - s.time)
	_check(s.actors.p0.phase == "Drop" and s.ledger.available_stock_at("workshop_input", "M01") == 0, "Arrival alone is not deposited stock")
	s.advance_time(2.0)
	_check(s.ledger.available_stock_at("workshop_input", "M01") == 25, "Only two-second putdown completes local receipt")
	_check(s.ledger.total_stock("M01") == 50, "No mass lost or created")
	_audit(s)


func _gear() -> void:
	var s := _empty()
	s.ledger.add_weapon("rifle", "E01", 4.0, "p0", "army-blue", "E02", 10)
	s.ledger.add_stock("metal", "M01", 50, 1.0, "depot", "army-blue")
	s.request_haul("depot", "workshop_input", "M01", 50)
	s.set_target("hauling", 1)
	_check(s.actors.p0.load.count == 21, "Retained four-kg rifle leaves21kg freight allowance")
	s.advance_time(2.0)
	_check(s.ledger.inspect_entity("p0").contents_mass_kg == 25.0, "Personal gear plus load stays within25kg")
	_audit(s)


func _source_release() -> void:
	var s := _haul()
	s.ledger.request_stock("other", "metal", 5, "someone-else", "Independent intent", "army-blue")
	s.reassign_person("p0", "construction")
	_check(s.ledger.reserved("metal") == 5 and s._reserved_space("workshop_input") == 0, "Pre-pickup cancellation returns only its own promises")
	_check(s.ledger.inspect_entity("p0").duty_id == "construction", "Pre-pickup reassignment has one actual duty")
	s = _haul()
	s.set_store("depot", false)
	s.advance_time(9.999)
	_check(s.ledger.reserved("metal") == 25, "Source promise retained before10s")
	s.advance_time(0.001)
	_check(s.ledger.reserved("metal") == 0 and s._reserved_space("workshop_input") == 0, "Unreachable source releases promises at10s")
	_check(s.jobs[0].delivered == 0 and s.jobs[0].requested == 50, "Unreachable demand survives")
	s.set_store("depot", true)
	s.advance_time(300)
	_check(s.jobs[0].delivered == 50, "Restored source can genuinely satisfy retained demand")
	_audit(s)


func _handoff() -> void:
	var s := _haul(25)
	s.advance_time(2)
	s.reassign_person("p0", "construction")
	_check(s.ledger.inspect_entity("p0").duty_id == "hauling" and s.ledger.inspect_entity("p0").pending_duty == "construction", "Old carry duty remains actual")
	_check(s.reassign_person("p0", "construction").ok, "Repeated pending request is idempotent")
	s.advance_time(300)
	_check(s.ledger.available_stock_at("workshop_input", "M01") == 25, "Goods deposited before new duty")
	_check(s.ledger.inspect_entity("p0").duty_id == "construction" and s.ledger.inspect_entity("p0").pending_assignment == "None", "Pending converts once after safety")
	_audit(s)


func _reroute() -> void:
	var s := _haul(25)
	s.advance_time(2)
	s.reassign_person("p0", "construction")
	s.set_store("workshop_input", false)
	_check(s.actors.p0.load.destination == "depot", "Nearest accessible accepting safe storage is selected by real route")
	s.advance_time(2)
	_check(s.ledger.available_stock_at("depot", "M01") == 25 and s.jobs[0].delivered == 0, "Safe return preserves original unmet demand")
	_audit(s)
	s = _haul(25)
	s.advance_time(10)
	s.reassign_person("p0", "construction")
	for id in s.stores.keys(): s.set_store(id, false)
	var pile: String = s.actors.p0.load.destination
	_check(pile.begins_with("pile-") and s.stores[pile].pile, "No safe store creates a marked recoverable pile")
	s.advance_time(2)
	_check(s.ledger.available_stock_at(pile, "M01") == 25, "Actual handling deposits all freight into pile")
	_check(s.ledger.inspect_entity("p0").duty_id == "construction", "Safe pile allows pending duty without deleting goods")
	s.set_store("workshop_input", true)
	s.reassign_person("p0", "hauling")
	s.advance_time(400)
	_check(s.ledger.available_stock_at("workshop_input", "M01") == 25, "The real pile can later satisfy retained demand")
	_audit(s)


func _job_selection() -> void:
	var s := _empty()
	s.ledger.add_stock("metal", "M01", 100, 1, "depot", "army-blue")
	var low: Dictionary = s.request_haul("depot", "receiving", "M01", 1, 0)
	var high: Dictionary = s.request_haul("depot", "workshop_input", "M01", 1, 2)
	s.set_target("hauling", 1)
	_check(s.actors.p0.load.job == high.id and s._job(low.id).selected == 0, "Higher priority beats a nearer accessible carry")
	s = _empty()
	s.ledger.add_stock("metal", "M01", 100, 1, "depot", "army-blue")
	s.request_haul("depot", "workshop_input", "M01", 1)
	var near: Dictionary = s.request_haul("depot", "receiving", "M01", 1)
	s.set_target("hauling", 1)
	_check(s.actors.p0.load.job == near.id, "Shortest complete carry wins equal priority despite age")
	s = _empty()
	s.ledger.add_stock("metal", "M01", 10, 1, "depot", "army-blue")
	var old: Dictionary = s.request_haul("depot", "workshop_input", "M01", 1)
	s.request_haul("depot", "workshop_input", "M01", 1)
	s.set_target("hauling", 1)
	_check(s.actors.p0.load.job == old.id, "Oldest actual job wins equal priority and complete distance")
	_audit(s)


func _aging() -> void:
	var s := _empty()
	s.ledger.add_stock("metal", "M01", 5000, 1, "depot", "army-blue")
	s.request_haul("depot", "workshop_input", "M01", 1, 0)
	s.advance_time(59.999)
	_check(s.effective_priority(s.jobs[0]) == 0, "Low before60s")
	s.advance_time(0.001)
	_check(s.effective_priority(s.jobs[0]) == 1, "Normal at60s")
	s.advance_time(60)
	_check(s.effective_priority(s.jobs[0]) == 2, "High at120s")
	s.advance_time(600)
	_check(s.effective_priority(s.jobs[0]) == 2, "Aging never promotes to Emergency")
	s = _empty()
	s.ledger.add_stock("metal", "M01", 5000, 1, "depot", "army-blue")
	s.request_haul("depot", "receiving", "M01", 1, 0)
	s.request_haul("depot", "materials_input", "M01", 1000, 3)
	s.set_target("hauling", 1)
	s.advance_time(119.999)
	_check(not s.snapshot().jobs[0].starved, "No early starvation report")
	s.advance_time(0.001)
	_check(s.snapshot().jobs[0].starved and s.snapshot().jobs[0].blocker.contains("Emergency"), "Explicit Emergency competition is reported at120s")
	_audit(s)


func _driver() -> void:
	var s := Simulation.new("Driver")
	s.advance_time(2.999)
	_check(s.ledger.inspect_entity("driver-01").crew_station == "", "No premature station occupancy")
	s.advance_time(0.001)
	_check(s.ledger.inspect_entity("driver-01").holder_id == "yard-t01", "Actual P08 physically boards")
	_check(s.yard.start_trip().ok, "Qualified seated driver can start reserved parking trip")
	s.advance_time(1)
	var moving: Vector2 = s.ledger.inspect_entity("yard-t01").position
	_check(moving != Yard.START, "Hull physically moves")
	_check(s.ledger.inspect_entity("driver-01").position == moving, "Driver follows actual hull holder")
	s.reassign_person("driver-01", "construction")
	_check(s.ledger.inspect_entity("driver-01").duty_id == "yard" and s.ledger.inspect_entity("driver-01").pending_duty == "construction", "Moving crew retains old station/duty")
	_check(not s.ledger.move_entity("driver-01", "rear", Vector2.ZERO).ok, "An occupied station prevents a ghost remote driver move")
	s.advance_time(Yard.route_seconds() - 1)
	_check(s.yard.state == "Leaving station" and s.yard.occupied[1] == "yard-t01", "Legal parking precedes exit handling")
	_check(s.ledger.inspect_entity("driver-01").crew_station == "Driver", "Driver stays real until stationary handling ends")
	s.advance_time(3)
	_check(s.yard.driver == "" and s.ledger.inspect_entity("driver-01").crew_station == "", "Station vacated once after parking")
	_check(s.ledger.inspect_entity("driver-01").duty_id == "construction", "New duty starts after safe exit")
	_check(is_equal_approx(s.yard.burned, Yard.route_length() * 0.002), "Actual distance consumes declared road fuel")
	_check(not s.yard.start_trip().ok, "Uncrewed hull cannot move again")
	_audit(s)


func _layout() -> void:
	for source in Layout.FACILITIES:
		for destination in Layout.FACILITIES:
			var points: Array = Layout.path(Layout.door(source), Layout.door(destination))
			_check(not points.is_empty(), "Every bounded facility entrance is reachable: " + source + "/" + destination)
			for i in range(1, points.size()):
				_check(Layout.clear_segment(points[i - 1], points[i]), "Actual path segment clears facility footprints")
	_check(is_equal_approx(Yard.TURN_SPEED / Yard.TURN_RADIUS, PI / 4.0), "Yard arcs obey45degree/s T01 hull turn rate")


func _partitioning() -> void:
	var first := _haul(50)
	var second := _haul(50)
	first.advance_time(250)
	for i in 250: second.advance_time(1)
	_check(first.ledger.available_stock_at("workshop_input", "M01") == second.ledger.available_stock_at("workshop_input", "M01"), "Large advances preserve actual deposits")
	_check(first.ledger.inspect_entity("p0").position.is_equal_approx(second.ledger.inspect_entity("p0").position), "Time partitioning preserves positions")
	var view: Dictionary = first.snapshot()
	view.people[0].duty_id = "invented"
	view.stores[0].capacity = 0
	_check(first.ledger.inspect_entity("p0").duty_id == "hauling" and first.stores.receiving.capacity == 5000, "Inspection is detached")
	_audit(first)
	_audit(second)


func _source_restore() -> void:
	var s := _haul(25)
	s.advance_time(1)
	s.set_store("depot", false)
	s.advance_time(5)
	s.set_store("depot", true)
	_check(s.ledger.reserved("metal") == 25 and s.actors.p0.phase == "Pickup", "Restoring before10s retains original source promise")
	s.advance_time(0.999)
	_check(s.actors.p0.phase == "Pickup", "Completed pickup work is preserved while blocked")
	s.advance_time(0.001)
	_check(s.actors.p0.phase == "Carry", "Remaining pickup handling completes exactly once")
	_audit(s)


func _storage_edits() -> void:
	var s := _empty()
	s.ledger.add_stock("stored", "M02", 40, 1, "depot", "army-blue")
	s.set_store("depot", true, 10000, ["M01"])
	_check(s.ledger.total_stock("M02") == 40 and s.ledger.available_stock_at("depot", "M02") == 40, "Filter edit preserves all existing contents")
	_check(s.jobs.size() == 1 and s.jobs[0].requested == 40, "Filter change creates actual relocation intent")
	s.set_target("hauling", 1)
	s.advance_time(400)
	_check(s.ledger.total_stock("M02") == 40 and s.ledger.available_stock_at("depot", "M02") == 0, "Only real hauling relocates filtered stock")
	_audit(s)
	s = _empty()
	s.ledger.add_stock("stored", "M01", 40, 1, "depot", "army-blue")
	s.set_store("depot", true, 10)
	_check(s.jobs.size() == 1 and s.jobs[0].requested == 30, "Space reduction stages only actual excess")
	s.set_target("hauling", 1)
	s.advance_time(400)
	_check(s.ledger.available_stock_at("depot", "M01") == 10 and s.ledger.total_stock("M01") == 40, "Existing excess relocates without deletion")
	_audit(s)


func _space_competition() -> void:
	var s := _empty(2)
	s.ledger.add_stock("stored", "M04", 999, 1, "workshop_input", "army-blue")
	s.ledger.add_stock("metal", "M01", 50, 1, "depot", "army-blue")
	s.request_haul("depot", "workshop_input", "M01", 50)
	s.set_target("hauling", 2)
	_check(s._reserved_space("workshop_input") == 1 and s.ledger.reserved("metal") == 1, "Only one actual free kg is promised across two real haulers")
	s.advance_time(300)
	_check(s.ledger.loose_stock_mass_at("workshop_input") == 1000 and s.jobs[0].delivered == 1, "Full bay leaves remaining demand/source stock intact")
	_audit(s)


func _qualified_incumbent() -> void:
	var s := Simulation.new("Empty")
	s.add_person("first-qualified", true)
	s.add_person("second-untrained")
	s.set_target("workshop", 2)
	s.advance_time(200)
	s.set_target("training", 1)
	_check(s.ledger.inspect_entity("first-qualified").duty_id == "training" and _staff(s, "workshop").assigned == 1, "A qualified incumbent is not trapped behind an ineligible idle donor")
	_audit(s)


func _entry_interruption() -> void:
	var s := Simulation.new("Driver")
	s.advance_time(1)
	s.set_target("yard", 0)
	s.advance_time(5)
	_check(s.yard.driver == "" and s.yard.state == "Parked", "Cancelling reporting/station entry cannot later seat a reassigned driver")
	_check(s.ledger.inspect_entity("driver-01").crew_station == "", "No ghost station from cancelled entry")
	s = Simulation.new("Driver")
	s.advance_time(3)
	s.yard.start_trip()
	s.reassign_person("driver-01", "construction")
	_check(s.reassign_person("driver-01", "construction").ok, "Repeated moving-driver request is idempotent")
	s.advance_time(100)
	_check(s.yard.driver == "" and s.ledger.inspect_entity("driver-01").duty_id == "construction", "One physical exit completes the one pending duty")
	_audit(s)


func _aged_selection() -> void:
	var s := _empty()
	s.ledger.add_stock("metal", "M01", 100, 1, "depot", "army-blue")
	var old: Dictionary = s.request_haul("depot", "workshop_input", "M01", 1, 0)
	s.advance_time(60)
	var near: Dictionary = s.request_haul("depot", "receiving", "M01", 1, 0)
	s.set_target("hauling", 1)
	_check(s.actors.p0.load.job == old.id and s._job(near.id).selected == 0, "Promotion changes an actual limited-worker decision despite a nearer new job")
	_audit(s)


func _post_handoff_staffing() -> void:
	var s := _haul(25)
	s.advance_time(2)
	s.set_target("hauling", 0)
	s.set_target("workshop", 1)
	_check(_staff(s, "workshop").assigned == 0 and _staff(s, "hauling").assigned == 1, "Pending release is not a second worker")
	s.advance_time(300)
	_check(_staff(s, "workshop").present == 1 and _staff(s, "hauling").assigned == 0, "Freed real person fills existing shortage after safe deposit")
	s.add_person("outside", true, "P08", "away")
	_check(not s.reassign_person("outside", "yard").ok, "Physically away people cannot be borrowed")
	_audit(s)


func _parking_guards() -> void:
	var s := Simulation.new("Driver")
	_check(not s.yard.start_trip().ok, "Station handling must finish before movement")
	s.advance_time(3)
	s.ledger.add_carrier("occupied-hull", "yard-finish", "army-blue", "army-blue", "T01")
	s.yard.occupied[1] = "occupied-hull"
	var position: Vector2 = s.ledger.inspect_entity("yard-t01").position
	_check(not s.yard.start_trip().ok and s.ledger.inspect_entity("yard-t01").position == position, "Occupied finite parking rejects movement without deleting the other hull")
	_check(not s.ledger.begin_carry("driver-01", "missing-stock", 1).ok, "A seated driver cannot become a simultaneous hauler")
	_audit(s)


func _approach() -> void:
	var s := Simulation.new("Approach")
	_check(s.actors["worker-01"].phase == "Approach" and s.ledger.reserved("fixture-metal") == 25, "Worker genuinely approaches a remote source with both reservations")
	s.advance_time(1)
	var position: Vector2 = s.ledger.inspect_entity("worker-01").position
	_check(position != Layout.door("depot") and position != Layout.door("receiving"), "Approach moves continuously without reaching pickup early")
	s.set_target("hauling", 0)
	_check(s.ledger.reserved("fixture-metal") == 0 and s._reserved_space("workshop_input") == 0, "Approach cancellation releases its own source/output claims")
	_check(s.ledger.inspect_entity("worker-01").position == position and s.ledger.total_stock("M01") == 50, "Stopping approach neither teleports the person nor deletes goods")
	_audit(s)


func _staff_age() -> void:
	var s := _empty()
	s.set_target("workshop", 4, 0)
	s.ledger.add_stock("metal", "M01", 5, 1, "depot", "army-blue")
	s.request_haul("depot", "workshop_input", "M01", 1, 0)
	s.advance_time(120)
	_check(_staff(s, "workshop").priority == "Low" and _staff(s, "workshop").shortage == 3, "Unfilled staffing request remains player-set Low after120s")
	_check(s.effective_priority(s.jobs[0]) == 2, "Queued Low work becomes High after120s without stealing an operator")
	_check(s.ledger.inspect_entity("p0").duty_id == "workshop", "Job aging never moves staff between pools")
	_audit(s)


func _idle_selection() -> void:
	var s := Simulation.new("Empty")
	s.add_person("untrained-busy")
	s.set_target("workshop", 1)
	s.advance_time(100)
	s.add_person("trained-idle", true)
	s.set_target("hauling", 1)
	_check(s.ledger.inspect_entity("trained-idle").duty_id == "hauling", "New request uses an eligible idle person before taking a busy less-qualified operator")
	_check(s.ledger.inspect_entity("untrained-busy").duty_id == "workshop", "Existing fulfilled operator duty is retained")
	_audit(s)


func _contention_cause() -> void:
	var s := _empty()
	s.ledger.add_stock("metal", "M01", 5000, 1, "depot", "army-blue")
	s.request_haul("depot", "receiving", "M01", 1, 0)
	s.advance_time(300)
	_check(not s.snapshot().jobs[0].starved, "Old request without staff does not claim Emergency starvation")
	s.request_haul("depot", "materials_input", "M01", 1000, 3)
	s.set_target("hauling", 1)
	_check(not s.snapshot().jobs[0].starved, "New Emergency contention does not inherit300s of missing-staff age")
	s.advance_time(119.999)
	_check(not s.snapshot().jobs[0].starved, "Warning waits for real120s Emergency contention")
	s.advance_time(0.001)
	_check(s.snapshot().jobs[0].starved, "Actual contention produces warning after120s")
	s.set_store("receiving", false)
	_check(not s.snapshot().jobs[0].starved, "Independent access blockage replaces the Emergency contention cause")
	_audit(s)


func _filter_and_relocation() -> void:
	var s := _empty()
	for id in s.stores.keys(): s.set_store(id, false)
	s.ledger.add_stock("first", "M02", 15, 1, "depot", "army-blue")
	s.ledger.add_stock("second", "M02", 25, 1, "depot", "army-blue")
	s.set_store("depot", false, 10000, ["M01"])
	_check(s.jobs.size() == 1 and s.jobs[0].requested == 40, "All physical portions of one filtered type retain relocation demand despite blocked storage")
	s.set_store("depot", true)
	_check(s.stores.depot.filter == ["M01"], "Access restoration does not silently remove the storage filter")
	s.set_target("hauling", 1)
	s.advance_time(10)
	_check(s.jobs[0].delivered == 0 and s.ledger.total_stock("M02") == 40, "Blocked relocation preserves real contents")
	s.set_store("receiving", true)
	s.advance_time(400)
	_check(s.jobs[0].delivered == 40 and s.ledger.available_stock_at("receiving", "M02") == 40, "Restored destination allows real relocation of every original portion")
	_audit(s)


func _pending_target_quota() -> void:
	var s := _haul(25)
	s.advance_time(2)
	s.set_target("workshop", 1, 3)
	_check(s.ledger.inspect_entity("p0").pending_duty == "workshop", "Carrying person reserves the one Workshop target vacancy")
	s.add_person("newcomer", false, "None", "duty-depot")
	_check(_staff(s, "workshop").pending_in == 1 and _staff(s, "workshop").shortage == 0 and _staff(s, "workshop").assigned == 0, "Inspection separates the one pending target commitment from actual staff")
	for repeat in 3: s.set_target("workshop", 1, 3)
	_check(s.ledger.inspect_entity("newcomer").duty_id != "workshop", "Arrival/reconciliation does not fill the same pending destination target again")
	s.advance_time(300)
	_check(_staff(s, "workshop").assigned == 1 and _staff(s, "workshop").present == 1, "Safe completion leaves exactly one actual Workshop person for target1")
	_audit(s)
	s = _haul(50)
	s.advance_time(2)
	s.set_target("workshop", 2, 3)
	s.add_person("second", false, "None", "duty-depot")
	s.add_person("third", false, "None", "duty-depot")
	_check(_staff(s, "workshop").assigned == 1, "Target2 admits one newcomer alongside one pending carry, not two")
	s.set_target("workshop", 0, 3)
	_check(s.ledger.inspect_entity("p0").pending_duty != "workshop" and s.actors.p0.phase == "Carry", "Target cancellation removes destination intent without interrupting its safe carry")
	s.set_target("workshop", 1, 3)
	s.advance_time(300)
	_check(_staff(s, "workshop").assigned == 1, "Target edit/repeated reconciliation preserves a single target allocation after staggered completion")
	_audit(s)


func _repeated_relocation() -> void:
	var s := _empty()
	s.ledger.add_stock("stored", "M01", 40, 1, "depot", "army-blue")
	s.set_store("depot", true, 30)
	var original_id: String = s.jobs[0].id
	s.advance_time(12)
	s.set_store("depot", true, 10)
	for repeat in 3: s.set_store("depot", true, 10)
	_check(s.jobs.size() == 1 and s.jobs[0].requested == 30, "Repeated reduction expands the existing10kg request to30kg without duplicate jobs")
	_check(s.jobs[0].id == original_id and s.jobs[0].created == 0.0, "Outstanding relocation keeps original demand identity/age")
	s.set_target("hauling", 1)
	s.advance_time(300)
	_check(s.ledger.available_stock_at("depot", "M01") == 10 and s.ledger.total_stock("M01") == 40, "All30kg excess physically leaves the10kg depot")
	_audit(s)
	s = _empty()
	s.ledger.add_stock("stored", "M01", 40, 1, "depot", "army-blue")
	s.set_store("depot", true, 30)
	s.set_target("hauling", 1)
	s.advance_time(2)
	_check(s.actors.p0.load.count == 10 and s.actors.p0.phase == "Carry", "First relocation is a real10kg in-flight carry")
	s.set_store("depot", true, 10)
	for repeat in 3: s.set_store("depot", true, 10)
	_check(s.jobs.size() == 1 and s.jobs[0].requested == 30 and s.jobs[0].delivered == 0, "In-flight10 plus physical20 excess yields30 total, not20 or40")
	s.advance_time(300)
	_check(s.jobs[0].delivered == 30 and s.ledger.available_stock_at("depot", "M01") == 10, "In-flight repeated edits deliver exactly30 once")
	_audit(s)
	s = _empty()
	s.ledger.add_stock("stored", "M01", 40, 1, "depot", "army-blue")
	s.set_store("depot", true, 30)
	s.set_target("hauling", 1)
	_check(s.ledger.reserved("stored") == 10, "First relocation is reserved but not picked up")
	s.set_store("depot", true, 10)
	_check(s.jobs[0].requested == 30 and s.ledger.reserved("stored") == 10, "Source contents already include the10 reserved units; reduction adds only20")
	s.advance_time(300)
	_check(s.jobs[0].delivered == 30 and s.ledger.available_stock_at("depot", "M01") == 10, "Repeated edit before pickup removes exactly30")
	_audit(s)
	s = _empty()
	s.ledger.add_stock("stored", "M01", 60, 1, "depot", "army-blue")
	s.set_store("depot", true, 30)
	s.set_target("hauling", 1)
	s.advance_time(2)
	s.advance_time(s.actors.p0.deadline - s.time + 2)
	_check(s.jobs[0].delivered == 25, "First part is actually deposited while original request remains active")
	s.set_store("depot", true, 10)
	_check(s.jobs[0].requested == 50, "Delivered25 plus remaining physical25 yields50 total, retaining prior progress")
	s.advance_time(300)
	_check(s.jobs[0].delivered == 50 and s.ledger.available_stock_at("depot", "M01") == 10 and s.ledger.total_stock("M01") == 60, "Already delivered progress and repeated reduction reconcile exactly")
	_audit(s)
	s = _empty()
	s.ledger.add_stock("first", "M02", 15, 1, "depot", "army-blue")
	s.set_store("depot", true, 10000, ["M01"])
	s.set_target("hauling", 1)
	s.advance_time(2)
	s.ledger.add_stock("second", "M02", 25, 1, "depot", "army-blue")
	s.set_store("depot", true, 10000, ["M01"])
	for repeat in 3: s.set_store("depot", true, 10000, ["M01"])
	_check(s.jobs.size() == 1 and s.jobs[0].requested == 40, "New filtered portions extend the same request around an existing carry")
	s.advance_time(300)
	_check(s.jobs[0].delivered == 40 and s.ledger.available_stock_at("depot", "M02") == 0 and s.ledger.total_stock("M02") == 40, "Every disallowed portion relocates without duplicates/loss")
	_audit(s)


func _parked_reentry() -> void:
	var s := Simulation.new("Driver")
	s.advance_time(3)
	s.yard.start_trip()
	s.set_target("yard", 0)
	s.advance_time(60)
	var fuel: float = s.yard.fuel
	var distance: float = s.yard.distance
	_check(s.yard.state == "Parked" and s.ledger.inspect_entity("yard-t01").position == Yard.FINISH, "First physical trip parks at its real end place")
	s.set_target("yard", 1)
	s.advance_time(3)
	_check(s.yard.state == "Ready" and s.ledger.inspect_entity("driver-01").holder_id == "yard-t01", "Qualified person re-enters at the parked hull after3s stationary handling")
	_check(s.yard.fuel == fuel and s.yard.distance == distance and s.yard.occupied[1] == "yard-t01", "Re-entry preserves fuel, completed distance and finite occupied parking")
	_check(not s.yard.start_trip().ok, "Re-entry does not invent a second trip or clear occupied destination")
	s.set_target("yard", 0)
	s.advance_time(3)
	s.ledger.move_entity("driver-01", "rear", Yard.START)
	s.set_target("yard", 1)
	s.advance_time(1)
	var position: Vector2 = s.ledger.inspect_entity("driver-01").position
	_check(position != Yard.START and position != Yard.FINISH, "Reporting approaches the current hull instead of staying at its obsolete start")
	s.set_target("yard", 0)
	s.advance_time(10)
	_check(s.yard.driver == "" and s.ledger.inspect_entity("driver-01").position == position, "Cancelling approach preserves actual position and empty station")
	s.set_target("yard", 1)
	s.advance_time(6)
	_check(s.yard.state == "Entering station", "Re-entry requires completing actual approach before3s station entry")
	s.set_target("yard", 0)
	s.advance_time(10)
	_check(s.yard.state == "Parked" and s.yard.driver == "" and s.ledger.inspect_entity("driver-01").crew_station == "", "Cancelling new-position station entry cannot create a delayed ghost driver")
	_audit(s)
