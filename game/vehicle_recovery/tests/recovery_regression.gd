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
	expect(ledger.request_stock("cargo-reservation","freight-b",4,"test","Reserved cargo",rear.PLAYER).ok,"real reservation before loss")
	expect(ledger.apply_vehicle_surface_damage("carrier",1000,999,"Side","A41 destroying strike").ok,"destroying hull strike")
	expect(ledger.inspect_entity("healthy").health == 40 and ledger.inspect_entity("healthy").suppression == 80,"A41 healthy occupant receives exactly60 injury/80 suppression")
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
	expect(ledger.inspect_entity("carrier").wreck_cleared and ledger.inspect_entity("clear-m11").quantity == 0,"wreck clears once without free Metal")
	expect(fixture.base.audit().is_empty(),"A41 whole-ledger audit: "+str(fixture.base.audit()))

func _water_and_no_exit() -> void:
	for submerged in [true,false]:
		var fixture := Fixture.new()
		var rear: RefCounted = fixture.base.rear
		if submerged: rear.combat.world.paint(Rect2i(490,40,20,20),"TR11")
		else: rear.combat.world.obstacles.append({"id":"sealed","rect":Rect2(490,40,20,20),"solid":true,"classes":[0,1,2]})
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
	expect(fixture.base.audit().is_empty(),"A42 physical load/fuel/person accounting: "+str(fixture.base.audit()))
