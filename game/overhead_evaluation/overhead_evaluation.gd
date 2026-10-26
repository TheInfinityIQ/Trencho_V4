extends Control
## Optional authored presentation sample; no authoritative game simulation.

const MapCanvas = preload("res://game/overhead_evaluation/sample_map.gd")
const EXTENT := Vector2(4000, 6000)
const SAMPLES: Array[Dictionary] = [
	{"id": "sample-f04-01", "name": "F04 Workshop", "position": Vector2(1000, 3000), "size": Vector2(16, 12), "ground": 2.0, "cargo": 0, "reference": false},
	{"id": "sample-t02-01", "name": "T02 Transport", "position": Vector2(1017, 3010), "size": Vector2(6.8, 2.5), "ground": 2.0, "cargo": 100, "reference": false},
	{"id": "sample-person-01", "name": "Person reference", "position": Vector2(1010, 3010), "size": Vector2(1, 1), "ground": 2.0, "cargo": 0, "reference": true},
]
var view_name := "Close"
var text_scale := 1.0
var selected_id := ""
var canvas: Control
var _inspection: Label
var _camera_label: Label


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("101820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	_label(layout, "D01 / 2D overhead evaluation", 26)
	_label(layout, "Authored reference sample · full 4,000 × 6,000 m extent · same identities, physical dimensions and supplies at every zoom", 15)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	layout.add_child(bar)
	for title in ["Close", "Intermediate", "6 km overview"]:
		_button(bar, title, func() -> void: view_name = title; _refresh())
	for factor in [1.0, 1.5]:
		_button(bar, "Text %d%%" % (factor * 100), func() -> void: text_scale = factor; _scale_text(self); _refresh())
	_camera_label = _label(layout, "", 14)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 20)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(split)
	canvas = MapCanvas.new()
	canvas.model = self
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.resized.connect(_refresh)
	split.add_child(canvas)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 330
	split.add_child(panel)
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: padding.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(padding)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	padding.add_child(info)
	_label(info, "SELECTED SAMPLE", 15)
	_inspection = _label(info, "", 16)
	_label(info, "HEIGHT KEY", 15)
	_label(info, "Ground +2 m\nBridge deck +8 m\nClearance 6 m\nRidge +12 m\nRise 10 m / 50 m = 11.3°", 15)
	_label(info, "Authored bridge / ridge only. No sight, traversal or construction simulation.", 14)
	_label(info, "Person square: D02 reference, not a hitbox. T02 / F04: GDD footprints.", 14)
	_label(layout, "Overview badges and leader lines are visual aids, not enlarged physical footprints. Only these declared friendly samples exist; zoom reveals no enemies.", 14)
	resized.connect(_refresh)
	_refresh()


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_meta("base_font_size", font_size)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.set_meta("base_font_size", 14)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	parent.add_child(button)


func _scale_text(node: Node) -> void:
	if node is Control and node.has_meta("base_font_size"):
		node.add_theme_font_size_override("font_size", roundi(node.get_meta("base_font_size") * text_scale))
	for child in node.get_children(): _scale_text(child)


func camera() -> Dictionary:
	var ppm := 12.0 if view_name == "Close" else 1.0
	var centre := Vector2(1020, 3000)
	if view_name == "6 km overview":
		centre = EXTENT / 2.0
		ppm = minf((canvas.size.x - 90.0) / EXTENT.x, (canvas.size.y - 90.0) / EXTENT.y)
	return {"centre": centre, "pixels_per_metre": ppm}


func screen_for(position: Vector2) -> Vector2:
	var view := camera()
	return canvas.size / 2.0 + (position - view.centre) * view.pixels_per_metre


func select_sample(id: String) -> void:
	selected_id = id
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(canvas) or not is_instance_valid(_inspection): return
	var view := camera()
	_camera_label.text = "%s · %.4f px/m · camera (%.1f, %.1f) m · text %d%% · x → / y ↓" % [view_name, view.pixels_per_metre, view.centre.x, view.centre.y, text_scale * 100]
	_inspection.text = "Click a footprint or its badge to inspect."
	for item in SAMPLES:
		if item.id == selected_id:
			_inspection.text = "%s\n%s\nPosition %.1f, %.1f m\nFootprint %.1f × %.1f m\nGround +%.1f m / %d M01" % [item.name, item.id, item.position.x, item.position.y, item.size.x, item.size.y, item.ground, item.cargo]
	canvas.queue_redraw()


func physical_snapshot() -> Dictionary:
	return {"extent": EXTENT, "samples": SAMPLES.duplicate(true), "bridge_ground": 2.0, "bridge_deck": 8.0, "ridge_height": 12.0}


func render_metadata() -> Dictionary:
	var view := camera()
	var samples: Array = []
	for item in SAMPLES:
		samples.append({"id": item.id, "position_m": [item.position.x, item.position.y], "footprint_m": [item.size.x, item.size.y], "ground_m": item.ground, "M01": item.cargo, "person_reference_only": item.reference})
	return {"kind": "Godot CI render, not Windows native evidence", "view": view_name, "camera_centre_m": [view.centre.x, view.centre.y], "pixels_per_metre": view.pixels_per_metre, "selected_id": selected_id, "text_scale": text_scale, "extent_m": [4000, 6000], "samples": samples, "height_demo_m": {"ground": 2, "deck": 8, "ridge": 12, "rise": 10, "run": 50}, "map_rect_px": [canvas.global_position.x, canvas.global_position.y, canvas.size.x, canvas.size.y]}
