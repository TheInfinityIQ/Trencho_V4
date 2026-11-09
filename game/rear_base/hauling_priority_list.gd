extends VBoxContainer
signal result_reported(result: Dictionary)
const Row = preload("res://game/rear_base/hauling_priority_row.gd")
const Policy = preload("res://game/staffing/hauling_policy.gd")
const UIKit = preload("res://game/ui/ui_kit.gd")
var simulation: RefCounted
var draft: Array[String] = []
var _committed: Array[String] = []
var _selected := ""
var _dragging := false
var assigned_count := 0
var _toggle: Button
var _body: VBoxContainer
var _rows: VBoxContainer
var _status: Label
var _activity: Label
var _confirm: Button
var _revert: Button
var _up: Button
var _down: Button

func _ready() -> void:
	_toggle = Button.new()
	_toggle.toggle_mode = true
	_toggle.text = "▸ Hauling"
	add_child(_toggle)
	_body = VBoxContainer.new()
	add_child(_body)
	_body.hide()
	_toggle.toggled.connect(func(open: bool) -> void: _body.visible = open; _update_header())
	UIKit.label(_body,"New workers start in Hauling after joining the rear. Explicit facility and crew jobs take precedence.",14,UIKit.MUTED,true)
	UIKit.label(_body,"Task order — highest priority at the top",15)
	_rows = VBoxContainer.new()
	_body.add_child(_rows)
	for id: String in Policy.DEFAULT_ORDER:
		var row := Row.new()
		row.setup(id,Policy.LABELS[id])
		row.selected.connect(_select)
		row.moved.connect(reorder)
		row.drag_state.connect(func(active: bool) -> void: _dragging = active)
		_rows.add_child(row)
	var actions := HBoxContainer.new()
	_body.add_child(actions)
	_up = _button(actions,"Move up",func() -> void: _move_selected(-1))
	_down = _button(actions,"Move down",func() -> void: _move_selected(1))
	_confirm = _button(_body,"Confirm hauling priorities",_apply)
	_revert = _button(_body,"Revert changes",discard_draft)
	_status = UIKit.label(_body,"",14,UIKit.ACCENT,true)
	_activity = UIKit.label(_body,"",14,UIKit.MUTED,true)
	UIKit.label(_body,"Workers take the next feasible task. Blocked tasks are skipped; active carries finish safely.",14,UIKit.MUTED,true)
	if simulation != null: discard_draft()

func bind(model: RefCounted) -> void:
	simulation = model
	_dragging = false
	if is_node_ready(): discard_draft()

func refresh(view: Dictionary) -> void:
	if not is_node_ready() or simulation == null: return
	var actual: Array[String] = simulation.rear.hauling_policy.order
	if draft == _committed and not _dragging and actual != _committed: discard_draft()
	var counts: Dictionary = {}
	for person: Dictionary in view.rear.people:
		if person.get("duty_id","") != "hauling" or not simulation.rear.actors.has(person.id): continue
		var actor: Dictionary = simulation.rear.actors[person.id]
		var phase: String = actor.phase
		if phase == "Unloading": phase = str(view.receiving.workers.get(person.id,{}).get("job",{}).get("phase",phase))
		counts[phase] = int(counts.get(phase,0))+1
	var lines: Array[String] = []
	for phase: String in counts: lines.append("%s: %d" % [phase,counts[phase]])
	_activity.text = " · ".join(lines) if not lines.is_empty() else "No hauling workers have joined yet."
	_update_header()

func _update_header() -> void:
	if simulation == null: return
	_toggle.text = ("▾" if _body.visible else "▸")+" Hauling · %d assigned" % assigned_count

func discard_draft() -> void:
	if simulation == null: return
	_committed = simulation.rear.hauling_policy.order.duplicate()
	draft = _committed.duplicate()
	_selected = draft[0]
	_render_order()

func reorder(source: String, target: String, after: bool) -> void:
	if source not in draft or target not in draft or source == target: return
	draft.erase(source)
	draft.insert(draft.find(target)+(1 if after else 0),source)
	_selected = source
	_render_order()

func _render_order() -> void:
	for index in draft.size():
		for row: Node in _rows.get_children():
			if row.task_id != draft[index]: continue
			_rows.move_child(row,index)
			row.caption.text = "%d  %s" % [index+1,Policy.LABELS[draft[index]]]
	_update_actions()

func _select(id: String) -> void:
	_selected = id
	_update_actions()

func _move_selected(direction: int) -> void:
	var index := draft.find(_selected)
	var next := index+direction
	if index < 0 or next < 0 or next >= draft.size(): return
	reorder(_selected,draft[next],direction > 0)

func _update_actions() -> void:
	var index := draft.find(_selected)
	_up.disabled = index <= 0
	_down.disabled = index < 0 or index >= draft.size()-1
	_confirm.disabled = draft == _committed
	_revert.disabled = draft == _committed
	_status.text = "Unconfirmed changes" if draft != _committed else "Confirmed order · top is highest"

func _apply() -> void:
	var result: Dictionary = simulation.rear.set_hauling_priorities(draft.duplicate())
	if result.ok: discard_draft()
	else: _status.text = str(result.message)
	result_reported.emit(result)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _body.visible or not event is InputEventKey or not event.pressed or event.echo: return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null or not is_ancestor_of(focus): return
	if event.alt_pressed and event.keycode in [KEY_UP,KEY_DOWN]:
		_move_selected(-1 if event.keycode == KEY_UP else 1)
		get_viewport().set_input_as_handled()

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button
