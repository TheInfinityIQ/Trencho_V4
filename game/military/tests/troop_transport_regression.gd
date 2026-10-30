extends SceneTree

const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const BattlefieldStart = preload("res://game/scenario/battlefield_start.gd")
const HQ := Vector2(1640,91)
const SAFE := Vector2(1640,150)
var checks := 0
var failures := 0


func _initialize() -> void:
	if "--seeded-only" not in OS.get_cmdline_user_args():
		_test_two_loaded_t02()
		_test_owner_filter_and_generated_names()
	if "--fixture-only" not in OS.get_cmdline_user_args(): _test_seeded_army_movement()
	print("Troop transport regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _add_squad(rear: RefCounted, side: String, number: int, count: int, stage: String, company: String, platoon: String) -> String:
	var owner: String = "army-"+side
	var squad_id: String = "%s-squad-%d" % [side,number]
	var people: Array[String] = []
	for index in count:
		var id: String = "%s-person-%d-%d" % [side,number,index]
		_check(rear.ledger.add_person(id,stage,owner,Records.Assignment.AVAILABLE,true,"None","None").ok,"real initial passenger " + id)
		_check(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,owner,"E02",30).ok,"actual carried rifle " + id)
		_check(rear.ledger.add_stock(id+"-rounds","E02",60,0.02,id,owner).ok,"actual carried rounds " + id)
		people.append(id)
	_check(rear.military.add_initial_squad(squad_id,"Rifle",people,company,platoon,owner).ok,"initial squad registered " + squad_id)
	if stage == "hq-berth":
		for index in people.size():
			_check(rear.ledger.move_entity(people[index],stage,HQ+Vector2(float(index%4)*2.0-3.0,3.0+float(index/4)*2.0)).ok,"passenger waits near truck before timed approach")
	return squad_id


func _add_blue_t02(rear: RefCounted, id: String, driver_id: String) -> void:
	var ledger: RefCounted = rear.ledger
	_check(ledger.reserve_rear_hull(id+"-admission",rear.PLAYER,"transport-fixture").ok,"real T02 admission " + id)
	_check(ledger.create_heavy_output(id+"-admission","transport-fixture",id,"T02","hq-berth",rear.PLAYER,Specs.TYPES.T02).ok,"actual T02 hull " + id)
	_check(ledger.complete_hq_hull_receipt(id).ok,"same T02 military receipt")
	rear.dispatch.military_hulls[id] = "transport-fixture"
	_check(ledger.add_person(driver_id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08","None").ok,"qualified P08 driver " + id)
	rear.dispatch.military_people[driver_id] = "transport-receipt"
	rear.dispatch.hq_reserve[driver_id] = "Occupied"
	_check(rear.military.assign_crew(driver_id,id,"Driver").ok,"same driver reports to T02")
	_check(ledger.add_stock(id+"-fuel","M08",20,1.0,"hq-berth",rear.PLAYER).ok,"physical tank fuel")


func _test_two_loaded_t02() -> void:
	var base: RefCounted = Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	_check(ledger.add_place("troop-safe","Declared safe dismount",SAFE).ok,"real safe place")
	var squads: Array[String] = []
	for number in 4:
		var platoon: String = "blue-platoon-1" if number < 2 else "blue-platoon-2"
		squads.append(_add_squad(rear,"blue",number,8,"hq-berth","blue-company",platoon))
	_add_blue_t02(rear,"blue-t02-a","blue-driver-a")
	_add_blue_t02(rear,"blue-t02-b","blue-driver-b")
	rear.advance_time(8)
	for id in ["blue-t02-a","blue-t02-b"]:
		if not rear.military.vehicles.has(id): _check(rear.military.attach_vehicle(id,"blue-platoon-1").ok,"same staffed T02 attaches")
		_check(rear.military.vehicles.has(id),"owned T02 military element exists")
		var fuel_id: String = id+"-fuel"
		var worker: String = "initial-hq-01" if id == "blue-t02-a" else "initial-hq-02"
		_check(ledger.begin_carry(worker,fuel_id,20).ok,"real HQ worker carries M08")
		_check(ledger.load_vehicle_fuel(worker,id).ok,"same T02 tank gains actual fuel")
	_check(ledger.add_stock("troop-issue-conflict","E02",5,0.02,"hq-berth",rear.PLAYER).ok,"physical local stock for commitment refusal")
	var before_rounds: int = ledger.total_stock("E02")
	var out: Array = [HQ,SAFE]
	var home: Array = [SAFE,HQ]
	var first_driver = ledger._entities["blue-driver-a"]
	first_driver.health = 0
	_check(not rear.military.request_troop_trip("blue-t02-a",[squads[0],squads[1]],"hq-berth","troop-safe",out,home).ok,"incapacitated actual driver cannot start a trip or burn fuel")
	first_driver.health = 100
	var first: Dictionary = rear.military.request_troop_trip("blue-t02-a",[squads[0],squads[1]],"hq-berth","troop-safe",out,home)
	var second: Dictionary = rear.military.request_troop_trip("blue-t02-b",[squads[2],squads[3]],"hq-berth","troop-safe",out,home)
	_check(first.ok and second.ok,"two separate T02 each accept two actual eight-person squads")
	if not first.ok or not second.ok: return
	_check(not rear.military.request_troop_trip("blue-t02-a",[squads[0]],"hq-berth","troop-safe",out,home).ok,"one T02 cannot own overlapping troop work")
	_check(not rear.forward_supply.start_issue("troop-issue-conflict","blue-person-0-0","blue-person-0-1",5,"hq-berth").ok,"local issue cannot seize people reserved for timed boarding")
	_check(ledger.inspect_entity("troop-issue-conflict").available == 5,"refused conflicting forward work leaves same stock unclaimed")
	_check(rear.military.vehicles["blue-t02-a"].passenger_squads.size() == 2 and rear.military.vehicles["blue-t02-a"].passenger_squad == squads[0],"Organization owns both squads while retaining first-squad diagnostic field")
	rear.advance_time(10)
	var first_row: Dictionary = rear.military.troop_transport.jobs[first.id]
	_check(first_row.boarded > 0 and first_row.boarded < 16,"boarding changes real passenger holders over time")
	_check(rear.military.interrupt_troop_trip(first.id).ok,"first T02 boarding can be interrupted")
	var boarded_before: int = first_row.boarded
	rear.advance_time(6)
	_check(first_row.boarded == boarded_before and ledger.inspect_entity("blue-t02-a").fuel == 20.0,"paused T02 neither boards nor burns fuel")
	_check(rear.military.resume_troop_trip(first.id).ok,"same physical boarding resumes")
	for _step in 90:
		var travelling: Dictionary = rear.military.troop_transport.jobs[second.id]
		if travelling.state == "Outbound" and travelling.route_distance > 0.0: break
		rear.advance_time(1)
	var moving: Dictionary = rear.military.troop_transport.jobs[second.id]
	_check(moving.state == "Outbound" and moving.route_distance > 0.0,"second T02 starts measured travel only after all sixteen board")
	_check(rear.military.interrupt_troop_trip(second.id).ok,"occupied T02 route can be paused")
	var held_position: Vector2 = ledger.inspect_entity("blue-t02-b").position
	var held_fuel: float = ledger.inspect_entity("blue-t02-b").fuel
	rear.advance_time(5)
	_check(ledger.inspect_entity("blue-t02-b").position.is_equal_approx(held_position) and is_equal_approx(ledger.inspect_entity("blue-t02-b").fuel,held_fuel),"route interruption preserves exact travelled position and remaining tank fuel")
	var second_driver = ledger._entities["blue-driver-b"]
	second_driver.health = 0
	_check(not rear.military.resume_troop_trip(second.id,[held_position,SAFE]).ok,"incapacitated driver blocks mid-route resume before movement")
	second_driver.health = 100
	_check(rear.military.resume_troop_trip(second.id,[held_position,SAFE]).ok,"occupied T02 resumes from actual hull location")
	rear.advance_time(130)
	first_row = rear.military.troop_transport.jobs[first.id]
	var second_row: Dictionary = rear.military.troop_transport.jobs[second.id]
	_check(first_row.state == "Complete" and second_row.state == "Complete","both full T02 trips dismount and return")
	_check(first_row.boarded == 16 and first_row.dismounted == 16 and second_row.boarded == 16 and second_row.dismounted == 16,"all 32 distinct passengers complete real seat and exit boundaries")
	for id in ["blue-t02-a","blue-t02-b"]:
		var hull: Dictionary = ledger.inspect_entity(id)
		_check(hull.holder_id == "hq-berth" and hull.passengers.is_empty() and hull.fuel < 20.0,"same empty T02 returns to origin after burning tank fuel")
	for squad_id in squads:
		_check(rear.military.squads[squad_id].vehicle.is_empty(),"dismounted squad regains ground capability")
		for person_id in rear.military.squads[squad_id].roster:
			_check(ledger.inspect_entity(person_id).holder_id == "troop-safe","same person remains at declared safe dismount place")
	_check(ledger.total_stock("E02") == before_rounds,"passenger weapons and rounds conserve physical stock")
	_check(base.audit().is_empty(),"two T02, 32 passenger trip preserves common identity invariants: " + str(base.audit()))


func _test_owner_filter_and_generated_names() -> void:
	var base: RefCounted = Base.new(true,true)
	var rear: RefCounted = base.rear
	_check(rear.ledger.add_place("red-stage","Declared opposing start",Vector2(2000,600)).ok,"red start place")
	var red_id: String = _add_squad(rear,"red",0,4,"red-stage","company-02","platoon-02")
	_check(rear.military.snapshot().squads.size() == 1 and rear.military.snapshot(rear.PLAYER).squads.is_empty(),"authoritative view retains red, player view omits unseen red")
	_check(rear.military.snapshot(rear.PLAYER).shortages.is_empty(),"player shortage list does not expose red readiness")
	var blue_parent: Dictionary = rear.military._available_platoon()
	_check(not blue_parent.is_empty() and blue_parent.id != "platoon-02" and blue_parent.company != "company-02","generated blue parent IDs skip opposing declared IDs")
	_check(rear.military.squads[red_id].company == "company-02" and base.audit().is_empty(),"red original hierarchy remains intact after blue parent generation")


func _test_seeded_army_movement() -> void:
	var base: RefCounted = Base.new(true,true,true,Vector2(2000,450),false)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var armies: Dictionary = BattlefieldStart.apply(base)
	for owner in armies:
		for vehicle in armies[owner].hulls:
			_check(rear.military.attach_initial_vehicle(vehicle.id,vehicle.parent).ok,"seeded same-army military hull attaches at time zero: " + vehicle.id)
	var blue_t01: String = "start-blue-vehicle-02"
	var blue_t03: String = "start-blue-vehicle-03"
	var reposition_ids: Array[String] = []
	var reposition_destinations: Dictionary = {}
	for id in [blue_t01,blue_t03]:
		var hull: Dictionary = ledger.inspect_entity(id)
		var start: Vector2 = hull.position
		var destination_id: String = id+"-reposition-test"
		var destination: Vector2 = start+Vector2(0,-12)
		_check(ledger.add_place(destination_id,"Declared military support position",destination).ok,"real reposition destination")
		var moved: Dictionary = rear.military.request_reposition(id,destination_id,[start,destination],[destination,start])
		_check(moved.ok,"attached empty support hull receives bounded reposition: " + str(moved))
		if not moved.ok: continue
		_check(not rear.military.request_reposition(id,destination_id,[start,destination],[destination,start]).ok,"same hull cannot receive overlapping reposition")
		_check(rear.military.interrupt_troop_trip(moved.id).ok,"empty military movement can pause")
		var held_fuel: float = ledger.inspect_entity(id).fuel
		rear.advance_time(3)
		_check(is_equal_approx(ledger.inspect_entity(id).fuel,held_fuel),"paused empty hull does not burn fuel")
		_check(rear.military.resume_troop_trip(moved.id,[start,destination]).ok,"same empty movement resumes from actual position")
		reposition_ids.append(moved.id)
		reposition_destinations[id] = {"place":destination_id,"position":destination,"fuel":held_fuel}
	rear.advance_time(30)
	for id in [blue_t01,blue_t03]:
		if not reposition_destinations.has(id): continue
		var target: Dictionary = reposition_destinations[id]
		var actual: Dictionary = ledger.inspect_entity(id)
		var complete := false
		for movement_id in reposition_ids:
			if rear.military.troop_transport.jobs[movement_id].hull == id:
				complete = rear.military.troop_transport.jobs[movement_id].state == "Complete"
		_check(complete and actual.holder_id == target.place and actual.position.is_equal_approx(target.position),"empty military hull completes at destination without automatic return")
		_check(actual.fuel < target.fuel and actual.passengers.is_empty(),"reposition burns actual tank fuel without inventing passengers")
	var red_t02: String = "start-red-vehicle-00"
	var red_pad: String = red_t02+"-pad"
	var red_squad: String = "start-red-squad-00"
	var red_hull: Dictionary = ledger.inspect_entity(red_t02)
	var red_target: Vector2 = red_hull.position+Vector2(0,-36)
	_check(ledger.add_place("red-dismount-test","Declared opposing safe dismount",red_target).ok,"red real dismount")
	for id in rear.military.squads[red_squad].roster:
		_check(ledger.move_entity(id,red_pad,ledger.inspect_entity(id).position).ok,"red squad stages at its actual T02 pad")
	var red_trip: Dictionary = rear.military.request_troop_trip(red_t02,[red_squad],red_pad,"red-dismount-test",[red_hull.position,red_target],[red_target,red_hull.position])
	_check(red_trip.ok,"same ordinary troop trip accepts one opposing Rifle squad with its own actual driver: " + str(red_trip))
	if red_trip.ok:
		var blue_jobs: Array = rear.military.snapshot(rear.PLAYER).troop_transport.rows
		var leaked := false
		for job in blue_jobs:
			if job.owner != rear.PLAYER: leaked = true
		_check(not leaked,"player filtered military view hides opposing transport activity")
		rear.advance_time(90)
		var row: Dictionary = rear.military.troop_transport.jobs[red_trip.id]
		_check(row.state == "Complete" and row.boarded == 8 and row.dismounted == 8,"opposing T02 boards, dismounts and returns its eight actual soldiers")
		_check(ledger.inspect_entity(red_t02).holder_id == red_pad and ledger.inspect_entity(red_t02).passengers.is_empty(),"opposing same hull returns empty to its actual pad")
	_check(base.audit().is_empty(),"seeded blue and red military moves preserve shared physical ledger: " + str(base.audit()))
