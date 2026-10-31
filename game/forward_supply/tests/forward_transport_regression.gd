extends SceneTree

const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const HQ := Vector2(1640.0,91.0)
const STOP := Vector2(1640.0,300.0)
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_two_physical_cycles()
	_test_multiportion_cycle()
	_test_claim_rollback()
	_test_mixed_masses()
	_test_changed_source_and_handler()
	print("Forward transport regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _person(rear: RefCounted, id: String, qualification: String = "None") -> void:
	_expect(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,qualification,"None").ok,"real military person " + id)
	rear.dispatch.military_people[id] = "transport-receipt"
	rear.dispatch.hq_reserve[id] = "Occupied"
	if qualification == "None":
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"real rifle for " + id)
		_expect(rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"real matching rounds for " + id)


func _test_two_physical_cycles() -> void:
	var base := Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var supply: RefCounted = rear.forward_supply
	for id in ["transport-a","transport-b","transport-c","transport-d"]:
		_person(rear,id)
	_person(rear,"transport-driver","P08")
	rear.advance_time(8)
	_expect(rear.military.squads.size() == 1,"four equipped people form one actual squad")
	if rear.military.squads.is_empty(): return
	var squad: Dictionary = rear.military.squads.values()[0]
	_expect(ledger.reserve_rear_hull("transport-admission",rear.PLAYER,"transport-fixture").ok,"real hull admission")
	_expect(ledger.create_heavy_output("transport-admission","transport-fixture","transport-t01","T01","hq-berth",rear.PLAYER,Specs.TYPES.T01).ok,"actual T01 at HQ berth")
	_expect(ledger.complete_hq_hull_receipt("transport-t01").ok,"same T01 enters military fleet")
	rear.dispatch.military_hulls["transport-t01"] = "transport-fixture"
	_expect(rear.military.assign_crew("transport-driver","transport-t01","Driver").ok,"qualified driver reports to same hull")
	rear.advance_time(8)
	if not rear.military.vehicles.has("transport-t01"):
		_expect(rear.military.attach_vehicle("transport-t01",squad.platoon).ok,"staffed T01 attaches to actual platoon")
	_expect(rear.military.vehicles.has("transport-t01"),"named military T01 has actual formation attachment")
	_expect(ledger.add_stock("transport-fuel","M08",20,1.0,"hq-berth",rear.PLAYER).ok,"physical fuel at HQ")
	_expect(ledger.begin_carry("initial-hq-01","transport-fuel",20).ok,"real HQ worker carries fuel")
	_expect(ledger.load_vehicle_fuel("initial-hq-01","transport-t01").ok,"real fuel enters T01 tank")
	_expect(ledger.add_place("transport-stop","Declared destination",STOP).ok,"physical forward stop")
	_expect(ledger.move_entity("transport-a","transport-stop",STOP+Vector2(5,0)).ok,"actual member near destination")
	_expect(ledger.add_stock("transport-hq-rounds","E02",120,0.02,"hq-stock",rear.PLAYER).ok,"real HQ freight")
	var outbound: Array = [HQ,STOP]
	var returning: Array = [STOP,HQ]
	var before: int = ledger.total_stock("E02")
	var fuel_before: float = ledger.inspect_entity("transport-t01").fuel
	_expect(not supply.request_delivery("transport-t01","transport-a-rounds",5,"transport-stop",outbound,returning,"initial-hq-02","transport-a").ok,"remote personal stock cannot become HQ freight")
	_expect(not supply.request_delivery("transport-t01","transport-hq-rounds",5,"transport-stop",outbound,returning,"transport-a","transport-a").ok,"formation member cannot impersonate HQ loader")
	var first: Dictionary = supply.request_delivery("transport-t01","transport-hq-rounds",30,"transport-stop",outbound,returning,"initial-hq-02","transport-a")
	_expect(first.ok,"first physical HQ delivery accepted")
	if not first.ok: return
	_expect(supply.hull_committed("transport-t01"),"same hull committed across delivery")
	rear.advance_time(0)
	_expect("initial-hq-02" not in rear.dispatch.free_hq_handlers(4),"forward pickup excludes its loader from unrelated HQ handling before stock is lifted")
	var competing_fuel: Dictionary = rear.hq.request_vehicle_fuel("transport-t01",1)
	_expect(not competing_fuel.ok and "job" in str(competing_fuel.message),"HQ cannot start refuelling the hull committed to forward delivery")
	_expect(not supply.request_delivery("transport-t01","transport-hq-rounds",30,"transport-stop",outbound,returning,"initial-hq-03","transport-a").ok,"second simultaneous mission cannot own same hull")
	rear.advance_time(2)
	_expect(not str(supply.transport.jobs[first.id].task.get("carry","")).is_empty(),"loader physically carries first portion")
	_expect(supply.interrupt_delivery(first.id).ok,"loading can be interrupted")
	var held: int = supply.transport.jobs[first.id].loaded
	rear.advance_time(5)
	_expect(supply.transport.jobs[first.id].loaded == held,"interruption does not teleport more stock")
	var resumed: Dictionary = supply.resume_delivery(first.id)
	_expect(resumed.ok,"same loading task resumes: " + str(resumed))
	rear.advance_time(200)
	var first_row: Dictionary = supply.transport.jobs[first.id]
	_expect(first_row.state == "Complete","first freight arrives, unloads and same hull returns HQ")
	_expect(first_row.loaded == 30 and first_row.unloaded == 30,"exact first manifest accounted for")
	_expect(ledger.inspect_entity("transport-t01").holder_id == "hq-berth","same T01 physically returns to HQ")
	_expect(ledger.inspect_entity("transport-t01").fuel < fuel_before,"route burns actual tank fuel")
	var first_delivered := 0
	for id in first_row.delivered_items:
		var item: Dictionary = ledger.inspect_entity(id)
		if item.holder_id == "transport-stop": first_delivered += int(item.quantity)
	_expect(first_delivered == 30,"actual first stock portions remain at forward stop")
	var second: Dictionary = supply.request_delivery("transport-t01","transport-hq-rounds",20,"transport-stop",outbound,returning,"initial-hq-02","transport-a")
	_expect(second.ok,"second resupply uses returned same hull and remaining HQ freight")
	if not second.ok: return
	rear.advance_time(45)
	var second_row: Dictionary = supply.transport.jobs[second.id]
	_expect(second_row.state == "Outbound" or second_row.state == "Unloading" or second_row.state == "Returning","second freight has left HQ")
	_expect(supply.interrupt_delivery(second.id).ok,"active second delivery can be interrupted")
	var paused_hull: Dictionary = ledger.inspect_entity("transport-t01")
	var paused_position: Vector2 = paused_hull.position
	var paused_fuel: float = paused_hull.fuel
	rear.advance_time(10)
	_expect(ledger.inspect_entity("transport-t01").position.is_equal_approx(paused_position) and is_equal_approx(ledger.inspect_entity("transport-t01").fuel,paused_fuel),"paused hull neither moves nor burns fuel")
	var resume_points: Array = [paused_position,STOP] if second_row.paused_state == "Outbound" else [paused_position,HQ]
	var second_resume: Dictionary = supply.resume_delivery(second.id,resume_points,returning) if second_row.paused_state == "Outbound" else supply.resume_delivery(second.id,[],resume_points)
	_expect(second_resume.ok,"same hull resumes from actual location with declared waypoints: " + str(second_resume))
	rear.advance_time(180)
	second_row = supply.transport.jobs[second.id]
	_expect(second_row.state == "Complete" and second_row.unloaded == 20,"second full physical delivery and return complete")
	_expect(ledger.total_stock("E02") == before,"both cycles conserve exact stock")
	var driver = ledger._entities["transport-driver"]
	driver.health = 0
	_expect(not supply.request_delivery("transport-t01","transport-hq-rounds",5,"transport-stop",outbound,returning,"initial-hq-02","transport-a").ok,"incapacitated actual driver prevents new transport")
	driver.health = 100
	var remaining_fuel: float = ledger.inspect_entity("transport-t01").fuel
	_expect(ledger.burn_vehicle_fuel("transport-t01",remaining_fuel).ok,"actual tank can be depleted")
	_expect(not supply.request_delivery("transport-t01","transport-hq-rounds",5,"transport-stop",outbound,returning,"initial-hq-02","transport-a").ok,"empty physical tank refuses further delivery")
	_expect(supply.audit().is_empty() and base.audit().is_empty(),"transport and common ledger audit remain clean: " + str(supply.audit()) + " / " + str(base.audit()))


func _multi_fixture() -> Dictionary:
	var base := Base.new(false,true,false,HQ,false)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	_expect(ledger.add_place("multi-stop","Actual multiportion destination",STOP).ok,"multiportion stop")
	var ids: Array[String] = []
	for index in 4:
		var id := "multi-person-%d" % index
		_expect(ledger.add_person(id,"multi-stop",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"actual destination member")
		_expect(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok and ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"actual formation package")
		ids.append(id)
	_expect(rear.military.add_initial_squad("multi-squad","Rifle",ids,"multi-company","multi-platoon",rear.PLAYER).ok,"actual destination hierarchy")
	_expect(ledger.add_initial_vehicle("multi-t01","T01","hq-berth",rear.PLAYER,Specs.TYPES.T01,20,"Military").ok,"actual empty HQ truck with finite fuel")
	_expect(ledger.add_person("multi-driver","hq-berth",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok and ledger.assign_initial_vehicle_crew("multi-driver","multi-t01","Driver").ok,"actual qualified truck driver")
	_expect(rear.military.attach_initial_vehicle("multi-t01","multi-platoon").ok,"actual truck attachment")
	rear.dispatch.military_hulls["multi-t01"] = "Initial multiportion fixture"
	return {"base":base,"rear":rear,"ledger":ledger,"supply":rear.forward_supply}


func _parts(f: Dictionary, count: int = 4) -> void:
	for index in count:
		_expect(f.ledger.add_stock("multi-source-%d" % index,"E26",50,0.5,"hq-stock",f.rear.PLAYER).ok,"distinct physical origin")


func _request_multi(f: Dictionary, quantity: int) -> Dictionary:
	return f.supply.request_delivery_type("multi-t01","E26",quantity,"multi-stop",[HQ,STOP],[STOP,HQ],"initial-hq-02","multi-person-0")


func _test_multiportion_cycle() -> void:
	var f := _multi_fixture()
	_parts(f)
	_expect(f.ledger.add_stock("multi-foreign","E26",200,0.5,"hq-stock","army-red").ok,"foreign stock cannot cover own request")
	_expect(f.ledger.add_stock("multi-reserved","E26",50,0.5,"hq-stock",f.rear.PLAYER).ok and f.ledger.request_stock("multi-other","multi-reserved",50,"other","Competing request",f.rear.PLAYER).ok,"other reservation stays separate")
	_expect(f.ledger.add_stock("multi-wrong","E25",200,1.0,"hq-stock",f.rear.PLAYER).ok,"wrong type cannot cover request")
	_expect(f.ledger.add_weapon("multi-nested-weapon","E07",4.0,"hq-stock",f.rear.PLAYER,"E26",10).ok and f.ledger.add_stock("multi-nested-source","E26",5,0.5,"hq-stock",f.rear.PLAYER).ok,"real HQ weapon and matching ammunition")
	_expect(f.ledger.load_rounds("multi-nested-weapon","multi-nested-source",5).ok,"nested loaded ammunition and depleted original source are not direct available freight")
	_expect(not f.supply.request_delivery("multi-t01","multi-source-0",180,"multi-stop",[HQ,STOP],[STOP,HQ],"initial-hq-02","multi-person-0").ok,"legacy stock-ID request remains strictly single-source")
	_expect(not _request_multi(f,201).ok,"foreign, reserved and wrong stock cannot inflate available own type")
	var accepted := _request_multi(f,180)
	_expect(accepted.ok,"one requested load spans four actual origins")
	if not accepted.ok: return
	var row: Dictionary = f.supply.transport.jobs[accepted.id]
	_expect(row.sources.size() == 4 and row.sources[0].quantity == 50 and row.sources[3].quantity == 30,"canonical quotas total exactly 180 without merging stacks")
	_expect(f.ledger.inspect_entity("multi-source-3").available == 20 and f.ledger.inspect_claim("multi-other").reserved == 50,"only the exact own deficit is reserved")
	f.rear.advance_time(6)
	_expect(row.loaded == 50 and row.task.get("source","") == "multi-source-1" and not str(row.task.get("carry","")).is_empty(),"second source is physically carried after first source was deposited")
	if str(row.task.get("carry","")).is_empty(): return
	var carry: String = row.task.carry
	var claim: String = row.task.claim
	_expect(f.supply.interrupt_delivery(row.id).ok,"actual second-source carry pauses")
	f.rear.advance_time(3)
	_expect(row.loaded == 50 and f.ledger.inspect_entity(carry).holder_id == row.loader and row.task.claim == claim,"pause retains exact carried ID, source claim and uncredited count")
	_expect(f.ledger.move_entity("multi-t01","hq-berth",HQ+Vector2(2,0)).ok,"actual hull moves outside owned loading position")
	_expect(f.supply.resume_delivery(row.id).ok,"same handling task resumes for fresh boundary validation")
	f.rear.advance_time(2)
	_expect(row.state == "Paused" and row.loaded == 50 and row.task.carry == carry,"changed hull blocks deposit without replacing the carry")
	_expect(f.ledger.move_entity("multi-t01","hq-berth",HQ).ok and f.supply.resume_delivery(row.id).ok,"same hull returns before the same carry resumes")
	f.rear.advance_time(220)
	_expect(row.state == "Complete" and row.loaded == 180 and row.unloaded == 180 and row.return_completed,"one multiportion mission fully unloads and returns")
	var delivered := {}
	for id in row.delivered_items:
		var stock: Dictionary = f.ledger.inspect_entity(id)
		delivered[stock.origin_id] = int(delivered.get(stock.origin_id,0))+int(stock.quantity)
	_expect(delivered == {"multi-source-0":50,"multi-source-1":50,"multi-source-2":50,"multi-source-3":30},"all four physical origins and quantities reach the stop exactly once")
	_expect(f.ledger.inspect_entity("multi-source-3").quantity == 20 and f.ledger.total_stock("E26") == 455,"leftovers, nested, foreign and reserved goods remain conserved")
	_expect(f.base.audit().is_empty(),"multiportion pause, load and one return retain common invariants")


func _test_claim_rollback() -> void:
	var f := _multi_fixture()
	_parts(f)
	var once: Array[bool] = [false]
	# An existing route callback introduces a real competing claim after planning.
	f.ledger.route_hazard = func(_owner: String, _points: Array) -> String:
		if not once[0]:
			once[0] = true
			_expect(f.ledger.request_stock("late-other","multi-source-2",25,"other","Late real contention",f.rear.PLAYER).ok,"late competitor reserves physical stock")
		return ""
	var rejected := _request_multi(f,180)
	f.ledger.route_hazard = Callable()
	_expect(not rejected.ok and f.supply.transport.jobs.is_empty() and not f.supply.hull_committed("multi-t01"),"partial later claim cannot publish a job or hull commitment")
	var own := 0
	for item in f.ledger.snapshot().claims:
		if str(item.claimant).begins_with("forward-delivery-"):
			own += 1
			_expect(item.cancelled and item.reserved == 0,"rollback releases every own claim including partially reserved last source")
	_expect(own == 3 and f.ledger.inspect_claim("late-other").reserved == 25,"rollback leaves the competing claim unchanged")
	_expect(f.ledger.inspect_entity("multi-source-0").available == 50 and f.ledger.inspect_entity("multi-source-1").available == 50 and f.ledger.total_stock("E26") == 200,"failed admission moves no goods and releases earlier source claims")
	_expect(f.base.audit().is_empty(),"claim rollback retains ledger invariants")


func _test_mixed_masses() -> void:
	var f := _multi_fixture()
	_expect(f.ledger.add_stock("mass-one","E26",20,1.0,"hq-stock",f.rear.PLAYER).ok and f.ledger.add_stock("mass-two","E26",20,2.0,"hq-stock",f.rear.PLAYER).ok,"same type retains heterogeneous physical unit masses")
	var preview: Dictionary = f.supply.preview_delivery_type("multi-t01","E26",40,"multi-stop",[HQ,STOP],[STOP,HQ],"initial-hq-02","multi-person-0")
	var hull: Dictionary = f.ledger.inspect_entity("multi-t01")
	_expect(preview.ok and preview.gross_kg == hull.unit_mass_kg+hull.fuel+hull.contents_mass_kg+60.0,"preview sums each selected source mass rather than multiplying the first mass")
	var accepted := _request_multi(f,40)
	_expect(accepted.ok,"actual mixed-mass load admitted")
	if not accepted.ok: return
	var row: Dictionary = f.supply.transport.jobs[accepted.id]
	f.rear.advance_time(6)
	var carried: Dictionary = f.ledger.inspect_entity(row.task.get("carry",""))
	_expect(row.loaded == 20 and carried.get("quantity",0) == 12 and carried.get("unit_mass_kg",0) == 2.0,"second-source pickup uses its own 25kg capacity, not first-source mass")
	f.rear.advance_time(220)
	_expect(row.state == "Complete" and f.ledger.loose_stock_mass_at("multi-stop") == 60.0,"all heterogeneous mass reaches the stop physically")
	_expect(f.ledger.add_stock("over-one","E26",1,1.0,"hq-stock",f.rear.PLAYER).ok and f.ledger.add_stock("over-two","E26",2,3000.0,"hq-stock",f.rear.PLAYER).ok,"actual oversized mixed-mass source fixture")
	var oversized: Dictionary = _request_multi(f,3)
	_expect(not oversized.ok and "payload" in str(oversized.message),"sum of source masses enforces the unchanged truck payload")
	_expect(f.base.audit().is_empty(),"mixed mass and payload refusal preserve physical quantities")


func _test_changed_source_and_handler() -> void:
	var moved := _multi_fixture()
	_parts(moved,2)
	var accepted := _request_multi(moved,100)
	_expect(accepted.ok,"source-change fixture admitted")
	if not accepted.ok: return
	var row: Dictionary = moved.supply.transport.jobs[accepted.id]
	moved.rear.advance_time(0)
	_expect(moved.ledger.release_claim(row.sources[0].claim).ok,"actual source claim withdrawn")
	_expect(moved.ledger.add_place("changed-source","Separate co-located actual holder",HQ).ok,"physical alternate holder")
	_expect(moved.ledger.transfer_stock("multi-source-0",50,"changed-source").ok,"withdrawn source physically moves")
	moved.rear.advance_time(2)
	_expect(row.state == "Paused" and row.loaded == 0 and row.task.source == "multi-source-0" and moved.ledger.inspect_entity("multi-source-1").quantity == 50 and moved.ledger.inspect_claim(row.sources[1].claim).reserved == 50,"changed source blocks instead of silently switching to another stack")
	var injured := _multi_fixture()
	_parts(injured,2)
	accepted = _request_multi(injured,100)
	_expect(accepted.ok,"handler-change fixture admitted")
	if not accepted.ok: return
	row = injured.supply.transport.jobs[accepted.id]
	injured.rear.advance_time(6)
	var carry: String = str(row.task.get("carry",""))
	_expect(not carry.is_empty(),"second-source handler actually holds the planned portion before injury")
	if carry.is_empty(): return
	_expect(injured.ledger.injure_person(row.loader,100).ok,"actual loader incapacitated mid-second-source carry")
	injured.rear.advance_time(2)
	_expect(row.state == "Paused" and row.loaded == 50 and not injured.supply.resume_delivery(row.id).ok,"unavailable handler cannot resume or credit a lost carry")
	_expect(injured.ledger.inspect_entity(carry).origin_id == "multi-source-1" and injured.ledger.total_stock("E26") == 100,"dropped second-source goods retain physical identity without replacement")
