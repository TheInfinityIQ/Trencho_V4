extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Routes = preload("res://game/routes/route_planner.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_a33_material_and_time()
	_a23_live_vehicle_route()
	_a34_foot_queue()
	_damage_repair_rebuild_upgrade()
	_upgrade_and_interruption()
	_collapse_on_water()
	_tank_tow_load()
	_exclusive_engineering()
	_damaged_foot_mass()
	_collapse_vehicle()
	_boarded_passenger_and_move_failure()
	_impossible_approaches()
	_repeated_upgrade_cancellation()
	_damage_retimes_active_tow()
	print("G20 bridge regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(detail)

func _site(base: RefCounted, code: String, water_start: int, width: int) -> Dictionary:
	var world: RefCounted = base.rear.combat.world
	world.paint(Rect2i(water_start,10,width,20),"TR11")
	var ordered: Dictionary = base.rear.bridges.order(code,Vector2(water_start-0.5,20.5),Vector2(water_start+width+0.5,20.5))
	_check(ordered.ok,"actual two-bank "+code+" order: "+ordered.get("message",""))
	return ordered

func _engineer(base: RefCounted, bridge_id: String, suffix: String) -> String:
	var rear: RefCounted = base.rear
	var person_id := bridge_id+"-engineer-"+suffix
	var bank_place: String = rear.bridges.projects[bridge_id].places[0]
	_check(rear.ledger.add_person(person_id,bank_place,rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02").ok,"actual P02 at construction bank")
	_check(rear.ledger.add_stock(person_id+"-kit","E08",1,5.0,person_id,rear.PLAYER).ok,"actual engineer kit")
	_check(rear.bridges.assign_engineer(bridge_id,person_id).ok,"engineer assigned")
	return person_id

func _stage(base: RefCounted, bridge_id: String, count: int) -> void:
	var rear: RefCounted = base.rear
	var bank: Vector2 = rear.bridges.projects[bridge_id].banks[0]
	var carrier_id := bridge_id+"-carrier"
	_check(rear.ledger.add_carrier(carrier_id,"hq-stock",rear.PLAYER,rear.PLAYER).ok,"real material carrier")
	var stock_id := bridge_id+"-m11"
	_check(rear.ledger.add_stock(stock_id,"M11",count,1.0,carrier_id,rear.PLAYER).ok,"real M11 on carrier")
	_check(not rear.bridges.deliver_material(bridge_id,stock_id,count).ok,"remote material cannot stage")
	_check(rear.ledger.move_entity(carrier_id,"hq-stock",bank).ok,"controlled carrier arrival at bank")
	_check(rear.bridges.deliver_material(bridge_id,stock_id,count).ok,"whole physical M11 staged")

func _build(base: RefCounted, code: String, water_start: int, width: int) -> String:
	var ordered: Dictionary = _site(base,code,water_start,width)
	if not ordered.ok: return ""
	var id: String = ordered.id
	_engineer(base,id,"one")
	_engineer(base,id,"two")
	_stage(base,id,ordered.m11)
	base.rear.advance_time(float(ordered.work)/2.0)
	_check(base.rear.bridges.inspect(id).state == "Complete","actual bridge completes with two engineers")
	return id

func _a33_material_and_time() -> void:
	var base := Base.new(true)
	var ordered: Dictionary = _site(base,"B03",101,30)
	if not ordered.ok: return
	var id: String = ordered.id
	_check(ordered.span == 30 and ordered.m11 == 2400 and ordered.work == 1200 and ordered.max_health == 7000,"A33 exact 30 m B03 blueprint")
	for n in range(4): _engineer(base,id,str(n))
	base.rear.advance_time(500)
	_check(base.rear.bridges.inspect(id).progress == 0.0 and base.rear.bridges.inspect(id).m11_consumed == 0,"four engineers cannot build from remote stock")
	_stage(base,id,2400)
	_check(base.rear.bridges.inspect(id).m11_consumed == 2400 and base.rear.ledger.available_stock_at(base.rear.bridges.projects[id].places[0],"M11") == 0,"A33 full delivered M11 consumed exactly once")
	base.rear.advance_time(299.75)
	_check(base.rear.bridges.inspect(id).progress == 1199.0 and base.rear.bridges.inspect(id).state != "Complete","A33 fractional time does not complete early")
	base.rear.advance_time(0.25)
	_check(base.rear.bridges.inspect(id).state == "Complete" and base.rear.bridges.inspect(id).health == 7000,"A33 four P02 complete after exactly 300 active seconds")
	_check(base.audit().is_empty(),"A33 ledger audit: "+str(base.audit()))

func _hull(base: RefCounted, id: String, type: String, position: Vector2) -> void:
	var rear: RefCounted = base.rear
	var claim := id+"-claim"
	_check(rear.ledger.reserve_rear_hull(claim,rear.PLAYER,"bridge-test").ok,"actual hull admission")
	_check(rear.ledger.create_heavy_output(claim,"bridge-test",id,type,"hq-berth",rear.PLAYER,Specs.TYPES[type]).ok,"actual manufactured hull")
	var fueler := id+"-fueler"
	_check(rear.ledger.add_person(fueler,"hq-berth",rear.PLAYER,Records.Assignment.HQ_DUTY,true).ok,"actual HQ fuel worker")
	var fuel_stock := id+"-fuel"
	var fuel_count: int = int(Specs.TYPES[type].tank_capacity)
	_check(rear.ledger.add_stock(fuel_stock,"M08",fuel_count,1.0,"hq-berth",rear.PLAYER).ok,"physical M08 at hull")
	for n in range(int(fuel_count/20)):
		_check(rear.ledger.begin_carry(fueler,fuel_stock,20).ok,"worker carries twenty actual fuel units")
		_check(rear.ledger.load_vehicle_fuel(fueler,id).ok,"twenty actual fuel units enter same hull")
	_check(rear.ledger.add_place(id+"-holding","Bridge fixture holding area",position).ok,"physical vehicle holding place")
	_check(rear.ledger.move_entity(id,id+"-holding",position).ok,"actual hull moved to holding point")

func _a23_live_vehicle_route() -> void:
	var base := Base.new(true)
	var b02 := _build(base,"B02",101,20)
	var b03 := _build(base,"B03",301,30)
	if b02.is_empty() or b03.is_empty(): return
	var rear: RefCounted = base.rear
	_hull(base,"a23-apc","T04",Vector2(80.5,20.5))
	_check(rear.ledger.move_entity("a23-apc","hq-berth",rear.ledger.inspect_entity("hq-berth").position).ok,"APC stops at actual HQ crew berth")
	_check(rear.ledger.complete_hq_hull_receipt("a23-apc").ok,"same APC transfers to military control")
	for station in ["Driver","Gunner","Commander"]:
		var crew_id: String = "a23-"+str(station).to_lower()
		_check(rear.ledger.add_person(crew_id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08").ok,"actual qualified APC crew reserve")
		_check(rear.ledger.request_military_crew_report(crew_id,"a23-apc",station).ok,"distinct real APC station reserved")
		_check(rear.ledger.move_entity(crew_id,"hq-berth",rear.ledger.inspect_entity("hq-berth").position).ok,"same crew member physically reaches APC")
		_check(rear.ledger.complete_military_crew_report(crew_id,"a23-apc",station).ok,"actual P08 occupies named APC station")
	_check(rear.ledger.move_entity("a23-apc","a23-apc-holding",Vector2(80.5,20.5)).ok,"fully crewed APC reaches B02 holding")
	for n in range(8): _check(rear.ledger.add_person("a23-passenger-"+str(n),"a23-apc",rear.PLAYER,Records.Assignment.PASSENGER,true).ok,"actual APC passenger")
	_check(rear.ledger.add_stock("a23-freight","M11",1000,1.0,"a23-apc",rear.PLAYER).ok,"actual APC payload")
	_check(rear.ledger.add_stock("a23-ammo","E26",240,0.5,"a23-apc",rear.PLAYER).ok,"full actual APC autocannon rack")
	_check(rear.ledger.inspect_entity("a23-apc").crew.size() == 3 and rear.ledger.inspect_entity("a23-apc").passengers.size() == 8 and rear.ledger.inspect_entity("a23-apc").ammunition.E26 == 240 and rear.ledger.inspect_entity("a23-apc").fuel == 80.0,"A23 actual crew, passengers, rack and full tank remain on same hull")
	var gross := Routes.gross_kg(rear.ledger,"a23-apc")
	_check(gross >= 16000.0,"A23 nested crew, passengers, rack, payload and fuel included")
	_check(not rear.bridges.request_crossing(b02,"a23-apc",0).ok,"A23 loaded APC cannot enter live B02")
	_check(rear.ledger.move_entity("a23-apc","a23-apc-holding",Vector2(280.5,20.5)).ok,"same loaded APC reaches B03 holding")
	_check(rear.bridges.request_crossing(b03,"a23-apc",0).ok,"A23 same loaded APC admitted on live B03")
	var fuel_before: float = rear.ledger.inspect_entity("a23-apc").fuel
	rear.advance_time(0)
	_check(rear.bridges.inspect(b03).traffic.size() == 1,"one actual APC occupies B03")
	_check(rear.bridges.request_crossing(b03,"a23-apc",0).ok == false,"occupied APC cannot duplicate crossing")
	rear.advance_time(100)
	_check(rear.ledger.inspect_entity("a23-apc").position.distance_to(Vector2(351.5,20.5)) < 0.01,"A23 actual APC traversed to far holding point")
	_check(rear.ledger.inspect_entity("a23-apc").fuel < fuel_before,"A23 live crossing burned actual vehicle fuel")
	_check(base.audit().is_empty(),"A23 loaded vehicle accounting: "+str(base.audit()))

func _a34_foot_queue() -> void:
	var base := Base.new(true)
	var id := _build(base,"B01",101,20)
	if id.is_empty(): return
	var rear: RefCounted = base.rear
	_hull(base,"a34-truck","T02",Vector2(80.5,20.5))
	_check(not rear.bridges.request_crossing(id,"a34-truck",0).ok,"A34 B01 excludes every vehicle")
	var total_mass := 0.0
	for n in range(9):
		var person_id := "a34-person-"+str(n)
		_check(rear.ledger.add_person(person_id,"hq-stock",rear.PLAYER,Records.Assignment.AVAILABLE,true).ok,"A34 person exists")
		_check(rear.ledger.move_entity(person_id,"hq-stock",Vector2(80.5,20.5)).ok,"A34 person at holding")
		_check(rear.ledger.add_stock(person_id+"-gear","E08",1,5.0,person_id,rear.PLAYER).ok,"A34 actual equipped person")
		if n < 8: total_mass += rear.ledger.inspect_entity(person_id).unit_mass_kg+rear.ledger.inspect_entity(person_id).contents_mass_kg
		_check(rear.bridges.request_crossing(id,person_id,0).ok,"A34 equipped person queues")
	_check(total_mass == 680.0 and total_mass <= 1000.0,"A34 actual bodies and gear checked against B01 load")
	rear.advance_time(0)
	_check(rear.bridges.inspect(id).traffic.size() == 8 and rear.bridges.inspect(id).queued.size() == 1,"A34 eight actual people occupy span; ninth waits")
	rear.advance_time(50)
	_check(rear.bridges.inspect(id).traffic.size() == 1,"A34 ninth person starts only after first party clears")
	_check(base.audit().is_empty(),"A34 infantry ledger accounting: "+str(base.audit()))

func _damage_repair_rebuild_upgrade() -> void:
	var base := Base.new(true)
	var id := _build(base,"B02",101,20)
	if id.is_empty(): return
	var rear: RefCounted = base.rear
	var bridge: RefCounted = rear.bridges
	_check(bridge.damage(id,1500).ok,"actual B02 damage applied")
	_check(bridge.inspect(id).effective_load_kg == 5000.0 and bridge.inspect(id).speed_cap_mps == 2.0,"damaged B02 halves load and speed")
	var first: String = bridge.projects[id].places[0]
	_check(rear.ledger.add_person("repairer",first,rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02").ok,"repairer at bank")
	_check(rear.ledger.add_stock("repairer-kit","E08",1,5.0,"repairer",rear.PLAYER).ok,"repairer kit")
	_check(rear.ledger.add_stock("repair-m11","M11",10,1.0,first,rear.PLAYER).ok,"repair M11 staged")
	_check(not bridge.request_repair(id,["repairer"]).ok,"damage safety delay blocks immediate repair")
	rear.advance_time(10)
	_check(not bridge.request_repair(id,["repairer","repairer"]).ok,"one repair engineer cannot count twice")
	_check(bridge.request_repair(id,["repairer"]).ok,"repair consumes ten actual local M11")
	rear.advance_time(40)
	_check(bridge.inspect(id).health == 1600,"40 engineer-work restores capped 100 health")
	_check(rear.ledger.add_stock("interrupted-repair-m11","M11",10,1.0,first,rear.PLAYER).ok,"next repair has fresh local M11")
	_check(bridge.damage(id,100).ok,"new actual damage interrupts repair eligibility")
	rear.advance_time(10)
	_check(bridge.request_repair(id,["repairer"]).ok,"second local repair commits ten M11")
	_check(bridge.damage(id,5000).ok and bridge.inspect(id).state == "Destroyed","whole span destroyed")
	_check(not bridge.repairs.has(id),"full destruction cancels unfinished repair without free health")
	_check(bridge.rebuild(id,1).ok,"rebuild can choose other supported bank")
	_check(bridge.inspect(id).m11_consumed == 0 and bridge.inspect(id).state != "Complete","rebuild needs full fresh material and work")
	var far: Vector2 = bridge.projects[id].banks[1]
	for suffix in ["one","two"]:
		var person_id: String = id+"-engineer-"+str(suffix)
		_check(rear.ledger.move_entity(person_id,id+"-b",far).ok,"same engineer reaches far supported bank")
		_check(bridge.assign_engineer(id,person_id).ok,"far-bank engineer joins rebuild")
	_check(rear.ledger.add_stock("rebuild-m11","M11",800,1.0,id+"-carrier",rear.PLAYER).ok,"full fresh B02 M11 placed on actual carrier")
	_check(rear.ledger.move_entity(id+"-carrier",id+"-b",far).ok,"same carrier reaches far bank")
	_check(bridge.deliver_material(id,"rebuild-m11",800).ok,"full rebuild M11 delivered to far bank")
	rear.advance_time(10)
	_check(bridge.inspect(id).m11_consumed == 800,"rebuild consumes whole new batch after damage safety delay")
	rear.advance_time(200)
	_check(bridge.inspect(id).state == "Complete" and bridge.inspect(id).effective_load_kg == 10000.0,"far-bank rebuild restores live B02 after full original work")
	_check(base.audit().is_empty(),"bridge restoration audit: "+str(base.audit()))

func _upgrade_and_interruption() -> void:
	var base := Base.new(true)
	var id := _build(base,"B02",101,20)
	if id.is_empty(): return
	var rear: RefCounted = base.rear
	var bridge: RefCounted = rear.bridges
	_check(bridge.upgrade(id).ok,"sound empty B02 closes for B03 upgrade")
	_check(bridge.inspect(id).m11_required == 800 and bridge.inspect(id).work_required == 400.0,"20 m upgrade costs only 800 difference M11 and 400 work")
	var bank: Vector2 = bridge.projects[id].banks[0]
	var probe: Dictionary = rear.combat.world.route({"position":bank-Vector2(20,0),"facing":0.0,"size":Vector2(0.6,0.6),"movement_class":0,"base":1.5,"rate":0.0,"gross_mass_kg":80.0},bridge.projects[id].banks[1]+Vector2(20,0))
	_check(not probe.ok,"closed upgrade grants no partial deck access")
	var first := _engineer(base,id,"upgrade-one")
	_engineer(base,id,"upgrade-two")
	_check(rear.ledger.add_stock("upgrade-m11","M11",800,1.0,id+"-carrier",rear.PLAYER).ok,"upgrade M11 physically on previous bank carrier")
	_check(bridge.deliver_material(id,"upgrade-m11",800).ok,"upgrade difference staged and consumed")
	rear.advance_time(50)
	var progress: float = bridge.inspect(id).progress
	_check(rear.ledger.move_entity(first,"hq-stock",Vector2(30,20)).ok,"one engineer leaves actual site")
	rear.advance_time(20)
	_check(bridge.inspect(id).progress == progress and bridge.inspect(id).state == "Paused","bridge work pauses below two local engineers")
	_check(rear.ledger.move_entity(first,id+"-a",bank).ok,"same engineer returns")
	rear.advance_time(150)
	_check(bridge.inspect(id).state == "Complete" and bridge.inspect(id).code == "B03" and bridge.inspect(id).max_health == 6000,"upgrade completes only after remaining work")
	_check(bridge.inspect(id).effective_load_kg == 80000.0 and bridge.inspect(id).speed_cap_mps == 4.0,"finished upgrade exposes actual full B03 capacity")
	_check(base.audit().is_empty(),"upgrade and interruption audit: "+str(base.audit()))
	var cancelled := Base.new(true)
	var cancel_id := _build(cancelled,"B02",101,20)
	_check(cancelled.rear.bridges.upgrade(cancel_id).ok,"second B02 opens cancellable upgrade")
	_check(cancelled.rear.bridges.cancel(cancel_id).ok,"unstarted upgrade cancelled")
	_check(cancelled.rear.bridges.inspect(cancel_id).state == "Complete" and cancelled.rear.bridges.inspect(cancel_id).code == "B02" and cancelled.rear.bridges.inspect(cancel_id).effective_load_kg == 10000.0,"cancelled upgrade restores original B02 and its original deck")
	_check(cancelled.audit().is_empty(),"cancelled upgrade audit: "+str(cancelled.audit()))

func _collapse_on_water() -> void:
	var base := Base.new(true)
	var id := _build(base,"B01",101,20)
	if id.is_empty(): return
	var rear: RefCounted = base.rear
	_check(rear.ledger.add_person("collapse-person","hq-stock",rear.PLAYER,Records.Assignment.AVAILABLE,true).ok,"actual future crossing person")
	_check(rear.ledger.move_entity("collapse-person","hq-stock",Vector2(80.5,20.5)).ok,"person at real holding point")
	_check(rear.bridges.request_crossing(id,"collapse-person",0).ok,"person admitted to actual B01")
	rear.advance_time(24)
	_check(rear.bridges.inspect(id).traffic.size() == 1 and rear.ledger.inspect_entity("collapse-person").position.x > 101.0,"person physically on deep-water span")
	_check(rear.ledger.add_person("waiting-person","hq-stock",rear.PLAYER,Records.Assignment.AVAILABLE,true).ok,"second actual person at near bank")
	_check(rear.ledger.move_entity("waiting-person","hq-stock",Vector2(80.5,20.5)).ok,"second person reaches holding point")
	_check(rear.bridges.request_crossing(id,"waiting-person",0).ok,"second person joins occupied queue")
	_check(rear.bridges.inspect(id).queued.size() == 1,"occupied crossing retains visible waiting person")
	_check(rear.bridges.damage(id,5000).ok,"bridge collapses from actual damage")
	_check(rear.ledger.inspect_entity("collapse-person").assignment == "Dead" and rear.bridges.inspect(id).traffic.is_empty(),"water-span person dies once and crossing ends")
	_check(rear.bridges.inspect(id).queued.is_empty() and rear.ledger.inspect_entity("waiting-person").assignment != "Dead","destruction clears stale queue without killing person still on land")
	_check(base.audit().is_empty(),"collapse casualty audit: "+str(base.audit()))

func _tank_tow_load() -> void:
	var base := Base.new(true)
	var id := _build(base,"B03",301,30)
	if id.is_empty(): return
	var rear: RefCounted = base.rear
	_hull(base,"tow-tractor","T05",Vector2(280.5,20.5))
	_hull(base,"tow-tank","T05",Vector2(268.5,20.5))
	_check(rear.ledger.set_tow_pair("tow-tractor","tow-tank",true).ok,"G21 load fixture seeds actual G24 coupling; timed attachment covered by G24")
	var coupled := Routes.gross_kg(rear.ledger,"tow-tractor")+Routes.gross_kg(rear.ledger,"tow-tank")
	_check(coupled > 60000.0 and coupled < 80000.0,"two actual fuelled tanks form below-80-tonne coupled gross")
	_check(rear.bridges.request_crossing(id,"tow-tractor",0,false,"tow-tank").ok,"B03 accepts one compatible sub-limit tow combination")
	rear.advance_time(0)
	_check(rear.bridges.inspect(id).traffic.size() == 1,"coupled tanks own one bridge occupancy")
	rear.advance_time(100)
	_check(rear.ledger.inspect_entity("tow-tractor").position.distance_to(Vector2(351.5,20.5)) < 0.01 and rear.ledger.inspect_entity("tow-tank").position.distance_to(Vector2(339.5,20.5)) < 0.01,"both actual tanks traverse with twelve-metre tow spacing")
	_check(rear.bridges.damage(id,3500).ok and rear.bridges.inspect(id).effective_load_kg == 40000.0,"damaged B03 halves 80-tonne load")
	_check(rear.ledger.move_entity("tow-tractor","tow-tractor-holding",Vector2(280.5,20.5)).ok and rear.ledger.move_entity("tow-tank","tow-tank-holding",Vector2(268.5,20.5)).ok,"same tanks return to holding fixture")
	_check(not rear.bridges.request_crossing(id,"tow-tractor",0,false,"tow-tank").ok,"A35 damaged B03 rejects actual coupled gross above 40 tonnes")
	_check(base.audit().is_empty(),"coupled tank and fuel accounting: "+str(base.audit()))

func _exclusive_engineering() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var bridge_order: Dictionary = _site(base,"B01",101,20)
	if not bridge_order.ok: return
	var bridge_id: String = bridge_order.id
	var engineer_id := _engineer(base,bridge_id,"exclusive")
	var field_order: Dictionary = rear.field_structures.order("S02",Vector2(80,5))
	_check(field_order.ok,"independent field project exists")
	_check(not rear.field_structures.assign_engineer(field_order.id,engineer_id).ok,"same P02 cannot build bridge and field site")
	_check(rear.bridges.release_engineer(engineer_id).ok,"bridge assignment releases actual engineer")
	_check(rear.field_structures.assign_engineer(field_order.id,engineer_id).ok,"released P02 may join field project")
	_check(not rear.bridges.assign_engineer(bridge_id,engineer_id).ok,"same P02 cannot rejoin bridge while committed to field project")
	_check(base.audit().is_empty(),"exclusive engineer accounting: "+str(base.audit()))

func _damaged_foot_mass() -> void:
	var base := Base.new(true)
	var id := _build(base,"B01",101,20)
	if id.is_empty(): return
	var rear: RefCounted = base.rear
	var bridge: RefCounted = rear.bridges
	_check(bridge.damage(id,600).ok and bridge.inspect(id).effective_load_kg == 500.0,"damaged footbridge halves group mass limit")
	for n in range(8):
		var person_id := "damaged-foot-"+str(n)
		_check(rear.ledger.add_person(person_id,"hq-stock",rear.PLAYER,Records.Assignment.AVAILABLE,true).ok,"actual footbridge person")
		_check(rear.ledger.move_entity(person_id,"hq-stock",Vector2(80.5,20.5)).ok,"person at real holding point")
		_check(bridge.request_crossing(id,person_id,0).ok,"person joins damaged B01 queue")
	rear.advance_time(0)
	_check(bridge.inspect(id).traffic.size() == 6 and bridge.inspect(id).queued.size() == 2,"only six actual 80 kg bodies fit damaged B01's 500 kg live limit")
	_check(base.audit().is_empty(),"damaged footbridge mass accounting: "+str(base.audit()))

func _collapse_vehicle() -> void:
	var base := Base.new(true)
	var id := _build(base,"B03",301,30)
	if id.is_empty(): return
	var rear: RefCounted = base.rear
	_hull(base,"collapse-apc","T04",Vector2(280.5,20.5))
	_check(rear.ledger.add_person("collapse-passenger","collapse-apc",rear.PLAYER,Records.Assignment.PASSENGER,true).ok,"actual APC occupant")
	_check(rear.bridges.request_crossing(id,"collapse-apc",0).ok,"actual APC enters completed B03")
	rear.advance_time(10)
	_check(rear.ledger.inspect_entity("collapse-apc").position.x > 301.0 and rear.bridges.inspect(id).traffic.size() == 1,"APC physically over water")
	_check(rear.bridges.damage(id,7000).ok,"B03 fully destroyed while occupied")
	_check(rear.ledger.inspect_entity("collapse-apc").health == 0 and rear.ledger.inspect_entity("collapse-passenger").assignment == "Dead","actual hull and occupant lost on water span")
	_check(rear.bridges.inspect(id).traffic.is_empty(),"destroyed crossing releases occupied traffic identity")
	_check(base.audit().is_empty(),"collapsed vehicle and person accounting: "+str(base.audit()))

func _boarded_passenger_and_move_failure() -> void:
	var base := Base.new(true)
	var id := _build(base,"B01",101,20)
	if id.is_empty(): return
	var rear: RefCounted = base.rear
	_hull(base,"passenger-truck","T02",Vector2(80.5,20.5))
	_check(rear.ledger.add_person("same-passenger","passenger-truck",rear.PLAYER,Records.Assignment.PASSENGER,true).ok,"actual passenger seated at footbridge holding point")
	_check(not rear.bridges.request_crossing(id,"same-passenger",0).ok,"seated person cannot claim independent B01 crossing")
	_check(rear.bridges.inspect(id).queued.is_empty() and rear.bridges.inspect(id).traffic.is_empty(),"invalid seated request creates no footbridge occupancy")
	_check(rear.ledger.disembark_dispatch_passenger("same-passenger","passenger-truck","passenger-truck-holding").ok,"same person physically exits actual carrier to a place")
	_check(rear.ledger.inspect_entity("same-passenger").holder_id == "passenger-truck-holding","same identity now independently dismounted")
	_check(rear.bridges.request_crossing(id,"same-passenger",0).ok,"same dismounted person admitted on B01")
	rear.advance_time(0)
	_check(rear.bridges.inspect(id).traffic.size() == 1,"same person occupies crossing after real disembark")
	var progress: float = rear.bridges.inspect(id).traffic[0].progress
	_check(rear.ledger.move_entity("same-passenger","hq-stock",Vector2(80.5,20.5)).ok,"person leaves recorded crossing place")
	rear.advance_time(5)
	_check(rear.bridges.inspect(id).traffic[0].progress == progress and rear.ledger.inspect_entity("same-passenger").position.x == 80.5,"failed physical movement earns no crossing progress")
	_check(rear.ledger.move_entity("same-passenger","passenger-truck-holding",Vector2(80.5,20.5)).ok,"same person returns to recorded physical place")
	rear.advance_time(50)
	_check(rear.bridges.inspect(id).traffic.is_empty() and rear.ledger.inspect_entity("same-passenger").position.distance_to(Vector2(141.5,20.5)) < 0.01,"same dismounted person completes actual footbridge traversal")
	_check(base.audit().is_empty(),"boarded passenger and movement interruption accounting: "+str(base.audit()))

func _impossible_approaches() -> void:
	var edge := Base.new(true)
	var edge_world: RefCounted = edge.rear.combat.world
	edge_world.bounds = Rect2i(0,0,60,40)
	edge_world.paint(Rect2i(20,10,20,20),"TR11")
	var outside: Dictionary = edge.rear.bridges.order("B02",Vector2(19.5,20.5),Vector2(40.5,20.5))
	_check(not outside.ok and edge.rear.bridges.projects.is_empty(),"order rejects project when neither out-of-bounds holding approach is viable")
	var blocked := Base.new(true)
	var world: RefCounted = blocked.rear.combat.world
	world.paint(Rect2i(101,10,20,20),"TR11")
	var near_wire := Rect2(Vector2(85,19),Vector2(2,3))
	var far_wire := Rect2(Vector2(135,19),Vector2(2,3))
	world.set_project_structure("blocked-near","S04",near_wire,true)
	world.set_project_structure("blocked-far","S04",far_wire,true)
	var denied: Dictionary = blocked.rear.bridges.order("B02",Vector2(100.5,20.5),Vector2(121.5,20.5))
	_check(not denied.ok and blocked.rear.bridges.projects.is_empty(),"order rejects project when both real holding approaches are obstructed")
	var one_bank := Base.new(true)
	var one_world: RefCounted = one_bank.rear.combat.world
	one_world.paint(Rect2i(101,10,20,20),"TR11")
	one_world.set_project_structure("far-wire","S04",far_wire,true)
	var legal: Dictionary = one_bank.rear.bridges.order("B02",Vector2(100.5,20.5),Vector2(121.5,20.5))
	_check(legal.ok,"stable far endpoint and accessible near holding permit one-bank order despite obstructed far approach")
	if legal.ok:
		_check(one_bank.rear.bridges.inspect(legal.id).work_bank == 0,"accessible near bank selected for actual construction")
		_check(not one_bank.rear.bridges.choose_work_bank(legal.id,1).ok,"blocked far approach cannot become work bank before M11 consumption")
		_engineer(one_bank,legal.id,"one")
		_engineer(one_bank,legal.id,"two")
		_stage(one_bank,legal.id,legal.m11)
		one_bank.rear.advance_time(200)
		_check(one_bank.rear.bridges.inspect(legal.id).state == "Complete","one-bank construction completes while far approach remains obstructed")
		var rear: RefCounted = one_bank.rear
		_check(rear.ledger.add_person("one-bank-walker","hq-stock",rear.PLAYER,Records.Assignment.AVAILABLE,true).ok,"actual person available for approach test")
		_check(rear.ledger.move_entity("one-bank-walker","hq-stock",Vector2(80.5,20.5)).ok,"person reaches near holding point")
		_check(not rear.bridges.request_crossing(legal.id,"one-bank-walker",0).ok,"real far obstruction bars crossing after one-bank completion")
		one_world.set_project_structure("far-wire","S04",far_wire,false)
		_check(rear.bridges.request_crossing(legal.id,"one-bank-walker",0).ok,"same person crosses only after far approach clears")
		rear.advance_time(100)
		_check(rear.ledger.inspect_entity("one-bank-walker").position.distance_to(Vector2(141.5,20.5)) < 0.01,"same person physically reaches far holding after clearance")
	_check(one_bank.audit().is_empty(),"bank feasibility accounting: "+str(one_bank.audit()))
	var interrupted := Base.new(true)
	var interrupted_order: Dictionary = _site(interrupted,"B02",101,20)
	if interrupted_order.ok:
		var interrupted_id: String = interrupted_order.id
		_engineer(interrupted,interrupted_id,"one")
		_engineer(interrupted,interrupted_id,"two")
		interrupted.rear.combat.world.set_project_structure("new-near-wire","S04",near_wire,true)
		_stage(interrupted,interrupted_id,interrupted_order.m11)
		_check(interrupted.rear.bridges.inspect(interrupted_id).m11_consumed == 0,"new obstruction on chosen work bank preserves staged M11 unconsumed")
		interrupted.rear.combat.world.set_project_structure("new-near-wire","S04",near_wire,false)
		interrupted.rear.advance_time(0)
		_check(interrupted.rear.bridges.inspect(interrupted_id).m11_consumed == interrupted_order.m11,"cleared chosen-bank approach permits same staged M11 to start once")
	var far_only := Base.new(true)
	var far_world: RefCounted = far_only.rear.combat.world
	far_world.paint(Rect2i(101,10,20,20),"TR11")
	far_world.set_project_structure("near-wire","S04",near_wire,true)
	var far_order: Dictionary = far_only.rear.bridges.order("B02",Vector2(100.5,20.5),Vector2(121.5,20.5))
	_check(far_order.ok,"far supported approach alone permits a bridge order")
	if far_order.ok:
		_check(far_only.rear.bridges.inspect(far_order.id).work_bank == 1,"only accessible far bank is selected for physical construction")
		var far_rear: RefCounted = far_only.rear
		for suffix in ["one","two"]:
			var person_id: String = "far-builder-"+str(suffix)
			_check(far_rear.ledger.add_person(person_id,far_order.id+"-b",far_rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02").ok,"actual P02 reaches far accessible bank")
			_check(far_rear.ledger.add_stock(person_id+"-kit","E08",1,5.0,person_id,far_rear.PLAYER).ok,"far-bank P02 carries actual E08")
			_check(far_rear.bridges.assign_engineer(far_order.id,person_id).ok,"far-bank P02 assigned")
		_check(far_rear.ledger.add_carrier("far-build-carrier",far_order.id+"-b",far_rear.PLAYER,far_rear.PLAYER).ok,"actual carrier reaches far bank")
		_check(far_rear.ledger.add_stock("far-build-m11","M11",far_order.m11,1.0,"far-build-carrier",far_rear.PLAYER).ok,"full actual M11 travels on far-bank carrier")
		_check(far_rear.bridges.deliver_material(far_order.id,"far-build-m11",far_order.m11).ok,"far bank accepts real full M11 batch")
		far_rear.advance_time(200)
		_check(far_rear.bridges.inspect(far_order.id).state == "Complete","far-bank construction finishes despite obstructed near approach")
		_check(far_only.audit().is_empty(),"far-bank construction accounting: "+str(far_only.audit()))

func _repeated_upgrade_cancellation() -> void:
	var base := Base.new(true)
	var id := _build(base,"B02",101,20)
	if id.is_empty(): return
	var rear: RefCounted = base.rear
	var bridge: RefCounted = rear.bridges
	var people: Array[String] = []
	for suffix in ["one","two"]: people.append(_engineer_for_repeat(base,id,str(suffix)))
	for iteration in range(2):
		_check(bridge.upgrade(id).ok,"sound B02 can begin upgrade attempt %d" % iteration)
		for person_id in people: _check(bridge.assign_engineer(id,person_id).ok,"same free P02 assigned to upgrade attempt %d" % iteration)
		var stock_id := "repeat-upgrade-m11-%d" % iteration
		_check(rear.ledger.add_stock(stock_id,"M11",800,1.0,id+"-carrier",rear.PLAYER).ok,"fresh physical M11 for upgrade attempt %d" % iteration)
		_check(bridge.deliver_material(id,stock_id,800).ok,"upgrade attempt %d consumes full local M11" % iteration)
		rear.advance_time(10)
		var cancelled: Dictionary = bridge.cancel(id)
		_check(cancelled.ok and cancelled.recovered == 400,"consumed upgrade attempt %d returns half as actual stock" % iteration)
		_check(bridge.inspect(id).state == "Complete" and bridge.inspect(id).code == "B02","cancelled upgrade attempt %d reopens B02" % iteration)
		var pile_id := "%s-salvage-%04d" % [id,iteration+1]
		_check(rear.ledger.available_stock_at(pile_id,"M11") == 400,"upgrade attempt %d has distinct recoverable pile" % iteration)
	_check(rear.ledger.available_stock_at(id+"-salvage-0001","M11") == 400 and rear.ledger.available_stock_at(id+"-salvage-0002","M11") == 400,"both cancelled upgrade piles persist without identity collision")
	_check(base.audit().is_empty(),"repeated upgrade material conservation: "+str(base.audit()))

func _engineer_for_repeat(base: RefCounted, bridge_id: String, suffix: String) -> String:
	var rear: RefCounted = base.rear
	var person_id := "repeat-"+suffix
	_check(rear.ledger.add_person(person_id,bridge_id+"-a",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02").ok,"actual free repeat-upgrade P02")
	_check(rear.ledger.add_stock(person_id+"-kit","E08",1,5.0,person_id,rear.PLAYER).ok,"actual repeat-upgrade E08")
	return person_id

func _damage_retimes_active_tow() -> void:
	var base := Base.new(true)
	var id := _build(base,"B03",301,30)
	if id.is_empty(): return
	var rear: RefCounted = base.rear
	_hull(base,"active-tractor","T05",Vector2(280.5,20.5))
	_hull(base,"active-tow","T05",Vector2(268.5,20.5))
	_check(rear.ledger.set_tow_pair("active-tractor","active-tow",true).ok,"G21 active-load fixture seeds actual G24 coupling")
	var gross: float = Routes.gross_kg(rear.ledger,"active-tractor")+Routes.gross_kg(rear.ledger,"active-tow")
	_check(gross > 40000.0 and gross < 80000.0,"actual coupled tank load fits sound B03 but exceeds damaged limit")
	_check(rear.bridges.request_crossing(id,"active-tractor",0,false,"active-tow").ok,"coupled tow admitted before bridge damage")
	rear.advance_time(0)
	rear.advance_time(24)
	var before: Dictionary = rear.ledger.inspect_entity("active-tractor")
	var fuel_before: float = before.fuel
	_check(before.position.x > 301.0 and rear.bridges.inspect(id).traffic.size() == 1,"lead tank is actually over the water when damage occurs")
	var original_remaining: float = rear.bridges.inspect(id).traffic[0].seconds-rear.bridges.inspect(id).traffic[0].progress
	_check(rear.bridges.damage(id,3500).ok,"B03 damaged to half while overloaded tow is already on span")
	var crossing: Dictionary = rear.bridges.inspect(id).traffic[0]
	_check(crossing.progress == 0.0 and crossing.seconds > original_remaining and crossing.start.distance_to(before.position) < 0.01,"active tow retains physical position and longer remaining time")
	_check(rear.ledger.inspect_entity("active-tractor").health > 0 and rear.ledger.inspect_entity("active-tow").health > 0,"new half-load limit does not auto-collapse already crossing tow")
	rear.advance_time(5)
	var after: Dictionary = rear.ledger.inspect_entity("active-tractor")
	_check(after.position.distance_to(before.position) <= 5.01 and after.position.distance_to(before.position) > 0.0,"damaged active tow advances at at most effective 1 m/s")
	_check(after.fuel < fuel_before,"damaged crossing continues to burn real fuel")
	rear.advance_time(100)
	_check(rear.bridges.inspect(id).traffic.is_empty() and rear.ledger.inspect_entity("active-tractor").position.distance_to(Vector2(351.5,20.5)) < 0.01,"already admitted tow clears damaged bridge without a fresh load admission")
	_check(not rear.bridges.request_crossing(id,"active-tractor",1,false,"active-tow").ok,"new coupled return entry is rejected above damaged 40 tonne limit")
	_check(base.audit().is_empty(),"active damaged tow accounting: "+str(base.audit()))
