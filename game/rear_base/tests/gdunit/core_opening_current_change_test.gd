extends GdUnitTestSuite
## Current opening/UI check, followed by a rear-only first-building component.
## Component elapsed time does not certify authored battlefield pacing or native FPS.
const Base = preload("res://game/rear_base/base_simulation.gd")
const RearScene = preload("res://game/rear_base/base_demo.tscn")
const HIRE := "Hire 8 workers · 140 requisition · 90 s travel"


func test_empty_opening_and_first_workshop_current_change(_timeout := 30000) -> void:
	var deadline: int = Time.get_ticks_msec()+25000
	var runner := scene_runner("res://game/main/main.tscn")
	var main := runner.scene() as Control
	await runner.simulate_frames(1)
	var view: Control = main.get("_base")
	var session: RefCounted = view.get("simulation")
	var rear: RefCounted = session.rear
	if not _require(session.empty_field_opening,"Main must launch the corrected empty-field opening."): return
	if not _require(view.visible and not main.get("_battlefield").visible,"Rear must be the initial play surface."): return
	if not _require(rear.actors.is_empty() and rear.construction.instances.is_empty(),"No hired workers or buildings may be granted at launch."): return
	if not _require(session.receiving.requisition_balance() == 2500,"Opening requisition must be 2500."): return
	var starter: Dictionary = rear.ledger.inspect_entity("start-supply-table-M11",{},false)
	if not _require(starter.get("quantity",0) == 500 and starter.get("holder_id","") == "receiving","500 real Building Materials must be at the Supply Table."): return
	var map: Control = view.get("base_map")
	if not _require(map.get("character_enabled"),"Rear character must be enabled."): return
	var origin: Vector2 = map.get("character_position")
	map.move_character(Vector2.RIGHT,0.1)
	if not _require(map.get("character_position").x > origin.x,"Character movement must change its actual map position."): return
	for title in ["Workers/Jobs","Supplies","Build"]:
		if not _require(view.show_panel(title),"Persistent panel unavailable: "+title): return
	var before_preview: Dictionary = rear.ledger.snapshot()
	view.select_build_kind("workshop")
	view.preview_build_at(Vector2(60,45))
	if not _require(map.get("placement_preview").get("ok",false),"First workshop location must preview successfully."): return
	map.placement_cancelled.emit()
	if not _require(not map.get("placement_active") and rear.construction.instances.is_empty(),"Cancel must clear placement without a site."): return
	assert_dict(rear.ledger.snapshot()).is_equal(before_preview)
	if not _press_hire(view.get("workforce_panel")): return
	if not _require(session.receiving.requisition_balance() == 2360,"Hire admission must debit exactly140 before time advances."): return
	if not _require(session.receiving.incoming_people() == 8 and rear.actors.is_empty(),"Purchase reserves eight incoming places without instant workers."): return
	print("CURRENT_OPENING_PASS: actual main, empty rear, 2500 requisition/500 Building Materials, movement, panels, read-only preview/cancel and UI hire admission.")
	# Keep the authored opening paused and stop its normal clock driver. Only the
	# separate rear component below advances through arrival and construction.
	view.set_process(false)
	main.hide()
	await _first_workshop(deadline)


func _first_workshop(deadline: int) -> void:
	var session: RefCounted = Base.new(false,false,false,Vector2(1640,91),false,{},true)
	var view: Control = auto_free(RearScene.instantiate())
	view.set("simulation",session)
	view.set_process(false)
	add_child(view)
	view._bind_started_session(false)
	if not _press_hire(view.get("workforce_panel")): return
	if not _require(session.receiving.requisition_balance() == 2360,"Rear component hire must debit140 immediately."): return
	if not _require(session.receiving.incoming_people() == 8 and session.rear.actors.is_empty(),"Component workers must first be incoming."): return
	# Advance the real rear services; retain ordinary requisition income and the
	# real supplier carrier, timed exits, walks and rear admission.
	session.rear.advance_time(120.0)
	if not _require(session.rear.actors.size() == 8 and session.receiving.incoming_people() == 0,"Eight real workers must disembark and join the pool."): return
	if not _require(session.receiving.rear_population() == 8,"Supplier driver must not join the rear population."): return
	view.show_panel("Workers/Jobs")
	view._refresh()
	var workforce: VBoxContainer = view.get("workforce_panel")
	workforce.controls.hauling.count.value = 4
	view.select_build_kind("workshop")
	view.confirm_build_at(Vector2(60,45))
	if not _require(session.rear.construction.instances.size() == 1,"UI placement must create one real workshop site."): return
	var id: String = session.rear.construction.instances.keys()[0]
	var duty := "builders-"+id
	if not _require(workforce.controls.has(duty),"New site must expose its pooled builder target."): return
	workforce.controls[duty].count.value = 4
	view.show_panel("Supplies")
	var finish_by: float = session.rear.time+600.0
	var steps := 0
	while session.rear.time < finish_by and Time.get_ticks_msec() < deadline and session.rear.construction.instances[id].state != "Complete":
		session.rear.advance_time(0.5)
		steps += 1
		if steps % 20 == 0: await get_tree().process_frame
	var site: Dictionary = session.rear.construction.instances[id]
	print("CURRENT_FIRST_BUILD_RESULT ",JSON.stringify({"time":session.rear.time,"state":site.state,"blocker":site.blocker,"progress":site.progress,"material_total":session.rear.ledger.total_stock("M11",session.rear.PLAYER)}))
	if not _require(site.state == "Complete","First workshop must finish inside the bounded rear component: "+str(site)): return
	if not _require(session.rear.ledger.total_stock("M11",session.rear.PLAYER) == 350,"Workshop must consume exactly150 real Building Materials."): return
	if not _require(session.rear.requests[duty].target == 0 and session.rear.requests[duty].positions == 0,"Completed site must release its builder request."): return
	if not _require(session.rear._assigned(duty) == 0,"Completed site must release actual builder assignments."): return
	if not _require(session.rear.construction.activities.has(id),"Completed workshop must register its real production activity."): return
	# Supplies deliberately leaves hidden selectors untouched. Clicking the
	# newly completed site must refresh Work before resolving that selection.
	view._select("site",id)
	if not _require(str(view.tabs.get_tab_control(view.tabs.current_tab).name) == "Work" and view._context_duty() == id,"Selecting a workshop after waiting in Supplies must open its current production context."): return
	if not _require(not workforce.controls.has(duty),"Retired builder job must leave the worker board."): return
	print("CURRENT_FIRST_BUILD_PASS: rear-only component, actual eight-worker purchase/disembark, UI hauling/builders, real150 Building Materials consumed, workshop completed and builders released. Production, shipping, authored battlefield timing and native FPS remain unverified.")


func _press_hire(node: Node) -> bool:
	var button := _button(node,HIRE)
	if not _require(button != null,"Direct hire8/full140/90s action must be present."): return false
	button.pressed.emit()
	return true


func _require(condition: bool, message: String) -> bool:
	assert_bool(condition).override_failure_message(message).is_true()
	return condition


func _button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found := _button(child,title)
		if found != null: return found
	return null
