extends AcceptDialog
## Scene-owned debug UI. Buttons emit commands; no timers or model polling.
signal action_requested(action: String)
const UI = preload("res://game/ui/ui_kit.gd")
var result_label: Label
var buttons: Dictionary = {}
const START_MESSAGE := "Debug deliveries appear beside the Supply Table. No time is skipped."

func _ready() -> void:
	title = "Debug tools"
	exclusive = true
	wrap_controls = false
	size = Vector2i(600,460)
	min_size = Vector2i(600,440)
	get_ok_button().text = "Close"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540,320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var layout := UI.column(scroll,true)
	UI.label(layout,"Prototype cheats · using these marks the current session DEBUG.",14,UI.ACCENT,true)
	_add_action(layout,"force_deliver","Force deliver now","Immediately finish pending incoming resource orders, including unloading.")
	_add_action(layout,"instant_build","Instant build","Complete all pending rear-base buildings without waiting for materials or labour.")
	_add_action(layout,"infinite_resources","Infinite resources (+1,000 each)","One free, immediately delivered batch of all nine raw resources per click.")
	result_label = UI.label(layout,START_MESSAGE,13,UI.MUTED,true)

func _add_action(layout: Node, action: String, text: String, description: String) -> void:
	buttons[action] = UI.button(layout,text,func() -> void: action_requested.emit(action))
	UI.label(layout,description,13,UI.MUTED,true)

func show_result(result: Dictionary) -> void:
	result_label.text = str(result.get("message","Debug action finished."))
	result_label.modulate = Color.WHITE if result.get("ok",false) else Color("ff817c")

func reset_feedback() -> void:
	hide()
	result_label.text = START_MESSAGE
	result_label.modulate = Color.WHITE
