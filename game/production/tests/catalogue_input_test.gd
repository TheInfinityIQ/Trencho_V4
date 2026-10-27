extends GdUnitTestSuite
## Full purchased-goods flow; no stock or staff injection to bypass controls.

func _expanded(runner: GdUnitSceneRunner, main: Control, demo: Control) -> void:
	assert_bool(demo.get("simulation").expanded_catalogue).is_false()
	await _choose(runner, demo.get("scenario"), 1)
	# Choosing a configuration alone never resets or grants access.
	assert_bool(demo.get("simulation").expanded_catalogue).is_false()
	await _press(runner, main, "Start new session")
	assert_bool(demo.get("simulation").expanded_catalogue).is_true()
	assert_dict(demo.get("simulation").rear.ledger.snapshot().created).is_empty()

func _purchase(runner: GdUnitSceneRunner, main: Control, demo: Control, cart: Dictionary) -> void:
	await _tab(runner, demo, 0)
	for code in cart: await _number(runner, demo.get("cart")[code], cart[code])
	await _press(runner, main, "Buy resources")
	assert_int(demo.get("simulation").receiving.freight_admitted()).is_equal(1)

func _staff(runner: GdUnitSceneRunner, demo: Control, targets: Dictionary) -> void:
	await _tab(runner, demo, 1)
	for duty in targets: await _number(runner, demo.get("targets")[duty], targets[duty])

func _hauls(runner: GdUnitSceneRunner, main: Control, demo: Control, rows: Array) -> void:
	await _tab(runner, demo, 2)
	var stores: Array = demo.get("simulation").rear.stores.keys()
	var goods: OptionButton = demo.get("goods_type")
	for row in rows:
		await _choose(runner, demo.get("source"), stores.find(row[0]))
		await _choose(runner, demo.get("destination"), stores.find(row[1]))
		var index := -1
		for item in goods.item_count:
			if goods.get_item_text(item) == row[2]: index = item
		assert_int(index).is_greater_equal(0)
		await _choose(runner, goods, index)
		await _number(runner, demo.get("haul_count"), row[3])
		await _press(runner, main, "Order haul")

func _recipe(runner: GdUnitSceneRunner, main: Control, demo: Control, facility: int, id: String, target: int) -> void:
	await _tab(runner, demo, 3)
	await _choose(runner, demo.get("facility"), facility)
	var option: OptionButton = demo.get("recipe")
	var index := -1
	for item in option.item_count:
		if option.get_item_metadata(item) == id: index = item
	assert_int(index).is_greater_equal(0)
	await _choose(runner, option, index)
	await _press(runner, main, "Select recipe")
	if demo.get("confirmation").visible: return
	await _choose(runner, demo.get("mode"), 0)
	await _number(runner, demo.get("stock_target"), target)
	await _press(runner, main, "Apply production order")

func _elapsed(runner: GdUnitSceneRunner, main: Control, base: RefCounted, seconds: float) -> void:
	await _press(runner, main, "1x")
	base.tick(seconds)
	await _press(runner, main, "Pause")

func test_expanded_session_nine_purchased_resources_multi_output_chain_and_actual_explosives_feed() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	var demo: Control = main.get("_host").get_child(0)
	await _expanded(runner, main, demo)
	var base: RefCounted = demo.get("simulation")
	await _purchase(runner, main, demo, {"M01":64,"M02":5,"M03":100,"M04":70,"M05":2,"M07":3,"M08":1,"M09":6,"M10":5})
	await _staff(runner,demo,{"receiving":1,"hauling":3,"workshop":2,"munitions":2,"support":2,"materials":2})
	await _recipe(runner,main,demo,0,"R03",1)
	await _recipe(runner,main,demo,1,"R27",10)
	await _recipe(runner,main,demo,3,"R11",1)
	await _recipe(runner,main,demo,2,"R26",100)
	await _hauls(runner,main,demo,[["receiving","workshop_input","M01",4],["receiving","workshop_input","M02",3],["receiving","support_input","M02",2],["receiving","support_input","M05",2],["receiving","support_input","M10",5],["receiving","munitions_input","M01",30],["receiving","munitions_input","M03",100],["receiving","materials_input","M01",30],["receiving","materials_input","M04",70]])
	await _elapsed(runner,main,base,1600)
	for row in [["E03",1],["E11",1],["M06",10],["M11",100]]: assert_int(base.rear.ledger.total_stock(row[0])).is_equal(row[1])
	await _tab(runner,demo,3)
	await _capture(runner,main,demo,"purchased_workshop_support_and_explosives")
	await _recipe(runner,main,demo,0,"R08",1)
	await _recipe(runner,main,demo,3,"R17",5)
	await _recipe(runner,main,demo,1,"R07",10)
	assert_dict(base.rear.munitions_production.batch).is_empty()
	await _hauls(runner,main,demo,[["munitions_output","munitions_input","M06",10]])
	await _elapsed(runner,main,base,300)
	for row in [["E03",1],["E08",1],["E11",1],["E17",5],["E07",10],["M11",100]]: assert_int(base.rear.ledger.total_stock(row[0])).is_equal(row[1])
	assert_int(base.rear.ledger.total_stock("M06")).is_zero()
	assert_int(base.rear.actors.size()).is_equal(12)
	assert_array(base.audit()).is_empty()
	window.size = Vector2i(960,640)
	window.content_scale_size = window.size
	await runner.simulate_frames(3)
	await _tab(runner,demo,3)
	await _choose(runner,demo.get("facility"),3)
	await _expose(demo.get("production_status"))
	await _capture(runner,main,demo,"small_connected_bombs_kits_and_batteries")
	var before: Dictionary = base.rear.ledger.snapshot()
	await _tab(runner,demo,0)
	await _choose(runner,demo.get("scenario"),0)
	await _tab(runner,demo,4)
	assert_dict(base.rear.ledger.snapshot()).is_equal(before)
	assert_bool(base.rear.support_production.recipe_accessible("R17")).is_true()
	window.size=previous.size
	window.content_scale_size=previous.content

func test_purchased_workshop_and_support_pending_changes_decline_confirm_and_retain_consumed_loss() -> void:
	var window := get_tree().root
	var previous := {"size":window.size,"content":window.content_scale_size}
	window.size=Vector2i(1280,720)
	window.content_scale_size=window.size
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(3)
	var demo: Control=main.get("_host").get_child(0)
	await _expanded(runner,main,demo)
	var base: RefCounted=demo.get("simulation")
	await _purchase(runner,main,demo,{"M01":4,"M02":2,"M05":4,"M10":5})
	await _staff(runner,demo,{"receiving":2,"hauling":4,"workshop":2,"support":2})
	await _recipe(runner,main,demo,0,"R03",1)
	await _press(runner,main,"Pause / resume facility")
	await _recipe(runner,main,demo,3,"R11",1)
	await _press(runner,main,"Pause / resume facility")
	await _hauls(runner,main,demo,[["receiving","workshop_input","M01",4],["receiving","workshop_input","M05",2],["receiving","support_input","M02",2],["receiving","support_input","M05",2],["receiving","support_input","M10",5]])
	await _elapsed(runner,main,base,600)
	await _recipe(runner,main,demo,0,"R03",1)
	await _press(runner,main,"Pause / resume facility")
	await _elapsed(runner,main,base,2)
	await _press(runner,main,"Pause / resume facility")
	var work: float=base.rear.production.batch.work
	assert_float(work).is_greater(0)
	await _recipe(runner,main,demo,0,"R04",1)
	assert_bool(demo.get("confirmation").visible).is_true()
	await _capture(runner,main,demo,"workshop_consumed_loss_confirmation")
	await _press(runner,main,"Cancel")
	assert_float(base.rear.production.batch.work).is_equal(work)
	await _recipe(runner,main,demo,0,"R04",1)
	await _press(runner,main,"OK")
	assert_str(base.rear.production.snapshot().recipe).is_equal("R04")
	await _recipe(runner,main,demo,3,"R11",1)
	await _press(runner,main,"Pause / resume facility")
	await _elapsed(runner,main,base,2)
	await _press(runner,main,"Pause / resume facility")
	window.size=Vector2i(960,640)
	window.content_scale_size=window.size
	await runner.simulate_frames(3)
	await _recipe(runner,main,demo,3,"R17",5)
	assert_bool(demo.get("confirmation").visible).is_true()
	await _capture(runner,main,demo,"small_support_consumed_loss_confirmation")
	await _press(runner,main,"Cancel")
	await _recipe(runner,main,demo,3,"R17",5)
	await _press(runner,main,"OK")
	await _elapsed(runner,main,base,100)
	assert_int(base.rear.ledger.total_stock("E03")).is_zero()
	assert_int(base.rear.ledger.total_stock("E11")).is_zero()
	assert_int(base.rear.ledger.total_stock("E04")).is_equal(1)
	assert_int(base.rear.ledger.total_stock("E17")).is_equal(5)
	assert_dict(base.rear.ledger.snapshot().consumed).is_equal({"M01":4,"M02":2,"M05":4,"M10":5})
	assert_str(base.rear.production.snapshot().recipe_records.R03.history[0].state).is_equal("Cancelled")
	assert_str(base.rear.support_production.snapshot().recipe_records.R11.history[0].state).is_equal("Cancelled")
	assert_array(base.audit()).is_empty()
	window.size=previous.size
	window.content_scale_size=previous.content

func _expose(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await get_tree().process_frame

func _number(runner: GdUnitSceneRunner, spin: SpinBox, number: int) -> void:
	await _expose(spin)
	await _click(runner, spin.get_line_edit().get_global_rect().get_center())
	runner.simulate_key_press(KEY_CTRL)
	await runner.simulate_key_pressed(KEY_A)
	runner.simulate_key_release(KEY_CTRL)
	for digit in str(number): await runner.simulate_key_pressed(digit.unicode_at(0))
	await runner.simulate_key_pressed(KEY_ENTER)
	await runner.await_input_processed()
	assert_int(int(spin.value)).is_equal(number)

func _choose(runner: GdUnitSceneRunner, option: OptionButton, index: int) -> void:
	await _expose(option)
	await _click(runner, option.get_global_rect().get_center())
	await runner.simulate_frames(2)
	var popup := option.get_popup()
	assert_bool(popup.visible).is_true()
	assert_bool(popup.is_embedded()).is_true()
	# Target the real embedded menu row. All these menus have uniform rows,
	# no separators; panel margins are smaller than half a row.
	var point := Vector2(popup.position) + Vector2(popup.size.x * 0.5, (index + 0.5) * popup.size.y / popup.item_count)
	await _click(runner, point)

	assert_int(option.selected).is_equal(index)

func _tab(runner: GdUnitSceneRunner, demo: Control, index: int) -> void:
	var bar: TabBar = demo.get("tabs").get_tab_bar()
	await _click(runner, bar.global_position + bar.get_tab_rect(index).get_center())
	await runner.simulate_frames(2)
	assert_int((demo.get("tabs") as TabContainer).current_tab).is_equal(index)

func _press(runner: GdUnitSceneRunner, root: Control, text: String) -> void:
	var matches: Array[Button] = []
	for button in root.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree(): matches.append(button)
	assert_int(matches.size()).is_equal(1)
	if matches.size() != 1: return
	await _expose(matches[0])
	var button := matches[0]
	var point := button.get_global_rect().get_center()
	if button.get_window() != get_tree().root and button.get_window().is_embedded(): point += Vector2(button.get_window().position)
	await _click(runner, point)

func _click(runner: GdUnitSceneRunner, point: Vector2) -> void:
	runner.set_mouse_position(point)
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()

func _capture(runner: GdUnitSceneRunner, main: Control, demo: Control, name: String) -> void:
	demo.call("_refresh")
	runner.set_mouse_position(main.size - Vector2(8, 8))
	await runner.await_input_processed()
	await runner.simulate_frames(3)
	_bounds(main)
	await RenderingServer.frame_post_draw
	var rendered: Image = main.get_viewport().get_texture().get_image()
	var output := "res://.artifacts/production-catalogue"
	assert_int(DirAccess.make_dir_recursive_absolute(output)).is_equal(OK)
	assert_int(rendered.save_png(output + "/" + name + ".png")).is_equal(OK)
	var file := FileAccess.open(output + "/" + name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"head": OS.get_environment("EVALUATION_HEAD"), "engine": Engine.get_version_info().string, "state": _json(demo.get("simulation").snapshot())}, "\t"))

func _json(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _json(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_json(item))
		return result
	return value

func _bounds(node: Node, scrolling: bool = false) -> void:
	if node is Control and node.is_visible_in_tree() and not scrolling:
		assert_bool(node.get_viewport_rect().grow(1).encloses(node.get_global_rect())).override_failure_message("Connected rear visible control fits: " + str(node.get_path())).is_true()
	for child in node.get_children(): _bounds(child, scrolling or node is ScrollContainer)
