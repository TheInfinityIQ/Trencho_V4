extends GdUnitTestSuite
## Pure preparation and physical freight components; explicit stepping is not FPS evidence.
const Opening = preload("res://game/scenario/farmland_session.gd")
const Base = preload("res://game/rear_base/base_simulation.gd")
const Start = preload("res://game/scenario/battlefield_start.gd")
const Resupply = preload("res://game/battlefield/opening_resupply.gd")
const Probe = preload("res://game/diagnostics/tests/gdunit/fixtures/ui_action_probe.gd")
var _watchdog: Node

func before_test() -> void:
	_watchdog = Probe.new()
	add_child(_watchdog)
	_watchdog.action = {"label":"Forward supply/planning component: not a native FPS observation"}

func after_test() -> void:
	_watchdog.queue_free()
	await get_tree().process_frame

func _ready_route(transport: RefCounted, key: String) -> void:
	for _step in 2000:
		# Synthetic pure preparation can group chunks. Runtime frame scheduling
		# is verified separately by the unchanged native placement benchmark.
		for _chunk in 16:
			transport.pump_planning(false,128,4000)
			if transport.planning_status(key).state != "Pending": break
		if transport.planning_status(key).state != "Pending": break
		await get_tree().process_frame
	assert_str(transport.planning_status(key).state).override_failure_message(str(transport.planning_status(key))).is_equal("Ready")

func test_paused_preparation_is_pure_and_stale_fuel_cannot_admit_reposition() -> void:
	var model: RefCounted = Opening.create_empty_field(true)
	var rear: RefCounted = model.rear
	var policy: RefCounted = rear.battlefield_operations.policy
	var key: String = policy._reposition_request
	assert_str(key).is_not_empty()
	var transport: RefCounted = rear.forward_supply.transport
	var before: Dictionary = rear.ledger.snapshot()
	var jobs_before: Dictionary = rear.military.troop_transport.jobs.duplicate(true)
	await _ready_route(transport,key)
	assert_dict(rear.ledger.snapshot()).is_equal(before)
	assert_dict(rear.military.troop_transport.jobs).is_equal(jobs_before)
	assert_float(rear.time).is_equal(0.0)
	var request: Dictionary = transport._plans[key]
	assert_bool(transport.request_deferred(key,request.hull,"",0,"different-stop",request.out,request.home,"","",true).ok).is_false()
	assert_bool(rear.ledger.burn_vehicle_fuel(request.hull,1.0).ok).is_true()
	var changed: Dictionary = rear.ledger.snapshot()
	assert_bool(transport.pump_planning(true,128,4000)).is_false()
	assert_str(transport.planning_status(key).state).is_equal("Blocked")
	assert_dict(rear.ledger.snapshot()).is_equal(changed)
	assert_dict(rear.military.troop_transport.jobs).is_equal(jobs_before)

func test_prepared_reposition_admits_one_real_job_and_repeated_pump_cannot_duplicate() -> void:
	var model: RefCounted = Opening.create_empty_field(true)
	var rear: RefCounted = model.rear
	var transport: RefCounted = rear.forward_supply.transport
	var key: String = rear.battlefield_operations.policy._reposition_request
	await _ready_route(transport,key)
	var count_before: int = rear.military.troop_transport.jobs.size()
	assert_bool(transport.pump_planning(true,128,4000)).is_true()
	var admitted: Dictionary = transport.planning_status(key)
	assert_str(admitted.state).is_equal("Admitted")
	assert_int(rear.military.troop_transport.jobs.size()).is_equal(count_before+1)
	assert_str(rear.military.troop_transport.jobs[admitted.job].state).is_equal("Outbound")
	assert_bool(transport.pump_planning(true,128,4000)).is_false()
	assert_int(rear.military.troop_transport.jobs.size()).is_equal(count_before+1)

func test_automatic_freight_and_engineer_issue_restore_real_rounds_twice() -> void:
	# Declared component arrangement before observation: actual starting armies,
	# stopped T01 at HQ, Engineer and one Rifle element at a separate forward stop.
	# No battlefield AI is installed in this component; normal-session acceptance
	# must separately demonstrate autonomous movement and combat consequences.
	var model := Base.new(false,true,false,Vector2(2000,450),false,{},true)
	var rear: RefCounted = model.rear
	var ledger: RefCounted = rear.ledger
	var armies: Dictionary = Start.apply(model)
	for army in armies.values():
		for hull in army.hulls: assert_bool(rear.military.attach_initial_vehicle(hull.id,hull.parent).ok).is_true()
	var blue: Dictionary = armies[rear.PLAYER]
	var truck: String = blue.hulls[2].id
	var at := Vector2(2000,700)
	assert_bool(ledger.move_entity(truck,"hq-berth",rear.dispatch.hq_position).ok).is_true()
	assert_bool(ledger.add_place("freight-component-stop","Declared component destination",at).ok).is_true()
	assert_bool(rear.forward_supply.register_delivery_stop("freight-component-stop",[rear.dispatch.hq_position,at],[at,rear.dispatch.hq_position]).ok).is_true()
	for squad_id in [blue.rifles[0],blue.engineer]:
		for id in rear.military.squads[squad_id].roster:
			assert_bool(ledger.move_entity(id,"freight-component-stop",at+Vector2(3,0)).ok).is_true()
	var recipient: String = rear.military.squads[blue.rifles[0]].roster[0]
	var supply := Resupply.new(rear,[blue.rifles[0]],blue.engineer,"freight-component-stop")
	supply.automatic_deliveries = true
	var transport: RefCounted = rear.forward_supply.transport
	var initial_hq: int = ledger.available_stock_at("hq-stock","E02")
	var initial_fuel: float = ledger.inspect_entity(truck).fuel
	rear.military.troop_transport.incremental_planning = true
	var interrupted_departure := false
	for cycle in 2:
		# Physical depletion is the component stimulus, recorded by the ledger.
		for stock in ledger.entities_at(recipient,["STOCK"],false):
			if stock.design_type == "E02" and stock.holder_id == recipient and stock.quantity > 0:
				var spent: Dictionary = ledger.record_consumption(stock.id,int(stock.quantity),"Component ammunition expenditure")
				assert_bool(spent.ok).override_failure_message(str(spent)).is_true()
		for _round in ledger.loaded_rounds(recipient+"-rifle"):
			assert_bool(ledger.fire_loaded_round(recipient+"-rifle").ok).is_true()
		assert_int(rear.military._rounds(recipient)).is_equal(0)
		for _step in 400:
			supply.tick()
			for job in transport.jobs.values():
				if not interrupted_departure and job.state == "Planning Route":
					assert_bool(transport.interrupt_delivery(job.id).ok).is_true()
					var stopped: Dictionary = ledger.snapshot()
					for _chunk in 5: transport.pump_planning(false,128,4000)
					assert_dict(ledger.snapshot()).is_equal(stopped)
					assert_str(job.state).is_equal("Paused")
					assert_bool(transport.resume_delivery(job.id).ok).is_true()
					interrupted_departure = true
			for _chunk in 20: transport.pump_planning(true,128,4000)
			rear.advance_time(1.0)
			await get_tree().process_frame
			if rear.military._rounds(recipient) == 60 and transport.jobs.size() == cycle+1 and transport.jobs.values()[-1].state == "Complete": break
		assert_int(rear.military._rounds(recipient)).override_failure_message(str(supply.snapshot())+" / "+str(transport.jobs)).is_equal(60)
		assert_int(transport.jobs.size()).is_equal(cycle+1)
		assert_int(ledger.available_stock_at("hq-stock","E02")).is_equal(initial_hq-60*(cycle+1))
		assert_str(ledger.inspect_entity(truck).holder_id).is_equal("hq-berth")
		for job in transport.jobs.values():
			assert_str(job.hull).is_equal(truck)
			assert_str(job.state).is_equal("Complete")
			assert_int(job.unloaded).is_equal(60)
	assert_float(ledger.inspect_entity(truck).fuel).is_less(initial_fuel)
	assert_bool(interrupted_departure).is_true()
	assert_array(rear.audit()).is_empty()

func test_pending_walk_is_pure_rejects_moved_person_and_admits_current_order() -> void:
	var model: RefCounted = Opening.create_empty_field(true)
	var rear: RefCounted = model.rear
	# Explicit component stimulus: normal order propagation and AI decisions.
	rear.advance_time(6.0)
	var execution: RefCounted = rear.battlefield_operations
	assert_bool(execution.has_planning_work()).is_true()
	for _decision in 100:
		if not execution.has_due_decisions(): break
		execution.pump_planning(true,128,4000)
	assert_bool(execution.has_due_decisions()).is_false()
	var id := ""
	for candidate in execution.motions:
		if execution.motions[candidate].get("pending",false): id = candidate; break
	assert_str(id).is_not_empty()
	if id.is_empty(): return
	var motion: Dictionary = execution.motions[id]
	var before: Dictionary = rear.ledger.snapshot()
	for _chunk in 2000:
		execution.pump_planning(false,128,4000)
		if motion.work != null and motion.work.done: break
		await get_tree().process_frame
	assert_bool(motion.pending).is_true()
	assert_bool(motion.work != null and motion.work.done and motion.work.result.ok).is_true()
	assert_dict(rear.ledger.snapshot()).is_equal(before)
	var person: Dictionary = rear.ledger.inspect_entity(id)
	assert_bool(rear.ledger.move_entity(id,person.holder_id,person.position+Vector2(1,0)).ok).is_true()
	var moved: Dictionary = rear.ledger.snapshot()
	assert_bool(execution.pump_planning(true,128,4000)).is_false()
	assert_bool(execution.motions.has(id)).is_false()
	assert_dict(rear.ledger.snapshot()).is_equal(moved)
	# A fresh request follows the same acknowledged order from the new position.
	execution._walk(id,motion.place,motion.destination,motion.allow_unarmed,motion.purpose)
	var admitted := false
	for _chunk in 4000:
		execution.pump_planning(true,128,4000)
		if not execution.motions.has(id): break
		if execution.motions.has(id) and not execution.motions[id].get("pending",false): admitted = true; break
		await get_tree().process_frame
	assert_bool(admitted).is_true()
	assert_dict(rear.ledger.snapshot()).is_equal(moved)
	if not admitted: return
	var at: Vector2 = rear.ledger.inspect_entity(id).position
	execution.advance_to(rear.time+0.1)
	assert_bool(rear.ledger.inspect_entity(id).position.is_equal_approx(at)).is_false()

func test_due_decisions_remain_queued_while_paused_and_one_running_pump_consumes_one() -> void:
	var model: RefCounted = Opening.create_empty_field(true)
	var rear: RefCounted = model.rear
	rear.advance_time(6.0) # Explicit component time, not a native FPS observation.
	var execution: RefCounted = rear.battlefield_operations
	var pending: int = execution.decision_backlog().pending
	assert_int(pending).is_greater(1)
	var before: Dictionary = rear.ledger.snapshot()
	for _chunk in 5: assert_bool(execution.pump_planning(false,128,4000)).is_false()
	assert_dict(rear.ledger.snapshot()).is_equal(before)
	assert_int(execution.decision_backlog().pending).is_equal(pending)
	assert_bool(execution.pump_planning(true,128,4000)).is_true()
	assert_int(execution.decision_backlog().pending).is_equal(pending-1)

func test_troop_approaches_prepare_without_reservation_and_reject_stale_people() -> void:
	for change in ["position","mass","unchanged"]:
		var model: RefCounted = Opening.create_empty_field(true)
		var rear: RefCounted = model.rear
		rear.advance_time(6.0) # Declared component preparation through actual orders.
		var transport: RefCounted = rear.military.troop_transport
		var key := ""
		for trip in rear.battlefield_operations.policy.trips.values():
			if not str(trip.request).is_empty(): key = trip.request; break
		assert_str(key).is_not_empty()
		if key.is_empty(): return
		var before: Dictionary = rear.ledger.snapshot()
		var attachments: Dictionary = rear.military.vehicles.duplicate(true)
		await _ready_route(transport,key)
		assert_dict(rear.ledger.snapshot()).is_equal(before)
		assert_dict(rear.military.vehicles).is_equal(attachments)
		var request: Dictionary = transport._planning_requests[key]
		assert_int(request.approaches.size()).is_equal(request.capture.people_order.size())
		var masses: Dictionary = rear.ledger.contents_masses(request.capture.people_order)
		for id in request.capture.people_order:
			assert_float(masses[id]).is_equal(rear.ledger.inspect_entity(id).contents_mass_kg)
		if change == "position":
			var person: Dictionary = rear.ledger.inspect_entity(request.capture.people_order[0])
			assert_bool(rear.ledger.move_entity(person.id,person.holder_id,person.position+Vector2(1,0)).ok).is_true()
		elif change == "mass":
			var id: String = request.capture.people_order[0]
			var weapons: Array = rear.ledger.entities_at(id,["WEAPON"],false)
			assert_bool(rear.ledger.fire_loaded_round(weapons[0].id).ok).is_true()
			assert_float(rear.ledger.contents_masses([id])[id]).is_less(masses[id])
		var admission_before: Dictionary = rear.ledger.snapshot()
		var jobs_before: int = transport.jobs.size()
		assert_bool(transport.pump_planning(true,128,4000) == (change == "unchanged")).is_true()
		assert_dict(rear.ledger.snapshot()).is_equal(admission_before)
		if change != "unchanged":
			assert_str(transport.planning_status(key).state).is_equal("Blocked")
			assert_int(transport.jobs.size()).is_equal(jobs_before)
			assert_dict(rear.military.vehicles).is_equal(attachments)
		else:
			assert_str(transport.planning_status(key).state).is_equal("Admitted")
			assert_int(transport.jobs.size()).is_equal(jobs_before+1)
			assert_str(transport.jobs[request.job].state).is_equal("Boarding")
			assert_array(transport.jobs[request.job].people).is_not_empty()
