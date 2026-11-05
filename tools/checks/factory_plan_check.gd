extends SceneTree
## Brief direct demonstration of the new factory plan; explicit stepping is not FPS evidence.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Session = preload("res://game/main/game_session.gd")
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
const VIEW_COUNTER := "rear_base/factory_plan.gd::view"

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _frames(count: int = 3) -> void:
	for _frame in count: await process_frame

func _run() -> void:
	if not _require(ResourceLoader.exists("res://game/rear_base/factory_plan.gd"),"Factory plan projection has not been implemented."): return
	if not _require(ResourceLoader.exists("res://game/rear_base/factory_plan_panel.gd"),"Factory plan panel has not been implemented."): return
	var Plan = load("res://game/rear_base/factory_plan.gd")
	var Panel = load("res://game/rear_base/factory_plan_panel.gd")
	CallLog.enabled = true
	CallLog.capture_stacks = false
	var model := Base.new(false,false,false,Vector2(1640,91),false,{},true)
	var rear: RefCounted = model.rear
	var before: Dictionary = rear.ledger.snapshot(false)
	var opening: Dictionary = Plan.view(model)
	if not _require(not opening.complete and opening.workers.present == 0,"Starting materials and an empty field must not count as completed manufacturing."): return
	if not _require(opening.steps.size() == 5 and not opening.next_action.label.is_empty(),"The factory task must expose its five steps and an actionable next step."): return
	if not _require(rear.ledger.snapshot(false) == before,"Reading the factory plan must preserve authoritative physical state."): return
	var session := Session.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.replace_simulation(model)
	var panel: VBoxContainer = Panel.new()
	root.add_child(panel)
	panel.bind(session)
	await _frames()
	var calls: int = CallLog.totals().get(VIEW_COUNTER,0)
	await _frames(8)
	if not _require(int(CallLog.totals().get(VIEW_COUNTER,0)) == calls,"A quiet factory plan must not poll on idle frames."): return
	session.notify_command()
	session.notify_command()
	session.notify_command()
	await _frames()
	if not _require(int(CallLog.totals().get(VIEW_COUNTER,0)) == calls+1,"A committed-event burst must coalesce into one plan read."): return
	panel.hide()
	await _frames()
	calls = CallLog.totals().get(VIEW_COUNTER,0)
	session.notify_command()
	await _frames()
	if not _require(int(CallLog.totals().get(VIEW_COUNTER,0)) == calls,"A hidden factory plan must defer model reads until shown."): return
	panel.show()
	await _frames()
	if not _require(int(CallLog.totals().get(VIEW_COUNTER,0)) == calls+1,"Showing the plan must read fresh authoritative facts."): return
	# Physical construction and manufacture through existing commands; no grants,
	# shortened recipes or fake progress. This is explicit component time.
	if not _require(model.receiving.buy_people().ok,"The approved opening must admit its actual worker purchase."): return
	if not _require(model.receiving.buy_resources({"M01":31,"M04":70,"M03":1}).ok,"Actual factory ingredients must be purchased."): return
	if not _require(rear.set_target("receiving",2,2).ok and rear.set_target("hauling",2,2).ok,"Existing receiving and hauling requests must remain usable."): return
	var materials: Dictionary = rear.construction.place("materials",Vector2(65,55))
	var ammunition: Dictionary = rear.construction.place("munitions",Vector2(120,100))
	if not _require(materials.ok and ammunition.ok,"Both actual factory sites must be admitted from starting materials."): return
	if not _require(rear.construction.set_builders(materials.id,2).ok and rear.construction.set_builders(ammunition.id,2).ok,"Real builders must be requested for both sites."): return
	model.set_speed(1)
	session.notify_command()
	for _second in 1800:
		rear.advance_time(1.0)
		await process_frame
		if _second == 899: print("FACTORY_CHECKPOINT " + JSON.stringify({"simulation_seconds":rear.time,"materials":rear.construction.instances[materials.id].state,"munitions":rear.construction.instances[ammunition.id].state}))
		if rear.construction.instances[materials.id].state == "Complete" and rear.construction.instances[ammunition.id].state == "Complete": break
	if not _require(rear.construction.activities.has(materials.id) and rear.construction.activities.has(ammunition.id),"Physical construction must create actual production owners."): return
	var material_activity: RefCounted = rear.construction.activities[materials.id]
	var ammo_activity: RefCounted = rear.construction.activities[ammunition.id]
	if not _require(material_activity.set_stock_target(100).ok and ammo_activity.set_stock_target(100).ok,"Actual factory output targets must be accepted."): return
	if not _require(rear.set_target(materials.id,2).ok and rear.set_target(ammunition.id,2).ok,"Actual factory operators must report after construction."): return
	var covered: Dictionary = Plan.view(model)
	if not _require(covered.facilities.materials.target_covered and covered.next_action.facility_id == materials.id,"Starting material coverage must be explained as a covered minimum, not falsely counted as manufactured output."): return
	if not _require(material_activity.set_stock_target(int(material_activity.stock_coverage(false).projected)+100).ok,"Request new materials above existing stock coverage using the real production command."): return
	session.notify_command()
	for _second in 1800:
		rear.advance_time(1.0)
		await process_frame
		if not material_activity.history.is_empty() and not ammo_activity.history.is_empty(): break
	var completed: Dictionary = Plan.view(model)
	if not _require(completed.complete,"Factory completion must follow actual completed material and ammunition batches."): return
	if not _require(rear.ledger.available_stock_at(material_activity._spec.output_store,"M11") == 100 and rear.ledger.available_stock_at(ammo_activity._spec.output_store,"E02") == 100,"Plan completion must correspond to physically manufactured output."): return
	if not _require(model.audit().is_empty(),"The direct factory task must preserve physical ledger invariants."): return
	var replacement := Session.new()
	root.add_child(replacement)
	replacement.set_physics_process(false)
	replacement.replace_simulation(Base.new(false,false,false,Vector2(1640,91),false,{},true))
	panel.bind(replacement)
	await _frames()
	if not _require(not panel.view.complete,"Binding a new session must not retain old factory completion."): return
	calls = CallLog.totals().get(VIEW_COUNTER,0)
	session.notify_command()
	await _frames()
	if not _require(int(CallLog.totals().get(VIEW_COUNTER,0)) == calls,"Old session events must be disconnected after rebinding."): return
	panel.queue_free()
	session.queue_free()
	replacement.queue_free()
	await _frames()
	# Confirm ordinary main-scene integration separately from component stepping.
	var game: Control = load("res://game/main/main.tscn").instantiate()
	root.add_child(game)
	game._session.set_physics_process(false)
	game._base.show_panel("Work")
	await _frames()
	if not _require(game._base.factory_plan_panel.is_visible_in_tree() and game._base.factory_plan_panel.view.steps.size() == 5,"Ordinary Production navigation must expose the integrated factory task."): return
	game.queue_free()
	await _frames()
	print(JSON.stringify({"result":"PASS","scope":"New factory plan: pure opening read, signal/visibility lifecycle, actual construction and two manufactured outputs, rebinding and ordinary main-scene integration. Explicit component stepping; no native-input/FPS or whole-demo acceptance."}))
	quit(0)
