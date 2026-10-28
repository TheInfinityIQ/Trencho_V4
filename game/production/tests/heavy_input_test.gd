extends GdUnitTestSuite
## Normal essential session: actual purchases to one transport, no clearance substitute.
func test_purchased_transport_admission_empty_hull_occupied_next_order_and_retained_nonheavy_work() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size=Vector2i(1280,720)
	window.content_scale_size=window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	var demo: Control=main.get("_host").get_child(0)
	var base: RefCounted=demo.get("simulation")
	var heavy: RefCounted=base.rear.heavy_production
	assert_bool(base.expanded_catalogue).is_false()
	assert_int(base.rear.actors.size()).is_equal(12)
	assert_int(heavy.snapshot().fleet.live).is_equal(1)
	await _recipe(runner,main,demo,4,"R25",2)
	assert_dict(heavy.snapshot().order).is_empty()
	await _press(runner,main,"Accept heavy order")
	assert_str(heavy.snapshot().order.state).is_equal("Accepted")
	assert_int(heavy.snapshot().fleet.live).is_equal(1)
	assert_int(heavy.snapshot().fleet.reserved).is_equal(1)
	assert_str((demo.get("heavy_status") as Label).text).contains("F11 place 2")
	assert_dict(base.rear.ledger.snapshot().consumed).is_empty()
	await _expose(demo.get("heavy_status"))
	await _capture(runner,main,demo,"accepted_order_before_materials")
	await _purchase(runner,main,demo,{"M01":122,"M02":81})
	await _staff(runner,demo,{"receiving":1,"hauling":3,"vehicle_works":8})
	await _hauls(runner,main,demo,[["receiving","vehicle_input","M01",120],["receiving","vehicle_input","M02",80]])
	await _elapsed(runner,main,base,1600)
	var output: Dictionary=heavy.snapshot().bay.physical
	assert_str(output.kind).is_equal("CARRIER")
	assert_str(output.design_type).is_equal("T01")
	assert_str(output.holder_id).is_equal("heavy-bay")
	assert_float(output.unit_mass_kg).is_equal(4000.0)
	assert_float(output.fuel).is_zero()
	assert_array(output.crew).is_empty()
	assert_array(output.passengers).is_empty()
	assert_dict(output.ammunition).is_empty()
	assert_int(heavy.snapshot().fleet.live).is_equal(2)
	assert_int(heavy.snapshot().fleet.reserved).is_zero()
	assert_float(heavy.history[0].work).is_equal(800.0)
	assert_str(heavy.snapshot().bay.clearance).contains("Awaiting Qualified Driver")
	assert_str(heavy.snapshot().bay.clearance).contains("Fuel Empty")
	await _tab(runner,demo,3)
	await _expose(demo.get("heavy_status"))
	await _capture(runner,main,demo,"manufactured_empty_transport_occupied_bay")
	await _staff(runner,demo,{"vehicle_works":0,"receiving":0,"hauling":1,"workshop":2})
	await _hauls(runner,main,demo,[["receiving","workshop_input","M01",2],["receiving","workshop_input","M02",1]])
	await _recipe(runner,main,demo,0,"R01",1)
	await _elapsed(runner,main,base,600)
	assert_int(base.rear.ledger.total_stock("E01")).is_equal(1)
	await _recipe(runner,main,demo,4,"R28",1)
	var before: Dictionary=base.rear.ledger.snapshot().consumed
	await _press(runner,main,"Accept heavy order")
	assert_str((demo.get("feedback") as Label).text).contains("bay occupied")
	assert_dict(heavy.snapshot().order).is_empty()
	assert_str(heavy.bay_occupant).is_equal(output.id)
	assert_dict(base.rear.ledger.snapshot().consumed).is_equal(before)
	await _press(runner,main,"Cancel consumed batch / stop")
	assert_str(heavy.bay_occupant).is_equal(output.id)
	assert_int(heavy.snapshot().fleet.live).is_equal(2)
	window.size=Vector2i(960,640)
	window.content_scale_size=window.size
	await runner.simulate_frames(3)
	await _expose(demo.get("heavy_status"))
	await _capture(runner,main,demo,"small_occupied_next_refusal_and_retained_rifle")
	assert_array(base.audit()).is_empty()
	window.size=previous.size
	window.content_scale_size=previous.content

func _purchase(runner: GdUnitSceneRunner, main: Control, demo: Control, cart: Dictionary) -> void:
	await _tab(runner, demo, 0)
	for code in cart: await _number(runner, demo.get("cart")[code], cart[code])
	await _press(runner, main, "Buy resources")
	assert_int(demo.get("simulation").receiving.freight_admitted()).is_equal(1)

func _staff(runner: GdUnitSceneRunner, demo: Control, targets: Dictionary) -> void:
	await _tab(runner, demo, 1)
	for duty in targets: await _number(runner, demo.get("targets")[duty], targets[duty])

func _hauls(runner: GdUnitSceneRunner, main: Control, demo: Control, rows: Array) -> void:
	await _tab(runner, demo, 2)
	var stores: Array = demo.get("simulation").rear.stores.keys()
	var goods: OptionButton = demo.get("goods_type")
	for row in rows:
		await _choose(runner, demo.get("source"), stores.find(row[0]))
		await _choose(runner, demo.get("destination"), stores.find(row[1]))
		var index := -1
		for item in goods.item_count:
			if goods.get_item_text(item) == row[2]: index = item
		assert_int(index).is_greater_equal(0)
		await _choose(runner, goods, index)
		await _number(runner, demo.get("haul_count"), row[3])
		await _press(runner, main, "Order haul")

func _recipe(runner: GdUnitSceneRunner, main: Control, demo: Control, facility: int, id: String, target: int) -> void:
	await _tab(runner, demo, 3)
	await _choose(runner, demo.get("facility"), facility)
	var option: OptionButton = demo.get("recipe")
	var index := -1
	for item in option.item_count:
		if option.get_item_metadata(item) == id: index = item
	assert_int(index).is_greater_equal(0)
	await _choose(runner, option, index)
	await _press(runner, main, "Select recipe")
	if demo.get("confirmation").visible: return
	await _choose(runner, demo.get("mode"), 0)
	await _number(runner, demo.get("stock_target"), target)
	await _press(runner, main, "Apply production order")

func _elapsed(runner: GdUnitSceneRunner, main: Control, base: RefCounted, seconds: float) -> void:
	await _press(runner, main, "1x")
	base.tick(seconds)
	await _press(runner, main, "Pause")

func _expose(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await get_tree().process_frame

func _number(runner: GdUnitSceneRunner, spin: SpinBox, number: int) -> void:
	await _expose(spin)
	await _click(runner, spin.get_line_edit().get_global_rect().get_center())
	runner.simulate_key_press(KEY_CTRL)
	await runner.simulate_key_pressed(KEY_A)
	runner.simulate_key_release(KEY_CTRL)
	for digit in str(number): await runner.simulate_key_pressed(digit.unicode_at(0))
	await runner.simulate_key_pressed(KEY_ENTER)
	await runner.await_input_processed()
	assert_int(int(spin.value)).is_equal(number)

func _choose(runner: GdUnitSceneRunner, option: OptionButton, index: int) -> void:
	await _expose(option)
	await _click(runner, option.get_global_rect().get_center())
	await runner.simulate_frames(2)
	var popup := option.get_popup()
	assert_bool(popup.visible).is_true()
	assert_bool(popup.is_embedded()).is_true()
	# Target the real embedded menu row. All these menus have uniform rows,
	# no separators; panel margins are smaller than half a row.
	var point := Vector2(popup.position) + Vector2(popup.size.x * 0.5, (index + 0.5) * popup.size.y / popup.item_count)
	await _click(runner, point)

	assert_int(option.selected).is_equal(index)

func _tab(runner: GdUnitSceneRunner, demo: Control, index: int) -> void:
	var bar: TabBar = demo.get("tabs").get_tab_bar()
	await _click(runner, bar.global_position + bar.get_tab_rect(index).get_center())
	await runner.simulate_frames(2)
	assert_int((demo.get("tabs") as TabContainer).current_tab).is_equal(index)

func _press(runner: GdUnitSceneRunner, root: Control, text: String) -> void:
	var matches: Array[Button] = []
	for button in root.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree(): matches.append(button)
	assert_int(matches.size()).is_equal(1)
	if matches.size() != 1: return
	await _expose(matches[0])
	var button := matches[0]
	var point := button.get_global_rect().get_center()
	if button.get_window() != get_tree().root and button.get_window().is_embedded(): point += Vector2(button.get_window().position)
	await _click(runner, point)

func _click(runner: GdUnitSceneRunner, point: Vector2) -> void:
	runner.set_mouse_position(point)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()

func _capture(runner: GdUnitSceneRunner, main: Control, demo: Control, name: String) -> void:
	demo.call("_refresh")
	runner.set_mouse_position(main.size - Vector2(8, 8))
	await runner.await_input_processed()
	await runner.simulate_frames(3)
	_bounds(main)
	await RenderingServer.frame_post_draw
	var rendered: Image = main.get_viewport().get_texture().get_image()
	var output := "res://.artifacts/heavy-production"
	assert_int(DirAccess.make_dir_recursive_absolute(output)).is_equal(OK)
	assert_int(rendered.save_png(output + "/" + name + ".png")).is_equal(OK)
	var file := FileAccess.open(output + "/" + name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"head": OS.get_environment("EVALUATION_HEAD"), "engine": Engine.get_version_info().string, "state": _json(demo.get("simulation").snapshot())}, "\t"))

func _json(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _json(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_json(item))
		return result
	return value

func _bounds(node: Node, scrolling: bool = false) -> void:
	if node is Control and node.is_visible_in_tree() and not scrolling:
		assert_bool(node.get_viewport_rect().grow(1).encloses(node.get_global_rect())).override_failure_message("Connected rear visible control fits: " + str(node.get_path())).is_true()
	for child in node.get_children(): _bounds(child, scrolling or node is ScrollContainer)
