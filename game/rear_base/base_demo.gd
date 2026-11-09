extends Control
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
## One live scene, persistent panels, physical map and player commands.
signal command_reported(result: Dictionary)
signal placement_ended
signal site_placement_result(result: Dictionary)
signal placement_started
## The alternate 3D input owner retains its draft across management panels.
var preserve_placement_draft := false
## Optional actual 3D occupation; the normal 2D composition leaves these unset.
var placement_manager_body: CharacterBody3D
var placement_manager_shape: CollisionShape3D

signal session_changed(next_simulation: RefCounted)
signal panel_changed(title: String)
signal observation_requested(entity_id: String)
const Session = preload("res://game/main/game_session.gd")
const Simulation = preload("res://game/rear_base/base_simulation.gd")
const Map = preload("res://game/rear_base/base_map.gd")
const Catalog = preload("res://game/procurement/resource_catalog.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
const ConstructionCatalog = preload("res://game/construction/construction_catalogue.gd")
const ForwardDeliveryPanel = preload("res://game/forward_supply/forward_delivery_panel.gd")
const WorkforcePanel = preload("res://game/rear_base/workforce_panel.gd")
const FactoryPlanPanel = preload("res://game/rear_base/factory_plan_panel.gd")
const UIKit = preload("res://game/ui/ui_kit.gd")
const RearLogistics = preload("res://game/logistics/rear_logistics.gd")
const ArmySupplyView = preload("res://game/logistics/army_supply_view.gd")
const ArmySupplyPanel = preload("res://game/logistics/army_supply_panel.gd")
const BUILD_PURPOSES := {"receiving":"Unload purchased supplies", "depot":"Store raw supplies", "workshop":"Manufacture infantry equipment", "munitions":"Manufacture ammunition", "training":"Train workers and specialists", "dispatch":"Send finished supplies onward", "support":"Manufacture support equipment", "vehicle_works":"Build vehicles", "park":"Park finished vehicles", "construction":"Organize construction crews", "materials":"Manufacture Building Materials"}
const VEHICLE_NAMES := {"T01":"Supply truck","T02":"Personnel transport","T03":"Armed car","T04":"APC","T05":"Tank"}
var session: Node
var simulation: RefCounted
var forward_delivery_panel: VBoxContainer
var construction_kind: OptionButton
var construction_x: SpinBox
var construction_y: SpinBox
var construction_turn: CheckBox
var construction_source: OptionButton
var construction_builders: SpinBox
var construction_office: SpinBox
var construction_staff: SpinBox
var construction_rows: ItemList
var construction_ids: Array[String] = []
var construction_status: Label
var base_map: Control
var tabs: TabContainer
var status: Label
var _local_clock_controls: HBoxContainer
var _local_clock_status: Label
var _standalone_clock_row: HBoxContainer
var _standalone_actions: HBoxContainer
var _standalone_session_actions: VBoxContainer
var _fit_base_button: Button
var _advanced_panels: CheckButton
var _uses_shared_navigation := false
var _staff_control_basis := ""
var _staff_draft_dirty := false
var _instructor_draft_dirty := false
var _instructor_draft_basis := ""
var _office_draft_dirty := false
var _office_draft_basis := ""
var feedback: Label
var orders: ItemList
var people: ItemList
var jobs: ItemList
var inspection: Label
var production_status: Label
var _production_pause_button: Button
var _production_enable_button: Button
var cart: Dictionary = {}
var factory_plan_panel: VBoxContainer
var army_supply_panel: VBoxContainer
var _supply_views: TabContainer
var _purchase_catalogue_scroll: ScrollContainer
var workforce_panel: VBoxContainer
var resource_hud: Label
var purchase_quote: Label
var purchase_button: Button
var include_workers: CheckBox
var _purchase_receiving: RefCounted
var delivery_status: Label
var delivery_progress: ProgressBar
var delivery_cancel_button: Button
var delivery_cancel_reason: Label
var army_request_type: OptionButton
var army_request_count: SpinBox
var army_request_rows: ItemList
var army_request_status: Label
var army_request_button: Button
var army_request_cancel: Button
var _army_request_ids: Array[String] = []
var construction_description: Label
var context_staff: SpinBox
var context_priority: OptionButton
var context_status: Label
var production_controls: VBoxContainer
var _placing_building := false
var source: OptionButton
var destination: OptionButton
var goods_type: OptionButton
var haul_count: SpinBox
var haul_category: OptionButton
var haul_draft_status: Label
var ingredient_checklist: VBoxContainer
var ingredient_heading: Label
var _ingredient_basis := ""
var _haul_draft_dirty := false
var facility: OptionButton
var recipe: OptionButton
var mode: OptionButton
var stock_target: SpinBox
var person_duty: OptionButton
var store: OptionButton
var capacity: SpinBox
var accessible: CheckBox
var confirmation: ConfirmationDialog
var training_course: OptionButton
var training_count: SpinBox
var training_rows: ItemList
var training_status: Label
var training_ids: Array[String] = []
var instructor_count: SpinBox
var training_site: OptionButton
var instructor_hire_button: Button
var instructor_hire_status: Label
var training_access: CheckBox
var recovery_button: Button
var recovery_status: Label
var vehicle_rows: ItemList
var vehicle_ids: Array[String] = []
var vehicle_person: OptionButton
var vehicle_fuel_person: OptionButton
var vehicle_station: OptionButton
var vehicle_fuel_units: SpinBox
var vehicle_status: Label
var dispatch_hull: OptionButton
var dispatch_site: OptionButton
var dispatch_mode: OptionButton
var dispatch_people: ItemList
var dispatch_person_ids: Array[String] = []
var dispatch_gun: OptionButton
var dispatch_cargo_type: OptionButton
var dispatch_cargo_count: SpinBox
var dispatch_draft: Dictionary = {}
var dispatch_rows: ItemList
var dispatch_ids: Array[String] = []
var dispatch_status: Label
var dispatch_surface: OptionButton
var dispatch_bridge: OptionButton
var dispatch_clearance: SpinBox
var hq_person: OptionButton
var hq_hull: OptionButton
var hq_type: OptionButton
var hq_weapon: OptionButton
var hq_count: SpinBox
var hq_rows: ItemList
var hq_ids: Array[String] = []
var hq_status: Label
var _pending_token: int = -1
var heavy_controls: VBoxContainer
var heavy_status: Label
var bay_access: CheckBox
var parking_access: CheckBox
var parking_destination: OptionButton
var _batch_cancel_dialog: ConfirmationDialog
var _batch_cancel_request: Dictionary = {}
var _construction_cancel_dialog: ConfirmationDialog
var _construction_cancel_request: Dictionary = {}
var _pending_activity: RefCounted
var scenario: OptionButton
var declaration: Label
var _selected_kind := "building"
var _selected_id := "terminal"
var _refresh_queued := false
var _displayed_time := -INF
var _displayed_speed := -1
var _displayed_planning_revision := -1
var _order_ids: Array[String] = []
var _person_ids: Array[String] = []
var _job_ids: Array[String] = []

func _ready() -> void:
	if session == null:
		session = Session.new()
		session.name = "GameSession"
		add_child(session)
	simulation = session.simulation
	_bind_purchase_receiving(simulation.receiving)
	session.state_changed.connect(_on_session_state_changed)
	session.simulation_changed.connect(_batch_cancel_model_changed)
	session.time_advanced.connect(_on_time_advanced)
	session.automatic_logistics.changed.connect(_on_logistics_changed)
	theme = UIKit.make_theme()
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree(): _request_refresh())
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var clock := HBoxContainer.new()
	_standalone_clock_row = clock
	layout.add_child(clock)
	_local_clock_controls = HBoxContainer.new()
	clock.add_child(_local_clock_controls)
	for value in [0, 1, 2]:
		_button(_local_clock_controls, ["Pause", "1x", "2x"][value], func() -> void:
			session.set_speed(value)
			_local_clock_status.text = clock_text())
	_local_clock_status = _label(_local_clock_controls,clock_text())
	_fit_base_button = _button(clock, "Fit base", func() -> void: base_map.reset_camera())
	status = _label(clock, "")
	var actions := HBoxContainer.new()
	_standalone_actions = actions
	layout.add_child(actions)
	for title in ["Build","Workers/Jobs","Supplies"]:
		var action := _button(actions,title,func() -> void: show_panel(title))
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var advanced := CheckButton.new()
	_advanced_panels = advanced
	advanced.text = "Advanced panels"
	advanced.toggled.connect(func(enabled: bool) -> void: tabs.tabs_visible = enabled)
	resource_hud = _label(layout, "")
	resource_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	declaration = _label(layout, "Essential session | Prebuilt: 12 ordinary people, 2500 requisition, no starting goods.")
	declaration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(split)
	base_map = Map.new()
	base_map.manager_pose = session.manager_pose
	base_map.simulation = simulation
	base_map.placement_preview = {}
	base_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_map.selected.connect(_select)
	base_map.placement_hovered.connect(preview_build_hint_at)
	base_map.placement_requested.connect(confirm_build_at)
	base_map.placement_cancelled.connect(_cancel_placement)
	base_map.placement_rotated.connect(func() -> void:
		construction_turn.button_pressed = not construction_turn.button_pressed)
	split.add_child(base_map)
	tabs = TabContainer.new()
	tabs.custom_minimum_size.x = 400
	tabs.tabs_visible = false
	split.add_child(tabs)
	_orders_panel(_panel("Supplies"))
	_staff_panel(_panel("Workers/Jobs"))
	_haul_panel(_panel("Haul"))
	_production_panel(_panel("Work"))
	_army_needs_panel(_panel("ArmyNeeds"))
	_inspect_panel(_panel("Info"))
	_training_panel(_panel("Train"))
	_vehicles_panel(_panel("Vehicles"))
	_dispatch_panel(_panel("Dispatch"))
	_construction_panel(_panel("Build"))
	forward_delivery_panel = ForwardDeliveryPanel.new(simulation)
	_panel("Supply").add_child(forward_delivery_panel)
	forward_delivery_panel.result_reported.connect(_result)
	if OS.get_environment("TRENCHO_HQ_DIAGNOSTICS") == "1": _hq_panel(_panel("HQ Diagnostics"))
	layout.add_child(advanced)
	feedback = _label(layout, "WASD: move your rear character. Build: place workshops. Workers/Jobs: hire and assign workers. Supplies: purchase raw resources.")
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Cancel consumed batch?"
	confirmation.min_size = Vector2i(620, 230)
	confirmation.confirmed.connect(func() -> void: _result(_pending_activity.confirm_recipe(_pending_token)); _load_production())
	confirmation.canceled.connect(func() -> void: _result(_pending_activity.decline_recipe(_pending_token)); _load_production())
	add_child(confirmation)
	_build_batch_cancel_dialog()
	_build_construction_cancel_dialog()
	_load_production()
	_load_store()
	_load_vehicle_people()
	tabs.tab_changed.connect(func(_index: int) -> void:
		var panel: Control = tabs.get_tab_control(tabs.current_tab)
		panel_changed.emit(str(panel.get_meta("panel_title",panel.name)))
		if is_node_ready() and is_visible_in_tree():
			if str(tabs.get_tab_control(tabs.current_tab).name) != "Build" and _placing_building and not preserve_placement_draft: _cancel_placement()
			_request_refresh())
	_request_refresh.call_deferred()

func _request_refresh() -> void:
	CallLog.record(&"rear_base/base_demo.gd::_request_refresh")
	if _refresh_queued or not is_node_ready() or not is_visible_in_tree(): return
	_refresh_queued = true
	get_tree().process_frame.connect(_refresh,CONNECT_ONE_SHOT)

func _on_time_advanced() -> void:
	if not is_node_ready() or not is_visible_in_tree(): return
	var panel: Control = tabs.get_tab_control(tabs.current_tab)
	if str(panel.name) == "ArmyNeeds":
		# The new panel owns committed-event reads. Elapsed time only moves the map.
		base_map.queue_redraw()
		if _local_clock_controls.visible: _local_clock_status.text = clock_text()
		return
	if str(panel.name) == "Workers_Jobs" and OS.get_environment("TRENCHO_HQ_DIAGNOSTICS") != "1":
		# Commands and committed work still request immediate fresh presentation.
		# Only arrival countdown text needs an elapsed-time update, once a second.
		base_map.queue_redraw()
		if floorf(_displayed_time) != floorf(simulation.rear.time): _request_refresh()
		return
	if str(panel.name) != "Build" or OS.get_environment("TRENCHO_HQ_DIAGNOSTICS") == "1":
		_request_refresh()
		return
	# Elapsed time moves markers and earned work. It does not change the build
	# catalogue, stock, site membership or staffing. Committed events still
	# request the complete view, including when a site starts/finishes/cancels.
	base_map.queue_redraw()
	if _local_clock_controls.visible: _local_clock_status.text = clock_text()
	_displayed_time = simulation.rear.time
	_displayed_speed = simulation.speed
	_displayed_planning_revision = simulation.planning_view_revision
	var row: Dictionary = simulation.rear.construction.instances.get(_construction_site(),{})
	if row.get("state","") in ["Building","Dismantling"]: _refresh_construction_progress()

func _on_logistics_changed() -> void:
	if not is_node_ready() or not is_visible_in_tree(): return
	var panel: Control = tabs.get_tab_control(tabs.current_tab)
	if str(panel.get_meta("panel_title",panel.name)) == "Supplies": _request_refresh()

func clock_text() -> String:
	# Shared by both live views; no snapshot, wall-time estimate or clock advance.
	var preparing: String = simulation.planning_status_text()
	return "  %.1f s · %s%s" % [simulation.rear.time,"Paused" if simulation.speed == 0 else "%dx" % simulation.speed," · "+preparing if not preparing.is_empty() else ""]

func use_shared_clock() -> void:
	_local_clock_controls.hide()

func use_shared_navigation() -> void:
	# Main's command shell owns the one persistent navigation and clock surface.
	_uses_shared_navigation = true
	_standalone_actions.hide()
	_standalone_clock_row.hide()
	_local_clock_controls.hide()
	_standalone_session_actions.hide()
	declaration.hide()
	feedback.hide()
	if _fit_base_button.get_parent() != base_map: _fit_base_button.reparent(base_map)
	_fit_base_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_fit_base_button.offset_left = 12
	_fit_base_button.offset_top = -92
	_fit_base_button.offset_right = 112
	_fit_base_button.offset_bottom = -50
	_advanced_panels.hide()
	tabs.tabs_visible = false
	_request_refresh()

func show_panel(title: String, start_build_preview: bool = true) -> bool:
	title = {"Staff":"Workers/Jobs","Orders":"Supplies"}.get(title,title)
	for index in tabs.get_tab_count():
		var panel: Control = tabs.get_tab_control(index)
		if str(panel.get_meta("panel_title", panel.name)) != title: continue
		tabs.current_tab = index
		if panel is ScrollContainer: panel.scroll_vertical = 0
		# Inspecting an existing site opens controls without acquiring a blueprint.
		if title == "Build" and start_build_preview: select_build_kind(_construction_kind())
		elif _placing_building: _cancel_placement()
		return true
	return false

func _panel(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title.replace("/", "_")
	scroll.set_meta("panel_title", title)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count()-1, title)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func _label(parent: Node, text: String) -> Label:
	return UIKit.label(parent,text)

func _section(parent: Node, title: String, description: String) -> VBoxContainer:
	var body: VBoxContainer = UIKit.card(parent)
	UIKit.label(body,title,20)
	if not description.is_empty():
		UIKit.label(body,description,14,UIKit.MUTED,true)
	return body

func _button(parent: Node, text: String, action: Callable, primary: bool = false) -> Button:
	return UIKit.button(parent,text,action,primary)

func _spin(parent: Node, title: String, maximum: int, value: int = 0) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, title).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = maximum
	spin.step = 1
	spin.set_value_no_signal(value)
	spin.custom_minimum_size.x = 100
	row.add_child(spin)
	return spin

func _option(parent: Node, title: String, values: Array) -> OptionButton:
	_label(parent, title)
	var option := OptionButton.new()
	for value in values: option.add_item(str(value))
	parent.add_child(option)
	return option

func _list(parent: Node, height: float = 120) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size.y = height
	list.clip_contents = true
	parent.add_child(list)
	return list

func _orders_panel(box: VBoxContainer) -> void:
	var views := TabContainer.new()
	_supply_views = views
	box.add_child(views)
	var purchase := VBoxContainer.new()
	purchase.name = "Purchase"
	views.add_child(purchase)
	var deliveries_view := VBoxContainer.new()
	deliveries_view.name = "Deliveries"
	views.add_child(deliveries_view)
	var army_view := VBoxContainer.new()
	army_view.name = "Army requests"
	views.add_child(army_view)
	var army_box := _section(army_view,"Supply your army","Request supplies at HQ. A staffed Logistics Centre uses your actual driven truck, loads available goods, delivers them and returns for the next trip.")
	army_request_type = _option(army_box,"Supply",[])
	for type in RearLogistics.shipment_types():
		army_request_type.add_item(_material_label(type))
		army_request_type.set_item_metadata(army_request_type.item_count-1,type)
		if type == "E02": army_request_type.select(army_request_type.item_count-1)
	army_request_count = _spin(army_box,"Quantity",50000,100)
	army_request_count.min_value = 1
	army_request_button = _button(army_box,"Request delivery to HQ",_request_army_delivery,true)
	army_request_rows = _list(army_box,100)
	army_request_rows.item_selected.connect(func(_index: int) -> void: _refresh_army_requests())
	army_request_status = _label(army_box,"")
	army_request_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	army_request_cancel = _button(army_box,"Cancel remaining delivery",_cancel_army_delivery)
	var hiring: VBoxContainer = UIKit.card(purchase)
	UIKit.label(hiring,"WORKERS",11,UIKit.ACCENT)
	include_workers = CheckBox.new()
	include_workers.text = "Include 8 workers · 140 requisition (120 + 20 transport)"
	include_workers.toggled.connect(func(_enabled: bool) -> void: _refresh_purchase_quote())
	hiring.add_child(include_workers)
	UIKit.label(hiring,"Workers join after disembarking.",14,UIKit.MUTED,true)
	var deliveries: VBoxContainer = _section(deliveries_view,"Deliveries","Select an order to inspect its actual arrival or unloading state.")
	orders = _list(deliveries,112)
	orders.item_selected.connect(func(index: int) -> void: _select("order", _order_ids[index], false))
	delivery_status = _label(deliveries,"")
	delivery_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delivery_progress = ProgressBar.new()
	delivery_progress.max_value = 1.0
	delivery_progress.show_percentage = false
	delivery_progress.custom_minimum_size.y = 6
	deliveries.add_child(delivery_progress)
	delivery_cancel_button = _button(deliveries, "Cancel selected undispatched order", func() -> void:
		if not orders.get_selected_items().is_empty(): _result(simulation.receiving.cancel_order(_order_ids[orders.get_selected_items()[0]])))
	delivery_cancel_reason = _label(deliveries,"")
	delivery_cancel_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var catalogue: VBoxContainer = _section(purchase,"Raw supplies","Whole kg · price per kg")
	var catalogue_scroll := ScrollContainer.new()
	_purchase_catalogue_scroll = catalogue_scroll
	catalogue_scroll.custom_minimum_size.y = 160
	catalogue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalogue.add_child(catalogue_scroll)
	var quantities := VBoxContainer.new()
	quantities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalogue_scroll.add_child(quantities)
	for code in Catalog.MATERIALS:
		cart[code] = _spin(quantities, Catalog.MATERIALS[code].name + " · " + str(Catalog.MATERIALS[code].price)+" req/kg", 55000)
		cart[code].value_changed.connect(func(_value: float) -> void: _refresh_purchase_quote())
	purchase_quote = _label(catalogue,"")
	purchase_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	purchase_button = _button(catalogue,"Confirm order",_confirm_purchase,true)
	var recovery_toggle := CheckButton.new()
	recovery_toggle.text = "Specialist recovery details"
	purchase.add_child(recovery_toggle)
	var recovery: VBoxContainer = _section(purchase,"Specialist recovery","")
	var recovery_card := recovery.get_parent() as Control
	recovery_card.hide()
	recovery_toggle.toggled.connect(recovery_card.set_visible)
	recovery_button = _button(recovery,"Confirm recovery instructor · 120 requisition",func() -> void: _result(simulation.receiving.buy_recovery_instructor()))
	recovery_status = _label(recovery,"")
	recovery_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_standalone_session_actions = VBoxContainer.new()
	purchase.add_child(_standalone_session_actions)
	_button(_standalone_session_actions,"Start new empty-field game",start_empty_field_session)
	var diagnostics := VBoxContainer.new()
	_standalone_session_actions.add_child(diagnostics)
	diagnostics.hide()
	var detail := CheckButton.new()
	detail.text = "Legacy session options"
	_standalone_session_actions.add_child(detail)
	detail.toggled.connect(diagnostics.set_visible)
	_label(diagnostics, "New session resets the base; inspection never does.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scenario = _option(diagnostics, "Diagnostic session", ["Essential recipes", "Expanded production catalogue", "Farmland and Towns playtest"])
	_button(diagnostics, "Start diagnostic session", _start_session)

func _start_session(refresh_rear_ui: bool = true) -> void:
	simulation.cancel_live_planning()
	simulation = preload("res://game/scenario/farmland_session.gd").create() if scenario.selected == 2 else Simulation.new(scenario.selected == 1, true)
	if scenario.selected == 2: simulation.enable_live_planning()
	_bind_started_session(refresh_rear_ui)

func start_empty_field_session(refresh_rear_ui: bool = true) -> void:
	simulation.cancel_live_planning()
	simulation = preload("res://game/scenario/farmland_session.gd").create_empty_field(true)
	simulation.enable_live_planning()
	_bind_started_session(refresh_rear_ui)

func _bind_started_session(refresh_rear_ui: bool) -> void:
	_keep_batch_cancel()
	_keep_construction_cancel()
	session.replace_simulation(simulation)
	_displayed_time = -INF
	_haul_draft_dirty = false
	if haul_draft_status != null: haul_draft_status.text = "Prepare an ingredient in Work, or choose a haul below. Click Order haul to submit it."
	forward_delivery_panel.bind(simulation)
	workforce_panel.bind(simulation)
	session_changed.emit(simulation)
	base_map.simulation = simulation
	base_map.enable_character(bool(simulation.get("empty_field_opening")))
	_cancel_placement()
	base_map.reset_camera()
	_pending_activity = null
	_pending_token = -1
	for spin in cart.values(): spin.set_value_no_signal(0)
	instructor_count.set_value_no_signal(int(simulation.rear.requests.get("training",{}).get("target",0)))
	training_access.set_pressed_no_signal(simulation.rear.training.accessible)
	_load_courses()
	facility.select(0)
	_selected_kind = "building"
	_selected_id = "terminal"
	_load_production()
	_sync_option(store,simulation.rear.stores.keys())
	_load_store()
	declaration.text = "Farmland and Towns | Declared starting armies and rear | Selected free card: C30 (APC and E26 recipes)." if scenario.selected == 2 else ("Expanded production catalogue" if simulation.expanded_catalogue else "Essential session") + " | Prebuilt: 12 ordinary people, 2500 requisition, no starting goods."
	if simulation.get("empty_field_opening"):
		declaration.text = "Empty field · WASD to move · Hire workers, build workshops and assign real jobs."
	var message := "New paused Farmland opening. Buildings block sight and movement; entry and damage are pending." if scenario.selected == 2 else "New paused session. Recipe access was declared at creation; actual cards remain separate."
	if simulation.get("empty_field_opening"):
		message = "Running at 1x. Build and assign builders; workers can start as Building Materials arrive. Supplies orders bring more resources and workers."
	if refresh_rear_ui: _result({"ok":true,"message":message})
	elif feedback != null:
		feedback.text = message
		feedback.show()
	if _uses_shared_navigation and feedback != null: feedback.hide()

func _staff_panel(box: VBoxContainer) -> void:
	workforce_panel = WorkforcePanel.new(simulation)
	box.add_child(workforce_panel)
	workforce_panel.result_reported.connect(_result)
	workforce_panel.purchase_requested.connect(_draft_worker_purchase)
	_label(box,"Individual worker inspection")
	people = _list(box, 150)
	people.item_selected.connect(func(index: int) -> void: _select("entity", _person_ids[index], false))
	person_duty = _option(box, "Selected person's requested duty", ["Available", "receiving", "hauling", "workshop", "munitions", "materials", "support", "vehicle_works", "training"])
	_button(box, "Reassign selected person", func() -> void:
		if not people.get_selected_items().is_empty(): _result(simulation.rear.reassign_person(_person_ids[people.get_selected_items()[0]], person_duty.get_item_text(person_duty.selected))))

func _bind_purchase_receiving(receiving: RefCounted) -> void:
	if _purchase_receiving != null and _purchase_receiving.convoy_changed.is_connected(_request_refresh): _purchase_receiving.convoy_changed.disconnect(_request_refresh)
	_purchase_receiving = receiving
	if receiving != null: receiving.convoy_changed.connect(_request_refresh)

func _draft_worker_purchase() -> void:
	include_workers.button_pressed = true
	_supply_views.current_tab = 0
	show_panel("Supplies")
	_refresh_purchase_quote()

func discard_menu_drafts() -> void:
	if workforce_panel != null and workforce_panel.hauling_priorities != null: workforce_panel.hauling_priorities.discard_draft()
	_staff_draft_dirty = false
	_staff_control_basis = ""
	_instructor_draft_dirty = false
	_instructor_draft_basis = ""
	_office_draft_dirty = false
	_office_draft_basis = ""
	for spin: SpinBox in cart.values(): spin.set_value_no_signal(0)
	include_workers.set_pressed_no_signal(false)

func _confirm_purchase() -> void:
	var request := {}
	for code in cart:
		if cart[code].value > 0: request[code] = int(cart[code].value)
	var result: Dictionary
	if simulation.receiving.development_convoys:
		result = simulation.receiving.buy_delivery(request,include_workers.button_pressed)
	elif include_workers.button_pressed and not request.is_empty():
		result = {"ok":false,"message":"This legacy session supports separate resource and worker orders."}
	else:
		result = simulation.receiving.buy_people() if include_workers.button_pressed else simulation.receiving.buy_resources(request)
	if result.ok:
		for spin: SpinBox in cart.values(): spin.set_value_no_signal(0)
		include_workers.set_pressed_no_signal(false)
	_result(result)

func _refresh_purchase_quote() -> void:
	if purchase_quote == null: return
	var request := {}
	for code in cart:
		if cart[code].value > 0: request[code] = int(cart[code].value)
	if simulation.receiving.development_convoys:
		var combined: Dictionary = simulation.receiving.quote_delivery(request,include_workers.button_pressed)
		purchase_quote.text = str(combined.message)
		if combined.ok:
			purchase_quote.text = "%d kg + %d workers · %d vehicles · %d requisition total\nIncludes %d transport · Balance %.0f\nDestination: south unloading apron. Trucks spawn on confirmation; physical travel/unloading follows.\n%s" % [combined.mass_kg,combined.workers,combined.total_vehicles,combined.cost,combined.transport_fees,simulation.receiving.requisition_balance(),combined.message]
		purchase_button.disabled = not combined.ok or not combined.get("can_commit",false)
		return
	if include_workers.button_pressed and request.is_empty():
		purchase_quote.text = "8 workers · 140 requisition · 90 s travel, then disembarking."
		purchase_button.disabled = simulation.receiving.requisition_balance() < 140
		return
	var quote: Dictionary = simulation.receiving.quote_resources(request)
	purchase_quote.text = str(quote.message)
	if quote.ok:
		var balance: float = simulation.receiving.requisition_balance()
		purchase_quote.text = "%d kg · %d vehicles · %d requisition total\nIncludes %d transport · Balance %.0f\n60 s travel, then physical unloading." % [quote.mass_kg,quote.vehicle_count,quote.cost,quote.transport_fees,balance]
		if balance < float(quote.cost): purchase_quote.text += "\nNeeds %.0f more requisition." % (float(quote.cost)-balance)
		if int(quote.vehicle_count) > int(quote.free_vehicle_places): purchase_quote.text += "\nWaiting for supplier vehicle clearance: %d free places, %d needed." % [quote.free_vehicle_places,quote.vehicle_count]
	purchase_button.disabled = request.is_empty() or not quote.ok or not quote.get("can_commit",false)

func _order_summary(order: Dictionary) -> String:
	var contents: String = _named_quantities(order.cargo) if order.kind == "Freight" else "%d workers" % int(order.expected_people)
	if order.get("recovery_instructor",false): contents = "Recovery instructor"
	return "%s · %s · %d requisition" % [contents,order.state,int(order.cost)]

func _refresh_delivery_status(receiving: Dictionary) -> void:
	orders.visible = not receiving.orders.is_empty()
	delivery_cancel_button.disabled = true
	delivery_cancel_reason.text = "Select a booked order. Only its first five undispatched seconds allow a full refund."
	var selected := ""
	if not orders.get_selected_items().is_empty(): selected = _order_ids[orders.get_selected_items()[0]]
	var current: Dictionary = {}
	for order in receiving.orders:
		if order.id == selected:
			current = order
			break
		if current.is_empty() and order.state not in ["Complete","Cancelled"]: current = order
	if current.is_empty() and not receiving.orders.is_empty(): current = receiving.orders.back()
	delivery_progress.hide()
	if current.is_empty():
		delivery_status.text = "No deliveries booked. Worker and raw-supply purchases appear here."
		return
	if current.id == selected:
		var cancellable: bool = current.state == "Ordered" and float(receiving.time) < float(current.purchased_at)+5.0
		delivery_cancel_button.disabled = not cancellable
		delivery_cancel_reason.text = "Full refund available before dispatch." if cancellable else "This order has dispatched or closed; it can no longer be refunded."
	var detail: String = _order_summary(current)
	if current.state == "Incoming":
		var duration: float = float(current.arrival_at)-float(current.state_entered_at)
		var remaining: float = maxf(0.0,float(current.arrival_at)-float(receiving.time))
		if duration > 0.0:
			delivery_progress.value = clampf((float(receiving.time)-float(current.state_entered_at))/duration,0.0,1.0)
			delivery_progress.show()
		detail += "\nTravel · %.0f s until scheduled arrival" % ceilf(remaining)
	elif current.state == "Ordered":
		detail += "\nBooked · dispatch due in %.0f s" % ceilf(maxf(0.0,float(current.next_at)-float(receiving.time)))
	elif current.state != "Cancelled":
		if current.kind == "Freight":
			var requested := 0
			var unloaded := 0
			for type in current.cargo:
				requested += int(current.cargo[type])
				unloaded += int(current.unloaded.get(type,0))
			if requested > 0:
				delivery_progress.value = clampf(float(unloaded)/float(requested),0.0,1.0)
				delivery_progress.show()
			detail += "\nPhysically unloaded · %d / %d kg" % [unloaded,requested]
		else:
			var expected: int = current.expected_people
			if expected > 0:
				delivery_progress.value = clampf(float(current.people_arrived)/float(expected),0.0,1.0)
				delivery_progress.show()
			detail += "\n%d / %d joined the worker pool · %d disembarked" % [current.people_arrived,expected,current.people_exited]
	delivery_status.text = detail+"\n"+str(current.blocked_reason)

func _refresh_core_ui(view: Dictionary) -> void:
	workforce_panel.refresh(view)
	_refresh_purchase_quote()
	_refresh_resource_hud(view)
	_refresh_production_context(view)

func _refresh_resource_hud(view: Dictionary) -> void:
	var stock_totals := {"M11":{"physical":0,"reserved":0}}
	for storage in view.rear.stores:
		for stock in storage.stocks:
			if stock.owner != simulation.rear.PLAYER: continue
			var type: String = stock.design_type
			if not stock_totals.has(type): stock_totals[type] = {"physical":0,"reserved":0}
			stock_totals[type].physical += int(stock.quantity)
			stock_totals[type].reserved += int(stock.reserved)
	var physical: Array[String] = []
	for type in stock_totals:
		var count: Dictionary = stock_totals[type]
		physical.append("%s %d (%d reserved)" % [_material_label(type),count.physical,count.reserved])
	var outstanding := {}
	for order in view.receiving.orders:
		if order.kind != "Freight" or order.state in ["Cancelled","Complete"]: continue
		for type in order.cargo:
			outstanding[type] = int(outstanding.get(type,0))+maxi(0,int(order.cargo[type])-int(order.unloaded.get(type,0)))
	var incoming: Array[String] = []
	for type in outstanding:
		if outstanding[type] > 0: incoming.append("%s %d" % [_material_label(type),outstanding[type]])
	var money: String = "" if _uses_shared_navigation else "Requisition %.0f · " % view.receiving.money
	var separator: String = " · " if _uses_shared_navigation else "\n"
	resource_hud.text = "%sLocal stock: %s%sOrdered / in delivery: %s" % [money," · ".join(physical),separator,", ".join(incoming) if not incoming.is_empty() else "none"]

func _refresh_production_context(view: Dictionary) -> void:
	var duty := _context_duty()
	var basis := str(simulation.get_instance_id()) + ":" + duty
	var staff: Dictionary = simulation.rear.requests.get(duty,{})
	context_staff.editable = not staff.is_empty()
	context_priority.disabled = staff.is_empty()
	context_staff.set_block_signals(true)
	context_staff.max_value = int(staff.get("positions",0))
	if basis != _staff_control_basis: _staff_draft_dirty = false
	if not _staff_draft_dirty:
		context_staff.value = int(staff.get("target",0))
		context_priority.select(int(staff.get("priority",1)))
	_staff_control_basis = basis
	context_staff.set_block_signals(false)
	var activity: Dictionary = _activity().snapshot(false)
	context_status.text = "%s\nRecipe %s · %s\nOutput target %d · Local inputs: %s\nNeeds: %s" % [WorkforcePanel.job_name(duty,simulation),activity.recipe,activity.status,int(_activity().stock_target),_named_quantities(activity.local_inputs),_named_quantities(activity.missing_local)]
	production_controls.visible = int(staff.get("positions",0)) > 0 or simulation.rear.construction.activities.has(duty)
	if not production_controls.visible: context_status.text = "No workshop built. Open Build to place one, then assign workers after construction."
	for row in view.rear.staffing:
		if row.id == duty: context_status.text += "\n%d present · %d assigned · %d requested · %d vacancies" % [row.present,row.assigned,row.target,row.shortage]
	_refresh_build_description()

func _refresh_build_description() -> void:
	if construction_description == null or construction_turn == null: return
	var kind: String = _construction_kind()
	var spec: Dictionary = ConstructionCatalog.SPECS[kind]
	construction_description.text = "%s\n%d Building Materials · %.0f work seconds\nFootprint %s metres · needs a clear entrance and physical materials at the site.\nClick the field to place · R rotates · Esc / right-click cancels." % [BUILD_PURPOSES.get(kind,""),spec.m11,spec.work,str(ConstructionCatalog.footprint(kind,construction_turn.button_pressed))]

func _named_quantities(values: Dictionary) -> String:
	var result: Array[String] = []
	for type in values:
		if values[type] > 0: result.append("%s %s" % [_material_label(type),str(values[type])])
	return ", ".join(result) if not result.is_empty() else "none"

func _context_duty() -> String:
	return str(facility.get_item_metadata(facility.selected)) if facility.get_item_metadata(facility.selected) != null else facility.get_item_text(facility.selected)

func _sync_facilities(ids: Array) -> void:
	if ids.is_empty(): ids = [""]
	var prior: String = _context_duty()
	var existing: Array[String] = []
	for index in facility.item_count: existing.append(str(facility.get_item_metadata(index)))
	if existing == ids: return
	facility.clear()
	for id in ids:
		facility.add_item(WorkforcePanel.job_name(id,simulation) if not str(id).is_empty() else "No workshop built")
		facility.set_item_metadata(facility.item_count-1,id)
		if id == prior: facility.select(facility.item_count-1)
	if facility.selected < 0: facility.select(0)
	_load_production()

func _haul_panel(box: VBoxContainer) -> void:
	_label(box, "Orders wait for real loose source goods")
	haul_draft_status = _label(box,"Prepare an ingredient in Work, or choose a haul below. Click Order haul to submit it.")
	haul_draft_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source = _option(box, "Source", [])
	destination = _option(box, "Destination", [])
	_sync_haul_stores()
	destination.select(1)
	haul_category = _option(box, "Goods category", ["Materials", "Workshop output", "Munitions output", "Support output"])
	goods_type = _option(box, "Goods", [])
	haul_category.item_selected.connect(_load_haul_goods)
	_load_haul_goods(0)
	haul_count = _spin(box, "Units", 10000, 1)
	for option in [source,destination,haul_category,goods_type]:
		option.item_selected.connect(func(_index: int) -> void: _mark_haul_draft_dirty())
	haul_count.value_changed.connect(func(_value: float) -> void: _mark_haul_draft_dirty())
	_button(box, "Order haul", _order_haul)
	_button(box, "Clear haul draft", func() -> void:
		_haul_draft_dirty = false
		haul_count.set_value_no_signal(0)
		haul_draft_status.text = "Draft cleared. Prepare an ingredient in Work or choose new haul fields.")
	jobs = _list(box, 140)
	jobs.item_selected.connect(func(index: int) -> void: _select("job", _job_ids[index], false))
	_button(box, "Cancel selected haul", func() -> void:
		if not jobs.get_selected_items().is_empty(): _result(simulation.rear.cancel_job(_job_ids[jobs.get_selected_items()[0]])))

func _load_haul_goods(category: int) -> void:
	goods_type.clear()
	if category == 0:
		for id in ["M01", "M02", "M03", "M04", "M06", "M11", "M05", "M07", "M08", "M09", "M10"]:
			goods_type.add_item(_material_label(id))
			goods_type.set_item_metadata(goods_type.item_count-1,id)
	else:
		var duty: String = ["", "workshop", "munitions", "support"][category]
		for spec in simulation.rear.production.RECIPES.values():
			if spec.duty == duty:
				goods_type.add_item(spec.output_type)
				goods_type.set_item_metadata(goods_type.item_count-1,spec.output_type)

func _haul_choice(option: OptionButton) -> String:
	return str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""

func _mark_haul_draft_dirty() -> void:
	_haul_draft_dirty = true
	haul_draft_status.text = "Unsubmitted haul draft. Review the fields, then click Order haul; Clear haul draft lets you prepare another ingredient."

func _sync_haul_stores() -> void:
	var ids: Array = simulation.rear.stores.keys()
	for option in [source,destination]:
		var selected: String = _haul_choice(option)
		var same: bool = option.item_count == ids.size()
		if same:
			for index in ids.size():
				if option.get_item_metadata(index) != ids[index]: same = false; break
		if same: continue
		option.clear()
		for id in ids:
			option.add_item(str(id).capitalize())
			option.set_item_metadata(option.item_count-1,id)
		option.select(maxi(0,ids.find(selected)))

func _order_haul() -> void:
	var result: Dictionary = simulation.rear.request_haul(_haul_choice(source),_haul_choice(destination),_haul_choice(goods_type),int(haul_count.value))
	if result.ok:
		_haul_draft_dirty = false
		haul_draft_status.text = "Haul ordered. The Haul list tracks actual deliveries; prepare another ingredient in Work when needed."
	else: _haul_draft_dirty = true
	_result(result)

func _material_label(type: String) -> String:
	return str(Catalog.MATERIALS[type].name) if Catalog.MATERIALS.has(type) else {"M06":"Explosives","M11":"Building Materials","E01":"Service rifles","E02":"Rifle rounds","E03":"Helmets","E04":"Body armour","E05":"Support machine guns","E06":"Mortars","E07":"Mortar bombs","E08":"Engineer kits","E11":"Medic kits","E12":"Medical packs","E13":"Field guns","E14":"Artillery shells","E15":"Recon drones","E16":"Drone controllers","E17":"Drone batteries","E18":"Field radios","E19":"Marksman rifles","E20":"Binoculars","E21":"Stretchers","E24":"Smoke rounds","E25":"Tank shells","E26":"Autocannon rounds"}.get(type,type)

func _request_army_delivery() -> void:
	var result: Dictionary = session.automatic_logistics.request_delivery(str(army_request_type.get_item_metadata(army_request_type.selected)),int(army_request_count.value))
	_result(result)
	if result.ok: _refresh_army_requests(str(result.id))

func _cancel_army_delivery() -> void:
	if army_request_rows.get_selected_items().is_empty(): return
	_result(session.automatic_logistics.cancel_request(_army_request_ids[army_request_rows.get_selected_items()[0]]))

func _refresh_army_requests(preferred_id: String = "") -> void:
	if army_request_rows == null: return
	army_request_button.disabled = not simulation.empty_field_opening
	var rows: Array = session.automatic_logistics.requests.values()
	_fill(army_request_rows,_army_request_ids,rows,func(row: Dictionary) -> String:
		return "%s%s · %d / %d delivered · %s" % ["Army: " if row.get("automatic",false) else "",_material_label(row.type),row.delivered,row.requested,row.state])
	var preferred_index: int = _army_request_ids.find(preferred_id)
	if preferred_index >= 0:
		army_request_rows.select(preferred_index)
		army_request_rows.ensure_current_is_visible()
	if army_request_rows.get_selected_items().is_empty() and army_request_rows.item_count > 0: army_request_rows.select(0)
	army_request_cancel.disabled = true
	army_request_status.text = "Production inputs are hauled automatically when a staffed facility needs its next batch. Assign actual hauling workers. Delivery requires a built Logistics Centre, a parked transport truck and a qualified Driver."
	if army_request_rows.get_selected_items().is_empty(): return
	var row: Dictionary = session.automatic_logistics.requests[_army_request_ids[army_request_rows.get_selected_items()[0]]]
	army_request_status.text = "%s\n%d / %d physically unloaded at HQ\n%s" % [row.state,row.delivered,row.requested,row.blocker]
	army_request_cancel.disabled = row.cancelled or row.state == "Complete"

func _input_hauls(input_store: String, type: String, rows: Array) -> Dictionary:
	var result := {"open":0,"carried":0}
	for job in rows:
		if job.cancelled or job.destination != input_store or job.type != type: continue
		result.open += maxi(0,int(job.requested)-int(job.delivered))
		result.carried += int(job.get("in_flight",0))
	return result

func _prepare_ingredient_haul(type: String, expected_recipe: String, input_store: String) -> void:
	if _haul_draft_dirty:
		tabs.current_tab = 2
		haul_draft_status.text = "Your unfinished haul draft was kept. Order it or click Clear haul draft before preparing another ingredient."
		return
	var current: Dictionary = _activity().snapshot()
	if current.recipe != expected_recipe or current.input_store != input_store: return
	var open: Dictionary = _input_hauls(input_store,type,simulation.rear.jobs)
	var needed: int = maxi(0,int(current.missing_local.get(type,0))-int(open.open))
	var source_id := ""
	var available := 0
	for id in simulation.rear.stores:
		if id == input_store or not simulation.rear.stores[id].accessible: continue
		var count: int = simulation.rear.ledger.available_stock_at(id,type)
		if count > available: source_id = id; available = count
	if needed <= 0 or source_id.is_empty():
		_result({"ok":false,"inspection_only":true,"message":"No new haul is needed beyond existing orders." if needed <= 0 else "No accessible store has unreserved "+_material_label(type)+". Buy or manufacture it before preparing this haul."})
		return
	_sync_haul_stores()
	for index in source.item_count:
		if source.get_item_metadata(index) == source_id: source.select(index)
	for index in destination.item_count:
		if destination.get_item_metadata(index) == input_store: destination.select(index)
	haul_category.select(0)
	_load_haul_goods(0)
	for index in goods_type.item_count:
		if goods_type.get_item_metadata(index) == type: goods_type.select(index)
	haul_count.set_value_no_signal(mini(needed,available))
	_haul_draft_dirty = true
	tabs.current_tab = 2
	haul_draft_status.text = "Prepared %d %s: %s → %s. %d still missing locally; %d already ordered. Click Order haul to request real hauling." % [int(haul_count.value),_material_label(type),source_id.capitalize(),input_store.capitalize(),int(current.missing_local.get(type,0)),int(open.open)]
	# Preparing edits UI only: no after_command, reservation, job or clock step.

func _refresh_ingredients(current: Dictionary, rear_view: Dictionary) -> void:
	if ingredient_checklist == null: return
	var basis: String = str(current.recipe)+":"+str(current.input_store)
	if current.get("selected_recipe",current.recipe) == "":
		ingredient_heading.text = "Select a recipe to see its ingredient needs."
		ingredient_checklist.hide()
		return
	ingredient_checklist.show()
	ingredient_heading.text = "Ingredients for one new batch\nDeliver to %s. Physical stock and haul orders are separate." % str(current.input_store).capitalize()
	if not current.batch.is_empty(): ingredient_heading.text += "\nThe current batch has consumed its ingredients; this checklist is for the next batch."
	if _ingredient_basis != basis:
		_ingredient_basis = basis
		for child in ingredient_checklist.get_children():
			ingredient_checklist.remove_child(child)
			child.queue_free()
		for type in current.inputs:
			var row := VBoxContainer.new()
			row.set_meta("type",type)
			ingredient_checklist.add_child(row)
			_label(row,"").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_button(row,"Prepare haul: "+_material_label(type),_prepare_ingredient_haul.bind(str(type),str(current.recipe),str(current.input_store)))
			if cart.has(type):
				var review := _button(row,"Review "+_material_label(type)+" supply",_review_ingredient_supply.bind(row))
				review.name = "ReviewSupply"
				review.hide()
	for row in ingredient_checklist.get_children():
		var type: String = str(row.get_meta("type"))
		var physical := 0
		var available: int = int(current.local_inputs.get(type,0))
		for storage in rear_view.stores:
			if storage.id != current.input_store: continue
			for stock in storage.stocks:
				if stock.design_type == type: physical += int(stock.quantity)
		var open: Dictionary = _input_hauls(str(current.input_store),type,rear_view.jobs)
		var missing: int = int(current.missing_local.get(type,0))
		var new_units: int = maxi(0,missing-int(open.open))
		var source_available := 0
		for storage in rear_view.stores:
			if storage.id == current.input_store or not storage.accessible: continue
			for stock in storage.stocks:
				if stock.design_type == type: source_available += int(stock.available)
		row.get_child(0).text = "%s: %d required · %d physically here (%d available)\nMissing locally: %d · Open hauls: %d (%d being carried)\nNew haul needed: %d · Available elsewhere: %d" % [_material_label(type),int(current.inputs[type]),physical,available,missing,int(open.open),int(open.carried),new_units,source_available]
		var button: Button = row.get_child(1)
		button.disabled = new_units <= 0 or source_available <= 0
		button.tooltip_text = "Existing haul orders cover the local shortage; arrival is still required." if new_units <= 0 and missing > 0 else ("Ingredients are locally available." if missing <= 0 else ("Buy or manufacture this material; no accessible source stock is available." if source_available <= 0 else "Prepare up to %d units beyond existing haul orders. Review the fields in Haul, then click Order haul." % new_units))
		row.set_meta("ingredient_detail",row.get_child(0).text)
		row.set_meta("prepare_tooltip",button.tooltip_text)
		var review := row.get_node_or_null("ReviewSupply") as Button
		if review == null: continue
		var request: Dictionary = _ingredient_supply_request(current,type) if new_units > 0 and source_available <= 0 else {}
		row.set_meta("supply_request",request)
		review.visible = not request.is_empty()
		review.disabled = request.is_empty()
		if not request.is_empty():
			review.tooltip_text = "No accessible unreserved %s is available for a new haul. Review existing deliveries and raw supplies; ingredients must arrive and be hauled to this factory." % _material_label(type)
			row.get_child(0).text += "\n" + review.tooltip_text
			button.tooltip_text = review.tooltip_text

func _ingredient_supply_request(current: Dictionary, type: String) -> Dictionary:
	var field := cart.get(type) as SpinBox
	if not is_instance_valid(field) or not field.is_inside_tree(): return {}
	var duty := _context_duty()
	var service: RefCounted = simulation.rear.construction
	var site: Dictionary = service.instances.get(duty,service.instances.get("initial-"+duty,{}))
	if site.get("state","") != "Complete": return {}
	var owner := _activity()
	if str(current.recipe) != owner._recipe or str(current.input_store) != owner._spec.input_store or owner._spec.duty != duty: return {}
	return {"session":session,"model":simulation,"service":service,"site":site,"site_id":str(site.id),
		"owner":owner,"duty":duty,"recipe":str(current.recipe),"input_store":str(current.input_store),
		"type":type,"field":field,"kind":_selected_kind,"selection":_selected_id}

func _ingredient_supply_is_current(request: Dictionary) -> bool:
	if request.is_empty() or not is_instance_valid(session) or not is_instance_valid(request.session): return false
	if session != request.session or simulation != request.model or session.simulation != request.model: return false
	if simulation.rear.construction != request.service or _context_duty() != request.duty: return false
	if _selected_kind != request.kind or _selected_id != request.selection: return false
	var site: Dictionary = request.service.instances.get(request.site_id,{})
	if not is_same(site,request.site) or site.get("state","") != "Complete": return false
	var owner := _activity()
	if owner != request.owner or owner._recipe != request.recipe or owner._spec.input_store != request.input_store: return false
	if owner._spec.duty != request.duty or not owner._spec.inputs.has(request.type): return false
	return is_instance_valid(request.field) and request.field == cart.get(request.type) and request.field.is_inside_tree()

func _hide_ingredient_supply_review(row: Control) -> void:
	row.set_meta("supply_request",{})
	var review := row.get_node_or_null("ReviewSupply") as Button
	if review != null:
		review.disabled = true
		review.hide()
	row.get_child(0).text = str(row.get_meta("ingredient_detail",row.get_child(0).text))
	row.get_child(1).tooltip_text = str(row.get_meta("prepare_tooltip",""))

func _review_ingredient_supply(row: Control) -> void:
	if not is_instance_valid(row) or not row.is_inside_tree() or not row.is_visible_in_tree(): return
	var request: Dictionary = row.get_meta("supply_request",{})
	if not _ingredient_supply_is_current(request):
		_hide_ingredient_supply_review(row)
		return
	var owner: RefCounted = request.owner
	var type := str(request.type)
	var open := _input_hauls(request.input_store,type,simulation.rear.jobs)
	var needed: int = maxi(0,int(owner._missing().get(type,0))-int(open.open))
	if needed <= 0:
		_hide_ingredient_supply_review(row)
		return
	for id in simulation.rear.stores:
		if id == request.input_store or not simulation.rear.stores[id].accessible: continue
		if simulation.rear.ledger.available_stock_at(id,type) > 0:
			_hide_ingredient_supply_review(row)
			return
	var purchase_index := -1
	for index in _supply_views.get_tab_count():
		if _supply_views.get_tab_title(index) == "Purchase": purchase_index = index; break
	if purchase_index < 0: return
	if not show_panel("Supplies"): return
	_supply_views.current_tab = purchase_index
	if not _ingredient_supply_is_current(request): return
	var field: SpinBox = request.field
	field.get_line_edit().grab_focus()
	_purchase_catalogue_scroll.ensure_control_visible(field)
	var panel: Control = tabs.get_tab_control(tabs.current_tab)
	if panel is ScrollContainer: panel.ensure_control_visible(_purchase_catalogue_scroll)

func _production_panel(box: VBoxContainer) -> void:
	factory_plan_panel = FactoryPlanPanel.new()
	box.add_child(factory_plan_panel)
	factory_plan_panel.bind(session)
	factory_plan_panel.action_requested.connect(_factory_plan_action)
	facility = _option(box, "Facility", ["workshop", "munitions", "materials", "support", "vehicle_works"])
	facility.item_selected.connect(func(_index: int) -> void: _invalidate_batch_cancel(); _load_production(); _request_refresh())
	context_status = _label(box,"")
	context_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_staff = _spin(box,"Requested workers",8)
	context_priority = _option(box,"Staff priority",simulation.rear.PRIORITIES)
	context_staff.value_changed.connect(func(_value: float) -> void: _staff_draft_dirty = true)
	context_priority.item_selected.connect(func(_value: int) -> void: _staff_draft_dirty = true)
	_button(box,"Confirm staffing",func() -> void:
		if _staff_control_basis != str(simulation.get_instance_id())+":"+_context_duty():
			_result({"ok":false,"message":"Facility changed. Review the current staffing draft."})
			return
		var result: Dictionary = simulation.rear.set_target(_context_duty(),int(context_staff.value),context_priority.selected)
		if result.ok: _staff_draft_dirty = false
		_result(result))
	production_controls = VBoxContainer.new()
	box.add_child(production_controls)
	box = production_controls
	recipe = _option(box, "Recipe / declared session access", [])
	recipe.item_selected.connect(_batch_cancel_selection_changed)
	_button(box, "Select recipe", _change_recipe)
	mode = _option(box, "Production mode", ["Stock target", "Continuous"])
	stock_target = _spin(box, "Minimum output units", 10000)
	_button(box, "Apply production order", func() -> void:
		var activity := _activity()
		activity.set_stock_target(int(stock_target.value))
		_result(activity.set_mode(mode.get_item_text(mode.selected))))
	ingredient_heading = _label(box,"")
	ingredient_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ingredient_checklist = VBoxContainer.new()
	box.add_child(ingredient_checklist)
	_production_pause_button = _button(box, "Pause / resume facility", func() -> void: _result(_activity().set_paused(not _activity().paused)))
	_button(box, "Cancel consumed batch / stop", func() -> void: _request_batch_cancel())
	_production_enable_button = _button(box, "Enable facility", func() -> void: _result(_activity().resume()))
	heavy_controls = VBoxContainer.new()
	box.add_child(heavy_controls)
	_label(heavy_controls,"Heavy targets request goods; acceptance reserves the bay/fleet place.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(heavy_controls,"Accept heavy order",func() -> void: _result(_activity().accept_order()))
	bay_access = CheckBox.new()
	bay_access.text = "F10 bay accessible"
	heavy_controls.add_child(bay_access)
	parking_access = CheckBox.new()
	parking_access.text = "Parking route accessible"
	heavy_controls.add_child(parking_access)
	_button(heavy_controls,"Apply heavy access",func() -> void: _result(_activity().set_access(bay_access.button_pressed,parking_access.button_pressed)))
	parking_destination = _option(heavy_controls,"Requested parking destination",["F11 place 1","F11 place 2","F11 place 3","F11 place 4"])
	_button(heavy_controls,"Change promised parking",func() -> void: _result(_activity().set_parking_destination(parking_destination.selected)))
	heavy_status = _label(heavy_controls,"")
	heavy_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	production_status = _label(box, "")
	production_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _inspect_panel(box: VBoxContainer) -> void:
	inspection = _label(box, "Select a building, person, vehicle, order or haul job.")
	inspection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	store = _option(box, "Physical store", simulation.rear.stores.keys())
	store.item_selected.connect(func(_index: int) -> void: _load_store())
	capacity = _spin(box, "Capacity kg", 10000)
	accessible = CheckBox.new()
	accessible.text = "Store accessible"
	box.add_child(accessible)
	_button(box, "Apply store settings", func() -> void:
		var id := store.get_item_text(store.selected)
		if id == "receiving" and capacity.value < simulation.receiving.receiving_kg() + simulation.rear._reserved_space(id):
			_result({"ok": false, "message": "Receiving capacity must retain deposited goods and all promised inbound loads."})
		else: _result(simulation.rear.set_store(id, accessible.button_pressed, capacity.value)))

func _construction_panel(box: VBoxContainer) -> void:
	var parent := box
	box = _section(parent,"Build a facility","Choose its purpose and footprint, then click the field. Previewing or cancelling does not spend materials.")
	var kinds: Array = []
	for kind in ConstructionCatalog.SPECS:
		if not ConstructionCatalog.SPECS[kind].get("fixed",false): kinds.append(kind)
	construction_kind = _option(box,"Facility",kinds)
	for index in kinds.size():
		construction_kind.set_item_metadata(index,kinds[index])
		construction_kind.set_item_text(index,WorkforcePanel.job_name(kinds[index],simulation))
	construction_description = _label(box,"")
	construction_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	construction_kind.item_selected.connect(func(_index: int) -> void: select_build_kind(_construction_kind()); _request_refresh())
	_button(box,"Place on field",func() -> void: select_build_kind(_construction_kind()),true)
	_button(box,"Cancel placement",_cancel_placement)
	var coordinates := VBoxContainer.new()
	box.add_child(coordinates)
	coordinates.hide()
	var coordinate_toggle := CheckButton.new()
	coordinate_toggle.text = "Exact placement coordinates"
	coordinate_toggle.toggled.connect(coordinates.set_visible)
	box.add_child(coordinate_toggle)
	construction_x = _spin(coordinates,"Centre X metres",240,140)
	construction_y = _spin(coordinates,"Centre Y metres",180,10)
	construction_turn = CheckBox.new()
	construction_turn.text = "Turn footprint 90 degrees"
	box.add_child(construction_turn)
	construction_turn.toggled.connect(func(_turned: bool) -> void:
		_refresh_build_description()
		if _placing_building: preview_build_hint_at(_construction_point()))
	_button(coordinates,"Preview legal site",func() -> void: preview_build_at(_construction_point()))
	_button(coordinates,"Place physical site",func() -> void: confirm_build_at(_construction_point()))
	box = _section(parent,"Selected site","Choose a site below or click it on the field. Its materials and workers must physically arrive before construction progresses.")
	construction_rows = _list(box,120)
	construction_rows.item_selected.connect(func(index: int) -> void: _select("site",construction_ids[index],false))
	construction_status = _label(box,"")
	construction_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	construction_source = _option(box,"Building Materials source",simulation.rear.stores.keys())
	construction_builders = _spin(box,"Builder target (max four)",4)
	construction_staff = _spin(box,"Completed facility staff target",8)
	_button(box,"Deliver Building Materials to site",func() -> void:
		_result(simulation.rear.construction.order_materials(_construction_site(),construction_source.get_item_text(construction_source.selected))))
	_button(box,"Set builders",func() -> void:
		_result(simulation.rear.construction.set_builders(_construction_site(),int(construction_builders.value))))
	_button(box,"Set facility staff",func() -> void:
		var id: String = _construction_site()
		if not simulation.rear.requests.has(id):
			_result({"ok":false,"message":"Select a completed facility with staff positions."})
			return
		var priority := int(simulation.rear.requests[id].priority)
		_result(simulation.rear.set_target(id,int(construction_staff.value),priority)))
	construction_office = _spin(box,"Construction Office staff requested",4)
	construction_office.value_changed.connect(func(_value: float) -> void: _office_draft_dirty = true)
	_button(box,"Confirm office staffing",func() -> void:
		if _office_draft_basis != str(simulation.get_instance_id()): return
		var result: Dictionary = simulation.rear.construction.set_office_staff("construction",int(construction_office.value))
		if result.ok: _office_draft_dirty = false
		_result(result))
	box = _section(parent,"Remove a site","Unfinished sites can be cancelled. Completed facilities require physical clearing and dismantling.")
	_button(box,"Cancel unfinished site",func() -> void:
		_request_construction_cancel())
	_button(box,"Dismantle completed facility",func() -> void:
		_result(simulation.rear.construction.request_dismantle(_construction_site())))

func _construction_kind() -> String:
	return str(construction_kind.get_item_metadata(construction_kind.selected))

func select_build_kind(kind: String) -> void:
	if not ConstructionCatalog.SPECS.has(kind) or ConstructionCatalog.SPECS[kind].get("fixed",false): return
	for index in construction_kind.item_count:
		if str(construction_kind.get_item_metadata(index)) == kind: construction_kind.select(index)
	_refresh_build_description()
	_placing_building = true
	base_map.begin_placement()
	placement_started.emit()

func preview_build_hint_at(point: Vector2) -> void:
	preview_build_at(point,false)

func preview_build_at(point: Vector2, full_validation: bool = true) -> Dictionary:
	point = _snap_build_point(point)
	construction_x.set_value_no_signal(point.x)
	construction_y.set_value_no_signal(point.y)
	var service: RefCounted = simulation.rear.construction
	var kind: String = _construction_kind()
	var turned: bool = construction_turn.button_pressed
	var plan: Dictionary = _manager_placement_rejection(kind,point,turned)
	if plan.is_empty(): plan = service.preview(kind,point,turned) if full_validation else service.placement_hint(kind,point,turned)
	plan["provisional"] = not full_validation
	if not plan.has("footprint"):
		var size: Vector2 = ConstructionCatalog.footprint(kind,turned)
		plan.footprint = Rect2(point-size/2.0,size)
	plan["visual_kind"] = kind
	base_map.placement_preview = plan
	base_map.queue_redraw()
	if feedback != null:
		feedback.text = str(plan.message)
		feedback.visible = not feedback.text.is_empty()
	return plan

func confirm_build_at(point: Vector2) -> Dictionary:
	point = _snap_build_point(point)
	var kind: String = _construction_kind()
	var turned: bool = construction_turn.button_pressed
	var result: Dictionary = _manager_placement_rejection(kind,point,turned)
	if result.is_empty(): result = simulation.rear.construction.place(kind,point,turned)
	if result.ok:
		_cancel_placement()
		_selected_kind = "site"
		_selected_id = str(result.id)
	_result(result)
	if result.ok:
		var index: int = construction_ids.find(str(result.id))
		if index >= 0: construction_rows.select(index)
		_request_refresh()
	site_placement_result.emit(result)
	return result

func _cancel_placement() -> void:
	var was_placing := _placing_building
	_placing_building = false
	base_map.end_placement()
	if was_placing: placement_ended.emit()

func _snap_build_point(point: Vector2) -> Vector2:
	if placement_manager_body == null: return point
	var size: Vector2 = ConstructionCatalog.footprint(_construction_kind(),construction_turn.button_pressed)
	var corner: Vector2 = (point-size/2.0).snapped(Vector2.ONE)
	return corner+size/2.0

func _construction_point() -> Vector2:
	return Vector2(construction_x.value,construction_y.value)

func _construction_site() -> String:
	return construction_ids[construction_rows.get_selected_items()[0]] if not construction_rows.get_selected_items().is_empty() else ""

func _sync_option(option: OptionButton, values: Array) -> void:
	var selected: String = option.get_item_text(option.selected) if option.selected >= 0 else ""
	if option.item_count == values.size():
		var same := true
		for index in values.size():
			if option.get_item_text(index) != str(values[index]): same = false
		if same: return
	option.clear()
	for value in values: option.add_item(str(value))
	var index: int = values.find(selected)
	option.select(index if index >= 0 else 0)

func _training_panel(box: VBoxContainer) -> void:
	UIKit.label(box,"Train your workforce",20)
	_label(box,"Build a Training facility, hire its first instructor, then assign that instructor here. Train a worker in Basic infantry before Vehicle crew to prepare a Driver.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(box,"Build a Training facility",func() -> void: _factory_plan_action({"panel":"Build","building_kind":"training"}))
	training_site = _option(box,"Training facility",[])
	training_site.item_selected.connect(func(_index: int) -> void: _request_refresh())
	instructor_hire_button = _button(box,"Hire instructor · 120 requisition",func() -> void: _result(simulation.receiving.buy_recovery_instructor()),true)
	instructor_hire_status = _label(box,"")
	instructor_hire_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructor_count = _spin(box,"Instructor target",2)
	instructor_count.value_changed.connect(func(_value: float) -> void: _instructor_draft_dirty = true)
	_button(box,"Confirm instructor target",func() -> void:
		var duty := _training_duty()
		if not duty.is_empty():
			if _instructor_draft_basis != str(simulation.get_instance_id())+":"+duty:
				_result({"ok":false,"message":"School changed. Review its current instructor draft."})
				return
			var priority := int(simulation.rear.requests.get(duty,{}).get("priority",1))
			var result: Dictionary = simulation.rear.set_target(duty,int(instructor_count.value),priority)
			if result.ok: _instructor_draft_dirty = false
			_result(result))
	training_course = _option(box,"Course / declared recipe access",[])
	training_count = _spin(box,"Requested students",12,1)
	_button(box,"Request course",func() -> void: _result(simulation.rear.training.request_course(training_course.get_item_metadata(training_course.selected),int(training_count.value))))
	training_rows = _list(box,150)
	training_rows.item_selected.connect(func(index: int) -> void:
		_selected_kind = "course"
		_selected_id = training_ids[index]
		_request_refresh())
	_button(box,"Withdraw selected course",func() -> void:
		if not training_rows.get_selected_items().is_empty(): _result(simulation.rear.training.withdraw(training_ids[training_rows.get_selected_items()[0]])))
	training_access = CheckBox.new()
	training_access.text = "Training facility accessible"
	training_access.set_pressed_no_signal(true)
	box.add_child(training_access)
	training_access.toggled.connect(func(value: bool) -> void: _result(simulation.rear.training.set_access(value)))
	training_status = _label(box,"")
	training_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_courses()

func _vehicles_panel(box: VBoxContainer) -> void:
	_label(box,"Prepare a supply truck").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box,"Build Vehicle Works and a Vehicle Park. In Production choose Supply truck, apply a target of 1 and accept the vehicle order. Train a Driver, buy fuel, then prepare the same manufactured truck below.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(box,"Vehicle production",_open_vehicle_production,true)
	_button(box,"Driver training",func() -> void: show_panel("Train"))
	_button(box,"Buy fuel",func() -> void:
		show_panel("Supplies")
		_supply_views.current_tab = 0
		cart.M08.get_line_edit().grab_focus())
	vehicle_rows = _list(box,140)
	vehicle_rows.item_selected.connect(func(_index: int) -> void: _load_vehicle_stations(); _request_refresh())
	vehicle_person = _option(box,"Driver / crew member",[])
	vehicle_station = _option(box,"Distinct crew station",[])
	_button(box,"Report and board selected station",func() -> void:
		if not vehicle_rows.get_selected_items().is_empty() and vehicle_person.selected >= 0 and vehicle_station.selected >= 0:
			_result(simulation.rear.vehicles.assign_station(_vehicle_id(),vehicle_person.get_item_metadata(vehicle_person.selected),vehicle_station.get_item_text(vehicle_station.selected))))
	_button(box,"Extract selected station occupant",func() -> void:
		if vehicle_person.selected >= 0: _result(simulation.rear.reassign_person(vehicle_person.get_item_metadata(vehicle_person.selected),"Available")))
	vehicle_fuel_person = _option(box,"Available fuel-handling worker",[])
	vehicle_fuel_units = _spin(box,"Whole M08 units (up to 25 per carry)",25,1)
	_button(box,"Carry purchased fuel into this tank",func() -> void:
		if not vehicle_rows.get_selected_items().is_empty() and vehicle_fuel_person.selected >= 0:
			_result(simulation.rear.vehicles.request_refuel(_vehicle_id(),vehicle_fuel_person.get_item_metadata(vehicle_fuel_person.selected),int(vehicle_fuel_units.value))))
	_button(box,"Drive SAME F10 hull to promised F11 place",func() -> void:
		if not vehicle_rows.get_selected_items().is_empty(): _result(simulation.rear.vehicles.start_drive(_vehicle_id())))
	vehicle_status = _label(box,"")
	vehicle_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box,"Once parked, staff a Logistics Centre and use Supplies → Army requests. Its workers load the truck, deliver to HQ and return for the next load.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _dispatch_panel(box: VBoxContainer) -> void:
	_label(box,"G12/G13 | Accept one actual parked produced hull. Passenger seats exclude crew; Strategic returns hull/crew, Fleet permanently transfers them at HQ. Preview the full route against tank fuel before departure.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dispatch_hull = _option(box,"Same F10-produced parked hull",[])
	dispatch_site = _option(box,"Physical F07 dispatch berth",["Initial F07"])
	dispatch_mode = _option(box,"Mode",["Strategic Delivery","Fleet Transfer"])
	dispatch_surface = _option(box,"Route surface",["TR02 Road","TR03 Farm","TR07 Rocky","TR10 Ford","TR11 Deep water"])
	dispatch_bridge = _option(box,"Specified crossing fixture",["No bridge","B02 Light road bridge","B03 Heavy road bridge"])
	dispatch_clearance = _spin(box,"Route clear width (metres)",30,8)
	_label(box,"Select named rear passengers (Ctrl-click for multiple). They remain separate from crew.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dispatch_people = _list(box,105)
	dispatch_people.select_mode = ItemList.SELECT_MULTI
	dispatch_gun = _option(box,"Same packed E13 at F10",["No field gun"])
	var types: Array = ["E01","E02"]
	for type in Fixed.RECIPES.values():
		if type.output_type not in types and type.output_type != "E13": types.append(type.output_type)
	for index in range(1,12):
		var code := "M%02d" % index
		if code not in types: types.append(code)
	dispatch_cargo_type = _option(box,"Cargo type (real stock or intact weapon)",types)
	dispatch_cargo_count = _spin(box,"Whole cargo units to add",5000,1)
	_button(box,"Add requested cargo line",func() -> void:
		var type := dispatch_cargo_type.get_item_text(dispatch_cargo_type.selected)
		dispatch_draft[type] = int(dispatch_draft.get(type,0)) + int(dispatch_cargo_count.value)
		_request_refresh())
	_button(box,"Clear requested cargo lines",func() -> void: dispatch_draft.clear(); _request_refresh())
	_button(box,"Accept named manifest and claims",func() -> void:
		if dispatch_hull.selected < 0: _result({"ok":false,"message":"Select an actual parked produced hull."}); return
		var passengers: Array = []
		for index in dispatch_people.get_selected_items(): passengers.append(dispatch_person_ids[index])
		var guns: Array = []
		if dispatch_gun.selected > 0: guns.append(dispatch_gun.get_item_metadata(dispatch_gun.selected))
		_result(simulation.rear.dispatch.accept(dispatch_hull.get_item_metadata(dispatch_hull.selected),dispatch_mode.get_item_text(dispatch_mode.selected),passengers,dispatch_draft,guns,str(dispatch_site.get_item_metadata(dispatch_site.selected))))
		_request_refresh())
	_label(box,"Accepted manifests | requested, reserved, staged, onboard, arrived and unloaded use the same physical IDs.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dispatch_rows = _list(box,110)
	dispatch_rows.item_selected.connect(func(_index: int) -> void: _request_refresh())
	_button(box,"Depart complete selected manifest",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty(): _result(simulation.rear.dispatch.depart(dispatch_ids[dispatch_rows.get_selected_items()[0]])))
	_button(box,"Preview measured route and gross load",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty():
			var plan: Dictionary = simulation.rear.dispatch.route_preview(dispatch_ids[dispatch_rows.get_selected_items()[0]],_dispatch_profile())
			_result({"ok":plan.ok,"inspection_only":true,"message":("%.1f m, %.1f s, %.2f travel fuel, %.2f required with reserve, %.2f in tank, gross %.1f kg" % [plan.distance,plan.seconds,plan.fuel,plan.required_fuel,plan.tank_fuel,plan.gross_kg]) if plan.ok else plan.message}))
	_button(box,"Apply measured route before departure",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty(): _result(simulation.rear.dispatch.set_route_profile(dispatch_ids[dispatch_rows.get_selected_items()[0]],_dispatch_profile())))
	_button(box,"Change selected manifest mode before departure",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty(): _result(simulation.rear.dispatch.change_mode(dispatch_ids[dispatch_rows.get_selected_items()[0]],dispatch_mode.get_item_text(dispatch_mode.selected))))
	_button(box,"Add same F10 field gun to selected manifest",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty() and dispatch_gun.selected > 0: _result(simulation.rear.dispatch.add_field_gun(dispatch_ids[dispatch_rows.get_selected_items()[0]],dispatch_gun.get_item_metadata(dispatch_gun.selected))))
	_button(box,"Cancel selected predeparture manifest",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty(): _result(simulation.rear.dispatch.cancel(dispatch_ids[dispatch_rows.get_selected_items()[0]])))
	_button(box,"Request safe return before HQ receipt",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty(): _result(simulation.rear.dispatch.request_safe_return(dispatch_ids[dispatch_rows.get_selected_items()[0]])))
	_button(box,"Report observed unsafe forward route",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty(): _result(simulation.rear.dispatch.report_route_hazard(dispatch_ids[dispatch_rows.get_selected_items()[0]],"Observed unsafe forward road")))
	_button(box,"Clear observed route hazard",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty(): _result(simulation.rear.dispatch.clear_route_hazard(dispatch_ids[dispatch_rows.get_selected_items()[0]])))
	dispatch_status = _label(box,"")
	dispatch_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _hq_panel(box: VBoxContainer) -> void:
	_label(box,"Development diagnostics: manually exercise local HQ handoffs. Normal HQ command selects recipients automatically.")
	hq_person = _option(box,"Same person in HQ Reserve",[])
	hq_hull = _option(box,"Same stopped military hull at HQ berth",[])
	hq_type = _option(box,"Unreserved unloaded stock type",[])
	hq_weapon = _option(box,"Intact weapon in HQ stock",[])
	hq_count = _spin(box,"Whole units",1200,1)
	_button(box,"Issue stock to person",func() -> void:
		if hq_person.selected < 0 or hq_type.selected < 0: return
		_result(simulation.rear.hq.request_person_stock(str(hq_person.get_item_metadata(hq_person.selected)),str(hq_type.get_item_metadata(hq_type.selected)),int(hq_count.value))))
	_button(box,"Issue intact weapon to person",func() -> void:
		if hq_person.selected < 0 or hq_weapon.selected < 0: return
		_result(simulation.rear.hq.request_person_weapon(str(hq_person.get_item_metadata(hq_person.selected)),str(hq_weapon.get_item_metadata(hq_weapon.selected)))))
	_button(box,"Load matching rounds into HQ hull rack",func() -> void:
		if hq_hull.selected < 0 or hq_type.selected < 0: return
		_result(simulation.rear.hq.request_vehicle_ammo(str(hq_hull.get_item_metadata(hq_hull.selected)),str(hq_type.get_item_metadata(hq_type.selected)),int(hq_count.value))))
	_button(box,"Refuel HQ hull from unloaded M08",func() -> void:
		if hq_hull.selected < 0: return
		_result(simulation.rear.hq.request_vehicle_fuel(str(hq_hull.get_item_metadata(hq_hull.selected)),int(hq_count.value))))
	hq_rows = _list(box,125)
	_button(box,"Cancel selected issue; return any carried stock",func() -> void:
		if not hq_rows.get_selected_items().is_empty(): _result(simulation.rear.hq.cancel(hq_ids[hq_rows.get_selected_items()[0]])))
	hq_status = _label(box,"")
	hq_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _refresh_hq_option(option: OptionButton, entries: Array[Dictionary]) -> void:
	var selected: String = str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""
	option.clear()
	for entry in entries:
		option.add_item(entry.label)
		option.set_item_metadata(option.item_count-1,entry.id)
		if entry.id == selected: option.select(option.item_count-1)
	if option.selected < 0 and option.item_count > 0: option.select(0)

func _refresh_hq(view: Dictionary) -> void:
	if hq_person == null: return
	var people: Array[Dictionary] = []
	var hulls: Array[Dictionary] = []
	var weapons: Array[Dictionary] = []
	for entity in view.rear.ledger.entities:
		if entity.kind == "PERSON" and entity.assignment == "HQ Reserve" and entity.holder_id in ["hq-reserve","hq-stock"]:
			people.append({"id":entity.id,"label":"%s | %.1f/25 kg" % [entity.id,entity.contents_mass_kg]})
		elif entity.kind == "CARRIER" and entity.fleet_domain == "Military" and entity.holder_id == "hq-berth":
			hulls.append({"id":entity.id,"label":"%s %s | fuel %.0f" % [entity.id,entity.design_type,entity.fuel]})
		elif entity.kind == "WEAPON" and entity.holder_id == "hq-stock":
			weapons.append({"id":entity.id,"label":"%s %s" % [entity.id,entity.design_type]})
	var types: Array[Dictionary] = []
	for type in view.hq.available:
		if int(view.hq.available[type]) > 0: types.append({"id":type,"label":"%s | %d available" % [type,int(view.hq.available[type])]})
	_refresh_hq_option(hq_person,people)
	_refresh_hq_option(hq_hull,hulls)
	_refresh_hq_option(hq_type,types)
	_refresh_hq_option(hq_weapon,weapons)
	_fill(hq_rows,hq_ids,view.hq.rows,func(row: Dictionary) -> String: return "%s | %s %s | %d/%d | %s | %s" % [row.id,row.kind,row.target,row.issued,row.requested,row.state,row.blocker])
	hq_status.text = "HQ stock %.1f/%.0f kg | available %s | reserved %s | intact weapons %s | promised weapons %s\nActual issue changes holdings only when local handoff finishes. Remote delivery and transfer are separate work." % [view.hq.occupied_stock_kg,view.hq.stock_limit_kg,str(view.hq.available),str(view.hq.reserved),str(view.hq.weapons_available),str(view.hq.weapons_promised)]

func _dispatch_profile() -> Dictionary:
	var profile := {"surface":dispatch_surface.get_item_text(dispatch_surface.selected).get_slice(" ",0),"corridor_width":dispatch_clearance.value}
	if dispatch_bridge.selected > 0: profile.bridge = dispatch_bridge.get_item_text(dispatch_bridge.selected).get_slice(" ",0)
	return profile

func _vehicle_id() -> String:
	return vehicle_ids[vehicle_rows.get_selected_items()[0]] if not vehicle_rows.get_selected_items().is_empty() else ""

func _load_vehicle_people() -> void:
	if vehicle_person == null or vehicle_fuel_person == null: return
	var crew: Array[Dictionary] = []
	var fuel: Array[Dictionary] = []
	for id in simulation.rear.actors:
		var person: Dictionary = simulation.rear.ledger.inspect_person_status(id)
		if person.owner != simulation.rear.PLAYER or person.health <= 0 or person.rear_place != "Occupied": continue
		# Seated rear crew remain selectable for the existing safe-exit command.
		if person.qualification in ["P08","P04"]: crew.append(person)
		if person.assignment == "Available" and person.pending_assignment == "None" and person.crew_station.is_empty() and person.carrying_stock_id.is_empty(): fuel.append(person)
	_sync_vehicle_people(vehicle_person,crew)
	_sync_vehicle_people(vehicle_fuel_person,fuel)

func _sync_vehicle_people(option: OptionButton, people: Array[Dictionary]) -> void:
	var selected := str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""
	var selection := -1
	for index in people.size():
		var person: Dictionary = people[index]
		var role := "Driver trained" if person.qualification == "P08" else ("Heavy weapons trained" if person.qualification == "P04" else "Worker")
		var caption := "%s · %s · %s" % [role,str(person.id),str(person.assignment)]
		if index >= option.item_count: option.add_item(caption)
		elif option.get_item_text(index) != caption: option.set_item_text(index,caption)
		option.set_item_metadata(index,str(person.id))
		if str(person.id) == selected: selection = index
	while option.item_count > people.size(): option.remove_item(option.item_count-1)
	option.select(selection if selection >= 0 else (0 if not people.is_empty() else -1))
	option.disabled = people.is_empty()
	if people.is_empty(): option.text = "No eligible rear person available"

func _open_vehicle_production() -> void:
	var chosen := {}
	for site in simulation.rear.construction.instances.values():
		if site.kind != "vehicle_works" or site.state in ["Cancelled","Destroyed","Dismantled"]: continue
		if chosen.is_empty() or (site.state == "Complete" and chosen.state != "Complete"): chosen = site
	_factory_plan_action({"panel":"Work" if chosen.get("state","") == "Complete" else "Build","facility_id":str(chosen.get("id","")),"building_kind":"vehicle_works","focus":"target"})

func _training_duty() -> String:
	if training_site == null or training_site.selected < 0: return ""
	var duty := str(training_site.get_item_metadata(training_site.selected))
	for site in simulation.rear.training.training_sites:
		if site.active and str(site.duty) == duty: return duty
	return ""

func _sync_training_sites(sites: Array) -> void:
	var selected := str(training_site.get_item_metadata(training_site.selected)) if training_site.selected >= 0 else ""
	var active: Array = sites.filter(func(site: Dictionary) -> bool: return bool(site.active))
	var selection := -1
	for index in active.size():
		var duty := str(active[index].duty)
		var caption := WorkforcePanel.job_name(duty,simulation)
		if index >= training_site.item_count: training_site.add_item(caption)
		elif training_site.get_item_text(index) != caption: training_site.set_item_text(index,caption)
		training_site.set_item_metadata(index,duty)
		if duty == selected: selection = index
	while training_site.item_count > active.size(): training_site.remove_item(training_site.item_count-1)
	training_site.select(selection if selection >= 0 else (0 if not active.is_empty() else -1))
	training_site.disabled = active.is_empty()
	if active.is_empty(): training_site.text = "Build a Training facility"

func _load_vehicle_stations() -> void:
	if vehicle_station == null: return
	var selected: String = vehicle_station.get_item_text(vehicle_station.selected) if vehicle_station.selected >= 0 else ""
	vehicle_station.clear()
	var id := _vehicle_id()
	if id.is_empty(): return
	for station in simulation.rear.ledger.inspect_entity(id).vehicle_spec.stations:
		vehicle_station.add_item(station)
		if station == selected: vehicle_station.select(vehicle_station.item_count-1)
	if vehicle_station.selected < 0 and vehicle_station.item_count > 0: vehicle_station.select(0)

func _load_courses() -> void:
	training_course.clear()
	for id in simulation.rear.training.COURSES:
		var spec: Dictionary = simulation.rear.training.COURSES[id]
		var allowed: bool = simulation.rear.training.course_accessible(id)
		training_course.add_item(id + " " + spec.name + ("" if allowed else " (locked)"))
		training_course.set_item_metadata(training_course.item_count-1,id)
		training_course.set_item_disabled(training_course.item_count-1,not allowed)

func _activity() -> RefCounted:
	var id: String = _context_duty()
	if simulation.rear.construction.activities.has(id): return simulation.rear.construction.activities[id]
	match id:
		"workshop": return simulation.rear.production
		"munitions": return simulation.rear.munitions_production
		"materials": return simulation.rear.materials_production
		"support": return simulation.rear.support_production
		"vehicle_works": return simulation.rear.heavy_production
	return simulation.rear.production

func _load_production() -> void:
	_staff_draft_dirty = false
	_validate_batch_cancel()
	var activity := _activity()
	heavy_controls.visible = activity.has_method("accept_order")
	bay_access.set_pressed_no_signal(activity.bay_accessible if activity.has_method("accept_order") else true)
	parking_access.set_pressed_no_signal(activity.parking_accessible if activity.has_method("accept_order") else true)
	mode.select(0 if activity.mode == "Stock target" else 1)
	stock_target.set_value_no_signal(activity.stock_target)
	var view: Dictionary = activity.snapshot(false)
	var choices: Array = view.get("recipe_choices", [view.recipe])
	recipe.clear()
	for id in choices:
		var spec: Dictionary = activity.RECIPES[id]
		var allowed: bool = activity.recipe_accessible(id) if activity.has_method("recipe_accessible") else true
		recipe.add_item(str(VEHICLE_NAMES.get(spec.output_type,spec.output_type)) + " · " + id + ("" if allowed else " (locked)"))
		recipe.set_item_metadata(recipe.item_count - 1, id)
		recipe.set_item_disabled(recipe.item_count - 1, not allowed)
		if id == view.recipe: recipe.select(recipe.item_count - 1)

func _load_store() -> void:
	var entry: Dictionary = simulation.rear.stores[store.get_item_text(store.selected)]
	capacity.set_value_no_signal(entry.capacity)
	accessible.set_pressed_no_signal(entry.accessible)

func _build_construction_cancel_dialog() -> void:
	_construction_cancel_dialog = ConfirmationDialog.new()
	_construction_cancel_dialog.name = "ConstructionCancellation"
	_construction_cancel_dialog.min_size = Vector2i(620,230)
	_construction_cancel_dialog.dialog_autowrap = true
	_construction_cancel_dialog.ok_button_text = "Cancel construction"
	_construction_cancel_dialog.cancel_button_text = "Keep construction"
	_construction_cancel_dialog.confirmed.connect(_confirm_construction_cancel)
	_construction_cancel_dialog.canceled.connect(_keep_construction_cancel)
	add_child(_construction_cancel_dialog)

func _request_construction_cancel() -> void:
	_keep_construction_cancel()
	var service: RefCounted = simulation.rear.construction
	var id := _construction_site()
	var loss: Dictionary = service.cancellation_loss(id)
	if loss.is_empty():
		_result(service.cancel(id))
		return
	_construction_cancel_request = {"session":session,"simulation":simulation,"service":service,
		"id":id,"site":service.instances[id],"kind":_selected_kind,"selection":_selected_id}
	_construction_cancel_dialog.title = "Cancel construction of %s (%s)?" % [WorkforcePanel.job_name(id,simulation),id]
	_update_construction_cancel_warning(int(loss.consumed_m11))
	_construction_cancel_dialog.popup_centered_clamped(Vector2i(680,280))
	_construction_cancel_dialog.get_cancel_button().grab_focus()

func _construction_cancel_is_current(request: Dictionary) -> bool:
	if request.is_empty() or not is_instance_valid(session) or not is_instance_valid(request.session): return false
	if session != request.session or simulation != request.simulation or session.simulation != request.simulation: return false
	if simulation.rear.construction != request.service: return false
	if _construction_site() != request.id or _selected_kind != request.kind or _selected_id != request.selection: return false
	var service: RefCounted = request.service
	if not is_same(service.instances.get(request.id,{}),request.site): return false
	var loss: Dictionary = service.cancellation_loss(request.id)
	return not loss.is_empty()

func _update_construction_cancel_warning(consumed: int) -> void:
	_construction_cancel_dialog.dialog_text = "Building Materials used now: %d. Builders continue while this dialog is open, so this amount can increase. Cancellation loses all work and only the materials actually used when you confirm. Remaining real materials return through workers and hauling." % consumed

func _confirm_construction_cancel() -> void:
	if _construction_cancel_request.is_empty(): return
	var request := _construction_cancel_request
	_keep_construction_cancel() # Consume one decision before validation or command.
	if not _construction_cancel_is_current(request):
		_result({"ok":false,"requires_reconciliation":false,"message":"The construction site changed. Nothing was cancelled. Review the current site and try again."})
		return
	var service: RefCounted = request.service
	_result(service.cancel(request.id))

func _keep_construction_cancel() -> void:
	_construction_cancel_request = {}
	if is_instance_valid(_construction_cancel_dialog): _construction_cancel_dialog.hide()

func _invalidate_construction_cancel() -> void:
	if _construction_cancel_request.is_empty(): return
	_keep_construction_cancel()
	_result({"ok":false,"requires_reconciliation":false,"message":"The construction site changed. Nothing was cancelled. Review the current site and try again."})

func _validate_construction_cancel() -> void:
	if _construction_cancel_request.is_empty(): return
	if not _construction_cancel_is_current(_construction_cancel_request):
		_invalidate_construction_cancel()
		return
	var loss: Dictionary = _construction_cancel_request.service.cancellation_loss(_construction_cancel_request.id)
	_update_construction_cancel_warning(int(loss.consumed_m11))

func _build_batch_cancel_dialog() -> void:
	_batch_cancel_dialog = ConfirmationDialog.new()
	_batch_cancel_dialog.name = "ConsumedBatchCancellation"
	_batch_cancel_dialog.title = "Cancel active batch?"
	_batch_cancel_dialog.min_size = Vector2i(620,260)
	_batch_cancel_dialog.dialog_autowrap = true
	_batch_cancel_dialog.ok_button_text = "Cancel batch and stop"
	_batch_cancel_dialog.cancel_button_text = "Keep batch"
	_batch_cancel_dialog.confirmed.connect(_confirm_batch_cancel)
	_batch_cancel_dialog.canceled.connect(_keep_batch_cancel)
	add_child(_batch_cancel_dialog)

func _request_batch_cancel() -> void:
	_keep_batch_cancel()
	var activity := _activity()
	if activity.batch.is_empty():
		_result(activity.cancel())
		return
	var batch: Dictionary = activity.batch
	var duty := _context_duty()
	_batch_cancel_request = {"session":session,"simulation":simulation,"activity":activity,"duty":duty,
		"kind":_selected_kind,"selection":_selected_id,"recipe":str(batch.recipe),"batch_id":str(batch.id)}
	var consumed := {}
	for portion in batch.receipt:
		consumed[portion.type] = int(consumed.get(portion.type,0)) + int(portion.count)
	var output: String = str(VEHICLE_NAMES.get(activity._spec.output_type,_material_label(activity._spec.output_type)))
	_batch_cancel_dialog.dialog_text = "%s · %s / %s · %s\n\nCancel this batch and stop production here? Its consumed ingredients (%s) will not be refunded. Work already done on this batch will be lost, and its unfinished output will not be produced. Finished goods remain.\n\nTo suspend work without discarding this batch, keep it and use Pause / resume facility." % [WorkforcePanel.job_name(duty,simulation),batch.recipe,output,batch.id,_named_quantities(consumed)]
	_batch_cancel_dialog.popup_centered_clamped(Vector2i(680,320))
	_batch_cancel_dialog.get_cancel_button().grab_focus()

func _batch_cancel_is_current(request: Dictionary) -> bool:
	if request.is_empty() or not is_instance_valid(session) or not is_instance_valid(request.session): return false
	if session != request.session: return false
	if simulation != request.simulation or session.simulation != request.simulation: return false
	if _context_duty() != request.duty or _selected_kind != request.kind or _selected_id != request.selection: return false
	var activity := _activity()
	if activity != request.activity or str(activity._recipe) != request.recipe: return false
	return str(activity.batch.get("id","")) == request.batch_id and str(activity.batch.get("recipe","")) == request.recipe

func _confirm_batch_cancel() -> void:
	if _batch_cancel_request.is_empty(): return
	var request := _batch_cancel_request
	_keep_batch_cancel() # Single-use before validation or any domain command.
	if not _batch_cancel_is_current(request):
		_result({"ok":false,"requires_reconciliation":false,"message":"The batch changed. Nothing was cancelled. Review the current batch and try again."})
		return
	var activity: RefCounted = request.activity
	_result(activity.cancel())

func _keep_batch_cancel() -> void:
	_batch_cancel_request = {}
	if is_instance_valid(_batch_cancel_dialog): _batch_cancel_dialog.hide()

func _invalidate_batch_cancel() -> void:
	if _batch_cancel_request.is_empty(): return
	_keep_batch_cancel()
	_result({"ok":false,"requires_reconciliation":false,"message":"The batch changed. Nothing was cancelled. Review the current batch and try again."})

func _on_session_state_changed() -> void:
	_request_refresh()
	_validate_batch_cancel()
	_validate_construction_cancel()

func _validate_batch_cancel() -> void:
	if not _batch_cancel_request.is_empty() and not _batch_cancel_is_current(_batch_cancel_request): _invalidate_batch_cancel()

func _batch_cancel_model_changed(_next: RefCounted) -> void:
	if include_workers != null: discard_menu_drafts()
	_bind_purchase_receiving(_next.receiving)
	if include_workers != null: include_workers.set_pressed_no_signal(false)
	_invalidate_batch_cancel()
	_invalidate_construction_cancel()

func _batch_cancel_selection_changed(_index: int) -> void:
	_invalidate_batch_cancel()

func _exit_tree() -> void:
	_bind_purchase_receiving(null)
	_batch_cancel_request = {}
	_construction_cancel_request = {}
	if is_instance_valid(session):
		if session.state_changed.is_connected(_on_session_state_changed): session.state_changed.disconnect(_on_session_state_changed)
		if session.simulation_changed.is_connected(_batch_cancel_model_changed): session.simulation_changed.disconnect(_batch_cancel_model_changed)

func _change_recipe() -> void:
	var activity := _activity()
	if not activity.has_method("request_recipe"):
		_result({"ok": true, "message": "R26 is the fixed Materials recipe."})
		return
	var result: Dictionary = activity.request_recipe(recipe.get_item_metadata(recipe.selected))
	if result.get("confirmation_required", false):
		_pending_activity = activity
		_pending_token = result.token
		confirmation.dialog_text = result.message
		confirmation.popup_centered()
	_result(result)
	_load_production()

func _result(result: Dictionary) -> void:
	var reconcile: bool = result.get("requires_reconciliation", true)
	if session != null and reconcile: session.notify_command.call_deferred()
	if reconcile and not result.get("speed_change",false) and not result.get("inspection_only",false): simulation.after_command()
	if feedback != null:
		feedback.text = str(result.get("message", str(result)))
		feedback.visible = not feedback.text.is_empty()
	command_reported.emit(result)
	if is_node_ready(): _request_refresh()

func _select(kind: String, id: String, open_panel: bool = true) -> void:
	if kind != _selected_kind or id != _selected_id:
		_invalidate_batch_cancel()
		_invalidate_construction_cancel()
	_selected_kind = kind
	_selected_id = id
	if open_panel:
		var target := "Info"
		if kind == "building" and id == "terminal": target = "Supplies"
		elif kind == "site" and not simulation.rear.construction.activities.has(id): target = "Build"
		elif kind == "building" or (kind == "site" and simulation.rear.construction.activities.has(id)): target = "Work"
		var previous_tab: int = tabs.current_tab
		show_panel(target,false)
		# Hidden controls can be old while Supplies is open. Refresh the target
		# before resolving its selection; tab_changed handles a visible new tab.
		if target == "Work" or previous_tab == tabs.current_tab or not is_visible_in_tree(): _refresh()
		if target == "Build": _cancel_placement()
	if kind == "site":
		var site_index: int = construction_ids.find(id)
		if site_index >= 0: construction_rows.select(site_index)
	if kind == "building":
		var store_id := "vehicle_input" if id == "vehicle_works" else (id if simulation.rear.stores.has(id) else id + "_input")
		var index: int = simulation.rear.stores.keys().find(store_id)
		if index >= 0:
			store.select(index)
			_load_store()
	if open_panel:
		if (kind == "building" and id != "terminal") or (kind == "site" and simulation.rear.construction.activities.has(id)):
			var found := false
			for index in facility.item_count:
				if str(facility.get_item_metadata(index)) == id:
					facility.select(index)
					_load_production()
					found = true
					break
			if not found: show_panel("Info")
	_request_refresh()

func _fill(list: ItemList, ids: Array[String], entries: Array, make_text: Callable) -> void:
	CallLog.record(&"rear_base/base_demo.gd::_fill")
	var next_ids: Array[String] = []
	for entry in entries: next_ids.append(entry.id)
	if ids == next_ids:
		for index in entries.size():
			var summary: String = make_text.call(entries[index])
			if list.get_item_text(index) != summary:
				list.set_item_text(index, summary)
				list.set_item_tooltip(index, summary)
		return
	var selected := ids[list.get_selected_items()[0]] if not list.get_selected_items().is_empty() else ""
	var scroll: float = list.get_v_scroll_bar().value
	list.clear()
	ids.clear()
	for entry in entries:
		ids.append(entry.id)
		var summary: String = make_text.call(entry)
		list.add_item(summary)
		list.set_item_tooltip(ids.size() - 1, summary)
		if entry.id == selected: list.select(ids.size() - 1)
	list.get_v_scroll_bar().set_deferred("value", scroll)


func _refresh_dispatch_choices(view: Dictionary) -> void:
	var chosen_site: String = str(dispatch_site.get_item_metadata(dispatch_site.selected)) if dispatch_site.selected >= 0 else "dispatch"
	var site_ids: Array = simulation.rear.dispatch.dispatch_sites.keys()
	site_ids.sort()
	var sites_changed: bool = dispatch_site.item_count != site_ids.size()
	if not sites_changed:
		for index in site_ids.size():
			if dispatch_site.get_item_metadata(index) != site_ids[index]: sites_changed = true; break
	if sites_changed:
		dispatch_site.clear()
		for site_id in site_ids:
			dispatch_site.add_item("Initial F07" if site_id == "dispatch" else site_id + " / F07")
			dispatch_site.set_item_metadata(dispatch_site.item_count-1,site_id)
			if site_id == chosen_site: dispatch_site.select(dispatch_site.item_count-1)
		if dispatch_site.selected < 0 and dispatch_site.item_count > 0: dispatch_site.select(0)
	var chosen_hull: String = str(dispatch_hull.get_item_metadata(dispatch_hull.selected)) if dispatch_hull.selected >= 0 else ""
	var hull_ids: Array[String] = []
	for row in view.vehicles.rows:
		if row.state == "Parked": hull_ids.append(row.id)
	var same_hulls: bool = dispatch_hull.item_count == hull_ids.size()
	if same_hulls:
		for index in hull_ids.size():
			if dispatch_hull.get_item_metadata(index) != hull_ids[index]: same_hulls = false; break
	if not same_hulls:
		dispatch_hull.clear()
		for id in hull_ids:
			dispatch_hull.add_item(id+" / "+simulation.rear.ledger.inspect_entity(id).design_type)
			dispatch_hull.set_item_metadata(dispatch_hull.item_count-1,id)
			if id == chosen_hull: dispatch_hull.select(dispatch_hull.item_count-1)
		if dispatch_hull.selected < 0 and dispatch_hull.item_count > 0: dispatch_hull.select(0)
	var gun_ids: Array[String] = []
	for activity in simulation.rear._production_activities():
		if not activity.has_method("accept_order") or activity.bay_occupant.is_empty(): continue
		var occupant: String = activity.bay_occupant
		if simulation.rear.ledger.inspect_entity(occupant).get("design_type","") == "E13": gun_ids.append(occupant)
	gun_ids.sort()
	var chosen_gun: String = str(dispatch_gun.get_item_metadata(dispatch_gun.selected)) if dispatch_gun.selected > 0 else ""
	var guns_changed: bool = dispatch_gun.item_count != gun_ids.size()+1
	if not guns_changed:
		for index in gun_ids.size():
			if dispatch_gun.get_item_metadata(index+1) != gun_ids[index]: guns_changed = true; break
	if guns_changed:
		dispatch_gun.clear()
		dispatch_gun.add_item("No field gun")
		for gun_id in gun_ids:
			dispatch_gun.add_item(gun_id+" at F10")
			dispatch_gun.set_item_metadata(dispatch_gun.item_count-1,gun_id)
			if chosen_gun == gun_id: dispatch_gun.select(dispatch_gun.item_count-1)
	var ids: Array[String] = []
	for p in view.rear.people:
		if p.owner == "army-blue" and p.rear_place == "Occupied" and p.crew_station.is_empty() and simulation.rear.actors.has(p.id): ids.append(p.id)
	if ids != dispatch_person_ids:
		var selected: Array[String] = []
		for index in dispatch_people.get_selected_items(): selected.append(dispatch_person_ids[index])
		dispatch_people.clear()
		dispatch_person_ids = ids
		for index in ids.size():
			var p: Dictionary = simulation.rear.ledger.inspect_entity(ids[index])
			dispatch_people.add_item("%s %s | %s at %s" % [p.id,p.design_type,p.assignment,str(p.position)])
			if ids[index] in selected: dispatch_people.select(index,false)

func _dispatch_army_diagnostics(view: Dictionary) -> String:
	var text := ""
	text += "\nArmy command %s | %d companies, %d platoons, %d squads, %d vehicle elements\nOrganization: %s" % [view.military.commander,view.military.companies.size(),view.military.platoons.size(),view.military.squads.size(),view.military.vehicles.size(),view.military.status]
	for shortage in view.military.shortages: text += "\nShortage: %s" % shortage
	for squad in view.military.squads:
		text += "\n%s %s %s | %s/%s | %d actual members | leader %s | readiness %.2f | %s" % [squad.id,squad.kind,squad.state,squad.company,squad.platoon,squad.roster.size(),squad.leader,squad.readiness,squad.blocker]
	for hull_id in view.military.vehicles:
		var element: Dictionary = view.military.vehicles[hull_id]
		text += "\nElement %s under %s | crew %s | passengers %s | readiness %.2f" % [hull_id,element.parent,str(element.crew),element.passenger_squad,simulation.rear.military.vehicle_readiness(hull_id)]
	for person in view.combat.people:
		text += "\nCombat %s at %s | %s | health %d, morale %d, suppression %d, bleed %.1f s" % [person.id,str(person.position),person.state,person.health,person.morale,person.suppression,person.bleed_remaining]
	for id in view.combat.formations:
		var formation: Dictionary = view.combat.formations[id]
		text += "\nCohesion %s %.2f | %s %s" % [id,formation.cohesion,formation.state,formation.blocked_reason]
	for id in view.combat.demands: text += "\nCombat supply %s: %s" % [id,view.combat.demands[id].blocked_reason]
	for id in view.combat.care: text += "\nCare %s: %.1f/10 seconds, active %s, pack %s committed" % [id,view.combat.care[id].progress,str(view.combat.care[id].active),view.combat.care[id].pack]
	return text

func _refresh_dispatch(view: Dictionary) -> void:
	_refresh_dispatch_choices(view)
	_fill(dispatch_rows,dispatch_ids,view.dispatch.rows,func(row: Dictionary) -> String: return "%s | %s | %s %s | %s" % [row.id,row.mode,row.hull,row.state,row.blocker])
	if dispatch_rows.get_selected_items().is_empty() and dispatch_rows.item_count > 0: dispatch_rows.select(dispatch_rows.item_count-1)
	var text := "Draft cargo %s\nMilitary: %d members + %d incoming / 384; hulls %d + %d / 24\nRear return places %d | HQ Reserve %d/96, stock %.1f/20000 kg\nHQ local available %s | reserved %s" % [str(dispatch_draft),view.dispatch.military_people,view.dispatch.incoming_people,view.dispatch.military_hulls,view.dispatch.incoming_hulls,view.dispatch.return_places,view.dispatch.hq_reserve,view.dispatch.hq_stock_kg,str(view.hq.available),str(view.hq.reserved)]
	text += "\nHQ intact weapons %s | promised %s\nHQ command: %s" % [str(view.hq.weapons_available),str(view.hq.weapons_promised),str(view.hq.auto_status)]
	if view.has("military") and view.has("combat"): text += _dispatch_army_diagnostics(view)
	for job in view.hq.rows:
		if job.state not in ["Complete","Cancelled"]: text += "\nHQ %s %s: %d/%d %s | %s" % [job.kind,job.target,job.issued,job.requested,job.state,job.blocker]
	if dispatch_rows.get_selected_items().is_empty():
		if dispatch_status.text != text: dispatch_status.text = text
		return
	var id: String = dispatch_ids[dispatch_rows.get_selected_items()[0]]
	for row in view.dispatch.rows:
		if row.id != id: continue
		text += "\n%s %s | same %s at %s | fuel %.2f | driver %s | crew %s\nPassengers %s | guns %s | payload %.1f/%.1f kg; seats %d/%d\nRequested %s\nCommitted %s\nStaged %s\nOnboard %s\nArrived %s\nUnloaded %s\nHandling %s; route %.1f/%.1f m\nBlocked: %s" % [row.id,row.state,row.hull,str(row.hull_physical.position),row.hull_physical.fuel,row.driver,str(row.crew),str(row.passengers),str(row.guns),row.payload_used,row.hull_physical.vehicle_spec.payload,row.seats_used,row.hull_physical.vehicle_spec.passenger_seats,str(row.requested),str(row.committed),str(row.staged),str(row.onboard),str(row.arrived),str(row.unloaded),str(row.task.get("phase","idle")),row.distance,row.route_length,row.blocker]
		var planned: Dictionary = row.get("full_route_plan",{})
		if planned.get("ok",false): text += "\nG13 last plan %.1f m / %.1f s; fuel %.2f + 25%% = %.2f needed; gross %.1f kg; %s" % [planned.distance,planned.seconds,planned.fuel,planned.required_fuel,planned.gross_kg,str(planned.profile)]
		break
	if dispatch_status.text != text: dispatch_status.text = text

func _refresh() -> void:
	# An explicit refresh consumes any queued presentation for the same frame.
	# Session replacement and retained diagnostic callers may refresh directly.
	if get_tree().process_frame.is_connected(_refresh): get_tree().process_frame.disconnect(_refresh)
	CallLog.record(&"rear_base/base_demo.gd::_refresh")
	var started_usec: int = Time.get_ticks_usec() if CallLog.enabled else 0
	_refresh_contents()
	if CallLog.enabled: CallLog.record_duration(&"rear_base/base_demo.gd::_refresh",Time.get_ticks_usec()-started_usec)

func _refresh_contents() -> void:
	_refresh_queued = false
	if orders == null or not is_visible_in_tree(): return
	if _local_clock_controls.visible: _local_clock_status.text = clock_text()
	_displayed_time = simulation.rear.time
	_displayed_speed = simulation.speed
	_displayed_planning_revision = simulation.planning_view_revision
	base_map.queue_redraw()
	var active_panel: String = str(tabs.get_tab_control(tabs.current_tab).name)
	resource_hud.visible = active_panel != "ArmyNeeds"
	if active_panel == "ArmyNeeds": return
	var diagnostics: bool = OS.get_environment("TRENCHO_HQ_DIAGNOSTICS") == "1"
	if active_panel == "Supplies" and not diagnostics:
		_refresh_purchasing()
		return
	if active_panel == "Workers_Jobs" and not diagnostics:
		_refresh_workforce()
		return
	if active_panel == "Build" and not diagnostics:
		_refresh_construction()
		return
	if active_panel == "Train" and not diagnostics:
		_refresh_training()
		return
	if active_panel == "Work" and not diagnostics:
		_refresh_work()
		return
	if active_panel == "Vehicles" and not diagnostics:
		var vehicle_view: Dictionary = simulation.vehicle_view()
		_refresh_resource_hud(vehicle_view)
		_refresh_vehicle_controls(vehicle_view,true)
		status.text = "  %.0f req | %d rear + %d incoming" % [vehicle_view.receiving.money,vehicle_view.rear_population,simulation.receiving.incoming_people()]
		return
	if active_panel == "Haul" and not diagnostics:
		var haul_view: Dictionary = simulation.hauling_view()
		_refresh_resource_hud(haul_view)
		_sync_haul_stores()
		_refresh_haul_rows(haul_view.rear.jobs)
		status.text = "  %.0f req | %d rear + %d incoming" % [haul_view.receiving.money,haul_view.rear_population,simulation.receiving.incoming_people()]
		return
	if active_panel == "Supply" and not diagnostics:
		var supply_view: Dictionary = simulation.purchasing_view()
		_refresh_resource_hud(supply_view)
		forward_delivery_panel.refresh()
		status.text = "  %.0f req | %d rear + %d incoming" % [supply_view.receiving.money,supply_view.rear_population,simulation.receiving.incoming_people()]
		return
	if active_panel == "Dispatch" and not diagnostics:
		var dispatch_view: Dictionary = simulation.dispatch_view()
		_refresh_resource_hud(dispatch_view)
		_refresh_dispatch(dispatch_view)
		status.text = "  %.0f req | %d rear + %d incoming" % [dispatch_view.receiving.money,dispatch_view.rear_population,simulation.receiving.incoming_people()]
		return
	if active_panel == "Info" and not diagnostics:
		var info_view: Dictionary = simulation.inspection_view(_selected_kind,_selected_id)
		_refresh_resource_hud(info_view)
		_sync_option(store,simulation.rear.stores.keys())
		if _selected_kind == "building" and _selected_id == "vehicle_works": _refresh_production_status(simulation.production_view())
		if _selected_kind == "course" or (_selected_kind == "building" and _selected_id == "training"): _refresh_training_controls(simulation.rear.training.snapshot(),simulation.training_person_view(_selected_id))
		_refresh_inspection(info_view)
		status.text = "  %.0f req | %d rear + %d incoming" % [info_view.receiving.money,info_view.rear_population,simulation.receiving.incoming_people()]
		return
	var view: Dictionary = simulation.snapshot(diagnostics,diagnostics or active_panel == "Dispatch")
	_sync_haul_stores()
	_sync_option(store,simulation.rear.stores.keys())
	_sync_option(construction_source,simulation.rear.stores.keys())
	_refresh_office_draft()
	construction_office.editable = simulation.rear.requests.has("construction") and int(simulation.rear.requests.construction.positions) > 0
	(construction_office.get_parent() as Control).visible = construction_office.editable
	var parking_labels: Array = []
	for index in simulation.rear.yard.PARKING_POSITIONS.size():
		parking_labels.append("F11 place %d%s" % [index+1,"" if simulation.rear.yard.active_parking[index] else " (retired)"])
	_sync_option(parking_destination,parking_labels)
	var production_ids: Array = []
	for id in ["workshop","munitions","materials","support","vehicle_works"]:
		if int(simulation.rear.requests.get(id,{}).get("positions",0)) > 0: production_ids.append(id)
	for row in view.construction.rows:
		if row.state == "Complete" and simulation.rear.construction.activities.has(row.id): production_ids.append(row.id)
	_sync_facilities(production_ids)
	_sync_option(person_duty,["Available"]+simulation.rear.requests.keys())
	_refresh_core_ui(view)
	_refresh_ingredients(_activity().snapshot(),view.rear)
	_fill(construction_rows,construction_ids,view.construction.rows,func(row: Dictionary) -> String:
		return "%s · %s · %d Building Materials" % [WorkforcePanel.job_name(row.id,simulation),str(row.state).replace("M11","Building Materials"),row.m11])
	_sync_construction_selection()
	var selected_site: String = _construction_site()
	construction_status.text = "Select a site or building to inspect its physical work."
	for row in view.construction.rows:
		if row.id == selected_site:
			construction_status.text = _construction_progress_text(row)
	if active_panel == "Dispatch": _refresh_dispatch(view)
	if active_panel == "Supply": forward_delivery_panel.refresh()
	_refresh_hq(view)
	var offer: Dictionary = view.receiving.recovery_offer
	recovery_button.visible = offer.available
	recovery_status.text = offer.message
	_refresh_training_controls(view.training, simulation.training_person_view(_selected_id))
	var rear_population := 0
	for person in view.rear.people:
		if person.owner == simulation.rear.PLAYER and person.get("rear_place","None") in ["Occupied","Held Home"]: rear_population += 1
	status.text = "  %.0f req | %d rear + %d incoming" % [view.receiving.money, rear_population, simulation.receiving.incoming_people()]
	_fill(orders, _order_ids, view.receiving.orders, _order_summary)
	_refresh_delivery_status(view.receiving)
	var actual_people: Array = view.rear.people.filter(func(p: Dictionary) -> bool: return p.owner == "army-blue")
	_fill(people, _person_ids, actual_people, func(p: Dictionary) -> String: return p.id + " | " + (p.duty_id if not p.duty_id.is_empty() else p.assignment) + " | " + p.phase)
	_refresh_vehicle_controls(view,active_panel == "Vehicles")
	_refresh_haul_rows(view.rear.jobs)
	_refresh_production_status(view)
	_refresh_inspection(view)

func _refresh_inspection(view: Dictionary) -> void:
	var info := _selected_kind + ": " + _selected_id + "\n"
	match _selected_kind:
		"site":
			if simulation.rear.construction.instances.has(_selected_id):
				var row: Dictionary = simulation.rear.construction.instances[_selected_id]
				info += "%s %s at %s\nFootprint %s; entrance %s\nM11 %d; work %.1f/%.0f\n%s\n" % [row.kind,row.state,str(row.center),str(row.size),str(row.door),row.m11,row.progress,row.work,row.blocker]
				if simulation.rear.requests.has(_selected_id):
					var request: Dictionary = simulation.rear.requests[_selected_id]
					info += "Staff %d/%d target; %d actually assigned\n" % [request.target,request.positions,simulation.rear._assigned(_selected_id)]
				for storage in view.rear.stores:
					if storage.id == _selected_id or storage.id.begins_with(_selected_id+"-"):
						info += "%s: %.1f/%.1f kg\n" % [storage.id,storage.physical_kg,storage.capacity]
		"entity":
			var p: Dictionary = simulation.rear.ledger.inspect_entity(_selected_id)
			info += "Owner: %s\nHolder: %s\nPosition: %s\nDuty: %s; pending: %s\nCarry: %s\n%s" % [p.get("owner", ""), p.get("holder_id", ""), str(p.get("position", "")), p.get("duty_id", "External supplier service"), p.get("pending_duty", ""), p.get("carrying_stock_id", ""), p.get("blocked_reason", "")]
			if p.get("kind") == "PERSON": info += "\nBasic completed: %s; specialist: %s" % [str(p.basic_training),p.qualification]
			if p.get("kind") == "CARRIER" and simulation.rear.vehicles.vehicles.has(_selected_id):
				info += "\nTank %.2f/%.0f; crew by station %s; passengers %s; rack %s\nReadiness %s" % [p.fuel,p.vehicle_spec.tank_capacity,str(p.crew_by_station),str(p.passengers),str(p.ammunition),str(simulation.rear.vehicles.readiness(_selected_id))]
		"building":
			if simulation.rear.requests.has(_selected_id):
				var r: Dictionary = simulation.rear.requests[_selected_id]
				info += "Staff target %d / %d positions; actual %d.\n" % [r.target, r.positions, simulation.rear._assigned(_selected_id)]
			if _selected_id == "vehicle_works": info += heavy_status.text + "\n"
			if _selected_id == "training": info += training_status.text + "\n"
			for row in view.rear.stores:
				if row.id == _selected_id or row.id.begins_with(_selected_id + "_"):
					info += "%s: %.1f kg, free %.1f, inbound %.1f, output promise %.1f\n" % [row.id, row.physical_kg, row.free_kg, row.reserved_inbound_kg, row.reserved_output_kg]
					for stock in row.stocks: info += "%s %d (reserved %d)\n" % [stock.design_type, stock.quantity, stock.reserved]
		"course":
			info += training_status.text
		"job":
			for job in view.rear.jobs:
				if job.id == _selected_id: info += "%s -> %s: %s %d/%d; in flight %d\n%s" % [job.source, job.destination, job.type, job.delivered, job.requested, job.in_flight, job.blocker]
		"order":
			for order in view.receiving.orders:
				if order.id == _selected_id: info += "%s %s\nCargo %s\nUnloaded %s\n%s" % [order.kind, order.state, str(order.cargo), str(order.unloaded), order.blocked_reason]
	inspection.text = info

func _refresh_haul_rows(rows: Array) -> void:
	_fill(jobs, _job_ids, rows, func(j: Dictionary) -> String: return "%s %s %d/%d | %s" % [j.id, j.type, j.delivered, j.requested, ("Missing hauling staff" if j.delivered < j.requested and simulation.rear._assigned("hauling") == 0 else j.blocker)])

static func _transport_truck_status(row: Dictionary, delivery: Dictionary) -> String:
	if row.get("utility",false):
		var status := "Construction-only utility truck · %s\nFuel %.2f / %.0f · finite tank; no free refill.\nAn idle assigned hauler loads M11, drives and unloads for unfinished sites. No P08 needed for this truck; no army/passengers.\nTo refuel: buy M08 in Supplies, select an available worker and use the fuel carry button below." % [row.state,row.hull.fuel,row.hull.vehicle_spec.tank_capacity]
		if not str(row.get("utility_blocker","")).is_empty(): status += "\n"+str(row.utility_blocker)
		if not str(row.get("utility_worker","")).is_empty(): status += "\nSame hauler: "+str(row.utility_worker)+" · "+str(row.get("utility_phase",""))
		return status
	var lines: Array[String] = [
		"%s · %s" % [VEHICLE_NAMES[row.hull.design_type],row.state],
		"Fuel %.1f / %.0f · Driver %s" % [row.hull.fuel,row.hull.vehicle_spec.tank_capacity,"seated" if row.readiness.driver else "required"]]
	for job in row.fuel_claims:
		if not str(job.get("claim","")).is_empty():
			lines.append("Fuel reserved: %d units; pickup and tank handoff pending." % int(job.units))
		elif not str(job.get("carried","")).is_empty():
			lines.append("Fuel carried: %d units; tank handoff pending." % int(job.units))
		else:
			lines.append("Fuel handling: %d units pending." % int(job.units))
	if not delivery.is_empty():
		lines.append("Delivery: " + str(delivery.state))
		if not str(delivery.handling).is_empty(): lines.append("Handling: " + str(delivery.handling))
		if not str(delivery.blocker).is_empty(): lines.append("Blocked: " + str(delivery.blocker))
		lines.append("Inspect this shipment in Supplies → Army requests or Dispatch.")
	else:
		if not row.readiness.driver: lines.append("Choose a trained Driver and report to this truck's Driver station.")
		if row.hull.fuel <= 0.0 and row.fuel_claims.is_empty(): lines.append("Choose an available worker to carry purchased fuel into the tank.")
		if row.state == "In F10":
			lines.append("Finish fuel handling and boarding before driving this truck to its promised parking place.")
		elif row.state == "Parked":
			lines.append("Inspect Army needs for actual demand, stock coverage, handling and transport eligibility. A staffed Logistics Centre fulfils genuine Army requests automatically when automatic supply is enabled and the physical requirements are met.")
		else:
			lines.append("Inspect the current vehicle state before requesting another trip.")
	return "\n".join(lines)

func _refresh_vehicle_controls(view: Dictionary, include_people: bool) -> void:
	if include_people: _load_vehicle_people()
	_fill(vehicle_rows,vehicle_ids,view.vehicles.rows,func(row: Dictionary) -> String: return ("Construction utility · %s | %s | fuel %.2f/%.0f" % [row.id,row.state,row.hull.fuel,row.hull.vehicle_spec.tank_capacity]) if row.get("utility",false) else ("%s %s | %s | fuel %.1f/%.0f | F11 %d" % [row.id,row.hull.design_type,row.state,row.hull.fuel,row.hull.vehicle_spec.tank_capacity,row.slot+1]))
	if vehicle_rows.get_selected_items().is_empty() and vehicle_rows.item_count > 0:
		vehicle_rows.select(0)
		_load_vehicle_stations()
	vehicle_status.text = "No manufactured vehicle yet. Build Vehicle Works and a Vehicle Park, choose Supply truck in Production, apply its target and accept the order."
	for row in view.vehicles.rows:
		if row.id != _vehicle_id(): continue
		if row.hull.design_type in ["T01","T02"]:
			vehicle_status.text = _transport_truck_status(row,simulation.rear.dispatch.active_handling_status(row.id))
			continue
		vehicle_status.text = "%s %s at %s | %s | distance %.1f/%.1fm | fuel burned %.3f\nStations %s; missing %s\nDriver-only Fleet Transfer crew %s; motion %s; combat crew %s; main-fire stations %s; matching rack ammo %d; combat ready %s\nFuel carries %s; rear fleet remains %d live/%d reserved. Fleet Transfer preserves this hull at HQ; inspect military deployment on Battlefield and actual E26 issue in Supply." % [row.id,row.hull.design_type,str(row.hull.position),row.state,row.distance,row.length,row.burned,str(row.hull.crew_by_station),str(row.readiness.missing_stations),str(row.readiness.transfer_crew_eligible),str(row.readiness.motion_ready),str(row.readiness.combat_crew_ready),str(row.readiness.main_fire_stations_ready),row.readiness.matching_ammo,str(row.readiness.combat_ready),str(row.fuel_claims),view.heavy.fleet.live,view.heavy.fleet.reserved]

func _refresh_work() -> void:
	var view: Dictionary = simulation.production_view()
	_refresh_resource_hud(view)
	_sync_facilities(view.production_facilities)
	var parking_labels: Array = []
	for index in simulation.rear.yard.PARKING_POSITIONS.size():
		parking_labels.append("F11 place %d%s" % [index+1,"" if simulation.rear.yard.active_parking[index] else " (retired)"])
	_sync_option(parking_destination,parking_labels)
	_refresh_production_context(view)
	_refresh_ingredients(_activity().snapshot(false),view.rear)
	_refresh_production_status(view)
	status.text = "  %.0f req | %d rear + %d incoming" % [view.receiving.money,view.rear_population,simulation.receiving.incoming_people()]

func _refresh_production_status(view: Dictionary) -> void:
	var lines: Array[String] = []
	var activities: Array = []
	if view.has("production_activities"):
		activities = view.production_activities
	else:
		activities = [view.production,view.munitions,view.materials,view.support]
		for site_id in simulation.rear.construction.activities:
			var copy: RefCounted = simulation.rear.construction.activities[site_id]
			if not copy.has_method("accept_order"): activities.append(copy.snapshot(false))
	for activity in activities:
		lines.append("%s %s -> %s: %s\nLocal %s; missing %s\nWork %.1f/%.0f; output %d; promised %.1f kg" % [activity.facility,activity.recipe,activity.output_type,activity.status,str(activity.local_inputs),str(activity.missing_local),activity.batch.get("work",0.0),activity.required_work,activity.physical_output,activity.output_promise.get("mass",0.0)])
	production_status.text = "\n\n".join(lines)
	var heavy: Dictionary = _activity().snapshot(false) if _activity().has_method("accept_order") else view.heavy
	if heavy.is_empty():
		heavy_status.text = ""
		return
	heavy_status.text = "%s -> %s: %s\nRear fleet: %d live + %d reserved / 8\nBay: %s\nOrder: %s; work %.1f/%.0f\n%s" % [heavy.recipe,heavy.output_type,heavy.status,heavy.fleet.live,heavy.fleet.reserved,heavy.bay.occupant if not heavy.bay.occupant.is_empty() else ("one accepted promise" if not heavy.order.is_empty() else "empty"),heavy.order.get("id","unaccepted"),heavy.batch.get("work",0.0),heavy.required_work,heavy.bay.clearance]
	if heavy.bay.parking_slot >= 0:
		heavy_status.text += "\nReserved destination: F11 place %d %s" % [heavy.bay.parking_slot+1,str(heavy.bay.parking_position)]
	else: heavy_status.text += "\nDestination: F10 heavy collection bay"
	if not heavy.bay.physical.is_empty():
		var object: Dictionary = heavy.bay.physical
		heavy_status.text += "\n%s: %.0f kg; fuel %.0f; %d crew, %d passengers; no ammunition" % [object.design_type,object.unit_mass_kg,object.get("fuel",0.0),object.get("crew",[]).size(),object.get("passengers",[]).size()]

func _refresh_office_draft() -> void:
	var basis := str(simulation.get_instance_id())
	if basis != _office_draft_basis: _office_draft_dirty = false
	_office_draft_basis = basis
	if not _office_draft_dirty: construction_office.set_value_no_signal(int(simulation.rear.construction.office_desired.get("construction",0)))

func _refresh_construction() -> void:
	CallLog.record(&"rear_base/base_demo.gd::_refresh_construction")
	var view: Dictionary = simulation.construction_view()
	_refresh_resource_hud(view)
	_refresh_build_description()
	_sync_option(construction_source, simulation.rear.stores.keys())
	_refresh_office_draft()
	construction_office.editable = simulation.rear.requests.has("construction") and int(simulation.rear.requests.construction.positions) > 0
	(construction_office.get_parent() as Control).visible = construction_office.editable
	_fill(construction_rows, construction_ids, view.construction.rows, func(row: Dictionary) -> String:
		return "%s · %s · %d Building Materials" % [WorkforcePanel.job_name(row.id, simulation), str(row.state).replace("M11", "Building Materials"), row.m11])
	_sync_construction_selection()
	_refresh_construction_progress()
	status.text = "  %.0f req | %d rear + %d incoming" % [view.receiving.money, view.rear_population, simulation.receiving.incoming_people()]

func _refresh_construction_progress() -> void:
	construction_status.text = "Select a site or building to inspect its physical work."
	var row: Dictionary = simulation.rear.construction.instances.get(_construction_site(),{})
	if row.is_empty(): return
	construction_status.text = _construction_progress_text(row)

func _construction_progress_text(row: Dictionary) -> String:
	var duty: String = "builders-" + str(row.id)
	var present: int = simulation.rear._present(duty) if simulation.rear.requests.has(duty) else 0
	var stored: int = simulation.rear.ledger.available_stock_at(row.id,"M11") if simulation.rear.stores.has(row.id) else 0
	var progress: float = float(row.progress)/float(row.work) if float(row.work) > 0.0 else 1.0
	var used: int = int(row.get("consumed_m11",row.m11 if row.state == "Complete" else 0))
	var heading := "Construction complete" if row.state == "Complete" else "Construction %d%% · Builders present: %d" % [roundi(progress*100),present]
	if row.state in ["Clearing","Dismantling","Dismantled","Cancelled"]: heading = str(row.state)
	var text := "%s · %s\n%s\nBuilding Materials: used %d / %d · Stored on site: %d\n%s" % [WorkforcePanel.job_name(row.id,simulation),str(row.state).replace("M11","Building Materials"),heading,used,row.m11,stored,str(row.blocker).replace("M11","Building Materials")]
	if simulation.rear.requests.has(duty):
		text += "\nBuilders: %d assigned · %d requested" % [simulation.rear._assigned(duty),simulation.rear.requests[duty].target]
	return text

func _refresh_training() -> void:
	CallLog.record(&"rear_base/base_demo.gd::_refresh_training")
	var view: Dictionary = simulation.training_view(_selected_id)
	var offer: Dictionary = view.receiving.recovery_offer
	instructor_hire_button.disabled = not bool(offer.available) or float(view.receiving.money) < 120.0
	instructor_hire_status.text = "120 requisition includes arrival transport. The instructor must arrive before teaching." if offer.available else str(offer.message).replace("recovery","instructor").replace("Recovery","Instructor")
	_refresh_resource_hud(view)
	_refresh_training_controls(view.training, view.training_selected_person)
	status.text = "  %.0f req | %d rear + %d incoming" % [view.receiving.money, view.rear_population, simulation.receiving.incoming_people()]

func _refresh_training_controls(training: Dictionary, person: Dictionary) -> void:
	_sync_training_sites(training.training_sites)
	_fill(training_rows,training_ids,training.rows,func(row: Dictionary) -> String: return "%s %s %s | %s %.1f/%.0fs" % [row.id,row.course,row.person_id,row.state,row.work,row.required])
	var duty := _training_duty()
	var requested := int(simulation.rear.requests.get(duty,{}).get("target",0))
	var basis := str(simulation.get_instance_id())+":"+duty
	if basis != _instructor_draft_basis: _instructor_draft_dirty = false
	_instructor_draft_basis = basis
	if not _instructor_draft_dirty: instructor_count.set_value_no_signal(requested)
	instructor_count.editable = not duty.is_empty()
	training_status.text = "Selected school's instructor target: %d · Instructors present overall: %d · Coverage: %d students\nStudent places reserved: %d | active %d, paused %d, reporting %d, queued %d\n" % [requested,training.instructors.size(),training.coverage,training.reserved_student_places,training.counts.Active,training.counts.Paused,training.counts.Reporting,training.counts.Queued]
	if duty.is_empty(): training_status.text += "Build a Training facility before assigning instructors or requesting courses.\n"
	elif training.instructors.is_empty(): training_status.text += "Hire or assign an existing basic-trained instructor, then wait for reporting. If that person is on another job, use Workers / Jobs to raise this school's priority above competing jobs and allow the current carry and reporting to finish.\n"
	for row in training.rows:
		if row.id != _selected_id: continue
		training_status.text += "%s / %s: %s\nElapsed %.1f/%.0f seconds; %s" % [row.course,row.person_id,row.state,row.work,row.required,row.reason]
		if not person.is_empty():
			training_status.text += "\nBasic completed: %s; specialist: %s\nActual position %s; duty %s" % [str(person.basic_training),person.qualification,str(person.position),person.duty_id if not person.duty_id.is_empty() else person.assignment]


func _refresh_purchasing() -> void:
	CallLog.record(&"rear_base/base_demo.gd::_refresh_purchasing")
	var view: Dictionary = simulation.purchasing_view()
	_refresh_resource_hud(view)
	_refresh_purchase_quote()
	var offer: Dictionary = view.receiving.recovery_offer
	recovery_button.visible = offer.available
	recovery_status.text = offer.message
	status.text = "  %.0f req | %d rear + %d incoming" % [view.receiving.money,view.rear_population,simulation.receiving.incoming_people()]
	_fill(orders,_order_ids,view.receiving.orders,_order_summary)
	_refresh_delivery_status(view.receiving)
	_refresh_army_requests()

func _refresh_workforce() -> void:
	CallLog.record(&"rear_base/base_demo.gd::_refresh_workforce")
	var view: Dictionary = simulation.workforce_view()
	_refresh_resource_hud(view)
	workforce_panel.refresh(view)
	_sync_option(person_duty,["Available"]+simulation.rear.requests.keys())
	_fill(people,_person_ids,view.rear.people,func(person: Dictionary) -> String:
		return person.id+" | "+(person.duty_id if not person.duty_id.is_empty() else person.assignment)+" | "+person.phase)

func _factory_plan_action(action: Dictionary) -> void:
	if str(action.get("focus","")) in ["enable","pause"]:
		_focus_factory_recovery(action)
		return
	var panel := str(action.get("panel", ""))
	var id := str(action.get("facility_id", ""))
	if panel == "Build" and not id.is_empty():
		_select("site", id)
	elif panel == "Build":
		show_panel("Build")
		select_build_kind(str(action.get("building_kind", "")))
	elif panel == "Work" and not id.is_empty():
		if str(tabs.get_tab_control(tabs.current_tab).name) == "Work" and _context_duty() == id:
			# Returning to an already selected control must not reload the model
			# over a target, staffing or recipe draft that has not been submitted.
			match str(action.get("focus","")):
				"target": stock_target.get_line_edit().grab_focus()
				"staff": context_staff.get_line_edit().grab_focus()
				"recipe": recipe.grab_focus()
			return
		_select("site", id)
	elif not panel.is_empty():
		show_panel(panel)

func _army_needs_panel(box: VBoxContainer) -> void:
	army_supply_panel = ArmySupplyPanel.new()
	box.add_child(army_supply_panel)
	army_supply_panel.bind(session,ArmySupplyView.view)
	army_supply_panel.action_requested.connect(_army_supply_action)

func _army_supply_action(requested: Dictionary) -> void:
	# A click re-resolves current commands; never execute an old facility/action
	# retained by deferred presentation across a replaced session.
	var current: Dictionary = ArmySupplyView.view(session)
	var action := {}
	for candidate in current.get("actions",[]):
		if candidate.id == requested.get("id","") and candidate.get("enabled",false):
			action = candidate
			break
	if action.is_empty(): return
	match str(action.id):
		"resume_automatic": _result(session.automatic_logistics.resume_automatic_supply("E02"))
		"resume_rifle_equipment": _result(session.automatic_logistics.resume_automatic_supply("E01"))
		"rear_requests":
			show_panel("Supplies")
			for index in _supply_views.get_tab_count():
				if _supply_views.get_tab_title(index) == "Army requests":
					_supply_views.current_tab = index
					break
		"observe":
			var id := str(requested.get("entity_id",""))
			for row in current.get("recipients",[]):
				if row.id == id:
					observation_requested.emit(id)
					break
		_: _factory_plan_action(action)

func _focus_factory_recovery(requested: Dictionary) -> void:
	if session == null or session.simulation != simulation: return
	var action: Dictionary = factory_plan_panel.current_recovery_action(requested)
	if action.is_empty(): return
	var id := str(action.facility_id)
	var panel: Control = tabs.get_tab_control(tabs.current_tab)
	if str(panel.get_meta("panel_title",panel.name)) != "Work" or _context_duty() != id:
		_select("site",id)
	# Recheck identities/state after selection without another plan query.
	if session.simulation != simulation or not factory_plan_panel.recovery_identity_is_current(requested): return
	if _context_duty() != id or _activity() != requested.owner: return
	if action.focus == "enable" and _activity().enabled: return
	if action.focus == "pause" and (not _activity().enabled or not _activity().paused): return
	panel = tabs.get_tab_control(tabs.current_tab)
	if str(panel.get_meta("panel_title",panel.name)) != "Work": return
	var button: Button = _production_enable_button if action.focus == "enable" else _production_pause_button
	button.grab_focus()
	if panel is ScrollContainer: panel.ensure_control_visible(button)

func _sync_construction_selection() -> void:
	if _selected_kind != "site": return
	var index: int = construction_ids.find(_selected_id)
	if index >= 0: construction_rows.select(index)

func _manager_placement_rejection(kind: String, point: Vector2, turned: bool) -> Dictionary:
	if not is_instance_valid(placement_manager_body) or not is_instance_valid(placement_manager_shape): return {}
	if placement_manager_shape.get_parent() != placement_manager_body or placement_manager_shape.disabled: return {}
	if not point.is_finite() or not ConstructionCatalog.SPECS.has(kind) or ConstructionCatalog.SPECS[kind].get("fixed",false): return {}
	var capsule: CapsuleShape3D = placement_manager_shape.shape as CapsuleShape3D
	if capsule == null: return {}
	# The actual controller capsule is upright/unscaled; visual offsets never apply.
	var at: Vector3 = placement_manager_shape.global_position
	var center: Vector2 = Vector2(at.x,at.z)
	var size: Vector2 = ConstructionCatalog.footprint(kind,turned)
	var footprint: Rect2 = Rect2(point-size/2.0,size)
	var nearest: Vector2 = Vector2(clampf(center.x,footprint.position.x,footprint.end.x),clampf(center.y,footprint.position.y,footprint.end.y))
	var radius: float = capsule.radius
	if center.distance_squared_to(nearest) < radius*radius:
		return {"ok":false,"message":"Move away before placing here.","requires_reconciliation":false}
	return {}
