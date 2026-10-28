extends GdUnitTestSuite
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")

func test_hq_issue_panel_click_reserves_then_physically_issues_same_person() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	var base := Base.new(true)
	demo.set("simulation",base)
	demo.get("base_map").set("simulation",base)
	assert_bool(base.rear.ledger.add_person("hq-ui-person","hq-reserve",base.rear.PLAYER,Records.Assignment.HQ_RESERVE,true).ok).is_true()
	assert_bool(base.rear.ledger.add_stock("hq-ui-rounds","E02",20,0.02,"hq-stock",base.rear.PLAYER).ok).is_true()
	demo.call("_refresh")
	var bar: TabBar = demo.get("tabs").get_tab_bar()
	bar.ensure_tab_visible(8)
	await runner.simulate_frames(2)
	await _click(runner,bar.global_position+bar.get_tab_rect(8).get_center())
	assert_int((demo.get("tabs") as TabContainer).current_tab).is_equal(8)
	assert_int((demo.get("hq_person") as OptionButton).item_count).is_equal(1)
	assert_int((demo.get("hq_type") as OptionButton).item_count).is_equal(1)
	(demo.get("hq_count") as SpinBox).value = 10
	await _press(runner,main,"Issue stock to person")
	assert_int(base.rear.hq.jobs.size()).is_equal(1)
	assert_float(base.rear.ledger.inspect_entity("hq-ui-person").contents_mass_kg).is_equal(0.0)
	assert_int(base.rear.hq.snapshot().reserved.E02).is_equal(10)
	base.rear.advance_time(20)
	demo.call("_refresh")
	assert_float(base.rear.ledger.inspect_entity("hq-ui-person").contents_mass_kg).is_equal(0.2)
	assert_str(base.rear.hq.jobs.values()[0].state).is_equal("Complete")
	assert_str((demo.get("hq_status") as Label).text).contains("available")
	assert_array(base.audit()).is_empty()
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(3)
	var scroll: ScrollContainer = (demo.get("tabs") as TabContainer).get_child(8)
	scroll.ensure_control_visible(demo.get("hq_status"))
	await runner.simulate_frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = main.get_viewport().get_texture().get_image()
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/hq")).is_equal(OK)
	assert_int(image.save_png("res://.artifacts/hq/issue_small.png")).is_equal(OK)
	window.size = previous.size
	window.content_scale_size = previous.content

func _press(runner: GdUnitSceneRunner, root: Control, label: String) -> void:
	var matches: Array[Button] = []
	for button in root.find_children("*","Button",true,false):
		if button.text == label and button.is_visible_in_tree(): matches.append(button)
	assert_int(matches.size()).is_equal(1)
	if matches.size() != 1: return
	var control: Control = matches[0]
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await get_tree().process_frame
	await _click(runner,control.get_global_rect().get_center())

func _click(runner: GdUnitSceneRunner, point: Vector2) -> void:
	runner.set_mouse_position(point)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
