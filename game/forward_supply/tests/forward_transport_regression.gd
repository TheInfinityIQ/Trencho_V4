extends SceneTree

const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const HQ := Vector2(1640.0,91.0)
const STOP := Vector2(1640.0,300.0)
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_two_physical_cycles()
	print("Forward transport regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _person(rear: RefCounted, id: String, qualification: String = "None") -> void:
	_expect(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,qualification,"None").ok,"real military person " + id)
	rear.dispatch.military_people[id] = "transport-receipt"
	rear.dispatch.hq_reserve[id] = "Occupied"
	if qualification == "None":
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"real rifle for " + id)
		_expect(rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"real matching rounds for " + id)


func _test_two_physical_cycles() -> void:
	var base := Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var supply: RefCounted = rear.forward_supply
	for id in ["transport-a","transport-b","transport-c","transport-d"]:
		_person(rear,id)
	_person(rear,"transport-driver","P08")
	rear.advance_time(8)
	_expect(rear.military.squads.size() == 1,"four equipped people form one actual squad")
	if rear.military.squads.is_empty(): return
	var squad: Dictionary = rear.military.squads.values()[0]
	_expect(ledger.reserve_rear_hull("transport-admission",rear.PLAYER,"transport-fixture").ok,"real hull admission")
	_expect(ledger.create_heavy_output("transport-admission","transport-fixture","transport-t01","T01","hq-berth",rear.PLAYER,Specs.TYPES.T01).ok,"actual T01 at HQ berth")
	_expect(ledger.complete_hq_hull_receipt("transport-t01").ok,"same T01 enters military fleet")
	rear.dispatch.military_hulls["transport-t01"] = "transport-fixture"
	_expect(rear.military.assign_crew("transport-driver","transport-t01","Driver").ok,"qualified driver reports to same hull")
	rear.advance_time(8)
	if not rear.military.vehicles.has("transport-t01"):
		_expect(rear.military.attach_vehicle("transport-t01",squad.platoon).ok,"staffed T01 attaches to actual platoon")
	_expect(rear.military.vehicles.has("transport-t01"),"named military T01 has actual formation attachment")
	_expect(ledger.add_stock("transport-fuel","M08",20,1.0,"hq-berth",rear.PLAYER).ok,"physical fuel at HQ")
	_expect(ledger.begin_carry("initial-hq-01","transport-fuel",20).ok,"real HQ worker carries fuel")
	_expect(ledger.load_vehicle_fuel("initial-hq-01","transport-t01").ok,"real fuel enters T01 tank")
	_expect(ledger.add_place("transport-stop","Declared destination",STOP).ok,"physical forward stop")
	_expect(ledger.move_entity("transport-a","transport-stop",STOP+Vector2(5,0)).ok,"actual member near destination")
	_expect(ledger.add_stock("transport-hq-rounds","E02",120,0.02,"hq-stock",rear.PLAYER).ok,"real HQ freight")
	var outbound: Array = [HQ,STOP]
	var returning: Array = [STOP,HQ]
	var before: int = ledger.total_stock("E02")
	var fuel_before: float = ledger.inspect_entity("transport-t01").fuel
	_expect(not supply.request_delivery("transport-t01","transport-a-rounds",5,"transport-stop",outbound,returning,"initial-hq-02","transport-a").ok,"remote personal stock cannot become HQ freight")
	_expect(not supply.request_delivery("transport-t01","transport-hq-rounds",5,"transport-stop",outbound,returning,"transport-a","transport-a").ok,"formation member cannot impersonate HQ loader")
	var first: Dictionary = supply.request_delivery("transport-t01","transport-hq-rounds",30,"transport-stop",outbound,returning,"initial-hq-02","transport-a")
	_expect(first.ok,"first physical HQ delivery accepted")
	if not first.ok: return
	_expect(supply.hull_committed("transport-t01"),"same hull committed across delivery")
	_expect(not supply.request_delivery("transport-t01","transport-hq-rounds",30,"transport-stop",outbound,returning,"initial-hq-03","transport-a").ok,"second simultaneous mission cannot own same hull")
	rear.advance_time(2)
	_expect(not str(supply.transport.jobs[first.id].task.get("carry","")).is_empty(),"loader physically carries first portion")
	_expect(supply.interrupt_delivery(first.id).ok,"loading can be interrupted")
	var held: int = supply.transport.jobs[first.id].loaded
	rear.advance_time(5)
	_expect(supply.transport.jobs[first.id].loaded == held,"interruption does not teleport more stock")
	var resumed: Dictionary = supply.resume_delivery(first.id)
	_expect(resumed.ok,"same loading task resumes: " + str(resumed))
	rear.advance_time(200)
	var first_row: Dictionary = supply.transport.jobs[first.id]
	_expect(first_row.state == "Complete","first freight arrives, unloads and same hull returns HQ")
	_expect(first_row.loaded == 30 and first_row.unloaded == 30,"exact first manifest accounted for")
	_expect(ledger.inspect_entity("transport-t01").holder_id == "hq-berth","same T01 physically returns to HQ")
	_expect(ledger.inspect_entity("transport-t01").fuel < fuel_before,"route burns actual tank fuel")
	var first_delivered := 0
	for id in first_row.delivered_items:
		var item: Dictionary = ledger.inspect_entity(id)
		if item.holder_id == "transport-stop": first_delivered += int(item.quantity)
	_expect(first_delivered == 30,"actual first stock portions remain at forward stop")
	var second: Dictionary = supply.request_delivery("transport-t01","transport-hq-rounds",20,"transport-stop",outbound,returning,"initial-hq-02","transport-a")
	_expect(second.ok,"second resupply uses returned same hull and remaining HQ freight")
	if not second.ok: return
	rear.advance_time(45)
	var second_row: Dictionary = supply.transport.jobs[second.id]
	_expect(second_row.state == "Outbound" or second_row.state == "Unloading" or second_row.state == "Returning","second freight has left HQ")
	_expect(supply.interrupt_delivery(second.id).ok,"active second delivery can be interrupted")
	var paused_hull: Dictionary = ledger.inspect_entity("transport-t01")
	var paused_position: Vector2 = paused_hull.position
	var paused_fuel: float = paused_hull.fuel
	rear.advance_time(10)
	_expect(ledger.inspect_entity("transport-t01").position.is_equal_approx(paused_position) and is_equal_approx(ledger.inspect_entity("transport-t01").fuel,paused_fuel),"paused hull neither moves nor burns fuel")
	var resume_points: Array = [paused_position,STOP] if second_row.paused_state == "Outbound" else [paused_position,HQ]
	var second_resume: Dictionary = supply.resume_delivery(second.id,resume_points,returning) if second_row.paused_state == "Outbound" else supply.resume_delivery(second.id,[],resume_points)
	_expect(second_resume.ok,"same hull resumes from actual location with declared waypoints: " + str(second_resume))
	rear.advance_time(180)
	second_row = supply.transport.jobs[second.id]
	_expect(second_row.state == "Complete" and second_row.unloaded == 20,"second full physical delivery and return complete")
	_expect(ledger.total_stock("E02") == before,"both cycles conserve exact stock")
	var driver = ledger._entities["transport-driver"]
	driver.health = 0
	_expect(not supply.request_delivery("transport-t01","transport-hq-rounds",5,"transport-stop",outbound,returning,"initial-hq-02","transport-a").ok,"incapacitated actual driver prevents new transport")
	driver.health = 100
	var remaining_fuel: float = ledger.inspect_entity("transport-t01").fuel
	_expect(ledger.burn_vehicle_fuel("transport-t01",remaining_fuel).ok,"actual tank can be depleted")
	_expect(not supply.request_delivery("transport-t01","transport-hq-rounds",5,"transport-stop",outbound,returning,"initial-hq-02","transport-a").ok,"empty physical tank refuses further delivery")
	_expect(supply.audit().is_empty() and base.audit().is_empty(),"transport and common ledger audit remain clean: " + str(supply.audit()) + " / " + str(base.audit()))
