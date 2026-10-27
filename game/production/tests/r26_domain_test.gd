extends GdUnitTestSuite

const Rear = preload("res://game/staffing/rear_simulation.gd")
const Materials = preload("res://game/production/r26_production.gd")
const Rifle = preload("res://game/production/r01_production.gd")
const Rounds = preload("res://game/production/r02_production.gd")


func _local(metal: int = 30, timber: int = 70, count: int = 4) -> RefCounted:
	var rear := Rear.new("Empty")
	for index in count: rear.add_person("operator-%d" % index, false, "None", "duty-materials")
	rear.set_target("materials", count)
	if metal > 0: rear.ledger.add_stock("metal", "M01", metal, 1, "materials_input", rear.PLAYER)
	if timber > 0: rear.ledger.add_stock("timber", "M04", timber, 1, "materials_input", rear.PLAYER)
	rear.materials_production = Materials.new(rear)
	return rear


func _coverage(rear: RefCounted, available: int, planned: int) -> void:
	var view: Dictionary = rear.materials_production.stock_coverage()
	assert_int(view.available).is_equal(available)
	assert_int(view.planned).is_equal(planned)
	assert_int(view.projected).is_equal(available + planned)
	assert_array(rear.audit()).is_empty()


func _target(rear: RefCounted, value: int) -> void:
	rear.materials_production.set_paused(true)
	rear.materials_production.set_mode("Stock target")
	rear.materials_production.set_stock_target(value)
	rear.materials_production.set_paused(false)


func test_r26_exact_inputs_100work_mass_and_four_eight_ordinary_operators() -> void:
	var completed_work := 0.0
	for count in [4, 8]:
		var rear := _local(30, 70, count)
		var activity: RefCounted = rear.materials_production
		assert_str(activity.mode).is_equal("Continuous")
		assert_int(rear.requests.materials.positions).is_equal(8)
		assert_float(rear.stores.materials_input.capacity).is_equal(2000.0)
		assert_float(rear.stores.materials_output.capacity).is_equal(3000.0)
		for id in activity.operators(): assert_str(rear.ledger.inspect_entity(id).qualification).is_equal("None")
		rear.advance_time(0)
		assert_float(activity.batch.required_work).is_equal(100.0)
		assert_float(activity.snapshot().output_promise.mass).is_equal(100.0)
		assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 30, "M04": 70})
		assert_array(activity.batch.receipt).is_equal([{"id": "metal", "type": "M01", "count": 30}, {"id": "timber", "type": "M04", "count": 70}])
		_coverage(rear, 0, 100)
		rear.advance_time(100.0 / count)
		assert_int(rear.ledger.total_stock("M11")).is_equal(100)
		assert_float(rear.ledger.loose_stock_mass_at("materials_output")).is_equal(100.0)
		assert_float(rear.ledger.inspect_entity(activity.history[0].output_id).unit_mass_kg).is_equal(1.0)
		assert_float(activity.history[0].completed_at).is_equal(100.0 / count)
		completed_work = activity.history[0].work
		assert_dict(activity.batch).is_empty()
		assert_dict(rear._output_promises).is_empty()
		_coverage(rear, 100, 0)
		var before: Dictionary = rear.ledger.snapshot()
		rear.advance_time(0)
		rear.advance_time(0)
		assert_dict(rear.ledger.snapshot()).is_equal(before)
	assert_float(completed_work).is_equal(100.0)


func test_30metal_69timber_and_actual_carried_last_unit_cannot_start_before_drop() -> void:
	var rear := _local(30, 69)
	rear.ledger.add_stock("last-timber", "M04", 1, 1, "depot", rear.PLAYER)
	rear.add_person("hauler", false, "None", "duty-depot")
	rear.request_haul("depot", "materials_input", "M04", 1)
	rear.set_target("hauling", 1)
	assert_dict(rear.materials_production.batch).is_empty()
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_int(rear.materials_production.snapshot().missing_local.M04).is_equal(1)
	rear.advance_time(2)
	assert_str(rear.actors.hauler.phase).is_equal("Carry")
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_int(rear.ledger.available_stock_at("materials_input", "M04")).is_equal(69)
	assert_int(rear.ledger.inspect_entity(rear.actors.hauler.load.carried).quantity).is_equal(1)
	var carry_end: float = rear.actors.hauler.deadline
	rear.advance_time(carry_end - rear.time)
	assert_str(rear.actors.hauler.phase).is_equal("Drop")
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	rear.advance_time(2)
	assert_float(rear.materials_production.batch.started_at).is_equal(rear.time)
	assert_float(rear.materials_production.batch.work).is_zero()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 30, "M04": 70})
	assert_int(rear.ledger.total_stock("M11")).is_zero()
	assert_array(rear.audit()).is_empty()


func test_foreign_remote_and_reserved_ingredients_fail_without_partial_consumption() -> void:
	var rear := _local(30, 69)
	rear.ledger.add_stock("foreign", "M04", 1, 1, "materials_input", "supplier")
	rear.ledger.add_stock("remote", "M04", 1, 1, "depot", rear.PLAYER)
	rear.ledger.add_stock("personal", "M04", 1, 1, "operator-0", rear.PLAYER)
	rear.advance_time(0)
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_dict(rear._output_promises).is_empty()
	rear.ledger.add_stock("local-last", "M04", 1, 1, "materials_input", rear.PLAYER)
	rear.ledger.request_stock("other-use", "metal", 1, "shipment", "outbound", rear.PLAYER)
	var before: Dictionary = rear.ledger.snapshot()
	rear.advance_time(0)
	assert_dict(rear.ledger.snapshot()).is_equal(before)
	assert_dict(rear.materials_production.batch).is_empty()
	rear.ledger.release_claim("other-use")
	rear.advance_time(0)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 30, "M04": 70})
	for id in ["foreign", "remote", "personal"]: assert_int(rear.ledger.inspect_entity(id).quantity).is_equal(1)
	assert_array(rear.audit()).is_empty()


func test_real_five_trip_delivery_respects_25kg_and_never_earns_work_in_transit() -> void:
	var rear := _local(0, 0)
	rear.ledger.add_stock("depot-metal", "M01", 30, 1, "depot", rear.PLAYER)
	rear.ledger.add_stock("depot-timber", "M04", 70, 1, "depot", rear.PLAYER)
	rear.add_person("hauler", false, "None", "duty-depot")
	rear.request_haul("depot", "materials_input", "M01", 30)
	rear.request_haul("depot", "materials_input", "M04", 70)
	rear.set_target("hauling", 1)
	var saw_carry := false
	for boundary in 50:
		if not rear.materials_production.batch.is_empty(): break
		assert_dict(rear.ledger.snapshot().consumed).is_empty()
		var actor: Dictionary = rear.actors.hauler
		assert_bool(is_finite(actor.deadline)).is_true()
		if not actor.load.is_empty():
			assert_float(actor.load.mass).is_less_equal(25.0)
			assert_bool(actor.load.type in ["M01", "M04"]).is_true()
		if actor.phase == "Carry": saw_carry = true
		rear.advance_time(actor.deadline - rear.time)
	assert_bool(saw_carry).is_true()
	assert_bool(rear.materials_production.batch.is_empty()).is_false()
	assert_float(rear.materials_production.batch.work).is_zero()
	assert_int(rear.jobs[0].selected).is_equal(2)
	assert_int(rear.jobs[1].selected).is_equal(3)
	assert_int(rear.jobs[0].delivered).is_equal(30)
	assert_int(rear.jobs[1].delivered).is_equal(70)
	assert_float(rear.ledger.inspect_entity("hauler").contents_mass_kg).is_zero()
	assert_array(rear.materials_production.operators()).not_contains("hauler")
	rear.advance_time(25)
	_coverage(rear, 100, 0)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 30, "M04": 70})


func test_100kg_promise_and_invalidating_edits_preserve_all_independent_owners() -> void:
	var rear := _local()
	rear.set_store("materials_output", true, 99)
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_str(rear.materials_production.snapshot().status).is_equal("Output Full")
	rear.ledger.add_stock("existing-metal", "M01", 2900, 1, "materials_output", rear.PLAYER)
	rear.set_store("materials_output", true, 3000)
	assert_float(rear.materials_production.snapshot().output_promise.mass).is_equal(100.0)
	rear.reserve_output_space("rifle-owner", "workshop_output", "E01", 4)
	rear.reserve_output_space("round-owner", "munitions_output", "E02", 2)
	var before: Dictionary = rear.stores.duplicate(true)
	assert_bool(rear.set_store("materials_output", false, 2999, ["M01"]).ok).is_false()
	assert_dict(rear.stores).is_equal(before)
	assert_bool(rear.set_store("materials_output", true, -1, ["M01"]).ok).is_false()
	assert_dict(rear.stores).is_equal(before)
	rear.advance_time(25)
	assert_float(rear.ledger.loose_stock_mass_at("materials_output")).is_equal(3000.0)
	assert_int(rear.ledger.inspect_entity("existing-metal").quantity).is_equal(2900)
	assert_int(rear._output_promises.size()).is_equal(2)
	assert_bool(rear._output_promises.has("rifle-owner")).is_true()
	assert_bool(rear._output_promises.has("round-owner")).is_true()
	assert_array(rear.audit()).is_empty()


func test_target_overshoot_200minus80_makes_one100_batch_and_preserves_claim() -> void:
	var rear := _local(60, 140)
	rear.materials_production.set_paused(true)
	rear.ledger.add_stock("existing", "M11", 200, 1, "depot", rear.PLAYER)
	rear.ledger.request_stock("other80", "existing", 80, "shipment", "outbound materials", rear.PLAYER)
	_target(rear, 150)
	_coverage(rear, 120, 100)
	var batch: Dictionary = rear.materials_production.batch.duplicate(true)
	for repeat in 4:
		rear.materials_production.set_stock_target(150)
		rear.advance_time(0)
		assert_dict(rear.materials_production.batch).is_equal(batch)
	rear.advance_time(25)
	_coverage(rear, 220, 0)
	assert_int(rear.ledger.total_stock("M11")).is_equal(300)
	assert_int(rear.materials_production.history.size()).is_equal(1)
	assert_int(rear.ledger.inspect_claim("other80").reserved).is_equal(80)
	assert_str(rear.materials_production.snapshot().status).is_equal("Target satisfied — no new batch")
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 30, "M04": 70})
	rear.advance_time(100)
	assert_int(rear.materials_production.history.size()).is_equal(1)


func test_zero_target_partial_mode_staff_access_and_cancel_keep_consumed_owner_state() -> void:
	var rear := _local(60, 140)
	var activity: RefCounted = rear.materials_production
	_target(rear, 0)
	rear.advance_time(100)
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	activity.set_stock_target(1)
	rear.advance_time(10)
	var active: Dictionary = activity.batch.duplicate(true)
	assert_float(active.work).is_equal(40.0)
	activity.set_stock_target(0)
	activity.set_mode("Continuous")
	activity.set_mode("Stock target")
	activity.set_paused(true)
	rear.advance_time(100)
	assert_dict(activity.batch).is_equal(active)
	activity.set_paused(false)
	rear.set_target("materials", 0)
	rear.advance_time(100)
	assert_dict(activity.batch).is_equal(active)
	assert_str(activity.snapshot().status).is_equal("Missing Labour")
	rear.set_target("materials", 4)
	rear.set_store("materials_output", false)
	rear.advance_time(100)
	assert_dict(activity.batch).is_equal(active)
	_coverage(rear, 0, 0)
	assert_float(activity.snapshot().output_promise.mass).is_equal(100.0)
	rear.set_store("materials_output", true)
	rear.advance_time(15)
	_coverage(rear, 100, 0)
	activity.set_stock_target(101)
	rear.advance_time(1)
	rear.reserve_output_space("independent", "workshop_output", "E01", 4)
	activity.cancel()
	activity.cancel()
	_coverage(rear, 100, 0)
	assert_int(rear._output_promises.size()).is_equal(1)
	assert_bool(rear._output_promises.has("independent")).is_true()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 60, "M04": 140})
	assert_int(activity.history.size()).is_equal(2)


func test_fully_worked_r26_waits_for_legal_completion_without_new_staff_work() -> void:
	var rear := _local()
	rear.advance_time(0)
	rear.materials_production.advance_work(25) # Explicit component boundary, not clock evidence.
	rear.set_store("materials_output", false)
	assert_float(rear.materials_production.batch.work).is_equal(100.0)
	rear.advance_time(100)
	assert_int(rear.ledger.total_stock("M11")).is_zero()
	rear.set_target("materials", 0)
	rear.set_store("materials_output", true)
	_coverage(rear, 100, 0)
	assert_dict(rear._output_promises).is_empty()


func _haul_rear() -> RefCounted:
	var rear := _local(0, 0)
	_target(rear, 0)
	rear.ledger.add_stock("materials", "M11", 50, 1, "depot", rear.PLAYER)
	rear.add_person("hauler", false, "None", "duty-depot")
	rear.request_haul("depot", "receiving", "M11", 25)
	return rear


func test_actual_m11_claim_carry_deposit_reroute_and_cancel_count_once() -> void:
	var rear := _haul_rear()
	_coverage(rear, 50, 0)
	rear.set_target("hauling", 1)
	_coverage(rear, 25, 25)
	rear.advance_time(2)
	assert_str(rear.actors.hauler.phase).is_equal("Carry")
	_coverage(rear, 25, 25)
	rear.set_store("receiving", false)
	assert_str(rear.actors.hauler.load.destination).is_not_equal("receiving")
	_coverage(rear, 25, 25)
	rear.cancel_job(rear.jobs[0].id)
	_coverage(rear, 25, 0)
	rear.advance_time(300)
	_coverage(rear, 50, 0)
	assert_int(rear.ledger.total_stock("M11")).is_equal(50)
	# Fresh uncancelled haul proves actual requested deposit C -> A once.
	rear = _haul_rear()
	rear.set_target("hauling", 1)
	rear.advance_time(300)
	_coverage(rear, 50, 0)
	assert_int(rear.jobs[0].delivered).is_equal(25)
	assert_int(rear.ledger.available_stock_at("receiving", "M11")).is_equal(25)


func test_ineligible_m11_holders_claims_and_pile_recovery_supply_no_usable_stock() -> void:
	var rear := _haul_rear()
	rear.ledger.request_stock("other10", "materials", 10, "shipment", "outbound", rear.PLAYER)
	rear.ledger.add_stock("foreign", "M11", 100, 1, "depot", "supplier")
	rear.ledger.add_carrier("supplier", "rear", "supplier", "supplier")
	rear.ledger.add_stock("cargo", "M11", 50, 1, "supplier", rear.PLAYER)
	rear.ledger.add_stock("personal", "M11", 1, 1, "operator-0", rear.PLAYER)
	rear.ledger.add_stock("inaccessible", "M11", 10, 1, "support_output", rear.PLAYER)
	rear.ledger.add_stock("filtered", "M11", 10, 1, "munitions_output", rear.PLAYER)
	rear.set_store("support_output", false)
	rear.set_store("munitions_output", true, -1, ["M01"])
	_coverage(rear, 40, 0)
	var view: Dictionary = rear.materials_production.stock_coverage()
	view.stocks.clear()
	_coverage(rear, 40, 0)
	# Real internal carry to a pile cannot retain forecast or become A there.
	rear = _haul_rear()
	rear.set_target("hauling", 1)
	rear.advance_time(2)
	for id in rear.stores.keys(): rear.set_store(id, false)
	assert_bool(rear.stores[rear.actors.hauler.load.destination].pile).is_true()
	_coverage(rear, 0, 0)
	rear.advance_time(300)
	var pile: String = rear.jobs[0].recovery_sources[0]
	assert_int(rear.ledger.available_stock_at(pile, "M11")).is_equal(25)
	rear.set_store("receiving", true)
	_coverage(rear, 0, 0)
	rear.advance_time(300)
	_coverage(rear, 25, 0)
	assert_int(rear.ledger.available_stock_at(pile, "M11")).is_zero()
	rear.set_store("depot", true)
	_coverage(rear, 50, 0)


func _three() -> RefCounted:
	var rear := _local()
	rear.materials_production.set_paused(true)
	for duty in ["workshop", "munitions"]:
		for index in 2: rear.add_person(duty + str(index), false, "None", "duty-" + duty)
		rear.set_target(duty, 2)
	rear.ledger.add_stock("rifle-metal", "M01", 2, 1, "workshop_input", rear.PLAYER)
	rear.ledger.add_stock("components", "M02", 1, 1, "workshop_input", rear.PLAYER)
	rear.ledger.add_stock("round-metal", "M01", 1, 1, "munitions_input", rear.PLAYER)
	rear.ledger.add_stock("powder", "M03", 1, 1, "munitions_input", rear.PLAYER)
	rear.production = Rifle.new(rear)
	rear.munitions_production = Rounds.new(rear)
	rear.materials_production.set_paused(false)
	return rear


func test_three_facilities_have_different_work_and_exclusive_people_promises_and_targets() -> void:
	var rear := _three()
	rear.advance_time(10)
	assert_float(rear.production.batch.work).is_equal(20.0)
	assert_float(rear.munitions_production.batch.work).is_equal(20.0)
	assert_float(rear.materials_production.batch.work).is_equal(40.0)
	assert_int(rear._output_promises.size()).is_equal(3)
	for id in rear.materials_production.operators():
		assert_array(rear.production.operators()).not_contains(id)
		assert_array(rear.munitions_production.operators()).not_contains(id)
	assert_int(rear.production.stock_coverage().planned).is_equal(1)
	assert_int(rear.munitions_production.stock_coverage().planned).is_equal(100)
	_coverage(rear, 0, 100)
	rear.materials_production.set_paused(true)
	rear.advance_time(10)
	assert_int(rear.ledger.total_stock("E01")).is_equal(1)
	assert_int(rear.ledger.total_stock("E02")).is_equal(100)
	assert_int(rear.ledger.total_stock("M11")).is_zero()
	assert_float(rear.materials_production.batch.work).is_equal(40.0)
	assert_int(rear._output_promises.size()).is_equal(1)
	_coverage(rear, 0, 100)
	rear.materials_production.set_paused(false)
	rear.advance_time(15)
	_coverage(rear, 100, 0)
	assert_float(rear.materials_production.history[0].completed_at).is_equal(35.0)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 33, "M02": 1, "M03": 1, "M04": 70})
	assert_int(rear.production.stock_coverage().available).is_equal(1)
	assert_int(rear.munitions_production.stock_coverage().available).is_equal(100)
	assert_dict(rear._output_promises).is_empty()


func test_three_owner_coarse_fractional_time_and_r26_partial_tolerance_match() -> void:
	var coarse := _three()
	var split := _three()
	coarse.advance_time(25)
	for interval in [0.125, 12.375, 7.5, 4.999, 0.001]: split.advance_time(interval)
	for rear in [coarse, split]:
		assert_float(rear.production.history[0].completed_at).is_equal_approx(20, Rear.EPS)
		assert_float(rear.munitions_production.history[0].completed_at).is_equal_approx(20, Rear.EPS)
		assert_float(rear.materials_production.history[0].completed_at).is_equal_approx(25, Rear.EPS)
		assert_int(rear.ledger.total_stock("M11")).is_equal(100)
		assert_dict(rear._output_promises).is_empty()
		assert_array(rear.audit()).is_empty()
	for count in [4, 8]:
		var rear := _local(30, 70, count)
		rear.advance_time(100.0 / count - 10 * Rear.EPS)
		assert_int(rear.ledger.total_stock("M11")).is_zero()
		assert_float(rear.materials_production.batch.work).is_equal_approx(100.0 - count * 10 * Rear.EPS, 0.000000001)
		rear.materials_production.set_paused(true)
		rear.advance_time(100)
		assert_int(rear.ledger.total_stock("M11")).is_zero()
		rear.materials_production.set_paused(false)
		rear.advance_time(10 * Rear.EPS)
		_coverage(rear, 100, 0)
