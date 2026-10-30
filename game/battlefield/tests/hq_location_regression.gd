extends SceneTree
## HQ handling and formation report must use one scenario-declared location.
const Rear = preload("res://game/staffing/rear_simulation.gd")
const Dispatch = preload("res://game/dispatch/dispatch_service.gd")
const Hq = preload("res://game/hq/hq_logistics.gd")
const Military = preload("res://game/military/organization.gd")
const Records = preload("res://game/identity/identity_records.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	for at in [Vector2(1640,91),Vector2(2000,400)]: _exercise(at)
	print("HQ location regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _exercise(at: Vector2) -> void:
	var rear := Rear.new("Empty")
	rear.dispatch = Dispatch.new(rear,at)
	rear.hq = Hq.new(rear)
	rear.military = Military.new(rear)
	var ledger: RefCounted = rear.ledger
	_check(ledger.inspect_entity("hq-stock").position == at and ledger.inspect_entity("hq-formation").position == at,"Stock and formation use declared HQ")
	_check(ledger.inspect_entity("hq-queue").position == at+Vector2(-40,0),"Queue retains its local offset")
	for index in 4:
		var id := "location-person-%d" % index
		_check(ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"None","None").ok,"Real reserve person")
		rear.dispatch.military_people[id] = "scenario"
		rear.dispatch.hq_reserve[id] = "Occupied"
		_check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Real rifle")
		_check(ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"Real rounds")
	_check(ledger.add_stock("location-helmet","E03",1,1,"hq-stock",rear.PLAYER).ok,"Local HQ equipment")
	var issue: Dictionary = rear.hq.request_person_stock("location-person-0","E03",1)
	_check(issue.ok,"Reserve member requests actual local equipment")
	rear.advance_time(50)
	_check(rear.hq.jobs[issue.id].state == "Complete","Local issue completes at configured HQ")
	_check(ledger.available_stock_at("location-person-0","E03") == 1,"Same real helmet reaches recipient")
	_check(rear.military.squads.size() == 1,"Equipped people form one squad after local issue")
	for index in 4:
		var person: Dictionary = ledger.inspect_entity("location-person-%d" % index)
		_check(person.assignment == "Formation Duty" and person.position.distance_to(at) < 20,"Formation report stays at declared HQ")
	_check(rear.audit().is_empty() and rear.hq.audit().is_empty() and rear.military.audit().is_empty(),"Configured HQ preserves identities and goods")

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
