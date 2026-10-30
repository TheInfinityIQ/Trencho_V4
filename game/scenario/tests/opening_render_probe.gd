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
	base.scenario.select(2)
	base._start_session()
	assert(base.simulation.rear.military.squads.size() == 10)
	main._show_battlefield()
	var view: Control = main.get("_battlefield")
	assert(view.simulation == base.simulation)
	assert(main.get("_field_clock").is_visible_in_tree() and not main.get("_diagnostics").visible)
	if "--boarding" in OS.get_cmdline_user_args(): base.simulation.rear.advance_time(12)
	view.selected_id = "start-blue-vehicle-00"
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/opening-overview.png")
	view.zoom = 5.0
	view.pan = -Vector2(0,600-3000)*view._scale()
	view._refresh()
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/opening-staging.png")
	print("Opening render probe: ordinary session creation and shared views captured")
	quit()
