extends RefCounted
## Ground translation for a measured, fixed-orientation two-person load.
## Turns and rack engagement are separately authored/validated activities.
const CELL := 0.5
const EPS := 0.00001
var _grid: AStarGrid2D
var _allowed := Rect2()
var _boxes: Array[Rect2] = []

func find(origin: Vector2, goal: Vector2, footprints: Array[Rect2], obstacles: Array[Rect2], floor_bounds: Rect2) -> Array:
	if not origin.is_finite() or not goal.is_finite() or footprints.is_empty() or not floor_bounds.has_area(): return []
	var envelope: Rect2 = footprints[0]
	var forbidden: Array[Rect2] = []
	for part: Rect2 in footprints:
		if not part.has_area(): return []
		envelope = envelope.merge(part)
		for obstacle: Rect2 in obstacles:
			# Reference payload positions whose translated component would hit
			# this obstacle. Preserve asymmetric worker/load offsets.
			forbidden.append(Rect2(obstacle.position-part.end,obstacle.size+part.size).grow(EPS))
	var allowed := Rect2(floor_bounds.position-envelope.position,floor_bounds.size-envelope.size)
	if not allowed.has_area(): return []
	_update_geometry(forbidden,allowed)
	var direct := _connector(origin,goal)
	if not direct.is_empty(): return direct
	var first := _anchor(origin)
	var last := _anchor(goal)
	if first.is_empty() or last.is_empty(): return []
	var points := _grid.get_point_path(first.id,last.id,false)
	if points.is_empty(): return []
	var route: Array = first.path.duplicate()
	for point: Vector2 in points:
		if not point.is_equal_approx(route.back()): route.append(point)
	var tail: Array = last.path.duplicate()
	tail.reverse()
	for point: Vector2 in tail:
		if not point.is_equal_approx(route.back()): route.append(point)
	for index in range(1,route.size()):
		if not _clear(route[index-1],route[index]): return []
	var simple: Array = [route[0]]
	for index in range(1,route.size()-1):
		var before: Vector2 = Vector2(route[index])-Vector2(simple.back())
		var after: Vector2 = Vector2(route[index+1])-Vector2(route[index])
		if absf(before.cross(after)) > EPS or before.dot(after) < 0.0: simple.append(route[index])
	if not Vector2(route.back()).is_equal_approx(simple.back()): simple.append(route.back())
	return simple

func _update_geometry(boxes: Array[Rect2], allowed: Rect2) -> void:
	if _grid != null and _allowed == allowed and _boxes == boxes: return
	if _grid == null or _allowed != allowed:
		_grid = AStarGrid2D.new()
		var first := Vector2i((allowed.position/CELL).ceil())
		var last := Vector2i((allowed.end/CELL).floor())
		_grid.region = Rect2i(first,last-first+Vector2i.ONE)
		_grid.cell_size = Vector2.ONE*CELL
		_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		_grid.jumping_enabled = true # No weight scaling is used.
		_grid.update()
	_grid.fill_solid_region(_grid.region,false)
	for box: Rect2 in boxes:
		var first := Vector2i((box.position/CELL).ceil())
		var last := Vector2i((box.end/CELL).floor())
		var region := Rect2i(first,last-first+Vector2i.ONE).intersection(_grid.region)
		if region.has_area(): _grid.fill_solid_region(region,true)
	_allowed = allowed
	_boxes.assign(boxes)

func _anchor(point: Vector2) -> Dictionary:
	var nearest := Vector2i((point/CELL).round())
	var candidates: Array[Vector2i] = []
	for x in range(-1,2):
		for y in range(-1,2):
			var id := nearest+Vector2i(x,y)
			if _grid.is_in_boundsv(id) and not _grid.is_point_solid(id): candidates.append(id)
	candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		return point.distance_squared_to(Vector2(a)*CELL)<point.distance_squared_to(Vector2(b)*CELL))
	for id: Vector2i in candidates:
		var path := _connector(point,_grid.get_point_position(id))
		if not path.is_empty(): return {"id":id,"path":path}
	return {}

func _connector(start: Vector2, finish: Vector2) -> Array:
	if _clear(start,finish): return [start,finish]
	for elbow: Vector2 in [Vector2(finish.x,start.y),Vector2(start.x,finish.y)]:
		if _clear(start,elbow) and _clear(elbow,finish): return [start,elbow,finish]
	return []

func _clear(start: Vector2, finish: Vector2) -> bool:
	if not _allowed.grow(EPS).has_point(start) or not _allowed.grow(EPS).has_point(finish): return false
	var delta := finish-start
	if absf(delta.x) > EPS and absf(delta.y) > EPS: return false
	for box: Rect2 in _boxes:
		if box.has_point(start) or box.has_point(finish): return false
		var corners: Array[Vector2] = [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
		for edge in 4:
			if Geometry2D.segment_intersects_segment(start,finish,corners[edge],corners[(edge+1)%4]) != null: return false
	return true
