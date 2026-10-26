extends RefCounted
## Small explicit metre-cell world. No generator, renderer or world navigation owner.

const Catalog = preload("res://game/terrain/terrain_catalog.gd")
const EPS := 0.0000001
var bounds := Rect2i(0, 0, 900, 40)
var cells: Dictionary = {}
var obstacles: Array[Dictionary] = []
var shields: Array[Dictionary] = []
var revision: int = 0


func paint(area: Rect2i, terrain: String, properties: Dictionary = {}) -> void:
	assert(Catalog.SURFACES.has(terrain) and bounds.encloses(area))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var value := properties.duplicate(true)
			value.terrain = terrain
			cells[Vector2i(x, y)] = value
	revision += 1


func cell(at: Vector2i) -> Dictionary:
	return cells.get(at, {"terrain": "TR01"})


func ground(point: Vector2) -> float:
	var tile := cell(Vector2i(floor(point.x), floor(point.y)))
	return _tile_height(tile, point)


func _tile_height(tile: Dictionary, point: Vector2) -> float:
	var overlay: Dictionary = tile.get("overlay", {})
	if overlay.get("complete", false) and overlay.has("height"): return float(overlay.height)
	return float(tile.get("height", 0.0)) + Vector2(tile.get("gradient", Vector2.ZERO)).dot(point)


func obstacle(id: String, rectangle: Rect2, bottom: float, top: float, solid: bool = true, opaque: bool = true) -> void:
	assert(rectangle.has_area() and top > bottom)
	obstacles.append({"id": id, "rect": rectangle, "bottom": bottom, "top": top, "solid": solid, "opaque": opaque})
	revision += 1


func support(at: Vector2i, movement_class: int) -> Dictionary:
	if not bounds.has_point(at): return _blocked("Outside declared world")
	var tile := cell(at)
	var surface: String = tile.terrain
	var overlay: Dictionary = tile.get("overlay", {})
	var gradient: Vector2 = tile.get("gradient", Vector2.ZERO)
	var slope := rad_to_deg(atan(gradient.length()))
	var slope_multiplier := Catalog.slope_factor(slope, movement_class)
	if slope_multiplier == 0: return _blocked("Forbidden slope %.6f degrees" % slope)
	if overlay.get("complete", false) and movement_class in overlay.get("classes", []):
		var kind: String = overlay.get("kind", "")
		var legal_base: bool = kind == "crossing" or (kind == "road" and surface not in ["TR09", "TR10", "TR11", "TR12"] and slope <= 10.0 + 0.00001) or (kind == "causeway" and ((surface == "TR09" and not tile.get("deep_bog", false)) or (surface == "TR12" and tile.get("landform", "cliff") == "bog_edge")))
		if legal_base: surface = "TR02"
	if surface == "TR10":
		if not tile.get("marked", false) or not tile.get("firm", false) or not tile.get("banks", false): return _blocked("Ford needs marked firm bottom and accessible banks")
		if movement_class not in tile.get("classes", []): return _blocked("Ford excludes movement class")
		if float(tile.get("depth", INF)) > [0.6, 0.35, 0.8][movement_class]: return _blocked("Ford depth exceeds class limit")
	if surface == "TR09" and tile.get("deep_bog", false): return _blocked("Deep bog has no support")
	var factor: float = Catalog.SURFACES[surface].speed[movement_class]
	if factor == 0.0: return _blocked("%s forbids movement class" % surface)
	return {"ok": true, "reason": "Supported", "surface": surface, "slope": slope, "factor": factor * slope_multiplier, "terrain_factor": factor, "slope_factor": slope_multiplier, "fuel": Catalog.SURFACES[surface].fuel}


func footprint(entity: Dictionary, at: Vector2) -> PackedVector2Array:
	var along := Vector2.from_angle(entity.facing)
	var across := along.orthogonal()
	var half: Vector2 = entity.size * 0.5
	return PackedVector2Array([at - along * half.x - across * half.y, at + along * half.x - across * half.y, at + along * half.x + across * half.y, at - along * half.x + across * half.y])


func _blocked(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _overlap_interval(entity: Dictionary, start: Vector2, finish: Vector2, rectangle: Rect2) -> Vector2:
	# Continuous SAT for a translating oriented rectangle and an axis-aligned box.
	# Interior overlap only; boundary contact is not occupied area.
	var along := Vector2.from_angle(entity.facing)
	var across := along.orthogonal()
	var half: Vector2 = entity.size * 0.5
	var low := 0.0
	var high := 1.0
	for axis in [Vector2.RIGHT, Vector2.DOWN, along, across]:
		var radius: float = absf(axis.dot(along)) * half.x + absf(axis.dot(across)) * half.y + absf(axis.x) * rectangle.size.x * 0.5 + absf(axis.y) * rectangle.size.y * 0.5
		var origin: float = axis.dot(start - rectangle.get_center())
		var velocity: float = axis.dot(finish - start)
		if absf(velocity) < EPS:
			if absf(origin) >= radius - EPS: return Vector2(-1, -1)
		else:
			var first: float = (-radius - origin) / velocity
			var last: float = (radius - origin) / velocity
			low = maxf(low, minf(first, last))
			high = minf(high, maxf(first, last))
			if high - low <= EPS: return Vector2(-1, -1)
	return Vector2(low, high)


func route(entity: Dictionary, destination: Vector2) -> Dictionary:
	var start: Vector2 = entity.position
	var distance := start.distance_to(destination)
	if distance <= EPS: return _blocked("Choose a distinct lane endpoint")
	var direction := (destination - start) / distance
	if absf(direction.cross(Vector2.from_angle(entity.facing))) > EPS: return _blocked("Declared straight lane requires current hull alignment; no turn planner")
	for point in footprint(entity, start) + footprint(entity, destination):
		if point.x < bounds.position.x - EPS or point.y < bounds.position.y - EPS or point.x > bounds.end.x + EPS or point.y > bounds.end.y + EPS: return _blocked("Whole footprint exceeds declared world")
	for item in obstacles:
		if item.solid and _overlap_interval(entity, start, destination, item.rect).x >= 0: return _blocked("Footprint blocked by %s" % item.id)
	var minimum := start.min(destination) - Vector2(entity.size.length(), entity.size.length()) * 0.5
	var maximum := start.max(destination) + Vector2(entity.size.length(), entity.size.length()) * 0.5
	var intervals: Array[Dictionary] = []
	var occupied_cells: Dictionary = {}
	var cuts: Array[float] = [0.0, 1.0]
	for y in range(maxi(bounds.position.y, int(floor(minimum.y))), mini(bounds.end.y, int(ceil(maximum.y)))):
		for x in range(maxi(bounds.position.x, int(floor(minimum.x))), mini(bounds.end.x, int(ceil(maximum.x)))):
			var at := Vector2i(x, y)
			var interval := _overlap_interval(entity, start, destination, Rect2(Vector2(at), Vector2.ONE))
			if interval.x < 0: continue
			var rule := support(at, entity.movement_class)
			if not rule.ok: return _blocked("Cell %s: %s" % [at, rule.reason])
			occupied_cells[at] = true
			intervals.append({"from": interval.x, "to": interval.y, "rule": rule})
			cuts.append(interval.x)
			cuts.append(interval.y)
	# A discontinuous height edge is not a free vertical step. Authored sloping
	# planes and completed support must meet; live bridge approaches are G13.
	for at in occupied_cells:
		for offset in [Vector2i.RIGHT, Vector2i.DOWN]:
			if not occupied_cells.has(at + offset): continue
			var edge := Vector2(at + offset)
			var tangent := Vector2.DOWN if offset == Vector2i.RIGHT else Vector2.RIGHT
			for point in [edge, edge + tangent]:
				if absf(_tile_height(cell(at), point) - _tile_height(cell(at + offset), point)) > 0.00001: return _blocked("Disconnected height support at %s" % at)
	cuts.sort()
	var parts: Array[Dictionary] = []
	var seconds := 0.0
	var fuel := 0.0
	for index in range(cuts.size() - 1):
		var begin: float = cuts[index]
		var end: float = cuts[index + 1]
		if end - begin <= EPS: continue
		var middle := (begin + end) * 0.5
		var factor := INF
		var burn := 0.0
		var surfaces: Array[String] = []
		var max_slope := 0.0
		for interval in intervals:
			if middle < interval.from or middle > interval.to: continue
			factor = minf(factor, interval.rule.factor)
			burn = maxf(burn, interval.rule.fuel)
			max_slope = maxf(max_slope, interval.rule.slope)
			if interval.rule.surface not in surfaces: surfaces.append(interval.rule.surface)
		var length := (end - begin) * distance
		var speed: float = entity.base * factor
		var used: float = length * entity.rate * burn / 1000.0
		parts.append({"from": start.lerp(destination, begin), "to": start.lerp(destination, end), "distance": length, "speed": speed, "seconds": length / speed, "fuel": used, "surfaces": surfaces, "slope": max_slope})
		seconds += length / speed
		fuel += used
	return {"ok": true, "reason": "Whole straight lane supported", "parts": parts, "seconds": seconds, "distance": distance, "fuel": fuel, "revision": revision}


func ray_cells(start: Vector2, finish: Vector2) -> Array[Dictionary]:
	var cuts: Array[float] = [0.0, 1.0]
	var delta := finish - start
	for axis in [0, 1]:
		if absf(delta[axis]) < EPS: continue
		for coordinate in range(int(floor(minf(start[axis], finish[axis]))) + 1, int(ceil(maxf(start[axis], finish[axis])))):
			var fraction: float = (coordinate - start[axis]) / delta[axis]
			if fraction > 0 and fraction < 1: cuts.append(fraction)
	cuts.sort()
	var result: Array[Dictionary] = []
	for index in range(cuts.size() - 1):
		var first := cuts[index]
		var last := cuts[index + 1]
		if last - first <= EPS: continue
		var point := start.lerp(finish, (first + last) * 0.5)
		result.append({"cell": Vector2i(floor(point.x), floor(point.y)), "from": first, "to": last})
	return result


func _volume_interval(start: Vector3, finish: Vector3, item: Dictionary) -> Vector2:
	var low := 0.0
	var high := 1.0
	var rectangle: Rect2 = item.rect
	var minimum := Vector3(rectangle.position.x, rectangle.position.y, item.bottom)
	var maximum := Vector3(rectangle.end.x, rectangle.end.y, item.top)
	for axis in 3:
		var delta: float = finish[axis] - start[axis]
		if absf(delta) < EPS:
			if start[axis] <= minimum[axis] or start[axis] >= maximum[axis]: return Vector2(-1, -1)
		else:
			var first: float = (minimum[axis] - start[axis]) / delta
			var last: float = (maximum[axis] - start[axis]) / delta
			low = maxf(low, minf(first, last))
			high = minf(high, maxf(first, last))
			if high - low <= EPS: return Vector2(-1, -1)
	return Vector2(low, high)


func probe(start: Vector2, finish: Vector2, start_height: float, target_height: float, maximum: float, drone: bool = false) -> Dictionary:
	var distance := start.distance_to(finish)
	var a := Vector3(start.x, start.y, ground(start) + start_height)
	var b := Vector3(finish.x, finish.y, ground(finish) + target_height)
	var result := {"clear": false, "reason": "Out of range", "distance": distance, "range": maximum, "from": a, "to": b, "budget": 0.0, "limit": 100.0, "segments": [], "blocker": ""}
	if distance > maximum + EPS: return result
	if not Rect2(bounds).has_point(start) or not Rect2(bounds).has_point(finish):
		result.reason = "Outside declared world"
		return result
	var stop := INF
	var reason := ""
	var blocker := ""
	for item in obstacles:
		if not item.opaque: continue
		var interval := _volume_interval(a, b, item)
		if interval.x >= 0 and interval.x < stop:
			stop = interval.x
			reason = "Opaque volume"
			blocker = item.id
	var budget := 0.0
	for segment in ray_cells(start, finish):
		var tile := cell(segment.cell)
		var first: float = segment.from
		var last: float = segment.to
		var from := a.lerp(b, first)
		var to := a.lerp(b, last)
		var gradient: Vector2 = tile.get("gradient", Vector2.ZERO)
		var base: float = tile.get("height", 0.0)
		var overlay: Dictionary = tile.get("overlay", {})
		if overlay.get("complete", false) and overlay.has("height"):
			base = overlay.height
			gradient = Vector2.ZERO
		var low: float = from.z - (base + gradient.dot(Vector2(from.x, from.y)))
		var high: float = to.z - (base + gradient.dot(Vector2(to.x, to.y)))
		if minf(low, high) <= 0.0:
			var hit: float = first if low <= 0.0 else lerpf(first, last, low / (low - high))
			if hit < stop:
				stop = hit
				reason = "Terrain height"
				blocker = str(segment.cell)
		var top: float = tile.get("vegetation_height", 0.0)
		var vegetation_from := first
		var vegetation_to := last
		if minf(low, high) >= top: continue
		if low > top: vegetation_from = lerpf(first, last, (low - top) / (low - high))
		if high > top: vegetation_to = lerpf(first, last, (top - low) / (high - low))
		if drone and tile.terrain == "TR06" and tile.get("canopy", false):
			if vegetation_from < stop:
				stop = vegetation_from
				reason = "Dense canopy"
				blocker = str(segment.cell)
		var cost: float = Catalog.SURFACES[tile.terrain].sight
		if drone and tile.terrain in ["TR03", "TR04"]: cost = 0.0
		var metres: float = maxf(0, minf(vegetation_to, stop) - vegetation_from) * distance
		if metres <= EPS or cost == 0: continue
		var spent := metres * cost
		result.segments.append({"cell": segment.cell, "terrain": tile.terrain, "metres": metres, "cost": cost, "spent": spent})
		if budget + spent >= 100.0 - EPS:
			stop = vegetation_from + (100.0 - budget) / cost / maxf(distance, EPS)
			reason = "Vegetation budget"
			blocker = str(segment.cell)
			budget = 100.0
			break
		budget += spent
	result.budget = budget
	result.clear = is_inf(stop)
	result.reason = "Clear" if result.clear else reason
	result.blocker = blocker
	result.block_distance = stop * distance if not result.clear else -1.0
	result.block_point = a.lerp(b, stop) if not result.clear else Vector3.ZERO
	if reason in ["Terrain height", "Dense canopy", "Vegetation budget"]:
		var point: Vector3 = result.block_point
		var location := Vector2(point.x, point.y)
		result.block_cell = cell(Vector2i(floor(location.x), floor(location.y))).duplicate(true)
	return result


func observe(observer: Vector2, target: Vector2, role: String = "ordinary", muzzle: float = 1.5, weapon_range: float = 160.0) -> Dictionary:
	assert(Catalog.ROLES.has(role))
	var profile: Dictionary = Catalog.ROLES[role]
	var eye := probe(observer, target, profile.eye, 1.7, profile.range, role == "drone")
	var firing := probe(observer, target, muzzle, 1.7, weapon_range)
	return {"visible": eye.clear, "eye": eye, "muzzle": firing, "role": role, "weapon_range": weapon_range, "firing_line_clear": firing.clear}


func cover(person: Vector2, attacker: Vector2, movement_class: int = 0, exposed_deck: bool = false, impact: Variant = null) -> Dictionary:
	var result := {"hit": 1.0, "blast": 1.0, "source": "Exposed", "blast_source": "Exposed", "valid": [], "blast_valid": [], "blast_eligibility": "No natural blast benefit", "blast_status": "Defined", "impact": impact}
	if movement_class != 0 or exposed_deck: return result
	var place := _cover_place(person)
	if not place.ok:
		result.blast_eligibility = place.reason
		return result
	var tile := cell(Vector2i(floor(person.x), floor(person.y)))
	var overlay: Dictionary = tile.get("overlay", {})
	if overlay.get("complete", false) and overlay.get("kind", "") in ["road", "causeway", "crossing"] and 0 in overlay.get("classes", []): return result
	var natural: Dictionary = Catalog.SURFACES[tile.terrain]
	# Rocky terrain needs a declared actual directional shield; proximity is insufficient.
	if tile.terrain != "TR07" and tile.terrain != "TR02":
		result.hit = natural.hit
		result.source = tile.terrain
		result.valid.append(tile.terrain)
	if tile.terrain == "TR06":
		result.blast = 0.5
		result.blast_source = "TR06"
		result.blast_valid.append("TR06")
		result.blast_eligibility = "Occupied valid dense-forest cover"
	var target := Vector3(person.x, person.y, ground(person) + 1.7)
	var impact_valid: bool = impact is Vector3 and impact.is_finite() and impact.distance_to(target) > EPS
	if tile.terrain == "TR07": result.blast_eligibility = "No shielding rock for impact" if impact_valid else "Missing usable impact origin"
	for shield in shields:
		if not _shield_usable(shield):
			if result.blast == 1.0: result.blast_eligibility = "Invalid shield geometry"
			continue
		if not shield.area.has_point(person): continue
		var benefit: Dictionary = {"hit": 0.5, "blast": 0.5} if shield.kind == "rock" else Catalog.STRUCTURES[shield.kind]
		if attacker.is_finite() and attacker.distance_to(person) > EPS:
			var line_from := Vector3(attacker.x, attacker.y, ground(attacker) + 1.5)
			if _volume_interval(line_from, target, shield).x >= 0:
				result.valid.append(shield.id)
				if benefit.hit < result.hit:
					result.hit = benefit.hit
					result.source = shield.id
		if impact_valid and _volume_interval(impact, target, shield).x >= 0:
			result.blast_valid.append(shield.id)
			if benefit.blast < result.blast:
				result.blast = benefit.blast
				result.blast_source = shield.id
				result.blast_eligibility = "Actual shielding from impact origin"
	return result


func _shield_usable(shield: Dictionary) -> bool:
	if not shield.get("area") is Rect2 or not shield.get("rect") is Rect2: return false
	if not shield.area.has_area() or not shield.rect.has_area(): return false
	if not (shield.get("bottom") is float or shield.get("bottom") is int) or not (shield.get("top") is float or shield.get("top") is int): return false
	return is_finite(shield.bottom) and is_finite(shield.top) and shield.top > shield.bottom and (shield.get("kind") == "rock" or Catalog.STRUCTURES.has(shield.get("kind"))) and not str(shield.get("id", "")).is_empty()


func _cover_place(person: Vector2) -> Dictionary:
	# The declared person probe has the same 0.6m footprint as the lane fixture.
	if not person.is_finite(): return _blocked("Invalid occupied cover position")
	var body := {"facing": 0.0, "size": Vector2(0.6, 0.6)}
	for point in footprint(body, person):
		if point.x < bounds.position.x or point.y < bounds.position.y or point.x > bounds.end.x or point.y > bounds.end.y: return _blocked("Cover position outside declared world")
	for item in obstacles:
		if item.solid and _overlap_interval(body, person, person, item.rect).x >= 0: return _blocked("Cover position occupied by solid " + item.id)
	for y in range(int(floor(person.y - 0.3)), int(ceil(person.y + 0.3))):
		for x in range(int(floor(person.x - 0.3)), int(ceil(person.x + 0.3))):
			if not support(Vector2i(x, y), 0).ok: return _blocked("Cover position lacks physical foot support")
	return {"ok": true}
