extends RefCounted
## Bounded rear geometry and catalogue capacities, not a production world navigator.

const FACILITIES: Dictionary = {
	"receiving": ["F02", Vector2(45, 25), Vector2(16, 12), 4, Vector2(45, 18)],
	"depot": ["F03", Vector2(80, 20), Vector2(20, 16), 0, Vector2(80, 11)],
	"workshop": ["F04", Vector2(125, 25), Vector2(16, 12), 4, Vector2(125, 18)],
	"munitions": ["F05", Vector2(125, 55), Vector2(16, 12), 4, Vector2(116, 55)],
	"training": ["F06", Vector2(55, 110), Vector2(20, 16), 2, Vector2(44, 110)],
	"dispatch": ["F07", Vector2(210, 100), Vector2(20, 16), 4, Vector2(210, 91)],
	"personnel": ["F08", Vector2(20, 90), Vector2(16, 12), 0, Vector2(11, 90)],
	"support": ["F09", Vector2(90, 110), Vector2(16, 12), 4, Vector2(90, 103)],
	"vehicle_works": ["F10", Vector2(180, 40), Vector2(28, 24), 8, Vector2(165, 40)],
	"park": ["F11", Vector2(180, 140), Vector2(30, 20), 0, Vector2(180, 140)],
	"construction": ["F12", Vector2(30, 140), Vector2(10, 8), 4, Vector2(24, 140)],
	"materials": ["F13", Vector2(125, 95), Vector2(20, 16), 8, Vector2(114, 95)],
	"terminal": ["F01", Vector2(20, 20), Vector2(6, 6), 0, Vector2(16, 20)],
}
const STORES: Dictionary = {
	"receiving": ["receiving", 5000], "depot": ["depot", 10000],
	"workshop_input": ["workshop", 1000], "workshop_output": ["workshop", 1000],
	"munitions_input": ["munitions", 1000], "munitions_output": ["munitions", 1000],
	"support_input": ["support", 1000], "support_output": ["support", 1000],
	"materials_input": ["materials", 2000], "materials_output": ["materials", 3000],
	"vehicle_input": ["vehicle_works", 5000], "dispatch": ["dispatch", 6000],
}


static func door(facility: String) -> Vector2:
	return FACILITIES[facility][4]


static func clear_segment(a: Vector2, b: Vector2) -> bool:
	for id in FACILITIES:
		if id == "park":
			continue # A park is an accessible open parking area.
		var f: Array = FACILITIES[id]
		var box := Rect2(f[1] - f[2] / 2.0, f[2]).grow(0.25)
		if box.has_point(a) or box.has_point(b) or box.has_point(a.lerp(b, 0.5)):
			return false
		var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
				return false
	return true


static func path(a: Vector2, b: Vector2) -> Array:
	if a.is_equal_approx(b):
		return [a, b]
	var nodes: Array = [a, b]
	for id in FACILITIES:
		if id == "park":
			continue
		var f: Array = FACILITIES[id]
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
			if visited[i] or not clear_segment(nodes[selected], nodes[i]):
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


static func length(points: Array) -> float:
	var total: float = 0.0
	for i in range(1, points.size()):
		total += (points[i - 1] as Vector2).distance_to(points[i])
	return total


static func position(points: Array, distance: float) -> Vector2:
	for i in range(1, points.size()):
		var segment: float = (points[i - 1] as Vector2).distance_to(points[i])
		if distance <= segment and segment > 0.0:
			return (points[i - 1] as Vector2).lerp(points[i], distance / segment)
		distance -= segment
	return points.back()
