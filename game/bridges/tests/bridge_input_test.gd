extends GdUnitTestSuite

func test_bridge_delivery_traversal_damage_and_small_render() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/bridges/bridge_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(3)
	var actions: HFlowContainer = demo.get_child(0).get_child(1)
	var rear: RefCounted = demo.get("simulation").rear
	var id: String = demo.get("bridge_id")
	await _click(runner,actions.get_node("Advance100s"))
	assert_float(rear.bridges.inspect(id).progress).is_zero()
	await _click(runner,actions.get_node("StagearrivedM11"))
	assert_int(rear.bridges.inspect(id).m11_consumed).is_equal(2400)
	await _click(runner,actions.get_node("Advance300s"))
	assert_str(rear.bridges.inspect(id).state).is_equal("Complete")
	await _click(runner,actions.get_node("Queueequippedperson"))
	assert_int(rear.bridges.inspect(id).traffic.size()).is_equal(1)
	await _click(runner,actions.get_node("Advancecrossing"))
	assert_float(rear.ledger.inspect_entity("review-walker").position.x).is_greater(140.0)
	await _click(runner,actions.get_node("Damagetohalf"))
	assert_float(rear.bridges.inspect(id).effective_load_kg).is_equal(40000.0)
	assert_float(rear.bridges.inspect(id).speed_cap_mps).is_equal(2.0)
	await _click(runner,actions.get_node("Repair100"))
	assert_float(rear.bridges.inspect(id).effective_load_kg).is_equal(80000.0)
	assert_array(demo.get("simulation").audit()).is_empty()
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(2)
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/g20")).is_equal(OK)
	assert_int(demo.get_viewport().get_texture().get_image().save_png("res://.artifacts/g20/bridge_960x540.png")).is_equal(OK)
	window.size = previous.size
	window.content_scale_size = previous.content

func _click(runner: GdUnitSceneRunner, button: Button) -> void:
	runner.set_mouse_position(button.global_position+button.size*0.5)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
