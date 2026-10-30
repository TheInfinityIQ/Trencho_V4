extends GdUnitTestSuite

func test_combat_review_accepts_real_input_and_renders_state() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/combat/combat_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(3)
	var actions: HFlowContainer = demo.get_child(0).get_child(1)
	var fire: Button = actions.get_node("Fire")
	runner.set_mouse_position(fire.global_position+fire.size*0.5)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	assert_int(demo.get("simulation").rear.ledger.inspect_entity("g16-rifle").loaded_rounds).is_equal(0)
	assert_str((demo.get("details") as Label).text).contains("Demand g16-shooter")
	var casualty: Button = actions.get_node("Incapacitate")
	runner.set_mouse_position(casualty.global_position+casualty.size*0.5)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	assert_str((demo.get("details") as Label).text).contains("g16-patient | Wounded")
	var start: Button = actions.get_node("Startcare")
	runner.set_mouse_position(start.global_position+start.size*0.5)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	assert_str((demo.get("details") as Label).text).contains("pack committed g16-pack")
	assert_array(demo.get("simulation").audit()).is_empty()
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(2)
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/g16")).is_equal(OK)
	assert_int(demo.get_viewport().get_texture().get_image().save_png("res://.artifacts/g16/combat_960x540.png")).is_equal(OK)
	window.size = previous.size
	window.content_scale_size = previous.content
