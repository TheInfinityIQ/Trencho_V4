extends GdUnitTestSuite
const Budget = preload("res://game/diagnostics/performance_budget.gd")
## Functional read guards plus the opt-in, fail-fast 1x live-menu exerciser.

const Simulation = preload("res://game/rear_base/base_simulation.gd")
const Counter = preload("res://game/diagnostics/function_call_log.gd")
const OriginA = preload("res://game/diagnostics/tests/gdunit/fixtures/call_stack_origin_a.gd")
const OriginD = preload("res://game/diagnostics/tests/gdunit/fixtures/call_stack_origin_d.gd")
const StackTarget = preload("res://game/diagnostics/tests/gdunit/fixtures/call_stack_target.gd")
const ReadScenarios = preload("res://game/diagnostics/tests/gdunit/fixtures/read_path_scenarios.gd")
const Records = preload("res://game/identity/identity_records.gd")


func test_00_call_stacks_group_origins_per_second() -> void:
	# Leave ample room in one real second, regardless of the runner's start time.
	await get_tree().create_timer(float(1000 - Time.get_ticks_msec() % 1000) / 1000.0 + 0.01).timeout
	var previous_capture := Counter.capture_stacks
	Counter.capture_stacks = true
	OriginA.function_a()
	OriginD.function_d()
	OriginA.function_a()
	var window := Counter.current_second()
	Counter.capture_stacks = previous_capture
	var groups: Array = window.stacks.filter(func(group: Dictionary) -> bool: return group.function_id == str(StackTarget.FUNCTION_ID))
	assert_int(int(window.counts.get(StackTarget.FUNCTION_ID, 0))).is_equal(3)
	assert_int(groups.size()).is_equal(2)
	if groups.size() != 2: return
	assert_int(groups[0].count).is_equal(2)
	assert_int(groups[1].count).is_equal(1)
	assert_str(groups[0].chain[-3]).ends_with("call_stack_origin_a.gd::function_a")
	assert_str(groups[1].chain[-3]).ends_with("call_stack_origin_d.gd::function_d")
	for group in groups:
		assert_str(group.chain[-2]).ends_with("call_stack_target.gd::function_b")
		assert_str(group.chain[-1]).ends_with("call_stack_target.gd::function_c")
		assert_bool("game/diagnostics/function_call_log.gd::record" in group.chain).is_false()
	await get_tree().create_timer(1.05).timeout
	var completed: Array = Counter.completed_seconds().filter(func(report: Dictionary) -> bool: return report.second == window.second)
	assert_int(completed.size()).is_equal(1)
	if completed.is_empty(): return
	assert_bool(completed[0].complete).is_true()
	assert_array(completed[0].stacks).is_equal(window.stacks)
	assert_bool(Counter.current_second().counts.has(StackTarget.FUNCTION_ID)).is_false()
	_write_guard("call_stack_grouping", {"window": completed[0], "verified_counts": [2, 1]})


func test_00_call_stacks_can_be_disabled_without_losing_counts() -> void:
	var previous_capture := Counter.capture_stacks
	var before := Counter.totals()
	Counter.capture_stacks = false
	Counter.record(&"diagnostics/test_counts_only")
	var window := Counter.current_second()
	Counter.capture_stacks = previous_capture
	var groups: Array = window.stacks.filter(func(group: Dictionary) -> bool: return group.function_id == "diagnostics/test_counts_only")
	assert_int(int(_difference(Counter.totals(), before).get("diagnostics/test_counts_only", 0))).is_equal(1)
	assert_int(groups.size()).is_equal(0)
	assert_int(window.stack_capture_disabled_calls).is_greater_equal(1)


func test_00_duration_windows_preserve_known_totals() -> void:
	await get_tree().create_timer(float(1000 - Time.get_ticks_msec() % 1000) / 1000.0 + 0.01).timeout
	Counter.record_duration(&"test/timing_scope", 10)
	Counter.record_duration(&"test/timing_scope", 20)
	Counter.record_duration(&"test/timing_scope", 5)
	Counter.record_duration(&"test/timing_scope", -1)
	var window := Counter.current_second()
	assert_int(window.durations_usec[&"test/timing_scope"].calls).is_equal(3)
	assert_int(window.durations_usec[&"test/timing_scope"].total).is_equal(35)
	assert_int(window.durations_usec[&"test/timing_scope"].maximum).is_equal(20)
	assert_bool(window.counts.has(&"test/timing_scope")).is_false()
	await get_tree().create_timer(1.05).timeout
	var reports: Array = Counter.completed_seconds().filter(func(report: Dictionary) -> bool: return report.second == window.second)
	assert_int(reports.size()).is_equal(1)
	if not reports.is_empty(): assert_that(reports[0].durations_usec).is_equal(window.durations_usec)
	assert_bool(Counter.current_second().durations_usec.has(&"test/timing_scope")).is_false()


func test_01_build_and_map_reads_do_not_export_whole_world() -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	game._session.set_speed(1)
	game._navigate("Build")
	await runner.simulate_frames(2)
	var before := Counter.totals()
	var started := Time.get_ticks_usec()
	game._base._refresh()
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var counts := _difference(Counter.totals(), before)
	_write_guard("build_refresh", {"elapsed_ms": elapsed_ms, "counts": counts, "speed": game._base.simulation.speed})
	assert_int(int(counts.get("rear_base/base_simulation.gd::snapshot", 0))).is_equal(0)
	assert_int(int(counts.get("staffing/rear_simulation.gd::snapshot", 0))).is_equal(0)
	assert_int(int(counts.get("identity/identity_ledger.gd::snapshot", 0))).is_equal(0)
	assert_int(int(counts.get("identity/identity_ledger.gd::inspect_entity", 0))).is_less_equal(4)
	assert_float(elapsed_ms).is_less_equal(_setting("TRENCHO_PERF_ACTION_MS", Budget.MAX_ACTION_MS))
	if is_failure(): return
	var ledger: RefCounted = game._base.simulation.rear.ledger
	var expected := {}
	for entity in ledger.snapshot(false).entities:
		if entity.owner != "army-red" and entity.kind in ["PERSON", "CARRIER", "HEAVY_OBJECT", "STOCK"]:
			expected[entity.id] = entity
	before = Counter.totals()
	var markers: Array[Dictionary] = ledger.map_markers()
	counts = _difference(Counter.totals(), before)
	assert_int(int(counts.get("identity/identity_ledger.gd::inspect_entity", 0))).is_equal(0)
	assert_int(markers.size()).is_equal(expected.size())
	for marker in markers:
		assert_bool(expected.has(marker.id)).is_true()
		if not expected.has(marker.id): return
		for field in ["position", "kind", "owner", "holder_id", "quantity"]:
			assert_that(marker[field]).is_equal(expected[marker.id][field])
		if marker.kind == "PERSON": assert_str(marker.carrying_stock_id).is_equal(expected[marker.id].carrying_stock_id)


func test_02_narrow_staffing_queries_preserve_assignments() -> void:
	var simulation: RefCounted = auto_free(Simulation.new(false, true))
	simulation.set_speed(1)
	assert_bool(simulation.rear.set_target("hauling", 3).ok).is_true()
	var rear: RefCounted = simulation.rear
	var people: Array[Dictionary] = []
	for id in rear.actors: people.append(rear.ledger.inspect_person_status(id))
	var before := Counter.totals()
	var actual := {}
	for duty in rear.requests:
		actual[duty] = [rear._assigned(duty), rear._present(duty), rear._pending_in(duty), rear._retaining(duty), rear._committed(duty)]
	var counts := _difference(Counter.totals(), before)
	assert_int(int(counts.get("identity/identity_ledger.gd::inspect_entity", 0))).is_equal(0)
	for duty in rear.requests:
		var expected: Array[int] = [0, 0, 0, 0, 0]
		for person in people:
			if person.duty_id == duty:
				expected[0] += 1
				expected[4] += 1
				if rear.actors[person.id].phase in ["Idle", "Unloading"]: expected[1] += 1
				if person.pending_assignment == "None" or person.pending_duty == duty: expected[3] += 1
			if person.pending_duty == duty:
				expected[4] += 1
				if person.pending_assignment != "None": expected[2] += 1
		assert_array(actual[duty]).is_equal(expected)
	assert_int(rear.ledger.count_rear_people(rear.PLAYER)).is_equal(simulation.receiving.rear_population())
	_write_guard("staffing_queries", {"people": people.size(), "duties": actual.size(), "full_inspections": counts.get("identity/identity_ledger.gd::inspect_entity", 0)})


func test_02a_read_paths_preserve_recorded_gameplay() -> void:
	var previous_enabled := Counter.enabled
	var previous_capture := Counter.capture_stacks
	Counter.enabled = true
	Counter.capture_stacks = false
	var actual: Dictionary = ReadScenarios.run()
	Counter.enabled = previous_enabled
	Counter.capture_stacks = previous_capture
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/diagnostics/tests/gdunit/fixtures/read_path_baseline.json"))
	assert_int(actual.states.size()).is_equal(expected.states.size())
	for name in expected.states:
		assert_bool(actual.states.has(name)).is_true()
		if not actual.states.has(name): return
		assert_str(actual.states[name].sha256).override_failure_message("Behavior changed at checkpoint: " + str(name)).is_equal(expected.states[name].sha256)
		assert_array(actual.states[name].audit).is_empty()
	assert_int(int(actual.states.hq_coarse.tank.ammunition.E25)).is_equal(3)
	assert_float(float(actual.states.hq_coarse.tank.fuel)).is_equal(5.0)
	assert_str(actual.states.hq_coarse.rifle.holder_id).is_equal("read-trained")
	assert_str(actual.states.hq_coarse.sha256).is_equal(actual.states.hq_partitioned.sha256)
	_write_guard("read_path_characterization", actual)


func test_02b_narrow_reads_follow_current_authoritative_fields() -> void:
	var base: RefCounted = auto_free(ReadScenarios.hq_fixture())
	var ledger: RefCounted = base.rear.ledger
	var person: RefCounted = ledger._entities["read-trained"]
	var hull: RefCounted = ledger._entities["read-tank"]
	var original_person_health: int = person.health
	var original_hull_health: int = hull.health
	var before := Counter.totals()
	assert_bool(ledger.person_is_alive("read-trained")).is_true()
	assert_bool(ledger.person_is_alive("read-tank")).is_false()
	assert_bool(ledger.person_is_alive("missing")).is_false()
	assert_bool(ledger.person_has_living_duty("read-trained", "")).is_true()
	assert_bool(ledger.person_has_living_duty("read-trained", "wrong-duty")).is_false()
	assert_str(ledger.person_qualification("missing")).is_empty()
	assert_bool(ledger.person_ready_for_hq_issue("read-trained", base.rear.PLAYER, true)).is_true()
	assert_bool(ledger.person_ready_for_hq_issue("read-untrained", base.rear.PLAYER)).is_true()
	assert_bool(ledger.person_ready_for_hq_issue("read-untrained", base.rear.PLAYER, true)).is_false()
	# Isolated record variations exercise every rejection without fabricating
	# physical gameplay transitions. Restore each field before the next case.
	var variations := {"pending_assignment": Records.Assignment.AVAILABLE, "crew_station": "Driver",
		"owner": "army-red", "health": 0, "assignment": Records.Assignment.AVAILABLE, "holder_id": "depot", "kind": Records.Kind.CARRIER}
	for field in variations:
		var original: Variant = person.get(field)
		person.set(field, variations[field])
		var eligible: bool = ledger.person_ready_for_hq_issue("read-trained", base.rear.PLAYER, true)
		person.set(field, original)
		assert_bool(eligible).override_failure_message("HQ eligibility did not reject field variation: " + str(field)).is_false()
	person.health = 0
	var living: bool = ledger.person_is_alive("read-trained")
	var living_duty: bool = ledger.person_has_living_duty("read-trained", "")
	person.health = original_person_health
	assert_bool(living).is_false()
	assert_bool(living_duty).is_false()
	person.qualification = "P08"
	var generic: bool = ledger.person_ready_for_hq_issue("read-trained", base.rear.PLAYER, true)
	assert_str(ledger.person_qualification("read-trained")).is_equal("P08")
	person.qualification = "None"
	assert_bool(generic).is_false()
	assert_bool(ledger.military_hull_ready_at("read-tank", "hq-berth", base.rear.PLAYER, base.rear.hq.hq_position)).is_true()
	assert_bool(ledger.military_hull_ready_at("read-trained", "hq-berth")).is_false()
	assert_bool(ledger.military_hull_ready_at("missing", "hq-berth")).is_false()
	assert_bool(ledger.military_hull_ready_at("read-tank", "depot")).is_false()
	assert_bool(ledger.military_hull_ready_at("read-tank", "hq-berth", "army-red")).is_false()
	var original_position: Vector2 = hull.position
	hull.position += Vector2(1, 0)
	var at_location: bool = ledger.military_hull_ready_at("read-tank", "hq-berth", base.rear.PLAYER, base.rear.hq.hq_position)
	var at_holder: bool = ledger.military_hull_ready_at("read-tank", "hq-berth")
	hull.position = original_position
	assert_bool(at_location).is_false()
	assert_bool(at_holder).is_true()
	hull.health = 0
	var healthy_hull: bool = ledger.military_hull_ready_at("read-tank", "hq-berth")
	hull.health = original_hull_health
	assert_bool(healthy_hull).is_false()
	assert_int(int(_difference(Counter.totals(), before).get("identity/identity_ledger.gd::inspect_entity", 0))).is_equal(0)
	assert_bool(ledger.add_weapon("probe-held-rifle", "E01", 4.0, "read-trained", base.rear.PLAYER, "E02", 30).ok).is_true()
	assert_bool(ledger.add_stock("probe-loose", "E02", 7, 0.02, "read-trained", base.rear.PLAYER).ok).is_true()
	assert_bool(ledger.add_stock("probe-to-load", "E02", 5, 0.02, "read-trained", base.rear.PLAYER).ok).is_true()
	assert_bool(ledger.load_rounds("probe-held-rifle", "probe-to-load", 5).ok).is_true()
	assert_bool(ledger.request_stock("probe-claim", "probe-loose", 2, "probe", "physical count check", base.rear.PLAYER).ok).is_true()
	assert_bool(ledger.has_weapon_at("read-trained", "E01")).is_true()
	assert_bool(ledger.has_weapon_at("read-untrained", "E01")).is_false()
	assert_int(ledger.personal_ammunition_count("read-trained", "E02")).is_equal(12)
	assert_int(ledger.personal_ammunition_count("read-untrained", "E02")).is_equal(0)


func test_02c_hot_checks_avoid_full_entity_exports() -> void:
	var previous_capture := Counter.capture_stacks
	Counter.capture_stacks = false
	var world: RefCounted = auto_free(ReadScenarios.Opening.create_empty_field())
	for _frame in 120: world.tick(1.0 / 60.0)
	var world_counts: Dictionary = ReadScenarios.measure_checks(world)
	var base: RefCounted = auto_free(ReadScenarios.hq_fixture())
	base.rear.advance_time(60)
	var hq_counts: Dictionary = ReadScenarios.measure_checks(base)
	Counter.capture_stacks = previous_capture
	for label in world_counts:
		assert_int(world_counts[label].full_inspections).override_failure_message("Default-world check exported full entities: " + str(label)).is_equal(0)
	assert_int(hq_counts.commander.full_inspections).is_equal(0)
	assert_int(hq_counts.auto_vehicle.full_inspections).is_less_equal(100)
	assert_int(hq_counts.hq_auto_issue.full_inspections).is_less_equal(100)
	_write_guard("read_path_costs", {"world": world_counts, "hq": hq_counts})


func test_02d_sight_candidates_preserve_real_contact_reports() -> void:
	var base: RefCounted = auto_free(ReadScenarios.Opening.create_empty_field())
	var rear: RefCounted = base.rear
	var own_squad := ""
	for row in rear.military.squads.values():
		if row.state == "Active" and row.get("owner", rear.PLAYER) == rear.PLAYER:
			own_squad = row.id
			break
	assert_str(own_squad).is_not_empty()
	if own_squad.is_empty(): return
	var observer: Dictionary = rear.ledger.inspect_person_status(rear.military.squads[own_squad].leader)
	assert_bool(rear.ledger.add_place("sight-fixture-place", "Sight fixture", observer.position + Vector2(1, 0)).ok).is_true()
	assert_bool(rear.ledger.add_person("sight-enemy", "sight-fixture-place", "army-red", Records.Assignment.AVAILABLE, true).ok).is_true()
	assert_bool(rear.ledger.add_person("sight-friendly", "sight-fixture-place", rear.PLAYER, Records.Assignment.AVAILABLE, true).ok).is_true()
	var enemy: RefCounted = rear.ledger._entities["sight-enemy"]
	for assignment in [Records.Assignment.AVAILABLE, Records.Assignment.RECOVERY, Records.Assignment.WOUNDED, Records.Assignment.DEAD]:
		enemy.assignment = assignment
		var full: Array = rear.ledger.snapshot(false).entities
		var before := Counter.totals()
		var candidates: Array = rear.ledger.sight_candidates()
		assert_int(int(_difference(Counter.totals(), before).get("identity/identity_ledger.gd::inspect_entity", 0))).is_equal(0)
		var full_by_id := {}
		for item in full: full_by_id[item.id] = item
		var expected_count := 0
		for item in full:
			if item.kind in ["PERSON", "CARRIER"]: expected_count += 1
		assert_int(candidates.size()).is_equal(expected_count)
		for item in candidates:
			for field in item: assert_that(item[field]).is_equal(full_by_id[item.id][field])
		var legacy := _sample_contacts(base, full)
		var narrow := _sample_contacts(base, candidates)
		assert_that(narrow).override_failure_message("Contact output changed for assignment " + str(assignment)).is_equal(legacy)
		if assignment == Records.Assignment.AVAILABLE:
			assert_bool(legacy.visible[own_squad].has("sight-enemy")).is_true()
			assert_bool(legacy.visible[own_squad].has("sight-friendly")).is_false()
	_write_guard("sight_candidate_parity", {"assignment_cases": 4, "positive_enemy_contact_checked": true})


func _sample_contacts(base: RefCounted, entities: Array) -> Dictionary:
	var orders: RefCounted = base.rear.orders
	var original_visible: Dictionary = orders.visible.duplicate(true)
	var original_pending: Array = orders.pending.duplicate(true)
	var original_watch: Dictionary = orders.watch_squads.duplicate(true)
	orders.visible = {}
	orders.pending.clear()
	for id in original_watch: orders._sample_squad(id, entities)
	orders._sample_apc_elements(entities)
	var result := {"visible": orders.visible.duplicate(true), "pending": orders.pending.duplicate(true)}
	orders.visible = original_visible
	orders.pending.assign(original_pending)
	orders.watch_squads = original_watch
	return result


func test_02e_patient_search_matches_canonical_selection() -> void:
	var base: RefCounted = auto_free(Simulation.new())
	var ledger: RefCounted = base.rear.ledger
	assert_bool(ledger.add_place("care-center", "Care fixture", Vector2(100, 100)).ok).is_true()
	assert_bool(ledger.add_place("care-edge", "Care boundary", Vector2(160, 100)).ok).is_true()
	assert_bool(ledger.add_place("care-outside", "Outside care", Vector2(160.01, 100)).ok).is_true()
	for id in ["near", "edge", "outside", "enemy", "healthy", "dead"]:
		var owner: String = "army-red" if id == "enemy" else base.rear.PLAYER
		var place: String = "care-edge" if id == "edge" else ("care-outside" if id == "outside" else "care-center")
		assert_bool(ledger.add_person("care-patient-" + id, place, owner).ok).is_true()
		var person: RefCounted = ledger._entities["care-patient-" + id]
		person.assignment = Records.Assignment.AVAILABLE if id == "healthy" else Records.Assignment.WOUNDED
		person.health = 0 if id == "dead" else 35
	var expected: Array[String] = []
	for person in ledger.entities_of_kind(Records.Kind.PERSON, false):
		if person.owner == base.rear.PLAYER and person.assignment == "Wounded" and person.health > 0 and person.position.distance_to(Vector2(100, 100)) <= 60:
			expected.append(person.id)
	var before := Counter.totals()
	var selected: Array = ledger.wounded_people_near(base.rear.PLAYER, Vector2(100, 100), 60.0)
	var ids: Array[String] = []
	for person in selected: ids.append(person.id)
	assert_array(ids).is_equal(expected)
	assert_array(ids).is_equal(["care-patient-near", "care-patient-edge"])
	assert_int(int(_difference(Counter.totals(), before).get("identity/identity_ledger.gd::inspect_entity", 0))).is_equal(2)


func test_03_observe_live_menu_actions_at_one_x(timeout: int = 900000) -> void:
	var runner := scene_runner("res://game/diagnostics/menu_performance_suite.tscn")
	var suite: Control = runner.scene()
	var destination := OS.get_environment("TRENCHO_PERF_RUN_DIRECTORY")
	if not destination.is_empty(): suite._requested_run_dir = destination
	suite._engine_log_source = OS.get_environment("TRENCHO_PERF_ENGINE_LOG")
	suite.maximum_frame_ms = _setting("TRENCHO_PERF_FRAME_MS", Budget.MAX_FRAME_MS)
	suite.maximum_action_ms = _setting("TRENCHO_PERF_ACTION_MS", Budget.MAX_ACTION_MS)
	suite.observation_seconds = _setting("TRENCHO_PERF_OBSERVATION_SECONDS", 2.0)
	suite.inspect_calls_per_second_budget = int(_setting("TRENCHO_PERF_CALL_BUDGET", 30000))
	suite._start_suite()
	if suite.run_status == "log_setup_failed":
		fail("Performance logs could not be created.")
		return
	var outcome: Array = await suite.run_finished
	assert_int(suite._game._base.simulation.speed).is_equal(0)
	assert_bool(suite._game._session.is_physics_processing()).is_false()
	assert_str(str(outcome[0])).override_failure_message("Performance run stopped at %s. Inspect %s/failure.json and summary.json; untested actions are not passes." % [suite._action.get("label", "startup"), outcome[1]]).is_equal("completed_with_coverage_report")


func _setting(name: String, fallback: float) -> float:
	var value := OS.get_environment(name)
	var setting := fallback if value.is_empty() else float(value)
	if name == "TRENCHO_PERF_FRAME_MS": return Budget.capped_limit(setting,Budget.MAX_FRAME_MS)
	if name == "TRENCHO_PERF_ACTION_MS": return Budget.capped_limit(setting,Budget.MAX_ACTION_MS)
	return setting


func _difference(current: Dictionary, previous: Dictionary) -> Dictionary:
	var counts := {}
	for name in current:
		var difference := int(current[name]) - int(previous.get(name, 0))
		if difference > 0: counts[str(name)] = difference
	return counts


func _write_guard(name: String, details: Dictionary) -> void:
	var directory := OS.get_environment("TRENCHO_PERF_RUN_DIRECTORY")
	if directory.is_empty(): return
	var file := FileAccess.open(directory.path_join(name + ".json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(details, "\t") + "\n")
