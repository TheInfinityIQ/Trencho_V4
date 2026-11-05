extends GdUnitTestSuite
## Independent state, parity and detached-data guards for a bounded Train read slice.
const Scenarios = preload("res://game/diagnostics/tests/gdunit/fixtures/training_read_scenarios.gd")
const Counter = preload("res://game/diagnostics/function_call_log.gd")
const Safe = preload("res://game/diagnostics/tests/gdunit/fixtures/read_path_scenarios.gd")

func test_00_characterize_training_reads_without_hidden_owner_mutations() -> void:
	var report := {}
	for label in Scenarios.labels():
		var old: RefCounted = Scenarios.fixture(label)
		var current: RefCounted = Scenarios.fixture(label)
		var selected: String = "" if old.rear.training.rows.is_empty() else old.rear.training.rows[-1].id
		var before: Dictionary = Scenarios.raw_state(old)
		assert_str(Scenarios.fingerprint(Scenarios.raw_state(current))).is_equal(Scenarios.fingerprint(before))
		var legacy: Dictionary = old.snapshot(false, false)
		legacy.rear_population = old.receiving.rear_population()
		legacy.training_selected_person = Scenarios.selected_person(old, selected)
		var actual: Dictionary = Scenarios.read_view(current, selected)
		assert_dict(Scenarios.display_values(actual)).override_failure_message("Train display parity: " + label).is_equal(Scenarios.display_values(legacy))
		assert_str(Scenarios.fingerprint(Scenarios.raw_state(current))).override_failure_message("Omitted exporter side effects: " + label).is_equal(Scenarios.fingerprint(Scenarios.raw_state(old)))
		var once: Dictionary = Scenarios.raw_state(current)
		Scenarios.read_view(current, selected)
		assert_str(Scenarios.fingerprint(Scenarios.raw_state(current))).override_failure_message("Repeated reads must stabilize: " + label).is_equal(Scenarios.fingerprint(once))
		report[label] = {"before":Scenarios.fingerprint(before), "after":Scenarios.fingerprint(once),
			"display":Scenarios.fingerprint(Scenarios.display_values(actual)), "counts":actual.training.counts,
			"time":current.rear.time, "normalization_changed_state":Scenarios.fingerprint(before) != Scenarios.fingerprint(once)}
		assert_array(old.audit()).is_empty()
		assert_array(current.audit()).is_empty()
	_save("training_read_characterization.json", {"path":"training_view" if Scenarios.Base.new().has_method("training_view") else "legacy_broad", "states":report})

func test_01_snapshot_normalization_is_characterized_before_purity_migration() -> void:
	var old: RefCounted = Scenarios.fixture("active")
	var current: RefCounted = Scenarios.fixture("active")
	# A stale presentation reason models a read before its next reconciliation.
	# It must normalize identically today; it is not a legitimate domain command.
	for base in [old, current]: base.rear.training.rows[0].reason = "stale presentation reason"
	var before: Dictionary = Scenarios.raw_state(current)
	old.snapshot(false, false)
	Scenarios.read_view(current)
	assert_bool(Scenarios.fingerprint(before) != Scenarios.fingerprint(Scenarios.raw_state(current))).is_true()
	assert_str(Scenarios.fingerprint(Scenarios.raw_state(current))).is_equal(Scenarios.fingerprint(Scenarios.raw_state(old)))

func test_02_train_reads_are_detached_and_missing_selection_is_safe() -> void:
	var base: RefCounted = Scenarios.fixture()
	var selected: String = base.rear.training.rows[0].id
	var view: Dictionary = Scenarios.read_view(base, selected)
	var before: Dictionary = Scenarios.raw_state(base)
	view.training.rows[0].work = -999
	view.training.training_sites[0].active = false
	view.training.courses.P01.seconds = -1
	view.training_selected_person.qualification = "fake"
	view.rear.stores.clear()
	assert_str(Scenarios.fingerprint(Scenarios.raw_state(base))).is_equal(Scenarios.fingerprint(before))
	assert_dict(Scenarios.read_view(base, "missing-course").training_selected_person).is_empty()
	assert_float(Scenarios.read_view(base, selected).training.rows[0].work).is_greater_equal(0)

func test_03_read_order_preserves_withdrawal_progress_and_no_ui_outcomes() -> void:
	var observed: RefCounted = Scenarios.fixture()
	var unseen: RefCounted = Scenarios.fixture()
	for step in 4:
		Scenarios.read_view(observed)
		observed.rear.advance_time(7.5)
		unseen.rear.advance_time(7.5)
	assert_str(Scenarios.fingerprint(Scenarios.raw_state(observed))).is_equal(Scenarios.fingerprint(Scenarios.raw_state(unseen)))
	for base in [observed, unseen]:
		base.rear.training.withdraw(base.rear.training.rows[0].id)
		base.rear.advance_time(200)
	Scenarios.read_view(observed)
	assert_str(Scenarios.fingerprint(Scenarios.raw_state(observed))).is_equal(Scenarios.fingerprint(Scenarios.raw_state(unseen)))
	assert_str(observed.rear.training.rows[0].state).is_equal("Withdrawn")
	assert_bool(observed.rear.ledger.inspect_entity(observed.rear.training.rows[0].person_id).basic_training).is_false()

func test_04_train_read_measurements() -> void:
	var base: RefCounted = Scenarios.fixture()
	Scenarios.read_view(base)
	var before: Dictionary = Counter.totals()
	var timings: Array[float] = []
	for repeat in 30:
		var started := Time.get_ticks_usec()
		Scenarios.read_view(base)
		timings.append(float(Time.get_ticks_usec() - started) / 1000.0)
	_save("training_read_micro.json", {"repeats":timings.size(), "milliseconds":timings, "counts":_difference(Counter.totals(), before),
		"mode":"fresh uncached reads; counters only when enabled; elapsed call time is not CPU self time"})

func test_05_frozen_pre_change_training_states_and_display_values() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/diagnostics/tests/gdunit/fixtures/training_read_baseline.json"))
	for label in baseline.states:
		var base: RefCounted = Scenarios.fixture(label)
		var selected: String = "" if base.rear.training.rows.is_empty() else base.rear.training.rows[-1].id
		var before: Dictionary = Scenarios.raw_state(base)
		assert_str(Scenarios.fingerprint(Scenarios.frozen_baseline_projection(before))).override_failure_message("Frozen pre-query state: " + label).is_equal(baseline.states[label].before)
		var view: Dictionary = Scenarios.read_view(base, selected)
		var after: Dictionary = Scenarios.raw_state(base)
		assert_str(Scenarios.fingerprint(Scenarios.frozen_baseline_projection(after))).override_failure_message("Frozen post-query state: " + label).is_equal(baseline.states[label].after)
		assert_str(Scenarios.fingerprint(after)).override_failure_message("Full current-state query purity: "+label).is_equal(Scenarios.fingerprint(before))
		assert_str(Scenarios.fingerprint(Scenarios.display_values(view))).override_failure_message("Frozen display facts: " + label).is_equal(baseline.states[label].display)
		if OS.get_environment("TRENCHO_CAPTURE_TRAINING_STATE") == "1":
			_save("training_frozen_"+label+".json",{"before":before,"after":after,"display":Scenarios.display_values(view),"before_hash":Scenarios.fingerprint(before),"after_hash":Scenarios.fingerprint(after)})

func test_06_train_view_avoids_world_exports_and_domain_commands() -> void:
	var base: RefCounted = Scenarios.fixture()
	assert_bool(base.has_method("training_view")).is_true()
	if not base.has_method("training_view"): return
	var before := Counter.totals()
	var view: Dictionary = base.training_view(base.rear.training.rows[0].id)
	var counts := _difference(Counter.totals(), before)
	for id in ["rear_base/base_simulation.gd::snapshot", "staffing/rear_simulation.gd::snapshot", "identity/identity_ledger.gd::snapshot",
		"training/training_service.gd::request_course", "training/training_service.gd::withdraw", "training/training_service.gd::set_access", "staffing/rear_simulation.gd::set_target"]:
		assert_int(int(counts.get(id, 0))).override_failure_message("Narrow Train read called " + id).is_equal(0)
	assert_int(int(counts.get("rear_base/base_simulation.gd::training_view", 0))).is_equal(1)
	assert_int(view.training.counts.Active).is_equal(6)
	assert_int(view.training.counts.Paused).is_equal(6)
	_save("training_read_structure.json", {"counts":counts, "selected_person":view.training_selected_person.id})

func test_07_rejected_training_commands_explicitly_need_no_reconciliation() -> void:
	var base: RefCounted = Scenarios.fixture("empty")
	var before: Dictionary = Scenarios.raw_state(base)
	for result in [base.rear.training.request_course("P01", 1), base.rear.training.request_course("missing", 1), base.rear.training.withdraw("missing-course")]:
		assert_bool(result.ok).is_false()
		assert_bool(result.requires_reconciliation).is_false()
	assert_str(Scenarios.fingerprint(Scenarios.raw_state(base))).is_equal(Scenarios.fingerprint(before))
	base = Scenarios.fixture("idle")
	assert_bool(base.rear.training.request_course("P01", 1).requires_reconciliation).is_true()
	assert_bool(base.rear.training.set_access(false).requires_reconciliation).is_true()

func test_08_selected_withdrawn_completed_injured_and_dead_students_match_legacy_reads() -> void:
	for label in ["withdrawn", "completed", "injured", "dead"]:
		var scenario: String = "active" if label in ["injured", "dead"] else label
		var old: RefCounted = Scenarios.fixture(scenario)
		var current: RefCounted = Scenarios.fixture(scenario)
		var selected: String = old.rear.training.rows[0].id
		if label in ["injured", "dead"]:
			for base in [old, current]:
				assert_bool(base.rear.combat.injure(base.rear.training.rows[0].person_id, 500 if label == "dead" else 25).ok).is_true()
				base.rear.advance_time(0)
		var legacy: Dictionary = old.snapshot(false, false)
		legacy.rear_population = old.receiving.rear_population()
		legacy.training_selected_person = Scenarios.selected_person(old, selected)
		var actual: Dictionary = current.training_view(selected)
		assert_dict(Scenarios.display_values(actual)).override_failure_message("Selected student parity: " + label).is_equal(Scenarios.display_values(legacy))
		assert_str(Scenarios.fingerprint(Scenarios.raw_state(current))).is_equal(Scenarios.fingerprint(Scenarios.raw_state(old)))
		assert_str(actual.training_selected_person.id).is_equal(current.rear.training.rows[0].person_id)
		if label == "dead": assert_int(int(actual.training_selected_person.health)).is_zero()
		assert_array(current.audit()).is_empty()

func _difference(after: Dictionary, before: Dictionary) -> Dictionary:
	var result := {}
	for key in after:
		var count := int(after[key]) - int(before.get(key, 0))
		if count > 0: result[str(key)] = count
	return result

func _save(name: String, value: Dictionary) -> void:
	var directory := OS.get_environment("TRENCHO_PERF_RUN_DIRECTORY")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://logs/training-reads")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file != null: file.store_string(JSON.stringify(Safe._json_safe(value), "\t") + "\n")
