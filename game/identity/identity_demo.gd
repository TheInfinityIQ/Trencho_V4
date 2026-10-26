extends Control
## Event-driven review UI; owns its fixture without an autoload or per-frame polling.

const Fixture = preload("res://game/identity/identity_fixture.gd")
const Records = preload("res://game/identity/identity_records.gd")

var _fixture := Fixture.new()
var _status: Label
var _person: Label
var _claims: Label
var _ammunition: Label
var _carrier: Label
var _audit: Label
var _stock_tree: Tree
var _trace: Label


func _ready() -> void:
	_fixture.reset()
	_build_ui()
	_show_result({"ok": true, "message": "Ready. Choose a scenario tab; reset restores the same initial people and stock."})


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
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := _label(heading, "Trencho V4  /  Physical supply ledger", 27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading, "+2s fixture time", func() -> Dictionary: return _fixture.ledger.advance_time(2.0), false)
	_button(heading, "Reset fixture", func() -> Dictionary:
		_fixture.reset()
		return {"ok": true, "message": "Fixture reset: 3 people, 11 rifles (10 stock + 1 personal), 60 rounds and 5 steel."}, false)
	_label(layout, "G01 review fixture · upstream jobs and handling boundaries are scripted; no live courses, combat or capacity lifecycle.", 15)
	_status = _label(layout, "", 16)
	_status.custom_minimum_size.y = 42
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_stretch_ratio = 1.0
	tabs.custom_minimum_size.x = 480
	columns.add_child(tabs)
	_build_duty_tab(_tab(tabs, "Duty handoff"))
	_build_claims_tab(_tab(tabs, "Rifle requests"))
	_build_ammo_tab(_tab(tabs, "Ammunition"))
	var holdings := VBoxContainer.new()
	holdings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holdings.size_flags_stretch_ratio = 1.1
	columns.add_child(holdings)
	_label(holdings, "Physical holdings", 23)
	_carrier = _label(holdings, "", 15)
	_label(holdings, "Actual counts include loaded rounds exactly once. Empty source portions retain their origin and unmet demand.", 14)
	_stock_tree = Tree.new()
	_stock_tree.columns = 5
	_stock_tree.column_titles_visible = true
	_stock_tree.hide_root = true
	_stock_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stock_tree.custom_minimum_size.y = 230
	_stock_tree.add_theme_font_size_override("font_size", 14)
	var titles := ["Identity / type", "Holder", "Count", "Reserved", "Free"]
	for index in range(5):
		_stock_tree.set_column_title(index, titles[index])
		_stock_tree.set_column_expand(index, index < 2)
		_stock_tree.set_column_custom_minimum_width(index, 130 if index < 2 else 70)
	holdings.add_child(_stock_tree)
	_audit = _label(holdings, "", 15)
	_trace = _label(layout, "", 14)
	_trace.custom_minimum_size.y = 46
	_label(layout, "A01/A02 foundation + A03 ammunition accounting only. Incapacitation, dropped gear and casualty recovery remain G16.", 14)


func _build_duty_tab(page: VBoxContainer) -> void:
	_label(page, "One person, one active duty", 22)
	_person = _inspection_label(page)
	var buttons := _button_grid(page)
	_button(buttons, "1. Pick up 5 steel", func() -> Dictionary:
		return _fixture.ledger.begin_carry("worker-01", "steel-01", 5))
	_button(buttons, "2. Request training", func() -> Dictionary:
		return _fixture.ledger.request_assignment("worker-01", Records.Assignment.TRAINING, "course-fixture"))
	_button(buttons, "3. Finish safe deposit", func() -> Dictionary:
		return _fixture.ledger.finish_carry("worker-01", "rear-store"))
	_button(buttons, "Cancel pending request", func() -> Dictionary:
		return _fixture.ledger.cancel_assignment_request("worker-01"))
	_label(page, "While carrying, training stays pending and labour remains the only duty. Finishing a valid deposit changes duty once; no course progress is simulated.", 14)


func _build_claims_tab(page: VBoxContainer) -> void:
	_label(page, "Two requests, ten depot rifles", 22)
	_claims = _inspection_label(page)
	var buttons := _button_grid(page)
	_button(buttons, "A: request 10 rifles", func() -> Dictionary: return _fixture.request_rifles("claim-A"))
	_button(buttons, "B: request 10 rifles", func() -> Dictionary: return _fixture.request_rifles("claim-B"))
	_button(buttons, "A: load 4 onto carrier", func() -> Dictionary:
		return _fixture.ledger.transfer_stock("rifles-01", 4, "supplier-truck", "claim-A"))
	_button(buttons, "A: cancel remaining", func() -> Dictionary: return _fixture.ledger.release_claim("claim-A"))
	_button(buttons, "B: retry reservation", func() -> Dictionary: return _fixture.ledger.reserve_remaining("claim-B"))
	_button(buttons, "Try remote HQ transfer", func() -> Dictionary:
		return _fixture.ledger.transfer_stock("rifles-01", 1, "far-hq"))
	_label(page, "Requests reserve only existing stock. Buttons determine fixture request order; this is not a manifest scheduler. Cancellation never unloads goods already aboard.", 14)


func _build_ammo_tab(page: VBoxContainer) -> void:
	_label(page, "Loaded rounds travel with the rifle", 22)
	_ammunition = _inspection_label(page)
	var buttons := _button_grid(page)
	_button(buttons, "Unload to current holder", func() -> Dictionary: return _fixture.ledger.unload_rounds("rifle-11"))
	_button(buttons, "Load 10 local rounds", _fixture.load_ten)
	_button(buttons, "Complete local handoff", _fixture.handoff_weapon)
	_button(buttons, "Try reserving loaded rounds", _try_loaded_claim)
	_label(page, "The handoff button completes an accounting boundary between co-located fixture people. Actual handoff timing and firing eligibility are downstream behavior.", 14)


func _try_loaded_claim() -> Dictionary:
	for entity in _fixture.ledger.snapshot().entities:
		if entity.kind == "STOCK" and entity.holder_id == "rifle-11" and entity.quantity > 0:
			return _fixture.ledger.request_stock("loaded-claim", entity.id, 1, "Manifest C", "Invalid loaded-round request", "army-blue")
	return {"ok": false, "message": "There are no loaded rounds; load the rifle first."}


func _refresh() -> void:
	var ledger := _fixture.ledger
	var person := ledger.inspect_entity("worker-01")
	_person.text = "ID: %s · owner/control: army-blue\nPhysical holder: %s at %s m\nActive duty: %s / %s\nPending: %s\nCarry: %s\nBlocker: %s" % [
		person.id, person.holder_id, person.position, person.assignment, person.duty_id,
		person.pending_assignment, _none(person.carrying_stock_id), _none(person.blocked_reason)]
	_claims.text = "Depot stock rifles-01: actual %d · reserved %d · free %d\n\n%s\n\n%s" % [
		ledger.inspect_entity("rifles-01").quantity, ledger.reserved("rifles-01"), ledger.available("rifles-01"),
		_claim_text("claim-A"), _claim_text("claim-B")]
	var weapon := ledger.inspect_entity("rifle-11")
	_ammunition.text = "Weapon: rifle-11 · owner: army-blue\nHolder: %s · functional: %s\nLoaded: %d / %d\nperson-02 loose: %d · person-03 loose: %d\nAll physical E02 rounds: %d / 60\nLoaded rounds are stock inside rifle-11." % [
		weapon.holder_id, "yes" if weapon.functional else "no", weapon.loaded_rounds,
		weapon.loaded_capacity, _fixture.loose_rounds_at("person-02"), _fixture.loose_rounds_at("person-03"), ledger.total_stock("E02 Round")]
	var carrier := ledger.inspect_entity("supplier-truck")
	_carrier.text = "supplier-truck · holder: %s\nOwner: %s · controller: %s\nFreight: %.2f kg; goods retain their purchaser." % [carrier.holder_id, carrier.owner, carrier.controller, carrier.contents_mass_kg]
	_stock_tree.clear()
	var root := _stock_tree.create_item()
	for entity in ledger.snapshot().entities:
		if entity.kind not in ["STOCK", "WEAPON"]:
			continue
		var row := _stock_tree.create_item(root)
		row.set_text(0, "%s / %s" % [entity.id, entity.design_type])
		row.set_text(1, entity.holder_id)
		row.set_text(2, str(entity.quantity))
		row.set_text(3, str(entity.get("reserved", 0)))
		row.set_text(4, str(entity.get("available", entity.quantity)))
		for column in range(5):
			row.set_tooltip_text(column, "Owner: %s\nOrigin: %s\nWorld position: %s m\nUnit mass: %.2f kg\nBlocker: %s" % [entity.owner, _none(entity.origin_id), entity.position, entity.unit_mass_kg, _none(entity.get("blocked_reason", ""))])
	var failures := ledger.audit()
	_audit.text = "Conservation: PASS · 11 rifles, 60 rounds, 5 steel; one exclusive duty per person." if failures.is_empty() else "INVARIANT FAILURE: " + "; ".join(failures)
	_audit.modulate = Color("8ee4ba") if failures.is_empty() else Color("ffb0a8")
	var events: Array = ledger.snapshot().events
	var recent: Array[String] = []
	for index in range(maxi(0, events.size() - 2), events.size()):
		var event: Dictionary = events[index]
		recent.append("t=%.1fs · %s · %s" % [event.time, event.entity_id, event.description])
	_trace.text = "\n".join(recent)


func _claim_text(id: String) -> String:
	var claim := _fixture.ledger.inspect_claim(id)
	if claim.is_empty():
		return "%s: not requested" % id
	return "%s · age %.1fs\n%s\nRequested %d · reserved %d · delivered %d · unfilled %d\n%s" % [
		claim.claimant, claim.age, claim.purpose, claim.requested, claim.reserved,
		claim.fulfilled, claim.unfilled, _none(claim.blocked_reason)]


func _show_result(result: Dictionary) -> void:
	_status.text = result.message
	_status.modulate = Color("8ee4ba") if result.ok else Color("ffcf91")
	_refresh()


func _button_grid(parent: Node) -> GridContainer:
	var buttons := GridContainer.new()
	buttons.columns = 2
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	parent.add_child(buttons)
	return buttons


func _inspection_label(parent: Node) -> Label:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 144
	parent.add_child(scroll)
	var label := _label(scroll, "", 17)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(parent: Node, text: String, action: Callable, expand: bool = true) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_END
	button.pressed.connect(func() -> void: _show_result(action.call()))
	parent.add_child(button)


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	tabs.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	return page


func _none(value: String) -> String:
	return "None" if value.is_empty() else value
