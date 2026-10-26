extends Control
## G08 diagnostic controls use explicit time; no per-frame simulation polling.

const Fixtures = preload("res://game/terrain/terrain_fixtures.gd")
const Catalog = preload("res://game/terrain/terrain_catalog.gd")
const Diagram = preload("res://game/terrain/terrain_diagram.gd")
var _lane: RefCounted
var _fixture: Dictionary = {}
var _observation: Dictionary = {}
var _knowledge := "Unknown"
var _cases: Array[Dictionary] = Fixtures.movement_cases()
var _mode: OptionButton
var _selector: OptionButton
var _summary: Label
var _detail: Label
var _diagram: Control
var _movement_controls: HBoxContainer
var _overview: CheckButton


func _ready() -> void:
	_build()
	_choose_mode(0)


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("101c29")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	_label(layout, "Trencho V4 / Terrain & sight", 25)
	_label(layout, "G08 declared local fixtures · straight lanes and static observation · production world, live crews/combat and causeway recovery remain later systems.", 14)
	var options := HBoxContainer.new()
	layout.add_child(options)
	_mode = OptionButton.new()
	_mode.add_item("Movement")
	_mode.add_item("Sight & cover")
	_mode.item_selected.connect(_choose_mode)
	options.add_child(_mode)
	_selector = OptionButton.new()
	_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selector.item_selected.connect(_load_case)
	options.add_child(_selector)
	_button(options, "Reset case", func() -> void: _load_case(_selector.selected))
	_overview = CheckButton.new()
	_overview.text = "Overview"
	_overview.toggled.connect(func(_on: bool) -> void: _refresh())
	options.add_child(_overview)
	_movement_controls = HBoxContainer.new()
	layout.add_child(_movement_controls)
	_button(_movement_controls, "Start lane", func() -> void:
		_lane.start()
		_refresh())
	for seconds in [1, 5, 30, 120]:
		_button(_movement_controls, "+%ds" % seconds, func() -> void:
			_lane.advance(seconds)
			_refresh())
	_button(_movement_controls, "Stop here", func() -> void:
		_lane.cancel()
		_refresh())
	_summary = _label(layout, "", 16)
	_summary.custom_minimum_size.y = 44
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 440
	layout.add_child(split)
	_diagram = Diagram.new()
	_diagram.custom_minimum_size = Vector2(300, 120)
	_diagram.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_diagram)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 340
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_detail = _label(scroll, "", 14)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(layout, "Explicit clock · poses/fuel are real within this initialized fixture · diagram scale never changes range or knowledge · native verification pending.", 13)


func _label(parent: Node, text: String, font: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	button.pressed.connect(action)
	parent.add_child(button)


func _choose_mode(index: int) -> void:
	_selector.clear()
	if index == 0:
		for spec in _cases: _selector.add_item(spec.name)
	else:
		for name in Fixtures.sight_cases(): _selector.add_item(name)
	_mode.select(index)
	_movement_controls.visible = index == 0
	_selector.select(0)
	_load_case(0)


func _load_case(index: int) -> void:
	_selector.select(index)
	_knowledge = "Unknown"
	if _mode.selected == 0:
		_lane = Fixtures.lane(_cases[index])
		_fixture = {}
		_observation = {}
	else:
		_fixture = Fixtures.sight(Fixtures.sight_cases()[index])
		_observation = _fixture.world.observe(_fixture.observer, _fixture.target, _fixture.role, _fixture.muzzle, _fixture.weapon_range)
		if _observation.visible: _knowledge = "Observed at declared probe time"
	_refresh()


func _refresh() -> void:
	_diagram.overview = _overview.button_pressed
	_diagram.sight = _mode.selected == 1
	if _mode.selected == 0:
		var view: Dictionary = _lane.snapshot()
		var body: Dictionary = view.entity
		var at: Vector2 = body.position
		var sample: Dictionary = _lane.world.cell(Vector2i(floor(at.x), floor(at.y)))
		var support: Dictionary = _lane.world.support(Vector2i(floor(at.x), floor(at.y)), body.movement_class)
		_summary.text = "t=%.3fs · %s · %s\n%s" % [view.time, body.id, view.state, view.reason]
		var text := "ACTUAL BODY\nPosition (%.3f, %.3f)m · ground %.3fm\nClass %s · footprint %.2f × %.2fm · facing %.1f°\nBase %.2fm/s · tank %.6f units\nTravelled %.3fm · consumed %.6f fuel\nDestination %s\n\nCENTRE CELL (whole footprint also checked)\n%s %s\nHeight %.3fm · slope %.6f°\nDepth %.3fm · ford classes %s\n%s\n\n" % [at.x, at.y, _lane.world.ground(at), ["foot", "wheel", "track"][body.movement_class], body.size.x, body.size.y, rad_to_deg(body.facing), body.base, body.fuel, view.distance, view.fuel_used, view.destination, sample.terrain, Catalog.SURFACES[sample.terrain].name, _lane.world.ground(at), rad_to_deg(atan(Vector2(sample.get("gradient", Vector2.ZERO)).length())), sample.get("depth", 0), str(sample.get("classes", [])), str(support)]
		if not view.plan.is_empty() and view.plan.ok:
			text += "ACCEPTED LANE\n%.3fm · %.6fs · %.6f fuel\n%d physical support intervals\n" % [view.plan.distance, view.plan.seconds, view.plan.fuel, view.plan.parts.size()]
			if not view.motion.is_empty(): text += "Current interval: %s\n" % str(view.motion.parts[view.motion.index])
		text += "\nOBSTACLES\n" + str(_lane.world.obstacles) + "\n\nDeclared compatible overlays are inputs; bridge production/load integration is G13. No turn planner or full-world route claimed."
		_detail.text = text
		_diagram.world = _lane.world
		_diagram.entity = body
		_diagram.destination = view.destination
	else:
		var value: Dictionary = _observation
		var protection: Dictionary = _fixture.world.cover(_fixture.target, _fixture.observer, _fixture.cover_class, false, _fixture.impact)
		_summary.text = "Knowledge: %s · eye: %s · muzzle: %s\nCover hit ×%.2f (%s) / blast ×%.2f (%s)" % [_knowledge, value.eye.reason, value.muzzle.reason, protection.hit, protection.source, protection.blast, protection.blast_source]
		_detail.text = "DECLARED PROBES (configuration, not hidden enemy knowledge)\nObserver %s · target %s\nRole %s · actual ground-relative eye %.2fm\n\nEYE\n%s\n\nINDEPENDENT GROUND MUZZLE\n%s\n\nDECLARED BLAST IMPACT\n%s\n\nDIRECTIONAL COVER (separate direct/blast sources)\n%s\n\nGEOMETRY\n%s\n\nOverview only changes this diagnostic diagram. No contacts are discovered by zooming; unseen targets are not drawn. No weapon, drone launch, smoke delivery or damage is simulated." % [_fixture.observer, _fixture.target, _fixture.role, Catalog.ROLES[_fixture.role].eye, str(value.eye), str(value.muzzle), str(_fixture.impact), str(protection), str(_fixture.world.obstacles)]
		_diagram.world = _fixture.world
		_diagram.observer = _fixture.observer
		_diagram.target = _fixture.target
		_diagram.visible_target = value.visible
	_diagram.queue_redraw()
