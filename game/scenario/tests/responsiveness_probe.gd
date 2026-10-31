extends SceneTree
## Rendered opening/control probe. Extended warm-up belongs on GitHub, not the desktop.
const Main = preload("res://game/main/main.tscn")
var main: Control
var phase := "loading"
var frames: Dictionary = {}
var actions: Array[Dictionary] = []
var previous := 0
var failures: Array[String] = []
var finished := false
var frame_budget := 0.0
var warmup := 0.0
var profile_live := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--max-frame-ms="): frame_budget = argument.get_slice("=",1).to_float()
		if argument.begins_with("--warmup="): warmup = argument.get_slice("=",1).to_float()
		if argument == "--profile-live": profile_live = true
	if profile_live: EngineDebugger.profiler_enable("scripts",false)
	_run.call_deferred()

func _process(_delta: float) -> bool:
	var at := Time.get_ticks_usec()
	if previous > 0 and phase != "loading" and not finished:
		var interval := (at-previous)/1000.0
		if not frames.has(phase): frames[phase] = []
		frames[phase].append(interval)
		if frame_budget > 0 and interval > frame_budget:
			failures.append("%s frame took %.3f ms" % [phase,interval])
			_finish.call_deferred()
	previous = at
	return false

func _phase(label: String) -> void:
	phase = label
	previous = 0
	print("RESPONSIVENESS_PHASE ",phase," sim=",main.get("_base").simulation.rear.time)

func _press(label: String) -> void:
	var matches: Array[Button] = []
	for button in main.find_children("*","Button",true,false):
		if button.text == label and button.is_visible_in_tree(): matches.append(button)
	if matches.size() != 1:
		failures.append("Expected one visible control: "+label)
		return
	var started := Time.get_ticks_usec()
	matches[0].pressed.emit()
	var elapsed := (Time.get_ticks_usec()-started)/1000.0
	actions.append({"control":label,"handler_ms":elapsed})
	if label != "New playtest" and frame_budget > 0 and elapsed > frame_budget: failures.append("%s handler took %.3f ms" % [label,elapsed])

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.title = "Trencho V4 responsiveness check"
	main = Main.instantiate()
	root.add_child(main)
	await process_frame
	_press("New playtest")
	var base: RefCounted = main.get("_base").simulation
	_check(base.rear.military.squads.size() == 10 and base.speed == 0,"Ordinary playtest starts with its actual paused armies")
	if warmup > 0:
		print("RESPONSIVENESS_WARMUP_START ",warmup)
		base.rear.advance_time(warmup)
		print("RESPONSIVENESS_WARMUP_COMPLETE ",base.rear.time)
	_phase("paused_battlefield")
	await create_timer(0.5).timeout
	_press("1x")
	_check(base.speed == 1,"Ordinary1x control changes the shared clock")
	_phase("running_1x")
	if profile_live: EngineDebugger.profiler_enable("scripts",true)
	await _wait_simulation(base.rear.time+9.0,60.0)
	_press("Pause")
	var paused: float = base.rear.time
	_phase("pause_response")
	await create_timer(0.5).timeout
	_check(base.speed == 0 and base.rear.time == paused,"Pause stops the shared simulation")
	_phase("rear_switch")
	_press("Rear base")
	_check(main.get("_base").visible and not main.get("_battlefield").visible,"Rear view opens normally")
	await create_timer(0.5).timeout
	_phase("battlefield_switch")
	_press("Battlefield")
	_check(main.get("_battlefield").simulation == base and base.rear.time == paused,"View changes retain paused identities and time")
	await create_timer(0.5).timeout
	_press("2x")
	_check(base.speed == 2,"Ordinary2x control changes the shared clock")
	_phase("running_2x")
	await _wait_simulation(base.rear.time+6.0,40.0)
	_press("Pause")
	_check(base.rear.time > paused,"The same session continues actual simulation at2x")
	phase = "loading"
	_check(base.audit().is_empty(),"The observed session preserves physical invariants")
	_finish()

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _wait_simulation(target: float, wall_limit: float) -> void:
	var deadline := Time.get_ticks_msec()+int(wall_limit*1000.0)
	while main.get("_base").simulation.rear.time < target and not finished:
		if Time.get_ticks_msec() >= deadline:
			failures.append("Simulation failed to reach %.3f s within %.1f wall seconds" % [target,wall_limit])
			return
		await process_frame

func _finish() -> void:
	if finished: return
	finished = true
	main.get("_base").simulation.set_speed(0)
	if profile_live: EngineDebugger.profiler_enable("scripts",false)
	var results := {}
	for label in frames:
		var values: Array = frames[label]
		values.sort()
		results[label] = {"frames":values.size(),"p95_ms":values[mini(values.size()-1,int(values.size()*0.95))],"max_ms":values[-1]}
	var admissions := {}
	for id in main.get("_base").simulation.rear.battlefield_operations.policy.trips:
		var trip: Dictionary = main.get("_base").simulation.rear.battlefield_operations.policy.trips[id]
		admissions[id] = {"started":trip.started,"admitted_at":trip.admitted_at,"blocker":trip.blocker}
	var output := {"revision":OS.get_environment("EVALUATION_HEAD"),"engine":Engine.get_version_info().string,"failures":failures,"warmup_seconds":warmup,"frame_budget_ms":frame_budget,"phases":results,"actions":actions,"admissions":admissions,"sim_seconds":main.get("_base").simulation.rear.time,"engine_static_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}
	var file := FileAccess.open("res://.artifacts/responsiveness.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	print("RESPONSIVENESS_RESULT ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)
