extends Control
## Diagnostic metre diagram only; does not choose the production world presentation.

var world: RefCounted
var entity: Dictionary = {}
var destination := Vector2.ZERO
var observer := Vector2.ZERO
var target := Vector2.ZERO
var sight := false
var visible_target := false
var overview := false
var _scale: float = 1.0
var _origin := Vector2(12, 12)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("142536"))
	if world == null: return
	var extent: Vector2 = Vector2(world.bounds.size)
	if sight: extent = Vector2(maxf(observer.x, target.x) + 15, 40)
	_scale = minf((size.x - 24) / extent.x, (size.y - 32) / extent.y)
	if overview: _scale *= 0.75
	_origin = Vector2(12, 16)
	var palette := {"TR01": Color("415548"), "TR02": Color("9b947a"), "TR03": Color("84764b"), "TR04": Color("a39d45"), "TR05": Color("386748"), "TR06": Color("20432d"), "TR07": Color("7a7d7c"), "TR08": Color("828188"), "TR09": Color("4f7161"), "TR10": Color("51899c"), "TR11": Color("29557d"), "TR12": Color("433d4a"), "TR13": Color("837063")}
	draw_rect(Rect2(_origin, extent * _scale), palette.TR01)
	for at in world.cells:
		var tile: Dictionary = world.cells[at]
		if at.x > extent.x: continue
		var color: Color = palette[tile.terrain]
		if tile.get("height", 0.0) > 0.0 or Vector2(tile.get("gradient", Vector2.ZERO)).length() > 0.0: color = color.lightened(0.25)
		if tile.get("overlay", {}).get("complete", false): color = palette.TR02
		draw_rect(Rect2(_point(Vector2(at)), Vector2.ONE * _scale + Vector2(0.2, 0.2)), color)
	for obstacle in world.obstacles:
		draw_rect(Rect2(_point(obstacle.rect.position), obstacle.rect.size * _scale), Color("b0b2b6") if obstacle.solid else Color("d1b9db"))
	for shield in world.shields:
		draw_rect(Rect2(_point(shield.rect.position), shield.rect.size * _scale), Color("c29d6a"))
	if sight:
		draw_circle(_point(observer), 5, Color("8cceff"))
		if visible_target:
			draw_line(_point(observer), _point(target), Color("f4de81"), 2)
			draw_circle(_point(target), 5, Color("ffac89"))
	else:
		draw_line(_point(entity.position), _point(destination), Color("d7bd7b"), 1)
		draw_circle(_point(destination), 3, Color("d7bd7b"))
		var polygon: PackedVector2Array = world.footprint(entity, entity.position)
		for index in polygon.size(): polygon[index] = _point(polygon[index])
		draw_colored_polygon(polygon, Color("8cceff"))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color.WHITE, 1)
	draw_string(ThemeDB.fallback_font, Vector2(12, size.y - 8), "Metre calibration diagram · blue = declared body/observer · target appears only with sight", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _point(at: Vector2) -> Vector2:
	return _origin + at * _scale
