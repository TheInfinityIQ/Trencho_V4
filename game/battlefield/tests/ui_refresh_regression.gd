extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Main = preload("res://game/main/main.tscn")
class CountedBase extends Base:
	var snapshot_calls := 0
	func snapshot() -> Dictionary:
		snapshot_calls += 1
		return super.snapshot()
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var main: Control = Main.instantiate()
	root.add_child(main)
	var demo: Control = main.get("_base")
	var field: Control = main.get("_battlefield")
	demo.set_process(false)
	field.set_process(false)
	var base := CountedBase.new(false,true)
	demo.simulation = base
	demo.base_map.simulation = base
	demo.forward_delivery_panel.bind(base)
	main._on_session_changed(base)
	main._show_base()
	demo._refresh()
	base.snapshot_calls = 0
	for step in 5: demo._process(0.25)
	check(base.snapshot_calls == 0,"Paused rear does not repeatedly build full state on idle frames")
	check(base.receiving.buy_resources({"M01":1}).ok,"Actual paused procurement changes requisition")
	demo._refresh()
	check(base.snapshot_calls == 1 and "2478" in demo.status.text,"Explicit same-time user refresh still shows physical procurement")
	main._show_battlefield()
	base.snapshot_calls = 0
	field._refresh()
	check(base.snapshot_calls == 0 and "2478" in field.get("_inspector").text,"Battlefield reads current account without a complete rear-state snapshot")
	for step in 5:
		demo._process(0.25)
		field._process(0.25)
	check(base.snapshot_calls == 0,"Hidden rear and idle battlefield do no repeated full-state reads")
	check(base.set_speed(1).ok,"Actual common clock starts")
	var before: float = base.rear.time
	demo._process(0.25)
	field._process(0.25)
	check(is_equal_approx(base.rear.time,before+0.25) and base.snapshot_calls == 0,"Hidden rear continues exact shared time while visible battlefield stays lightweight")
	check(base.set_speed(0).ok,"Common clock pauses")
	field._process(0.25)
	check("Paused" in field.get("_inspector").text,"Same-time speed change refreshes the battlefield inspector")
	main._show_base()
	check(base.snapshot_calls == 1,"Showing the rear refreshes once even at unchanged paused time")
	var shown_time: float = field.get("_displayed_time")
	check(base.set_speed(1).ok,"Common clock restarts")
	demo._process(0.25)
	field._process(0.25)
	check(base.snapshot_calls == 2 and field.get("_displayed_time") == shown_time,"Visible rear refreshes live state while hidden battlefield skips work")
	check(base.set_speed(0).ok,"Stop fixture clock")
	check(base.audit().is_empty(),"UI refresh scheduling preserves actual deliveries, clock and physical invariants")
	check(Engine.max_fps == 30,"Default game rendering honours the thirty-frame resource budget")
	main.queue_free()
	await process_frame
	print("UI refresh regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(detail)
