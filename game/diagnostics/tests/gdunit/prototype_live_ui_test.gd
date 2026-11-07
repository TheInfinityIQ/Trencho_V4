extends GdUnitTestSuite
## Real persistent opening and real controls; no rear-only replacement fixture.
const Probe = preload("res://game/diagnostics/tests/gdunit/fixtures/ui_action_probe.gd")
var _probe: Node
var _saved := {}

func before_test() -> void:
	var window := get_tree().root
	_saved = {"size":window.size,"content":window.content_scale_size,"mode":window.mode,"embed":window.gui_embed_subwindows,"diagnostics":OS.get_environment("TRENCHO_HQ_DIAGNOSTICS")}
	OS.set_environment("TRENCHO_HQ_DIAGNOSTICS","")
	window.gui_embed_subwindows = true
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1280,720)
	window.content_scale_size = window.size
	window.grab_focus()
	_probe = Probe.new()
	add_child(_probe)

func after_test() -> void:
	_probe.active = false
	_probe.queue_free()
	await get_tree().process_frame
	var window := get_tree().root
	window.size = _saved.size
	window.content_scale_size = _saved.content
	window.mode = _saved.mode
	window.gui_embed_subwindows = _saved.embed
	OS.set_environment("TRENCHO_HQ_DIAGNOSTICS",_saved.diagnostics)

func test_ordinary_primary_and_management_panels_keep_pace_at_one_x(timeout: int = 90000) -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	await runner.simulate_frames(3)
	assert_bool(game._base.simulation.empty_field_opening and game._base.simulation.connected_world).is_true()
	var identity: int = game._base.simulation.get_instance_id()
	var actions: Array = [{"nav":"Work"},{"nav":"Build"},{"nav":"Workers/Jobs"},{"nav":"Supplies"},{"nav":"Battlefield"},
		{"more":2,"panel":"Train"},{"more":3,"panel":"Vehicles"},{"more":4,"panel":"ArmySupply"},{"more":5,"panel":"Dispatch"},{"more":0,"panel":"Haul"},{"more":1,"panel":"Info"}]
	_probe.pending = [{"nav":"start 1x"}]+actions.duplicate(true)
	_begin(game,"Ordinary game / start 1x through the speed button")
	var cost: float = await _press(runner,game._shell._speed_buttons[1])
	await runner.simulate_frames(3)
	if not _finish(game,cost,identity): return
	for action in actions:
		_begin(game,"Ordinary game / open and observe %s at 1x" % str(action.get("nav",action.get("panel",""))))
		if action.has("nav"):
			cost = await _press(runner,game._shell._navigation_buttons[action.nav])
		else:
			var menu: MenuButton
			for button in game._shell.find_children("*","MenuButton",true,false):
				if button.text == "More systems": menu = button; break
			_probe.require_condition(menu != null,"The actual management menu must exist.")
			if menu == null: _finish(game,0.0,identity); return
			cost = await _press(runner,menu)
			var popup := menu.get_popup()
			_probe.require_condition(popup.visible,"The management button must open its actual popup.")
			popup.grab_focus()
			await _key(KEY_HOME)
			await runner.simulate_frames(1)
			var target: int = popup.get_item_index(int(action.more))
			for _step in popup.item_count+1:
				if popup.get_focused_item() == target: break
				await _key(KEY_DOWN)
				await runner.simulate_frames(1)
			_probe.action.popup_target = target
			_probe.action.popup_focused = popup.get_focused_item()
			_probe.require_condition(popup.get_focused_item() == target,"Keyboard navigation must focus the requested management item.")
			if not _probe._issues.is_empty(): _finish(game,cost,identity); return
			var receipt := {"ids":[]}
			var callback := func(id: int) -> void: receipt.ids.append(id)
			popup.id_pressed.connect(callback)
			await _key(KEY_ENTER)
			await runner.simulate_frames(2)
			popup.id_pressed.disconnect(callback)
			_probe.require_condition(receipt.ids == [int(action.more)],"The native popup must activate exactly the requested item.",receipt)
		await runner.simulate_frames(2)
		_probe.require_condition(game._shell._current_navigation == str(action.get("nav",action.get("panel",""))),"Real navigation must select the requested panel.",{"actual":game._shell._current_navigation,"expected":action.get("nav",action.get("panel",""))})
		var deadline: int = Time.get_ticks_usec()+2000000
		while Time.get_ticks_usec() < deadline and _probe._issues.is_empty(): await runner.simulate_frames(1)
		if not _finish(game,cost,identity): return

func _begin(game: Control, label: String) -> void:
	_probe.begin({"label":label,"initial_time":game._base.simulation.rear.time,"initial_speed":game._base.simulation.speed},game)

func _finish(game: Control, cost: float, identity: int) -> bool:
	var simulation: RefCounted = game._base.simulation
	var elapsed: float = float(Time.get_ticks_usec()-_probe._started_usec)/1000000.0
	var progressed: float = simulation.rear.time-float(_probe.action.initial_time)
	_probe.action.simulation_progress_seconds = progressed
	_probe.action.owed_simulation_seconds = simulation.owed_simulation_seconds
	_probe.require_condition(simulation.get_instance_id() == identity,"All panels must observe the same continuing simulation.")
	if _probe._issues.is_empty():
		_probe.require_condition(simulation.speed == 1,"The ordinary menu observation must remain at 1x.")
		if elapsed >= 1.0:
			_probe.require_condition(progressed >= elapsed-0.25,"UI work must not conceal stalled simulation progress.",{"wall_seconds":elapsed,"simulation_seconds":progressed})
			_probe.require_condition(simulation.owed_simulation_seconds <= 0.25,"UI work must not hide growing simulation debt.")
	if not _probe.pending.is_empty(): _probe.pending.pop_front()
	var result: Dictionary = _probe.finish(cost,"ordinary_connected_menu_input")
	assert_bool(result.ok).override_failure_message("Ordinary menu failed: %s. Logs: %s" % [_probe.action.label,_probe.directory]).is_true()
	return result.ok

func _press(runner: GdUnitSceneRunner, button: Button) -> float:
	_probe.require_condition(button != null and button.is_visible_in_tree() and not button.disabled,"The actual player control must be reachable and enabled.")
	if button == null: return 0.0
	var parent: Node = button.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await runner.simulate_frames(2)
	var receipt := {"count":0}
	var callback := func() -> void: receipt.count += 1
	button.pressed.connect(callback)
	var started: int = Time.get_ticks_usec()
	var elapsed := 0.0
	if button is MenuButton:
		# PopupMenu is a Window. Route native pointer state through Input,
		# including a returned frame between down and up, as a player does.
		runner.simulate_mouse_move(button.get_global_rect().get_center())
		runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
		elapsed = float(Time.get_ticks_usec()-started)/1000.0
		await runner.simulate_frames(1)
		started = Time.get_ticks_usec()
		runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
		elapsed += float(Time.get_ticks_usec()-started)/1000.0
	else:
		_click(button.get_viewport(),button.get_global_rect().get_center())
		elapsed = float(Time.get_ticks_usec()-started)/1000.0
	await runner.simulate_frames(2)
	button.pressed.disconnect(callback)
	_probe.require_condition(receipt.count == 1,"A real GUI click must activate the requested control once.")
	return elapsed

func _click(viewport: Viewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		viewport.push_input(event,true)

func _key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
