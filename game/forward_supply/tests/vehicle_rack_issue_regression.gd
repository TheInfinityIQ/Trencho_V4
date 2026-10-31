extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
const AT := Vector2(1640,150)
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _initialize() -> void:
	var base: RefCounted = Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	check(ledger.add_place("rack-stop","Physical arrived ammunition stop",AT).ok,"declare real forward stop")
	check(rear.forward_supply.register_delivery_stop("rack-stop").ok,"register local stop")
	var roster: Array[String] = []
	for index in 4:
		var id := "rack-handler-%d" % index
		check(ledger.add_person(id,"rack-stop",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"real field person")
		check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"real carried rifle")
		check(ledger.add_stock(id+"-ammo","E02",60,0.02,id,rear.PLAYER).ok,"real personal ammo")
		roster.append(id)
	check(rear.military.add_initial_squad("rack-squad","Rifle",roster,"rack-company","rack-platoon",rear.PLAYER).ok,"real roster")
	check(ledger.add_initial_vehicle("rack-t04","T04","rack-stop",rear.PLAYER,Specs.TYPES.T04,80,"Military").ok,"real empty initial T04")
	for station in Specs.TYPES.T04.stations:
		var id: String = "rack-t04-"+str(station)
		check(ledger.add_person(id,"rack-stop",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok,"real distinct crew")
		check(ledger.assign_initial_vehicle_crew(id,"rack-t04",station).ok,"real initial station occupancy")
	check(rear.military.attach_initial_vehicle("rack-t04","rack-platoon").ok,"attach same T04")
	check(rear.military.set_vehicle_mission("rack-t04",{"E26":180},0).ok,"retain actual 180 round mission target")
	check(ledger.move_entity("rack-t04","rack-stop",AT+Vector2(5,0)).ok,"stopped actual hull five metres from arrived stock")
	check(ledger.add_stock("rack-e26","E26",300,0.5,"rack-stop",rear.PLAYER).ok,"actual arrived E26")
	check(ledger.add_stock("rack-wrong","E02",10,0.02,"rack-stop",rear.PLAYER).ok,"actual wrong ammo")
	check(ledger.add_initial_vehicle("rack-enemy","T04","rack-stop","army-red",Specs.TYPES.T04,80,"Military").ok,"real hostile target")
	check(ledger.move_entity("rack-enemy","rack-stop",AT+Vector2(105,0)).ok,"actual target away from friendly workers")
	check(not rear.military.vehicle_capability("rack-t04","Fire").ok and rear.military.vehicle_readiness("rack-t04") == 0,"empty actual rack is notready despite arrived remote stock")
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-wrong","rack-t04",roster[0],5,"rack-stop").ok,"wrong ammo refused")
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-enemy",roster[0],5,"rack-stop").ok,"foreign hull refused")
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-t04","rack-t04-Driver",5,"rack-stop").ok,"seated crew cannot also act as courier")
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-t04",roster[0],241,"rack-stop").ok,"rack overflow refused before claims")
	check(ledger.add_stock("rack-foreign","E26",5,0.5,"rack-stop","army-red").ok,"foreign actual stock")
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-foreign","rack-t04",roster[0],5,"rack-stop").ok,"foreign stock refused")
	check(ledger.move_entity("rack-t04","rack-stop",AT+Vector2(30,0)).ok,"hull physically outside local radius")
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-t04",roster[0],5,"rack-stop").ok,"distant hull refused")
	check(ledger.move_entity("rack-t04","rack-stop",AT+Vector2(5,0)).ok,"hull returns locally")
	rear.battlefield_operations = Execution.new(rear)
	rear.battlefield_operations._walk(roster[0],"rack-stop",AT+Vector2(0,10))
	check(rear.battlefield_operations.person_committed(roster[0]),"real tactical foot motion starts")
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-t04",roster[0],5,"rack-stop").ok,"moving handler refused")
	rear.battlefield_operations = null
	check(ledger.move_entity(roster[0],"rack-stop",AT+Vector2(30,0)).ok,"handler really walks outside local radius")
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-t04",roster[0],5,"rack-stop").ok,"distant handler refused")
	check(ledger.move_entity(roster[0],"rack-stop",AT).ok,"handler returns to actual stock")
	rear.combat.reloads["rack-handler-0-rifle"] = {"operator":roster[0],"due":INF}
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-t04",roster[0],5,"rack-stop").ok,"busy reload handler refused")
	rear.combat.reloads.clear()
	var issue: Dictionary = rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-t04",roster[0],180,"rack-stop")
	check(issue.ok,"actual local 180 round issue accepts multiple carry portions: "+str(issue))
	if not issue.ok: quit(1); return
	check(ledger.inspect_entity("rack-t04").ammunition.get("E26",0) == 0,"reservation never remotely fills rack")
	check(rear.forward_supply.person_committed(roster[0]) and rear.forward_supply.hull_committed("rack-t04"),"one common physical commitment owns handler and hull")
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-t04",roster[1],5,"rack-stop").ok,"overlapping rack handler refused")
	check(not rear.forward_supply.start_issue("rack-wrong",roster[1],roster[0],1,"rack-stop").ok,"rack courier cannot also perform personal forward issue")
	rear.advance_time(2)
	var row: Dictionary = rear.forward_supply.rack_issue.jobs[issue.id]
	check(not row.carry.is_empty() and ledger.inspect_entity(row.carry).holder_id == roster[0],"pickup creates one real carried portion: "+str(row))
	if row.carry.is_empty(): quit(1); return
	check(ledger.inspect_entity(roster[0]).contents_mass_kg <= 25,"actual retained gear plus portion stays within25kg")
	check(rear.forward_supply.rack_issue.interrupt(issue.id).ok,"carrying can be interrupted")
	var carried_id: String = row.carry
	rear.advance_time(2)
	check(row.issued == 0 and ledger.inspect_entity(carried_id).holder_id == roster[0],"interruption keeps goods with real handler and no rack fill")
	check(rear.forward_supply.rack_issue.resume(issue.id).ok,"same real carry resumes")
	check(ledger.move_entity("rack-t04","rack-stop",AT+Vector2(6,0)).ok,"actual hull moves during local carry")
	rear.advance_time(1)
	check(row.state == "Interrupted Carry" and ledger.inspect_entity(carried_id).holder_id == roster[0],"hull movement interrupts without losing or remotely depositing carried ammunition")
	check(rear.forward_supply.rack_issue.resume(issue.id).ok,"same carry replans to now-stopped local hull")
	rear.advance_time(90)
	check(row.state == "Complete" and row.issued == 180,"all multiple physical portions complete timed walking and deposit: "+str(row.state))
	check(ledger.inspect_entity("rack-t04").ammunition.E26 == 180 and ledger.inspect_entity("rack-e26").quantity == 120,"rack and source conserve same180 actual rounds")
	var inspected: Dictionary = rear.forward_supply.rack_issue.snapshot()
	inspected.rows[0].issued = 999
	check(row.issued == 180 and rear.forward_supply.rack_issue.snapshot("army-red").rows.is_empty(),"detached own snapshots cannot change issue owner or expose opposing rows")
	check(is_equal_approx(rear.military.vehicle_readiness("rack-t04"),1),"matching actual issue reaches unchanged180 target")
	check(rear.vehicle_combat.aim("rack-t04","rack-enemy").ok,"actual gunner aims at real hostile hull")
	rear.advance_time(4)
	var fired: Dictionary = rear.vehicle_combat.fire("rack-t04","rack-enemy","Autocannon")
	check(fired.ok and ledger.inspect_entity("rack-t04").ammunition.E26 == 179,"actual ammunition release consumes one delivered E26: "+str(fired))
	check(not rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-t04",roster[0],62,"rack-stop").ok,"max240 includes virtual loaded rounds once in physical rack count")
	var topup: Dictionary = rear.forward_supply.request_vehicle_rack_issue("rack-e26","rack-t04",roster[0],61,"rack-stop")
	check(topup.ok,"physical179 plus61 reaches max240 without double-counting the virtual loaded magazine")
	if topup.ok: check(rear.forward_supply.rack_issue.interrupt(topup.id).ok,"unused exact-max topup releases its own source claim")
	check(base.audit().is_empty(),"shared ledger reconciles after local rack issue and fire: "+str(base.audit()))
	print("Vehicle rack issue regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
