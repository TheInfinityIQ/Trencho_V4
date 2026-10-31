extends GdUnitTestSuite
## Both complete raw-stock chains use normal-launch actual engine input.


func test_normal_launch_r32_raw_explosives_haul_access_guard_and_physical_tank_shells() -> void:
	await _chain("R32", 140, "E25", 10, 120.0, 180.0)


func test_normal_launch_r33_raw_explosives_haul_and_physical_autocannon_rounds() -> void:
	await _chain("R33", 70, "E26", 100, 50.0, 100.0)


func _chain(recipe: String, metal: int, type: String, yield_count: int, mass: float, work: float) -> void:
	# Current development acceptance uses one fixed 1280x720 screen.
	var window := get_tree().root
	var previous := {"size": window.size, "content": window.content_scale_size}
	window.size = Vector2i(1280, 720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	if recipe == "R32":
		await _press(runner, main, "G04 R27 Explosives")
		await runner.simulate_frames(3)
		var denied: Control = main.get("_host").get_child(0)
		var original: Dictionary = denied.get("simulation").ledger.snapshot()
		await _press(runner, main, "Select R32")
		assert_str((denied.get("_feedback") as Label).text).contains("access absent")
		assert_str(denied.get("production").snapshot().recipe).is_equal("R02")
		assert_dict(denied.get("simulation").ledger.snapshot()).is_equal(original)
		await _capture(runner, main, denied, "shell_access_absent")
	await _press(runner, main, "G04 " + recipe + " Chain")
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	var rear: RefCounted = demo.get("simulation")
	var activity: RefCounted = demo.get("production")
	assert_str(activity.snapshot().recipe).is_equal("R02")
	assert_int(rear.actors.size()).is_equal(5)
	assert_int(rear.ledger.total_stock("M01")).is_equal(metal)
	assert_int(rear.ledger.total_stock("M03")).is_equal(200)
	for output in ["M06", "E25", "E26"]: assert_int(rear.ledger.total_stock(output)).is_zero()
	await _press(runner, main, "Select " + recipe)
	await _press(runner, main, "Operators 4")
	await _press(runner, main, "+300s")
	assert_str(activity.snapshot().status).is_equal("Missing Inputs")
	assert_int(activity.operators().size()).is_equal(4)
	assert_dict(rear.ledger.snapshot().consumed).is_empty()
	await _capture(runner, main, demo, recipe.to_lower() + "_raw_missing_inputs")
	await _press(runner, main, "Select R27")
	await _press(runner, main, "Stock target")
	for count in 20: await _spin_target(runner, demo, true)
	assert_int(activity.stock_target).is_equal(20)
	await _press(runner, main, "Hauling 1")
	for interval in 20:
		if activity.history.size() == 20: break
		await _press(runner, main, "+300s")
	assert_int(activity.history.size()).is_equal(20)
	assert_dict(activity.batch).is_empty()
	assert_int(rear.ledger.total_stock("M06")).is_equal(20)
	assert_int(rear.ledger.available_stock_at("munitions_output", "M06")).is_equal(20)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": 40, "M03": 200})
	assert_int(rear.ledger.available_stock_at("munitions_input", "M01")).is_equal(metal - 40)
	var manufactured_ids: Array[String] = []
	for item in activity.history: manufactured_ids.append(item.output_id)
	await _capture(runner, main, demo, recipe.to_lower() + "_twenty_manufactured_m06")
	await _press(runner, main, "Select " + recipe)
	await _press(runner, main, "Stock target")
	await _spin_target(runner, demo, true)
	assert_int(activity.stock_target).is_equal(1)
	assert_dict(activity.batch).is_empty()
	assert_int(activity.snapshot().missing_local.M06).is_equal(20)
	assert_int(activity.stock_coverage().planned).is_zero()
	await _capture(runner, main, demo, recipe.to_lower() + "_output_m06_is_not_input")
	await _press(runner, main, "M06 to input")
	assert_dict(activity.batch).is_empty()
	await _press(runner, main, "+2s")
	var carriers: Array = rear.actors.values().filter(func(a: Dictionary) -> bool: return a.phase in ["Carry", "Drop"])
	assert_array(carriers).has_size(1)
	assert_str(carriers[0].load.type).is_equal("M06")
	assert_bool(carriers[0].load.stock in manufactured_ids).is_true()
	assert_dict(activity.batch).is_empty()
	assert_int(rear.ledger.total_stock(type)).is_zero()
	await _capture(runner, main, demo, recipe.to_lower() + "_actual_m06_carry")
	# Pause before advancing haul time, so the production start is exactly visible.
	await _press(runner, main, "Pause " + recipe)
	await _press(runner, main, "+300s")
	assert_int(rear.jobs.back().delivered).is_equal(20)
	assert_int(rear.ledger.available_stock_at("munitions_input", "M06")).is_equal(20)
	await _press(runner, main, "Resume " + recipe)
	assert_float(activity.batch.work).is_zero()
	assert_float(activity.batch.required_work).is_equal(work)
	assert_float(activity.snapshot().output_promise.mass).is_equal(mass)
	assert_int(activity.stock_coverage().planned).is_equal(yield_count)
	assert_dict(rear.ledger.snapshot().consumed).is_equal({"M01": metal, "M03": 200, "M06": 20})
	var explosive_receipts: Array = activity.batch.receipt.filter(func(p: Dictionary) -> bool: return p.type == "M06")
	assert_array(explosive_receipts).has_size(20)
	for portion in explosive_receipts: assert_bool(rear.ledger.inspect_entity(portion.id).origin_id in manufactured_ids).is_true()
	await _capture(runner, main, demo, recipe.to_lower() + "_shell_batch_started")
	await _press(runner, main, "+10s")
	var partial: Dictionary = activity.batch.duplicate(true)
	assert_float(partial.work).is_equal(40.0)
	await _press(runner, main, "Select R27")
	var dialog := demo.get("_recipe_dialog") as ConfirmationDialog
	assert_bool(dialog.visible).is_true()
	assert_str(dialog.dialog_text).contains(partial.id)
	await _press(runner, dialog, "Keep current recipe")
	assert_dict(activity.batch).is_equal(partial)
	await _press(runner, main, "Try %d kg" % (mass - 1))
	assert_float(rear.stores.munitions_output.capacity).is_equal(1000.0)
	await _press(runner, main, "Reject %s filter" % type)
	assert_array(rear.stores.munitions_output.filter).is_empty()
	await _press(runner, main, "Block output")
	await _press(runner, main, "+20s")
	assert_dict(activity.batch).is_equal(partial)
	assert_int(rear.ledger.total_stock(type)).is_zero()
	await _capture(runner, main, demo, recipe.to_lower() + "_partial_blocked_work")
	await _press(runner, main, "Restore output")
	if recipe == "R32": await _press(runner, main, "+20s")
	await _press(runner, main, "+10s")
	await _press(runner, main, "+5s")
	assert_int(rear.ledger.total_stock(type)).is_equal(yield_count)
	assert_float(rear.ledger.loose_stock_mass_at("munitions_output")).is_equal(mass)
	assert_float(activity.history[0].work).is_equal(work)
	assert_int(activity.snapshot().recipe_records.R27.history.size()).is_equal(20)
	assert_int(rear.ledger.total_stock("M06")).is_zero()
	assert_int(activity.stock_coverage().available).is_equal(yield_count)
	assert_int(activity.stock_coverage().planned).is_zero()
	assert_dict(activity.batch).is_empty()
	assert_dict(rear._output_promises).is_empty()
	assert_array(rear.audit()).is_empty()
	await _capture(runner, main, demo, recipe.to_lower() + "_physical_output")
	window.size = Vector2i(1280, 720)
	window.content_scale_size = window.size
	await runner.simulate_frames(4)
	var scroll := (demo.get("_people") as Label).get_parent() as ScrollContainer
	assert_float(scroll.size.y).is_greater_equal(48)
	runner.set_mouse_position(scroll.get_global_rect().get_center())
	await runner.await_input_processed()
	for notch in 500:
		if scroll.scroll_vertical >= scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page - 1: break
		runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
		await runner.await_input_processed()
		await runner.simulate_frames(2)
	assert_int(scroll.scroll_vertical).is_greater(0)
	assert_float(float(scroll.scroll_vertical)).is_equal_approx(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page, 1.0)
	await _capture(runner, main, demo, recipe.to_lower() + "_small_scrolled")
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


func _press(runner: GdUnitSceneRunner, root: Node, title: String) -> void:
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
	var point := matches[0].get_global_rect().get_center()
	var window := matches[0].get_window()
	if window != get_tree().root and window.is_embedded(): point += Vector2(window.position)
	runner.set_mouse_position(point)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()


func _capture(runner: GdUnitSceneRunner, main: Control, demo: Control, checkpoint: String) -> void:
	await runner.simulate_frames(3)
	_bounds(main)
	await RenderingServer.frame_post_draw
	var rendered: Image = main.get_viewport().get_texture().get_image()
	assert_vector(rendered.get_size()).is_equal(get_tree().root.size)
	var output := "res://.artifacts/g04-shell-chain"
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
		"production": _json_value(demo.get("production").snapshot()),
		"confirmation_dialog": {"visible": (demo.get("_recipe_dialog") as ConfirmationDialog).visible, "text": (demo.get("_recipe_dialog") as ConfirmationDialog).dialog_text}}
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
		assert_bool(node.get_viewport_rect().grow(1).encloses(node.get_global_rect())).override_failure_message("Shell-chain visible control fits: " + str(node.get_path())).is_true()
	for child in node.get_children(): _bounds(child, in_scroll or node is ScrollContainer)
