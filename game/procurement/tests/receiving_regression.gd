extends SceneTree

const Simulation = preload("res://game/procurement/receiving_simulation.gd")
const Catalog = preload("res://game/procurement/resource_catalog.gd")
const Records = preload("res://game/identity/identity_records.gd")

var _checks: int = 0
var _failures: int = 0
var _cases: int = 0


func _initialize() -> void:
	_run("catalogue, exact prices and per-vehicle quotes", _catalogue)
	_run("purchase failures are atomic", _purchase_rejection)
	_run("refund window, cancellation and independent reservation reuse", _cancellation)
	_run("eleven commitments include travel, queue and berth", _freight_admission)
	_run("two personnel commitments include transit and clearance", _personnel_admission)
	_run("incoming population is reserved before debit", _population)
	_run("A04 workerless goods plus self-disembarking manpower", _a04)
	_run("A58 full freight queue admits independent manpower recovery", _a58)
	_run("partial unloading reserves actual destination capacity", _storage)
	_run("assignment interruption preserves in-flight freight", _interruption)
	_run("empty holds do not release occupied freight admission", _freight_clearance)
	_run("pre-pickup reassignment releases only its own claims", _approach_cancellation)
	_run("time partitioning preserves physical outcomes", _time_partition)
	_run("fixed-seed mixed purchases and handling reconcile", _mixed_operations)
	print("G02 regression: %d cases, %d checks, %d failures" % [_cases, _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _catalogue() -> void:
	var prices := {"M01": 2, "M02": 4, "M03": 1, "M04": 1, "M05": 2, "M07": 12, "M08": 2, "M09": 6, "M10": 8}
	_check(Catalog.MATERIALS.size() == 9, "Exactly nine purchased resources")
	for code in prices:
		var quote := Catalog.quote({code: 1}, 11)
		_check(quote.ok and quote.cost == prices[code] + 20, "Exact one-kg price plus one fee: " + code)
	var split := Catalog.quote({"M01": 5001}, 11)
	_check(split.ok and split.vehicle_count == 2 and split.cost == 10042, "5001 kg quotes two separately priced trucks")
	_check(split.vehicles[0].mass_kg == 5000 and split.vehicles[1].mass_kg == 1 and split.transport_fees == 40, "Each quoted truck respects 5000 kg and its own fee")
	var basket := Catalog.quote({"M01": 4999, "M02": 2}, 11)
	_check(basket.vehicles[0].cargo.M02 == 1 and basket.vehicles[1].cargo.M02 == 1, "Mixed baskets retain exact types across truck boundaries")


func _purchase_rejection() -> void:
	var s := Simulation.new()
	_reject(s, func() -> Dictionary: return s.buy_resources({"M06": 1}), "NOT_PURCHASABLE")
	_reject(s, func() -> Dictionary: return s.buy_resources({"M11": 1}), "NOT_PURCHASABLE")
	_reject(s, func() -> Dictionary: return s.buy_resources({"M99": 1}), "NOT_PURCHASABLE")
	_reject(s, func() -> Dictionary: return s.buy_resources({"M01": 0}), "INVALID_QUANTITY")
	_reject(s, func() -> Dictionary: return s.buy_resources({"M01": -1}), "INVALID_QUANTITY")
	_reject(s, func() -> Dictionary: return s.buy_resources({"M01": 1.5}), "INVALID_QUANTITY")
	_reject(s, func() -> Dictionary: return s.buy_resources({"M01": 1000000000000}), "FREIGHT_QUEUE_FULL")
	_reject(s, func() -> Dictionary: return s.buy_resources({"M07": 5000}), "INSUFFICIENT_MONEY")
	_check(s.snapshot().money == 2500 and s.snapshot().orders.is_empty(), "Rejected purchases create no money, stock, orders or people")
	_reject(s, func() -> Dictionary: return s.advance_time(NAN), "INVALID_TIME")


func _cancellation() -> void:
	var s := Simulation.new()
	var resource := s.buy_resources({"M01": 10})
	_success(resource)
	var people := s.buy_people()
	_success(people)
	_success(s.advance_time(4.999))
	_success(s.cancel_order(resource.ids[0]))
	_check(s.freight_admitted() == 0 and s.personnel_admitted() == 1 and s.incoming_people() == 8, "Cancellation releases only the selected freight commitment")
	_success(s.cancel_order(people.ids[0]))
	_check(is_equal_approx(s.snapshot().money, 2500 + 4.999 * 6), "Goods, people and both fees refund exactly once; elapsed income remains")
	_check(s.rear_population() == 0 and s.incoming_people() == 0, "Cancelled incoming people do not become recruits")
	_reject(s, func() -> Dictionary: return s.cancel_order(people.ids[0]), "CANNOT_CANCEL")
	_success(s.buy_people())
	_check(s.incoming_people() == 8 and s.personnel_admitted() == 1, "Released personnel and population places can be reused once")
	var boundary := Simulation.new()
	var order := boundary.buy_resources({"M01": 1})
	_success(boundary.advance_time(5.0))
	_reject(boundary, func() -> Dictionary: return boundary.cancel_order(order.ids[0]), "CANNOT_CANCEL")
	_check(boundary.snapshot().orders[0].state == "Incoming", "Dispatch occurs at the five-second boundary")


func _freight_admission() -> void:
	var s := Simulation.new()
	for index in range(11):
		_success(s.buy_resources({"M03": 1}))
	_check(s.freight_admitted() == 11, "All eleven future arrivals reserve admission immediately")
	_reject(s, func() -> Dictionary: return s.buy_resources({"M01": 5001}), "FREIGHT_QUEUE_FULL")
	_reject(s, func() -> Dictionary: return s.buy_resources({"M03": 1}), "FREIGHT_QUEUE_FULL")
	_success(s.cancel_order("delivery-0005"))
	_success(s.buy_resources({"M03": 1}))
	_reject(s, func() -> Dictionary: return s.cancel_order("delivery-0005"), "CANNOT_CANCEL")
	_check(s.freight_admitted() == 11, "Cancellation/reuse cannot release another truck's place")
	_success(s.advance_time(60.0))
	_check(_states(s, "Waiting") == 10 and _states(s, "Berthing") == 1, "Arrival changes state without increasing admission allowance")
	_reject(s, func() -> Dictionary: return s.buy_resources({"M03": 1}), "FREIGHT_QUEUE_FULL")
	_success(s.advance_time(3.0))
	_check(_states(s, "Berthed") == 1 and _states(s, "Waiting") == 10, "A58 full freight state is one blocked berth plus ten waiting")
	_check(s.resource_counts("M03").onboard == 11 and s.resource_counts("M03").available == 0, "All eleven owned units remain physically onboard without unloaders")
	_check(s.audit().is_empty(), "Freight admissions and stock reconcile")


func _personnel_admission() -> void:
	var s := Simulation.new()
	_success(s.buy_people())
	_success(s.buy_people())
	_reject(s, func() -> Dictionary: return s.buy_people(), "PERSONNEL_QUEUE_FULL")
	_success(s.advance_time(90.0))
	_check(s.rear_population() == 0 and s.incoming_people() == 16 and s.personnel_admitted() == 2, "Arrival is not completed disembarkation or free capacity")
	_reject(s, func() -> Dictionary: return s.ledger.complete_person_arrival("delivery-0001-person-01", "personnel", "army-blue"), "NOT_DISEMBARKED")
	_reject(s, func() -> Dictionary: return s.ledger.complete_person_arrival("delivery-0001-driver", "personnel", "army-blue"), "NOT_ARRIVING_PASSENGER")
	_reject(s, func() -> Dictionary: return s.ledger.add_person("unqualified-driver", "delivery-0001", "supplier", Records.Assignment.STRATEGIC_CREW, false, "P08"), "INVALID_QUALIFICATION")
	_success(s.advance_time(9.5))
	_check(s.rear_population() == 16 and s.incoming_people() == 0, "Actual disembarked people replace their own incoming place reservations")
	_reject(s, func() -> Dictionary: return s.ledger.complete_person_arrival("delivery-0001-person-01", "personnel", "army-blue"), "NOT_ARRIVING_PASSENGER")
	_check(s.personnel_admitted() == 2 and _states(s, "Departing") == 2, "Empty personnel carriers still reserve their pull-off while clearing")
	_reject(s, func() -> Dictionary: return s.buy_people(), "PERSONNEL_QUEUE_FULL")
	_success(s.advance_time(3.0))
	_check(s.personnel_admitted() == 0, "Physical clearance releases each admission once")
	_success(s.buy_people())
	_check(s.incoming_people() == 8, "New personnel delivery can use the cleared place")
	_check(s.audit().is_empty(), "People and service-driver counts reconcile")


func _population() -> void:
	var s := Simulation.new()
	_seed(s, 112)
	_success(s.buy_people())
	_check(s.rear_population() == 112 and s.incoming_people() == 8, "Existing and incoming people occupy all 120 rear places")
	_reject(s, func() -> Dictionary: return s.buy_people(), "REAR_CAPACITY_FULL")
	_success(s.cancel_order("delivery-0001"))
	_success(s.buy_people())
	_success(s.advance_time(110.0))
	_check(s.rear_population() == 120 and s.incoming_people() == 0, "Disembarkation preserves the total capacity commitment")
	_reject(s, func() -> Dictionary: return s.buy_people(), "REAR_CAPACITY_FULL")
	_check(s.audit().is_empty(), "Simultaneous population claims never overbook")


func _a04() -> void:
	var s := Simulation.new()
	_success(s.buy_resources({"M01": 100}))
	_success(s.advance_time(59.999))
	_check(s.resource_counts("M01").incoming == 100 and s.resource_counts("M01").available == 0, "Resources cannot arrive early or grant local stock")
	_success(s.advance_time(10.001))
	_check(s.resource_counts("M01").onboard == 100 and s.receiving_kg() == 0, "With no rear workers, actual supplier cargo stays aboard")
	_reject(s, func() -> Dictionary: return s.assign_unloaders(1), "MISSING_PEOPLE")
	_success(s.buy_people())
	_success(s.advance_time(89.999))
	_check(s.rear_population() == 0, "No recruits before the full 90-second arrival")
	_success(s.advance_time(10.001))
	_check(s.rear_population() == 8 and s.incoming_people() == 0, "Eight real P00 disembark under their own movement without workers")
	_success(s.assign_unloaders(4))
	_check(s.receiving_kg() == 0 and s.reserved_storage_kg() == 100, "Assignments reserve capacity but do not teleport freight")
	_success(s.advance_time(10.0))
	_check(s.resource_counts("M01").available == 0, "Workers still need actual elapsed approach and handling time")
	_success(s.advance_time(70.0))
	_check(s.resource_counts("M01").unloaded == 100 and s.resource_counts("M01").available == 100, "Recovered real labour physically unloads the purchase")
	_check(s.rear_population() == 8, "Supplier drivers are not free recruits")
	for entity in s.ledger.snapshot().entities:
		if entity.kind == "CARRIER" or entity.id.ends_with("-driver"):
			_check(entity.owner == "supplier" and entity.controller == "supplier", "Supplier hull and driver remain external")
	_check(s.audit().is_empty(), "A04 conserves identity, quantities, money and capacity")


func _a58() -> void:
	var s := Simulation.new()
	for index in range(11):
		_success(s.buy_resources({"M03": 1}))
	_success(s.advance_time(63.0))
	_check(s.rear_population() == 0 and s.freight_admitted() == 11, "Start A58 with zero workers and full freight admission")
	_check(_states(s, "Berthed") == 1 and _states(s, "Waiting") == 10, "Freight is physically blocked at the single bay")
	_success(s.buy_people())
	_success(s.advance_time(100.0))
	_check(s.rear_population() == 8 and s.resource_counts("M03").available == 0, "Independent personnel access restores people while freight remains blocked")
	_success(s.assign_unloaders(4))
	_success(s.advance_time(1000.0))
	_check(s.resource_counts("M03").unloaded == 11 and s.freight_admitted() == 0, "Recovered workers unload all eleven trucks and each physically clears")
	_check(s.rear_population() == 8 and s.ledger.total_stock("M03") == 11, "Recovery creates no bonus people, stock or player vehicles")
	_check(s.audit().is_empty(), "A58 closes without a labour bootstrap deadlock")


func _storage() -> void:
	var s := Simulation.new()
	_seed(s, 4)
	_success(s.ledger.add_stock("initial-storage", "M04", 4990, 1.0, "receiving", "army-blue"))
	_success(s.buy_resources({"M01": 50}))
	_success(s.assign_unloaders(4))
	_success(s.advance_time(63.0))
	_check(s.reserved_storage_kg() == 10 and s.receiving_kg() == 4990, "Concurrent unloaders reserve only the ten free kilograms")
	_success(s.advance_time(200.0))
	_check(s.receiving_kg() == 5000 and s.resource_counts("M01").unloaded == 10 and s.resource_counts("M01").onboard == 40, "Partial delivery fills exact storage and preserves forty aboard")
	_check(s.freight_admitted() == 1 and s.reserved_storage_kg() == 0, "Blocked remainder keeps its vehicle admission without leaking destination claims")
	_check(s.audit().is_empty(), "Full storage never overbooks or deletes freight")


func _interruption() -> void:
	var s := Simulation.new()
	_seed(s, 1)
	_success(s.buy_resources({"M01": 25}))
	_success(s.assign_unloaders(1))
	# Arrival 60s + 35m vehicle approach /12 + 80m person approach /1.5
	# + 2s pickup = 118.25s. Observe after pickup, before the loaded carry ends.
	_success(s.advance_time(118.5))
	var worker: Dictionary = s.snapshot().workers["initial-001"]
	_check(worker.job.phase == "Carry", "Fixture reaches a real in-flight carry")
	_success(s.release_unloaders())
	_check(s.ledger.inspect_entity("initial-001").pending_assignment == "Available", "Reassignment is pending while freight is physically carried")
	var waiting := s.snapshot()
	_success(s.release_unloaders())
	_check(s.snapshot() == waiting, "Repeating the same safe-release request does not duplicate work or mutate a pending handoff")
	_success(s.advance_time(20.0))
	_check(s.snapshot().workers.is_empty() and s.ledger.inspect_entity("initial-001").assignment == "Available", "Safe deposit removes the old receiving duty without a ghost worker")
	_check(s.resource_counts("M01").unloaded == 25 and s.audit().is_empty(), "Interruption preserves the completed physical delivery")


func _freight_clearance() -> void:
	var s := Simulation.new()
	_seed(s, 1)
	_success(s.ledger.move_entity("initial-001", "rear-lane", Simulation.FREIGHT_BERTH))
	_success(s.buy_resources({"M03": 1}))
	_success(s.assign_unloaders(1))
	_success(s.advance_time(63.0))
	var job: Dictionary = s.snapshot().workers["initial-001"].job
	_check(job.phase == "Pickup", "Physical arrival begins timed pickup, not instant availability")
	_success(s.advance_time(job.ends_at - s.snapshot().time))
	_check(s.resource_counts("M03").onboard == 0 and s.resource_counts("M03").carried == 1, "The final real unit leaves the truck only at completed pickup")
	_check(s.freight_admitted() == 1 and s.resource_counts("M03").available == 0, "An empty truck still holds its admission while freight is carried")
	job = s.snapshot().workers["initial-001"].job
	_success(s.advance_time(job.ends_at - s.snapshot().time))
	_check(s.resource_counts("M03").available == 0, "Reaching storage is not completion of the two-second drop")
	_success(s.advance_time(2.0))
	_check(_states(s, "Departing") == 1 and s.freight_admitted() == 1, "Deposited cargo does not release the physically occupied berth")
	var order: Dictionary = s.snapshot().orders[0]
	_success(s.advance_time(order.next_at - s.snapshot().time - 0.001))
	_check(s.freight_admitted() == 1, "Admission persists until physical clearance completes")
	_success(s.advance_time(0.002))
	_check(s.freight_admitted() == 0 and s.ledger.inspect_entity(order.id).position.x <= -12.0, "Clearance, not ownership or emptying, releases the place")
	_success(s.advance_time(100.0))
	_reject(s, func() -> Dictionary: return s.cancel_order(order.id), "CANNOT_CANCEL")
	_check(s.freight_admitted() == 0 and s.audit().is_empty(), "Completion cannot release admission a second time")


func _approach_cancellation() -> void:
	var s := Simulation.new()
	_seed(s, 1)
	_success(s.buy_resources({"M01": 25}))
	_success(s.assign_unloaders(1))
	_success(s.advance_time(70.0))
	_check(s.reserved_storage_kg() == 25 and s.resource_counts("M01").onboard == 25, "Approaching a pickup reserves output but leaves all stock aboard")
	_success(s.release_unloaders())
	_check(s.reserved_storage_kg() == 0 and s.snapshot().workers.is_empty(), "Cancelling pre-pickup work releases its output and source claims")
	_check(s.ledger.available("delivery-0001-M01") == 25 and s.audit().is_empty(), "Pre-pickup release loses no goods or physical identities")


func _time_partition() -> void:
	var whole := Simulation.new()
	var parts := Simulation.new()
	for s in [whole, parts]:
		_seed(s, 4)
		_success(s.buy_resources({"M01": 100}))
		_success(s.buy_people())
		_success(s.assign_unloaders(4))
	_success(whole.advance_time(200.0))
	for index in range(200):
		_success(parts.advance_time(1.0))
	_check(whole.resource_counts("M01") == parts.resource_counts("M01"), "Time partition does not change delivered quantities")
	_check(whole.rear_population() == parts.rear_population() and whole.freight_admitted() == parts.freight_admitted(), "One large step and small steps conserve the same people and admission state")
	_check(is_equal_approx(whole.snapshot().money, parts.snapshot().money), "Baseline income is proportional to actual elapsed simulation time")
	_check(whole.audit().is_empty() and parts.audit().is_empty(), "Both clock partitions reconcile")


func _mixed_operations() -> void:
	var s := Simulation.new()
	var random := RandomNumberGenerator.new()
	random.seed = 20261026
	for step in range(100):
		var before := s.snapshot()
		var result: Dictionary
		match random.randi_range(0, 6):
			0: result = s.buy_resources({"M01": random.randi_range(1, 40)})
			1: result = s.buy_people()
			2: result = s.cancel_order("delivery-%04d" % random.randi_range(1, 30))
			3: result = s.advance_time(random.randi_range(0, 100))
			4: result = s.assign_unloaders(1)
			5: result = s.release_unloaders()
			6: result = s.buy_resources({"M06": 1})
		if not result.ok:
			_check(s.snapshot() == before, "Rejected mixed operation %d is atomic" % step)
		_check(s.audit().is_empty(), "Mixed operation %d preserves all G01/G02 invariants" % step)


func _seed(s: Simulation, count: int) -> void:
	for index in range(count):
		_success(s.ledger.add_person("initial-%03d" % (index + 1), "personnel", "army-blue"))


func _states(s: Simulation, state: String) -> int:
	var count: int = 0
	for order in s.snapshot().orders:
		if order.state == state:
			count += 1
	return count


func _run(title: String, test: Callable) -> void:
	var before := _failures
	test.call()
	_cases += 1
	print("%s: %s" % ["PASS" if before == _failures else "FAIL", title])


func _reject(s: Simulation, operation: Callable, code: String) -> void:
	var before := s.snapshot()
	var result: Dictionary = operation.call()
	_check(not result.ok and result.code == code, "Expected atomic rejection " + code + "; got " + str(result))
	_check(before == s.snapshot(), "Rejected operation changes no money, order, identity, location or reservation")


func _success(result: Dictionary) -> void:
	_check(result.ok, "Expected success; got " + str(result))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)
