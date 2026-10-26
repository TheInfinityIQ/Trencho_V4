extends GdUnitTestSuite
## Two independent commitments: cancelling one must not release or erase the other.

const Simulation = preload("res://game/procurement/receiving_simulation.gd")


func test_cancel_one_order_preserves_other_admission_and_physical_cargo() -> void:
	var simulation := Simulation.new()
	var first: Dictionary = simulation.buy_resources({"M01": 100})
	var second: Dictionary = simulation.buy_resources({"M01": 200})
	assert_bool(first.ok).is_true()
	assert_bool(second.ok).is_true()
	assert_int(simulation.freight_admitted()).is_equal(2)
	# 100*2 + 20, then 200*2 + 20; neither purchase grants local stock.
	assert_float(simulation.snapshot().money).is_equal(1860.0)
	assert_int(simulation.receiving_kg()).is_zero()
	assert_bool(simulation.cancel_order(first.ids[0]).ok).is_true()
	assert_float(simulation.snapshot().money).is_equal(2080.0)
	assert_int(simulation.freight_admitted()).is_equal(1)
	var before_repeat: Dictionary = simulation.snapshot()
	assert_bool(simulation.cancel_order(first.ids[0]).ok).is_false()
	assert_dict(simulation.snapshot()).is_equal(before_repeat)
	assert_bool(simulation.advance_time(70.0).ok).is_true()
	var counts: Dictionary = simulation.resource_counts("M01")
	assert_int(counts.purchased).is_equal(200)
	assert_int(counts.onboard).is_equal(200)
	assert_int(counts.carried).is_zero()
	assert_int(counts.unloaded).is_zero()
	assert_int(counts.available).is_zero()
	assert_int(simulation.ledger.total_stock("M01")).is_equal(200)
	assert_int(simulation.freight_admitted()).is_equal(1)
	assert_array(simulation.audit()).is_empty()
