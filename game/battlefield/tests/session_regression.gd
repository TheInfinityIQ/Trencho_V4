extends SceneTree
## A hidden rear view must continue to own the same active session.

const Main = preload("res://game/main/main.tscn")
const FarmlandMap = preload("res://game/battlefield/farmland_scenario.gd")
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
	_check(_declared_objectives_present(simulation), "Every authored default-world objective is registered on the live ledger")
	_check(simulation.empty_field_opening and base.base_map.character_enabled, "Normal launch retains the playable empty-field opening")
	main._show_battlefield()
	_check(not base.visible and battlefield.visible and battlefield.simulation == simulation, "Battlefield uses the same session")
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
	main._start_playtest()
	_check(base.simulation != simulation and battlefield.simulation == base.simulation, "New session rebinding is event driven")
	_check(base.simulation.rear.time == 0.0 and base.simulation.speed == 0 and _declared_objectives_present(base.simulation), "New session starts paused with all authored default-world objectives")
	print("Battlefield session regression: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _declared_objectives_present(simulation: RefCounted) -> bool:
	if FarmlandMap.OBJECTIVES.is_empty(): return false
	for objective in FarmlandMap.OBJECTIVES:
		if not simulation.rear.objectives.objectives.has(objective.id): return false
	return true


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
