extends GdUnitTestSuite

func test_a36_real_buttons_clearance_and_small_render() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/bridges/demolition_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(3)
	var actions: HFlowContainer = demo.get_child(0).get_child(1)
	var rear: RefCounted = demo.get("simulation").rear
	var bridge_id: String = demo.get("bridge_id")
	await _click(runner,actions.get_node("OrderD04"))
	var id: String = demo.get("demolition_id")
	assert_int(rear.demolition.inspect(id).m06_reserved).is_equal(14)
	await _click(runner,actions.get_node("Place19s"))
	assert_float(rear.demolition.inspect(id).progress).is_zero()
	await _click(runner,actions.get_node("Stage14M06"))
	await _click(runner,actions.get_node("Place19s"))
	assert_str(rear.demolition.inspect(id).state).is_equal("Placed")
	assert_int(rear.demolition.inspect(id).m06_consumed).is_equal(14)
	await _click(runner,actions.get_node("Withdraw"))
	await _click(runner,actions.get_node("Arm10s"))
	assert_str(rear.demolition.inspect(id).state).is_equal("Armed")
	await _click(runner,actions.get_node("Authorize"))
	await _click(runner,actions.get_node("Choosefuse"))
	await _click(runner,actions.get_node("Friendlyenters"))
	await _click(runner,actions.get_node("Startfuse"))
	assert_str(rear.demolition.inspect(id).state).is_equal("Armed")
	assert_int(rear.bridges.inspect(bridge_id).health).is_equal(7000)
	await _click(runner,actions.get_node("Friendlyclears"))
	await _click(runner,actions.get_node("Startfuseagain"))
	await _click(runner,actions.get_node("Advance5s"))
	assert_str(rear.bridges.inspect(bridge_id).state).is_equal("Destroyed")
	assert_int(rear.bridges.inspect(bridge_id).health).is_zero()
	assert_array(demo.get("simulation").audit()).is_empty()
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(2)
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/g21")).is_equal(OK)
	assert_int(demo.get_viewport().get_texture().get_image().save_png("res://.artifacts/g21/a36_destroyed_960x540.png")).is_equal(OK)
	window.size = previous.size
	window.content_scale_size = previous.content

func _click(runner: GdUnitSceneRunner, button: Button) -> void:
	runner.set_mouse_position(button.global_position+button.size*0.5)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
