extends RefCounted
const Target = preload("res://game/diagnostics/tests/gdunit/fixtures/call_stack_target.gd")

static func function_a() -> void:
	Target.function_b()
