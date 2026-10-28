extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
const Records = preload("res://game/identity/identity_records.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_test_a24_and_local_handoff()
	_test_person_and_cancellation()
	_test_carried_cancel_returns_to_hq()
	_test_automatic_hq_command()
	_test_real_dispatch_receipt_auto_issue()
	print("G14 HQ regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _tank(base: RefCounted) -> String:
	var ledger: RefCounted = base.rear.ledger
	_expect(ledger.reserve_rear_hull("g14-admission",base.rear.PLAYER,"g14-fixture").ok,"fleet admission")
	_expect(ledger.create_heavy_output("g14-admission","g14-fixture","g14-tank","T05","heavy-bay",base.rear.PLAYER,Specs.TYPES.T05).ok,"actual T05 hull")
	_expect(ledger.move_entity("g14-tank","hq-berth",Vector2(1640,91)).ok,"same hull reaches HQ berth")
	_expect(ledger.complete_hq_hull_receipt("g14-tank").ok,"same fleet hull has military identity")
	_expect(ledger.move_entity("g14-tank","field-entry",Vector2(3640,91)).ok,"same military hull physically two kilometres away")
	return "g14-tank"

func _test_a24_and_local_handoff() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var tank := _tank(base)
	_expect(ledger.add_stock("g14-shells","E25",10,10.0,"hq-stock",rear.PLAYER).ok,"ten unloaded shells at HQ stock")
	_expect(ledger.add_stock("g14-arrived-shell","E25",1,10.0,"hq-berth",rear.PLAYER).ok,"one arrived shell still awaits HQ unload")
	_expect(ledger.add_stock("g14-foreign-shell","E25",2,10.0,"hq-stock","foreign-army").ok,"foreign stock can occupy physical HQ mass without becoming owned issue stock")
	_expect(rear.hq.snapshot().available.E25 == 10,"arrived but not unloaded shell is excluded from usable local stock")
	_expect(ledger.add_stock("g14-fuel","M08",12,1.0,"hq-stock",rear.PLAYER).ok,"unloaded fuel at HQ stock")
	_expect(not rear.hq.request_vehicle_ammo(tank,"E25",2).ok,"A24 remote T05 cannot request HQ rack issue")
	_expect(not rear.hq.request_vehicle_fuel(tank,4).ok,"remote T05 cannot request HQ tank issue")
	_expect(ledger.inspect_entity(tank).ammunition.get("E25",0) == 0 and ledger.inspect_entity(tank).fuel == 0.0,"A24 same tank remains empty despite unloaded HQ shells/fuel")
	_expect(ledger.move_entity(tank,"hq-berth",Vector2(1640,91)).ok,"same tank physically reaches HQ")
	_expect(not rear.hq.request_vehicle_ammo(tank,"E25",11).ok,"arrived shell cannot satisfy rack issue before unloading")
	_expect(ledger.transfer_stock("g14-arrived-shell",1,"hq-stock").ok,"completed local HQ unload creates usable stock portion")
	_expect(rear.hq.snapshot().available.E25 == 11,"only after unload does shell become eligible HQ stock")
	var accepted: Dictionary = rear.hq.request_vehicle_ammo(tank,"E25",2)
	_expect(accepted.ok,"HQ reserves two actual unloaded shells")
	if not accepted.ok: return
	_expect(ledger.inspect_entity(tank).ammunition.get("E25",0) == 0 and rear.hq.snapshot().reserved.E25 == 2,"reservation does not refill rack")
	rear.advance_time(2)
	_expect(ledger.inspect_entity(tank).ammunition.get("E25",0) == 0,"pickup carry does not refill rack")
	rear.advance_time(2)
	_expect(ledger.inspect_entity(tank).ammunition.E25 == 2 and rear.hq.jobs[accepted.id].state == "Complete","timed local handoff fills exact two shells once")
	var fuel: Dictionary = rear.hq.request_vehicle_fuel(tank,4)
	_expect(fuel.ok,"four unloaded M08 reserved")
	rear.advance_time(4)
	_expect(ledger.inspect_entity(tank).fuel == 4.0 and rear.hq.jobs[fuel.id].state == "Complete","actual HQ carry fills only four tank units")
	var second: Dictionary = rear.hq.request_vehicle_ammo(tank,"E25",3)
	_expect(second.ok,"three more shells reserved across multiple 25 kg carries")
	rear.advance_time(4)
	_expect(ledger.inspect_entity(tank).ammunition.E25 == 4,"first two of three shells fit one ordinary carry")
	rear.advance_time(4)
	_expect(ledger.inspect_entity(tank).ammunition.E25 == 5 and rear.hq.jobs[second.id].state == "Complete","second carry loads final whole shell once")
	_expect(base.audit().is_empty(),"A24 exact physical conservation: "+str(base.audit()))

func _test_person_and_cancellation() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	_expect(ledger.add_person("g14-recipient","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true).ok,"actual HQ Reserve person")
	_expect(ledger.add_stock("g14-rounds","E02",100,0.02,"hq-stock",rear.PLAYER).ok,"actual HQ rounds")
	_expect(ledger.add_weapon("g14-rifle","E01",4.0,"hq-stock",rear.PLAYER,"E02",30).ok,"unloaded intact HQ rifle")
	var stock: Dictionary = rear.hq.request_person_stock("g14-recipient","E02",20)
	_expect(stock.ok,"person stock reservation")
	_expect(ledger.inspect_entity("g14-recipient").contents_mass_kg == 0.0,"reservation is not issued holding")
	rear.advance_time(7.5)
	_expect(ledger.inspect_entity("g14-recipient").contents_mass_kg == 0.0,"walk to HQ stock is not issued holding")
	rear.advance_time(4)
	_expect(ledger.inspect_entity("g14-recipient").contents_mass_kg > 0.0,"actual local transfer changes person holding")
	rear.advance_time(8)
	_expect(rear.hq.jobs[stock.id].state == "Complete" and ledger.inspect_entity("g14-recipient").holder_id == "hq-reserve","issued person returns to HQ Reserve")
	var weapon: Dictionary = rear.hq.request_person_weapon("g14-recipient","g14-rifle")
	_expect(weapon.ok,"unloaded intact weapon promised")
	rear.advance_time(20)
	_expect(ledger.inspect_entity("g14-rifle").holder_id == "g14-recipient" and rear.hq.jobs[weapon.id].state == "Complete","same intact weapon actually issued")
	var cancelled: Dictionary = rear.hq.request_person_stock("g14-recipient","E02",10)
	_expect(cancelled.ok and rear.hq.cancel(cancelled.id).ok,"unstarted person issue cancelled")
	_expect(rear.hq.jobs[cancelled.id].state == "Cancelled" and rear.hq.snapshot().reserved.get("E02",0) == 0,"cancellation releases only own claim")
	_expect(base.audit().is_empty(),"person issue ledger remains conserved: "+str(base.audit()))

func _test_carried_cancel_returns_to_hq() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var tank := _tank(base)
	_expect(rear.ledger.move_entity(tank,"hq-berth",Vector2(1640,91)).ok,"same military tank locally parked")
	_expect(rear.ledger.add_stock("g14-cancel-shells","E25",3,10.0,"hq-stock",rear.PLAYER).ok,"three unloaded shells")
	var job: Dictionary = rear.hq.request_vehicle_ammo(tank,"E25",2)
	_expect(job.ok,"two local shells reserved")
	rear.advance_time(2)
	_expect(rear.ledger.inspect_entity(tank).ammunition.get("E25",0) == 0,"actual handler carry has not filled rack")
	_expect(rear.hq.cancel(job.id).ok,"cancel active named carry")
	rear.advance_time(2)
	_expect(rear.hq.jobs[job.id].state == "Cancelled" and rear.hq.snapshot().available.E25 == 3,"carried shells returned to HQ stock, claim released")
	_expect(rear.ledger.inspect_entity(tank).ammunition.get("E25",0) == 0,"cancelled carry never refills tank")
	_expect(base.audit().is_empty(),"cancelled actual carry remains conserved: "+str(base.audit()))

func _test_automatic_hq_command() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var tank := _tank(base)
	_expect(ledger.move_entity(tank,"hq-berth",Vector2(1640,91)).ok,"admitted same T05 stops at HQ")
	rear.dispatch.military_hulls[tank] = "g14-receipt"
	_expect(ledger.add_stock("g14-auto-shells","E25",3,10.0,"hq-stock",rear.PLAYER).ok,"HQ has three actual shells")
	_expect(ledger.add_stock("g14-auto-fuel","M08",5,1.0,"hq-stock",rear.PLAYER).ok,"HQ has five actual fuel units")
	_expect(ledger.add_person("g14-auto-trained","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true).ok,"trained generic military reserve")
	_expect(ledger.add_person("g14-auto-untrained","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,false).ok,"untrained reserve must not receive a generic rifle package")
	rear.dispatch.hq_reserve["g14-auto-trained"] = "Occupied"
	rear.dispatch.hq_reserve["g14-auto-untrained"] = "Occupied"
	rear.dispatch.military_people["g14-auto-trained"] = "g14-receipt"
	rear.dispatch.military_people["g14-auto-untrained"] = "g14-receipt"
	_expect(ledger.add_weapon("g14-auto-rifle","E01",4.0,"hq-stock",rear.PLAYER,"E02",30).ok,"one unloaded rifle")
	_expect(ledger.add_stock("g14-auto-rounds","E02",930,0.02,"hq-stock",rear.PLAYER).ok,"hull target plus thirty unloaded matching personal rounds")
	rear.advance_time(0)
	_expect(ledger.inspect_entity(tank).ammunition.get("E25",0) == 0 and ledger.inspect_entity(tank).fuel == 0.0,"automatic HQ choice first reserves, never instantly fills")
	_expect(rear.hq.jobs.values()[0].automatic and rear.hq.jobs.values()[0].kind == "Vehicle Ammo","command prioritizes admitted stopped hull matching rack")
	rear.advance_time(60)
	_expect(ledger.inspect_entity(tank).ammunition.E25 == 3 and ledger.inspect_entity(tank).fuel == 5.0,"automatic hull rounds/fuel use real timed local carries")
	_expect(ledger.inspect_entity("g14-auto-rifle").holder_id == "g14-auto-trained","HQ command selects eligible trained generic recipient automatically: "+str(rear.hq.snapshot().rows)+" / "+str(rear.hq.auto_status))
	_expect(rear.hq._held_rounds(rear,"g14-auto-trained") == 30,"same recipient receives minimum thirty compatible rounds: "+str(rear.hq.snapshot().rows))
	_expect(ledger.inspect_entity("g14-auto-untrained").contents_mass_kg == 0.0,"untrained person receives no unsolicited package")
	_expect(rear.hq.snapshot().reserved.get("E25",0) == 0 and rear.hq.snapshot().reserved.get("E02",0) == 0,"all automatic promises resolve against physical stock")
	_expect(base.audit().is_empty(),"automatic HQ issue conserves identities and quantities: "+str(base.audit()))

func _test_real_dispatch_receipt_auto_issue() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var heavy: RefCounted = rear.heavy_production
	heavy.request_recipe("R28")
	heavy.set_mode("Continuous")
	_expect(heavy.accept_order().ok,"real T02 production accepted")
	for type in Fixed.RECIPES.R28.inputs:
		rear.ledger.add_stock("g14-real-input-"+type,type,Fixed.RECIPES.R28.inputs[type],1.0,"vehicle_input",rear.PLAYER)
	rear.set_target("vehicle_works",8)
	rear.advance_time(1000)
	var hull: String = heavy.bay_occupant
	_expect(not hull.is_empty(),"real T02 output exists at F10")
	if hull.is_empty(): return
	rear.add_person("g14-real-driver",true,"P08")
	_expect(rear.vehicles.assign_station(hull,"g14-real-driver","Driver").ok,"qualified real driver assigned")
	rear.advance_time(160)
	rear.ledger.add_stock("g14-real-fuel","M08",12,1.0,"depot",rear.PLAYER)
	_expect(rear.vehicles.request_refuel(hull,"base-person-11",12).ok,"real T02 receives rear fuel")
	rear.advance_time(200)
	_expect(rear.vehicles.start_drive(hull).ok,"real T02 drives to F11")
	rear.advance_time(100)
	rear.add_person("g14-real-recruit",true)
	rear.ledger.add_weapon("g14-real-rifle","E01",4.0,"dispatch",rear.PLAYER,"E02",30)
	rear.ledger.add_stock("g14-real-rounds","E02",30,0.02,"dispatch",rear.PLAYER)
	rear.set_target("dispatch",2)
	rear.advance_time(160)
	var manifest: Dictionary = rear.dispatch.accept(hull,"Strategic Delivery",["g14-real-recruit"],{"E01":1,"E02":30})
	_expect(manifest.ok,"real trained recruit and matching rifle/rounds committed")
	if not manifest.ok: return
	rear.advance_time(650)
	_expect(rear.dispatch.manifests[manifest.id].state == "Loaded Waiting Dispatch","real manifest finishes loading")
	_expect(rear.dispatch.depart(manifest.id).ok,"real T02 departs on measured route")
	rear.advance_time(850)
	_expect(rear.dispatch.manifests[manifest.id].state == "Complete","same T02 unloads and returns")
	_expect(rear.ledger.inspect_entity("g14-real-recruit").assignment == "HQ Reserve","real recruit joins HQ Reserve after exit/walk")
	_expect(rear.ledger.inspect_entity("g14-real-rifle").holder_id == "g14-real-recruit","HQ command automatically issued same unloaded rifle after receipt")
	_expect(rear.hq._held_rounds(rear,"g14-real-recruit") == 30,"HQ command issued same thirty rounds after actual unload")
	_expect(base.audit().is_empty(),"G12/G13 arrival to G14 actual issue conserves identities: "+str(base.audit()))
