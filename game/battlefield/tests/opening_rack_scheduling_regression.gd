extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
const Resupply = preload("res://game/battlefield/opening_resupply.gd")
const AT := Vector2(2000,500)
var checks := 0
var failures := 0

func _initialize() -> void:
	_initial_need()
	_interrupted_and_consumed()
	_partial_allocation()
	_known_fire()
	print("Opening rack scheduling: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func fixture() -> Dictionary:
	var base := Base.new(false,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	check(ledger.add_place("blue-delivery","Actual local E26 stop",AT).ok,"real stop")
	check(rear.forward_supply.register_delivery_stop("blue-delivery").ok,"declared delivery boundary")
	var ids: Array[String] = []
	for index in 4:
		var id := "rack-engineer-%d" % index
		check(ledger.add_person(id,"blue-delivery",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02" if index < 2 else "None","None").ok,"actual Engineer member")
		check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"retained real rifle")
		check(ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"retained personal rounds")
		if index < 2: check(ledger.add_stock(id+"-tools","E08",1,6,id,rear.PLAYER).ok,"actual Engineer tool load")
		ids.append(id)
	check(rear.military.add_initial_squad("rack-engineers","Engineer",ids,"rack-company","rack-platoon",rear.PLAYER).ok,"real Engineer hierarchy")
	for hull_id in ["rack-new","rack-starting"]:
		check(ledger.add_initial_vehicle(hull_id,"T04","blue-delivery",rear.PLAYER,Specs.TYPES.T04,80,"Military").ok,"real local hull "+hull_id)
		for station in Specs.TYPES.T04.stations:
			if hull_id == "rack-starting" and station != "Driver": continue
			var id: String = hull_id+"-"+str(station)
			check(ledger.add_person(id,"blue-delivery",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok,"distinct qualified crew")
			check(ledger.assign_initial_vehicle_crew(id,hull_id,station).ok,"actual occupied station")
		check(rear.military.attach_initial_vehicle(hull_id,"rack-platoon").ok,"actual attached hull")
		check(rear.military.set_vehicle_mission(hull_id,{"E26":180},0).ok,"unchanged real rack mission")
	check(ledger.add_stock("starting-e26","E26",180,0.5,"rack-starting",rear.PLAYER).ok,"existing full rack cannot mask empty hull")
	check(ledger.move_entity("rack-new","blue-delivery",AT+Vector2(5,0)).ok,"new hull stops five metres from freight")
	rear.battlefield_operations = Execution.new(rear)
	var policy := Resupply.new(rear,[],"rack-engineers","blue-delivery")
	return {"base":base,"rear":rear,"ledger":ledger,"policy":policy,"ids":ids}

func _initial_need() -> void:
	var f := fixture()
	f.policy.tick()
	check(f.policy.rack_requests.has("rack-new") and not f.policy.rack_requests.has("rack-starting"),"only actually empty first-seen rack latches initial demand")
	check(f.ledger.record_consumption("starting-e26",180,"Declared prior use in latch regression").ok,"existing full rack can later empty through real consumption")
	f.policy.tick()
	check(not f.policy.rack_requests.has("rack-starting"),"a previously full starting hull never gains artificial initial demand later")
	check(f.rear.forward_supply.rack_issue.jobs.is_empty() and f.ledger.inspect_entity("rack-new").ammunition.get("E26",0) == 0,"no local freight never refills the new hull")
	check(f.ledger.add_stock("rack-wrong","E02",200,0.02,"blue-delivery",f.rear.PLAYER).ok,"wrong-type local stock")
	check(f.ledger.add_stock("rack-foreign","E26",200,0.5,"blue-delivery","army-red").ok,"foreign local stock")
	check(f.ledger.add_stock("rack-remote","E26",200,0.5,"hq-stock",f.rear.PLAYER).ok,"remote stock")
	check(f.ledger.add_stock("rack-reserved","E26",180,0.5,"blue-delivery",f.rear.PLAYER).ok,"real reserved local stack")
	check(f.ledger.request_stock("rack-competing","rack-reserved",180,"other","Competing actual demand",f.rear.PLAYER).ok,"another owner reserves freight")
	f.policy.tick()
	check(f.rear.forward_supply.rack_issue.jobs.is_empty(),"wrong, foreign, remote and reserved ammunition cannot satisfy need")
	for id in f.ids: check(f.ledger.move_entity(id,"blue-delivery",AT+Vector2(0,21)).ok,"courier actually leaves local radius")
	check(f.ledger.release_claim("rack-competing").ok,"actual stock becomes available")
	f.policy.tick()
	check(f.rear.forward_supply.rack_issue.jobs.is_empty(),"seated crew and remote Engineers cannot act as local couriers")
	check(f.ledger.move_entity(f.ids[0],"blue-delivery",AT).ok,"same Engineer returns locally")
	check(f.ledger.move_entity(f.ids[1],"blue-delivery",AT).ok,"actual personal issue recipient returns locally")
	var personal: Dictionary = f.rear.forward_supply.start_issue("rack-wrong",f.ids[1],f.ids[0],1,"blue-delivery")
	check(personal.ok,"real competing personal issue owns both local Engineers")
	f.policy.tick()
	check(f.rear.forward_supply.rack_issue.jobs.is_empty(),"busy handler and recipient cannot also courier rack rounds")
	if personal.ok: check(f.rear.forward_supply.interrupt(personal.id).ok,"actual competing task releases local people before pickup")
	f.policy.tick()
	check(f.rear.forward_supply.rack_issue.jobs.size() == 1,"one actual Engineer owns serial rack handling")
	if f.rear.forward_supply.rack_issue.jobs.is_empty(): return
	var row: Dictionary = f.rear.forward_supply.rack_issue.jobs.values()[0]
	check(row.hull == "rack-new" and row.quantity == 180 and row.handler == f.ids[0],"initial request reserves exact deficit from the real stack")
	f.policy.tick()
	check(f.rear.forward_supply.rack_issue.jobs.size() == 1,"repeated scheduling does not duplicate the reservation")
	var view: Dictionary = f.policy.snapshot()
	check(view.rack_requests.size() == 1 and view.rack_requests[0].needed == 180 and view.rack_requests[0].committed == 180 and view.available_E26 == 0,"additive view distinguishes needed, committed and available freight")
	check(view.has("requests") and view.has("available_E02") and view.has("status") and view.has("engineer_squad"),"original Rifle view keys remain")

func _interrupted_and_consumed() -> void:
	var f := fixture()
	check(f.ledger.add_stock("rack-arrived","E26",180,0.5,"blue-delivery",f.rear.PLAYER).ok,"declared already-arrived physical regression freight")
	f.rear.battlefield_operations.policy = f.policy
	var job: Dictionary = {}
	for step in 30:
		f.rear.advance_time(0.5)
		for row in f.rear.forward_supply.rack_issue.jobs.values():
			if not str(row.carry).is_empty(): job = row
		if not job.is_empty(): break
	check(not job.is_empty(),"actual timed pickup precedes interruption")
	if job.is_empty(): return
	var portion: String = job.carry
	check(f.ledger.move_entity("rack-new","blue-delivery",AT+Vector2(25,0)).ok,"same hull actually leaves the local stop")
	f.rear.advance_time(2)
	check(job.state == "Interrupted Carry" and f.ledger.inspect_entity(portion).holder_id == job.handler,"same carried portion remains with Engineer after interruption")
	check(f.rear.forward_supply.rack_issue.jobs.size() == 1 and f.ledger.inspect_claim(job.claim).reserved == 0,"interruption releases unpicked claim without duplicate issue")
	check(f.ledger.move_entity("rack-new","blue-delivery",AT+Vector2(5,0)).ok,"same hull returns to local receipt")
	f.rear.advance_time(240)
	check(job.state == "Complete" and job.issued == 180 and f.rear.forward_supply.rack_issue.jobs.size() == 1,"same job resumes real serial portions to complete initial allocation")
	check(f.ledger.inspect_entity("rack-new").ammunition.get("E26",0) == 180 and f.ledger.inspect_entity("rack-arrived").quantity == 0,"all 180 actual rounds reach the new rack")
	check(f.policy.rack_requests.is_empty(),"initial completed target clears its request")
	check(f.ledger.add_place("rack-hostile","Actual hostile contact",AT+Vector2(105,0)).ok,"real hostile place")
	check(f.ledger.add_person("rack-enemy","rack-hostile","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"actual enemy person")
	check(f.rear.orders.watch("rack-engineers").ok,"actual Engineer observations reach hull parent")
	f.rear.advance_time(15)
	var fired := false
	for event in f.ledger.snapshot().events:
		if str(event.description).contains("Mounted Autocannon fired from rack-new"):
			fired = true
			check(f.ledger.inspect_entity(event.entity_id).origin_id == "rack-arrived","autonomous shot consumes the arrived physical lineage")
	check(fired,"autonomous mounted fire waits for delivered rounds and actual contact")
	check(f.policy.rack_requests.is_empty() and f.rear.forward_supply.rack_issue.jobs.size() == 1,"firing never re-latches per-shot initial supply demand")
	check(f.base.audit().is_empty(),"rack scheduling preserves physical conservation and duties")

func _partial_allocation() -> void:
	var f := fixture()
	check(f.ledger.add_stock("rack-first","E26",60,0.5,"blue-delivery",f.rear.PLAYER).ok,"actual first partial arrived stack")
	f.rear.battlefield_operations.policy = f.policy
	f.rear.advance_time(90)
	check(f.ledger.inspect_entity("rack-new").ammunition.get("E26",0) == 60,"only the first actual stack can be deposited")
	for stock in f.ledger.entities_at("rack-new",["STOCK"]):
		if stock.design_type == "E26" and stock.quantity >= 5:
			check(f.ledger.record_consumption(stock.id,5,"Declared prior consumption in partial allocation regression").ok,"actual deposited rounds can be consumed before next arrival")
			break
	check(f.ledger.add_stock("rack-second","E26",150,0.5,"blue-delivery",f.rear.PLAYER).ok,"actual second partial arrived stack")
	f.policy.tick()
	var jobs: Array = f.rear.forward_supply.rack_issue.jobs.values()
	check(jobs.size() == 2 and jobs[-1].quantity == 120,"remaining initial allocation excludes replacement of earlier consumed rounds")
	f.rear.advance_time(180)
	check(f.policy.rack_requests.is_empty() and f.ledger.inspect_entity("rack-new").ammunition.get("E26",0) == 175,"exactly 180 initial rounds supplied despite five already consumed")
	check(f.ledger.inspect_entity("rack-second").quantity == 30,"unused second-stack rounds remain physically at the stop")
	check(f.base.audit().is_empty(),"partial allocation conserves both actual stacks and consumption")

func _known_fire() -> void:
	var f := fixture()
	check(f.ledger.add_stock("rack-arrived","E26",180,0.5,"blue-delivery",f.rear.PLAYER).ok,"actual safe-stop stock")
	check(f.ledger.add_place("rack-hostile","Actual observed threat",AT+Vector2(175,0)).ok,"real nearby threat")
	check(f.ledger.add_person("rack-enemy","rack-hostile","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"actual observed enemy")
	check(f.rear.orders.watch("rack-engineers").ok,"actual safety observer")
	f.rear.advance_time(0.5)
	check(not f.rear.orders.contact("rack-engineers","rack-enemy").is_empty(),"actual contact delivered before admission")
	f.policy.tick()
	check(f.rear.forward_supply.rack_issue.jobs.is_empty(),"delivered effective fire prevents local rack issue")
