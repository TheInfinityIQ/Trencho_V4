extends SceneTree
## Rendered mouse/control probe. Extended warm-up belongs on GitHub, not the desktop.
const Main = preload("res://game/main/main.tscn")
var main: Control
var phase := "loading"
var previous_phase := "loading"
var frames: Dictionary = {}
var actions: Array[Dictionary] = []
var phase_transitions: Array[Dictionary] = []
var previous := 0
var failures: Array[String] = []
var finished := false
var frame_budget := 0.0
var warmup := 0.0
var profile_live := false
var report_path := "res://.artifacts/responsiveness.json"
var run_seconds := 9.0
var double_seconds := 6.0
var heartbeat_path := ""
var heartbeat_at := 0
var capture := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--max-frame-ms="): frame_budget = argument.get_slice("=",1).to_float()
		if argument.begins_with("--warmup="): warmup = argument.get_slice("=",1).to_float()
		if argument.begins_with("--report-path="): report_path = argument.trim_prefix("--report-path=")
		if argument.begins_with("--run-seconds="): run_seconds = maxf(9.0,argument.get_slice("=",1).to_float())
		if argument.begins_with("--double-seconds="): double_seconds = maxf(6.0,argument.get_slice("=",1).to_float())
		if argument.begins_with("--heartbeat-path="): heartbeat_path = argument.trim_prefix("--heartbeat-path=")
		if argument == "--profile-live": profile_live = true
		if argument == "--capture": capture = true
	if profile_live: EngineDebugger.profiler_enable("scripts",false)
	_run.call_deferred()

func _process(_delta: float) -> bool:
	_record_frame()
	if not heartbeat_path.is_empty() and Time.get_ticks_msec() >= heartbeat_at:
		heartbeat_at = Time.get_ticks_msec()+250
		DirAccess.make_dir_recursive_absolute(heartbeat_path.get_base_dir())
		var heartbeat := FileAccess.open(heartbeat_path,FileAccess.WRITE)
		if heartbeat != null: heartbeat.store_string(phase)
	return false

func _record_frame() -> void:
	var at := Time.get_ticks_usec()
	# Attribute the whole interval to its starting phase. Transitions never erase
	# a last expensive running frame or a synchronous view-switch handler.
	if previous > 0 and previous_phase != "loading" and not finished:
		var interval := (at-previous)/1000.0
		if not frames.has(previous_phase): frames[previous_phase] = []
		frames[previous_phase].append(interval)
		if frame_budget > 0 and interval > frame_budget:
			failures.append("%s frame took %.3f ms" % [previous_phase,interval])
			_finish.call_deferred()
	previous = at
	previous_phase = phase

func _phase(label: String) -> void:
	phase = label
	phase_transitions.append({"phase":phase,"wall_msec":Time.get_ticks_msec(),"sim_seconds":main.get("_base").simulation.rear.time})
	print("RESPONSIVENESS_PHASE ",phase," sim=",main.get("_base").simulation.rear.time)

func _press(label: String) -> bool:
	var matches: Array[Button] = []
	for button in main.find_children("*","Button",true,false):
		if button.text == label and button.is_visible_in_tree(): matches.append(button)
	if matches.size() != 1:
		failures.append("Expected one visible control: "+label)
		_finish()
		return false
	var action := {"control":label,"input_to_response_ms":-1.0}
	var started := Time.get_ticks_usec()
	# Connect after the ordinary handler, so this includes its synchronous work.
	matches[0].pressed.connect(func() -> void: action.input_to_response_ms = (Time.get_ticks_usec()-started)/1000.0,CONNECT_ONE_SHOT)
	var down := InputEventMouseButton.new()
	down.position = matches[0].get_global_rect().get_center()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate()
	up.pressed = false
	up.button_mask = 0
	Input.parse_input_event(up)
	await process_frame
	actions.append(action)
	if action.input_to_response_ms < 0:
		failures.append("Mouse input did not activate "+label)
		_finish()
		return false
	if label != "New playtest" and frame_budget > 0 and action.input_to_response_ms > frame_budget:
		failures.append("%s mouse response took %.3f ms" % [label,action.input_to_response_ms])
	return true

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.title = "Trencho V4 responsiveness check"
	main = Main.instantiate()
	root.add_child(main)
	await process_frame
	if not await _press("New playtest"): return
	var base: RefCounted = main.get("_base").simulation
	_check(base.rear.military.squads.size() == 10 and base.speed == 0,"Ordinary playtest starts with its actual paused armies")
	if base.rear.battlefield_operations == null or base.rear.battlefield_operations.policy == null:
		failures.append("New playtest did not create the opening policy")
		_finish()
		return
	if warmup > 0:
		print("RESPONSIVENESS_WARMUP_START ",warmup)
		base.rear.advance_time(warmup)
		print("RESPONSIVENESS_WARMUP_COMPLETE ",base.rear.time)
		if warmup >= 180.0:
			for id in ["blue-rifles","blue-support","red-forward"]:
				var trip: Dictionary = base.rear.battlefield_operations.policy.trips[id]
				var job: Dictionary = base.rear.military.troop_transport.jobs.get(trip.job,{})
				_check(job.get("state","") in ["Outbound","Dismounting","Returning","Complete"],"Actual initial lift departed before the later observation: "+id)
	_phase("paused_battlefield")
	await create_timer(0.5).timeout
	if not await _press("1x"): return
	_check(base.speed == 1,"Ordinary1x control changes the shared clock")
	_phase("running_1x")
	if profile_live: EngineDebugger.profiler_enable("scripts",true)
	await _wait_simulation(base.rear.time+run_seconds,maxf(60.0,run_seconds*6.0))
	for id in ["blue-rifles","blue-support","red-forward"]:
		_check(base.rear.battlefield_operations.policy.trips[id].started,"Observed the actual initial admission: "+id)
	if not await _press("Pause"): return
	var paused: float = base.rear.time
	_phase("pause_response")
	await create_timer(0.5).timeout
	_check(base.speed == 0 and base.rear.time == paused,"Pause stops the shared simulation")
	_phase("rear_switch")
	if not await _press("Rear base"): return
	_check(main.get("_base").visible and not main.get("_battlefield").visible,"Rear view opens normally")
	await create_timer(0.5).timeout
	_phase("battlefield_switch")
	if not await _press("Battlefield"): return
	_check(main.get("_battlefield").simulation == base and base.rear.time == paused,"View changes retain paused identities and time")
	await create_timer(0.5).timeout
	if not await _press("2x"): return
	_check(base.speed == 2,"Ordinary2x control changes the shared clock")
	_phase("running_2x")
	await _wait_simulation(base.rear.time+double_seconds,maxf(40.0,double_seconds*4.0))
	if not await _press("Pause"): return
	_check(base.rear.time > paused,"The same session continues actual simulation at2x")
	_check(base.speed == 0,"The final Pause stops the same session after2x")
	_phase("loading")
	_record_frame()
	if profile_live: EngineDebugger.profiler_enable("scripts",false)
	_check(base.audit().is_empty(),"The observed session preserves physical invariants")
	if capture:
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		var captured: Error = root.get_texture().get_image().save_png(report_path.trim_suffix(".json")+".png")
		_check(captured == OK,"The exact observed candidate produces its review image")
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
	_record_frame()
	finished = true
	if profile_live: EngineDebugger.profiler_enable("scripts",false)
	var base: RefCounted = main.get("_base").simulation if is_instance_valid(main) and is_instance_valid(main.get("_base")) else null
	if base != null: base.set_speed(0)
	var results := {}
	for label in frames:
		var values: Array = frames[label]
		values.sort()
		var wall_ms := 0.0
		for interval in values: wall_ms += float(interval)
		results[label] = {"frames":values.size(),"p95_ms":values[mini(values.size()-1,int(values.size()*0.95))],"max_ms":values[-1],"wall_seconds":wall_ms/1000.0}
	var admissions := {}
	if base != null and base.rear.battlefield_operations != null and base.rear.battlefield_operations.policy != null:
		for id in base.rear.battlefield_operations.policy.trips:
			var trip: Dictionary = base.rear.battlefield_operations.policy.trips[id]
			var job: Dictionary = base.rear.military.troop_transport.jobs.get(trip.job,{})
			admissions[id] = {"started":trip.started,"admitted_at":trip.admitted_at,"blocker":trip.blocker,"state":job.get("state","Not requested"),"boarded":job.get("boarded",0),"people":job.get("people",[]).size()}
	var output := {"revision":OS.get_environment("EVALUATION_HEAD"),"engine":Engine.get_version_info().string,"failures":failures,"profiled":profile_live,"warmup_seconds":warmup,"frame_budget_ms":frame_budget,"phases":results,"phase_transitions":phase_transitions,"actions":actions,"admissions":admissions,"sim_seconds":base.rear.time if base != null else 0.0,"engine_static_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write responsiveness report: "+str(FileAccess.get_open_error()))
	else: file.store_string(JSON.stringify(output,"\t"))
	print("RESPONSIVENESS_RESULT ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)
