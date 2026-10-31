extends SceneTree
## A hidden rear view must continue to own the same active session.

const Main = preload("res://game/main/main.tscn")
const Base = preload("res://game/rear_base/base_simulation.gd")
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
	_check(battlefield.selected_id == "resource-central" and battlefield.get("_inspector").text.contains("Central resource"),"Legacy diagnostic starts selected on its real registered central objective")
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
	var launch: Button
	for button in main.find_children("*","Button",true,false):
		if button.text == "New playtest": launch = button
	_check(launch != null,"Ordinary New playtest action is reachable")
	launch.pressed.emit()
	_check(battlefield.simulation == base.simulation and battlefield.selected_id == "resource-centre-blue","New playtest immediately replaces stale legacy selection with actual blue Resource2")
	var text: String = battlefield.get("_inspector").text
	_check(text.contains("Farmland") and text.contains("Resource 2") and text.contains("Selected\nResource 2\nPosition: (2000, 2600)") and not text.contains("Central resource"),"New playtest immediately shows current family, real context and selected marker before periodic refresh")
	for id in ["start-blue-vehicle-00","start-blue-squad-00-person-00"]:
		battlefield.selected_id = id
		battlefield._refresh()
		text = battlefield.get("_inspector").text
		_check(battlefield.selected_id == id and text.contains("Resource 2\nControl:") and not text.contains("Central resource"),"Own unit selection retains real Resource2 objective context")
	battlefield.selected_id = "missing-old-entity"
	battlefield._refresh()
	_check(battlefield.selected_id == "resource-centre-blue","Stale selection refresh resolves to an actual registered marker")
	var custom: RefCounted = Base.new(false,true,false,Vector2(1640,91),false)
	custom.rear.ledger.add_place("custom-objective","Actual standalone objective",Vector2(2000,3000))
	custom.rear.objectives.register("custom-objective","Observation")
	battlefield.bind(custom)
	_check(battlefield.selected_id == "custom-objective" and battlefield.get("_inspector").text.contains("custom-objective\nControl:"),"Generic fixture without either preferred name uses its actual registered objective")
	var empty: RefCounted = Base.new(false,true,false,Vector2(1640,91),false)
	battlefield.bind(empty)
	_check(battlefield.selected_id.is_empty() and battlefield.get("_inspector").text.contains("No objective registered.") and not battlefield.get("_inspector").text.contains("Control:"),"Session without objectives has no phantom marker or objective statistics")
	base.scenario.select(0)
	base._start_session()
	_check(battlefield.simulation == base.simulation and battlefield.selected_id == "resource-central" and battlefield.get("_inspector").text.contains("Selected\nCentral resource"),"Returning to legacy diagnostic restores its actual central objective immediately")
	print("Battlefield session regression: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
