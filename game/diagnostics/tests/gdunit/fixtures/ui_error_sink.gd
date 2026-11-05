extends Logger
## Test-process only. Logger callbacks can arrive from other engine threads.
var _mutex := Mutex.new()
var _errors: Array[Dictionary] = []
var log_file: FileAccess

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == Logger.ERROR_TYPE_WARNING: return
	var traces: Array[String] = []
	for trace in script_backtraces: traces.append(trace.format())
	_mutex.lock()
	var entry := {"function": function, "file": file, "line": line, "code": code, "engine_usec": Time.get_ticks_usec(),
		"message": rationale, "type": error_type, "backtraces": traces}
	_errors.append(entry)
	if log_file != null:
		log_file.store_line(JSON.stringify(entry))
		log_file.flush()
	_mutex.unlock()

func drain() -> Array[Dictionary]:
	_mutex.lock()
	var result: Array[Dictionary] = _errors.duplicate(true)
	_errors.clear()
	_mutex.unlock()
	return result
