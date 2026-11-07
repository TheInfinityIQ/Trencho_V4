extends Control
const Budget = preload("res://game/diagnostics/performance_budget.gd")
## Opt-in live UI exerciser. Never loaded by the normal main scene.

const Main = preload("res://game/main/main.tscn")
const Counter = preload("res://game/diagnostics/function_call_log.gd")
const MENUS: Array[String] = ["Build", "Supplies", "Workers/Jobs", "Work", "Battlefield", "Haul", "Info", "Train", "Vehicles", "ArmySupply", "Dispatch", "Diagnostics", "rear"]
signal run_finished(status: String, directory: String)
var run_status := "not_started"

@export var maximum_frame_ms := Budget.MAX_FRAME_MS
@export var maximum_action_ms := Budget.MAX_ACTION_MS
@export var inspect_calls_per_second_budget := 30000
@export var observation_seconds := 2.0
@export var warmup_seconds := 1.0
@export_dir var logs_directory := "res://logs"

var _game: Control
var _status: Label
var _continue: Button
var _start: Button
var _running := false
var _starting := false
var _observing := false
var _warming := false
var _action: Dictionary = {}
var _queue: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _seen: Dictionary = {}
var _inventory: Dictionary = {}
var _baseline: Dictionary = {}
var _sample_baseline: Dictionary = {}
var _started_usec := 0
var _sample_usec := 0
var _last_frame_usec := 0
var _action_ms := 0.0
var _peak_frame_ms := 0.0
var _run_dir := ""
var _events: FileAccess
var _samples: FileAccess
var _stack_samples: FileAccess
var _exit_on_pause := false
var _step_limit := 0
var _steps_done := 0
var _requested_run_dir := ""
var _heartbeat_usec := 0
var _engine_log_source := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	for argument in OS.get_cmdline_user_args():
		if argument == "--menu-perf-exit-on-pause": _exit_on_pause = true
		elif argument.begins_with("--menu-perf-step-limit="): _step_limit = int(argument.get_slice("=", 1))
		elif argument.begins_with("--menu-perf-call-budget="): inspect_calls_per_second_budget = int(argument.get_slice("=", 1))
		elif argument.begins_with("--menu-perf-frame-ms="): maximum_frame_ms = float(argument.get_slice("=", 1))
		elif argument.begins_with("--menu-perf-action-ms="): maximum_action_ms = float(argument.get_slice("=", 1))
		elif argument.begins_with("--menu-perf-observe-seconds="): observation_seconds = maxf(0.1, float(argument.get_slice("=", 1)))
		elif argument.begins_with("--menu-perf-run-dir="): _requested_run_dir = argument.trim_prefix("--menu-perf-run-dir=")
		elif argument.begins_with("--menu-perf-engine-log="): _engine_log_source = argument.trim_prefix("--menu-perf-engine-log=")
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var toolbar := HBoxContainer.new()
	layout.add_child(toolbar)
	_start = _button(toolbar, "Start 1x suite", _start_suite)
	_continue = _button(toolbar, "Continue after issue", _resume)
	_continue.disabled = true
	_button(toolbar, "Stop suite", _stop)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)
	_status.text = "Opt-in test session. Stops at the first budget violation. Normal F5 startup is unchanged."
	_game = Main.instantiate()
	_game.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_game)
	if "--menu-perf-autostart" in OS.get_cmdline_user_args(): _start_suite.call_deferred()


func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _start_suite() -> void:
	if _running or _starting or not _run_dir.is_empty(): return
	_starting = true
	_start.disabled = true
	run_status = "preparing_initial_presentation"
	# Initial scene creation/layout is fixture setup, as in the native-input
	# suites. Keep the complete measured 1x warmup after these paused frames.
	for _frame in 3: await get_tree().process_frame
	if not _starting: return
	_starting = false
	maximum_frame_ms = Budget.capped_limit(maximum_frame_ms,Budget.MAX_FRAME_MS)
	maximum_action_ms = Budget.capped_limit(maximum_action_ms,Budget.MAX_ACTION_MS)
	Counter.enabled = true
	if not _open_logs():
		run_status = "log_setup_failed"
		run_finished.emit(run_status, _run_dir)
		return
	_game._session.get_node("FunctionCallLog").connect("second_reported", _write_function_stacks)
	_start.disabled = true
	for menu in MENUS:
		_queue.append({"kind": "menu", "menu": menu, "label": "Open " + menu})
	for node in _game._shell.find_children("*", "MenuButton", true, false):
		var popup: PopupMenu = node.get_popup()
		for index in popup.item_count:
			if not popup.is_item_separator(index):
				_queue.append({"kind": "popup", "menu": "Shell", "path": str(_game.get_path_to(node)),
					"id": popup.get_item_id(index), "label": str(node.text) + " > " + popup.get_item_text(index)})
	_queue.append({"kind": "shell", "label": "Getting started: show", "show": true})
	_queue.append({"kind": "shell", "label": "Getting started: hide", "show": false})
	# Exercise Session menu and confirmation independently of the panel actions.
	for confirm in [false, true]:
		_queue.append({"kind": "new_prompt", "label": "Session > New game prompt"})
		_queue.append({"kind": "new_answer", "label": "Confirm new game" if confirm else "Cancel new game", "confirm": confirm})
	_running = true
	run_status = "running"
	_event("coverage_exclusion", {"controls": ["Pause", "2x"], "reason": "All measured observations must run at 1x."})
	_warming = true
	_begin({"kind": "warmup", "label": "Warm up the opening at 1x"})


func _open_logs() -> bool:
	var root := ProjectSettings.globalize_path(logs_directory)
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "-")
	_run_dir = root.path_join("menu-performance-" + stamp + "-" + str(OS.get_process_id()))
	if not _requested_run_dir.is_empty(): _run_dir = _requested_run_dir
	if DirAccess.make_dir_recursive_absolute(_run_dir) != OK:
		_status.text = "Cannot create logs folder: " + _run_dir
		_run_dir = ""
		return false
	var ignored := FileAccess.open(root.path_join(".gdignore"), FileAccess.WRITE)
	if ignored != null: ignored.close()
	_events = FileAccess.open(_run_dir.path_join("actions.jsonl"), FileAccess.WRITE)
	_samples = FileAccess.open(_run_dir.path_join("function_calls.jsonl"), FileAccess.WRITE)
	_stack_samples = FileAccess.open(_run_dir.path_join("function_stacks.jsonl"), FileAccess.WRITE)
	if _events == null or _samples == null or _stack_samples == null:
		_status.text = "Cannot write performance logs: " + _run_dir
		return false
	_save("metadata.json", {"engine": Engine.get_version_info(), "os": OS.get_name(),
		"cpu": OS.get_processor_name(), "menus": MENUS, "speed": 1,
		"minimum_fps": Budget.MINIMUM_FPS, "engine_max_fps": Engine.max_fps,
		"disable_vsync_requested": OS.get_cmdline_args().has("--disable-vsync"),
		"maximum_frame_ms": maximum_frame_ms, "maximum_action_ms": maximum_action_ms,
		"inspect_calls_per_second_budget": inspect_calls_per_second_budget,
		"observation_seconds": observation_seconds, "instrumentation_enabled": true,
		"call_stack_capture_enabled": Counter.capture_stacks,
		"stack_identity": "Ordered script paths and function names, oldest caller first; call-site lines are ignored.",
		"scope": "Reachable live UI handlers in a disposable opening; disabled/missing controls are untested. No diagnostic fixture time jumps.",
		"frame_measurement": "Wall time between process callbacks, including scheduling/render pacing; not attribution to one function."})
	var latest := FileAccess.open(root.path_join("latest_run.txt"), FileAccess.WRITE)
	if latest != null: latest.store_string(_run_dir + "\n")
	print("[MenuPerf] Logs: " + _run_dir)
	return true


func _write_function_stacks(report: Dictionary) -> void:
	if _stack_samples == null: return
	_stack_samples.store_line(JSON.stringify({"action_at_report": _action.get("label", ""), "window": report}))


func _one_x() -> void:
	_game._session.set_physics_process(true)
	if _game._base.simulation.speed != 1: _game._session.set_speed(1)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if not _running: return
	if now - _heartbeat_usec >= 500000: _heartbeat("running")
	if _last_frame_usec > 0:
		var frame_ms := float(now - _last_frame_usec) / 1000.0
		_peak_frame_ms = maxf(_peak_frame_ms, frame_ms)
		if maximum_frame_ms > 0 and frame_ms > maximum_frame_ms:
			_issue("frame_time_budget", {"frame_ms": frame_ms, "limit_ms": maximum_frame_ms})
			return
	_last_frame_usec = now
	if not _observing: return
	if _game._base.simulation.speed != 1:
		_issue("unexpected_game_speed", {"expected": 1, "actual": _game._base.simulation.speed})
		return
	var seconds := float(now - _sample_usec) / 1000000.0
	if seconds >= 1.0:
		var current := Counter.totals()
		var counts := _difference(current, _sample_baseline)
		var calls: int = int(counts.get("identity/identity_ledger.gd::inspect_entity", 0))
		var rate := float(calls) / seconds
		var sample := {"action": _action.get("label", ""), "elapsed_seconds": seconds,
			"counts": counts, "inspect_calls_per_second": rate,
			"simulation_time": _game._base.simulation.rear.time, "speed": _game._base.simulation.speed}
		_samples.store_line(JSON.stringify(sample))
		_sample_baseline = current
		_sample_usec = now
		if not _warming and inspect_calls_per_second_budget > 0 and rate > inspect_calls_per_second_budget:
			_issue("call_volume_budget", {"inspect_calls_per_second": rate, "limit": inspect_calls_per_second_budget,
				"note": "A call-volume budget is a diagnostic trigger, not proof of CPU cost."})
			return
	var dwell := warmup_seconds if _warming else observation_seconds
	if float(now - _started_usec) / 1000000.0 >= dwell:
		_finish("observed")
		if _warming:
			_warming = false
		else:
			_steps_done += 1
			if _step_limit > 0 and _steps_done >= _step_limit:
				_end("step_limit")
				get_tree().quit(0)
				return
		_next.call_deferred()


func _next() -> void:
	if not _running or _observing: return
	if _queue.is_empty():
		_end("completed_with_coverage_report")
		return
	_begin(_queue.pop_front())


func _begin(step: Dictionary) -> void:
	_action = step
	_baseline = Counter.totals()
	_sample_baseline = _baseline
	_started_usec = Time.get_ticks_usec()
	_sample_usec = _started_usec
	_peak_frame_ms = 0.0
	_last_frame_usec = 0
	_status.text = "%s | 1x | 60 FPS target | frame/action %.2f/%.2f ms | logs: %s" % [step.label, maximum_frame_ms, maximum_action_ms, _run_dir]
	_event("action_started", {"action": step})
	_one_x()
	var action_started := Time.get_ticks_usec()
	if step.has("menu") and step.kind != "menu" and step.menu != "Shell" and _game._shell._current_navigation != step.menu:
		_game._shell.navigation_requested.emit(step.menu)
	var executed := _activate(step)
	_one_x()
	_action_ms = float(Time.get_ticks_usec() - action_started) / 1000.0
	if not executed:
		_finish("untested_unavailable")
		_next.call_deferred()
		return
	if maximum_action_ms > 0 and _action_ms > maximum_action_ms:
		_issue("action_time_budget", {"action_ms": _action_ms, "limit_ms": maximum_action_ms})
		return
	_observing = true
	_last_frame_usec = action_started


func _activate(step: Dictionary) -> bool:
	match step.kind:
		"warmup": return true
		"menu": _game._shell.navigation_requested.emit(step.menu)
		"shell":
			var button := _shell_button("Getting started")
			if button == null: return false
			if _game._shell._help.visible != step.show: button.pressed.emit()
		"new_prompt": _session_popup().id_pressed.emit(0)
		"new_answer":
			var dialog: ConfirmationDialog = _game._shell._confirmation
			if not dialog.visible: return false
			if step.confirm: dialog.confirmed.emit()
			else: dialog.canceled.emit()
			dialog.hide()
			_one_x()
		"build_preview":
			_game._base.select_build_kind("workshop")
			_game._base.preview_build_at(Vector2(60, 45))
		"build_rotate":
			_game._base.construction_turn.button_pressed = not _game._base.construction_turn.button_pressed
			_game._base.preview_build_at(Vector2(60, 45))
		"build_place": _game._base.confirm_build_at(Vector2(60, 45))
		"build_cancel": _game._base._cancel_placement()
		_:
			var target := _game.get_node_or_null(NodePath(step.path))
			if not is_instance_valid(target) and step.has("route"):
				target = _game
				for index in step.route:
					if target == null or int(index) >= target.get_child_count():
						target = null
						break
					target = target.get_child(int(index))
			if not is_instance_valid(target): return false
			if target is Control and (not target.is_visible_in_tree() or target.get_window() != get_window()): return false
			if step.has("text") and target is Button and target.text != step.text: return false
			if step.kind == "option" and not target is OptionButton: return false
			if step.kind == "spin" and not target is SpinBox: return false
			if step.kind == "item" and not target is ItemList: return false
			if step.kind == "button" and not target is Button: return false
			match step.kind:
				"tab":
					target.current_tab = step.index
				"option":
					if target.disabled or step.index >= target.item_count or target.is_item_disabled(step.index): return false
					target.select(step.index)
					target.item_selected.emit(step.index)
				"spin":
					if not target.editable: return false
					target.value = step.value
				"item":
					if step.index >= target.item_count or target.is_item_disabled(step.index): return false
					target.select(step.index)
					target.item_selected.emit(step.index)
				"popup":
					if target.disabled: return false
					target.get_popup().id_pressed.emit(step.id)
				"button":
					if target.disabled: return false
					if target.toggle_mode: target.button_pressed = not target.button_pressed
					target.pressed.emit()
				_: return false
	return true


func _finish(outcome: String) -> void:
	_observing = false
	var result := {"action": _action, "outcome": outcome, "action_ms": _action_ms,
		"peak_frame_ms": _peak_frame_ms, "elapsed_seconds": float(Time.get_ticks_usec() - _started_usec) / 1000000.0,
		"function_calls": _difference(Counter.totals(), _baseline)}
	_results.append(result)
	_event("action_finished", result)
	if outcome == "observed":
		_discover_after_step()
	_dismiss_action_dialogs()
	_save_summary("running")


func _discover_after_step() -> void:
	if _action.kind == "menu": _expand_menu(_action.menu, true)
	elif _action.kind == "tab": _expand_menu(_action.menu, false)
	elif _action.has("menu") and _action.menu != "Shell":
		_expand_menu(str(_game._shell._current_navigation), false)


func _expand_menu(menu: String, include_tabs: bool) -> void:
	var root: Node
	if menu == "Diagnostics":
		_event("coverage_exclusion", {"menu": menu, "reason": "Retained diagnostic fixtures jump game time; their launch buttons are outside the 1x live-game suite."})
		return
	if menu == "Battlefield": root = _game._battlefield
	else: root = _game._base.tabs.get_tab_control(_game._base.tabs.current_tab)
	var discovered: Array[Dictionary] = []
	if menu == "Build" and include_tabs:
		for kind in ["build_preview", "build_rotate", "build_place", "build_cancel"]:
			discovered.append({"kind": kind, "menu": menu, "label": "Build map action: " + kind})
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	if include_tabs:
		var has_tabs := false
		for node in nodes:
			if not node is TabContainer or not node.is_visible_in_tree(): continue
			has_tabs = true
			for index in node.get_tab_count():
				_add_discovered(discovered, {"kind": "tab", "menu": menu, "path": str(_game.get_path_to(node)),
					"index": index, "label": menu + " > " + node.get_tab_title(index)})
		if has_tabs:
			discovered.append_array(_queue)
			_queue = discovered
			return
	for node in nodes:
		if not node is Control or not node.is_visible_in_tree() or node.get_window() != get_window(): continue
		var path: String = str(_game.get_path_to(node))
		if node is TabContainer and include_tabs:
			for index in node.get_tab_count():
				_add_discovered(discovered, {"kind": "tab", "menu": menu, "path": path, "index": index, "label": menu + " > " + node.get_tab_title(index)})
		elif node is OptionButton:
			for index in node.item_count:
				_add_discovered(discovered, {"kind": "option", "menu": menu, "path": path, "index": index, "label": menu + " > choose " + node.get_item_text(index)})
		elif node is MenuButton:
			var popup: PopupMenu = node.get_popup()
			for index in popup.item_count:
				if not popup.is_item_separator(index):
					_add_discovered(discovered, {"kind": "popup", "menu": menu, "path": path, "id": popup.get_item_id(index), "label": menu + " > " + popup.get_item_text(index)})
		elif node is Button and (not node.pressed.get_connections().is_empty() or not node.toggled.get_connections().is_empty()):
				_add_discovered(discovered, {"kind": "button", "menu": menu, "path": path, "text": node.text, "label": menu + " > " + node.text})
		elif node is SpinBox and not node.value_changed.get_connections().is_empty():
			var next: float = minf(node.max_value, node.value + maxf(1.0, node.step))
			if next == node.value: next = maxf(node.min_value, node.value - maxf(1.0, node.step))
			_add_discovered(discovered, {"kind": "spin", "menu": menu, "path": path, "value": next, "label": menu + " > set " + path})
		elif node is ItemList:
			if node.item_count == 0: _event("coverage_unavailable", {"menu": menu, "path": path, "reason": "No rows exist in this opening state."})
			for index in node.item_count:
				_add_discovered(discovered, {"kind": "item", "menu": menu, "path": path, "index": index, "label": menu + " > inspect " + node.get_item_text(index)})
	_inventory[menu] = int(_inventory.get(menu, 0)) + discovered.size()
	discovered.append_array(_queue)
	_queue = discovered


func _add_discovered(actions: Array[Dictionary], action: Dictionary) -> void:
	var route: Array[int] = []
	var node := _game.get_node_or_null(NodePath(action.path))
	while node != null and node != _game:
		route.push_front(node.get_index())
		node = node.get_parent()
	action.route = route
	var key := "%s:%s:%s:%s:%s" % [action.menu, str(route), action.kind, action.get("index", action.get("id", "")), action.get("text", "")]
	if _seen.has(key): return
	_seen[key] = true
	actions.append(action)


func _session_popup() -> PopupMenu:
	for node in _game._shell.find_children("*", "MenuButton", true, false):
		if node.text == "Session": return node.get_popup()
	return null


func _shell_button(title: String) -> Button:
	for node in _game._shell.find_children("*", "Button", true, false):
		if node.text == title: return node
	return null


func _dismiss_action_dialogs() -> void:
	if _action.kind in ["new_prompt", "new_answer"]: return
	for node in _game.find_children("*", "ConfirmationDialog", true, false):
		if node.visible:
			node.canceled.emit()
			node.hide()
			_event("dialog_cancelled", {"name": node.name, "reason": "Generic sweep does not silently confirm a destructive or consumed-batch action."})


func _issue(reason: String, measurement: Dictionary) -> void:
	_running = false
	_observing = false
	var failure := {"reason": reason, "measurement": measurement, "action": _action,
		"simulation_time": _game._base.simulation.rear.time, "speed_at_detection": _game._base.simulation.speed,
		"elapsed_seconds": float(Time.get_ticks_usec() - _started_usec) / 1000000.0,
		"function_calls": _difference(Counter.totals(), _baseline), "pending_actions": _queue,
		"function_call_second": Counter.current_second(),"frame_scopes":Counter.frame_scope_report()}
	_write_function_stacks(failure.function_call_second)
	_pause_game()
	_results.append({"action": _action, "outcome": "paused_on_issue", "failure": failure})
	_save("failure.json", failure)
	_event("paused_on_issue", failure)
	_flush_logs()
	_save_summary("paused_on_issue")
	_heartbeat("paused_on_issue")
	_copy_engine_log()
	_continue.disabled = false
	run_status = "paused_on_issue"
	_status.text = "PAUSED: %s — %s\nLogs: %s" % [_action.label, reason, _run_dir]
	print("[MenuPerf] PAUSED on " + str(_action.label) + ": " + reason + ". Logs: " + _run_dir)
	run_finished.emit(run_status, _run_dir)
	if _exit_on_pause: get_tree().quit(2)


func _pause_game() -> void:
	_game._session.set_speed(0)
	_game._session.set_physics_process(false)


func _resume() -> void:
	if _running or _run_dir.is_empty(): return
	_continue.disabled = true
	_running = true
	run_status = "running"
	_last_frame_usec = 0
	_event("continued_by_user", {"after": _action})
	_discover_after_step()
	_dismiss_action_dialogs()
	_one_x()
	_heartbeat("running")
	_next.call_deferred()


func _stop() -> void:
	_starting = false
	if _run_dir.is_empty():
		_start.disabled = false
		run_status = "stopped_before_observation"
		return
	_end("stopped_by_user")


func _end(outcome: String) -> void:
	_running = false
	_observing = false
	_write_function_stacks(Counter.current_second())
	_flush_logs()
	_pause_game()
	_save_summary(outcome)
	_heartbeat(outcome)
	_copy_engine_log()
	_continue.disabled = true
	_status.text = "%s. Review coverage and timings in %s" % [outcome, _run_dir]
	print("[MenuPerf] " + outcome + ". Logs: " + _run_dir)
	run_status = outcome
	run_finished.emit(run_status, _run_dir)


func _difference(current: Dictionary, previous: Dictionary) -> Dictionary:
	var delta := {}
	for name in current:
		var count: int = int(current[name]) - int(previous.get(name, 0))
		if count > 0: delta[str(name)] = count
	return delta


func _heartbeat(status: String) -> void:
	_heartbeat_usec = Time.get_ticks_usec()
	_save("heartbeat.json", {"status": status, "action": _action.get("label", "initializing"),
		"engine_usec": _heartbeat_usec, "simulation_time": _game._base.simulation.rear.time})


func _event(kind: String, details: Dictionary) -> void:
	_events.store_line(JSON.stringify({"event": kind, "engine_usec": Time.get_ticks_usec(), "details": details}))

func _flush_logs() -> void:
	if _events != null: _events.flush()
	if _samples != null: _samples.flush()
	if _stack_samples != null: _stack_samples.flush()

func _exit_tree() -> void:
	_flush_logs()


func _save(filename: String, details: Dictionary) -> void:
	var file := FileAccess.open(_run_dir.path_join(filename), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(details, "\t") + "\n")


func _save_summary(outcome: String) -> void:
	_save("summary.json", {"status": outcome, "results": _results, "discovered_actions_by_menu": _inventory,
		"pending_actions": _queue, "planned_menus": MENUS,
		"coverage_note": "Disabled, missing and not-yet-reached controls are not passes. This is an opening-state handler sweep, not proof of every gameplay prerequisite or input/render path."})


func _copy_engine_log() -> void:
	# A concurrent editor/game can own the default log. Only copy a source
	# explicitly assigned to this process; the launcher supplies it.
	var source := _engine_log_source
	var arguments := OS.get_cmdline_args()
	var index := arguments.find("--log-file")
	if index >= 0 and index + 1 < arguments.size(): source = arguments[index + 1]
	if not source.is_empty() and FileAccess.file_exists(source):
		if ProjectSettings.globalize_path(source).replace("\\", "/").simplify_path() == _run_dir.path_join("engine.log").replace("\\", "/").simplify_path(): return
		var contents := FileAccess.get_file_as_string(source)
		var file := FileAccess.open(_run_dir.path_join("engine.log"), FileAccess.WRITE)
		if file != null: file.store_string(contents)
