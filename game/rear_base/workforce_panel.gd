extends VBoxContainer
## Reads the shared worker pool; all allocation remains with the rear owner.
signal result_reported(result: Dictionary)
const UIKit = preload("res://game/ui/ui_kit.gd")
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


func _init(session: RefCounted) -> void:
	simulation = session


func _ready() -> void:
	var pool: VBoxContainer = _section(self,"Worker pool","")
	summary = _label(pool, "")
	var hire := Button.new()
	hire.text = "Hire 8 workers · 140 requisition · 90 s travel"
	hire.theme_type_variation = "Primary"
	hire.pressed.connect(func() -> void: result_reported.emit(simulation.receiving.buy_people()))
	pool.add_child(hire)
	_label(pool,"120 requisition + 20 transport. Eight rear places are reserved now; workers join the pool after disembarking. The carrier and service driver leave.")
	arrivals = _label(_section(self,"Arrivals","Only workers who finish disembarking and walking join the pool."), "")
	var allocation: VBoxContainer = _section(self,"Jobs and priorities","Request workers from the shared pool. Assigned people must report before they are present; a carry finishes or is deposited safely before reassignment.")
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
		current_ids.append(str(row.id))
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
		if not controls.has(id): _add_row(id)
	for row in view.rear.staffing:
		if not controls.has(row.id): continue
		var widgets: Dictionary = controls[row.id]
		widgets.count.set_block_signals(true)
		widgets.count.max_value = int(row.positions)
		if not widgets.count.get_line_edit().has_focus(): widgets.count.set_value_no_signal(int(row.target))
		widgets.count.set_block_signals(false)
		widgets.priority.select(simulation.rear.PRIORITIES.find(row.priority))
		widgets.status.text = "%d present · %d assigned · %d reporting / active\n%d requested · %d vacancies" % [row.present,row.assigned,row.reporting_or_active,row.target,row.shortage]


func _add_row(id: String) -> void:
	var block := VBoxContainer.new()
	rows.add_child(block)
	var title: String = job_name(id,simulation)
	_label(block,title)
	var row := HBoxContainer.new()
	block.add_child(row)
	_label(row,"Requested")
	var count := SpinBox.new()
	count.step = 1
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
	controls.clear()
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
