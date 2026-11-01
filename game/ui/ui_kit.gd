extends RefCounted
## Presentation tokens and native Control factories. No game state or clocks.

const BG := Color("0c1113")
const PANEL := Color("151e21")
const RAISED := Color("1d292d")
const BORDER := Color("344347")
const INK := Color("edf0e7")
const MUTED := Color("a1b0b0")
const ACCENT := Color("e8b96b")
const GOOD := Color("8bd0b3")
const BAD := Color("ed8e7e")

static func style(color: Color, edge: Color = BORDER, padding: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	for type: String in ["Label", "Button", "LineEdit", "SpinBox", "OptionButton", "ItemList", "Tree", "PopupMenu", "CheckBox", "CheckButton"]:
		result.set_color("font_color", type, INK)
		result.set_color("font_disabled_color", type, MUTED)
	result.set_constant("separation", "VBoxContainer", 8)
	result.set_constant("separation", "HBoxContainer", 8)
	result.set_stylebox("panel", "PanelContainer", style(PANEL))
	for type: String in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, style(RAISED, BORDER, 10))
		result.set_stylebox("hover", type, style(Color("2b3a3d"), ACCENT, 10))
		result.set_stylebox("pressed", type, style(Color("394136"), ACCENT, 10))
		result.set_stylebox("disabled", type, style(PANEL, Color("263235"), 10))
		result.set_stylebox("focus", type, style(Color(0, 0, 0, 0), ACCENT, 0))
	result.set_type_variation("Primary", "Button")
	result.set_stylebox("normal", "Primary", style(ACCENT, ACCENT, 10))
	result.set_stylebox("hover", "Primary", style(Color("f4ca85"), ACCENT, 10))
	result.set_stylebox("pressed", "Primary", style(Color("c59a57"), ACCENT, 10))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		result.set_color(state, "Primary", BG)
	result.set_stylebox("normal", "LineEdit", style(BG, BORDER, 8))
	result.set_stylebox("focus", "LineEdit", style(BG, ACCENT, 8))
	result.set_stylebox("read_only", "LineEdit", style(PANEL, BORDER, 8))
	result.set_color("caret_color", "LineEdit", ACCENT)
	result.set_stylebox("background", "ProgressBar", style(BG, BG, 0))
	result.set_stylebox("fill", "ProgressBar", style(GOOD, GOOD, 0))
	for type: String in ["ItemList", "Tree"]:
		result.set_stylebox("panel", type, style(BG, BORDER, 8))
		result.set_stylebox("focus", type, style(Color(0, 0, 0, 0), ACCENT, 0))
		result.set_stylebox("selected", type, style(Color("394136"), ACCENT, 6))
		result.set_stylebox("selected_focus", type, style(Color("394136"), ACCENT, 6))
		result.set_color("font_selected_color", type, INK)
	result.set_stylebox("panel", "PopupMenu", style(RAISED, BORDER, 8))
	result.set_stylebox("hover", "PopupMenu", style(Color("394136"), ACCENT, 8))
	result.set_stylebox("panel", "PopupPanel", style(PANEL))
	result.set_stylebox("panel", "AcceptDialog", style(PANEL, BORDER, 20))
	result.set_stylebox("panel", "TooltipPanel", style(RAISED, ACCENT, 12))
	result.set_color("font_color", "TooltipLabel", INK)
	result.set_font_size("font_size", "TooltipLabel", 14)
	result.set_stylebox("panel", "TabContainer", style(PANEL, BORDER, 8))
	return result

static func label(parent: Node, text: String, font_size: int = 14, color: Color = INK, wrap: bool = false) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	if wrap:
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(item)
	return item

static func button(parent: Node, text: String, action: Callable, primary: bool = false) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 38
	if primary:
		item.theme_type_variation = "Primary"
	item.pressed.connect(action)
	parent.add_child(item)
	return item

static func column(parent: Node, expand: bool = false) -> VBoxContainer:
	var box := VBoxContainer.new()
	if expand:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box

static func row(parent: Node) -> HBoxContainer:
	var box := HBoxContainer.new()
	parent.add_child(box)
	return box

static func card(parent: Node, expand: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	if expand:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return column(panel)
