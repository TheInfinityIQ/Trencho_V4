extends SceneTree

const Catalog = preload("res://game/terrain/terrain_catalog.gd")
const World = preload("res://game/terrain/terrain_world.gd")
const Lane = preload("res://game/terrain/lane_simulation.gd")
const Fixtures = preload("res://game/terrain/terrain_fixtures.gd")
var checks: int = 0
var failures: int = 0
var cases: int = 0


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
	_run("detached inspection preserves authoritative movement", _detached)
	_run("rotated hull sweep and directional ray integration", _rotated)
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
		var value: Dictionary = fixture.world.cover(fixture.target, fixture.observer, fixture.cover_class)
		_near(value.hit, values[1], values[0])
		if values[0] == "Bunker physical shield": _near(value.blast, 0.25, "Bunker blast benefit separately inspected")
		if values[0] == "Strongest forest and sandbag": _check(value.valid.size() == 2, "Two valid covers select strongest instead of multiplying")
		if values[0] == "Directional rock front": _check(value.blast == null, "Unapproved heavy-natural classification remains explicit, not an invented blast rule")


func _detached() -> void:
	var s := Fixtures.lane(_spec())
	s.start()
	var view: Dictionary = s.snapshot()
	view.entity.position = Vector2.ZERO
	view.motion.parts.clear()
	s.advance(1)
	_near(s.entity.position.x, 20, "Returned snapshots cannot change actual movement")


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
