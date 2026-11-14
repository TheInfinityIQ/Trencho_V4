extends RefCounted
## One actual squad task, one local observation and delayed report on one clock.
const Commander = preload("res://game/commander.gd")
const SPEED_MPS := 20.0
const SENSOR_RADIUS_M := 40.0
const REPORT_DELAY_SECONDS := 3.0
var now := 0.0
var phase := "Not issued"
var task: Dictionary = {}
var observation: Dictionary = {}
var delivered: Dictionary = {}
var decision: Dictionary = {}
var events: Array[Dictionary] = []
var _known: Dictionary = {}
var _world: RefCounted
var _destination := Vector2.ZERO
var _report_due := INF
var _task_event := 0
var _observation_event := 0
var _receipt_event := 0

func _init(known: Dictionary, initial: Dictionary, world: RefCounted) -> void:
	_known = known.duplicate(true)
	decision = initial.duplicate(true)
	_world = world
	now = float(known.time_seconds)
	events.assign(initial.journal.duplicate(true))

func issue() -> bool:
	if phase != "Not issued" or not decision.get("ok",false): return false
	var element: Dictionary = _known.elements[0]
	var at: String = str(decision.question_at)
	if element.individuals.is_empty() or not _known.nodes.has(at): return false
	_destination = _known.nodes[at].position
	task = {"id":"task-1","question":decision.question,"element":element.id,"individuals":element.individuals.duplicate(),"destination":at,"issued_at":now}
	phase = "Travelling"
	_record("task_issued",{"task":task.duplicate(true),"position":_world.people[element.individuals[0]].position,"causes":[1]})
	_task_event = events.size()
	return true

func advance(seconds: float) -> void:
	if seconds <= 0.0 or phase in ["Not issued","Complete"]: return
	var remaining := seconds
	if phase == "Travelling":
		var first: Vector2 = _world.people[task.individuals[0]].position
		var travel: float = first.distance_to(_destination)/SPEED_MPS
		var elapsed := minf(remaining,travel)
		_world.move_toward(task.individuals,_destination,elapsed*SPEED_MPS)
		now += elapsed
		remaining -= elapsed
		if elapsed > 0.0:
			_record("people_moved",{"actor":task.element,"task_id":task.id,"individuals":task.individuals.duplicate(),"from":first,"to":_world.people[task.individuals[0]].position,"causes":[_task_event]})
		if elapsed+0.000001 >= travel:
			observation = _world.observe(task.individuals,SENSOR_RADIUS_M,now)
			_record("local_observation",{"actor":observation.observer,"task_id":task.id,"observation":observation.duplicate(true),"causes":[_task_event,events.size()]})
			_observation_event = events.size()
			_report_due = now+REPORT_DELAY_SECONDS
			phase = "Report in transit"
	if phase == "Report in transit" and remaining > 0.0:
		var elapsed := minf(remaining,_report_due-now)
		now += elapsed
		if now+0.000001 >= _report_due:
			delivered = observation.duplicate(true)
			delivered["received_at"] = now
			_record("report_received",{"task_id":task.id,"report":delivered.duplicate(true),"causes":[_observation_event]})
			_receipt_event = events.size()
			decision = Commander.reassess(_known,decision,delivered)
			_record("operation_reassessed",{"reason":decision.reassessment,"route":decision.route.duplicate(true),"causes":[1,_task_event,_observation_event,_receipt_event]})
			phase = "Complete"

func _record(kind: String, facts: Dictionary) -> void:
	var event := {"sequence":events.size()+1,"kind":kind,"time_seconds":now,"side":str(_known.side),"actor":str(_known.commander)}
	event.merge(facts,true)
	events.append(event)
