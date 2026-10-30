extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_transport_dismount_capture_and_income()
	_test_contest_reversal_and_decay()
	_test_eligibility_and_nonresource_income()
	print("G18 objective regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _squad(base: RefCounted, prefix: String) -> String:
	var rear: RefCounted = base.rear
	var people: Array[String] = []
	for i in 4:
		var id := "%s-person-%d" % [prefix,i]
		_expect(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"None","None").ok,"actual HQ Reserve squad member")
		rear.dispatch.military_people[id] = prefix
		rear.dispatch.hq_reserve[id] = "Occupied"
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"functional physical rifle")
		_expect(rear.ledger.add_stock(id+"-ammo","E02",30,0.02,id,rear.PLAYER).ok,"matching physical rounds")
		_expect(rear.ledger.load_rounds(id+"-rifle",id+"-ammo",1).ok,"loaded physical round")
		people.append(id)
	var result: Dictionary = rear.military.form_squad("Rifle",people)
	_expect(result.ok,"real Rifle squad forms: "+str(result))
	return str(result.get("id",""))

func _transport(base: RefCounted, squad_id: String) -> String:
	var rear: RefCounted = base.rear
	var hull_id := "capture-transport"
	_expect(rear.ledger.reserve_rear_hull("capture-admission",rear.PLAYER,"capture-fixture").ok,"actual transport admission")
	_expect(rear.ledger.create_heavy_output("capture-admission","capture-fixture",hull_id,"T02","hq-berth",rear.PLAYER,Specs.TYPES.T02).ok,"empty physical transport")
	_expect(rear.ledger.complete_hq_hull_receipt(hull_id).ok,"same transport enters military fleet")
	rear.dispatch.military_hulls[hull_id] = "capture-fixture"
	_expect(rear.ledger.add_person("capture-driver","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08","None").ok,"qualified real driver")
	rear.dispatch.military_people["capture-driver"] = "capture-fixture"
	rear.dispatch.hq_reserve["capture-driver"] = "Occupied"
	_expect(rear.military.assign_crew("capture-driver",hull_id,"Driver").ok,"physical driver report starts")
	rear.advance_time(8)
	_expect(rear.military.vehicles.has(hull_id),"same transport assigned to squad platoon")
	_expect(rear.military.board_squad(squad_id,hull_id).ok,"four physical people board real passenger seats")
	return hull_id

func _test_transport_dismount_capture_and_income() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var squad_id := _squad(base,"a30")
	rear.advance_time(8)
	var hull_id := _transport(base,squad_id)
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	_expect(rear.ledger.add_place("resource-a30","Resource objective",hull.position).ok,"objective has actual physical metre position")
	_expect(rear.objectives.register("resource-a30","Resource").ok,"resource registered without ownership")
	rear.advance_time(30)
	var held: Dictionary = rear.objectives.inspect("resource-a30")
	_expect(held.control == 0.0 and held.owner.is_empty() and held.blue.is_empty(),"parked occupied transport contributes zero capture for thirty seconds")
	var passenger_blockers := 0
	for blocker in held.blockers:
		if str(blocker.person).begins_with("a30-person") and str(blocker.reason).contains("dismount"): passenger_blockers += 1
	_expect(passenger_blockers == 4,"inspection names all four boarded people and their actual exit blocker")
	_expect(is_equal_approx(rear.receiving.snapshot().income,46.0*6.0),"transport passengers grant no resource income beyond baseline")
	_expect(rear.military.exit_squad(squad_id).ok,"same four members physically dismount at legal stopped place")
	rear.advance_time(0)
	_expect(rear.objectives.inspect("resource-a30").blue.size() == 4,"four actual armed dismounted people become eligible")
	rear.advance_time(14.75)
	_expect(rear.objectives.inspect("resource-a30").owner.is_empty(),"neutral control remains unowned before fifteen seconds")
	rear.advance_time(0.25)
	var owned: Dictionary = rear.objectives.inspect("resource-a30")
	_expect(owned.control == 60.0 and owned.owner == rear.PLAYER and owned.income_rate == 1.5 and owned.capture_rate == 0.0,"four dismounted people take neutral control at exact fifteen-second boundary without displaying impossible further progress")
	_expect(is_equal_approx(rear.receiving.snapshot().income,61.0*6.0),"no resource income credited before actual full control")
	rear.advance_time(10)
	_expect(is_equal_approx(rear.receiving.snapshot().income,71.0*6.0+15.0),"owned uncontested Resource adds continuous 1.5/s to existing requisition account")
	_expect(is_equal_approx(rear.receiving.snapshot().money,2500.0+71.0*6.0+15.0),"money and income use same existing requisition ledger")
	_expect(base.audit().is_empty(),"A30 physical squad, transport, objective and money audit reconcile: "+str(base.audit()))

func _test_contest_reversal_and_decay() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var squad_id := _squad(base,"contest")
	rear.advance_time(8)
	_expect(rear.ledger.add_place("resource-contest","Resource objective",Vector2(1640,91)).ok,"physical contested resource")
	_expect(rear.objectives.register("resource-contest","Resource").ok,"registered neutral resource")
	rear.advance_time(10)
	_expect(rear.objectives.inspect("resource-contest").control == 40.0,"four eligible people produce capped four work per second")
	_expect(rear.ledger.add_place("remote-place","Safe remote place",Vector2(1500,91)).ok,"actual departure destination")
	for id in rear.military.squads[squad_id].roster: _expect(rear.ledger.move_entity(id,"remote-place",Vector2(1500,91)).ok,"same member physically leaves radius")
	rear.advance_time(0)
	rear.advance_time(20)
	_expect(rear.objectives.inspect("resource-contest").control == 0.0,"unowned partial progress decays toward zero at two per second")
	for id in rear.military.squads[squad_id].roster: _expect(rear.ledger.move_entity(id,"hq-formation",Vector2(1640,91)).ok,"same member physically returns")
	rear.advance_time(0)
	rear.advance_time(15)
	_expect(rear.objectives.inspect("resource-contest").owner == rear.PLAYER,"returning real squad captures resource")
	for i in 4:
		var id := "red-person-%d" % i
		_expect(rear.ledger.add_person(id,"resource-contest","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"real hostile person enters objective")
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,"army-red","E02",10).ok,"hostile carries functional rifle")
		_expect(rear.ledger.add_stock(id+"-ammo","E02",1,0.02,id,"army-red").ok,"hostile carries matching round")
	rear.advance_time(0)
	var contested: Dictionary = rear.objectives.inspect("resource-contest")
	_expect(contested.state == "Contested" and contested.blue.size() == 4 and contested.red.size() == 4,"two actual armies contest without progress")
	var prior_income: float = rear.receiving.snapshot().income
	rear.advance_time(10)
	_expect(rear.objectives.inspect("resource-contest").control == 60.0 and is_equal_approx(rear.receiving.snapshot().income-prior_income,60.0),"contested resource grants no additional income")
	for id in rear.military.squads[squad_id].roster: _expect(rear.ledger.move_entity(id,"remote-place",Vector2(1500,91)).ok,"blue squad physically retreats")
	rear.advance_time(0)
	rear.advance_time(15)
	_expect(rear.objectives.inspect("resource-contest").control == 0.0 and rear.objectives.inspect("resource-contest").owner.is_empty(),"four red people remove blue owner at zero after fifteen seconds")
	rear.advance_time(15)
	_expect(rear.objectives.inspect("resource-contest").control == -60.0 and rear.objectives.inspect("resource-contest").owner == "army-red","another fifteen seconds reverses full ownership")
	_expect(base.audit().is_empty(),"contested and reversed actual identities reconcile: "+str(base.audit()))

func _test_eligibility_and_nonresource_income() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var site := Vector2(1700,200)
	_expect(rear.ledger.add_place("route-hub","Physical route hub",site).ok,"actual operational place")
	_expect(rear.objectives.register("route-hub","Route Hub").ok,"route hub has control but no material or money grant")
	for i in 5:
		var id := "eligible-%d" % i
		_expect(rear.ledger.add_person(id,"route-hub",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"actual person within objective radius")
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",10).ok,"actual functional carried weapon")
		if i < 4:
			_expect(rear.ledger.add_stock(id+"-round","E02",1,0.02,id,rear.PLAYER).ok,"one physically available matching round")
	rear.advance_time(0)
	var seen: Dictionary = rear.objectives.inspect("route-hub")
	_expect(seen.blue.size() == 4 and seen.capture_rate == 4.0,"fifth empty rifle supplies zero work; four eligible people meet cap")
	_expect(seen.blockers.size() == 1 and seen.blockers[0].reason.contains("matching"),"inspection explains empty-rifle ineligibility")
	_expect(rear.ledger.add_stock("eligible-4-round","E02",1,0.02,"eligible-4",rear.PLAYER).ok,"fifth matching round physically added")
	rear.advance_time(0)
	_expect(rear.objectives.inspect("route-hub").blue.size() == 5 and rear.objectives.inspect("route-hub").capture_rate == 4.0,"five eligible bodies still capped at four work")
	_expect(rear.ledger.add_place("just-outside","Actual point beyond radius",site+Vector2(25.01,0)).ok,"physical beyond-radius point")
	_expect(rear.ledger.move_entity("eligible-4","just-outside",site+Vector2(25.01,0)).ok,"same fifth body physically leaves radius")
	rear.advance_time(0)
	_expect(rear.objectives.inspect("route-hub").blue.size() == 4,"25.01 m is outside capture radius")
	_expect(rear.ledger.move_entity("eligible-4","route-hub",site+Vector2(25,0)).ok,"same person reaches exact radius boundary")
	rear.advance_time(0)
	_expect(rear.objectives.inspect("route-hub").blue.size() == 5,"25.0 m boundary is included")
	rear.combat._apply_stress("eligible-0",-50,0,false)
	rear.advance_time(0)
	_expect(rear.objectives.inspect("route-hub").blue.size() == 4 and str(rear.objectives.inspect("route-hub").blockers).contains("Broken"),"G16 Broken person cannot contribute work")
	_expect(rear.combat.injure("eligible-1",100).ok,"actual second person incapacitated")
	rear.advance_time(0)
	_expect(rear.objectives.inspect("route-hub").blue.size() == 3,"incapacitated person also supplies zero")
	var start_money: float = rear.receiving.snapshot().money
	rear.advance_time(20)
	_expect(rear.objectives.inspect("route-hub").owner == rear.PLAYER and is_equal_approx(rear.receiving.snapshot().money-start_money,120.0),"three people take twenty seconds, but Route Hub adds no requisition to baseline")
	_expect(base.audit().is_empty(),"eligibility filters and nonresource income preserve identities: "+str(base.audit()))
