extends GdUnitTestSuite
## Component fixtures below are separate from the two raw-stock chain cases.

const Rear = preload("res://game/staffing/rear_simulation.gd")
const F05 = preload("res://game/production/r02_production.gd")
const Rifle = preload("res://game/production/r01_production.gd")
const Materials = preload("res://game/production/r26_production.gd")
const SPECS := {
	"R32": {"metal": 100, "work": 180.0, "type": "E25", "yield": 10, "mass": 12.0, "promise": 120.0},
	"R33": {"metal": 30, "work": 100.0, "type": "E26", "yield": 100, "mass": 0.5, "promise": 50.0},
}


func _rear(recipe: String, count: int = 4, access: bool = true) -> RefCounted:
	var rear := Rear.new("Empty")
	for index in count: rear.add_person("operator-%d" % index, false, "None", "duty-munitions")
	rear.set_target("munitions", count)
	var declared: Array[String] = []
	if access: declared.append(recipe)
	rear.munitions_production = F05.new(rear, declared)
	return rear


func _component(recipe: String, count: int = 4, missing: String = "") -> RefCounted:
	var rear := _rear(recipe, count)
	rear.munitions_production.request_recipe(recipe)
	rear.ledger.add_stock("metal", "M01", SPECS[recipe].metal - (1 if missing == "M01" else 0), 1, "munitions_input", rear.PLAYER)
	rear.ledger.add_stock("explosives", "M06", 20 - (1 if missing == "M06" else 0), 1, "munitions_input", rear.PLAYER)
	return rear


func _target(activity: RefCounted, count: int) -> void:
	activity.set_paused(true)
	activity.set_mode("Stock target")
	activity.set_stock_target(count)
	activity.set_paused(false)


func _coverage(rear: RefCounted, available: int, planned: int) -> void:
	var view: Dictionary = rear.munitions_production.stock_coverage()
	assert_int(view.available).is_equal(available)
	assert_int(view.planned).is_equal(planned)
	assert_int(view.projected).is_equal(available + planned)
	assert_array(rear.audit()).is_empty()


func test_shell_access_is_declared_at_construction_and_never_grants_stock_or_cancels_old_batch() -> void:
	for recipe in SPECS:
		var rear := _rear(recipe, 4, false)
		var activity: RefCounted = rear.munitions_production
		rear.ledger.add_stock("metal", "M01", 1, 1, "munitions_input", rear.PLAYER)
		rear.ledger.add_stock("powder", "M03", 1, 1, "munitions_input", rear.PLAYER)
		rear.advance_time(1)
		var batch: Dictionary = activity.batch.duplicate(true)
		var ledger: Dictionary = rear.ledger.snapshot()
		var promises: Dictionary = rear._output_promises.duplicate(true)
		assert_bool(activity.request_recipe(recipe).ok).is_false()
		assert_dict(activity.batch).is_equal(batch)
		assert_dict(activity.snapshot().pending_recipe_change).is_empty()
		assert_dict(rear.ledger.snapshot()).is_equal(ledger)
		assert_dict(rear._output_promises).is_equal(promises)
		var authorized := _rear(recipe)
		assert_bool(authorized.munitions_production.request_recipe(recipe).ok).is_true()
		assert_dict(authorized.ledger.snapshot().consumed).is_empty()
		assert_int(authorized.ledger.total_stock(SPECS[recipe].type)).is_zero()
		assert_int(authorized.ledger.total_stock("M06")).is_zero()
		assert_bool(authorized.munitions_production.request_recipe("R33" if recipe == "R32" else "R32").ok).is_false()


func test_component_exact_shell_inputs_work_yields_mass_and_two_four_ordinary_operators() -> void:
	for recipe in SPECS:
		var spec: Dictionary = SPECS[recipe]
		for count in [2, 4]:
			var rear := _component(recipe, count)
			var activity: RefCounted = rear.munitions_production
			assert_str(activity.mode).is_equal("Continuous")
			rear.advance_time(0)
			assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": spec.metal, "M06": 20})
			assert_float(activity.batch.required_work).is_equal(spec.work)
			assert_float(activity.snapshot().output_promise.mass).is_equal(spec.promise)
			_coverage(rear, 0, spec.yield)
			assert_int(rear.ledger.total_stock(spec.type)).is_zero()
			rear.advance_time(spec.work / count)
			assert_int(rear.ledger.total_stock(spec.type)).is_equal(spec.yield)
			assert_float(rear.ledger.loose_stock_mass_at("munitions_output")).is_equal(spec.promise)
			assert_float(rear.ledger.inspect_entity(activity.history[0].output_id).unit_mass_kg).is_equal(spec.mass)
			assert_float(activity.history[0].work).is_equal(spec.work)
			assert_float(activity.history[0].completed_at).is_equal(spec.work / count)
			assert_dict(rear._output_promises).is_empty()
			rear.advance_time(1)
			assert_int(activity.history.size()).is_equal(1)
			_coverage(rear, spec.yield, 0)


func test_each_missing_other_reserved_foreign_remote_person_and_cargo_ingredient_refuses_atomic_start() -> void:
	for recipe in SPECS:
		for missing in ["M01", "M06"]:
			var rear := _component(recipe, 4, missing)
			for entry in [["foreign", "munitions_input", "supplier"], ["remote", "depot", rear.PLAYER], ["personal", "operator-0", rear.PLAYER]]:
				rear.ledger.add_stock(entry[0], missing, 1, 1, entry[1], entry[2])
			rear.ledger.add_carrier("supplier", "rear", "supplier", "supplier")
			rear.ledger.add_stock("cargo", missing, 1, 1, "supplier", rear.PLAYER)
			rear.ledger.add_stock("raw-powder", "M03", 200, 1, "munitions_input", rear.PLAYER)
			rear.advance_time(100)
			assert_dict(rear.ledger.snapshot().consumed).is_empty()
			assert_dict(rear._output_promises).is_empty()
			rear.ledger.add_stock("last", missing, 1, 1, "munitions_input", rear.PLAYER)
			rear.ledger.request_stock("shipment", "last", 1, "other", "outbound", rear.PLAYER)
			rear.advance_time(0)
			assert_dict(rear.ledger.snapshot().consumed).is_empty()
			rear.ledger.release_claim("shipment")
			rear.advance_time(0)
			assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": SPECS[recipe].metal, "M06": 20})
			assert_int(rear.ledger.inspect_entity("raw-powder").quantity).is_equal(200)
			assert_array(rear.audit()).is_empty()


func _raw_chain(recipe: String) -> RefCounted:
	var rear := _rear(recipe)
	var activity: RefCounted = rear.munitions_production
	rear.add_person("hauler", false, "None", "duty-depot")
	var metal: int = SPECS[recipe].metal + 40
	rear.ledger.add_stock("raw-metal", "M01", metal, 1, "depot", rear.PLAYER)
	rear.ledger.add_stock("raw-powder", "M03", 200, 1, "depot", rear.PLAYER)
	activity.request_recipe(recipe)
	assert_str(activity.snapshot().status).is_equal("Missing Inputs")
	activity.request_recipe("R27")
	_target(activity, 20)
	rear.request_haul("depot", "munitions_input", "M01", metal)
	rear.request_haul("depot", "munitions_input", "M03", 200)
	rear.set_target("hauling", 1)
	rear.advance_time(3000)
	assert_int(activity.history.size()).is_equal(20)
	assert_dict(activity.batch).is_empty()
	assert_int(rear.ledger.total_stock("M06")).is_equal(20)
	assert_int(rear.ledger.available_stock_at("munitions_output", "M06")).is_equal(20)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 40, "M03": 200})
	var ids: Array[String] = []
	for item in activity.history:
		assert_float(item.work).is_equal(40.0)
		assert_float(item.completed_at - item.started_at).is_equal_approx(10, Rear.EPS)
		ids.append(item.output_id)
		assert_str(rear.ledger.inspect_entity(item.output_id).holder_id).is_equal("munitions_output")
	activity.request_recipe(recipe)
	_target(activity, 1)
	assert_dict(activity.batch).is_empty() # Output M06 is not local recipe input.
	assert_int(activity.snapshot().missing_local.M06).is_equal(20)
	rear.request_haul("munitions_output", "munitions_input", "M06", 20)
	var saw_last := false
	for step in 120:
		var actor: Dictionary = rear.actors.hauler
		if actor.phase in ["Carry", "Drop"]:
			assert_bool(actor.load.source == "munitions_output").is_true()
			assert_bool(actor.load.type == "M06").is_true()
			assert_bool(actor.load.stock in ids).is_true()
			if rear.ledger.available_stock_at("munitions_input", "M06") == 19:
				saw_last = true
				assert_dict(activity.batch).is_empty()
				assert_int(activity.stock_coverage().planned).is_zero()
				assert_int(rear.ledger.total_stock(SPECS[recipe].type)).is_zero()
		if not activity.batch.is_empty(): break
		rear.advance_time(actor.deadline - rear.time)
	assert_bool(saw_last).is_true()
	assert_float(activity.batch.work).is_zero()
	assert_int(rear.jobs.back().delivered).is_equal(20)
	assert_int(rear.jobs.back().selected).is_equal(20)
	var consumed_ids: Array[String] = []
	for part in activity.batch.receipt:
		if part.type == "M06": consumed_ids.append(part.id)
	assert_array(consumed_ids).has_size(20)
	for id in consumed_ids: assert_bool(rear.ledger.inspect_entity(id).origin_id in ids).is_true()
	assert_int(rear.ledger.total_stock("M06")).is_zero()
	rear.advance_time(SPECS[recipe].work / 4.0)
	assert_int(activity.history.size()).is_equal(1)
	assert_int(activity.snapshot().recipe_records.R27.history.size()).is_equal(20)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": metal, "M03": 200, "M06": 20})
	assert_float(rear.ledger.loose_stock_mass_at("munitions_output")).is_equal(SPECS[recipe].promise)
	assert_dict(activity.batch).is_empty()
	assert_dict(rear._output_promises).is_empty()
	_coverage(rear, SPECS[recipe].yield, 0)
	return rear


func test_raw_depot_twenty_r27_completions_actual_m06_handling_then_ten_r32_shells() -> void:
	var rear := _raw_chain("R32")
	var physical_shells: int = rear.ledger.total_stock("E25")
	assert_int(physical_shells).is_equal(10)
	assert_int(rear.ledger.total_stock("E26")).is_zero()


func test_raw_depot_twenty_r27_completions_actual_m06_handling_then_hundred_r33_rounds() -> void:
	var rear := _raw_chain("R33")
	assert_int(rear.ledger.total_stock("E26")).is_equal(100)
	assert_int(rear.ledger.total_stock("E25")).is_zero()


func test_whole_shell_promise_mixed_finished_contents_and_other_inbound_claims_are_atomic() -> void:
	for recipe in SPECS:
		var rear := _component(recipe)
		var activity: RefCounted = rear.munitions_production
		var existing: int = int(1000 - SPECS[recipe].promise)
		rear.ledger.add_stock("finished-m06", "M06", existing, 1, "munitions_output", rear.PLAYER)
		rear.reserve_output_space("same-bay-other", "munitions_output", "E02", 0.5)
		rear.advance_time(0)
		assert_dict(rear.ledger.snapshot().consumed).is_empty()
		assert_dict(activity.batch).is_empty()
		rear.release_output_space("same-bay-other")
		rear.advance_time(0)
		rear.reserve_output_space("independent", "materials_output", "M11", 100)
		var before: Dictionary = rear.stores.duplicate(true)
		assert_bool(rear.set_store("munitions_output", false, 999, ["M03"]).ok).is_false()
		assert_bool(rear.set_store("munitions_output", true, -1, ["M06"]).ok).is_false()
		assert_dict(rear.stores).is_equal(before)
		rear.advance_time(SPECS[recipe].work / 4.0)
		assert_float(rear.ledger.loose_stock_mass_at("munitions_output")).is_equal(1000.0)
		assert_int(rear.ledger.inspect_entity("finished-m06").quantity).is_equal(existing)
		assert_bool(rear._output_promises.has("independent")).is_true()
		assert_int(rear._output_promises.size()).is_equal(1)
		assert_array(rear.audit()).is_empty()


func test_shell_pause_staff_access_mode_target_and_explicit_cancel_preserve_owner() -> void:
	for recipe in SPECS:
		var rear := _component(recipe)
		var activity: RefCounted = rear.munitions_production
		_target(activity, 1)
		rear.advance_time(5)
		var partial: Dictionary = activity.batch.duplicate(true)
		assert_float(partial.work).is_equal(20.0)
		assert_bool(activity.set_stock_target(-1).ok).is_false()
		activity.set_stock_target(0)
		activity.set_mode("Continuous")
		activity.set_mode("Stock target")
		activity.set_paused(true)
		rear.advance_time(100)
		assert_dict(activity.batch).is_equal(partial)
		activity.set_paused(false)
		rear.set_target("munitions", 0)
		rear.advance_time(100)
		assert_dict(activity.batch).is_equal(partial)
		rear.set_target("munitions", 4)
		rear.set_store("munitions_output", false)
		rear.advance_time(100)
		assert_dict(activity.batch).is_equal(partial)
		assert_float(activity.snapshot().output_promise.mass).is_equal(SPECS[recipe].promise)
		_coverage(rear, 0, 0)
		rear.reserve_output_space("other", "workshop_output", "E01", 4)
		var consumed: Dictionary = rear.ledger.snapshot().consumed
		activity.cancel()
		activity.cancel()
		assert_dict(rear.ledger.snapshot().consumed).is_equal(consumed)
		assert_str(activity.history[0].state).is_equal("Cancelled")
		assert_float(activity.history[0].work).is_equal(20.0)
		assert_int(rear._output_promises.size()).is_equal(1)
		assert_bool(rear._output_promises.has("other")).is_true()
		assert_int(rear.ledger.total_stock(SPECS[recipe].type)).is_zero()


func test_earned_blocked_shell_completion_requires_no_extra_work_and_confirmed_change_discards_it() -> void:
	for recipe in SPECS:
		for change in [false, true]:
			var rear := _component(recipe)
			var activity: RefCounted = rear.munitions_production
			rear.advance_time(0)
			activity.advance_work(SPECS[recipe].work / 4.0) # Component boundary, not elapsed-clock evidence.
			rear.set_store("munitions_output", false)
			rear.set_target("munitions", 0)
			rear.advance_time(100)
			assert_int(rear.ledger.total_stock(SPECS[recipe].type)).is_zero()
			if change:
				var request: Dictionary = activity.request_recipe("R27")
				assert_bool(request.confirmation_required).is_true()
				activity.confirm_recipe(request.token)
				assert_str(activity.snapshot().recipe_records[recipe].history[0].state).is_equal("Cancelled")
				assert_dict(rear._output_promises).is_empty()
			rear.set_store("munitions_output", true)
			assert_int(rear.ledger.total_stock(SPECS[recipe].type)).is_equal(0 if change else SPECS[recipe].yield)
			assert_array(rear.audit()).is_empty()


func test_shell_selection_decline_confirm_stale_repeat_and_preserved_history_configuration() -> void:
	for recipe in SPECS:
		var rear := _component(recipe)
		var activity: RefCounted = rear.munitions_production
		_target(activity, 1)
		rear.advance_time(5)
		var before: Dictionary = activity.snapshot()
		var request: Dictionary = activity.request_recipe("R27")
		activity.decline_recipe(request.token)
		assert_dict(activity.snapshot()).is_equal(before)
		request = activity.request_recipe("R27")
		activity.confirm_recipe(request.token)
		assert_bool(activity.confirm_recipe(request.token).ok).is_false()
		assert_dict(activity.batch).is_empty()
		assert_str(activity.snapshot().recipe_records[recipe].history[0].state).is_equal("Cancelled")
		assert_float(activity.snapshot().recipe_records[recipe].history[0].work).is_equal(20.0)
		activity.request_recipe(recipe)
		assert_int(activity.stock_target).is_equal(1)
		assert_str(activity.mode).is_equal("Stock target")
		assert_int(activity.history.size()).is_equal(1)
		rear.ledger.add_stock("more-metal", "M01", SPECS[recipe].metal, 1, "munitions_input", rear.PLAYER)
		rear.ledger.add_stock("more-m06", "M06", 20, 1, "munitions_input", rear.PLAYER)
		rear.advance_time(0)
		assert_str(activity.batch.id).is_equal(recipe.to_lower() + "-batch-0002")
		request = activity.request_recipe("R27")
		rear.advance_time(SPECS[recipe].work / 4.0)
		assert_bool(activity.confirm_recipe(request.token).ok).is_false()
		assert_str(activity.snapshot().recipe).is_equal(recipe)
		assert_int(activity.history.size()).is_equal(2)
		assert_int(rear.ledger.total_stock(SPECS[recipe].type)).is_equal(SPECS[recipe].yield)
		assert_array(rear.audit()).is_empty()


func test_shell_whole_yield_targets_exclude_other_types_and_other_use_claims() -> void:
	for recipe in SPECS:
		var rear := _component(recipe)
		var activity: RefCounted = rear.munitions_production
		activity.paused = true # Declared component initialization before settling.
		var type: String = SPECS[recipe].type
		rear.ledger.add_stock("own", type, 2, SPECS[recipe].mass, "depot", rear.PLAYER)
		rear.ledger.request_stock("shipment", "own", 1, "other", "outbound", rear.PLAYER)
		for other in ["E02", "M06", "E25", "E26"]:
			if other != type: rear.ledger.add_stock(other, other, 100, 0.5, "receiving", rear.PLAYER)
		rear.ledger.add_stock("foreign", type, 10, SPECS[recipe].mass, "depot", "supplier")
		rear.ledger.add_stock("personal", type, 1, SPECS[recipe].mass, "operator-0", rear.PLAYER)
		rear.ledger.add_carrier("carrier", "rear", "supplier", "supplier")
		rear.ledger.add_stock("cargo", type, 10, SPECS[recipe].mass, "carrier", rear.PLAYER)
		rear.ledger.add_stock("blocked", type, 1, SPECS[recipe].mass, "support_output", rear.PLAYER)
		rear.set_store("support_output", false)
		_coverage(rear, 1, 0)
		_target(activity, 2)
		_coverage(rear, 1, SPECS[recipe].yield)
		rear.advance_time(SPECS[recipe].work / 4.0)
		_coverage(rear, 1 + SPECS[recipe].yield, 0)
		assert_dict(activity.batch).is_empty()
		assert_int(rear.ledger.inspect_claim("shipment").reserved).is_equal(1)


func _haul(recipe: String) -> RefCounted:
	var rear := _rear(recipe)
	rear.munitions_production.request_recipe(recipe)
	_target(rear.munitions_production, 0)
	rear.ledger.add_stock("ammo", SPECS[recipe].type, SPECS[recipe].yield, SPECS[recipe].mass, "depot", rear.PLAYER)
	rear.add_person("hauler", false, "None", "duty-depot")
	rear.request_haul("depot", "receiving", SPECS[recipe].type, SPECS[recipe].yield)
	return rear


func test_actual_shell_handling_correct_mass_one_type_25kg_claim_carry_deposit_and_reroute() -> void:
	for recipe in SPECS:
		var rear := _haul(recipe)
		var spec: Dictionary = SPECS[recipe]
		var portion: int = 2 if recipe == "R32" else 50
		rear.set_target("hauling", 1)
		assert_int(rear.actors.hauler.load.count).is_equal(portion)
		assert_float(rear.actors.hauler.load.mass).is_equal(portion * spec.mass)
		_coverage(rear, spec.yield - portion, portion)
		rear.advance_time(2)
		assert_int(rear.munitions_production.stock_coverage().internal_carried).is_equal(portion)
		rear.set_store("receiving", false)
		assert_str(rear.actors.hauler.load.destination).is_not_equal("receiving")
		_coverage(rear, spec.yield - portion, portion)
		rear.cancel_job(rear.jobs[0].id)
		_coverage(rear, spec.yield - portion, 0)
		rear.advance_time(1000)
		_coverage(rear, spec.yield, 0)
		rear = _haul(recipe)
		rear.set_target("hauling", 1)
		rear.advance_time(2000)
		assert_int(rear.jobs[0].delivered).is_equal(spec.yield)
		assert_int(rear.jobs[0].selected).is_equal(5 if recipe == "R32" else 2)
		_coverage(rear, spec.yield, 0)


func test_shell_pile_recovery_removes_forecast_until_actual_eligible_deposit() -> void:
	for recipe in SPECS:
		var rear := _haul(recipe)
		var portion: int = 2 if recipe == "R32" else 50
		rear.set_target("hauling", 1)
		rear.advance_time(2)
		for id in rear.stores.keys(): rear.set_store(id, false)
		_coverage(rear, 0, 0)
		rear.advance_time(300)
		var pile: String = rear.jobs[0].recovery_sources[0]
		assert_int(rear.ledger.available_stock_at(pile, SPECS[recipe].type)).is_equal(portion)
		rear.set_store("receiving", true)
		_coverage(rear, 0, 0)
		rear.advance_time(300)
		_coverage(rear, portion, 0)
		rear.set_store("depot", true)
		rear.advance_time(2000)
		_coverage(rear, SPECS[recipe].yield, 0)


func _three(recipe: String) -> RefCounted:
	var rear := _component(recipe)
	rear.munitions_production.paused = true
	for duty in ["workshop", "materials"]:
		for index in 2: rear.add_person(duty + str(index), false, "None", "duty-" + duty)
		rear.set_target(duty, 2)
	rear.ledger.add_stock("rifle-metal", "M01", 2, 1, "workshop_input", rear.PLAYER)
	rear.ledger.add_stock("components", "M02", 1, 1, "workshop_input", rear.PLAYER)
	rear.ledger.add_stock("materials-metal", "M01", 30, 1, "materials_input", rear.PLAYER)
	rear.ledger.add_stock("timber", "M04", 70, 1, "materials_input", rear.PLAYER)
	rear.production = Rifle.new(rear)
	rear.materials_production = Materials.new(rear)
	rear.munitions_production.set_paused(false)
	return rear


func test_independent_r01_r26_and_single_shell_owner_coarse_fractional_durations_agree() -> void:
	for recipe in SPECS:
		var coarse := _three(recipe)
		var split := _three(recipe)
		var duration: float = maxf(50, SPECS[recipe].work / 4.0)
		coarse.advance_time(duration)
		for delta in [0.125, 9.875, 10.0, 4.999, 0.001, duration - 25]: split.advance_time(delta)
		for rear in [coarse, split]:
			assert_int(rear._production_activities().size()).is_equal(3)
			assert_float(rear.production.history[0].completed_at).is_equal_approx(20, Rear.EPS)
			assert_float(rear.materials_production.history[0].completed_at).is_equal_approx(50, Rear.EPS)
			assert_float(rear.munitions_production.history[0].completed_at).is_equal_approx(SPECS[recipe].work / 4.0, Rear.EPS)
			for id in rear.munitions_production.operators():
				assert_array(rear.production.operators()).not_contains(id)
				assert_array(rear.materials_production.operators()).not_contains(id)
			assert_int(rear.ledger.total_stock(SPECS[recipe].type)).is_equal(SPECS[recipe].yield)
			assert_int(rear.ledger.total_stock("E01")).is_equal(1)
			assert_int(rear.ledger.total_stock("M11")).is_equal(100)
			assert_dict(rear._output_promises).is_empty()
			assert_array(rear.audit()).is_empty()


func test_shell_fractional_endpoints_do_not_round_meaningful_partial_work_across_pause() -> void:
	for recipe in SPECS:
		for count in [2, 4]:
			var rear := _component(recipe, count)
			rear.advance_time(SPECS[recipe].work / count - 10 * Rear.EPS)
			assert_int(rear.ledger.total_stock(SPECS[recipe].type)).is_zero()
			assert_float(rear.munitions_production.batch.work).is_equal_approx(SPECS[recipe].work - count * 10 * Rear.EPS, 0.000000001)
			rear.munitions_production.set_paused(true)
			rear.advance_time(100)
			rear.munitions_production.set_paused(false)
			rear.advance_time(10 * Rear.EPS)
			_coverage(rear, SPECS[recipe].yield, 0)


func test_r27_active_forecast_and_raw_powder_never_supply_shell_ingredients() -> void:
	for recipe in SPECS:
		var rear := _rear(recipe)
		var activity: RefCounted = rear.munitions_production
		activity.request_recipe("R27")
		rear.ledger.add_stock("raw-metal", "M01", SPECS[recipe].metal + 2, 1, "munitions_input", rear.PLAYER)
		rear.ledger.add_stock("raw-powder", "M03", 210, 1, "munitions_input", rear.PLAYER)
		rear.advance_time(5)
		assert_int(activity.stock_coverage().planned).is_equal(1)
		assert_int(rear.ledger.total_stock("M06")).is_zero()
		var request: Dictionary = activity.request_recipe(recipe)
		assert_bool(request.confirmation_required).is_true()
		activity.confirm_recipe(request.token)
		assert_str(activity.snapshot().status).is_equal("Missing Inputs")
		assert_dict(activity.batch).is_empty()
		assert_int(activity.stock_coverage().planned).is_zero()
		assert_int(rear.ledger.total_stock(SPECS[recipe].type)).is_zero()
		assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M03": 10})
		assert_dict(rear._output_promises).is_empty()
