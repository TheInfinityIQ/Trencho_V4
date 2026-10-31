extends SceneTree
const Main = preload("res://game/main/main.tscn")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	var main: Control = Main.instantiate()
	root.add_child(main)
	await process_frame
	var base: Control = main.get("_base")
	var launch: Button
	for button in main.find_children("*","Button",true,false):
		if button.text == "New playtest": launch = button
	assert(launch != null)
	var down := InputEventMouseButton.new()
	down.position = launch.get_global_rect().get_center()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	assert(base.simulation.rear.military.squads.size() == 10)
	main._show_battlefield()
	var view: Control = main.get("_battlefield")
	assert(view.simulation == base.simulation)
	assert(main.get("_field_clock").is_visible_in_tree() and not main.get("_diagnostics").visible)
	if "--supply" in OS.get_cmdline_user_args():
		main._show_base()
		base.tabs.current_tab = base.tabs.get_node("Supply").get_index()
		base.forward_delivery_panel.refresh()
		assert(not base.forward_delivery_panel.manual_issue.visible and base.forward_delivery_panel.loader_choice.disabled and base.forward_delivery_panel.unloader_choice.disabled)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.artifacts/opening-supply.png")
		print("Opening Supply render: ordinary controls and autonomous-role presentation captured")
		quit()
		return
	if "--boarding" in OS.get_cmdline_user_args(): base.simulation.rear.advance_time(12)
	if "--underway" in OS.get_cmdline_user_args():
		base.simulation.rear.advance_time(180)
		var actual: Dictionary = base.simulation.rear.ledger.inspect_entity("start-blue-vehicle-00")
		assert(actual.passengers.size() == 16 and actual.holder_id == "troop-transit","Actual first lift is underway with sixteen people aboard")
		print("Underway first lift: ",actual.position," passengers=",actual.passengers.size()," fuel=",actual.fuel)
	var capture: bool = "--capture" in OS.get_cmdline_user_args()
	if capture:
		base.simulation.rear.advance_time(600)
		assert(base.simulation.rear.objectives.inspect("resource-centre-blue").owner == "army-blue","First objective is physically captured")
		print("Actual capture events: ",base.simulation.rear.objectives.events)
	view.selected_id = "start-blue-vehicle-00"
	if capture: view.selected_id = "resource-centre-blue"
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/opening-capture-overview.png" if capture else "res://.artifacts/opening-overview.png")
	view.zoom = 5.0
	view.pan = Vector2.ZERO if capture else -Vector2(0,600-3000)*view._scale()
	view._refresh()
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/opening-capture-front.png" if capture else "res://.artifacts/opening-staging.png")
	print("Opening render probe: ordinary session creation and shared views captured")
	quit()
