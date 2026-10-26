extends GdUnitTestSuite
## Engine input and hit testing, distinct from callback signals and OS/native input.


func test_purchase_routes_input_and_disabled_control_cannot_commit() -> void:
	var runner := scene_runner("res://game/procurement/receiving_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(2)
	var purchase := _button(demo, "Purchase quoted goods")
	assert_object(purchase).is_not_null()
	if purchase == null:
		return
	assert_bool(purchase.is_visible_in_tree()).is_true()
	var simulation: RefCounted = demo.get("_simulation")
	var before: Dictionary = simulation.snapshot()
	purchase.disabled = true
	runner.set_mouse_position(purchase.get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	assert_dict(simulation.snapshot()).is_equal(before)
	purchase.disabled = false
	await runner.simulate_frames(1)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	assert_int(simulation.resource_counts("M01").purchased).is_equal(100)
	assert_float(simulation.snapshot().money).is_equal(2280.0)
	assert_int(simulation.freight_admitted()).is_equal(1)
	assert_int(simulation.receiving_kg()).is_zero()
	assert_str((demo.get("_summary") as Label).text).contains("Requisition 2280.00")
	assert_array(simulation.audit()).is_empty()


func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null

