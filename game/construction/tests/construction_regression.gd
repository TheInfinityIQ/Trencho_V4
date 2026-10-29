extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var base := Base.new(true)
	var site := Vector2.ZERO
	for y in range(10,171,10):
		for x in range(10,231,10):
			var point := Vector2(x,y)
			if base.rear.construction.preview("depot",point).ok:
				site = point
				break
		if site != Vector2.ZERO: break
	_check(site != Vector2.ZERO,"At least one legal F03 placement exists")
	if site != Vector2.ZERO:
		print("G05 legal sample: ",site)
		_check(base.rear.construction.place("depot",site).ok,"Legal F03 reserves a physical site")
		_check(not base.rear.construction.place("depot",site).ok,"Same footprint cannot overlap")
	if site != Vector2.ZERO:
		var build_id := "site-0001"
		base.rear.ledger.add_stock("test-m11","M11",100,1.0,"depot",base.rear.PLAYER)
		_check(base.rear.construction.order_materials(build_id,"depot").ok,"Real M11 haul requested")
		_check(base.rear.set_target("hauling",4).ok,"Four actual haulers requested")
		_staff_initial_office(base.rear)
		_check(base.rear.construction.set_builders(build_id,4).ok,"Four actual builders requested")
		base.rear.advance_time(900)
		var row: Dictionary = base.rear.construction.instances[build_id]
		_check(row.state == "Complete","Actual hauling and builder work complete: "+str(row))
		_check(base.rear.ledger.total_stock("M11") == 0,"Whole M11 recipe consumed once")
	var copy := Base.new(true)
	var copy_site := Vector2.ZERO
	for y in range(10,171,10):
		for x in range(10,231,10):
			var point := Vector2(x,y)
			if copy.rear.construction.preview("workshop",point).ok:
				copy_site = point
				break
		if copy_site != Vector2.ZERO: break
	_check(copy_site != Vector2.ZERO,"Legal F04 copy site exists")
	if copy_site != Vector2.ZERO:
		copy.rear.construction.place("workshop",copy_site)
		copy.rear.ledger.add_stock("copy-m11","M11",150,1.0,"depot",copy.rear.PLAYER)
		copy.rear.construction.order_materials("site-0001","depot")
		copy.rear.set_target("hauling",4)
		_staff_initial_office(copy.rear)
		copy.rear.construction.set_builders("site-0001",4)
		copy.rear.advance_time(1200)
		_check(copy.rear.construction.instances["site-0001"].state == "Complete","F04 copy completed")
		_check(copy.rear.construction.activities.has("site-0001"),"F04 copy owns independent activity")
		if copy.rear.construction.activities.has("site-0001"):
			var activity: RefCounted = copy.rear.construction.activities["site-0001"]
			_check(activity._spec.input_store == "site-0001-input" and activity._spec.output_store == "site-0001-output","Copy has independent input/output stores")
			_check(copy.rear.stores["site-0001-input"].capacity == 1000.0 and copy.rear.stores["site-0001-output"].capacity == 1000.0,"Copy has own GDD capacities")
			_check(copy.rear.requests["site-0001"].positions == 4,"Copy has own four staff positions")
			copy.rear.ledger.add_stock("copy-m01","M01",2,1.0,"depot",copy.rear.PLAYER)
			copy.rear.ledger.add_stock("copy-m02","M02",1,1.0,"depot",copy.rear.PLAYER)
			copy.rear.request_haul("depot","site-0001-input","M01",2)
			copy.rear.request_haul("depot","site-0001-input","M02",1)
			activity.set_stock_target(1)
			copy.rear.set_target("site-0001",4)
			copy.rear.advance_time(900)
			_check(copy.rear.ledger.available_stock_at("site-0001-output","E01") == 1,"F04 copy completes its own actual R01 batch")
			_check(copy.rear.ledger.available_stock_at("workshop_output","E01") == 0,"Initial F04 did not inherit copy batch")
	var bay := Base.new(true)
	var bay_site := Vector2.ZERO
	for y in range(10,171,10):
		for x in range(10,231,10):
			var point := Vector2(x,y)
			if bay.rear.construction.preview("receiving",point).ok:
				bay_site = point
				break
		if bay_site != Vector2.ZERO: break
	_check(bay_site != Vector2.ZERO,"Legal additional F02 site exists")
	if bay_site != Vector2.ZERO:
		bay.rear.construction.place("receiving",bay_site)
		bay.rear.ledger.add_stock("bay-m11","M11",100,1.0,"depot",bay.rear.PLAYER)
		bay.rear.construction.order_materials("site-0001","depot")
		bay.rear.set_target("hauling",4)
		_staff_initial_office(bay.rear)
		bay.rear.construction.set_builders("site-0001",4)
		bay.rear.advance_time(900)
		_check(bay.rear.construction.instances["site-0001"].state == "Complete","Additional F02 built from real M11")
		_check(bay.receiving.freight_limit() == 12 and bay.receiving.freight_berths.size() == 2,"One shared ten-place queue plus two berths")
		_check(bay.rear.stores["site-0001-output"].capacity == 5000.0 and bay.rear.requests["site-0001"].positions == 4,"Additional F02 has independent storage and staff")
		for _order in 12:
			_check(bay.receiving.buy_resources({"M03":1}).ok,"Each physical berth raises only one shared freight admission")
		_check(not bay.receiving.buy_resources({"M03":1}).ok,"Thirteenth freight commitment cannot enter ten waiting plus two berths")
		bay.rear.set_target("site-0001",1)
		bay.rear.advance_time(700)
		_check(bay.receiving.receiving_kg(1) > 0,"Second F02 physically unloads freight into its own store")
		_check(bay.audit().is_empty(),"Two-berth session retains shared invariants: "+str(bay.audit()))
	var early := Base.new(true)
	var early_site := Vector2.ZERO
	for y in range(10,171,10):
		for x in range(10,231,10):
			var point := Vector2(x,y)
			if early.rear.construction.preview("depot",point).ok:
				early_site = point
				break
		if early_site != Vector2.ZERO: break
	if early_site != Vector2.ZERO:
		early.rear.construction.place("depot",early_site)
		early.rear.ledger.add_stock("early-m11","M11",100,1.0,"depot",early.rear.PLAYER)
		early.rear.construction.order_materials("site-0001","depot")
		early.rear.set_target("hauling",4)
		early.rear.advance_time(650)
		_check(early.rear.ledger.available_stock_at("site-0001","M11") == 100,"All delivered M11 is physical before work")
		_check(early.rear.construction.cancel("site-0001").ok,"Prework cancellation accepted")
		early.rear.advance_time(650)
		_check(early.rear.ledger.available_stock_at("depot","M11") == 100,"Prework cancellation returns all delivered M11")
		_check(early.rear.ledger.total_stock("M11") == 100,"Prework cancellation consumes none")
	var started := Base.new(true)
	if early_site != Vector2.ZERO:
		started.rear.construction.place("depot",early_site)
		started.rear.ledger.add_stock("started-m11","M11",100,1.0,"depot",started.rear.PLAYER)
		started.rear.construction.order_materials("site-0001","depot")
		started.rear.set_target("hauling",4)
		started.rear.advance_time(650)
		_staff_initial_office(started.rear,1)
		started.rear.construction.set_builders("site-0001",1)
		for _step in range(40):
			started.rear.advance_time(10)
			if started.rear.construction.instances["site-0001"].state == "Building" and started.rear.construction.instances["site-0001"].progress > 0: break
		_check(started.rear.construction.instances["site-0001"].state == "Building","Partial work starts only after delivery")
		_check(started.rear.construction.cancel("site-0001").ok,"Started work can cancel")
		started.rear.advance_time(650)
		_check(started.rear.ledger.total_stock("M11") == 50,"Started cancellation consumes floor half and returns half")
	var dismantle := Base.new(true)
	if early_site != Vector2.ZERO:
		dismantle.rear.construction.place("depot",early_site)
		dismantle.rear.ledger.add_stock("demolition-m11","M11",100,1.0,"depot",dismantle.rear.PLAYER)
		dismantle.rear.construction.order_materials("site-0001","depot")
		dismantle.rear.set_target("hauling",4)
		_staff_initial_office(dismantle.rear)
		dismantle.rear.construction.set_builders("site-0001",4)
		dismantle.rear.advance_time(900)
		_check(dismantle.rear.construction.request_dismantle("site-0001").ok,"Completed unprotected F03 can dismantle")
		dismantle.rear.advance_time(120)
		dismantle.rear.construction.set_builders("site-0001",4)
		dismantle.rear.advance_time(200)
		_check(dismantle.rear.construction.instances["site-0001"].state == "Dismantled","Twenty builder work seconds dismantle")
		_check(dismantle.rear.ledger.available_stock_at("depot","M11") == 50,"Dismantling salvages half build M11")
	var recovery_paths := {"initial-receiving":"supplier and personnel recovery admissions","initial-construction":"construct replacement facilities","initial-materials":"make replacement M11"}
	for starter_id in recovery_paths:
		var refused: Dictionary = base.rear.construction.request_dismantle(starter_id)
		_check(not refused.ok and refused.message.contains(recovery_paths[starter_id]),"Protected starter states its recovery reason: "+starter_id+" / "+str(refused))
	for kind in ["park","training","vehicle_works","dispatch"]:
		var fixture := Base.new(true)
		var target := Vector2.ZERO
		for y in range(15,166,10):
			for x in range(15,226,10):
				var point := Vector2(x,y)
				if fixture.rear.construction.preview(kind,point).ok:
					target = point
					break
			if target != Vector2.ZERO: break
		_check(target != Vector2.ZERO,"Legal "+kind+" copy site exists")
		if target == Vector2.ZERO: continue
		fixture.rear.construction.place(kind,target)
		var required: int = fixture.rear.construction.instances["site-0001"].m11
		fixture.rear.ledger.add_stock(kind+"-m11","M11",required,1.0,"depot",fixture.rear.PLAYER)
		fixture.rear.construction.order_materials("site-0001","depot")
		fixture.rear.set_target("hauling",4)
		_staff_initial_office(fixture.rear)
		fixture.rear.construction.set_builders("site-0001",4)
		fixture.rear.advance_time(3000)
		_check(fixture.rear.construction.instances["site-0001"].state == "Complete",kind+" copy completes physical build")
		if kind == "park":
			_check(fixture.rear.construction.instances["site-0001"].parking_slots.size() == 4,"Additional F11 owns four parking places")
			_check(fixture.rear.yard.active_parking.count(true) == 8,"Additional F11 raises active parking to eight")
		if kind == "training":
			_check(fixture.rear.training.snapshot().student_places == 24,"Additional F06 owns twelve student places")
			_check(fixture.rear.requests["site-0001"].positions == 2,"Additional F06 owns two instructor positions")
		if kind == "dispatch":
			_check(fixture.rear.dispatch.dispatch_sites.has("site-0001"),"Additional F07 registers a selectable physical berth")
			_check(fixture.rear.stores["site-0001-output"].capacity == 6000.0,"Additional F07 has independent 6000 kg storage")
			_check(fixture.rear.requests["site-0001"].positions == 4,"Additional F07 has four own staff positions")
			_check(not fixture.rear.dispatch.site_committed("site-0001"),"Unused additional F07 may be dismantled")
			var original_heavy: RefCounted = fixture.rear.heavy_production
			original_heavy.request_recipe("R28")
			original_heavy.set_mode("Continuous")
			_check(original_heavy.accept_order().ok,"F07 fixture accepts original T02 order")
			for material in Fixed.RECIPES["R28"].inputs:
				fixture.rear.ledger.add_stock("f07-"+material,material,int(Fixed.RECIPES["R28"].inputs[material]),1.0,"vehicle_input",fixture.rear.PLAYER)
			fixture.rear.set_target("vehicle_works",8)
			fixture.rear.advance_time(1000)
			var hull: String = original_heavy.bay_occupant
			_check(not hull.is_empty(),"F07 fixture has one physical T02 hull")
			if not hull.is_empty():
				fixture.rear.add_person("f07-driver",true,"P08")
				_check(fixture.rear.vehicles.assign_station(hull,"f07-driver","Driver").ok,"F07 fixture driver assigned to real hull")
				fixture.rear.advance_time(160)
				fixture.rear.ledger.add_stock("f07-fuel","M08",12,1.0,"depot",fixture.rear.PLAYER)
				_check(fixture.rear.vehicles.request_refuel(hull,"base-person-11",12).ok,"F07 fixture physical fuel ordered")
				fixture.rear.advance_time(200)
				_check(fixture.rear.vehicles.start_drive(hull).ok,"F07 fixture same hull clears initial F10")
				fixture.rear.advance_time(100)
				_check(fixture.rear.vehicles.vehicles[hull].state == "Parked","F07 fixture hull parks at real F11")
				fixture.rear.set_target("site-0001",2)
				var accepted: Dictionary = fixture.rear.dispatch.accept(hull,"Fleet Transfer",[],{},[],"site-0001")
				_check(accepted.ok,"Copy F07 accepts a named manifest: "+str(accepted))
				if accepted.ok:
					_check(fixture.rear.dispatch.site_committed("site-0001"),"Copy berth committed by its actual manifest")
					_check(not fixture.rear.construction.request_dismantle("site-0001").ok,"Committed F07 cannot dismantle")
					fixture.rear.advance_time(250)
					var manifest: Dictionary = fixture.rear.dispatch.manifests[accepted.id]
					_check(manifest.state == "Loaded Waiting Dispatch","Hull physically reaches copy F07: "+manifest.state+" / "+manifest.blocker)
					if manifest.state == "Loaded Waiting Dispatch":
						_check(fixture.rear.dispatch.depart(accepted.id).ok,"Copy F07 launches existing fleet transfer")
						fixture.rear.advance_time(350)
						_check(manifest.state == "Complete","Copy F07 manifest completes at HQ: "+manifest.state+" / "+manifest.blocker)
				_check(fixture.audit().is_empty(),"Copy F07 shares existing lifecycle invariants: "+str(fixture.audit()))
		if kind == "vehicle_works":
			_check(fixture.rear.construction.activities.has("site-0001"),"Additional F10 owns heavy activity")
			if fixture.rear.construction.activities.has("site-0001"):
				var heavy_copy: RefCounted = fixture.rear.construction.activities["site-0001"]
				_check(heavy_copy.bay_id == "site-0001-bay" and heavy_copy._spec.input_store == "site-0001-input","Additional F10 has own bay and input store")
				_check(fixture.rear.stores["site-0001-input"].capacity == 5000.0 and fixture.rear.requests["site-0001"].positions == 8,"Additional F10 has own capacity and eight staff positions")
				fixture.rear.ledger.add_stock("heavy-copy-m01","M01",120,1.0,"depot",fixture.rear.PLAYER)
				fixture.rear.ledger.add_stock("heavy-copy-m02","M02",80,1.0,"depot",fixture.rear.PLAYER)
				fixture.rear.request_haul("depot","site-0001-input","M01",120)
				fixture.rear.request_haul("depot","site-0001-input","M02",80)
				heavy_copy.set_stock_target(2)
				var accepted: Dictionary = heavy_copy.accept_order()
				_check(accepted.ok,"Copy F10 accepts its own heavy order: "+str(accepted))
				fixture.rear.set_target("site-0001",8)
				fixture.rear.advance_time(1600)
				_check(not heavy_copy.bay_occupant.is_empty(),"Copy F10 physically produces its own T01: "+str(heavy_copy.snapshot().status))
				_check(fixture.rear.heavy_production.bay_occupant.is_empty(),"Initial F10 bay stays independent")
				if not heavy_copy.bay_occupant.is_empty():
					var copied_hull: String = heavy_copy.bay_occupant
					fixture.rear.add_person("copy-f10-driver",true,"P08")
					_check(fixture.rear.vehicles.assign_station(copied_hull,"copy-f10-driver","Driver").ok,"Copy F10 hull gets a real driver")
					fixture.rear.advance_time(160)
					fixture.rear.ledger.add_stock("copy-f10-fuel","M08",8,1.0,"depot",fixture.rear.PLAYER)
					_check(fixture.rear.vehicles.request_refuel(copied_hull,"base-person-11",8).ok,"Copy F10 hull gets physical fuel")
					fixture.rear.advance_time(200)
					var copy_drive: Dictionary = fixture.rear.vehicles.start_drive(copied_hull)
					_check(copy_drive.ok,"Copy F10 hull can drive to its promised F11: "+copy_drive.message)
					if copy_drive.ok:
						fixture.rear.advance_time(150)
						_check(fixture.rear.vehicles.vehicles[copied_hull].state == "Parked","Copy F10 hull physically clears its bay and parks")
						_check(heavy_copy.request_recipe("R13").ok,"Copy F10 can select E13 after the hull clears")
						fixture.rear.ledger.add_stock("copy-gun-m01","M01",100,1.0,"site-0001-input",fixture.rear.PLAYER)
						fixture.rear.ledger.add_stock("copy-gun-m02","M02",60,1.0,"site-0001-input",fixture.rear.PLAYER)
						heavy_copy.set_stock_target(2)
						_check(heavy_copy.accept_order().ok,"Copy F10 accepts its independent E13 order")
						fixture.rear.advance_time(1200)
						var copied_gun: String = heavy_copy.bay_occupant
						_check(not copied_gun.is_empty() and fixture.rear.ledger.inspect_entity(copied_gun).get("design_type","") == "E13","Copy F10 physically produces E13")
						if not copied_gun.is_empty():
							fixture.rear.set_target("dispatch",2)
							fixture.rear.advance_time(160)
							var collected: Dictionary = fixture.rear.dispatch.accept(copied_hull,"Strategic Delivery",[],{},[copied_gun])
							_check(collected.ok,"Existing G12 accepts E13 from additional F10: "+str(collected))
							if collected.ok:
								fixture.rear.advance_time(500)
								_check(fixture.rear.ledger.inspect_entity(copied_gun).holder_id == copied_hull,"Two loaders collect copy F10 E13 into same parked hull")
				_check(fixture.audit().is_empty(),"Copy F10 output preserves shared invariants: "+str(fixture.audit()))
	_check(not base.rear.construction.preview("terminal",Vector2(100,160)).ok,"Fixed F01 cannot be built")
	_check(not base.rear.construction.preview("depot",Vector2(45,25)).ok,"Initial F02 footprint blocks construction")
	var blocked_access := false
	for y in range(10,171,5):
		for x in range(10,231,5):
			var candidate := Vector2(x,y)
			var size: Vector2 = base.rear.Layout.FACILITIES.depot[2]
			var candidate_box := Rect2(candidate-size/2.0,size).grow(0.25)
			var overlaps := false
			for facility in base.rear.construction.instances.values():
				if candidate_box.intersects(Rect2(facility.center-facility.size/2.0,facility.size).grow(0.25)):
					overlaps = true
					break
			if overlaps: continue
			var refused: Dictionary = base.rear.construction.preview("depot",candidate)
			if not refused.ok and (refused.message.contains("walking access") or refused.message.contains("eight-metre")):
				blocked_access = true
				var placement: Dictionary = base.rear.construction.place("depot",candidate)
				_check(not placement.ok and (placement.message.contains("walking access") or placement.message.contains("eight-metre")),"A10 rejects non-overlap road or walking obstruction with its access reason: "+str(placement))
				break
		if blocked_access: break
	_check(blocked_access,"A10 finds a non-overlap placement refused for walking or eight-metre vehicle access")
	_check(base.audit().is_empty(),"Shared audit after placement: "+str(base.audit()))
	_test_two_offices()
	print("G05 construction regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _first_site(rear: RefCounted, kind: String) -> Vector2:
	for y in range(15,166,10):
		for x in range(15,226,10):
			var point := Vector2(x,y)
			if rear.construction.preview(kind,point).ok: return point
	return Vector2.ZERO

func _test_two_offices() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var office_point := _first_site(rear,"construction")
	_check(office_point != Vector2.ZERO,"Additional F12 has a legal physical site")
	if office_point == Vector2.ZERO: return
	_check(rear.construction.place("construction",office_point).ok,"Second F12 site placed")
	rear.ledger.add_stock("second-office-m11","M11",60,1.0,"depot",rear.PLAYER)
	rear.construction.order_materials("site-0001","depot")
	rear.set_target("hauling",4)
	_staff_initial_office(rear)
	_check(rear.construction.set_builders("site-0001",4).ok,"First office sends the same four actual people to build second F12")
	rear.advance_time(850)
	_check(rear.construction.instances["site-0001"].state == "Complete","Second F12 construction completes")
	_check(rear.requests["site-0001"].positions == 4,"Second F12 owns four staff positions")
	for index in 8: rear.add_person("extra-builder-%d" % index)
	rear.advance_time(150)
	var first_point := _first_site(rear,"depot")
	_check(first_point != Vector2.ZERO,"First concurrent construction site is legal")
	if first_point == Vector2.ZERO: return
	rear.construction.place("depot",first_point)
	var second_point := _first_site(rear,"workshop")
	_check(second_point != Vector2.ZERO,"Second concurrent construction site is legal")
	if second_point == Vector2.ZERO: return
	rear.construction.place("workshop",second_point)
	_check(rear.construction.set_builders("site-0002",4).ok,"First staffed F12 transfers four people to first active site")
	_check(not rear.construction.set_builders("site-0003",4).ok,"Unstaffed second F12 cannot create four extra site workers")
	_check(rear.construction.set_office_staff("site-0001",4).ok,"Second F12 requests its own four physical people")
	rear.advance_time(150)
	_check(rear.construction.set_builders("site-0003",4).ok,"Staffed second F12 transfers four distinct people to second site")
	_check(rear.construction._site_members("site-0002").size() == 4 and rear.construction._site_members("site-0003").size() == 4,"Eight distinct people split across two sites; each site's limit remains four")
	_check(not rear.construction.request_dismantle("site-0001").ok,"F12 cannot dismantle while its real staff serve a site")
	_check(rear.construction.set_office_staff("site-0001",0).ok,"Reducing F12 staff recalls its same site builders")
	_check(rear.construction._site_members("site-0003").is_empty(),"No ghost second-site work after F12 recall")
	_check(rear.construction.set_office_staff("site-0001",4).ok,"Second F12 can restaff after recall")
	rear.advance_time(150)
	_check(rear.construction.set_builders("site-0003",4).ok,"Recalled real builders return to second site")
	var manually_reassigned: String = rear.construction._site_members("site-0002")[0]
	_check(rear.reassign_person(manually_reassigned,"Available").ok,"Player may safely reassign one site builder")
	_check(rear.construction._site_members("site-0002").size() == 3,"Reassigned person immediately stops counting as site work")
	rear.advance_time(150)
	_check(rear.construction.set_builders("site-0002",4).ok,"Original F12 refills with another real person before site restaffing")
	rear.ledger.add_stock("two-sites-m11","M11",250,1.0,"depot",rear.PLAYER)
	rear.construction.order_materials("site-0002","depot")
	rear.construction.order_materials("site-0003","depot")
	rear.advance_time(1250)
	_check(rear.construction.instances["site-0002"].state == "Complete" and rear.construction.instances["site-0003"].state == "Complete","Both staffed offices support concurrent physical builds")
	_check(rear.construction._site_members("site-0002").is_empty() and rear.construction._site_members("site-0003").is_empty(),"Completed site builders return to their own offices")
	_check(base.audit().is_empty(),"Two-office shared identity and capacity invariants: "+str(base.audit()))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _staff_initial_office(rear: RefCounted, count: int = 4) -> void:
	_check(rear.construction.set_office_staff("construction",count).ok,"Initial F12 requests actual builder staff")
	rear.advance_time(150)
	_check(rear._present("construction") >= count,"Actual F12 builders report before site transfer")
