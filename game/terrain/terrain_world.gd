extends RefCounted
## Small explicit metre-cell world. No generator, renderer or world navigation owner.

const Catalog = preload("res://game/terrain/terrain_catalog.gd")
const EPS := 0.0000001
var bounds := Rect2i(0, 0, 900, 40)
var cells: Dictionary = {}
var base_regions: Array[Dictionary] = []
var scenario: Dictionary = {}
var obstacles: Array[Dictionary] = []
var shields: Array[Dictionary] = []
var field_effects: Array[Dictionary] = []
var bridge_approaches: Dictionary = {} # land cells within twenty metres of a live bridge
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
	if cells.has(at): return cells[at]
	for index in range(base_regions.size()-1,-1,-1):
		if base_regions[index].area.has_point(at): return base_regions[index].tile
	return {"terrain": "TR01"}

func add_base_region(area: Rect2i, terrain: String, properties: Dictionary = {}) -> void:
	assert(bounds.encloses(area) and Catalog.SURFACES.has(terrain))
	var tile := properties.duplicate(true)
	tile.terrain = terrain
	base_regions.append({"area":area,"tile":tile})
	revision += 1

func set_bridge_surface(id: String, deck_cells: Array, approach_cells: Array, code: String, load_kg: float, speed_cap: float, width: float, classes: Array, complete: bool) -> Dictionary:
	if id.is_empty(): return _blocked("Bridge surface needs an actual project identity.")
	for at in deck_cells:
		if not bounds.has_point(at): return _blocked("Bridge deck exceeds the declared world.")
		var existing: Dictionary = cell(at).get("overlay",{})
		if complete and not existing.is_empty() and existing.get("id","") != id: return _blocked("Another completed surface owns the bridge span.")
	for at in deck_cells:
		var tile: Dictionary = cell(at).duplicate(true)
		if complete: tile["overlay"] = {"id":id,"kind":"crossing","code":code,"complete":true,"classes":classes,"load_kg":load_kg,"speed_cap":speed_cap,"width":width}
		elif tile.get("overlay",{}).get("id","") == id: tile.erase("overlay")
		cells[at] = tile
	for at in bridge_approaches.keys():
		var caps: Dictionary = bridge_approaches[at]
		caps.erase(id)
		if caps.is_empty(): bridge_approaches.erase(at)
	if complete:
		for at in approach_cells:
			if bounds.has_point(at):
				var caps: Dictionary = bridge_approaches.get(at,{})
				caps[id] = speed_cap
				bridge_approaches[at] = caps
	revision += 1
	return {"ok":true,"message":"Actual bridge support and approaches updated."}

func set_project_overlay(id: String, area: Rect2i, kind: String, complete: bool, load_kg: float = 0.0, closed: bool = false) -> Dictionary:
	if id.is_empty() or kind not in ["road","causeway"] or not bounds.encloses(area) or not area.has_area():
		return _blocked("Project overlay needs a bounded real segment.")
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var at := Vector2i(x,y)
			var tile: Dictionary = cell(at)
			var existing: Dictionary = tile.get("overlay",{})
			if complete:
				if not existing.is_empty() and existing.get("id","") != id: return _blocked("Another completed crossing or surface owns this cell.")
				var slope: float = rad_to_deg(atan(Vector2(tile.get("gradient",Vector2.ZERO)).length()))
				if kind == "road" and (tile.terrain in ["TR09","TR10","TR11","TR12"] or slope > 10.0+EPS): return _blocked("Road requires dry passable ground at at most ten degrees.")
				if kind == "causeway" and not ((tile.terrain == "TR09" and not tile.get("deep_bog",false)) or (tile.terrain == "TR12" and tile.get("landform","") == "bog_edge")): return _blocked("Causeway needs shallow swamp or bog edge; deep water and cliffs remain barred.")
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var at := Vector2i(x,y)
			var tile: Dictionary = cell(at).duplicate(true)
			if complete: tile["overlay"] = {"id":id,"kind":kind,"complete":true,"classes":[0,1,2],"load_kg":load_kg}
			elif tile.get("overlay",{}).get("id","") == id: tile.erase("overlay")
			if closed: tile["closed_project"] = id
			elif tile.get("closed_project","") == id: tile.erase("closed_project")
			cells[at] = tile
	revision += 1
	return {"ok":true,"message":"Actual project surface updated; routes recheck the terrain revision."}

func set_project_structure(id: String, code: String, area: Rect2, complete: bool, facing: float = 0.0) -> void:
	shields = shields.filter(func(row: Dictionary) -> bool: return row.get("id","") != id)
	obstacles = obstacles.filter(func(row: Dictionary) -> bool: return row.get("id","") != id)
	field_effects = field_effects.filter(func(row: Dictionary) -> bool: return row.get("id","") != id)
	if complete:
		if code in ["S01","S02","S03"]:
			var forward := Vector2.from_angle(facing)
			var face: Rect2
			if absf(forward.x) >= absf(forward.y):
				face = Rect2(Vector2(area.end.x,area.position.y) if forward.x >= 0.0 else area.position-Vector2(0.25,0.0),Vector2(0.25,area.size.y))
			else:
				face = Rect2(Vector2(area.position.x,area.end.y) if forward.y >= 0.0 else area.position-Vector2(0.0,0.25),Vector2(area.size.x,0.25))
			shields.append({"id":id,"kind":code,"area":area,"rect":face,"bottom":0.0,"top":2.0 if code != "S03" else 3.0})
		if code in ["S04","S05"]:
			obstacle(id,area,0.0,1.5 if code == "S04" else 2.0,true,false)
			obstacles[-1]["classes"] = [0,1] if code == "S04" else [1,2]
		if code in ["S02","S04","S05"]: field_effects.append({"id":id,"code":code,"area":area})
	revision += 1


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
	return _support_from_tile(tile,movement_class)


func _support_from_tile(tile: Dictionary, movement_class: int) -> Dictionary:
	# A fresh rule is required: route applies cell-local field effects and caps.
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
		if item.solid and int(entity.movement_class) in item.get("classes",[0,1,2]) and _overlap_interval(entity, start, destination, item.rect).x >= 0: return _blocked("Footprint blocked by %s" % item.id)
	var minimum := start.min(destination) - Vector2(entity.size.length(), entity.size.length()) * 0.5
	var maximum := start.max(destination) + Vector2(entity.size.length(), entity.size.length()) * 0.5
	var intervals: Array[Dictionary] = []
	var occupied_cells: Dictionary = {}
	var cuts: Array[float] = [0.0, 1.0]
	var previous_tile: Dictionary = {}
	var previous_rule: Dictionary = {}
	var previous_shareable := false
	for y in range(maxi(bounds.position.y, int(floor(minimum.y))), mini(bounds.end.y, int(ceil(maximum.y)))):
		for x in range(maxi(bounds.position.x, int(floor(minimum.x))), mini(bounds.end.x, int(ceil(maximum.x)))):
			var at := Vector2i(x, y)
			var interval := _overlap_interval(entity, start, destination, Rect2(Vector2(at), Vector2.ONE))
			if interval.x < 0: continue
			var tile := cell(at)
			if not str(tile.get("closed_project","")).is_empty(): return _blocked("Active project closes this segment to traffic")
			var rule := _support_from_tile(tile, entity.movement_class)
			if not rule.ok: return _blocked("Cell %s: %s" % [at, rule.reason])
			var shareable := true
			for effect in field_effects:
				if not effect.area.has_point(Vector2(at)+Vector2(0.5,0.5)): continue
				shareable = false
				if effect.code == "S02" and entity.movement_class == 0: rule.factor *= 0.8
				if effect.code == "S05" and entity.movement_class == 0: rule.factor *= 0.7
				if effect.code == "S04" and entity.movement_class == 2: rule.factor *= 0.25
			var overlay: Dictionary = tile.get("overlay",{})
			if overlay.get("complete",false) and overlay.get("kind","") == "causeway" and entity.has("gross_mass_kg") and float(entity.gross_mass_kg) > float(overlay.get("load_kg",8000.0))+EPS:
				return _blocked("Causeway gross-load limit excludes this actual body and contents")
			if overlay.get("complete",false) and overlay.get("kind","") == "crossing" and overlay.has("code"):
				if entity.has("gross_mass_kg") and not entity.get("bridge_existing_traffic",false) and float(entity.gross_mass_kg) > float(overlay.load_kg)+EPS: return _blocked("%s gross-load limit excludes this actual body and contents" % overlay.code)
				if entity.size.y > float(overlay.width)+EPS: return _blocked("%s deck is narrower than the actual footprint" % overlay.code)
				rule["speed_cap"] = float(overlay.speed_cap)
			elif bridge_approaches.has(at):
				shareable = false
				var approach_cap := INF
				for cap in bridge_approaches[at].values(): approach_cap = minf(approach_cap,float(cap))
				rule["speed_cap"] = approach_cap
			# Finalize every fresh rule first. Only adjacent occupied cells with
			# the identical raw tile and no cell-local modifier may share it.
			if shareable and previous_shareable and is_same(tile,previous_tile): rule = previous_rule
			previous_tile = tile
			previous_rule = rule
			previous_shareable = shareable
			# Only this synchronous route owns these read-only tile references.
			# Keep insertion order for the existing first height-edge refusal.
			occupied_cells[at] = tile
			intervals.append({"from": interval.x, "to": interval.y, "rule": rule})
			cuts.append(interval.x)
			cuts.append(interval.y)
	# A discontinuous height edge is not a free vertical step. Authored sloping
	# planes and completed support must meet; live bridge approaches are G13.
	for at in occupied_cells:
		for offset in [Vector2i.RIGHT, Vector2i.DOWN]:
			if not occupied_cells.has(at + offset): continue
			var here: Dictionary = occupied_cells[at]
			var there: Dictionary = occupied_cells[at + offset]
			# The identical raw tile has identical pure height at either edge
			# point. Distinct dictionaries still take every original check.
			if is_same(here,there): continue
			var edge := Vector2(at + offset)
			var tangent := Vector2.DOWN if offset == Vector2i.RIGHT else Vector2.RIGHT
			for point in [edge, edge + tangent]:
				if absf(_tile_height(here, point) - _tile_height(there, point)) > 0.00001: return _blocked("Disconnected height support at %s" % at)
	return _route_parts(entity, start, destination, distance, intervals, cuts)


func _route_parts(entity: Dictionary, start: Vector2, destination: Vector2, distance: float, intervals: Array[Dictionary], cuts: Array[float]) -> Dictionary:
	cuts.sort()
	# Sweep starts once; only footprint cells still overlapping the current span
	# participate. Keep original cell order so surface lists remain identical.
	var pending: Array[int] = []
	for index in intervals.size(): pending.append(index)
	pending.sort_custom(func(a: int, b: int) -> bool: return intervals[a].from < intervals[b].from)
	var cursor := 0
	var active: Array[int] = []
	var parts: Array[Dictionary] = []
	var seconds := 0.0
	var fuel := 0.0
	for index in range(cuts.size() - 1):
		var begin: float = cuts[index]
		var end: float = cuts[index + 1]
		if end - begin <= EPS: continue
		var middle := (begin + end) * 0.5
		for index_active in range(active.size()-1,-1,-1):
			if intervals[active[index_active]].to < middle: active.remove_at(index_active)
		while cursor < pending.size() and intervals[pending[cursor]].from <= middle:
			var id: int = pending[cursor]
			if intervals[id].to >= middle: active.insert(active.bsearch(id),id)
			cursor += 1
		var factor := INF
		var burn := 0.0
		var surfaces: Array[String] = []
		var max_slope := 0.0
		var speed_cap := INF
		var previous_rule: Dictionary = {}
		for id in active:
			var rule: Dictionary = intervals[id].rule
			# Repeating the same consecutive min/max operand and surface is
			# idempotent. Never skip across a differing active rule.
			if is_same(rule,previous_rule): continue
			previous_rule = rule
			factor = minf(factor, rule.factor)
			burn = maxf(burn, rule.fuel)
			max_slope = maxf(max_slope, rule.slope)
			speed_cap = minf(speed_cap,float(rule.get("speed_cap",INF)))
			if rule.surface not in surfaces: surfaces.append(rule.surface)
		var length := (end - begin) * distance
		var speed: float = minf(entity.base * factor,speed_cap)
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
	if movement_class != 0: return result
	var place := _cover_place(person)
	if not place.ok:
		result.blast_eligibility = place.reason
		return result
	var tile := cell(Vector2i(floor(person.x), floor(person.y)))
	var overlay: Dictionary = tile.get("overlay", {})
	var natural_exposed: bool = exposed_deck or tile.terrain == "TR02" or (overlay.get("complete", false) and overlay.get("kind", "") in ["road", "causeway", "crossing"] and 0 in overlay.get("classes", []))
	var natural: Dictionary = Catalog.SURFACES[tile.terrain]
	# Rocky terrain needs a declared actual directional shield; proximity is insufficient.
	if not natural_exposed and tile.terrain != "TR07":
		result.hit = natural.hit
		result.source = tile.terrain
		result.valid.append(tile.terrain)
	if not natural_exposed and tile.terrain == "TR06":
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
		if natural_exposed and shield.kind == "rock": continue
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
		if item.solid and 0 in item.get("classes",[0,1,2]) and _overlap_interval(body, person, person, item.rect).x >= 0: return _blocked("Cover position occupied by solid " + item.id)
	for y in range(int(floor(person.y - 0.3)), int(ceil(person.y + 0.3))):
		for x in range(int(floor(person.x - 0.3)), int(ceil(person.x + 0.3))):
			if not support(Vector2i(x, y), 0).ok: return _blocked("Cover position lacks physical foot support")
	return {"ok": true}
