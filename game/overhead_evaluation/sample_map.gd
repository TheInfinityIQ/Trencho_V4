extends Control
## Plan projection for three declared samples, not a general world renderer.

var model: Control
var _badges: Dictionary = {}
const PALETTE := [Color("72c8bf"), Color("e6b36b"), Color("c9d1e7")]


func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)


func _draw() -> void:
	if not is_instance_valid(model): return
	draw_rect(Rect2(Vector2.ZERO, size), Color("1c2b30"))
	var cam: Dictionary = model.camera()
	var ppm: float = cam.pixels_per_metre
	var origin: Vector2 = model.screen_for(Vector2.ZERO)
	var extent: Vector2 = model.EXTENT * ppm
	draw_rect(Rect2(origin, extent), Color("263b35"))
	var step: int = 10 if model.view_name == "Close" else (100 if model.view_name == "Intermediate" else 1000)
	var lower: Vector2 = cam.centre - size / (2.0 * ppm)
	var upper: Vector2 = cam.centre + size / (2.0 * ppm)
	for x in range(maxi(0, int(floor(lower.x / step)) * step), mini(4001, int(upper.x) + step), step):
		draw_line(model.screen_for(Vector2(x, maxf(0, lower.y))), model.screen_for(Vector2(x, minf(6000, upper.y))), Color("355047"), 1)
	for y in range(maxi(0, int(floor(lower.y / step)) * step), mini(6001, int(upper.y) + step), step):
		draw_line(model.screen_for(Vector2(maxf(0, lower.x), y)), model.screen_for(Vector2(minf(4000, upper.x), y)), Color("355047"), 1)
	# Sparse authored terrain shapes provide context, not generated terrain cells.
	var river := PackedVector2Array()
	for point in [Vector2(1035, 0), Vector2(1045, 1800), Vector2(1045, 2950), Vector2(1035, 3050), Vector2(2500, 4500), Vector2(2300, 6000)]:
		river.append(model.screen_for(point))
	draw_polyline(river, Color("327f9c"), maxf(1.0, 14 * ppm), true)
	var bridge := Rect2(model.screen_for(Vector2(1029, 2996)), Vector2(24, 8) * ppm)
	draw_rect(bridge, Color("89948b"))
	draw_rect(bridge, Color("e2d0a1"), false, 2)
	var ridge_a: Vector2 = model.screen_for(Vector2(995, 2984))
	var ridge_b: Vector2 = model.screen_for(Vector2(1045, 2984))
	draw_line(ridge_a, ridge_b, Color("d9c590"), maxf(1, 2 * ppm))
	if model.view_name == "Close":
		_caption(ridge_a + Vector2(0, -14), "Ridge +12 m · slope ↑ 11.3°")
		_caption(bridge.position + Vector2(0, -10), "Deck +8 m")
		_caption(bridge.position + Vector2(0, bridge.size.y + 24), "Ground +2 m · 6 m below")
	else:
		_caption(model.screen_for(Vector2(1041, 3000)) + Vector2(35, -65), "Bridge: deck +8 / ground +2 m")
		_caption(model.screen_for(Vector2(1020, 2984)) + Vector2(35, -90), "Ridge +12 m / slope cue")
	draw_rect(Rect2(origin, extent), Color("728f7f"), false, 2)
	if model.view_name == "6 km overview":
		_caption(origin + Vector2(0, -12), "(0, 0) m")
		_caption(origin + Vector2(0, extent.y + 25), "4,000 × 6,000 m extent")
	_badges.clear()
	for index in model.SAMPLES.size():
		var item: Dictionary = model.SAMPLES[index]
		var position: Vector2 = model.screen_for(item.position)
		var footprint := Rect2(position - item.size * ppm / 2.0, item.size * ppm)
		draw_rect(footprint, PALETTE[index])
		if item.id == model.selected_id: draw_rect(footprint.grow(4), Color("ffe596"), false, 2)
		var badge: Vector2 = position
		if model.view_name != "Close": badge += Vector2(-165, -15 + 43 * index)
		else: badge += [Vector2(-80, -90), Vector2(0, 50), Vector2(-90, 25)][index]
		var badge_rect := Rect2(badge - Vector2(7, 14), Vector2(185, 28) * model.text_scale)
		_badges[item.id] = badge_rect
		draw_line(position, badge, PALETTE[index], 1)
		draw_circle(badge, 4, PALETTE[index])
		_caption(badge + Vector2(10, 4), item.name, PALETTE[index])
	# Fixed screen scale bar describes metres rather than changing physical data.
	var metres: float = 10 if model.view_name == "Close" else (100 if model.view_name == "Intermediate" else 1000)
	var bar := Vector2(24, size.y - 30)
	draw_line(bar, bar + Vector2(metres * ppm, 0), Color.WHITE, 3)
	_caption(bar + Vector2(0, -12), "%d m" % metres)


func _caption(at: Vector2, text: String, color: Color = Color("dce8df")) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13 * model.text_scale), color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ppm: float = model.camera().pixels_per_metre
		for item in model.SAMPLES:
			var footprint := Rect2(model.screen_for(item.position) - item.size * ppm / 2.0, item.size * ppm)
			if footprint.has_point(event.position) or _badges.get(item.id, Rect2()).has_point(event.position):
				model.select_sample(item.id)
				accept_event()
				return
