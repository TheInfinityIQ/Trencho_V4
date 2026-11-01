extends Control
## Persistent presentation shell. The parent owns all game state and commands.
signal navigation_requested(action: String)
signal speed_requested(value: int)
signal new_session_requested
signal modal_visibility_changed(visible: bool)

const UI = preload("res://game/ui/ui_kit.gd")
const NAVIGATION := [["rear", "Rear base"], ["Build", "Build"], ["Workers/Jobs", "Workers / Jobs"], ["Supplies", "Supplies"], ["Work", "Production"]]
const TITLES := {"rear": "REAR OPERATIONS", "Build": "CONSTRUCTION", "Workers/Jobs": "WORKFORCE", "Supplies": "ACQUISITION", "Work": "PRODUCTION", "Battlefield": "BATTLEFIELD", "Haul": "HAULING", "Info": "INSPECTION", "Train": "TRAINING", "Vehicles": "VEHICLES", "ArmySupply": "ARMY SUPPLY / PROTOTYPE", "Dispatch": "DISPATCH / PROTOTYPE", "Diagnostics": "DIAGNOSTICS"}
const MORE_ACTIONS := ["Haul", "Info", "Train", "Vehicles", "ArmySupply", "Dispatch", "Diagnostics"]

var content_host: Control
var _navigation_buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _title: Label
var _clock: Label
var _planning: Label
var _requisition: Label
var _help: PanelContainer
var _confirmation: ConfirmationDialog
var _current_navigation := "rear"
var _clock_text := "—"
var _planning_text := ""
var _current_speed := 0
var _requisition_text := "— REQ"

func _ready() -> void:
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UI.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var layout := UI.column(margin, true)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_header(layout)
	_build_help(layout)
	var body := UI.row(layout)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	_build_navigation(body)
	content_host = Control.new()
	content_host.name = "ContentHost"
	content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content_host)
	_build_confirmation()
	set_navigation(_current_navigation)
	set_clock(_clock_text, _current_speed, _planning_text)
	_requisition.text = _requisition_text

func _build_header(parent: Node) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 76
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)
	var header := UI.row(scroll)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.custom_minimum_size.y = 68
	header.add_theme_constant_override("separation", 16)
	var brand := UI.column(header)
	brand.custom_minimum_size.x = 174
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.label(brand, "T R E N C H O", 22)
	UI.label(brand, "LOGISTICS COMMAND", 10, UI.ACCENT)
	_title = UI.label(header, "", 15, UI.MUTED)
	_title.custom_minimum_size.x = 150
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_requisition = UI.label(header, _requisition_text, 16, UI.ACCENT)
	_requisition.custom_minimum_size.x = 120
	_requisition.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_requisition.clip_text = true
	var timing := UI.column(header)
	timing.custom_minimum_size.x = 192
	timing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_clock = UI.label(timing, _clock_text, 16)
	_clock.clip_text = true
	_clock.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_planning = UI.label(timing, "", 12, UI.ACCENT)
	_planning.clip_text = true
	_planning.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var speeds := UI.row(header)
	speeds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for value: int in [0, 1, 2]:
		var button := UI.button(speeds, ["Ⅱ", "1×", "2×"][value], func() -> void: speed_requested.emit(value))
		button.custom_minimum_size = Vector2(40, 40)
		button.toggle_mode = true
		button.tooltip_text = ["Pause the shared game clock", "Normal game speed", "Double game speed"][value]
		_speed_buttons[value] = button
	var menu := MenuButton.new()
	menu.text = "Session"
	menu.custom_minimum_size = Vector2(86, 40)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(menu)
	menu.get_popup().add_item("New game…", 0)
	menu.get_popup().add_item("Getting started", 1)
	menu.get_popup().id_pressed.connect(func(id: int) -> void:
		if id == 0: _confirmation.popup_centered()
		elif id == 1: _help.visible = not _help.visible)

func _build_navigation(parent: Node) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 174
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var rail := UI.column(scroll, true)
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI.label(rail, "COMMAND", 11, UI.MUTED)
	for item: Array in NAVIGATION:
		_navigation_button(rail, str(item[0]), str(item[1]))
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.add_child(space)
	UI.label(rail, "OBSERVE", 11, UI.MUTED)
	_navigation_button(rail, "Battlefield", "Battlefield  ↗")
	var advanced := MenuButton.new()
	advanced.text = "More systems"
	advanced.custom_minimum_size.y = 38
	advanced.tooltip_text = "Additional management panels and retained supply prototypes."
	rail.add_child(advanced)
	advanced.get_popup().add_item("Hauling", 0)
	advanced.get_popup().add_item("Inspection", 1)
	advanced.get_popup().add_item("Training", 2)
	advanced.get_popup().add_item("Vehicles", 3)
	advanced.get_popup().add_separator()
	advanced.get_popup().add_item("Army supply · prototype", 4)
	advanced.get_popup().add_item("Dispatch · prototype", 5)
	advanced.get_popup().add_separator()
	advanced.get_popup().add_item("Diagnostics", 6)
	advanced.get_popup().id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < MORE_ACTIONS.size(): navigation_requested.emit(MORE_ACTIONS[id]))
	UI.button(rail, "Getting started", func() -> void: _help.visible = not _help.visible)
	UI.label(rail, "The army acts\nautonomously.", 12, UI.MUTED)

func _navigation_button(parent: Node, action: String, title: String) -> void:
	var button := UI.button(parent, title, func() -> void: navigation_requested.emit(action))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 42
	button.toggle_mode = true
	_navigation_buttons[action] = button

func _build_help(parent: Node) -> void:
	_help = PanelContainer.new()
	_help.name = "GettingStarted"
	_help.hide()
	parent.add_child(_help)
	var layout := UI.column(_help)
	var heading := UI.row(layout)
	UI.label(heading, "Your first workshop", 18).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(heading, "Close", func() -> void: _help.hide())
	UI.label(layout, "Start time with 1×. Hire workers through Supplies or Workers / Jobs; they join only after arrival and disembarkation. Request haulers, place a Workshop through Build, then assign builders to its site.", 14, UI.INK, true)
	UI.label(layout, "WASD: move · R: rotate placement · Esc: cancel placement. Rear and Battlefield share one session.", 12, UI.MUTED, true)

func _build_confirmation() -> void:
	_confirmation = ConfirmationDialog.new()
	_confirmation.name = "NewSessionConfirmation"
	_confirmation.title = "Start a new game?"
	_confirmation.dialog_text = "This replaces the current session.\nCurrent progress will be lost."
	_confirmation.min_size = Vector2i(460, 180)
	_confirmation.theme = theme
	_confirmation.get_ok_button().text = "Start new game"
	_confirmation.get_ok_button().theme_type_variation = "Primary"
	_confirmation.get_cancel_button().text = "Keep playing"
	_confirmation.confirmed.connect(func() -> void: new_session_requested.emit())
	_confirmation.visibility_changed.connect(func() -> void: modal_visibility_changed.emit(_confirmation.visible))
	add_child(_confirmation)

func set_navigation(action: String) -> void:
	_current_navigation = action
	for id: String in _navigation_buttons:
		var button: Button = _navigation_buttons[id]
		var selected := id == action
		if button.button_pressed != selected: button.set_pressed_no_signal(selected)
	if is_instance_valid(_title):
		var text: String = TITLES.get(action, action.to_upper())
		if _title.text != text: _title.text = text

func set_clock(text: String, speed: int, planning_text: String) -> void:
	_clock_text = text
	_planning_text = planning_text
	_current_speed = speed
	if is_instance_valid(_clock) and _clock.text != text:
		_clock.text = text
		_clock.tooltip_text = text
	if is_instance_valid(_planning):
		if _planning.text != planning_text:
			_planning.text = planning_text
			_planning.tooltip_text = planning_text
		var has_planning := not planning_text.is_empty()
		if _planning.visible != has_planning: _planning.visible = has_planning
	for value: int in _speed_buttons:
		var button: Button = _speed_buttons[value]
		if button.button_pressed != (value == speed): button.set_pressed_no_signal(value == speed)

func set_requisition(amount: float) -> void:
	_requisition_text = ("%.0f" if is_equal_approx(amount, roundf(amount)) else "%.1f") % amount + " REQ"
	if is_instance_valid(_requisition) and _requisition.text != _requisition_text:
		_requisition.text = _requisition_text
		_requisition.tooltip_text = "Requisition available: %s\nPurchase quotes include transport fees before commitment." % ("%.2f" % amount)
