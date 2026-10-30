extends GdUnitTestSuite
## Genuine engine-input normal-launch flow and rendered CI evidence, not Windows QA.


func test_normal_launch_hauls_local_inputs_and_produces_one_empty_rifle_with_protected_work() -> void:
	var window := get_tree().root
	var previous := {"size": window.size, "content": window.content_scale_size}
	window.size = Vector2i(1280, 720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	await _press(runner, main, "G04 R01 Production")
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	var rear: RefCounted = demo.get("simulation")
	var production: RefCounted = demo.get("production")
	await _press(runner, main, "+300s")
	assert_int(production.operators().size()).is_equal(2)
	assert_str(production.snapshot().status).is_equal("Missing Inputs")
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	await _capture(runner, main, demo, "operators_missing_inputs")
	# Hold facility work while actual hauling delivers: reserve/carry never consumes.
	await _press(runner, main, "Pause R01")
	await _press(runner, main, "Hauling 1")
	await _press(runner, main, "+300s")
	assert_int(rear.ledger.available_stock_at("workshop_input", "M01")).is_equal(2)
	assert_int(rear.ledger.available_stock_at("workshop_input", "M02")).is_equal(1)
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_dict(production.batch).is_empty()
	await _press(runner, main, "Resume R01")
	assert_float(production.batch.started_at).is_equal(600.0)
	assert_float(production.batch.work).is_zero()
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M02": 1})
	assert_float(production.snapshot().output_promise.mass).is_equal(4.0)
	await _capture(runner, main, demo, "local_batch_started")
	await _press(runner, main, "+10s")
	assert_float(production.batch.work).is_equal(20.0)
	await _press(runner, main, "Try 3 kg")
	assert_float(rear.stores.workshop_output.capacity).is_equal(1000.0)
	assert_str((demo.get("_feedback") as Label).text).contains("active output promise")
	await _capture(runner, main, demo, "partial_work_edit_refused")
	await _press(runner, main, "Reject E01 filter")
	assert_array(rear.stores.workshop_output.filter).is_empty()
	await _press(runner, main, "Block output")
	await _press(runner, main, "+20s")
	assert_float(production.batch.work).is_equal(20.0)
	assert_int(rear.ledger.total_stock("E01")).is_zero()
	await _capture(runner, main, demo, "access_paused_work_retained")
	await _press(runner, main, "Restore output")
	await _press(runner, main, "+10s")
	assert_float(rear.time).is_equal(640.0)
	assert_float(production.history[0].completed_at).is_equal(640.0)
	assert_int(production.snapshot().physical_output).is_equal(1)
	assert_int(rear.ledger.total_stock("E02")).is_zero()
	assert_dict(production.snapshot().output_promise).is_empty()
	assert_float(rear.ledger.loose_stock_mass_at("workshop_output")).is_equal(4.0)
	assert_str(production.snapshot().status).is_equal("Missing Inputs")
	await _capture(runner, main, demo, "physical_empty_rifle")
	await _press(runner, main, "Cancel batch")
	await _press(runner, main, "+20s")
	assert_int(rear.ledger.total_stock("E01")).is_equal(1)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M02": 1})
	assert_array(rear.audit()).is_empty()
	window.size = Vector2i(1280, 720)
	window.content_scale_size = window.size
	await runner.simulate_frames(3)
	var scroll := (demo.get("_people") as Label).get_parent() as ScrollContainer
	runner.set_mouse_position(scroll.get_global_rect().get_center())
	await runner.await_input_processed()
	for notch in 100:
		if scroll.scroll_vertical >= scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page - 1: break
		runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
		await runner.await_input_processed()
		await runner.simulate_frames(4)
	assert_int(scroll.scroll_vertical).is_greater(0)
	assert_float(float(scroll.scroll_vertical)).is_equal_approx(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page, 1.0)
	await _capture(runner, main, demo, "finished_stock_after_cancel_small")
	window.size = previous.size
	window.content_scale_size = previous.content


func test_normal_launch_stock_target_keeps_active_work_and_finishes_without_restart() -> void:
	var window := get_tree().root
	var previous := {"size": window.size, "content": window.content_scale_size}
	window.size = Vector2i(1280, 720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	await _press(runner, main, "G04 R01 Production")
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	var rear: RefCounted = demo.get("simulation")
	var production: RefCounted = demo.get("production")
	assert_str(production.mode).is_equal("Continuous")
	await _press(runner, main, "Stock target")
	await _press(runner, main, "+300s")
	assert_str(production.snapshot().status).is_equal("Target satisfied — no new batch")
	assert_int(production.stock_target).is_zero()
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	assert_dict(production.batch).is_empty()
	assert_str((demo.get("_target") as Label).text).contains("Available A=0 + planned C=0 = 0")
	await _capture(runner, main, demo, "target_zero_no_consumption")
	await _spin_target(runner, demo, true)
	assert_int(production.stock_target).is_equal(1)
	assert_str(production.snapshot().status).is_equal("Missing Inputs")
	await _press(runner, main, "Pause R01")
	await _press(runner, main, "Hauling 1")
	await _press(runner, main, "+300s")
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	await _press(runner, main, "Resume R01")
	assert_float(production.batch.started_at).is_equal(600.0)
	assert_int(production.stock_coverage().available).is_zero()
	assert_int(production.stock_coverage().planned).is_equal(1)
	assert_str((demo.get("_target") as Label).text).contains("Available A=0 + planned C=1 = 1")
	await _capture(runner, main, demo, "target_batch_started_forecast_once")
	await _press(runner, main, "+10s")
	var partial: Dictionary = production.batch.duplicate(true)
	assert_float(partial.work).is_equal(20.0)
	await _spin_target(runner, demo, false)
	assert_int(production.stock_target).is_zero()
	await _press(runner, main, "Continuous")
	await _press(runner, main, "Stock target")
	assert_dict(production.batch).is_equal(partial)
	assert_float(production.snapshot().output_promise.mass).is_equal(4.0)
	await _capture(runner, main, demo, "target_lowered_active_work_retained")
	await _press(runner, main, "+10s")
	assert_int(production.stock_coverage().available).is_equal(1)
	assert_int(production.stock_coverage().planned).is_zero()
	assert_dict(production.batch).is_empty()
	await _spin_target(runner, demo, true)
	assert_int(production.stock_target).is_equal(1)
	await _press(runner, main, "+20s")
	assert_str(production.snapshot().status).is_equal("Target satisfied — no new batch")
	assert_int(production.history.size()).is_equal(1)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 2, "M02": 1})
	assert_str((demo.get("_target") as Label).text).contains("Available A=1 + planned C=0 = 1")
	assert_array(rear.audit()).is_empty()
	await _capture(runner, main, demo, "target_satisfied_physical_rifle")
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
	var output := "res://.artifacts/g04-r01"
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
		assert_bool(node.get_viewport_rect().grow(1).encloses(node.get_global_rect())).override_failure_message("R01 visible control fits: " + str(node.get_path())).is_true()
	for child in node.get_children(): _bounds(child, in_scroll or node is ScrollContainer)
