extends GdUnitTestSuite
## Frame coalescing applies only to the already wall-clock-driven live model.
const Counter = preload("res://game/diagnostics/function_call_log.gd")
const Base = preload("res://game/rear_base/base_simulation.gd")
const Opening = preload("res://game/scenario/farmland_session.gd")
const Presentation = preload("res://game/battlefield/battlefield_presentation.gd")
const SlowRear = preload("res://game/diagnostics/tests/gdunit/fixtures/slow_settlement_rear.gd")

func test_00_live_catch_up_pumps_once_per_process_frame_without_losing_elapsed_time() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	var session: Node = game._session
	session.set_physics_process(false)
	session.set_speed(1)
	await get_tree().process_frame
	session.set_speed(1)
	var before := Counter.totals()
	var started := Time.get_ticks_usec()
	var initial: float = session.simulation.rear.time + session.simulation.owed_simulation_seconds
	for catch_up in 5: session._physics_process(1.0/60.0)
	assert_int(int(Counter.totals().get("rear_base/base_simulation.gd::tick_live",0))-int(before.get("rear_base/base_simulation.gd::tick_live",0))).is_equal(1)
	await get_tree().create_timer(0.05).timeout
	session._physics_process(1.0/60.0)
	var elapsed := float(Time.get_ticks_usec()-started)/1000000.0
	var accrued: float = session.simulation.rear.time+session.simulation.owed_simulation_seconds-initial
	assert_float(accrued).is_between(elapsed-0.025,elapsed+0.025)

	var paused: float = session.simulation.rear.time
	session.set_speed(0)
	await get_tree().process_frame
	session._physics_process(1.0/60.0)
	assert_float(session.simulation.rear.time).is_equal(paused)
	var credit: float = session.simulation.rear.time+session.simulation.owed_simulation_seconds
	started = Time.get_ticks_usec()
	session.set_speed(2)
	await get_tree().create_timer(0.04).timeout
	session.set_speed(0)
	elapsed = float(Time.get_ticks_usec()-started)/1000000.0
	accrued = session.simulation.rear.time+session.simulation.owed_simulation_seconds-credit
	assert_float(accrued).is_between(2.0*elapsed-0.025,2.0*elapsed+0.025)
	assert_float(session.simulation.rear.time).is_equal(paused)
	var replacement: RefCounted = Opening.create_empty_field()
	replacement.enable_live_planning()
	session.replace_simulation(replacement)
	before = Counter.totals()
	session._physics_process(1.0/60.0)
	assert_int(int(Counter.totals().get("rear_base/base_simulation.gd::tick_live",0))-int(before.get("rear_base/base_simulation.gd::tick_live",0))).is_equal(1)

func test_01_explicit_delta_models_keep_every_physics_step() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	var session: Node = game._session
	session.set_physics_process(false)
	var model := Base.new(true)
	session.replace_simulation(model)
	session.set_speed(1)
	var before: float = model.rear.time
	for step in 5: session._physics_process(0.01)
	assert_float(model.rear.time-before).is_between(0.049999,0.050001)

func test_02_panel_presentation_retains_elapsed_time_and_cannot_starve_simulation() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var session: Node = runner.scene()._session
	session.set_physics_process(false)
	session.set_speed(1)
	await get_tree().process_frame
	var credit: float = session.simulation.rear.time+session.simulation.owed_simulation_seconds
	var started := Time.get_ticks_usec()
	var before := Counter.totals()
	session.reserve_presentation_frame()
	var first_frame := Engine.get_process_frames()
	session._physics_process(1.0/60.0)
	assert_bool(session._presentation_deferred_last).override_failure_message("The first explicit frame must actually defer presentation work.").is_true()
	assert_int(int(Counter.totals().get("rear_base/base_simulation.gd::tick_live",0))-int(before.get("rear_base/base_simulation.gd::tick_live",0))).is_zero()
	await get_tree().create_timer(0.05).timeout
	await runner.simulate_frames(2)
	assert_int(Engine.get_process_frames()).is_greater(first_frame)
	# Repeated navigation cannot defer consecutive live pumps.
	session.reserve_presentation_frame()
	session._physics_process(1.0/60.0)
	assert_int(int(Counter.totals().get("rear_base/base_simulation.gd::tick_live",0))-int(before.get("rear_base/base_simulation.gd::tick_live",0))).override_failure_message("frames %d -> %d; last pump %d; deferred %s; speed %d" % [first_frame,Engine.get_process_frames(),session._last_live_process_frame,session._presentation_deferred_last,session.simulation.speed]).is_equal(1)
	var elapsed := float(Time.get_ticks_usec()-started)/1000000.0
	var accrued: float = session.simulation.rear.time+session.simulation.owed_simulation_seconds-credit
	assert_float(accrued).is_between(elapsed-0.025,elapsed+0.025)


func test_03_battlefield_markers_preserve_visibility_order_and_immediate_positions() -> void:
	var model: RefCounted = Opening.create_empty_field()
	var rear: RefCounted = model.rear
	var ledger: RefCounted = rear.ledger
	var expected: Array[String] = []
	# Legacy whole-ledger oracle, deliberately separate from the narrow query.
	for entity in ledger.snapshot(false).entities:
		if entity.kind == "PLACE":
			if entity.id == "hq-berth" or rear.objectives.objectives.has(entity.id) or rear.orders.objective_markers.has(entity.id): expected.append(entity.id)
		elif entity.kind == "PERSON" and entity.owner == rear.PLAYER and entity.rear_place != "Occupied": expected.append(entity.id)
		elif entity.kind == "CARRIER" and str(entity.controller).trim_suffix("-hq") == rear.PLAYER: expected.append(entity.id)
	for id in rear.orders.contacts.get("army",{}):
		var report: Dictionary = rear.orders.contact("army",id)
		if not report.is_empty() and report.confidence > 0 and report.position.is_finite() and report.get("class","") not in ["Enemy HQ","Resource","Route Hub","Observation"]: expected.append(id)
	var before: Dictionary = ledger.snapshot(false)
	var markers: Array[Dictionary] = Presentation.markers(rear)
	var actual: Array[String] = []
	var person := ""
	for marker in markers:
		actual.append(marker.id)
		assert_bool(marker.kind in ["PLACE","PERSON","CARRIER","CONTACT"]).is_true()
		if marker.kind == "PERSON":
			assert_str(marker.owner).is_equal(rear.PLAYER)
			if not marker.aboard: person = marker.id
	assert_array(actual).is_equal(expected)
	assert_dict(ledger.snapshot(false)).is_equal(before)
	assert_str(person).is_not_empty()
	var original: Dictionary = ledger.inspect_entity(person,{},false)
	var point: Vector2 = original.position+Vector2(0.2,0.2)
	assert_bool(ledger.move_entity(person,original.holder_id,point).ok).is_true()
	for marker in Presentation.markers(rear):
		if marker.id == person: assert_vector(marker.position).is_equal(point)

func test_04_initial_settlement_over_budget_cannot_starve_positive_elapsed_time() -> void:
	# Deliberately slow component stimulus, not a native FPS observation.
	var rear := SlowRear.new()
	rear.settle_delay_usec = 6000
	for _step in 3:
		var before: float = rear.time
		var result: Dictionary = rear.advance_time(0.1,false,Base.SIMULATION_FRAME_USEC)
		assert_bool(result.ok).is_true()
		assert_float(rear.time-before).override_failure_message("Initial settlement exceeded the unchanged 4 ms allowance, but a positive elapsed-time request must still complete a transaction.").is_between(0.099999,0.100001)
	assert_int(rear.delayed_settlements).is_equal(6)
	var paused: float = rear.time
	rear.advance_time(0.0,false,Base.SIMULATION_FRAME_USEC)
	assert_float(rear.time).is_equal(paused)
	rear.settle_delay_usec = 0
	assert_bool(rear.advance_time(0.025,false,0).ok).is_true()
	assert_float(rear.time-paused).is_between(0.024999,0.025001)
	assert_array(rear.ledger.audit()).is_empty()
	# A real three-metre staff report completes at t=2, inside a ten-second
	# request. The exhausted allowance must yield there, retaining the remainder.
	var reporting := SlowRear.new()
	assert_bool(reporting.ledger.add_place("budget-stop","Declared budget-test duty",Vector2(13,90)).ok).is_true()
	reporting.requests.receiving.place = "budget-stop"
	assert_bool(reporting.add_person("budget-worker").ok).is_true()
	assert_bool(reporting.set_target("receiving",1).ok).is_true()
	assert_str(reporting.actors["budget-worker"].phase).is_equal("Reporting")
	reporting.settle_delay_usec = 6000
	assert_bool(reporting.advance_time(10.0,false,Base.SIMULATION_FRAME_USEC).ok).is_true()
	assert_float(reporting.time).is_equal(2.0)
	assert_str(reporting.actors["budget-worker"].phase).is_equal("Idle")
	assert_vector(reporting.ledger.inspect_person_status("budget-worker").position).is_equal(Vector2(13,90))
	assert_bool(reporting.advance_time(10.0-reporting.time,false,Base.SIMULATION_FRAME_USEC).ok).is_true()
	assert_float(reporting.time).is_equal(10.0)
	assert_array(reporting.ledger.audit()).is_empty()
