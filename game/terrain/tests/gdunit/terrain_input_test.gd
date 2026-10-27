extends GdUnitTestSuite
## Engine-input regression over existing declared diagnostics, not native evidence.


func test_blocked_wheel_then_real_road_travel_preserves_fuel_and_inspection() -> void:
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
	await _press(runner, demo, "+5s")
	assert_float(lane.time).is_equal(6.0)
	assert_str(lane.state).is_equal("Arrived")
	assert_vector(lane.entity.position).is_equal(Vector2(70, 12))
	assert_float(lane.travelled).is_equal_approx(60.0, 0.000001)
	assert_float(lane.entity.fuel).is_equal_approx(39.88, 0.000001)
	assert_float(lane.fuel_used).is_equal_approx(0.12, 0.000001)
	assert_str((demo.get("_detail") as Label).text).contains("TR02 Road")
	assert_str((demo.get("_detail") as Label).text).contains("Position (70.000, 12.000)m")


func test_eye_and_ground_muzzle_then_independent_direct_and_blast_cover() -> void:
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
