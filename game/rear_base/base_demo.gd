extends Control
## One live scene, persistent panels, physical map and player commands.
const Simulation = preload("res://game/rear_base/base_simulation.gd")
const Map = preload("res://game/rear_base/base_map.gd")
const Catalog = preload("res://game/procurement/resource_catalog.gd")
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
var _pending_token: int = -1
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
	var declaration := _label(layout, "Prebuilt integration scenario: 12 ordinary people, 2500 requisition, no starting recipe goods. Construction/training/world remain separate.")
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
	tabs.custom_minimum_size.x = 350
	split.add_child(tabs)
	_orders_panel(_panel("Orders"))
	_staff_panel(_panel("Staff"))
	_haul_panel(_panel("Haul"))
	_production_panel(_panel("Production"))
	_inspect_panel(_panel("Inspect"))
	feedback = _label(layout, "Buy resources and people in Orders; set actual staff in Staff; request physical routes in Haul; set output targets in Production.")
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Cancel consumed batch?"
	confirmation.min_size = Vector2i(620, 230)
	confirmation.confirmed.connect(func() -> void: _result(simulation.rear.munitions_production.confirm_recipe(_pending_token)); _load_production())
	confirmation.canceled.connect(func() -> void: _result(simulation.rear.munitions_production.decline_recipe(_pending_token)); _load_production())
	add_child(confirmation)
	_load_production()
	_load_store()
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
	for code in ["M01", "M02", "M03", "M04"]:
		cart[code] = _spin(box, code + " " + Catalog.MATERIALS[code].name + " @" + str(Catalog.MATERIALS[code].price), 55000)
	_button(box, "Buy resources", func() -> void:
		var request := {}
		for code in cart:
			if cart[code].value > 0: request[code] = int(cart[code].value)
		_result(simulation.receiving.buy_resources(request)))
	_button(box, "Buy 8 people (140)", func() -> void: _result(simulation.receiving.buy_people()))
	orders = _list(box, 150)
	orders.item_selected.connect(func(index: int) -> void: _select("order", _order_ids[index], false))
	_button(box, "Cancel selected undispatched order", func() -> void:
		if not orders.get_selected_items().is_empty(): _result(simulation.receiving.cancel_order(_order_ids[orders.get_selected_items()[0]])))

func _staff_panel(box: VBoxContainer) -> void:
	_label(box, "Count targets share the same real people")
	for duty in ["receiving", "hauling", "workshop", "munitions", "materials"]:
		var spin := _spin(box, duty.capitalize(), simulation.rear.requests[duty].positions)
		targets[duty] = spin
		spin.value_changed.connect(func(value: float) -> void: _result(simulation.rear.set_target(duty, int(value))))
	people = _list(box, 150)
	people.item_selected.connect(func(index: int) -> void: _select("entity", _person_ids[index], false))
	person_duty = _option(box, "Selected person's requested duty", ["Available", "receiving", "hauling", "workshop", "munitions", "materials"])
	_button(box, "Reassign selected person", func() -> void:
		if not people.get_selected_items().is_empty(): _result(simulation.rear.reassign_person(_person_ids[people.get_selected_items()[0]], person_duty.get_item_text(person_duty.selected))))

func _haul_panel(box: VBoxContainer) -> void:
	_label(box, "Orders wait for real loose source goods")
	source = _option(box, "Source", simulation.rear.stores.keys())
	destination = _option(box, "Destination", simulation.rear.stores.keys())
	destination.select(1)
	goods_type = _option(box, "Goods", ["M01", "M02", "M03", "M04", "M06", "M11", "E01", "E02", "E25", "E26"])
	haul_count = _spin(box, "Units", 10000, 1)
	_button(box, "Order haul", func() -> void: _result(simulation.rear.request_haul(source.get_item_text(source.selected), destination.get_item_text(destination.selected), goods_type.get_item_text(goods_type.selected), int(haul_count.value))))
	jobs = _list(box, 140)
	jobs.item_selected.connect(func(index: int) -> void: _select("job", _job_ids[index], false))
	_button(box, "Cancel selected haul", func() -> void:
		if not jobs.get_selected_items().is_empty(): _result(simulation.rear.cancel_job(_job_ids[jobs.get_selected_items()[0]])))

func _production_panel(box: VBoxContainer) -> void:
	facility = _option(box, "Facility", ["workshop", "munitions", "materials"])
	facility.item_selected.connect(func(_index: int) -> void: _load_production())
	recipe = _option(box, "F05 recipe (shell access requires a later scenario)", ["R02", "R27", "R32 (locked)", "R33 (locked)"])
	recipe.set_item_disabled(2, true)
	recipe.set_item_disabled(3, true)
	_button(box, "Select F05 recipe", _change_recipe)
	mode = _option(box, "Production mode", ["Stock target", "Continuous"])
	stock_target = _spin(box, "Minimum output units", 10000)
	_button(box, "Apply production order", func() -> void:
		var activity := _activity()
		activity.set_stock_target(int(stock_target.value))
		_result(activity.set_mode(mode.get_item_text(mode.selected))))
	_button(box, "Pause / resume facility", func() -> void: _result(_activity().set_paused(not _activity().paused)))
	_button(box, "Cancel consumed batch / stop", func() -> void: _result(_activity().cancel()))
	_button(box, "Enable facility", func() -> void: _result(_activity().resume()))
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

func _activity() -> RefCounted:
	return [simulation.rear.production, simulation.rear.munitions_production, simulation.rear.materials_production][facility.selected]

func _load_production() -> void:
	var activity := _activity()
	mode.select(0 if activity.mode == "Stock target" else 1)
	stock_target.value = activity.stock_target
	recipe.select(1 if simulation.rear.munitions_production.snapshot().recipe == "R27" else 0)

func _load_store() -> void:
	var entry: Dictionary = simulation.rear.stores[store.get_item_text(store.selected)]
	capacity.value = entry.capacity
	accessible.button_pressed = entry.accessible

func _change_recipe() -> void:
	var result: Dictionary = simulation.rear.munitions_production.request_recipe(["R02", "R27", "R32", "R33"][recipe.selected])
	if result.get("confirmation_required", false):
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
		var store_id := id if simulation.rear.stores.has(id) else id + "_input"
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
		list.add_item(make_text.call(entry))
		list.set_item_tooltip(ids.size() - 1, str(entry))
		if entry.id == selected: list.select(ids.size() - 1)

func _refresh() -> void:
	if orders == null: return
	var view: Dictionary = simulation.snapshot()
	status.text = "  %.1fs | %.0f req | %d rear + %d incoming" % [simulation.rear.time, view.receiving.money, simulation.receiving.rear_population(), simulation.receiving.incoming_people()]
	_fill(orders, _order_ids, view.receiving.orders, func(o: Dictionary) -> String: return o.id + " " + o.state + " | " + o.blocked_reason)
	var actual_people: Array = view.rear.people.filter(func(p: Dictionary) -> bool: return p.owner == "army-blue")
	_fill(people, _person_ids, actual_people, func(p: Dictionary) -> String: return p.id + " | " + (p.duty_id if not p.duty_id.is_empty() else p.assignment) + " | " + p.phase)
	_fill(jobs, _job_ids, view.rear.jobs, func(j: Dictionary) -> String: return "%s %s %d/%d | %s" % [j.id, j.type, j.delivered, j.requested, ("Missing hauling staff" if j.delivered < j.requested and simulation.rear._assigned("hauling") == 0 else j.blocker)])
	var lines: Array[String] = []
	for activity in [view.production, view.munitions, view.materials]:
		lines.append("%s %s: %s\nLocal %s; missing %s\nWork %.1f/%.0f; output %d; promised %.1f kg" % [activity.facility, activity.recipe, activity.status, str(activity.local_inputs), str(activity.missing_local), activity.batch.get("work", 0.0), activity.required_work, activity.physical_output, activity.output_promise.get("mass", 0.0)])
	production_status.text = "\n\n".join(lines)
	var info := _selected_kind + ": " + _selected_id + "\n"
	match _selected_kind:
		"entity":
			var p: Dictionary = simulation.rear.ledger.inspect_entity(_selected_id)
			info += "Owner: %s\nHolder: %s\nPosition: %s\nDuty: %s; pending: %s\nCarry: %s\n%s" % [p.get("owner", ""), p.get("holder_id", ""), str(p.get("position", "")), p.get("duty_id", "External supplier service"), p.get("pending_duty", ""), p.get("carrying_stock_id", ""), p.get("blocked_reason", "")]
		"building":
			if simulation.rear.requests.has(_selected_id):
				var r: Dictionary = simulation.rear.requests[_selected_id]
				info += "Staff target %d / %d positions; actual %d.\n" % [r.target, r.positions, simulation.rear._assigned(_selected_id)]
			for row in view.rear.stores:
				if row.id == _selected_id or row.id.begins_with(_selected_id + "_"):
					info += "%s: %.1f kg, free %.1f, inbound %.1f, output promise %.1f\n" % [row.id, row.physical_kg, row.free_kg, row.reserved_inbound_kg, row.reserved_output_kg]
					for stock in row.stocks: info += "%s %d (reserved %d)\n" % [stock.design_type, stock.quantity, stock.reserved]
		"job":
			for job in view.rear.jobs:
				if job.id == _selected_id: info += "%s -> %s: %s %d/%d; in flight %d\n%s" % [job.source, job.destination, job.type, job.delivered, job.requested, job.in_flight, job.blocker]
		"order":
			for order in view.receiving.orders:
				if order.id == _selected_id: info += "%s %s\nCargo %s\nUnloaded %s\n%s" % [order.kind, order.state, str(order.cargo), str(order.unloaded), order.blocked_reason]
	inspection.text = info
