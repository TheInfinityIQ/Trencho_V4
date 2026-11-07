extends Node
const Budget = preload("res://game/diagnostics/performance_budget.gd")
## Scene-owned measurement/reporting for real-input UI acceptance cases.
const Counter = preload("res://game/diagnostics/function_call_log.gd")
const ErrorSink = preload("res://game/diagnostics/tests/gdunit/fixtures/ui_error_sink.gd")
const Safe = preload("res://game/diagnostics/tests/gdunit/fixtures/read_path_scenarios.gd")
var directory := ""
static var _sequence := 0
var _run_root := ""
var results: Array[Dictionary] = []
var pending: Array = []
var errors: RefCounted
var action: Dictionary = {}
var active := false
var _baseline := {}
var _last_usec := 0
var _started_usec := 0
var _heartbeat_usec := 0
var _peak_ms := 0.0
var _frame_intervals_ms: Array[float] = []
var _issues: Array[Dictionary] = []
var _events: FileAccess
var _stacks: FileAccess
var _root: Node
var _sample_usec := 0
var _sample_totals := {}
var _reporter: Node

func _ready() -> void:
	process_priority = 10000
	_run_root = OS.get_environment("TRENCHO_PERF_RUN_DIRECTORY")
	if _run_root.is_empty(): _run_root = ProjectSettings.globalize_path("res://logs/ui-contracts-" + str(OS.get_process_id()))
	_sequence += 1
	directory = _run_root.path_join("ui-contracts/group-%02d" % _sequence)
	DirAccess.make_dir_recursive_absolute(directory)
	_events = FileAccess.open(directory.path_join("cases.jsonl"), FileAccess.WRITE)
	_stacks = FileAccess.open(directory.path_join("function_stacks.jsonl"), FileAccess.WRITE)
	errors = ErrorSink.new()
	errors.log_file = FileAccess.open(directory.path_join("engine_errors.jsonl"), FileAccess.WRITE)
	OS.add_logger(errors)
	Counter.enabled = true
	_save("metadata.json", {"engine": Engine.get_version_info(), "headless": DisplayServer.get_name() == "headless",
		"observation_seconds": _setting("TRENCHO_PERF_OBSERVATION_SECONDS", 2),
		"minimum_fps":Budget.MINIMUM_FPS, "engine_max_fps":Engine.max_fps,
		"disable_vsync_requested":OS.get_cmdline_args().has("--disable-vsync"),
		"stacks_enabled": Counter.capture_stacks, "frame_limit_ms": _setting("TRENCHO_PERF_FRAME_MS", Budget.MAX_FRAME_MS),
		"dispatch_limit_ms": _setting("TRENCHO_PERF_ACTION_MS", Budget.MAX_ACTION_MS), "inspect_call_budget": _setting("TRENCHO_PERF_CALL_BUDGET", 30000),
		"timing": "Monotonic wall time; native input dispatch includes event-queue latency, frame intervals include scheduling/rendering. Fixture setup and audit time are outside the observation window."})
	_heartbeat("setup")

func _exit_tree() -> void:
	_flush_logs()
	OS.remove_logger(errors)

func begin(next_action: Dictionary, root: Node) -> void:
	action = next_action.duplicate(true)
	_root = root
	_reporter = root.find_child("FunctionCallLog", true, false)
	if _reporter != null and not _reporter.second_reported.is_connected(_stack_report): _reporter.second_reported.connect(_stack_report)
	_baseline = Counter.totals()
	_issues.clear()
	for error in errors.drain(): _issues.append({"reason": "setup_engine_error", "error": error})
	_peak_ms = 0.0
	_frame_intervals_ms.clear()
	_started_usec = Time.get_ticks_usec()
	_sample_usec = _started_usec
	_sample_totals = _baseline.duplicate()
	_last_usec = _started_usec
	active = true
	_save("current_case.json", {"action": action, "pending_cases": pending})
	_heartbeat("running")
	_event("started", {"action": action})

func require_condition(condition: bool, message: String, details: Dictionary = {}) -> void:
	if not condition: _issues.append({"reason": details.get("classification", "contract_failure"), "message": message, "details": details})

func begin_excluded_work(label: String) -> Dictionary:
	# Explicit test fast-forward/state capture is not a live frame or UI action.
	# Keep errors/contracts visible and record exactly what measurement excludes.
	var token := {"label":label, "started_usec":Time.get_ticks_usec(), "totals":Counter.totals(), "was_active":active}
	active = false
	return token

func end_excluded_work(token: Dictionary) -> void:
	var now := Time.get_ticks_usec()
	var current := Counter.totals()
	var excluded_counts := {}
	for id in current:
		var count := int(current[id]) - int(token.totals.get(id, 0))
		if count > 0:
			_baseline[id] = int(_baseline.get(id, 0)) + count
			excluded_counts[str(id)] = count
	_started_usec += now - int(token.started_usec)
	_last_usec = now
	_sample_usec = now
	_sample_totals = current
	active = bool(token.was_active) and _issues.is_empty()
	_event("excluded_test_work", {"label":token.label, "microseconds":now - int(token.started_usec), "counts":excluded_counts})

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if now - _heartbeat_usec >= 500000: _heartbeat("running" if active else "setup")
	if not active: return
	var simulation := _simulation()
	if simulation != null and simulation.get("rear") != null:
		var execution: RefCounted = simulation.rear.battlefield_operations
		if execution != null and execution.has_method("decision_backlog"):
			var backlog: Dictionary = execution.decision_backlog()
			action.maximum_ai_decision_age = maxf(float(action.get("maximum_ai_decision_age",0.0)),float(backlog.oldest_age))
			action.maximum_pending_ai_decisions = maxi(int(action.get("maximum_pending_ai_decisions",0)),int(backlog.pending))
			if float(backlog.oldest_age) >= 1.0 or int(backlog.pending) > simulation.rear.military.squads.size():
				_issues.append({"reason":"ai_decision_backlog","pending":backlog.pending,"oldest_age":backlog.oldest_age,"decision_period_seconds":1.0})
	var interval_ms := float(now - _last_usec) / 1000.0
	_frame_intervals_ms.append(interval_ms)
	_peak_ms = maxf(_peak_ms, interval_ms)
	_last_usec = now
	for error in errors.drain(): _issues.append({"reason": "engine_error", "error": error})
	# A scene-owned logger publishes completed windows on its real-time timer.
	# Do not consume its global buckets first and silently suppress console logs.
	if not is_instance_valid(_reporter):
		for report in Counter.completed_seconds(): _stack_report(report)
	var sample_seconds := float(now - _sample_usec) / 1000000.0
	if sample_seconds >= 1.0:
		var totals := Counter.totals()
		var id := "identity/identity_ledger.gd::inspect_entity"
		var rate := float(int(totals.get(id, 0)) - int(_sample_totals.get(id, 0))) / sample_seconds
		_event("function_sample", {"action": action, "elapsed_seconds": sample_seconds, "inspect_calls_per_second": rate})
		var limit := _setting("TRENCHO_PERF_CALL_BUDGET", 30000)
		if limit > 0 and rate > limit: _issues.append({"reason": "call_volume_budget", "calls_per_second": rate, "limit": limit})
		_sample_usec = now
		_sample_totals = totals
	if _peak_ms > _setting("TRENCHO_PERF_FRAME_MS", Budget.MAX_FRAME_MS):
		_issues.append({"reason": "frame_time_budget", "milliseconds": _peak_ms})
	if not _issues.is_empty():
		active = false
		_pause()
		_save("failure-live.json", {"action": action, "issues": _issues, "pending_cases": pending, "function_call_second": Counter.current_second(),"frame_scopes":Counter.frame_scope_report(),"engine_monitors_informational":{"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"note":"Engine monitor update cadence differs from this failing interval; these values do not replace the monotonic frame gate."}})
		_heartbeat("paused_on_issue")
		_flush_logs()

func finish(dispatch_ms: float = 0.0, outcome: String = "input_exercised") -> Dictionary:
	active = false
	var ended_usec := Time.get_ticks_usec()
	var current := Counter.totals()
	var end_window := Counter.current_second()
	for error in errors.drain(): _issues.append({"reason": "engine_error", "error": error})
	var audit: Array = []
	var simulation: RefCounted = _simulation()
	var audit_started := Time.get_ticks_usec()
	if simulation != null and simulation.has_method("audit"): audit = simulation.audit()
	require_condition(audit.is_empty(), "Simulation invariants failed after UI input.", {"audit": audit})
	var action_limit := _setting("TRENCHO_PERF_ACTION_MS", Budget.MAX_ACTION_MS)
	var frame_limit := _setting("TRENCHO_PERF_FRAME_MS", Budget.MAX_FRAME_MS)
	if dispatch_ms > action_limit: _issues.append({"reason": "action_time_budget", "milliseconds": dispatch_ms, "limit": action_limit})
	if _peak_ms > frame_limit: _issues.append({"reason": "frame_time_budget", "milliseconds": _peak_ms, "limit": frame_limit})
	var counts := {}
	for id in current:
		var count := int(current[id]) - int(_baseline.get(id, 0))
		if count > 0: counts[str(id)] = count
	var elapsed := float(ended_usec - _started_usec) / 1000000.0
	var rate := float(counts.get("identity/identity_ledger.gd::inspect_entity", 0)) / maxf(elapsed, 0.001)
	var budget := _setting("TRENCHO_PERF_CALL_BUDGET", 30000)
	if budget > 0 and elapsed >= 1.0 and rate > budget: _issues.append({"reason": "call_volume_budget", "calls_per_second": rate, "limit": budget})
	var result := {"action": action, "ok": _issues.is_empty(), "outcome": outcome if _issues.is_empty() else "failed",
		"audit_checked": simulation != null and simulation.has_method("audit"),
		"dispatch_ms": dispatch_ms, "peak_frame_ms": _peak_ms, "elapsed_seconds": elapsed,
		"frame_intervals_ms": _frame_intervals_ms.duplicate(),
		"audit_ms": float(Time.get_ticks_usec() - audit_started) / 1000.0,
		"inspect_calls_per_second": rate, "function_calls": counts, "issues": _issues.duplicate(true)}
	results.append(result)
	_stack_report(end_window)
	_event("finished", result)
	if not result.ok:
		_pause()
		if is_instance_valid(_root) and DisplayServer.get_name() != "headless":
			_root.get_viewport().get_texture().get_image().save_png(directory.path_join("failure-%04d.png" % results.size()))
		var failure: Dictionary = result.duplicate(true)
		failure.pending_cases = pending.duplicate(true)
		failure.function_call_second = end_window
		if simulation != null and simulation.get("rear") != null: failure.ledger = simulation.rear.ledger.snapshot(false)
		_save("failure-%04d.json" % results.size(), failure)
		_heartbeat("paused_on_issue")
	_save("summary.json", {"results": results, "pending_cases": pending, "complete": pending.is_empty(),
		"limits": "Real Godot GUI input and bounded postconditions, not every gameplay state. Handler input does not establish a successful domain action; unavailable controls are failures, never passes."})
	_flush_logs()
	return result

func _simulation() -> RefCounted:
	if not is_instance_valid(_root): return null
	if _root.get("_base") != null: return _root._base.simulation
	if _root.get("simulation") is RefCounted: return _root.simulation
	return null

func _pause() -> void:
	var simulation := _simulation()
	if simulation != null and simulation.has_method("set_speed"): simulation.set_speed(0)
	if is_instance_valid(_root) and _root.get("_session") != null: _root._session.set_physics_process(false)
	elif is_instance_valid(_root) and _root.get("session") != null: _root.session.set_physics_process(false)
	if is_instance_valid(_root):
		_root.set_process(false)
		_root.set_physics_process(false)

func _heartbeat(status: String) -> void:
	var started_usec := Time.get_ticks_usec()
	_heartbeat_usec = Time.get_ticks_usec()
	var file := FileAccess.open(_run_root.path_join("heartbeat.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"status": status, "action": action.get("label", "UI fixture setup"), "engine_usec": _heartbeat_usec}))
	file = null # Include closing/flushing the heartbeat file in diagnostic timing.
	Counter.record_duration(&"diagnostics/ui_action_probe.gd::_heartbeat",Time.get_ticks_usec()-started_usec)

func _stack_report(report: Dictionary) -> void:
	if _stacks == null: return
	var started_usec := Time.get_ticks_usec()
	_stacks.store_line(JSON.stringify({"action": action, "window": report,
		"window_scope": "process-wide real second; may overlap fixture setup and other actions", "action_started_usec": _started_usec}))
	Counter.record_duration(&"diagnostics/ui_action_probe.gd::_stack_report",Time.get_ticks_usec()-started_usec)

func _event(kind: String, details: Dictionary) -> void:
	if _events == null: return
	_events.store_line(JSON.stringify(Safe._json_safe({"event": kind, "engine_usec": Time.get_ticks_usec(), "details": details})))

func _flush_logs() -> void:
	# Pause/finish/teardown preserve the complete evidence before returning.
	# Do not force disk synchronization inside a measured live frame.
	if _events != null: _events.flush()
	if _stacks != null: _stacks.flush()

func _save(name: String, details: Dictionary) -> void:
	var file := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(Safe._json_safe(details), "\t") + "\n")

func _setting(name: String, fallback: float) -> float:
	var value := OS.get_environment(name)
	var setting := fallback if value.is_empty() else float(value)
	if name == "TRENCHO_PERF_FRAME_MS": return Budget.capped_limit(setting,Budget.MAX_FRAME_MS)
	if name == "TRENCHO_PERF_ACTION_MS": return Budget.capped_limit(setting,Budget.MAX_ACTION_MS)
	return setting
