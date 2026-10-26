extends Control
## Inspectable G03 rear fixture. Only explicit clock controls advance simulation.

const Simulation = preload("res://game/staffing/rear_simulation.gd")
var simulation := Simulation.new()
var _summary: Label
var _feedback: Label
var _audit: Label
var _readiness: Label
var _staff: Tree
var _people: Tree
var _jobs: Tree
var _stores: Tree
var _yard: Label
var _detail: Label
var _duty: OptionButton
var _target: SpinBox
var _priority: OptionButton
var _store_choice: OptionButton
var _filter: OptionButton
var _capacity: SpinBox
var _refreshing := false


func _ready() -> void:
	_build()
	_update("Declared small rear fixture: R01 input gate only. Full A05 production is G04.")


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("121b27")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)
	_label(layout, "Trencho V4 / Staffing & physical hauling", 25)
	_label(layout, "G03 bounded fixture · six local people, one away crew, one external driver, one owned starting T01 · separate review clocks", 13)
	_summary = _label(layout, "", 16)
	var scenarios := HBoxContainer.new()
	layout.add_child(scenarios)
	for fixture in ["A05", "Carry", "Driver"]:
		_button(scenarios, {"A05": "Reset A05 inputs", "Carry": "Reset A06 carry", "Driver": "Reset A06 driver"}[fixture], func() -> Dictionary:
			simulation = Simulation.new(fixture)
			return {"ok": true, "message": "Fresh declared " + fixture + " fixture; no runtime teleport or manufactured people implied."})
	for seconds in [1, 2, 10, 60, 300]:
		_button(scenarios, "+%ds" % seconds, func() -> Dictionary: return simulation.advance_time(seconds))
	_feedback = _label(layout, "", 15)
	_feedback.custom_minimum_size.y = 36
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	_build_staff(_page(tabs, "Staffing & inputs"))
	_build_people(_page(tabs, "People"))
	_build_jobs(_page(tabs, "Jobs"))
	_build_stores(_page(tabs, "Storage"))
	_build_yard(_page(tabs, "Yard"))
	_audit = _label(layout, "", 14)
	_label(layout, "Reserved ≠ carried ≠ deposited. A pending duty is not extra labour. Production, courses, construction, strategic transport and D01 remain separate.", 13)


func _build_staff(page: VBoxContainer) -> void:
	var controls := HBoxContainer.new()
	page.add_child(controls)
	_duty = OptionButton.new()
	for id in simulation.requests: _duty.add_item(id)
	controls.add_child(_duty)
	_duty.item_selected.connect(func(_index: int) -> void: _target.max_value = simulation.requests[_duty.get_item_text(_duty.selected)].positions)
	_target = SpinBox.new()
	_target.min_value = 0
	_target.max_value = 4
	_target.step = 1
	_target.custom_minimum_size.x = 100
	controls.add_child(_target)
	_priority = OptionButton.new()
	for name in Simulation.PRIORITIES: _priority.add_item(name)
	_priority.select(1)
	controls.add_child(_priority)
	_button(controls, "Apply target", func() -> Dictionary: return simulation.set_target(_duty.get_item_text(_duty.selected), int(_target.value), _priority.selected))
	_button(controls, "Hauling target 1", func() -> Dictionary: return simulation.set_target("hauling", 1))
	_button(controls, "Release haulers", func() -> Dictionary: return simulation.set_target("hauling", 0))
	_staff = _tree(page, ["Duty", "Target / positions", "Assigned", "Present", "Travel / active", "Shortage", "Priority"])
	_readiness = _label(page, "", 16)
	_readiness.custom_minimum_size.y = 65


func _build_people(page: VBoxContainer) -> void:
	var controls := HBoxContainer.new()
	page.add_child(controls)
	_button(controls, "Release haulers", func() -> Dictionary: return simulation.set_target("hauling", 0))
	_button(controls, "Block F04 input", func() -> Dictionary: return simulation.set_store("workshop_input", false))
	_button(controls, "No safe stores", _no_safe_stores)
	_button(controls, "Restore stores", _restore_stores)
	_people = _tree(page, ["Person", "Owner / qualification", "Actual duty", "Phase", "Position", "Load", "Pending"])
	_label(page, "Reporting is not presence. Supplier/away crew are ineligible; carried freight and occupied stations keep the old actual duty until safe handoff.", 14)


func _build_jobs(page: VBoxContainer) -> void:
	var controls := HBoxContainer.new()
	page.add_child(controls)
	_button(controls, "Block depot source", func() -> Dictionary: return simulation.set_store("depot", false))
	_button(controls, "Restore stores", _restore_stores)
	_button(controls, "Cancel selected demand", func() -> Dictionary:
		var selected := _jobs.get_selected()
		return simulation.cancel_job(selected.get_metadata(0)) if selected != null else {"ok": false, "message": "Select an actual job first."})
	_jobs = _tree(page, ["Job / type", "Base → effective", "Age", "Requested", "In flight", "Deposited", "Cause"])
	_jobs.set_column_expand_ratio(6, 3)
	_jobs.item_selected.connect(func() -> void:
		var selected := _jobs.get_selected()
		if selected != null:
			var job: Dictionary = simulation._job(selected.get_metadata(0))
			_detail.text = "%s · source %s → %s · %s\nAge %.3fs · %s · selected %d times\n%s" % [job.id, job.source, job.destination, job.type, simulation.time - job.created, Simulation.PRIORITIES[simulation.effective_priority(job)], job.selected, job.blocker])
	_detail = _scroll_label(page, 70)
	_label(page, "Waiting work promotes every 60s to High. Explicit Emergency stays above High; 120s starvation reports that cause. Source blockage releases its own claims after 10s.", 14)


func _build_stores(page: VBoxContainer) -> void:
	var controls := HBoxContainer.new()
	page.add_child(controls)
	_store_choice = OptionButton.new()
	for id in simulation.stores: _store_choice.add_item(id)
	controls.add_child(_store_choice)
	_filter = OptionButton.new()
	for name in ["All types", "M01 only", "M02 only"]: _filter.add_item(name)
	controls.add_child(_filter)
	_capacity = SpinBox.new()
	_capacity.min_value = 0
	_capacity.max_value = 5000
	_capacity.value = 5000
	_capacity.step = 1
	_capacity.custom_minimum_size.x = 120
	controls.add_child(_capacity)
	_store_choice.item_selected.connect(func(_index: int) -> void:
		var id := _store_choice.get_item_text(_store_choice.selected)
		_capacity.max_value = simulation.Layout.STORES[id][1]
		_capacity.value = simulation.stores[id].capacity)
	_button(controls, "Apply space / filter", func() -> Dictionary:
		var id := _store_choice.get_item_text(_store_choice.selected)
		var allowed: Array = [] if _filter.selected == 0 else ["M01" if _filter.selected == 1 else "M02"]
		return simulation.set_store(id, simulation.stores[id].accessible, _capacity.value, allowed))
	_button(controls, "Restore stores", _restore_stores)
	_stores = _tree(page, ["Store / type", "Physical", "Available", "Reserved out", "Inbound kg", "Capacity kg", "Access / filter"])
	_stores.set_column_expand_ratio(0, 2)
	_label(page, "Actual capacities are catalogue bays/depots. Edits preserve existing goods and create relocation demand. Piles are marked physical recovery locations, never missing freight.", 14)


func _build_yard(page: VBoxContainer) -> void:
	var controls := HBoxContainer.new()
	page.add_child(controls)
	_button(controls, "Yard target 1", func() -> Dictionary: return simulation.set_target("yard", 1, 2))
	_button(controls, "Drive to reserved parking", func() -> Dictionary: return simulation.yard.start_trip())
	_button(controls, "Release yard driver", func() -> Dictionary: return simulation.set_target("yard", 0))
	_yard = _scroll_label(page, 200)
	_yard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(page, "Declared owned starting T01, not supplier property or manufactured crew. Four real parking places; two used by this single bounded route. Strategic dispatch and full G07 stations remain separate.", 14)


func _no_safe_stores() -> Dictionary:
	for id in simulation.stores.keys(): simulation.set_store(id, false)
	return {"ok": true, "message": "Fixture access invalidation: carrying goods need a nearest valid store or real marked temporary pile."}


func _restore_stores() -> Dictionary:
	for id in simulation.stores.keys(): simulation.set_store(id, true)
	return {"ok": true, "message": "Storage access restored; recovery still requires real people and handling."}


func _update(message: String = "") -> void:
	_refreshing = true
	var view: Dictionary = simulation.snapshot()
	_summary.text = "t=%.3fs · %d physical people · one owned T01 · work/consumption/output = 0 (G04)" % [view.time, view.people.size()]
	if not message.is_empty(): _feedback.text = message
	_clear(_staff)
	for row in view.staffing:
		_row(_staff, [row.id, "%d / %d" % [row.target, row.positions], row.assigned, row.present, row.reporting_or_active, row.shortage, row.priority])
	var gate: Dictionary = view.workshop
	_readiness.text = "R01 local-input gate: %s\n%s · operators present %d · %s\nWork 0 · consumed 0 · output 0 · full A05 continuation remains G04" % [gate.status, gate.reference, gate.operators_present, "Hauling shortage: assign General Hauling" if gate.hauling_shortage else "Inputs become usable only after deposit"]
	_clear(_people)
	for p in view.people:
		var load := "—" if p.load.is_empty() else "%d %s → %s" % [p.load.count, p.load.type, p.load.destination]
		_row(_people, [p.id, "%s / %s" % [p.owner, p.qualification], p.duty_id if not p.duty_id.is_empty() else p.assignment, p.phase, str(p.position), load, p.pending_duty if p.pending_assignment != "None" else "None"])
	_clear(_jobs)
	for job in view.jobs:
		var row := _row(_jobs, [job.id + " / " + job.type, Simulation.PRIORITIES[job.priority] + " → " + job.effective_priority, "%.1fs" % job.age, job.requested, job.in_flight, job.delivered, "Cancelled" if job.cancelled else job.blocker])
		row.set_metadata(0, job.id)
		row.set_tooltip_text(6, job.blocker)
	_clear(_stores)
	for store in view.stores:
		var by_type: Dictionary = {}
		for stock in store.stocks:
			if not by_type.has(stock.design_type): by_type[stock.design_type] = [0, 0, 0]
			by_type[stock.design_type][0] += stock.quantity
			by_type[stock.design_type][1] += stock.available
			by_type[stock.design_type][2] += stock.reserved
		if by_type.is_empty(): by_type["empty"] = [0, 0, 0]
		for type in by_type:
			_row(_stores, [store.id + " / " + type, by_type[type][0], by_type[type][1], by_type[type][2], store.reserved_inbound_kg, store.capacity, ("Open" if store.accessible else "Blocked") + " " + str(store.filter)])
	var y: Dictionary = view.yard
	var driver: Dictionary = simulation.ledger.inspect_entity("driver-01")
	_yard.text = "Owned T01 yard-t01 · %s\nPosition %s · facing %s · footprint 7 × 2.7m\nDriver station: %s · pending exit %s\nFinite F11 places: occupied %s · reserved %s\nDistance %.3f / %.3fm · actual tank %.4f M08 · burned %.4f\nStraight speed 12m/s; radius 10m arcs limited to 45°/s (7.854m/s).\nStation entry/exit 3s while stationary; reassignment cannot vacate a moving driver.\nActual driver inspection: %s" % [y.state, y.position, y.facing, y.driver if not y.driver.is_empty() else "Empty", y.pending_exit, y.occupied_parking, y.reserved_parking, y.distance, y.route_length, y.fuel, y.burned, str(driver)]
	_audit.text = "Conservation / duty / reservation audit: " + ("PASS" if view.audit.is_empty() else str(view.audit))
	_refreshing = false


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void:
		var result: Dictionary = action.call()
		_update(result.message))
	parent.add_child(button)
	return button


func _label(parent: Node, text: String, size: int = 15) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _scroll_label(parent: Node, height: int) -> Label:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = height
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var label := _label(scroll, "", 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	page.add_theme_constant_override("separation", 6)
	tabs.add_child(page)
	return page


func _tree(parent: Node, titles: Array) -> Tree:
	var tree := Tree.new()
	tree.columns = titles.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in titles.size(): tree.set_column_title(i, titles[i])
	parent.add_child(tree)
	return tree


func _clear(tree: Tree) -> void:
	tree.clear()
	tree.create_item()


func _row(tree: Tree, values: Array) -> TreeItem:
	var row := tree.create_item(tree.get_root())
	for i in values.size():
		row.set_text(i, str(values[i]))
		row.set_tooltip_text(i, str(values[i]))
	return row
