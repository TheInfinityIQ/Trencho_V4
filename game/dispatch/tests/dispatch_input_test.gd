extends GdUnitTestSuite
const Fixed = preload("res://game/production/fixed_production.gd")
const Base = preload("res://game/rear_base/base_simulation.gd")

func test_normal_dispatch_accept_reject_depart_and_small_panel() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	var base: RefCounted = Base.new(true)
	demo.set("simulation",base)
	demo.get("base_map").set("simulation",base)
	demo.call("_load_production")
	(demo.get("declaration") as Label).text = "Expanded connected G12 dispatch session."
	var rear: RefCounted = base.rear
	var heavy: RefCounted = rear.heavy_production
	heavy.request_recipe("R28")
	heavy.set_mode("Continuous")
	assert_bool(heavy.accept_order().ok).is_true()
	for type in Fixed.RECIPES.R28.inputs:
		rear.ledger.add_stock("g12-input-"+type,type,Fixed.RECIPES.R28.inputs[type],1.0,"vehicle_input",rear.PLAYER)
	rear.set_target("vehicle_works",8)
	rear.advance_time(1000)
	var hull: String = heavy.bay_occupant
	assert_str(hull).is_not_empty()
	rear.add_person("g12-input-driver",true,"P08")
	assert_bool(rear.vehicles.assign_station(hull,"g12-input-driver","Driver").ok).is_true()
	rear.advance_time(160)
	rear.ledger.add_stock("g12-input-fuel","M08",10,1.0,"depot",rear.PLAYER)
	assert_bool(rear.vehicles.request_refuel(hull,"base-person-11",10).ok).is_true()
	rear.advance_time(200)
	assert_bool(rear.vehicles.start_drive(hull).ok).is_true()
	rear.advance_time(100)
	heavy.request_recipe("R13")
	assert_bool(heavy.accept_order().ok).is_true()
	for type in Fixed.RECIPES.R13.inputs:
		rear.ledger.add_stock("g12-gun-input-"+type,type,Fixed.RECIPES.R13.inputs[type],1.0,"vehicle_input",rear.PLAYER)
	rear.advance_time(1000)
	assert_str(heavy.bay_occupant).is_not_empty()
	for index in 9: rear.add_person("g12-input-passenger-%02d" % index)
	rear.set_target("dispatch",2)
	rear.advance_time(160)
	demo.call("_refresh")
	await _tab(runner,demo,7)
	(demo.get("dispatch_gun") as OptionButton).select(1)
	var people: ItemList = demo.get("dispatch_people")
	for index in people.item_count:
		if str(people.get_item_text(index)).begins_with("g12-input-passenger-"):
			people.select(index,false)
	assert_int(people.get_selected_items().size()).is_equal(9)
	await _press(runner,main,"Accept named manifest and claims")
	assert_str((demo.get("feedback") as Label).text).contains("Passenger seats exceeded")
	assert_int(rear.dispatch.manifests.size()).is_zero()
	people.deselect(people.get_selected_items()[8])
	await _press(runner,main,"Accept named manifest and claims")
	assert_int(rear.dispatch.manifests.size()).is_equal(1)
	var id: String = rear.dispatch.manifests.keys()[0]
	assert_int(rear.dispatch.incoming_people.size()).is_equal(8)
	rear.advance_time(650)
	assert_str(rear.dispatch.manifests[id].state).is_equal("Loaded Waiting Dispatch")
	await _capture(runner,main,demo,"normal_loaded_eight")
	await _press(runner,main,"Depart complete selected manifest")
	assert_str((demo.get("feedback") as Label).text).contains("trip begun")
	rear.advance_time(700)
	assert_str(rear.dispatch.manifests[id].state).is_equal("Complete")
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(3)
	await _capture(runner,main,demo,"small_hq_receipt")
	assert_array(base.audit()).is_empty()
	window.size = previous.size
	window.content_scale_size = previous.content

func _tab(runner: GdUnitSceneRunner, demo: Control, index: int) -> void:
	var bar: TabBar = demo.get("tabs").get_tab_bar()
	bar.ensure_tab_visible(index)
	await runner.simulate_frames(2)
	await _click(runner,bar.global_position + bar.get_tab_rect(index).get_center())
	await runner.simulate_frames(2)
	assert_int((demo.get("tabs") as TabContainer).current_tab).is_equal(index)

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

func _capture(runner: GdUnitSceneRunner, main: Control, demo: Control, name: String) -> void:
	demo.call("_refresh")
	var scroll: ScrollContainer = (demo.get("tabs") as TabContainer).get_child(7)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	runner.set_mouse_position(main.size-Vector2(8,8))
	await runner.await_input_processed()
	await runner.simulate_frames(3)
	_bounds(main)
	await RenderingServer.frame_post_draw
	var rendered: Image = main.get_viewport().get_texture().get_image()
	var output := "res://.artifacts/dispatch"
	assert_int(DirAccess.make_dir_recursive_absolute(output)).is_equal(OK)
	assert_int(rendered.save_png(output+"/"+name+".png")).is_equal(OK)
	var file := FileAccess.open(output+"/"+name+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"head":OS.get_environment("EVALUATION_HEAD"),"engine":Engine.get_version_info().string,"size":[main.size.x,main.size.y],"dispatch":demo.get("simulation").rear.dispatch.snapshot()},"\t"))

func _bounds(node: Node, scrolling: bool = false) -> void:
	if node is Control and node.is_visible_in_tree() and not scrolling:
		assert_bool(node.get_viewport_rect().grow(1).encloses(node.get_global_rect())).override_failure_message("Visible dispatch control fits: " + str(node.get_path()) + " rect=" + str(node.get_global_rect()) + " viewport=" + str(node.get_viewport_rect())).is_true()
	for child in node.get_children(): _bounds(child,scrolling or node is ScrollContainer)
