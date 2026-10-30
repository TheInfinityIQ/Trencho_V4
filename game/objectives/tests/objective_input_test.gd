extends GdUnitTestSuite

func test_objective_review_real_dismount_input_and_small_render() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/objectives/objective_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(3)
	var actions: HFlowContainer = demo.get_child(0).get_child(1)
	for name in ["Advance15s","Dismount","Advance15s"]:
		var button: Button = actions.get_node(name)
		runner.set_mouse_position(button.global_position+button.size*0.5)
		await runner.await_input_processed()
		runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		await runner.await_input_processed()
	var rear: RefCounted = demo.get("simulation").rear
	assert_float(rear.objectives.inspect("g18-resource").control).is_equal(60.0)
	assert_str((demo.get("details") as Label).text).contains("owner army-blue")
	assert_array(demo.get("simulation").audit()).is_empty()
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(2)
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/g18")).is_equal(OK)
	assert_int(demo.get_viewport().get_texture().get_image().save_png("res://.artifacts/g18/objectives_960x540.png")).is_equal(OK)
	window.size = previous.size
	window.content_scale_size = previous.content
