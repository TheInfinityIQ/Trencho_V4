extends SceneTree

const Base = preload("res://game/rear_base/base_simulation.gd")
const ForwardSupply = preload("res://game/forward_supply/forward_supply.gd")
const Records = preload("res://game/identity/identity_records.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_two_local_issues_and_interruption()
	print("Forward supply regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _advance(rear: RefCounted, supply: RefCounted, seconds: float) -> void:
	var end: float = rear.time + seconds
	while rear.time < end - 0.000001:
		var next: float = minf(end,rear.time + 0.25)
		supply.advance_to(next)
		rear.advance_time(next - rear.time)
		supply.settle()


func _test_two_local_issues_and_interruption() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	rear.combat.world.bounds = Rect2i(0,0,4000,6000)
	var people: Array[String] = ["supply-shooter","supply-handler","supply-guard-a","supply-guard-b"]
	for id in people:
		_expect(ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true).ok,"real trained HQ Reserve member " + id)
		rear.dispatch.military_people[id] = "supply-receipt"
		rear.dispatch.hq_reserve[id] = "Occupied"
		_expect(ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"actually issued rifle " + id)
		_expect(ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"actually issued rounds " + id)
	rear.advance_time(8)
	_expect(rear.military.squads.size() == 1,"four equipped people form one real G15 squad")
	if rear.military.squads.is_empty(): return
	var squad: Dictionary = rear.military.squads.values()[0]
	_expect(squad.state == "Active" and squad.roster.size() == 4,"same four are active after physical formation report")
	_expect(ledger.add_place("forward-stop","Declared local supply rendezvous",Vector2(500,20)).ok,"actual forward stop")
	for index in people.size():
		var position: Vector2 = Vector2(506,20) if index == 0 else Vector2(494,20+index-1)
		_expect(ledger.move_entity(people[index],"forward-stop",position).ok,"active member reaches actual forward stop")
	_expect(ledger.add_place("supply-target-place","Hostile observed position",Vector2(516,20)).ok,"real hostile place")
	_expect(ledger.add_person("supply-target","supply-target-place","army-red",Records.Assignment.AVAILABLE,true).ok,"real hostile target")
	_expect(ledger.add_stock("remote-hq-rounds","E02",50,0.02,"hq-stock",rear.PLAYER).ok,"matching stock remains at HQ")
	_expect(ledger.record_consumption("supply-shooter-rounds",29,"Earlier actual rifle use in this focused fixture").ok,"shooter has one final local round")
	_expect(ledger.load_rounds("supply-shooter-rifle","supply-shooter-rounds",1).ok,"last local round loaded")
	var before: int = ledger.total_stock("E02")
	_expect(rear.combat.fire("supply-shooter","supply-target","supply-shooter-rifle").ok,"last physical round fires")
	_expect(not rear.combat.fire("supply-shooter","supply-target","supply-shooter-rifle").ok,"empty rifle stops despite matching HQ stock")
	var supply := ForwardSupply.new(rear)
	_expect(not supply.start_issue("remote-hq-rounds","supply-shooter","supply-handler",5,"forward-stop").ok,"HQ-only stock cannot issue at remote stop")
	_expect(ledger.add_carrier("forward-carrier-a","forward-stop",rear.PLAYER,rear.PLAYER).ok,"first named friendly carrier physically at stop")
	_expect(ledger.add_stock("forward-rounds-a","E02",5,0.02,"forward-carrier-a",rear.PLAYER).ok,"first real forward load")
	var abandoned: Dictionary = supply.start_issue("forward-rounds-a","supply-shooter","supply-handler",5,"forward-stop")
	_expect(abandoned.ok and supply.interrupt(abandoned.id).ok,"unpicked issue can be interrupted")
	_expect(ledger.inspect_entity("forward-rounds-a").holder_id == "forward-carrier-a" and ledger.inspect_entity("forward-rounds-a").available == 5,"unpicked interruption releases only its claim; same stock stays aboard")
	var first: Dictionary = supply.start_issue("forward-rounds-a","supply-shooter","supply-handler",5,"forward-stop")
	_expect(first.ok,"first arrived load starts timed local issue")
	if not first.ok: return
	_expect(supply.person_committed("supply-handler") and supply.person_committed("supply-shooter"),"named handler and recipient have exclusive local commitment")
	_expect(not supply.start_issue("forward-rounds-a","supply-shooter","supply-guard-a",1,"forward-stop").ok,"same recipient and reserved stock cannot be issued twice")
	_expect(ledger.inspect_entity("supply-shooter").contents_mass_kg < 5.0,"reservation alone does not put rounds on rifleman")
	_advance(rear,supply,20)
	_expect(supply.jobs[first.id].state == "Complete","first named handler finishes physical pickup and handoff")
	var first_rounds: String = str(supply.jobs[first.id].issued_stock)
	_expect(ledger.inspect_entity(first_rounds).holder_id == "supply-shooter" and ledger.inspect_entity(first_rounds).quantity == 5,"same five real rounds reach active rifleman")
	_expect(not rear.combat.fire("supply-shooter","supply-target","supply-shooter-rifle").ok,"loose delivered rounds still need actual reload")
	_expect(rear.combat.request_reload("supply-shooter","supply-shooter-rifle",first_rounds,5).ok,"existing G16 local reload consumes delivered loose stock")
	rear.advance_time(20)
	_expect(ledger.inspect_entity("supply-shooter-rifle").loaded_rounds == 5,"actual reload fills weapon from first load")
	_expect(rear.combat.fire("supply-shooter","supply-target","supply-shooter-rifle").ok,"supply restores firing capability")
	_expect(ledger.add_carrier("forward-carrier-b","forward-stop",rear.PLAYER,rear.PLAYER).ok,"second named carrier physically arrives")
	_expect(ledger.add_stock("forward-rounds-b","E02",5,0.02,"forward-carrier-b",rear.PLAYER).ok,"second distinct real load")
	var second: Dictionary = supply.start_issue("forward-rounds-b","supply-shooter","supply-handler",5,"forward-stop")
	_expect(second.ok,"second local resupply cycle begins")
	if not second.ok: return
	_advance(rear,supply,7)
	_expect(not str(supply.jobs[second.id].carried_stock).is_empty(),"second stock has actually been picked by handler")
	var carried_id: String = str(supply.jobs[second.id].carried_stock)
	_expect(supply.interrupt(second.id).ok,"mid-carry interruption is explicit")
	_expect(ledger.inspect_entity(carried_id).holder_id == "supply-handler" and ledger.inspect_entity(carried_id).quantity == 5,"interruption leaves exact five with physical handler")
	_expect(ledger.inspect_entity("forward-rounds-b").quantity == 0 and supply.person_committed("supply-handler"),"no duplicate stock; handler remains committed while holding the interrupted carry")
	_expect(supply.resume_issue(second.id).ok,"same carried portion resumes without another source claim")
	_advance(rear,supply,12)
	_expect(supply.jobs[second.id].state == "Complete" and ledger.inspect_entity(supply.jobs[second.id].issued_stock).holder_id == "supply-shooter","second handoff reaches same active rifleman")
	_expect(ledger.total_stock("E02") == before - 2 + 10,"two fired rounds and two five-round deliveries conserve total physical stock")
	_expect(supply.audit().is_empty() and base.audit().is_empty(),"forward jobs and common ledger remain consistent: " + str(supply.audit()) + " / " + str(base.audit()))
