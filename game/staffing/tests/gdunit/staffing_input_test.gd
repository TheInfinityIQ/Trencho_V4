extends GdUnitTestSuite
## Actual engine input over declared fixtures; no OS/native or production claim.


func test_driver_cannot_leave_moving_hull_and_reenters_actual_parking() -> void:
	var previous_window := _render_window(Vector2i(1000, 720))
	var runner := scene_runner("res://game/staffing/rear_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(2)
	await _press(runner, demo, "Reset A06 driver")
	await _tab(runner, demo, "Yard")
	var simulation: RefCounted = demo.get("simulation")
	var yard: RefCounted = simulation.yard
	assert_str(yard.state).is_equal("Entering station")
	assert_str(_person(simulation, "driver-01").qualification).is_equal("P08")
	assert_str(_person(simulation, "driver-01").crew_station).is_empty()
	var before: Dictionary = simulation.snapshot()
	await _press(runner, demo, "Drive to reserved parking")
	assert_dict(simulation.snapshot()).is_equal(before)
	assert_str((demo.get("_feedback") as Label).text).contains("actual seated P08")
	assert_float(yard.fuel).is_equal(40.0)
	await _press(runner, demo, "+2s")
	assert_str(yard.state).is_equal("Entering station")
	assert_str(_person(simulation, "driver-01").crew_station).is_empty()
	await _press(runner, demo, "+1s")
	assert_str(yard.state).is_equal("Ready")
	assert_str(_person(simulation, "driver-01").crew_station).is_equal("Driver")
	assert_str(_person(simulation, "driver-01").holder_id).is_equal("yard-t01")
	await _capture(runner, demo, "driver_seated")
	await _press(runner, demo, "Drive to reserved parking")
	assert_array(yard.reserved).is_equal(["", "yard-t01", "", ""])
	assert_array(yard.occupied).is_equal(["", "", "", ""])
	await _press(runner, demo, "+1s")
	assert_vector(_person(simulation, "yard-t01").position).is_equal(Vector2(180, 128))
	assert_vector(_person(simulation, "driver-01").position).is_equal(Vector2(180, 128))
	assert_float(yard.distance).is_equal(12.0)
	assert_float(yard.burned).is_equal_approx(0.024, 0.000001)
	await _press(runner, demo, "Release yard driver")
	var pending: Dictionary = simulation.snapshot()
	assert_str(_person(simulation, "driver-01").duty_id).is_equal("yard")
	assert_str(_person(simulation, "driver-01").pending_assignment).is_equal("Available")
	assert_str(_person(simulation, "driver-01").crew_station).is_equal("Driver")
	await _press(runner, demo, "Release yard driver")
	assert_dict(simulation.snapshot()).is_equal(pending)
	assert_str((demo.get("_yard") as Label).text).contains("pending exit true")
	await _capture(runner, demo, "driver_moving_pending_yard")
	await _tab(runner, demo, "People")
	assert_str((demo.get("_people_detail") as Label).text).contains("station Driver")
	assert_str((demo.get("_people_detail") as Label).text).contains("pending Available")
	await _capture(runner, demo, "driver_moving_pending_person")
	await _tab(runner, demo, "Yard")
	await _press(runner, demo, "+10s")
	assert_str(yard.state).is_equal("Moving to reserved parking")
	assert_str(_person(simulation, "driver-01").crew_station).is_equal("Driver")
	# One trip takes 130/12 + 6 = 16 5/6 seconds from t3; t20 is parked,
	# but the distinct three-second stationary exit must still be in progress.
	for second in range(6):
		await _press(runner, demo, "+1s")
	assert_float(simulation.time).is_equal(20.0)
	assert_str(yard.state).is_equal("Leaving station")
	assert_vector(_person(simulation, "yard-t01").position).is_equal(Vector2(170, 140))
	assert_str(_person(simulation, "driver-01").crew_station).is_equal("Driver")
	assert_str(_person(simulation, "driver-01").pending_assignment).is_equal("Available")
	assert_array(yard.occupied).is_equal(["", "yard-t01", "", ""])
	assert_array(yard.reserved).is_equal(["", "", "", ""])
	await _capture(runner, demo, "driver_parked_exiting")
	await _press(runner, demo, "+2s")
	assert_str(yard.state).is_equal("Leaving station")
	await _press(runner, demo, "+1s")
	assert_str(yard.state).is_equal("Parked")
	assert_str(yard.driver).is_empty()
	assert_str(_person(simulation, "driver-01").assignment).is_equal("Available")
	assert_str(_person(simulation, "driver-01").pending_assignment).is_equal("None")
	assert_str(_person(simulation, "driver-01").crew_station).is_empty()
	assert_vector(_person(simulation, "driver-01").position).is_equal(Vector2(170, 140))
	var route_metres: float = 130.0 + 15.0 * PI
	assert_float(yard.distance).is_equal_approx(route_metres, 0.00001)
	assert_float(yard.burned).is_equal_approx(route_metres * 0.002, 0.000001)
	assert_float(yard.fuel).is_equal_approx(40.0 - route_metres * 0.002, 0.000001)
	await _capture(runner, demo, "driver_exit_complete")
	var parked: Dictionary = yard.snapshot()
	await _press(runner, demo, "Drive to reserved parking")
	assert_dict(yard.snapshot()).is_equal(parked)
	# Later entry uses the current hull, without restoring initial fuel/parking.
	await _press(runner, demo, "Yard target 1")
	assert_str(yard.state).is_equal("Entering station")
	assert_vector(_person(simulation, "driver-01").position).is_equal(Vector2(170, 140))
	await _press(runner, demo, "+2s")
	assert_str(_person(simulation, "driver-01").crew_station).is_empty()
	await _press(runner, demo, "+1s")
	assert_str(yard.state).is_equal("Ready")
	assert_str(_person(simulation, "driver-01").holder_id).is_equal("yard-t01")
	assert_str((demo.get("_yard") as Label).text).contains("Position (170.0, 140.0)")
	assert_float(yard.fuel).is_equal(parked.fuel)
	assert_float(yard.distance).is_equal(parked.distance)
	assert_array(yard.occupied).is_equal(parked.occupied_parking)
	before = simulation.snapshot()
	await _press(runner, demo, "Drive to reserved parking")
	assert_dict(simulation.snapshot()).is_equal(before)
	assert_str((demo.get("_feedback") as Label).text).contains("parking place is occupied/reserved")
	await _capture(runner, demo, "driver_reentered_same_hull")
	assert_str(_person(simulation, "supplier-driver").owner).is_equal("supplier")
	assert_array(simulation.audit()).is_empty()
	assert_str((demo.get("_audit") as Label).text).contains("PASS")
	_restore_window(previous_window)


func test_a05_actual_labour_and_haul_unlock_local_inputs_without_production() -> void:
	var previous_window := _render_window(Vector2i(1000, 720))
	var runner := scene_runner("res://game/staffing/rear_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(2)
	await _press(runner, demo, "Reset A05 inputs")
	var simulation: RefCounted = demo.get("simulation")
	await _press(runner, demo, "+300s")
	var gate: Dictionary = simulation.workshop_readiness()
	assert_int(gate.operators_present).is_equal(2)
	var actual_operators: Array[String] = []
	for person in simulation.snapshot().people:
		if person.duty_id == "workshop":
			actual_operators.append(person.id)
			assert_str(person.assignment).is_equal("Rear Labour")
			assert_str(person.phase).is_equal("Idle")
			assert_vector(person.position).is_equal(Vector2(125, 18))
	assert_int(actual_operators.size()).is_equal(2)
	assert_str(actual_operators[0]).is_not_equal(actual_operators[1])
	assert_str(gate.status).is_equal("Missing Inputs")
	assert_dict(gate.missing).is_equal({"M01": 2, "M02": 1})
	assert_bool(gate.hauling_shortage).is_true()
	assert_int(simulation.ledger.available_stock_at("depot", "M01")).is_equal(2)
	assert_int(simulation.ledger.available_stock_at("depot", "M02")).is_equal(1)
	assert_int(simulation.ledger.available_stock_at("workshop_input", "M01")).is_zero()
	assert_str((demo.get("_readiness") as Label).text).contains("operators present 2")
	await _capture(runner, demo, "a05_missing_inputs")
	await _tab(runner, demo, "Jobs")
	var jobs := demo.get("_jobs") as Tree
	await _click(runner, jobs.get_global_transform() * jobs.get_item_area_rect(jobs.get_root().get_first_child()).get_center())
	assert_str((demo.get("_detail") as Label).text).contains("deposited 0 / 2")
	await _capture(runner, demo, "a05_selected_job_before")
	await _tab(runner, demo, "Staffing & inputs")
	await _press(runner, demo, "Hauling target 1")
	# Reservation is not stock: report from Personnel to the depot is still required.
	assert_dict(simulation.workshop_readiness().missing).is_equal({"M01": 2, "M02": 1})
	await _press(runner, demo, "+300s")
	gate = simulation.workshop_readiness()
	assert_int(gate.operators_present).is_equal(2)
	assert_dict(gate.missing).is_empty()
	assert_str(gate.status).is_equal("Local inputs ready — G04 production not implemented")
	assert_int(gate.work).is_zero()
	assert_int(gate.consumed).is_zero()
	assert_int(gate.output).is_zero()
	assert_bool(gate.complete_A05_passed).is_false()
	assert_int(simulation.ledger.available_stock_at("workshop_input", "M01")).is_equal(2)
	assert_int(simulation.ledger.available_stock_at("workshop_input", "M02")).is_equal(1)
	assert_int(simulation.ledger.available_stock_at("depot", "M01")).is_zero()
	assert_int(simulation.ledger.available_stock_at("depot", "M02")).is_zero()
	assert_int(simulation.ledger.total_stock("M01")).is_equal(2)
	assert_int(simulation.ledger.total_stock("M02")).is_equal(1)
	assert_str((demo.get("_readiness") as Label).text).contains("Work 0 · consumed 0 · output 0")
	await _capture(runner, demo, "a05_local_inputs_ready")
	await _tab(runner, demo, "Jobs")
	# The same selected job detail must refresh after time/actions without reselection.
	assert_str((demo.get("_detail") as Label).text).contains("Source promised 0 · actually carried 0 · deposited 2 / 2")
	await _capture(runner, demo, "a05_selected_job_after")
	for job in simulation.snapshot().jobs:
		assert_int(job.in_flight).is_zero()
		assert_int(job.delivered).is_equal(job.requested)
	for store in simulation.snapshot().stores:
		assert_float(store.reserved_inbound_kg).is_zero()
	await _tab(runner, demo, "People")
	assert_str((demo.get("_people_detail") as Label).text).contains("worker-01")
	assert_str((demo.get("_people_detail") as Label).text).contains("Actual Rear Labour / workshop")
	assert_str((demo.get("_people_detail") as Label).text).contains("phase Idle")
	_render_window(Vector2i(960, 540))
	await _capture(runner, demo, "a05_selected_person_small")
	var detail_scroll := (demo.get("_people_detail") as Label).get_parent() as ScrollContainer
	var before_scroll := detail_scroll.scroll_vertical
	runner.set_mouse_position(detail_scroll.get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
	await runner.await_input_processed()
	assert_int(detail_scroll.scroll_vertical).is_greater(before_scroll)
	await _capture(runner, demo, "a05_selected_person_small_scrolled")
	assert_array(simulation.audit()).is_empty()
	assert_str((demo.get("_audit") as Label).text).contains("PASS")
	_restore_window(previous_window)


func _render_window(dimensions: Vector2i) -> Dictionary:
	var window := get_tree().root
	var previous := {"size": window.size, "content": window.content_scale_size}
	window.size = dimensions
	window.content_scale_size = dimensions
	return previous


func _restore_window(previous: Dictionary) -> void:
	get_tree().root.size = previous.size
	get_tree().root.content_scale_size = previous.content


func _capture(runner: GdUnitSceneRunner, demo: Control, checkpoint: String) -> void:
	# Same rendered-frame export as accepted D01; actions above remain real input.
	await runner.simulate_frames(3)
	_visible_bounds(demo)
	await RenderingServer.frame_post_draw
	var rendered: Image = demo.get_viewport().get_texture().get_image()
	assert_vector(rendered.get_size()).is_equal(get_tree().root.size)
	var output := "res://.artifacts/g03-rendered"
	assert_int(DirAccess.make_dir_recursive_absolute(output)).is_equal(OK)
	assert_int(rendered.save_png(output + "/" + checkpoint + ".png")).is_equal(OK)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(rendered.get_data())
	var tabs := demo.find_children("*", "TabContainer", true, false)[0] as TabContainer
	var details: Dictionary = {}
	for field in ["_summary", "_feedback", "_readiness", "_yard", "_detail", "_people_detail", "_audit"]:
		var label := demo.get(field) as Label
		details[field] = {"visible": label.is_visible_in_tree(), "text": label.text}
		if label.get_parent() is ScrollContainer:
			details[field].scroll_y_px = (label.get_parent() as ScrollContainer).scroll_vertical
	var simulation: RefCounted = demo.get("simulation")
	var metadata := {"kind": "Godot Linux CI render; Windows native input/readability unverified",
		"revision": OS.get_environment("EVALUATION_HEAD"), "engine": Engine.get_version_info().string,
		"checkpoint": checkpoint, "image": checkpoint + ".png", "pixel_sha256": digest.finish().hex_encode(),
		"viewport_px": [rendered.get_width(), rendered.get_height()], "tab": tabs.get_current_tab_control().name,
		"selected_person": demo.get("_selected_person"), "selected_job": demo.get("_selected_job"),
		"inspection": details, "state": _json_value(simulation.snapshot())}
	var file := FileAccess.open(output + "/" + checkpoint + ".json", FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file != null: file.store_string(JSON.stringify(metadata, "\t") + "\n")


func _json_value(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[str(key)] = _json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(_json_value(item))
		return result
	return value


func _visible_bounds(node: Node, in_scroll: bool = false) -> void:
	if node is Control and node.is_visible_in_tree() and not in_scroll:
		assert_bool(node.get_viewport_rect().grow(1).encloses(node.get_global_rect())).override_failure_message("Rendered control fits viewport: " + str(node.get_path())).is_true()
	for child in node.get_children(): _visible_bounds(child, in_scroll or node is ScrollContainer)


func _person(simulation: RefCounted, id: String) -> Dictionary:
	return simulation.ledger.inspect_entity(id)


func _press(runner: GdUnitSceneRunner, demo: Control, text: String) -> void:
	var matches: Array[Button] = []
	for node in demo.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree():
			matches.append(node)
	assert_int(matches.size()).override_failure_message("Exactly one visible button: " + text).is_equal(1)
	if matches.size() != 1:
		return
	await _click(runner, matches[0].get_global_rect().get_center())


func _tab(runner: GdUnitSceneRunner, demo: Control, title: String) -> void:
	var tabs := demo.find_children("*", "TabContainer", true, false)[0] as TabContainer
	var bar := tabs.get_tab_bar()
	for index in range(bar.tab_count):
		if bar.get_tab_title(index) == title:
			await _click(runner, bar.get_global_transform() * bar.get_tab_rect(index).get_center())
			assert_str(tabs.get_current_tab_control().name).is_equal(title)
			return
	fail("Missing actual tab: " + title)


func _click(runner: GdUnitSceneRunner, position: Vector2) -> void:
	runner.set_mouse_position(position)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
