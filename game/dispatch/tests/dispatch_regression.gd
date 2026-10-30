extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
const Records = preload("res://game/identity/identity_records.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_test_passenger_duty_handoff()
	_test_a20_a21_a60()
	_test_a21_cancellation()
	_test_driver_only_fleet_transfer()
	_test_a20_exact_and_unload_cancel()
	_test_hq_berth_wait()
	_test_pre_hq_safety_return()
	_test_damage_stops_transit()
	print("G12 dispatch regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func _manufacture(base: RefCounted, recipe: String) -> String:
	var rear: RefCounted = base.rear
	var heavy: RefCounted = rear.heavy_production
	heavy.request_recipe(recipe)
	heavy.set_mode("Continuous")
	_expect(heavy.accept_order().ok,recipe+" accepted with real F10 bay claim")
	for type in Fixed.RECIPES[recipe].inputs:
		rear.ledger.add_stock("local-%s-%s-%d" % [recipe,type,heavy._order_sequence],type,Fixed.RECIPES[recipe].inputs[type],1.0,"vehicle_input",rear.PLAYER)
	rear.set_target("vehicle_works",8)
	rear.advance_time(1000)
	var id: String = heavy.bay_occupant
	_expect(not id.is_empty(),recipe+" physical output occupies F10")
	return id

func _fixture() -> Dictionary:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var hull := _manufacture(base,"R28")
	rear.add_person("g12-driver",true,"P08")
	_expect(rear.vehicles.assign_station(hull,"g12-driver","Driver").ok,"same T02 gets actual P08 Driver")
	rear.advance_time(160)
	rear.ledger.add_stock("g12-fuel","M08",12,1.0,"depot",rear.PLAYER)
	_expect(rear.vehicles.request_refuel(hull,"base-person-11",12).ok,"same T02 takes a real local M08 carry")
	rear.advance_time(200)
	_expect(rear.vehicles.start_drive(hull).ok,"same T02 clears F10 through legal F11 route")
	rear.advance_time(100)
	_expect(rear.vehicles.vehicles[hull].state == "Parked","same T02 physically parked")
	var gun := _manufacture(base,"R13")
	for index in 9: rear.add_person("g12-passenger-%02d" % index)
	for index in 8: rear.ledger.add_weapon("g12-rifle-%02d" % index,"E01",4.0,"dispatch",rear.PLAYER,"E02",30)
	rear.ledger.add_stock("g12-rounds","E02",480,0.02,"dispatch",rear.PLAYER)
	rear.set_target("dispatch",2)
	rear.advance_time(160)
	return {"base":base,"rear":rear,"hull":hull,"gun":gun}

func _passengers(count: int) -> Array[String]:
	var ids: Array[String] = []
	for index in count: ids.append("g12-passenger-%02d" % index)
	return ids

func _test_passenger_duty_handoff() -> void:
	var f := _fixture()
	var rear: RefCounted = f.rear
	var service: RefCounted = rear.dispatch
	var student := "g12-passenger-00"
	var free_person := "g12-passenger-01"
	_expect(rear.reassign_person(student,"students").ok,"actual rear person enters exclusive Training duty")
	var before: Dictionary = rear.ledger.inspect_entity(student)
	var free_before: Dictionary = rear.ledger.inspect_entity(free_person)
	var rejected: Dictionary = service.accept(f.hull,"Strategic Delivery",[free_person,student],{})
	_expect(not rejected.ok,"training student cannot be accepted as a dispatch passenger")
	_expect(service.manifests.is_empty() and service.passenger_promises.is_empty() and service.incoming_people.is_empty(),"failed admission keeps no manifest or passenger/military claims")
	_expect(rear.ledger.inspect_entity(student).assignment == "Training" and rear.ledger.inspect_entity(student).holder_id == before.holder_id and rear.ledger.inspect_entity(free_person).duty_id == free_before.duty_id and rear.ledger.inspect_entity(free_person).holder_id == free_before.holder_id,"rejected admission preserves both actual duties and holders")
	_expect(rear.reassign_person(student,"Available").ok,"student is explicitly withdrawn to Available before dispatch")
	var accepted: Dictionary = service.accept(f.hull,"Strategic Delivery",[free_person,student],{})
	_expect(accepted.ok,"same people can be accepted after lawful duty handoff")
	if not accepted.ok: return
	_expect(service.passenger_promises.size() == 2 and service.incoming_people.size() == 2 and rear.ledger.inspect_entity(student).duty_id == "passenger:"+accepted.id,"accepted manifest retains only actual reporting passengers and their claims")
	rear.advance_time(400)
	_expect(rear.ledger.inspect_entity(student).holder_id == f.hull and rear.ledger.inspect_entity(free_person).holder_id == f.hull,"both named passengers physically board the same hull")
	_expect(f.base.audit().is_empty(),"rejected admission and valid retry reconcile identities: "+str(f.base.audit()))

func _test_a20_a21_a60() -> void:
	var f := _fixture()
	var rear: RefCounted = f.rear
	var service: RefCounted = rear.dispatch
	var hull: String = f.hull
	var gun: String = f.gun
	_expect(not service.accept(hull,"Strategic Delivery",_passengers(9),{},[gun]).ok,"A60 nine passengers with gun rejected by folded-bench seats")
	_expect(service.manifests.is_empty() and rear.heavy_production.bay_occupant == gun,"rejected A60 preserves actual gun and no manifest")
	var accepted: Dictionary = service.accept(hull,"Strategic Delivery",_passengers(8),{"E01":8,"E02":480},[gun])
	_expect(accepted.ok,"A20/A60 eight passenger gun manifest accepted")
	if not accepted.ok: return
	var id: String = accepted.id
	_expect(service.incoming_people.size() == 8 and not service.incoming_people.has("g12-driver"),"Strategic crew stays rear; only eight passenger military admissions")
	_expect(service.snapshot().rows[0].requested.E02 == 480,"480 requested rounds shown separately from physical stages")
	rear.advance_time(650)
	var row: Dictionary = service.manifests[id]
	_expect(row.state == "Loaded Waiting Dispatch","all real A20 goods/passengers and A21 gun finish physical loading: "+row.state+" / "+row.blocker+" / "+str(rear.snapshot().people.filter(func(p: Dictionary) -> bool: return p.duty_id == "vehicle_works")))
	_expect(rear.ledger.inspect_entity(gun).holder_id == hull and rear.heavy_production.bay_occupant.is_empty(),"A21 same gun onboard clears F10 only after collection")
	_expect(service.snapshot().rows[0].onboard.people == 8 and service.snapshot().rows[0].onboard.E01 == 8 and service.snapshot().rows[0].onboard.E02 == 480,"A20 actual onboard 8/8/480")
	_expect(is_equal_approx(service.snapshot().rows[0].payload_used,861.6),"A20 plus field gun uses 861.6 kg actual payload")
	_expect(service.depart(id).ok,"legal A60 eight-person gun manifest departs")
	rear.advance_time(250)
	_expect(row.state in ["Arrived","Unloading","Returning","Complete"],"same hull travels bounded 1000m and 400m to HQ")
	rear.advance_time(600)
	_expect(row.state == "Complete","Strategic Delivery physically unloads and returns same hull to rear: "+row.state+" / "+row.blocker)
	_expect(service.military_people.size() == 8 and service.incoming_people.is_empty() and rear.ledger.inspect_entity("g12-driver").rear_place == "Occupied","eight distinct people join HQ; same driver comes home")
	_expect(rear.ledger.inspect_entity("hq-stock").contents_mass_kg >= 221.6,"actual rifles/rounds/field gun reach HQ stock after handling")
	_expect(f.base.audit().is_empty(),"A20/A60 conservation and shared audit: "+str(f.base.audit()))

func _test_a21_cancellation() -> void:
	var f := _fixture()
	var rear: RefCounted = f.rear
	var service: RefCounted = rear.dispatch
	var accepted: Dictionary = service.accept(f.hull,"Strategic Delivery",[],{},[f.gun])
	_expect(accepted.ok,"A21 gun-only manifest accepted on same manufactured T02")
	if not accepted.ok: return
	rear.advance_time(500)
	var row: Dictionary = service.manifests[accepted.id]
	_expect(row.state == "Loaded Waiting Dispatch" and rear.ledger.inspect_entity(f.gun).holder_id == f.hull,"A21 direct F10 gun actually aboard before cancellation")
	_expect(service.cancel(accepted.id).ok,"predeparture cancellation withdraws only this manifest's claims")
	_expect(not service.cancel(accepted.id).ok,"repeat cancellation cannot release claims twice")
	_expect(rear.ledger.inspect_entity(f.gun).holder_id == f.hull,"cancellation does not teleport gun out of occupied hull")
	rear.advance_time(500)
	_expect(row.state == "Cancelled" and rear.ledger.inspect_entity(f.gun).holder_id == "heavy-bay" and rear.heavy_production.bay_occupant == f.gun,"two-loader gun return and same hull parking finish physically: "+row.state+" / "+row.blocker)
	_expect(rear.vehicles.vehicles[f.hull].state == "Parked" and service.incoming_people.is_empty() and service.incoming_hulls.is_empty(),"cancelled hull and crew remain rear with no phantom commitments")
	_expect(f.base.audit().is_empty(),"A21 cancellation audit: "+str(f.base.audit()))

func _test_driver_only_fleet_transfer() -> void:
	var f := _fixture()
	var rear: RefCounted = f.rear
	var service: RefCounted = rear.dispatch
	var accepted: Dictionary = service.accept(f.hull,"Fleet Transfer",[],{})
	_expect(accepted.ok,"valid empty Fleet Transfer needs only same real driver/hull")
	if not accepted.ok: return
	_expect(service.incoming_hulls.has(f.hull) and service.incoming_people.size() == 1 and service.incoming_people.has("g12-driver"),"driver-only transfer claims one hull and one actual P08")
	rear.advance_time(160)
	_expect(service.manifests[accepted.id].state == "Loaded Waiting Dispatch","empty transfer may become loaded waiting dispatch")
	_expect(service.depart(accepted.id).ok,"driver-only Fleet Transfer departs with fuel and real route")
	_expect(rear.ledger.rear_fleet_hulls(rear.PLAYER).has(f.hull),"rear fleet 8 remains held after departure")
	rear.advance_time(300)
	_expect(service.manifests[accepted.id].state == "Complete","actual HQ berth finishes driver-only transfer")
	_expect(rear.ledger.inspect_entity(f.hull).fleet_domain == "Military" and rear.ledger.inspect_entity("g12-driver").holder_id == f.hull,"same hull and seated driver transfer physically at HQ")
	_expect(not rear.ledger.rear_fleet_hulls(rear.PLAYER).has(f.hull) and service.military_hulls.has(f.hull) and service.military_people.has("g12-driver") and service.incoming_hulls.is_empty() and service.incoming_people.is_empty(),"HQ receipt converts hull/crew claims exactly once")
	_expect(f.base.audit().is_empty(),"driver-only Fleet Transfer audit: "+str(f.base.audit()))

func _test_a20_exact_and_unload_cancel() -> void:
	var f := _fixture()
	var rear: RefCounted = f.rear
	var service: RefCounted = rear.dispatch
	var accepted: Dictionary = service.accept(f.hull,"Strategic Delivery",_passengers(8),{"E01":8,"E02":480})
	_expect(accepted.ok,"A20 exact cargo/passenger manifest accepted without field gun")
	if not accepted.ok: return
	var id: String = accepted.id
	_expect(is_equal_approx(service._manifest_payload(service.manifests[id]),681.6),"A20 exact eight people/rifles/480 rounds is 681.6 kg")
	_expect(service.change_mode(id,"Fleet Transfer").ok and service.incoming_hulls.has(f.hull) and service.incoming_people.size() == 9,"mode edit adds same real driver and hull incoming claims")
	_expect(service.change_mode(id,"Strategic Delivery").ok and service.incoming_hulls.is_empty() and service.incoming_people.size() == 8,"mode edit returns exact crew/hull claims before departure")
	rear.advance_time(500)
	var row: Dictionary = service.manifests[id]
	_expect(row.state == "Loaded Waiting Dispatch" and service.snapshot().rows[0].onboard.E01 == 8 and service.snapshot().rows[0].onboard.E02 == 480,"A20 actual load ready before cancellation")
	_expect(service.cancel(id).ok,"predeparture A20 cancellation withdraws eight military admissions")
	_expect(rear.ledger.inspect_entity("g12-passenger-00").holder_id == f.hull,"one-second exits remain physical after cancellation request")
	rear.advance_time(500)
	_expect(row.state == "Cancelled" and rear.vehicles.vehicles[f.hull].state == "Parked","A20 real unboarding/unloading and same-hull parking finish: "+row.state+" / "+row.blocker)
	_expect(service.incoming_people.is_empty() and service.incoming_hulls.is_empty(),"cancelled A20 commitments released once")
	_expect(rear.ledger.inspect_entity("g12-passenger-00").assignment == "Available" and rear.ledger.inspect_entity("g12-passenger-00").rear_place == "Occupied","same passenger physically unboarded into rear")
	_expect(rear.ledger.available_stock_at("dispatch","E02") == 480,"all 480 physical rounds returned to dispatch storage")
	_expect(f.base.audit().is_empty(),"A20 cancellation audit: "+str(f.base.audit()))

func _test_hq_berth_wait() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var service: RefCounted = rear.dispatch
	for index in 96:
		var person_id := "g12-prior-reserve-%02d" % index
		_expect(rear.ledger.add_person(person_id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,false,"None","None").ok,"prior HQ reserve fixture uses real person identity")
		service.hq_reserve[person_id] = "Occupied"
		service.military_people[person_id] = "prior-hq"
	rear.set_target("dispatch",2)
	rear.advance_time(160)
	var manifests: Array[String] = []
	for index in 3:
		var hull := _manufacture(base,"R28")
		var driver := "g12-berth-driver-%d" % index
		rear.add_person(driver,true,"P08")
		_expect(rear.vehicles.assign_station(hull,driver,"Driver").ok,"berth fixture's real P08 boards produced hull")
		rear.advance_time(160)
		rear.ledger.add_stock("g12-berth-fuel-%d" % index,"M08",12,1.0,"depot",rear.PLAYER)
		var fuel_worker := "g12-berth-fuel-worker-%d" % index
		rear.add_person(fuel_worker)
		_expect(rear.vehicles.request_refuel(hull,fuel_worker,12).ok,"berth fixture fuels same actual hull")
		rear.advance_time(200)
		var drive: Dictionary = rear.vehicles.start_drive(hull)
		_expect(drive.ok,"berth fixture drives same produced hull from F10 to F11: "+drive.message)
		rear.advance_time(100)
		var passenger := "g12-berth-passenger-%d" % index
		rear.add_person(passenger)
		var accepted: Dictionary = service.accept(hull,"Fleet Transfer",[passenger],{})
		_expect(accepted.ok,"one passenger is committed on each distinct produced hull")
		if not accepted.ok: continue
		manifests.append(accepted.id)
		rear.advance_time(180)
		_expect(service.manifests[accepted.id].state == "Loaded Waiting Dispatch","berth fixture passenger physically boarded")
		_expect(service.depart(accepted.id).ok,"each distinct loaded hull starts a real HQ trip")
		rear.advance_time(300)
	rear.advance_time(300)
	_expect(service._hq_berth_count() == 2,"only two real HQ berth claims occupied")
	if manifests.size() == 3:
		var third: Dictionary = service.manifests[manifests[2]]
		_expect(third.state == "Waiting HQ Berth" and rear.ledger.inspect_entity(third.hull).holder_id == "hq-queue" and third.arrived.is_empty(),"third same hull waits outside full HQ receiving berth without false arrival")
	_expect(base.audit().is_empty(),"two occupied and one safely waiting HQ berth audit: "+str(base.audit()))

func _test_pre_hq_safety_return() -> void:
	var full := _fixture()
	var rear: RefCounted = full.rear
	var service: RefCounted = rear.dispatch
	var accepted: Dictionary = service.accept(full.hull,"Fleet Transfer",[],{})
	_expect(accepted.ok,"safety return fixture accepts real Fleet Transfer hull and driver")
	if not accepted.ok: return
	rear.advance_time(160)
	_expect(service.depart(accepted.id).ok,"same Fleet Transfer departs before safety return")
	rear.advance_time(30)
	_expect(service.manifests[accepted.id].state == "Transit" and rear.ledger.inspect_entity("g12-driver").rear_place == "None","actual rear exit releases nonreturning driver place, keeping incoming military claim")
	_fill_rear_to(rear,120,"g12-full-rear")
	_expect(not service.request_safe_return(accepted.id).ok and service.incoming_hulls.has(full.hull) and service.incoming_people.has("g12-driver"),"full rear refuses pre-HQ readmission without withdrawing the physical trip or military claims")
	var home := _fixture()
	var home_rear: RefCounted = home.rear
	var home_service: RefCounted = home_rear.dispatch
	var home_accepted: Dictionary = home_service.accept(home.hull,"Fleet Transfer",[],{})
	_expect(home_accepted.ok,"separate actual Fleet Transfer ready for lawful safety return")
	if not home_accepted.ok: return
	home_rear.advance_time(160)
	_expect(home_service.depart(home_accepted.id).ok,"same hull starts irreversible outbound trip")
	home_rear.advance_time(30)
	_expect(home_service.request_safe_return(home_accepted.id).ok,"pre-HQ return reserves real rear readmission for the driver")
	_expect(home_service.return_places.has("g12-driver") and home_service.incoming_hulls.has(home.hull),"outside return retains incoming military/hull claims until actual rear entry")
	_fill_rear_to(home_rear,112,"g12-return-home")
	_expect(not home.base.receiving.buy_people().ok,"supplier cannot consume the eight-place gap reserved for the returning actual driver")
	home_rear.advance_time(300)
	_expect(home_service.manifests[home_accepted.id].state == "Safety Returned" and home_rear.vehicles.vehicles[home.hull].state == "Parked","same Fleet hull physically readmitted and parked after return")
	_expect(not home_service.incoming_people.has("g12-driver") and home_service.incoming_hulls.is_empty() and home_service.return_places.is_empty() and home_rear.ledger.inspect_entity("g12-driver").rear_place == "Occupied","real rear arrival withdraws each outstanding admission exactly once")
	_expect(home.base.audit().is_empty(),"safety return conservation and shared audit: "+str(home.base.audit()))

func _test_damage_stops_transit() -> void:
	var f := _fixture()
	var rear: RefCounted = f.rear
	var service: RefCounted = rear.dispatch
	var accepted: Dictionary = service.accept(f.hull,"Fleet Transfer",[],{})
	_expect(accepted.ok,"damage fixture accepts a real driver and hull")
	if not accepted.ok: return
	rear.advance_time(160)
	_expect(service.depart(accepted.id).ok,"damage fixture leaves F07")
	rear.advance_time(30)
	_expect(service.manifests[accepted.id].state == "Transit","hull is physically in transit before damage")
	_expect(rear.ledger.add_stock("g12-damage-cargo","E02",3,0.02,f.hull,rear.PLAYER).ok,"three actual rounds are aboard damaged hull")
	var before: Dictionary = rear.ledger.inspect_entity(f.hull)
	var distance: float = service.manifests[accepted.id].distance
	var hit: Dictionary = rear.ledger.apply_vehicle_surface_damage(f.hull,int(ceil(float(before.max_health)*0.8)),1,"Side","Transit interruption regression")
	_expect(hit.ok and hit.health > 0 and rear.ledger.inspect_entity(f.hull).damage_immobilized,"penetrating hit leaves the hull alive but immobile")
	rear.advance_time(10)
	var after: Dictionary = rear.ledger.inspect_entity(f.hull)
	_expect(service.manifests[accepted.id].state == "Stranded" and service.manifests[accepted.id].distance == distance,"newly immobilized hull stops before another route segment")
	_expect(after.position.is_equal_approx(before.position) and is_equal_approx(float(after.fuel),float(before.fuel)),"no movement or fuel burn follows pre-existing damage")
	_expect(rear.ledger.inspect_entity("g12-damage-cargo").holder_id == f.hull,"same real rounds remain aboard stranded hull")
	_expect(f.base.audit().is_empty(),"stranded dispatch identities and stock reconcile: "+str(f.base.audit()))

func _fill_rear_to(rear: RefCounted, target: int, prefix: String) -> void:
	var missing: int = target-rear.receiving.rear_population()-rear.receiving.incoming_people()
	for index in missing:
		var id := "%s-%03d" % [prefix,index]
		_expect(rear.ledger.add_person(id,"duty-personnel",rear.PLAYER).ok,"real physical rear capacity fixture person added")
		rear.actors[id] = {"id":id,"phase":"Available","deadline":INF,"motion":{},"load":{},"blocked_since":-1.0}
	rear._settle()
