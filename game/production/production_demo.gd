extends Control
## Separate released R01 review; G03's original staged fixtures stay unchanged.

const Rear = preload("res://game/staffing/rear_simulation.gd")
const Production = preload("res://game/production/r01_production.gd")
var simulation := Rear.new()
var production: RefCounted
var _status: Label
var _work: Label
var _physical: Label
var _people: Label
var _feedback: Label
var _target: Label
var _target_count: SpinBox


func _ready() -> void:
	production = Production.new(simulation)
	simulation.production = production
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
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	_label(layout, "G04 / R01 — real workshop production", 24)
	_label(layout, "R01 continuous / stock target · shared G03 people, hauling, ledger and clock · bounded review", 14)
	var targets := HBoxContainer.new()
	layout.add_child(targets)
	_button(targets, "Continuous", func() -> Dictionary: return production.set_mode("Continuous"))
	_button(targets, "Stock target", func() -> Dictionary: return production.set_mode("Stock target"))
	_label(targets, "E01 minimum", 14)
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
	_button(staffing, "Operators 2", func() -> Dictionary: return simulation.set_target("workshop", 2))
	_button(staffing, "Release operators", func() -> Dictionary: return simulation.set_target("workshop", 0))
	_button(staffing, "Hauling 1", func() -> Dictionary: return simulation.set_target("hauling", 1))
	_button(staffing, "Release haulers", func() -> Dictionary: return simulation.set_target("hauling", 0))
	var controls := HBoxContainer.new()
	layout.add_child(controls)
	_button(controls, "Pause R01", func() -> Dictionary: return production.set_paused(true))
	_button(controls, "Resume R01", func() -> Dictionary: return production.resume())
	_button(controls, "Cancel batch", func() -> Dictionary: return production.cancel())
	for seconds in [1, 2, 10, 20, 300]:
		_button(controls, "+%ds" % seconds, func() -> Dictionary: return simulation.advance_time(seconds))
	var space := HBoxContainer.new()
	layout.add_child(space)
	_button(space, "Block output", func() -> Dictionary: return simulation.set_store("workshop_output", false))
	_button(space, "Restore output", func() -> Dictionary: return simulation.set_store("workshop_output", true, 1000, []))
	_button(space, "Try 3 kg", func() -> Dictionary: return simulation.set_store("workshop_output", true, 3))
	_button(space, "Reject E01 filter", func() -> Dictionary: return simulation.set_store("workshop_output", true, -1, ["M01"]))
	_feedback = _label(layout, "Initial ingredients: 2 M01 + 1 M02 at the depot. Two operators must actually report; assign real hauling.", 14)
	_status = _label(layout, "", 18)
	_target = _label(layout, "", 14)
	_work = _label(layout, "", 16)
	_physical = _label(layout, "", 16)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_people = _label(scroll, "", 14)
	_people.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(layout, "Pause/access/staff loss preserves active work. Cancel loses consumed inputs, keeps finished rifles and stops continuous requests. Windows input/readability remain unverified.", 13)
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
	_status.text = "t=%.3fs · R01 / F04 · %s\nOperators present %d / target %d · IDs %s · hauling shortage %s" % [simulation.time, view.status, view.operators.size(), view.target, str(view.operators), view.haul_shortage]
	var coverage: Dictionary = view.coverage
	_target.text = "%s · E01 minimum %d · Available A=%d + planned C=%d = %d\nEligible deposited %d / reserved %d · internal inbound %d (carried %d) · active batch forecast %d" % [view.mode, view.stock_target, coverage.available, coverage.planned, coverage.projected, coverage.eligible_physical, coverage.eligible_reserved, coverage.internal_relocation, coverage.internal_carried, coverage.batch_forecast]
	_work.text = "Batch %s / %s · work %.3f / 40 operator-seconds\nPromised output %.1f kg · consumed at start: %s" % [displayed.get("id", "None"), displayed.get("state", "Not started"), displayed.get("work", 0.0), view.output_promise.get("mass", 0.0), ", ".join(receipt) if not receipt.is_empty() else "None"]
	_physical.text = "Local inputs M01=%d / 2, M02=%d / 1 · depot M01=%d, M02=%d\nPhysical F04 output: %d empty E01 / %.1f kg · output capacity %.1f kg · completed batches %d\nConservation / duty audit: %s" % [view.local_inputs.M01, view.local_inputs.M02, simulation.ledger.available_stock_at("depot", "M01"), simulation.ledger.available_stock_at("depot", "M02"), view.physical_output, simulation.ledger.loose_stock_mass_at("workshop_output"), simulation.stores.workshop_output.capacity, production.history.filter(func(b: Dictionary) -> bool: return b.state == "Completed").size(), "PASS" if simulation.audit().is_empty() else str(simulation.audit())]
	var lines: Array[String] = []
	for person in simulation.snapshot().people:
		lines.append("%s · %s / %s · %s · position %s · carry %s · pending %s" % [person.id, person.assignment, person.duty_id, person.phase, person.position, person.carrying_stock_id, person.pending_assignment])
	for job in simulation.snapshot().jobs:
		lines.append("%s · %s → %s / %s · deposited %d/%d · in flight %d · %s" % [job.id, job.source, job.destination, job.type, job.delivered, job.requested, job.in_flight, job.blocker])
	lines.append("E01 eligible physical stock: " + str(coverage.stocks))
	lines.append("E01 valid internal coverage: " + str(coverage.relocations))
	lines.append("E01 excluded holdings: " + str(coverage.excluded))
	_people.text = "\n".join(lines)
