extends RefCounted
## Shared lifecycle for the released recipes; F05 owns its exclusive released selection.

const RECIPES := {
	"R01": {"work": 40.0, "inputs": {"M01": 2, "M02": 1}, "output_type": "E01", "output_count": 1, "unit_mass": 4.0,
		"duty": "workshop", "facility": "F04", "input_store": "workshop_input", "output_store": "workshop_output"},
	"R02": {"work": 40.0, "inputs": {"M01": 1, "M03": 1}, "output_type": "E02", "output_count": 100, "unit_mass": 0.02,
		"duty": "munitions", "facility": "F05", "input_store": "munitions_input", "output_store": "munitions_output"},
	"R26": {"work": 100.0, "inputs": {"M01": 30, "M04": 70}, "output_type": "M11", "output_count": 100, "unit_mass": 1.0,
		"duty": "materials", "facility": "F13", "input_store": "materials_input", "output_store": "materials_output"},
	"R27": {"work": 40.0, "inputs": {"M03": 10, "M01": 2}, "output_type": "M06", "output_count": 1, "unit_mass": 1.0,
		"duty": "munitions", "facility": "F05", "input_store": "munitions_input", "output_store": "munitions_output"},
	"R32": {"work": 180.0, "inputs": {"M01": 100, "M06": 20}, "output_type": "E25", "output_count": 10, "unit_mass": 12.0,
		"duty": "munitions", "facility": "F05", "input_store": "munitions_input", "output_store": "munitions_output"},
	"R33": {"work": 100.0, "inputs": {"M01": 30, "M06": 20}, "output_type": "E26", "output_count": 100, "unit_mass": 0.5,
		"duty": "munitions", "facility": "F05", "input_store": "munitions_input", "output_store": "munitions_output"},
	"R03": {"work": 15.0, "inputs": {"M01": 1}, "output_type": "E03", "output_count": 1, "unit_mass": 1.0,
		"duty": "workshop", "facility": "F04", "input_store": "workshop_input", "output_store": "workshop_output"},
	"R04": {"work": 35.0, "inputs": {"M01": 3, "M05": 2}, "output_type": "E04", "output_count": 1, "unit_mass": 5.0,
		"duty": "workshop", "facility": "F04", "input_store": "workshop_input", "output_store": "workshop_output"},
	"R05": {"work": 90.0, "inputs": {"M01": 5, "M02": 3}, "output_type": "E05", "output_count": 1, "unit_mass": 9.0,
		"duty": "workshop", "facility": "F04", "input_store": "workshop_input", "output_store": "workshop_output"},
	"R06": {"work": 120.0, "inputs": {"M01": 8, "M02": 3}, "output_type": "E06", "output_count": 1, "unit_mass": 18.0,
		"duty": "workshop", "facility": "F04", "input_store": "workshop_input", "output_store": "workshop_output"},
	"R08": {"work": 45.0, "inputs": {"M01": 3, "M02": 3}, "output_type": "E08", "output_count": 1, "unit_mass": 6.0,
		"duty": "workshop", "facility": "F04", "input_store": "workshop_input", "output_store": "workshop_output"},
	"R19": {"work": 75.0, "inputs": {"M01": 3, "M02": 3}, "output_type": "E19", "output_count": 1, "unit_mass": 5.0,
		"duty": "workshop", "facility": "F04", "input_store": "workshop_input", "output_store": "workshop_output"},
	"R07": {"work": 80.0, "inputs": {"M01": 10, "M06": 10}, "output_type": "E07", "output_count": 10, "unit_mass": 2.0,
		"duty": "munitions", "facility": "F05", "input_store": "munitions_input", "output_store": "munitions_output"},
	"R14": {"work": 140.0, "inputs": {"M01": 30, "M06": 20}, "output_type": "E14", "output_count": 10, "unit_mass": 5.0,
		"duty": "munitions", "facility": "F05", "input_store": "munitions_input", "output_store": "munitions_output"},
	"R24": {"work": 70.0, "inputs": {"M01": 8, "M03": 4, "M05": 2}, "output_type": "E24", "output_count": 10, "unit_mass": 2.0,
		"duty": "munitions", "facility": "F05", "input_store": "munitions_input", "output_store": "munitions_output"},
	"R11": {"work": 40.0, "inputs": {"M02": 2, "M05": 2}, "output_type": "E11", "output_count": 1, "unit_mass": 4.0,
		"duty": "support", "facility": "F09", "input_store": "support_input", "output_store": "support_output"},
	"R12": {"work": 50.0, "inputs": {"M05": 4, "M09": 6}, "output_type": "E12", "output_count": 10, "unit_mass": 1.0,
		"duty": "support", "facility": "F09", "input_store": "support_input", "output_store": "support_output"},
	"R15": {"work": 100.0, "inputs": {"M02": 2, "M07": 3}, "output_type": "E15", "output_count": 1, "unit_mass": 5.0,
		"duty": "support", "facility": "F09", "input_store": "support_input", "output_store": "support_output"},
	"R16": {"work": 70.0, "inputs": {"M02": 2, "M07": 2}, "output_type": "E16", "output_count": 1, "unit_mass": 4.0,
		"duty": "support", "facility": "F09", "input_store": "support_input", "output_store": "support_output"},
	"R17": {"work": 40.0, "inputs": {"M10": 5}, "output_type": "E17", "output_count": 5, "unit_mass": 1.0,
		"duty": "support", "facility": "F09", "input_store": "support_input", "output_store": "support_output"},
	"R18": {"work": 50.0, "inputs": {"M02": 1, "M07": 2}, "output_type": "E18", "output_count": 1, "unit_mass": 3.0,
		"duty": "support", "facility": "F09", "input_store": "support_input", "output_store": "support_output"},
	"R20": {"work": 25.0, "inputs": {"M02": 1}, "output_type": "E20", "output_count": 1, "unit_mass": 1.0,
		"duty": "support", "facility": "F09", "input_store": "support_input", "output_store": "support_output"},
	"R21": {"work": 25.0, "inputs": {"M01": 2, "M05": 2}, "output_type": "E21", "output_count": 1, "unit_mass": 4.0,
		"duty": "support", "facility": "F09", "input_store": "support_input", "output_store": "support_output"},
	"R13": {"work": 600.0, "inputs": {"M01": 100, "M02": 60}, "output_type": "E13", "output_count": 1, "unit_mass": 180.0,
		"duty": "vehicle_works", "facility": "F10", "input_store": "vehicle_input", "output_store": "heavy-bay", "heavy": true},
	"R25": {"work": 800.0, "inputs": {"M01": 120, "M02": 80}, "output_type": "T01", "output_count": 1, "unit_mass": 4000.0,
		"duty": "vehicle_works", "facility": "F10", "input_store": "vehicle_input", "output_store": "heavy-bay", "heavy": true},
	"R28": {"work": 700.0, "inputs": {"M01": 100, "M02": 60}, "output_type": "T02", "output_count": 1, "unit_mass": 3200.0,
		"duty": "vehicle_works", "facility": "F10", "input_store": "vehicle_input", "output_store": "heavy-bay", "heavy": true},
	"R29": {"work": 900.0, "inputs": {"M01": 80, "M02": 50}, "output_type": "T03", "output_count": 1, "unit_mass": 2000.0,
		"duty": "vehicle_works", "facility": "F10", "input_store": "vehicle_input", "output_store": "heavy-bay", "heavy": true},
	"R30": {"work": 2200.0, "inputs": {"M01": 500, "M02": 250, "M07": 20}, "output_type": "T04", "output_count": 1, "unit_mass": 14000.0,
		"duty": "vehicle_works", "facility": "F10", "input_store": "vehicle_input", "output_store": "heavy-bay", "heavy": true},
	"R31": {"work": 4000.0, "inputs": {"M01": 1200, "M02": 500, "M07": 40}, "output_type": "T05", "output_count": 1, "unit_mass": 30000.0,
		"duty": "vehicle_works", "facility": "F10", "input_store": "vehicle_input", "output_store": "heavy-bay", "heavy": true},
}
var _instance_spec: Dictionary = {}
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


func _init(rear: RefCounted, recipe: String, instance_spec: Dictionary = {}) -> void:
	assert(recipe in RECIPES, "Only canonical released recipes are supported.")
	_recipe = recipe
	_instance_spec = instance_spec.duplicate(true)
	_spec = RECIPES[recipe].duplicate(true)
	_spec.merge(_instance_spec,true)
	_rear_ref = weakref(rear) # Rear owns this activity; do not retain a reference cycle.


func operators() -> Array[String]:
	var rear: RefCounted = _rear_ref.get_ref()
	var result: Array[String] = []
	for id in rear.actors:
		var person: Dictionary = rear.ledger.inspect_person_status(id)
		var actor: Dictionary = rear.actors[id]
		if rear._eligible(person, _spec.duty) and person.assignment == "Rear Labour" and person.duty_id == _spec.duty and person.pending_assignment == "None" and person.crew_station.is_empty() and person.carrying_stock_id.is_empty() and actor.phase == "Idle" and actor.load.is_empty() and person.position.is_equal_approx(rear.ledger.inspect_entity(rear.requests[_spec.duty].place).position):
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
	return not store.pile and store.accessible and (store.filter.is_empty() or _spec.output_type in store.filter) and rear.ledger.entity_kind(id) == "PLACE"


func stock_coverage(collect_excluded: bool = true) -> Dictionary:
	# A detached query, never a second inventory. Each reserved/carry portion is
	# identified by the existing actor, matching ledger claim and actual holder.
	# Target checks can omit excluded rows; the public detailed report is default.
	var rear: RefCounted = _rear_ref.get_ref()
	var available := 0
	var physical := 0
	var reserved := 0
	var relocation := 0
	var carried := 0
	var stocks: Array[Dictionary] = []
	var portions: Array[Dictionary] = []
	var excluded: Array[Dictionary] = []
	var candidates: Array[Dictionary] = []
	if collect_excluded:
		candidates = rear.ledger.entities_of_type(_spec.output_type,["STOCK","WEAPON"],false)
	else:
		# Only these current holders can contribute available stock. Target checks
		# need no inspection of issued/loaded/cargo goods for exclusion details.
		for holder in rear.stores:
			if _eligible_store(holder): candidates.append_array(rear.ledger.entities_at(holder,["STOCK","WEAPON"],false))
	for stock in candidates:
		if stock.kind not in ["STOCK", "WEAPON"] or stock.design_type != _spec.output_type or stock.quantity <= 0: continue
		var usable: bool = stock.kind == "STOCK" or (_spec.output_type == "E01" and stock.functional and stock.loaded_rounds == 0)
		if usable and stock.owner == rear.PLAYER and _eligible_store(stock.holder_id):
			var committed: int = rear.ledger.reserved(stock.id)
			available += maxi(0, stock.quantity - committed)
			physical += stock.quantity
			reserved += committed
			stocks.append({"id": stock.id, "kind": stock.kind, "holder": stock.holder_id, "physical": stock.quantity, "reserved": committed, "available": maxi(0, stock.quantity - committed)})
		elif collect_excluded:
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
	var forecast: int = _spec.output_count if not batch.is_empty() and _output_valid(batch.id) else 0
	return {"available": available, "planned": relocation + forecast, "projected": available + relocation + forecast,
		"eligible_physical": physical, "eligible_reserved": reserved, "internal_relocation": relocation, "internal_carried": carried,
		"batch_forecast": forecast, "batch_id": batch.get("id", ""), "stocks": stocks, "relocations": portions, "excluded": excluded}


func _target_satisfied() -> bool:
	if mode != "Stock target": return false
	# Coverage is nonnegative: clamped available stock + positive relocation
	# portions + a canonical positive batch yield (or zero). Zero needs no scan.
	return stock_target == 0 or stock_coverage(false).projected >= stock_target


func _can_work() -> bool:
	return not batch.is_empty() and enabled and not paused and _access() and _output_valid(batch.id) and not operators().is_empty()


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
		if batch.work < _spec.work or not enabled or paused or not _access() or not _output_valid(batch.id): return false
		var result: Dictionary = _create_output()
		if not result.ok: return false # Keep complete work/promise; no duplicate or overflow fallback.
		_release_output(batch.id)
		batch.completed_at = rear.time
		batch.state = "Completed"
		history.append(batch.duplicate(true))
		batch = {}
		return true
	if not enabled or paused or _target_satisfied() or not _access() or operators().is_empty() or not _missing().is_empty(): return false
	var id := "%s%s-batch-%04d" % [(_spec.duty + "-") if _instance_spec.has("duty") else "", _recipe.to_lower(), _sequence + 1]
	if not rear.ledger.inspect_entity(id + "-" + _spec.output_type).is_empty(): return false
	if not _reserve_output(id).ok: return false
	var consumption: Dictionary = rear.ledger.consume_local_batch(_spec.input_store, rear.PLAYER, _spec.inputs, id + " " + _recipe + " inputs")
	if not consumption.ok:
		_release_output(id)
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
		_release_output(batch.id)
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
	elif not batch.is_empty() and not _output_valid(batch.id): status = "Output blocked — promise/work retained"
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


func _reserve_output(id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	return rear.reserve_output_space(id, _spec.output_store, _spec.output_type, _spec.output_count * _spec.unit_mass)

func _output_valid(id: String) -> bool:
	return _rear_ref.get_ref().output_space_valid(id)

func _release_output(id: String) -> void:
	_rear_ref.get_ref().release_output_space(id)

func _create_output() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	return rear.ledger.add_stock(batch.output_id, _spec.output_type, _spec.output_count, _spec.unit_mass, _spec.output_store, rear.PLAYER)
