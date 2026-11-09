extends RefCounted
## Preferences choose only the next feasible task; existing services own work.
const DEFAULT_ORDER: Array[String] = ["unloading", "dispatch", "construction", "production", "other"]
const LABELS := {"unloading":"Unload incoming supplies", "dispatch":"Load outbound supplies", "construction":"Supply construction sites", "production":"Supply production", "other":"Other hauling"}
var order: Array[String] = DEFAULT_ORDER.duplicate()
var _rear_ref: WeakRef

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)

func set_order(values: Array) -> Dictionary:
	if values.size() != DEFAULT_ORDER.size(): return {"ok":false,"message":"Keep each hauling task exactly once."}
	var next: Array[String] = []
	for value: Variant in values:
		if not value is String or value not in DEFAULT_ORDER or value in next: return {"ok":false,"message":"The hauling task list changed; review each task before confirming."}
		next.append(value)
	if next == order: return {"ok":true,"changed":false,"message":"Hauling priorities already match."}
	order = next
	return {"ok":true,"changed":true,"message":"Hauling priorities confirmed. Current work finishes safely; new tasks use this order."}

func category(job: Dictionary) -> String:
	var rear: RefCounted = _rear_ref.get_ref()
	var destination: String = job.destination
	if rear.dispatch != null:
		for site: Dictionary in rear.dispatch.dispatch_sites.values():
			if destination == site.store: return "dispatch"
	if rear.construction != null and rear.construction.instances.has(destination): return "construction"
	if not str(job.get("automatic_factory", "")).is_empty(): return "production"
	for activity: RefCounted in rear._production_activities():
		if destination == activity._spec.input_store: return "production"
	return "other"

func start(actor: Dictionary) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if actor.phase != "Idle" or not rear.ledger.person_has_duty(actor.id,"hauling"): return false
	if rear.ledger.inspect_person_status(actor.id).pending_assignment != "None": return false
	for task: String in order:
		if task == "unloading" and rear.receiving != null and rear.receiving.start_shared_unload(actor.id):
			actor.phase = "Unloading"
			return true
		if task == "dispatch" and rear.dispatch != null and rear.dispatch.start_shared_preparation(actor.id): return true
		if task != "unloading" and not rear.jobs.is_empty() and rear._start_job(actor,task): return true
	return false
