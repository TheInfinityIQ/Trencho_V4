extends GdUnitTestSuite
## Exercise real pause/log behavior at the 60 FPS limit, independent of OS timing.
const Probe = preload("res://game/diagnostics/tests/gdunit/fixtures/ui_action_probe.gd")
const Base = preload("res://game/rear_base/base_simulation.gd")

class FixtureRoot extends Node:
	var simulation: RefCounted
	var _base: Node
	var _session: Node
	var session: Node

func test_00_seventeen_ms_frame_pauses_and_writes_failure() -> void:
	var result := _violation("frame")
	assert_bool(result.report.ok).is_false()
	assert_int(result.speed).is_equal(0)
	assert_bool(result.report.issues.any(func(issue: Dictionary) -> bool: return issue.reason == "frame_time_budget")).is_true()
	assert_bool(FileAccess.file_exists(result.directory.path_join("failure-live.json"))).is_true()

func test_01_seventeen_ms_synchronous_action_pauses_and_writes_failure() -> void:
	var result := _violation("action")
	assert_bool(result.report.ok).is_false()
	assert_int(result.speed).is_equal(0)
	assert_bool(result.report.issues.any(func(issue: Dictionary) -> bool: return issue.reason == "action_time_budget")).is_true()
	assert_bool(FileAccess.file_exists(result.directory.path_join("failure-0001.json"))).is_true()

func test_02_larger_environment_limits_cannot_weaken_acceptance() -> void:
	for kind in ["frame","action"]:
		var result := _violation(kind,"100")
		assert_bool(result.report.ok).is_false()
		assert_int(result.speed).is_equal(0)

func _violation(kind: String, requested_limit: String = "") -> Dictionary:
	var saved_frame := OS.get_environment("TRENCHO_PERF_FRAME_MS")
	var saved_action := OS.get_environment("TRENCHO_PERF_ACTION_MS")
	var saved_directory := OS.get_environment("TRENCHO_PERF_RUN_DIRECTORY")
	OS.set_environment("TRENCHO_PERF_FRAME_MS",requested_limit)
	OS.set_environment("TRENCHO_PERF_ACTION_MS",requested_limit)
	# Expected rejection artifacts are labelled separately from game acceptance.
	if not saved_directory.is_empty(): OS.set_environment("TRENCHO_PERF_RUN_DIRECTORY",saved_directory.path_join("intentional-budget-rejections"))
	var root := FixtureRoot.new()
	root.simulation = Base.new(false,false,false,Vector2(1640,91),false,{},true)
	root.simulation.set_speed(1)
	add_child(root)
	var probe := Probe.new()
	add_child(probe)
	probe.begin({"label":"Intentional 17 ms " + kind + " rejection contract","expected_failure":true},root)
	if kind == "frame":
		probe._last_usec = Time.get_ticks_usec()-17000
		probe._process(0.0)
	var report: Dictionary = probe.finish(17.0 if kind == "action" else 0.0,"expected_budget_rejection")
	var result := {"report":report,"speed":root.simulation.speed,"directory":probe.directory}
	probe.free()
	root.free()
	OS.set_environment("TRENCHO_PERF_FRAME_MS",saved_frame)
	OS.set_environment("TRENCHO_PERF_ACTION_MS",saved_action)
	OS.set_environment("TRENCHO_PERF_RUN_DIRECTORY",saved_directory)
	return result
