extends Control
## The shell presents commands; the existing rear scene owns the live session.
const Shell = preload("res://game/ui/command_shell.gd")
const UIKit = preload("res://game/ui/ui_kit.gd")
const Base = preload("res://game/rear_base/base_demo.tscn")
const Battlefield = preload("res://game/battlefield/battlefield_view.tscn")
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
var _shell: Control
var _host: Control
var _base: Control
var _battlefield: Control
var _review: Control

func _ready() -> void:
	theme = UIKit.make_theme()
	_shell = Shell.new()
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shell)
	_host = _shell.content_host
	_base = Base.instantiate()
	_host.add_child(_base)
	_base.use_shared_navigation()
	_base.session_changed.connect(_on_session_changed)
	_battlefield = Battlefield.instantiate()
	_battlefield.simulation = _base.simulation
	_host.add_child(_battlefield)
	_shell.navigation_requested.connect(_navigate)
	_shell.speed_requested.connect(func(value: int) -> void:
		_base.simulation.set_speed(value)
		_refresh_clock())
	_shell.new_session_requested.connect(_start_playtest)
	_start_playtest()

func _navigate(action: String) -> void:
	match action:
		"Battlefield": _show_battlefield()
		"rear": _show_base()
		"ArmySupply": _show_supply()
		"Diagnostics": _show_diagnostics()
		_:
			if _base.show_panel(action): _show_base()

func _show_base() -> void:
	_clear_review()
	_battlefield.hide()
	_base.show()
	var panel: Control = _base.tabs.get_tab_control(_base.tabs.current_tab)
	var title: String = str(panel.get_meta("panel_title",panel.name))
	_shell.set_navigation("ArmySupply" if title == "Supply" else title)
	_refresh_clock()

func _show_supply() -> void:
	_base.show_panel("Supply")
	_show_base()

func _show_battlefield() -> void:
	_clear_review()
	_base.hide()
	_battlefield.show()
	_shell.set_navigation("Battlefield")
	_refresh_clock()

func _show_diagnostics() -> void:
	_clear_review()
	_base.hide()
	_battlefield.hide()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_review = scroll
	_host.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for title in REVIEWS:
		var button := Button.new()
		button.text = title
		button.pressed.connect(func() -> void: _show_review(title))
		list.add_child(button)
	_shell.set_navigation("Diagnostics")

func _show_review(title: String) -> void:
	_clear_review()
	_base.hide()
	_battlefield.hide()
	_review = REVIEWS[title].instantiate()
	_host.add_child(_review)
	_shell.set_navigation("Diagnostics")

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
	if is_instance_valid(_base): _refresh_clock()

func _refresh_clock() -> void:
	var session: RefCounted = _base.simulation
	_shell.set_clock("%.1f s" % session.rear.time,session.speed,session.planning_status_text())
	_shell.set_requisition(session.receiving.requisition_balance())
