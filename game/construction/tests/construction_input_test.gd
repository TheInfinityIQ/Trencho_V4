extends GdUnitTestSuite

func test_build_panel_preview_place_and_cancel_through_real_input() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	demo.tabs.current_tab = 8
	await runner.simulate_frames(3)
	await _number(runner,demo.construction_office,2)
	assert_int(demo.simulation.rear.construction.office_desired.construction).is_equal(2)
	var kinds: OptionButton = demo.construction_kind
	for index in kinds.item_count:
		if kinds.get_item_text(index) == "depot": kinds.select(index)
	demo.construction_x.value = 140
	demo.construction_y.value = 10
	await _press(runner,main,"Preview legal site")
	assert_bool(demo.base_map.placement_preview.ok).is_true()
	await _press(runner,main,"Place physical site")
	assert_str(demo.simulation.rear.construction.instances["site-0001"].state).is_equal("Awaiting M11")
	assert_int(demo.construction_rows.item_count).is_greater(0)
	demo.construction_rows.select(demo.construction_rows.item_count-1)
	await _press(runner,main,"Cancel unfinished site")
	assert_str(demo.simulation.rear.construction.instances["site-0001"].state).is_equal("Cancelled")
	assert_array(demo.simulation.audit()).is_empty()

func _number(runner: GdUnitSceneRunner, spin: SpinBox, number: int) -> void:
	var parent: Node = spin.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(spin)
		parent = parent.get_parent()
	await runner.simulate_frames(2)
	runner.set_mouse_position(spin.get_line_edit().get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	runner.simulate_key_press(KEY_CTRL)
	await runner.simulate_key_pressed(KEY_A)
	runner.simulate_key_release(KEY_CTRL)
	for digit in str(number): await runner.simulate_key_pressed(digit.unicode_at(0))
	await runner.simulate_key_pressed(KEY_ENTER)
	await runner.await_input_processed()
	assert_int(int(spin.value)).is_equal(number)

func _press(runner: GdUnitSceneRunner, root: Control, label: String) -> void:
	var matches: Array[Button] = []
	for button in root.find_children("*","Button",true,false):
		if button.text == label and button.is_visible_in_tree(): matches.append(button)
	assert_int(matches.size()).is_equal(1)
	if matches.size() != 1: return
	var parent: Node = matches[0].get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(matches[0])
		parent = parent.get_parent()
	await runner.simulate_frames(2)
	runner.set_mouse_position(matches[0].get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
