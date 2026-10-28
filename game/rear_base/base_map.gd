extends Control
## Draw/hit testing transforms only authoritative metre positions, never simulated icons.
signal selected(kind: String, id: String)
const Layout = preload("res://game/staffing/rear_layout.gd")
var simulation: RefCounted
var zoom: float = 1.0
var pan := Vector2.ZERO
var selection := ""
var _dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(340, 250)
	resized.connect(queue_redraw)

func _scale() -> float:
	return minf(size.x / 260.0, size.y / 200.0) * zoom

func map_point(world: Vector2) -> Vector2:
	return size / 2.0 + (world - Vector2(120, 90)) * _scale() + pan

func _world(point: Vector2) -> Vector2:
	return (point - size / 2.0 - pan) / _scale() + Vector2(120, 90)

func reset_camera() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE: _dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := _world(event.position)
			zoom = clampf(zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.65, 4.0)
			pan += event.position - map_point(before)
			queue_redraw()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point := _world(event.position)
			var nearest := ""
			var distance := 9.0 / _scale()
			for entity in simulation.rear.ledger.snapshot().entities:
				if entity.kind not in ["PERSON", "CARRIER"]: continue
				if entity.kind == "PERSON" and entity.holder_id not in ["rear", "rear-lane", "personnel"] and not entity.holder_id.begins_with("duty-"): continue
				if entity.position.distance_to(point) < distance:
					nearest = entity.id
					distance = entity.position.distance_to(point)
			if not nearest.is_empty():
				selection = nearest
				selected.emit("entity", nearest)
			else:
				for id in Layout.FACILITIES:
					var f: Array = Layout.FACILITIES[id]
					if Rect2(f[1] - f[2] / 2, f[2]).grow(2).has_point(point):
						selection = id
						selected.emit("building", id)
			queue_redraw()
	if event is InputEventMouseMotion and _dragging:
		pan += event.relative
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("16242b"))
	if simulation == null: return
	var scale := _scale()
	draw_rect(Rect2(map_point(Vector2.ZERO), Vector2(240, 180) * scale), Color("243d3c"))
	for x in range(0, 241, 20): draw_line(map_point(Vector2(x, 0)), map_point(Vector2(x, 180)), Color("2d4846"))
	for y in range(0, 181, 20): draw_line(map_point(Vector2(0, y)), map_point(Vector2(240, y)), Color("2d4846"))
	var font := ThemeDB.fallback_font
	for id in Layout.FACILITIES:
		var f: Array = Layout.FACILITIES[id]
		var box := Rect2(map_point(f[1] - f[2] / 2), f[2] * scale)
		draw_rect(box, Color("506574"))
		draw_rect(box, Color("ffd37c") if id == selection else Color("8ea6b2"), false, 2)
		draw_circle(map_point(f[4]), 3, Color("b3d69a"))
		draw_string(font, box.position + Vector2(0, -4), f[0] + " " + id.replace("vehicle_works", "vehicles"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	for entity in simulation.rear.ledger.snapshot().entities:
		var point := map_point(entity.position)
		if entity.kind == "STOCK" and entity.quantity > 0 and not simulation.rear.ledger.inspect_entity(entity.holder_id).is_empty():
			var holder: Dictionary = simulation.rear.ledger.inspect_entity(entity.holder_id)
			if holder.kind == "PLACE": draw_rect(Rect2(point + Vector2(3, 3), Vector2(5, 5)), Color("ddbd72"))
		if entity.kind in ["CARRIER", "HEAVY_OBJECT"]:
			if entity.position.x < -10: continue
			draw_rect(Rect2(point - Vector2(7, 4), Vector2(14, 8)), Color("dba274"))
		if entity.kind != "PERSON": continue
		# Passengers/drivers remain visibly on their carrier; don't draw them as loose workers.
		if simulation.rear.ledger.inspect_entity(entity.holder_id).get("kind", "") == "CARRIER": continue
		if entity.position.x < 0: continue
		draw_circle(point, 4.0, Color("82e3b0") if entity.owner == "army-blue" else Color("dba274"))
		if not entity.carrying_stock_id.is_empty(): draw_rect(Rect2(point + Vector2(4, -5), Vector2(6, 6)), Color("ffd37c"))
		if entity.id == selection: draw_arc(point, 8, 0, TAU, 20, Color.WHITE, 2)
	var ledger: RefCounted = simulation.rear.ledger
	if simulation.expanded_catalogue:
		var totals: Array[String] = []
		for activity in [simulation.rear.production, simulation.rear.munitions_production, simulation.rear.materials_production, simulation.rear.support_production]:
			var type: String = activity._spec.output_type
			totals.append("%s %s: %d" % [activity._spec.facility, type, ledger.total_stock(type)])
		draw_string(font, Vector2(12, size.y - 50), "Physical outputs | " + " | ".join(totals), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	else:
		draw_string(font, Vector2(12, size.y - 50), "Physical goods: %d rifles | %d rounds | %d materials | %d explosives" % [ledger.total_stock("E01"), ledger.total_stock("E02"), ledger.total_stock("M11"), ledger.total_stock("M06")], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var training: RefCounted = simulation.rear.training
	for row in training.rows:
		if row.seat >= 0:
			var at: Vector2 = map_point(training.student_position(row.person_id))
			draw_circle(at,5,Color("84a2e5") if row.state == "Active" else Color("f3c477"),false,1.0)
	var heavy: RefCounted = simulation.rear.heavy_production
	var fleet: Dictionary = ledger.rear_fleet_status("army-blue")
	var bay: String = "occupied " + ledger.inspect_entity(heavy.bay_occupant).get("design_type", "") if not heavy.bay_occupant.is_empty() else ("order accepted" if not heavy._order.is_empty() else "empty")
	draw_string(font,Vector2(12,size.y-68),"F10 bay: %s | fleet %d live + %d reserved / 8" % [bay,fleet.live,fleet.reserved],HORIZONTAL_ALIGNMENT_LEFT,-1,12)
	draw_string(font, Vector2(12, size.y - 32), "240 x 180 m | green people / gold freight / orange vehicles", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2(12, size.y - 14), "Click to inspect | wheel zoom | middle-drag pan | Fit base", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
