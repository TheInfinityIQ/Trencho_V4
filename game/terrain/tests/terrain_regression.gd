extends SceneTree

const Catalog = preload("res://game/terrain/terrain_catalog.gd")
const World = preload("res://game/terrain/terrain_world.gd")
const Lane = preload("res://game/terrain/lane_simulation.gd")
const Fixtures = preload("res://game/terrain/terrain_fixtures.gd")
var checks: int = 0
var failures: int = 0
var cases: int = 0

class LegacySightWorld extends World:
	# Complete pre-change lookup/traversal/height/probe/observe oracle from a7b5792.
	func cell(at: Vector2i) -> Dictionary:
		if cells.has(at): return cells[at]
		for index in range(base_regions.size()-1,-1,-1):
			if base_regions[index].area.has_point(at): return base_regions[index].tile
		return {"terrain": "TR01"}

	func ground(point: Vector2) -> float:
		var tile := cell(Vector2i(floor(point.x), floor(point.y)))
		return _tile_height(tile, point)

	func _tile_height(tile: Dictionary, point: Vector2) -> float:
		var overlay: Dictionary = tile.get("overlay", {})
		if overlay.get("complete", false) and overlay.has("height"): return float(overlay.height)
		return float(tile.get("height", 0.0)) + Vector2(tile.get("gradient", Vector2.ZERO)).dot(point)

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



class CountedProbeWorld extends World:
	var preparations := 0
	var probe_calls := 0
	var lookup_cells: Array[Vector2i] = []
	var candidates: Array[Dictionary] = []
	func probe(start: Vector2, finish: Vector2, start_height: float, target_height: float, maximum: float, drone: bool = false) -> Dictionary:
		probe_calls += 1
		return super.probe(start,finish,start_height,target_height,maximum,drone)
	func _probe_regions(segments: Array[Dictionary]) -> Array[Dictionary]:
		preparations += 1
		candidates = super._probe_regions(segments)
		return candidates
	func _route_tile(at: Vector2i, regions: Array[Dictionary]) -> Dictionary:
		lookup_cells.append(at)
		return super._route_tile(at,regions)

func _initialize() -> void:
	_run("all13 surfaces produce actual class movement/time/fuel", _surfaces)
	_run("slope boundary and just-above class effects", _slopes)
	_run("independent surface and slope compose once", _composition)
	_run("ford depth/class/bottom/bank permissions", _fords)
	_run("whole footprint and continuous swept obstacle clearance", _clearance)
	_run("allfive vehicle dimensions and cross-country/road values", _vehicles)
	_run("completed compatible overlay only in supported footprint", _overlays)
	_run("movement cancellation, retry and time partitioning", _interruption)
	_run("fuel reserve and actual exhaustion", _fuel)
	_run("terrain edits stop actual body without free traversal", _edit)
	_run("ordinary and configured role ranges stay metres", _ranges)
	_run("mixed vegetation budget100 and just below", _vegetation)
	_run("height, trunks and buildings independently block rays", _height)
	_run("drone crops/canopy/smoke and independent muzzle", _drone)
	_run("strongest valid directional cover and vehicle exclusion", _cover)
	_run("declared natural blast classes and independent impact eligibility", _natural_blast)
	_run("completed exposed support preserves independently valid structures", _overlay_structure_cover)
	_run("detached inspection preserves authoritative movement", _detached)
	_run("rotated hull sweep and directional ray integration", _rotated)
	_run("independent complete probe/observe parity and fresh region context", _sight_read_reuse)
	print("G08 regression: %d cases, %d checks, %d failures" % [cases, checks, failures])
	quit(0 if failures == 0 else 1)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _near(a: float, b: float, message: String) -> void:
	_check(absf(a - b) < 0.00001, "%s: %.8f / %.8f" % [message, a, b])


func _run(title: String, test: Callable) -> void:
	var before := failures
	test.call()
	cases += 1
	print("%s: %s" % ["PASS" if before == failures else "FAIL", title])


func _spec(surface: String = "TR01", type: String = "T02", slope: float = 0.0) -> Dictionary:
	return {"surface": surface, "type": type, "slope": slope}


func _variant(name: String) -> RefCounted:
	for spec in Fixtures.movement_cases():
		if spec.name == name: return Fixtures.lane(spec)
	return null


func _surfaces() -> void:
	var expected := [[1.0, 1.0, 1.0, 1.0], [1.1, 1.5, 1.5, 1.0], [0.95, 0.85, 0.95, 1.1], [0.85, 0.7, 0.85, 1.3], [0.8, 0.45, 0.65, 1.8], [0.65, 0.0, 0.4, 2.5], [0.75, 0.4, 0.65, 2.0], [1.0, 1.1, 1.1, 1.2], [0.5, 0.0, 0.35, 3.0], [0.35, 0.4, 0.5, 2.5], [0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0], [0.7, 0.35, 0.5, 2.0]]
	for index in 13:
		for movement_class in 3:
			var s := Fixtures.lane(_spec("TR%02d" % (index + 1), ["person", "T02", "T05"][movement_class]))
			var result: Dictionary = s.start()
			var factor: float = expected[index][movement_class]
			_check(result.ok == (factor > 0), "Surface/class permission %d/%d" % [index + 1, movement_class])
			if factor == 0:
				s.advance(100)
				_near(s.travelled, 0, "Refused route never moves")
				_near(s.fuel_used, 0, "Refused route never burns traversal fuel")
				continue
			var speed: float = [2.0, 10.0, 6.0][movement_class] * factor
			_near(s.last_plan.seconds, 60.0 / speed, "Actual lane duration uses one terrain factor")
			s.advance(s.last_plan.seconds * 0.5)
			_near(s.entity.position.x, 40, "Half actual elapsed lane reaches half distance")
			s.advance(s.last_plan.seconds * 0.5)
			_check(s.state == "Arrived", "Supported body reaches actual endpoint")
			_near(s.travelled, 60, "Physical horizontal distance")
			_near(s.fuel_used, 60.0 / 1000.0 * [0.0, 2.0, 6.0][movement_class] * expected[index][3], "Distance-based fuel")
	var road := Fixtures.lane(_spec("TR02"))
	road.start()
	_near(road.last_plan.seconds, 4.0, "T02 road60m at15m/s, not22.5")


func _slopes() -> void:
	var degrees := [10.0, 10.001, 15.0, 15.001, 25.0, 25.001, 40.0, 40.001]
	var factors := [[1.0, 1.0, 1.0], [0.8, 0.6, 0.8], [0.8, 0.6, 0.8], [0.65, 0.0, 0.5], [0.65, 0.0, 0.5], [0.4, 0.0, 0.0], [0.4, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for index in degrees.size():
		for movement_class in 3:
			var s := Fixtures.lane(_spec("TR01", ["person", "T02", "T05"][movement_class], degrees[index]))
			var result: Dictionary = s.start()
			var factor: float = factors[index][movement_class]
			_check(result.ok == (factor > 0), "Actual slope %.3f class%d" % [degrees[index], movement_class])
			if factor > 0: _near(s.last_plan.seconds, 60.0 / ([2.0, 10.0, 6.0][movement_class] * factor), "Slope time")
			_check(s.world.ground(Vector2(70, 12)) > s.world.ground(Vector2(10, 12)), "Slope is actual shaped height")


func _composition() -> void:
	var s := Fixtures.lane(_spec("TR05", "T02", 12.0))
	s.start()
	_near(s.last_plan.seconds, 60 / (10 * 0.45 * 0.6), "Lightforest and independent slope multiply")
	_near(s.last_plan.fuel, 0.216, "Slope does not invent another fuel multiplier")
	s = Fixtures.lane(_spec("TR06", "T02", 1.0))
	_check(not s.start().ok, "Easy slope cannot override denseforest wheel prohibition")
	s = Fixtures.lane(_spec())
	s.world.paint(Rect2i(30, 0, 10, 24), "TR03")
	s.world.paint(Rect2i(40, 0, 10, 24), "TR05")
	s.start()
	_check(s.last_plan.parts.any(func(p: Dictionary) -> bool: return p.surfaces.size() == 2), "Whole footprint straddles adjacent surfaces during transition")
	_check(s.last_plan.parts.all(func(p: Dictionary) -> bool: return p.speed >= 4.5 - 0.00001), "Restrictive applicable speed, no multiplication of adjacent terrain classes")


func _fords() -> void:
	for values in [["person", 0.6, true], ["person", 0.6001, false], ["T02", 0.35, true], ["T02", 0.3501, false], ["T05", 0.8, true], ["T05", 0.8001, false]]:
		var spec := _spec("TR10", values[0])
		spec.depth = values[1]
		_check(Fixtures.lane(spec).start().ok == values[2], "Exact ford class/depth limit")
	for name in ["Foot-only ford", "Soft ford bottom", "Inaccessible ford bank", "Unmarked ford", "Deep bog"]:
		var s := _variant(name)
		_check(not s.start().ok, name + " refuses actual wheeled entry")
		_near(s.fuel_used, 0, "No refused-ford fuel")
	var s := Fixtures.lane(_spec("TR09", "T05"))
	s.world.paint(s.world.bounds, "TR09", {"deep_bog": true})
	_check(not s.start().ok, "Tracks cannot use deep bog")


func _clearance() -> void:
	for name in ["Track trunk contact", "Wheel boulder contact", "Narrow town alley"]:
		var s := _variant(name)
		_check(not s.start().ok and s.reason.contains("Footprint"), "Full hull refuses " + name)
	_check(_variant("Track clear forest gap").start().ok, "Track can use actual clear forest gap")
	var s := Fixtures.lane(_spec())
	s.world.obstacle("tiny-between-endpoints", Rect2(41.123, 11.95, 0.001, 0.1), 0, 3)
	_check(not s.start().ok, "Continuous sweep catches submillimetre obstacle between time samples")
	s = Fixtures.lane(_spec())
	s.world.obstacle("touch-only", Rect2(30, 13.25, 1, 1), 0, 3)
	_check(s.start().ok, "Boundary contact alone is not interior collision")
	s = Fixtures.lane(_spec())
	s.entity.position = Vector2(3, 12)
	_check(not s.start().ok, "Whole footprint boundary, not centre only")
	s = Fixtures.lane(_spec())
	s.destination = Vector2(70, 14)
	_check(not s.start().ok and s.reason.contains("alignment"), "Unimplemented turn cannot become instant orientation")
	s = Fixtures.lane(_spec())
	s.world.paint(Rect2i(40, 0, 10, 24), "TR01", {"height": 3.0})
	_check(not s.start().ok and s.reason.contains("height"), "Flat tile labels cannot teleport a hull over a3m vertical step")


func _overlays() -> void:
	for name in ["Completed crossing", "Completed causeway"]:
		var s := _variant(name)
		_check(s.start().ok, name + " supports declared compatible body")
		s.advance(100)
		_check(s.state == "Arrived", "Actual overlay traversal")
	for name in ["Unbuilt crossing", "Narrow crossing", "Adjacent cliff", "Road cannot erase slope", "Unbuilt causeway"]:
		_check(not _variant(name).start().ok, name + " cannot bypass full-footprint limits")
	var s := _variant("Completed crossing")
	s.world.paint(Rect2i(30, 8, 20, 8), "TR11", {"overlay": {"kind": "crossing", "complete": true, "classes": [0]}})
	_check(not s.start().ok, "Declared class compatibility matters independently")


func _vehicles() -> void:
	var expected := [["T01", 8.0, 12.0, 2.0, Vector2(7, 2.7)], ["T02", 10.0, 15.0, 2.0, Vector2(6.8, 2.5)], ["T03", 12.0, 18.0, 1.5, Vector2(5.2, 2.1)], ["T04", 8.0, 12.0, 4.0, Vector2(7.5, 3)], ["T05", 6.0, 9.0, 6.0, Vector2(8.5, 3.5)]]
	for values in expected:
		for surface in ["TR01", "TR02"]:
			var s := Fixtures.lane(_spec(surface, values[0]))
			_check(s.entity.size == values[4] and s.entity.movement_class == (2 if values[0] == "T05" else 1), "Actual catalogue hull dimensions and movement class " + values[0])
			_check(s.start().ok, "Declared vehicle admits supported straight lane")
			_near(s.last_plan.seconds, 60.0 / values[1 if surface == "TR01" else 2], "Vehicle terrain base applies once")
			s.advance(100)
			_near(s.fuel_used, 0.06 * values[3], "Vehicle-specific actual fuel")
		var narrow := Fixtures.lane(_spec("TR08", values[0]))
		narrow.world.obstacle("north-wall", Rect2(25, 0, 20, 10.8), 0, 8)
		narrow.world.obstacle("south-wall", Rect2(25, 13.2, 20, 10.8), 0, 8)
		_check(narrow.start().ok == (values[0] == "T03"), "2.4m alley admits2.1m technical, refuses wider hulls")


func _interruption() -> void:
	var a := Fixtures.lane(_spec("TR05"))
	var b := Fixtures.lane(_spec("TR05"))
	a.start()
	b.start()
	a.advance(10)
	for step in 100: b.advance(0.1)
	_near(a.entity.position.x, b.entity.position.x, "Time partition preserves actual position")
	_near(a.fuel_used, b.fuel_used, "Time partition preserves fuel")
	a.cancel()
	var position: Vector2 = a.entity.position
	var used: float = a.fuel_used
	a.advance(100)
	_check(a.entity.position == position, "Cancellation stops at real position")
	_near(a.fuel_used, used, "Stopped body consumes no travel fuel")
	a.start()
	a.advance(100)
	_near(a.travelled, 60, "Resume finishes remaining physical lane once")


func _fuel() -> void:
	var s := Fixtures.lane(_spec())
	s.entity.fuel = 0.149
	_check(not s.start().ok and s.reason.contains("25%"), "Leg requires real fuel plus25% reserve")
	s.entity.fuel = 0.15
	_check(s.start().ok, "Exact reserve boundary accepted")
	# Declared test fault after valid admission; no refuel/resource feature here.
	s.entity.fuel = 0.01
	s.advance(100)
	_check(s.state == "Fuel Empty", "Actual fuel exhaust stops motion")
	_near(s.travelled, 5.0, "Only affordable metres travelled")
	_near(s.entity.position.x, 15, "Actual stopped location")
	_near(s.fuel_used, 0.01, "No negative or phantom burn")


func _edit() -> void:
	var s := Fixtures.lane(_spec())
	s.start()
	s.advance(1)
	s.world.paint(Rect2i(40, 0, 10, 24), "TR11")
	var position: Vector2 = s.entity.position
	s.advance(100)
	_check(s.state == "Blocked" and s.entity.position == position, "Changed route stops actual body rather than teleporting past water")
	_near(s.travelled, 10, "No extra blocked distance")
	_near(s.fuel_used, 0.02, "No imaginary blocked fuel")


func _observation(name: String) -> Dictionary:
	var fixture := Fixtures.sight(name)
	return fixture.world.observe(fixture.observer, fixture.target, fixture.role, fixture.muzzle, fixture.weapon_range)


func _legacy_sight(world: RefCounted) -> RefCounted:
	var legacy := LegacySightWorld.new()
	for key in ["bounds","cells","base_regions","scenario","obstacles","shields","field_effects","bridge_approaches","revision"]: legacy.set(key,world.get(key))
	return legacy

func _sight_state(world: RefCounted) -> Dictionary:
	return {"bounds":world.bounds,"cells":world.cells.duplicate(true),"regions":world.base_regions.duplicate(true),"obstacles":world.obstacles.duplicate(true),"shields":world.shields.duplicate(true),"revision":world.revision}

func _probe_parity(world: RefCounted, start: Vector2, finish: Vector2, eye: float, target_height: float, maximum: float, drone: bool, label: String) -> Dictionary:
	var legacy := _legacy_sight(world)
	var before := _sight_state(world)
	var expected: Dictionary = legacy.probe(start,finish,eye,target_height,maximum,drone)
	var actual: Dictionary = world.probe(start,finish,eye,target_height,maximum,drone)
	_check(var_to_bytes(actual) == var_to_bytes(expected),label+": complete prior probe fields/ordered segments/budget/first blocker match exactly")
	_check(world.is_visible(start,finish) == legacy.observe(start,finish).visible,label+": ordinary boolean API matches independent prior observe visibility")
	_check(_sight_state(world) == before,label+": probe does not mutate world or raw region tiles")
	return actual

func _sight_parity(world: RefCounted, start: Vector2, finish: Vector2, role: String, muzzle: float, weapon_range: float, label: String) -> void:
	var legacy := _legacy_sight(world)
	var before := _sight_state(world)
	var expected: Dictionary = legacy.observe(start,finish,role,muzzle,weapon_range)
	var actual: Dictionary = world.observe(start,finish,role,muzzle,weapon_range)
	_check(var_to_bytes(actual) == var_to_bytes(expected),label+": complete prior observe result including independent eye/muzzle matches exactly")
	_check(world.is_visible(start,finish,role) == expected.visible,label+": role boolean API matches independent prior observe visibility")
	_check(_sight_state(world) == before,label+": observation does not mutate world")
	var profile: Dictionary = Catalog.ROLES[role]
	_probe_parity(world,start,finish,profile.eye,1.7,profile.range,role == "drone",label+" direct call")

func _sight_read_reuse() -> void:
	for name in Fixtures.sight_cases():
		var fixture: Dictionary = Fixtures.sight(name)
		_sight_parity(fixture.world,fixture.observer,fixture.target,fixture.role,fixture.muzzle,fixture.weapon_range,name)
	var plain := World.new()
	for distance in [0.0,World.EPS*0.5,World.EPS,World.EPS*2.0,1.0]:
		for maximum in [0.0,distance-World.EPS*0.5,distance,distance+World.EPS]:
			_probe_parity(plain,Vector2.ZERO,Vector2(distance,0),1.7,1.7,maximum,false,"Near/zero distance and range EPS")
	_probe_parity(plain,Vector2(-0.25,20),Vector2(2,20),1.7,1.7,1.0,false,"Range rejection still precedes outside-world refusal")
	_probe_parity(plain,Vector2(-0.25,20),Vector2(2,20),1.7,1.7,10.0,false,"Outside-world direct-call fallback fields")
	var world := CountedProbeWorld.new()
	world.bounds = Rect2i(0,0,300,80)
	world.add_base_region(world.bounds,"TR01")
	for area in [Rect2i(0,20,10,1),Rect2i(211,20,20,1),Rect2i(10,19,201,1),Rect2i(10,21,201,1)]: world.add_base_region(area,"TR11",{"height":9.0})
	world.add_base_region(Rect2i(60,20,20,1),"TR05",{"vegetation_height":12.0})
	world.add_base_region(Rect2i(110,20,10,1),"TR06",{"vegetation_height":18.0,"canopy":true})
	var a := Vector2(10.5,20.5)
	var b := Vector2(210.5,20.5)
	var result: Dictionary = world.probe(a,b,1.7,1.7,220.0)
	_check(result.clear and world.preparations == 1,"One fresh region candidate list for a supported direct probe")
	_check(world.candidates.size() == 3 and is_same(world.candidates[0],world.base_regions[6]) and is_same(world.candidates[1],world.base_regions[5]) and is_same(world.candidates[2],world.base_regions[0]),"Exact ray-cell bounds exclude four outside-touching regions while retaining descending identity/order")
	_check(world.lookup_cells.size() == world.ray_cells(a,b).size(),"Clear ray still resolves every original segment in order")
	for role in Catalog.ROLES:
		for target in [b,Vector2(1000,20.5)]:
			var calls: int = world.probe_calls
			var visible: bool = world.is_visible(a,target,role)
			_check(world.probe_calls == calls+1,"Boolean visibility invokes exactly one real probe for "+role)
			_check(visible == _legacy_sight(world).observe(a,target,role).visible,"Single-probe visibility retains prior eye rules in/out of range for "+role)
	_sight_parity(world,a,b,"ordinary",1.5,220.0,"Layered half-open base regions")
	world.base_regions[1].area = Rect2i(150,20,1,1)
	_check(not _probe_parity(world,a,b,1.7,1.7,220.0,false,"Previously excluded region moves into ray").clear,"Next query sees actual changed region height")
	world.paint(Rect2i(150,20,1,1),"TR01")
	_sight_parity(world,a,b,"ordinary",1.5,220.0,"Explicit cell overrides changed region")
	world.add_base_region(world.bounds,"TR03",{"height":2.0,"gradient":Vector2(0.02,0.01),"vegetation_height":2.5})
	_sight_parity(world,a,b,"ordinary",1.5,220.0,"New last region with continuous nonzero ground plane")
	world.paint(Rect2i(10,20,1,1),"TR11",{"height":99.0,"overlay":{"complete":true,"height":6.0}})
	world.paint(Rect2i(210,20,1,1),"TR11",{"height":99.0,"overlay":{"complete":true,"height":8.0}})
	_sight_parity(world,a,b,"ordinary",1.5,220.0,"Endpoint overlay ground and independent eye/muzzle heights")
	world.obstacle("first-volume",Rect2(90,19,2,3),0,12)
	world.obstacle("second-volume",Rect2(90,19,2,3),0,12)
	_sight_parity(world,a,b,"ordinary",1.5,220.0,"Equal-distance volume first-blocker order")
	world.obstacles.reverse()
	_sight_parity(world,a,b,"drone",1.5,220.0,"Changed obstacle order and drone/ground muzzle independence")
	world.obstacles.clear()
	world.base_regions.append({"area":Rect2(180.25,20,0.5,1),"tile":{"terrain":"TR01","height":20.0}})
	_sight_parity(world,a,b,"ordinary",1.5,220.0,"Fractional region between integer ray cells")
	world.base_regions[-1].area = Rect2(180,20,0.25,1)
	_check(not _probe_parity(world,a,b,1.7,1.7,220.0,false,"Fractional region now contains integer ray cell").clear,"Non-integer areas retain original membership semantics")
	world.base_regions.append({"area":Rect2i(0,0,0,1),"tile":{"terrain":"TR11"}})
	world.base_regions.append({"area":Rect2i(0,0,-1,1),"tile":{"terrain":"TR11"}})
	world.base_regions.append({"area":Rect2i(2147483640,20,20,1),"tile":{"terrain":"TR11"}})
	world.add_base_region(world.bounds,"TR01") # shadows unsupported negative-size point membership
	_sight_parity(world,a,b,"ordinary",1.5,220.0,"Unusual region candidates retained conservatively")
	_check(world.candidates.size() == world.base_regions.size()-3,"Fractional/zero/negative areas retained; moved and remaining outside-touching regions handled freshly")
	var extreme_segments: Array[Dictionary] = [{"cell":Vector2i(2147483647,20)}]
	_check(world._probe_regions(extreme_segments).size() == world.base_regions.size(),"Unrepresentable exclusive ray-cell end conservatively retains all regions")
	var forest := CountedProbeWorld.new()
	forest.bounds = world.bounds
	forest.add_base_region(forest.bounds,"TR05",{"vegetation_height":12.0})
	result = forest.probe(a,b,1.7,1.7,220.0)
	_check(result.reason == "Vegetation budget" and forest.lookup_cells.size() < forest.ray_cells(a,b).size() and forest.lookup_cells[-1] == result.segments[-1].cell,"Budget stop retains original last tile read without resolving later ray cells")
	_sight_parity(forest,a,b,"ordinary",1.5,220.0,"Shared forest budget reaches exact original blocker")
	forest.obstacle("near-opaque",Rect2(50,19,1,3),0,8)
	_sight_parity(forest,a,b,"ordinary",1.5,220.0,"Opaque stop truncates vegetation before budget exhaustion")
	forest.obstacles.clear()
	forest.base_regions[0].tile.vegetation_height = 0.0
	_sight_parity(forest,a,b,"ordinary",1.5,220.0,"Same world sees changed vegetation on next probe")
	var rotated := World.new()
	rotated.bounds = Rect2i(-60,-60,320,160)
	rotated.add_base_region(rotated.bounds,"TR05",{"vegetation_height":12.0,"gradient":Vector2(0.01,0.01)})
	for ends in [[Vector2(-20.5,-20.5),Vector2(90.5,40.5)],[Vector2(90.5,40.5),Vector2(-20.5,-20.5)],[Vector2(-20,0),Vector2(90,0)]]:
		_sight_parity(rotated,ends[0],ends[1],"ordinary",1.5,220.0,"Negative/rotated/grid-edge ray traversal")

func _ranges() -> void:
	_check(_observation("Ordinary at 220m").visible, "Ordinary220 inclusive")
	_check(not _observation("Ordinary beyond 220m").visible, "Ordinary beyond220 blocked")
	var world := World.new()
	for values in [["ordinary", 220.0], ["binocular_ready", 350.0], ["driver", 220.0], ["technical_gunner", 250.0], ["apc_commander", 450.0], ["tank_commander", 700.0], ["lookout_staffed", 500.0], ["field_gun_deployed", 650.0], ["drone", 350.0]]:
		_check(world.observe(Vector2(10, 20), Vector2(10 + values[1], 20), values[0]).visible, "Declared active role at actual range " + values[0])
		_check(not world.observe(Vector2(10, 20), Vector2(10.001 + values[1], 20), values[0]).visible, "Role range not weapon range or camera zoom")


func _vegetation() -> void:
	var below := _observation("Mixed foliage just below budget")
	var limit := _observation("Mixed foliage reaches 100")
	_check(below.visible and not limit.visible, "Mixed budget below100 versus threshold")
	_near(below.eye.budget, 99, "20dense*3+39light*1")
	_near(limit.eye.budget, 100, "20dense*3+40light*1")
	_check(limit.eye.reason == "Vegetation budget" and limit.eye.segments.size() > 1, "Actual contributing cells inspectable")
	var world := World.new()
	world.paint(Rect2i(20, 19, 100, 2), "TR05", {"vegetation_height": 12.0})
	_check(world.probe(Vector2(10, 20), Vector2(130, 20), 1.7, 1.7, 220).budget == 100, "100m light foliage blocks")


func _height() -> void:
	_check(_observation("Ridge blocks ground eye").eye.reason == "Terrain height", "Ground ridge actual height blocks")
	for name in ["Opaque tree trunk", "Opaque building"]:
		_check(_observation(name).eye.reason == "Opaque volume", name + " blocks independently of foliage budget")
	var split := _observation("Eye clears low ridge; rifle muzzle blocked")
	_check(split.visible and not split.firing_line_clear and split.muzzle.reason == "Terrain height", "Visible eye does not permit lower muzzle through ridge")
	_near(split.eye.from.z, 1.7, "Actual eye height")
	_near(split.muzzle.from.z, 1.5, "Independent actual muzzle height")
	_near(_observation("Elevated target").eye.to.z, 16.7, "Target height relative to real local ground")


func _drone() -> void:
	_check(not _observation("Low crops block ground").visible, "200m tall crops exhaust ground budget")
	_check(_observation("Drone ignores low crops").visible, "Drone ignores low crops")
	_check(_observation("Drone target under dense canopy").eye.reason == "Dense canopy", "Drone cannot reveal person under actual dense canopy")
	for name in ["Opaque smoke / ground", "Opaque smoke / drone"]:
		_check(_observation(name).eye.reason == "Opaque volume", "Static opaque smoke volume blocks both roles")
	var value := _observation("Drone sees beyond ridge; ground muzzle blocked")
	_check(value.visible and not value.firing_line_clear, "Drone observation does not raise ground muzzle")
	_near(value.eye.from.z, 40, "Declared drone actual40m height")


func _cover() -> void:
	for values in [["Directional rock front", 0.5], ["Directional rock rear", 1.0], ["Strongest forest and sandbag", 0.5], ["Bunker physical shield", 0.25], ["Exposed crossing deck", 1.0], ["Vehicle has no forest bonus", 1.0]]:
		var fixture := Fixtures.sight(values[0])
		var value: Dictionary = fixture.world.cover(fixture.target, fixture.observer, fixture.cover_class, false, fixture.impact)
		_near(value.hit, values[1], values[0])
		if values[0] == "Bunker physical shield": _near(value.blast, 0.25, "Bunker blast benefit separately inspected")
		if values[0] == "Strongest forest and sandbag": _check(value.valid.size() == 2, "Two valid covers select strongest instead of multiplying")
		if values[0] == "Directional rock front": _near(value.blast, 0.5, "Actual rock shields from explicit impact origin")


func _natural_blast() -> void:
	var person := Vector2(30, 20)
	var attacker := Vector2(10, 20)
	var front := Vector3(10, 20, 0)
	var rear := Vector3(50, 20, 0)
	for index in 13:
		var world := World.new()
		var surface := "TR%02d" % (index + 1)
		world.paint(Rect2i(29, 19, 2, 2), surface, {"marked": true, "firm": true, "banks": true, "classes": [0], "depth": 0.3})
		var value: Dictionary = world.cover(person, attacker, 0, false, front)
		_near(value.blast, 0.5 if surface == "TR06" else 1.0, "All13 natural classes: " + surface)
		for movement_class in [1, 2]: _near(world.cover(person, attacker, movement_class, false, front).blast, 1.0, "Vehicle hull receives no natural blast benefit")
		_near(world.cover(person, attacker, 0, true, front).blast, 1.0, "Exposed deck suppresses natural blast protection")
	var fixture := Fixtures.sight("Directional rock front")
	var world: RefCounted = fixture.world
	_near(world.cover(person, attacker, 0, false, front).blast, 0.5, "Rock on actual impact side protects")
	var value: Dictionary = world.cover(person, attacker, 0, false, rear)
	_near(value.hit, 0.5, "Direct attacker still shielded independently")
	_near(value.blast, 1.0, "Rock on wrong blast side cannot protect from impact")
	value = world.cover(person, Vector2(50, 20), 0, false, front)
	_near(value.hit, 1.0, "Direct wrong side has no benefit")
	_near(value.blast, 0.5, "Blast selects its actual origin independently of direct attacker")
	for missing in [null, Vector3(NAN, 20, 0), Vector3(30, 20, 1.7)]:
		value = world.cover(person, attacker, 0, false, missing)
		_check(value.blast == 1.0 and value.blast_eligibility.contains("Missing"), "Absent/nonfinite/coincident impact cannot fabricate a rock shield")
	world.shields.clear()
	value = world.cover(person, attacker, 0, false, front)
	_check(value.blast == 1.0 and value.blast_eligibility.contains("No shielding"), "TR07 alone is not blast cover")
	world.shields.append({"kind": "rock", "area": Rect2(29, 19, 2, 2)})
	value = world.cover(person, attacker, 0, false, front)
	_check(value.blast == 1.0 and value.blast_eligibility.contains("Invalid"), "Unusable shield geometry is explicitly rejected")
	world = Fixtures.sight("Directional rock front").world
	world.shields[0].top = 0.1
	_near(world.cover(person, attacker, 0, false, front).blast, 1.0, "Rock below actual blast line does not shield")
	world = Fixtures.sight("Directional rock front").world
	world.shields[0].area = Rect2(40, 19, 2, 2)
	_near(world.cover(person, attacker, 0, false, front).blast, 1.0, "Person must occupy the declared shielded place")
	world = Fixtures.sight("Strongest forest and sandbag").world
	value = world.cover(person, attacker, 0, false, front)
	_near(value.blast, 0.5, "Dense forest and sandbag do not stack")
	world.shields[0].kind = "S01"
	_near(world.cover(person, attacker, 0, false, front).blast, 0.5, "Trench0.5 and dense forest0.5 do not multiply")
	world.shields[0].kind = "S03"
	value = world.cover(person, attacker, 0, false, front)
	_near(value.blast, 0.25, "Bunker beats forest blast benefit without stacking")
	_check(value.blast_source == "declared-shield" and value.blast_valid.size() == 2, "Blast winner and valid candidates are inspectable")
	value = world.cover(person, attacker, 0, false, rear)
	_check(value.hit == 0.25 and value.blast == 0.5 and value.blast_source == "TR06", "Direct winner can differ from strongest valid blast benefit")
	world.shields.clear()
	world.obstacle("solid-trunk-at-probe", Rect2(29.8, 19.8, 0.4, 0.4), 0, 8)
	value = world.cover(person, attacker, 0, false, front)
	_check(value.blast == 1.0 and value.blast_eligibility.contains("occupied"), "Dense forest does not protect an impossible occupied solid position")
	world.obstacles.clear()
	world.paint(Rect2i(29, 19, 2, 2), "TR06", {"gradient": Vector2(2, 0)})
	_near(world.cover(person, attacker, 0, false, front).blast, 1.0, "Invalid foot support is not valid occupied forest cover")
	world.paint(Rect2i(29, 19, 2, 2), "TR06", {"overlay": {"kind": "crossing", "complete": true, "classes": [0]}})
	_near(world.cover(person, attacker, 0, false, front).blast, 1.0, "Completed exposed crossing suppresses underlying denseforest protection")
	world.paint(Rect2i(29, 19, 2, 2), "TR06", {"overlay": {"kind": "crossing", "complete": false, "classes": [0]}})
	_near(world.cover(person, attacker, 0, false, front).blast, 0.5, "Unbuilt overlay does not erase actual forest cover")


func _detached() -> void:
	var s := Fixtures.lane(_spec())
	s.start()
	var view: Dictionary = s.snapshot()
	view.entity.position = Vector2.ZERO
	view.motion.parts.clear()
	s.advance(1)
	_near(s.entity.position.x, 20, "Returned snapshots cannot change actual movement")


func _overlay_structure_cover() -> void:
	var person := Vector2(30, 20)
	var front := Vector2(10, 20)
	var rear := Vector2(50, 20)
	var impact := Vector3(10, 20, 0)
	var shield := {"id": "sandbags", "kind": "S02", "area": Rect2(29, 19, 2, 2), "rect": Rect2(28, 19, 0.5, 2), "bottom": 0.0, "top": 2.0}
	for kind in ["road", "causeway", "crossing"]:
		var world := World.new()
		world.paint(Rect2i(29, 19, 2, 2), "TR09" if kind == "causeway" else "TR06", {"overlay": {"kind": kind, "complete": true, "classes": [0]}})
		var value: Dictionary = world.cover(person, front, 0, false, impact)
		_check(value.hit == 1.0 and value.blast == 1.0, "Completed exposed support suppresses underlying natural benefits only: " + kind)
		world.shields.append(shield.duplicate(true))
		value = world.cover(person, front, 0, false, impact)
		_check(value.hit == 0.65 and value.source == "sandbags" and value.valid.has("sandbags"), "Real sandbags remain valid on completed exposed support: " + kind)
		value = world.cover(person, rear, 0, false, Vector3(50, 20, 0))
		_check(value.hit == 1.0 and value.blast == 1.0, "Wrong-side structure grants no cover on exposed support")
		world.shields[0].kind = "S03"
		value = world.cover(person, front, 0, false, impact)
		_check(value.hit == 0.25 and value.blast == 0.25, "Actual strongest structure provides its own direct/blast benefit")
		value = world.cover(person, front, 0, false, Vector3(50, 20, 0))
		_check(value.hit == 0.25 and value.blast == 1.0, "Independent rear impact gains neither front structure nor underlying forest")
		world.shields.append(shield.duplicate(true))
		value = world.cover(person, front, 0, false, impact)
		_check(value.hit == 0.25 and value.blast == 0.25, "Exposed support does not stack multiple valid structures")
		_check(world.cover(person, front, 1, false, impact).hit == 1.0 and world.cover(person, front, 2, false, impact).blast == 1.0, "Vehicle exclusions survive constructed cover")
		world.shields.clear()
		var rock := shield.duplicate(true)
		rock.kind = "rock"
		world.shields.append(rock)
		value = world.cover(person, front, 0, false, impact)
		_check(value.hit == 1.0 and value.blast == 1.0, "Exposed surface still excludes natural rock benefit")
	var world := World.new()
	world.shields.append(shield.duplicate(true))
	world.paint(Rect2i(29, 19, 2, 2), "TR02")
	_near(world.cover(person, front, 0, false, impact).hit, 0.65, "Baseline TR02 road retains sandbags")
	world.paint(Rect2i(29, 19, 2, 2), "TR01", {"overlay": {"kind": "road", "complete": true, "classes": [0]}})
	_check(world.support(Vector2i(30, 20), 0).surface == "TR02", "At-grade completed road resolves to same actual surface")
	_near(world.cover(person, front, 0, false, impact).hit, 0.65, "Exact review reproduction: at-grade road overlay also retains sandbags")
	world.shields.clear()
	_near(world.cover(person, front, 0, false, impact).hit, 1.0, "At-grade completed road without actual shield is exposed")


func _rotated() -> void:
	var s := Lane.new()
	s.world.bounds = Rect2i(0, 0, 100, 100)
	s.initialize("T02", Vector2(20, 10), PI * 0.5)
	s.destination = Vector2(20, 70)
	_check(s.start().ok, "Rotated actual hull supports aligned vertical lane")
	s.advance(3)
	_near(s.entity.position.y, 40, "Rotated lane moves actual yposition")
	s.cancel()
	s.world.obstacle("side-contact", Rect2(21.2, 50, 0.1, 0.1), 0, 3)
	_check(not s.start().ok, "Continuous SAT uses rotated halfwidth against tiny side obstacle")
	var world := World.new()
	world.bounds = Rect2i(0, 0, 100, 100)
	world.paint(world.bounds, "TR05", {"vegetation_height": 12.0})
	var a := Vector2(10, 10)
	var b := Vector2(50, 50)
	var forward: Dictionary = world.probe(a, b, 1.7, 1.7, 220)
	var reverse: Dictionary = world.probe(b, a, 1.7, 1.7, 220)
	_near(forward.budget, a.distance_to(b), "Diagonal foliage uses horizontal metres, not crossed-cell count")
	_near(reverse.budget, forward.budget, "Reverse ray integrates same physical foliage")
	world.obstacle("low-trunk", Rect2(29, 29, 2, 2), 0, 3)
	_check(not world.probe(a, b, 1.7, 1.7, 220).clear, "Diagonal opaque volume intercept")
	_check(world.probe(a, b, 40, 40, 220, true).clear, "Ray above actual opaque top remains clear")
