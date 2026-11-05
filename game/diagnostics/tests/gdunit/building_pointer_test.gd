extends GdUnitTestSuite
const Budget = preload("res://game/diagnostics/performance_budget.gd")
## The actual default game, continuous 1x time and GUI pointer input, without replacing its world.
const Probe = preload("res://game/diagnostics/tests/gdunit/fixtures/ui_action_probe.gd")
const Counter = preload("res://game/diagnostics/function_call_log.gd")
const PlacementTrace = preload("res://game/diagnostics/tests/gdunit/fixtures/placement_trace.gd")
var _probe: Node
var _saved := {}

func before_test() -> void:
	var window := get_tree().root
	_saved = {"size":window.size, "content":window.content_scale_size, "mode":window.mode,
		"embed":window.gui_embed_subwindows, "diagnostics":OS.get_environment("TRENCHO_HQ_DIAGNOSTICS")}
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
	window.size = _saved.size
	window.content_scale_size = _saved.content
	window.mode = _saved.mode
	window.gui_embed_subwindows = _saved.embed
	OS.set_environment("TRENCHO_HQ_DIAGNOSTICS", _saved.diagnostics)

func test_00_default_game_move_preview_place_and_repeat_at_one_x() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	_probe.pending = ["Open Build at 1x", "Idle baseline", "Move workshop preview", "Place workshop", "Move depot preview", "Place depot"]
	if not await _open(runner, game): return
	_begin_phase({"label":"Default game / Build idle baseline at 1x"}, game)
	await _observe(runner)
	if not _finish(game): return
	for spec in [{"kind":"workshop", "point":Vector2(83.375, 48.625)}, {"kind":"depot", "point":Vector2(158.125, 127.375)}]:
		_begin_phase({"label":"Default game / select and move " + spec.kind + " preview at 1x"}, game)
		await _choose(runner, game._base.construction_kind, spec.kind)
		var before: int = game._base.simulation.rear.construction.instances.size()
		var commands: int = Counter.totals().get("rear_base/base_simulation.gd::after_command", 0)
		await _sweep(runner, game, spec.point, 1)
		_probe.require_condition(game._base.simulation.rear.construction.instances.size() == before, "Moving the ghost must not place sites.")
		_probe.require_condition(int(Counter.totals().get("rear_base/base_simulation.gd::after_command", 0)) == commands, "Pointer motion must not reconcile domain commands.")
		if not _finish(game): return
		_begin_phase({"label":"Default game / click and observe " + spec.kind + " at 1x", "expected_center":str(spec.point)}, game)
		_place(game, spec.point, spec.kind, before)
		await runner.simulate_frames(2)
		await _observe(runner)
		_probe.require_condition(not game._base.base_map.placement_active, "A successful click must end ghost placement.")
		if not _finish(game): return

func test_01_transformed_map_rotation_rejected_click_recovery_and_cancel_at_one_x() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	_probe.pending = ["Open Build at 1x", "Transformed map placement", "Rejected click recovery and cancellation"]
	if not await _open(runner, game): return
	_begin_phase({"label":"Default game / zoom, pan, rotate and place with the pointer at 1x"}, game)
	var map: Control = game._base.base_map
	var middle: Vector2 = map.get_global_rect().get_center()
	_button_event(map.get_viewport(), middle, MOUSE_BUTTON_WHEEL_UP, true)
	_button_event(map.get_viewport(), middle, MOUSE_BUTTON_WHEEL_UP, false)
	_button_event(map.get_viewport(), middle, MOUSE_BUTTON_MIDDLE, true)
	_motion(map.get_viewport(), middle + Vector2(23, -17), Vector2(23, -17), MOUSE_BUTTON_MASK_MIDDLE)
	_button_event(map.get_viewport(), middle + Vector2(23, -17), MOUSE_BUTTON_MIDDLE, false)
	await runner.simulate_frames(2)
	await _choose(runner, game._base.construction_kind, "workshop")
	await _key(KEY_R)
	_probe.require_condition(game._base.construction_turn.button_pressed, "R must rotate the actual ghost.")
	var point := Vector2(109.375, 63.625)
	await _sweep(runner, game, point, 1)
	_place(game, point, "workshop", 0)
	await runner.simulate_frames(2)
	if not _finish(game): return
	_begin_phase({"label":"Default game / overlap rejection then move and place without restarting"}, game)
	await _press(runner, _button(game, "Place on field"))
	var screen := _screen(map, point)
	_click(map.get_viewport(), screen)
	await runner.simulate_frames(2)
	_probe.require_condition(map.placement_active and game._base.simulation.rear.construction.instances.size() == 1, "An overlapping click must leave the ghost active and create no site.")
	point = Vector2(170.125, 112.375)
	await _sweep(runner, game, point, 1)
	_place(game, point, "workshop", 1)
	await runner.simulate_frames(2)
	await _press(runner, _button(game, "Place on field"))
	await _key(KEY_ESCAPE)
	_probe.require_condition(not map.placement_active, "Escape must cancel the pointer workflow.")
	await _observe(runner)
	_finish(game)

func test_02_sustained_pointer_motion_and_post_placement_workload_at_one_x() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	_probe.pending = ["Open Build at 1x", "Sustained preview motion", "Sustained post-placement motion"]
	if not await _open(runner, game): return
	_begin_phase({"label":"Default game / sustained eight-motion bursts per rendered frame at 1x", "input_scope":"Direct viewport GUI events; deliberate unaccumulated stress, not a claim about OS mouse polling."}, game)
	await _choose(runner, game._base.construction_kind, "materials")
	var point := Vector2(146.375, 81.625)
	await _sweep(runner, game, point, 8)
	_probe.require_condition(game._base.simulation.rear.construction.instances.is_empty(), "Even sustained motion must create no sites.")
	if not _finish(game): return
	_begin_phase({"label":"Default game / sustained motion after placing a building at 1x"}, game)
	_place(game, point, "materials", 0)
	await runner.simulate_frames(2)
	await _sweep(runner, game, Vector2(79.125, 120.375), 8, false)
	_probe.require_condition(game._base.simulation.rear.construction.instances.size() == 1, "Moving after placement must not issue more placements.")
	_finish(game)

func test_03_default_game_without_building_control_at_one_x() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	_probe.pending = ["Open Build at 1x", "Twelve-second no-building control"]
	if not await _open(runner, game): return
	_begin_phase({"label":"Default game / no selection or placement control at 1x"}, game)
	var deadline := Time.get_ticks_usec() + int(maxf(12.0, _seconds()) * 1000000)
	while Time.get_ticks_usec() < deadline and _probe._issues.is_empty(): await runner.simulate_frames(1)
	_probe.require_condition(game._base.simulation.rear.construction.instances.is_empty(), "The comparison control must contain no placed building.")
	_finish(game)

func test_04_populated_field_pointer_motion_and_fresh_placement_at_one_x() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	_probe.pending = ["Open Build at 1x", "Prepare six real sites", "Populated preview motion", "Fresh placement"]
	if not await _open(runner, game): return
	# Preparation is a declared fixture, outside the live input measurement.
	await _press(runner, _button(game, "Ⅱ"))
	var service: RefCounted = game._base.simulation.rear.construction
	for point in [Vector2(50,30), Vector2(85,30), Vector2(120,30), Vector2(155,30), Vector2(50,140), Vector2(85,140)]:
		var result: Dictionary = service.place("construction", point)
		_probe.require_condition(result.ok, "Prepared sites must use legal construction commands.", result)
	if not _probe._issues.is_empty():
		_finish(game)
		return
	await _press(runner, _button(game, "1×"))
	await runner.simulate_frames(3)
	_begin_phase({"label":"Populated field / six real sites and eight pointer motions per frame at 1x", "prepared_sites":6}, game)
	await _choose(runner, game._base.construction_kind, "workshop")
	var point := Vector2(190.375,130.625)
	await _sweep(runner, game, point, 8)
	_probe.require_condition(service.instances.size() == 6, "Hovering a populated field must not create a site.")
	if not _finish(game): return
	_begin_phase({"label":"Populated field / fresh authoritative click and subsequent work at 1x"}, game)
	_place(game, point, "workshop", 6)
	await _observe(runner)
	_finish(game)

func test_05_hover_is_provisional_and_click_uses_current_pose_and_geometry() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	_probe.pending = ["Open Build at 1x", "Trace real pointer validation and same-frame clicks"]
	if not await _open(runner, game): return
	var rear: RefCounted = game._base.simulation.rear
	var service := PlacementTrace.new(rear)
	rear.construction = service
	_begin_phase({"label":"Default game / provisional hover and fresh same-frame commit at 1x", "instrumentation":"Subclass counts calls to unchanged construction rules"}, game)
	await _choose(runner, game._base.construction_kind, "construction")
	await _sweep(runner, game, Vector2(100,40), 8)
	_probe.require_condition(service.hints > 0 and service.full_previews == 0 and service.path_queries == 0, "Pointer motion must use hints without full validation or route searches.")
	var hint_count: int = service.hints
	await runner.simulate_frames(3)
	_probe.require_condition(service.hints == hint_count, "A stationary blueprint must not poll validation.")
	var map: Control = game._base.base_map
	# No mouse-motion event or frame between the legal ghost and this invalid
	# click: the command's position must win over the previous hover result.
	var screen := _screen(map, Vector2(18,100))
	_button_event(map.get_viewport(),screen,MOUSE_BUTTON_LEFT,true)
	_button_event(map.get_viewport(),screen,MOUSE_BUTTON_LEFT,false)
	_probe.require_condition(service.instances.is_empty() and map.placement_active and service.full_previews == 1, "A same-frame click in a protected lane must reject despite the previous clear footprint.")
	_probe.require_condition(service.place("construction",Vector2(100,40)).ok, "Prepare a new obstruction at the previous hint position.")
	screen = _screen(map,Vector2(100,40))
	_button_event(map.get_viewport(),screen,MOUSE_BUTTON_LEFT,true)
	_button_event(map.get_viewport(),screen,MOUSE_BUTTON_LEFT,false)
	_probe.require_condition(service.instances.size() == 1 and map.placement_active, "A stationary stale hint must not bypass a new obstruction.")
	_place(game,Vector2(160.375,125.625),"construction",1)
	_probe.require_condition(service.path_queries > 0, "Successful placement still validates access routes.")
	_finish(game)

func _open(runner: GdUnitSceneRunner, game: Control) -> bool:
	await runner.simulate_frames(3)
	_begin_phase({"label":"Default game / open Build and start 1x through player controls"}, game)
	await _press(runner, _button(game, "Build"))
	await _press(runner, _button(game, "1×"))
	await runner.simulate_frames(3)
	_probe.require_condition(game._base.simulation.empty_field_opening and game._base.simulation.connected_world, "Use the actual connected empty-field game, never a substituted rear-only fixture.")
	return _finish(game)

func _begin_phase(action: Dictionary, game: Control) -> void:
	action.initial_logical_time = game._base.simulation.rear.time
	action.initial_speed = game._base.simulation.speed
	_probe.begin(action,game)

func _button(root: Node, text: String) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree(): return button
	return null

func _press(runner: GdUnitSceneRunner, button: Button) -> void:
	if not _probe._issues.is_empty(): return
	_probe.require_condition(is_instance_valid(button), "Required player control must exist.")
	if not is_instance_valid(button): return
	var parent := button.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await runner.simulate_frames(2)
	var receipt := {"count":0}
	var callback := func() -> void: receipt.count += 1
	button.pressed.connect(callback)
	_click(button.get_viewport(), button.get_global_rect().get_center())
	await runner.simulate_frames(1)
	button.pressed.disconnect(callback)
	_probe.require_condition(receipt.count == 1, "GUI click must activate the requested control exactly once: " + button.text, receipt)

func _choose(runner: GdUnitSceneRunner, option: OptionButton, kind: String) -> void:
	if not _probe._issues.is_empty(): return
	var target := -1
	for index in option.item_count:
		if option.get_item_metadata(index) == kind: target = index
	_probe.require_condition(target >= 0, "Facility must be in the player catalogue: " + kind)
	if target < 0: return
	await _press(runner, option)
	var popup := option.get_popup()
	_probe.require_condition(popup.visible, "Facility selector must open its popup.")
	popup.grab_focus()
	await _key(KEY_HOME)
	for step in option.item_count + 1:
		if popup.get_focused_item() == target: break
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await runner.simulate_frames(2)
	_probe.require_condition(option.selected == target, "Popup input must select the requested facility.")

func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame

func _screen(map: Control, point: Vector2) -> Vector2:
	return map.get_global_transform_with_canvas() * map.map_point(point)

func _motion(viewport: Viewport, point: Vector2, relative: Vector2 = Vector2.ZERO, buttons: MouseButtonMask = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = buttons
	viewport.push_input(event, true)

func _button_event(viewport: Viewport, point: Vector2, code: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = code
	event.pressed = down
	viewport.push_input(event, true)

func _click(viewport: Viewport, point: Vector2) -> void:
	_motion(viewport, point)
	_button_event(viewport, point, MOUSE_BUTTON_LEFT, true)
	_button_event(viewport, point, MOUSE_BUTTON_LEFT, false)

func _sweep(runner: GdUnitSceneRunner, game: Control, final_point: Vector2, burst: int, expect_ghost: bool = true) -> void:
	var map: Control = game._base.base_map
	var deadline := Time.get_ticks_usec() + int(_seconds() * 1000000)
	var index := 0
	var maximum := 0.0
	var dispatch_samples: Array[float] = []
	while Time.get_ticks_usec() < deadline and _probe._issues.is_empty():
		for sample in burst:
			var point := Vector2(70.125 + fposmod(index * 1.375, 100), 40.375 + fposmod(index * 0.625, 85))
			var started := Time.get_ticks_usec()
			_motion(map.get_viewport(), _screen(map, point))
			var dispatch_ms := float(Time.get_ticks_usec() - started) / 1000.0
			dispatch_samples.append(dispatch_ms)
			maximum = maxf(maximum, dispatch_ms)
			index += 1
		await runner.simulate_frames(1)
	_probe.action.motion_events = index
	_probe.action.maximum_motion_dispatch_ms = maximum
	_probe.action.motion_dispatch_ms = dispatch_samples
	# The first issue has already paused the world. Do not send more input or
	# report misleading final-pose failures against an interrupted sequence.
	if not _probe._issues.is_empty(): return
	_motion(map.get_viewport(), _screen(map, final_point))
	_probe.action.motion_events += 1
	await runner.simulate_frames(1)
	if not _probe._issues.is_empty(): return
	_probe.require_condition(maximum <= _probe._setting("TRENCHO_PERF_ACTION_MS", Budget.MAX_ACTION_MS), "Pointer handling exceeded the action budget.", {"milliseconds":maximum})
	if expect_ghost:
		var plan: Dictionary = map.placement_preview
		_probe.require_condition(plan.get("ok", false), "The final arbitrary pointer position must have a legal preview.", plan)
		_probe.require_condition(plan.has("center") and plan.center.distance_to(final_point) < 0.01, "Ghost coordinates must follow the pointer through the actual map transform.")

func _place(game: Control, point: Vector2, kind: String, before: int) -> void:
	if not _probe._issues.is_empty(): return
	var demo: Control = game._base
	var service: RefCounted = demo.simulation.rear.construction
	var screen := _screen(demo.base_map, point)
	_probe.require_condition(demo.base_map.get_global_rect().has_point(screen), "The intended pointer position must be visible on the map.")
	var started := Time.get_ticks_usec()
	_click(demo.get_viewport(), screen)
	_probe.action.click_dispatch_ms = float(Time.get_ticks_usec() - started) / 1000.0
	_probe.require_condition(service.instances.size() == before + 1, "One player click must create exactly one real site.")
	if service.instances.size() != before + 1: return
	var row: Dictionary = service.instances.values().back()
	_probe.require_condition(row.kind == kind and row.center.distance_to(point) < 0.01, "The placed kind and center must match the pointer, not exact-coordinate defaults.", row)
	_probe.require_condition(row.quarter_turn == demo.construction_turn.button_pressed, "The placed orientation must match the rotated ghost.")
	_probe.require_condition(row.progress == 0 and row.state == "Awaiting M11", "An empty-world placement must await actual delivered materials and builders.")

func _seconds() -> float:
	var configured := OS.get_environment("TRENCHO_PERF_OBSERVATION_SECONDS")
	return maxf(2.0, float(configured)) if not configured.is_empty() else 2.0

func _observe(runner: GdUnitSceneRunner) -> void:
	var deadline := Time.get_ticks_usec() + int(_seconds() * 1000000)
	while Time.get_ticks_usec() < deadline and _probe._issues.is_empty(): await runner.simulate_frames(1)

func _finish(game: Control) -> bool:
	if _probe._issues.is_empty(): _probe.require_condition(game._base.simulation.speed == 1, "The player sequence must remain at 1x.")
	_probe.action.logical_time = game._base.simulation.rear.time
	_probe.action.owed_simulation_seconds = game._base.simulation.owed_simulation_seconds
	var elapsed := float(Time.get_ticks_usec()-_probe._started_usec)/1000000.0
	var progressed: float = game._base.simulation.rear.time-float(_probe.action.initial_logical_time)
	_probe.action.simulation_progress_seconds = progressed
	if _probe._issues.is_empty() and _probe.action.initial_speed == 1 and elapsed >= 1.0:
		_probe.require_condition(progressed >= elapsed-0.25, "The real simulation must keep pace with 1x wall time.", {"wall_seconds":elapsed,"simulation_seconds":progressed})
		_probe.require_condition(game._base.simulation.owed_simulation_seconds <= 0.25, "A passing frame budget must not hide growing simulation debt.", {"owed_seconds":game._base.simulation.owed_simulation_seconds})
	if not _probe.pending.is_empty(): _probe.pending.pop_front()
	var result: Dictionary = _probe.finish(float(_probe.action.get("click_dispatch_ms", 0)), "default_game_pointer_placement")
	assert_bool(result.ok).override_failure_message("Pointer placement failed; logs: " + _probe.directory).is_true()
	return result.ok
