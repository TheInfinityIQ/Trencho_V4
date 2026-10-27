extends RefCounted
## One F04 continuous R01 owner over G03's real ledger, workers, space and clock.

const INPUTS := {"M01": 2, "M02": 1}
const REQUIRED_WORK := 40.0
const OUTPUT_MASS := 4.0
var _rear_ref: WeakRef
var enabled := true
var paused := false
var batch: Dictionary = {}
var history: Array[Dictionary] = []
var _sequence := 0


func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear) # Rear owns this activity; do not retain a reference cycle.


func operators() -> Array[String]:
	var rear: RefCounted = _rear_ref.get_ref()
	var result: Array[String] = []
	for id in rear.actors:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		var actor: Dictionary = rear.actors[id]
		if rear._eligible(person, "workshop") and person.assignment == "Rear Labour" and person.duty_id == "workshop" and person.pending_assignment == "None" and person.crew_station.is_empty() and person.carrying_stock_id.is_empty() and actor.phase == "Idle" and actor.load.is_empty() and person.position.is_equal_approx(rear.Layout.door("workshop")):
			result.append(id)
	return result


func _local_inputs() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var result: Dictionary = {}
	for type in INPUTS:
		var available := 0
		for stock in rear._stock_at("workshop_input"):
			if stock.design_type == type: available += stock.available
		result[type] = available
	return result


func _missing() -> Dictionary:
	var missing: Dictionary = {}
	var local := _local_inputs()
	for type in INPUTS:
		if local[type] < INPUTS[type]: missing[type] = INPUTS[type] - local[type]
	return missing


func _access() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	return rear.stores.workshop_input.accessible and rear.stores.workshop_output.accessible


func _can_work() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	return not batch.is_empty() and enabled and not paused and _access() and rear.output_space_valid(batch.id) and not operators().is_empty()


func next_boundary() -> float:
	var rear: RefCounted = _rear_ref.get_ref()
	if not _can_work() or batch.work >= REQUIRED_WORK: return INF
	return rear.time + (REQUIRED_WORK - float(batch.work)) / operators().size()


func advance_work(seconds: float) -> void:
	# Called before G03 advances physical people to the next shared event boundary.
	if _can_work(): batch.work = minf(REQUIRED_WORK, float(batch.work) + seconds * operators().size())


func settle() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if not batch.is_empty():
		# All operator work is already earned. Physical completion needs no extra
		# work credit, but still obeys facility pause/access and its valid promise.
		if batch.work < REQUIRED_WORK or not enabled or paused or not _access() or not rear.output_space_valid(batch.id): return false
		var result: Dictionary = rear.ledger.add_stock(batch.output_id, "E01", 1, OUTPUT_MASS, "workshop_output", rear.PLAYER)
		if not result.ok: return false # Keep complete work/promise; no duplicate or overflow fallback.
		rear.release_output_space(batch.id)
		batch.completed_at = rear.time
		batch.state = "Completed"
		history.append(batch.duplicate(true))
		batch = {}
		return true
	if not enabled or paused or not _access() or operators().is_empty() or not _missing().is_empty(): return false
	var id := "r01-batch-%04d" % (_sequence + 1)
	if not rear.ledger.inspect_entity(id + "-E01").is_empty(): return false
	if not rear.reserve_output_space(id, "workshop_output", "E01", OUTPUT_MASS).ok: return false
	var consumption: Dictionary = rear.ledger.consume_local_batch("workshop_input", rear.PLAYER, INPUTS, id + " R01 inputs")
	if not consumption.ok:
		rear.release_output_space(id)
		return false
	_sequence += 1
	batch = {"id": id, "recipe": "R01", "work": 0.0, "required_work": REQUIRED_WORK,
		"started_at": rear.time, "receipt": consumption.receipt, "output_id": id + "-E01", "state": "Active"}
	return true


func set_paused(value: bool) -> Dictionary:
	paused = value
	var rear: RefCounted = _rear_ref.get_ref()
	rear._settle()
	return {"ok": true, "message": "R01 pause retains consumed inputs, work and output promise." if value else "R01 pause released; actual prerequisites still apply."}


func resume() -> Dictionary:
	enabled = true
	return set_paused(false)


func cancel() -> Dictionary:
	enabled = false # Stop continuous requests too; repeated cancellation cannot start new input loss.
	if not batch.is_empty():
		var rear: RefCounted = _rear_ref.get_ref()
		rear.release_output_space(batch.id)
		batch.state = "Cancelled"
		batch.cancelled_at = rear.time
		history.append(batch.duplicate(true))
		batch = {}
	return {"ok": true, "message": "R01 stopped; consumed inputs stay consumed, finished goods stay physical, only this batch's unused promise is released."}


func snapshot() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var physical_output := 0
	for stock in rear._stock_at("workshop_output"):
		if stock.design_type == "E01": physical_output += stock.quantity
	var status := "Working"
	if not enabled: status = "No Recipe — stopped"
	elif paused: status = "Paused"
	elif not _access(): status = "Access blocked — work paused"
	elif not batch.is_empty() and not rear.output_space_valid(batch.id): status = "Output blocked — promise/work retained"
	elif batch.is_empty() and not rear._valid_destination("workshop_output", "E01", OUTPUT_MASS): status = "Output Full"
	elif batch.is_empty() and not _missing().is_empty(): status = "Missing Inputs"
	elif operators().is_empty(): status = "Missing Labour"
	elif not batch.is_empty() and batch.work >= REQUIRED_WORK: status = "Completion blocked — work retained"
	return {"recipe": "R01", "mode": "Continuous only", "enabled": enabled, "paused": paused, "status": status,
		"operators": operators(), "target": rear.requests.workshop.target, "missing_local": _missing(), "local_inputs": _local_inputs(),
		"batch": batch.duplicate(true), "history": history.duplicate(true),
		"output_promise": rear._output_promises.get(batch.get("id", ""), {}).duplicate(true),
		"physical_output": physical_output,
		"required_work": REQUIRED_WORK, "haul_shortage": rear._assigned("hauling") == 0 and not _missing().is_empty()}
