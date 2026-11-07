extends Node
## Own the live clock independently of either screen.

signal simulation_changed(next_simulation: RefCounted)
signal state_changed
signal time_advanced

const Simulation = preload("res://game/rear_base/base_simulation.gd")
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
const Logistics = preload("res://game/logistics/rear_logistics.gd")
var simulation: RefCounted = Simulation.new(false, true)
var automatic_logistics: Node
var _last_live_process_frame := -1
var _presentation_pending := false
var _presentation_deferred_last := false


func _ready() -> void:
	var call_logger := CallLog.new()
	call_logger.name = "FunctionCallLog"
	add_child(call_logger)
	simulation.rear.state_changed.connect(_on_state_changed)
	automatic_logistics = Logistics.new(self)
	automatic_logistics.name = "RearLogistics"
	add_child(automatic_logistics)


func _physics_process(delta: float) -> void:
	CallLog.record(&"main/game_session.gd::_physics_process")
	# Physics catch-up may invoke this repeatedly before a single UI frame.
	# The wall-clock model accrues the complete elapsed interval on its next
	# pump; repeating planning/settlement here only compounds a slow frame.
	if simulation.uses_live_wall_clock():
		var frame := Engine.get_process_frames()
		if frame == _last_live_process_frame: return
		_last_live_process_frame = frame
		# A requested panel change has layout/render work of its own. Let one
		# frame present it without stacking a complete simulation transaction.
		# The monotonic clock retains every elapsed second for the next pump.
		if _presentation_pending and not _presentation_deferred_last:
			_presentation_pending = false
			_presentation_deferred_last = true
			return
		_presentation_pending = false
		_presentation_deferred_last = false
	var previous_time: float = simulation.rear.time
	var previous_revision: int = simulation.planning_view_revision
	# The opening prepares routes while paused; tick_live preserves that work
	# without advancing game time. Keep it independent of the visible screen.
	var started_usec: int = Time.get_ticks_usec() if CallLog.enabled else 0
	simulation.tick_live(delta)
	if CallLog.enabled: CallLog.record_duration(&"rear_base/base_simulation.gd::tick_live", Time.get_ticks_usec() - started_usec)
	if simulation.rear.time != previous_time or simulation.planning_view_revision != previous_revision:
		time_advanced.emit()


func reserve_presentation_frame() -> void:
	if simulation.uses_live_wall_clock() and simulation.speed > 0:
		_presentation_pending = true


func replace_simulation(next_simulation: RefCounted) -> void:
	if next_simulation == simulation: return
	simulation.rear.state_changed.disconnect(_on_state_changed)
	simulation.cancel_live_planning()
	simulation = next_simulation
	_last_live_process_frame = -1
	_presentation_pending = false
	_presentation_deferred_last = false
	simulation.rear.state_changed.connect(_on_state_changed)
	simulation_changed.emit(simulation)
	state_changed.emit()


func set_speed(value: int) -> Dictionary:
	var result: Dictionary = simulation.set_speed(value)
	state_changed.emit()
	return result


func notify_command() -> void:
	CallLog.record(&"main/game_session.gd::notify_command")
	# Commands can change state while the clock is paused.
	state_changed.emit()


func _on_state_changed() -> void:
	state_changed.emit()
