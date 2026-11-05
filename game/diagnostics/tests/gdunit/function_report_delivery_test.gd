extends GdUnitTestSuite
## Completed-second delivery is independent of the asynchronous console writer.
const Counter = preload("res://game/diagnostics/function_call_log.gd")
var _saved := {}

func before_test() -> void:
	_saved = {"enabled":Counter.enabled,"stacks":Counter.capture_stacks}
	Counter.enabled = true
	Counter.capture_stacks = false

func after_test() -> void:
	Counter.enabled = _saved.enabled
	Counter.capture_stacks = _saved.stacks

func test_native_timer_preserves_every_count_and_console_queue_returns_to_idle() -> void:
	var logger: Node = auto_free(Counter.new())
	var delivered: Array[Dictionary] = []
	logger.second_reported.connect(func(report: Dictionary) -> void: delivered.append(report))
	add_child(logger)
	var timer: Timer = logger.get_node("ReportTimer")
	assert_bool(timer.ignore_time_scale).is_true()
	assert_float(timer.wait_time).is_equal(1.0)
	for _entry in 3: Counter.record(&"diagnostics/report_delivery_test::stimulus")
	# Covers two timeout opportunities even if the entries straddle a real
	# second boundary. No gameplay frame-rate claim is made by this unit test.
	await get_tree().create_timer(2.15,true,false,true).timeout
	var count := 0
	for report in delivered:
		assert_bool(report.complete).is_true()
		count += int(report.counts.get("diagnostics/report_delivery_test::stimulus",0))
	assert_int(count).is_equal(3)
	var writer: RefCounted = logger._writer
	assert_int(writer.status().queued_batches).is_zero()
	assert_bool(writer.status().busy).is_false()
	assert_int(writer.status().delivered_lines).is_greater(0)
	assert_bool(logger.is_processing()).is_false()
	var delivered_before: int = writer.status().delivered_lines
	writer.enqueue(PackedStringArray(["[Report delivery test] shutdown line one","[Report delivery test] shutdown line two"]))
	logger.queue_free()
	await get_tree().process_frame
	assert_int(writer.status().delivered_lines).is_greater_equal(delivered_before+2)
	assert_int(writer.status().queued_batches).is_zero()
	assert_bool(writer.status().started).is_false()
