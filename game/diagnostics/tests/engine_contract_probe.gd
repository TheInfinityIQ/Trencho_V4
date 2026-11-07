extends SceneTree
## Opt-in engine-behavior investigation. Does not instantiate the game or addons.
## godot --headless --path PROJECT --max-fps 60 --script res://game/diagnostics/tests/engine_contract_probe.gd

class PhaseProbe extends Control:
	signal ping
	var running := false
	var refresh_queued := false
	var refreshes: Array[Dictionary] = []
	var process_calls := 0
	var draw_calls := 0

	func _physics_process(_delta: float) -> void:
		if running: request_refresh("physics")

	func _process(_delta: float) -> void:
		process_calls += 1
		if running: request_refresh("process")

	func request_refresh(origin: String) -> void:
		if refresh_queued: return
		refresh_queued = true
		_flush_refresh.call_deferred(origin)

	func _flush_refresh(origin: String) -> void:
		refresh_queued = false
		refreshes.append({"origin": origin, "process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames()})

	func _draw() -> void:
		draw_calls += 1

var _signal_order: Array[String] = []
var _cascade_frames: Array[int] = []
var _pausable_fired := false
var _failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var original_scale := Engine.time_scale
	Engine.time_scale = 1.0
	var node := PhaseProbe.new()
	root.add_child(node)
	node.size = Vector2(16, 16)
	await _wait_frames(3)

	node.ping.connect(_on_immediate)
	node.ping.connect(_on_deferred, Object.CONNECT_DEFERRED)
	_signal_order.append("before_emit")
	node.ping.emit()
	_signal_order.append("after_emit")
	var immediate_order := _signal_order.duplicate()
	_cascade(0)
	await _wait_frames(3)
	_require(immediate_order == ["before_emit", "immediate", "after_emit"], "Ordinary signal callback must run inside emit().")
	_require(_signal_order == ["before_emit", "immediate", "after_emit", "deferred"], "Deferred signal must run after the emitter returns.")
	_require(_cascade_frames.size() == 4 and _cascade_frames.min() == _cascade_frames.max(), "Bounded nested deferred calls should complete within the same observed process-frame ID.")

	var draws_before := node.draw_calls
	for request in 3: node.queue_redraw()
	await _wait_frames(3)
	var redraw_batch := node.draw_calls - draws_before
	_require(redraw_batch == 1, "Three redraw requests before the queued callback must coalesce to one draw notification.")
	node.hide()
	draws_before = node.draw_calls
	var processes_before := node.process_calls
	node.queue_redraw()
	await _wait_frames(3)
	var hidden_processes := node.process_calls - processes_before
	var hidden_draws := node.draw_calls - draws_before
	_require(hidden_processes > 0, "Hiding a CanvasItem must not implicitly stop its process callback.")
	_require(hidden_draws == 0, "A hidden CanvasItem must not execute its queued draw notification.")
	node.show()
	await _wait_frames(3)

	node.running = true
	await _wait_frames(40)
	node.running = false
	await _wait_frames(2)
	var refreshes_by_frame := {}
	for refresh in node.refreshes:
		var frame: String = str(refresh.process_frame)
		refreshes_by_frame[frame] = int(refreshes_by_frame.get(frame, 0)) + 1
	var duplicate_frames: Array[String] = []
	for frame in refreshes_by_frame:
		if refreshes_by_frame[frame] > 1: duplicate_frames.append(frame)
	_require(not duplicate_frames.is_empty(), "Physics/process notification bursts should expose that a pending-only guard does not enforce one refresh per process-frame ID.")

	paused = true
	var pausable_timer := create_timer(0.02, false)
	pausable_timer.timeout.connect(_on_pausable_timeout)
	await create_timer(0.05).timeout
	var default_timer_fired_while_paused := true
	var pausable_held := not _pausable_fired
	_require(pausable_held, "A SceneTreeTimer with process_always=false must remain paused while the default timer fires.")
	paused = false
	await pausable_timer.timeout
	_require(_pausable_fired, "The pausable timer must resume after SceneTree is unpaused.")

	var output := ProjectSettings.globalize_path("res://logs/engine-contracts-%d.json" % OS.get_process_id())
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): output = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var report := {"engine": Engine.get_version_info(), "headless": DisplayServer.get_name() == "headless",
		"scope": "Engine callback semantics in a tiny synthetic scene; no game performance or GPU-rendering claim.",
		"signal_order_before_idle": immediate_order, "signal_order_after_idle": _signal_order,
		"nested_deferred_process_frame_ids": _cascade_frames,
		"three_queued_redraws_draw_notifications": redraw_batch, "hidden_process_callbacks": hidden_processes, "hidden_draw_notifications": hidden_draws,
		"refreshes_by_process_frame": refreshes_by_frame, "frames_with_multiple_refreshes": duplicate_frames,
		"refresh_trace": node.refreshes, "default_timer_fired_while_tree_paused": default_timer_fired_while_paused,
		"pausable_timer_held_until_unpause": pausable_held, "pausable_timer_resumed": _pausable_fired,
		"failures": _failures, "ok": _failures.is_empty()}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		_failures.append("Could not open report output.")
	else:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	Engine.time_scale = original_scale
	node.queue_free()
	await _wait_frames(1)
	print("Engine contracts: %s. Report: %s" % ["PASS" if _failures.is_empty() else str(_failures), output])
	quit(0 if _failures.is_empty() else 1)

func _wait_frames(count: int) -> void:
	for frame in count: await process_frame

func _on_immediate() -> void:
	_signal_order.append("immediate")

func _on_deferred() -> void:
	_signal_order.append("deferred")

func _cascade(depth: int) -> void:
	_cascade_frames.append(Engine.get_process_frames())
	if depth < 3: _cascade.call_deferred(depth + 1)

func _on_pausable_timeout() -> void:
	_pausable_fired = true

func _require(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
