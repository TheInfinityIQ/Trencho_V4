extends VBoxContainer
## Read-only, scene-owned presentation of the lead-supplied detached supply view.
signal action_requested(action: Dictionary)

const UIKit = preload("res://game/ui/ui_kit.gd")
const ACTION_LABELS := {
	"produce": "Inspect ammunition production", "build": "Build required facility",
	"workers": "Manage workers", "rear_requests": "View deliveries to HQ",
	"observe": "Observe selected recipient", "resume_automatic": "Resume automatic resupply",
}

var view: Dictionary = {}
var _session_ref: WeakRef
var _reader: Callable
var _connections: Array[Dictionary] = []
var _generation := 0
var _dirty := true
var _queued := false
var _built := false
var _title: Label
var _summary: Label
var _hold: Label
var _blockers: Label
var _recipients: OptionButton
var _recipient_detail: Label
var _recipient_ids: Array[String] = []
var _recipient_rows: Dictionary = {}
var _selected_recipient := ""
var _selection_initialized := false
var _actions_box: VBoxContainer
var _actions: Dictionary = {}
var _action_buttons: Dictionary = {}
var _stages_box: VBoxContainer
var _stage_rows: Array[Dictionary] = []
var _requests_box: VBoxContainer
var _request_rows: Dictionary = {}
var _requests_empty: Label

func _enter_tree() -> void:
	if _built:
		_connect_sources()
		_invalidate()

func _ready() -> void:
	var overview := UIKit.card(self, true)
	_title = UIKit.label(overview, "Army needs", 20, UIKit.INK, true)
	_summary = UIKit.label(overview, "Waiting for the current supply view.", 14, UIKit.MUTED, true)
	_hold = UIKit.label(overview, "", 14, UIKit.ACCENT, true)
	_hold.hide()
	_blockers = UIKit.label(overview, "", 14, UIKit.BAD, true)
	_blockers.hide()
	var recipients := UIKit.card(self, true)
	UIKit.label(recipients, "Follow a recipient", 14, UIKit.MUTED)
	_recipients = OptionButton.new()
	_recipients.custom_minimum_size.y = 38
	_recipients.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipients.fit_to_longest_item = false
	_recipients.clip_text = true
	_recipients.disabled = true
	_recipients.text = "No current recipient"
	_recipients.item_selected.connect(_on_recipient_selected)
	recipients.add_child(_recipients)
	_recipient_detail = UIKit.label(recipients, "", 14, UIKit.INK, true)
	_actions_box = UIKit.column(self, true)
	_stages_box = UIKit.card(self, true)
	UIKit.label(_stages_box, "Physical supply stages", 16)
	UIKit.label(_stages_box, "HQ receipt, forward delivery and recipient issue are separate milestones.", 14, UIKit.MUTED, true)
	_requests_box = UIKit.card(self, true)
	UIKit.label(_requests_box, "Rear requests · receipt at HQ", 16)
	_requests_empty = UIKit.label(_requests_box, "No rear requests reported.", 14, UIKit.MUTED, true)
	_built = true
	visibility_changed.connect(_on_visibility_changed)
	_connect_sources()
	_invalidate()

func bind(session: Node, reader: Callable) -> void:
	_disconnect_sources()
	_generation += 1
	_queued = false
	_session_ref = weakref(session) if is_instance_valid(session) else null
	_reader = reader
	_clear_current_view()
	if is_inside_tree(): _connect_sources()
	_invalidate()

func _current_session() -> Node:
	if _session_ref == null: return null
	var current: Object = _session_ref.get_ref()
	return current as Node if is_instance_valid(current) else null

func _connect_sources() -> void:
	var session := _current_session()
	if session == null: return
	_connect_signal(session, &"state_changed", _invalidate)
	_connect_signal(session, &"simulation_changed", _on_simulation_changed)
	var intent: Object = session.get("automatic_logistics")
	if is_instance_valid(intent): _connect_signal(intent, &"changed", _invalidate)

func _connect_signal(source: Object, signal_name: StringName, callback: Callable) -> void:
	if not source.has_signal(signal_name) or source.is_connected(signal_name, callback): return
	if source.connect(signal_name, callback) == OK:
		_connections.append({"source": weakref(source), "signal": signal_name, "callback": callback})

func _disconnect_sources() -> void:
	for connection: Dictionary in _connections:
		var source: Object = connection.source.get_ref()
		if is_instance_valid(source) and source.is_connected(connection.signal, connection.callback):
			source.disconnect(connection.signal, connection.callback)
	_connections.clear()

func _on_simulation_changed(_simulation: Variant = null) -> void:
	_disconnect_sources()
	_generation += 1
	_queued = false
	_clear_current_view()
	_connect_sources()
	_invalidate()

func _on_visibility_changed() -> void:
	_invalidate()

func _invalidate() -> void:
	_dirty = true
	if _queued or not _built or not is_inside_tree() or not is_visible_in_tree(): return
	if _current_session() == null or not _reader.is_valid(): return
	_queued = true
	_refresh.call_deferred(_generation)

func _refresh(generation: int) -> void:
	# An obsolete callback must not clear the pending flag of a newer binding.
	if generation != _generation: return
	_queued = false
	var session := _current_session()
	if not _dirty or not is_inside_tree() or not is_visible_in_tree() or session == null or not _reader.is_valid(): return
	_dirty = false
	var current: Variant = _reader.call(session)
	if generation != _generation or _current_session() != session or not is_inside_tree() or not is_visible_in_tree(): return
	if not current is Dictionary:
		_clear_current_view()
		_set_text(_summary, "Army needs are unavailable for the current session.")
		return
	view = current
	_render_view()

func _clear_current_view() -> void:
	view = {}
	_actions.clear()
	_recipient_rows.clear()
	_selected_recipient = ""
	_selection_initialized = false
	_dirty = true
	for button: Button in _action_buttons.values():
		button.disabled = true
		button.hide()
	if not _built: return
	_recipients.disabled = true
	_recipients.select(-1)
	_recipients.text = "Waiting for current recipients"
	_recipient_ids.clear()
	_set_text(_title, "Army needs")
	_set_text(_summary, "Waiting for the current supply view.")
	_set_text(_recipient_detail, "")
	_hold.hide()
	_blockers.hide()
	for controls: Dictionary in _stage_rows: controls.box.hide()
	for controls: Dictionary in _request_rows.values(): controls.box.hide()
	_set_text(_requests_empty, "Waiting for current rear requests.")
	_requests_empty.show()

func _render_view() -> void:
	_set_text(_title, str(view.get("title", "Army needs")))
	_set_text(_summary, str(view.get("summary", "No supply summary was reported.")))
	var held := bool(view.get("held", false))
	_hold.visible = held
	if held:
		_set_text(_hold, "Automatic rifle-ammunition resupply is on hold. Resuming clears the hold; previously cancelled requests stay cancelled.")
	var causes: PackedStringArray = []
	for cause: Variant in view.get("blockers", []):
		if not str(cause).is_empty(): causes.append("• " + str(cause))
	_set_text(_blockers, "\n".join(causes))
	_blockers.visible = not causes.is_empty()
	_sync_recipients(view.get("recipients", []))
	_sync_actions(view.get("actions", []))
	_sync_stages(view.get("stages", []))
	_sync_requests(view.get("requests", []))

func _sync_recipients(rows: Array) -> void:
	var ids: Array[String] = []
	_recipient_rows.clear()
	_recipients.set_block_signals(true)
	for row: Dictionary in rows:
		var id := str(row.get("id", ""))
		if id.is_empty() or _recipient_rows.has(id): continue
		var index := ids.size()
		ids.append(id)
		_recipient_rows[id] = row
		var text := str(row.get("label", "Reported recipient"))
		if index >= _recipients.item_count: _recipients.add_item(text)
		elif _recipients.get_item_text(index) != text: _recipients.set_item_text(index, text)
	while _recipients.item_count > ids.size(): _recipients.remove_item(_recipients.item_count - 1)
	_recipient_ids = ids
	if not _selection_initialized and not ids.is_empty():
		_selected_recipient = ids[0]
		_selection_initialized = true
	elif not _selected_recipient.is_empty() and not _recipient_rows.has(_selected_recipient):
		_selected_recipient = ""
	var selected := ids.find(_selected_recipient)
	if _recipients.selected != selected: _recipients.select(selected)
	_recipients.disabled = ids.is_empty()
	if selected < 0: _recipients.text = "No recipients reported" if ids.is_empty() else "Select a reported recipient"
	_recipients.set_block_signals(false)
	_render_recipient()

func _on_recipient_selected(index: int) -> void:
	if index < 0 or index >= _recipient_ids.size() or not _recipient_rows.has(_recipient_ids[index]): return
	_selected_recipient = _recipient_ids[index]
	_selection_initialized = true
	_render_recipient()
	_update_action_availability()

func _render_recipient() -> void:
	var row: Dictionary = _recipient_rows.get(_selected_recipient, {})
	var text := "Select a reported recipient to inspect its actual ammunition."
	if not row.is_empty():
		text = "Carried: %s · Reported need: %s\nCommitted to issue: %s · Remaining: %s" % [row.get("carried", "—"), row.get("needed", "—"), row.get("committed", "—"), row.get("remaining", "—")]
		var detail := str(row.get("detail", ""))
		if not detail.is_empty(): text += "\n" + detail
	_set_text(_recipient_detail, text)

func _sync_actions(rows: Array) -> void:
	_actions.clear()
	var position_index := 0
	for row: Dictionary in rows:
		var id := str(row.get("id", ""))
		if id.is_empty() or _actions.has(id): continue
		_actions[id] = row
		var button: Button = _action_buttons.get(id) as Button
		if not _action_buttons.has(id):
			button = UIKit.button(_actions_box, "", _activate_action.bind(id))
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_action_buttons[id] = button
		var text := str(row.get("label", ACTION_LABELS.get(id, "Inspect supply requirement")))
		if button.text != text: button.text = text
		button.theme_type_variation = "Primary" if id == "resume_automatic" and bool(view.get("held", false)) else ""
		button.show()
		if button.get_index() != position_index: _actions_box.move_child(button, position_index)
		position_index += 1
	for id: String in _action_buttons:
		if not _actions.has(id):
			_action_buttons[id].disabled = true
			_action_buttons[id].hide()
	_update_action_availability()

func _update_action_availability() -> void:
	for id: String in _action_buttons:
		var row := _current_action(id)
		var enabled := not _dirty and not row.is_empty() and bool(row.get("enabled", false))
		if id == "observe": enabled = enabled and _recipient_rows.has(_selected_recipient)
		_action_buttons[id].disabled = not enabled

func _current_action(id: String) -> Dictionary:
	for row: Dictionary in view.get("actions", []):
		if str(row.get("id", "")) == id: return row
	return {}

func _activate_action(id: String) -> void:
	if _dirty or not is_inside_tree() or not is_visible_in_tree() or _current_session() == null or not _reader.is_valid(): return
	var current := _current_action(id)
	if current.is_empty() or not bool(current.get("enabled", false)): return
	var action: Dictionary = current.duplicate(true)
	if id == "observe":
		if not _recipient_rows.has(_selected_recipient): return
		action.entity_id = _selected_recipient
	action_requested.emit(action)

func _sync_stages(rows: Array) -> void:
	for index in rows.size():
		if index >= _stage_rows.size():
			var box := UIKit.column(_stages_box, true)
			_stage_rows.append({"box": box, "label": UIKit.label(box, "", 14, UIKit.ACCENT, true), "quantity": UIKit.label(box, "", 14, UIKit.INK, true), "detail": UIKit.label(box, "", 14, UIKit.MUTED, true)})
		var controls: Dictionary = _stage_rows[index]
		var row: Dictionary = rows[index]
		controls.box.show()
		_set_text(controls.label, str(row.get("label", "Supply stage")))
		_set_text(controls.quantity, str(row.get("quantity_text", "Quantity unavailable")))
		_set_text(controls.detail, str(row.get("detail", "")))
		controls.detail.visible = not str(row.get("detail", "")).is_empty()
	for index in range(rows.size(), _stage_rows.size()): _stage_rows[index].box.hide()

func _sync_requests(rows: Array) -> void:
	var visible_ids: Dictionary = {}
	var position_index := 2
	for row: Dictionary in rows:
		var id := str(row.get("id", ""))
		if id.is_empty() or visible_ids.has(id): continue
		visible_ids[id] = true
		if not _request_rows.has(id):
			var box := UIKit.column(_requests_box, true)
			_request_rows[id] = {"box": box, "label": UIKit.label(box, "", 14, UIKit.ACCENT, true), "detail": UIKit.label(box, "", 14, UIKit.INK, true), "blocker": UIKit.label(box, "", 14, UIKit.MUTED, true)}
		var controls: Dictionary = _request_rows[id]
		controls.box.show()
		if controls.box.get_index() != position_index: _requests_box.move_child(controls.box, position_index)
		position_index += 1
		_set_text(controls.label, str(row.get("label", "Rear delivery request")))
		var cancellation := " · Cancellation requested" if bool(row.get("cancelled", false)) else ""
		_set_text(controls.detail, "%s%s\nUnloaded at HQ: %s / %s requested" % [row.get("state", "State unavailable"), cancellation, row.get("delivered", "—"), row.get("requested", "—")])
		_set_text(controls.blocker, str(row.get("blocker", "")))
		controls.blocker.visible = not str(row.get("blocker", "")).is_empty()
	for id: String in _request_rows:
		if not visible_ids.has(id): _request_rows[id].box.hide()
	_set_text(_requests_empty, "No rear requests reported.")
	_requests_empty.visible = visible_ids.is_empty()

func _set_text(label: Label, text: String) -> void:
	if label.text != text: label.text = text

func _exit_tree() -> void:
	_disconnect_sources()
	_generation += 1
	_queued = false
	_clear_current_view()
