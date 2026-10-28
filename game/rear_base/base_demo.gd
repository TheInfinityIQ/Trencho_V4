extends Control
## One live scene, persistent panels, physical map and player commands.
const Simulation = preload("res://game/rear_base/base_simulation.gd")
const Map = preload("res://game/rear_base/base_map.gd")
const Catalog = preload("res://game/procurement/resource_catalog.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
var simulation := Simulation.new()
var base_map: Control
var tabs: TabContainer
var status: Label
var feedback: Label
var orders: ItemList
var people: ItemList
var jobs: ItemList
var inspection: Label
var production_status: Label
var cart: Dictionary = {}
var targets: Dictionary = {}
var source: OptionButton
var destination: OptionButton
var goods_type: OptionButton
var haul_count: SpinBox
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
var training_access: CheckBox
var recovery_button: Button
var recovery_status: Label
var vehicle_rows: ItemList
var vehicle_ids: Array[String] = []
var vehicle_person: OptionButton
var vehicle_station: OptionButton
var vehicle_fuel_units: SpinBox
var vehicle_status: Label
var dispatch_hull: OptionButton
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
var _pending_activity: RefCounted
var scenario: OptionButton
var declaration: Label
var _selected_kind := "building"
var _selected_id := "terminal"
var _refresh_elapsed := 0.0
var _order_ids: Array[String] = []
var _person_ids: Array[String] = []
var _job_ids: Array[String] = []

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var clock := HBoxContainer.new()
	layout.add_child(clock)
	for value in [0, 1, 2]:
		_button(clock, ["Pause", "1x", "2x"][value], func() -> void: _result(simulation.set_speed(value)))
	_button(clock, "Fit base", func() -> void: base_map.reset_camera())
	status = _label(clock, "")
	declaration = _label(layout, "Essential session | Prebuilt: 12 ordinary people, 2500 requisition, no starting goods.")
	declaration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(split)
	base_map = Map.new()
	base_map.simulation = simulation
	base_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_map.selected.connect(_select)
	split.add_child(base_map)
	tabs = TabContainer.new()
	tabs.custom_minimum_size.x = 400
	split.add_child(tabs)
	_orders_panel(_panel("Orders"))
	_staff_panel(_panel("Staff"))
	_haul_panel(_panel("Haul"))
	_production_panel(_panel("Work"))
	_inspect_panel(_panel("Info"))
	_training_panel(_panel("Train"))
	_vehicles_panel(_panel("Vehicles"))
	_dispatch_panel(_panel("Dispatch"))
	if OS.get_environment("TRENCHO_HQ_DIAGNOSTICS") == "1": _hq_panel(_panel("HQ Diagnostics"))
	feedback = _label(layout, "Buy resources and people in Orders; set actual staff in Staff; request physical routes in Haul; set output targets in Work.")
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Cancel consumed batch?"
	confirmation.min_size = Vector2i(620, 230)
	confirmation.confirmed.connect(func() -> void: _result(_pending_activity.confirm_recipe(_pending_token)); _load_production())
	confirmation.canceled.connect(func() -> void: _result(_pending_activity.decline_recipe(_pending_token)); _load_production())
	add_child(confirmation)
	_load_production()
	_load_store()
	_load_vehicle_people()
	_refresh()

func _process(delta: float) -> void:
	simulation.tick(delta)
	base_map.queue_redraw()
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.2:
		_refresh_elapsed = 0.0
		_refresh()

func _panel(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _spin(parent: Node, title: String, maximum: int, value: int = 0) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, title).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = maximum
	spin.step = 1
	spin.value = value
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
	_label(box, "Purchase kilograms (plus 20 per vehicle)")
	for code in Catalog.MATERIALS:
		cart[code] = _spin(box, code + " " + Catalog.MATERIALS[code].name + " @" + str(Catalog.MATERIALS[code].price), 55000)
	_button(box, "Buy resources", func() -> void:
		var request := {}
		for code in cart:
			if cart[code].value > 0: request[code] = int(cart[code].value)
		_result(simulation.receiving.buy_resources(request)))
	_button(box, "Buy 8 people (140)", func() -> void: _result(simulation.receiving.buy_people()))
	recovery_button = _button(box,"Buy recovery instructor (120)",func() -> void: _result(simulation.receiving.buy_recovery_instructor()))
	recovery_status = _label(box,"")
	recovery_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orders = _list(box, 150)
	orders.item_selected.connect(func(index: int) -> void: _select("order", _order_ids[index], false))
	_button(box, "Cancel selected undispatched order", func() -> void:
		if not orders.get_selected_items().is_empty(): _result(simulation.receiving.cancel_order(_order_ids[orders.get_selected_items()[0]])))

	_label(box, "New session resets the base; inspection never does.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scenario = _option(box, "Access at session creation", ["Essential recipes", "Expanded production catalogue"])
	_button(box, "Start new session", _start_session)

func _start_session() -> void:
	simulation = Simulation.new(scenario.selected == 1)
	base_map.simulation = simulation
	base_map.reset_camera()
	_pending_activity = null
	_pending_token = -1
	for spin in cart.values(): spin.value = 0
	for spin in targets.values(): spin.value = 0
	instructor_count.set_value_no_signal(0)
	training_access.set_pressed_no_signal(true)
	_load_courses()
	facility.select(0)
	_selected_kind = "building"
	_selected_id = "terminal"
	_load_production()
	_load_store()
	declaration.text = ("Expanded production catalogue" if simulation.expanded_catalogue else "Essential session") + " | Prebuilt: 12 ordinary people, 2500 requisition, no starting goods."
	_result({"ok": true, "message": "New paused session. Recipe access was declared at creation; actual cards remain separate."})

func _staff_panel(box: VBoxContainer) -> void:
	_label(box, "Count targets share the same real people")
	for duty in ["receiving", "hauling", "workshop", "munitions", "materials", "support", "vehicle_works", "dispatch", "training"]:
		var spin := _spin(box, duty.capitalize(), simulation.rear.requests[duty].positions)
		targets[duty] = spin
		spin.value_changed.connect(func(value: float) -> void: _result(simulation.rear.set_target(duty, int(value))))
	people = _list(box, 150)
	people.item_selected.connect(func(index: int) -> void: _select("entity", _person_ids[index], false))
	person_duty = _option(box, "Selected person's requested duty", ["Available", "receiving", "hauling", "workshop", "munitions", "materials", "support", "vehicle_works", "training"])
	_button(box, "Reassign selected person", func() -> void:
		if not people.get_selected_items().is_empty(): _result(simulation.rear.reassign_person(_person_ids[people.get_selected_items()[0]], person_duty.get_item_text(person_duty.selected))))

func _haul_panel(box: VBoxContainer) -> void:
	_label(box, "Orders wait for real loose source goods")
	source = _option(box, "Source", simulation.rear.stores.keys())
	destination = _option(box, "Destination", simulation.rear.stores.keys())
	destination.select(1)
	var category := _option(box, "Goods category", ["Materials", "Workshop output", "Munitions output", "Support output"])
	goods_type = _option(box, "Goods", [])
	category.item_selected.connect(_load_haul_goods)
	_load_haul_goods(0)
	haul_count = _spin(box, "Units", 10000, 1)
	_button(box, "Order haul", func() -> void: _result(simulation.rear.request_haul(source.get_item_text(source.selected), destination.get_item_text(destination.selected), goods_type.get_item_text(goods_type.selected), int(haul_count.value))))
	jobs = _list(box, 140)
	jobs.item_selected.connect(func(index: int) -> void: _select("job", _job_ids[index], false))
	_button(box, "Cancel selected haul", func() -> void:
		if not jobs.get_selected_items().is_empty(): _result(simulation.rear.cancel_job(_job_ids[jobs.get_selected_items()[0]])))

func _load_haul_goods(category: int) -> void:
	goods_type.clear()
	if category == 0:
		for id in ["M01", "M02", "M03", "M04", "M06", "M11", "M05", "M07", "M08", "M09", "M10"]: goods_type.add_item(id)
	else:
		var duty: String = ["", "workshop", "munitions", "support"][category]
		for spec in simulation.rear.production.RECIPES.values():
			if spec.duty == duty: goods_type.add_item(spec.output_type)

func _production_panel(box: VBoxContainer) -> void:
	facility = _option(box, "Facility", ["workshop", "munitions", "materials", "support", "vehicle_works", "training"])
	facility.item_selected.connect(func(_index: int) -> void: _load_production())
	recipe = _option(box, "Recipe / declared session access", [])
	_button(box, "Select recipe", _change_recipe)
	mode = _option(box, "Production mode", ["Stock target", "Continuous"])
	stock_target = _spin(box, "Minimum output units", 10000)
	_button(box, "Apply production order", func() -> void:
		var activity := _activity()
		activity.set_stock_target(int(stock_target.value))
		_result(activity.set_mode(mode.get_item_text(mode.selected))))
	_button(box, "Pause / resume facility", func() -> void: _result(_activity().set_paused(not _activity().paused)))
	_button(box, "Cancel consumed batch / stop", func() -> void: _result(_activity().cancel()))
	_button(box, "Enable facility", func() -> void: _result(_activity().resume()))
	heavy_controls = VBoxContainer.new()
	box.add_child(heavy_controls)
	_label(heavy_controls,"Heavy targets request goods; acceptance reserves the bay/fleet place.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(heavy_controls,"Accept heavy order",func() -> void: _result(simulation.rear.heavy_production.accept_order()))
	bay_access = CheckBox.new()
	bay_access.text = "F10 bay accessible"
	heavy_controls.add_child(bay_access)
	parking_access = CheckBox.new()
	parking_access.text = "Parking route accessible"
	heavy_controls.add_child(parking_access)
	_button(heavy_controls,"Apply heavy access",func() -> void: _result(simulation.rear.heavy_production.set_access(bay_access.button_pressed,parking_access.button_pressed)))
	parking_destination = _option(heavy_controls,"Requested parking destination",["F11 place 1","F11 place 2","F11 place 3","F11 place 4"])
	_button(heavy_controls,"Change promised parking",func() -> void: _result(simulation.rear.heavy_production.set_parking_destination(parking_destination.selected)))
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

func _training_panel(box: VBoxContainer) -> void:
	_label(box,"F06: two instructors, twelve students").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructor_count = _spin(box,"Instructor target",2)
	instructor_count.value_changed.connect(func(value: float) -> void:
		targets.training.set_value_no_signal(value)
		_result(simulation.rear.set_target("training",int(value))))
	targets.training.value_changed.connect(func(value: float) -> void: instructor_count.set_value_no_signal(value))
	training_course = _option(box,"Course / declared recipe access",[])
	training_count = _spin(box,"Requested students",12,1)
	_button(box,"Request course",func() -> void: _result(simulation.rear.training.request_course(training_course.get_item_metadata(training_course.selected),int(training_count.value))))
	training_rows = _list(box,150)
	training_rows.item_selected.connect(func(index: int) -> void:
		_selected_kind = "course"
		_selected_id = training_ids[index]
		_refresh())
	_button(box,"Withdraw selected course",func() -> void:
		if not training_rows.get_selected_items().is_empty(): _result(simulation.rear.training.withdraw(training_ids[training_rows.get_selected_items()[0]])))
	training_access = CheckBox.new()
	training_access.text = "Training facility accessible"
	training_access.button_pressed = true
	box.add_child(training_access)
	training_access.toggled.connect(func(value: bool) -> void: _result(simulation.rear.training.set_access(value)))
	training_status = _label(box,"")
	training_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_courses()

func _vehicles_panel(box: VBoxContainer) -> void:
	_label(box,"F10 produced hulls retain their identity through crew, fuel and F11 parking.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vehicle_rows = _list(box,140)
	vehicle_rows.item_selected.connect(func(_index: int) -> void: _load_vehicle_stations(); _refresh())
	vehicle_person = _option(box,"Actual rear person",[])
	vehicle_station = _option(box,"Distinct crew station",[])
	_button(box,"Report and board selected station",func() -> void:
		if not vehicle_rows.get_selected_items().is_empty() and vehicle_person.selected >= 0 and vehicle_station.selected >= 0:
			_result(simulation.rear.vehicles.assign_station(_vehicle_id(),vehicle_person.get_item_metadata(vehicle_person.selected),vehicle_station.get_item_text(vehicle_station.selected))))
	_button(box,"Extract selected station occupant",func() -> void:
		if vehicle_person.selected >= 0: _result(simulation.rear.reassign_person(vehicle_person.get_item_metadata(vehicle_person.selected),"Available")))
	vehicle_fuel_units = _spin(box,"Whole M08 units (up to 25 per carry)",25,1)
	_button(box,"Carry purchased fuel into this tank",func() -> void:
		if not vehicle_rows.get_selected_items().is_empty() and vehicle_person.selected >= 0:
			_result(simulation.rear.vehicles.request_refuel(_vehicle_id(),vehicle_person.get_item_metadata(vehicle_person.selected),int(vehicle_fuel_units.value))))
	_button(box,"Drive SAME F10 hull to promised F11 place",func() -> void:
		if not vehicle_rows.get_selected_items().is_empty(): _result(simulation.rear.vehicles.start_drive(_vehicle_id())))
	vehicle_status = _label(box,"")
	vehicle_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _dispatch_panel(box: VBoxContainer) -> void:
	_label(box,"G12/G13 | Accept one actual parked produced hull. Passenger seats exclude crew; Strategic returns hull/crew, Fleet permanently transfers them at HQ. Preview the full route against tank fuel before departure.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dispatch_hull = _option(box,"Same F10-produced parked hull",[])
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
		_refresh())
	_button(box,"Clear requested cargo lines",func() -> void: dispatch_draft.clear(); _refresh())
	_button(box,"Accept named manifest and claims",func() -> void:
		if dispatch_hull.selected < 0: _result({"ok":false,"message":"Select an actual parked produced hull."}); return
		var passengers: Array = []
		for index in dispatch_people.get_selected_items(): passengers.append(dispatch_person_ids[index])
		var guns: Array = []
		if dispatch_gun.selected > 0: guns.append(dispatch_gun.get_item_metadata(dispatch_gun.selected))
		_result(simulation.rear.dispatch.accept(dispatch_hull.get_item_metadata(dispatch_hull.selected),dispatch_mode.get_item_text(dispatch_mode.selected),passengers,dispatch_draft,guns))
		_refresh())
	_label(box,"Accepted manifests | requested, reserved, staged, onboard, arrived and unloaded use the same physical IDs.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dispatch_rows = _list(box,110)
	dispatch_rows.item_selected.connect(func(_index: int) -> void: _refresh())
	_button(box,"Depart complete selected manifest",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty(): _result(simulation.rear.dispatch.depart(dispatch_ids[dispatch_rows.get_selected_items()[0]])))
	_button(box,"Preview measured route and gross load",func() -> void:
		if not dispatch_rows.get_selected_items().is_empty():
			var plan: Dictionary = simulation.rear.dispatch.route_preview(dispatch_ids[dispatch_rows.get_selected_items()[0]],_dispatch_profile())
			_result({"ok":plan.ok,"message":("%.1f m, %.1f s, %.2f travel fuel, %.2f required with reserve, %.2f in tank, gross %.1f kg" % [plan.distance,plan.seconds,plan.fuel,plan.required_fuel,plan.tank_fuel,plan.gross_kg]) if plan.ok else plan.message}))
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
	if vehicle_person == null: return
	var selected: String = str(vehicle_person.get_item_metadata(vehicle_person.selected)) if vehicle_person.selected >= 0 else ""
	var ids: Array[String] = []
	for p in simulation.rear.snapshot().people:
		if p.owner == "army-blue": ids.append(p.id)
	if vehicle_person.item_count == ids.size():
		var same := true
		for index in ids.size():
			if vehicle_person.get_item_metadata(index) != ids[index]: same = false
		if same: return
	vehicle_person.clear()
	for id in ids:
		var p: Dictionary = simulation.rear.ledger.inspect_entity(id)
		vehicle_person.add_item(id + " / " + p.design_type)
		vehicle_person.set_item_metadata(vehicle_person.item_count-1,id)
		if id == selected: vehicle_person.select(vehicle_person.item_count-1)
	if vehicle_person.selected < 0 and vehicle_person.item_count > 0: vehicle_person.select(0)

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
	return [simulation.rear.production, simulation.rear.munitions_production, simulation.rear.materials_production, simulation.rear.support_production, simulation.rear.heavy_production][facility.selected]

func _load_production() -> void:
	var activity := _activity()
	heavy_controls.visible = activity == simulation.rear.heavy_production
	bay_access.button_pressed = simulation.rear.heavy_production.bay_accessible
	parking_access.button_pressed = simulation.rear.heavy_production.parking_accessible
	mode.select(0 if activity.mode == "Stock target" else 1)
	stock_target.value = activity.stock_target
	var view: Dictionary = activity.snapshot()
	var choices: Array = view.get("recipe_choices", [view.recipe])
	recipe.clear()
	for id in choices:
		var spec: Dictionary = activity.RECIPES[id]
		var allowed: bool = activity.recipe_accessible(id) if activity.has_method("recipe_accessible") else true
		recipe.add_item(id + " / " + spec.output_type + ("" if allowed else " (locked)"))
		recipe.set_item_metadata(recipe.item_count - 1, id)
		recipe.set_item_disabled(recipe.item_count - 1, not allowed)
		if id == view.recipe: recipe.select(recipe.item_count - 1)

func _load_store() -> void:
	var entry: Dictionary = simulation.rear.stores[store.get_item_text(store.selected)]
	capacity.value = entry.capacity
	accessible.button_pressed = entry.accessible

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
	if feedback != null: feedback.text = result.get("message", str(result))
	if is_node_ready(): _refresh()

func _select(kind: String, id: String, open_panel: bool = true) -> void:
	_selected_kind = kind
	_selected_id = id
	if kind == "building":
		var store_id := "vehicle_input" if id == "vehicle_works" else (id if simulation.rear.stores.has(id) else id + "_input")
		var index: int = simulation.rear.stores.keys().find(store_id)
		if index >= 0:
			store.select(index)
			_load_store()
	if open_panel: tabs.current_tab = 4
	_refresh()

func _fill(list: ItemList, ids: Array[String], entries: Array, make_text: Callable) -> void:
	var selected := ids[list.get_selected_items()[0]] if not list.get_selected_items().is_empty() else ""
	list.clear()
	ids.clear()
	for entry in entries:
		ids.append(entry.id)
		var summary: String = make_text.call(entry)
		list.add_item(summary)
		list.set_item_tooltip(ids.size() - 1, summary)
		if entry.id == selected: list.select(ids.size() - 1)

func _refresh_dispatch_choices(view: Dictionary) -> void:
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
	var gun: String = view.heavy.bay.occupant
	if gun.is_empty() or simulation.rear.ledger.inspect_entity(gun).design_type != "E13": gun = ""
	var chosen_gun: String = str(dispatch_gun.get_item_metadata(dispatch_gun.selected)) if dispatch_gun.selected > 0 else ""
	if dispatch_gun.item_count != (2 if not gun.is_empty() else 1) or (not gun.is_empty() and dispatch_gun.get_item_metadata(1) != gun):
		dispatch_gun.clear()
		dispatch_gun.add_item("No field gun")
		if not gun.is_empty():
			dispatch_gun.add_item(gun+" at F10")
			dispatch_gun.set_item_metadata(1,gun)
			if chosen_gun == gun: dispatch_gun.select(1)
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

func _refresh_dispatch(view: Dictionary) -> void:
	_refresh_dispatch_choices(view)
	_fill(dispatch_rows,dispatch_ids,view.dispatch.rows,func(row: Dictionary) -> String: return "%s | %s | %s %s | %s" % [row.id,row.mode,row.hull,row.state,row.blocker])
	if dispatch_rows.get_selected_items().is_empty() and dispatch_rows.item_count > 0: dispatch_rows.select(dispatch_rows.item_count-1)
	dispatch_status.text = "Draft cargo %s\nMilitary: %d members + %d incoming / 384; hulls %d + %d / 24\nRear return places %d | HQ Reserve %d/96, stock %.1f/20000 kg\nHQ local available %s | reserved %s" % [str(dispatch_draft),view.dispatch.military_people,view.dispatch.incoming_people,view.dispatch.military_hulls,view.dispatch.incoming_hulls,view.dispatch.return_places,view.dispatch.hq_reserve,view.dispatch.hq_stock_kg,str(view.hq.available),str(view.hq.reserved)]
	dispatch_status.text += "\nHQ intact weapons %s | promised %s\nHQ command: %s" % [str(view.hq.weapons_available),str(view.hq.weapons_promised),str(view.hq.auto_status)]
	for job in view.hq.rows:
		if job.state not in ["Complete","Cancelled"]: dispatch_status.text += "\nHQ %s %s: %d/%d %s | %s" % [job.kind,job.target,job.issued,job.requested,job.state,job.blocker]
	if dispatch_rows.get_selected_items().is_empty(): return
	var id: String = dispatch_ids[dispatch_rows.get_selected_items()[0]]
	for row in view.dispatch.rows:
		if row.id != id: continue
		dispatch_status.text += "\n%s %s | same %s at %s | fuel %.2f | driver %s | crew %s\nPassengers %s | guns %s | payload %.1f/%.1f kg; seats %d/%d\nRequested %s\nCommitted %s\nStaged %s\nOnboard %s\nArrived %s\nUnloaded %s\nHandling %s; route %.1f/%.1f m\nBlocked: %s" % [row.id,row.state,row.hull,str(row.hull_physical.position),row.hull_physical.fuel,row.driver,str(row.crew),str(row.passengers),str(row.guns),row.payload_used,row.hull_physical.vehicle_spec.payload,row.seats_used,row.hull_physical.vehicle_spec.passenger_seats,str(row.requested),str(row.committed),str(row.staged),str(row.onboard),str(row.arrived),str(row.unloaded),str(row.task.get("phase","idle")),row.distance,row.route_length,row.blocker]
		var planned: Dictionary = row.get("full_route_plan",{})
		if planned.get("ok",false): dispatch_status.text += "\nG13 last plan %.1f m / %.1f s; fuel %.2f + 25%% = %.2f needed; gross %.1f kg; %s" % [planned.distance,planned.seconds,planned.fuel,planned.required_fuel,planned.gross_kg,str(planned.profile)]
		break

func _refresh() -> void:
	if orders == null: return
	var view: Dictionary = simulation.snapshot()
	_refresh_dispatch(view)
	_refresh_hq(view)
	var offer: Dictionary = view.receiving.recovery_offer
	recovery_button.visible = offer.available
	recovery_status.text = offer.message
	var training: Dictionary = view.training
	_fill(training_rows,training_ids,training.rows,func(row: Dictionary) -> String: return "%s %s %s | %s %.1f/%.0fs" % [row.id,row.course,row.person_id,row.state,row.work,row.required])
	training_status.text = "Instructors %d/%d requested; coverage %d students\nStudent places %d/12 | active %d, paused %d, reporting %d, queued %d\n" % [training.instructors.size(),training.instructor_target,training.coverage,training.reserved_student_places,training.counts.Active,training.counts.Paused,training.counts.Reporting,training.counts.Queued]
	if training.instructors.is_empty(): training_status.text += "Missing actual instructor: purchase recovery P01 if none remain, then assign and wait for reporting.\n"
	for row in training.rows:
		if row.id == _selected_id:
			training_status.text += "%s / %s: %s\nElapsed %.1f/%.0f seconds; %s" % [row.course,row.person_id,row.state,row.work,row.required,row.reason]
			if not row.person_id.is_empty():
				var person: Dictionary = simulation.rear.ledger.inspect_entity(row.person_id)
				training_status.text += "\nBasic completed: %s; specialist: %s\nActual position %s; duty %s" % [str(person.basic_training),person.qualification,str(person.position),person.duty_id if not person.duty_id.is_empty() else person.assignment]
	status.text = "  %.1fs | %.0f req | %d rear + %d incoming" % [simulation.rear.time, view.receiving.money, simulation.receiving.rear_population(), simulation.receiving.incoming_people()]
	_fill(orders, _order_ids, view.receiving.orders, func(o: Dictionary) -> String: return o.id + " " + o.state + " | " + o.blocked_reason)
	var actual_people: Array = view.rear.people.filter(func(p: Dictionary) -> bool: return p.owner == "army-blue")
	_fill(people, _person_ids, actual_people, func(p: Dictionary) -> String: return p.id + " | " + (p.duty_id if not p.duty_id.is_empty() else p.assignment) + " | " + p.phase)
	_load_vehicle_people()
	_fill(vehicle_rows,vehicle_ids,view.vehicles.rows,func(row: Dictionary) -> String: return "%s %s | %s | fuel %.1f/%.0f | F11 %d" % [row.id,row.hull.design_type,row.state,row.hull.fuel,row.hull.vehicle_spec.tank_capacity,row.slot+1])
	if vehicle_rows.get_selected_items().is_empty() and vehicle_rows.item_count > 0:
		vehicle_rows.select(0)
		_load_vehicle_stations()
	vehicle_status.text = "No F10-produced hull yet. Manufacture R25/R28 or expanded T03–T05, then use actual trained people and purchased M08."
	for row in view.vehicles.rows:
		if row.id != _vehicle_id(): continue
		vehicle_status.text = "%s %s at %s | %s | distance %.1f/%.1fm | fuel burned %.3f\nStations %s; missing %s\nDriver-only Fleet Transfer crew %s; motion %s; combat crew %s; main-fire stations %s; matching rack ammo %d; combat ready %s\nFuel carries %s; rear fleet remains %d live/%d reserved. Actual HQ transfer and firing are later systems." % [row.id,row.hull.design_type,str(row.hull.position),row.state,row.distance,row.length,row.burned,str(row.hull.crew_by_station),str(row.readiness.missing_stations),str(row.readiness.transfer_crew_eligible),str(row.readiness.motion_ready),str(row.readiness.combat_crew_ready),str(row.readiness.main_fire_stations_ready),row.readiness.matching_ammo,str(row.readiness.combat_ready),str(row.fuel_claims),view.heavy.fleet.live,view.heavy.fleet.reserved]
	_fill(jobs, _job_ids, view.rear.jobs, func(j: Dictionary) -> String: return "%s %s %d/%d | %s" % [j.id, j.type, j.delivered, j.requested, ("Missing hauling staff" if j.delivered < j.requested and simulation.rear._assigned("hauling") == 0 else j.blocker)])
	var lines: Array[String] = []
	for activity in [view.production, view.munitions, view.materials, view.support]:
		lines.append("%s %s -> %s: %s\nLocal %s; missing %s\nWork %.1f/%.0f; output %d; promised %.1f kg" % [activity.facility, activity.recipe, activity.output_type, activity.status, str(activity.local_inputs), str(activity.missing_local), activity.batch.get("work", 0.0), activity.required_work, activity.physical_output, activity.output_promise.get("mass", 0.0)])
	production_status.text = "\n\n".join(lines)
	var heavy: Dictionary = view.heavy
	heavy_status.text = "%s -> %s: %s\nRear fleet: %d live + %d reserved / 8\nBay: %s\nOrder: %s; work %.1f/%.0f\n%s" % [heavy.recipe,heavy.output_type,heavy.status,heavy.fleet.live,heavy.fleet.reserved,heavy.bay.occupant if not heavy.bay.occupant.is_empty() else ("one accepted promise" if not heavy.order.is_empty() else "empty"),heavy.order.get("id","unaccepted"),heavy.batch.get("work",0.0),heavy.required_work,heavy.bay.clearance]
	if heavy.bay.parking_slot >= 0:
		heavy_status.text += "\nReserved destination: F11 place %d %s" % [heavy.bay.parking_slot+1,str(heavy.bay.parking_position)]
	else: heavy_status.text += "\nDestination: F10 heavy collection bay"
	if not heavy.bay.physical.is_empty():
		var object: Dictionary = heavy.bay.physical
		heavy_status.text += "\n%s: %.0f kg; fuel %.0f; %d crew, %d passengers; no ammunition" % [object.design_type,object.unit_mass_kg,object.get("fuel",0.0),object.get("crew",[]).size(),object.get("passengers",[]).size()]
	var info := _selected_kind + ": " + _selected_id + "\n"
	match _selected_kind:
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
