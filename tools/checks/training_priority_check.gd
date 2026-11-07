extends SceneTree
## Actual school and UI command ownership; not a physical teacher/course or FPS check.
const Session = preload("res://game/main/game_session.gd")
const Model = preload("res://game/rear_base/base_simulation.gd")
const BaseScene = preload("res://game/rear_base/base_demo.tscn")

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
	var session := Session.new()
	root.add_child(session)
	session.set_physics_process(false)
	var model := Model.new(false,false,false,Vector2(1640,91),false,{},true)
	session.replace_simulation(model)
	session.automatic_logistics.set_process(false)
	var rear: RefCounted = model.rear
	if not _require(model.receiving.buy_people().ok and rear.set_target("hauling",2,2).ok,"Purchase real workers and request material hauling."): return
	var placed: Dictionary = rear.construction.place("training",Vector2(70,65))
	if not _require(placed.ok and rear.construction.set_builders(placed.id,2).ok,"Place an actual school and request builders."): return
	rear.advance_time(1800)
	if not _require(rear.construction.instances[placed.id].state == "Complete","Actual materials and builders must complete the school."): return
	var ui: Control = BaseScene.instantiate()
	ui.session = session
	root.add_child(ui)
	ui.show_panel("Workers/Jobs")
	await _frames(60)
	if not _require(ui.workforce_panel.controls.has(placed.id),"The actual school must have normal Jobs controls."): return
	var priority: OptionButton = ui.workforce_panel.controls[placed.id].priority
	priority.select(3)
	priority.item_selected.emit(3)
	ui.show_panel("Train")
	await _frames()
	if not _require(ui._training_duty() == placed.id and rear.requests[placed.id].priority == 3,"Training must select the current actual school's chosen priority."): return
	for target in [2,0,1]:
		ui.instructor_count.value = target
		if not _require(rear.requests[placed.id].target == target and rear.requests[placed.id].priority == 3,"Changing Instructor target must preserve the player's school priority."): return
		await _frames()
	if not _require(model.audit().is_empty(),"UI count edits must preserve physical/accounting invariants."): return
	ui.queue_free()
	session.queue_free()
	await _frames()
	print(JSON.stringify({"result":"PASS","scope":"Purchased workers, actual school construction, normal Jobs priority and Training count edits preserving the current request priority. Isolated component; no actual teacher/course, connected demo, native input or FPS claim."}))
	quit(0)
