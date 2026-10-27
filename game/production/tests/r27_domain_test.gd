extends GdUnitTestSuite

const Rear = preload("res://game/staffing/rear_simulation.gd")
const F05 = preload("res://game/production/r02_production.gd")
const Rifle = preload("res://game/production/r01_production.gd")
const Materials = preload("res://game/production/r26_production.gd")


func _local(metal: int = 2, powder: int = 10, count: int = 2) -> RefCounted:
	var rear := Rear.new("Empty")
	for index in count: rear.add_person("operator-%d" % index, false, "None", "duty-munitions")
	rear.set_target("munitions", count)
	rear.munitions_production = F05.new(rear)
	rear.munitions_production.request_recipe("R27")
	if metal > 0: rear.ledger.add_stock("metal", "M01", metal, 1, "munitions_input", rear.PLAYER)
	if powder > 0: rear.ledger.add_stock("powder", "M03", powder, 1, "munitions_input", rear.PLAYER)
	return rear


func _coverage(rear: RefCounted, available: int, planned: int) -> void:
	var coverage: Dictionary = rear.munitions_production.stock_coverage()
	assert_int(coverage.available).is_equal(available)
	assert_int(coverage.planned).is_equal(planned)
	assert_int(coverage.projected).is_equal(available + planned)
	assert_array(rear.audit()).is_empty()


func _target(rear: RefCounted, value: int) -> void:
	rear.munitions_production.set_paused(true)
	rear.munitions_production.set_mode("Stock target")
	rear.munitions_production.set_stock_target(value)
	rear.munitions_production.set_paused(false)


func test_exact_r27_local_inputs_40work_one_physical_m06_and_two_four_operators() -> void:
	var completed_yield := 0
	for count in [2, 4]:
		var rear := _local(2, 10, count)
		var activity: RefCounted = rear.munitions_production
		assert_str(activity.mode).is_equal("Continuous")
		assert_int(rear.requests.munitions.positions).is_equal(4)
		assert_float(rear.stores.munitions_input.capacity).is_equal(1000.0)
		assert_float(rear.stores.munitions_output.capacity).is_equal(1000.0)
		for id in activity.operators(): assert_str(rear.ledger.inspect_entity(id).qualification).is_equal("None")
		rear.advance_time(0)
		assert_array(activity.batch.receipt).is_equal([{"id": "powder", "type": "M03", "count": 10}, {"id": "metal", "type": "M01", "count": 2}])
		assert_dict(rear.ledger.snapshot().consumed).is_equal({"M03": 10, "M01": 2})
		assert_float(activity.batch.required_work).is_equal(40.0)
		assert_float(activity.snapshot().output_promise.mass).is_equal(1.0)
		_coverage(rear, 0, 1)
		assert_int(rear.ledger.total_stock("M06")).is_zero()
		rear.advance_time(40.0 / count)
		completed_yield = rear.ledger.total_stock("M06")
		assert_float(rear.ledger.loose_stock_mass_at("munitions_output")).is_equal(1.0)
		assert_float(rear.ledger.inspect_entity(activity.history[0].output_id).unit_mass_kg).is_equal(1.0)
		assert_float(activity.history[0].work).is_equal(40.0)
		assert_float(activity.history[0].completed_at).is_equal(40.0 / count)
		assert_int(rear.ledger.total_stock("E02")).is_zero()
		assert_dict(rear._output_promises).is_empty()
		var before: Dictionary = rear.ledger.snapshot()
		rear.advance_time(100)
		assert_dict(rear.ledger.snapshot().consumed).is_equal(before.consumed)
		assert_int(rear.ledger.total_stock("M06")).is_equal(completed_yield)
		assert_int(activity.history.size()).is_equal(1)
		_coverage(rear, 1, 0)
	assert_int(completed_yield).is_equal(1)


func test_either_missing_foreign_remote_person_carrier_or_reserved_input_refuses_whole_batch() -> void:
	for missing in ["M01", "M03"]:
		var rear := _local(1 if missing == "M01" else 2, 9 if missing == "M03" else 10)
		rear.ledger.add_stock("foreign", missing, 1, 1, "munitions_input", "supplier")
		rear.ledger.add_stock("remote", missing, 1, 1, "depot", rear.PLAYER)
		rear.ledger.add_stock("personal", missing, 1, 1, "operator-0", rear.PLAYER)
		rear.ledger.add_carrier("carrier", "rear", "supplier", "supplier")
		rear.ledger.add_stock("cargo", missing, 1, 1, "carrier", rear.PLAYER)
		rear.advance_time(100)
		assert_dict(rear.ledger.snapshot().consumed).is_empty()
		assert_dict(rear._output_promises).is_empty()
		assert_str(rear.munitions_production.snapshot().status).is_equal("Missing Inputs")
		rear.ledger.add_stock("last-local", missing, 1, 1, "munitions_input", rear.PLAYER)
		rear.ledger.request_stock("other-use", "last-local", 1, "shipment", "outbound", rear.PLAYER)
		rear.advance_time(0)
		assert_dict(rear.ledger.snapshot().consumed).is_empty()
		rear.ledger.release_claim("other-use")
		rear.advance_time(0)
		assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M03": 10})
		for id in ["foreign", "remote", "personal", "cargo"]: assert_int(rear.ledger.inspect_entity(id).quantity).is_equal(1)
		assert_array(rear.audit()).is_empty()


func test_real_hauling_last_carried_powder_is_not_local_until_actual_deposit() -> void:
	var rear := _local(0, 0)
	rear.ledger.add_stock("depot-metal", "M01", 2, 1, "depot", rear.PLAYER)
	rear.ledger.add_stock("depot-powder", "M03", 10, 1, "depot", rear.PLAYER)
	rear.add_person("hauler", false, "None", "duty-depot")
	rear.request_haul("depot", "munitions_input", "M01", 2)
	rear.request_haul("depot", "munitions_input", "M03", 10)
	rear.set_target("hauling", 1)
	var saw_last_carry := false
	for boundary in 40:
		var actor: Dictionary = rear.actors.hauler
		if actor.phase in ["Carry", "Drop"]:
			assert_float(actor.load.mass).is_less_equal(25.0)
			assert_dict(rear.ledger.snapshot().consumed).is_empty()
			if actor.load.type == "M03":
				saw_last_carry = true
				assert_int(rear.ledger.available_stock_at("munitions_input", "M03")).is_zero()
		if not rear.munitions_production.batch.is_empty(): break
		rear.advance_time(actor.deadline - rear.time)
	assert_bool(saw_last_carry).is_true()
	assert_int(rear.jobs[0].delivered).is_equal(2)
	assert_int(rear.jobs[1].delivered).is_equal(10)
	assert_float(rear.munitions_production.batch.work).is_zero()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M03": 10})
	assert_array(rear.audit()).is_empty()


func test_whole_one_kg_promise_capacity_filter_and_other_claims_remain_atomic() -> void:
	var rear := _local()
	rear.ledger.add_stock("finished-rounds", "E02", 49950, 0.02, "munitions_output", rear.PLAYER) # 999 kg
	rear.reserve_output_space("other-f05", "munitions_output", "E02", 0.5)
	rear.advance_time(0)
	assert_dict(rear.munitions_production.batch).is_empty()
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	rear.release_output_space("other-f05")
	rear.advance_time(0)
	assert_float(rear.munitions_production.snapshot().output_promise.mass).is_equal(1.0)
	rear.reserve_output_space("independent", "materials_output", "M11", 100)
	var before: Dictionary = rear.stores.duplicate(true)
	assert_bool(rear.set_store("munitions_output", false, 999, ["M01"]).ok).is_false()
	assert_bool(rear.set_store("munitions_output", true, -1, ["E02"]).ok).is_false()
	assert_dict(rear.stores).is_equal(before)
	rear.advance_time(20)
	assert_float(rear.ledger.loose_stock_mass_at("munitions_output")).is_equal(1000.0)
	assert_int(rear.ledger.inspect_entity("finished-rounds").quantity).is_equal(49950)
	assert_int(rear._output_promises.size()).is_equal(1)
	assert_bool(rear._output_promises.has("independent")).is_true()
	assert_array(rear.audit()).is_empty()


func test_r27_target_mode_pause_absent_staff_access_and_cancel_retain_owned_work() -> void:
	var rear := _local(4, 20)
	var activity: RefCounted = rear.munitions_production
	_target(rear, 1)
	rear.advance_time(5)
	var partial: Dictionary = activity.batch.duplicate(true)
	assert_float(partial.work).is_equal(10.0)
	assert_bool(activity.set_stock_target(-1).ok).is_false()
	activity.set_stock_target(0)
	activity.set_mode("Continuous")
	activity.set_mode("Stock target")
	activity.set_paused(true)
	rear.advance_time(20)
	assert_dict(activity.batch).is_equal(partial)
	activity.set_paused(false)
	rear.set_target("munitions", 0)
	rear.advance_time(20)
	assert_dict(activity.batch).is_equal(partial)
	rear.set_target("munitions", 2)
	rear.set_store("munitions_output", false)
	rear.advance_time(20)
	assert_dict(activity.batch).is_equal(partial)
	assert_float(activity.snapshot().output_promise.mass).is_equal(1.0)
	_coverage(rear, 0, 0)
	rear.set_store("munitions_output", true)
	rear.advance_time(15)
	_coverage(rear, 1, 0)
	activity.set_stock_target(2)
	rear.advance_time(1)
	var consumed: Dictionary = rear.ledger.snapshot().consumed
	rear.reserve_output_space("independent", "workshop_output", "E01", 4)
	activity.cancel()
	activity.cancel()
	assert_dict(rear.ledger.snapshot().consumed).is_equal(consumed)
	assert_int(activity.history.size()).is_equal(2)
	assert_str(activity.history[1].state).is_equal("Cancelled")
	assert_int(rear.ledger.total_stock("M06")).is_equal(1)
	assert_int(rear._output_promises.size()).is_equal(1)
	assert_bool(rear._output_promises.has("independent")).is_true()


func test_fully_worked_blocked_r27_finishes_once_without_another_work_charge() -> void:
	var rear := _local()
	var activity: RefCounted = rear.munitions_production
	rear.advance_time(0)
	activity.advance_work(20) # Component boundary, distinct from shared-clock evidence.
	rear.set_store("munitions_output", false)
	rear.set_target("munitions", 0)
	rear.advance_time(100)
	assert_float(activity.batch.work).is_equal(40.0)
	assert_int(rear.ledger.total_stock("M06")).is_zero()
	rear.set_store("munitions_output", true)
	_coverage(rear, 1, 0)
	rear.advance_time(0)
	assert_int(activity.history.size()).is_equal(1)
	assert_dict(rear._output_promises).is_empty()


func test_decline_or_dismiss_recipe_change_preserves_exact_batch_receipt_and_promise() -> void:
	var rear := _local()
	var activity: RefCounted = rear.munitions_production
	rear.advance_time(5)
	var before: Dictionary = activity.snapshot()
	var ledger: Dictionary = rear.ledger.snapshot()
	var promises: Dictionary = rear._output_promises.duplicate(true)
	var request: Dictionary = activity.request_recipe("R02")
	assert_bool(request.confirmation_required).is_true()
	assert_str(request.message).contains(before.batch.id)
	assert_str(request.message).contains("permanently lost")
	assert_str(request.message).contains("finished goods remain")
	assert_dict(activity.batch).is_equal(before.batch)
	assert_bool(activity.decline_recipe(request.token).ok).is_true()
	assert_dict(activity.snapshot()).is_equal(before)
	assert_dict(rear.ledger.snapshot()).is_equal(ledger)
	assert_dict(rear._output_promises).is_equal(promises)
	assert_bool(activity.confirm_recipe(request.token).ok).is_false()
	assert_bool(activity.request_recipe("R32").ok).is_false()
	assert_dict(activity.snapshot()).is_equal(before)


func test_confirm_partial_change_loses_consumed_inputs_resets_new_work_and_repeats_once() -> void:
	var rear := _local(4, 12)
	var activity: RefCounted = rear.munitions_production
	rear.ledger.add_stock("finished", "M06", 3, 1, "munitions_output", rear.PLAYER)
	rear.reserve_output_space("independent", "materials_output", "M11", 100)
	rear.advance_time(5)
	var old_id: String = activity.batch.id
	var request: Dictionary = activity.request_recipe("R02")
	assert_bool(activity.confirm_recipe(request.token).ok).is_true()
	assert_str(activity.snapshot().recipe).is_equal("R02")
	assert_str(activity.batch.recipe).is_equal("R02")
	assert_float(activity.batch.work).is_zero()
	assert_float(activity.snapshot().output_promise.mass).is_equal(2.0)
	assert_bool(rear._output_promises.has(old_id)).is_false()
	assert_bool(rear._output_promises.has("independent")).is_true()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M03": 11, "M01": 3})
	assert_int(rear.ledger.total_stock("M06")).is_equal(3)
	var previous: Dictionary = activity.snapshot()
	var ledger: Dictionary = rear.ledger.snapshot()
	assert_bool(activity.confirm_recipe(request.token).ok).is_false()
	assert_dict(activity.snapshot()).is_equal(previous)
	assert_dict(rear.ledger.snapshot()).is_equal(ledger)
	var record: Dictionary = activity.snapshot().recipe_records.R27
	assert_int(record.history.size()).is_equal(1)
	assert_str(record.history[0].state).is_equal("Cancelled")
	assert_float(record.history[0].work).is_equal(10.0)
	assert_array(record.history[0].receipt).has_size(2)
	assert_int(record.stock_target).is_zero()
	assert_array(rear.audit()).is_empty()


func test_confirm_earned_blocked_change_cancels_only_identified_batch_without_output() -> void:
	var rear := _local(3, 11)
	var activity: RefCounted = rear.munitions_production
	rear.advance_time(0)
	activity.advance_work(20) # Explicit earned-but-not-deposited component boundary.
	rear.set_store("munitions_output", false)
	var old: Dictionary = activity.batch.duplicate(true)
	rear.reserve_output_space("other", "workshop_output", "E01", 4)
	var request: Dictionary = activity.request_recipe("R02")
	assert_bool(request.confirmation_required).is_true()
	activity.confirm_recipe(request.token)
	assert_int(rear.ledger.total_stock("M06")).is_zero()
	assert_dict(activity.batch).is_empty()
	assert_bool(rear._output_promises.has(old.id)).is_false()
	assert_bool(rear._output_promises.has("other")).is_true()
	assert_float(activity.snapshot().recipe_records.R27.history[0].work).is_equal(40.0)
	rear.set_store("munitions_output", true)
	assert_str(activity.batch.recipe).is_equal("R02")
	assert_float(activity.batch.work).is_zero()
	rear.advance_time(20)
	assert_int(rear.ledger.total_stock("M06")).is_zero()
	assert_int(rear.ledger.total_stock("E02")).is_equal(100)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M03": 11, "M01": 3})


func test_unstarted_change_is_free_and_switch_back_retains_modes_targets_history_and_stock() -> void:
	var rear := _local(0, 0)
	var activity: RefCounted = rear.munitions_production
	_target(rear, 2)
	var before: Dictionary = rear.ledger.snapshot()
	assert_bool(activity.request_recipe("R02").get("confirmation_required", false)).is_false()
	assert_str(activity.mode).is_equal("Continuous")
	assert_dict(rear.ledger.snapshot()).is_equal(before)
	_target(rear, 100)
	assert_bool(activity.request_recipe("R27").ok).is_true()
	assert_str(activity.mode).is_equal("Stock target")
	assert_int(activity.stock_target).is_equal(2)
	rear.ledger.add_stock("both-metal", "M01", 3, 1, "munitions_input", rear.PLAYER)
	rear.ledger.add_stock("both-powder", "M03", 11, 1, "munitions_input", rear.PLAYER)
	rear.advance_time(20)
	assert_int(activity.history.size()).is_equal(1)
	activity.request_recipe("R02")
	assert_int(activity.stock_target).is_equal(100)
	assert_int(activity.stock_coverage().planned).is_equal(100)
	rear.advance_time(20)
	assert_int(rear.ledger.total_stock("E02")).is_equal(100)
	assert_int(rear.ledger.total_stock("M06")).is_equal(1)
	assert_float(rear.ledger.loose_stock_mass_at("munitions_output")).is_equal(3.0)
	activity.request_recipe("R27")
	assert_int(activity.stock_target).is_equal(2)
	assert_int(activity.history.size()).is_equal(1)
	assert_str(activity.history[0].recipe).is_equal("R27")
	assert_dict(activity.batch).is_empty()
	assert_int(activity.stock_coverage().available).is_equal(1)
	activity.request_recipe("R02")
	assert_int(activity.history.size()).is_equal(1)
	assert_str(activity.history[0].recipe).is_equal("R02")
	assert_str(activity.snapshot().status).is_equal("Target satisfied — no new batch")
	activity.request_recipe("R27")
	rear.ledger.add_stock("next-metal", "M01", 2, 1, "munitions_input", rear.PLAYER)
	rear.ledger.add_stock("next-powder", "M03", 10, 1, "munitions_input", rear.PLAYER)
	rear.advance_time(0)
	assert_str(activity.batch.id).is_equal("r27-batch-0002")
	assert_str(activity.batch.output_id).is_not_equal(activity.history[0].output_id)
	assert_int(activity.history.size()).is_equal(1)
	assert_int(activity.snapshot().recipe_records.R02.history.size()).is_equal(1)
	assert_int(rear.ledger.total_stock("M06")).is_equal(1)
	assert_array(rear.audit()).is_empty()


func test_stale_confirmation_cannot_cancel_new_batch_and_fresh_confirmation_is_required() -> void:
	var rear := _local(4, 20)
	var activity: RefCounted = rear.munitions_production
	rear.advance_time(5)
	var request: Dictionary = activity.request_recipe("R02")
	var first_id: String = activity.batch.id
	rear.advance_time(15)
	assert_str(activity.batch.id).is_not_equal(first_id)
	var current: Dictionary = activity.batch.duplicate(true)
	var ledger: Dictionary = rear.ledger.snapshot()
	var promises: Dictionary = rear._output_promises.duplicate(true)
	var stale: Dictionary = activity.confirm_recipe(request.token)
	assert_bool(stale.ok).is_false()
	assert_str(stale.message).contains("fresh confirmation")
	assert_dict(activity.batch).is_equal(current)
	assert_dict(rear.ledger.snapshot()).is_equal(ledger)
	assert_dict(rear._output_promises).is_equal(promises)
	request = activity.request_recipe("R02")
	assert_bool(activity.confirm_recipe(request.token).ok).is_true()
	assert_str(activity.snapshot().recipe).is_equal("R02")
	assert_int(activity.snapshot().recipe_records.R27.history.size()).is_equal(2)
	assert_str(activity.snapshot().recipe_records.R27.history[1].id).is_equal(current.id)
	assert_int(rear.ledger.total_stock("M06")).is_equal(1)
	assert_dict(activity.batch).is_empty()


func test_completed_or_superseded_pending_confirmation_never_applies_to_other_state() -> void:
	var rear := _local()
	var activity: RefCounted = rear.munitions_production
	rear.advance_time(0)
	var first: Dictionary = activity.request_recipe("R02")
	var second: Dictionary = activity.request_recipe("R02")
	assert_bool(activity.confirm_recipe(first.token).ok).is_false()
	assert_dict(activity.snapshot().pending_recipe_change).is_equal({"token": second.token, "from": "R27", "to": "R02", "batch_id": activity.batch.id})
	rear.advance_time(20)
	assert_bool(activity.confirm_recipe(second.token).ok).is_false()
	assert_str(activity.snapshot().recipe).is_equal("R27")
	assert_int(activity.history.size()).is_equal(1)
	assert_int(rear.ledger.total_stock("M06")).is_equal(1)
	assert_bool(activity.request_recipe("R02").get("confirmation_required", false)).is_false()
	assert_int(rear.ledger.total_stock("M06")).is_equal(1)


func test_m06_target_eligibility_and_other_use_claim_yield_one_whole_unit() -> void:
	var rear := _local(4, 20)
	var activity: RefCounted = rear.munitions_production
	activity.paused = true # Declared domain initialization before settling.
	rear.ledger.add_stock("own", "M06", 2, 1, "depot", rear.PLAYER)
	rear.ledger.request_stock("other", "own", 1, "shipment", "outbound", rear.PLAYER)
	for entry in [["foreign", "depot", "supplier"], ["personal", "operator-0", rear.PLAYER], ["blocked", "receiving", rear.PLAYER], ["filtered", "support_output", rear.PLAYER]]:
		rear.ledger.add_stock(entry[0], "M06", 10, 1, entry[1], entry[2])
	rear.ledger.add_carrier("supplier", "rear", "supplier", "supplier")
	rear.ledger.add_stock("cargo", "M06", 10, 1, "supplier", rear.PLAYER)
	rear.set_store("receiving", false)
	rear.set_store("support_output", true, -1, ["M01"])
	_coverage(rear, 1, 0)
	_target(rear, 2)
	_coverage(rear, 1, 1)
	assert_int(rear.ledger.total_stock("M06")).is_equal(52)
	rear.advance_time(20)
	_coverage(rear, 2, 0)
	assert_int(activity.history.size()).is_equal(1)
	assert_int(rear.ledger.inspect_claim("other").reserved).is_equal(1)
	assert_dict(activity.batch).is_empty()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M03": 10})


func _haul_rear() -> RefCounted:
	var rear := _local(0, 0)
	_target(rear, 0)
	rear.ledger.add_stock("explosives", "M06", 4, 1, "depot", rear.PLAYER)
	rear.add_person("hauler", false, "None", "duty-depot")
	rear.request_haul("depot", "receiving", "M06", 2)
	return rear


func test_actual_m06_relocation_claim_carry_deposit_reroute_and_cancel_count_once() -> void:
	var rear := _haul_rear()
	_coverage(rear, 4, 0)
	rear.set_target("hauling", 1)
	_coverage(rear, 2, 2)
	rear.advance_time(2)
	assert_int(rear.munitions_production.stock_coverage().internal_carried).is_equal(2)
	_coverage(rear, 2, 2)
	rear.set_store("receiving", false)
	assert_str(rear.actors.hauler.load.destination).is_not_equal("receiving")
	_coverage(rear, 2, 2)
	rear.cancel_job(rear.jobs[0].id)
	_coverage(rear, 2, 0)
	rear.advance_time(300)
	_coverage(rear, 4, 0)
	rear = _haul_rear()
	rear.set_target("hauling", 1)
	rear.advance_time(300)
	_coverage(rear, 4, 0)
	assert_int(rear.jobs[0].delivered).is_equal(2)
	assert_int(rear.ledger.available_stock_at("receiving", "M06")).is_equal(2)


func test_m06_pile_recovery_is_neither_usable_stock_nor_valid_inbound_until_deposit() -> void:
	var rear := _haul_rear()
	rear.set_target("hauling", 1)
	rear.advance_time(2)
	for id in rear.stores.keys(): rear.set_store(id, false)
	assert_bool(rear.stores[rear.actors.hauler.load.destination].pile).is_true()
	_coverage(rear, 0, 0)
	rear.advance_time(300)
	var pile: String = rear.jobs[0].recovery_sources[0]
	assert_int(rear.ledger.available_stock_at(pile, "M06")).is_equal(2)
	rear.set_store("receiving", true)
	_coverage(rear, 0, 0)
	rear.advance_time(300)
	_coverage(rear, 2, 0)
	assert_int(rear.ledger.available_stock_at(pile, "M06")).is_zero()
	rear.set_store("depot", true)
	_coverage(rear, 4, 0)


func test_inactive_recipe_never_works_or_contributes_other_output_forecast() -> void:
	var rear := _local(3, 11)
	var activity: RefCounted = rear.munitions_production
	_target(rear, 1)
	rear.advance_time(5)
	assert_int(activity.stock_coverage().planned).is_equal(1)
	var request: Dictionary = activity.request_recipe("R02")
	activity.confirm_recipe(request.token)
	assert_str(activity.mode).is_equal("Continuous")
	assert_int(activity.stock_coverage().planned).is_equal(100)
	assert_float(activity.batch.work).is_zero()
	rear.advance_time(20)
	assert_int(rear.ledger.total_stock("E02")).is_equal(100)
	assert_int(rear.ledger.total_stock("M06")).is_zero()
	assert_float(activity.snapshot().recipe_records.R27.history[0].work).is_equal(10.0)
	activity.request_recipe("R27")
	assert_int(activity.stock_target).is_equal(1)
	_coverage(rear, 0, 0) # The 100 E02 cannot satisfy M06 minimum 1.
	assert_str(activity.snapshot().status).is_equal("Missing Inputs")
	assert_int(rear._production_activities().size()).is_equal(1)
	assert_array(rear.audit()).is_empty()


func _three() -> RefCounted:
	var rear := _local(3, 11)
	rear.munitions_production.paused = true
	for entry in [["workshop", 2], ["materials", 4]]:
		for index in entry[1]: rear.add_person(entry[0] + str(index), false, "None", "duty-" + entry[0])
		rear.set_target(entry[0], entry[1])
	rear.ledger.add_stock("rifle-metal", "M01", 2, 1, "workshop_input", rear.PLAYER)
	rear.ledger.add_stock("components", "M02", 1, 1, "workshop_input", rear.PLAYER)
	rear.ledger.add_stock("materials-metal", "M01", 30, 1, "materials_input", rear.PLAYER)
	rear.ledger.add_stock("timber", "M04", 70, 1, "materials_input", rear.PLAYER)
	rear.production = Rifle.new(rear)
	rear.materials_production = Materials.new(rear)
	rear.munitions_production.set_paused(false)
	return rear


func test_exclusive_f05_switch_and_independent_r01_r26_share_fractional_time_without_double_work() -> void:
	var coarse := _three()
	var split := _three()
	for rear in [coarse, split]:
		rear.advance_time(5)
		assert_float(rear.munitions_production.batch.work).is_equal(10.0)
		assert_float(rear.production.batch.work).is_equal(10.0)
		assert_float(rear.materials_production.batch.work).is_equal(20.0)
		for id in rear.munitions_production.operators():
			assert_array(rear.production.operators()).not_contains(id)
			assert_array(rear.materials_production.operators()).not_contains(id)
		var request: Dictionary = rear.munitions_production.request_recipe("R02")
		rear.munitions_production.confirm_recipe(request.token)
		assert_int(rear._production_activities().size()).is_equal(3)
		assert_float(rear.munitions_production.batch.work).is_zero()
		assert_int(rear._output_promises.size()).is_equal(3)
	coarse.advance_time(20)
	for delta in [0.125, 7.875, 7.0, 4.999, 0.001]: split.advance_time(delta)
	for rear in [coarse, split]:
		assert_int(rear.ledger.total_stock("E01")).is_equal(1)
		assert_int(rear.ledger.total_stock("E02")).is_equal(100)
		assert_int(rear.ledger.total_stock("M11")).is_equal(100)
		assert_int(rear.ledger.total_stock("M06")).is_zero()
		assert_float(rear.production.history[0].completed_at).is_equal_approx(20, Rear.EPS)
		assert_float(rear.munitions_production.history[0].completed_at).is_equal_approx(25, Rear.EPS)
		assert_float(rear.materials_production.history[0].completed_at).is_equal_approx(25, Rear.EPS)
		assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 35, "M02": 1, "M03": 11, "M04": 70})
		assert_float(rear.munitions_production.snapshot().recipe_records.R27.history[0].work).is_equal(10.0)
		assert_dict(rear._output_promises).is_empty()
		assert_array(rear.audit()).is_empty()


func test_r27_fractional_endpoint_preserves_meaningfully_partial_work_across_pause() -> void:
	for count in [2, 4]:
		var rear := _local(2, 10, count)
		rear.advance_time(40.0 / count - 10 * Rear.EPS)
		assert_int(rear.ledger.total_stock("M06")).is_zero()
		assert_float(rear.munitions_production.batch.work).is_equal_approx(40.0 - count * 10 * Rear.EPS, 0.000000001)
		rear.munitions_production.set_paused(true)
		rear.advance_time(100)
		assert_int(rear.ledger.total_stock("M06")).is_zero()
		rear.munitions_production.set_paused(false)
		rear.advance_time(10 * Rear.EPS)
		_coverage(rear, 1, 0)
		assert_float(rear.munitions_production.history[0].work).is_equal(40.0)
