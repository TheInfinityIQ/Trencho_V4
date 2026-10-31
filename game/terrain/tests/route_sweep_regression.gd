extends SceneTree
## Exact legacy-oracle comparison, including ordered per-span output and EPS cuts.
const World = preload("res://game/terrain/terrain_world.gd")
const Fixtures = preload("res://game/terrain/terrain_fixtures.gd")
const Map = preload("res://game/battlefield/farmland_scenario.gd")
var checks := 0
var failures := 0

class LegacyWorld extends World:
	# Pre-sweep aggregation retained only as an independent test oracle.
	func _route_parts(entity: Dictionary, start: Vector2, destination: Vector2, distance: float, intervals: Array[Dictionary], cuts: Array[float]) -> Dictionary:
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
			var speed_cap := INF
			for interval in intervals:
				if middle < interval.from or middle > interval.to: continue
				factor = minf(factor, interval.rule.factor)
				burn = maxf(burn, interval.rule.fuel)
				max_slope = maxf(max_slope, interval.rule.slope)
				speed_cap = minf(speed_cap,float(interval.rule.get("speed_cap",INF)))
				if interval.rule.surface not in surfaces: surfaces.append(interval.rule.surface)
			var length := (end - begin) * distance
			var speed: float = minf(entity.base * factor,speed_cap)
			var used: float = length * entity.rate * burn / 1000.0
			parts.append({"from": start.lerp(destination, begin), "to": start.lerp(destination, end), "distance": length, "speed": speed, "seconds": length / speed, "fuel": used, "surfaces": surfaces, "slope": max_slope})
			seconds += length / speed
			fuel += used
		return {"ok": true, "reason": "Whole straight lane supported", "parts": parts, "seconds": seconds, "distance": distance, "fuel": fuel, "revision": revision}

class CountedFoldWorld extends World:
	var scalar_checks := 0
	func _scalar_route_rule(rule: Dictionary) -> bool:
		scalar_checks += 1
		return super._scalar_route_rule(rule)

func _initialize() -> void:
	for spec in Fixtures.movement_cases():
		var lane: RefCounted = Fixtures.lane(spec)
		_compare_route(lane.world,lane.entity,lane.destination,spec.name)
	_generated_intervals()
	_repeated_rules()
	_homogeneous_cases()
	_folded_scalars()
	_generated_lanes()
	_long_lanes()
	print("Route sweep regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: "+label)

func _legacy(world: RefCounted) -> RefCounted:
	var legacy := LegacyWorld.new()
	for key in ["bounds","cells","base_regions","scenario","obstacles","field_effects","bridge_approaches","revision"]:
		legacy.set(key,world.get(key))
	return legacy

func _compare_route(world: RefCounted, body: Dictionary, destination: Vector2, label: String, timed: bool = false) -> void:
	var legacy := _legacy(world)
	var started := Time.get_ticks_usec()
	var expected: Dictionary = legacy.route(body,destination)
	var legacy_us := Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	var actual: Dictionary = world.route(body,destination)
	var sweep_us := Time.get_ticks_usec()-started
	_expect(actual == expected,label+": exact validity/reason and every ordered part/total")
	if timed:
		_expect(actual.ok,label+": long lane is supported")
		print("BENCH ",label," legacy_us=",legacy_us," sweep_us=",sweep_us," parts=",actual.get("parts",[]).size()," seconds=",actual.get("seconds",0)," fuel=",actual.get("fuel",0))

func _body(start: Vector2, finish: Vector2, movement_class: int = 1) -> Dictionary:
	return {"position":start,"facing":(finish-start).angle(),"size":Vector2(6.0,2.5),"movement_class":movement_class,"base":8.0,"rate":3.0,"gross_mass_kg":7000.0}

func _generated_lanes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8302026
	for trial in 24:
		var world := World.new()
		world.bounds = Rect2i(0,0,90,90)
		for index in 30:
			world.paint(Rect2i(rng.randi_range(12,70),rng.randi_range(12,70),5,5),["TR01","TR02","TR03","TR05","TR07","TR08","TR09"][rng.randi_range(0,6)])
		world.field_effects = [{"id":"sandbag","code":"S02","area":Rect2(30,0,10,90)},{"id":"wire","code":"S04","area":Rect2(40,0,12,90)}]
		world.paint(Rect2i(53,0,4,90),"TR11",{"overlay":{"kind":"crossing","code":"test","complete":true,"classes":[0,1,2],"width":8.0,"load_kg":9000.0,"speed_cap":1.7}})
		world.bridge_approaches[Vector2i(52,45)] = {"test":1.2}
		var start := Vector2(8,rng.randf_range(10,75))
		var finish := Vector2(80,rng.randf_range(10,75))
		_compare_route(world,_body(start,finish,trial%3),finish,"Generated rotated footprint %d" % trial)
		if trial%4 == 0:
			world.paint(Rect2i(40,0,2,90),"TR01",{"height":1.0})
			_compare_route(world,_body(start,finish),finish,"Height rejection %d" % trial)

func _generated_intervals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7326
	var world := World.new()
	var legacy := LegacyWorld.new()
	var body := _body(Vector2.ZERO,Vector2(100,0))
	for trial in 40:
		var intervals: Array[Dictionary] = [{"from":0.0,"to":1.0,"rule":{"factor":1.0,"fuel":1.0,"slope":0.0,"surface":"TR01"}}]
		var cuts: Array[float] = [0.0,1.0]
		for index in 80:
			# Coincident, nested, unordered and sub-EPS boundaries exercise cursor
			# advancement even when adjacent cut spans are omitted.
			var begin := float(rng.randi_range(0,90))/100.0
			var end := minf(1.0,begin+[0.00000001,0.0000001,0.001,0.1,0.5][index%5])
			intervals.append({"from":begin,"to":end,"rule":{"factor":rng.randf_range(0.1,1.5),"fuel":rng.randf_range(1,4),"slope":rng.randf_range(0,25),"speed_cap":[INF,2.0,5.0][index%3],"surface":"TR%02d" % (index%8+1)}})
			cuts.append(begin)
			cuts.append(end)
		var actual: Dictionary = world._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
		var expected: Dictionary = legacy._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
		_expect(actual == expected,"Generated interval aggregation %d preserves exact ordered output" % trial)

func _repeated_rules() -> void:
	var world := World.new()
	var legacy := LegacyWorld.new()
	var body := _body(Vector2.ZERO,Vector2(100,0))
	# Repeated references, equal-but-distinct references and A/B/A must all
	# preserve the legacy operation order, including exceptional operands.
	for value in [1.0,-0.0,0.0,INF,-INF,NAN]:
		var a := {"factor":1.0,"fuel":value,"slope":value,"speed_cap":INF,"surface":"TR01"}
		var b := {"factor":0.7,"fuel":2.0,"slope":3.0,"speed_cap":2.0,"surface":"TR02"}
		var equal_a: Dictionary = a.duplicate()
		for sequence in [[a,a,a],[a,a,b,a,a],[a,equal_a,a],[b,a,a,b,a]]:
			var intervals: Array[Dictionary] = []
			var cuts: Array[float] = [0.0,1.0,0.5,0.50000001]
			for index in sequence.size():
				var begin := 0.0 if index%2 == 0 else 0.2
				var end := 1.0 if index%3 == 0 else 0.8
				intervals.append({"from":begin,"to":end,"rule":sequence[index]})
				cuts.append(begin)
				cuts.append(end)
			var actual: Dictionary = world._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
			var expected: Dictionary = legacy._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
			# Byte comparison includes signed zero and accepts matching NaNs.
			_expect(var_to_bytes(actual) == var_to_bytes(expected),"Consecutive/shared/intervening rules preserve serialized legacy result for %s" % value)
	# Put exceptional values in each min/max input, not just fuel and slope.
	for key in ["factor","fuel","slope","speed_cap"]:
		for value in [-0.0,0.0,INF,-INF,NAN]:
			var a := {"factor":1.0,"fuel":1.0,"slope":0.0,"speed_cap":INF,"surface":"TR01"}
			a[key] = value
			var b := {"factor":0.7,"fuel":2.0,"slope":3.0,"speed_cap":2.0,"surface":"TR02"}
			var intervals: Array[Dictionary] = []
			for rule in [a,a,b,a,a]: intervals.append({"from":0.0,"to":1.0,"rule":rule})
			var cuts: Array[float] = [0.0,1.0]
			var actual: Dictionary = world._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
			var expected: Dictionary = legacy._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
			_expect(var_to_bytes(actual) == var_to_bytes(expected),"Exceptional %s=%s preserves legacy result" % [key,value])

func _homogeneous_cases() -> void:
	var rule := {"factor":0.6,"fuel":1.3,"slope":-0.0,"speed_cap":3.0,"surface":"TR03"}
	for spans in [[Vector2(0.2,0.4),Vector2(0.6,0.8)],[Vector2(0.4,0.8),Vector2(0,0.4),Vector2(0.3,0.7)],[Vector2(0,1),Vector2(0.2,0.3),Vector2(0.7,0.8)],[Vector2(0.5,0.5000001),Vector2(0.8,0.9)]]:
		var intervals: Array[Dictionary] = []
		var cuts: Array[float] = [0.0,1.0,0.25,0.5,0.5,0.50000001,0.75]
		for span in spans:
			intervals.append({"from":span.x,"to":span.y,"rule":rule})
			cuts.append(span.x)
			cuts.append(span.y)
		_interval_case(intervals,cuts,"Homogeneous gaps/overlap/nesting/touching/sub-EPS",true)
	var touching: Array[Dictionary] = [{"from":0.0,"to":0.5,"rule":rule},{"from":0.5,"to":1.0,"rule":rule}]
	_interval_case(touching,[0.0,1.0],"Midpoint exactly at two inclusive endpoints",true)
	_interval_case([], [0.0,0.5,1.0],"Empty interval list retains empty spans",false)
	var distinct: Array[Dictionary] = [{"from":0.0,"to":0.5,"rule":rule},{"from":0.5,"to":1.0,"rule":rule.duplicate()}]
	_interval_case(distinct,[0.0,0.5,1.0],"Equal-valued distinct rule references use ordinary sweep",false)
	for bounds in [Vector2(0.5,0.5),Vector2(0.8,0.2),Vector2(-INF,1.0),Vector2(0.0,INF)]:
		var intervals: Array[Dictionary] = [{"from":0.0,"to":1.0,"rule":rule},{"from":bounds.x,"to":bounds.y,"rule":rule}]
		_interval_case(intervals,[0.0,0.25,0.5,0.75,1.0],"Degenerate/inverted/infinite bounds retain ordinary sweep",false)
	var integer_bounds: Array[Dictionary] = [{"from":0,"to":1,"rule":rule}]
	_interval_case(integer_bounds,[0.0,1.0],"Non-float bounds conservatively retain ordinary sweep",false)
	var world := World.new()
	for bounds in [Vector2(NAN,1.0),Vector2(0.0,NAN)]:
		var intervals: Array[Dictionary] = [{"from":bounds.x,"to":bounds.y,"rule":rule}]
		_expect(not world._homogeneous_intervals(intervals,[0.0,1.0]),"NaN bounds cannot select homogeneous shortcut")
	for bad_cut in [NAN,INF,-INF]:
		_expect(not world._homogeneous_intervals(touching,[0.0,bad_cut,1.0]),"Nonfinite cuts cannot select homogeneous shortcut")
	# Every common-rule operand still enters the original min/max body once
	# per occupied span. Empty gaps keep its untouched empty accumulators.
	for key in ["factor","fuel","slope","speed_cap"]:
		for value in [-0.0,0.0,INF,-INF,NAN]:
			var exceptional: Dictionary = rule.duplicate()
			exceptional[key] = value
			var intervals: Array[Dictionary] = [{"from":0.0,"to":0.4,"rule":exceptional},{"from":0.6,"to":1.0,"rule":exceptional}]
			_interval_case(intervals,[0.0,0.2,0.4,0.5,0.6,0.8,1.0],"Shared exceptional %s=%s with empty gaps" % [key,value],true)

func _interval_case(intervals: Array[Dictionary], cuts: Array[float], label: String, homogeneous: bool) -> void:
	var world := World.new()
	var legacy := LegacyWorld.new()
	var body := _body(Vector2.ZERO,Vector2(100,0))
	_expect(world._homogeneous_intervals(intervals,cuts) == homogeneous,label+": guarded path selection")
	var actual: Dictionary = world._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
	var expected: Dictionary = legacy._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
	_expect(var_to_bytes(actual) == var_to_bytes(expected),label+": exact legacy bytes for every part/total")

func _folded_scalars() -> void:
	var world := CountedFoldWorld.new()
	var legacy := LegacyWorld.new()
	var body := _body(Vector2.ZERO,Vector2(100,0))
	var rule := {"factor":0.8,"fuel":1.2,"slope":-0.0,"surface":"TR01"}
	var intervals: Array[Dictionary] = [{"from":0.1,"to":0.4,"rule":rule},{"from":0.6,"to":0.9,"rule":rule}]
	var cuts: Array[float] = [0.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.9,1.0]
	var expected: Dictionary = legacy._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
	var actual: Dictionary = world._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
	_expect(var_to_bytes(actual) == var_to_bytes(expected),"Lazy shared fold preserves every occupied part and surrounding empty gaps")
	_expect(world.scalar_checks == 1,"Primitive rule shape checked once only after first occupied retained span")
	actual.parts[1].surfaces.append("detached mutation")
	_expect(actual.parts[2].surfaces == ["TR01"] and actual.parts[0].surfaces.is_empty(),"Every occupied and empty part owns an independent surfaces array")
	rule.factor = 0.3
	rule.fuel = 2.5
	rule.slope = 14.0
	rule.surface = "TR05"
	rule.speed_cap = 1.1
	expected = legacy._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
	actual = world._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,intervals,cuts.duplicate())
	_expect(var_to_bytes(actual) == var_to_bytes(expected) and world.scalar_checks == 2,"Same world/query arguments recompute changed rule and fresh surfaces on next invocation")
	for fallback in [{"factor":1,"fuel":1,"slope":0,"surface":"TR01"},{"factor":0.8,"fuel":1.2,"slope":0.0,"surface":"TR01","speed_cap":2}]:
		_expect(not world._scalar_route_rule(fallback),"Lenient numeric integer fields retain the original fold")
		var fallback_intervals: Array[Dictionary] = [{"from":0.1,"to":0.4,"rule":fallback},{"from":0.6,"to":0.9,"rule":fallback}]
		_interval_case(fallback_intervals,cuts,"Integer-valued rule uses unchanged fold across gaps",true)
	for malformed in [{},{"factor":0.5},{"factor":"invalid","fuel":1.0,"slope":0.0,"surface":"TR01"},{"factor":1.0,"fuel":1.0,"slope":0.0,"surface":42},{"factor":1.0,"fuel":1.0,"slope":0.0,"surface":"TR01","speed_cap":null}]:
		_expect(not world._scalar_route_rule(malformed),"Unknown/missing/nonprimitive rule fields decline scalar reuse")
		var untouched := CountedFoldWorld.new()
		var outside: Array[Dictionary] = [{"from":2.0,"to":3.0,"rule":malformed}]
		expected = legacy._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,outside,[0.0,1.0])
		actual = untouched._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,outside,[0.0,1.0])
		_expect(var_to_bytes(actual) == var_to_bytes(expected) and untouched.scalar_checks == 0,"No occupied span never inspects malformed rule fields")
		var covered: Array[Dictionary] = [{"from":0.0,"to":1.0,"rule":malformed}]
		expected = legacy._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,covered,[0.0,World.EPS*0.5])
		actual = untouched._route_parts(body,Vector2.ZERO,Vector2(100,0),100.0,covered,[0.0,World.EPS*0.5])
		_expect(var_to_bytes(actual) == var_to_bytes(expected) and untouched.scalar_checks == 0,"Only sub-EPS cuts never inspect malformed rule fields")

func _long_lanes() -> void:
	var world := World.new()
	Map.apply(world)
	for endpoints in [[Vector2(3000,650),Vector2(3000,2300)],[Vector2(3000,2300),Vector2(3000,650)],[Vector2(2200,2850),Vector2(2380,2980)],[Vector2(1900,1450),Vector2(2250,2100)]]:
		var start: Vector2 = endpoints[0]
		var finish: Vector2 = endpoints[1]
		_compare_route(world,_body(start,finish),finish,"Authored Farmland %s -> %s" % [start,finish],true)
