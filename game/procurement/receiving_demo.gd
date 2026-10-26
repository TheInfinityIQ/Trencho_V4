extends Control
## A bounded Terminal/Receiving UI with explicit simulation-time controls.

const Simulation = preload("res://game/procurement/receiving_simulation.gd")
const Catalog = preload("res://game/procurement/resource_catalog.gd")

var _simulation := Simulation.new()
var _material_codes: Array = Catalog.MATERIALS.keys()
var _material: OptionButton
var _quantity: SpinBox
var _quote: Label
var _summary: Label
var _status: Label
var _audit: Label
var _resources: Tree
var _deliveries: Tree
var _people: Tree
var _detail: Label
var _selected_order: String
var _view: Dictionary
var _refreshing := false


func _ready() -> void:
	_build_ui()
	_result({"ok": true, "message": "Zero-worker recovery fixture. Start with a resource purchase, then order eight people to restore Receiving labour."})


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("121b27")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	_label(layout, "Trencho V4  /  Terminal & Receiving", 27)
	_label(layout, "G02 review fixture · real identities, timed supply and handling · predefined rear access · general staffing/production remain later systems.", 14)
	_summary = _label(layout, "", 16)
	_summary.custom_minimum_size.y = 42
	var controls := HBoxContainer.new()
	layout.add_child(controls)
	for seconds in [1, 10, 60, 300]:
		_button(controls, "+%ds" % seconds, func() -> Dictionary: return _simulation.advance_time(seconds))
	_button(controls, "Reset (zero workers)", _reset)
	_button(controls, "A58: fill freight queue", _prepare_a58)
	_status = _label(layout, "", 16)
	_status.custom_minimum_size.y = 38
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	_build_terminal(_tab(tabs, "Terminal"))
	_build_deliveries(_tab(tabs, "Deliveries"))
	_build_people(_tab(tabs, "People & labour"))
	_audit = _label(layout, "", 14)
	_label(layout, "Admission is released on valid cancellation or physical vehicle clearance. Cargo ownership never substitutes for arrival, unloading or people disembarking.", 13)


func _build_terminal(page: VBoxContainer) -> void:
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	page.add_child(columns)
	var purchase := VBoxContainer.new()
	purchase.custom_minimum_size.x = 390
	purchase.add_theme_constant_override("separation", 8)
	columns.add_child(purchase)
	_label(purchase, "Purchase resources", 21)
	_material = OptionButton.new()
	_material.custom_minimum_size.y = 34
	for code in _material_codes:
		_material.add_item("%s %s · %d/kg" % [code, Catalog.MATERIALS[code].name, Catalog.MATERIALS[code].price])
	_material.item_selected.connect(func(_index: int) -> void: _refresh_quote())
	purchase.add_child(_material)
	var quantity_row := HBoxContainer.new()
	purchase.add_child(quantity_row)
	var quantity_label := _label(quantity_row, "Whole kg:", 16)
	quantity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_quantity = SpinBox.new()
	_quantity.min_value = 1
	_quantity.max_value = 55000
	_quantity.step = 1
	_quantity.rounded = true
	_quantity.value = 100
	_quantity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quantity.value_changed.connect(func(_value: float) -> void: _refresh_quote())
	quantity_row.add_child(_quantity)
	_quote = _scroll_label(purchase, 80)
	_button(purchase, "Purchase quoted goods", func() -> Dictionary: return _simulation.buy_resources(_cart()), true)
	_button(purchase, "Order 8 P00 · 120 + 20", func() -> Dictionary: return _simulation.buy_people(), true)
	_label(purchase, "M06 Explosives and M11 Building Materials must be manufactured. Each external resource truck carries 1–5,000 kg and costs its own 20 fee.", 14)
	var holdings := VBoxContainer.new()
	holdings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(holdings)
	_label(holdings, "Purchase → physical local stock", 21)
	_resources = _tree(holdings, ["Resource", "Bought", "Ordered", "Travel", "Aboard", "Carry", "Deposited", "Free"])
	_label(holdings, "Purchased = ordered + travelling + aboard + carried + deposited. Free means actually deposited and unreserved at F02. Columns retain real quantities during partial delivery.", 14)


func _build_deliveries(page: VBoxContainer) -> void:
	_deliveries = _tree(page, ["Delivery", "Kind", "State", "Cost", "Reserved", "Arrived people"])
	_deliveries.item_selected.connect(_select_delivery)
	_detail = _scroll_label(page, 100)
	_button(page, "Cancel selected (first 5 seconds)", func() -> Dictionary: return _simulation.cancel_order(_selected_order))
	_label(page, "Eleven unfinished freight services share one berth + ten waiting places. Two unfinished personnel services use independent pull-offs. Clearing vehicles still hold admission.", 14)


func _build_people(page: VBoxContainer) -> void:
	var controls := HBoxContainer.new()
	page.add_child(controls)
	_button(controls, "Assign 1 available person", func() -> Dictionary: return _simulation.assign_unloaders(1))
	_button(controls, "Assign 4 available people", func() -> Dictionary: return _simulation.assign_unloaders(4))
	_button(controls, "Release Receiving duty", func() -> Dictionary: return _simulation.release_unloaders())
	_people = _tree(page, ["Person", "Owner", "Duty", "Phase", "Position (m)", "Pending"])
	_label(page, "Supplier drivers remain external P08. Incoming P00 walk into Personnel and become player people only on completed disembarkation. Receiving uses actual available people, with no staff-count shortcut.", 14)


func _reset() -> Dictionary:
	_simulation = Simulation.new()
	_selected_order = ""
	return {"ok": true, "message": "Reset to 2,500 requisition and zero rear workers. No goods or personnel are supplied for free."}


func _prepare_a58() -> Dictionary:
	_reset()
	for index in range(11):
		var purchased := _simulation.buy_resources({"M03": 1})
		if not purchased.ok:
			return purchased
	_simulation.advance_time(63.0)
	return {"ok": true, "message": "A58 setup processed 11 real one-kg purchases and 63 seconds: one blocked freight berth, ten waiting, zero workers. Personnel access remains independent."}


func _cart() -> Dictionary:
	return {_material_codes[_material.selected]: int(_quantity.value)}


func _refresh_quote() -> void:
	if _quote == null or _quantity == null:
		return
	var quote := _simulation.quote_resources(_cart())
	if not quote.ok:
		_quote.text = quote.message
		return
	var lines: Array[String] = ["Quote: %d kg · %d vehicle(s) · total %d" % [quote.mass_kg, quote.vehicle_count, quote.cost]]
	for index in range(quote.vehicles.size()):
		var vehicle: Dictionary = quote.vehicles[index]
		lines.append("Truck %d: %d kg · goods %d + fee %d = %d" % [index + 1, vehicle.mass_kg, vehicle.goods_cost, vehicle.fee, vehicle.cost])
	lines.append("Free freight commitments: %d / 11" % quote.free_vehicle_places)
	if not quote.can_commit:
		lines.append("Blocked by available money or delivery admission; commit will revalidate.")
	_quote.text = "\n".join(lines)


func _result(result: Dictionary) -> void:
	_status.text = result.message
	_status.modulate = Color("8ee4ba") if result.ok else Color("ffcf91")
	if result.get("ok", false) and not result.get("ids", []).is_empty():
		_selected_order = result.ids[0]
	_refresh()


func _refresh() -> void:
	_refreshing = true
	_view = _simulation.snapshot()
	_summary.text = "t=%.3fs · Requisition %.2f · income +%.2f · spent %d · refunded %d\nRear people %d + incoming reserved %d / 120 · Freight %d / 11 · Personnel %d / 2 · F02 %d + reserved %d / 5000 kg · Receiving assignments %d / 4" % [
		_view.time, _view.money, _view.income, _view.spent, _view.refunds,
		_simulation.rear_population(), _simulation.incoming_people(), _simulation.freight_admitted(),
		_simulation.personnel_admitted(), _simulation.receiving_kg(), _simulation.reserved_storage_kg(), _view.workers.size()]
	_refresh_quote()
	_resources.clear()
	var root := _resources.create_item()
	for code in _material_codes:
		var counts := _simulation.resource_counts(code)
		var row := _resources.create_item(root)
		row.set_text(0, "%s %s" % [code, Catalog.MATERIALS[code].name])
		var values := [counts.purchased, counts.ordered, counts.incoming, counts.onboard, counts.carried, counts.unloaded, counts.available]
		for column in range(values.size()):
			row.set_text(column + 1, str(values[column]))
		for column in range(8):
			row.set_tooltip_text(column, "Total purchased: %d kg\nActual G01 holdings reconcile across carriers, workers and storage." % counts.purchased)
	_deliveries.clear()
	root = _deliveries.create_item()
	for order in _view.orders:
		var row := _deliveries.create_item(root)
		row.set_metadata(0, order.id)
		var values: Array = [order.id, order.kind, order.state, order.cost,
			"Yes" if order.admission else "Released", order.people_arrived]
		for column in range(values.size()):
			row.set_text(column, str(values[column]))
			row.set_tooltip_text(column, order.blocked_reason)
		if order.id == _selected_order:
			row.select(0)
	_people.clear()
	root = _people.create_item()
	for person in _view.ledger.entities:
		if person.kind != "PERSON":
			continue
		var row := _people.create_item(root)
		var phase := "External service" if person.owner == Simulation.SUPPLIER else "Available"
		if person.assignment == "Passenger":
			phase = "Walking to Personnel" if person.holder_id == "rear-lane" else "Passenger aboard"
		if _view.workers.has(person.id):
			phase = _view.workers[person.id].job.get("phase", "Waiting for freight")
		var values: Array = [person.id, person.owner, person.assignment, phase, person.position, person.pending_assignment]
		for column in range(values.size()):
			row.set_text(column, str(values[column]))
			row.set_tooltip_text(column, "Holder: %s\nOwner/control: %s / %s\nQualification: %s\nCarry: %s\nDuty: %s" % [person.holder_id, person.owner, person.controller, person.qualification, person.carrying_stock_id, person.duty_id])
	_update_detail()
	var failures := _simulation.audit()
	_audit.text = "Conservation PASS · money, people, physical goods, reservations and vehicle admission reconcile." if failures.is_empty() else "INVARIANT FAILURE: " + "; ".join(failures)
	_audit.modulate = Color("8ee4ba") if failures.is_empty() else Color("ffb0a8")
	_refreshing = false


func _select_delivery() -> void:
	if _refreshing:
		return
	var selected := _deliveries.get_selected()
	if selected != null:
		_selected_order = str(selected.get_metadata(0))
	_update_detail()


func _update_detail() -> void:
	_detail.text = "Select a delivery to inspect its identity, timing, reservations and exact blocking reason."
	for order in _view.orders:
		if order.id != _selected_order:
			continue
		var location := "Not dispatched"
		var entity := _simulation.ledger.inspect_entity(order.id)
		if not entity.is_empty():
			location = "%s at %s m; carrier owner/control %s / %s" % [entity.holder_id, entity.position, entity.owner, entity.controller]
		_detail.text = "%s · %s · %s\nPurchased t=%.3f · dispatch t=%.3f · arrival t=%.3f · next transition %s\nCost %d · admission %s · incoming people reserved %d · exited %d · arrived at F08 %d\n%s\nCargo purchased %s · actually deposited %s\nCause: %s" % [
			order.id, order.kind, order.state, order.purchased_at, order.purchased_at + 5,
			order.arrival_at, str(order.next_at), order.cost, order.admission,
			order.people_reserved, order.people_exited, order.people_arrived, location, str(order.cargo), str(order.unloaded), order.blocked_reason]


func _tree(parent: Node, titles: Array) -> Tree:
	var tree := Tree.new()
	tree.columns = titles.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = 180
	tree.add_theme_font_size_override("font_size", 14)
	for column in range(titles.size()):
		tree.set_column_title(column, titles[column])
		tree.set_column_custom_minimum_width(column, 145 if column == 0 else 78)
	parent.add_child(tree)
	return tree


func _scroll_label(parent: Node, minimum_height: int) -> Label:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = minimum_height
	parent.add_child(scroll)
	var label := _label(scroll, "", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable, expand: bool = false) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_END
	button.pressed.connect(func() -> void: _result(action.call()))
	parent.add_child(button)


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	tabs.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)
	return page
