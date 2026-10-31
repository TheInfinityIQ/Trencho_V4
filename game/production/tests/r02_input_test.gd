extends GdUnitTestSuite
## Normal-launch R02 input and actual CI frames; no Windows-native claim.


func test_normal_launch_r02_hauls_starts_retains_work_and_finishes_whole_yield() -> void:
	# Current development acceptance uses one fixed 1280x720 screen.
	var window := get_tree().root
	var previous := {"size": window.size, "content": window.content_scale_size}
	window.size = Vector2i(1280, 720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	await _press(runner, main, "G04 R02 Munitions")
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	var rear: RefCounted = demo.get("simulation")
	var production: RefCounted = demo.get("production")
	assert_str(production.mode).is_equal("Continuous")
	assert_int(rear.ledger.available_stock_at("depot", "M01")).is_equal(1)
	assert_int(rear.ledger.available_stock_at("depot", "M03")).is_equal(1)
	assert_object(rear.production).is_null()
	await _press(runner, main, "Operators 2")
	await _press(runner, main, "+300s")
	assert_int(production.operators().size()).is_equal(2)
	assert_str(production.snapshot().status).is_equal("Missing Inputs")
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_dict(production.batch).is_empty()
	await _capture(runner, main, demo, "r02_missing_local_inputs")
	await _press(runner, main, "Stock target")
	await _spin_target(runner, demo, true)
	assert_int(production.stock_target).is_equal(1)
	await _press(runner, main, "Pause R02")
	await _press(runner, main, "Hauling 1")
	await _press(runner, main, "+300s")
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_int(rear.ledger.available_stock_at("munitions_input", "M01")).is_equal(1)
	assert_int(rear.ledger.available_stock_at("munitions_input", "M03")).is_equal(1)
	await _press(runner, main, "Resume R02")
	assert_float(production.batch.started_at).is_equal(600.0)
	assert_float(production.batch.work).is_zero()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 1, "M03": 1})
	assert_int(production.stock_coverage().planned).is_equal(100)
	assert_float(production.snapshot().output_promise.mass).is_equal(2.0)
	assert_str((demo.get("_target") as Label).text).contains("E02 minimum 1 · Available A=0 + planned C=100 = 100")
	await _capture(runner, main, demo, "r02_local_batch_started")
	await _press(runner, main, "+10s")
	var partial: Dictionary = production.batch.duplicate(true)
	assert_float(partial.work).is_equal(20.0)
	await _spin_target(runner, demo, false)
	await _press(runner, main, "Continuous")
	await _press(runner, main, "Stock target")
	assert_dict(production.batch).is_equal(partial)
	await _press(runner, main, "Try 1 kg")
	assert_float(rear.stores.munitions_output.capacity).is_equal(1000.0)
	assert_str((demo.get("_feedback") as Label).text).contains("active output promise")
	await _press(runner, main, "Reject E02 filter")
	assert_array(rear.stores.munitions_output.filter).is_empty()
	await _press(runner, main, "Block output")
	await _press(runner, main, "+20s")
	assert_dict(production.batch).is_equal(partial)
	assert_int(production.stock_target).is_zero()
	assert_int(production.stock_coverage().planned).is_zero()
	assert_float(production.snapshot().output_promise.mass).is_equal(2.0)
	assert_int(rear.ledger.total_stock("E02")).is_zero()
	await _capture(runner, main, demo, "r02_access_blocked_work_retained")
	await _press(runner, main, "Restore output")
	await _press(runner, main, "+10s")
	await _spin_target(runner, demo, true)
	assert_float(rear.time).is_equal(640.0)
	assert_float(production.history[0].completed_at).is_equal(640.0)
	assert_int(production.snapshot().physical_output).is_equal(100)
	assert_float(rear.ledger.loose_stock_mass_at("munitions_output")).is_equal(2.0)
	assert_int(production.stock_coverage().available).is_equal(100)
	assert_int(production.stock_coverage().planned).is_zero()
	assert_str(production.snapshot().status).is_equal("Target satisfied — no new batch")
	assert_dict(production.batch).is_empty()
	assert_int(production.history.size()).is_equal(1)
	assert_int(rear.ledger.total_stock("E01")).is_zero()
	assert_array(rear.audit()).is_empty()
	await _capture(runner, main, demo, "r02_physical100_target_satisfied")
	window.size = Vector2i(1280, 720)
	window.content_scale_size = window.size
	await runner.simulate_frames(3)
	var scroll := (demo.get("_people") as Label).get_parent() as ScrollContainer
	assert_float(scroll.size.y).is_greater_equal(48)
	runner.set_mouse_position(scroll.get_global_rect().get_center())
	await runner.await_input_processed()
	for notch in 100:
		if scroll.scroll_vertical >= scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page - 1: break
		runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
		await runner.await_input_processed()
		await runner.simulate_frames(4)
	assert_int(scroll.scroll_vertical).is_greater(0)
	assert_float(float(scroll.scroll_vertical)).is_equal_approx(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page, 1.0)
	await _capture(runner, main, demo, "r02_small_inspection_scrolled")
	window.size = previous.size
	window.content_scale_size = previous.content


func _spin_target(runner: GdUnitSceneRunner, demo: Control, increase: bool) -> void:
	var spin := demo.get("_target_count") as SpinBox
	var rect := spin.get_global_rect()
	# Actual built-in stepper arrows; never assign value or emit a signal.
	runner.set_mouse_position(rect.position + Vector2(rect.size.x - 8, rect.size.y * (0.25 if increase else 0.75)))
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	await runner.simulate_frames(3)


func _press(runner: GdUnitSceneRunner, root: Control, title: String) -> void:
	if title.begins_with("G"):
		var hidden := false
		for node in root.find_children("*", "Button", true, false):
			if node.text == title and not node.is_visible_in_tree(): hidden = true
		if hidden: await _press(runner,root,"Diagnostics")
	var matches: Array[Button] = []
	for node in root.find_children("*", "Button", true, false):
		if node.text == title and node.is_visible_in_tree(): matches.append(node)
	assert_int(matches.size()).is_equal(1)
	if matches.size() != 1: return
	runner.set_mouse_position(matches[0].get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()


func _capture(runner: GdUnitSceneRunner, main: Control, demo: Control, checkpoint: String) -> void:
	await runner.simulate_frames(3)
	_bounds(main)
	await RenderingServer.frame_post_draw
	var rendered: Image = main.get_viewport().get_texture().get_image()
	assert_vector(rendered.get_size()).is_equal(get_tree().root.size)
	var output := "res://.artifacts/g04-r02"
	assert_int(DirAccess.make_dir_recursive_absolute(output)).is_equal(OK)
	assert_int(rendered.save_png(output + "/" + checkpoint + ".png")).is_equal(OK)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(rendered.get_data())
	var inspection: Dictionary = {}
	for field in ["_status", "_target", "_work", "_physical", "_people", "_feedback"]:
		inspection[field] = (demo.get(field) as Label).text
	inspection.people_jobs_scroll_y_px = ((demo.get("_people") as Label).get_parent() as ScrollContainer).scroll_vertical
	var metadata := {"kind": "Godot Linux CI render, not Windows native evidence",
		"revision": OS.get_environment("EVALUATION_HEAD"), "engine": Engine.get_version_info().string,
		"image": checkpoint + ".png", "checkpoint": checkpoint,
		"viewport_px": [rendered.get_width(), rendered.get_height()], "pixel_sha256": digest.finish().hex_encode(),
		"inspection": inspection, "rear": _json_value(demo.get("simulation").snapshot()),
		"production": _json_value(demo.get("production").snapshot())}
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


func _bounds(node: Node, in_scroll: bool = false) -> void:
	if node is Control and node.is_visible_in_tree() and not in_scroll:
		assert_bool(node.get_viewport_rect().grow(1).encloses(node.get_global_rect())).override_failure_message("R02 visible control fits: " + str(node.get_path())).is_true()
	for child in node.get_children(): _bounds(child, in_scroll or node is ScrollContainer)
