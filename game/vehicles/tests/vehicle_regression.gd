extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	var selected: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "all"
	if selected in ["all","types"]:
		for recipe in ["R25","R28","R29","R30","R31"]: _test_hull(recipe)
	if selected in ["all","stations"]: _test_station_readiness()
	if selected in ["all","interruptions"]: _test_interruptions()
	if selected in ["all","connected"]: _test_connected_session()
	print("G07 vehicle regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_hull(recipe: String) -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var heavy: RefCounted = rear.heavy_production
	heavy.request_recipe(recipe)
	heavy.set_mode("Continuous")
	_expect(heavy.accept_order().ok,recipe + " order accepted")
	for type in Fixed.RECIPES[recipe].inputs:
		rear.ledger.add_stock("local-"+type,type,Fixed.RECIPES[recipe].inputs[type],1.0,"vehicle_input",rear.PLAYER)
	for person in rear.actors:
		if person in ["base-person-11","base-person-12"]: continue
		rear.reassign_person(person,"vehicle_works")
	rear.advance_time(1000)
	var id: String = heavy.bay_occupant
	_expect(not id.is_empty(),recipe + " same output occupies F10")
	if id.is_empty(): return
	var hull: Dictionary = rear.ledger.inspect_entity(id)
	_expect(hull.crew.is_empty() and hull.passengers.is_empty() and hull.fuel == 0.0 and hull.ammunition.is_empty(),recipe + " empty output")
	_expect(not rear.vehicles.start_drive(id).ok,recipe + " no free P08 clearance")
	_expect(not heavy.accept_order().ok,recipe + " next heavy order blocked")
	rear.add_person("driver",true,"P08")
	_expect(rear.vehicles.assign_station(id,"driver","Driver").ok,recipe + " driver assigned")
	rear.advance_time(180)
	_expect(rear.ledger.inspect_entity("driver").crew_station == "Driver",recipe + " driver boarded")
	_expect(not rear.vehicles.start_drive(id).ok,recipe + " empty tank blocks")
	rear.ledger.add_stock("fuel-stock","M08",5,1.0,"depot",rear.PLAYER)
	_expect(rear.vehicles.request_refuel(id,"base-person-11",5).ok,recipe + " actual M08 carry requested")
	rear.advance_time(200)
	_expect(rear.ledger.inspect_entity(id).fuel == 5.0,recipe + " purchased local M08 entered tank")
	_expect(rear.ledger.total_stock("M08") == 0,recipe + " M08 not also loose")
	_expect(rear.vehicles.start_drive(id).ok,recipe + " physical F11 drive begins")
	rear.advance_time(100)
	_expect(rear.vehicles.vehicles[id].state == "Parked",recipe + " same hull parked")
	_expect(heavy.bay_occupant.is_empty(),recipe + " bay cleared only after travel")
	_expect(id in rear.ledger.rear_fleet_hulls(rear.PLAYER),recipe + " fleet membership retained")
	_expect(heavy.accept_order().ok,recipe + " next heavy order can proceed")
	_expect(base.audit().is_empty(),recipe + " audit " + str(base.audit()))

func _produced(recipe: String) -> Dictionary:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var heavy: RefCounted = rear.heavy_production
	heavy.request_recipe(recipe)
	heavy.set_mode("Continuous")
	heavy.accept_order()
	for type in Fixed.RECIPES[recipe].inputs:
		rear.ledger.add_stock("local-"+type,type,Fixed.RECIPES[recipe].inputs[type],1.0,"vehicle_input",rear.PLAYER)
	for person in rear.actors:
		if person in ["base-person-11","base-person-12"]: continue
		rear.reassign_person(person,"vehicle_works")
	rear.advance_time(1000)
	return {"base":base,"rear":rear,"id":heavy.bay_occupant}

func _test_station_readiness() -> void:
	var f: Dictionary = _produced("R31")
	var rear: RefCounted = f.rear
	var id: String = f.id
	_expect(not id.is_empty(),"T05 station fixture produced")
	if id.is_empty(): return
	for index in 4: rear.add_person("tank-crew-%d" % index,true,"P08")
	var service: RefCounted = rear.vehicles
	_expect(not service.readiness(id).transfer_crew_eligible,"empty T05 not transfer eligible")
	_expect(service.assign_station(id,"tank-crew-0","Driver").ok,"T05 driver reports")
	rear.advance_time(160)
	_expect(service.readiness(id).transfer_crew_eligible and not service.readiness(id).combat_crew_ready,"driver-only transfer distinct from combat")
	_expect(not service.assign_station(id,"tank-crew-1","Driver").ok,"no double driver station")
	_expect(service.assign_station(id,"tank-crew-1","Gunner").ok,"T05 gunner reports")
	_expect(service.assign_station(id,"tank-crew-2","Loader").ok,"T05 loader reports")
	rear.advance_time(160)
	_expect(service.readiness(id).main_fire_stations_ready and not service.readiness(id).combat_crew_ready,"T05 gunner and loader station readiness without commander")
	_expect(service.readiness(id).matching_ammo == 0 and not service.readiness(id).combat_ready,"empty rack remains separate")
	_expect(service.assign_station(id,"tank-crew-3","Commander").ok,"T05 commander reports")
	rear.advance_time(160)
	_expect(service.readiness(id).combat_crew_ready and not service.readiness(id).combat_ready,"four real crew but no ammo")
	_expect(rear.ledger.inspect_entity(id).crew_by_station.size() == 4,"four distinct identities occupy four stations")
	rear.ledger.add_stock("readiness-fuel","M08",5,1.0,"depot",rear.PLAYER)
	_expect(service.request_refuel(id,"base-person-11",5).ok,"readiness fixture starts physical fueling")
	rear.advance_time(200)
	_expect(service.readiness(id).motion_ready,"healthy actual driver and retained fuel permit motion readiness")
	rear.ledger._entities["tank-crew-0"].health = 0
	var unfit_driver: Dictionary = service.readiness(id)
	_expect(rear.ledger.inspect_entity(id).crew_by_station.has("Driver") and not service.assign_station(id,"tank-crew-3","Driver").ok,"unfit driver still physically occupies station")
	_expect(not unfit_driver.driver and not unfit_driver.transfer_crew_eligible and not unfit_driver.motion_ready and not unfit_driver.combat_crew_ready and "Driver" in unfit_driver.missing_stations,"incapacitated driver grants no readiness")
	_expect(not service.start_drive(id).ok,"incapacitated driver cannot clear F10")
	rear.ledger._entities["tank-crew-0"].health = 100
	rear.ledger._entities["tank-crew-1"].health = 0
	var unfit_gunner: Dictionary = service.readiness(id)
	_expect(unfit_gunner.transfer_crew_eligible and not unfit_gunner.main_fire_stations_ready and not unfit_gunner.combat_crew_ready and "Gunner" in unfit_gunner.missing_stations,"incapacitated gunner removes fire and combat readiness, not driver transfer")
	rear.ledger._entities["tank-crew-1"].health = 100
	rear.ledger._entities["tank-crew-2"].qualification = "None"
	var unqualified_loader: Dictionary = service.readiness(id)
	_expect(not unqualified_loader.main_fire_stations_ready and not unqualified_loader.combat_crew_ready and "Loader" in unqualified_loader.missing_stations,"unqualified occupied loader grants no readiness")
	rear.ledger._entities["tank-crew-2"].qualification = "P08"
	_expect(service.readiness(id).combat_crew_ready and service.readiness(id).motion_ready,"restored actual crew restores readiness")
	_expect(rear.reassign_person("tank-crew-3","Available").ok,"commander requests extraction")
	_expect(rear.ledger.inspect_entity("tank-crew-3").crew_station == "Commander","extraction does not instantly empty station")
	rear.advance_time(3)
	_expect(rear.ledger.inspect_entity("tank-crew-3").crew_station.is_empty(),"three-second extraction clears physical station")
	_expect(not service.readiness(id).combat_crew_ready,"commander loss removes crew readiness")
	_expect(f.base.audit().is_empty(),"station audit " + str(f.base.audit()))
	var technical: Dictionary = _produced("R29")
	technical.rear.add_person("heavy-gunner",true,"P04")
	_expect(technical.rear.vehicles.assign_station(technical.id,"heavy-gunner","Gunner").ok,"T03 accepts real P04 gunner")
	technical.rear.advance_time(160)
	_expect(technical.rear.ledger.inspect_entity("heavy-gunner").crew_station == "Gunner","T03 P04 physically aboard")
	_expect(technical.base.audit().is_empty(),"T03 station audit " + str(technical.base.audit()))
	var apc: Dictionary = _produced("R30")
	apc.rear.add_person("wrong-gunner",true,"P04")
	_expect(not apc.rear.vehicles.assign_station(apc.id,"wrong-gunner","Gunner").ok,"T04 gunner requires P08")

func _test_interruptions() -> void:
	var f: Dictionary = _produced("R25")
	var rear: RefCounted = f.rear
	var id: String = f.id
	if id.is_empty():
		_expect(false,"interruption fixture produced hull")
		return
	rear.add_person("trip-driver",true,"P08")
	_expect(rear.vehicles.assign_station(id,"trip-driver","Driver").ok,"driver report begins")
	rear.advance_time(160)
	rear.ledger.add_stock("purchased-fuel-fixture","M08",50,1.0,"depot",rear.PLAYER)
	rear.set_store("depot",false)
	_expect(not rear.vehicles.request_refuel(id,"base-person-11",25).ok,"inaccessible stock cannot fuel")
	rear.set_store("depot",true)
	_expect(rear.vehicles.request_refuel(id,"base-person-11",25).ok,"whole 25 fuel claim reserved")
	_expect(not rear.vehicles.request_refuel(id,"base-person-12",16).ok,"two pending carries cannot exceed tank capacity")
	rear.set_store("depot",false)
	rear.advance_time(150)
	_expect(rear.ledger.inspect_entity(id).fuel == 0.0,"blocked source does not create tank fuel")
	_expect(rear.ledger.inspect_claim("vehicle-fuel-0001").reserved == 25,"own fuel claim retained during access loss")
	rear.set_store("depot",true)
	rear.advance_time(200)
	_expect(rear.ledger.inspect_entity(id).fuel == 25.0,"restored access completes same physical carry")
	rear.heavy_production.set_access(true,false)
	_expect(not rear.vehicles.start_drive(id).ok and rear.heavy_production.bay_occupant == id,"parking access prevents clearance")
	rear.heavy_production.set_access(true,true)
	_expect(rear.vehicles.start_drive(id).ok,"valid promised parking permits movement")
	rear.advance_time(1)
	_expect(rear.heavy_production.bay_occupant == id and rear.vehicles.vehicles[id].distance > 0.0,"bay claim persists during measured motion")
	_expect(rear.ledger.inspect_entity(id).fuel < 25.0,"only traveled metres burn fuel")
	rear.heavy_production.set_access(true,false)
	var paused_distance: float = rear.vehicles.vehicles[id].distance
	var paused_fuel: float = rear.ledger.inspect_entity(id).fuel
	rear.advance_time(50)
	_expect(rear.vehicles.vehicles[id].state == "Stopped on lane" and rear.vehicles.vehicles[id].distance == paused_distance and rear.ledger.inspect_entity(id).fuel == paused_fuel,"mid-lane access loss stops position and burn with claims retained")
	_expect(rear.reassign_person("trip-driver","Available").ok,"lane driver may request safe extraction")
	_expect(rear.ledger.inspect_entity("trip-driver").crew_station == "Driver","lane driver cannot instantly vacate")
	rear.heavy_production.set_access(true,true)
	rear.advance_time(100)
	_expect(rear.vehicles.vehicles[id].state == "Parked" and rear.heavy_production.bay_occupant.is_empty(),"once-only physical parking handoff")
	_expect(rear.ledger.inspect_entity("trip-driver").crew_station.is_empty(),"driver exits after stopped three-second handling")
	_expect(id in rear.ledger.rear_fleet_hulls(rear.PLAYER),"parking does not release fleet admission")
	_expect(f.base.audit().is_empty(),"interruption audit " + str(f.base.audit()))

func _test_connected_session() -> void:
	var base := Base.new()
	var rear: RefCounted = base.rear
	_expect(base.receiving.buy_recovery_instructor().ok,"paid recovery instructor purchased")
	rear.advance_time(150)
	_expect(rear.ledger.inspect_entity("delivery-0001-person-01").basic_training,"same purchased instructor arrived")
	rear.set_target("training",1)
	_expect(rear.training.request_course("P01",1).ok,"actual basic course requested")
	rear.advance_time(300)
	var student: String = rear.training.rows[0].person_id
	_expect(not student.is_empty() and rear.ledger.inspect_entity(student).basic_training,"same basic student qualified")
	_expect(rear.training.request_course("P08",1).ok,"actual vehicle course requested")
	rear.advance_time(350)
	_expect(rear.training.rows[1].person_id == student and rear.ledger.inspect_entity(student).qualification == "P08","same F06 student became P08")
	var heavy: RefCounted = rear.heavy_production
	heavy.set_mode("Continuous")
	_expect(heavy.accept_order().ok,"normal-session T01 order reserves bay before materials")
	_expect(base.receiving.buy_resources({"M01":120,"M02":80,"M08":5}).ok,"real inputs and fuel purchased")
	_expect(base.receiving.buy_people().ok,"additional real labour purchased")
	rear.set_target("receiving",2)
	rear.set_target("hauling",4)
	rear.set_target("vehicle_works",8)
	rear.request_haul("receiving","vehicle_input","M01",120)
	rear.request_haul("receiving","vehicle_input","M02",80)
	rear.advance_time(1000)
	var id: String = heavy.bay_occupant
	_expect(not id.is_empty(),"normal-session received and hauled ingredients became produced hull")
	if id.is_empty(): return
	_expect(rear.ledger.inspect_entity(id).fuel == 0.0,"F06 and G04 created no fuel")
	_expect(rear.vehicles.assign_station(id,student,"Driver").ok,"same F06 graduate reports to manufactured hull")
	rear.advance_time(170)
	_expect(rear.ledger.inspect_entity(student).crew_station == "Driver","same graduate physically boarded")
	var worker := ""
	for person in rear.actors:
		if person == student: continue
		var result: Dictionary = rear.vehicles.request_refuel(id,person,5)
		if result.ok:
			worker = person
			break
	_expect(not worker.is_empty(),"real rear worker reserved purchased local M08")
	if worker.is_empty(): return
	rear.advance_time(220)
	_expect(rear.ledger.inspect_entity(id).fuel == 5.0 and rear.ledger.total_stock("M08") == 0,"purchased M08 moved from source to same tank")
	_expect(rear.vehicles.start_drive(id).ok,"normal-session produced hull begins actual clearance")
	rear.advance_time(100)
	_expect(rear.vehicles.vehicles[id].state == "Parked" and heavy.bay_occupant.is_empty(),"same produced hull parked, bay cleared")
	_expect(base.audit().is_empty(),"connected rear audit " + str(base.audit()))
