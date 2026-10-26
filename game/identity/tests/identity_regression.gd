extends SceneTree
## Executable behavioral checks: no editor plugin or third-party test dependency.

const Fixture = preload("res://game/identity/identity_fixture.gd")
const Ledger = preload("res://game/identity/identity_ledger.gd")
const Records = preload("res://game/identity/identity_records.gd")

var _failures: int = 0
var _checks: int = 0
var _cases: int = 0


func _initialize() -> void:
	_run_case("creation and identity are unique", _creation)
	_run_case("A01 safe handoff has one active duty", _safe_handoff)
	_run_case("interruption preserves duty and freight", _cancel_handoff)
	_run_case("active carry cannot be stolen or overfilled", _carry_protection)
	_run_case("reload cannot consume a carry pending safe duty handoff", _carry_reload_guard)
	_run_case("A02 reservations, delivery, cancellation and retry", _reservations)
	_run_case("mismatched and foreign claims leave state unchanged", _invalid_claims)
	_run_case("partial demand never invents stock", _partial_demand)
	_run_case("loaded rounds follow the same intact weapon", _ammunition)
	_run_case("loaded, incompatible and reserved rounds are protected", _invalid_ammunition)
	_run_case("consumption and loss reconcile with physical counts", _removals)
	_run_case("remote ownership is not local delivery", _physical_location)
	_run_case("inspection cannot mutate authoritative state", _detached_inspection)
	_run_case("fixed-seed mixed transitions preserve every invariant", _mixed_transitions)
	print("G01 regression: %d cases, %d checks, %d failures" % [_cases, _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _run_case(title: String, test: Callable) -> void:
	var before := _failures
	test.call()
	_cases += 1
	print("%s: %s" % ["PASS" if before == _failures else "FAIL", title])


func _fresh() -> Fixture:
	var fixture := Fixture.new()
	fixture.reset()
	_check(fixture.ledger.audit().is_empty(), "Initial fixture reconciles")
	return fixture


func _creation() -> void:
	var f := _fresh()
	var ledger := f.ledger
	_rejected(ledger, func() -> Dictionary: return ledger.add_person("worker-01", "rear-store", "army-blue"), "INVALID_ENTITY")
	_rejected(ledger, func() -> Dictionary: return ledger.add_stock("steel-01", "M01 Steel", 5, 1.0, "rear-store", "army-blue"), "INVALID_STOCK")
	_rejected(ledger, func() -> Dictionary: return ledger.add_stock("negative", "M01 Steel", -1, 1.0, "rear-store", "army-blue"), "INVALID_STOCK")
	_rejected(ledger, func() -> Dictionary: return ledger.add_stock("bad-mass", "M01 Steel", 1, NAN, "rear-store", "army-blue"), "INVALID_STOCK")
	_rejected(ledger, func() -> Dictionary: return ledger.add_place("bad-position", "Invalid", Vector2(INF, 0.0)), "INVALID_ENTITY")
	_check(ledger.total_stock("E01 Rifle") == 11, "Ten depot rifles plus one distinct personal weapon")
	_check(ledger.total_stock("E02 Round") == 60, "Initial loading does not create ammunition")
	var person := ledger.inspect_entity("worker-01")
	_check(person.health == 100 and person.morale == 60 and person.suppression == 0, "Documented person defaults")
	_check(person.qualification == "None" and not person.basic_training, "No free qualifications")
	_check(ledger.inspect_entity("rifle-11").functional, "An intact weapon has independent functionality")


func _safe_handoff() -> void:
	var f := _fresh()
	var ledger := f.ledger
	var person_before := ledger.inspect_entity("worker-01")
	_success(ledger.begin_carry("worker-01", "steel-01", 5))
	_success(ledger.advance_time(2.0))
	_success(ledger.request_assignment("worker-01", Records.Assignment.TRAINING, "course-fixture"))
	var waiting := ledger.inspect_entity("worker-01")
	_check(waiting.assignment == "Rear Labour" and waiting.pending_assignment == "Training", "Only labour active while handoff waits")
	_check(not waiting.blocked_reason.is_empty(), "Safe-handoff blocker is inspectable")
	_check(_duty_count(ledger, "Rear Labour") == 1 and _duty_count(ledger, "Training") == 0, "Pending training contributes no training duty")
	_rejected(ledger, func() -> Dictionary: return ledger.finish_carry("worker-01", "far-hq"), "NOT_COLOCATED")
	_success(ledger.advance_time(4.0))
	_success(ledger.finish_carry("worker-01", "rear-store"))
	var after := ledger.inspect_entity("worker-01")
	_check(after.id == person_before.id and after.holder_id == person_before.holder_id, "Duty handoff preserves physical person identity and holder")
	_check(after.created_at == 0.0 and after.state_entered_at == 6.0, "Creation and state times remain distinct simulation times")
	_check(after.assignment == "Training" and after.pending_assignment == "None" and after.carrying_stock_id.is_empty(), "Handoff clears only the finished carry and pending request")
	_check(_duty_count(ledger, "Rear Labour") == 0 and _duty_count(ledger, "Training") == 1, "No ghost labour after assignment changes")
	_check(ledger.total_stock("M01 Steel") == 5, "Deposit preserves all steel")
	_rejected(ledger, func() -> Dictionary: return ledger.finish_carry("worker-01", "rear-store"), "NO_CARRY")
	_rejected(ledger, func() -> Dictionary: return ledger.advance_time(-1.0), "INVALID_TIME")
	_rejected(ledger, func() -> Dictionary: return ledger.advance_time(INF), "INVALID_TIME")


func _cancel_handoff() -> void:
	var f := _fresh()
	var ledger := f.ledger
	_success(ledger.begin_carry("worker-01", "steel-01", 5))
	_success(ledger.request_assignment("worker-01", Records.Assignment.TRAINING, "course-fixture"))
	var carried_id: String = ledger.inspect_entity("worker-01").carrying_stock_id
	_rejected(ledger, func() -> Dictionary: return ledger.request_assignment("worker-01", Records.Assignment.AVAILABLE, ""), "HANDOFF_PENDING")
	_success(ledger.cancel_assignment_request("worker-01"))
	var person := ledger.inspect_entity("worker-01")
	_check(person.assignment == "Rear Labour" and person.pending_assignment == "None", "Cancellation preserves the current duty")
	_check(person.carrying_stock_id == carried_id and ledger.inspect_entity(carried_id).quantity == 5, "Cancellation neither deletes nor deposits carried goods")
	_rejected(ledger, func() -> Dictionary: return ledger.cancel_assignment_request("worker-01"), "NO_PENDING_DUTY")
	_success(ledger.finish_carry("worker-01", "rear-store"))
	_check(ledger.inspect_entity("worker-01").assignment == "Rear Labour", "Cancelled training cannot reappear at later deposit")
	_rejected(ledger, func() -> Dictionary: return ledger.request_assignment("worker-01", Records.Assignment.FORMATION_DUTY, "squad"), "UNSUPPORTED_DUTY")


func _carry_protection() -> void:
	var f := _fresh()
	var ledger := f.ledger
	_rejected(ledger, func() -> Dictionary: return ledger.begin_carry("worker-01", "rifles-01", 10), "CARRY_TOO_HEAVY")
	_success(ledger.begin_carry("worker-01", "steel-01", 5))
	var carried_id: String = ledger.inspect_entity("worker-01").carrying_stock_id
	_rejected(ledger, func() -> Dictionary: return ledger.begin_carry("worker-01", "steel-01", 1), "PERSON_BUSY")
	_rejected(ledger, func() -> Dictionary: return ledger.transfer_stock(carried_id, 1, "receiving"), "CARRY_IN_PROGRESS")
	_rejected(ledger, func() -> Dictionary: return ledger.record_loss(carried_id, 1, "Invalid active-carry removal"), "STOCK_COMMITTED")
	_rejected(ledger, func() -> Dictionary: return ledger.request_stock("carry-claim", carried_id, 1, "Request", "Invalid carry claim", "army-blue"), "STOCK_COMMITTED")
	_rejected(ledger, func() -> Dictionary: return ledger.finish_carry("worker-01", "supplier-truck"), "INVALID_SAFE_STORAGE")
	_success(ledger.finish_carry("worker-01", "rear-store"))
	_check(ledger.audit().is_empty(), "Carry lifecycle reconciles")


func _carry_reload_guard() -> void:
	# Both partial and complete reloads must preserve freight committed to a job.
	for reload_quantity in [1, 10]:
		var f := _fresh()
		var ledger := f.ledger
		_success(ledger.unload_rounds("rifle-11"))
		var depot_portion := ledger.transfer_stock("rounds-01", 10, "rear-store")
		_success(depot_portion)
		_success(ledger.request_assignment("person-02", Records.Assignment.REAR_LABOUR, "haul"))
		_success(ledger.begin_carry("person-02", depot_portion.entity_id, 10))
		var carrying_id: String = ledger.inspect_entity("person-02").carrying_stock_id
		_success(ledger.request_assignment("person-02", Records.Assignment.TRAINING, "course"))
		_rejected(ledger, func() -> Dictionary: return ledger.load_rounds("rifle-11", carrying_id, reload_quantity), "STOCK_COMMITTED")
		var carried := ledger.inspect_entity(carrying_id)
		_check(carried.quantity == 10 and carried.holder_id == "person-02", "Rejected reload preserves the full physically carried portion")
		_check(ledger.loaded_rounds("rifle-11") == 0 and ledger.total_stock("E02 Round") == 60, "Rejected reload preserves loaded/loose quantities without moving rounds")
		_check(ledger.audit().is_empty(), "Rejected reload leaves a healthy active-carry pointer")
		_success(ledger.finish_carry("person-02", "rear-store"))
		var person := ledger.inspect_entity("person-02")
		_check(person.assignment == "Training" and person.pending_assignment == "None" and person.carrying_stock_id.is_empty(), "Safe deposit still completes the requested exclusive duty handoff")
		_check(ledger.total_stock("E02 Round") == 60 and ledger.audit().is_empty(), "Post-handoff physical ammunition and accounting still reconcile")


func _reservations() -> void:
	var f := _fresh()
	var ledger := f.ledger
	_success(f.request_rifles("claim-A"))
	_success(f.request_rifles("claim-B"))
	_check(ledger.inspect_entity("rifles-01").quantity == 10 and ledger.inspect_entity("rifles-01").holder_id == "rear-store", "Reservation does not move or consume rifles")
	_check(ledger.reserved("rifles-01") == 10 and ledger.available("rifles-01") == 0, "Competing requests cannot reserve more than ten")
	_check(ledger.inspect_claim("claim-B").unfilled == 10 and not ledger.inspect_claim("claim-B").blocked_reason.is_empty(), "Unfilled second demand stays explicit")
	_rejected(ledger, func() -> Dictionary: return ledger.transfer_stock("rifles-01", 1, "supplier-truck"), "STOCK_RESERVED")
	var transfer := ledger.transfer_stock("rifles-01", 4, "supplier-truck", "claim-A")
	_success(transfer)
	var cargo := ledger.inspect_entity(transfer.entity_id)
	_check(cargo.quantity == 4 and cargo.owner == "army-blue" and cargo.holder_id == "supplier-truck", "Loaded goods retain purchaser ownership")
	var carrier := ledger.inspect_entity("supplier-truck")
	_check(carrier.owner == "supplier" and carrier.controller == "army-blue", "Carrier ownership and control stay independent")
	_check(is_equal_approx(carrier.contents_mass_kg, 16.0), "Cargo mass follows actual four rifles")
	_check(ledger.inspect_claim("claim-A").fulfilled == 4 and ledger.reserved("rifles-01") == 6, "Moving reserved stock fulfills the matching claim once")
	_success(ledger.release_claim("claim-A"))
	_check(ledger.inspect_entity(transfer.entity_id).quantity == 4 and ledger.available("rifles-01") == 6, "Cancelling does not unload delivered goods")
	_rejected(ledger, func() -> Dictionary: return ledger.release_claim("claim-A"), "NO_ACTIVE_CLAIM")
	_success(ledger.reserve_remaining("claim-B"))
	_check(ledger.inspect_claim("claim-B").reserved == 6 and ledger.inspect_claim("claim-B").unfilled == 4, "Retry claims only the actual remaining six")
	_success(ledger.transfer_stock("rifles-01", 6, "supplier-truck", "claim-B"))
	_check(ledger.inspect_entity("rifles-01").quantity == 0 and ledger.inspect_entity("rifles-01").holder_id == "rear-store", "Depleted source remains at origin")
	_check(ledger.inspect_claim("claim-B").source_id == "rifles-01" and ledger.inspect_claim("claim-B").unfilled == 4, "Unmet demand does not follow delivered cargo")
	_check(ledger.total_stock("E01 Rifle") == 11 and ledger.audit().is_empty(), "Transfers reconcile all eleven rifles including the personal weapon")


func _invalid_claims() -> void:
	var f := _fresh()
	var ledger := f.ledger
	_success(f.request_rifles("claim-A"))
	_rejected(ledger, func() -> Dictionary: return f.request_rifles("claim-A"), "INVALID_REQUEST")
	_rejected(ledger, func() -> Dictionary: return ledger.request_stock("worker-01", "rifles-01", 1, "A", "Conflict", "army-blue"), "INVALID_REQUEST")
	_rejected(ledger, func() -> Dictionary: return ledger.request_stock("foreign", "rifles-01", 1, "Supplier", "Foreign claim", "supplier"), "NOT_OWNED")
	_rejected(ledger, func() -> Dictionary: return ledger.request_stock("negative", "rifles-01", -1, "A", "Invalid", "army-blue"), "INVALID_REQUEST")
	_rejected(ledger, func() -> Dictionary: return ledger.transfer_stock("steel-01", 1, "receiving", "claim-A"), "CLAIM_MISMATCH")
	_rejected(ledger, func() -> Dictionary: return ledger.transfer_stock("rifles-01", 1, "receiving", "missing"), "NO_ACTIVE_CLAIM")
	_success(ledger.release_claim("claim-A"))
	_rejected(ledger, func() -> Dictionary: return ledger.reserve_remaining("claim-A"), "NO_ACTIVE_CLAIM")


func _partial_demand() -> void:
	var f := _fresh()
	var ledger := f.ledger
	_success(ledger.request_stock("first", "steel-01", 7, "Fixture A", "Partial demand", "army-blue"))
	_success(ledger.request_stock("second", "steel-01", 7, "Fixture B", "Competing demand", "army-blue"))
	_check(ledger.inspect_claim("first").reserved == 5 and ledger.inspect_claim("first").unfilled == 2, "A request preserves both partial grant and unmet amount")
	_check(ledger.inspect_claim("second").reserved == 0 and ledger.inspect_claim("second").unfilled == 7, "No negative availability for another request")
	_success(ledger.reserve_remaining("first"))
	_check(ledger.reserved("steel-01") == 5, "Retry cannot reserve its own reservation again")
	_success(ledger.release_claim("first"))
	_check(ledger.inspect_claim("second").reserved == 0, "Release does not invent an automatic scheduling policy")
	_success(ledger.reserve_remaining("second"))
	_check(ledger.inspect_claim("second").reserved == 5, "Explicit retry can claim newly available physical goods")


func _ammunition() -> void:
	var f := _fresh()
	var ledger := f.ledger
	var loaded_id := _loaded_id(ledger)
	_check(f.loose_rounds_at("person-02") == 50 and ledger.loaded_rounds("rifle-11") == 10, "Initial 60 rounds split into loose 50 and loaded 10")
	_check(ledger.inspect_entity(loaded_id).available == 0, "Loaded rounds are actual stock but unavailable for loose-stock allocation")
	_success(f.handoff_weapon())
	_check(ledger.inspect_entity("rifle-11").holder_id == "person-03", "Same weapon reaches new physical holder")
	_check(ledger.inspect_entity(loaded_id).holder_id == "rifle-11", "Loaded ammunition keeps its existing weapon holder identity")
	_check(f.loose_rounds_at("person-02") == 50 and f.loose_rounds_at("person-03") == 0, "Weapon handoff does not move unrelated loose ammunition")
	_check(is_equal_approx(ledger.inspect_entity("person-02").contents_mass_kg, 1.0), "Former holder no longer carries the loaded rifle's mass")
	_check(is_equal_approx(ledger.inspect_entity("person-03").contents_mass_kg, 4.2), "New holder carries weapon plus loaded-round mass once")
	_success(ledger.unload_rounds("rifle-11"))
	_check(f.loose_rounds_at("person-03") == 10 and ledger.loaded_rounds("rifle-11") == 0, "Unloading uses current holder, not former operator")
	_rejected(ledger, func() -> Dictionary: return ledger.unload_rounds("rifle-11"), "NO_LOADED_ROUNDS")
	_success(f.load_ten())
	_check(ledger.loaded_rounds("rifle-11") == 10 and ledger.total_stock("E02 Round") == 60, "Reload moves the existing ten rounds once")
	_check(ledger.inspect_entity("rifle-11").functional, "An intact handoff/reloaded weapon remains functional")
	_check(ledger.audit().is_empty(), "Nested weapon holdings reconcile")


func _invalid_ammunition() -> void:
	var f := _fresh()
	var ledger := f.ledger
	var loaded_id := _loaded_id(ledger)
	_rejected(ledger, func() -> Dictionary: return ledger.load_rounds("rifle-11", "rounds-01", 1), "MAGAZINE_FULL")
	_rejected(ledger, func() -> Dictionary: return ledger.load_rounds("rifle-11", "steel-01", 1), "WRONG_AMMUNITION")
	_rejected(ledger, func() -> Dictionary: return ledger.request_stock("loaded", loaded_id, 1, "A", "Invalid reservation", "army-blue"), "STOCK_COMMITTED")
	_rejected(ledger, func() -> Dictionary: return ledger.transfer_stock(loaded_id, 1, "person-03"), "LOADED_ROUNDS")
	_rejected(ledger, func() -> Dictionary: return ledger.record_consumption(loaded_id, 1, "Not a firing system"), "STOCK_COMMITTED")
	_success(ledger.unload_rounds("rifle-11"))
	_success(ledger.request_stock("loose", "rounds-01", 50, "A", "Loose stock request", "army-blue"))
	_rejected(ledger, func() -> Dictionary: return ledger.load_rounds("rifle-11", "rounds-01", 1), "INSUFFICIENT_AVAILABLE")
	_success(f.handoff_weapon())
	_rejected(ledger, func() -> Dictionary: return ledger.load_rounds("rifle-11", "rounds-01", 1), "AMMUNITION_NOT_CARRIED")


func _removals() -> void:
	var f := _fresh()
	var ledger := f.ledger
	_success(ledger.request_stock("steel", "steel-01", 5, "Workshop fixture", "Future inputs", "army-blue"))
	_rejected(ledger, func() -> Dictionary: return ledger.record_consumption("steel-01", 1, "Must resolve claim first"), "STOCK_COMMITTED")
	_success(ledger.release_claim("steel"))
	_success(ledger.record_consumption("steel-01", 3, "Fixture complete input commitment"))
	_success(ledger.record_loss("steel-01", 2, "Explicit accounting fixture loss"))
	var state := ledger.snapshot()
	_check(ledger.total_stock("M01 Steel") == 0 and state.consumed["M01 Steel"] == 3 and state.lost["M01 Steel"] == 2, "Created five equals actual zero plus consumed three plus lost two")
	_rejected(ledger, func() -> Dictionary: return ledger.record_loss("steel-01", 1, "Duplicate loss"), "STOCK_COMMITTED")
	_rejected(ledger, func() -> Dictionary: return ledger.record_loss("rounds-01", 1, ""), "INVALID_REMOVAL")
	_check(ledger.audit().is_empty(), "Explicit removal boundaries conserve the ledger")


func _physical_location() -> void:
	var f := _fresh()
	var ledger := f.ledger
	_rejected(ledger, func() -> Dictionary: return ledger.transfer_stock("rifles-01", 1, "far-hq"), "NOT_COLOCATED")
	_rejected(ledger, func() -> Dictionary: return ledger.transfer_weapon("rifle-11", "far-hq"), "NOT_COLOCATED")
	_rejected(ledger, func() -> Dictionary: return ledger.transfer_stock("rifles-01", 1, "unknown"), "INVALID_HOLDER")
	_rejected(ledger, func() -> Dictionary: return ledger.transfer_stock("rifles-01", -1, "receiving"), "INVALID_QUANTITY")
	_rejected(ledger, func() -> Dictionary: return ledger.transfer_weapon("rifle-11", "rifle-11"), "INVALID_HOLDER")
	_check(ledger.inspect_entity("rifles-01").position == Vector2.ZERO, "Remote rejection leaves the actual location unchanged")


func _detached_inspection() -> void:
	var f := _fresh()
	var ledger := f.ledger
	_success(f.request_rifles("claim-A"))
	var before := ledger.snapshot()
	var entity := ledger.inspect_entity("rifles-01")
	entity.quantity = 999
	entity.owner = "supplier"
	var claim := ledger.inspect_claim("claim-A")
	claim.reserved = 999
	var snapshot := ledger.snapshot()
	snapshot.entities.clear()
	snapshot.events.clear()
	snapshot.created["E02 Round"] = 999
	_check(ledger.snapshot() == before, "UI inspection copies cannot mutate holdings, events, claims or created counts")


func _mixed_transitions() -> void:
	var f := _fresh()
	var ledger := f.ledger
	var random := RandomNumberGenerator.new()
	random.seed = 470201
	for step in range(250):
		var before := ledger.snapshot()
		var result: Dictionary
		match random.randi_range(0, 10):
			0: result = f.load_ten()
			1: result = ledger.unload_rounds("rifle-11")
			2: result = f.handoff_weapon()
			3: result = f.request_rifles("claim-%d" % random.randi_range(0, 5))
			4: result = ledger.release_claim("claim-%d" % random.randi_range(0, 5))
			5: result = ledger.reserve_remaining("claim-%d" % random.randi_range(0, 5))
			6: result = ledger.transfer_stock("rifles-01", random.randi_range(-1, 11), "supplier-truck", "claim-%d" % random.randi_range(0, 5))
			7: result = ledger.request_assignment("worker-01", random.randi_range(0, 2), "duty-fixture")
			8: result = ledger.begin_carry("worker-01", "steel-01", 5)
			9: result = ledger.finish_carry("worker-01", "rear-store")
			10: result = ledger.cancel_assignment_request("worker-01")
		if not result.ok:
			_check(ledger.snapshot() == before, "Rejected mixed transition %d is atomic" % step)
		_check(ledger.audit().is_empty(), "Mixed transition %d preserves conservation and exclusive holders" % step)


func _loaded_id(ledger: Ledger) -> String:
	for entity in ledger.snapshot().entities:
		if entity.kind == "STOCK" and entity.holder_id == "rifle-11" and entity.quantity > 0:
			return entity.id
	return ""


func _duty_count(ledger: Ledger, assignment: String) -> int:
	var count: int = 0
	for entity in ledger.snapshot().entities:
		if entity.kind == "PERSON" and entity.assignment == assignment:
			count += 1
	return count


func _rejected(ledger: Ledger, operation: Callable, expected_code: String) -> void:
	var before := ledger.snapshot()
	var result: Dictionary = operation.call()
	_check(not result.ok and result.code == expected_code, "Expected actionable rejection " + expected_code + "; got " + str(result))
	_check(ledger.snapshot() == before, "Rejected operation leaves every authoritative record unchanged")


func _success(result: Dictionary) -> void:
	_check(result.ok, "Expected success; got " + str(result))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)
