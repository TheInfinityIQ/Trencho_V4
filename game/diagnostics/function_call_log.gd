extends Node
## Count instrumented entries and distinct caller chains in real-time seconds.
## This is a runtime diagnostic, not an editor plugin or a timing profiler.

signal second_reported(report: Dictionary)
const ConsoleWriter = preload("res://game/diagnostics/console_report_writer.gd")

static var enabled: bool = OS.is_debug_build()
static var capture_stacks: bool = OS.is_debug_build() and OS.get_environment("TRENCHO_CALL_STACKS") == "1"
static var capture_frame_scopes: bool = OS.is_debug_build() and OS.get_environment("TRENCHO_PROFILE_FRAMES") == "1"
static var _frame_scopes: Dictionary = {}
static var _buckets: Dictionary = {}
static var _totals: Dictionary = {}
static var _last_reported_second: int = -2
var _writer: RefCounted


@warning_ignore("integer_division")
static func _second() -> int:
	return Time.get_ticks_msec() / 1000


static func record(function_id: StringName) -> void:
	if not enabled: return
	var second := _second()
	if _last_reported_second < -1: _last_reported_second = second - 1
	if not _buckets.has(second): _buckets[second] = _empty_bucket()
	var bucket: Dictionary = _buckets[second]
	var counts: Dictionary = bucket.counts
	counts[function_id] = int(counts.get(function_id, 0)) + 1
	_totals[function_id] = int(_totals.get(function_id, 0)) + 1
	if not capture_stacks:
		bucket.stack_capture_disabled_calls += 1
		return
	# get_stack() is newest-first. Exclude record() itself and retain every
	# script caller, including functions without a counter hook. Call-site line
	# numbers deliberately do not split otherwise identical function chains.
	var stack: Array = get_stack()
	if stack.size() < 2:
		bucket.unavailable_stack_calls += 1
		return
	var chain := PackedStringArray()
	for index in range(stack.size() - 1, 0, -1):
		chain.append("%s::%s" % [str(stack[index].source).trim_prefix("res://"), stack[index].function])
	var key := str(function_id) + "\n" + "\n".join(chain)
	var groups: Dictionary = bucket.stacks
	if not groups.has(key): groups[key] = {"function_id": str(function_id), "chain": chain, "count": 0}
	groups[key].count += 1


static func totals() -> Dictionary:
	return _totals.duplicate()


static func record_duration(scope: StringName, elapsed_usec: int) -> void:
	if not enabled or elapsed_usec < 0: return
	var second := _second()
	if _last_reported_second < -1: _last_reported_second = second - 1
	if not _buckets.has(second): _buckets[second] = _empty_bucket()
	var durations: Dictionary = _buckets[second].durations_usec
	if not durations.has(scope): durations[scope] = {"calls": 0, "total": 0, "maximum": 0}
	durations[scope].calls += 1
	durations[scope].total += elapsed_usec
	durations[scope].maximum = maxi(int(durations[scope].maximum), elapsed_usec)
	if capture_frame_scopes: _record_frame_duration(scope,elapsed_usec)

static func _record_frame_duration(scope: StringName, elapsed_usec: int) -> void:
	var frame := Engine.get_process_frames()
	if not _frame_scopes.has(frame):
		_frame_scopes[frame] = {}
		for old in _frame_scopes.keys():
			if int(old) < frame-1: _frame_scopes.erase(old)
	var durations: Dictionary = _frame_scopes[frame]
	if not durations.has(scope): durations[scope] = {"calls":0,"total":0,"maximum":0}
	durations[scope].calls += 1
	durations[scope].total += elapsed_usec
	durations[scope].maximum = maxi(int(durations[scope].maximum),elapsed_usec)

static func frame_scope_report() -> Dictionary:
	return {"enabled":capture_frame_scopes,"current_process_frame":Engine.get_process_frames(),"scopes_by_process_frame":_frame_scopes.duplicate(true),"scope":"Inclusive completed scopes; the probe interval can span previous-frame drawing and current-frame physics. Uninstrumented engine, rendering and scheduling time remain outside these scopes."}


static func _empty_bucket() -> Dictionary:
	return {"counts": {}, "stacks": {}, "durations_usec": {}, "stack_capture_disabled_calls": 0, "unavailable_stack_calls": 0}


static func _report(second: int, bucket: Dictionary, complete: bool) -> Dictionary:
	var stacks: Array = bucket.stacks.values()
	stacks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.count != b.count: return a.count > b.count
		return str(a.chain) < str(b.chain))
	return {"second": second, "complete": complete, "counts": bucket.counts.duplicate(),
		"stacks": stacks.duplicate(true), "stack_capture_disabled_calls": bucket.stack_capture_disabled_calls,
		"unavailable_stack_calls": bucket.unavailable_stack_calls, "durations_usec": bucket.durations_usec.duplicate(true)}


static func current_second() -> Dictionary:
	var second := _second()
	return _report(second, _buckets.get(second, _empty_bucket()), false)


static func completed_seconds() -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	if not enabled:
		_buckets.clear()
		_last_reported_second = -2
		return reports
	var current := _second()
	if _last_reported_second < -1:
		_last_reported_second = current - 1
		return reports
	if current <= _last_reported_second + 1: return reports
	var seconds: Array = _buckets.keys()
	seconds.sort()
	for second: int in seconds:
		if second >= current: continue
		reports.append(_report(second, _buckets[second], true))
		_buckets.erase(second)
	if reports.is_empty():
		reports.append(_report(current - 1, _empty_bucket(), true))
	_last_reported_second = current - 1
	return reports


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	set_process(false)
	if enabled:
		_writer = ConsoleWriter.new()
		var error: Error = _writer.start()
		if error != OK: push_warning("Console report thread unavailable; queued text is retained until shutdown. Structured reports remain available.")
		_writer.enqueue(PackedStringArray(["[Calls/s] Runtime counters enabled; caller stacks %s. One report per real second; instrumented entries only." % ("enabled" if capture_stacks else "disabled")]))
		var timer := Timer.new()
		timer.name = "ReportTimer"
		timer.wait_time = 1.0
		timer.ignore_time_scale = true
		timer.timeout.connect(_collect_reports)
		add_child(timer)
		timer.start()

func _collect_reports() -> void:
	var started_usec: int = Time.get_ticks_usec()
	var lines := PackedStringArray()
	for report in completed_seconds():
		second_reported.emit(report)
		var counts: Dictionary = report.counts
		var names: Array = counts.keys()
		names.sort_custom(func(a: StringName, b: StringName) -> bool:
			if counts[a] != counts[b]: return counts[a] > counts[b]
			return str(a) < str(b))
		lines.append("[Calls/s] engine second %d [%d, %d):" % [report.second, report.second, report.second + 1])
		for function_id in names:
			lines.append("  %6d  %s" % [counts[function_id], function_id])
		if names.is_empty(): lines.append("       0  no instrumented calls")
		if not report.stacks.is_empty():
			lines.append("[Call stacks/s] engine second %d:" % report.second)
			for group in report.stacks:
				lines.append("  [%s] x%d" % [" -> ".join(group.chain), group.count])
		if report.unavailable_stack_calls > 0:
			lines.append("[Call stacks/s] %d entries had no available script stack." % report.unavailable_stack_calls)
		if not report.durations_usec.is_empty():
			lines.append("[Scope wall time/us] engine second %d (inclusive, completed scopes): %s" % [report.second, JSON.stringify(report.durations_usec)])
	if _writer != null: _writer.enqueue(lines)
	record_duration(&"diagnostics/function_call_log.gd::_collect_reports",Time.get_ticks_usec()-started_usec)

func _exit_tree() -> void:
	# Join the sole writer only at shutdown, after handing off completed windows.
	_collect_reports()
	if _writer != null: _writer.close()
