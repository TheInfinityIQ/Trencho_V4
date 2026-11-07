extends GdUnitTestSuite
## Current empty opening plus explicitly prepared native Train interactions and 1x observations.
const Scenarios = preload("res://game/diagnostics/tests/gdunit/fixtures/training_read_scenarios.gd")
const Probe = preload("res://game/diagnostics/tests/gdunit/fixtures/ui_action_probe.gd")
const Counter = preload("res://game/diagnostics/function_call_log.gd")
const COMMANDS := ["training/training_service.gd::request_course", "training/training_service.gd::withdraw",
	"training/training_service.gd::set_access", "staffing/rear_simulation.gd::set_target"]
var _probe: Node
var _previous_size: Vector2i
var _previous_content: Vector2i
var _previous_embed := false
var _previous_mode: Window.Mode
var _previous_diagnostics := ""

func before_test() -> void:
	var window := get_tree().root
	_previous_size = window.size
	_previous_content = window.content_scale_size
	_previous_embed = window.gui_embed_subwindows
	_previous_mode = window.mode
	_previous_diagnostics = OS.get_environment("TRENCHO_HQ_DIAGNOSTICS")
	OS.set_environment("TRENCHO_HQ_DIAGNOSTICS", "")
	window.gui_embed_subwindows = true
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1280, 720)
	window.content_scale_size = window.size
	window.grab_focus()
	_probe = Probe.new()
	add_child(_probe)

func after_test() -> void:
	_probe.active = false
	_probe.queue_free()
	await get_tree().process_frame
	var window := get_tree().root
	window.size = _previous_size
	window.content_scale_size = _previous_content
	window.gui_embed_subwindows = _previous_embed
	window.mode = _previous_mode
	OS.set_environment("TRENCHO_HQ_DIAGNOSTICS", _previous_diagnostics)

func test_00_empty_opening_train_reads_issue_no_commands() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	game._session.set_physics_process(false)
	game._navigate("Train")
	await runner.simulate_frames(2)
	var demo: Control = game._base
	var before := Scenarios.raw_state(demo.simulation)
	var calls := Counter.totals()
	for repeat in 10: demo._refresh()
	var unchanged: bool = Scenarios.fingerprint(Scenarios.raw_state(demo.simulation)) == Scenarios.fingerprint(before)
	var after := Counter.totals()
	await runner.simulate_frames(3)
	_probe.begin({"label":"Current empty opening / Train reads", "scope":"Raw capture and synthetic ten-read batch run outside the native-input observation; live performance is measured separately."}, game)
	_probe.require_condition(demo.simulation.empty_field_opening and demo.simulation.rear.actors.is_empty(), "Main must keep the current empty-field opening.")
	_probe.require_condition(unchanged, "Rendering an empty Train panel must not change domain state.")
	for id in COMMANDS:
		_probe.require_condition(int(after.get(id, 0)) == int(calls.get(id, 0)), "View synchronization must not issue a domain command: " + id)
	var before_input := Counter.totals()
	var revision: int = demo.simulation.planning_view_revision
	await _press(runner, _button(game, "Request course"))
	_probe.require_condition(demo.simulation.rear.training.rows.is_empty(), "A course request without a training site must be rejected without rows.")
	if demo.simulation.has_method("training_view"):
		for id in ["rear_base/base_simulation.gd::after_command", "staffing/rear_simulation.gd::advance_time", "main/game_session.gd::notify_command"]:
			_probe.require_condition(int(Counter.totals().get(id, 0)) == int(before_input.get(id, 0)), "A rejected training request must bypass global reconciliation/notification: " + id)
		_probe.require_condition(demo.simulation.planning_view_revision == revision, "A rejected request must not invalidate live planning.")
	_complete()

func test_01_native_training_request_access_withdraw_and_same_person_completion() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	await _bind(runner, game, "idle")
	var demo: Control = game._base
	var base: RefCounted = demo.simulation
	_probe.begin({"label":"Prepared training / native request, access, withdrawal and qualifications",
		"clock":"Explicit domain stepping; native GUI contracts, not a live 1x benchmark"}, game)
	var staff_before := Counter.totals()
	await _number(runner, demo.instructor_count, 2)
	_command_once(base, staff_before, COMMANDS[3])
	_probe.require_condition(base.rear.requests.training.target == 2, "Native staffing input must change the real instructor target.")
	staff_before = Counter.totals()
	await _number(runner, demo.instructor_count, 1)
	_command_once(base, staff_before, COMMANDS[3])
	await _number(runner, demo.training_count, 2)
	await _number(runner, demo.training_count, 1)
	var before := Counter.totals()
	await _press(runner, _button(game, "Request course"))
	_probe.require_condition(base.rear.training.rows.size() == 1, "One press must create one requested course.")
	if base.rear.training.rows.size() != 1:
		_complete()
		return
	_command_once(base, before, COMMANDS[0])
	_advance(base, 30)
	demo._refresh()
	var row: Dictionary = base.rear.training.rows[0]
	var student: String = row.person_id
	var work: float = row.work
	_probe.require_condition(row.state == "Active" and work > 0, "Actual reporting must precede earned course work.")
	before = Counter.totals()
	await _press(runner, demo.training_access)
	_command_once(base, before, COMMANDS[2])
	_probe.require_condition(not base.rear.training.accessible and row.state == "Paused", "The access checkbox must pause the actual course.")
	var paused_time: float = base.rear.time
	base.tick(10)
	_probe.require_condition(base.rear.time == paused_time and row.work == work, "Custom Pause must stop time and training progress.")
	_advance(base, 10)
	_probe.require_condition(row.work == work, "An inaccessible course retains work without accruing more.")
	await _press(runner, demo.training_access)
	await _select_row(runner, demo.training_rows, false)
	_probe.require_condition(demo._selected_id == row.id, "Native list selection must resolve the actual course ID.")
	before = Counter.totals()
	await _press(runner, _button(game, "Withdraw selected course"))
	_command_once(base, before, COMMANDS[1])
	_probe.require_condition(row.state == "Withdrawn" and row.work == 0, "Withdrawal must lose only unfinished work.")
	_probe.require_condition(not base.rear.ledger.inspect_entity(student).basic_training, "Withdrawal must not grant a qualification.")
	await _press(runner, _button(game, "Request course"))
	_advance(base, 200)
	_probe.require_condition(base.rear.training.rows[1].state == "Completed", "A second basic course must complete on the same real student.")
	var qualified: String = base.rear.training.rows[1].person_id
	var bodies: int = base.rear.actors.size()
	var created: Dictionary = base.rear.ledger.snapshot(false).created
	await _choose_last(runner, demo.training_course)
	_probe.require_condition(str(demo.training_course.get_item_metadata(demo.training_course.selected)) == "P08", "The native course option must select P08.")
	await _press(runner, _button(game, "Request course"))
	_probe.require_condition(base.rear.training.rows.size() == 3, "The selected specialist course must be requested exactly once.")
	if base.rear.training.rows.size() != 3:
		_complete()
		return
	_advance(base, 300)
	_probe.require_condition(base.rear.training.rows[2].state == "Completed" and base.rear.training.rows[2].person_id == qualified, "P08 must qualify the same person, without replacing their identity.")
	_probe.require_condition(base.rear.ledger.inspect_entity(qualified).qualification == "P08", "The completed native request must grant the selected specialist qualification.")
	_probe.require_condition(base.rear.actors.size() == bodies and base.rear.ledger.snapshot(false).created == created, "Training must not create bodies, stock or equipment.")
	_complete()

func test_02_selection_focus_hidden_catchup_and_replaced_session() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	await _bind(runner, game, "active")
	var demo: Control = game._base
	var old: RefCounted = demo.simulation
	get_tree().root.size = Vector2i(960, 640)
	get_tree().root.content_scale_size = get_tree().root.size
	await runner.simulate_frames(3)
	_probe.begin({"label":"Prepared training / selection, focus, hidden catch-up and replacement"}, game)
	await _select_row(runner, demo.training_rows, true)
	var selected: String = old.rear.training.rows[-1].id
	_probe.require_condition(demo._selected_id == selected, "End must select the last actual course.")
	for repeat in 5: demo._refresh()
	_probe.require_condition(demo._selected_id == selected and demo.training_rows.get_selected_items() == PackedInt32Array([11]), "Repeated reads must preserve selection by ID.")
	await _expose(demo.training_count)
	var edit: LineEdit = demo.training_count.get_line_edit()
	edit.grab_focus()
	edit.select_all()
	await _key(edit.get_viewport(), KEY_3, 51)
	await runner.simulate_frames(1)
	for repeat in 5: demo._refresh()
	_probe.require_condition(edit.has_focus() and edit.text == "3", "Refresh must preserve focused unsubmitted student-count text.", {"focus":edit.has_focus(), "text":edit.text})
	game._navigate("Build")
	await runner.simulate_frames(2)
	_probe.require_condition(game._shell._current_navigation == "Build","The queued Build navigation must actually hide Train before the hidden-progress check.")
	_advance(old, 5)
	game._navigate("Train")
	await runner.simulate_frames(2)
	_probe.require_condition(demo._selected_id == selected, "Changing panels must retain the selected course.")
	_probe.require_condition(demo.training_rows.get_item_text(0).contains("%.1f/" % old.rear.training.rows[0].work), "Showing Train must catch up to progress earned while it was hidden.")
	await RenderingServer.frame_post_draw
	var excluded: Dictionary = _probe.begin_excluded_work("Visual QA screenshot capture")
	game.get_viewport().get_texture().get_image().save_png(_probe.directory.path_join("training-small.png"))
	_probe.end_excluded_work(excluded)
	excluded = _probe.begin_excluded_work("Raw checkpoint and legal replacement fixture")
	var old_state := Scenarios.raw_state(old)
	demo._request_refresh()
	var replacement: RefCounted = Scenarios.fixture("idle")
	demo.simulation = replacement
	demo._bind_started_session(true)
	_probe.end_excluded_work(excluded)
	await runner.simulate_frames(3)
	_probe.require_condition(game._session.simulation == replacement and demo.training_rows.item_count == 0, "Queued refresh work must display the replacement session.")
	_probe.require_condition(demo._selected_id == "terminal" and demo._selected_kind == "building", "New-session binding must reset selection to the current opening policy.")
	excluded = _probe.begin_excluded_work("Obsolete model raw-state comparison")
	var old_unchanged: bool = Scenarios.fingerprint(Scenarios.raw_state(old)) == Scenarios.fingerprint(old_state)
	_probe.end_excluded_work(excluded)
	_probe.require_condition(old_unchanged, "Delayed UI work must not mutate the obsolete model.")
	_complete()

func test_03_three_warmed_training_observations_at_one_x(timeout: int = 300000) -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	var reports: Array = []
	var requested := OS.get_environment("TRENCHO_TRAINING_OBSERVATION_SECONDS")
	var seconds := 2.0 if requested.is_empty() else float(requested)
	for trial in 3:
		await _bind(runner, game, "active")
		var demo: Control = game._base
		game._session.set_speed(1)
		game._session.set_physics_process(true)
		await get_tree().create_timer(1.1).timeout
		var direct_ms: Array[float] = []
		var counts := Counter.totals()
		for repeat in 30:
			var started := Time.get_ticks_usec()
			demo._refresh()
			direct_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
		var direct_counts := _difference(Counter.totals(), counts)
		await runner.simulate_frames(3)
		_probe.pending = [{"trial":trial + 1}, {"trial":trial + 2}] if trial == 0 else ([{"trial":2}] if trial == 1 else [])
		_probe.begin({"label":"Prepared Train 1x / trial %d" % trial, "fixture":"Base expanded rear, 12 untrained students, two actual instructors, one requested instructor; tick_live delegates to tick", "trial":trial}, game)
		var start_time: float = demo.simulation.rear.time
		var start_work: float = demo.simulation.rear.training.rows[0].work
		var started_unix := Time.get_unix_time_from_system()
		var started := Time.get_ticks_usec()
		var previous := started
		var frames_ms: Array[float] = []
		var process_ms: Array[float] = []
		var physics_ms: Array[float] = []
		while _probe.active and float(Time.get_ticks_usec() - started) / 1000000.0 < seconds:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			frames_ms.append(float(now - previous) / 1000.0)
			process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			previous = now
		var ended_unix := Time.get_unix_time_from_system()
		_probe.require_condition(demo.simulation.speed == 1 and demo.simulation.rear.time > start_time, "Observation must retain 1x and advance real domain time.")
		var finished: Dictionary = _probe.finish(0, "bounded_1x_training_observation")
		reports.append({"trial":trial, "requested_seconds":seconds, "started_unix":started_unix, "ended_unix":ended_unix,
			"start_time":start_time, "end_time":demo.simulation.rear.time, "start_work":start_work, "end_work":demo.simulation.rear.training.rows[0].work,
			"direct_refresh_ms":direct_ms, "direct_counts":direct_counts, "frame_ms":frames_ms,
			"engine_frame_monitor_ms":process_ms, "engine_physics_monitor_ms":physics_ms,
			"result":finished, "limits":"Direct-call elapsed times and engine monitors are not script CPU self/total attribution; monitor values may lag. Frames are correlated; preserve each run separately."})
		_probe._save("training_observations.json", {"runs":reports})
		assert_bool(finished.ok).override_failure_message("Training performance issue; logs: " + _probe.directory).is_true()
		if not finished.ok: return

func _bind(runner: GdUnitSceneRunner, game: Control, label: String) -> void:
	game._session.set_physics_process(false)
	game._base.simulation = Scenarios.fixture(label)
	game._base._bind_started_session(true)
	game._navigate("Train")
	await runner.simulate_frames(3)

func _button(root: Node, text: String) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree(): return button
	_probe.require_condition(false, "Required native training button is missing: " + text)
	return null

func _expose(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await get_tree().process_frame

func _press(runner: GdUnitSceneRunner, button: Button) -> void:
	if button == null: return
	await _expose(button)
	var receipt := {"count":0}
	var callback := func() -> void: receipt.count += 1
	button.pressed.connect(callback)
	_click(button.get_viewport(), button.get_global_rect().get_center())
	await runner.simulate_frames(1)
	button.pressed.disconnect(callback)
	_probe.require_condition(receipt.count == (0 if button.disabled else 1), "Native input must press this training control exactly once: " + button.text, receipt)
	if not _probe.action.has("input_receipts"): _probe.action.input_receipts = []
	_probe.action.input_receipts.append({"text":button.text, "pressed_signals":receipt.count, "disabled":button.disabled})

func _number(runner: GdUnitSceneRunner, spin: SpinBox, number: int) -> void:
	await _expose(spin)
	spin.get_window().grab_focus()
	# Enter can end LineEdit editing while it keeps focus. A fresh mouse click
	# re-enters editing before the next numeric change, as a player would do.
	_click(spin.get_viewport(), spin.get_line_edit().get_global_rect().get_center())
	await runner.simulate_frames(1)
	# Arrange text selection, then exercise actual GUI text/submission events.
	# This tests numeric editing, not the platform's Ctrl+A shortcut mapping.
	spin.get_line_edit().select_all()
	for digit in str(number): await _key(spin.get_viewport(), digit.unicode_at(0), digit.unicode_at(0))
	var entered: String = spin.get_line_edit().text
	await _key(spin.get_viewport(), KEY_ENTER)
	await runner.simulate_frames(1)
	_probe.require_condition(int(spin.value) == number, "Native numeric input must commit the intended value.", {"expected":number, "actual":spin.value, "entered":entered, "text":spin.get_line_edit().text})

func _select_row(runner: GdUnitSceneRunner, list: ItemList, last: bool) -> void:
	await _expose(list)
	_click(list.get_viewport(), list.get_global_rect().position + Vector2(20, 12))
	list.grab_focus()
	if last:
		for step in list.item_count - 1:
			await _key(list.get_viewport(), KEY_DOWN)
			await runner.simulate_frames(1)
	await runner.simulate_frames(2)

func _choose_last(runner: GdUnitSceneRunner, option: OptionButton) -> void:
	await _press(runner, option)
	var popup := option.get_popup()
	_probe.require_condition(popup.visible, "The native course popup must open.")
	popup.grab_focus()
	for step in option.item_count + 1:
		if popup.get_focused_item() == option.item_count - 1: break
		await _key(popup, KEY_DOWN)
		await runner.simulate_frames(1)
	await _key(popup, KEY_ENTER)
	await runner.simulate_frames(2)

func _key(_viewport: Viewport, key: int, unicode: int = 0, control: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.unicode = unicode if down else 0
		event.ctrl_pressed = control
		event.pressed = down
		# Route through the focused native/embedded window, including PopupMenu.
		# Direct Viewport.push_input bypasses that routing for some text controls.
		Input.parse_input_event(event)
		await get_tree().process_frame

func _click(viewport: Viewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		viewport.push_input(event)

func _command_once(base: RefCounted, before: Dictionary, id: String) -> void:
	# Pre-change capture predates command counters; the new read API requires
	# these receipts after implementation, without weakening the old state checks.
	if base.has_method("training_view"):
		_probe.require_condition(int(Counter.totals().get(id, 0)) - int(before.get(id, 0)) == 1, "One input must invoke one domain command: " + id)

func _difference(after: Dictionary, before: Dictionary) -> Dictionary:
	var result := {}
	for key in after:
		var count := int(after[key]) - int(before.get(key, 0))
		if count > 0: result[str(key)] = count
	return result

func _complete() -> void:
	_probe.pending.clear()
	var result: Dictionary = _probe.finish(0, "native_training_contract")
	assert_bool(result.ok).override_failure_message("Native training contract failed; logs: " + _probe.directory).is_true()

func _advance(base: RefCounted, seconds: float) -> void:
	var excluded: Dictionary = _probe.begin_excluded_work("Explicit domain fast-forward %.1fs" % seconds)
	base.set_speed(1)
	base.tick(seconds)
	base.set_speed(0)
	_probe.end_excluded_work(excluded)
