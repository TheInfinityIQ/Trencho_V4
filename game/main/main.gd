extends Control
## Keep the live session in the tree while the player changes views.

const REVIEWS: Dictionary = {
	"G24 Vehicle recovery": preload("res://game/vehicle_recovery/recovery_demo.tscn"),
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
	"G20 Bridges & traversal": preload("res://game/bridges/bridge_demo.tscn"),
	"G22 Mines and clearance": preload("res://game/mines/mine_demo.tscn"),
	"G21 Bridge denial": preload("res://game/bridges/demolition_demo.tscn"),
}
var _host: Control
var _base: Control
var _battlefield: Control
var _review: Control
var _diagnostics: Control
var _diagnostic_button: Button
var _field_clock: HBoxContainer
var _clock_status: Label
const Base = preload("res://game/rear_base/base_demo.tscn")
const Battlefield = preload("res://game/battlefield/battlefield_view.tscn")


func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var controls := HFlowContainer.new()
	layout.add_child(controls)
	var home := Button.new()
	home.text = "Rear base"
	home.tooltip_text = "Return to the same live rear session."
	home.pressed.connect(_show_base)
	controls.add_child(home)
	var field_button := Button.new()
	field_button.text = "Battlefield"
	field_button.pressed.connect(_show_battlefield)
	controls.add_child(field_button)
	var playtest := Button.new()
	playtest.text = "New playtest"
	playtest.tooltip_text = "Start a fresh paused Farmland and Towns opening with its declared armies."
	playtest.pressed.connect(_start_playtest)
	controls.add_child(playtest)
	_field_clock = HBoxContainer.new()
	controls.add_child(_field_clock)
	for speed in [0,1,2]:
		var button := Button.new()
		button.text = ["Pause","1x","2x"][speed]
		button.pressed.connect(func() -> void: _base.simulation.set_speed(speed))
		_field_clock.add_child(button)
	_clock_status = Label.new()
	_field_clock.add_child(_clock_status)
	_diagnostic_button = Button.new()
	_diagnostic_button.text = "Diagnostics"
	_diagnostic_button.toggle_mode = true
	controls.add_child(_diagnostic_button)
	_diagnostics = HFlowContainer.new()
	_diagnostics.hide()
	layout.add_child(_diagnostics)
	_diagnostic_button.toggled.connect(func(open: bool) -> void: _diagnostics.visible = open)
	for title in REVIEWS:
		var button := Button.new()
		button.text = title
		button.pressed.connect(func() -> void: _show_review(title))
		_diagnostics.add_child(button)
	_host = Control.new()
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_host)
	_base = Base.instantiate()
	_host.add_child(_base)
	_base.session_changed.connect(_on_session_changed)
	_battlefield = Battlefield.instantiate()
	_battlefield.simulation = _base.simulation
	_host.add_child(_battlefield)
	_show_base()


func _show_review(title: String) -> void:
	_clear_review()
	_field_clock.hide()
	_diagnostic_button.set_pressed_no_signal(false)
	_diagnostics.hide()
	_base.hide()
	_battlefield.hide()
	_review = REVIEWS[title].instantiate()
	_host.add_child(_review)
	_host.move_child(_review, 0)


func _show_base() -> void:
	_clear_review()
	_field_clock.hide()
	_battlefield.hide()
	_base.show()


func _show_battlefield() -> void:
	_clear_review()
	_field_clock.show()
	_base.hide()
	_battlefield.show()


func _clear_review() -> void:
	if is_instance_valid(_review):
		_host.remove_child(_review)
		_review.queue_free()
	_review = null


func _on_session_changed(next_simulation: RefCounted) -> void:
	_battlefield.bind(next_simulation)

func _start_playtest() -> void:
	_base.hide()
	_base.scenario.select(2)
	_base._start_session(false)
	_show_battlefield()

func _process(_delta: float) -> void:
	if is_instance_valid(_base) and _field_clock.visible:
		_clock_status.text = "  %.1f s · %s" % [_base.simulation.rear.time,"Paused" if _base.simulation.speed == 0 else "%dx" % _base.simulation.speed]
