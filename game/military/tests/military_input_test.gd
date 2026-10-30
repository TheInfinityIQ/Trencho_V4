extends GdUnitTestSuite
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")

func test_dispatch_shows_real_automatic_formation_and_shortage() -> void:
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
	for i in 4:
		var id := "g15-ui-%d" % i
		assert_bool(base.rear.ledger.add_person(id,"hq-reserve",base.rear.PLAYER,Records.Assignment.HQ_RESERVE,true).ok).is_true()
		base.rear.dispatch.military_people[id] = "g15-ui"
		base.rear.dispatch.hq_reserve[id] = "Occupied"
		assert_bool(base.rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,base.rear.PLAYER,"E02",30).ok).is_true()
		assert_bool(base.rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,base.rear.PLAYER).ok).is_true()
	base.rear.advance_time(8)
	assert_int(base.rear.military.squads.size()).is_equal(1)
	var squad: Dictionary = base.rear.military.squads.values()[0]
	assert_str(squad.state).is_equal("Active")
	assert_bool(base.rear.military.request_need("Artillery","HQ requires field guns").ok).is_true()
	var bar: TabBar = (demo.get("tabs") as TabContainer).get_tab_bar()
	bar.ensure_tab_visible(7)
	await runner.simulate_frames(2)
	runner.set_mouse_position(bar.global_position+bar.get_tab_rect(7).get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	demo.call("_refresh")
	assert_int((demo.get("tabs") as TabContainer).current_tab).is_equal(7)
	var status: String = (demo.get("dispatch_status") as Label).text
	assert_str(status).contains("Army command")
	assert_str(status).contains("Rifle Active")
	assert_str(status).contains("4 actual members")
	assert_str(status).contains("Shortage: Artillery")
	assert_array(base.audit()).is_empty()
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(3)
	var scroll: ScrollContainer = (demo.get("tabs") as TabContainer).get_child(7)
	scroll.scroll_vertical = int((demo.get("dispatch_status") as Label).position.y)
	await runner.simulate_frames(2)
	await RenderingServer.frame_post_draw
	var screenshot: Image = main.get_viewport().get_texture().get_image()
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/g15")).is_equal(OK)
	assert_int(screenshot.save_png("res://.artifacts/g15/dispatch_960x540.png")).is_equal(OK)
	scroll.scroll_vertical += 250
	await runner.simulate_frames(2)
	await RenderingServer.frame_post_draw
	assert_int(main.get_viewport().get_texture().get_image().save_png("res://.artifacts/g15/organization_960x540.png")).is_equal(OK)
	window.size = previous.size
	window.content_scale_size = previous.content
