extends Control
## Draw/hit testing transforms only authoritative metre positions, never simulated icons.
signal selected(kind: String, id: String)
signal placement_hovered(world_position: Vector2)
signal placement_requested(world_position: Vector2)
signal placement_cancelled()
signal placement_rotated()
const Layout = preload("res://game/staffing/rear_layout.gd")
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
const FACTORY_ART: Texture2D = preload("res://game/test_art/tiny_battle/tile_0047.png")
const TRUCK_ART: Texture2D = preload("res://game/test_art/tiny_battle/tile_0132.png")
const PRODUCTION_KINDS := ["workshop","munitions","materials","support","vehicle_works"]
var simulation: RefCounted
var zoom: float = 1.0
var pan := Vector2.ZERO
var selection := ""
var placement_preview: Dictionary = {}
var _dragging := false
var placement_active := false
var input_blocked := false
## The player is a scene-owned avatar, never a free member of the worker pool.
var character_enabled := false
var character_position := Vector2(16, 90)
const CHARACTER_SPEED := 5.0

func begin_placement() -> void:
	placement_active = true
	grab_focus()
	placement_hovered.emit(_world(get_local_mouse_position()))

func end_placement() -> void:
	placement_active = false
	placement_preview = {}
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if input_blocked or not placement_active or not is_visible_in_tree(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			end_placement()
			placement_cancelled.emit()
		elif event.physical_keycode == KEY_R:
			placement_rotated.emit()
			placement_hovered.emit(_world(get_local_mouse_position()))
		else: return
		get_viewport().set_input_as_handled()

func enable_character(enabled: bool) -> void:
	end_placement()
	character_enabled = enabled
	character_position = Vector2(16, 90)
	queue_redraw()

func _process(delta: float) -> void:
	if input_blocked or not character_enabled or not is_visible_in_tree() or simulation == null: return
	# Global key state ignores GUI consumption: never walk while editing a field.
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit or not get_window().has_focus(): return
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	if direction.is_zero_approx() or simulation.speed == 0: return
	move_character(direction, minf(delta, 0.1)*simulation.speed)

func move_character(direction: Vector2, seconds: float) -> void:
	if not character_enabled or not is_finite(seconds) or seconds <= 0.0: return
	var step := direction.limit_length()*CHARACTER_SPEED*minf(seconds, 0.2)
	# Resolve axes separately to slide along built footprints without crossing them.
	for offset in [Vector2(step.x, 0), Vector2(0, step.y)]:
		var candidate: Vector2 = character_position+offset
		if not Rect2(0.5, 0.5, 239, 179).has_point(candidate): continue
		var blocked := false
		for row in simulation.rear.construction.instances.values():
			if row.state in ["Cancelled", "Dismantled"]: continue
			if Rect2(row.center-row.size/2.0, row.size).grow(0.5).has_point(candidate):
				blocked = true
				break
		if not blocked: character_position = candidate
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
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
	if input_blocked: return
	if placement_active:
		if event is InputEventMouseMotion:
			placement_hovered.emit(_world(event.position))
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				placement_requested.emit(_world(event.position))
				accept_event()
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				end_placement()
				placement_cancelled.emit()
				accept_event()
				return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE: _dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := _world(event.position)
			zoom = clampf(zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.65, 4.0)
			pan += event.position - map_point(before)
			if placement_active: placement_hovered.emit(_world(event.position))
			queue_redraw()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point := _world(event.position)
			var nearest := ""
			var distance := 9.0 / _scale()
			for entity in simulation.rear.ledger.map_markers():
				if entity.owner == "army-red": continue
				if entity.kind not in ["PERSON", "CARRIER"]: continue
				if entity.kind == "PERSON" and entity.holder_id not in ["rear", "rear-lane", "personnel"] and not entity.holder_id.begins_with("duty-"): continue
				if entity.position.distance_to(point) < distance:
					nearest = entity.id
					distance = entity.position.distance_to(point)
			if not nearest.is_empty():
				selection = nearest
				selected.emit("entity", nearest)
			else:
				var hit_site := false
				for row in simulation.rear.construction.instances.values():
					if row.id.begins_with("initial-") or row.state in ["Cancelled","Dismantled"]: continue
					if Rect2(row.center-row.size/2.0,row.size).grow(2).has_point(point):
						selection = row.id
						selected.emit("site",row.id)
						hit_site = true
						break
				if character_enabled and point.distance_to(Vector2(10,90)) <= 5.0:
					selection = "terminal"
					selected.emit("building", "terminal")
				elif not hit_site and not character_enabled:
					for id in Layout.FACILITIES:
						var f: Array = Layout.FACILITIES[id]
						if Rect2(f[1] - f[2] / 2, f[2]).grow(2).has_point(point):
							selection = id
							selected.emit("building", id)
			queue_redraw()
	if event is InputEventMouseMotion and _dragging:
		pan += event.relative
		if placement_active: placement_hovered.emit(_world(event.position))
		queue_redraw()

func _draw() -> void:
	var started_usec: int = Time.get_ticks_usec() if CallLog.enabled else 0
	_draw_contents()
	if CallLog.enabled: CallLog.record_duration(&"rear_base/base_map.gd::_draw",Time.get_ticks_usec()-started_usec)

func _draw_contents() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("16242b"))
	if simulation == null: return
	var scale := _scale()
	draw_rect(Rect2(map_point(Vector2.ZERO), Vector2(240, 180) * scale), Color("243d3c"))
	for x in range(0, 241, 20): draw_line(map_point(Vector2(x, 0)), map_point(Vector2(x, 180)), Color("2d4846"))
	for y in range(0, 181, 20): draw_line(map_point(Vector2(0, y)), map_point(Vector2(240, y)), Color("2d4846"))
	var font := ThemeDB.fallback_font
	for id in Layout.FACILITIES:
		if character_enabled: continue
		var f: Array = Layout.FACILITIES[id]
		var box := Rect2(map_point(f[1] - f[2] / 2), f[2] * scale)
		draw_rect(box, Color("506574"))
		if id in PRODUCTION_KINDS and simulation.rear.construction.instances.get("initial-"+id,{}).get("state","") == "Complete":
			_draw_icon(FACTORY_ART,box)
		draw_rect(box, Color("ffd37c") if id == selection else Color("8ea6b2"), false, 2)
		draw_circle(map_point(f[4]), 3, Color("b3d69a"))
		draw_string(font, box.position + Vector2(0, -4), f[0] + " " + id.replace("vehicle_works", "vehicles"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	for row in simulation.rear.construction.instances.values():
		if row.id.begins_with("initial-") or row.state in ["Cancelled","Dismantled"]: continue
		var box := Rect2(map_point(row.center-row.size/2.0),row.size*scale)
		var fill := Color("558b76") if row.state == "Complete" else Color("a77745")
		draw_rect(box,fill)
		if row.state == "Complete" and row.kind in PRODUCTION_KINDS and simulation.rear.construction.activities.has(row.id):
			_draw_icon(FACTORY_ART,box)
		draw_rect(box,Color("ffd37c") if row.id == selection else Color("a8d7b2"),false,2)
		draw_circle(map_point(row.door),3,Color("b3d69a"))
		draw_string(font,box.position+Vector2(0,-4),row.kind+" "+row.id,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
	if placement_preview.has("footprint"):
		var ghost: Rect2 = placement_preview.footprint
		var tint := Color("90e2bf") if placement_preview.get("ok",false) else Color("ff817c")
		if placement_preview.get("ok",false) and placement_preview.get("provisional",false): tint = Color("ffd37c")
		draw_rect(Rect2(map_point(ghost.position),ghost.size*scale),Color(tint,0.3))
		draw_rect(Rect2(map_point(ghost.position),ghost.size*scale),tint,false,2)
	for entity in simulation.rear.ledger.map_markers():
		if entity.owner == "army-red": continue
		var point := map_point(entity.position)
		if entity.kind == "STOCK" and entity.quantity > 0 and simulation.rear.ledger.entity_kind(entity.holder_id) == "PLACE":
			draw_rect(Rect2(point + Vector2(3, 3), Vector2(5, 5)), Color("ddbd72"))
		if entity.kind in ["CARRIER", "HEAVY_OBJECT"]:
			if entity.position.x < -10: continue
			draw_rect(Rect2(point - Vector2(7, 4), Vector2(14, 8)), Color("dba274"))
			if entity.kind == "CARRIER" and entity.design_type == "T01" and entity.owner == simulation.rear.PLAYER:
				_draw_icon(TRUCK_ART,Rect2(point-Vector2(7,4),Vector2(14,8)))
		if entity.kind != "PERSON": continue
		# Passengers/drivers remain visibly on their carrier; don't draw them as loose workers.
		if simulation.rear.ledger.entity_kind(entity.holder_id) == "CARRIER": continue
		if entity.position.x < 0: continue
		draw_circle(point, 4.0, Color("82e3b0") if entity.owner == "army-blue" else Color("dba274"))
		if not entity.carrying_stock_id.is_empty(): draw_rect(Rect2(point + Vector2(4, -5), Vector2(6, 6)), Color("ffd37c"))
		if entity.id == selection: draw_arc(point, 8, 0, TAU, 20, Color.WHITE, 2)
	if character_enabled:
		var table := map_point(Vector2(10,90))
		draw_rect(Rect2(table-Vector2(6,4),Vector2(12,8)),Color("ddbd72"))
		draw_string(font,table+Vector2(10,-8),"Supply Table / arrivals",HORIZONTAL_ALIGNMENT_LEFT,-1,14)
		var player := map_point(character_position)
		draw_circle(player,7,Color("80caff"))
		draw_arc(player,10,0,TAU,24,Color.WHITE,2)
		draw_string(font,player+Vector2(12,-8),"You",HORIZONTAL_ALIGNMENT_LEFT,-1,14)
		draw_string(font,Vector2(12,size.y-32),"WASD move at 1x / 2x | wheel zoom | middle-drag pan",HORIZONTAL_ALIGNMENT_LEFT,-1,14)
		return
	var ledger: RefCounted = simulation.rear.ledger
	if simulation.expanded_catalogue:
		var totals: Array[String] = []
		for activity in [simulation.rear.production, simulation.rear.munitions_production, simulation.rear.materials_production, simulation.rear.support_production]:
			var type: String = activity._spec.output_type
			totals.append("%s %s: %d" % [activity._spec.facility, type, ledger.total_stock(type,simulation.rear.PLAYER)])
		draw_string(font, Vector2(12, size.y - 50), "Physical outputs | " + " | ".join(totals), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	else:
		draw_string(font, Vector2(12, size.y - 50), "Own physical goods: %d rifles | %d rounds | %d materials | %d explosives" % [ledger.total_stock("E01",simulation.rear.PLAYER), ledger.total_stock("E02",simulation.rear.PLAYER), ledger.total_stock("M11",simulation.rear.PLAYER), ledger.total_stock("M06",simulation.rear.PLAYER)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
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

func _draw_icon(texture: Texture2D, bounds: Rect2) -> void:
	var dimensions := texture.get_size()
	var factor := minf(1.0,minf(bounds.size.x/dimensions.x,bounds.size.y/dimensions.y))
	var extent := dimensions*factor
	draw_texture_rect(texture,Rect2(bounds.get_center()-extent/2.0,extent),false)
