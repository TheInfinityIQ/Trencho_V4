extends GdUnitTestSuite
## Finite UI preparation must preserve bindings, allocation and session identity.
const Base = preload("res://game/rear_base/base_simulation.gd")
const WorkerPanel = preload("res://game/rear_base/workforce_panel.gd")

func test_worker_rows_prepare_across_frames_and_replacement_cancels_old_bindings() -> void:
	var model := Base.new(true)
	var panel := WorkerPanel.new(model)
	add_child(panel)
	var before: Dictionary = model.rear.ledger.snapshot()
	panel.refresh(model.workforce_view())
	var previous := 0
	for _frame in 40:
		await get_tree().process_frame
		assert_int(panel.controls.size()-previous).is_between(0,1)
		previous = panel.controls.size()
		if panel._pending_rows.is_empty() and not panel._row_queued: break
	var expected: Array[String] = []
	for row in model.workforce_view().rear.staffing:
		if row.positions > 0:
			expected.append(row.id)
			assert_bool(panel.controls.has(row.id)).is_true()
			if panel.controls.has(row.id): assert_float(panel.controls[row.id].count.max_value).is_equal(float(row.positions))
	assert_int(panel.controls.size()).is_equal(expected.size())
	assert_bool(panel._row_queued).is_false()
	assert_dict(model.rear.ledger.snapshot()).is_equal(before)
	var replacement := Base.new(false,false,false,Vector2(1640,91),false,{},true)
	# Cancel one generation while its next row is still queued.
	panel.bind(model)
	panel.refresh(model.workforce_view())
	panel.bind(replacement)
	var replacement_before: Dictionary = replacement.rear.ledger.snapshot()
	panel.refresh(replacement.workforce_view())
	for _frame in 8: await get_tree().process_frame
	assert_bool(panel.controls.has("receiving")).is_true()
	assert_bool(panel.controls.has("hauling")).is_true()
	assert_bool(panel.controls.has("workshop")).is_false()
	assert_bool(panel._row_queued).is_false()
	assert_dict(replacement.rear.ledger.snapshot()).is_equal(replacement_before)
	assert_dict(model.rear.ledger.snapshot()).is_equal(before)
	panel.queue_free()
	await get_tree().process_frame
