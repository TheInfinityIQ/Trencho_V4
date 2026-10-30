extends SceneTree
const Fixture = preload("res://game/vehicle_recovery/recovery_fixture.gd")
const Routes = preload("res://game/routes/route_planner.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_a41()
	_water_and_no_exit()
	_repairs()
	_a42()
	_boarded_engineer()
	print("G24 recovery regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _a41() -> void:
	var fixture := Fixture.new()
	var rear: RefCounted = fixture.base.rear
	var ledger: RefCounted = rear.ledger
	expect(rear.recovery.inspect("tractor").conditions.is_empty(),"inspection accepts supported hull at actual non-axis heading")
	expect(ledger.request_stock("cargo-reservation","freight-b",4,"test","Reserved cargo",rear.PLAYER).ok,"real reservation before loss")
	expect(ledger.apply_vehicle_surface_damage("carrier",1000,999,"Side","A41 destroying strike").ok,"destroying hull strike")
	expect(ledger.inspect_entity("healthy").health == 40 and ledger.inspect_entity("healthy").suppression == 80,"A41 healthy occupant receives exactly60 injury/80 suppression")
	rear.advance_time(0)
	expect(ledger.inspect_entity("healthy").suppression == 80,"zero elapsed time cannot immediately recover destruction suppression")
	expect(ledger.inspect_entity("injured").assignment == "Wounded" and ledger.inspect_entity("injured").health == 0,"A41 injured occupant incapacitated once")
	expect(ledger.inspect_entity("incapacitated").assignment == "Dead" and rear.combat.deaths.has("incapacitated"),"A41 prior incapacitation becomes one roster loss")
	for id in ["healthy","injured","incapacitated"]:
		var person: Dictionary = ledger.inspect_entity(id)
		expect(person.holder_id != "carrier" and person.position.distance_to(Vector2(500,50)) <= 8.0,"same occupant ejected within8m: "+id)
	expect(ledger.inspect_entity("freight-a").quantity+ledger.inspect_entity("freight-b").quantity == 3,"half freight rounds down per type across stacks")
	expect(ledger.inspect_entity("odd-rounds").quantity == 3,"half vehicle ammunition rounds down")
	expect(ledger.inspect_entity("incapacitated-rounds").quantity == 5 and ledger.inspect_entity("injured-rounds").quantity == 5,"personal dropped belongings remain whole")
	expect(ledger.inspect_entity("healthy-rounds").holder_id == "healthy","healthy survivor retains personal gear")
	expect(ledger.inspect_claim("cargo-reservation").reserved == 0,"destroyed cargo claim is released")
	var event_count: int = rear.recovery.events.size()
	rear.recovery._on_damage("carrier")
	expect(not ledger.apply_vehicle_surface_damage("carrier",1,999,"Side","Repeat").ok and rear.recovery.events.size() == event_count and ledger.inspect_entity("healthy").health == 40,"repeated destruction cannot duplicate injury or salvage")
	expect(not ledger.apply_heavy_repair("carrier",100).ok,"destroyed hull cannot be resurrected through old repair boundary")
	expect(ledger.snapshot().fuel_lost == 40.0,"destroyed tank fuel recorded as loss")
	fixture.engineer("clearer",Vector2(500,53))
	ledger.add_stock("clear-m11","M11",20,1.0,"clearer-ground",rear.PLAYER)
	rear.advance_time(10)
	expect(rear.recovery.start_repair("carrier",["clearer"],"Clear wreck").ok,"reachable wreck accepts20M11/60work clearance")
	rear.advance_time(59.75)
	expect(not ledger.inspect_entity("carrier").wreck_cleared,"wreck remains until exact work boundary")
	rear.advance_time(0.25)
	expect(ledger.inspect_entity("carrier").wreck_cleared and ledger.local_vehicle_material("carrier") == 3,"wreck clears after consuming20actual nearbyM11, including eligible owned salvage")
	expect(ledger.total_stock("M01") == 0,"wreck clearance creates no Metal")
	expect(fixture.base.audit().is_empty(),"A41 whole-ledger audit: "+str(fixture.base.audit()))

func _water_and_no_exit() -> void:
	for submerged in [true,false]:
		var fixture := Fixture.new()
		var rear: RefCounted = fixture.base.rear
		if submerged: rear.combat.world.paint(Rect2i(490,40,20,20),"TR11")
		else: rear.combat.world.obstacle("sealed",Rect2(490,40,20,20),0.0,2.0,true)
		rear.ledger.apply_vehicle_surface_damage("carrier",1000,999,"Top","No safe exit")
		for id in ["healthy","injured","incapacitated"]: expect(rear.ledger.inspect_entity(id).assignment == "Dead","no survivable exit kills once")
		if submerged: expect(rear.ledger.inspect_entity("freight-a").quantity+rear.ledger.inspect_entity("freight-b").quantity == 0 and rear.ledger.inspect_entity("odd-rounds").quantity == 0,"deep water loses all cargo/ammunition")
		expect(fixture.base.audit().is_empty(),"unreachable destruction accounting")

func _repairs() -> void:
	var fixture := Fixture.new()
	var rear: RefCounted = fixture.base.rear
	var ledger: RefCounted = rear.ledger
	ledger.move_entity("repairer","repairer-ground",Vector2(68.5,23.5))
	ledger.add_place("repair-material","Real staged repair goods",Vector2(68.5,23.5))
	ledger.add_stock("repair-stock","M11",80,1.0,"repair-material",rear.PLAYER)
	expect(not rear.recovery.start_repair("tow",["repairer"]).ok,"recent damage blocks work")
	rear.advance_time(10)
	expect(rear.recovery.start_repair("tow",["repairer"]).ok,"real engineer kit and local materials start health repair")
	rear.advance_time(20)
	ledger.move_entity("repairer","repairer-ground",Vector2(60,30))
	rear.advance_time(40)
	expect(rear.recovery.jobs.tow.progress == 20.0,"access loss preserves earned work without progress")
	ledger.move_entity("repairer","repairer-ground",Vector2(68.5,23.5))
	rear.advance_time(20)
	expect(ledger.inspect_entity("tow").health == 1200 and ledger.inspect_entity("tow").damage_immobilized,"health repair caps100 and does not clear device immobilization")
	expect(not rear.recovery.start_repair("tow",["repairer"]).ok,"full health cannot consume health-repair materials")
	expect(rear.recovery.start_repair("tow",["repairer"],"Mobility").ok,"distinct20M11/60work mobility repair")
	rear.advance_time(60)
	expect(not ledger.inspect_entity("tow").damage_immobilized,"only completed mobility action clears immobilization")
	expect(ledger.inspect_entity("repair-stock").quantity == 50,"health10 plus mobility20M11 consumed exactly once")
	fixture.hull("stranded-wheel","T02",Vector2(600,50),false)
	ledger.apply_vehicle_surface_damage("stranded-wheel",200,999,"Side","Stranded repair case")
	rear.combat.world.paint(Rect2i(596,48,8,4),"TR09")
	ledger.move_entity("repairer","repairer-ground",Vector2(600,53))
	fixture.engineer("second-repairer",Vector2(600,53))
	ledger.add_place("wheel-material","Physically staged beside wheel hull",Vector2(600,53))
	ledger.add_stock("wheel-m11","M11",10,1.0,"wheel-material",rear.PLAYER)
	ledger.add_person("repair-hostile","wheel-material","army-red")
	rear.advance_time(10)
	expect(not rear.recovery.start_repair("stranded-wheel",["repairer","second-repairer"]).ok and ledger.inspect_entity("wheel-m11").quantity == 10,"visible hostile blocks repair before material commitment")
	ledger.move_entity("repair-hostile","wheel-material",Vector2(800,53))
	expect(rear.recovery.start_repair("stranded-wheel",["repairer","second-repairer"]).ok,"two real local P02 commit one health repair")
	rear.advance_time(19.75)
	expect(ledger.inspect_entity("stranded-wheel").health == 200,"two engineers cannot finish40work before20active seconds")
	rear.advance_time(0.25)
	expect(ledger.inspect_entity("stranded-wheel").health == 300 and not rear.field_structures.assess_vehicle("stranded-wheel").ok,"health repair leaves actual wheel vehicle stranded on forbidden terrain")
	expect(fixture.base.audit().is_empty(),"repair accounting")

func _a42() -> void:
	var fixture := Fixture.new()
	var rear: RefCounted = fixture.base.rear
	var ledger: RefCounted = rear.ledger
	expect(not rear.bridges.request_crossing(fixture.b03,"tractor",0,false,"tow").ok,"uncoupled tank cannot use staged tow fixture")
	expect(rear.recovery.start_coupling("tractor","tow","repairer").ok,"P02 and E08 begin actual coupling")
	rear.advance_time(19.75)
	expect(ledger.inspect_entity("tractor").towing.is_empty(),"coupling cannot finish early")
	rear.advance_time(0.25)
	expect(ledger.inspect_entity("tractor").towing == "tow" and ledger.inspect_entity("tow").towed_by == "tractor","actual pair after20 active seconds")
	expect(rear.vehicle_combat.inspect_fire("tractor","tow","Main").blocked_reason.contains("towing"),"tractor cannot fire while towing")
	var gross: float = Routes.gross_kg(ledger,"tractor")+Routes.gross_kg(ledger,"tow")
	expect(gross > 60000 and gross < 80000,"loaded pair actual crew/cargo/ammo/fuel gross fits80tonnes")
	var alone: Dictionary = Routes.plan(ledger,"tractor",[Vector2(80.5,20.5),Vector2(140.5,20.5)],{"surface":"TR02"})
	ledger.set_tow_pair("tractor","tow",false)
	var normal: Dictionary = Routes.plan(ledger,"tractor",[Vector2(80.5,20.5),Vector2(140.5,20.5)],{"surface":"TR02"})
	ledger.set_tow_pair("tractor","tow",true)
	expect(alone.ok and normal.ok and is_equal_approx(alone.seconds,normal.seconds*4.0) and is_equal_approx(alone.fuel,normal.fuel*2.0),"tow speed quarter and fuel doubled")
	expect(not Routes.plan(ledger,"tractor",[Vector2(80.5,20.5),Vector2(140.5,20.5)],{"bridge":"B02","bridge_span_m":20.0}).ok,"A42 combined load blocks B02")
	expect(rear.bridges.request_crossing(fixture.b03,"tractor",0).ok,"A42 actual coupled loaded pair admitted on B03")
	var fuel: float = ledger.inspect_entity("tractor").fuel
	rear.advance_time(100)
	expect(ledger.inspect_entity("tractor").position.distance_to(Vector2(141.5,20.5)) < 0.01 and ledger.inspect_entity("tow").position.distance_to(Vector2(129.5,20.5)) < 0.01,"A42 both actual hulls cross with twelve-metre spacing")
	expect(ledger.inspect_entity("tractor").fuel < fuel and ledger.inspect_entity("tow").fuel == 120.0,"tractor burns actual tow fuel; target tank untouched")
	ledger.move_entity("repairer","repairer-ground",Vector2(141.5,23.5))
	expect(rear.recovery.start_coupling("tractor","tow","repairer",false).ok,"stopped pair requires real detach work")
	rear.advance_time(20)
	expect(ledger.inspect_entity("tractor").towing.is_empty(),"detached after20active seconds; disabled target remains disabled")
	expect(rear.recovery.start_coupling("tractor","tow","repairer").ok,"same physical pair can be recoupled")
	rear.advance_time(20)
	var lane: Dictionary = rear.recovery.start_tow_route("tractor",Vector2(201.5,20.5))
	expect(lane.ok,"coupled tractor starts a measured ground recovery lane")
	if lane.ok:
		rear.advance_time(lane.seconds)
		expect(ledger.inspect_entity("tractor").position.distance_to(Vector2(201.5,20.5)) < 0.01 and ledger.inspect_entity("tow").position.distance_to(Vector2(189.5,20.5)) < 0.01,"ordinary recovery lane moves both actual hulls and keeps spacing")
	expect(fixture.base.audit().is_empty(),"A42 physical load/fuel/person accounting: "+str(fixture.base.audit()))

func _boarded_engineer() -> void:
	var fixture := Fixture.new()
	var rear: RefCounted = fixture.base.rear
	var ledger: RefCounted = rear.ledger
	ledger.move_entity("carrier","carrier-ground",Vector2(80.5,23.5))
	expect(ledger.board_dispatch_passenger("repairer","carrier").ok,"actual P02 boards nearby carrier as passenger without a crew station")
	ledger.apply_vehicle_surface_damage("tractor",100,999,"Side","Repair eligibility review")
	rear.advance_time(10)
	var materials: int = ledger.local_vehicle_material("tractor")
	expect(not rear.recovery.start_repair("tractor",["repairer"]).ok and ledger.local_vehicle_material("tractor") == materials,"seated passenger cannot commit repair or consume M11")
	expect(not rear.recovery.start_coupling("tractor","tow","repairer").ok,"seated passenger cannot begin coupling despite nearby kit and valid pair")
	expect(ledger.disembark_dispatch_passenger("repairer","carrier","carrier-ground").ok,"same engineer actually disembarks to independent PLACE")
	expect(rear.mines.start_scan("repairer").ok,"independent equipped engineer commits actual mine scan")
	expect(not rear.recovery.start_repair("tractor",["repairer"]).ok and not rear.recovery.start_coupling("tractor","tow","repairer").ok,"mine scan commitment excludes repair and coupling work")
	rear.mines.cancel_task("repairer")
	expect(rear.recovery.start_repair("tractor",["repairer"]).ok,"actual disembark enables repair without changing identity or kit")
	expect(not rear.mines.start_scan("repairer").ok,"repair commitment excludes a concurrent mine scan")
	rear.recovery.cancel("tractor")
	expect(rear.recovery.start_coupling("tractor","tow","repairer").ok,"actual disembark enables coupling after repair commitment is released")
	expect(not rear.mines.start_scan("repairer").ok,"coupling commitment excludes a concurrent mine scan")
	rear.advance_time(20)
	expect(ledger.inspect_entity("tractor").towing == "tow","only independently standing engineer completes actual coupling")
	expect(fixture.base.audit().is_empty(),"boarded engineer repair/coupling accounting")
