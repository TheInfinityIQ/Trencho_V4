extends Control
## Review controls shared only by the fixed released R01, R02 and R26 scenes.

const Rear = preload("res://game/staffing/rear_simulation.gd")
const Production = preload("res://game/production/r01_production.gd")
var simulation: RefCounted
var production: RefCounted
var _status: Label
var _work: Label
var _physical: Label
var _people: Label
var _feedback: Label
var _target: Label
var _target_count: SpinBox


func _make_production() -> void:
	simulation = Rear.new()
	production = Production.new(simulation)
	simulation.production = production


func _initial_stock_note() -> String:
	return "Initial ingredients: 2 M01 + 1 M02 at the depot. Two operators must actually report; assign real hauling."


func _ready() -> void:
	_make_production()
	var spec: Dictionary = production.snapshot()
	var background := ColorRect.new()
	background.color = Color("121b27")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)
	var title: String = {"R01": "workshop", "R02": "munitions", "R26": "building-material"}[spec.recipe]
	_label(layout, "G04 / %s — real %s production" % [spec.recipe, title], 24)
	_label(layout, "%s continuous / stock target · shared G03 people, hauling, ledger and clock · bounded review" % spec.recipe, 14)
	var targets := HBoxContainer.new()
	layout.add_child(targets)
	_button(targets, "Continuous", func() -> Dictionary: return production.set_mode("Continuous"))
	_button(targets, "Stock target", func() -> Dictionary: return production.set_mode("Stock target"))
	var target_prompt := _label(targets, spec.output_type + " minimum", 14)
	target_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_target_count = SpinBox.new()
	_target_count.min_value = 0
	_target_count.max_value = 1000000
	_target_count.allow_greater = true
	_target_count.step = 1
	_target_count.custom_minimum_size.x = 110
	_target_count.value_changed.connect(func(value: float) -> void:
		var result: Dictionary = production.set_stock_target(int(value))
		_feedback.text = result.message
		_refresh())
	targets.add_child(_target_count)
	var staffing := HBoxContainer.new()
	layout.add_child(staffing)
	for count in ([4, 8] if spec.recipe == "R26" else [2]):
		_button(staffing, "Operators %d" % count, func() -> Dictionary: return simulation.set_target(spec.duty, count))
	_button(staffing, "Release operators", func() -> Dictionary: return simulation.set_target(spec.duty, 0))
	_button(staffing, "Hauling 1", func() -> Dictionary: return simulation.set_target("hauling", 1))
	_button(staffing, "Release haulers", func() -> Dictionary: return simulation.set_target("hauling", 0))
	var controls := HBoxContainer.new()
	layout.add_child(controls)
	_button(controls, "Pause " + spec.recipe, func() -> Dictionary: return production.set_paused(true))
	_button(controls, "Resume " + spec.recipe, func() -> Dictionary: return production.resume())
	_button(controls, "Cancel batch", func() -> Dictionary: return production.cancel())
	for seconds in ([1, 2, 5, 10, 20, 300] if spec.recipe == "R26" else [1, 2, 10, 20, 300]):
		_button(controls, "+%ds" % seconds, func() -> Dictionary: return simulation.advance_time(seconds))
	var space := HBoxContainer.new()
	layout.add_child(space)
	_button(space, "Block output", func() -> Dictionary: return simulation.set_store(spec.output_store, false))
	_button(space, "Restore output", func() -> Dictionary: return simulation.set_store(spec.output_store, true, simulation.Layout.STORES[spec.output_store][1], []))
	_button(space, "Try %d kg" % (spec.output_count * spec.unit_mass - 1), func() -> Dictionary: return simulation.set_store(spec.output_store, true, spec.output_count * spec.unit_mass - 1))
	_button(space, "Reject %s filter" % spec.output_type, func() -> Dictionary: return simulation.set_store(spec.output_store, true, -1, ["M01"]))
	_feedback = _label(layout, _initial_stock_note(), 14)
	_status = _label(layout, "", 18)
	_target = _label(layout, "", 14)
	_work = _label(layout, "", 16)
	_physical = _label(layout, "", 14)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_people = _label(scroll, "", 14)
	_people.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(layout, "Consumed work survives pause/access/staff loss. Cancel keeps finished goods. Windows native testing unverified.", 13)
	_refresh()


func _button(parent: Node, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(func() -> void:
		var result: Dictionary = action.call()
		_feedback.text = result.message
		_refresh())
	parent.add_child(button)


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _refresh() -> void:
	var view: Dictionary = production.snapshot()
	var displayed: Dictionary = view.batch
	if displayed.is_empty() and not view.history.is_empty(): displayed = view.history.back()
	var receipt: Array[String] = []
	for portion in displayed.get("receipt", []): receipt.append("%d %s" % [portion.count, portion.type])
	_status.text = "t=%.3fs · %s / %s · %s\nOperators present %d / target %d · IDs %s · hauling shortage %s" % [simulation.time, view.recipe, view.facility, view.status, view.operators.size(), view.target, str(view.operators), view.haul_shortage]
	if view.recipe == "R26":
		# Eight operator IDs remain in the person inspection; keep the summary
		# within two lines so the small-window inspection still has useful space.
		_status.text = "t=%.3fs · R26 / F13 · %s\nOrdinary operators present %d / target %d · hauling shortage %s" % [simulation.time, view.status, view.operators.size(), view.target, view.haul_shortage]
	var coverage: Dictionary = view.coverage
	_target.text = "%s · %s minimum %d · Available A=%d + planned C=%d = %d" % [view.mode, view.output_type, view.stock_target, coverage.available, coverage.planned, coverage.projected]
	_work.text = "Batch %s / %s · work %.3f / %.0f operator-seconds\nPromised output %.1f kg · consumed at start: %s" % [displayed.get("id", "None"), displayed.get("state", "Not started"), displayed.get("work", 0.0), view.required_work, view.output_promise.get("mass", 0.0), ", ".join(receipt) if not receipt.is_empty() else "None"]
	var local: Array[String] = []
	var depot: Array[String] = []
	for type in view.inputs:
		local.append("%s=%d / %d" % [type, view.local_inputs[type], view.inputs[type]])
		depot.append("%s=%d" % [type, simulation.ledger.available_stock_at("depot", type)])
	var output_name: String = {"R01": "empty E01", "R02": "loose E02", "R26": "M11"}[view.recipe]
	_physical.text = "Local inputs %s · depot %s\nPhysical %s output: %d %s / %.1f kg · output capacity %.1f kg · completed batches %d\nConservation / duty audit: %s" % [", ".join(local), ", ".join(depot), view.facility, view.physical_output, output_name, simulation.ledger.loose_stock_mass_at(view.output_store), simulation.stores[view.output_store].capacity, production.history.filter(func(b: Dictionary) -> bool: return b.state == "Completed").size(), "PASS" if simulation.audit().is_empty() else str(simulation.audit())]
	var lines: Array[String] = []
	lines.append("%s eligible deposited %d / reserved %d · internal inbound %d (carried %d) · active batch forecast %d" % [view.output_type, coverage.eligible_physical, coverage.eligible_reserved, coverage.internal_relocation, coverage.internal_carried, coverage.batch_forecast])
	for person in simulation.snapshot().people:
		lines.append("%s · %s / %s · %s · position %s · carry %s · pending %s" % [person.id, person.assignment, person.duty_id, person.phase, person.position, person.carrying_stock_id, person.pending_assignment])
	for job in simulation.snapshot().jobs:
		lines.append("%s · %s → %s / %s · deposited %d/%d · in flight %d · %s" % [job.id, job.source, job.destination, job.type, job.delivered, job.requested, job.in_flight, job.blocker])
	lines.append(view.output_type + " eligible physical stock: " + str(coverage.stocks))
	lines.append(view.output_type + " valid internal coverage: " + str(coverage.relocations))
	lines.append(view.output_type + " excluded holdings: " + str(coverage.excluded))
	_people.text = "\n".join(lines)
