extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Start = preload("res://game/scenario/battlefield_start.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Records = preload("res://game/identity/identity_records.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var base := Base.new(true,true,true,Vector2(2000,450),false)
	var rear: RefCounted = base.rear
	var armies: Dictionary = Start.apply(base)
	var facts: Array = rear.ledger.snapshot().entities
	_check(not rear.objectives.objectives.has("resource-central") and rear.ledger.inspect_entity("enemy-hq").is_empty(),"Authored scenario can declare its own sites without extra diagnostic objectives")
	for owner in ["army-blue","army-red"]:
		var people := 0
		var fixed_staff := 0
		var crew := 0
		var field_hulls := 0
		var field_fuel := 0.0
		var loaded := 0
		var rounds := 0
		var weapons := 0
		for item in facts:
			if item.owner != owner: continue
			if item.kind == "PERSON" and item.rear_place == "None":
				people += 1
				if item.assignment == "HQ Duty": fixed_staff += 1
				if not str(item.crew_station).is_empty(): crew += 1
				_check(item.health == 100 and item.contents_mass_kg <= 25,"Healthy bounded-load battlefield person")
			if item.kind == "WEAPON":
				weapons += 1
				loaded += int(item.loaded_rounds)
			if item.kind == "STOCK" and item.design_type == "E02": rounds += int(item.quantity)
			if item.kind == "CARRIER" and item.fleet_domain == "Military":
				field_hulls += 1
				field_fuel += float(item.fuel)
				_check(item.design_type in ["T01","T02","T03"] and item.health == item.max_health,"Only declared healthy starting field hull types")
		_check(people == 52 and fixed_staff == 5 and crew == 5,"Exact fifty-two battlefield people, fixed five and distinct five crew for "+owner)
		_check(field_hulls == 4 and is_equal_approx(field_fuel,150),"Exact field fleet and tank fuel for "+owner)
		_check(weapons == 56 and loaded == 400 and rounds == 8820,"Initial rifles and total rounds include loaded portions once for %s: weapons %d, loaded %d, rounds %d" % [owner,weapons,loaded,rounds])
		_check(rear.ledger.available_stock_at(armies[owner].stock,"E02") == 6000,"HQ starts with unchanged six thousand loose rounds")
		var squad_count := 0
		var infantry_rounds := 0
		var qualification_counts := {"None":0,"P02":0,"P03":0}
		for squad in rear.military.squads.values():
			if squad.owner != owner: continue
			squad_count += 1
			_check(squad.roster.size() == 8 and rear.military.capability(squad.id).ok,"Each starting squad has its actual eight-person package")
			for id in squad.roster:
				qualification_counts[rear.ledger.inspect_entity(id).qualification] += 1
				infantry_rounds += rear.military._rounds(id)
		_check(squad_count == 5 and infantry_rounds == 1920 and qualification_counts == {"None":36,"P02":2,"P03":2},"Exact infantry qualifications and existing 1920 rounds")
	_check(rear.receiving.rear_population() == 60 and rear.ledger.rear_fleet_status(rear.PLAYER).live == 3,"Battlefield seed does not consume or duplicate rear people or hull places")
	_check(base.audit().is_empty(),"Complete initial physical ledger reconciles: "+str(base.audit()))
	_test_crew_admission()
	print("Battlefield start regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _test_crew_admission() -> void:
	var base := Base.new()
	var ledger: RefCounted = base.rear.ledger
	_check(ledger.add_initial_vehicle("crew-test-hull","T02","hq-berth","army-blue",Specs.TYPES.T02,40,"Military").ok,"Declared initial military hull")
	_check(ledger.add_person("foreign-driver","hq-berth","army-red",Records.Assignment.AVAILABLE,true,"P08","None").ok,"Foreign person at same physical place")
	_check(not ledger.assign_initial_vehicle_crew("foreign-driver","crew-test-hull","Driver").ok and ledger.inspect_entity("foreign-driver").assignment == "Available","Other army cannot occupy the initial station")
	for id in ["own-driver","second-driver"]: _check(ledger.add_person(id,"hq-berth","army-blue",Records.Assignment.AVAILABLE,true,"P08","None").ok,"Actual qualified own driver")
	_check(ledger.assign_initial_vehicle_crew("own-driver","crew-test-hull","Driver").ok,"One own driver occupies station")
	_check(not ledger.assign_initial_vehicle_crew("second-driver","crew-test-hull","Driver").ok and ledger.inspect_entity("second-driver").assignment == "Available","Refused double occupancy leaves the second driver unassigned")

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
