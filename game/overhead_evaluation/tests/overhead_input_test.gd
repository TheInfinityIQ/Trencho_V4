extends GdUnitTestSuite
## Genuine Godot viewport exports under CI Xvfb, never labelled native screenshots.


func test_selection_zoom_and_text_preserve_physical_samples_and_render_six_views() -> void:
	var window := get_tree().root
	var old_size := window.size
	var old_content_size := window.content_scale_size
	window.size = Vector2i(1600, 1000)
	window.content_scale_size = Vector2i(1600, 1000)
	var runner := scene_runner("res://game/overhead_evaluation/overhead_evaluation.tscn")
	var demo := runner.scene() as Control
	await runner.simulate_frames(3)
	var physical: Dictionary = demo.physical_snapshot()
	assert_vector(physical.extent).is_equal(Vector2(4000, 6000))
	assert_vector(physical.samples[0].size).is_equal(Vector2(16, 12))
	assert_vector(physical.samples[1].size).is_equal(Vector2(6.8, 2.5))
	assert_vector(physical.samples[2].size).is_equal(Vector2.ONE)
	assert_int(physical.samples[1].cargo).is_equal(100)
	var position: Vector2 = demo.canvas.global_position + demo.screen_for(Vector2(1017, 3010))
	runner.set_mouse_position(position)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	assert_str(demo.selected_id).is_equal("sample-t02-01")
	var output := "res://.artifacts/d01-overhead"
	assert_int(DirAccess.make_dir_recursive_absolute(output)).is_equal(OK)
	var captures: Array = []
	for factor in [100, 150]:
		await _press(runner, demo, "Text %d%%" % factor)
		for view in ["Close", "Intermediate", "6 km overview"]:
			await _press(runner, demo, view)
			await runner.simulate_frames(3)
			assert_dict(demo.physical_snapshot()).is_equal(physical)
			assert_str(demo.selected_id).is_equal("sample-t02-01")
			_visible_bounds(demo)
			assert_str((demo.get("_inspection") as Label).text).contains("sample-t02-01")
			if view == "6 km overview":
				var full_map := Rect2(demo.screen_for(Vector2.ZERO), physical.extent * demo.camera().pixels_per_metre)
				assert_bool(Rect2(Vector2.ZERO, demo.canvas.size).encloses(full_map)).is_true()
			await RenderingServer.frame_post_draw
			var image: Image = demo.get_viewport().get_texture().get_image()
			assert_vector(image.get_size()).is_equal(Vector2i(1600, 1000))
			assert_bool(image.get_pixel(0, 0) != image.get_pixel(int(demo.canvas.global_position.x + 5), int(demo.canvas.global_position.y + 5))).is_true()
			var stem: String = "overview" if view == "6 km overview" else view.to_lower()
			var filename := "%s_%d.png" % [stem, factor]
			assert_int(image.save_png(output + "/" + filename)).is_equal(OK)
			var metadata: Dictionary = demo.render_metadata()
			metadata.image = filename
			metadata.viewport_px = [image.get_width(), image.get_height()]
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(image.get_data())
			metadata.pixel_sha256 = digest.finish().hex_encode()
			metadata.engine = Engine.get_version_info().string
			metadata.revision = OS.get_environment("EVALUATION_HEAD")
			captures.append(metadata)
	var file := FileAccess.open(output + "/views.json", FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file != null: file.store_string(JSON.stringify(captures, "\t") + "\n")
	window.size = old_size
	window.content_scale_size = old_content_size


func _press(runner: GdUnitSceneRunner, demo: Control, title: String) -> void:
	for node in demo.find_children("*", "Button", true, false):
		if node.text == title:
			runner.set_mouse_position(node.get_global_rect().get_center())
			await runner.await_input_processed()
			runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			await runner.await_input_processed()
			return
	fail("Missing actual evaluation button: " + title)

func _visible_bounds(node: Node) -> void:
	if node is Control and node.is_visible_in_tree():
		assert_bool(node.get_viewport_rect().grow(1).encloses(node.get_global_rect())).override_failure_message("Visible evaluation control fits render: %s; bounds %s; viewport %s" % [node.get_path(), node.get_global_rect(), node.get_viewport_rect()]).is_true()
	for child in node.get_children(): _visible_bounds(child)
