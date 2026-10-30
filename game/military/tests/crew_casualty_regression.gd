extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _initialize() -> void:
	var base: RefCounted = Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var roster: Array[String] = []
	for index in 4:
		var id := "crew-support-%d" % index
		check(ledger.add_person(id,"hq-berth",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"actual support person")
		check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"actual rifle")
		check(ledger.add_stock(id+"-rounds","E02",60,0.02,id,rear.PLAYER).ok,"actual personal ammo")
		roster.append(id)
	check(rear.military.add_initial_squad("crew-support","Rifle",roster,"crew-company","crew-platoon",rear.PLAYER).ok,"actual parent formation")
	check(ledger.add_initial_vehicle("crew-apc","T04","hq-berth",rear.PLAYER,Specs.TYPES.T04,80,"Military").ok,"actual military APC")
	for station in Specs.TYPES.T04.stations:
		var id: String = "crew-"+str(station)
		check(ledger.add_person(id,"hq-berth",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok,"distinct actual crew")
		check(ledger.assign_initial_vehicle_crew(id,"crew-apc",station).ok,"actual assigned station")
	check(rear.military.attach_initial_vehicle("crew-apc","crew-platoon").ok,"same hull attaches")
	check(ledger.add_stock("crew-apc-rounds","E26",180,0.5,"crew-apc",rear.PLAYER).ok,"actual rack ammunition")
	check(ledger.add_place("crew-target-place","Actual target",Vector2(1740,91)).ok,"actual hostile place")
	check(ledger.add_initial_vehicle("crew-target","T04","crew-target-place","army-red",Specs.TYPES.T04,80,"Military").ok,"actual hostile hull")
	check(rear.vehicle_combat.aim("crew-apc","crew-target").ok,"actual healthy gunner aims")
	rear.advance_time(2)
	check(rear.military.vehicle_readiness("crew-apc") == 1 and rear.military.vehicle_capability("crew-apc","Fire").ok and rear.vehicle_combat.inspect_fire("crew-apc","crew-target","Autocannon").ok,"healthy real crew supports readiness and fire")
	# Deliberate invalid fixture state proves the audit still rejects an unrelated
	# healthy duty in an occupied military station.
	ledger._set_assignment(ledger._entities["crew-Gunner"],Records.Assignment.HQ_RESERVE,"")
	check(not rear.military.audit().is_empty(),"healthy wrong assignment still fails military audit")
	ledger._set_assignment(ledger._entities["crew-Gunner"],Records.Assignment.FORMATION_DUTY,"vehicle:crew-apc")
	check(base.audit().is_empty(),"restored actual crew fixture reconciles")
	check(rear.combat.injure("crew-Gunner",100).ok,"actual seated gunner incapacitated")
	assert_casualty(base,"Wounded")
	check(ledger.finish_field_care("crew-Gunner").ok,"actual stabilized patient enters Recovery")
	assert_casualty(base,"Recovery")
	check(rear.combat.injure("crew-Gunner",100).ok and rear.combat.injure("crew-Gunner",1).ok,"actual additional injury records death")
	assert_casualty(base,"Dead")
	print("Crew casualty regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func assert_casualty(base: RefCounted, state: String) -> void:
	var rear: RefCounted = base.rear
	var hull: Dictionary = rear.ledger.inspect_entity("crew-apc")
	var person: Dictionary = rear.ledger.inspect_entity("crew-Gunner")
	check(person.assignment == state and person.holder_id == "crew-apc" and person.crew_station == "Gunner" and person.position.is_equal_approx(hull.position),state+" remains in same actual station without teleport")
	check(hull.crew_by_station.size() == 3 and hull.crew_by_station.Gunner == "crew-Gunner" and hull.passengers.is_empty(),state+" neither creates a station nor turns crew into passenger")
	check(rear.military._living_crew_id(hull,"Gunner").is_empty() and rear.military.vehicle_readiness("crew-apc") < 1 and not rear.military.vehicle_capability("crew-apc","Fire").ok,state+" cannot satisfy operational crew readiness")
	check(not rear.vehicle_combat.fire("crew-apc","crew-target","Autocannon").ok and rear.ledger.inspect_entity("crew-apc").ammunition.E26 == 180,state+" cannot fire or consume actual rack ammunition")
	check(base.audit().is_empty(),state+" physical seat reconciles across military and ledger: "+str(base.audit()))
