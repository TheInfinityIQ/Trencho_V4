extends GdUnitTestSuite

func test_a37_a38_buttons_at_development_resolution() -> void:
	var window := get_tree().root
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/mines/mine_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(3)
	var rear: RefCounted = demo.get("simulation").rear
	var actions: HFlowContainer = demo.get_child(0).get_node("Actions")
	await click(runner,actions.get_node("OrderD02"))
	await click(runner,actions.get_node("Place12s"))
	assert_float(rear.mines.inspect(demo.get("device_id")).progress).is_zero()
	await click(runner,actions.get_node("Deliver3M06"))
	await click(runner,actions.get_node("Place12s"))
	assert_str(rear.mines.inspect(demo.get("device_id")).state).is_equal("Arming")
	await click(runner,actions.get_node("Arm10s"))
	assert_str(rear.mines.inspect(demo.get("device_id")).state).is_equal("Armed")
	await click(runner,actions.get_node("Drivetank"))
	assert_int(rear.ledger.inspect_entity("review-tank").health).is_equal(550)
	assert_bool(rear.ledger.inspect_entity("review-tank").damage_immobilized).is_true()
	assert_str(rear.mines.inspect(demo.get("device_id")).state).is_equal("Detonated")
	assert_array(demo.get("simulation").audit()).is_empty()
	await screenshot(demo,"a37_trigger")
	await click(runner,actions.get_node("Reset"))
	rear = demo.get("simulation").rear
	for name in ["OrderD02","Deliver3M06","Place12s","Arm10s","Scan3s"]: await click(runner,actions.get_node(name))
	assert_int(rear.mines.inspect_known("army-red").size()).is_equal(1)
	assert_str(rear.mines.route_blocker("army-red",[demo.SITE-Vector2(50,0),demo.SITE+Vector2(50,0)])).is_not_empty()
	await click(runner,actions.get_node("Disarm12s"))
	assert_str(rear.mines.inspect(demo.get("device_id")).state).is_equal("Inert")
	assert_int(rear.ledger.total_stock("M06")).is_zero()
	assert_str(rear.mines.route_blocker("army-red",[demo.SITE-Vector2(50,0),demo.SITE+Vector2(50,0)])).is_empty()
	assert_array(demo.get("simulation").audit()).is_empty()
	await screenshot(demo,"a38_cleared")

func click(runner: GdUnitSceneRunner, button: Button) -> void:
	runner.set_mouse_position(button.global_position+button.size*0.5)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	await runner.simulate_frames(2)

func screenshot(demo: Control, label: String) -> void:
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/g22")).is_equal(OK)
	assert_int(demo.get_viewport().get_texture().get_image().save_png("res://.artifacts/g22/"+label+"_1280x720.png")).is_equal(OK)
