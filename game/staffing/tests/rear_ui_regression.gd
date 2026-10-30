extends SceneTree
## Signals/bounds supplement native inspection; never claimed as OS-input proof.

const Demo = preload("res://game/staffing/rear_demo.tscn")
const Main = preload("res://game/main/main.tscn")
var _demo: Control
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1000, 720)
	_demo = Demo.instantiate()
	root.add_child(_demo)
	await _settle()
	_layout("A05 initial")
	_press("+300s")
	_check(_demo.simulation.workshop_readiness().hauling_shortage, "Actual UI starts with operator-only Missing Inputs")
	_press("Hauling target 1")
	_press("+300s")
	_check(_demo.simulation.workshop_readiness().missing.is_empty(), "Hauling button/time controls supply real local inputs")
	_check(_demo.get("_readiness").text.contains("output 0"), "UI discloses staged A05 limit")
	for index in range(5):
		_tab(index)
		await _settle()
		_layout("Populated tab %d" % index)
	_press("Reset A06 carry")
	_tab(2)
	var jobs: Tree = _demo.get("_jobs")
	jobs.get_root().get_first_child().select(0)
	jobs.item_selected.emit()
	_check(_demo.get("_detail").text.contains("Source promised 25 · actually carried 0"), "Selected job distinguishes pre-pickup promises")
	_press("+2s")
	_check(_demo.simulation.actors["worker-01"].phase == "Carry", "Native-review carry scenario exposes a real carried load")
	_check(_demo.get("_detail").text.contains("Source promised 0 · actually carried 25"), "Selected job refreshes to current carried stock after time advances")
	_tab(1)
	_check(_demo.get("_people_detail").text.contains("Actual carried stock portion-"), "Person details refresh the actual carrying holder")
	_press("Release haulers")
	_check(_demo.simulation.ledger.inspect_entity("worker-01").pending_assignment == "Available", "Release control keeps carrying duty pending")
	_press("No safe stores")
	_press("+2s")
	_check(_demo.simulation.ledger.inspect_entity("worker-01").carrying_stock_id == "", "Actual safe pile deposit finishes the pending handoff")
	_check(_demo.get("_people_detail").text.contains("Actual carried stock None"), "Safe deposit clears the selected person's displayed carry")
	_tab(2)
	_press("Reset A06 approach")
	_check(_demo.simulation.actors["worker-01"].phase == "Approach", "Separate UI scenario really approaches a remote source")
	_tab(1)
	_press("Release haulers")
	_check(_demo.simulation.ledger.reserved("fixture-metal") == 0, "Approach release returns the actual source claim")
	_tab(3)
	await _settle()
	_layout("Marked recovery pile")
	_press("Reset A06 driver")
	_tab(4)
	_press("+2s")
	_press("+1s")
	_press("Drive to reserved parking")
	_press("+1s")
	_press("Release yard driver")
	_check(_demo.simulation.ledger.inspect_entity("driver-01").crew_station == "Driver", "Driver release button cannot leave a moving hull uncrewed")
	await _settle()
	_layout("Moving driver pending")
	_press("+60s")
	_check(_demo.simulation.yard.driver == "" and _demo.simulation.yard.occupied[1] == "yard-t01", "Actual parking and exit occur before duty release")
	_press("Yard target 1")
	_press("+2s")
	_press("+1s")
	_check(_demo.simulation.yard.state == "Ready" and _demo.simulation.ledger.inspect_entity("driver-01").holder_id == "yard-t01", "Yard UI can report and re-enter the actual current parked hull")
	_check(_demo.get("_yard").text.contains("Ready"), "Yard inspection refreshes after parked re-entry")
	_check(_demo.simulation.audit().is_empty(), "UI flows preserve physical invariants")
	root.size = Vector2i(960, 540)
	for index in range(5):
		_tab(index)
		await _settle()
		_layout("960x540 tab %d" % index)
	_demo.free()
	var main: Control = Main.instantiate()
	root.add_child(main)
	await _settle()
	var live_base: Control = main.get("_base")
	_check(main.get("_host").get_child_count() == 2 and live_base.visible and not main.get("_battlefield").visible, "Normal launch keeps one live session with two views")
	main.call("_show_review", "G02 Procurement")
	await _settle()
	var procurement_review: Control = main.get("_review")
	_check(procurement_review.get_script() == preload("res://game/procurement/receiving_demo.gd") and not live_base.visible, "Accepted G02 diagnostic remains selectable over the retained session")
	main.call("_show_review", "G01 Identity")
	await _settle()
	_check(main.get("_host").get_child_count() == 3 and not is_instance_valid(procurement_review) and main.get("_base") == live_base and main.get("_review").get_script() == preload("res://game/identity/identity_demo.gd"), "G01 replaces only the previous diagnostic and retains the live session")
	main.queue_free()
	print("G03 UI signals/layout: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _press(text: String) -> void:
	var matches: Array[Button] = []
	for button in _demo.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree(): matches.append(button)
	_check(matches.size() == 1, "One visible button: " + text)
	if matches.size() == 1: matches[0].pressed.emit()


func _tab(index: int) -> void:
	for tabs in _demo.find_children("*", "TabContainer", true, false): tabs.current_tab = index


func _settle() -> void:
	await process_frame
	await process_frame


func _layout(context: String) -> void:
	_bounds(_demo, _demo.get_global_rect(), false, context)


func _bounds(node: Node, bounds: Rect2, in_scroll: bool, context: String) -> void:
	if node is Control and node.is_visible_in_tree() and not in_scroll:
		_check(bounds.grow(1).encloses(node.get_global_rect()), context + " keeps " + node.get_class() + " within view: " + str(node.get_global_rect()))
	for child in node.get_children(): _bounds(child, bounds, in_scroll or node is ScrollContainer, context)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)
