extends GdUnitTestSuite
## Actual engine GUI input; isolated fixtures, exhaustive runtime button inventory.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Main = preload("res://game/main/main.gd")
const Facilities = preload("res://game/construction/construction_catalogue.gd")
const Probe = preload("res://game/diagnostics/tests/gdunit/fixtures/ui_action_probe.gd")
var _probe: Node
var _previous_embed := false
var _original_diagnostics := ""

func before_test() -> void:
	_original_diagnostics = OS.get_environment("TRENCHO_HQ_DIAGNOSTICS")
	_previous_embed = get_tree().root.gui_embed_subwindows
	get_tree().root.gui_embed_subwindows = true
	_probe = Probe.new()
	add_child(_probe)

func after_test() -> void:
	OS.set_environment("TRENCHO_HQ_DIAGNOSTICS", _original_diagnostics)
	_probe.queue_free()
	await get_tree().process_frame
	get_tree().root.gui_embed_subwindows = _previous_embed

func test_10_every_buildable_facility_placement_rotation_rejection_and_cancellation(timeout: int = 900000) -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	var cases: Array = []
	for kind in Facilities.SPECS:
		if not Facilities.SPECS[kind].get("fixed", false):
			for turned in [false, true]: cases.append({"kind": kind, "turned": turned, "label": "Build %s / rotated %s" % [kind, turned]})
	_probe.pending = cases.duplicate(true)
	for spec in cases:
		_bind_fixture(game, true)
		var demo: Control = game._base
		demo.show_panel("Build")
		_select_kind(demo, spec.kind)
		demo.construction_turn.set_pressed_no_signal(spec.turned)
		await runner.simulate_frames(2)
		_probe.begin(spec, game)
		var cost := 0.0
		cost = maxf(cost, await _press(runner, _find_button(game, "Place on field")))
		_probe.require_condition(demo.base_map.placement_active, "Place on field must activate placement.")
		cost = maxf(cost, await _press(runner, _find_button(game, "Cancel placement")))
		_probe.require_condition(not demo.base_map.placement_active, "Cancel placement must remove the preview.")
		cost = maxf(cost, await _press(runner, _find_button(game, "Place on field")))
		_key(demo.get_viewport(), KEY_ESCAPE)
		await runner.simulate_frames(1)
		_probe.require_condition(not demo.base_map.placement_active, "Escape must cancel placement.")
		cost = maxf(cost, await _press(runner, _find_button(game, "Exact placement coordinates")))
		demo.construction_x.set_value_no_signal(110)
		demo.construction_y.set_value_no_signal(40)
		var service: RefCounted = demo.simulation.rear.construction
		var ledger: RefCounted = demo.simulation.rear.ledger
		var stock_before: int = ledger.total_stock("M11")
		cost = maxf(cost, await _press(runner, _find_button(game, "Preview legal site")))
		_probe.require_condition(demo.base_map.placement_preview.get("ok", false), "Every buildable kind/orientation needs a legal fixture position.")
		_probe.require_condition(service.instances.is_empty(), "A preview must not create a site.")
		cost = maxf(cost, await _press(runner, _find_button(game, "Place physical site")))
		_probe.require_condition(service.instances.size() == 1, "A placement must create exactly one site.")
		if service.instances.size() != 1:
			if not _complete(cost): return
			continue
		var id: String = service.instances.keys()[0]
		var row: Dictionary = service.instances[id]
		_probe.require_condition(row.kind == spec.kind and row.quarter_turn == spec.turned, "Placed kind and orientation must match the controls.")
		_probe.require_condition(row.state == "Awaiting M11", "Placement must await physical construction work.")
		cost = maxf(cost, await _press(runner, _find_button(game, "Place physical site")))
		_probe.require_condition(service.instances.size() == 1, "Overlapping placement must be rejected without another site.")
		demo.construction_x.set_value_no_signal(-100)
		cost = maxf(cost, await _press(runner, _find_button(game, "Place physical site")))
		_probe.require_condition(service.instances.size() == 1, "Out-of-bounds placement must be rejected.")
		_select_site(demo, id)
		cost = maxf(cost, await _press(runner, _find_button(game, "Cancel unfinished site")))
		_probe.require_condition(row.state == "Cancelled", "Cancel unfinished site must cancel the selected actual site.")
		_probe.require_condition(ledger.total_stock("M11") == stock_before, "Pre-work cancellation must conserve all building materials.")
		_probe.require_condition(service.preview(spec.kind, Vector2(110, 40), spec.turned).ok, "A cleared cancelled footprint must become placeable again.")
		cost = maxf(cost, await _press(runner, _find_button(game, "Cancel unfinished site")))
		_probe.require_condition(row.state == "Cancelled" and ledger.total_stock("M11") == stock_before, "Repeated cancellation must not duplicate or consume materials.")
		demo.select_build_kind(spec.kind)
		var original_turn: bool = demo.construction_turn.button_pressed
		_key(demo.get_viewport(), KEY_R)
		_probe.require_condition(demo.construction_turn.button_pressed != original_turn, "R must rotate the active footprint.")
		_key(demo.get_viewport(), KEY_R)
		var map_position: Vector2 = demo.base_map.get_global_transform_with_canvas() * demo.base_map.map_point(Vector2(110, 40))
		_mouse(demo.get_viewport(), map_position, MOUSE_BUTTON_RIGHT)
		_probe.require_condition(not demo.base_map.placement_active, "Right-click must cancel the active preview.")
		demo.select_build_kind(spec.kind)
		_mouse(demo.get_viewport(), map_position, MOUSE_BUTTON_LEFT)
		await runner.simulate_frames(2)
		_probe.require_condition(service.instances.size() == 2, "A real field click must place exactly one additional site.")
		if service.instances.size() == 2:
			var map_id: String = service.instances.keys()[1]
			_select_site(demo, map_id)
			cost = maxf(cost, await _press(runner, _find_button(game, "Cancel unfinished site")))
			_probe.require_condition(service.instances[map_id].state == "Cancelled", "The field-placed site must cancel through the same UI.")
		for fixed in ["terminal", "personnel"]:
			_probe.require_condition(not service.place(fixed, Vector2(110, 40)).ok, "Fixed facilities must remain unbuildable.")
		await _observe(runner)
		if not _complete(cost): return

func test_11_every_started_building_cancellation_keeps_consumed_materials_consumed(timeout: int = 900000) -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	var kinds: Array = []
	for kind in Facilities.SPECS:
		if not Facilities.SPECS[kind].get("fixed", false):
			for completed in [false, true]: kinds.append({"kind": kind, "completed": completed})
	_probe.pending = kinds.duplicate()
	for spec in kinds:
		var kind: String = spec.kind
		var label: String = ("Completed cancellation rejection: " if spec.completed else "Started cancellation: ") + kind
		_bind_fixture(game, false)
		var demo: Control = game._base
		var rear: RefCounted = demo.simulation.rear
		var service: RefCounted = rear.construction
		var point := _legal_point(service, kind)
		_probe.begin({"label": label, "kind": kind, "completed": spec.completed}, game)
		_probe.require_condition(point.is_finite(), "The prepared rear needs a legal placement for every facility.")
		var placed: Dictionary = service.place(kind, point)
		_probe.require_condition(placed.ok, "Started-work fixture must place a real site.", placed)
		if not placed.ok:
			if not _complete(): return
			continue
		# Setup uses legal commands and explicit time outside measured input. It is
		# not a claim that 900 simulation seconds elapsed at live 1x wall speed.
		_probe.active = false
		var id: String = placed.id
		var row: Dictionary = service.instances[id]
		rear.construction.set_office_staff("construction", 1)
		rear.advance_time(150)
		service.order_materials(id, "depot")
		rear.set_target("hauling", 4)
		rear.advance_time(650)
		service.set_builders(id, 1)
		for step in 800:
			rear.advance_time(0.5)
			if step % 80 == 0: _probe._heartbeat("setup")
			if row.state == "Building" and row.progress > 0: break
		if spec.completed:
			for step in 2400:
				rear.advance_time(0.5)
				if step % 80 == 0: _probe._heartbeat("setup")
				if row.state == "Complete": break
		demo.show_panel("Build")
		demo._refresh()
		_select_site(demo, id)
		demo.session.set_speed(1)
		await runner.simulate_frames(2)
		_probe.begin({"label": label, "kind": kind, "completed": spec.completed}, game)
		_probe.require_condition(row.state == ("Complete" if spec.completed else "Building") and row.progress > 0, "Fixture must have earned the requested construction state.", {"state": row.state, "progress": row.progress})
		var remaining: int = rear.ledger.total_stock("M11")
		_probe.require_condition(remaining == 500 - (int(row.m11) if spec.completed else int(row.m11 / 2)), "Construction must consume its own starting half or full completed recipe.")
		var cost: float = await _press(runner, _find_button(game, "Cancel unfinished site"))
		_probe.require_condition(row.state == ("Complete" if spec.completed else "Cancelled"), "Unfinished work must cancel; completed facilities must reject cancellation.")
		_probe.require_condition(rear.ledger.total_stock("M11") == remaining, "Cancellation must not refund consumed inputs or delete recoverable material.")
		await _observe(runner)
		if not _complete(cost): return

func test_12_every_runtime_button_and_menu_choice_in_game_and_retained_reviews(timeout: int = 3600000) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/diagnostics/tests/gdunit/fixtures/ui_button_contracts.json"))
	var fresh: bool = manifest.has("source_sha256") and not manifest.source_sha256.is_empty()
	for path in manifest.get("source_sha256", {}):
		var source := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		fresh = fresh and source.sha256_text() == manifest.source_sha256[path]
	assert_bool(fresh).override_failure_message("UI button inventory is stale. Run Update System Map.cmd before testing changed UI source.").is_true()
	if not fresh: return
	var profiles: Array = [{"scene": "res://game/main/main.tscn", "label": "Main game", "main": true},
		{"scene": "res://game/rear_base/base_demo.tscn", "label": "Standalone rear", "standalone": true},
		{"scene": "res://game/main/main.tscn", "label": "HQ diagnostics", "main": true, "diagnostics": true}]
	for label in Main.REVIEWS: profiles.append({"scene": Main.REVIEWS[label].resource_path, "label": label})
	var all_coverage: Array[Dictionary] = []
	var profile_inventory := {}
	for profile in profiles:
		var profile_filter := OS.get_environment("TRENCHO_UI_PROFILE")
		if not profile_filter.is_empty() and not str(profile.label).matchn(profile_filter): continue
		var previous_diagnostics := OS.get_environment("TRENCHO_HQ_DIAGNOSTICS")
		OS.set_environment("TRENCHO_HQ_DIAGNOSTICS", "1" if profile.get("diagnostics", false) else "")
		var runner := scene_runner(profile.scene)
		var root: Control = runner.scene()
		await runner.simulate_frames(2)
		if profile.get("main", false) or profile.get("standalone", false): _bind_fixture(root, false)
		var queue: Array[Dictionary] = _bootstrap_inventory(root)
		var text_filter := OS.get_environment("TRENCHO_UI_BUTTON_TEXT")
		if not text_filter.is_empty():
			var filtered: Array[Dictionary] = []
			for entry in queue:
				if text_filter.to_lower() in entry.text.to_lower(): filtered.append(entry)
			queue = filtered
		var applicable := queue.size()
		profile_inventory[profile.label] = applicable
		_probe._save("profile_inventory.json", profile_inventory)
		assert_int(applicable).override_failure_message("The selected UI profile/filter discovered no buttons: " + profile.label).is_greater(0)
		var seen := {}
		for entry in queue: seen[entry.key] = true
		_probe.pending = queue.duplicate(true)
		while not queue.is_empty():
			var entry: Dictionary = queue.pop_front()
			_probe.pending = queue.duplicate(true)
			if profile.get("main", false) or profile.get("standalone", false): _bind_fixture(root, false)
			root.set_process(true)
			root.set_physics_process(true)
			_prepare(root, entry)
			await runner.simulate_frames(2)
			_probe.begin({"label": profile.label + " > " + entry.text, "target": entry, "profile": profile}, root)
			if entry.has("setup_ready"): _probe.require_condition(entry.setup_ready, "Confirmation setup must have a consumed live batch and a real confirmation token.", entry.get("setup_details", {}))
			var button: Button = _locate(root, entry)
			var cost := 0.0
			if entry.kind == "option":
				cost = await _press(runner, button)
				if is_instance_valid(button) and not button.disabled and button.item_count > 0:
					var popup: PopupMenu = button.get_popup()
					var next := -1
					for index in button.item_count:
						if not button.is_item_disabled(index) and (index != button.selected or button.item_count == 1):
							next = index
							break
					if next >= 0:
						popup.set_focused_item(next)
						await _accept_popup(runner, popup)
						if is_instance_valid(button): _probe.require_condition(button.selected == next, "Native option-button input must select the intended available choice.")
			elif entry.kind == "menu_item":
				cost = await _press(runner, button)
				if is_instance_valid(button):
					var popup: PopupMenu = button.get_popup()
					_probe.require_condition(popup.visible, "A real menu-button press must open its popup.")
					popup.set_focused_item(entry.index)
					var receipt := {"id": -1}
					var expected_id: int = popup.get_item_id(entry.index)
					var selected := func(id: int) -> void: receipt.id = id
					popup.id_pressed.connect(selected)
					await _accept_popup(runner, popup)
					await runner.simulate_frames(1)
					if is_instance_valid(popup): popup.id_pressed.disconnect(selected)
					_probe.require_condition(receipt.id == expected_id, "Keyboard acceptance must activate the intended popup item.")
			else: cost = await _press(runner, button)
			_assert_navigation(root, entry, button if is_instance_valid(button) else null)
			if entry.get("role", "") == "review_production":
				_probe.require_condition(root.production.snapshot().recipe == entry.expected_recipe, "Review recipe confirmation must preserve or change the intended recipe.")
				if not entry.accept: _probe.require_condition(root.production.batch.get("id", "") == entry.before_batch, "Declining a review recipe change must preserve the consumed batch.")
			var demo: Control = root._base if root.get("_base") != null else (root if root.get("construction_kind") != null else null)
			if demo != null:
				if entry.kind == "dialog":
					if entry.role == "shell":
						_probe.require_condition(demo.simulation.get_instance_id() != entry.before_simulation if entry.accept else demo.simulation.get_instance_id() == entry.before_simulation, "New-game confirmation must replace the session only on acceptance.")
					else:
						var activity: RefCounted = demo.simulation.rear.production
						_probe.require_condition(activity.snapshot().recipe == entry.expected_recipe, "Recipe confirmation/decline must select the correct recipe.")
						if not entry.accept: _probe.require_condition(activity.batch.get("id", "") == entry.before_batch, "Declining must preserve the real consumed batch.")
				_probe.action.speed_after_input = demo.simulation.speed
				_probe.action.feedback = demo.feedback.text
				if entry.text == "Pause": _probe.require_condition(demo.simulation.speed == 0, "Pause must stop the shared clock.")
				if entry.text == "2x": _probe.require_condition(demo.simulation.speed == 2, "2x must select double speed.")
				demo.session.set_speed(1)
			await _observe(runner)
			var disabled_only: bool = not _probe.action.get("input_receipts", []).is_empty()
			for receipt in _probe.action.get("input_receipts", []): disabled_only = disabled_only and receipt.disabled
			var report: Dictionary = _probe.finish(cost, "disabled_input_rejected" if disabled_only else "handler_input_exercised")
			all_coverage.append(report)
			_probe._save("button_coverage.json", {"profiles": profiles, "cases": all_coverage, "pending": queue,
				"profile_filter": profile_filter, "text_filter": text_filter,
				"scope": "Concrete runtime button instances and menu choices, with disabled/hidden/unreached targets failing coverage. Filters certify only their selected subset. Successful input does not by itself prove every domain outcome or state."})
			assert_bool(report.ok).override_failure_message("UI failure: %s. Logs: %s" % [report.action.label, _probe.directory]).is_true()
			if not report.ok and not _continue_after_issue(): return
			for found in _inventory(root):
				if not text_filter.is_empty() and text_filter.to_lower() not in found.text.to_lower(): continue
				if not seen.has(found.key):
					seen[found.key] = true
					queue.append(found)
			if seen.size() > 5000:
				fail("Unbounded UI discovery exceeded 5000 distinct controls; inspect dynamic labels.")
				return
		root.queue_free()
		await get_tree().process_frame
		OS.set_environment("TRENCHO_HQ_DIAGNOSTICS", previous_diagnostics)
	assert_int(all_coverage.size()).override_failure_message("No UI targets were exercised; check the profile/button filter.").is_greater(0)
	if OS.get_environment("TRENCHO_UI_PROFILE").is_empty() and OS.get_environment("TRENCHO_UI_BUTTON_TEXT").is_empty():
		var missing: Array = []
		for definition in manifest.button_definitions:
			var matched := false
			for result in all_coverage:
				var target: Dictionary = result.action.target
				if target.owner.trim_prefix("res://") != definition.path: continue
				if definition.dynamic:
					if not str(target.text).begins_with(definition.prefix): continue
				elif target.text != definition.label: continue
				for receipt in result.action.get("input_receipts", []):
					if receipt.pressed_signals == 1: matched = true
			if not matched: missing.append(definition)
		_probe._save("source_button_coverage.json", {"missing": missing, "declared_definitions": manifest.button_definitions.size(), "runtime_cases": all_coverage.size()})
		assert_array(missing).override_failure_message("Declared UI buttons were not pressed. Inspect source_button_coverage.json; missing coverage is not a pass.").is_empty()

func _bind_fixture(root: Control, empty_field: bool) -> void:
	var demo: Control = root._base if root.get("_base") != null else root
	var fixture := Base.new(not empty_field, false, false, Vector2(1640, 91), true, {}, empty_field)
	if not empty_field:
		for number in range(1, 12):
			var type := "M%02d" % number
			fixture.rear.ledger.add_stock("ui-fixture-" + type, type, 500, 1.0, "depot", fixture.rear.PLAYER)
		fixture.receiving.buy_resources({"M01": 1})
		fixture.rear.request_haul("depot", "workshop_input", "M01", 1)
		fixture.rear.production.set_stock_target(1)
		fixture.rear.heavy_production.set_stock_target(1)
	demo.simulation = fixture
	demo._bind_started_session(true)
	demo.construction_turn.set_pressed_no_signal(false)
	var coordinates_toggle := _find_button(root, "Exact placement coordinates")
	if coordinates_toggle != null: coordinates_toggle.button_pressed = false
	for dialog in root.find_children("*", "ConfirmationDialog", true, false): dialog.hide()
	for popup in root.find_children("*", "PopupMenu", true, false): popup.hide()
	for button in root.find_children("*", "Button", true, false):
		if button is MenuButton or button is OptionButton: button.get_popup().hide()
	if root.get("_shell") != null: root._shell._help.hide()
	demo.session.set_speed(1)
	demo.session.set_physics_process(true)

func _select_kind(demo: Control, kind: String) -> void:
	for index in demo.construction_kind.item_count:
		if str(demo.construction_kind.get_item_metadata(index)) == kind:
			demo.construction_kind.select(index)
			demo.construction_kind.item_selected.emit(index)
			return

func _select_site(demo: Control, id: String) -> void:
	var index: int = demo.construction_ids.find(id)
	if index >= 0:
		demo.construction_rows.select(index)
		demo.construction_rows.item_selected.emit(index)

func _legal_point(service: RefCounted, kind: String) -> Vector2:
	for y in range(15, 166, 10):
		for x in range(15, 226, 10):
			var point := Vector2(x, y)
			if service.preview(kind, point).ok: return point
	return Vector2(INF, INF)

func _find_button(root: Node, title: String) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if button.text == title and button.is_visible_in_tree(): return button
	return null

func _press(runner: GdUnitSceneRunner, button: Button) -> float:
	if not _probe._issues.is_empty(): return 0
	_probe.require_condition(is_instance_valid(button), "A required button is missing from the prepared UI.", {"classification": "coverage_gap"})
	if not is_instance_valid(button): return 0
	var child: Node = button
	var parent := button.get_parent()
	while parent != null:
		if parent is TabContainer and child is Control:
			var tab: int = parent.get_tab_idx_from_control(child)
			if tab >= 0: parent.current_tab = tab
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		child = parent
		parent = parent.get_parent()
	await runner.simulate_frames(1)
	_probe.require_condition(button.is_visible_in_tree(), "A required button must be reachable; hidden is not a pass.", {"text": button.text, "visible": button.is_visible_in_tree(), "disabled": button.disabled, "classification": "coverage_gap"})
	if not button.is_visible_in_tree(): return 0
	var was_disabled := button.disabled
	var was_pressed := button.button_pressed
	var target_rect := button.get_global_rect()
	var viewport_rect := button.get_viewport().get_visible_rect()
	var native_transform := button.get_viewport().get_screen_transform()
	var native_position: Vector2 = native_transform * button.get_global_transform_with_canvas() * (button.size / 2.0)
	button.get_window().grab_focus()
	var receipt := {"calls": 0, "pressed_usec": 0}
	var callback := func() -> void:
		receipt.calls += 1
		receipt.pressed_usec = Time.get_ticks_usec()
	button.pressed.connect(callback)
	var started := Time.get_ticks_usec()
	if button is MenuButton or button is OptionButton or was_disabled:
		runner.set_mouse_position(native_position)
		await runner.await_input_processed()
		started = Time.get_ticks_usec()
		await runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		await runner.await_input_processed()
	elif button.focus_mode == Control.FOCUS_ALL:
		button.grab_focus()
		_key(button.get_viewport(), KEY_SPACE)
	else: _mouse(button.get_viewport(), button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	var elapsed := float(maxi(started, receipt.pressed_usec) - started) / 1000.0
	if is_instance_valid(button): button.pressed.disconnect(callback)
	if not _probe.action.has("input_receipts"): _probe.action.input_receipts = []
	_probe.action.input_receipts.append({"text": button.text if is_instance_valid(button) else "freed after activation", "pressed_signals": receipt.calls, "disabled": was_disabled,
		"target_rect": str(target_rect), "viewport_rect": str(viewport_rect), "native_position": str(native_position),
		"screen_transform": str(native_transform), "center_in_viewport": viewport_rect.has_point(target_rect.get_center())})
	_probe.require_condition(receipt.calls == (0 if was_disabled else 1), "Engine GUI input must emit pressed once when enabled and never when disabled.", {"received": receipt.calls, "disabled": was_disabled})
	if is_instance_valid(button) and (button is CheckBox or button is CheckButton):
		_probe.require_condition(button.button_pressed == (was_pressed if was_disabled else not was_pressed), "Checkbox input must toggle exactly once, or remain unchanged when disabled.")
	await runner.simulate_frames(1)
	return elapsed

func _key(viewport: Viewport, key: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		viewport.push_input(event)

func _mouse(viewport: Viewport, position: Vector2, button: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion,true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = button
		event.pressed = down
		viewport.push_input(event,true)

func _accept_popup(runner: GdUnitSceneRunner, popup: PopupMenu) -> void:
	popup.grab_focus()
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = down
		# Special keys have no Unicode text. GdUnit 6.2.2's key helper assigns
		# the physical key code to unicode, which Godot 4.7 rejects for Enter.
		event.unicode = 0
		Input.parse_input_event(event)
		await runner.await_input_processed()

func _observe(runner: GdUnitSceneRunner) -> void:
	var configured := OS.get_environment("TRENCHO_PERF_OBSERVATION_SECONDS")
	var seconds := 2.0 if configured.is_empty() else float(configured)
	var deadline := Time.get_ticks_usec() + int(seconds * 1000000)
	while Time.get_ticks_usec() < deadline:
		await runner.simulate_frames(1)
		if not _probe._issues.is_empty(): break

func _complete(cost: float = 0.0) -> bool:
	if not _probe.pending.is_empty(): _probe.pending.pop_front()
	var result: Dictionary = _probe.finish(cost)
	assert_bool(result.ok).override_failure_message("UI contract failed: %s. Logs: %s" % [result.action.label, _probe.directory]).is_true()
	return result.ok or _continue_after_issue()

func _continue_after_issue() -> bool:
	return OS.get_environment("TRENCHO_UI_CONTINUE_AFTER_ISSUES") == "1"

func _inventory(root: Control) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for button in root.find_children("*", "Button", true, false):
		var internal := false
		var child: Node = button
		while child != root and child.get_parent() != null:
			if not child.get_parent().get_children().has(child): internal = true
			child = child.get_parent()
		if internal: continue # Engine-owned subcontrols are not separate project actions; dialogs are added explicitly below.
		if root.get("_base") != null:
			var demo: Control = root._base
			var standalone := false
			for container in [demo._local_clock_controls, demo._standalone_actions, demo._standalone_session_actions, demo._advanced_panels]:
				if container == button or container.is_ancestor_of(button): standalone = true
			if standalone: continue # Covered by the standalone rear profile.
		var connections: Array = button.pressed.get_connections() + button.toggled.get_connections()
		if button is MenuButton: connections.append_array(button.get_popup().id_pressed.get_connections())
		if button is OptionButton: connections.append_array(button.item_selected.get_connections())
		var owner_path := ""
		for connection in connections:
			var owner: Object = connection.callable.get_object()
			if owner != null and owner.get_script() is GDScript:
				owner_path = owner.get_script().resource_path
				break
		if owner_path.is_empty():
			var ancestor: Node = button.get_parent()
			while ancestor != null:
				if ancestor.get_script() is GDScript:
					owner_path = ancestor.get_script().resource_path
					break
				ancestor = ancestor.get_parent()
		if owner_path.is_empty(): continue
		if root.get("_review") != null and root._review.is_ancestor_of(button) and owner_path != "res://game/main/main.gd": continue # Reviewed through its independent scene profile.
		var panel := ""
		var node: Node = button
		while node != root and node != null:
			if node.has_meta("panel_title"): panel = str(node.get_meta("panel_title"))
			node = node.get_parent()
		var entry := {"text": button.text, "owner": owner_path, "panel": panel, "kind": "button"}
		if root.get("production") != null: entry.review_recipe = root.production.snapshot().recipe
		if root.get("_movement_controls") != null and root._movement_controls.is_ancestor_of(button): entry.terrain_movement = true
		entry.key = owner_path + "|" + panel + "|" + button.text
		entry.path = str(root.get_path_to(button))
		var route: Array[int] = []
		var ancestor: Node = button
		while ancestor != root and ancestor != null:
			route.push_front(ancestor.get_index(true))
			ancestor = ancestor.get_parent()
		entry.route = route
		var demo: Control = root._base if root.get("_base") != null else (root if root.get("construction_kind") != null else null)
		if demo != null:
			entry.heavy = demo.heavy_controls.is_ancestor_of(button)
			entry.legacy_session = demo._standalone_session_actions.is_ancestor_of(button)
			if demo.production_controls.is_ancestor_of(button):
				entry.production_duty = demo._context_duty()
				entry.production_recipe = str(demo._activity().get("_recipe"))
			for duty in demo.workforce_panel.controls:
				if demo.workforce_panel.controls[duty].priority == button: entry.workforce_duty = duty
		if button is OptionButton:
			entry.kind = "option"
			entry.key = owner_path + "|option|" + str(route)
		if entry.has("production_duty"):
			entry.key += "|production:" + ("vehicle_works" if entry.heavy else entry.production_duty)
		if entry.has("workforce_duty"): entry.key = owner_path + "|priority:" + entry.workforce_duty
		result.append(entry)
		if button is MenuButton:
			var popup: PopupMenu = button.get_popup()
			for index in popup.item_count:
				if popup.is_item_separator(index): continue
				var choice: Dictionary = entry.duplicate()
				choice.kind = "menu_item"
				choice.index = index
				choice.key += "|" + str(index)
				result.append(choice)
	for dialog in root.find_children("*", "ConfirmationDialog", true, false):
		var role := ""
		var owner_path := ""
		for connection in dialog.confirmed.get_connections():
			var owner: Object = connection.callable.get_object()
			if owner != null and owner.get_script() is GDScript: owner_path = owner.get_script().resource_path
		if owner_path == "res://game/ui/command_shell.gd": role = "shell"
		elif owner_path == "res://game/rear_base/base_demo.gd": role = "production"
		elif root.get("_recipe_dialog") == dialog: role = "review_production"
		else: continue
		for accept in [false, true]:
			var button: Button = dialog.get_ok_button() if accept else dialog.get_cancel_button()
			result.append({"key": owner_path + "|dialog|" + role + "|" + str(accept), "text": button.text,
				"owner": owner_path, "panel": "", "kind": "dialog", "role": role, "accept": accept})
	return result

func _locate(root: Control, entry: Dictionary) -> Button:
	if entry.has("workforce_duty"):
		var demo: Control = root._base if root.get("_base") != null else root
		return demo.workforce_panel.controls.get(entry.workforce_duty, {}).get("priority", null)
	if entry.kind == "dialog":
		if entry.role == "review_production":
			return root._recipe_dialog.get_ok_button() if entry.accept else root._recipe_dialog.get_cancel_button()
		var demo: Control = root._base if root.get("_base") != null else root
		var dialog: ConfirmationDialog = root._shell._confirmation if entry.role == "shell" else demo.confirmation
		return dialog.get_ok_button() if entry.accept else dialog.get_cancel_button()
	if entry.has("path"):
		var target := root.get_node_or_null(NodePath(entry.path))
		if target is Button and (entry.kind == "option" or target.text == entry.text): return target
	if entry.has("route"):
		var target: Node = root
		for index in entry.route:
			if target == null or index >= target.get_child_count(true):
				target = null
				break
			target = target.get_child(index, true)
		if target is Button and (entry.kind == "option" or target.text == entry.text): return target
	for button in root.find_children("*", "Button", true, false):
		if button.text != entry.text: continue
		for connection in button.pressed.get_connections() + button.toggled.get_connections():
			var owner: Object = connection.callable.get_object()
			if owner != null and owner.get_script() is GDScript and owner.get_script().resource_path == entry.owner: return button
		if button is MenuButton: return button
	return null

func _prepare(root: Control, entry: Dictionary) -> void:
	for button in root.find_children("*", "Button", true, false):
		if button is MenuButton or button is OptionButton: button.get_popup().hide()
	var demo: Control = root._base if root.get("_base") != null else (root if root.get("construction_kind") != null else null)
	if demo == null:
		if root.get("_recipe_dialog") != null: root._recipe_dialog.hide()
		if entry.get("terrain_movement", false): root._choose_mode(0)
		if entry.has("review_recipe") and root.production.snapshot().recipe != entry.review_recipe:
			root.production.cancel()
			root.production.request_recipe(entry.review_recipe)
			root._refresh()
		if entry.get("role", "") == "review_production": _prepare_review_confirmation(root, entry)
		return
	if entry.text in ["Request delivery to HQ","Cancel remaining delivery"]:
		# These controls belong to the actual empty-field game. The retained
		# prebuilt review intentionally cannot book automatic live deliveries.
		_bind_fixture(root,true)
		if entry.text == "Cancel remaining delivery":
			demo.session.automatic_logistics.request_delivery("E02",100)
		demo._refresh_army_requests()
	if entry.kind == "dialog":
		if entry.role == "shell":
			entry.before_simulation = demo.simulation.get_instance_id()
			root._shell._confirmation.popup_centered()
		else:
			_prepare_recipe_confirmation(demo)
			entry.before_batch = demo.simulation.rear.production.batch.get("id", "")
			entry.expected_recipe = demo.simulation.rear.production._pending.get("to", "") if entry.accept else demo.simulation.rear.production.snapshot().recipe
		return
	if not entry.panel.is_empty(): demo.show_panel(entry.panel)
	if root.get("_base") != null: root._show_base()
	if root.get("_base") != null and Main.REVIEWS.has(entry.text): root._show_diagnostics()
	if entry.get("heavy", false) or entry.has("production_duty"):
		var duty: String = "vehicle_works" if entry.get("heavy", false) else entry.production_duty
		for index in demo.facility.item_count:
			if str(demo.facility.get_item_metadata(index)) == duty: demo.facility.select(index)
		var activity: RefCounted = demo._activity()
		if entry.get("production_duty", "") == duty and entry.has("production_recipe") and activity.has_method("request_recipe"):
			activity.request_recipe(entry.production_recipe)
		demo._load_production()
		demo._refresh()
	if entry.has("workforce_duty"):
		if not demo.simulation.rear.requests.has(entry.workforce_duty) and str(entry.workforce_duty).begins_with("builders-"):
			var service: RefCounted = demo.simulation.rear.construction
			service.place("depot", _legal_point(service, "depot"))
		demo.show_panel("Workers/Jobs")
		demo._refresh()
	if entry.text in ["Preview legal site", "Place physical site"]:
		var toggle := _find_button(root, "Exact placement coordinates")
		if toggle != null: toggle.button_pressed = true
		demo.construction_x.value = 110
		demo.construction_y.value = 40
	if entry.text in ["Cancel unfinished site", "Deliver Building Materials to site", "Set builders"]:
		demo.confirm_build_at(Vector2(110, 40))
	if entry.text == "Cancel placement": demo.select_build_kind("workshop")
	if entry.text == "Buy resources":
		demo.cart.M01.value = 1
		demo._refresh_purchase_quote()
	if entry.text == "Close":
		if root.get("_shell") != null: root._shell._help.show()
	if entry.text.begins_with("Buy recovery instructor"):
		var recovery := _find_button(root, "Specialist recovery details")
		if recovery != null: recovery.button_pressed = true
	if entry.text == "Start diagnostic session" or entry.get("legacy_session", false):
		var legacy := _find_button(root, "Legacy session options")
		if legacy != null: legacy.button_pressed = true
	if demo.orders.item_count > 0: demo.orders.select(0)
	if demo.jobs.item_count > 0: demo.jobs.select(0)
	if demo.people.item_count > 0: demo.people.select(0)

func _prepare_recipe_confirmation(demo: Control) -> void:
	demo.show_panel("Work")
	for index in demo.facility.item_count:
		if str(demo.facility.get_item_metadata(index)) == "workshop": demo.facility.select(index)
	demo._load_production()
	var rear: RefCounted = demo.simulation.rear
	var activity: RefCounted = rear.production
	activity.set_stock_target(100)
	var view: Dictionary = activity.snapshot()
	for type in view.inputs:
		rear.ledger.add_stock("ui-confirmation-" + type, type, int(view.inputs[type]) * 2, 1.0, view.input_store, rear.PLAYER)
	rear.set_target("workshop", 1)
	for step in 1000:
		rear.advance_time(0.5)
		if step % 80 == 0: _probe._heartbeat("setup")
		if not activity.batch.is_empty() and activity.batch.work > 0: break
	activity.set_paused(true)
	demo._load_production()
	for index in demo.recipe.item_count:
		if str(demo.recipe.get_item_metadata(index)) != activity.snapshot().recipe and not demo.recipe.is_item_disabled(index):
			demo.recipe.select(index)
			break
	demo._change_recipe()

func _bootstrap_inventory(root: Control) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	var demo: Control = root._base if root.get("_base") != null else (root if root.get("construction_kind") != null else null)
	if demo == null: return _inventory(root)
	demo.show_panel("Workers/Jobs")
	demo._refresh()
	for index in demo.facility.item_count:
		demo.show_panel("Work")
		demo.facility.select(index)
		demo._load_production()
		demo._refresh()
		for entry in _inventory(root):
			if not seen.has(entry.key):
				seen[entry.key] = true
				result.append(entry)
	return result

func _prepare_review_confirmation(root: Control, entry: Dictionary) -> void:
	var activity: RefCounted = root.production
	activity.cancel()
	activity.resume()
	activity.set_stock_target(100)
	var view: Dictionary = activity.snapshot()
	for store_id in [view.input_store, view.output_store]:
		root.simulation.set_store(store_id, true, root.simulation.Layout.STORES[store_id][1], [])
	for type in view.inputs:
		root.simulation.ledger.add_stock("review-confirmation-" + type, type, int(view.inputs[type]) * 2, 1.0, view.input_store, root.simulation.PLAYER)
	root.simulation.set_target(view.duty, 2)
	for step in 1000:
		root.simulation.advance_time(0.5)
		if step % 80 == 0: _probe._heartbeat("setup")
		if not activity.batch.is_empty() and activity.batch.work > 0: break
	activity.set_paused(true)
	var other := "R27" if view.recipe == "R02" else "R02"
	var result: Dictionary = activity.request_recipe(other)
	entry.setup_ready = result.get("confirmation_required", false) and not activity.batch.is_empty() and activity.batch.work > 0
	entry.setup_details = {"request": result, "batch": activity.batch.duplicate(true), "status": activity.snapshot().get("status", "")}
	entry.before_batch = activity.batch.get("id", "")
	root._confirmation_token = result.get("token", -1)
	entry.expected_recipe = other if entry.accept else view.recipe
	root._recipe_dialog.popup_centered()

func _assert_navigation(root: Control, entry: Dictionary, button: Button) -> void:
	if root.get("_shell") == null or not is_instance_valid(button): return
	if entry.owner != "res://game/ui/command_shell.gd": return
	if entry.kind == "button":
		for navigation in root._shell.NAVIGATION:
			if entry.text != navigation[1]: continue
			_probe.require_condition(root._base.visible and not root._battlefield.visible, "Rear navigation must show the shared rear view.")
			if navigation[0] != "rear": _probe.require_condition(root._shell._current_navigation == navigation[0], "Navigation must open the requested panel.")
		if str(entry.text).begins_with("Battlefield"): _probe.require_condition(root._battlefield.visible and not root._base.visible, "Battlefield navigation must show the battlefield view.")
		if entry.text == "Getting started": _probe.require_condition(root._shell._help.visible, "Getting started must open help.")
		if entry.text == "Close": _probe.require_condition(not root._shell._help.visible, "Close must hide help.")
	elif entry.kind == "menu_item":
		var id: int = button.get_popup().get_item_id(entry.index)
		if entry.text == "More systems": _probe.require_condition(root._shell._current_navigation == root._shell.MORE_ACTIONS[id], "More systems must route the selected menu item.")
		elif entry.text == "Session":
			if id == 0: _probe.require_condition(root._shell._confirmation.visible, "New game must open a confirmation before resetting.")
			elif id == 1: _probe.require_condition(root._shell._help.visible, "Session help must open Getting started.")
