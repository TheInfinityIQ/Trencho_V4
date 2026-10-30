extends GdUnitTestSuite

func test_recovery_destruction_repair_and_tow_controls_at_development_size() -> void:
	var window := get_tree().root
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/vehicle_recovery/recovery_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(3)
	var actions: HFlowContainer = demo.get_child(0).get_child(1)
	await _click(runner,actions.get_node("Destroycarrier"))
	var rear: RefCounted = demo.get("fixture").base.rear
	assert_int(rear.ledger.inspect_entity("healthy").health).is_equal(40)
	assert_str(rear.ledger.inspect_entity("incapacitated").assignment).is_equal("Dead")
	assert_str((demo.get("details") as Label).text).contains("wreck:carrier")
	await _capture(demo,"destruction")
	await _click(runner,actions.get_node("Repairscenario"))
	rear = demo.get("fixture").base.rear
	await _click(runner,actions.get_node("Healthrepair"))
	await _click(runner,actions.get_node("Advance20s"))
	await _click(runner,actions.get_node("Advance20s"))
	assert_int(rear.ledger.inspect_entity("tow").health).is_equal(1200)
	assert_bool(rear.ledger.inspect_entity("tow").damage_immobilized).is_true()
	await _click(runner,actions.get_node("Mobilityrepair"))
	await _click(runner,actions.get_node("Advance60s"))
	assert_bool(rear.ledger.inspect_entity("tow").damage_immobilized).is_false()
	await _capture(demo,"repaired")
	await _click(runner,actions.get_node("Reset"))
	rear = demo.get("fixture").base.rear
	await _click(runner,actions.get_node("Couple"))
	await _click(runner,actions.get_node("Advance20s"))
	assert_str(rear.ledger.inspect_entity("tractor").towing).is_equal("tow")
	await _click(runner,actions.get_node("CrossB03"))
	await _click(runner,actions.get_node("Advance60s"))
	await _click(runner,actions.get_node("Advance20s"))
	assert_float(rear.ledger.inspect_entity("tractor").position.x).is_equal(141.5)
	assert_float(rear.ledger.inspect_entity("tow").position.x).is_equal(129.5)
	assert_array(demo.get("fixture").base.audit()).is_empty()
	await _capture(demo,"towed")

func _click(runner: GdUnitSceneRunner, button: Button) -> void:
	runner.set_mouse_position(button.global_position+button.size*0.5)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()

func _capture(demo: Control, label: String) -> void:
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/g24")).is_equal(OK)
	assert_int(demo.get_viewport().get_texture().get_image().save_png("res://.artifacts/g24/"+label+"_1280x720.png")).is_equal(OK)
