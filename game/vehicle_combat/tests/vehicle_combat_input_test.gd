extends GdUnitTestSuite

func test_vehicle_combat_review_accepts_mouse_input_and_renders_real_hulls() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/vehicle_combat/vehicle_combat_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(3)
	var actions: HFlowContainer = demo.get_child(0).get_child(1)
	await _click(runner,actions.get_node("Fire"))
	assert_int(demo.get("simulation").rear.ledger.inspect_entity("review-apc").ammunition.E26).is_equal(19)
	assert_int(demo.get("simulation").rear.ledger.inspect_entity("review-tank").health).is_equal(1200)
	await _click(runner,actions.get_node("Advance2s"))
	assert_str((demo.get("details") as Label).text).contains("Front")
	assert_int(demo.get("simulation").rear.ledger.inspect_entity("review-tank").health).is_equal(1200)
	await _click(runner,actions.get_node("Flankandaim"))
	await _click(runner,actions.get_node("Advance3s"))
	assert_str((demo.get("details") as Label).text).contains("struck tank surface: Rear")
	for i in 6:
		await _click(runner,actions.get_node("Fire"))
		await _click(runner,actions.get_node("Advance2s"))
		if demo.get("simulation").rear.ledger.inspect_entity("review-tank").health < 1200: break
	assert_int(demo.get("simulation").rear.ledger.inspect_entity("review-tank").health).is_less(1200)
	assert_int(demo.get("simulation").rear.ledger.inspect_entity("review-apc").ammunition.E26).is_less(19)
	assert_array(demo.get("simulation").audit()).is_empty()
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(2)
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/g23")).is_equal(OK)
	assert_int(demo.get_viewport().get_texture().get_image().save_png("res://.artifacts/g23/vehicle_combat_960x540.png")).is_equal(OK)
	window.size = previous.size
	window.content_scale_size = previous.content

func _click(runner: GdUnitSceneRunner, button: Button) -> void:
	runner.set_mouse_position(button.global_position+button.size*0.5)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
