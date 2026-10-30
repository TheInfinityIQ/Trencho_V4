extends GdUnitTestSuite

func test_field_review_delivery_work_and_small_render() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/field_structures/field_demo.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(3)
	var actions: HFlowContainer = demo.get_child(0).get_child(1)
	await _click(runner,actions.get_node("Advance100s"))
	var rear: RefCounted = demo.get("simulation").rear
	var site_id: String = demo.get("site_id")
	assert_float(rear.field_structures.inspect(site_id).progress).is_zero()
	assert_str((demo.get("details") as Label).text).contains("300 missing")
	await _click(runner,actions.get_node("StagearrivedM11"))
	assert_int(rear.field_structures.inspect(site_id).m11_consumed).is_equal(300)
	for i in 4: await _click(runner,actions.get_node("Advance100s"))
	assert_str(rear.field_structures.inspect(site_id).state).is_equal("Complete")
	assert_array(rear.field_structures.inspect(site_id).occupants).is_empty()
	await _click(runner,actions.get_node("Enterbunker"))
	assert_array(rear.field_structures.inspect(site_id).occupants).contains(["review-engineer"])
	assert_array(demo.get("simulation").audit()).is_empty()
	window.size = Vector2i(960,540)
	window.content_scale_size = window.size
	await runner.simulate_frames(2)
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute("res://.artifacts/g19")).is_equal(OK)
	assert_int(demo.get_viewport().get_texture().get_image().save_png("res://.artifacts/g19/field_960x540.png")).is_equal(OK)
	window.size = previous.size
	window.content_scale_size = previous.content

func _click(runner: GdUnitSceneRunner, button: Button) -> void:
	runner.set_mouse_position(button.global_position+button.size*0.5)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
