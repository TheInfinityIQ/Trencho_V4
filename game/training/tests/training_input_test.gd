extends GdUnitTestSuite
## Normal launch; no injected qualifications, people, resources or course progress.
func test_normal_recovery_arrival_a11_basic_then_same_person_p08_and_persistent_small_training_panel() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size=Vector2i(1280,720)
	window.content_scale_size=window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	var base: RefCounted = demo.get("simulation")
	assert_int(base.rear.actors.size()).is_equal(12)
	for id in base.rear.actors: assert_bool(base.rear.ledger.inspect_entity(id).basic_training).is_false()
	await _number(runner,demo.get("cart").M01,1)
	await _press(runner,main,"Buy resources")
	await _press(runner,main,"Buy recovery instructor (120)")
	assert_float(base.receiving.snapshot().money).is_equal(2358.0)
	assert_int(base.receiving.incoming_people()).is_equal(1)
	assert_bool((demo.get("recovery_button") as Button).visible).is_false()
	await _elapsed(runner,main,base,150)
	assert_int(base.rear.actors.size()).is_equal(13)
	var instructor_id := "delivery-0002-person-01"
	assert_bool(base.rear.ledger.inspect_entity(instructor_id).basic_training).is_true()
	assert_str(base.rear.ledger.inspect_entity(instructor_id).qualification).is_equal("None")
	assert_bool(base.rear.actors.has("delivery-0002-driver")).is_false()
	assert_int(base.receiving.receiving_kg()).is_zero()
	assert_str(base.receiving.snapshot().orders[0].blocked_reason).contains("Missing actual")
	await _capture(runner,main,demo,"paid_recovery_p01_arrived_zero_unloaders")
	await _tab(runner,demo,5)
	await _number(runner,demo.get("instructor_count"),1)
	await _number(runner,demo.get("training_count"),1)
	await _press(runner,main,"Request course")
	await _elapsed(runner,main,base,200)
	assert_str(base.rear.training.rows[0].state).is_equal("Completed")
	# Train a real second instructor before requesting twelve further students.
	await _tab(runner,demo,0)
	await _press(runner,main,"Buy 8 people (140)")
	await _elapsed(runner,main,base,150)
	assert_int(base.rear.actors.size()).is_equal(21)
	await _tab(runner,demo,5)
	await _number(runner,demo.get("training_count"),12)
	await _press(runner,main,"Request course")
	assert_int(base.rear.training.snapshot().reserved_student_places).is_equal(12)
	await _elapsed(runner,main,base,60)
	assert_int(base.rear.training.snapshot().counts.Active).is_equal(6)
	assert_int(base.rear.training.snapshot().counts.Paused).is_equal(6)
	var paused_work: Array[float] = []
	for index in 12:
		var row: Dictionary=base.rear.training.rows[index+1]
		if index<6: assert_float(row.work).is_greater(0)
		else:
			assert_str(row.state).is_equal("Paused")
			paused_work.append(row.work)
	# Earlier arrivals may work before older students report. Once all are
	# present, the newest six retain that work without earning more under one instructor.
	await _elapsed(runner,main,base,10)
	for index in 6:
		assert_float(base.rear.training.rows[index+7].work).is_equal(paused_work[index])
	await _capture(runner,main,demo,"a11_twelve_students_one_instructor_six_paused")
	await _number(runner,demo.get("instructor_count"),2)
	await _elapsed(runner,main,base,10)
	assert_int(base.rear.training.snapshot().counts.Active).is_equal(12)
	assert_int(base.rear.training.snapshot().counts.Paused).is_zero()
	await _capture(runner,main,demo,"a11_twelve_students_two_real_instructors")
	await _elapsed(runner,main,base,150)
	assert_int(base.rear.training.snapshot().counts.Completed).is_equal(13)
	assert_int(base.rear.training.instructors().size()).is_equal(2)
	await _choose(runner,demo.get("training_course"),7)
	await _number(runner,demo.get("training_count"),1)
	await _press(runner,main,"Request course")
	var student_id: String=base.rear.training.rows[13].person_id
	assert_bool(base.rear.ledger.inspect_entity(student_id).basic_training).is_true()
	await _elapsed(runner,main,base,300)
	assert_str(base.rear.training.rows[13].state).is_equal("Completed")
	assert_str(base.rear.ledger.inspect_entity(student_id).qualification).is_equal("P08")
	assert_str(base.rear.ledger.inspect_entity(student_id).assignment).is_equal("Available")
	assert_int(base.rear.actors.size()).is_equal(21)
	assert_int(base.rear.ledger.rear_fleet_status(base.rear.PLAYER).live).is_equal(1)
	assert_str(base.rear.heavy_production.bay_occupant).is_empty()
	assert_dict(base.rear.ledger.snapshot().created).is_equal({"M01":1})
	assert_array(base.audit()).is_empty()
	var before: Dictionary=base.rear.ledger.snapshot()
	await _tab(runner,demo,4)
	await _tab(runner,demo,5)
	assert_dict(base.rear.ledger.snapshot()).is_equal(before)
	window.size=Vector2i(960,640)
	window.content_scale_size=window.size
	await runner.simulate_frames(3)
	var list: ItemList = demo.get("training_rows")
	await _expose(list)
	await _click(runner,list.global_position+Vector2(20,12))
	for index in 13: await runner.simulate_key_pressed(KEY_DOWN)
	await runner.await_input_processed()
	assert_array(Array(list.get_selected_items())).is_equal([13])
	assert_str(demo.get("_selected_id")).is_equal(base.rear.training.rows[13].id)
	await _expose(demo.get("training_status"))
	await _capture(runner,main,demo,"small_same_p08_completed_training_retained")
	window.size=previous.size
	window.content_scale_size=previous.content

func _elapsed(runner: GdUnitSceneRunner, main: Control, base: RefCounted, seconds: float) -> void:
	await _press(runner,main,"1x")
	base.tick(seconds)
	await _press(runner,main,"Pause")

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
	await _click(runner, matches[0].get_global_rect().get_center())

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
	var output := "res://.artifacts/training-courses"
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
