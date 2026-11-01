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
	for action in [["Build", "Build"], ["Workers / Jobs", "Workers/Jobs"], ["Supplies", "Supplies"]]:
		var shortcut := Button.new()
		shortcut.text = action[0]
		var panel_title: String = action[1]
		shortcut.pressed.connect(func() -> void:
			_base.show_panel(panel_title)
			_show_base())
		controls.add_child(shortcut)
	var supply_button := Button.new()
	supply_button.text = "Army supply"
	supply_button.tooltip_text = "Open forward deliveries and the army's actual supply needs."
	supply_button.pressed.connect(_show_supply)
	controls.add_child(supply_button)
	var field_button := Button.new()
	field_button.text = "Battlefield"
	field_button.pressed.connect(_show_battlefield)
	controls.add_child(field_button)
	var playtest := Button.new()
	playtest.text = "New game"
	playtest.tooltip_text = "Start a fresh paused field with 2500 requisition, 500 Building Materials and no hired workers."
	playtest.pressed.connect(_start_playtest)
	controls.add_child(playtest)
	_field_clock = HBoxContainer.new()
	controls.add_child(_field_clock)
	for speed in [0,1,2]:
		var button := Button.new()
		button.text = ["Pause","1x","2x"][speed]
		button.pressed.connect(func() -> void:
			_base.simulation.set_speed(speed)
			_refresh_clock())
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
	var help_button := Button.new()
	help_button.text = "Getting started"
	help_button.toggle_mode = true
	help_button.button_pressed = true
	controls.add_child(help_button)
	var help := PanelContainer.new()
	layout.add_child(help)
	var guide := Label.new()
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.text = "Build your base and manage its workers. Start with 2500 requisition and 500 Building Materials on an empty rear field.\nUse 1x to begin and WASD to move your character. Supplies lets you buy the first eight workers for 140 requisition; arrival takes 90 seconds. Build places facilities; Workers / Jobs allocates actual people to work.\nRear base and Battlefield share one session. The army acts autonomously. Automatic onward supply is still being connected; the Army supply panel is the existing manual prototype. New game replaces the session."
	help.add_child(guide)
	help_button.toggled.connect(func(open: bool) -> void: help.visible = open)
	_host = Control.new()
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_host)
	_base = Base.instantiate()
	_host.add_child(_base)
	_base.use_shared_clock()
	_base.session_changed.connect(_on_session_changed)
	_battlefield = Battlefield.instantiate()
	_battlefield.simulation = _base.simulation
	_host.add_child(_battlefield)
	# Launch and New game share the approved empty rear opening; battlefield
	# forces remain authored by the scenario, independent of the rear workforce.
	_start_playtest()


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
	_field_clock.show()
	_battlefield.hide()
	_base.show()
	_refresh_clock()

func _show_supply() -> void:
	_base.show_panel("Supply")
	_show_base()


func _show_battlefield() -> void:
	_clear_review()
	_field_clock.show()
	_base.hide()
	_battlefield.show()
	_refresh_clock()


func _clear_review() -> void:
	if is_instance_valid(_review):
		_host.remove_child(_review)
		_review.queue_free()
	_review = null


func _on_session_changed(next_simulation: RefCounted) -> void:
	_battlefield.bind(next_simulation)
	_refresh_clock()

func _start_playtest() -> void:
	_base.hide()
	_base.start_empty_field_session(false)
	_show_base()

func _process(_delta: float) -> void:
	if is_instance_valid(_base) and _field_clock.visible:
		_refresh_clock()

func _refresh_clock() -> void:
	_clock_status.text = _base.clock_text()
