extends Control
## Each review owns independent declared state. Selectors preserve G01/G02 flows.

const SCENES := [preload("res://game/terrain/terrain_demo.tscn"), preload("res://game/procurement/receiving_demo.tscn"), preload("res://game/identity/identity_demo.tscn")]
var _review: Control
var _host: Control


func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var selector := OptionButton.new()
	for title in ["G08 Terrain & sight (draft)", "G02 Terminal & Receiving", "G01 Identity & accounting"]: selector.add_item(title)
	selector.item_selected.connect(_select)
	layout.add_child(selector)
	_host = Control.new()
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_host)
	_select(0)


func _select(index: int) -> void:
	if is_instance_valid(_review):
		_host.remove_child(_review)
		_review.queue_free()
	_review = SCENES[index].instantiate()
	_host.add_child(_review)
