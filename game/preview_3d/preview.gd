extends "res://game/main/main.gd"
## Main/F5 instances this 3D presentation around the shared session controller.
const World = preload("res://game/preview_3d/world_presenter.gd")
const FieldPolicy = preload("res://game/battlefield/battlefield_presentation.gd")
const FieldCues = preload("res://game/preview_3d/field_person_cues.gd")
const TruckCues = preload("res://game/preview_3d/field_t01_cues.gd")
const ObjectiveCues = preload("res://game/preview_3d/field_objective_cues.gd")
const FollowSoldier = preload("res://game/battlefield/presentation_3d/follow_soldier.gd")
var _construction_visuals_ready := false
var _construction_preparation_usec := 0
var _construction_render_resources: Array[Resource] = []
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
var _workshop_request: Dictionary = {}
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
var _place_button: Button
var _build_target_locked := false
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
var _field_cues: FieldCues
var _truck_cues: TruckCues
var _objective_cues: ObjectiveCues
var _follow: FollowSoldier
var _follow_button: Button

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
	get_viewport().size_changed.connect(_field_viewport_changed)
	_base.construction_kind.item_selected.connect(func(_index: int) -> void: _draft_changed())
	_base.construction_turn.toggled.connect(func(_value: bool) -> void: _draft_changed())
	_shell.modal_visibility_changed.connect(func(_blocked: bool) -> void: _release_controls())
	_session.state_changed.connect(_state_changed)
	_session.time_advanced.connect(_time_changed)
	_session.simulation_changed.connect(_replace_world)
	_build_hud()
	_replace_world(_session.simulation)
	_set_management(false)
	if DisplayServer.get_name() != "headless":
		var opening_speed: int = _session.simulation.speed
		_session.set_speed(0) # Loading must not accrue unseen simulation debt.
		var preparation := preload("res://game/construction/visuals/construction_render_preparation.gd").new()
		add_child(preparation)
		await preparation.prepare(world.third)
		_construction_preparation_usec = preparation.elapsed_usec
		_construction_render_resources = preparation.resources
		_session.set_speed(opening_speed)
	_construction_visuals_ready = true

func _build_hud() -> void:
	_follow = FollowSoldier.new()
	add_child(_follow)
	_follow.state_changed.connect(_update_hint)
	_field_cues = FieldCues.new()
	add_child(_field_cues)
	_truck_cues = TruckCues.new()
	add_child(_truck_cues)
	_objective_cues = ObjectiveCues.new()
	add_child(_objective_cues)
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
	_follow_button = Button.new()
	_follow_button.text = "Follow soldier"
	_follow_button.pressed.connect(_toggle_follow)
	row.add_child(_follow_button)
	_check_button = Button.new()
	_check_button.text = "Check placement"
	_check_button.pressed.connect(_check_candidate)
	row.add_child(_check_button)
	_place_button = Button.new()
	_place_button.text = "Confirm placement"
	_place_button.pressed.connect(_queue_commit)
	row.add_child(_place_button)
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
	if _follow != null: _follow.bind(null,null,Callable(),"")
	if _field_cues != null: _field_cues.bind(null,null)
	if _truck_cues != null: _truck_cues.bind(null,null)
	if _objective_cues != null: _objective_cues.bind(null,null,Callable())
	_base.placement_manager_body = null
	_base.placement_manager_shape = null
	if world != null:
		remove_child(world)
		world.queue_free()
	world = World.new()
	add_child(world)
	world.build(model,_session.manager_pose)
	_follow.bind(world.field_persons,world.rts,_follow_inspect,model.rear.PLAYER)
	_base.placement_manager_body = world.player
	_base.placement_manager_shape = world.manager_collision
	world.first.pose_changed.connect(_camera_changed)
	world.third.pose_changed.connect(_camera_changed)
	world.build_camera.pose_changed.connect(_camera_changed)
	world.rts.pose_changed.connect(_field_camera_changed)
	_field_cues.bind(world.field_persons,world.rts)
	_field_cues.set_selected(_battlefield.selected_id)
	_truck_cues.bind(world.field_t01_trucks,world.rts)
	_truck_cues.set_selected(_battlefield.selected_id)
	_objective_cues.bind(world.field_objectives,world.rts,_battlefield._site_label)
	_objective_cues.set_selected(_battlefield.selected_id)
	world.field_t01_trucks.removing.connect(_field_truck_removed)
	world.player.global_rotation.y = _session.manager_pose.heading
	world.player_visual.rotation.y = PI
	_rear_dirty = false
	_field_dirty = true
	_draft_generation += 1
	_command_message = ""
	_release_controls()
	_apply_view()

func _show_base() -> void:
	if _follow != null: _follow.stop("Follow stopped: left the battlefield.")
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
	if management_open and not open: _base.discard_menu_drafts()
	management_open = open
	_shell.visible = open
	_base.visible = open
	if _hud != null: _hud.visible = not open
	if _crosshair != null: _crosshair.visible = not open and not battlefield_open
	if world != null: world.build_grid.visible = _base._placing_building and not battlefield_open and not open
	if _field_cues != null: _field_cues.visible = battlefield_open and not open
	if _truck_cues != null: _truck_cues.visible = battlefield_open and not open
	if _objective_cues != null: _objective_cues.visible = battlefield_open and not open and not _field_dirty
	_release_controls()
	if not open: _invalidate_preview(false)
	_update_hint()

func _apply_view() -> void:
	_release_controls()
	world.rear_root.visible = not battlefield_open
	world.field_root.visible = battlefield_open
	world.player_visual.visible = not first_person
	var building: bool = _base._placing_building and not battlefield_open
	if world.warehouse_view != null: world.warehouse_view.set_cutaway_enabled(building or not first_person)
	world.build_camera.current = building
	world.build_grid.visible = building and not management_open
	world.first.current = not battlefield_open and not building and first_person
	world.third.current = not battlefield_open and not building and not first_person
	world.rts.current = battlefield_open
	_field_cues.visible = battlefield_open and not management_open
	_field_cues.request_projection()
	_truck_cues.visible = battlefield_open and not management_open
	_truck_cues.request_projection()
	_objective_cues.hide() # Show only after the existing fresh Policy reconciliation.
	_objective_cues.request_projection()
	if battlefield_open:
		_field_dirty = true
		world.clear_preview()
	else: _invalidate_preview()
	_update_hint()

func _toggle_camera() -> void:
	if battlefield_open or management_open or _modal_open() or _base._placing_building: return
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
	_workshop_request.clear()
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
	if not _construction_visuals_ready:
		get_viewport().set_input_as_handled()
		return
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
	if not _construction_visuals_ready: return
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
			KEY_E: _queue_workshop()
			KEY_R:
				if not battlefield_open and _base._placing_building:
					_base.construction_turn.button_pressed = not _base.construction_turn.button_pressed
			KEY_W,KEY_A,KEY_S,KEY_D:
				if not _suppressed.has(event.physical_keycode) and (battlefield_open or _base._placing_building or not _needs_capture): _held[event.physical_keycode] = true
			_: return
		get_viewport().set_input_as_handled()
	if management_open: return
	if event is InputEventMouseButton:
		var changed_point: bool = _pointer != event.position
		_pointer = event.position
		if changed_point and _base._placing_building and not battlefield_open: _invalidate_preview()
		if event.button_index == MOUSE_BUTTON_MIDDLE: _middle_drag = event.pressed and (battlefield_open or _base._placing_building)
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
				_build_target_locked = true
				_command_message = "Preview selected. Confirm placement to build; R rotates, Escape cancels."
				_update_hint()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and _base._placing_building:
			_cancel_preview()
		elif _base._placing_building and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			world.build_camera.size = clampf(world.build_camera.size*(0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/0.85),30,240)
			_invalidate_preview()
		elif battlefield_open and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			world.rts.size = clampf(world.rts.size*(0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/0.85),10,6500)
			_field_cues.request_projection()
			_truck_cues.request_projection()
			_objective_cues.request_projection()
	if event is InputEventMouseMotion:
		if _base._placing_building and _build_target_locked and not _middle_drag: return
		var moved_pointer: bool = _pointer != event.position
		_pointer = event.position
		if battlefield_open and _middle_drag:
			_pan_field(Vector2(-event.relative.x,-event.relative.y)*world.rts.size/get_viewport_rect().size.y)
		elif not battlefield_open and _base._placing_building:
			if _middle_drag: _pan_build(Vector2(-event.relative.x,-event.relative.y)*world.build_camera.size/get_viewport_rect().size.y)
			elif moved_pointer: _invalidate_preview()
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
		_objective_cues.flush_projection()
		_objective_cues.visible = not management_open
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
	if _base._placing_building and not _needs_capture and not direction.is_zero_approx(): _pan_build(direction*world.build_camera.size*delta*0.55)
	if not _needs_capture and not _base._placing_building and _session.simulation.speed > 0:
		if world.move_manager(direction,_session.simulation.speed,_session.manager_pose): _pick_pending = true

	# Newly attached/removed colliders synchronize before the next physics query.
	if geometry_refreshed: return
	if not _workshop_request.is_empty():
		_consume_workshop()
		if management_open: return
	if _pick_pending:
		_pick_pending = false
		_pick_ground()
	if not _pending_commit.is_empty(): _consume_commit()

func _queue_workshop() -> void:
	if battlefield_open or management_open or _needs_capture or _base._placing_building or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	var camera: Camera3D = world.first if first_person else world.third
	# One contextual E request; same current-world and first-hit guards for every site.
	_workshop_request = {"world":world,"model":_session.simulation,"service":_session.simulation.rear.construction,"receiving":_session.simulation.receiving,"camera":camera}

func _workshop_target(site_id: String) -> Dictionary:
	var model: RefCounted = _session.simulation
	var service: RefCounted = model.rear.construction
	var row: Dictionary = service.instances.get(site_id,{})
	if row.is_empty() or row.state != "Complete": return {}
	var kind: String = "site"
	var duty: String = site_id
	var activity: RefCounted = service.activities.get(site_id)
	if activity == null and site_id == "initial-workshop" and not model.empty_field_opening:
		kind = "building"
		duty = "workshop"
		activity = model.rear.production
	if activity == null or activity._spec.duty != duty or not model.rear.requests.has(duty): return {}
	return {"physical":site_id,"kind":kind,"id":duty,"activity":activity}

func _consume_workshop() -> void:
	var request: Dictionary = _workshop_request
	_workshop_request = {}
	if request.is_empty() or not is_instance_valid(request.world) or request.world != world or request.model != _session.simulation or request.model != _base.simulation or request.service != _session.simulation.rear.construction or request.get("receiving") != _session.simulation.receiving: return
	var camera: Camera3D = world.first if first_person else world.third
	if request.camera != camera or battlefield_open or management_open or _modal_open() or _needs_capture or _base._placing_building or not get_window().has_focus() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	var point: Vector2 = get_viewport_rect().size/2.0
	var origin: Vector3 = camera.project_ray_origin(point)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(point)*camera.far,5)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Node = hit.get("collider") as Node
	if world.is_supply_table_collider(collider):
		_open_supply_table(request)
		return
	var site_id: String = world.site_id_from_collider(collider)
	var target: Dictionary = _workshop_target(site_id)
	if target.is_empty():
		var row: Dictionary = request.service.instances.get(site_id,{})
		if not row.is_empty() and row.state not in ["Cancelled","Dismantled"]:
			_set_management(true)
			_base._select("site",site_id,true)
			if row.state == "Complete":
				var panel_name: String = {"training":"Train","dispatch":"Dispatch","park":"Vehicles","receiving":"Info","depot":"Info","construction":"Build"}.get(str(row.kind),"Build")
				_base.show_panel(panel_name,false)
				if panel_name == "Info":
					if row.kind == "depot" and _session.simulation.rear.warehouse != null:
						var index: int = _session.simulation.rear.stores.keys().find("receiving")
						_base.store.select(index)
						_base._load_store()
					for index in _base.store.item_count:
						if _base.store.get_item_text(index) == site_id:
							_base.store.select(index)
							_base._load_store()
				if row.kind == "training":
					for index in _base.training_site.item_count:
						if str(_base.training_site.get_item_metadata(index)) == site_id: _base.training_site.select(index)
			_command_message = ""
			return
		_command_message = "Aim at the Supply Table or a current building/site and press E. Structures block selection."
		_update_hint()
		return
	# Hidden panels intentionally skip refresh; show before resolving metadata.
	_set_management(true)
	_base._select(str(target.kind),str(target.id),true)
	var panel: Control = _base.tabs.get_tab_control(_base.tabs.current_tab)
	if _base._selected_kind != target.kind or _base._selected_id != target.id or _base._context_duty() != target.id or _base._activity() != target.activity or str(panel.get_meta("panel_title",panel.name)) != "Work":
		_set_management(false)
		_command_message = "This Workshop's controls are unavailable. Select a current completed Workshop."
		_update_hint()
		return
	_focus_workshop.call_deferred(request,target)

func _open_supply_table(request: Dictionary) -> void:
	var model: RefCounted = _session.simulation
	if not model.empty_field_opening or request.receiving != model.receiving or not model.receiving.supply_table_access:
		_command_message = "The Supply Table is unavailable in this session."
		_update_hint()
		return
	# 'terminal' is the existing logical UI context; 'receiving' is the real place.
	var place: Dictionary = model.rear.ledger.inspect_entity("receiving",{},false)
	var table_at: Vector2 = Vector2(world.supply_table_body.global_position.x,world.supply_table_body.global_position.z)
	if place.get("kind","") != "PLACE" or not place.position.is_equal_approx(table_at) or not model.receiving.receiving_position.is_equal_approx(place.position):
		_command_message = "The Supply Table's receiving place is unavailable."
		_update_hint()
		return
	_set_management(true)
	_base._supply_views.current_tab = 0 # Existing Purchase tab; preserve cart/order state.
	_base._select("building","terminal",true)
	var panel: Control = _base.tabs.get_tab_control(_base.tabs.current_tab)
	if _base.simulation != model or _base._selected_kind != "building" or _base._selected_id != "terminal" or str(panel.get_meta("panel_title",panel.name)) != "Supplies":
		_set_management(false)
		_command_message = "The Supply Table's purchase controls are unavailable."
		_update_hint()
		return
	_command_message = ""

func _focus_workshop(request: Dictionary, target: Dictionary) -> void:
	if not management_open or battlefield_open or not is_instance_valid(request.world) or request.world != world or request.model != _session.simulation or request.service != _session.simulation.rear.construction: return
	var current: Dictionary = _workshop_target(str(target.physical))
	if current.is_empty() or current.activity != target.activity or _base._context_duty() != target.id or _base._activity() != target.activity: return
	var panel: Control = _base.tabs.get_tab_control(_base.tabs.current_tab)
	if panel is ScrollContainer and str(panel.get_meta("panel_title",panel.name)) == "Work" and _base.facility.is_visible_in_tree():
		panel.scroll_vertical = int(_base.facility.global_position.y-panel.get_child(0).global_position.y)
		_base.facility.grab_focus()

func _pan_field(offset: Vector2) -> void:
	if not offset.is_zero_approx() and _follow != null: _follow.stop("Follow stopped: camera panned manually.")
	world.rts.position.x = clampf(world.rts.position.x+offset.x,0,4000)
	world.rts.position.z = clampf(world.rts.position.z+offset.y,0,7500)

func _pan_build(offset: Vector2) -> void:
	_build_target_locked = false
	world.build_camera.position.x = clampf(world.build_camera.position.x+offset.x,0,240)
	world.build_camera.position.z = clampf(world.build_camera.position.z+offset.y,0,210)
	_invalidate_preview()

func _begin_preview() -> void:
	_build_target_locked = false
	_draft_generation += 1
	_pointer = get_viewport().get_mouse_position()
	_set_management(false)
	_apply_view()
	_needs_capture = false
	_invalidate_preview()

func _draft_changed() -> void:
	_draft_generation += 1
	_invalidate_preview()

func _draft_ended() -> void:
	_build_target_locked = false
	_draft_generation += 1
	_preview_message = ""
	_apply_view()
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
	var camera: Camera3D = world.build_camera
	var origin := camera.project_ray_origin(_pointer)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(_pointer)*500,5)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != world.rear_ground or not hit.position.is_finite():
		_candidate = {}
		world.clear_preview()
		_preview_message = "Aim at rear ground. A table, wall or structure blocks placement here." if not hit.is_empty() else "No rear-ground target."
		_update_hint()
		return
	var ground: Vector2 = _base._snap_build_point(Vector2(hit.position.x,hit.position.z))
	var plan: Dictionary = _base.preview_build_at(ground,false)
	_candidate = {"session":_session,"model":_session.simulation,"service":_session.simulation.rear.construction,
		"draft":_draft_generation,"revision":_candidate_revision,"kind":_base._construction_kind(),"turn":_base.construction_turn.button_pressed,
		"camera":camera,"transform":camera.get_camera_transform(),"projection":camera.get_camera_projection(),"screen":_pointer,"point":ground,"hint":plan,"blockers":_blocker_membership(plan.footprint)}
	world.show_preview(plan)
	_preview_message = "Grid preview — Confirm placement to validate and build." if plan.ok else str(plan.message)
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
	if not _build_target_locked: return
	if _submitting or not _pending_commit.is_empty(): return
	if not _candidate_is_current(_candidate):
		_command_message = "Preview changed or has no ground target. Nothing placed; wait for the current preview and click again."
		_pick_pending = true
	else:
		_pending_commit = _candidate.duplicate()
		_pending_commit.from_confirm_button = true
		_command_message = "Checking placement…"
	_update_hint()

func _consume_commit() -> void:
	var request := _pending_commit
	_pending_commit = {} # Consume once before any owner callback can invalidate it.
	if not _candidate_is_current(request) or _needs_capture or _modal_open() or not get_window().has_focus() or (get_viewport().gui_get_hovered_control() != null and not request.get("from_confirm_button",false)):
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
			_command_message = "Placement checked — Confirm placement to build. This is not a reservation." if plan.ok else str(plan.message)
	_update_hint()

func _placement_result(result: Dictionary) -> void:
	_command_message = "Site %s: %s" % [result.id,result.message] if result.ok else "Last placement attempt: "+str(result.message)
	if result.ok: _preview_message = ""
	else: _invalidate_preview(false)
	_update_hint()

func _select_marker() -> void:
	_field_cues.flush_projection()
	_truck_cues.flush_projection()
	_objective_cues.flush_projection()
	var nearest := ""
	var distance := 18.0
	for row in world.marker_rows:
		if not world.markers.has(row.id) or not world.markers[row.id].visible: continue
		if row.kind == "PERSON" and not _field_cues.points.has(row.id): continue
		var truck: bool = world.field_t01_trucks.bodies.has(row.id)
		if truck and not _truck_cues.points.has(row.id): continue
		var objective: bool = world.field_objectives.anchors.has(row.id)
		if objective and not _objective_cues.points.has(row.id): continue
		var at: Vector3 = world.markers[row.id].global_position
		if not truck and not objective and world.rts.is_position_behind(at): continue
		var point: Vector2
		if objective: point = _objective_cues.points[row.id]
		elif truck: point = _truck_cues.points[row.id]
		elif row.kind == "PERSON": point = _field_cues.points[row.id]
		else: point = world.rts.unproject_position(at)
		var measure: float = point.distance_to(_pointer)
		if measure < distance:
			distance = measure
			nearest = str(row.id)
	if not nearest.is_empty(): _inspect(nearest)

func _inspect(id: String) -> void:
	if _follow != null and not _follow.followed_id.is_empty() and _follow.followed_id != id: _follow.stop("Follow stopped: selection changed.")
	_battlefield.selected_id = id
	_field_cues.set_selected(id)
	_truck_cues.set_selected(id)
	_objective_cues.set_selected(id)
	_refresh_inspection()
	_update_hint()


func _follow_inspect(id: String) -> Dictionary:
	return FieldPolicy.inspect(_session.simulation.rear,id)

func _toggle_follow() -> void:
	if world == null or not battlefield_open or management_open or _modal_open(): return
	if not _follow.followed_id.is_empty(): _follow.stop("Follow stopped.")
	else: _follow.start(_battlefield.selected_id)
	_update_hint()

func _field_camera_changed(_camera: Camera3D) -> void:
	if world != null: world.field_persons.set_animation_detail(world.rts.size <= 240.0)
	if _field_cues != null: _field_cues.request_projection()
	if _truck_cues != null: _truck_cues.request_projection()
	if _objective_cues != null: _objective_cues.request_projection()

func _field_viewport_changed() -> void:
	if _field_cues != null: _field_cues.request_projection()
	if _truck_cues != null: _truck_cues.request_projection()
	if _objective_cues != null: _objective_cues.request_projection()

func _field_truck_removed(_id: String, _body: Node3D) -> void:
	# Coalesce a current Policy refresh so an ineligible detailed hull falls back.
	_field_dirty = true

func _refresh_inspection() -> void:
	if _inspection == null: return
	_inspection.text = _battlefield.inspection_text()
	var row: Dictionary = FieldPolicy.inspect(_session.simulation.rear,_battlefield.selected_id)
	if row.get("kind","") == "CONTACT": _inspection.text += "\nReport confidence: %.2f" % row.confidence

func _state_changed() -> void:
	if world != null:
		world.sync_character_playback()
		world.rear_workers.request_refresh()
		world.utility_trucks.request_refresh()
		world.rear_t01_trucks.request_refresh()
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
		"RTS · WASD / middle drag pan · wheel zoom · LMB inspect" if battlefield_open else (("Click world to enable placement · Tab management" if _base._placing_building else "Click world to resume camera · Tab management") if _needs_capture else "WASD move · V perspective · E interact · Tab management")]
	if _base._placing_building and not battlefield_open:
		_hint.text += "\nBUILD · 1 m grid · WASD / middle drag pan · wheel zoom · LMB select · Confirm placement to build · R rotate · RMB/Esc cancel"
		if not _preview_message.is_empty(): _hint.text += "\n"+_preview_message
	if battlefield_open and _follow != null and not _follow.status.is_empty(): _hint.text += "\n"+_follow.status
	if not _command_message.is_empty(): _hint.text += "\n"+_command_message
	if _place_button != null:
		_place_button.visible = _base._placing_building and not battlefield_open
		_place_button.disabled = not _build_target_locked or _candidate.is_empty()
	if _follow_button != null:
		_follow_button.visible = battlefield_open and not management_open
		_follow_button.text = "Stop following" if not _follow.followed_id.is_empty() else "Follow soldier"
		_follow_button.disabled = _follow.followed_id.is_empty() and (world == null or not world.field_persons.anchors.has(_battlefield.selected_id))
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
