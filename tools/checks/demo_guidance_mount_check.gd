extends SceneTree
## Brief paused actual-main UI check; no physical progression or native rendering claim.
const Main = preload("res://game/main/main.tscn")
const Guidance = preload("res://game/ui/demo_guidance.gd")
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
const COUNTER := "ui/demo_guidance.gd::view"
var _checks := 0
var _actions: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _frames(count: int = 4) -> void:
	for _frame in count: await process_frame

func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child in node.get_children():
		var found := _button(child,caption)
		if found != null: return found
	return null

func _capture(action: String) -> void:
	_actions.append(action)

func _destination(base: Control) -> String:
	var panel: Control = base.tabs.get_tab_control(base.tabs.current_tab)
	return str(panel.get_meta("panel_title",panel.name))

func _run() -> void:
	CallLog.enabled = true
	CallLog.capture_stacks = false
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	var main: Control = Main.instantiate()
	root.add_child(main)
	var session: Node = main._session
	# Ordinary main boot and paused model; stop its pump for bounded UI-only observations.
	session.set_physics_process(false)
	var shell: Control = main._shell
	var base: Control = main._base
	var guide: VBoxContainer = shell.demo_guidance_panel
	shell.navigation_requested.connect(_capture)
	await _frames()
	if not _require(session.simulation.speed == 0 and guide._session == session and not shell._help.visible,"One guide must bind the actual paused main session and start optional/hidden."): return
	var calls: int = CallLog.totals().get(COUNTER,0)
	session.notify_command()
	session.automatic_logistics.changed.emit()
	await _frames()
	if not _require(int(CallLog.totals().get(COUNTER,0)) == calls,"Hidden mounted guide must not read on state/logistics events."): return
	var ledger: Dictionary = session.simulation.rear.ledger.snapshot(false)
	var requests: Dictionary = session.simulation.rear.requests.duplicate(true)
	var courses: Array = session.simulation.rear.training.rows.duplicate(true)
	var target: float = base._activity().stock_target
	var time: float = session.simulation.rear.time
	_button(shell,"Getting started").pressed.emit()
	await _frames()
	if not _require(guide.view.next_action.panel == "Workers/Jobs" and not guide._summary.visible and not guide._primary.disabled,"Ordinary Getting started must offer current opening worker action with collapsed overview."): return
	if not _require(guide.view.army_status.contains("No current rear ammunition shortfall") and guide._reason.text.contains("paused"),"Opening guidance must preserve actual HQ coverage and explain pause."): return
	guide._primary.pressed.emit()
	await _frames()
	if not _require(_actions == ["Workers/Jobs"] and _destination(base) == "Workers/Jobs","Opening action must emit once and reach actual worker destination."): return
	for entry in [["Open Training","Train"],["Open Vehicles","Vehicles"],["Review Army needs","ArmyNeeds"]]:
		var previous := _actions.size()
		_button(guide,entry[0]).pressed.emit()
		await _frames()
		if not _require(_actions.size() == previous+1 and _actions.back() == entry[1] and _destination(base) == entry[1],"One link must reach actual destination: "+entry[1]): return
		if entry[1] == "Train" and not _require(base.instructor_hire_button.visible and base.instructor_hire_button.text.contains("Hire instructor"),"Training destination must expose primary instructor hire, without executing it."): return
	# Draft values are deliberately unsubmitted UI inputs, not fabricated world facilities/output.
	shell.navigation_requested.emit("Work")
	await _frames()
	base.stock_target.set_value_no_signal(237)
	base.mode.select(1)
	base.cart.M01.set_value_no_signal(17)
	var selected_kind: String = base._selected_kind
	var selected_id: String = base._selected_id
	var selected_facility: int = base.facility.selected
	var selected_recipe: int = base.recipe.selected
	for destination in ["Work","Supplies","Train","Vehicles","ArmyNeeds","Work"]:
		shell.navigation_requested.emit(destination)
		await _frames()
	if not _require(base.stock_target.value == 237 and base.mode.selected == 1 and base.cart.M01.value == 17 and base.recipe.selected == selected_recipe and base.facility.selected == selected_facility,"Existing navigation and same-destination navigation must preserve unsubmitted production/cart drafts."): return
	if not _require(base._selected_kind == selected_kind and base._selected_id == selected_id,"Panel links must preserve actual selected context."): return
	if not _require(session.simulation.rear.ledger.snapshot(false) == ledger and session.simulation.rear.requests == requests and session.simulation.rear.training.rows == courses and base._activity().stock_target == target and session.simulation.rear.time == time and session.simulation.speed == 0,"Paused help/navigation must not buy, assign, set targets, create courses or advance time."): return
	guide._overview.pressed.emit()
	await _frames()
	calls = CallLog.totals().get(COUNTER,0)
	session.notify_command()
	session.notify_command()
	session.automatic_logistics.changed.emit()
	await _frames()
	if not _require(int(CallLog.totals().get(COUNTER,0)) == calls+1 and guide._summary.visible,"Visible event burst must coalesce and preserve expanded overview."): return
	calls += 1
	await _frames(6)
	if not _require(int(CallLog.totals().get(COUNTER,0)) == calls,"Mounted guide must not poll quiet frames."): return
	_button(shell._help,"Close").pressed.emit()
	session.notify_command()
	session.automatic_logistics.changed.emit()
	await _frames()
	if not _require(not shell._help.visible and int(CallLog.totals().get(COUNTER,0)) == calls,"Close must hide help and suppress event reads."): return
	_button(shell,"Getting started").pressed.emit()
	await _frames()
	if not _require(guide._summary.visible and not guide._primary.disabled,"Reopen must restore expanded overview with fresh action."): return
	# Detached first-instructor selector inputs isolate the approved route migration.
	var first := Guidance._next({"complete":true},{"training":{"state":"Complete"}},{"crew":0,"basic":0,"instructors":0},{"trips":0,"driven":0},{})
	if not _require(first.panel == "Train" and first.reason.contains("Hire instructor"),"First-instructor guidance must use current primary Training hire route."): return
	var scroll: ScrollContainer = shell._help.find_child("GuidanceScroll",true,false)
	var geometry: Array[Dictionary] = []
	for viewport in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = viewport
		# Arranged long presentation text, never world readiness or fabricated demand.
		guide._reason.text = "Current preparation can be inspected while paused. ".repeat(12)
		await _frames(8)
		var close := _button(shell._help,"Close")
		var viewport_rect := Rect2(Vector2.ZERO,Vector2(viewport))
		if not _require(viewport_rect.encloses(shell._help.get_global_rect()) and viewport_rect.encloses(close.get_global_rect()) and shell._help.size.y <= 260 and shell.content_host.size.y >= 150,"Expanded long guide must remain bounded with fixed Close and destination space at "+str(viewport)): return
		if not _require(scroll.get_v_scroll_bar().max_value > scroll.size.y and scroll.follow_focus,"Long expanded body must scroll without growing outer help."): return
		for control in [guide._primary,_button(guide,"Open Training"),_button(guide,"Open Vehicles"),_button(guide,"Review Army needs")]:
			scroll.ensure_control_visible(control)
			await _frames()
			if not _require(scroll.get_global_rect().encloses(control.get_global_rect()),"Each navigation control must be revealable inside guide scroll at "+str(viewport)): return
		geometry.append({"viewport":str(viewport),"help":str(shell._help.size),"destination":str(shell.content_host.size)})
	var old_model: RefCounted = session.simulation
	main._start_playtest()
	session.set_physics_process(false)
	await _frames()
	if not _require(session.simulation != old_model and guide._session == session and guide.view.next_action.panel == "Workers/Jobs" and not guide._primary.disabled,"Actual new-session replacement must clear stale guidance and show current opening."): return
	calls = CallLog.totals().get(COUNTER,0)
	old_model.rear.state_changed.emit()
	await _frames()
	if not _require(int(CallLog.totals().get(COUNTER,0)) == calls,"Prior simulation must no longer invalidate mounted guidance."): return
	main.queue_free()
	await _frames()
	if not _require(not is_instance_valid(guide),"Guide must leave with its shell/session, without another lifecycle owner."): return
	print(JSON.stringify({"result":"PASS","checks":_checks,"geometry":geometry,"scope":"Actual paused main scene UI destinations, drafts, nonmutation, hidden/coalesced reads, close/reopen, replacement and headless bounds. Draft/long text/selector inputs arranged explicitly. No physical course/truck/delivery, native input, visible render, whole-demo or FPS proof."}))
	quit(0)
