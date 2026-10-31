extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Main = preload("res://game/main/main.tscn")
const RearStart = preload("res://game/scenario/rear_start.gd")
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
	# Old UI values must not issue commands into the replacement session.
	demo.targets.workshop.value = 2
	check(base.rear.requests.workshop.target == 2,"Visible user target change still executes its real staffing command")
	for duty in demo.targets: demo.targets[duty].set_value_no_signal(1)
	demo.instructor_count.set_value_no_signal(1)
	demo.cart.M01.set_value_no_signal(5)
	demo.stock_target.set_value_no_signal(17)
	demo.bay_access.set_pressed_no_signal(false)
	demo.parking_access.set_pressed_no_signal(false)
	demo.capacity.set_value_no_signal(123)
	demo.accessible.set_pressed_no_signal(false)
	var signals := {"changes":0}
	for control in demo.targets.values()+demo.cart.values()+[demo.instructor_count,demo.stock_target,demo.capacity]:
		control.value_changed.connect(func(_value: float) -> void: signals.changes += 1)
	for control in [demo.bay_access,demo.parking_access,demo.accessible,demo.training_access]:
		control.toggled.connect(func(_value: bool) -> void: signals.changes += 1)
	demo.tabs.current_tab = demo.tabs.get_node("Supply").get_index()
	var prior_tab: int = demo.tabs.current_tab
	demo.status.text = "No rear refresh during direct battlefield launch"
	main._start_playtest()
	var fresh: RefCounted = demo.simulation
	check(not demo.visible and field.visible and field.simulation == fresh and demo.base_map.simulation == fresh and demo.forward_delivery_panel.simulation == fresh,"Direct battlefield launch keeps all views bound to one replacement session")
	check(demo.get("_displayed_time") == -INF and demo.status.text == "No rear refresh during direct battlefield launch","Hidden launch skips the final full rear refresh and invalidates its displayed time")
	check(signals.changes == 0 and demo.cart.M01.value == 0,"Programmatic reset and choice loading emit no UI change commands")
	for duty in RearStart.STAFF:
		check(fresh.rear.requests[duty].target == RearStart.STAFF[duty],"New session retains authored staffing: "+duty)
	for duty in demo.targets:
		check(demo.targets[duty].value == fresh.rear.requests[duty].target,"Staff UI loads actual new request: "+duty)
	check(demo.instructor_count.value == fresh.rear.requests.training.target and demo.stock_target.value == fresh.rear.production.stock_target,"Instructor and production controls load actual seeded targets")
	check(fresh.rear.time == 0 and fresh.speed == 0 and field.selected_id == "resource-centre-blue","Launch remains paused at zero with actual Resource2 selection")
	var ledger_events: int = fresh.rear.ledger._events.size()
	var rear_events: int = fresh.rear._events.size()
	demo._load_production()
	demo._load_store()
	check(signals.changes == 0 and fresh.rear.time == 0 and fresh.rear.ledger._events.size() == ledger_events and fresh.rear._events.size() == rear_events,"Read loaders neither signal commands nor settle or advance physical state")
	main._show_base()
	check(demo.get("_displayed_time") == 0 and demo.status.text != "No rear refresh during direct battlefield launch" and demo.tabs.current_tab == prior_tab,"First return builds fresh rear state and preserves the selected tab")
	demo.scenario.select(0)
	demo._start_session()
	check(demo.visible and demo.get("_displayed_time") == 0 and field.simulation == demo.simulation and field.selected_id == "resource-central","Normal visible Orders session creation still refreshes immediately and retains its real diagnostic objective")
	main.queue_free()
	await process_frame
	print("UI refresh regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(detail)
