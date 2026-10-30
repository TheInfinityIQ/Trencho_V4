extends SceneTree
## Combined G22/G24 regression: paid armed initial devices, real coupled movement.
const Fixture = preload("res://game/vehicle_recovery/recovery_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_tow_contact(false)
	_tow_contact(true)
	_rotated_blast()
	print("G22/G24 recovery mine regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _armed(rear: RefCounted, position: Vector2) -> String:
	# Initial scenario supply is paid once; G22 separately verifies placement/arming.
	var id := "integration-pressure-mine"
	rear.ledger.add_place(id,"Declared armed enemy device",position)
	rear.ledger.add_stock(id+"-supply","M06",3,1.0,id,"army-red")
	var paid: Dictionary = rear.ledger.consume_local_batch(id,"army-red",{"M06":3},"Declared armed initial device")
	expect(paid.ok,"armed scenario device has actual consumed explosives")
	rear.mines.projects[id] = {"id":id,"code":"D02","kind":"D02","position":position,"place":id,"squad":"","engineer":"","owner":"army-red","state":"Armed","progress":12.0,"work_required":12.0,"m06_reserved":3,"m06_consumed":3,"claims":[],"receipt":paid.receipt,"health":20,"armed_at":rear.time,"controller":"","blocked_reason":""}
	return id

func _tow_contact(trailing: bool) -> void:
	var fixture := Fixture.new()
	var rear: RefCounted = fixture.base.rear
	var ledger: RefCounted = rear.ledger
	rear.combat.world.paint(Rect2i(170,40,100,20),"TR02")
	ledger.move_entity("tractor","tractor-ground",Vector2(200,50))
	ledger.move_entity("tow","tow-ground",Vector2(188,50))
	ledger.move_entity("repairer","repairer-ground",Vector2(200,53))
	if not trailing: ledger.apply_vehicle_surface_damage("tractor",600,999,"Side","Prior damage leaves600hull")
	expect(rear.recovery.start_coupling("tractor","tow","repairer").ok,"real engineer starts combined-case coupling")
	rear.advance_time(20)
	var mine := _armed(rear,Vector2(194,50) if trailing else Vector2(208,50))
	var start: Dictionary = ledger.snapshot()
	var fuel: float = ledger.inspect_entity("tractor").fuel
	var lane: Dictionary = rear.recovery.start_tow_route("tractor",Vector2(240,50))
	expect(lane.ok,"uninformed tractor may start real lane past unknown device")
	if not lane.ok: return
	rear.advance_time(lane.seconds)
	var lead: Dictionary = ledger.inspect_entity("tractor")
	var target: Dictionary = ledger.inspect_entity("tow")
	var distance: float = lead.position.distance_to(Vector2(200,50))
	var expected_burn: float = distance*12.0/1000.0 # T05 six road units/km, doubled for towing.
	expect(rear.mines.inspect(mine).state == "Detonated","actual swept contact detonates exactly one device")
	expect(is_equal_approx(float(ledger.snapshot().fuel_burned)-float(start.fuel_burned),expected_burn),"fuel charged only for real contact-prefix tractor travel")
	expect(not rear.recovery.journeys.tractor.blocked_reason.is_empty(),"mine contact holds the interrupted coupled journey")
	if trailing:
		expect(absf(lead.position.x-200.25) < 0.001 and absf(target.position.x-188.25) < 0.001,"trailing footprint contact limits both actual bodies before tractor overshoots")
		expect(target.health == 450 and lead.health == 1200,"only trailing tank takes the actual bottom hit")
		expect(is_equal_approx(lead.fuel,fuel-expected_burn),"surviving tractor retains all untravelled fuel")
	else:
		expect(absf(lead.position.x-202.25) < 0.001 and lead.health == 0,"tractor destruction occurs at actual front-footprint contact")
		expect(target.position.x <= lead.position.x-12.0+0.001 and lead.towing.is_empty() and target.towed_by.is_empty(),"destruction uncouples without moving the stale trailing snapshot")
		expect(is_equal_approx(float(ledger.snapshot().fuel_lost)-float(start.fuel_lost),fuel-expected_burn),"only remaining fuel is lost after prefix travel was charged")
		for station in ["Driver","Gunner","Loader","Commander"]:
			var person: Dictionary = ledger.inspect_entity("tractor-"+station)
			expect(person.health == 40 and person.holder_id != "tractor","mine destruction ejects each actual crew member with one60injury: "+station)
		var resolved := 0
		for event in rear.recovery.events:
			if event.hull == "tractor" and event.kind == "Destroyed": resolved += 1
		expect(resolved == 1,"synchronous mine damage has one authoritative destruction outcome")
	var lead_position: Vector2 = lead.position
	var target_position: Vector2 = target.position
	rear.advance_time(20)
	expect(ledger.inspect_entity("tractor").position == lead_position and ledger.inspect_entity("tow").position == target_position,"later clock advance cannot move either stopped body")
	expect(fixture.base.audit().is_empty(),"combined mine/tow identities stock and fuel reconcile: "+str(fixture.base.audit()))

func _rotated_blast() -> void:
	var fixture := Fixture.new()
	var rear: RefCounted = fixture.base.rear
	var ledger: RefCounted = rear.ledger
	ledger.move_entity("tractor","tractor-ground",Vector2(200,50))
	ledger.set_vehicle_facing("tractor",90.0)
	var mine := _armed(rear,Vector2(200,57))
	rear.mines._detonate(rear.mines.projects[mine])
	expect(ledger.inspect_entity("tractor").health == 996,"stationary rotated hull uses actual long-axis distance for secondary bottom blast")
	expect(fixture.base.audit().is_empty(),"rotated secondary blast reconciles shared state")
