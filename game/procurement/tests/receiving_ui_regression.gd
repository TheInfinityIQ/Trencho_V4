extends SceneTree
## Engine-level control wiring/layout checks. This does not send OS input and is
## not native interaction or visual evidence.

const Demo = preload("res://game/procurement/receiving_demo.tscn")
var _demo: Control
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(960, 540)
	_demo = Demo.instantiate()
	root.add_child(_demo)
	await _settle()
	_layout("Initial Terminal")
	_press("+1s")
	_check(_simulation().snapshot().time == 1.0, "The +1s button advances one second, not another loop-captured duration")
	_press("Purchase quoted goods")
	_check(_simulation().resource_counts("M01").purchased == 100, "Purchase button uses its visible default quote")
	_press("+60s")
	_check(_simulation().resource_counts("M01").onboard == 100 and _simulation().resource_counts("M01").available == 0, "Timed arrival exposes onboard stock without granting local inventory")
	_press("Order 8 P00 · 120 + 20")
	_press("+60s")
	_check(_simulation().rear_population() == 0, "Manpower does not arrive before 90 seconds")
	for step in range(3):
		_press("+10s")
	for step in range(3):
		_press("+1s")
	_check(_simulation().snapshot().walks.size() == 1 and _simulation().rear_population() == 0 and _simulation().incoming_people() == 8, "At purchase +93s, only one passenger has exited and their walk has not admitted anyone")
	_check(_person_phase("delivery-0002-person-01") == "Walking to Personnel" and _person_phase("delivery-0002-person-02") == "Passenger aboard", "Inspection distinguishes the walking individual from passengers still aboard")
	var detail: Label = _demo.get("_detail")
	_check(detail.text.contains("incoming people reserved 8 · exited 1 · arrived at F08 0"), "Selected delivery exposes exit progress separately from actual F08 arrivals")
	_press("+10s")
	_check(_simulation().rear_population() == 4 and _simulation().incoming_people() == 4, "UI clock converts individual reservations at staggered F08 arrivals")
	_press("+10s")
	_check(_simulation().rear_population() == 8, "All actual people eventually self-disembark through the UI clock controls")
	_tab(2)
	await _settle()
	_layout("People and actual labour")
	_press("Assign 4 available people")
	_press("+60s")
	_check(_simulation().resource_counts("M01").carried == 100 and _simulation().resource_counts("M01").available == 0, "UI distinguishes actual in-flight carries from free depot stock")
	_press("+10s")
	_check(_simulation().resource_counts("M01").available == 100 and _simulation().freight_admitted() == 0, "Elapsed handling and clearance produce real local stock")
	_tab(1)
	await _settle()
	_layout("Populated delivery inspection")
	_press("Reset (zero workers)")
	_tab(0)
	_press("Purchase quoted goods")
	_tab(1)
	_press("Cancel selected (first 5 seconds)")
	_check(_simulation().snapshot().money == 2500.0 and _simulation().freight_admitted() == 0, "Selected-order cancellation refunds the actual quote")
	_press("Cancel selected (first 5 seconds)")
	_check(_simulation().snapshot().money == 2500.0, "Repeated UI cancellation cannot mint requisition")
	_press("A58: fill freight queue")
	_check(_simulation().freight_admitted() == 11 and _simulation().rear_population() == 0, "A58 setup executes eleven purchases and real arrival time with no workers")
	await _settle()
	_layout("Eleven real freight deliveries")
	_tab(0)
	_press("Order 8 P00 · 120 + 20")
	_press("+60s")
	_press("+60s")
	_tab(2)
	_press("Assign 4 available people")
	_press("+300s")
	_press("+60s")
	_check(_simulation().resource_counts("M03").available == 11 and _simulation().rear_population() == 8, "Engine-control callbacks support full-queue recovery without staff or stock shortcuts")
	_check(_simulation().audit().is_empty(), "All UI actions preserve G01/G02 accounting")
	_tab(0)
	var quantity: SpinBox = _demo.get("_quantity")
	quantity.value = 5001
	var quote: Label = _demo.get("_quote")
	_check(quote.text.contains("2 vehicle(s)") and quote.text.contains("Truck 2:"), "A large order shows both priced vehicles before purchase")
	var before: Dictionary = _simulation().snapshot()
	_press("Purchase quoted goods")
	_check(_simulation().snapshot() == before, "An unaffordable UI purchase remains atomic")
	await _settle()
	_layout("Multi-vehicle quote")
	var report := {"kind": "engine control wiring and geometry only", "checks": _checks,
		"failures": _failures, "physical_window": str(root.size),
		"logical_viewport": str(root.get_visible_rect()), "native_input_verified": false}
	var output := FileAccess.open("res://.artifacts/g02-ui-wiring.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t") + "\n")
	print("G02 UI wiring/layout: %d checks, %d failures" % [_checks, _failures])
	_demo.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _simulation() -> RefCounted:
	return _demo.get("_simulation")


func _person_phase(id: String) -> String:
	var people: Tree = _demo.get("_people")
	for row in people.get_root().get_children():
		if row.get_text(0) == id:
			return row.get_text(3)
	return "Missing"


func _press(text: String) -> void:
	var matches: Array[Button] = []
	_find_buttons(_demo, text, matches)
	_check(matches.size() == 1, "One matching control: " + text)
	if matches.size() == 1:
		matches[0].pressed.emit()


func _find_buttons(node: Node, text: String, matches: Array[Button]) -> void:
	if node is Button and node.text == text:
		matches.append(node)
	for child in node.get_children():
		_find_buttons(child, text, matches)


func _tab(index: int) -> void:
	for tab in _demo.find_children("*", "TabContainer", true, false):
		tab.current_tab = index


func _settle() -> void:
	await process_frame
	await process_frame


func _layout(context: String) -> void:
	var bounds := _demo.get_global_rect()
	_check_layout(_demo, bounds, false, context)


func _check_layout(node: Node, bounds: Rect2, inside_scroll: bool, context: String) -> void:
	if node is Control and node.is_visible_in_tree() and not inside_scroll:
		var rect: Rect2 = node.get_global_rect()
		_check(bounds.grow(1.0).encloses(rect), "%s keeps visible %s within the viewport: %s" % [context, node.get_class(), rect])
	for child in node.get_children():
		_check_layout(child, bounds, inside_scroll or node is ScrollContainer, context)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)
