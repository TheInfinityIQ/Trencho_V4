extends VBoxContainer
## Reads the shared worker pool; all allocation remains with the rear owner.
signal result_reported(result: Dictionary)
signal purchase_requested
const UIKit = preload("res://game/ui/ui_kit.gd")
const HaulingPriorities = preload("res://game/rear_base/hauling_priority_list.gd")
const JOB_NAMES := {
	"receiving":"Supply unloading", "hauling":"Hauling", "workshop":"Workshop",
	"munitions":"Munitions workshop", "materials":"Building Materials workshop",
	"support":"Support workshop", "vehicle_works":"Vehicle workshop",
	"dispatch":"Logistics Centre", "training":"Training", "construction":"Construction crew",
	"yard":"Vehicle driver", "park":"Vehicle parking", "terminal":"Supply Table",
	"personnel":"Worker arrival", "depot":"Depot",
}
var simulation: RefCounted
var summary: Label
var arrivals: Label
var rows: VBoxContainer
var controls: Dictionary = {}
var _row_view: Dictionary = {}
var _pending_rows: Array[String] = []
var _row_generation := 0
var _row_queued := false
var hauling_priorities: VBoxContainer


func _init(session: RefCounted) -> void:
	simulation = session


func _ready() -> void:
	var pool: VBoxContainer = _section(self,"Worker pool","")
	summary = _label(pool, "")
	var hire := Button.new()
	hire.text = "Order workers at Supply Table"
	hire.theme_type_variation = "Primary"
	hire.tooltip_text = "120 requisition + 20 transport. Reserves eight rear places; the supplier carrier and driver leave."
	hire.pressed.connect(func() -> void: purchase_requested.emit())
	pool.add_child(hire)
	_label(pool,"Workers join after disembarking.")
	arrivals = _label(_section(self,"Arrivals","Only workers who finish disembarking and walking join the pool."), "")
	var allocation: VBoxContainer = _section(self,"Jobs and priorities","Request workers and set priority from the shared pool.")
	allocation.tooltip_text = "Assigned people must report before they are present. A carry finishes or is deposited safely before reassignment."
	rows = VBoxContainer.new()
	allocation.add_child(rows)


func bind(session: RefCounted) -> void:
	simulation = session
	_clear_rows()


func refresh(view: Dictionary) -> void:
	if not is_node_ready(): return
	var available := 0
	var assigned := 0
	for person in view.rear.people:
		if person.owner != simulation.rear.PLAYER or not simulation.rear.actors.has(person.id) or person.health <= 0: continue
		if person.assignment == "Available" and person.pending_assignment == "None" and person.health > 0 and str(person.crew_station).is_empty() and str(person.carrying_stock_id).is_empty() and str(person.carrying_weapon_id).is_empty(): available += 1
		else: assigned += 1
	var requested := 0
	var vacancies := 0
	var current_ids: Array[String] = []
	for row in view.rear.staffing:
		if int(row.positions) <= 0: continue
		if simulation.rear.empty_field_opening and row.id == "receiving": continue
		current_ids.append(str(row.id))
		if simulation.rear.requests[row.id].get("fallback",false): continue
		requested += int(row.target)
		vacancies += int(row.shortage)
	var incoming: int = simulation.receiving.incoming_people()
	var occupied: int = simulation.receiving.rear_population()
	var returning := 0
	if simulation.receiving.external_rear_reservations.is_valid(): returning = int(simulation.receiving.external_rear_reservations.call())
	summary.text = "%d available · %d assigned / committed\n%d arriving · %d requested · %d vacancies\nRear places: %d occupied + %d arriving + %d held for return / 120" % [available,assigned,incoming,requested,vacancies,occupied,incoming,returning]
	var arrival_lines: Array[String] = []
	for order in view.receiving.orders:
		if order.kind != "Personnel" or order.state in ["Complete","Cancelled"]: continue
		arrival_lines.append("%s · %d/%d workers joined · %s" % [order.state,order.people_arrived,order.expected_people,order.blocked_reason])
		if order.state == "Incoming": arrival_lines.append("Scheduled arrival in %.0f s" % ceilf(maxf(0.0,float(order.arrival_at)-float(view.receiving.time))))
	arrivals.text = "\n".join(arrival_lines) if not arrival_lines.is_empty() else "No worker arrivals pending."
	# Keep existing controls while another job appears, preserving focused edits.
	for id in controls.keys():
		if id in current_ids: continue
		var block: Control = controls[id].block
		rows.remove_child(block)
		block.queue_free()
		controls.erase(id)
	for id in current_ids:
		if not controls.has(id) and id not in _pending_rows: _pending_rows.append(id)
	_pending_rows = _pending_rows.filter(func(id: String) -> bool: return id in current_ids)
	_row_view.clear()
	for row in view.rear.staffing:
		_row_view[row.id] = row
		_refresh_row(row)
	_queue_row()
	if hauling_priorities != null: hauling_priorities.refresh(view)


func _refresh_row(row: Dictionary) -> void:
	if not controls.has(row.id): return
	var widgets: Dictionary = controls[row.id]
	if widgets.has("hauling"):
		widgets.hauling.assigned_count = int(row.assigned)
		widgets.hauling._update_header()
		return
	widgets.count.set_block_signals(true)
	widgets.count.max_value = int(row.positions)
	if not widgets.count.get_line_edit().has_focus(): widgets.count.set_value_no_signal(int(row.target))
	widgets.count.set_block_signals(false)
	widgets.priority.select(simulation.rear.PRIORITIES.find(row.priority))
	widgets.status.text = "%d present · %d assigned · %d reporting / active\n%d requested · %d vacancies" % [row.present,row.assigned,row.reporting_or_active,row.target,row.shortage]
	if row.shortage > 0 and simulation.rear.requests[row.id].get("starter_request",false):
		widgets.status.text += "\nStarter request waits for available eligible workers; committed jobs stay staffed."
	if row.shortage > 0 and simulation.rear.construction.instances.has(row.id) and simulation.rear.construction.instances[row.id].kind == "training":
		widgets.status.text += "\nInstructor vacancies need an available basic-trained worker; untrained workers cannot fill them."


func _queue_row() -> void:
	if _row_queued or _pending_rows.is_empty(): return
	_row_queued = true
	get_tree().process_frame.connect(_prepare_row.bind(_row_generation),CONNECT_ONE_SHOT)


func _prepare_row(generation: int) -> void:
	if generation != _row_generation: return
	_row_queued = false
	if _pending_rows.is_empty(): return
	# One control group per returned frame bounds creation and deferred layout.
	# There is no idle callback after the finite set has been prepared.
	var id: String = _pending_rows.pop_front()
	if _row_view.has(id) and not controls.has(id):
		_add_row(id)
		_refresh_row(_row_view[id])
	_queue_row()


func _add_row(id: String) -> void:
	var block := VBoxContainer.new()
	rows.add_child(block)
	if id == "hauling" and simulation.rear.empty_field_opening:
		hauling_priorities = HaulingPriorities.new()
		block.add_child(hauling_priorities)
		hauling_priorities.bind(simulation)
		hauling_priorities.result_reported.connect(func(result: Dictionary) -> void: result_reported.emit(result))
		controls[id] = {"block":block,"hauling":hauling_priorities}
		return
	var title: String = job_name(id,simulation)
	_label(block,title)
	var row := HBoxContainer.new()
	block.add_child(row)
	_label(row,"Requested")
	var count := SpinBox.new()
	count.step = 1
	count.tooltip_text = "Requested staffing; workers must report before becoming present. Existing carries finish or deposit safely before reassignment."
	row.add_child(count)
	var priority := OptionButton.new()
	for value in simulation.rear.PRIORITIES: priority.add_item(value)
	priority.tooltip_text = "Staff allocation priority"
	row.add_child(priority)
	count.value_changed.connect(func(value: float) -> void:
		result_reported.emit(simulation.rear.set_target(id,int(value),priority.selected)))
	priority.item_selected.connect(func(value: int) -> void:
		result_reported.emit(simulation.rear.set_target(id,int(count.value),value)))
	controls[id] = {"block":block,"count":count,"priority":priority,"status":_label(block,"")}


func _clear_rows() -> void:
	if _row_queued and is_inside_tree():
		var callback := _prepare_row.bind(_row_generation)
		if get_tree().process_frame.is_connected(callback): get_tree().process_frame.disconnect(callback)
	_row_generation += 1
	_row_queued = false
	_pending_rows.clear()
	_row_view.clear()
	controls.clear()
	hauling_priorities = null
	if rows == null: return
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()


static func job_name(id: String, session: RefCounted) -> String:
	if JOB_NAMES.has(id): return JOB_NAMES[id]
	if id.begins_with("builders-"): return "Builders · "+job_name(id.trim_prefix("builders-"),session)
	if session.rear.construction.instances.has(id):
		var site: Dictionary = session.rear.construction.instances[id]
		return str(JOB_NAMES.get(site.kind,str(site.kind).capitalize()))+" · "+str(site.get("center",""))
	return id.replace("_"," ").capitalize()


func _label(parent: Node, text: String) -> Label:
	return UIKit.label(parent,text,14,UIKit.INK,true)


func _section(parent: Node, title: String, description: String) -> VBoxContainer:
	var body: VBoxContainer = UIKit.card(parent)
	UIKit.label(body,title,20)
	if not description.is_empty(): UIKit.label(body,description,14,UIKit.MUTED,true)
	return body
