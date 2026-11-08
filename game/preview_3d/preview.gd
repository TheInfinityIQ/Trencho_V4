extends "res://game/main/main.gd"
## Explicit opt-in entry. Default Main/F5 stays on the existing playable view.
const World = preload("res://game/preview_3d/world_presenter.gd")
const FieldPolicy = preload("res://game/battlefield/battlefield_presentation.gd")
var world: Node3D
var management_open := false
var battlefield_open := false
var first_person := false
var _needs_capture := true
var _held: Dictionary = {}
var _suppressed: Dictionary = {}
var _middle_drag := false
var _pick_pending := false
var _select_pending := false
var _pointer := Vector2.ZERO
var _draft_generation := 0
var _candidate_revision := 0
var _candidate: Dictionary = {}
var _pending_commit: Dictionary = {}
var _submitting := false
var _left_down := false
var _command_message := ""
var _preview_message := ""
var _check_button: Button
var _fully_checked := false
var _rear_dirty := false
var _field_dirty := true
var _motion_dirty := true
var _inspection_second := -1
var _inspection_dirty := true
var _hud: VBoxContainer
var _hint: Label
var _inspection: Label
var _inspection_panel: ScrollContainer
var _crosshair: Label

func _ready() -> void:
	super._ready()
	_base.preserve_placement_draft = true
	_base.base_map.hide()
	_base.base_map.set_process(false)
	_base.base_map.set_process_unhandled_key_input(false)
	_base.base_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.base_map.placement_requested.disconnect(_base.confirm_build_at)
	_base.base_map.placement_hovered.disconnect(_base.preview_build_hint_at)
	_base.placement_started.connect(_begin_preview)
	_base.placement_ended.connect(_draft_ended)
	_base.site_placement_result.connect(_placement_result)
	_base.command_reported.connect(_command_reported)
	get_viewport().size_changed.connect(_invalidate_preview)
	_base.construction_kind.item_selected.connect(func(_index: int) -> void: _draft_changed())
	_base.construction_turn.toggled.connect(func(_value: bool) -> void: _draft_changed())
	_shell.modal_visibility_changed.connect(func(_blocked: bool) -> void: _release_controls())
	_session.state_changed.connect(_state_changed)
	_session.time_advanced.connect(_time_changed)
	_session.simulation_changed.connect(_replace_world)
	_build_hud()
	_replace_world(_session.simulation)
	_set_management(false)

func _build_hud() -> void:
	_hud = VBoxContainer.new()
	_hud.position = Vector2(20,16)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var row := HBoxContainer.new()
	_hud.add_child(row)
	var manage := Button.new()
	manage.text = "Management · Tab"
	manage.pressed.connect(func() -> void: _set_management(not management_open))
	row.add_child(manage)
	var area := Button.new()
	area.text = "Rear / Battlefield"
	area.pressed.connect(func() -> void:
		if battlefield_open: _show_base()
		else: _show_battlefield())
	row.add_child(area)
	var perspective := Button.new()
	perspective.text = "First / Third · V"
	perspective.pressed.connect(_toggle_camera)
	row.add_child(perspective)
	_check_button = Button.new()
	_check_button.text = "Check placement"
	_check_button.pressed.connect(_check_candidate)
	row.add_child(_check_button)
	_hint = Label.new()
	_hint.custom_minimum_size.x = 850
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_shadow_color",Color.BLACK)
	_hint.add_theme_constant_override("shadow_outline_size",6)
	_hud.add_child(_hint)
	_inspection_panel = ScrollContainer.new()
	_inspection_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_inspection_panel.offset_left = -350
	_inspection_panel.offset_top = 100
	_inspection_panel.offset_bottom = -20
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.06,0.1,0.13,0.94)
	backdrop.content_margin_left = 10
	backdrop.content_margin_right = 10
	_inspection_panel.add_theme_stylebox_override("panel",backdrop)
	add_child(_inspection_panel)
	_inspection = Label.new()
	_inspection.custom_minimum_size.x = 330
	_inspection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspection_panel.add_child(_inspection)
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(_crosshair)

func _replace_world(model: RefCounted) -> void:
	if world != null:
		remove_child(world)
		world.queue_free()
	world = World.new()
	add_child(world)
	world.build(model,_session.manager_pose)
	world.first.pose_changed.connect(_camera_changed)
	world.third.pose_changed.connect(_camera_changed)
	world.player.global_rotation.y = _session.manager_pose.heading
	world.player_visual.rotation.y = PI
	_rear_dirty = false
	_field_dirty = true
	_draft_generation += 1
	_command_message = ""
	_release_controls()
	_apply_view()

func _show_base() -> void:
	super._show_base()
	battlefield_open = false
	if world == null: return
	_set_management(false)
	_apply_view()

func _show_battlefield() -> void:
	super._show_battlefield()
	_battlefield.hide()
	battlefield_open = true
	if world == null: return
	_set_management(false)
	_apply_view()

func _observe_recipient(id: String) -> void:
	var marker: Dictionary = FieldPolicy.inspect(_session.simulation.rear,id)
	if marker.is_empty() or marker.get("owner","") != _session.simulation.rear.PLAYER: return
	_show_battlefield()
	world.rts.position.x = marker.position.x
	world.rts.position.z = marker.position.y+900
	world.rts.size = 1200
	_inspect(id)

func _apply_navigation() -> void:
	var action: String = _pending_navigation
	super._apply_navigation()
	if world == null: return
	if action not in ["rear","Battlefield"]: _set_management(true)

func _set_management(open: bool) -> void:
	management_open = open
	_shell.visible = open
	_base.visible = open
	if _hud != null: _hud.visible = not open
	if _crosshair != null: _crosshair.visible = not open and not battlefield_open
	_release_controls()
	if not open: _invalidate_preview(false)
	_update_hint()

func _apply_view() -> void:
	_release_controls()
	world.rear_root.visible = not battlefield_open
	world.field_root.visible = battlefield_open
	world.player_visual.visible = not first_person
	world.first.current = not battlefield_open and first_person
	world.third.current = not battlefield_open and not first_person
	world.rts.current = battlefield_open
	if battlefield_open:
		_field_dirty = true
		world.clear_preview()
	else: _invalidate_preview()
	_update_hint()

func _toggle_camera() -> void:
	if battlefield_open or management_open or _modal_open(): return
	first_person = not first_person
	_apply_view()

func _release_controls() -> void:
	_held.clear()
	_suppressed.clear()
	for key in [KEY_W,KEY_A,KEY_S,KEY_D]:
		if Input.is_physical_key_pressed(key): _suppressed[key] = true
	_middle_drag = false
	_left_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_fully_checked = false
	_candidate_revision += 1
	_candidate = {}
	_pending_commit = {}
	if world != null: world.clear_preview()
	_pick_pending = false
	_select_pending = false
	_needs_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _modal_open() -> bool:
	if _base == null or _shell == null: return false
	for dialog in [_base.confirmation,_base._batch_cancel_dialog,_base._construction_cancel_dialog,_shell._confirmation,_shell.debug_menu]:
		if is_instance_valid(dialog) and dialog.visible: return true
	return false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_controls()
		_update_hint()

func _input(event: InputEvent) -> void:
	# Tab is a mode shortcut even when a management field owns GUI focus.
	if world != null and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB and not _modal_open() and get_window().has_focus():
		_set_management(not management_open)
		get_viewport().set_input_as_handled()
		return
	# Releases must be observed even when a text field consumes the event.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: _left_down = false
	if event is InputEventKey and not event.pressed:
		_held.erase(event.physical_keycode)
		_suppressed.erase(event.physical_keycode)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed: _middle_drag = false

func _unhandled_input(event: InputEvent) -> void:
	if world == null or _modal_open() or not get_window().has_focus(): return
	if event is InputEventKey and event.pressed and not event.echo:
		# A decision modal retained GUI ownership above. Escape handles one layer.
		if event.physical_keycode == KEY_ESCAPE:
			if management_open: _set_management(false)
			elif _base._placing_building: _cancel_preview()
			else: _set_management(true)
			get_viewport().set_input_as_handled()
			return
		if management_open: return
		match event.physical_keycode:
			KEY_V: _toggle_camera()
			KEY_R:
				if not battlefield_open and _base._placing_building:
					_base.construction_turn.button_pressed = not _base.construction_turn.button_pressed
			KEY_W,KEY_A,KEY_S,KEY_D:
				if not _suppressed.has(event.physical_keycode) and (battlefield_open or not _needs_capture): _held[event.physical_keycode] = true
			_: return
		get_viewport().set_input_as_handled()
	if management_open: return
	if event is InputEventMouseButton:
		var changed_point: bool = _pointer != event.position
		_pointer = event.position
		if changed_point and _base._placing_building and not battlefield_open: _invalidate_preview()
		if event.button_index == MOUSE_BUTTON_MIDDLE: _middle_drag = event.pressed and battlefield_open
		if not event.pressed: return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _left_down or event.double_click: return
			_left_down = true
			if battlefield_open:
				_select_pending = true
			elif _needs_capture:
				_needs_capture = false
				if not _base._placing_building: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_invalidate_preview(false)
			elif _base._placing_building:
				_queue_commit()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and _base._placing_building:
			_cancel_preview()
		elif battlefield_open and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			world.rts.size = clampf(world.rts.size*(0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/0.85),100,6500)
	if event is InputEventMouseMotion:
		var moved_pointer: bool = _pointer != event.position
		_pointer = event.position
		if battlefield_open and _middle_drag:
			_pan_field(Vector2(-event.relative.x,-event.relative.y)*world.rts.size/get_viewport_rect().size.y)
		elif not battlefield_open and _base._placing_building:
			if moved_pointer: _invalidate_preview()
		elif not battlefield_open and not _needs_capture:
			world.player.global_rotation.y -= event.relative.x*0.003
			world.eye.rotation.x = clampf(world.eye.rotation.x-event.relative.y*0.003,-1.25,0.8)
			_session.manager_pose.heading = world.player.global_rotation.y
			_pick_pending = true

func _physics_process(delta: float) -> void:
	if world == null: return
	var geometry_refreshed := false
	if _rear_dirty:
		_rear_dirty = false
		geometry_refreshed = world.refresh_rear()
		if geometry_refreshed: _invalidate_preview(false)
	if battlefield_open and _field_dirty:
		_field_dirty = false
		world.refresh_markers()
		_inspection_dirty = true
	if battlefield_open and _motion_dirty:
		_motion_dirty = false
		world.refresh_marker_positions()
	if battlefield_open and _inspection_dirty:
		_inspection_dirty = false
		_refresh_inspection()
	if _modal_open():
		_release_controls()
		return
	if management_open or not get_window().has_focus(): return
	var direction := Vector2(float(_held.has(KEY_D))-float(_held.has(KEY_A)),float(_held.has(KEY_S))-float(_held.has(KEY_W))).limit_length()
	if battlefield_open:
		if not direction.is_zero_approx(): _pan_field(direction*world.rts.size*delta*0.55)
		if _select_pending:
			_select_pending = false
			_select_marker()
		return
	if not _needs_capture and not _base._placing_building and _session.simulation.speed > 0:
		if world.move_manager(direction,_session.simulation.speed,_session.manager_pose): _pick_pending = true

	# Newly attached/removed colliders synchronize before the next physics query.
	if geometry_refreshed: return
	if _pick_pending:
		_pick_pending = false
		_pick_ground()
	if not _pending_commit.is_empty(): _consume_commit()

func _pan_field(offset: Vector2) -> void:
	world.rts.position.x = clampf(world.rts.position.x+offset.x,0,4000)
	world.rts.position.z = clampf(world.rts.position.z+offset.y,0,7500)

func _begin_preview() -> void:
	_draft_generation += 1
	_pointer = get_viewport().get_mouse_position()
	_set_management(false)
	_invalidate_preview()

func _draft_changed() -> void:
	_draft_generation += 1
	_invalidate_preview()

func _draft_ended() -> void:
	_draft_generation += 1
	_preview_message = ""
	_release_controls()
	_update_hint()

func _camera_changed(camera: Camera3D) -> void:
	if camera.current and not battlefield_open and _base._placing_building: _invalidate_preview(false)

func _invalidate_preview(clear_feedback: bool = true) -> void:
	if clear_feedback: _command_message = ""
	if not _pending_commit.is_empty(): _command_message = "Placement target changed. Nothing placed; click the current preview again."
	_fully_checked = false
	_candidate_revision += 1
	_candidate = {}
	_pending_commit = {}
	_pick_pending = _base != null and _base._placing_building and not battlefield_open
	_preview_message = "Updating ground preview…" if _pick_pending else ""
	if world != null: world.clear_preview()
	_update_hint()

func _cancel_preview() -> void:
	_base._cancel_placement()
	_command_message = "Uncommitted preview cancelled. No construction site was cancelled."
	_update_hint()

func _pick_ground() -> void:
	if not _base._placing_building:
		world.clear_preview()
		return
	var camera: Camera3D = world.first if first_person else world.third
	var origin := camera.project_ray_origin(_pointer)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(_pointer)*500,1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != world.rear_ground or not hit.position.is_finite():
		_candidate = {}
		world.clear_preview()
		_preview_message = "Aim at rear ground. A table, wall or structure blocks placement here." if not hit.is_empty() else "No rear-ground target."
		_update_hint()
		return
	var ground := Vector2(hit.position.x,hit.position.z)
	var plan: Dictionary = _base.preview_build_at(ground,false)
	_candidate = {"session":_session,"model":_session.simulation,"service":_session.simulation.rear.construction,
		"draft":_draft_generation,"revision":_candidate_revision,"kind":_base._construction_kind(),"turn":_base.construction_turn.button_pressed,
		"camera":camera,"transform":camera.get_camera_transform(),"projection":camera.get_camera_projection(),"screen":_pointer,"point":ground,"hint":plan,"blockers":_blocker_membership(plan.footprint)}
	world.show_preview(plan)
	_preview_message = "Preview — click to validate and place." if plan.ok else str(plan.message)
	_update_hint()

func _candidate_is_current(candidate: Dictionary) -> bool:
	if candidate.is_empty() or _pick_pending or not _base._placing_building or management_open or battlefield_open: return false
	if candidate.session != _session or candidate.model != _session.simulation or candidate.service != _session.simulation.rear.construction: return false
	if candidate.draft != _draft_generation or candidate.revision != _candidate_revision: return false
	if candidate.kind != _base._construction_kind() or candidate.turn != _base.construction_turn.button_pressed or candidate.screen != _pointer: return false
	if candidate.blockers != _blocker_membership(candidate.hint.footprint): return false
	var camera: Camera3D = candidate.camera
	return is_instance_valid(camera) and camera.current and candidate.transform.is_equal_approx(camera.get_camera_transform()) and candidate.projection == camera.get_camera_projection()

func _queue_commit() -> void:
	if _submitting or not _pending_commit.is_empty(): return
	if not _candidate_is_current(_candidate):
		_command_message = "Preview changed or has no ground target. Nothing placed; wait for the current preview and click again."
		_pick_pending = true
	else:
		_pending_commit = _candidate.duplicate()
		_command_message = "Checking placement…"
	_update_hint()

func _consume_commit() -> void:
	var request := _pending_commit
	_pending_commit = {} # Consume once before any owner callback can invalidate it.
	if not _candidate_is_current(request) or _needs_capture or _modal_open() or not get_window().has_focus() or get_viewport().gui_get_hovered_control() != null:
		_command_message = "Placement input changed. Nothing placed; review the current preview."
		_update_hint()
		return
	_submitting = true
	_base.confirm_build_at(request.point)
	_submitting = false

func _check_candidate() -> void:
	if _modal_open() or not _candidate_is_current(_candidate):
		_command_message = "Choose a current rear-ground preview before checking placement."
	else:
		var candidate := _candidate.duplicate()
		var plan: Dictionary = _base.preview_build_at(candidate.point,true)
		if _candidate_is_current(candidate):
			world.show_preview(plan)
			_fully_checked = bool(plan.ok)
			_command_message = "Placement checked — click to place. This is not a reservation." if plan.ok else str(plan.message)
	_update_hint()

func _placement_result(result: Dictionary) -> void:
	_command_message = "Site %s: %s" % [result.id,result.message] if result.ok else "Last placement attempt: "+str(result.message)
	if result.ok: _preview_message = ""
	else: _invalidate_preview(false)
	_update_hint()

func _select_marker() -> void:
	var nearest := ""
	var distance := 18.0
	for row in world.marker_rows:
		if not world.markers.has(row.id) or not world.markers[row.id].visible: continue
		var at: Vector3 = world.markers[row.id].global_position
		if world.rts.is_position_behind(at): continue
		var measure: float = world.rts.unproject_position(at).distance_to(_pointer)
		if measure < distance:
			distance = measure
			nearest = str(row.id)
	if not nearest.is_empty(): _inspect(nearest)

func _inspect(id: String) -> void:
	_battlefield.selected_id = id
	_refresh_inspection()

func _refresh_inspection() -> void:
	if _inspection == null: return
	_inspection.text = _battlefield.inspection_text()
	var row: Dictionary = FieldPolicy.inspect(_session.simulation.rear,_battlefield.selected_id)
	if row.get("kind","") == "CONTACT": _inspection.text += "\nReport confidence: %.2f" % row.confidence

func _state_changed() -> void:
	_rear_dirty = true
	_field_dirty = true
	if _fully_checked and not _candidate.is_empty():
		_fully_checked = false
		world.show_preview(_candidate.hint)
		_command_message = "Placement facts changed; preview is provisional again."
	_update_hint()

func _time_changed() -> void:
	_motion_dirty = true
	if _base._placing_building and not battlefield_open and not _candidate.is_empty():
		if _candidate.blockers != _blocker_membership(_candidate.hint.footprint): _invalidate_preview(false)
	var second := floori(_session.simulation.rear.time)
	if second != _inspection_second:
		_inspection_second = second
		_inspection_dirty = true
	_update_hint()

func _update_hint() -> void:
	if _hint == null or _session == null: return
	var model: RefCounted = _session.simulation
	_hint.text = "3D PROTOTYPE · %d REQ · %s · %.1fs\n%s" % [model.receiving.requisition_balance(),"Paused" if model.speed == 0 else str(model.speed)+"x",model.rear.time,
		"RTS · WASD / middle drag pan · wheel zoom · LMB inspect" if battlefield_open else (("Click world to enable placement · Tab management" if _base._placing_building else "Click world to resume camera · Tab management") if _needs_capture else "WASD move · V perspective · Tab management")]
	if _base._placing_building and not battlefield_open:
		_hint.text += "\nCONSTRUCTION · pointer aim · LMB place · R rotate · V perspective · RMB/Esc cancel draft"
		if not _preview_message.is_empty(): _hint.text += "\n"+_preview_message
	if not _command_message.is_empty(): _hint.text += "\n"+_command_message
	if _check_button != null: _check_button.visible = _base._placing_building and not battlefield_open
	if _crosshair != null: _crosshair.visible = not management_open and not battlefield_open and not _base._placing_building
	if _inspection_panel != null: _inspection_panel.visible = battlefield_open and not management_open

func _blocker_membership(footprint: Rect2) -> Dictionary:
	# Existing finite construction-truck owner only, using holder-chain positions.
	# Match placement_hint's four-metre clearance; never inspect inventories.
	var result: Dictionary = {}
	var rear: RefCounted = _session.simulation.rear
	for truck in rear.construction.trucks.trucks.values():
		if truck.get("created",false) and footprint.grow(4.0).has_point(rear.ledger._world_position(truck.id)):
			result[truck.id] = true
	return result

func _command_reported(result: Dictionary) -> void:
	# Includes the existing selected-site cancellation result, without ending a draft.
	_command_message = str(result.get("message",""))
	_update_hint()
