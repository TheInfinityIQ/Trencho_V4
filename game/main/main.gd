extends Control
## Scene-owned review selector; each bounded review has its own declared state/clock.

const REVIEWS: Dictionary = {
	"G03 Staffing & hauling": preload("res://game/staffing/rear_demo.tscn"),
	"G04 R01 Production": preload("res://game/production/production_demo.tscn"),
	"G04 R02 Munitions": preload("res://game/production/munitions_demo.tscn"),
	"G04 R27 Explosives": preload("res://game/production/explosives_demo.tscn"),
	"G04 R26 Materials": preload("res://game/production/materials_demo.tscn"),
	"G04 R32 Chain": preload("res://game/production/r32_chain_demo.tscn"),
	"G04 R33 Chain": preload("res://game/production/r33_chain_demo.tscn"),
	"G08 Terrain & sight": preload("res://game/terrain/terrain_demo.tscn"),
	"G02 Procurement": preload("res://game/procurement/receiving_demo.tscn"),
	"G01 Identity": preload("res://game/identity/identity_demo.tscn"),
	"G16 Combat & care": preload("res://game/combat/combat_demo.tscn"),
	"G17 Orders & information": preload("res://game/orders/order_demo.tscn"),
	"G18 Objectives & income": preload("res://game/objectives/objective_demo.tscn"),
	"G19 Field structures & roads": preload("res://game/field_structures/field_demo.tscn"),
}
var _host: Control
var _base: Control
const Base = preload("res://game/rear_base/base_demo.tscn")


func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var controls := HFlowContainer.new()
	layout.add_child(controls)
	var home := Button.new()
	home.text = "Rear base"
	home.tooltip_text = "Return to the same live base. Diagnostics reset their own fixtures; base time pauses while away."
	home.pressed.connect(_show_base)
	controls.add_child(home)
	for title in REVIEWS:
		var button := Button.new()
		button.text = title
		button.pressed.connect(func() -> void: _show_review(title))
		controls.add_child(button)
	_host = Control.new()
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_host)
	_show_base()


func _show_review(title: String) -> void:
	for child in _host.get_children():
		_host.remove_child(child)
		if child != _base: child.queue_free()
	_host.add_child(REVIEWS[title].instantiate())


func _show_base() -> void:
	for child in _host.get_children():
		_host.remove_child(child)
		if child != _base: child.queue_free()
	if not is_instance_valid(_base): _base = Base.instantiate()
	_host.add_child(_base)


func _exit_tree() -> void:
	if is_instance_valid(_base) and not _base.is_inside_tree(): _base.queue_free()
