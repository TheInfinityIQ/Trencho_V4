extends RefCounted
## Native planar search, followed by the existing exact physical clearance guard.
## Scene-owned and synchronous; stock changes never rebuild navigation geometry.
const CELL := 0.5
const QUERY_CACHE_LIMIT := 256
var _grid: AStarGrid2D
var _bounds := Rect2()
var _boxes: Array[Rect2] = []
var searches := 0
var geometry_updates := 0
var rejected_segments := 0
var cache_hits := 0
var _routes: Dictionary = {}

func find(start: Vector2, goal: Vector2, boxes: Array[Rect2], bounds: Rect2, clear: Callable) -> Array:
	_update_geometry(boxes,bounds)
	var key := Vector4(start.x,start.y,goal.x,goal.y)
	if _routes.has(key):
		cache_hits += 1
		return _routes[key].duplicate() # The caller never owns the cached array.
	var first := _anchor(start,clear)
	var last := _anchor(goal,clear)
	if not _grid.is_in_boundsv(first) or not _grid.is_in_boundsv(last): return []
	searches += 1
	var points: PackedVector2Array = _grid.get_point_path(first,last,false)
	if points.is_empty(): return []
	var path: Array = [start]
	for point: Vector2 in points:
		if not point.is_equal_approx(path.back()): path.append(point)
	if not goal.is_equal_approx(path.back()): path.append(goal)
	for index in range(1,path.size()):
		if not bool(clear.call(path[index-1],path[index])):
			rejected_segments += 1
			return [] # Never accept a raster corner that clips actual geometry.
	var smooth: Array = [start]
	for index in range(2,path.size()):
		if not bool(clear.call(smooth.back(),path[index])): smooth.append(path[index-1])
	if not goal.is_equal_approx(smooth.back()): smooth.append(goal)
	if _routes.size() >= QUERY_CACHE_LIMIT: _routes.clear()
	_routes[key] = smooth.duplicate()
	return smooth

func _update_geometry(boxes: Array[Rect2], bounds: Rect2) -> void:
	if _grid != null and _bounds == bounds and _boxes == boxes: return
	_routes.clear()
	if _grid == null or _bounds != bounds:
		_grid = AStarGrid2D.new()
		var first := Vector2i((bounds.position/CELL).ceil())
		var last := Vector2i((bounds.end/CELL).floor())
		_grid.region = Rect2i(first,last-first+Vector2i.ONE)
		_grid.cell_size = Vector2.ONE*CELL
		_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		# This grid deliberately has no weight scaling; native jump search is
		# valid here and avoids exploring every open-floor intermediate cell.
		_grid.jumping_enabled = true
		_grid.update()
	_grid.fill_solid_region(_grid.region,false)
	for box: Rect2 in boxes:
		var first := Vector2i((box.position/CELL).ceil())
		var last := Vector2i((box.end/CELL).floor())
		var region := Rect2i(first,last-first+Vector2i.ONE).intersection(_grid.region)
		if region.has_area(): _grid.fill_solid_region(region,true)
	_boxes.assign(boxes)
	_bounds = bounds
	geometry_updates += 1

func _anchor(point: Vector2, clear: Callable) -> Vector2i:
	var nearest := Vector2i((point/CELL).round())
	var candidates: Array[Vector2i] = []
	for x in range(-1,2):
		for y in range(-1,2):
			var id := nearest+Vector2i(x,y)
			if _grid.is_in_boundsv(id) and not _grid.is_point_solid(id): candidates.append(id)
	candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		return point.distance_squared_to(Vector2(a)*CELL)<point.distance_squared_to(Vector2(b)*CELL))
	for id: Vector2i in candidates:
		if bool(clear.call(point,_grid.get_point_position(id))): return id
	return Vector2i(-1,-1)
