extends Control
## Scene-owned review selector; each bounded review has its own declared state/clock.

const REVIEWS: Dictionary = {
	"G03 Staffing & hauling": preload("res://game/staffing/rear_demo.tscn"),
	"G04 R01 Production": preload("res://game/production/production_demo.tscn"),
	"G04 R02 Munitions": preload("res://game/production/munitions_demo.tscn"),
	"G04 R26 Materials": preload("res://game/production/materials_demo.tscn"),
	"G08 Terrain & sight": preload("res://game/terrain/terrain_demo.tscn"),
	"G02 Procurement": preload("res://game/procurement/receiving_demo.tscn"),
	"G01 Identity": preload("res://game/identity/identity_demo.tscn"),
}
var _host: Control


func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var controls := HFlowContainer.new()
	layout.add_child(controls)
	for title in REVIEWS:
		var button := Button.new()
		button.text = title
		button.pressed.connect(func() -> void: _show_review(title))
		controls.add_child(button)
	var note := Label.new()
	note.text = "Switching review resets its declared fixture."
	controls.add_child(note)
	_host = Control.new()
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_host)
	_show_review("G03 Staffing & hauling")


func _show_review(title: String) -> void:
	for child in _host.get_children():
		_host.remove_child(child)
		child.queue_free()
	_host.add_child(REVIEWS[title].instantiate())
