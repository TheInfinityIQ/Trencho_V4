extends SceneTree
## Signal/layout evidence only. No OS input or visual acceptance is claimed.

const Main = preload("res://game/main/main.tscn")
const Fixtures = preload("res://game/terrain/terrain_fixtures.gd")
var _main: Control
var _demo: Control
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1000, 720)
	_main = Main.instantiate()
	root.add_child(_main)
	await _settle()
	_main.call("_show_review", "G08 Terrain & sight")
	_demo = _main.get("_host").get_child(0)
	_layout("Initial movement")
	_check(_demo.get("_lane").entity.type == "person", "Default case is labelled declared person")
	_press("Start lane")
	_press("+1s")
	_check(_demo.get("_lane").time == 1 and is_equal_approx(_demo.get("_lane").entity.position.x, 12), "Clock button moves actual person at2m/s")
	_press("Stop here")
	_press("+30s")
	_check(is_equal_approx(_demo.get("_lane").entity.position.x, 12), "UI stop preserves actual position")
	_press("Reset case")
	_check(_demo.get("_lane").time == 0, "Reset creates explicitly new declared case")
	var selector: OptionButton = _demo.get("_selector")
	for index in selector.item_count:
		selector.item_selected.emit(index)
		_press("Start lane")
		_press("+120s")
		var lane: RefCounted = _demo.get("_lane")
		_check(lane.state in ["Arrived", "Blocked"], "Named movement case settles visibly: " + selector.get_item_text(index))
		_check(not str(_demo.get("_summary").text).is_empty() and str(_demo.get("_detail").text).contains("footprint"), "Current body/cause inspection updates for actual case")
	_demo.get("_mode").item_selected.emit(1)
	await _settle()
	_layout("Sight controls")
	for index in selector.item_count:
		selector.item_selected.emit(index)
		var before: Dictionary = _demo.get("_observation").duplicate(true)
		var knowledge: String = _demo.get("_knowledge")
		var observer: Vector2 = _demo.get("_fixture").observer
		var overview: CheckButton = _demo.get("_overview")
		overview.button_pressed = not overview.button_pressed
		_check(_demo.get("_observation") == before and _demo.get("_knowledge") == knowledge and _demo.get("_fixture").observer == observer, "Overview never changes range, actual observer or knowledge: " + selector.get_item_text(index))
		_check(_demo.get("_diagram").visible_target == before.visible, "Diagram never draws unseen target")
		_check(str(_demo.get("_detail").text).contains("INDEPENDENT GROUND MUZZLE"), "Current eye/muzzle cause inspection")
		_check(str(_demo.get("_detail").text).contains("DECLARED BLAST IMPACT") and str(_demo.get("_detail").text).contains("blast_eligibility") and not str(_demo.get("_summary").text).contains("pending"), "Current explicit blast origin and cover eligibility replace pending classification")
	root.size = Vector2i(960, 540)
	await _settle()
	_layout("960x540 sight")
	_demo.get("_mode").item_selected.emit(0)
	await _settle()
	_layout("960x540 movement")
	# Root selectors retain accepted G01/G02 implementations unchanged.
	_main.call("_show_review", "G02 Procurement")
	await _settle()
	_check(_main.get("_host").get_child(0).get_script().resource_path == "res://game/procurement/receiving_demo.gd", "G02 review remains reachable")
	_main.call("_show_review", "G01 Identity")
	await _settle()
	_check(_main.get("_host").get_child(0).get_script().resource_path == "res://game/identity/identity_demo.gd", "G01 review remains reachable")
	_main.queue_free()
	await _settle()
	print("G08 UI signals/layout: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _press(text: String) -> void:
	var matches: Array[Button] = []
	_buttons(_demo, text, matches)
	_check(matches.size() == 1, "One control: " + text)
	if matches.size() == 1: matches[0].pressed.emit()


func _buttons(node: Node, text: String, matches: Array[Button]) -> void:
	if node is Button and node.text == text: matches.append(node)
	for child in node.get_children(): _buttons(child, text, matches)


func _settle() -> void:
	await process_frame
	await process_frame


func _layout(context: String) -> void:
	_bounds(_main, _main.get_global_rect(), false, context)


func _bounds(node: Node, rect: Rect2, scrolling: bool, context: String) -> void:
	if node is Control and node.is_visible_in_tree() and not scrolling:
		_check(rect.grow(1).encloses(node.get_global_rect()), "%s contains %s %s" % [context, node.get_class(), node.get_global_rect()])
	for child in node.get_children(): _bounds(child, rect, scrolling or node is ScrollContainer, context)


func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)
