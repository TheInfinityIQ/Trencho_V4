extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var safe: RefCounted = _fixture()
	var rear: RefCounted = safe.rear
	check(rear.battlefield_operations._blocking_armour(rear.military.squads.red,Vector2(2000,2800)).is_empty(),"Unseen physical armour cannot change Red's mission")
	rear.advance_time(2)
	check(rear.battlefield_operations.motions.values().any(func(row: Dictionary) -> bool: return row.purpose == "Advance"),"Without a delivered contact the real acknowledged order advances")
	check(rear.orders.watch("red").ok,"Red observes through actual members")
	rear.advance_time(6)
	check(not rear.orders.contact("red","blue-armour").is_empty(),"Armour report reaches Red through the real observation link")
	check(rear.orders.reports.any(func(row: Dictionary) -> bool: return row.kind == "Inability" and "penetrating support" in row.detail),"Superior rifle numbers report the missing armour counter")
	check(not rear.battlefield_operations.motions.values().any(func(row: Dictionary) -> bool: return row.purpose == "Advance"),"Delivered mission-relevant armour stops ordinary offensive advance")
	check(rear.battlefield_operations.motions.values().any(func(row: Dictionary) -> bool: return row.purpose == "Fallback"),"Existing movement owner admits the declared safe fallback")
	check(safe.audit().is_empty(),"Safe fallback retains physical people and stock")

	var unsafe: RefCounted = _fixture()
	var blocked: RefCounted = unsafe.rear
	check(blocked.ledger.add_place("blocking-lane","Actual fallback threat",Vector2(2000,3150)).ok,"Fallback threat location")
	check(blocked.ledger.add_initial_vehicle("blocking-hull","T03","blocking-lane",blocked.PLAYER,Specs.TYPES.T03,20,"Military").ok,"Existing physical class blocks the declared fallback")
	check(blocked.orders.watch("red").ok,"Actual observers see the fallback threat")
	blocked.advance_time(6)
	check(blocked.battlefield_operations.motions.is_empty(),"No safe fallback means hold, without an invented alternate route")
	check(blocked.orders.reports.any(func(row: Dictionary) -> bool: return "fallback" in row.detail and row.kind == "Inability"),"Unsafe fallback remains reported")
	check(unsafe.audit().is_empty(),"Holding adds no counter equipment or force")

	var remote: RefCounted = _fixture(Vector2(2600,3000))
	check(remote.rear.ledger.move_entity("red-person-7","red-stage",Vector2(2400,3000)).ok,"A real separated member observes away from the leader's assigned approach")
	check(remote.rear.orders.watch("red").ok,"Actual observation of an unrelated armour contact")
	remote.rear.advance_time(2)
	check(not remote.rear.orders.contact("red","blue-armour").is_empty(),"Unrelated armour is actually delivered, not merely hidden")
	check(remote.rear.battlefield_operations._blocking_armour(remote.rear.military.squads.red,Vector2(2000,2800)).is_empty(),"A delivered contact away from the mission approach cannot block it")

	var pinned: RefCounted = _fixture()
	check(pinned.rear.orders.watch("red").ok,"Pinned case receives actual armour information")
	pinned.rear.advance_time(2)
	pinned.rear.combat._apply_stress("red-person-7",0,60,true)
	pinned.rear.advance_time(1)
	check(pinned.rear.combat.pinned.has("red-person-7") and not pinned.rear.battlefield_operations.person_committed("red-person-7"),"Armour fallback preserves the pinned member's stopped survival behavior")
	check(pinned.audit().is_empty(),"Pinned and ordinary fallback remain reconciled")

	# A declared time-zero support fixture isolates the existing counter check.
	var supported: RefCounted = _fixture(Vector2(2000,2820),true)
	check(supported.rear.orders.watch("red").ok,"Supported Red sees the same real armour")
	supported.rear.advance_time(3)
	check(supported.rear.battlefield_operations._blocking_armour(supported.rear.military.squads.red,Vector2(2000,2800)).is_empty(),"An existing actual ready counter removes the narrow inability gate")
	check(supported.rear.ledger.record_consumption("counter-round",1,"Declared prior counter fire").ok,"Real counter round consumed")
	check(not supported.rear.battlefield_operations._blocking_armour(supported.rear.military.squads.red,Vector2(2000,2800)).is_empty(),"An empty counter cannot substitute for penetrating capability")
	check(rear.orders.unwatch("red").ok,"Actual observer stops reporting")
	rear.advance_time(51)
	check(rear.battlefield_operations._blocking_armour(rear.military.squads.red,Vector2(2000,2800)).is_empty(),"Expired delivered armour does not become permanent hidden knowledge")
	check(safe.audit().is_empty(),"Counter consumption and expired reports preserve physical invariants")
	print("Observed armour regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _fixture(threat: Vector2 = Vector2(2000,2820), counter: bool = false) -> RefCounted:
	var base := Base.new(false,true)
	var rear: RefCounted = base.rear
	for item in [["red-stage",Vector2(2000,3000)],["red-goal",Vector2(2000,2800)],["red-fallback",Vector2(2000,3200)],["blue-stage",threat]]:
		check(rear.ledger.add_place(item[0],"Declared armour-response fixture",item[1]).ok,"Actual mission place")
	var roster: Array[String] = []
	for index in 8:
		var id := "red-person-%d" % index
		check(rear.ledger.add_person(id,"red-stage","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Existing Red member")
		check(rear.ledger.add_weapon(id+"-rifle","E01",4,id,"army-red","E02",30).ok,"Existing Red rifle")
		check(rear.ledger.add_stock(id+"-rounds","E02",60,0.02,id,"army-red").ok,"Existing actual Red rounds")
		check(rear.ledger.load_rounds(id+"-rifle",id+"-rounds",30).ok,"Existing loaded Red magazine")
		roster.append(id)
	check(rear.military.add_initial_squad("red","Rifle",roster,"red-company","red-platoon","army-red").ok,"Existing Red hierarchy")
	check(rear.ledger.add_initial_vehicle("blue-armour","T04","blue-stage",rear.PLAYER,Specs.TYPES.T04,20,"Military").ok,"Actual armour gives no report on its own")
	if counter:
		check(rear.ledger.add_initial_vehicle("red-counter","T05","red-stage","army-red",Specs.TYPES.T05,20,"Military").ok,"Actual time-zero counter hull")
		for station in Specs.TYPES.T05.stations:
			var person := "counter-"+str(station)
			check(rear.ledger.add_person(person,"red-stage","army-red",Records.Assignment.AVAILABLE,true,"P08","None").ok,"Actual qualified counter crew")
			check(rear.ledger.assign_initial_vehicle_crew(person,"red-counter",station).ok,"Actual distinct counter station")
		check(rear.military.attach_initial_vehicle("red-counter","red-platoon").ok,"Actual counter attached to this platoon")
		check(rear.ledger.add_stock("counter-round","E25",1,12.0,"red-counter","army-red").ok,"Actual penetrating rack round")
	rear.battlefield_operations = Execution.new(rear)
	check(rear.orders.issue_order("red-platoon","red","Seize Objective","Assigned approach","Observed armour response",{"destination":"red-goal","fallback_place":"red-fallback","role":"Rifle"},"Normal","Declared fallback").ok,"Actual intent sent to Red squad")
	return base

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(detail)
