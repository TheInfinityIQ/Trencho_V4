extends SceneTree
## Focused declared receipt/output fixtures, NOT proof of the R30/FleetTransfer UI chain.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Map = preload("res://game/battlefield/farmland_scenario.gd")
const Session = preload("res://game/scenario/farmland_session.gd")
const Deployment = preload("res://game/battlefield/vehicle_deployment.gd")
const HULL := "deployment-output"
const RECEIPT := "deployment-receipt"
const COMPANY := "deployment-company"
const PLATOON := "deployment-platoon"
var checks := 0
var failures := 0

func _initialize() -> void:
	_receipt_filters()
	_command_and_readiness()
	_route_refusals()
	_two_physical_legs()
	_policy_discovery()
	print("Vehicle deployment regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _hull(rear: RefCounted, parent: String) -> void:
	var ledger: RefCounted = rear.ledger
	check(ledger.reserve_rear_hull("deployment-admission",rear.PLAYER,"deployment-fixture").ok,"Declared physical hull admission")
	check(ledger.create_heavy_output("deployment-admission","deployment-fixture",HULL,"T04","hq-berth",rear.PLAYER,Specs.TYPES.T04).ok,"Declared empty manufactured output; no recipe completion claim")
	check(ledger.inspect_entity(HULL).fuel == 0.0 and ledger.inspect_entity(HULL).ammunition.is_empty(),"Output starts without fuel or ammunition")
	check(ledger.complete_hq_hull_receipt(HULL).ok,"Fixture same-hull HQ transfer")
	for station in ["Driver","Gunner","Commander"]:
		var id: String = "deployment-"+str(station)
		check(ledger.add_person(id,"hq-berth",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok,"Declared distinct P08 crew")
		check(ledger.assign_initial_vehicle_crew(id,HULL,station).ok,"Same actual qualified person occupies station")
		rear.dispatch.military_people[id] = RECEIPT
	# Explicit declared completed-manifest fixture; end-to-end real dispatch is a root gate.
	rear.dispatch.manifests[RECEIPT] = {"id":RECEIPT,"hull":HULL,"mode":"Fleet Transfer","state":"Complete","task":{},"hq_berth":false}
	rear.dispatch.military_hulls[HULL] = RECEIPT
	check(rear.military.attach_vehicle(HULL,parent).ok,"Actual admitted staffed hull attaches to named parent")
	check(ledger.add_stock("deployment-fuel","M08",60,1.0,"hq-berth",rear.PLAYER).ok,"Declared real local fuel supply")
	for _portion in 3:
		check(ledger.begin_carry("initial-hq-01","deployment-fuel",20).ok,"Actual fuel carry")
		check(ledger.load_vehicle_fuel("initial-hq-01",HULL).ok,"Actual carried fuel enters same tank")

func _fixture() -> Dictionary:
	var base := Base.new(false,true,false,Map.BLUE_HQ,false)
	var rear: RefCounted = base.rear
	Map.apply(rear.combat.world)
	var points: Dictionary = Map.waypoints()
	check(rear.ledger.add_place("blue-delivery","Declared forward supply stop",points["blue-delivery"]).ok,"Physical supply stop")
	check(rear.forward_supply.register_delivery_stop("blue-delivery",points["blue-delivery-route"],points["blue-delivery-return"]).ok,"Forward owner knows declared stop")
	check(rear.ledger.add_place("observation-central","Declared fixed support destination",Vector2(2000,3000)).ok,"Existing-map support point fixture")
	var roster: Array[String] = []
	for index in 4:
		var id := "deployment-person-%d" % index
		check(rear.ledger.add_person(id,"blue-delivery",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Declared existing forward formation member")
		check(rear.ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual rifle")
		check(rear.ledger.add_stock(id+"-rounds","E02",60,0.02,id,rear.PLAYER).ok,"Actual personal package")
		roster.append(id)
	check(rear.military.add_initial_squad("deployment-squad","Rifle",roster,COMPANY,PLATOON,rear.PLAYER).ok,"Existing actual command hierarchy")
	_hull(rear,PLATOON)
	return {"base":base,"rear":rear,"owner":Deployment.new(rear,points)}

func _acknowledge(f: Dictionary, payloads: Dictionary) -> void:
	var rear: RefCounted = f.rear
	check(rear.orders.issue_order("army",COMPANY,"Support Formation","Deploy named hull","Supply-to-front support",{"vehicle_deployments":payloads},"Normal","Own HQ").ok,"Ordinary company deployment intent")
	rear.advance_time(2.1)
	check(rear.orders.relay_order(COMPANY,PLATOON).ok,"Normal actual-parent relay")
	f.owner.tick()
	check(f.owner.missions[HULL].transport_job.is_empty(),"Unacknowledged platoon intent cannot move a hull")
	rear.advance_time(2.1)

func _receipt_filters() -> void:
	var f := _fixture()
	var rear: RefCounted = f.rear
	var owner: RefCounted = f.owner
	var manifest: Dictionary = rear.dispatch.manifests[RECEIPT]
	for state in ["Requested","Transit","Unloading","Cancelled"]:
		manifest.state = state
		check(owner.payloads(COMPANY).is_empty(),"Incoming/unloading/cancelled receipt cannot become deployment: "+state)
	manifest.state = "Complete"
	manifest.mode = "Strategic Delivery"
	check(owner.payloads(COMPANY).is_empty(),"Strategic receipt does not transfer a military deployment hull")
	manifest.mode = "Fleet Transfer"
	manifest.hull = "another-hull"
	check(owner.payloads(COMPANY).is_empty(),"Receipt must map to the same exact hull")
	manifest.hull = HULL
	rear.dispatch.military_hulls[HULL] = "Initial field fleet"
	check(owner.payloads(COMPANY).is_empty(),"Starting-receipt labels are not completed manifest identities")
	rear.dispatch.military_hulls[HULL] = "unmapped-receipt"
	check(owner.payloads(COMPANY).is_empty(),"Unmapped military receipt cannot deploy")
	rear.dispatch.military_hulls[HULL] = RECEIPT
	rear.dispatch.incoming_hulls[HULL] = RECEIPT
	check(owner.payloads(COMPANY).is_empty(),"Incoming admission remains ineligible even with a contradictory completed record")
	rear.dispatch.incoming_hulls.erase(HULL)
	var hull = rear.ledger._entities[HULL]
	hull.fleet_domain = "Rear"
	check(owner.payloads(COMPANY).is_empty(),"Rear hull cannot use the deployment intent")
	hull.fleet_domain = "Military"
	hull.owner = "army-red"
	check(owner.payloads(COMPANY).is_empty(),"Foreign hull cannot use own deployment policy")
	hull.owner = rear.PLAYER
	hull.design_type = "T03"
	check(owner.payloads(COMPANY).is_empty(),"Other actual vehicle types are not C30 deployment candidates")
	hull.design_type = "T04"
	check(owner.payloads(COMPANY).has(HULL),"Completed same own T04 becomes explicitly named")
	var snapshot: Array = owner.snapshot()
	snapshot[0].state = "Changed copy"
	check(owner.missions[HULL].state != "Changed copy","Deployment report is detached")

func _command_and_readiness() -> void:
	var f := _fixture()
	var rear: RefCounted = f.rear
	var owner: RefCounted = f.owner
	var payloads: Dictionary = owner.payloads(COMPANY)
	owner.tick()
	check(rear.military.troop_transport.jobs.is_empty(),"No movement without real acknowledged command")
	var row: Dictionary = owner.missions[HULL]
	check(not owner.request(HULL,PLATOON,"unsent","blue-delivery",row.outbound,row.fallback).ok,"Unsent named intent is rejected")
	_acknowledge(f,payloads)
	var gunner = rear.ledger._entities["deployment-Gunner"]
	gunner.health = 0
	owner.tick()
	check(row.transport_job.is_empty() and row.blocker.contains("Three distinct"),"Dead gunner cannot be bypassed by driver-only movement")
	gunner.health = 100
	var qualified: String = gunner.qualification
	gunner.qualification = "None"
	owner.tick()
	check(row.transport_job.is_empty(),"Unqualified physical station cannot deploy")
	gunner.qualification = qualified
	var hull = rear.ledger._entities[HULL]
	var fuel: float = hull.fuel
	hull.fuel = 0.0
	owner.tick()
	check(row.transport_job.is_empty() and rear.ledger.inspect_entity(HULL).position == Map.BLUE_HQ,"Empty actual tank cannot move or teleport")
	hull.fuel = fuel
	var parent: String = rear.military.vehicles[HULL].parent
	rear.military.vehicles[HULL].parent = COMPANY
	owner.tick()
	check(row.transport_job.is_empty() and row.blocker.contains("parent"),"Actual parent change blocks instead of silently reparenting")
	rear.military.vehicles[HULL].parent = parent
	owner.tick()
	check(not row.transport_job.is_empty(),"Full actual crew/fuel may move toward supply with empty rack: "+str(row.blocker))
	if row.transport_job.is_empty(): return
	var count: int = rear.military.troop_transport.jobs.size()
	for _repeat in 3: owner.tick()
	check(rear.military.troop_transport.jobs.size() == count,"Repeated tick cannot duplicate an admitted transport")
	check(not owner.request(HULL,PLATOON,row.intent,row.stop,row.outbound,row.fallback).ok,"Duplicate deployment admission refused")
	var job: Dictionary = rear.military.troop_transport.jobs[row.transport_job]
	job.state = "Complete" # Deliberately inconsistent completion record.
	owner.tick()
	check(row.state == "Not at deployment stop","Completion record alone cannot assert physical arrival")
	job.state = "Outbound"
	check(rear.military.interrupt_troop_trip(row.transport_job).ok,"Existing transport owner interrupts actual route")
	owner.tick()
	check(row.state == "Paused" and rear.military.troop_transport.jobs.size() == count,"Coordinator reports interrupted job without auto-restarting")

func _route_refusals() -> void:
	var f := _fixture()
	var rear: RefCounted = f.rear
	var owner: RefCounted = f.owner
	_acknowledge(f,owner.payloads(COMPANY))
	var row: Dictionary = owner.missions[HULL]
	var hull = rear.ledger._entities[HULL]
	hull.fuel = 1.0 # Explicit insufficient-tank fault with positive Movement capability.
	owner.tick()
	check(row.transport_job.is_empty() and row.blocker.contains("25 percent reserve"),"Measured out/fallback fuel requirement rejects positive but inadequate actual tank")
	check(rear.ledger.inspect_entity(HULL).position == Map.BLUE_HQ and hull.fuel == 1.0,"Fuel refusal neither moves hull nor consumes tank")
	hull.fuel = 60.0
	rear.combat.world.obstacle("deployment-blocked-lane",Rect2(2090,500,20,20),0,10)
	owner.tick()
	check(row.transport_job.is_empty() and row.blocker.contains("route"),"New physical route blocker is retained/reported by existing route owner")
	check(rear.ledger.inspect_entity(HULL).position == Map.BLUE_HQ and hull.fuel == 60.0,"Blocked route cannot teleport or burn untravelled fuel")

func _two_physical_legs() -> void:
	var f := _fixture()
	var rear: RefCounted = f.rear
	var owner: RefCounted = f.owner
	_acknowledge(f,owner.payloads(COMPANY))
	owner.tick()
	var row: Dictionary = owner.missions[HULL]
	check(not row.transport_job.is_empty(),"Actual T04 canonical first route passes owner: "+str(row.blocker))
	if row.transport_job.is_empty(): return
	var first: String = row.transport_job
	var crew: Dictionary = rear.ledger.inspect_entity(HULL).crew_by_station.duplicate()
	var before: float = rear.ledger.inspect_entity(HULL).fuel
	rear.advance_time(float(rear.military.troop_transport.jobs[first].route_deadline)-rear.time+0.1)
	owner.tick()
	var hull: Dictionary = rear.ledger.inspect_entity(HULL)
	check(row.state == "Holding for ammunition" and hull.holder_id == "blue-delivery" and hull.position == Map.waypoints()["blue-delivery"],"Job completion and exact same-hull physical supply arrival agree")
	check(hull.fuel < before and hull.ammunition.get("E26",0) == 0,"First leg burns real fuel and does not invent E26")
	check(hull.crew_by_station == crew and rear.military.vehicles[HULL].ammo_target == {"E26":180},"Three crew identities preserved and mission owner records actual180 target")
	check(owner.payloads(COMPANY)[HULL].stop == "blue-delivery","Empty rack cannot request support leg")
	check(rear.ledger.add_stock("deployment-arrived-E26","E26",180,0.5,"blue-delivery",rear.PLAYER).ok,"Declared physically arrived E26 fixture, not manufacturing proof")
	var issued: Dictionary = rear.forward_supply.request_vehicle_rack_issue("deployment-arrived-E26",HULL,"deployment-person-0",180,"blue-delivery")
	check(issued.ok,"Existing physical courier handles matching arrived ammunition")
	if not issued.ok: return
	rear.advance_time(2.0)
	check(owner.payloads(COMPANY)[HULL].stop == "blue-delivery","Reserved/carried ammunition and active courier cannot trigger departure")
	rear.advance_time(30.0)
	check(rear.ledger.inspect_entity(HULL).ammunition.get("E26",0) == 180,"Only completed real rack handling supplies180")
	var support: Dictionary = owner.payloads(COMPANY)
	check(support[HULL].stop == "observation-central" and row.intent.is_empty(),"Actual180 and released hull request a distinct support-phase command")
	owner.tick()
	check(row.transport_job.is_empty(),"First acknowledged command cannot authorize a different leg")
	_acknowledge(f,support)
	owner.tick()
	check(not row.transport_job.is_empty() and row.transport_job != first,"Separate acknowledged support command starts distinct owner job: "+str(row.blocker))
	if row.transport_job.is_empty(): return
	var second: String = row.transport_job
	rear.advance_time(float(rear.military.troop_transport.jobs[second].route_deadline)-rear.time+0.1)
	owner.tick()
	hull = rear.ledger.inspect_entity(HULL)
	check(row.state == "Support position reached" and hull.holder_id == "observation-central" and hull.position == Vector2(2000,3000),"Actual fixed stopped support destination reached through movement owner")
	check(hull.crew_by_station == crew and hull.ammunition.get("E26",0) == 180,"Deployment consumes no ammunition and changes no crew identities")
	check(rear.vehicle_combat.events.is_empty(),"Support arrival alone is not a fabricated firing outcome")
	for stock in rear.ledger.entities_at(HULL,["STOCK"]):
		if stock.design_type == "E26" and stock.quantity > 0:
			check(rear.ledger.record_loss(stock.id,1,"Declared post-arrival fixture consumption").ok,"Real remaining rack stock can decline after arrival")
			break
	var count: int = rear.military.troop_transport.jobs.size()
	for _repeat in 3: owner.payloads(COMPANY); owner.tick()
	check(rear.military.troop_transport.jobs.size() == count and row.stop == "observation-central" and rear.ledger.inspect_entity(HULL).ammunition.get("E26",0) == 179,"Post-arrival rack decline cannot restart180 demand or duplicate deployment trips")

func _policy_discovery() -> void:
	var base: RefCounted = Session.create()
	var rear: RefCounted = base.rear
	var policy: RefCounted = rear.battlefield_operations.policy
	check(policy.snapshot().deployments.is_empty(),"Starting fleet contains no T04 deployment")
	_hull(rear,"start-blue-platoon-rifle")
	policy.tick()
	check(policy.snapshot().deployments.size() == 1,"Existing policy automatically discovers completed named transfer")
	rear.advance_time(15.0)
	var row: Dictionary = policy.deployments.missions[HULL]
	var parent: Dictionary = rear.orders.intents["start-blue-platoon-rifle"]
	check(parent.state == "Acknowledged" and parent.constraints.vehicle_deployments.has(HULL),"Existing company/attached-parent relay carries explicit named deployment")
	check(not rear.orders.intents.has(HULL),"No new hull child or command bus")
	check(not row.transport_job.is_empty(),"Policy admits same physical hull only after normal command hold/delivery: "+str(row.blocker))
	check(policy.snapshot().has_all(["phase","status","trips","resupply","deployments"]),"Existing opening snapshot keys retained with additive deployments")
