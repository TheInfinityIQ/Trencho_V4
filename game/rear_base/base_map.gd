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
const GRASS_ART: Texture2D = preload("res://game/test_art/tiny_battle/tile_0001.png")
const ARRIVAL_ART: Texture2D = preload("res://game/test_art/tiny_battle/tile_0016.png")
const INDOOR_ART: Texture2D = preload("res://game/test_art/roguelike_indoor/indoor_sheet.png")
const SUPPLY_TABLE_REGION := Rect2(119,0,16,16)
const MaterialCatalog = preload("res://game/procurement/resource_catalog.gd")
const STOCK_REGION := Rect2(374,68,16,16)
const CIVILIAN_LAYERS := [
	preload("res://game/test_art/roguelike_characters/neutral_body.tres"),
	preload("res://game/test_art/roguelike_characters/neutral_trousers.tres"),
	preload("res://game/test_art/roguelike_characters/neutral_shoes.tres"),
	preload("res://game/test_art/roguelike_characters/teal_shirt.tres"),
	preload("res://game/test_art/roguelike_characters/neutral_hair.tres"),
]
const FACILITY_ART := {
	"terminal": preload("res://game/test_art/tiny_battle/tile_0050.png"),
	"personnel": preload("res://game/test_art/tiny_battle/tile_0044.png"),
	"receiving": preload("res://game/test_art/tiny_battle/tile_0045.png"),
	"depot": preload("res://game/test_art/tiny_battle/tile_0045.png"),
	"workshop": FACTORY_ART,
	"munitions": preload("res://game/test_art/tiny_battle/tile_0048.png"),
	"materials": preload("res://game/test_art/tiny_battle/tile_0049.png"),
	"training": preload("res://game/test_art/tiny_battle/tile_0044.png"),
	"dispatch": preload("res://game/test_art/tiny_battle/tile_0045.png"),
	"support": FACTORY_ART,
	"vehicle_works": preload("res://game/test_art/tiny_battle/tile_0046.png"),
	"construction": preload("res://game/test_art/tiny_battle/tile_0050.png"),
	"park": preload("res://game/test_art/tiny_battle/tile_0052.png"),
}
const FACILITY_LABELS := {
	"terminal":"Terminal", "personnel":"Personnel", "receiving":"Receiving Bay",
	"depot":"Storage Depot", "workshop":"Workshop", "munitions":"Munitions Workshop",
	"materials":"Materials Plant", "training":"School", "dispatch":"Logistics Centre",
	"support":"Support Workshop", "vehicle_works":"Vehicle Works",
	"construction":"Construction Office", "park":"Vehicle Park",
}
var simulation: RefCounted
var zoom: float = 1.0
var pan := Vector2.ZERO
var selection := ""
var placement_preview: Dictionary = {}
var _dragging := false
var placement_active := false
var input_blocked := false
## The player pose belongs to the session, never the free worker pool.
var character_enabled := false
const ManagerPose = preload("res://game/preview_3d/manager_pose.gd")
var manager_pose: RefCounted = ManagerPose.new()
var character_position: Vector2:
	get: return manager_pose.ground_position()
	set(value):
		if simulation == null or not value.is_finite(): return
		var height: float = simulation.rear.combat.world.ground(value)
		manager_pose.publish_ground(value,height)
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
		if offset.is_zero_approx(): continue
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_draw_ground(scale)
	for x in range(0, 241, 20): draw_line(map_point(Vector2(x, 0)), map_point(Vector2(x, 180)), Color("2d4846"))
	for y in range(0, 181, 20): draw_line(map_point(Vector2(0, y)), map_point(Vector2(240, y)), Color("2d4846"))
	var font := ThemeDB.fallback_font
	var facility_labels: Array[Dictionary] = []
	for id in Layout.FACILITIES:
		if character_enabled: continue
		var f: Array = Layout.FACILITIES[id]
		var box := Rect2(map_point(f[1] - f[2] / 2), f[2] * scale)
		draw_rect(box, Color("506574"))
		if simulation.rear.construction.instances.get("initial-"+id,{}).get("state","") == "Complete":
			_draw_facility_art(id,box)
		draw_rect(box, Color("ffd37c") if id == selection else Color("8ea6b2"), false, 2)
		draw_circle(map_point(f[4]), 3, Color("b3d69a"))
		facility_labels.append({"at":box.position+Vector2(0,-4),"text":str(FACILITY_LABELS.get(id,id)),"size":12,"tint":Color.WHITE})
	for row in simulation.rear.construction.instances.values():
		if row.id.begins_with("initial-") or row.state in ["Cancelled","Dismantled"]: continue
		var box := Rect2(map_point(row.center-row.size/2.0),row.size*scale)
		var fill := Color("558b76") if row.state == "Complete" else Color("a77745")
		draw_rect(box,fill)
		if row.state in ["Complete","Awaiting M11","Building"]:
			_draw_facility_art(row.kind,box,Color.WHITE if row.state == "Complete" else Color(1,1,1,0.35))
		draw_rect(box,Color("ffd37c") if row.id == selection else Color("a8d7b2"),false,2)
		draw_circle(map_point(row.door),3,Color("b3d69a"))
		facility_labels.append({"at":box.position+Vector2(0,-4),"text":str(FACILITY_LABELS.get(row.kind,row.kind))+" "+row.id,"size":12,"tint":Color.WHITE})
		if row.state in ["Awaiting M11","Building"]:
			var progress := clampf(float(row.progress)/maxf(float(row.work),0.001),0.0,1.0)
			draw_rect(Rect2(Vector2(box.position.x,box.end.y-4),Vector2(box.size.x,3)),Color("243d3c"))
			draw_rect(Rect2(Vector2(box.position.x,box.end.y-4),Vector2(box.size.x*progress,3)),Color("ffd37c"))
			facility_labels.append({"at":box.position+Vector2(2,13),"text":"%s · %d%%" % [str(row.state).replace("M11","materials"),roundi(progress*100.0)],"size":10,"tint":Color.WHITE})
	if placement_preview.has("footprint"):
		var ghost: Rect2 = placement_preview.footprint
		var tint := Color("90e2bf") if placement_preview.get("ok",false) else Color("ff817c")
		if placement_preview.get("ok",false) and placement_preview.get("provisional",false): tint = Color("ffd37c")
		draw_rect(Rect2(map_point(ghost.position),ghost.size*scale),Color(tint,0.3))
		var kind := str(placement_preview.get("visual_kind",""))
		_draw_facility_art(kind,Rect2(map_point(ghost.position),ghost.size*scale),Color(tint,0.55))
		facility_labels.append({"at":map_point(ghost.position)+Vector2(0,-5),"text":"Preview · "+str(FACILITY_LABELS.get(kind,kind)),"size":12,"tint":tint})
		draw_rect(Rect2(map_point(ghost.position),ghost.size*scale),tint,false,2)
	# Neighbouring facility/preview artwork must not paint over existing names/state.
	for label: Dictionary in facility_labels:
		_draw_label(font,label.at,label.text,label.size,label.tint)
	var stock_groups: Dictionary = {}
	for entity in simulation.rear.ledger.map_markers():
		if entity.owner == "army-red": continue
		var point := map_point(entity.position)
		if entity.kind == "STOCK" and entity.quantity > 0 and simulation.rear.ledger.entity_kind(entity.holder_id) == "PLACE":
			# Group only identical holder/owner/position; counts remain physical, not available.
			var key: String = str(entity.holder_id)+"\n"+str(entity.owner)
			if not stock_groups.has(key): stock_groups[key] = {}
			var positions: Dictionary = stock_groups[key]
			if not positions.has(entity.position): positions[entity.position] = {}
			var counts: Dictionary = positions[entity.position]
			counts[entity.design_type] = int(counts.get(entity.design_type,0))+int(entity.quantity)
		if entity.kind in ["CARRIER", "HEAVY_OBJECT"]:
			if entity.position.x < -10: continue
			draw_rect(Rect2(point - Vector2(7, 4), Vector2(14, 8)), Color("dba274"))
			if entity.kind == "CARRIER" and entity.design_type == "T01" and entity.owner == simulation.rear.PLAYER:
				_draw_icon(TRUCK_ART,Rect2(point-Vector2(7,4),Vector2(14,8)))
			if entity.get("fleet_domain","") == "Construction":
				draw_rect(Rect2(point-Vector2(9,6),Vector2(18,12)),Color("ffd37c"),false,2)
				_draw_label(font,point+Vector2(10,-7),"Construction truck",11,Color("ffd37c"))
		if entity.kind != "PERSON": continue
		# Passengers/drivers remain visibly on their carrier; don't draw them as loose workers.
		if simulation.rear.ledger.entity_kind(entity.holder_id) == "CARRIER": continue
		if entity.position.x < 0: continue
		draw_circle(point, 4.0, Color("82e3b0") if entity.owner == "army-blue" else Color("dba274"))
		if entity.owner == simulation.rear.PLAYER and entity.get("rear_place","") == "Occupied" and entity.get("assignment","") in ["Available","Rear Labour","Training","Strategic Crew"]:
			_draw_civilian(point)
		_draw_carry_art(entity,point,font)
		if entity.id == selection: draw_arc(point, 8, 0, TAU, 20, Color.WHITE, 2)
	if character_enabled:
		var table := map_point(Vector2(10,90))
		draw_rect(Rect2(table-Vector2(6,4),Vector2(12,8)),Color("ddbd72"))
		draw_texture_rect_region(INDOOR_ART,Rect2(table-Vector2(12,12),Vector2(24,24)),SUPPLY_TABLE_REGION)
		_draw_icon(ARRIVAL_ART,Rect2(table-Vector2(24,26),Vector2(16,16)))
		_draw_label(font,table+Vector2(-12,-32),"Supply Table / arrivals",14)
		var player := map_point(character_position)
		draw_circle(player,7,Color("80caff"))
		_draw_civilian(player)
		_draw_stock_groups(stock_groups,font)
		draw_arc(player,10,0,TAU,24,Color.WHITE,2)
		_draw_label(font,player+Vector2(12,-8),"You",14)
		_draw_label(font,Vector2(12,size.y-32),"WASD move at 1x / 2x | wheel zoom | middle-drag pan",14)
		return
	_draw_stock_groups(stock_groups,font)
	var ledger: RefCounted = simulation.rear.ledger
	if simulation.expanded_catalogue:
		var totals: Array[String] = []
		for activity in [simulation.rear.production, simulation.rear.munitions_production, simulation.rear.materials_production, simulation.rear.support_production]:
			var type: String = activity._spec.output_type
			totals.append("%s %s: %d" % [activity._spec.facility, type, ledger.total_stock(type,simulation.rear.PLAYER)])
		_draw_label(font, Vector2(12, size.y - 50), "Physical outputs | " + " | ".join(totals), 12)
	else:
		_draw_label(font, Vector2(12, size.y - 50), "Own physical goods: %d rifles | %d rounds | %d materials | %d explosives" % [ledger.total_stock("E01",simulation.rear.PLAYER), ledger.total_stock("E02",simulation.rear.PLAYER), ledger.total_stock("M11",simulation.rear.PLAYER), ledger.total_stock("M06",simulation.rear.PLAYER)], 12)
	var training: RefCounted = simulation.rear.training
	for row in training.rows:
		if row.seat >= 0:
			var at: Vector2 = map_point(training.student_position(row.person_id))
			draw_circle(at,5,Color("84a2e5") if row.state == "Active" else Color("f3c477"),false,1.0)
	var heavy: RefCounted = simulation.rear.heavy_production
	var fleet: Dictionary = ledger.rear_fleet_status("army-blue")
	var bay: String = "occupied " + ledger.inspect_entity(heavy.bay_occupant).get("design_type", "") if not heavy.bay_occupant.is_empty() else ("order accepted" if not heavy._order.is_empty() else "empty")
	_draw_label(font,Vector2(12,size.y-68),"F10 bay: %s | fleet %d live + %d reserved / 8" % [bay,fleet.live,fleet.reserved],12)
	_draw_label(font, Vector2(12, size.y - 32), "240 x 180 m | green people / gold freight / orange vehicles", 12)
	_draw_label(font, Vector2(12, size.y - 14), "Click to inspect | wheel zoom | middle-drag pan | Fit base", 12)

func _draw_icon(texture: Texture2D, bounds: Rect2) -> void:
	var dimensions := texture.get_size()
	var factor := minf(1.0,minf(bounds.size.x/dimensions.x,bounds.size.y/dimensions.y))
	var extent := dimensions*factor
	draw_texture_rect(texture,Rect2(bounds.get_center()-extent/2.0,extent),false)

func _draw_ground(pixels_per_metre: float) -> void:
	# One tiled GPU draw in existing world bounds; decorative, never terrain/collision.
	draw_set_transform(map_point(Vector2.ZERO),0.0,Vector2.ONE*pixels_per_metre)
	draw_texture_rect(GRASS_ART,Rect2(Vector2.ZERO,Vector2(240,180)),true)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_civilian(point: Vector2) -> void:
	var bounds := Rect2(point-Vector2(8,8),Vector2(16,16))
	for layer: Texture2D in CIVILIAN_LAYERS:
		draw_texture_rect(layer,bounds,false)

func _stock_label(type: String) -> String:
	if type == "M11": return "Building Materials"
	if type == "M06": return "Explosives"
	if type == "E02": return "Rifle rounds"
	return str(MaterialCatalog.MATERIALS.get(type,{}).get("name",type))

func _draw_carry_art(entity: Dictionary, point: Vector2, font: Font) -> void:
	var type := str(entity.get("carried_type",""))
	var count := int(entity.get("carried_quantity",0))
	if type.is_empty() or count <= 0: return
	draw_texture_rect_region(INDOOR_ART,Rect2(point+Vector2(5,-8),Vector2(10,10)),STOCK_REGION)
	_draw_label(font,point+Vector2(15,-9),"%s ×%d" % [_stock_label(type),count],10,Color("ffd37c"))

func _draw_stock_art(point: Vector2, counts: Dictionary, font: Font) -> void:
	# Offset callout keeps the real anchor visible without covering table/player art.
	draw_line(point,point+Vector2(18,18),Color("ddbd72"),1.0)
	draw_texture_rect_region(INDOOR_ART,Rect2(point+Vector2(18,18),Vector2(16,16)),STOCK_REGION)
	var line := 0
	for type in counts:
		_draw_label(font,point+Vector2(18,50+line*13),"%s: %d physical" % [_stock_label(str(type)),int(counts[type])],11,Color("ffd37c"))
		line += 1

func _draw_facility_art(kind: String, bounds: Rect2, tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = FACILITY_ART.get(kind)
	if texture == null: return
	var dimensions := texture.get_size()
	var inset := bounds.grow(-2)
	var factor := minf(4.0,minf(inset.size.x/dimensions.x,inset.size.y/dimensions.y))
	if factor <= 0: return
	var extent := dimensions*factor
	draw_texture_rect(texture,Rect2(bounds.get_center()-extent/2.0,extent),false,tint)

func _draw_stock_groups(groups: Dictionary, font: Font) -> void:
	for positions: Dictionary in groups.values():
		for world_point: Vector2 in positions:
			_draw_stock_art(map_point(world_point),positions[world_point],font)

func _draw_label(font: Font, at: Vector2, text: String, font_size: int = 12, tint: Color = Color.WHITE) -> void:
	var padding := 4.0
	var available := size-Vector2.ONE*padding*2.0
	if available.x <= 0.0 or available.y <= 0.0: return
	var measured := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	# Do not pull labels for fully offscreen world markers (such as HQ stock) into view.
	var natural := Rect2(at-Vector2(0,ascent),Vector2(measured.x,ascent+descent))
	if not natural.grow(2.0).intersects(Rect2(Vector2.ZERO,size)): return
	var width := minf(measured.x,available.x)
	var baseline := Vector2(
		clampf(at.x,padding,maxf(padding,size.x-padding-width)),
		clampf(at.y,padding+ascent,maxf(padding+ascent,size.y-padding-descent)))
	# Keep the existing text/colour readable, clipping only strings wider than the viewport.
	draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,2,Color("16242b"))
	draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,tint)
