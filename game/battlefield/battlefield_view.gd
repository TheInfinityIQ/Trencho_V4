extends Control
## Read-only strategic view of the same identities and clock used by the rear.

const WORLD_SIZE := Vector2(4000.0, 6000.0)
const PANEL_WIDTH := 350.0
var simulation: RefCounted
var zoom := 1.0
var pan := Vector2.ZERO
var selected_id := "resource-central"
var _dragging := false
var _refresh_elapsed := 0.0
var _inspector: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_WIDTH
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	_inspector = Label.new()
	_inspector.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inspector)
	_refresh()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.2:
		_refresh_elapsed = 0.0
		_refresh()
		queue_redraw()


func _map_rect() -> Rect2:
	return Rect2(Vector2(12, 12), Vector2(maxf(300.0, size.x - PANEL_WIDTH - 24.0), maxf(200.0, size.y - 24.0)))


func _scale() -> float:
	var area := _map_rect()
	return minf((area.size.x - 32.0) / WORLD_SIZE.x, (area.size.y - 72.0) / WORLD_SIZE.y) * zoom


func _screen(point: Vector2) -> Vector2:
	var area := _map_rect()
	return area.get_center() + (point - WORLD_SIZE / 2.0) * _scale() + pan


func _world(point: Vector2) -> Vector2:
	return (point - _map_rect().get_center() - pan) / _scale() + WORLD_SIZE / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := _world(event.position)
			zoom = clampf(zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.7, 16.0)
			pan += event.position - _screen(before)
			queue_redraw()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _map_rect().has_point(event.position):
			_select_nearest(event.position)
	if event is InputEventMouseMotion and _dragging:
		pan += event.relative
		queue_redraw()


func _select_nearest(point: Vector2) -> void:
	if simulation == null: return
	var distance := 14.0
	for entity in simulation.rear.ledger.snapshot().entities:
		if entity.kind not in ["PERSON", "CARRIER", "PLACE"]: continue
		if entity.kind == "PLACE" and entity.id not in ["hq-berth", "enemy-hq", "resource-central"]: continue
		if entity.kind == "PERSON" and entity.rear_place == "Occupied": continue
		var measure: float = _screen(entity.position).distance_to(point)
		if measure < distance:
			distance = measure
			selected_id = entity.id
	_refresh()
	queue_redraw()


func _draw() -> void:
	var area := _map_rect()
	draw_rect(area, Color("172633"))
	var world_rect := Rect2(_screen(Vector2.ZERO), WORLD_SIZE * _scale())
	draw_rect(world_rect, Color("395442"))
	draw_rect(world_rect, Color("a5baaa"), false, 2.0)
	var font := ThemeDB.fallback_font
	for x in range(0, 4001, 1000):
		var top := _screen(Vector2(x, 0))
		var bottom := _screen(Vector2(x, 6000))
		draw_line(top, bottom, Color("678278", 0.45), 1.0)
	for y in range(0, 6001, 1000):
		draw_line(_screen(Vector2(0, y)), _screen(Vector2(4000, y)), Color("678278", 0.45), 1.0)
	if simulation == null: return
	for entity in simulation.rear.ledger.snapshot().entities:
		if entity.kind == "PLACE" and entity.id in ["hq-berth", "enemy-hq", "resource-central"]:
			var colour := Color("f0c565") if entity.id == "resource-central" else (Color("73bde4") if entity.id == "hq-berth" else Color("e17c72"))
			_draw_marker(entity.position, colour, entity.id, font)
		elif entity.kind == "CARRIER" and entity.design_type in ["T01", "T02", "T03", "T04", "T05"] and entity.position.x >= 240.0:
			_draw_marker(entity.position, Color("74c8ed") if entity.owner == "army-blue" else Color("e48378"), entity.id, font)
		elif entity.kind == "PERSON" and entity.rear_place != "Occupied" and entity.holder_id not in ["hq-berth", "hq-stock", "hq-reserve"]:
			_draw_marker(entity.position, Color("b8e9fa") if entity.owner == "army-blue" else Color("f2aea0"), "", font, entity.id)
	draw_string(font, area.position + Vector2(12, 22), "BATTLEFIELD  •  4,000 × 6,000 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e8f2ec"))
	draw_line(area.position + Vector2(16, area.size.y - 24), area.position + Vector2(16 + 1000.0 * _scale(), area.size.y - 24), Color.WHITE, 3.0)
	draw_string(font, area.position + Vector2(16, area.size.y - 30), "1 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_marker(position: Vector2, colour: Color, title: String, font: Font, entity_id: String = "") -> void:
	var point := _screen(position)
	var id := entity_id if not entity_id.is_empty() else title
	draw_circle(point, 6.0 if id == selected_id else 4.0, colour)
	if id == selected_id: draw_arc(point, 10.0, 0.0, TAU, 24, Color.WHITE, 1.5)
	if not title.is_empty() or id == selected_id: draw_string(font, point + Vector2(8, -6), id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _refresh() -> void:
	if _inspector == null or simulation == null: return
	var rear: RefCounted = simulation.rear
	var view: Dictionary = simulation.snapshot()
	var objective: Dictionary = rear.objectives.inspect("resource-central")
	var selected: Dictionary = rear.ledger.inspect_entity(selected_id)
	var detail := ""
	if not selected.is_empty():
		detail = "%s  •  %s\nHolder: %s\nPosition: (%.0f, %.0f) m" % [selected.id, selected.kind, selected.holder_id, selected.position.x, selected.position.y]
		if selected.kind == "PERSON": detail += "\nDuty: %s | Health: %d" % [selected.assignment, selected.health]
	var blocked: String = objective.get("blocked_reason", "No objective registered.")
	_inspector.text = "BATTLEFIELD\n\nTime: %.1f s  •  %s\nRequisition: %.0f\n\nCentral resource objective\nControl: %.1f / 60\nOwner: %s\nIncome: %.1f per second\n%s\n\nSelected\n%s\n\nWheel: zoom  •  Middle drag: pan\nClick a marker to inspect.\nMilitary action is autonomous; use Rear base to manage supply." % [rear.time, "Paused" if simulation.speed == 0 else "%dx" % simulation.speed, view.receiving.money, objective.get("control", 0.0), objective.get("owner", "Neutral") if not str(objective.get("owner", "")).is_empty() else "Neutral", objective.get("income_rate", 0.0), blocked, detail]
