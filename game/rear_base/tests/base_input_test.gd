extends GdUnitTestSuite
## Real engine pointer/keyboard commands; elapsed time is advanced through the same public tick.
func test_normal_entry_purchases_receives_hauls_produces_and_retains_base_with_small_window_controls() -> void:
	var window := get_tree().root
	var previous := {"size": window.size, "content": window.content_scale_size}
	window.size = Vector2i(1280, 720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	assert_str(demo.get_script().resource_path).is_equal("res://game/rear_base/base_demo.gd")
	var base: RefCounted = demo.get("simulation")
	assert_int(base.speed).is_zero()
	for code in {"M01": 35, "M02": 1, "M03": 11, "M04": 70}:
		await _number(runner, demo.get("cart")[code], {"M01": 35, "M02": 1, "M03": 11, "M04": 70}[code])
	await _press(runner, main, "Buy resources")
	await _press(runner, main, "Buy 8 people (140)")
	assert_int(base.receiving.freight_admitted()).is_equal(1)
	assert_int(base.receiving.incoming_people()).is_equal(8)
	assert_float(base.receiving.snapshot().money).is_equal(2185.0)
	await _press(runner, main, "1x")
	base.tick(100)
	await _press(runner, main, "Pause")
	assert_int(base.receiving.receiving_kg()).is_zero()
	assert_str(base.receiving.snapshot().orders[0].blocked_reason).contains("Missing actual")
	await _capture(runner, main, demo, "arrival_without_unloaders")
	await _tab(runner, demo, 1)
	for duty in {"receiving": 2, "hauling": 4, "workshop": 2, "munitions": 2, "materials": 2}:
		await _number(runner, demo.get("targets")[duty], {"receiving": 2, "hauling": 4, "workshop": 2, "munitions": 2, "materials": 2}[duty])
	await _tab(runner, demo, 2)
	var stores: Array = base.rear.stores.keys()
	for code in {"M01": 35, "M02": 1, "M03": 11, "M04": 70}:
		await _haul(runner, main, demo, stores.find("receiving"), stores.find("depot"), ["M01", "M02", "M03", "M04"].find(code), {"M01": 35, "M02": 1, "M03": 11, "M04": 70}[code])
	for row in [["workshop_input", 0, 2], ["workshop_input", 1, 1], ["munitions_input", 0, 3], ["munitions_input", 2, 11], ["materials_input", 0, 30], ["materials_input", 3, 70]]:
		await _haul(runner, main, demo, stores.find("depot"), stores.find(row[0]), row[1], row[2])
	assert_int(base.rear.jobs.size()).is_equal(10)
	await _tab(runner, demo, 3)
	for row in [[0, 1], [1, 100], [2, 100]]:
		await _choose(runner, demo.get("facility"), row[0])
		await _number(runner, demo.get("stock_target"), row[1])
		await _press(runner, main, "Apply production order")
	await _press(runner, main, "2x")
	base.tick(550)
	await _press(runner, main, "Pause")
	assert_int(base.rear.ledger.total_stock("E01")).is_equal(1)
	assert_int(base.rear.ledger.total_stock("E02")).is_equal(100)
	assert_int(base.rear.ledger.total_stock("M11")).is_equal(100)
	assert_int(base.rear.actors.size()).is_equal(20)
	await _choose(runner, demo.get("facility"), 1)
	await _choose(runner, demo.get("recipe"), 1)
	await _press(runner, main, "Select F05 recipe")
	await _number(runner, demo.get("stock_target"), 1)
	await _press(runner, main, "Apply production order")
	await _press(runner, main, "1x")
	base.tick(100)
	await _press(runner, main, "Pause")
	assert_int(base.rear.ledger.total_stock("M06")).is_equal(1)
	assert_array(base.audit()).is_empty()
	await _capture(runner, main, demo, "purchased_goods_four_physical_outputs")
	var before: Dictionary = base.rear.ledger.snapshot()
	var time: float = base.rear.time
	await _press(runner, main, "G01 Identity")
	await _press(runner, main, "Rear base")
	assert_bool(main.get("_host").get_child(0) == demo).is_true()
	assert_dict(base.rear.ledger.snapshot()).is_equal(before)
	assert_float(base.rear.time).is_equal(time)
	# Building selection uses actual map coordinates, then persistent inspection.
	var map: Control = demo.get("base_map")
	await _click(runner, map.global_position + map.map_point(Vector2(125, 25)))
	assert_str(demo.get("_selected_id")).is_equal("workshop")
	assert_str((demo.get("inspection") as Label).text).contains("E01 1")
	var zoom: float = map.zoom
	runner.set_mouse_position(map.get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP)
	await runner.await_input_processed()
	assert_float(map.zoom).is_greater(zoom)
	await _press(runner, main, "Fit base")
	assert_float(map.zoom).is_equal(1.0)
	window.size = Vector2i(960, 640)
	window.content_scale_size = window.size
	await runner.simulate_frames(3)
	await _tab(runner, demo, 1)
	var scroll: ScrollContainer = demo.get("tabs").get_child(1)
	runner.set_mouse_position(scroll.get_global_rect().get_center())
	await runner.await_input_processed()
	for i in 15:
		runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
		await runner.await_input_processed()
	assert_int(scroll.scroll_vertical).is_greater(0)
	await _capture(runner, main, demo, "small_window_staff_inspection")
	await _tab(runner, demo, 4)
	await _capture(runner, main, demo, "small_window_physical_stock")
	window.size = previous.size
	window.content_scale_size = previous.content

func _haul(runner: GdUnitSceneRunner, main: Control, demo: Control, from: int, to: int, type: int, count: int) -> void:
	await _choose(runner, demo.get("source"), from)
	await _choose(runner, demo.get("destination"), to)
	await _choose(runner, demo.get("goods_type"), type)
	await _number(runner, demo.get("haul_count"), count)
	await _press(runner, main, "Order haul")

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
	await runner.simulate_key_pressed(KEY_HOME)
	for i in index: await runner.simulate_key_pressed(KEY_DOWN)
	await runner.simulate_key_pressed(KEY_ENTER)
	await runner.await_input_processed()
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
	await _click(runner, matches[0].get_global_rect().get_center())

func _click(runner: GdUnitSceneRunner, point: Vector2) -> void:
	runner.set_mouse_position(point)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()

func _capture(runner: GdUnitSceneRunner, main: Control, demo: Control, name: String) -> void:
	demo.call("_refresh")
	await runner.simulate_frames(3)
	_bounds(main)
	await RenderingServer.frame_post_draw
	var rendered: Image = main.get_viewport().get_texture().get_image()
	var output := "res://.artifacts/connected-rear"
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
