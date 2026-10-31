extends GdUnitTestSuite

const Rear = preload("res://game/staffing/rear_simulation.gd")
const Rifle = preload("res://game/production/r01_production.gd")
const Rounds = preload("res://game/production/r02_production.gd")

class CountedRounds extends Rounds:
	var detailed_calls := 0
	var projected_calls := 0
	func stock_coverage(collect_excluded: bool = true) -> Dictionary:
		if collect_excluded: detailed_calls += 1
		else: projected_calls += 1
		return super.stock_coverage(collect_excluded)


func test_positive_target_ignores_issued_and_loaded_rounds_but_reports_them() -> void:
	var rear := _local(0,0)
	var production := CountedRounds.new(rear)
	rear.munitions_production = production
	production.set_mode("Stock target")
	production.set_stock_target(150)
	rear.ledger.add_stock("target-rounds","E02",200,0.02,"depot",rear.PLAYER)
	rear.ledger.request_stock("target-outbound","target-rounds",80,"shipment","actual outbound claim",rear.PLAYER)
	var before: Dictionary = production.stock_coverage(false)
	rear.ledger.add_stock("issued-rounds","E02",100,0.02,"munitions-0",rear.PLAYER)
	rear.ledger.add_weapon("issued-rifle","E01",4,"munitions-0",rear.PLAYER,"E02",30)
	assert_bool(rear.ledger.load_rounds("issued-rifle","issued-rounds",30).ok).is_true()
	rear.ledger.add_carrier("military-cargo","rear",rear.PLAYER,rear.PLAYER)
	rear.ledger.add_stock("hull-rounds","E02",500,0.02,"military-cargo",rear.PLAYER)
	var fast: Dictionary = production.stock_coverage(false)
	for key in ["available","planned","projected","eligible_physical","eligible_reserved","internal_relocation","internal_carried","batch_forecast"]:
		assert_int(fast[key]).is_equal(before[key])
	_coverage(rear,120,0)
	var report: Dictionary = production.stock_coverage()
	assert_bool(report.excluded.any(func(row: Dictionary) -> bool: return row.holder == "munitions-0")).is_true()
	assert_bool(report.excluded.any(func(row: Dictionary) -> bool: return row.holder == "issued-rifle")).is_true()
	assert_bool(report.excluded.any(func(row: Dictionary) -> bool: return row.holder == "military-cargo")).is_true()
	assert_array(fast.excluded).is_empty()
	assert_dict(report).is_equal(production.stock_coverage(true))
	production.detailed_calls = 0
	production.projected_calls = 0
	assert_bool(production._target_satisfied()).is_false()
	assert_int(production.projected_calls).is_equal(1)
	assert_int(production.detailed_calls).is_zero()
	rear.ledger.add_stock("actual-arrival","E02",100,0.02,"receiving",rear.PLAYER)
	assert_bool(production._target_satisfied()).is_true()
	_coverage(rear,220,0)
	assert_dict(production.batch).is_empty()
	assert_dict(rear.ledger.snapshot().consumed).is_empty()


func _local(metal: int = 1, powder: int = 1, operators: int = 2) -> RefCounted:
	var rear := Rear.new("Empty")
	for index in operators: rear.add_person("munitions-%d" % index, false, "None", "duty-munitions")
	rear.set_target("munitions", operators)
	if metal > 0: rear.ledger.add_stock("metal", "M01", metal, 1, "munitions_input", rear.PLAYER)
	if powder > 0: rear.ledger.add_stock("powder", "M03", powder, 1, "munitions_input", rear.PLAYER)
	rear.munitions_production = Rounds.new(rear)
	return rear


func _target(rear: RefCounted, minimum: int) -> void:
	rear.munitions_production.set_paused(true)
	rear.munitions_production.set_mode("Stock target")
	rear.munitions_production.set_stock_target(minimum)
	rear.munitions_production.set_paused(false)


func _coverage(rear: RefCounted, available: int, planned: int) -> void:
	var view: Dictionary = rear.munitions_production.stock_coverage()
	var projected: Dictionary = rear.munitions_production.stock_coverage(false)
	for key in ["available","planned","projected","eligible_physical","eligible_reserved","internal_relocation","internal_carried","batch_forecast"]:
		assert_int(projected[key]).is_equal(view[key])
	assert_str(projected.batch_id).is_equal(view.batch_id)
	assert_int(view.available).is_equal(available)
	assert_int(view.planned).is_equal(planned)
	assert_int(view.projected).is_equal(available + planned)
	assert_array(rear.audit()).is_empty()


func test_exact_local_r02_consumption_work_yield_and_mass_complete_once() -> void:
	var completed_yield := 0
	for operator_count in [2, 4]:
		var rear := _local(1, 1, operator_count)
		var production: RefCounted = rear.munitions_production
		assert_str(production.mode).is_equal("Continuous")
		rear.advance_time(0)
		assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 1, "M03": 1})
		assert_float(production.snapshot().output_promise.mass).is_equal(2.0)
		assert_array(production.batch.receipt).is_equal([{"id": "metal", "type": "M01", "count": 1}, {"id": "powder", "type": "M03", "count": 1}])
		_coverage(rear, 0, 100)
		rear.advance_time(40.0 / operator_count)
		assert_int(rear.ledger.total_stock("E02")).is_equal(100)
		assert_int(rear.ledger.total_stock("E01")).is_zero()
		assert_float(rear.ledger.loose_stock_mass_at("munitions_output")).is_equal(2.0)
		assert_float(rear.ledger.inspect_entity(production.history[0].output_id).unit_mass_kg).is_equal(0.02)
		assert_float(production.history[0].work).is_equal(40.0)
		assert_float(production.history[0].completed_at).is_equal(40.0 / operator_count)
		assert_dict(production.batch).is_empty()
		assert_dict(rear._output_promises).is_empty()
		_coverage(rear, 100, 0)
		var before: Dictionary = rear.ledger.snapshot()
		rear.advance_time(0)
		rear.advance_time(0)
		assert_dict(rear.ledger.snapshot()).is_equal(before)
		assert_int(production.history.size()).is_equal(1)
		completed_yield = rear.ledger.inspect_entity(production.history[0].output_id).quantity
	assert_int(completed_yield).is_equal(100)


func test_foreign_remote_carried_and_other_reserved_inputs_cannot_start() -> void:
	var rear := _local(1, 0)
	var production: RefCounted = rear.munitions_production
	rear.ledger.add_stock("foreign-powder", "M03", 1, 1, "munitions_input", "supplier")
	rear.ledger.add_stock("remote-powder", "M03", 1, 1, "depot", rear.PLAYER)
	rear.ledger.add_carrier("supplier", "rear", "supplier", "supplier")
	rear.ledger.add_stock("supplier-powder", "M03", 1, 1, "supplier", rear.PLAYER)
	rear.ledger.add_stock("personal-powder", "M03", 1, 1, "munitions-0", rear.PLAYER)
	var before: Dictionary = rear.ledger.snapshot()
	rear.advance_time(0)
	assert_dict(rear.ledger.snapshot()).is_equal(before)
	assert_dict(production.batch).is_empty()
	assert_dict(rear._output_promises).is_empty()
	assert_str(production.snapshot().status).is_equal("Missing Inputs")
	rear.ledger.add_stock("own-powder", "M03", 1, 1, "munitions_input", rear.PLAYER)
	rear.ledger.request_stock("other-use", "metal", 1, "shipment", "outbound", rear.PLAYER)
	before = rear.ledger.snapshot()
	rear.advance_time(0)
	assert_dict(rear.ledger.snapshot()).is_equal(before)
	rear.ledger.release_claim("other-use")
	rear.advance_time(0)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 1, "M03": 1})
	for id in ["foreign-powder", "remote-powder", "supplier-powder", "personal-powder"]:
		assert_int(rear.ledger.inspect_entity(id).quantity).is_equal(1)
	assert_array(rear.audit()).is_empty()


func test_complete_output_capacity_and_filter_edits_protect_independent_claims() -> void:
	var rear := _local()
	var production: RefCounted = rear.munitions_production
	rear.set_store("munitions_output", true, 1)
	assert_dict(production.batch).is_empty()
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_str(production.snapshot().status).is_equal("Output Full")
	rear.ledger.add_stock("other-output", "M04", 998, 1, "munitions_output", rear.PLAYER)
	rear.set_store("munitions_output", true, 1000)
	assert_float(production.snapshot().output_promise.mass).is_equal(2.0)
	assert_bool(rear.reserve_output_space("independent", "workshop_output", "E01", 4).ok).is_true()
	var before: Dictionary = rear.stores.duplicate(true)
	assert_bool(rear.set_store("munitions_output", false, 999, ["M01"]).ok).is_false()
	assert_dict(rear.stores).is_equal(before)
	assert_bool(rear.set_store("munitions_output", true, -1, ["M01"]).ok).is_false()
	assert_dict(rear.stores).is_equal(before)
	rear.advance_time(20)
	assert_int(rear.ledger.total_stock("E02")).is_equal(100)
	assert_int(rear.ledger.inspect_entity("other-output").quantity).is_equal(998)
	assert_float(rear.ledger.loose_stock_mass_at("munitions_output")).is_equal(1000.0)
	assert_bool(rear._output_promises.has("independent")).is_true()
	assert_int(rear._output_promises.size()).is_equal(1)
	assert_array(rear.audit()).is_empty()


func test_reserved_200_target150_starts_one_full100_yield_for_available220() -> void:
	var rear := _local(3, 3)
	var production: RefCounted = rear.munitions_production
	production.set_paused(true)
	rear.ledger.add_stock("existing-rounds", "E02", 200, 0.02, "depot", rear.PLAYER)
	rear.ledger.request_stock("outbound80", "existing-rounds", 80, "shipment", "outbound rounds", rear.PLAYER)
	_target(rear, 150)
	_coverage(rear, 120, 100)
	assert_int(production.stock_coverage().projected).is_equal(220)
	var active: Dictionary = production.batch.duplicate(true)
	for repeat in 4:
		production.set_stock_target(150)
		rear.advance_time(0)
		assert_dict(production.batch).is_equal(active)
		_coverage(rear, 120, 100)
	rear.advance_time(20)
	_coverage(rear, 220, 0)
	assert_int(rear.ledger.total_stock("E02")).is_equal(300)
	assert_int(production.history.size()).is_equal(1)
	assert_dict(production.batch).is_empty()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 1, "M03": 1})
	assert_int(rear.ledger.inspect_claim("outbound80").reserved).is_equal(80)
	assert_str(production.snapshot().status).is_equal("Target satisfied — no new batch")
	rear.advance_time(200)
	assert_int(production.history.size()).is_equal(1)
	assert_int(rear.ledger.available_stock_at("munitions_input", "M03")).is_equal(2)


func test_zero_target_partial_edits_and_interruptions_keep_consumed_batch() -> void:
	var rear := _local(2, 2)
	var production: RefCounted = rear.munitions_production
	_target(rear, 0)
	rear.advance_time(100)
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_dict(production.batch).is_empty()
	production.set_stock_target(1)
	rear.advance_time(5)
	var active: Dictionary = production.batch.duplicate(true)
	assert_float(active.work).is_equal(10.0)
	production.set_stock_target(0)
	production.set_mode("Continuous")
	production.set_mode("Stock target")
	production.set_paused(true)
	rear.advance_time(100)
	assert_dict(production.batch).is_equal(active)
	production.set_paused(false)
	rear.set_target("munitions", 0)
	rear.advance_time(100)
	assert_dict(production.batch).is_equal(active)
	assert_str(production.snapshot().status).is_equal("Missing Labour")
	rear.set_target("munitions", 2)
	rear.set_store("munitions_output", false)
	rear.advance_time(100)
	assert_dict(production.batch).is_equal(active)
	_coverage(rear, 0, 0)
	assert_float(rear._output_promises[active.id].mass).is_equal(2.0)
	rear.set_store("munitions_output", true)
	_coverage(rear, 0, 100)
	rear.advance_time(15)
	_coverage(rear, 100, 0)
	assert_dict(production.batch).is_empty()
	assert_int(production.history.size()).is_equal(1)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 1, "M03": 1})
	production.set_stock_target(100)
	rear.advance_time(100)
	assert_int(production.history.size()).is_equal(1)


func test_cancel_and_earned_blocked_completion_preserve_other_owners_and_goods() -> void:
	var rear := _local(2, 2)
	var production: RefCounted = rear.munitions_production
	rear.reserve_output_space("independent", "workshop_output", "E01", 4)
	production.cancel()
	production.cancel()
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	production.resume()
	rear.advance_time(5)
	production.cancel()
	production.cancel()
	assert_int(rear._output_promises.size()).is_equal(1)
	assert_bool(rear._output_promises.has("independent")).is_true()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 1, "M03": 1})
	assert_int(rear.ledger.total_stock("E02")).is_zero()
	production.resume()
	# Component boundary: all earned work must survive invalid physical completion.
	production.advance_work(20)
	rear.set_store("munitions_output", false)
	assert_float(production.batch.work).is_equal(40.0)
	rear.advance_time(100)
	assert_int(rear.ledger.total_stock("E02")).is_zero()
	rear.set_target("munitions", 0)
	rear.set_store("munitions_output", true)
	assert_int(rear.ledger.total_stock("E02")).is_equal(100)
	production.cancel()
	production.cancel()
	assert_int(rear.ledger.total_stock("E02")).is_equal(100)
	assert_bool(rear._output_promises.has("independent")).is_true()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M03": 2})
	assert_array(rear.audit()).is_empty()


func test_e02_loaded_foreign_cargo_person_pile_and_ineligible_holders_are_excluded() -> void:
	var rear := _local(0, 0)
	var production: RefCounted = rear.munitions_production
	rear.ledger.add_stock("loose", "E02", 200, 0.02, "depot", rear.PLAYER)
	rear.ledger.request_stock("other80", "loose", 80, "shipment", "outbound", rear.PLAYER)
	rear.ledger.add_weapon("rifle", "E01", 4, "depot", rear.PLAYER, "E02", 5)
	rear.ledger.load_rounds("rifle", "loose", 5)
	rear.ledger.add_stock("foreign", "E02", 100, 0.02, "depot", "supplier")
	rear.ledger.add_carrier("supplier", "rear", "supplier", "supplier")
	rear.ledger.add_stock("cargo", "E02", 100, 0.02, "supplier", rear.PLAYER)
	rear.ledger.add_stock("personal", "E02", 50, 0.02, "munitions-0", rear.PLAYER)
	rear.ledger.add_place("pile-test", "Temporary recoverable pile", Vector2.ZERO)
	rear.stores["pile-test"] = {"id": "pile-test", "pile": true, "accessible": true, "filter": [], "capacity": 100}
	rear.ledger.add_stock("pile-rounds", "E02", 100, 0.02, "pile-test", rear.PLAYER)
	rear.ledger.add_stock("blocked", "E02", 100, 0.02, "receiving", rear.PLAYER)
	rear.ledger.add_stock("filtered", "E02", 100, 0.02, "support_output", rear.PLAYER)
	rear.set_store("receiving", false)
	rear.set_store("support_output", true, -1, ["M01"])
	_coverage(rear, 115, 0)
	var before: Dictionary = rear.ledger.snapshot()
	var detached: Dictionary = production.stock_coverage()
	detached.stocks.clear()
	_coverage(rear, 115, 0)
	assert_dict(rear.ledger.snapshot()).is_equal(before)
	rear.ledger.unload_rounds("rifle")
	_coverage(rear, 120, 0)
	assert_int(rear.ledger.inspect_claim("other80").reserved).is_equal(80)
	assert_int(rear.ledger.loaded_rounds("rifle")).is_zero()


func _haul_rear() -> RefCounted:
	var rear := _local(0, 0)
	_target(rear, 0)
	rear.ledger.add_stock("rounds", "E02", 200, 0.02, "depot", rear.PLAYER)
	rear.add_person("hauler", false, "None", "duty-depot")
	rear.request_haul("depot", "receiving", "E02", 100)
	return rear


func test_real_e02_claim_carry_and_deposit_convert_coverage_once() -> void:
	var rear := _haul_rear()
	_coverage(rear, 200, 0)
	rear.set_target("hauling", 1)
	_coverage(rear, 100, 100)
	assert_int(rear.ledger.inspect_entity("rounds").reserved).is_equal(100)
	var actor: Dictionary = rear.actors.hauler
	var claim: String = actor.load.claim
	rear.advance_time(2)
	assert_str(actor.phase).is_equal("Carry")
	assert_int(rear.ledger.inspect_claim(claim).fulfilled).is_equal(100)
	_coverage(rear, 100, 100)
	assert_int(rear.munitions_production.stock_coverage().internal_carried).is_equal(100)
	rear.advance_time(300)
	_coverage(rear, 200, 0)
	assert_int(rear.ledger.available_stock_at("receiving", "E02")).is_equal(100)
	assert_int(rear.jobs[0].delivered).is_equal(100)
	assert_int(rear.ledger.total_stock("E02")).is_equal(200)


func test_e02_invalid_destination_reroute_cancel_and_pile_recovery_keep_physical_goods() -> void:
	var rear := _haul_rear()
	rear.set_target("hauling", 1)
	rear.set_store("receiving", false)
	_coverage(rear, 200, 0)
	assert_int(rear.ledger.inspect_entity("rounds").reserved).is_zero()
	rear.set_store("receiving", true)
	rear.advance_time(2)
	rear.set_store("receiving", false)
	_coverage(rear, 100, 100)
	assert_int(rear.munitions_production.stock_coverage().relocations.size()).is_equal(1)
	assert_str(rear.actors.hauler.load.destination).is_not_equal("receiving")
	rear.cancel_job(rear.jobs[0].id)
	_coverage(rear, 100, 0)
	rear.advance_time(300)
	_coverage(rear, 200, 0)
	assert_int(rear.ledger.total_stock("E02")).is_equal(200)
	# Separate active load: no eligible destination creates an actual recoverable pile.
	rear = _haul_rear()
	rear.set_target("hauling", 1)
	rear.advance_time(2)
	for id in rear.stores.keys(): rear.set_store(id, false)
	assert_bool(rear.stores[rear.actors.hauler.load.destination].pile).is_true()
	_coverage(rear, 0, 0)
	rear.advance_time(300)
	assert_int(rear.jobs[0].recovery_sources.size()).is_equal(1)
	var pile: String = rear.jobs[0].recovery_sources[0]
	assert_int(rear.ledger.available_stock_at(pile, "E02")).is_equal(100)
	rear.set_store("receiving", true)
	_coverage(rear, 0, 0)
	rear.advance_time(300)
	_coverage(rear, 100, 0)
	assert_int(rear.ledger.available_stock_at(pile, "E02")).is_zero()
	rear.set_store("depot", true)
	_coverage(rear, 200, 0)


func _both(initially_paused: bool = false) -> RefCounted:
	var rear := _local(1, 1, 2)
	rear.munitions_production.set_paused(true)
	rear.add_person("rifle-operator", false, "None", "duty-workshop")
	rear.set_target("workshop", 1)
	rear.ledger.add_stock("rifle-metal", "M01", 2, 1, "workshop_input", rear.PLAYER)
	rear.ledger.add_stock("rifle-components", "M02", 1, 1, "workshop_input", rear.PLAYER)
	rear.production = Rifle.new(rear)
	rear.production.set_paused(true)
	if not initially_paused:
		rear.production.set_paused(false)
		rear.munitions_production.set_paused(false)
	return rear


func test_simultaneous_facilities_keep_people_inputs_forecasts_and_promises_exclusive() -> void:
	var rear := _both()
	rear.advance_time(5)
	var rifle: RefCounted = rear.production
	var rounds: RefCounted = rear.munitions_production
	assert_float(rifle.batch.work).is_equal(5.0)
	assert_float(rounds.batch.work).is_equal(10.0)
	assert_int(rifle.operators().size()).is_equal(1)
	assert_int(rounds.operators().size()).is_equal(2)
	for id in rifle.operators(): assert_array(rounds.operators()).not_contains(id)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 3, "M02": 1, "M03": 1})
	assert_int(rear._output_promises.size()).is_equal(2)
	assert_float(rear._output_promises[rifle.batch.id].mass).is_equal(4.0)
	assert_float(rear._output_promises[rounds.batch.id].mass).is_equal(2.0)
	assert_int(rifle.stock_coverage().planned).is_equal(1)
	_coverage(rear, 0, 100)
	rounds.set_paused(true)
	rear.advance_time(5)
	assert_float(rifle.batch.work).is_equal(10.0)
	assert_float(rounds.batch.work).is_equal(10.0)
	var rifle_batch: Dictionary = rifle.batch.duplicate(true)
	rounds.cancel()
	assert_dict(rifle.batch).is_equal(rifle_batch)
	assert_int(rear._output_promises.size()).is_equal(1)
	assert_bool(rear._output_promises.has(rifle.batch.id)).is_true()
	rear.advance_time(30)
	assert_int(rear.ledger.total_stock("E01")).is_equal(1)
	assert_int(rear.ledger.total_stock("E02")).is_zero()
	assert_dict(rear._output_promises).is_empty()
	assert_int(rifle.stock_coverage().available).is_equal(1)
	_coverage(rear, 0, 0)
	# A staff request cannot duplicate any existing person across facilities.
	rear.set_target("workshop", 0)
	rear.set_target("munitions", 3)
	rear.advance_time(300)
	assert_array(rifle.operators()).is_empty()
	assert_int(rounds.operators().size()).is_equal(3)
	assert_array(rear.audit()).is_empty()


func test_two_facility_coarse_and_fractional_time_match_independent_completion() -> void:
	var coarse := _both()
	var split := _both()
	coarse.advance_time(40)
	for interval in [0.125, 12.375, 7.5, 19.999, 0.001]: split.advance_time(interval)
	for rear in [coarse, split]:
		assert_int(rear.ledger.total_stock("E01")).is_equal(1)
		assert_int(rear.ledger.total_stock("E02")).is_equal(100)
		assert_float(rear.production.history[0].completed_at).is_equal_approx(40, Rear.EPS)
		assert_float(rear.munitions_production.history[0].completed_at).is_equal_approx(20, Rear.EPS)
		assert_dict(rear._output_promises).is_empty()
		assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 3, "M02": 1, "M03": 1})
		assert_array(rear.audit()).is_empty()
	for pair in [[coarse.production, split.production], [coarse.munitions_production, split.munitions_production]]:
		var expected: Dictionary = pair[0].history[0].duplicate(true)
		var actual: Dictionary = pair[1].history[0].duplicate(true)
		assert_float(actual.completed_at).is_equal_approx(expected.completed_at, Rear.EPS)
		expected.erase("completed_at")
		actual.erase("completed_at")
		assert_dict(actual).is_equal(expected)


func test_r02_fractional_endpoint_and_meaningful_partial_work_keep_clock_tolerance() -> void:
	for count in [1, 2, 4]:
		var rear := _local(1, 1, count)
		rear.advance_time(40.0 / count - 10 * Rear.EPS)
		assert_int(rear.ledger.total_stock("E02")).is_zero()
		assert_float(rear.munitions_production.batch.work).is_equal_approx(40.0 - count * 10 * Rear.EPS, 0.000000001)
		rear.munitions_production.set_paused(true)
		rear.advance_time(100)
		assert_int(rear.ledger.total_stock("E02")).is_zero()
		rear.munitions_production.set_paused(false)
		rear.advance_time(10 * Rear.EPS)
		assert_int(rear.ledger.total_stock("E02")).is_equal(100)
		assert_int(rear.munitions_production.history.size()).is_equal(1)
		assert_array(rear.audit()).is_empty()


func test_r01_and_r02_targets_never_count_each_others_stock_or_forecasts() -> void:
	var rear := _both(true)
	var rifle: RefCounted = rear.production
	var rounds: RefCounted = rear.munitions_production
	rifle.set_paused(true)
	rounds.set_paused(true)
	rear.ledger.add_stock("spare-rifles", "E01", 200, 4, "depot", rear.PLAYER)
	rear.ledger.add_stock("spare-rounds", "E02", 200, 0.02, "receiving", rear.PLAYER)
	rifle.set_mode("Stock target")
	rifle.set_stock_target(201)
	rounds.set_mode("Stock target")
	rounds.set_stock_target(201)
	rifle.set_paused(false)
	assert_int(rifle.stock_coverage().available).is_equal(200)
	assert_int(rifle.stock_coverage().planned).is_equal(1)
	_coverage(rear, 200, 0)
	rounds.set_paused(false)
	_coverage(rear, 200, 100)
	assert_int(rifle.stock_coverage().planned).is_equal(1)
	rear.advance_time(40)
	assert_int(rifle.stock_coverage().available).is_equal(201)
	assert_int(rifle.stock_coverage().planned).is_zero()
	_coverage(rear, 300, 0)
	assert_int(rifle.history.size()).is_equal(1)
	assert_int(rounds.history.size()).is_equal(1)
	assert_dict(rear._output_promises).is_empty()
