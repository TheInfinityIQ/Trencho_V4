extends GdUnitTestSuite

func test_orders_review_real_input_and_small_render() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/orders/order_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(3)
	var actions: HFlowContainer = demo.get_child(0).get_child(1)
	for name in ["Observe","Advance2s","Planflank","Spendfixingammo","Advance2s"]:
		var button: Button = actions.get_node(name)
		runner.set_mouse_position(button.global_position+button.size*0.5)
		await runner.await_input_processed()
		runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		await runner.await_input_processed()
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(2)
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/g17")).is_equal(OK)
	assert_int(demo.get_viewport().get_texture().get_image().save_png("res://.artifacts/g17/orders_960x540.png")).is_equal(OK)
	assert_str((demo.get("details") as Label).text).contains("Paused")
	assert_str((demo.get("details") as Label).text).contains("E02")
	assert_array(demo.get("simulation").audit()).is_empty()
	window.size = previous.size
	window.content_scale_size = previous.content
