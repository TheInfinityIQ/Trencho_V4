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
	_test_raw_held_counts()
	_test_carried_cancel_returns_to_hq()
	_test_automatic_hq_command()
	_test_real_dispatch_receipt_auto_issue()
	_test_construction_and_hq_share_clock()
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

func _test_construction_and_hq_share_clock() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var site: Dictionary = rear.construction.place("depot",Vector2(140,10))
	_expect(site.ok,"G05 site starts during G14 HQ issue")
	if not site.ok: return
	_expect(rear.ledger.add_stock("g14-build-m11","M11",100,1.0,"depot",rear.PLAYER).ok,"real M11 exists for concurrent build")
	_expect(rear.construction.order_materials(site.id,"depot").ok,"same rear requests physical M11 haul")
	_expect(rear.set_target("hauling",4).ok,"real rear haulers assigned")
	_expect(rear.construction.set_office_staff("construction",4).ok,"real F12 builders requested")
	rear.advance_time(150)
	_expect(rear._present("construction") >= 4,"builders report to F12 before transfer")
	_expect(rear.construction.set_builders(site.id,4).ok,"four actual builders serve the site")
	var tank := _tank(base)
	_expect(rear.ledger.move_entity(tank,"hq-berth",Vector2(1640,91)).ok,"same tank is locally at HQ")
	_expect(rear.ledger.add_stock("g14-build-shells","E25",2,12.0,"hq-stock",rear.PLAYER).ok,"separate unloaded HQ shells exist")
	var issue: Dictionary = rear.hq.request_vehicle_ammo(tank,"E25",2)
	_expect(issue.ok,"HQ shell issue starts while F03 builds")
	if not issue.ok: return
	rear.advance_time(900)
	_expect(rear.construction.instances[site.id].state == "Complete","G05 construction completes on shared clock")
	_expect(rear.hq.jobs[issue.id].state == "Complete" and rear.ledger.inspect_entity(tank).ammunition.E25 == 2,"G14 local issue completes once on same clock")
	_expect(base.audit().is_empty(),"concurrent G05/G14 state remains conserved: "+str(base.audit()))

func _test_a24_and_local_handoff() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var tank := _tank(base)
	_expect(ledger.add_stock("g14-shells","E25",10,12.0,"hq-stock",rear.PLAYER).ok,"ten unloaded shells at HQ stock")
	_expect(ledger.add_stock("g14-arrived-shell","E25",1,12.0,"hq-berth",rear.PLAYER).ok,"one arrived shell still awaits HQ unload")
	_expect(ledger.add_stock("g14-foreign-shell","E25",2,12.0,"hq-stock","foreign-army").ok,"foreign stock can occupy physical HQ mass without becoming owned issue stock")
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

func _test_raw_held_counts() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	_expect(ledger.add_person("g14-count-person","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true).ok,"count fixture recipient")
	_expect(ledger.add_person("g14-count-other","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true).ok,"count fixture other recipient")
	_expect(ledger.add_weapon("g14-count-rifle","E01",4.0,"g14-count-person","foreign-army","E02",30).ok,"foreign-owned held rifle remains a raw held weapon")
	_expect(ledger.add_weapon("g14-count-other-weapon","E07",4.0,"g14-count-person",rear.PLAYER,"E02",30).ok,"second held weapon for nested raw count")
	_expect(ledger.add_stock("g14-count-loose","E02",5,0.02,"g14-count-person",rear.PLAYER).ok,"five loose matching rounds")
	_expect(ledger.add_stock("g14-count-foreign","E02",7,0.02,"g14-count-person","foreign-army").ok,"seven foreign matching held rounds")
	_expect(ledger.add_stock("g14-count-loaded-source","E02",3,0.02,"g14-count-person","foreign-army").ok,"actual matching foreign-owned rifle ammunition")
	_expect(ledger.load_rounds("g14-count-rifle","g14-count-loaded-source",3).ok,"three rounds physically loaded into the held rifle")
	_expect(ledger.add_stock("g14-count-other-source","E02",2,0.02,"g14-count-person",rear.PLAYER).ok,"actual matching second-weapon ammunition")
	_expect(ledger.load_rounds("g14-count-other-weapon","g14-count-other-source",2).ok,"two rounds physically loaded into another held weapon type")
	_expect(ledger.add_stock("g14-count-unrelated","E02",11,0.02,"g14-count-other",rear.PLAYER).ok,"other person's rounds remain separate")
	_expect(ledger.add_stock("g14-count-wrong-type","E03",13,0.02,"g14-count-person",rear.PLAYER).ok,"nonmatching held stock remains separate")
	_expect(ledger.request_stock("g14-count-claim","g14-count-loose",3,"g14-fixture","Held count reservation",rear.PLAYER).ok,"reserved loose rounds remain physically held")
	_expect(rear.hq._held_weapon(rear,"g14-count-person","E01"),"held-weapon query preserves raw ownership semantics")
	_expect(not rear.hq._held_weapon(rear,"g14-count-other","E01"),"held-weapon query requires the same physical holder")
	_expect(rear.hq._held_rounds(rear,"g14-count-person") == 17,"held rounds include reserved and foreign loose/nested E02 without unrelated stock")
	_expect(ledger.add_stock("g14-count-hq","E02",13,0.02,"hq-stock",rear.PLAYER).ok,"owned unloaded HQ stock")
	_expect(ledger.add_stock("g14-count-hq-foreign","E02",17,0.02,"hq-stock","foreign-army").ok,"foreign unloaded stock excluded from availability")
	_expect(ledger.add_stock("g14-count-berth","E02",19,0.02,"hq-berth",rear.PLAYER).ok,"arrived stock excluded before unloading")
	_expect(ledger.request_stock("g14-count-hq-claim","g14-count-hq",4,"g14-fixture","HQ count reservation",rear.PLAYER).ok,"HQ availability subtracts actual reservation")
	var counts: Dictionary = rear.hq._stock_counts()
	_expect(counts.available.get("E02",0) == 9 and counts.reserved.get("E02",0) == 4,"automatic stock counts preserve ownership, location and reservation semantics")
	var view: Dictionary = rear.hq.snapshot()
	_expect(view.available == counts.available and view.reserved == counts.reserved,"public HQ snapshot retains the same available/reserved view")
	_expect(is_equal_approx(float(view.occupied_stock_kg),0.6),"public HQ snapshot still includes owned and foreign physical mass")
	_expect(ledger.add_weapon("g14-count-hq-rifle","E01",4.0,"hq-stock",rear.PLAYER,"E02",30).ok,"same owned weapon is physically at HQ")
	_expect(ledger.add_weapon("g14-count-broken","E01",4.0,"hq-stock",rear.PLAYER,"E02",30).ok,"second weapon retains raw inventory semantics")
	ledger._entities["g14-count-broken"].health = 0
	_expect(ledger.add_weapon("g14-count-foreign-rifle","E01",4.0,"hq-stock","foreign-army","E02",30).ok,"foreign HQ weapon is excluded")
	_expect(ledger.add_stock("g14-count-hq-extra","E02",3,0.04,"hq-stock",rear.PLAYER).ok,"heterogeneous same-type stack retains exact counts")
	_expect(ledger.add_stock("g14-count-empty","M11",1,1.0,"hq-stock",rear.PLAYER).ok and ledger.record_consumption("g14-count-empty",1,"Inventory depletion").ok,"depleted identity remains physical with zero quantity")
	_compare_stock_counts(rear)
	var retained: Dictionary = ledger.owned_inventory_at("hq-stock",rear.PLAYER)
	var copy: Dictionary = retained.duplicate(true)
	_expect(ledger.release_claim("g14-count-hq-claim").ok,"real reservation release changes availability")
	_expect(retained == copy and ledger.owned_inventory_at("hq-stock",rear.PLAYER) != retained,"prior inventory stays detached after real reservation change")
	_expect(ledger.move_entity("g14-count-person","hq-stock",rear.hq.hq_position).ok,"recipient physically reaches stock")
	_expect(ledger.load_rounds("g14-count-hq-rifle","g14-count-hq",3).ok,"nested loaded rounds are excluded from direct loose stock")
	_compare_stock_counts(rear)
	var promise: Dictionary = rear.hq.request_person_weapon("g14-count-other","g14-count-hq-rifle")
	_expect(promise.ok,"actual HQ job promises an intact inventory weapon")
	_compare_stock_counts(rear)
	if promise.ok: _expect(rear.hq.cancel(promise.id).ok,"actual cancellation restores available weapon bucket")
	_expect(ledger.transfer_weapon("g14-count-hq-rifle","g14-count-person").ok,"same loaded weapon physically leaves HQ stock")
	_compare_stock_counts(rear)
	retained.available.clear()
	retained.reserved.clear()
	retained.weapons.clear()
	_compare_stock_counts(rear)
	_expect(ledger.owned_inventory_at("missing",rear.PLAYER) == {"available":{},"reserved":{},"weapons":[]},"missing inventory holder remains empty")

func _compare_stock_counts(rear: RefCounted) -> void:
	# Retained original algorithm: complete independent per-row inspections.
	var expected := {"available":{},"reserved":{},"weapons_available":{},"weapons_promised":{}}
	for entity in rear.ledger._entities.values():
		if entity.holder_id != "hq-stock" or Records.Kind.keys()[entity.kind] not in ["STOCK","WEAPON"]: continue
		var row: Dictionary = rear.ledger.inspect_entity(entity.id,{},false)
		if row.holder_id != "hq-stock" or row.owner != rear.PLAYER or row.quantity <= 0: continue
		if row.kind == "STOCK":
			expected.available[row.design_type] = int(expected.available.get(row.design_type,0))+int(row.available)
			expected.reserved[row.design_type] = int(expected.reserved.get(row.design_type,0))+int(row.reserved)
		else:
			var bucket: Dictionary = expected.weapons_promised if rear.hq.weapon_promises.has(row.id) else expected.weapons_available
			bucket[row.design_type] = int(bucket.get(row.design_type,0))+1
	_expect(var_to_bytes(rear.hq._stock_counts()) == var_to_bytes(expected),"HQ count values and insertion order equal original independent inspections")

func _test_carried_cancel_returns_to_hq() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var tank := _tank(base)
	_expect(rear.ledger.move_entity(tank,"hq-berth",Vector2(1640,91)).ok,"same military tank locally parked")
	_expect(rear.ledger.add_stock("g14-cancel-shells","E25",3,12.0,"hq-stock",rear.PLAYER).ok,"three unloaded shells")
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
	_expect(ledger.add_stock("g14-auto-shells","E25",3,12.0,"hq-stock",rear.PLAYER).ok,"HQ has three actual shells")
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
