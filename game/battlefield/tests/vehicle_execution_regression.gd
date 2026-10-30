extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
const AT := Vector2(2000,500)
var checks := 0
var failures := 0

func _initialize() -> void:
	_empty_then_physical_issue()
	_current_parent_contacts()
	_fire_guards()
	_t03_reload()
	_facing()
	_moving_contact_aim()
	_alternative_contact()
	_movement_commitment()
	_partition()
	print("Vehicle execution regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _fixture(type: String = "T04", rounds: int = 0, target_type: String = "T02", company_parent: bool = false) -> RefCounted:
	var base := Base.new(false,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	rear.combat.world.bounds = Rect2i(0,0,4000,6000)
	check(ledger.add_place("mounted-stop","Actual local stop",AT).ok,"Real stop")
	check(rear.forward_supply.register_delivery_stop("mounted-stop").ok,"Real forward destination")
	check(ledger.add_place("mounted-target-place","Observed hostile lane",AT+Vector2(0,200)).ok,"Real hostile place")
	var roster: Array[String] = []
	for index in 4:
		var id := "mounted-observer-%d" % index
		check(ledger.add_person(id,"mounted-stop",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual observer")
		check(ledger.move_entity(id,"mounted-stop",AT+Vector2(-15,-index)).ok,"Actual off-line observer")
		check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual retained rifle")
		check(ledger.add_stock(id+"-rounds","E02",60,0.02,id,rear.PLAYER).ok,"Actual retained personal ammunition")
		roster.append(id)
	check(rear.military.add_initial_squad("mounted-squad","Rifle",roster,"mounted-company","mounted-platoon",rear.PLAYER).ok,"Actual parent hierarchy")
	check(ledger.add_initial_vehicle("mounted-hull",type,"mounted-stop",rear.PLAYER,Specs.TYPES[type],20,"Military").ok,"Actual initial own hull")
	for station in Specs.TYPES[type].stations:
		var id: String = "mounted-"+str(station)
		check(ledger.add_person(id,"mounted-stop",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P04" if type == "T03" and station == "Gunner" else "P08","None").ok,"Actual qualified crew")
		check(ledger.assign_initial_vehicle_crew(id,"mounted-hull",station).ok,"Actual seated station")
	check(rear.military.attach_initial_vehicle("mounted-hull","mounted-company" if company_parent else "mounted-platoon").ok,"Actual attachment")
	check(ledger.add_initial_vehicle("mounted-target",target_type,"mounted-target-place","army-red",Specs.TYPES[target_type],20,"Military").ok,"Actual hostile hull")
	if rounds > 0: check(ledger.add_stock("mounted-rack","E02" if type == "T03" else "E26",rounds,0.02 if type == "T03" else 0.5,"mounted-hull",rear.PLAYER).ok,"Declared actual initial rack")
	rear.battlefield_operations = Execution.new(rear)
	return base

func _shots(rear: RefCounted) -> Array:
	return rear.vehicle_combat.events.filter(func(row: Dictionary) -> bool: return row.get("hull","") == "mounted-hull" and row.get("phase","") not in ["Impact","Miss"])

func _watch(rear: RefCounted) -> void:
	check(rear.orders.watch("mounted-squad").ok,"Actual observation starts")

func _empty_then_physical_issue() -> void:
	var base := _fixture()
	var rear: RefCounted = base.rear
	_watch(rear)
	rear.advance_time(4)
	check(rear.orders.contact("mounted-platoon","mounted-target").get("current",false),"Real sighting delivered through parent hierarchy")
	check(_shots(rear).is_empty(),"Observed target cannot make an empty T04 fire")
	check(rear.orders.reports.any(func(row: Dictionary) -> bool: return row.kind == "Low Supply" and "mounted-hull" in row.detail),"Empty rack produces an actual command report")
	check(rear.ledger.add_stock("mounted-arrival","E26",24,0.5,"mounted-stop",rear.PLAYER).ok,"Actual arrived matching freight")
	var issued: Dictionary = rear.forward_supply.request_vehicle_rack_issue("mounted-arrival","mounted-hull","mounted-observer-0",24,"mounted-stop")
	check(issued.ok,"Existing timed physical rack issue admitted")
	if not issued.ok: return
	rear.advance_time(2)
	check(rear.ledger.inspect_entity("mounted-hull").ammunition.get("E26",0) == 0 and _shots(rear).is_empty(),"Source reservation cannot fire or fill a rack")
	rear.advance_time(24)
	check(rear.forward_supply.rack_issue.jobs[issued.id].state == "Complete","Physical pickup walking and rack deposit complete")
	var shots := _shots(rear)
	check(not shots.is_empty() and shots[0].weapon == "Autocannon" and shots[0].ammo == "E26","Common clock autonomously aims and releases actual E26")
	check(int(rear.ledger.snapshot().consumed.get("E26",0)) == shots.size(),"Every released round is physically consumed once")
	check(int(rear.ledger.inspect_entity("mounted-arrival").quantity) == 0,"No new source ammunition granted")
	check(base.audit().is_empty(),"Timed rack supply and autonomous fire reconcile")

func _current_parent_contacts() -> void:
	var base := _fixture("T03",80,"T01",true)
	var rear: RefCounted = base.rear
	rear.advance_time(2)
	check(_shots(rear).is_empty(),"Loaded hull does not search hidden hostile entities")
	_watch(rear)
	rear.advance_time(0.4)
	check(_shots(rear).is_empty(),"Squad observation is not instantly delivered to attached company")
	rear.advance_time(4)
	check(rear.orders.contact("mounted-company","mounted-target").get("current",false) and not _shots(rear).is_empty(),"Real company-delivered contact enables autonomous MG fire")
	check(rear.orders.unwatch("mounted-squad").ok,"Actual source stops observation")
	var count := _shots(rear).size()
	rear.advance_time(5)
	check(_shots(rear).size() == count,"Positive-confidence stale report without current source cannot fire")
	var view: Dictionary = rear.battlefield_operations.snapshot()
	view.vehicles.status["mounted-hull"] = "Changed copy"
	check(rear.battlefield_operations.vehicle_execution.status["mounted-hull"] != "Changed copy","Own helper snapshot is detached")
	check(base.audit().is_empty(),"Delivered/stale contact behavior reconciles")

func _fire_guards() -> void:
	for combination in [["T03","T04"],["T04","T05"]]:
		var base := _fixture(combination[0],80,combination[1])
		_watch(base.rear)
		base.rear.advance_time(6)
		check(_shots(base.rear).is_empty(),"Incompatible armour does not force pointless "+str(combination[0])+" shots")
	var base := _fixture("T04",80)
	var rear: RefCounted = base.rear
	check(rear.ledger.add_person("mounted-friend","mounted-stop",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual friendly person")
	check(rear.ledger.move_entity("mounted-friend","mounted-stop",AT+Vector2(0,100)).ok,"Actual friendly firing-line obstruction")
	_watch(rear)
	rear.advance_time(6)
	check(_shots(rear).is_empty(),"Friendly-line admission remains authoritative")
	check(rear.ledger.move_entity("mounted-friend","mounted-stop",AT+Vector2(1,201)).ok,"Actual friendly in cannon blast radius off firing line")
	rear.advance_time(2)
	check(_shots(rear).is_empty(),"Friendly blast admission remains authoritative")
	check(rear.ledger.move_entity("mounted-friend","mounted-stop",AT+Vector2(-30,0)).ok,"Friend actually clears")
	rear.combat.world.obstacle("mounted-wall",Rect2(1990,590,20,5),0,5,true,true)
	rear.advance_time(2)
	check(_shots(rear).is_empty(),"Actual opaque terrain stops current sight and firing line")
	rear.combat.world.obstacles.clear()
	rear.combat.world.revision += 1
	check(rear.ledger.request_stock("mounted-reserved","mounted-rack",80,"mounted-test","Actual other rack commitment",rear.PLAYER).ok,"All real rack rounds reserved elsewhere")
	rear.advance_time(3)
	check(_shots(rear).is_empty(),"Reserved rack stock cannot autonomously fire")
	check(rear.ledger.release_claim("mounted-reserved").ok,"Real competing claim releases")
	check(base.audit().is_empty(),"Safety/refusal paths preserve people and ammunition: "+str(base.audit()))
	rear.combat.injure("mounted-Gunner",1000)
	rear.advance_time(3)
	check(_shots(rear).is_empty(),"Lost actual gunner blocks fire despite ready rack")
	check(not rear.military.vehicle_capability("mounted-hull","Fire").ok,"Dead station occupant cannot count as a surviving qualified gunner")

func _t03_reload() -> void:
	var base := _fixture("T03",80,"T01")
	var rear: RefCounted = base.rear
	_watch(rear)
	rear.advance_time(18)
	var shots := _shots(rear)
	check(shots.size() == 60,"T03 uses its real sixty-round magazine at quarter-second cadence")
	if shots.size() > 1:
		check(is_equal_approx(float(shots[1].time)-float(shots[0].time),0.25),"Helper preserves mounted cadence between infantry decisions")
	check(rear.vehicle_combat.mounts["mounted-hull"].reload_due.has("MG"),"Magazine exhaustion autonomously starts the existing six-second reload")
	rear.advance_time(8)
	shots = _shots(rear)
	check(shots.size() > 60 and int(rear.ledger.snapshot().consumed.get("E02",0)) == shots.size(),"Same local E02 rack restores mounted fire after reload")
	if shots.size() > 60: check(float(shots[60].time)-float(shots[59].time) >= 6.0,"No shot bypasses real reload duration")
	check(base.audit().is_empty(),"MG cadence reload and rack consumption reconcile")

func _facing() -> void:
	var base := _fixture("T04",80)
	var rear: RefCounted = base.rear
	check(rear.vehicle_combat.set_facing("mounted-hull",270).ok,"Hull starts at an actual opposite bearing")
	_watch(rear)
	rear.advance_time(4)
	check(_shots(rear).is_empty(),"Opposite-facing previously unused turret cannot skip real turn time")
	check(is_equal_approx(float(rear.vehicle_combat.mounts["mounted-hull"].aim_due),2.0+175.0/60.0),"Actual facing establishes the full mount turn deadline")
	rear.advance_time(1)
	check(not _shots(rear).is_empty(),"Stable target fires when real aim time elapses without resetting aim")
	check(base.audit().is_empty(),"Non-default bearing and autonomous fire reconcile")

func _partition() -> void:
	var coarse := _fixture("T04",80)
	var fine := _fixture("T04",80)
	_watch(coarse.rear)
	_watch(fine.rear)
	coarse.rear.advance_time(10)
	for index in 100: fine.rear.advance_time(0.1)
	var a := _shots(coarse.rear)
	var b := _shots(fine.rear)
	check(a.size() > 3 and a.size() == b.size(),"Coarse and fractional common-clock advances release the same shots")
	if a.size() > 3:
		check(is_equal_approx(float(a[1].time)-float(a[0].time),1.0/3.0) and is_equal_approx(float(a[2].time)-float(a[1].time),1.0/3.0),"Autocannon keeps actual three-round burst spacing")
		check(is_equal_approx(float(a[3].time)-float(a[2].time),4.0/3.0),"Autocannon keeps actual pause between bursts")
	for index in mini(a.size(),b.size()): check(is_equal_approx(float(a[index].time),float(b[index].time)),"Actual aim/cadence release time is partition independent")
	if not a.is_empty(): check(float(a[0].time) >= 1.5+85.0/60.0,"New turret starts from real facing and spends actual aim time")
	check(coarse.rear.ledger.inspect_entity("mounted-hull").ammunition == fine.rear.ledger.inspect_entity("mounted-hull").ammunition,"Partitioning preserves matching physical rack")
	check(coarse.rear.ledger.inspect_entity("mounted-target").health == fine.rear.ledger.inspect_entity("mounted-target").health,"Partitioning preserves actual projectile outcomes")
	check(coarse.audit().is_empty() and fine.audit().is_empty(),"Both common-clock partitions reconcile")

func _moving_contact_aim() -> void:
	var base := _fixture("T04",80)
	var rear: RefCounted = base.rear
	check(rear.vehicle_combat.set_facing("mounted-hull",270).ok,"Actual opposite initial bearing for moving contact")
	_watch(rear)
	rear.advance_time(2.5)
	var due: float = rear.vehicle_combat.mounts["mounted-hull"].aim_due
	check(due > rear.time,"An actual long turn is already in progress")
	check(rear.ledger.move_entity("mounted-target","mounted-target-place",AT+Vector2(50,200)).ok,"Observed target actually moves to a new bearing")
	rear.advance_time(1.5)
	check(_shots(rear).is_empty() and is_equal_approx(float(rear.vehicle_combat.mounts["mounted-hull"].aim_due),due),"Reacquisition cannot treat the desired angle as an already completed turn")
	rear.advance_time(3)
	var shots := _shots(rear)
	check(not shots.is_empty() and float(shots[0].time) >= due,"Autonomous reacquisition waits for physical turn then updated alignment")
	check(base.audit().is_empty(),"Moving-contact aim preserves actual clock and ammunition")

func _alternative_contact() -> void:
	var base := _fixture("T03",80,"T01")
	var rear: RefCounted = base.rear
	check(rear.ledger.add_initial_vehicle("mounted-alternative","T01","mounted-target-place","army-red",Specs.TYPES.T01,20,"Military").ok,"Second actual compatible hostile")
	check(rear.ledger.move_entity("mounted-alternative","mounted-target-place",AT+Vector2(90,190)).ok,"Second actual visible direction")
	check(rear.ledger.add_person("mounted-blocker","mounted-stop",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual line blocker")
	check(rear.ledger.move_entity("mounted-blocker","mounted-stop",AT+Vector2(0,100)).ok,"Nearest contact line is physically obstructed")
	_watch(rear)
	rear.advance_time(7)
	var shots := _shots(rear)
	check(shots.size() > 1 and shots.all(func(row: Dictionary) -> bool: return row.target == "mounted-alternative"),"A refused nearest contact does not reset aim away from a usable alternative")
	check(base.audit().is_empty(),"Alternative target acquisition reconciles")

func _movement_commitment() -> void:
	var base := _fixture("T03",80,"T01")
	var rear: RefCounted = base.rear
	var destination := AT+Vector2(100,0)
	check(rear.ledger.add_place("mounted-park","Actual reposition destination",destination).ok,"Declared physical destination")
	var trip: Dictionary = rear.military.request_reposition("mounted-hull","mounted-park",[AT,destination],[destination,AT])
	check(trip.ok,"Existing service commits actual movement")
	_watch(rear)
	rear.advance_time(5)
	check(rear.ledger.inspect_entity("mounted-hull").position != AT and _shots(rear).is_empty(),"Moving committed hull waits instead of claiming stationary fire")
	check(base.audit().is_empty(),"Deferred mounted fire leaves physical movement owner intact")
