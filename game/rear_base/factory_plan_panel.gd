extends VBoxContainer
## Scene-owned presentation; the session remains the only model owner.
signal action_requested(action: Dictionary)
const Plan = preload("res://game/rear_base/factory_plan.gd")
const UIKit = preload("res://game/ui/ui_kit.gd")
var view: Dictionary = {}
var _session: Node
var _dirty := true
var _queued := false
var _summary: Label
var _hint: Label
var _action: Button

func _ready() -> void:
	UIKit.label(self, "Guided factory task", 18)
	_summary = UIKit.label(self, "", 14, UIKit.INK, true)
	_hint = UIKit.label(self, "", 14, UIKit.MUTED, true)
	_action = UIKit.button(self, "Open next step", func() -> void: action_requested.emit(view.get("next_action", {}).duplicate(true)), true)
	_action.disabled = true
	visibility_changed.connect(_invalidate)
	_invalidate()

func bind(session: Node) -> void:
	_disconnect_session()
	_session = session
	view = {}
	if _action != null: _action.disabled = true
	if _session != null:
		_session.state_changed.connect(_invalidate)
		_session.simulation_changed.connect(_simulation_changed)
	_invalidate()

func _disconnect_session() -> void:
	if not is_instance_valid(_session): return
	if _session.state_changed.is_connected(_invalidate): _session.state_changed.disconnect(_invalidate)
	if _session.simulation_changed.is_connected(_simulation_changed): _session.simulation_changed.disconnect(_simulation_changed)

func _exit_tree() -> void:
	_disconnect_session()
	_session = null

func _simulation_changed(_simulation: RefCounted) -> void:
	view = {}
	if _action != null: _action.disabled = true
	_invalidate()

func _invalidate() -> void:
	_dirty = true
	if _queued or not is_inside_tree() or not is_visible_in_tree() or not is_instance_valid(_session): return
	_queued = true
	_refresh.call_deferred()

func _refresh() -> void:
	_queued = false
	if not _dirty or not is_inside_tree() or not is_visible_in_tree() or not is_instance_valid(_session): return
	_dirty = false
	view = Plan.view(_session.simulation)
	var lines: Array[String] = []
	var names := {"todo":"To do", "active":"In progress — see cause below", "complete":"Done"}
	for step in view.steps:
		lines.append("%s: %s" % [step.get("title",step.id),names[step.status]])
	for kind in view.facilities:
		var site: Dictionary = view.facilities[kind]
		if site.has("stored_output"):
			lines.append("Currently stored: %d %s" % [site.stored_output,"Building Materials" if kind == "materials" else "rifle rounds"])
	_summary.text = "\n".join(lines)
	_hint.text = str(view.next_action.reason)
	_action.text = str(view.next_action.label)
	_action.disabled = view.complete
