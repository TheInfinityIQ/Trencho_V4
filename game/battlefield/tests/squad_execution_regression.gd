extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var base := Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	_check(ledger.add_place("execution-stage","Actual staging",Vector2(2000,500)).ok,"Actual staging place")
	_check(ledger.add_place("execution-goal","Assigned objective approach",Vector2(2000,523)).ok,"Actual destination")
	_check(ledger.add_place("execution-enemy","Observed threat",Vector2(2130,523)).ok,"Actual hostile place")
	_check(ledger.add_person("execution-target","execution-enemy","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual hostile person")
	var roster: Array[String] = []
	for index in 4:
		var id := "execution-person-%d" % index
		_check(ledger.add_person(id,"execution-stage",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual formation member")
		_check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual rifle")
		_check(ledger.add_stock(id+"-rounds","E02",60,0.02,id,rear.PLAYER).ok,"Actual rounds")
		_check(ledger.load_rounds(id+"-rifle",id+"-rounds",10).ok,"Actual initial magazine")
		roster.append(id)
	_check(rear.military.add_initial_squad("execution-squad","Rifle",roster,"execution-company","execution-platoon",rear.PLAYER).ok,"Actual hierarchy")
	_check(rear.orders.watch("execution-squad").ok,"Actual squad observes")
	rear.battlefield_operations = Execution.new(rear)
	var constraints := {"destination":"execution-goal","fallback_place":"execution-stage","role":"Rifle"}
	_check(rear.orders.issue_order("army","execution-company","Seize Objective","Reach the approach","Initial mission",constraints,"Normal","Staging").ok,"Commander sends real company intent")
	rear.advance_time(2)
	_check(rear.orders.relay_order("execution-company","execution-platoon").ok,"Company acknowledges then relays")
	rear.advance_time(2)
	_check(rear.orders.relay_order("execution-platoon","execution-squad").ok,"Platoon acknowledges then relays")
	rear.advance_time(12)
	_check(ledger.inspect_entity(roster[0]).position.y > 500,"Acknowledged squad intent produces actual timed movement")
	_check(int(ledger.snapshot().consumed.get("E02",0)) > 0,"Observed contact produces autonomous physical fire")
	# Prior fighting leaves the same people without local ammunition; no remote stock can fire.
	for id in roster:
		if ledger.inspect_entity(id+"-rifle").loaded_rounds > 0: _check(ledger.unload_rounds(id+"-rifle").ok,"Existing magazine emptied to the same holder")
		for stock in ledger.entities_at(id,["STOCK"]):
			if stock.design_type == "E02" and stock.quantity > 0: _check(ledger.record_consumption(stock.id,stock.quantity,"Declared prior combat expenditure").ok,"Existing rounds expended")
	var before_empty: Vector2 = ledger.inspect_entity(roster[0]).position
	rear.advance_time(2)
	_check(ledger.inspect_entity(roster[0]).position.y <= before_empty.y+0.001,"Empty people stop advancing and may fall back without capability")
	rear.advance_time(20)
	_check(ledger.add_person("execution-second-target","execution-enemy","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"New actual observed threat")
	var spent_before: int = ledger.snapshot().consumed.E02
	rear.advance_time(4)
	_check(ledger.snapshot().consumed.E02 == spent_before,"Empty formation cannot fire distant or nonexistent rounds")
	_check(ledger.add_carrier("execution-load-carrier","execution-stage",rear.PLAYER,rear.PLAYER).ok,"Arrived physical carrier")
	_check(ledger.add_stock("execution-delivered-rounds","E02",5,0.02,"execution-load-carrier",rear.PLAYER).ok,"Actual arrived five-round load")
	var issue: Dictionary = rear.forward_supply.start_issue("execution-delivered-rounds",roster[0],roster[1],5,"execution-stage")
	_check(issue.ok,"Actual local handoff starts after the formation stops")
	rear.advance_time(40)
	_check(rear.forward_supply.jobs[issue.id].state == "Complete","Shared clock completes the local physical issue")
	_check(ledger.snapshot().consumed.E02 > spent_before,"Delivered rounds autonomously reload and restore actual fire: " + str(rear.combat.inspect_fire(roster[0],"execution-second-target",roster[0]+"-rifle")) + " weapon " + str(ledger.inspect_entity(roster[0]+"-rifle")))
	_check(base.audit().is_empty(),"Autonomous action, interruption and issue reconcile: "+str(base.audit()))
	print("Squad execution regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
