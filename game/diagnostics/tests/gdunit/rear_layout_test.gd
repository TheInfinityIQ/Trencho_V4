extends GdUnitTestSuite
## Independent original shortest-path oracle for the fixed prebuilt rear.
const Layout = preload("res://game/staffing/rear_layout.gd")

func test_fixed_rear_routes_preserve_original_order_length_and_clearance() -> void:
	var points: Array[Vector2] = []
	for id in Layout.FACILITIES: points.append(Layout.door(id))
	for first in points:
		for second in points:
			var expected: Array = _legacy_path(first,second)
			var actual: Array = Layout.path(first,second)
			assert_array(actual).override_failure_message("Original route: %s -> %s" % [first,second]).is_equal(expected)
			for index in range(1,actual.size()):
				assert_bool(Layout.clear_segment(actual[index-1],actual[index])).is_true()
	for id in Layout.FACILITIES:
		var inside: Vector2 = Layout.FACILITIES[id][1]
		assert_array(Layout.path(inside,points[0])).is_equal(_legacy_path(inside,points[0]))
	# Public route arrays are detached, including a warm memo hit. Eviction is
	# bounded and cannot change the original route or its equal-cost tie order.
	var first: Vector2 = points[0]
	var last: Vector2 = points[-1]
	var original: Array = _legacy_path(first,last)
	var detached: Array = Layout.path(first,last)
	detached.clear()
	assert_array(Layout.path(first,last)).is_equal(original)
	for index in Layout.ROUTE_MEMO_LIMIT+1:
		Layout.path(Vector2(5.0+index*0.001,5),Vector2(8,8))
	assert_int(Layout._route_memo.size()).is_less_equal(Layout.ROUTE_MEMO_LIMIT)
	assert_array(Layout.path(first,last)).is_equal(original)

func _legacy_path(a: Vector2, b: Vector2) -> Array:
	if a.is_equal_approx(b):
		return [a, b]
	var nodes: Array = [a, b]
	for id in Layout.FACILITIES:
		if id == "park":
			continue
		var f: Array = Layout.FACILITIES[id]
		var box := Rect2(f[1] - f[2] / 2.0, f[2]).grow(0.6)
		nodes.append_array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
	var distances: Array = []
	var previous: Array = []
	var visited: Array = []
	for i in nodes.size():
		distances.append(INF)
		previous.append(-1)
		visited.append(false)
	distances[0] = 0.0
	for _step in nodes.size():
		var selected: int = -1
		for i in nodes.size():
			if not visited[i] and (selected == -1 or distances[i] < distances[selected]):
				selected = i
		if selected == 1 or selected == -1 or distances[selected] == INF:
			break
		visited[selected] = true
		for i in nodes.size():
			if visited[i] or not Layout.clear_segment(nodes[selected], nodes[i]):
				continue
			var candidate: float = distances[selected] + (nodes[selected] as Vector2).distance_to(nodes[i])
			if candidate < distances[i]:
				distances[i] = candidate
				previous[i] = selected
	if distances[1] == INF:
		return []
	var result: Array = [b]
	var cursor: int = 1
	while cursor != 0:
		cursor = previous[cursor]
		result.push_front(nodes[cursor])
	return result
