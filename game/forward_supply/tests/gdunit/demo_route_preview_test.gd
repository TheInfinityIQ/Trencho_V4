extends GdUnitTestSuite
## Ordinary authored session and production UI/service; no replacement world or stock.


func test_ordinary_supply_preview_becomes_available_without_dispatching() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(2)
	var supply := _button(main,"Supply")
	assert_object(supply).is_not_null()
	if supply == null: return
	supply.pressed.emit()
	await runner.simulate_frames(1)
	var base: Control = main.get("_base")
	var session: RefCounted = base.get("simulation")
	var panel: VBoxContainer = base.get("forward_delivery_panel")
	assert_bool(panel.is_visible_in_tree()).is_true()
	assert_int(session.speed).is_zero()
	var freight: OptionButton = panel.get("freight_choice")
	var found_ammunition := false
	for index in freight.item_count:
		if str(freight.get_item_metadata(index)) == "E02":
			freight.select(index)
			freight.item_selected.emit(index)
			found_ammunition = true
			break
	assert_bool(found_ammunition).is_true()
	if not found_ammunition: return
	var preview := _button(panel,"Preview route, load and fuel")
	assert_object(preview).is_not_null()
	if preview == null: return
	var before: Dictionary = session.rear.ledger.snapshot()
	var jobs: Dictionary = session.rear.forward_supply.transport.jobs.duplicate(true)
	var results: Array[Dictionary] = []
	panel.result_reported.connect(func(result: Dictionary) -> void: results.append(result))
	preview.pressed.emit()
	assert_int(results.size()).is_equal(1)
	if results.is_empty(): return
	var result: Dictionary = results.back()
	print("ORDINARY_SUPPLY_PREVIEW ",JSON.stringify(result))
	assert_bool(bool(result.get("ok",false))).is_true()
	assert_bool(bool(result.get("inspection_only",false))).is_true()
	assert_float(float(result.get("distance",0))).is_greater(0.0)
	assert_float(float(result.get("seconds",0))).is_greater(0.0)
	assert_float(float(result.get("required_fuel",0))).is_greater(0.0)
	assert_float(float(result.get("tank_fuel",0))).is_greater_equal(float(result.get("required_fuel",INF)))
	assert_float(float(result.get("gross_kg",0))).is_greater(0.0)
	assert_str((panel.get("route_status") as Label).text).contains("Fuel")
	assert_dict(session.rear.ledger.snapshot()).is_equal(before)
	assert_dict(session.rear.forward_supply.transport.jobs).is_equal(jobs)
	assert_float(session.rear.time).is_equal(0.0)
	assert_int(session.speed).is_zero()


func _button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found := _button(child,title)
		if found != null: return found
	return null
