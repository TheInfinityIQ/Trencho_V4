extends SceneTree
## A hidden rear view must continue to own the same active session.

const Main = preload("res://game/main/main.tscn")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Control = Main.instantiate()
	root.add_child(main)
	await process_frame
	var base: Control = main.get("_base")
	var battlefield: Control = main.get("_battlefield")
	var simulation: RefCounted = base.simulation
	_check(base.is_inside_tree() and battlefield.is_inside_tree(), "Both views remain in the scene tree")
	_check(simulation.connected_world and simulation.rear.combat.world.bounds == Rect2i(0, 0, 4000, 6000), "Normal launch owns a full-size shared world")
	_check(simulation.rear.objectives.objectives.has("resource-central"), "Central objective is registered on the live ledger")
	main._show_battlefield()
	_check(not base.visible and battlefield.visible and battlefield.simulation == simulation, "Battlefield uses the same session")
	_check(main.get("_field_clock").is_visible_in_tree() and not main.get("_diagnostics").visible,"Battlefield clock is reachable and diagnostics begin collapsed")
	main.get("_field_clock").get_child(2).pressed.emit()
	_check(simulation.speed == 2,"Battlefield 2x changes the shared session")
	main.get("_field_clock").get_child(0).pressed.emit()
	_check(simulation.speed == 0,"Battlefield Pause changes the same shared session")
	simulation.set_speed(1)
	await create_timer(0.15).timeout
	_check(simulation.rear.time > 0.0, "Rear clock advances while the rear view is hidden")
	var before: float = simulation.rear.time
	main._show_review("G01 Identity")
	await create_timer(0.15).timeout
	_check(base.is_inside_tree() and simulation.rear.time > before, "A diagnostic view does not pause the live session")
	main._show_base()
	_check(base.simulation == simulation and battlefield.simulation == simulation, "Return retains the same identities")
	simulation.set_speed(0)
	var paused: float = simulation.rear.time
	await create_timer(0.05).timeout
	_check(is_equal_approx(simulation.rear.time, paused), "Pause still stops the common clock")
	_check(simulation.audit().is_empty(), "Connected session audit is clean")
	base._start_session()
	_check(base.simulation != simulation and battlefield.simulation == base.simulation, "New session rebinding is event driven")
	_check(base.simulation.rear.time == 0.0 and base.simulation.rear.objectives.objectives.has("resource-central"), "New session starts paused with its own full-size world")
	print("Battlefield session regression: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
