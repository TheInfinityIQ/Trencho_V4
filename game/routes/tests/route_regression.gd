extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
const Routes = preload("res://game/routes/route_planner.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Records = preload("res://game/identity/identity_records.gd")
const TerrainWorld = preload("res://game/terrain/terrain_world.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_a23_loaded_bridge_classes()
	_test_terrain_and_clearance()
	_test_authored_world()
	_test_a22_real_tank()
	print("G13 route regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _fixture_hull(type: String, suffix: String) -> Dictionary:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var claim := "g13-claim-"+suffix
	var hull := "g13-hull-"+suffix
	_expect(rear.ledger.reserve_rear_hull(claim,rear.PLAYER,"g13-fixture").ok,"actual rear fleet slot reserved")
	_expect(rear.ledger.create_heavy_output(claim,"g13-fixture",hull,type,"heavy-bay",rear.PLAYER,Specs.TYPES[type]).ok,"canonical full-size physical hull created")
	return {"base":base,"rear":rear,"hull":hull}

func _test_a23_loaded_bridge_classes() -> void:
	for type in ["T04","T05"]:
		var f := _fixture_hull(type,type)
		var rear: RefCounted = f.rear
		var hull: String = f.hull
		var spec: Dictionary = Specs.TYPES[type]
		for index in spec.stations.size():
			var person := "g13-crew-%s-%d" % [type,index]
			var station: String = spec.stations[index]
			_expect(rear.ledger.add_person(person,"heavy-bay",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok,"named actual crew body exists at hull")
			_expect(rear.ledger.request_assignment(person,Records.Assignment.REAR_LABOUR,"crew:%s:%s" % [hull,station]).ok,"crew reports to distinct real station")
			_expect(rear.ledger.complete_vehicle_station_entry(person,hull,station).ok,"same qualified crew physically occupies station")
		for index in int(spec.passenger_seats):
			var passenger := "g13-passenger-%s-%d" % [type,index]
			_expect(rear.ledger.add_person(passenger,hull,rear.PLAYER,Records.Assignment.PASSENGER,false,"None","None").ok,"named actual passenger occupies a seat")
		var passenger_mass: float = 80.0*int(spec.passenger_seats)
		var freight_mass: int = int(spec.payload-passenger_mass)
		_expect(rear.ledger.add_stock("g13-freight-"+type,"M11",freight_mass,1.0,hull,rear.PLAYER).ok,"actual freight fills remaining payload exactly")
		for ammo in spec.rack_capacity:
			var mass: float = 12.0 if ammo == "E25" else (0.5 if ammo == "E26" else 0.02)
			_expect(rear.ledger.add_stock("g13-rack-"+type+ammo,ammo,spec.rack_capacity[ammo],mass,hull,rear.PLAYER).ok,"actual integral rack ammunition aboard")
		var worker: String = "g13-fuel-worker-"+type
		var fuel_stack: String = "g13-fuel-stack-"+type
		_expect(rear.ledger.add_person(worker,"heavy-bay",rear.PLAYER).ok,"actual fuel worker exists at same hull")
		_expect(rear.ledger.request_assignment(worker,Records.Assignment.REAR_LABOUR,"g13-fuel").ok,"fuel worker takes exclusive labour duty")
		_expect(rear.ledger.add_stock(fuel_stack,"M08",int(spec.tank_capacity),1.0,"heavy-bay",rear.PLAYER).ok,"real whole M08 exists outside tank")
		for portion in int(ceil(float(spec.tank_capacity)/25.0)):
			var quantity: int = mini(25,int(spec.tank_capacity)-portion*25)
			_expect(rear.ledger.begin_carry(worker,fuel_stack,quantity).ok,"one physical whole-unit fuel carry begins")
			_expect(rear.ledger.load_vehicle_fuel(worker,hull).ok,"same hull tank receives actual carried M08 once")
		var expected: float = float(spec.mass)+float(spec.tank_capacity)+80.0*spec.stations.size()+float(spec.payload)
		for ammo in spec.rack_capacity:
			expected += spec.rack_capacity[ammo]*(12.0 if ammo == "E25" else (0.5 if ammo == "E26" else 0.02))
		_expect(is_equal_approx(Routes.gross_kg(rear.ledger,hull),expected),"gross includes same hull, all crew/passengers, fuel, freight and rack: "+type)
		var line: Array = [Vector2(10,12),Vector2(110,12)]
		var light: Dictionary = Routes.plan(rear.ledger,hull,line,{"bridge":"B02"})
		var heavy: Dictionary = Routes.plan(rear.ledger,hull,line,{"bridge":"B03"})
		_expect(not light.ok and light.reason.contains("gross"),"A23 fully loaded "+type+" exceeds B02 10,000kg")
		_expect(heavy.ok and heavy.gross_kg <= 80000.0 and heavy.corridor_width >= spec.footprint.y,"A23 same fully loaded "+type+" fits B03 80,000kg and width")
		_expect(f.base.audit().is_empty(),"A23 actual fixture conservation: "+str(f.base.audit()))

func _test_terrain_and_clearance() -> void:
	var f := _fixture_hull("T02","terrain")
	var rear: RefCounted = f.rear
	var hull: String = f.hull
	var line: Array = [Vector2(10,12),Vector2(1010,12)]
	var road: Dictionary = Routes.plan(rear.ledger,hull,line)
	var rocky: Dictionary = Routes.plan(rear.ledger,hull,line,{"surface":"TR07"})
	_expect(road.ok and is_equal_approx(road.distance,1000.0) and is_equal_approx(road.seconds,1000.0/15.0) and is_equal_approx(road.fuel,2.0),"full kilometre road uses actual T02 distance, speed and burn")
	_expect(rocky.ok and rocky.seconds > road.seconds and is_equal_approx(rocky.fuel,4.0),"same kilometre rocky terrain halves speed factor and doubles fuel")
	_expect(not Routes.plan(rear.ledger,hull,line,{"surface":"TR11"}).ok,"deep water invalidates same vehicle route")
	_expect(not Routes.plan(rear.ledger,hull,line,{"surface":"TR10"}).ok,"ford requires marked firm banked depth-checked authored terrain")
	_expect(not Routes.plan(rear.ledger,hull,line,{"slope":26.0}).ok,"forbidden wheeled slope invalidates route")
	_expect(not Routes.plan(rear.ledger,hull,line,{"corridor_width":2.0}).ok,"whole footprint rejects narrow clearance")
	_expect(not Routes.plan(rear.ledger,hull,line,{"known_mine":true}).ok,"known armed mine rejects ordinary route")
	_expect(not Routes.plan(rear.ledger,hull,line,{"observed_hostile":true}).ok,"observed hostile fire rejects ordinary route")
	_expect(not Routes.plan(rear.ledger,hull,[Vector2(10,12),Vector2(11,12),Vector2(11,30)]).ok,"T02 9m rolling radius rejects impossible corner")
	var crossed: Dictionary = Routes.plan(rear.ledger,hull,line,{"bridge":"B03","bridge_span_m":20.0})
	_expect(crossed.ok and crossed.seconds > road.seconds and crossed.parts.size() == 3 and crossed.parts[1].speed <= 4.0,"specified B03 crossing uses 20m approaches and 4m/s entry speed")
	_expect(f.base.audit().is_empty(),"terrain fixture leaves identities and goods conserved")

func _test_authored_world() -> void:
	var f := _fixture_hull("T02","world")
	var world := TerrainWorld.new()
	world.bounds = Rect2i(0,0,120,20)
	world.paint(world.bounds,"TR02")
	world.paint(Rect2i(60,0,50,20),"TR07")
	var path: Array = [Vector2(10,10),Vector2(110,10)]
	var road: Dictionary = Routes.plan(f.rear.ledger,f.hull,path)
	var mixed: Dictionary = Routes.plan(f.rear.ledger,f.hull,path,{"world":world})
	_expect(mixed.ok and is_equal_approx(mixed.distance,100.0) and mixed.seconds > road.seconds and mixed.fuel > road.fuel,"actual authored cells change time and fuel across full swept route")
	world.obstacle("wreck",Rect2(Vector2(80,9),Vector2(1,2)),0,3)
	var blocked: Dictionary = Routes.plan(f.rear.ledger,f.hull,path,{"world":world})
	_expect(not blocked.ok and blocked.reason.contains("wreck"),"real whole-hull sweep rejects obstacle in authored world")
	_expect(f.base.audit().is_empty(),"authored terrain fixture conserves actual hull")

func _test_a22_real_tank() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var heavy: RefCounted = rear.heavy_production
	heavy.request_recipe("R28")
	heavy.set_mode("Continuous")
	_expect(heavy.accept_order().ok,"actual T02 order accepted")
	for type in Fixed.RECIPES.R28.inputs:
		rear.ledger.add_stock("g13-a22-"+type,type,Fixed.RECIPES.R28.inputs[type],1.0,"vehicle_input",rear.PLAYER)
	rear.set_target("vehicle_works",8)
	rear.advance_time(1000)
	var hull: String = heavy.bay_occupant
	rear.add_person("g13-driver",true,"P08")
	_expect(rear.vehicles.assign_station(hull,"g13-driver","Driver").ok,"same produced hull gets real P08 driver")
	rear.advance_time(160)
	rear.ledger.add_stock("g13-fuel","M08",8,1.0,"depot",rear.PLAYER)
	_expect(rear.vehicles.request_refuel(hull,"base-person-11",3).ok,"three actual M08 units reserved for same tank")
	_expect(rear.ledger.inspect_entity(hull).fuel == 0.0,"reservation alone never fills tank")
	rear.advance_time(200)
	_expect(rear.ledger.inspect_entity(hull).fuel == 3.0,"physical carry and tank handling deposit exactly three")
	_expect(rear.vehicles.start_drive(hull).ok,"same tank fuels legal F10-to-F11 clearance")
	rear.advance_time(100)
	var accepted: Dictionary = rear.dispatch.accept(hull,"Strategic Delivery",[],{})
	_expect(accepted.ok,"same parked hull accepts no-cargo Strategic manifest")
	if not accepted.ok: return
	rear.advance_time(150)
	var preview: Dictionary = rear.dispatch.route_preview(accepted.id)
	_expect(preview.ok and not preview.fuel_ok and preview.required_fuel > rear.ledger.inspect_entity(hull).fuel,"A22 complete return plus next-resupply reserve exceeds actual tank")
	_expect(not rear.dispatch.depart(accepted.id).ok,"A22 rejects route with insufficient actual fuel before departure")
	_expect(rear.dispatch.manifests[accepted.id].state == "Loaded Waiting Dispatch" and rear.dispatch.incoming_people.is_empty(),"A22 fuel rejection preserves manifest and physical hull without phantom receipt")
	var worker := "g13-dispatch-fueller"
	_expect(rear.ledger.add_person(worker,"dispatch-berth",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok,"real fueller reaches same stopped hull")
	_expect(rear.ledger.request_assignment(worker,Records.Assignment.REAR_LABOUR,"g13-tank").ok,"fueller has real labour assignment")
	_expect(rear.ledger.add_stock("g13-dispatch-fuel","M08",9,1.0,"dispatch-berth",rear.PLAYER).ok,"nine more physical M08 units exist at berth")
	var before_transfer: float = rear.ledger.inspect_entity(hull).fuel
	_expect(rear.ledger.begin_carry(worker,"g13-dispatch-fuel",9).ok,"fueller physically lifts nine whole M08")
	_expect(rear.ledger.load_vehicle_fuel(worker,hull).ok,"actual carry transfers into same T02 tank")
	var full: Dictionary = rear.dispatch.route_preview(accepted.id)
	_expect(full.fuel_ok and is_equal_approx(full.tank_fuel,before_transfer+9.0),"A22 retry counts transferred tank fuel after prior F10 driving burn")
	var bridge_plan: Dictionary = rear.dispatch.route_preview(accepted.id,{"bridge":"B03"})
	var outward_bridge: Dictionary = bridge_plan.segments[1].parts[1]
	var return_bridge: Dictionary = bridge_plan.segments[3].parts[2]
	_expect(bridge_plan.ok and is_equal_approx(outward_bridge.from.x,710.0) and is_equal_approx(outward_bridge.to.x,770.0) and is_equal_approx(return_bridge.from.x,770.0) and is_equal_approx(return_bridge.to.x,710.0),"same actual B03 road span and approaches on outbound and return")
	_expect(rear.dispatch.set_route_profile(accepted.id,{"bridge":"B03"}).ok,"same physical bridge fixture selected before departure")
	_expect(rear.dispatch.depart(accepted.id).ok,"A22 same manifest departs after physical tank transfer")
	rear.advance_time(30)
	var row: Dictionary = rear.dispatch.manifests[accepted.id]
	_expect(row.state == "Transit","same hull enters measured outside road")
	_expect(rear.dispatch.report_route_hazard(accepted.id,"Observed hostile fire").ok,"new observed hazard stops same moving hull")
	var stopped: Vector2 = rear.ledger.inspect_entity(hull).position
	rear.advance_time(5)
	_expect(row.state == "Safety Stop" and rear.ledger.inspect_entity(hull).position.is_equal_approx(stopped),"ten-second hold burns no fuel and does not move hull")
	_expect(rear.dispatch.clear_route_hazard(accepted.id).ok,"cleared hazard resumes original measured route")
	_expect(row.state == "Transit" and rear.ledger.inspect_entity(hull).position.is_equal_approx(stopped),"resume keeps exact stop position and crossing")
	rear.advance_time(500)
	_expect(row.state == "Complete","same A22 hull reaches HQ, unloads, returns, parks with real fuel: "+row.state+" / "+row.blocker)
	var second: Dictionary = rear.dispatch.accept(hull,"Fleet Transfer",[],{})
	_expect(second.ok,"returned same hull may take a later one-way Fleet manifest")
	if second.ok:
		rear.advance_time(150)
		var fleet_plan: Dictionary = rear.dispatch.route_preview(second.id)
		_expect(fleet_plan.fuel_ok and fleet_plan.distance < full.distance,"Fleet uses one-way route to HQ next resupply and residual actual fuel")
		_expect(rear.dispatch.change_mode(second.id,"Strategic Delivery").ok,"same manifest may change back to return mode before departure")
		var strategic_plan: Dictionary = rear.dispatch.route_preview(second.id)
		_expect(strategic_plan.distance > fleet_plan.distance and strategic_plan.required_fuel > fleet_plan.required_fuel,"Strategic includes entire return and larger reserve")
		_expect(rear.dispatch.change_mode(second.id,"Fleet Transfer").ok,"one-way mode restores own hull and driver incoming claims")
		_expect(rear.dispatch.depart(second.id).ok,"Fleet reserve is enough for actual one-way route")
		rear.advance_time(30)
		_expect(rear.dispatch.report_route_hazard(second.id,"Observed unsafe road").ok,"second trip observes new unsafe route")
		rear.advance_time(10)
		var second_row: Dictionary = rear.dispatch.manifests[second.id]
		_expect(second_row.state == "Safety Returning","expired ten-second hold begins same hull physical safety return: "+second_row.state+" / "+second_row.blocker)
		rear.advance_time(300)
		_expect(second_row.state == "Safety Returned" and rear.vehicles.vehicles[hull].state == "Parked","same Fleet hull readmitted and parked after hazard without phantom HQ receipt: "+second_row.state+" / "+second_row.blocker)
	_expect(base.audit().is_empty(),"A22 same fuel/manifest identity audit: "+str(base.audit()))
