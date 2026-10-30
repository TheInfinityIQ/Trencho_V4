extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
const Routes = preload("res://game/routes/route_planner.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	if "--dismounted" in OS.get_cmdline_user_args():
		_dismounted_ground_actions()
		print("G22 dismounted regression: %d checks, %d failures" % [checks,failures])
		quit(0 if failures == 0 else 1)
		return
	if "--review-fixes" in OS.get_cmdline_user_args():
		_a37()
		_fuel_boundary()
		_convoy_knowledge()
		print("G22 review-fix regression: %d checks, %d failures" % [checks,failures])
		quit(0 if failures == 0 else 1)
		return
	_a37()
	_a38()
	_remote()
	_limits_and_ap()
	_d04_clearance()
	_convoy_knowledge()
	_fuel_boundary()
	_dismounted_ground_actions()
	print("G22 regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(detail)

func fixture(existing: RefCounted = null) -> RefCounted:
	var base: RefCounted = Base.new(true) if existing == null else existing
	var rear: RefCounted = base.rear
	for i in 6:
		var id := "miner-%d" % i
		check(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P02" if i < 4 else "None","None").ok,"physical reserve")
		rear.dispatch.military_people[id] = "g22-receipt"
		rear.dispatch.hq_reserve[id] = "Occupied"
		rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30)
		rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER)
		if i < 4: rear.ledger.add_stock(id+"-kit","E08",1,5.0,id,rear.PLAYER)
	var roster: Array[String] = ["miner-0","miner-1","miner-2","miner-3","miner-4","miner-5"]
	var squad: Dictionary = rear.military.form_squad("Engineer",roster)
	check(squad.ok,"actual Engineer squad")
	rear.advance_time(8)
	rear.ledger.add_place("mine-road","Declared flat road fixture",Vector2.ZERO)
	for i in 6: rear.ledger.move_entity("miner-%d" % i,"mine-road",Vector2(60,40+i))
	rear.ledger.add_carrier("freight","mine-road",rear.PLAYER,rear.PLAYER)
	rear.ledger.add_stock("m06","M06",30,1.0,"freight",rear.PLAYER)
	return base

func squad(rear: RefCounted) -> String:
	return str(rear.military.squads.keys()[0])

func place(rear: RefCounted, code: String, point: Vector2, engineer: String = "miner-0") -> String:
	rear.ledger.move_entity(engineer,"mine-road",point)
	var ordered: Dictionary = rear.mines.order(code,point,squad(rear),engineer)
	check(ordered.ok,"order "+code+": "+ordered.get("message",""))
	if not ordered.ok: return ""
	var id: String = ordered.id
	rear.ledger.move_entity("freight","mine-road",point+Vector2(0,5))
	var count: int = rear.mines.projects[id].m06_reserved
	check(rear.mines.deliver(id,"m06",count).ok,"physically delivered M06")
	rear.advance_time(rear.mines.projects[id].work_required)
	check(rear.mines.inspect(id).state == "Arming","placement then arm delay")
	rear.ledger.move_entity(engineer,"mine-road",point+Vector2(-30,0))
	rear.ledger.move_entity("freight","mine-road",point+Vector2(-30,5))
	rear.advance_time(10)
	check(rear.mines.inspect(id).state == "Armed","ten-second arm delay")
	return id

func _a37() -> void:
	var base := fixture()
	var rear: RefCounted = base.rear
	var point := Vector2(200,100)
	rear.ledger.move_entity("miner-0","mine-road",point)
	var ordered: Dictionary = rear.mines.order("D02",point,squad(rear),"miner-0")
	check(ordered.ok,"D02 order")
	var id: String = ordered.id
	rear.advance_time(30)
	check(rear.mines.inspect(id).progress == 0,"remote M06 cannot earn work")
	check(not rear.mines.observe_placement(id,"miner-1").ok,"an unworked order is not observable physical placement")
	rear.ledger.move_entity("freight","mine-road",point+Vector2(0,5))
	check(rear.mines.deliver(id,"m06",3).ok,"three real explosives delivered")
	rear.advance_time(6)
	check(rear.mines.inspect(id).progress == 6 and rear.mines.inspect(id).committed_m06 == 3,"exclusive physical claim and partial work")
	check(not rear.field_structures.assign_engineer(rear.field_structures.order("S02",Vector2(230,100)).id,"miner-0").ok,"one engineer cannot also build")
	rear.ledger.move_entity("miner-0","mine-road",point+Vector2(-3,0))
	rear.advance_time(20)
	check(rear.mines.inspect(id).progress == 6 and rear.ledger.total_stock("M06") == 30,"interrupted placement retains stock and work")
	rear.ledger.move_entity("miner-0","mine-road",point)
	rear.advance_time(6)
	check(rear.mines.inspect(id).m06_consumed == 3 and rear.ledger.total_stock("M06") == 27,"consume exactly at completion")
	rear.ledger.reserve_rear_hull("tank-admit","army-red","g22")
	rear.ledger.create_heavy_output("tank-admit","g22","tank","T05","mine-road","army-red",Specs.TYPES.T05)
	rear.ledger.add_person("tank-driver","mine-road","army-red",Records.Assignment.AVAILABLE,true,"P08","None")
	rear.ledger.request_assignment("tank-driver",Records.Assignment.REAR_LABOUR,"crew:tank:Driver")
	check(rear.ledger.complete_vehicle_station_entry("tank-driver","tank","Driver").ok,"actual qualified T05 driver occupies station")
	rear.ledger.move_entity("tank","mine-road",point+Vector2(-10,0))
	rear.ledger.move_entity("tank","mine-road",point+Vector2(10,0))
	check(rear.ledger.inspect_entity("tank").health == 1200,"unarmed device cannot explode")
	rear.ledger.move_entity("tank","mine-road",point+Vector2(-10,0))
	rear.ledger.move_entity("miner-0","mine-road",point+Vector2(-30,0))
	rear.ledger.move_entity("freight","mine-road",point+Vector2(-30,5))
	rear.advance_time(9.999)
	check(rear.mines.inspect(id).state == "Arming","no early arming")
	rear.advance_time(0.001)
	rear.ledger.add_person("walker","mine-road","army-red",Records.Assignment.AVAILABLE,true)
	rear.ledger.move_entity("walker","mine-road",point)
	check(rear.mines.inspect(id).state == "Armed","infantry cannot trigger AV mine")
	check(Routes.plan(rear.ledger,"tank",[point+Vector2(-10,0),point+Vector2(20,0)]).ok,"uninformed side route is permitted")
	# Centre stops 5 m short: its 8.5 x 3.5 m footprint enters the 1.5 m circle.
	rear.ledger.move_entity("tank","mine-road",point+Vector2(-5,0))
	var tank: Dictionary = rear.ledger.inspect_entity("tank")
	check(rear.mines.inspect(id).state == "Detonated" and tank.health == 550 and tank.damage_immobilized,"A37 bottom 160 penetrates T05 45; surviving tank immobilized")
	check(not Routes.plan(rear.ledger,"tank",[tank.position,tank.position+Vector2(40,0)]).ok,"device immobilization blocks route above 25 percent health")
	check(rear.mines.events[-1].surface == "Bottom","actual bottom strike recorded")
	check(rear.ledger.inspect_entity("tank-driver").health == 90,"surviving hull occupant receives one ten-injury penetration consequence")
	check(base.audit().is_empty(),"A37 shared ledger audit: "+str(base.audit()))

func _a38() -> void:
	var base := fixture()
	var rear: RefCounted = base.rear
	var point := Vector2(180,100)
	var id := place(rear,"D02",point)
	check(rear.mines.route_blocker("army-red",[point-Vector2(50,0),point+Vector2(50,0)]).is_empty(),"hidden mine cannot change opponent route")
	rear.ledger.add_person("red-engineer","mine-road","army-red",Records.Assignment.AVAILABLE,true,"P02")
	rear.ledger.add_stock("red-kit","E08",1,5.0,"red-engineer","army-red")
	rear.ledger.move_entity("red-engineer","mine-road",point+Vector2(10,0))
	check(rear.mines.start_scan("red-engineer").ok,"actual stationary scan")
	rear.advance_time(2.9)
	check(rear.mines.inspect_known("army-red").is_empty(),"scan requires full three seconds")
	rear.ledger.move_entity("red-engineer","mine-road",point+Vector2(9,0))
	rear.advance_time(0.2)
	check(rear.mines.inspect_known("army-red").is_empty(),"moving scan restarts three seconds")
	rear.advance_time(2.8)
	check(rear.mines.inspect_known("army-red").size() == 1,"scan reveals actual device")
	check(not rear.mines.route_blocker("army-red",[point-Vector2(50,0),point+Vector2(50,0)]).is_empty(),"A38 observation marks thirty-metre hazard")
	rear.ledger.move_entity("red-engineer","mine-road",point+Vector2(1,0))
	check(rear.mines.start_disarm(id,"red-engineer").ok,"revealed device can be disarmed")
	rear.advance_time(11)
	check(rear.mines.inspect(id).state == "Armed","eleven active seconds cannot clear")
	rear.ledger.move_entity("red-engineer","mine-road",point+Vector2(3,0))
	rear.advance_time(10)
	check(rear.mines.tasks["red-engineer"].progress == 11,"disarm interruption retains only earned work")
	rear.ledger.move_entity("red-engineer","mine-road",point+Vector2(1,0))
	rear.advance_time(1)
	check(rear.mines.inspect(id).state == "Inert" and rear.ledger.total_stock("M06") == 27,"A38 twelve active seconds inert; no recovery")
	check(rear.mines.route_blocker("army-red",[point-Vector2(50,0),point+Vector2(50,0)]).is_empty(),"clearing side has safe route")
	check(not rear.mines.route_blocker(rear.PLAYER,[point-Vector2(50,0),point+Vector2(50,0)]).is_empty(),"unobserved clearance does not magically update original owner")
	check(rear.mines.observe_clearance(id,"miner-0").ok,"owner explicitly observes clearance")
	rear.ledger.move_entity("red-engineer","mine-road",point+Vector2(250,0))
	var next := place(rear,"D01",point+Vector2(10,0))
	var adjacent := place(rear,"D02",point+Vector2(10,4))
	check(rear.mines.damage_device(next,19,"miner-0").ok and rear.mines.inspect(next).state == "Armed","insufficient shot damage leaves live device")
	check(rear.mines.damage_device(next,1,"miner-0").ok and rear.mines.inspect(next).state == "Inert" and rear.mines.inspect(adjacent).state == "Armed","sufficient damage inert without sympathetic chain")
	check(base.audit().is_empty(),"A38 accounting audit: "+str(base.audit()))

func _remote() -> void:
	var base := fixture()
	var rear: RefCounted = base.rear
	var point := Vector2(220,150)
	var id := place(rear,"D03",point)
	check(not rear.demolition.remote_slot_blocker(squad(rear)).is_empty(),"D03 reserves same D04 squad remote slot")
	check(not rear.mines.order("D03",point+Vector2(20,0),squad(rear),"miner-1").ok,"combined remote cap blocks second D03")
	check(rear.mines.set_controller(id,"miner-0").ok,"qualified actual operator takes control")
	rear.ledger.reserve_rear_hull("remote-admit","army-red","g22")
	rear.ledger.create_heavy_output("remote-admit","g22","remote-target","T05","mine-road","army-red",Specs.TYPES.T05)
	rear.ledger.move_entity("remote-target","mine-road",point+Vector2(10,0))
	check(not rear.mines.remote_trigger(id,"remote-target").ok,"hostile outside trigger zone withheld")
	rear.ledger.move_entity("remote-target","mine-road",point)
	rear.ledger.move_entity("miner-1","mine-road",point+Vector2(10,0))
	check(not rear.mines.remote_trigger(id,"remote-target").ok,"friendly blast margin withholds")
	rear.ledger.move_entity("miner-1","mine-road",point+Vector2(-30,0))
	check(rear.mines.remote_trigger(id,"remote-target").ok,"observed hostile and clear friendlies trigger D03")
	check(rear.ledger.inspect_entity("remote-target").health == 300,"D03 bottom hit deals exact 900")
	check(rear.demolition.remote_slot_blocker(squad(rear)).is_empty(),"terminal device releases squad remote slot")

func _limits_and_ap() -> void:
	var base := fixture()
	var rear: RefCounted = base.rear
	rear.ledger.add_stock("bulk-m06","M06",300,1.0,"freight",rear.PLAYER)
	var first := ""
	for i in 96:
		var point := Vector2(300+(i%12)*6,200+(i/12)*6)
		rear.ledger.move_entity("miner-0","mine-road",point)
		var ordered: Dictionary = rear.mines.order("D02",point,squad(rear),"miner-0")
		check(ordered.ok,"actual pressure-device cap placement %d" % i)
		if not ordered.ok: return
		if i == 0: first = ordered.id
		rear.ledger.move_entity("freight","mine-road",point+Vector2(0,2))
		check(rear.mines.deliver(ordered.id,"bulk-m06",3).ok,"cap batch physically staged")
		rear.advance_time(22)
	check(not rear.mines.order("D02",Vector2(400,260),squad(rear),"miner-0").ok,"97th army pressure device refused")
	check(rear.mines.damage_device(first,20,"miner-0").ok,"inert pressure device releases cap")
	var extra: Dictionary = rear.mines.order("D02",Vector2(400,260),squad(rear),"miner-0")
	check(extra.ok,"inert pressure device permits replacement")
	check(rear.mines.cancel(extra.id).ok,"unplaced replacement cancels without spending")
	check(base.audit().is_empty(),"96 real pressure devices conserve resources")
	base = fixture()
	rear = base.rear
	var point := Vector2(200,100)
	var ap := place(rear,"D01",point)
	rear.ledger.reserve_rear_hull("ap-hull-claim",rear.PLAYER,"ap-fixture")
	rear.ledger.create_heavy_output("ap-hull-claim","ap-fixture","ap-hull","T01","mine-road",rear.PLAYER,Specs.TYPES.T01)
	rear.ledger.move_entity("ap-hull","mine-road",point+Vector2(-10,0))
	rear.ledger.move_entity("ap-hull","mine-road",point+Vector2(10,0))
	check(rear.mines.inspect(ap).state == "Armed","vehicles cannot trigger D01")
	rear.ledger.add_person("friendly-walker","mine-road",rear.PLAYER,Records.Assignment.AVAILABLE,true)
	rear.ledger.move_entity("friendly-walker","mine-road",point+Vector2(10,0))
	rear.ledger.move_entity("friendly-walker","mine-road",point-Vector2(10,0))
	check(rear.mines.inspect(ap).state == "Detonated" and rear.ledger.inspect_entity("friendly-walker").health < 100,"D01 is not faction selective; coarse movement meets real trigger")
	check(base.audit().is_empty(),"AP accounting audit")

func _d04_clearance() -> void:
	var base := fixture()
	var rear: RefCounted = base.rear
	var point := Vector2(300,100)
	var structure: Dictionary = rear.field_structures.order("S02",point)
	for i in 2:
		rear.ledger.move_entity("miner-%d" % i,structure.id,point)
		check(rear.field_structures.assign_engineer(structure.id,"miner-%d" % i).ok,"actual structure builder")
	rear.ledger.add_stock("d04-m11","M11",25,1.0,"freight",rear.PLAYER)
	rear.ledger.move_entity("freight","mine-road",point)
	check(rear.field_structures.deliver_material(structure.id,"d04-m11",25).ok,"actual structure stock")
	rear.advance_time(30)
	var engineers: Array[String] = ["miner-0","miner-1"]
	var charge: Dictionary = rear.demolition.order("Structure",structure.id,squad(rear),engineers)
	check(charge.ok,"actual D04 for combined cap and clearance")
	if not charge.ok: return
	check(rear.demolition.deliver(charge.id,"m06",1).ok,"physical D04 M06")
	rear.advance_time(6)
	for i in 2: rear.ledger.move_entity("miner-%d" % i,"mine-road",point-Vector2(30,i*2))
	rear.advance_time(10)
	check(rear.demolition.set_mode(charge.id,"Remote","miner-0").ok,"D04 reserves remote slot")
	check(not rear.mines.order("D03",point+Vector2(20,0),squad(rear),"miner-2").ok,"D04 prevents competing D03")
	rear.ledger.move_entity("miner-2","mine-road",point+Vector2(10,0))
	check(rear.mines.start_scan("miner-2").ok,"D04 uses common ground scan")
	rear.advance_time(3)
	rear.ledger.move_entity("miner-2","mine-road",point+Vector2(1,0))
	check(rear.mines.start_disarm(charge.id,"miner-2").ok,"revealed D04 shares actual disarm contract")
	rear.advance_time(12)
	check(rear.demolition.inspect(charge.id).state == "Inert" and rear.field_structures.inspect(structure.id).health == 500,"D04 disarms without target blast")
	check(rear.mines.order("D03",point+Vector2(20,0),squad(rear),"miner-2").ok,"inert D04 releases shared remote slot")
	check(base.audit().is_empty(),"D04 shared accounting audit: "+str(base.audit()))

func _manufacture(base: RefCounted, recipe: String) -> String:
	var rear: RefCounted = base.rear
	var heavy: RefCounted = rear.heavy_production
	heavy.request_recipe(recipe)
	heavy.set_mode("Continuous")
	check(heavy.accept_order().ok,recipe+" accepted with real F10 bay claim")
	for type in Fixed.RECIPES[recipe].inputs:
		rear.ledger.add_stock("local-%s-%s-%d" % [recipe,type,heavy._order_sequence],type,Fixed.RECIPES[recipe].inputs[type],1.0,"vehicle_input",rear.PLAYER)
	rear.set_target("vehicle_works",8)
	rear.advance_time(1000)
	var id: String = heavy.bay_occupant
	check(not id.is_empty(),recipe+" physical output occupies F10")
	return id

func _convoy_fixture() -> Dictionary:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var hull := _manufacture(base,"R28")
	rear.add_person("g12-driver",true,"P08")
	check(rear.vehicles.assign_station(hull,"g12-driver","Driver").ok,"same T02 gets actual P08 Driver")
	rear.advance_time(160)
	rear.ledger.add_stock("g12-fuel","M08",12,1.0,"depot",rear.PLAYER)
	check(rear.vehicles.request_refuel(hull,"base-person-11",12).ok,"same T02 takes a real local M08 carry")
	rear.advance_time(200)
	check(rear.vehicles.start_drive(hull).ok,"same T02 clears F10 through legal F11 route")
	rear.advance_time(100)
	check(rear.vehicles.vehicles[hull].state == "Parked","same T02 physically parked")
	var gun := _manufacture(base,"R13")
	for index in 9: rear.add_person("g12-passenger-%02d" % index)
	for index in 8: rear.ledger.add_weapon("g12-rifle-%02d" % index,"E01",4.0,"dispatch",rear.PLAYER,"E02",30)
	rear.ledger.add_stock("g12-rounds","E02",480,0.02,"dispatch",rear.PLAYER)
	rear.set_target("dispatch",2)
	rear.advance_time(160)
	return {"base":base,"rear":rear,"hull":hull,"gun":gun}


func _convoy_knowledge() -> void:
	var f: Dictionary = _convoy_fixture()
	var base: RefCounted = fixture(f.base)
	var rear: RefCounted = base.rear
	var accepted: Dictionary = rear.dispatch.accept(f.hull,"Fleet Transfer",[],{})
	check(accepted.ok,"actual dispatch with manufactured T02 and real crew/fuel")
	if not accepted.ok: return
	rear.advance_time(160)
	check(rear.dispatch.depart(accepted.id).ok,"actual convoy departs")
	rear.advance_time(30)
	var row: Dictionary = rear.dispatch.manifests[accepted.id]
	check(row.state == "Transit","actual convoy in transit before knowledge")
	var point := Vector2(1000,91)
	rear.ledger.move_entity("miner-0","mine-road",point)
	var mine: Dictionary = rear.mines.order("D02",point,squad(rear),"miner-0")
	check(mine.ok,"friendly engineering project on required route")
	if not mine.ok: return
	rear.ledger.move_entity("freight","mine-road",point+Vector2(0,5))
	check(rear.mines.deliver(mine.id,"m06",3).ok,"actual convoy-hazard project stock")
	rear.advance_time(12)
	check(row.state == "Safety Stop","issued placement knowledge stops active same convoy")
	var stopped: Vector2 = rear.ledger.inspect_entity(f.hull).position
	check(not rear.dispatch.clear_route_hazard(row.id).ok,"manual resume cannot authorize known mine route")
	rear.advance_time(5)
	check(rear.ledger.inspect_entity(f.hull).position.is_equal_approx(stopped),"actual hull remains stopped during safety hold")
	rear.advance_time(305)
	check(row.state == "Safety Returned","expired hold uses safe actual rear-return route instead of known hazard")
	check(base.audit().is_empty(),"actual mine-hazard convoy audit: "+str(base.audit()))

func _dismounted_ground_actions() -> void:
	var base := fixture()
	var rear: RefCounted = base.rear
	var point := Vector2(200,100)
	var parking := point+Vector2(1.5,0)
	check(rear.ledger.add_place("ground-exit","Actual parked transport exit",parking).ok,"physical exit place")
	check(rear.ledger.reserve_rear_hull("ground-claim",rear.PLAYER,"ground-fixture").ok,"ground-action transport admission")
	check(rear.ledger.create_heavy_output("ground-claim","ground-fixture","ground-transport","T02","hq-berth",rear.PLAYER,Specs.TYPES.T02).ok,"actual transport hull")
	check(rear.ledger.complete_hq_hull_receipt("ground-transport").ok,"transport physically received at HQ")
	check(rear.ledger.move_entity("ground-transport","mine-road",parking).ok,"transport parks before device placement")
	var mine := place(rear,"D02",point)
	check(rear.ledger.add_person("ground-passenger",mine,rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02","None").ok,"independent qualified passenger")
	check(rear.ledger.add_stock("ground-passenger-kit","E08",1,5.0,"ground-passenger",rear.PLAYER).ok,"passenger retains actual kit")
	for engineer in ["miner-1","ground-passenger"]:
		check(rear.ledger.move_entity(engineer,"mine-road",parking).ok,"engineer physically reaches parked hull")
		var formation_member: bool = engineer == "miner-1"
		var boarded: Dictionary = rear.ledger.board_formation_passenger(engineer,"ground-transport") if formation_member else rear.ledger.board_dispatch_passenger(engineer,"ground-transport")
		check(boarded.ok,"actual formation/Passenger boarding: "+engineer)
		check(rear.ledger.inspect_entity(engineer).holder_id == "ground-transport","engineer is physically inside hull")
		if not formation_member: check(rear.ledger.inspect_entity(engineer).assignment == "Passenger","reproduce Passenger assignment eligibility hole")
		if formation_member: check(not rear.mines.order("D01",point+Vector2(10,0),squad(rear),engineer).ok,"boarded squad engineer cannot place")
		check(not rear.mines.start_scan(engineer).ok,"boarded equipped engineer cannot scan")
		check(not rear.mines.start_disarm(mine,engineer).ok,"boarded equipped engineer within two metres cannot disarm")
		var exited: Dictionary = rear.ledger.exit_formation_passenger(engineer,"ground-transport","ground-exit") if formation_member else rear.ledger.disembark_dispatch_passenger(engineer,"ground-transport","ground-exit")
		check(exited.ok and rear.ledger.inspect_entity(engineer).holder_id == "ground-exit","actual physical disembark onto a place")
		if not formation_member: check(rear.ledger.complete_dispatch_cancel_person(engineer,"ground-exit").ok,"disembarked passenger resumes availability")
		if formation_member:
			var ordered: Dictionary = rear.mines.order("D01",point+Vector2(10,0),squad(rear),engineer)
			check(ordered.ok,"same dismounted squad engineer can place")
			if ordered.ok: check(rear.mines.cancel(ordered.id).ok,"release unworked placement before scanning")
		check(rear.mines.start_scan(engineer).ok,"same dismounted engineer can scan")
		rear.advance_time(3)
		check(rear.mines.start_disarm(mine,engineer).ok,"same dismounted engineer can disarm")
		if formation_member: rear.mines.cancel_task(engineer)
		else: rear.advance_time(12)
	check(rear.mines.inspect(mine).state == "Inert","only actual dismounted work clears device")
	check(rear.ledger.audit().is_empty(),"boarding/disembark preserves physical accounting")

func _fuel_boundary() -> void:
	var base := fixture()
	var rear: RefCounted = base.rear
	var point := Vector2(200,100)
	var mine := place(rear,"D02",point)
	rear.ledger.reserve_rear_hull("fuel-tank-admission","army-red","fuel-boundary")
	rear.ledger.create_heavy_output("fuel-tank-admission","fuel-boundary","fuel-tank","T05","mine-road","army-red",Specs.TYPES.T05)
	rear.ledger.add_person("fuel-handler","mine-road","army-red",Records.Assignment.AVAILABLE,true,"None","None")
	rear.ledger.request_assignment("fuel-handler",Records.Assignment.REAR_LABOUR,"fuel-boundary")
	rear.ledger.add_stock("physical-fuel","M08",10,1.0,"mine-road","army-red")
	check(rear.ledger.begin_carry("fuel-handler","physical-fuel",10).ok,"actual fuel carry")
	check(rear.ledger.load_vehicle_fuel("fuel-handler","fuel-tank").ok,"actual fuel loaded")
	var start: Vector2 = point-Vector2(20,0)
	var finish: Vector2 = point+Vector2(20,0)
	rear.ledger.move_entity("fuel-tank","mine-road",start)
	var fraction: float = rear.mines.movement_limit("fuel-tank",start,finish)
	check(is_equal_approx(fraction,14.25/40.0),"swept footprint predicts first pressure contact without exposing knowledge")
	check(rear.mines.inspect_known("army-red").is_empty(),"physical collision predictor is not enemy device discovery")
	var burn: float = 40.0*fraction/1000.0*6.0
	check(rear.ledger.burn_vehicle_fuel("fuel-tank",burn).ok,"travelled prefix burns before synchronous blast")
	rear.ledger.move_entity("fuel-tank","mine-road",start.lerp(finish,fraction))
	check(rear.mines.inspect(mine).state == "Detonated" and rear.ledger.inspect_entity("fuel-tank").damage_immobilized,"predicted contact still physically triggers mine")
	check(is_equal_approx(rear.ledger.inspect_entity("fuel-tank").fuel,10.0-burn),"only actual movement prefix fuel consumed")
	check(base.audit().is_empty(),"fuel-boundary accounting audit")
