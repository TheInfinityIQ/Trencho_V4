extends RefCounted
## Shared lifecycle for the three fixed released activities: R01, R02 and R26.

const RECIPES := {
	"R01": {"work": 40.0, "inputs": {"M01": 2, "M02": 1}, "output_type": "E01", "output_count": 1, "unit_mass": 4.0,
		"duty": "workshop", "facility": "F04", "input_store": "workshop_input", "output_store": "workshop_output"},
	"R02": {"work": 40.0, "inputs": {"M01": 1, "M03": 1}, "output_type": "E02", "output_count": 100, "unit_mass": 0.02,
		"duty": "munitions", "facility": "F05", "input_store": "munitions_input", "output_store": "munitions_output"},
	"R26": {"work": 100.0, "inputs": {"M01": 30, "M04": 70}, "output_type": "M11", "output_count": 100, "unit_mass": 1.0,
		"duty": "materials", "facility": "F13", "input_store": "materials_input", "output_store": "materials_output"},
}
var _spec: Dictionary
var _recipe: String
var _rear_ref: WeakRef
var enabled := true
var paused := false
var mode := "Continuous"
var stock_target := 0
var batch: Dictionary = {}
var history: Array[Dictionary] = []
var _sequence := 0


func _init(rear: RefCounted, recipe: String) -> void:
	assert(recipe in RECIPES, "Only the fixed released R01, R02 and R26 activities are supported.")
	_recipe = recipe
	_spec = RECIPES[recipe]
	_rear_ref = weakref(rear) # Rear owns this activity; do not retain a reference cycle.


func operators() -> Array[String]:
	var rear: RefCounted = _rear_ref.get_ref()
	var result: Array[String] = []
	for id in rear.actors:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		var actor: Dictionary = rear.actors[id]
		if rear._eligible(person, _spec.duty) and person.assignment == "Rear Labour" and person.duty_id == _spec.duty and person.pending_assignment == "None" and person.crew_station.is_empty() and person.carrying_stock_id.is_empty() and actor.phase == "Idle" and actor.load.is_empty() and person.position.is_equal_approx(rear.Layout.door(_spec.duty)):
			result.append(id)
	return result


func _local_inputs() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var result: Dictionary = {}
	for type in _spec.inputs:
		var available := 0
		for stock in rear._stock_at(_spec.input_store):
			if stock.design_type == type: available += stock.available
		result[type] = available
	return result


func _missing() -> Dictionary:
	var missing: Dictionary = {}
	var local := _local_inputs()
	for type in _spec.inputs:
		if local[type] < _spec.inputs[type]: missing[type] = _spec.inputs[type] - local[type]
	return missing


func _access() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	return rear.stores[_spec.input_store].accessible and rear.stores[_spec.output_store].accessible


func set_mode(value: String) -> Dictionary:
	if value not in ["Continuous", "Stock target"]:
		return {"ok": false, "message": "Choose Continuous or Stock target."}
	mode = value
	var rear: RefCounted = _rear_ref.get_ref()
	rear._settle()
	return {"ok": true, "message": "Mode updated; active consumed work and its output promise are retained."}


func set_stock_target(value: int) -> Dictionary:
	if value < 0:
		return {"ok": false, "message": _spec.output_type + " target must be a nonnegative whole count."}
	stock_target = value
	var rear: RefCounted = _rear_ref.get_ref()
	rear._settle()
	return {"ok": true, "message": _spec.output_type + " minimum updated; no goods created or active batch cancelled."}


func _eligible_store(id: String) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if not rear.stores.has(id): return false
	var store: Dictionary = rear.stores[id]
	return not store.pile and store.accessible and (store.filter.is_empty() or _spec.output_type in store.filter) and rear.ledger.inspect_entity(id).get("kind") == "PLACE"


func stock_coverage() -> Dictionary:
	# A detached query, never a second inventory. Each reserved/carry portion is
	# identified by the existing actor, matching ledger claim and actual holder.
	var rear: RefCounted = _rear_ref.get_ref()
	var available := 0
	var physical := 0
	var reserved := 0
	var relocation := 0
	var carried := 0
	var stocks: Array[Dictionary] = []
	var portions: Array[Dictionary] = []
	var excluded: Array[Dictionary] = []
	for stock in rear.ledger.snapshot().entities:
		if stock.kind not in ["STOCK", "WEAPON"] or stock.design_type != _spec.output_type or stock.quantity <= 0: continue
		var usable: bool = stock.kind == "STOCK" or (_spec.output_type == "E01" and stock.functional and stock.loaded_rounds == 0)
		if usable and stock.owner == rear.PLAYER and _eligible_store(stock.holder_id):
			var committed: int = rear.ledger.reserved(stock.id)
			available += maxi(0, stock.quantity - committed)
			physical += stock.quantity
			reserved += committed
			stocks.append({"id": stock.id, "kind": stock.kind, "holder": stock.holder_id, "physical": stock.quantity, "reserved": committed, "available": maxi(0, stock.quantity - committed)})
		else:
			excluded.append({"id": stock.id, "holder": stock.holder_id, "quantity": stock.quantity, "reason": "Foreign, issued/loaded/broken/cargo/pile or inaccessible/type-ineligible storage"})
	for actor in rear.actors.values():
		var load: Dictionary = actor.load
		if load.is_empty() or load.type != _spec.output_type or not _eligible_store(load.source) or not _eligible_store(load.destination): continue
		var job: Dictionary = rear._job(load.job)
		if job.is_empty() or job.cancelled or job.type != _spec.output_type or not rear._valid_destination(load.destination, _spec.output_type, load.mass, actor.id): continue
		var count := 0
		if load.carried.is_empty():
			var claim: Dictionary = rear.ledger.inspect_claim(load.claim)
			var stock: Dictionary = rear.ledger.inspect_entity(load.stock)
			if not claim.is_empty() and not claim.cancelled and claim.claimant == actor.id and claim.purpose == job.id and claim.source_id == stock.get("id") and stock.get("kind") == "STOCK" and stock.get("design_type") == _spec.output_type and stock.get("holder_id") == load.source and stock.get("owner") == rear.PLAYER:
				count = mini(load.count, claim.reserved)
		else:
			var stock: Dictionary = rear.ledger.inspect_entity(load.carried)
			var person: Dictionary = rear.ledger.inspect_entity(actor.id)
			if stock.get("kind") == "STOCK" and stock.get("design_type") == _spec.output_type and stock.get("owner") == rear.PLAYER and stock.get("holder_id") == actor.id and person.carrying_stock_id == stock.id:
				count = mini(load.count, stock.quantity)
				carried += count
		if count > 0:
			relocation += count
			portions.append({"job": job.id, "person": actor.id, "source": load.source, "destination": load.destination, "claim": load.get("claim", ""), "carried_stock": load.carried, "count": count})
	var forecast: int = _spec.output_count if not batch.is_empty() and rear.output_space_valid(batch.id) else 0
	return {"available": available, "planned": relocation + forecast, "projected": available + relocation + forecast,
		"eligible_physical": physical, "eligible_reserved": reserved, "internal_relocation": relocation, "internal_carried": carried,
		"batch_forecast": forecast, "batch_id": batch.get("id", ""), "stocks": stocks, "relocations": portions, "excluded": excluded}


func _target_satisfied() -> bool:
	return mode == "Stock target" and stock_coverage().projected >= stock_target


func _can_work() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	return not batch.is_empty() and enabled and not paused and _access() and rear.output_space_valid(batch.id) and not operators().is_empty()


func next_boundary() -> float:
	var rear: RefCounted = _rear_ref.get_ref()
	if not _can_work() or batch.work >= _spec.work: return INF
	return rear.time + (_spec.work - float(batch.work)) / operators().size()


func advance_work(seconds: float) -> void:
	# Called before G03 advances physical people to the next shared event boundary.
	if not _can_work(): return
	var rate := operators().size()
	batch.work = minf(_spec.work, float(batch.work) + seconds * rate)
	# Match the rear clock's time tolerance only at completion, not on each
	# partial increment. Fractional partitions can otherwise leave work one ULP short.
	var rear: RefCounted = _rear_ref.get_ref()
	if (_spec.work - float(batch.work)) / rate <= rear.EPS:
		batch.work = _spec.work


func settle() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if not batch.is_empty():
		# All operator work is already earned. Physical completion needs no extra
		# work credit, but still obeys facility pause/access and its valid promise.
		if batch.work < _spec.work or not enabled or paused or not _access() or not rear.output_space_valid(batch.id): return false
		var result: Dictionary = rear.ledger.add_stock(batch.output_id, _spec.output_type, _spec.output_count, _spec.unit_mass, _spec.output_store, rear.PLAYER)
		if not result.ok: return false # Keep complete work/promise; no duplicate or overflow fallback.
		rear.release_output_space(batch.id)
		batch.completed_at = rear.time
		batch.state = "Completed"
		history.append(batch.duplicate(true))
		batch = {}
		return true
	if not enabled or paused or _target_satisfied() or not _access() or operators().is_empty() or not _missing().is_empty(): return false
	var id := "%s-batch-%04d" % [_recipe.to_lower(), _sequence + 1]
	if not rear.ledger.inspect_entity(id + "-" + _spec.output_type).is_empty(): return false
	if not rear.reserve_output_space(id, _spec.output_store, _spec.output_type, (_spec.output_count * _spec.unit_mass)).ok: return false
	var consumption: Dictionary = rear.ledger.consume_local_batch(_spec.input_store, rear.PLAYER, _spec.inputs, id + " " + _recipe + " inputs")
	if not consumption.ok:
		rear.release_output_space(id)
		return false
	_sequence += 1
	batch = {"id": id, "recipe": _recipe, "work": 0.0, "required_work": _spec.work,
		"started_at": rear.time, "receipt": consumption.receipt, "output_id": id + "-" + _spec.output_type, "state": "Active"}
	return true


func set_paused(value: bool) -> Dictionary:
	paused = value
	var rear: RefCounted = _rear_ref.get_ref()
	rear._settle()
	return {"ok": true, "message": _recipe + (" pause retains consumed inputs, work and output promise." if value else " pause released; actual prerequisites still apply.")}


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
	return {"ok": true, "message": _recipe + " stopped; consumed inputs stay consumed, finished goods stay physical, only this batch's unused promise is released."}


func snapshot() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var physical_output := 0
	for stock in rear._stock_at(_spec.output_store):
		if stock.design_type == _spec.output_type: physical_output += stock.quantity
	var status := "Working"
	if not enabled: status = "No Recipe — stopped"
	elif paused: status = "Paused"
	elif not _access(): status = "Access blocked — work paused"
	elif not batch.is_empty() and not rear.output_space_valid(batch.id): status = "Output blocked — promise/work retained"
	elif batch.is_empty() and _target_satisfied(): status = "Target satisfied — no new batch"
	elif batch.is_empty() and not rear._valid_destination(_spec.output_store, _spec.output_type, (_spec.output_count * _spec.unit_mass)): status = "Output Full"
	elif batch.is_empty() and not _missing().is_empty(): status = "Missing Inputs"
	elif operators().is_empty(): status = "Missing Labour"
	elif not batch.is_empty() and batch.work >= _spec.work: status = "Completion blocked — work retained"
	return {"recipe": _recipe, "duty": _spec.duty, "facility": _spec.facility, "inputs": _spec.inputs.duplicate(),
		"input_store": _spec.input_store, "output_store": _spec.output_store, "output_type": _spec.output_type, "output_count": _spec.output_count, "unit_mass": _spec.unit_mass, "mode": mode, "stock_target": stock_target, "coverage": stock_coverage(), "enabled": enabled, "paused": paused, "status": status,
		"operators": operators(), "target": rear.requests[_spec.duty].target, "missing_local": _missing(), "local_inputs": _local_inputs(),
		"batch": batch.duplicate(true), "history": history.duplicate(true),
		"output_promise": rear._output_promises.get(batch.get("id", ""), {}).duplicate(true),
		"physical_output": physical_output,
		"required_work": _spec.work, "haul_shortage": rear._assigned("hauling") == 0 and not _missing().is_empty()}
