extends GdUnitTestSuite

const Rear = preload("res://game/staffing/rear_simulation.gd")
const Production = preload("res://game/production/r01_production.gd")


func _rear(target: int = 0, metal: int = 0, components: int = 0) -> RefCounted:
	var rear := Rear.new("Empty")
	for index in 2: rear.add_person("operator-%d" % index, false, "None", "duty-workshop")
	rear.set_target("workshop", 2)
	if metal > 0: rear.ledger.add_stock("metal", "M01", metal, 1, "workshop_input", rear.PLAYER)
	if components > 0: rear.ledger.add_stock("components", "M02", components, 1, "workshop_input", rear.PLAYER)
	var production := Production.new(rear)
	production.set_mode("Stock target")
	production.set_stock_target(target)
	rear.production = production
	return rear


func _coverage(rear: RefCounted, available: int, planned: int) -> void:
	var view: Dictionary = rear.production.stock_coverage()
	assert_int(view.available).is_equal(available)
	assert_int(view.planned).is_equal(planned)
	assert_int(view.projected).is_equal(available + planned)
	assert_array(rear.audit()).is_empty()


func test_zero_equal_target_and_active_forecast_prevent_duplicate_consumption() -> void:
	var rear := _rear(0, 6, 3)
	var initial: Dictionary = rear.ledger.snapshot()
	rear.advance_time(100)
	assert_array(rear.ledger.snapshot().entities).is_equal(initial.entities)
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_dict(rear.production.batch).is_empty()
	assert_str(rear.production.snapshot().status).is_equal("Target satisfied — no new batch")
	assert_bool(rear.production.set_stock_target(-1).ok).is_false()
	assert_bool(rear.production.set_mode("Invalid").ok).is_false()
	assert_int(rear.production.stock_target).is_zero()
	rear.production.set_stock_target(1)
	_coverage(rear, 0, 1)
	var started: Dictionary = rear.production.batch.duplicate(true)
	for repeat in 5:
		rear.advance_time(0)
		rear.production.set_stock_target(1)
		assert_dict(rear.production.batch).is_equal(started)
		_coverage(rear, 0, 1)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M02": 1})
	rear.advance_time(20)
	_coverage(rear, 1, 0)
	assert_dict(rear.production.batch).is_empty()
	assert_int(rear.production.history.size()).is_equal(1)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M02": 1})
	rear.advance_time(200)
	_coverage(rear, 1, 0)
	assert_int(rear.production.history.size()).is_equal(1)
	assert_int(rear.ledger.available_stock_at("workshop_input", "M01")).is_equal(4)
	# A target edit enables only the next whole real one-rifle batch.
	rear.production.set_stock_target(2)
	_coverage(rear, 1, 1)
	rear.advance_time(20)
	_coverage(rear, 2, 0)
	assert_int(rear.production.history.size()).is_equal(2)


func test_target_and_mode_edits_keep_partial_receipt_promise_and_explicit_cancel_owner() -> void:
	var rear := _rear(3, 6, 3)
	rear.advance_time(5)
	var active: Dictionary = rear.production.batch.duplicate(true)
	assert_float(active.work).is_equal(10.0)
	rear.reserve_output_space("independent-owner", "munitions_output", "M01", 1)
	for target in [1, 0, 10, 0]:
		rear.production.set_stock_target(target)
		rear.production.set_mode("Continuous")
		rear.production.set_mode("Stock target")
		assert_dict(rear.production.batch).is_equal(active)
		assert_float(rear._output_promises[active.id].mass).is_equal(4.0)
		_coverage(rear, 0, 1)
	rear.set_store("workshop_output", false)
	rear.advance_time(100)
	assert_dict(rear.production.batch).is_equal(active)
	_coverage(rear, 0, 0) # Inaccessible destination removes forecast, never work/promise.
	assert_float(rear._output_promises[active.id].mass).is_equal(4.0)
	rear.set_store("workshop_output", true)
	_coverage(rear, 0, 1)
	rear.advance_time(15)
	_coverage(rear, 1, 0)
	assert_dict(rear.production.batch).is_empty()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M02": 1})
	rear.production.set_stock_target(5)
	rear.advance_time(5)
	var consumed: Dictionary = rear.ledger.snapshot().consumed
	rear.production.cancel()
	rear.production.cancel()
	_coverage(rear, 1, 0)
	assert_dict(rear.ledger.snapshot().consumed).is_equal(consumed)
	assert_bool(rear._output_promises.has("independent-owner")).is_true()
	assert_int(rear._output_promises.size()).is_equal(1)
	assert_int(rear.production.history.size()).is_equal(2)
	assert_int(rear.ledger.total_stock("E01")).is_equal(1)


func test_reserved_stock_200_minus_80_requires_thirty_real_r01_batches() -> void:
	var rear := _rear(150, 60, 30)
	rear.ledger.add_stock("existing-rifles", "E01", 200, 4, "depot", rear.PLAYER)
	rear.ledger.request_stock("outbound-order", "existing-rifles", 80, "shipment", "outbound commitment", rear.PLAYER)
	_coverage(rear, 120, 0)
	rear.advance_time(0)
	_coverage(rear, 120, 1)
	assert_int(rear.production.stock_coverage().eligible_physical).is_equal(200)
	assert_int(rear.production.stock_coverage().eligible_reserved).is_equal(80)
	rear.advance_time(600)
	_coverage(rear, 150, 0)
	assert_int(rear.production.history.size()).is_equal(30)
	assert_dict(rear.production.batch).is_empty()
	assert_int(rear.ledger.total_stock("E01")).is_equal(230)
	assert_int(rear.ledger.inspect_claim("outbound-order").reserved).is_equal(80)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 60, "M02": 30})
	assert_str(rear.production.snapshot().status).is_equal("Target satisfied — no new batch")
	rear.advance_time(100)
	assert_int(rear.production.history.size()).is_equal(30)


func test_foreign_cargo_issued_pile_and_ineligible_deposits_are_excluded() -> void:
	var rear := _rear()
	rear.ledger.add_stock("eligible", "E01", 10, 4, "depot", rear.PLAYER)
	rear.ledger.request_stock("other-use", "eligible", 3, "course", "training commitment", rear.PLAYER)
	rear.ledger.add_stock("foreign", "E01", 20, 4, "depot", "supplier")
	# Empty setup has no supplier: explicitly initialize the real cargo holders.
	rear.ledger.add_carrier("supplier", "rear", "supplier", "supplier")
	rear.ledger.add_stock("cargo", "E01", 30, 4, "supplier", rear.PLAYER)
	rear.ledger.add_stock("personal", "E01", 1, 4, "operator-0", rear.PLAYER)
	rear.ledger.add_weapon("issued-rifle", "E01", 4, "operator-0", rear.PLAYER, "E02", 5)
	rear.ledger.add_place("pile-test", "Recoverable temporary pile", Vector2.ZERO)
	rear.stores["pile-test"] = {"id": "pile-test", "pile": true, "accessible": true, "filter": [], "capacity": 100}
	rear.ledger.add_stock("pile-stock", "E01", 2, 4, "pile-test", rear.PLAYER)
	rear.ledger.add_stock("inaccessible", "E01", 4, 4, "receiving", rear.PLAYER)
	rear.ledger.add_stock("filtered", "E01", 5, 4, "munitions_output", rear.PLAYER)
	rear.set_store("receiving", false)
	rear.set_store("munitions_output", true, -1, ["M01"])
	_coverage(rear, 7, 0)
	var before: Dictionary = rear.ledger.snapshot()
	var detached: Dictionary = rear.production.stock_coverage()
	detached.stocks.clear()
	detached.available = 999
	_coverage(rear, 7, 0)
	assert_dict(rear.ledger.snapshot()).is_equal(before)
	rear.set_store("receiving", true)
	_coverage(rear, 11, 0)
	assert_int(rear.ledger.inspect_entity("pile-stock").quantity).is_equal(2)
	assert_int(rear.ledger.inspect_entity("cargo").quantity).is_equal(30)


func _haul_rear() -> RefCounted:
	var rear := _rear()
	rear.ledger.add_stock("rifles", "E01", 3, 4, "depot", rear.PLAYER)
	rear.add_person("hauler", false, "None", "duty-depot")
	rear.request_haul("depot", "receiving", "E01", 2)
	return rear


func test_actual_internal_reservation_pickup_deposit_conserves_coverage_once() -> void:
	var rear := _haul_rear()
	rear.ledger.add_stock("unused-metal", "M01", 2, 1, "workshop_input", rear.PLAYER)
	rear.ledger.add_stock("unused-components", "M02", 1, 1, "workshop_input", rear.PLAYER)
	rear.production.set_stock_target(3)
	_coverage(rear, 3, 0) # Unselected demand alone forecasts nothing.
	rear.set_target("hauling", 1)
	_coverage(rear, 1, 2)
	assert_int(rear.ledger.inspect_entity("rifles").quantity).is_equal(3)
	assert_int(rear.ledger.inspect_entity("rifles").reserved).is_equal(2)
	var actor: Dictionary = rear.actors.hauler
	assert_str(actor.phase).is_equal("Pickup")
	var claim: String = actor.load.claim
	assert_int(rear.ledger.inspect_claim(claim).reserved).is_equal(2)
	rear.advance_time(2)
	assert_str(actor.phase).is_equal("Carry")
	assert_int(rear.ledger.inspect_claim(claim).fulfilled).is_equal(2)
	assert_str(rear.ledger.inspect_entity(actor.load.carried).holder_id).is_equal("hauler")
	_coverage(rear, 1, 2)
	assert_int(rear.production.stock_coverage().internal_carried).is_equal(2)
	rear.advance_time(300)
	_coverage(rear, 3, 0)
	assert_dict(rear.production.batch).is_empty()
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_int(rear.ledger.available_stock_at("receiving", "E01")).is_equal(2)
	assert_int(rear.jobs[0].delivered).is_equal(2)
	var deposited: Dictionary = rear.ledger.snapshot()
	rear.advance_time(0)
	rear.advance_time(0)
	assert_dict(rear.ledger.snapshot()).is_equal(deposited)
	_coverage(rear, 3, 0)


func test_invalid_unpicked_claim_and_ineligible_source_remove_only_their_coverage() -> void:
	var rear := _haul_rear()
	rear.set_target("hauling", 1)
	_coverage(rear, 1, 2)
	var job: String = rear.jobs[0].id
	rear.cancel_job(job)
	rear.cancel_job(job)
	_coverage(rear, 3, 0)
	assert_int(rear.ledger.total_stock("E01")).is_equal(3)
	rear = _haul_rear()
	rear.set_target("hauling", 1)
	rear.set_store("receiving", false)
	_coverage(rear, 3, 0)
	assert_int(rear.ledger.inspect_entity("rifles").reserved).is_zero()
	rear = _haul_rear()
	rear.set_target("hauling", 1)
	rear.set_store("depot", false)
	_coverage(rear, 0, 0)
	assert_int(rear.ledger.inspect_entity("rifles").quantity).is_equal(3)
	rear.advance_time(10)
	assert_int(rear.ledger.inspect_entity("rifles").reserved).is_zero()
	rear.set_store("depot", true)
	assert_int(rear.production.stock_coverage().projected).is_equal(3)
	assert_int(rear.ledger.total_stock("E01")).is_equal(3)
	assert_array(rear.audit()).is_empty()


func test_target_mode_fractional_shared_time_matches_coarse_multiple_batches() -> void:
	var coarse := _rear(3, 8, 4)
	var split := _rear(3, 8, 4)
	coarse.advance_time(60)
	for interval in [0.125, 2.375, 7.5, 9.999, 0.001, 39.999, 0.001]: split.advance_time(interval)
	for rear in [coarse, split]:
		_coverage(rear, 3, 0)
		assert_int(rear.production.history.size()).is_equal(3)
		assert_dict(rear.production.batch).is_empty()
		assert_dict(rear._output_promises).is_empty()
		assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 6, "M02": 3})
	for index in 3:
		assert_float(split.production.history[index].completed_at).is_equal_approx(coarse.production.history[index].completed_at, Rear.EPS)


func test_invalid_destination_replaces_coverage_with_one_valid_current_reroute() -> void:
	var rear := _haul_rear()
	rear.set_target("hauling", 1)
	rear.advance_time(2)
	var carried_id: String = rear.actors.hauler.load.carried
	_coverage(rear, 1, 2)
	rear.set_store("receiving", false)
	var current: Dictionary = rear.production.stock_coverage()
	assert_int(current.relocations.size()).is_equal(1)
	assert_str(current.relocations[0].destination).is_not_equal("receiving")
	assert_str(current.relocations[0].carried_stock).is_equal(carried_id)
	_coverage(rear, 1, 2)
	rear.advance_time(300)
	_coverage(rear, 3, 0)
	assert_int(rear.ledger.total_stock("E01")).is_equal(3)
	assert_int(rear.jobs[0].delivered).is_zero() # Safe deposit elsewhere is not original demand fulfilment.


func test_pile_and_cancelled_carry_exclude_forecast_until_real_eligible_deposit() -> void:
	var rear := _haul_rear()
	rear.set_target("hauling", 1)
	rear.advance_time(2)
	var job: String = rear.jobs[0].id
	rear.cancel_job(job)
	rear.cancel_job(job)
	_coverage(rear, 1, 0)
	assert_int(rear.ledger.total_stock("E01")).is_equal(3)
	rear.advance_time(300)
	_coverage(rear, 3, 0)
	assert_int(rear.jobs[0].delivered).is_zero()
	# A separate live fixture has nowhere legal to deposit: keep an actual pile.
	rear = _haul_rear()
	rear.set_target("hauling", 1)
	rear.advance_time(2)
	for store in rear.stores.keys(): rear.set_store(store, false)
	assert_bool(rear.stores[rear.actors.hauler.load.destination].pile).is_true()
	_coverage(rear, 0, 0)
	rear.advance_time(300)
	assert_int(rear.ledger.total_stock("E01")).is_equal(3)
	_coverage(rear, 0, 0)
	assert_int(rear.jobs[0].recovery_sources.size()).is_equal(1)
	var pile: String = rear.jobs[0].recovery_sources[0]
	assert_int(rear.ledger.available_stock_at(pile, "E01")).is_equal(2)
	rear.set_store("receiving", true)
	# Recovery from a pile is neither usable rear stock nor an eligible source forecast.
	_coverage(rear, 0, 0)
	rear.advance_time(300)
	_coverage(rear, 2, 0)
	assert_int(rear.ledger.available_stock_at("receiving", "E01")).is_equal(2)
	assert_int(rear.ledger.available_stock_at(pile, "E01")).is_zero()
	rear.set_store("depot", true)
	_coverage(rear, 3, 0)


func test_individual_weapon_counts_only_when_functional_unloaded_unissued_and_stored() -> void:
	var rear := _rear()
	rear.ledger.add_weapon("empty-rifle", "E01", 4, "workshop_output", rear.PLAYER, "E02", 5)
	rear.ledger.add_stock("rounds", "E02", 2, 0.015, "workshop_output", rear.PLAYER)
	rear.ledger.add_weapon("broken-rifle", "E01", 4, "depot", rear.PLAYER, "E02", 5)
	# Declared initial damaged entity; no new repair/damage gameplay API.
	rear.ledger._entities["broken-rifle"].health = 0
	rear.ledger.add_weapon("foreign-rifle", "E01", 4, "depot", "supplier", "E02", 5)
	rear.ledger.add_carrier("owned-hull", "rear", rear.PLAYER, rear.PLAYER)
	rear.ledger.add_weapon("carrier-rifle", "E01", 4, "owned-hull", rear.PLAYER, "E02", 5)
	_coverage(rear, 1, 0)
	assert_int(rear.production.stock_coverage().stocks.size()).is_equal(1)
	assert_str(rear.production.stock_coverage().stocks[0].id).is_equal("empty-rifle")
	assert_bool(rear.ledger.load_rounds("empty-rifle", "rounds", 2).ok).is_true()
	_coverage(rear, 0, 0)
	assert_bool(rear.ledger.unload_rounds("empty-rifle").ok).is_true()
	_coverage(rear, 1, 0)
	assert_bool(rear.ledger.transfer_weapon("empty-rifle", "operator-0").ok).is_true()
	_coverage(rear, 0, 0)
	assert_bool(rear.ledger.transfer_weapon("empty-rifle", "workshop_output").ok).is_true()
	_coverage(rear, 1, 0)
	assert_int(rear.ledger.total_stock("E01")).is_equal(4)
	assert_int(rear.ledger.total_stock("E02")).is_equal(2)
