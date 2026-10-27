extends GdUnitTestSuite
const Base = preload("res://game/rear_base/base_simulation.gd")

func _orders(base: RefCounted) -> void:
	assert_bool(base.receiving.buy_resources({"M01": 35, "M02": 1, "M03": 11, "M04": 70}).ok).is_true()
	assert_bool(base.receiving.buy_people().ok).is_true()
	base.rear.production.set_stock_target(1)
	base.rear.munitions_production.set_stock_target(100)
	base.rear.materials_production.set_stock_target(100)

func _staff(base: RefCounted) -> void:
	for duty in {"receiving": 2, "hauling": 4, "workshop": 2, "munitions": 2, "materials": 2}:
		assert_bool(base.rear.set_target(duty, {"receiving": 2, "hauling": 4, "workshop": 2, "munitions": 2, "materials": 2}[duty]).ok).is_true()

func _hauls(base: RefCounted) -> void:
	for code in {"M01": 35, "M02": 1, "M03": 11, "M04": 70}:
		base.rear.request_haul("receiving", "depot", code, {"M01": 35, "M02": 1, "M03": 11, "M04": 70}[code])
	for row in [["workshop_input", "M01", 2], ["workshop_input", "M02", 1], ["munitions_input", "M01", 3], ["munitions_input", "M03", 11], ["materials_input", "M01", 30], ["materials_input", "M04", 70]]:
		base.rear.request_haul("depot", row[0], row[1], row[2])

func test_declared_start_shared_identity_prices_and_pause_rate() -> void:
	var base := Base.new()
	assert_int(base.rear.actors.size()).is_equal(12)
	assert_float(base.receiving.snapshot().money).is_equal(2500.0)
	assert_dict(base.rear.ledger.snapshot().created).is_empty()
	assert_bool(base.receiving.ledger == base.rear.ledger).is_true()
	base.tick(10)
	assert_float(base.rear.time).is_zero()
	base.set_speed(1)
	base.tick(10)
	base.set_speed(2)
	base.tick(10)
	base.set_speed(0)
	base.tick(50)
	assert_float(base.rear.time).is_equal(30.0)
	assert_float(base.receiving.snapshot().money).is_equal(2680.0)
	assert_array(base.audit()).is_empty()

func test_purchase_real_arrival_zero_unloader_blocks_then_all_four_outputs_and_eight_same_people() -> void:
	var base := Base.new()
	_orders(base)
	assert_float(base.receiving.snapshot().money).is_equal(2185.0)
	_hauls(base)
	base.rear.advance_time(100)
	assert_int(base.receiving.receiving_kg()).is_zero()
	assert_dict(base.rear.ledger.snapshot().consumed).is_empty()
	assert_str(base.receiving.snapshot().orders[0].blocked_reason).contains("Missing actual")
	var passengers: Array = base.receiving._orders[1].passenger_ids.duplicate()
	assert_int(passengers.size()).is_equal(8)
	_staff(base)
	base.rear.advance_time(1100)
	assert_int(base.rear.production.snapshot().physical_output).is_equal(1)
	assert_int(base.rear.munitions_production.snapshot().physical_output).is_equal(100)
	assert_int(base.rear.materials_production.snapshot().physical_output).is_equal(100)
	base.rear.munitions_production.request_recipe("R27")
	base.rear.munitions_production.set_mode("Stock target")
	base.rear.munitions_production.set_stock_target(1)
	base.rear.advance_time(100)
	assert_int(base.rear.ledger.total_stock("M06")).is_equal(1)
	assert_int(base.rear.actors.size()).is_equal(20)
	assert_int(base.receiving.rear_population()).is_equal(20)
	for id in passengers:
		assert_bool(base.rear.actors.has(id)).is_true()
		assert_str(base.rear.ledger.inspect_entity(id).owner).is_equal("army-blue")
	for order in base.receiving._orders:
		assert_bool(base.rear.actors.has(order.id + "-driver")).is_false()
	assert_dict(base.rear.ledger.snapshot().consumed).is_equal({"M01": 35, "M02": 1, "M03": 11, "M04": 70})
	assert_array(base.audit()).is_empty()

func test_incoming_and_personally_carried_material_never_become_local_inputs() -> void:
	var base := Base.new()
	_orders(base)
	base.rear.set_target("workshop", 2)
	base.rear.advance_time(65)
	assert_dict(base.rear.production.batch).is_empty()
	assert_dict(base.rear.ledger.snapshot().consumed).is_empty()
	base.rear.set_target("receiving", 1)
	for step in 200:
		base.rear.advance_time(0.5)
		if not base.receiving._workers.is_empty():
			var person: Dictionary = base.rear.ledger.inspect_entity(base.receiving._workers.keys()[0])
			if not person.carrying_stock_id.is_empty(): break
	assert_int(base.receiving.reserved_storage_kg()).is_greater(0)
	assert_dict(base.rear.production.batch).is_empty()
	assert_dict(base.rear.ledger.snapshot().consumed).is_empty()
	assert_array(base.audit()).is_empty()

func test_unloader_carry_handoff_retains_exclusive_old_duty_until_safe_deposit() -> void:
	var base := Base.new()
	base.receiving.buy_resources({"M01": 25})
	base.rear.set_target("receiving", 1)
	base.rear.advance_time(64)
	var id := ""
	for step in 200:
		base.rear.advance_time(0.25)
		for worker in base.receiving._workers:
			if not base.rear.ledger.inspect_entity(worker).carrying_stock_id.is_empty(): id = worker
		if not id.is_empty(): break
	assert_str(id).is_not_empty()
	assert_bool(base.rear.set_target("receiving", 0).ok).is_true()
	var p: Dictionary = base.rear.ledger.inspect_entity(id)
	assert_str(p.duty_id).is_equal("receiving")
	assert_str(p.pending_assignment).is_equal("Available")
	assert_array(base.rear.production.operators()).not_contains(id)
	base.rear.advance_time(100)
	base.rear.set_target("workshop", 1)
	p = base.rear.ledger.inspect_entity(id)
	assert_str(p.duty_id).is_equal("workshop")
	assert_str(p.carrying_stock_id).is_empty()
	assert_int(base.rear.ledger.available_stock_at("receiving", "M01")).is_equal(25)
	assert_array(base.audit()).is_empty()

func test_receiving_space_and_output_access_blocks_are_actionable_and_recoverable() -> void:
	var base := Base.new()
	_orders(base)
	_staff(base)
	_hauls(base)
	base.rear.set_store("receiving", false)
	base.rear.set_store("workshop_output", false)
	base.rear.advance_time(200)
	assert_int(base.receiving.receiving_kg()).is_zero()
	assert_str(base.receiving.snapshot().orders[0].blocked_reason).contains("storage full")
	base.rear.set_store("receiving", true)
	base.rear.advance_time(1000)
	assert_int(base.rear.ledger.total_stock("E01")).is_zero()
	assert_int(base.rear.ledger.available_stock_at("workshop_input", "M01")).is_equal(2)
	base.rear.set_store("workshop_output", true)
	base.rear.advance_time(100)
	assert_int(base.rear.ledger.total_stock("E01")).is_equal(1)
	assert_array(base.audit()).is_empty()

func test_shared_clock_partition_and_access_boundary_preserved() -> void:
	var coarse := Base.new()
	var fine := Base.new()
	for base in [coarse, fine]:
		_orders(base)
		_staff(base)
		_hauls(base)
		assert_bool(base.rear.munitions_production.request_recipe("R32").ok).is_false()
		assert_bool(base.rear.munitions_production.request_recipe("R33").ok).is_false()
	coarse.rear.advance_time(600)
	for i in 120: fine.rear.advance_time(5)
	assert_dict(coarse.rear.ledger.snapshot().consumed).is_equal(fine.rear.ledger.snapshot().consumed)
	for type in ["M01", "M02", "M03", "M04", "E01", "E02", "M11"]:
		assert_int(coarse.rear.ledger.total_stock(type)).is_equal(fine.rear.ledger.total_stock(type))
	assert_float(coarse.receiving.snapshot().money).is_equal(fine.receiving.snapshot().money)
	assert_array(coarse.audit()).is_empty()
	assert_array(fine.audit()).is_empty()

func test_receiving_inbound_promises_bound_two_unloaders_and_refuse_unsafe_store_edits() -> void:
	var base := Base.new()
	base.rear.set_store("receiving", true, 25)
	base.receiving.buy_resources({"M01": 50})
	base.rear.set_target("receiving", 2)
	base.rear.advance_time(64)
	assert_int(base.receiving.reserved_storage_kg()).is_equal(25)
	var before: Dictionary = base.rear.stores.receiving.duplicate(true)
	assert_bool(base.rear.set_store("receiving", false).ok).is_false()
	assert_bool(base.rear.set_store("receiving", true, 24).ok).is_false()
	assert_bool(base.rear.set_store("receiving", true, -1, ["M02"]).ok).is_false()
	assert_dict(base.rear.stores.receiving).is_equal(before)
	base.rear.advance_time(100)
	assert_int(base.receiving.receiving_kg()).is_equal(25)
	assert_int(base.receiving.resource_counts("M01").onboard).is_equal(25)
	base.rear.request_haul("receiving", "depot", "M01", 50)
	base.rear.set_target("hauling", 1)
	base.rear.advance_time(300)
	assert_int(base.rear.ledger.available_stock_at("depot", "M01")).is_equal(50)
	assert_int(base.receiving.reserved_storage_kg()).is_zero()
	assert_array(base.audit()).is_empty()

func test_finished_unloader_release_rebalances_outstanding_staff_targets() -> void:
	var base := Base.new()
	base.receiving.buy_resources({"M01": 100})
	for duty in ["receiving", "workshop", "munitions"]: base.rear.set_target(duty, 4)
	base.rear.advance_time(64)
	var carried: int = 0
	for step in 200:
		base.rear.advance_time(0.25)
		carried = 0
		for id in base.receiving._workers:
			if not base.rear.ledger.inspect_entity(id).carrying_stock_id.is_empty(): carried += 1
		if carried == 4: break
	assert_int(carried).is_equal(4)
	assert_int(base.receiving.reserved_storage_kg()).is_equal(100)
	base.rear.set_target("receiving", 0)
	base.rear.set_target("hauling", 4)
	base.rear.advance_time(100)
	assert_int(base.rear._assigned("receiving")).is_zero()
	assert_int(base.rear._assigned("workshop")).is_equal(4)
	assert_int(base.rear._assigned("munitions")).is_equal(4)
	assert_int(base.rear._assigned("hauling")).is_equal(4)
	assert_array(base.audit()).is_empty()
