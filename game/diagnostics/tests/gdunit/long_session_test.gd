extends GdUnitTestSuite
## Explicitly selected endurance diagnosis; clock liveness is not FPS certification.
const Budget = preload("res://game/diagnostics/performance_budget.gd")
const RUN_SECONDS := 330

class FrameSamples:
	extends Node
	var active := true
	var last_usec := Time.get_ticks_usec()
	var intervals_ms: Array[float] = []
	var maximum_ms := 0.0
	var over_budget := 0

	func _process(_delta: float) -> void:
		if not active: return
		var now := Time.get_ticks_usec()
		var milliseconds := float(now-last_usec)/1000.0
		last_usec = now
		intervals_ms.append(milliseconds)
		maximum_ms = maxf(maximum_ms,milliseconds)
		if milliseconds > Budget.MAX_FRAME_MS: over_budget += 1

func test_normal_one_x_session_keeps_time_beyond_308_seconds(timeout: int = 420000) -> void:
	var runner := scene_runner("res://game/main/main.tscn")
	var game: Control = runner.scene()
	await runner.simulate_frames(3)
	var session: Node = game._session
	var model: RefCounted = session.simulation
	var identity := model.get_instance_id()
	var directory := OS.get_environment("TRENCHO_PERF_RUN_DIRECTORY")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://logs/long-session-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var frames := FrameSamples.new()
	add_child(frames)
	var samples: Array[Dictionary] = []
	var issue := ""
	var previous: float = model.rear.time
	var stalled_samples := 0
	var started := Time.get_ticks_usec()
	session.set_speed(1)
	for _second in RUN_SECONDS:
		await get_tree().create_timer(1.0).timeout
		var elapsed := float(Time.get_ticks_usec()-started)/1000000.0
		var at: float = model.rear.time
		var sample := {"wall_seconds":elapsed,"simulation_seconds":at,"speed":model.speed,"owed_seconds":model.owed_simulation_seconds,
			"peak_frame_ms":frames.maximum_ms,"frames_over_60_fps_budget":frames.over_budget,"ai":model.rear.battlefield_operations.decision_backlog()}
		samples.append(sample)
		_save(directory,"heartbeat.json",{"status":"clock_endurance","action":"Normal main scene at real 1x beyond 308 seconds","engine_usec":Time.get_ticks_usec(),"sample":sample})
		stalled_samples = stalled_samples+1 if at <= previous else 0
		previous = at
		if session.simulation.get_instance_id() != identity or model.speed != 1: issue = "The same normal session must remain at 1x."
		elif stalled_samples >= 3: issue = "Simulation time stalled for three consecutive wall-clock samples."
		elif model.owed_simulation_seconds > 0.25: issue = "Simulation debt exceeded the unchanged 0.25 second progress guard."
		elif at < elapsed-0.25: issue = "The 1x simulation fell behind real elapsed time."
		if not issue.is_empty(): break
	frames.active = false
	session.set_speed(0)
	session.set_physics_process(false)
	var elapsed := float(Time.get_ticks_usec()-started)/1000000.0
	var report := {"clock_ok":issue.is_empty() and model.rear.time > 308.0,"issue":issue,"wall_seconds":elapsed,"simulation_seconds":model.rear.time,
		"peak_frame_ms":frames.maximum_ms,"frames_over_60_fps_budget":frames.over_budget,"fps_certified":false,
		"scope":"Ordinary full-world 1x clock endurance without setup fast-forward. Frame costs are retained; a clock pass is not a passing FPS acceptance run.","samples":samples}
	_save(directory,"clock_endurance.json",report)
	_save(directory,"frame_intervals.json",{"milliseconds":frames.intervals_ms})
	frames.queue_free()
	assert_bool(report.clock_ok).override_failure_message("Clock endurance failed: %s. Logs: %s" % [issue,directory]).is_true()
	assert_array(model.audit()).is_empty()

func _save(directory: String, name: String, data: Dictionary) -> void:
	var file := FileAccess.open(directory.path_join(name),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data)+"\n")
