extends GdUnitTestSuite
## SceneRunner input drives the connected normal rear, never an isolated yard hull.

func test_normal_rear_vehicle_controls_report_refuel_drive_same_produced_hull_and_fit_small_view() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	var base: RefCounted = demo.get("simulation")
	var rear: RefCounted = base.rear
	assert_bool(base.receiving.buy_recovery_instructor().ok).is_true()
	rear.advance_time(150)
	rear.set_target("training",1)
	assert_bool(rear.training.request_course("P01",1).ok).is_true()
	rear.advance_time(300)
	var graduate: String = rear.training.rows[0].person_id
	assert_bool(rear.training.request_course("P08",1).ok).is_true()
	rear.advance_time(350)
	assert_str(rear.ledger.inspect_entity(graduate).qualification).is_equal("P08")
	var heavy: RefCounted = rear.heavy_production
	heavy.set_mode("Continuous")
	assert_bool(heavy.accept_order().ok).is_true()
	assert_bool(base.receiving.buy_resources({"M01":120,"M02":80,"M08":5}).ok).is_true()
	assert_bool(base.receiving.buy_people().ok).is_true()
	rear.set_target("receiving",2)
	rear.set_target("hauling",4)
	rear.set_target("vehicle_works",8)
	rear.request_haul("receiving","vehicle_input","M01",120)
	rear.request_haul("receiving","vehicle_input","M02",80)
	rear.advance_time(1000)
	var id: String = heavy.bay_occupant
	assert_str(id).is_not_empty()
	demo.call("_refresh")
	await _tab(runner,demo,6)
	assert_str((demo.get("vehicle_status") as Label).text).contains(id)
	await _press(runner,main,"Drive SAME F10 hull to promised F11 place")
	assert_str((demo.get("feedback") as Label).text).contains("Awaiting Qualified Driver")
	_select_person(demo,graduate)
	await _press(runner,main,"Report and board selected station")
	rear.advance_time(170)
	assert_str(rear.ledger.inspect_entity(graduate).crew_station).is_equal("Driver")
	await _press(runner,main,"Drive SAME F10 hull to promised F11 place")
	assert_str((demo.get("feedback") as Label).text).contains("Fuel Empty")
	await _capture(runner,main,demo,"normal_driver_no_fuel")
	var worker := ""
	for person in rear.actors:
		if person == graduate: continue
		var p: Dictionary = rear.ledger.inspect_entity(person)
		if p.pending_assignment == "None" and p.carrying_stock_id.is_empty() and p.crew_station.is_empty():
			worker = person
			break
	assert_str(worker).is_not_empty()
	_select_person(demo,worker)
	(demo.get("vehicle_fuel_units") as SpinBox).value = 5
	await _press(runner,main,"Carry purchased fuel into this tank")
	assert_str((demo.get("feedback") as Label).text).contains("Worker reporting")
	rear.advance_time(220)
	assert_float(rear.ledger.inspect_entity(id).fuel).is_equal(5.0)
	assert_int(rear.ledger.total_stock("M08")).is_zero()
	await _press(runner,main,"Drive SAME F10 hull to promised F11 place")
	assert_str((demo.get("feedback") as Label).text).contains("moving physically")
	rear.advance_time(1)
	assert_str(heavy.bay_occupant).is_equal(id)
	rear.advance_time(100)
	assert_str(rear.vehicles.vehicles[id].state).is_equal("Parked")
	assert_str(heavy.bay_occupant).is_empty()
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(3)
	await _capture(runner,main,demo,"small_same_hull_parked")
	assert_array(base.audit()).is_empty()
	window.size = previous.size
	window.content_scale_size = previous.content

func _select_person(demo: Control, id: String) -> void:
	demo.call("_refresh")
	var option: OptionButton = demo.get("vehicle_person")
	for index in option.item_count:
		if option.get_item_metadata(index) == id:
			option.select(index)
			return
	assert_bool(false).override_failure_message("Actual rear person is listed in Vehicles: " + id).is_true()

func _tab(runner: GdUnitSceneRunner, demo: Control, index: int) -> void:
	var bar: TabBar = demo.get("tabs").get_tab_bar()
	bar.ensure_tab_visible(index)
	await runner.simulate_frames(2)
	await _click(runner,bar.global_position + bar.get_tab_rect(index).get_center())
	await runner.simulate_frames(2)
	assert_int((demo.get("tabs") as TabContainer).current_tab).is_equal(index)

func _press(runner: GdUnitSceneRunner, root: Control, text: String) -> void:
	var matches: Array[Button] = []
	for button in root.find_children("*","Button",true,false):
		if button.text == text and button.is_visible_in_tree(): matches.append(button)
	assert_int(matches.size()).is_equal(1)
	if matches.size() != 1: return
	await _expose(matches[0])
	var point := matches[0].get_global_rect().get_center()
	if matches[0].get_window() != get_tree().root and matches[0].get_window().is_embedded(): point += Vector2(matches[0].get_window().position)
	await _click(runner,point)

func _expose(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await get_tree().process_frame

func _click(runner: GdUnitSceneRunner, point: Vector2) -> void:
	runner.set_mouse_position(point)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()

func _capture(runner: GdUnitSceneRunner, main: Control, demo: Control, name: String) -> void:
	demo.call("_refresh")
	runner.set_mouse_position(main.size-Vector2(8,8))
	await runner.await_input_processed()
	await runner.simulate_frames(3)
	_bounds(main)
	await RenderingServer.frame_post_draw
	var rendered: Image = main.get_viewport().get_texture().get_image()
	var output := "res://.artifacts/vehicles"
	assert_int(DirAccess.make_dir_recursive_absolute(output)).is_equal(OK)
	assert_int(rendered.save_png(output+"/"+name+".png")).is_equal(OK)
	var file := FileAccess.open(output+"/"+name+".json",FileAccess.WRITE)
	var id: String = demo.get("vehicle_ids")[(demo.get("vehicle_rows") as ItemList).get_selected_items()[0]]
	var base: RefCounted = demo.get("simulation")
	file.store_string(JSON.stringify({"head":OS.get_environment("EVALUATION_HEAD"),"engine":Engine.get_version_info().string,"size":[main.size.x,main.size.y],"hull":base.rear.ledger.inspect_entity(id),"readiness":base.rear.vehicles.readiness(id)},"\t"))

func _bounds(node: Node, scrolling: bool = false) -> void:
	if node is Control and node.is_visible_in_tree() and not scrolling:
		assert_bool(node.get_viewport_rect().grow(1).encloses(node.get_global_rect())).override_failure_message("Visible rear control fits: " + str(node.get_path())).is_true()
	for child in node.get_children(): _bounds(child,scrolling or node is ScrollContainer)
