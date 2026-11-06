extends SceneTree
## Two real centres and actual staffing; selector truck preconditions are detached inputs.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Guidance = preload("res://game/ui/demo_guidance.gd")
var _checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _advance(rear: RefCounted, until: Callable, ceiling: int, stage: String) -> bool:
	for _second in ceiling:
		if until.call(): return true
		rear.advance_time(1.0)
		await process_frame
	return _require(bool(until.call()),"Physical fixture did not reach " + stage)

func _selection(rear: RefCounted, expected: String, ready: bool, stage: String) -> bool:
	var before_ledger: Dictionary = rear.ledger.snapshot(false)
	var before_requests: Dictionary = rear.requests.duplicate(true)
	var before_instances: Dictionary = rear.construction.instances.duplicate(true)
	var before_actors: Dictionary = rear.actors.duplicate(true)
	var facts := Guidance._facilities(rear)
	# These prepare the selector branch only; no hull/crew/output is granted to the model.
	var action := Guidance._next({"complete":true},facts,{"crew":1},{"trips":0,"trucks":1,"driven":1,"fueled":1},{})
	if not _require(rear.ledger.snapshot(false) == before_ledger and rear.requests == before_requests and rear.construction.instances == before_instances and rear.actors == before_actors,"Selection must be read-only: " + stage): return false
	print("LOGISTICS_SELECTION " + JSON.stringify({"stage":stage,"expected":expected,"selected":facts.dispatch,"action":action}))
	if ready:
		if not _require(str(facts.dispatch.id) == expected,"Ignore unstaffed copies; select the actual staffed centre: " + stage): return false
		if not _require(int(facts.dispatch.requested) > 0 and int(facts.dispatch.present) > 0,"Selected staffing must be actual requested and present handlers: " + stage): return false
		return _require(action.panel == "ArmyNeeds","One staffed centre must satisfy preparation: " + stage)
	return _require(action.panel == "Workers/Jobs" and action.label == "Staff the Logistics Centre","No qualifying centre must retain the actual staffing action.")

func _run() -> void:
	var model := Base.new(false,false,false,Vector2(1640,91),false,{},true)
	var rear: RefCounted = model.rear
	if not _require(model.receiving.buy_people().ok,"Use an ordinary actual worker purchase."): return
	if not _require(rear.set_target("hauling",2,2).ok,"Use actual hauling workers for construction materials."): return
	var first: Dictionary = rear.construction.place("dispatch",Vector2(65,55))
	var second: Dictionary = rear.construction.place("dispatch",Vector2(120,100))
	if not _require(first.ok and second.ok,"Place two actual Logistics Centres from approved starting materials."): return
	if not _require(rear.construction.set_builders(first.id,2).ok and rear.construction.set_builders(second.id,2).ok,"Request real builders for both actual sites."): return
	if not await _advance(rear,func() -> bool: return rear.construction.instances[first.id].state == "Complete" and rear.construction.instances[second.id].state == "Complete",2400,"two physical completed centres"): return
	if not _require(rear.dispatch.dispatch_sites.has(first.id) and rear.dispatch.dispatch_sites.has(second.id),"Both constructed centres must be registered with the actual dispatch owner."): return
	if not _require(rear.stores[rear.dispatch.dispatch_sites[second.id].store].accessible,"Later centre must have its actual accessible dispatch store."): return
	if not _require(rear.set_target(second.id,1,2).ok,"Request an actual handler at the later centre."): return
	if not await _advance(rear,func() -> bool: return rear._present(second.id) > 0,1200,"later centre handler reporting"): return
	if not _require(rear.requests[first.id].target == 0 and rear._present(first.id) == 0,"Earlier completed centre remains genuinely unstaffed."): return
	if not _selection(rear,second.id,true,"earlier unstaffed / later staffed"): return
	if not _require(rear.set_target(second.id,0).ok and rear.set_target(first.id,1,2).ok,"Reverse staffing through existing actual commands."): return
	if not await _advance(rear,func() -> bool: return rear._present(first.id) > 0 and rear._present(second.id) == 0,1200,"reversed staffing order"): return
	if not _selection(rear,first.id,true,"earlier staffed / later unstaffed"): return
	if not _require(rear.set_target(first.id,0).ok,"Remove the last requested handlers through the existing command."): return
	if not await _advance(rear,func() -> bool: return rear._present(first.id) == 0 and rear._present(second.id) == 0,1200,"no present centre handlers"): return
	if not _selection(rear,"",false,"no qualifying centre"): return
	if not _require(model.audit().is_empty(),"Actual two-centre construction/staffing must preserve physical invariants."): return
	print(JSON.stringify({"result":"PASS","checks":_checks,"scope":"Two physically constructed Logistics Centres with actual worker purchase, material hauling, handler reporting, reversed readiness order and no qualifying centre. Navigation preconditions are detached; no physical truck, shell integration, whole-demo or FPS certification."}))
	quit(0)
