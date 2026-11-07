extends RefCounted
const Counter = preload("res://game/diagnostics/function_call_log.gd")
const FUNCTION_ID = &"diagnostics/tests/gdunit/fixtures/call_stack_target.gd::function_c"

static func function_b() -> void:
	function_c()

static func function_c() -> void:
	Counter.record(FUNCTION_ID)
