extends VBoxContainer
## Scene-owned navigation guidance; the current session remains the state owner.
signal action_requested(action: String)
const Guidance = preload("res://game/ui/demo_guidance.gd")
const UI = preload("res://game/ui/ui_kit.gd")
var view: Dictionary = {}
var _session: Node
var _logistics: Node
var _dirty := true
var _queued := false
var _summary: Label
var _reason: Label
var _primary: Button
var _overview: Button
var _army_status: Label

func _ready() -> void:
	UI.label(self,"Suggested next action",18)
	_reason = UI.label(self,"",14,UI.MUTED,true)
	_primary = UI.button(self,"Open next step",_request_next,true)
	_primary.disabled = true
	_army_status = UI.label(self,"",12,UI.MUTED,true)
	_overview = UI.button(self,"Show preparation overview",_toggle_overview)
	_summary = UI.label(self,"",13,UI.MUTED,true)
	_summary.hide()
	var links := UI.row(self)
	UI.button(links,"Training",func() -> void: action_requested.emit("Train"))
	UI.button(links,"Vehicles",func() -> void: action_requested.emit("Vehicles"))
	UI.button(links,"Army needs",func() -> void: action_requested.emit("ArmyNeeds"))
	visibility_changed.connect(_invalidate)
	_invalidate()

func bind(session: Node) -> void:
	_disconnect()
	_session = session
	_clear()
	if is_instance_valid(_session):
		_session.state_changed.connect(_invalidate)
		_session.simulation_changed.connect(_replaced)
		_logistics = _session.automatic_logistics
		if is_instance_valid(_logistics): _logistics.changed.connect(_invalidate)
	_invalidate()

func _disconnect() -> void:
	if is_instance_valid(_session):
		if _session.state_changed.is_connected(_invalidate): _session.state_changed.disconnect(_invalidate)
		if _session.simulation_changed.is_connected(_replaced): _session.simulation_changed.disconnect(_replaced)
	if is_instance_valid(_logistics) and _logistics.changed.is_connected(_invalidate): _logistics.changed.disconnect(_invalidate)
	_logistics = null

func _exit_tree() -> void:
	_disconnect()
	_session = null

func _clear() -> void:
	view = {}
	if is_instance_valid(_primary): _primary.disabled = true
	if is_instance_valid(_summary): _summary.text = ""
	if is_instance_valid(_reason): _reason.text = ""
	if is_instance_valid(_army_status): _army_status.text = ""

func _replaced(_model: RefCounted) -> void:
	_clear()
	_invalidate()

func _invalidate() -> void:
	_dirty = true
	if is_instance_valid(_primary): _primary.disabled = true
	if _queued or not is_inside_tree() or not is_visible_in_tree() or not is_instance_valid(_session): return
	_queued = true
	_refresh.call_deferred()

func _refresh() -> void:
	_queued = false
	if not _dirty or not is_inside_tree() or not is_visible_in_tree() or not is_instance_valid(_session): return
	_dirty = false
	view = Guidance.view(_session)
	if view.is_empty():
		_clear()
		return
	var lines: Array[String] = []
	for row in view.milestones: lines.append("%s: %s" % [row.title,row.detail])
	_summary.text = "\n".join(lines)
	_reason.text = str(view.next_action.reason)
	_army_status.text = str(view.army_status)
	_primary.text = str(view.next_action.label)
	_primary.disabled = str(view.next_action.panel).is_empty()

func _request_next() -> void:
	# Re-read after a committed event, including a click before deferred refresh.
	if not is_instance_valid(_session): return
	var current := Guidance.view(_session)
	if current.is_empty(): return
	var destination := str(current.next_action.panel)
	if not destination.is_empty(): action_requested.emit(destination)

func _toggle_overview() -> void:
	_summary.visible = not _summary.visible
	_overview.text = "Hide preparation overview" if _summary.visible else "Show preparation overview"
