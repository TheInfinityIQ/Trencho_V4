extends SceneTree
## Real observation/link delivery distinguishes nonthreat contacts from route fire.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Routes = preload("res://game/routes/route_planner.gd")
const HQ := Vector2(2000,450)
const STOP := Vector2(2000,650)
var checks := 0
var failures := 0

func _initialize() -> void:
	_noncombat_contacts()
	for threat in ["Person","T03","T04","T05","Enemy HQ"]: _hostile(threat)
	_aged_margin()
	print("Route contact regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _fixture(threat: String = "", threat_position: Vector2 = Vector2(2100,550)) -> RefCounted:
	var base := Base.new(false,true,false,HQ,false)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	check(ledger.add_place("contact-stop","Declared physical destination",STOP).ok,"Actual stop")
	check(rear.forward_supply.register_delivery_stop("contact-stop").ok,"Declared supply stop")
	var roster: Array[String] = []
	for index in 4:
		var id := "contact-member-%d" % index
		check(ledger.add_person(id,"hq-berth",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual observer/unloader")
		check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual held weapon")
		check(ledger.add_stock(id+"-rounds","E02",60,0.02,id,rear.PLAYER).ok,"Actual local personal rounds")
		roster.append(id)
	check(rear.military.add_initial_squad("contact-squad","Rifle",roster,"contact-company","contact-platoon",rear.PLAYER).ok,"Actual hierarchy")
	check(ledger.move_entity(roster[0],"contact-stop",STOP+Vector2(5,0)).ok,"Actual destination unloader")
	for type in ["T01","T02"]:
		var id: String = "contact-own-"+type
		check(ledger.add_initial_vehicle(id,type,"hq-berth",rear.PLAYER,Specs.TYPES[type],40,"Military").ok,"Actual own military hull")
		check(ledger.add_person(id+"-driver","hq-berth",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok,"Actual qualified driver")
		check(ledger.assign_initial_vehicle_crew(id+"-driver",id,"Driver").ok,"Actual seated driver")
		rear.dispatch.military_hulls[id] = "Declared initial route fixture"
		rear.dispatch.military_people[id+"-driver"] = "Declared initial route fixture"
		check(rear.military.attach_initial_vehicle(id,"contact-platoon").ok,"Actual parent attachment")
	check(ledger.add_stock("contact-freight","E02",100,0.02,"hq-stock",rear.PLAYER).ok,"Real unloaded HQ freight")
	for kind in ["Resource","Route Hub","Observation"]:
		var id: String = "contact-"+kind
		check(ledger.add_place(id,"Declared public objective",Vector2(2010,550)).ok,"Actual objective place")
		check(rear.objectives.register(id,kind).ok,"Actual objective owner")
		# Declare a public scenario marker, not a contact. Only actual sampling
		# and command link delivery may populate Orders.contacts below.
		rear.orders.objective_markers[id] = kind
	for type in ["T01","T02"]:
		var id: String = "contact-red-"+type
		check(ledger.add_place(id+"-place","Actually observed unarmed transport",Vector2(2020,550)).ok,"Real transport place")
		check(ledger.add_initial_vehicle(id,type,id+"-place","army-red",Specs.TYPES[type],0,"Military").ok,"Real unarmed hostile transport")
	if not threat.is_empty():
		check(ledger.add_place("contact-hostile-place","Actual hostile source",threat_position).ok,"Actual hostile place")
		if threat == "Person":
			check(ledger.add_person("contact-hostile","contact-hostile-place","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual hostile person")
			check(ledger.add_weapon("contact-hostile-rifle","E01",4,"contact-hostile","army-red","E02",30).ok,"Actual hostile weapon")
			check(ledger.add_stock("contact-hostile-rounds","E02",30,0.02,"contact-hostile","army-red").ok,"Actual hostile ammunition")
			check(ledger.load_rounds("contact-hostile-rifle","contact-hostile-rounds",30).ok,"Actual hostile loaded weapon")
		elif threat == "Enemy HQ":
			check(rear.orders.register_enemy_hq("contact-hostile-place").ok,"Actual hostile HQ marker")
		else:
			check(ledger.add_initial_vehicle("contact-hostile",threat,"contact-hostile-place","army-red",Specs.TYPES[threat],0,"Military").ok,"Actual armed-class hostile hull")
	return base

func _observe(rear: RefCounted) -> void:
	check(rear.orders.watch("contact-squad").ok,"Actual squad samples visibility")
	check(rear.orders.contacts.get("contact-company",{}).is_empty(),"No instant company knowledge from marker declaration")
	rear.advance_time(3)
	for id in ["contact-Resource","contact-Route Hub","contact-Observation","contact-red-T01","contact-red-T02"]:
		var known: Dictionary = rear.orders.contact("contact-company",id)
		check(known.get("current",false) and known.get("confidence",0) > 0,"Real current report reaches actual company: "+id)
		if id.begins_with("contact-") and not id.begins_with("contact-red-"): check(known.get("observed_strength",-1) == 0,"Public marker has no observed armed strength")

func _delivery(rear: RefCounted, preview: bool = false) -> Dictionary:
	if preview: return rear.forward_supply.preview_delivery("contact-own-T01","contact-freight",50,"contact-stop",[HQ,STOP],[STOP,HQ],"initial-hq-01","contact-member-0")
	return rear.forward_supply.request_delivery("contact-own-T01","contact-freight",50,"contact-stop",[HQ,STOP],[STOP,HQ],"initial-hq-01","contact-member-0")

func _reposition(rear: RefCounted) -> Dictionary:
	return rear.military.request_reposition("contact-own-T02","contact-stop",[HQ,STOP],[STOP,HQ])

func _noncombat_contacts() -> void:
	var base := _fixture()
	var rear: RefCounted = base.rear
	_observe(rear)
	var moved := _reposition(rear)
	var delivered := _delivery(rear)
	check(moved.ok,"Public objectives and unarmed transports do not block military reposition: "+str(moved))
	check(delivered.ok,"Public objectives and unarmed transports do not block forward delivery: "+str(delivered))
	if not moved.ok or not delivered.ok: return
	var total: int = rear.ledger.total_stock("E02")
	rear.advance_time(1)
	check(rear.ledger.inspect_entity("contact-own-T02").position != HQ and rear.ledger.inspect_entity("contact-own-T02").position != STOP,"Same hull travels physically rather than teleporting")
	check(rear.ledger.available_stock_at("contact-stop","E02") == 0,"No instant freight delivery from route admission")
	rear.advance_time(80)
	check(rear.military.troop_transport.jobs[moved.id].state == "Complete","Military reposition completes with observed public markers retained")
	check(rear.forward_supply.transport.jobs[delivered.id].state == "Complete","Forward delivery and actual HQ return complete")
	check(rear.ledger.available_stock_at("contact-stop","E02") == 50 and rear.ledger.total_stock("E02") == total,"Same fifty fixture rounds physically arrive without inventory creation")
	check(rear.ledger.inspect_entity("contact-own-T02").fuel < 40 and rear.ledger.inspect_entity("contact-own-T01").fuel < 40,"Both real hulls burn actual travel fuel")
	check(base.audit().is_empty(),"Accepted nonthreat routes reconcile: "+str(base.audit()))

func _hostile(kind: String) -> void:
	var base := _fixture(kind)
	var rear: RefCounted = base.rear
	check(_delivery(rear,true).ok,"Unreported actual hostile does not create hidden supply-route knowledge: "+kind)
	check(rear.military.troop_transport._known_route_danger("contact-own-T02",[{"from":HQ,"to":STOP}]).is_empty(),"Unreported actual hostile does not create hidden military-route knowledge: "+kind)
	_observe(rear)
	var id := "contact-hostile-place" if kind == "Enemy HQ" else "contact-hostile"
	check(rear.orders.contact("contact-company",id).get("current",false),"Actual hostile threat reaches company: "+kind)
	var moved := _reposition(rear)
	var delivered := _delivery(rear)
	check(not moved.ok and "Observed hostile effective fire" in str(moved.get("message","")),"Military movement still refuses reported "+kind)
	check(not delivered.ok and "Unsafe ordinary supply route" in str(delivered.get("message","")),"Forward delivery still refuses reported "+kind)
	check(rear.ledger.inspect_entity("contact-freight").available == 100 and rear.ledger.inspect_entity("contact-own-T02").fuel == 40 and rear.ledger.inspect_entity("contact-own-T01").fuel == 40,"Refusal leaves actual stock/fuel unclaimed and unspent")
	check(base.audit().is_empty(),"Hostile refusal reconciles: "+kind)

func _aged_margin() -> void:
	var base := _fixture("Person",Vector2(2308,550))
	var rear: RefCounted = base.rear
	check(rear.ledger.move_entity("contact-member-1","hq-berth",Vector2(2140,550)).ok,"Actual observer can see a threat beyond the conservative route margin")
	_observe(rear)
	check(_delivery(rear,true).ok,"Fresh reported threat outside conservative margin permits a route preview")
	var plan: Dictionary = Routes.plan(rear.ledger,"contact-own-T02",[HQ,STOP],{"world":rear.combat.world})
	check(plan.ok and rear.military.troop_transport._known_route_danger("contact-own-T02",plan.parts).is_empty(),"Military route initially lies outside reported effective fire plus uncertainty")
	check(rear.orders.unwatch("contact-squad").ok,"Actual source stops observing")
	rear.advance_time(5)
	var known: Dictionary = rear.orders.contact("contact-company","contact-hostile")
	check(not known.current and known.confidence > 0 and known.uncertainty_m >= 10,"Lost current sight preserves aged delivered uncertainty")
	check(not _reposition(rear).ok and not _delivery(rear).ok,"Both actual admissions retain conservative uncertainty-expanded hostile refusal")
	rear.advance_time(55)
	check(rear.orders.contact("contact-company","contact-hostile").confidence == 0,"Unrefreshed actual contact expires normally")
	check(_reposition(rear).ok and _delivery(rear).ok,"Expired hostile report no longer supplies an invented route position")
