extends GdUnitTestSuite
## Engine-input regression over existing declared diagnostics, not native evidence.


func test_blocked_wheel_then_real_road_travel_preserves_fuel_and_inspection() -> void:
	var previous := _render_window(Vector2i(1000, 720))
	var runner := scene_runner("res://game/terrain/terrain_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(2)
	await _choose(runner, demo.get("_selector"), "TR06 Dense forest / T02")
	var lane: RefCounted = demo.get("_lane")
	assert_str(lane.entity.type).is_equal("T02")
	assert_int(lane.entity.movement_class).is_equal(1)
	var start: Dictionary = lane.snapshot()
	await _press(runner, demo, "Start lane")
	assert_str(lane.state).is_equal("Blocked")
	assert_bool(lane.last_plan.ok).is_false()
	await _press(runner, demo, "+5s")
	assert_float(lane.time).is_equal(5.0)
	assert_vector(lane.entity.position).is_equal(start.entity.position)
	assert_float(lane.entity.fuel).is_equal(start.entity.fuel)
	assert_float(lane.travelled).is_zero()
	assert_float(lane.fuel_used).is_zero()
	assert_dict(lane.motion).is_empty()
	assert_str((demo.get("_summary") as Label).text).contains("Blocked")
	assert_str((demo.get("_detail") as Label).text).contains("Class wheel")
	assert_str((demo.get("_detail") as Label).text).contains("TR06 Dense forest")
	await _capture(runner, demo, "forest_wheel_refused")
	await _choose(runner, demo.get("_selector"), "TR02 Road / T02")
	lane = demo.get("_lane")
	assert_float(lane.time).is_zero()
	assert_str(lane.entity.type).is_equal("T02")
	assert_int(lane.entity.movement_class).is_equal(1)
	assert_vector(lane.entity.position).is_equal(Vector2(10, 12))
	assert_float(lane.entity.base).is_equal(10.0)
	await _press(runner, demo, "Start lane")
	# Road factor1.5: 60m / (10m/s * 1.5) =4s, 60m*2fuel/km =0.12.
	assert_str(lane.state).is_equal("Moving")
	assert_float(lane.last_plan.seconds).is_equal_approx(4.0, 0.000001)
	assert_float(lane.last_plan.fuel).is_equal_approx(0.12, 0.000001)
	await _press(runner, demo, "+1s")
	assert_vector(lane.entity.position).is_equal(Vector2(25, 12))
	assert_float(lane.travelled).is_equal_approx(15.0, 0.000001)
	assert_float(lane.fuel_used).is_equal_approx(0.03, 0.000001)
	assert_float(lane.entity.fuel).is_equal_approx(39.97, 0.000001)
	assert_str((demo.get("_summary") as Label).text).contains("t=1.000s")
	assert_str((demo.get("_detail") as Label).text).contains("Position (25.000, 12.000)m")
	assert_str((demo.get("_detail") as Label).text).contains("tank 39.970000")
	await _capture(runner, demo, "road_after_one_second")
	await _press(runner, demo, "Stop here")
	await _press(runner, demo, "+5s")
	assert_str(lane.state).is_equal("Stopped")
	assert_float(lane.time).is_equal_approx(6.0, 0.000001)
	assert_vector(lane.entity.position).is_equal(Vector2(25, 12))
	assert_float(lane.entity.fuel).is_equal_approx(39.97, 0.000001)
	assert_float(lane.travelled).is_equal_approx(15.0, 0.000001)
	assert_float(lane.fuel_used).is_equal_approx(0.03, 0.000001)
	await _capture(runner, demo, "road_stopped_after_further_time")
	# Retain the original full-lane timing/arrival regression as a fresh case.
	await _press(runner, demo, "Reset case")
	lane = demo.get("_lane")
	await _press(runner, demo, "Start lane")
	await _press(runner, demo, "+1s")
	await _press(runner, demo, "+5s")
	assert_float(lane.time).is_equal(6.0)
	assert_str(lane.state).is_equal("Arrived")
	assert_vector(lane.entity.position).is_equal(Vector2(70, 12))
	assert_float(lane.travelled).is_equal_approx(60.0, 0.000001)
	assert_float(lane.entity.fuel).is_equal_approx(39.88, 0.000001)
	assert_float(lane.fuel_used).is_equal_approx(0.12, 0.000001)
	assert_str((demo.get("_detail") as Label).text).contains("TR02 Road")
	assert_str((demo.get("_detail") as Label).text).contains("Position (70.000, 12.000)m")
	_render_window(Vector2i(960, 540))
	await runner.simulate_frames(3)
	await _choose(runner, demo.get("_selector"), "Ford 0.351m / T02")
	lane = demo.get("_lane")
	var ford_start: Dictionary = lane.snapshot()
	await _press(runner, demo, "Start lane")
	assert_str(lane.state).is_equal("Blocked")
	assert_vector(lane.entity.position).is_equal(ford_start.entity.position)
	assert_float(lane.entity.fuel).is_equal(ford_start.entity.fuel)
	assert_str((demo.get("_detail") as Label).text).contains("Depth 0.351m")
	await _capture(runner, demo, "ford_0351_refused_small")
	_restore_window(previous)


func test_eye_and_ground_muzzle_then_independent_direct_and_blast_cover() -> void:
	var previous := _render_window(Vector2i(1000, 720))
	var runner := scene_runner("res://game/terrain/terrain_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(2)
	await _choose(runner, demo.get("_mode"), "Sight & cover")
	await _choose(runner, demo.get("_selector"), "Eye clears low ridge; rifle muzzle blocked")
	var observation: Dictionary = demo.get("_observation")
	assert_bool(observation.visible).is_true()
	assert_bool(observation.eye.clear).is_true()
	assert_bool(observation.muzzle.clear).is_false()
	assert_bool(observation.firing_line_clear).is_false()
	assert_str(observation.eye.reason).is_equal("Clear")
	assert_str((demo.get("_knowledge") as String)).is_equal("Observed at declared probe time")
	var summary := demo.get("_summary") as Label
	assert_str(summary.text).contains("eye: Clear")
	assert_str(summary.text).contains("muzzle: " + observation.muzzle.reason)
	assert_str((demo.get("_detail") as Label).text).contains("INDEPENDENT GROUND MUZZLE")
	assert_bool((demo.get("_diagram") as Control).get("visible_target")).is_true()
	await _capture(runner, demo, "eye_visible_muzzle_blocked")
	await _choose(runner, demo.get("_selector"), "Mixed foliage reaches 100")
	var unseen: Dictionary = demo.get("_observation").duplicate(true)
	assert_bool(unseen.visible).is_false()
	assert_float(unseen.eye.budget).is_equal_approx(100.0, 0.000001)
	var knowledge: String = demo.get("_knowledge")
	await _press(runner, demo, "Overview")
	assert_bool((demo.get("_overview") as CheckButton).button_pressed).is_true()
	assert_dict(demo.get("_observation")).is_equal(unseen)
	assert_str(demo.get("_knowledge")).is_equal(knowledge)
	assert_bool((demo.get("_diagram") as Control).get("visible_target")).is_false()
	await _capture(runner, demo, "mixed_100_unseen_after_overview")
	await _press(runner, demo, "Overview")
	await _choose(runner, demo.get("_selector"), "Bunker direct front / blast rear")
	var fixture: Dictionary = demo.get("_fixture")
	assert_vector(fixture.observer).is_equal(Vector2(10, 20))
	assert_vector(fixture.target).is_equal(Vector2(30, 20))
	assert_vector(fixture.impact).is_equal(Vector3(50, 20, 0))
	var cover: Dictionary = fixture.world.cover(fixture.target, fixture.observer, fixture.cover_class, false, fixture.impact)
	assert_float(cover.hit).is_equal(0.25)
	assert_str(cover.source).is_equal("declared-shield")
	assert_array(cover.valid).contains(["TR06", "declared-shield"])
	assert_float(cover.blast).is_equal(0.5)
	assert_str(cover.blast_source).is_equal("TR06")
	assert_array(cover.blast_valid).contains_exactly(["TR06"])
	assert_str(summary.text).contains("Cover hit ×0.25 (declared-shield) / blast ×0.50 (TR06)")
	assert_str((demo.get("_detail") as Label).text).contains("DECLARED BLAST IMPACT")
	assert_str((demo.get("_detail") as Label).text).contains("DIRECTIONAL COVER (separate direct/blast sources)")
	await _capture(runner, demo, "bunker_front_forest_rear")
	_render_window(Vector2i(960, 540))
	await runner.simulate_frames(3)
	var detail := demo.get("_detail") as Label
	var scroll := detail.get_parent() as ScrollContainer
	var marker := detail.text.substr(0, detail.text.find("DIRECTIONAL COVER"))
	var font_size: int = detail.get_theme_font_size("font_size")
	var text_size := detail.get_theme_font("font").get_multiline_string_size(marker, HORIZONTAL_ALIGNMENT_LEFT, maxf(1, detail.size.x), font_size)
	# Scroll by actual wheel events until the cover section is in the visible area.
	runner.set_mouse_position(scroll.get_global_rect().get_center())
	await runner.await_input_processed()
	for notch in 100:
		if scroll.scroll_vertical >= text_size.y - scroll.size.y / 3: break
		runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
		await runner.await_input_processed()
		await runner.simulate_frames(3)
	assert_int(scroll.scroll_vertical).is_greater(0)
	assert_float(float(scroll.scroll_vertical)).is_greater_equal(text_size.y - scroll.size.y / 3)
	assert_float(float(scroll.scroll_vertical)).is_less(text_size.y + scroll.size.y / 3)
	await _capture(runner, demo, "cover_details_scrolled_small")
	_restore_window(previous)


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
	await runner.simulate_frames(3)
	_bounds(demo)
	await RenderingServer.frame_post_draw
	var rendered: Image = demo.get_viewport().get_texture().get_image()
	assert_vector(rendered.get_size()).is_equal(get_tree().root.size)
	var output := "res://.artifacts/g08-rendered"
	assert_int(DirAccess.make_dir_recursive_absolute(output)).is_equal(OK)
	assert_int(rendered.save_png(output + "/" + checkpoint + ".png")).is_equal(OK)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(rendered.get_data())
	var selector := demo.get("_selector") as OptionButton
	var mode := demo.get("_mode") as OptionButton
	var detail := demo.get("_detail") as Label
	var state: Dictionary = {}
	if mode.selected == 0:
		state = demo.get("_lane").snapshot()
	else:
		var fixture: Dictionary = demo.get("_fixture")
		state = {"time": 0.0, "time_kind": "static declared probe; no simulation clock",
			"observer": fixture.observer, "target": fixture.target, "role": fixture.role,
			"muzzle": fixture.muzzle, "impact": fixture.impact, "cover_class": fixture.cover_class,
			"observation": demo.get("_observation").duplicate(true), "knowledge": demo.get("_knowledge"),
			"visible_target": demo.get("_diagram").visible_target,
			"cover": fixture.world.cover(fixture.target, fixture.observer, fixture.cover_class, false, fixture.impact)}
	var metadata := {"kind": "Godot Linux CI render; Windows native input/readability unverified",
		"revision": OS.get_environment("EVALUATION_HEAD"), "engine": Engine.get_version_info().string,
		"image": checkpoint + ".png", "checkpoint": checkpoint,
		"viewport_px": [rendered.get_width(), rendered.get_height()], "pixel_sha256": digest.finish().hex_encode(),
		"mode": mode.get_item_text(mode.selected), "selected_fixture": selector.get_item_text(selector.selected),
		"overview": (demo.get("_overview") as CheckButton).button_pressed,
		"summary": (demo.get("_summary") as Label).text, "inspection": detail.text,
		"scroll_y_px": (detail.get_parent() as ScrollContainer).scroll_vertical, "state": _json_value(state)}
	var file := FileAccess.open(output + "/" + checkpoint + ".json", FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file != null: file.store_string(JSON.stringify(metadata, "\t") + "\n")


func _json_value(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is Vector3: return [value.x, value.y, value.z]
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
		assert_bool(node.get_viewport_rect().grow(1).encloses(node.get_global_rect())).override_failure_message("G08 visible control fits: " + str(node.get_path())).is_true()
	for child in node.get_children(): _bounds(child, in_scroll or node is ScrollContainer)


func _press(runner: GdUnitSceneRunner, demo: Control, text: String) -> void:
	var matches: Array[Button] = []
	for node in demo.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree(): matches.append(node)
	assert_int(matches.size()).override_failure_message("Exactly one visible button: " + text).is_equal(1)
	if matches.size() == 1:
		await _click(runner, matches[0].get_global_rect().get_center())


func _choose(runner: GdUnitSceneRunner, selector: OptionButton, title: String) -> void:
	var wanted: int = -1
	for index in selector.item_count:
		if selector.get_item_text(index) == title:
			wanted = index
	assert_int(wanted).override_failure_message("Existing diagnostic option: " + title).is_greater_equal(0)
	if wanted < 0:
		return
	# Inspect actual popup focus while sending engine navigation actions. Opening
	# a PopupMenu can initially leave focus at-1; selected index is not focus.
	await _click(runner, selector.get_global_rect().get_center())
	var popup := selector.get_popup()
	assert_bool(popup.visible).is_true()
	for step in range(selector.item_count + 1):
		if popup.get_focused_item() == wanted:
			break
		var previous: int = popup.get_focused_item()
		runner.simulate_action_pressed("ui_down")
		await runner.await_input_processed()
		assert_int(popup.get_focused_item()).override_failure_message("Popup navigation must move focus").is_not_equal(previous)
	assert_int(popup.get_focused_item()).is_equal(wanted)
	runner.simulate_action_pressed("ui_accept")
	await runner.await_input_processed()
	assert_int(selector.selected).override_failure_message("Input selected: " + title).is_equal(wanted)


func _click(runner: GdUnitSceneRunner, position: Vector2) -> void:
	runner.set_mouse_position(position)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
