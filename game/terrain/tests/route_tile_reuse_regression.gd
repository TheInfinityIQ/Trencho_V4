extends SceneTree
## Independent pre-reuse lookup/admission oracle; no inherited route or support lookup.
const World = preload("res://game/terrain/terrain_world.gd")
const Fixtures = preload("res://game/terrain/terrain_fixtures.gd")
const Map = preload("res://game/battlefield/farmland_scenario.gd")
var checks := 0
var failures := 0

class LegacyWorld extends World:
	# Verbatim cell/support/route control flow from 01942b3. Unchanged geometry
	# and aggregation helpers are shared; the new tile/support path is not.
	var resolutions: Dictionary = {}
	func cell(at: Vector2i) -> Dictionary:
		resolutions[at] = int(resolutions.get(at,0))+1
		if cells.has(at): return cells[at]
		for index in range(base_regions.size()-1,-1,-1):
			if base_regions[index].area.has_point(at): return base_regions[index].tile
		return {"terrain": "TR01"}

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
		for y in range(maxi(bounds.position.y, int(floor(minimum.y))), mini(bounds.end.y, int(ceil(maximum.y)))):
			for x in range(maxi(bounds.position.x, int(floor(minimum.x))), mini(bounds.end.x, int(ceil(maximum.x)))):
				var at := Vector2i(x, y)
				var interval := _overlap_interval(entity, start, destination, Rect2(Vector2(at), Vector2.ONE))
				if interval.x < 0: continue
				if not str(cell(at).get("closed_project","")).is_empty(): return _blocked("Active project closes this segment to traffic")
				var rule := support(at, entity.movement_class)
				if not rule.ok: return _blocked("Cell %s: %s" % [at, rule.reason])
				for effect in field_effects:
					if not effect.area.has_point(Vector2(at)+Vector2(0.5,0.5)): continue
					if effect.code == "S02" and entity.movement_class == 0: rule.factor *= 0.8
					if effect.code == "S05" and entity.movement_class == 0: rule.factor *= 0.7
					if effect.code == "S04" and entity.movement_class == 2: rule.factor *= 0.25
				var overlay: Dictionary = cell(at).get("overlay",{})
				if overlay.get("complete",false) and overlay.get("kind","") == "causeway" and entity.has("gross_mass_kg") and float(entity.gross_mass_kg) > float(overlay.get("load_kg",8000.0))+EPS:
					return _blocked("Causeway gross-load limit excludes this actual body and contents")
				if overlay.get("complete",false) and overlay.get("kind","") == "crossing" and overlay.has("code"):
					if entity.has("gross_mass_kg") and not entity.get("bridge_existing_traffic",false) and float(entity.gross_mass_kg) > float(overlay.load_kg)+EPS: return _blocked("%s gross-load limit excludes this actual body and contents" % overlay.code)
					if entity.size.y > float(overlay.width)+EPS: return _blocked("%s deck is narrower than the actual footprint" % overlay.code)
					rule["speed_cap"] = float(overlay.speed_cap)
				elif bridge_approaches.has(at):
					var approach_cap := INF
					for cap in bridge_approaches[at].values(): approach_cap = minf(approach_cap,float(cap))
					rule["speed_cap"] = approach_cap
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
		return _route_parts(entity, start, destination, distance, intervals, cuts)

class CountedWorld extends World:
	var resolutions: Dictionary = {}
	var height_calls := 0
	var support_calls := 0
	var rules: Array[Dictionary] = []
	func cell(at: Vector2i) -> Dictionary:
		resolutions[at] = int(resolutions.get(at,0))+1
		return super.cell(at)
	func _tile_height(tile: Dictionary, point: Vector2) -> float:
		height_calls += 1
		return super._tile_height(tile,point)
	func _support_from_tile(tile: Dictionary, movement_class: int) -> Dictionary:
		support_calls += 1
		return super._support_from_tile(tile,movement_class)
	func _route_parts(entity: Dictionary, start: Vector2, destination: Vector2, distance: float, intervals: Array[Dictionary], cuts: Array[float]) -> Dictionary:
		for interval in intervals: rules.append(interval.rule)
		return super._route_parts(entity,start,destination,distance,intervals,cuts)

func _initialize() -> void:
	for spec in Fixtures.movement_cases():
		var lane: RefCounted = Fixtures.lane(spec)
		_compare(lane.world,lane.entity,lane.destination,spec.name)
	_regions_and_mutations()
	_height_identity()
	_rule_identity()
	_bridges_and_effects()
	_generated()
	_farmland()
	print("Route tile reuse regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _copy(source: RefCounted, destination: RefCounted) -> void:
	for key in ["bounds","cells","base_regions","scenario","obstacles","shields","field_effects","bridge_approaches","revision"]:
		destination.set(key,source.get(key))

func _state(world: RefCounted) -> Dictionary:
	return {"cells":world.cells.duplicate(true),"regions":world.base_regions.duplicate(true),"effects":world.field_effects.duplicate(true),"approaches":world.bridge_approaches.duplicate(true),"revision":world.revision}

func _compare(source: RefCounted, body: Dictionary, finish: Vector2, label: String, report: bool = false) -> Dictionary:
	var legacy := LegacyWorld.new()
	var actual_world := CountedWorld.new()
	_copy(source,legacy)
	_copy(source,actual_world)
	var before := _state(source)
	var expected: Dictionary = legacy.route(body,finish)
	var actual: Dictionary = actual_world.route(body,finish)
	_expect(actual == expected,label+": exact result/first rejection and every ordered part/total")
	_expect(_state(source) == before,label+": lookup/support never mutates shared raw tiles or effects")
	_expect(actual_world.resolutions.keys() == legacy.resolutions.keys(),label+": resolves the same occupied cells in original order")
	var old_calls := 0
	var new_calls := 0
	for count in legacy.resolutions.values(): old_calls += int(count)
	for count in actual_world.resolutions.values(): new_calls += int(count)
	_expect(new_calls == actual_world.resolutions.size(),label+": each occupied cell resolved at most once per route")
	_expect(new_calls <= old_calls,label+": no extra cell resolutions")
	if actual.ok: _expect(old_calls >= new_calls*3,label+": removes repeated support/overlay/height lookup")
	if actual.ok: _expect(actual_world.support_calls == new_calls,label+": every occupied cell still computes fresh support")
	if report: print("LOOKUPS ",label," old=",old_calls," new=",new_calls," parts=",actual.get("parts",[]).size())
	return actual

func _body(start: Vector2, finish: Vector2, movement_class: int = 1) -> Dictionary:
	return {"position":start,"facing":(finish-start).angle(),"size":Vector2(6.0,2.5),"movement_class":movement_class,"base":8.0,"rate":3.0,"gross_mass_kg":7000.0}

func _regions_and_mutations() -> void:
	var world := World.new()
	world.bounds = Rect2i(0,0,100,30)
	world.add_base_region(world.bounds,"TR03")
	world.add_base_region(Rect2i(30,0,40,30),"TR05")
	world.add_base_region(Rect2i(40,0,20,30),"TR02")
	var body := _body(Vector2(10,15),Vector2(90,15))
	_expect(_compare(world,body,Vector2(90,15),"Last overlapping base region wins").ok,"Supported layered route")
	var legacy := LegacyWorld.new()
	_copy(world,legacy)
	for x in [29,30,39,40,59,60,69,70]:
		_expect(world.cell(Vector2i(x,15)) == legacy.cell(Vector2i(x,15)),"Half-open region edge %d" % x)
	world.paint(Rect2i(45,0,3,30),"TR01",{"closed_project":"live-work"})
	_expect(not _compare(world,body,Vector2(90,15),"Explicit closed work overrides region").ok,"Closure refuses before support")
	world.paint(Rect2i(45,0,3,30),"TR11")
	_expect(not _compare(world,body,Vector2(90,15),"Changed explicit impassable cells").ok,"Next query sees changed support")
	world.paint(Rect2i(45,0,3,30),"TR01",{"height":1.0})
	_expect(not _compare(world,body,Vector2(90,15),"Disconnected height first-edge order").ok,"Vertical step remains refused")
	world.paint(Rect2i(45,0,3,30),"TR01")
	_expect(_compare(world,body,Vector2(90,15),"Changed explicit cells restore support").ok,"No memo survives paint")
	world.add_base_region(Rect2i(20,0,60,30),"TR02")
	_expect(_compare(world,body,Vector2(90,15),"New last region with retained explicit override").ok,"No memo survives new region")
	var slope := World.new()
	slope.bounds = world.bounds
	slope.add_base_region(slope.bounds,"TR01",{"gradient":Vector2(0.05,0)})
	_expect(_compare(slope,body,Vector2(90,15),"Continuous shared sloped plane").ok,"Compatible slopes meet at all original edges")
	_copy(slope,legacy)
	for at in [Vector2i(-1,15),Vector2i(0,15),Vector2i(99,15),Vector2i(100,15)]:
		for movement_class in 3: _expect(slope.support(at,movement_class) == legacy.support(at,movement_class),"Public support preserves bounds and class rules")

func _height_identity() -> void:
	var world := World.new()
	world.bounds = Rect2i(0,0,100,30)
	var properties := {"height":10.0,"gradient":Vector2(0.05,0)}
	world.add_base_region(world.bounds,"TR01",properties)
	var finish := Vector2(90,15)
	var body := _body(Vector2(10,15),finish)
	_expect(is_same(world.cell(Vector2i(40,15)),world.cell(Vector2i(41,15))),"One base region returns the same raw tile reference")
	_expect(_compare(world,body,finish,"Shared nonzero sloped height plane").ok,"Shared sloped tile preserves independent legacy output")
	var counted := CountedWorld.new()
	_copy(world,counted)
	_expect(counted.route(body,finish).ok and counted.height_calls == 0,"Shared pure tile skips redundant endpoint height evaluations")
	world.paint(Rect2i(40,0,20,30),"TR01",properties)
	var here: Dictionary = world.cell(Vector2i(40,15))
	var there: Dictionary = world.cell(Vector2i(41,15))
	_expect(here == there and not is_same(here,there),"Equal explicit tile values remain distinct references")
	_expect(_compare(world,body,finish,"Equal but distinct painted height planes").ok,"Distinct equal planes still meet at the original endpoints")
	counted = CountedWorld.new()
	_copy(world,counted)
	_expect(counted.route(body,finish).ok and counted.height_calls > 0,"Distinct dictionary edges retain endpoint height evaluations")
	world.paint(Rect2i(49,14,1,1),"TR01",{"height":11.0,"gradient":Vector2(0.05,0)})
	_expect(not _compare(world,body,finish,"Distinct painted height step").ok,"Distinct height change still fails at the same first edge")
	world.paint(Rect2i(40,0,20,30),"TR01",properties)
	world.base_regions[0].tile.height = 10.5
	_expect(not _compare(world,body,finish,"Shared region mutation beside explicit cells").ok,"Identity shortcut cannot hide a changed boundary to another tile")
	var bridge := World.new()
	bridge.bounds = world.bounds
	bridge.add_base_region(bridge.bounds,"TR11",{"height":99.0,"gradient":Vector2(0.05,0),"overlay":{"kind":"crossing","code":"shared-height","complete":true,"classes":[0,1,2],"load_kg":10000.0,"width":4.0,"speed_cap":2.0,"height":4.0}})
	_expect(_compare(bridge,body,finish,"Shared completed overlay height overrides base plane").ok,"Shared overlay height preserves legacy support")
	counted = CountedWorld.new()
	_copy(bridge,counted)
	_expect(counted.route(body,finish).ok and counted.height_calls == 0,"Same completed overlay tile also needs no redundant endpoint evaluations")
	bridge.paint(Rect2i(49,14,1,1),"TR11",{"overlay":{"kind":"crossing","code":"changed-height","complete":true,"classes":[0,1,2],"load_kg":10000.0,"width":4.0,"speed_cap":2.0,"height":5.0}})
	_expect(not _compare(bridge,body,finish,"Distinct completed overlay height step").ok,"Different overlay reference and height retain the original rejection")

func _rule_identity() -> void:
	var world := World.new()
	world.bounds = Rect2i(0,0,100,30)
	world.add_base_region(world.bounds,"TR01")
	var finish := Vector2(90.5,15.5)
	var body := _body(Vector2(10.5,15.5),finish,0)
	body.size = Vector2(0.6,0.6)
	_expect(_compare(world,body,finish,"Consecutive shared raw tile rules").ok,"Shared-rule lane supported")
	var counted := CountedWorld.new()
	_copy(world,counted)
	_expect(counted.route(body,finish).ok,"Capture supported shared rules")
	_expect(counted.support_calls == counted.rules.size(),"Sharing occurs only after every fresh support evaluation")
	for index in range(1,counted.rules.size()):
		_expect(is_same(counted.rules[index-1],counted.rules[index]),"Unmodified consecutive same tile shares finalized rule")
	world.field_effects = [{"code":"S02","area":Rect2(40,0,2,30)},{"code":"S04","area":Rect2(45,0,1,30)}]
	world.bridge_approaches[Vector2i(60,15)] = {"cap":1.5}
	world.bridge_approaches[Vector2i(61,15)] = {"cap":1.5}
	world.bridge_approaches[Vector2i(65,15)] = {}
	world.paint(Rect2i(70,15,2,1),"TR01")
	_expect(_compare(world,body,finish,"Field factors, equal approach caps and distinct equal tiles").ok,"Modified lane keeps independent admission result")
	counted = CountedWorld.new()
	_copy(world,counted)
	_expect(counted.route(body,finish).ok,"Capture modified rules")
	var cells: Array = counted.resolutions.keys()
	for x in [40,41,42,45,46,60,61,62,65,66,70,71,72]:
		var index := cells.find(Vector2i(x,15))
		_expect(index > 0 and not is_same(counted.rules[index-1],counted.rules[index]),"Modifier/distinct tile prevents adjacent sharing at %d" % x)
	world.field_effects.clear()
	world.bridge_approaches.clear()
	world.add_base_region(world.bounds,"TR11",{"overlay":{"kind":"crossing","code":"shared-rule","complete":true,"classes":[0,1,2],"load_kg":10000.0,"width":4.0,"speed_cap":2.0}})
	world.cells.clear()
	_expect(_compare(world,body,finish,"Same raw crossing tile includes its finalized cap").ok,"Crossing cap and checks preserved")
	counted = CountedWorld.new()
	_copy(world,counted)
	_expect(counted.route(body,finish).ok,"Capture crossing rules")
	_expect(counted.rules.size() > 1 and is_same(counted.rules[0],counted.rules[1]) and counted.rules[0].speed_cap == 2.0,"Same crossing shares only after cap finalization")
	world.base_regions[-1].tile.overlay.speed_cap = 0.75
	_expect(_compare(world,body,finish,"Changed crossing cap recomputed on next query").ok,"No rule reference persists between routes")

func _bridges_and_effects() -> void:
	var world := World.new()
	world.bounds = Rect2i(0,0,100,30)
	world.add_base_region(world.bounds,"TR01")
	world.paint(Rect2i(35,0,15,30),"TR11")
	var deck: Array = []
	var approaches: Array = []
	for y in range(10,20):
		for x in range(15,70):
			if x >= 35 and x < 50: deck.append(Vector2i(x,y))
			else: approaches.append(Vector2i(x,y))
	_expect(world.set_bridge_surface("lookup-bridge",deck,approaches,"B-test",10000,2.0,4.0,[0,1,2],true).ok,"Declared actual bridge surface")
	var body := _body(Vector2(10,15),Vector2(90,15))
	_expect(_compare(world,body,Vector2(90,15),"Bridge deck and cell-local approach caps").ok,"Bridge support remains legal")
	body.gross_mass_kg = 10001.0
	_expect(not _compare(world,body,Vector2(90,15),"Actual bridge load refusal").ok,"Overweight body remains barred")
	body.bridge_existing_traffic = true
	_expect(_compare(world,body,Vector2(90,15),"Existing bridge traffic load exception").ok,"Existing bridge occupant rule unchanged")
	body.erase("bridge_existing_traffic")
	body.gross_mass_kg = 7000.0
	body.size.y = 5.0
	_expect(not _compare(world,body,Vector2(90,15),"Actual bridge width refusal").ok,"Narrow deck still bars the same footprint")
	body.size = Vector2(0.6,0.6)
	body.movement_class = 0
	world.field_effects = [{"id":"sandbags","code":"S02","area":Rect2(20,0,45,30)},{"id":"wire","code":"S05","area":Rect2(40,0,35,30)}]
	_expect(_compare(world,body,Vector2(90,15),"Overlapping effects need a fresh rule per shared base tile").ok,"Infantry effects compose exactly once per cell")
	body.size = Vector2(8.0,3.5)
	body.movement_class = 2
	world.field_effects.append({"id":"obstacle","code":"S04","area":Rect2(25,0,40,30)})
	_expect(_compare(world,body,Vector2(90,15),"Tracked obstacle effect with shared approach tiles").ok,"Track multiplier remains cell-local")
	_expect(world.set_bridge_surface("lookup-bridge",deck,approaches,"B-test",10000,2.0,4.0,[0,1,2],false).ok,"Remove completed support between queries")
	_expect(not _compare(world,body,Vector2(90,15),"Bridge removal invalidates next route").ok,"Removed bridge cannot remain in local memo")
	world.paint(Rect2i(35,0,15,30),"TR09",{"overlay":{"kind":"causeway","complete":true,"classes":[0,1,2],"load_kg":8000.0}})
	_expect(_compare(world,body,Vector2(90,15),"Completed causeway actual support").ok,"Legal causeway restored")
	body.gross_mass_kg = 8001.0
	_expect(not _compare(world,body,Vector2(90,15),"Causeway actual gross load refusal").ok,"Causeway load remains enforced")

func _generated() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 831101
	for trial in 18:
		var world := World.new()
		world.bounds = Rect2i(0,0,90,90)
		world.add_base_region(world.bounds,"TR01")
		for index in 12:
			world.add_base_region(Rect2i(rng.randi_range(12,60),rng.randi_range(12,60),18,18),["TR02","TR03","TR05","TR07","TR08"][index%5])
		world.paint(Rect2i(42,42,2,2),"TR11" if trial%2 == 0 else "TR01")
		var start := Vector2(8,rng.randf_range(8,80))
		var finish := Vector2(80,rng.randf_range(8,80))
		var body := _body(start,finish,trial%3)
		_compare(world,body,finish,"Generated rotated region/explicit footprint %d" % trial)
		world.obstacle("thin-obstacle",Rect2(start.lerp(finish,0.5),Vector2(0.001,0.001)),0,3,true,false)
		_expect(not _compare(world,body,finish,"Generated continuous obstacle %d" % trial).ok,"Thin obstacle retains refusal priority")

func _farmland() -> void:
	var world := World.new()
	Map.apply(world)
	for endpoints in [[Vector2(3000,650),Vector2(3000,2300)],[Vector2(3000,2300),Vector2(3000,650)],[Vector2(1900,1450),Vector2(2250,2100)]]:
		var start: Vector2 = endpoints[0]
		var finish: Vector2 = endpoints[1]
		_expect(_compare(world,_body(start,finish),finish,"Authored Farmland %s -> %s" % [start,finish],true).ok,"Long authored lane remains legal")
