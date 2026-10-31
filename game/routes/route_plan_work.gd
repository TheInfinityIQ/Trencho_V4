extends RefCounted
## Request-local pure route calculation. The caller owns admission and freshness.
## A unit is one policy stage, waypoint/leg, returned part, or child work unit.
## Snapshot/copy and the legacy hazard callable remain synchronous (see _admit).
const Terrain = preload("res://game/terrain/terrain_catalog.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const TerrainWorld = preload("res://game/terrain/terrain_world.gd")
const EPS := 0.000001
enum Phase { ADMIT, LENGTH, APPROACH, LEG, CHILD, PARTS, FINISH }

var done := false
var invalidated := false
var result: Dictionary = {}
# Detached capture for the owning command to revalidate at commit. Callable
# identity does not freeze hazard knowledge; that policy must be checked fresh.
var input_facts: Dictionary = {}
var last_step_units := 0
var _hull_id: String
var _hull: Dictionary
var _tow: Dictionary
var _points: Array
var _profile: Dictionary
var _hazard: Callable
var _world: RefCounted
var _world_revision := -1
var _bridges: Dictionary
var _radii: Dictionary
var _phase: int = Phase.ADMIT
var _type := ""
var _movement_class := 0
var _surface := ""
var _towing := ""
var _slope := 0.0
var _width := 0.0
var _bridge := ""
var _gross := 0.0
var _base := 0.0
var _rate := 0.0
var _damage_factor := 1.0
var _speed := 0.0
var _fuel_factor := 0.0
var _strict_turns := true
var _whole_length := 0.0
var _slow_start := 0.0
var _slow_end := 0.0
var _index := 1
var _sections: Array[Dictionary] = []
var _total_distance := 0.0
var _total_seconds := 0.0
var _total_fuel := 0.0
var _child: RefCounted
var _lane: Dictionary = {}
var _part_index := 0
var _leg_start := Vector2.ZERO
var _leg_finish := Vector2.ZERO
var _leg_length := 0.0
var _cuts: Array[float] = []

func _init(ledger: RefCounted, hull_id: String, points: Array, profile: Dictionary,
		bridges: Dictionary, radii: Dictionary) -> void:
	# Capture hull/load/crew at one settled boundary. Later policy only consults
	# the legacy hazard callable; terrain is read under the revision guard.
	_hull_id = hull_id
	_hull = ledger.inspect_entity(hull_id)
	_tow = ledger.inspect_entity(str(_hull.get("towing","")))
	_points = points.duplicate()
	_profile = profile.duplicate(true)
	_hazard = ledger.route_hazard
	_world = profile.get("world") as TerrainWorld
	if _world != null: _world_revision = _world.revision
	_bridges = bridges
	_radii = radii
	var crew := {}
	for id in _hull.get("crew",[]):
		var person: Dictionary = ledger.inspect_person_status(id)
		var facts := {}
		for key in ["id","owner","holder_id","position","health","assignment","pending_assignment","crew_station","qualification","basic_training"]:
			facts[key] = person.get(key)
		crew[id] = facts
	var profile_facts: Dictionary = _profile.duplicate(true)
	profile_facts.erase("world")
	input_facts = {"hull_id":hull_id,"hull":_hull.duplicate(true),"tow":_tow.duplicate(true),
		"crew":crew,"points":_points.duplicate(),"profile":profile_facts,
		"world_revision":_world_revision,"route_hazard":_hazard}

func step(max_units: int = 128, budget_usec: int = 4000) -> void:
	last_step_units = 0
	if invalidated: return
	if _world != null and _world.revision != _world_revision:
		_invalidate()
		return
	if done or max_units <= 0 or budget_usec <= 0: return
	var deadline: int = Time.get_ticks_usec()+budget_usec
	while not done and last_step_units < max_units and Time.get_ticks_usec() < deadline:
		if _world != null and _world.revision != _world_revision:
			_invalidate()
			return
		if _phase == Phase.CHILD:
			var remaining: int = max_units-last_step_units
			var remaining_usec: int = deadline-Time.get_ticks_usec()
			if remaining_usec <= 0: return
			_child.step(remaining,remaining_usec)
			# Conservatively charge the entire child allowance, even if it finishes
			# early. Part folding resumes next call; budgets never reset per leg.
			last_step_units += remaining
			if _world.revision != _world_revision or _child.invalidated:
				_invalidate()
			elif _child.done:
				if not _child.result.get("ok",false):
					_block(str(_child.result.get("reason","Terrain route could not be planned.")))
					if _child.result.get("unsupported",false): result.unsupported = true
				else:
					_lane = _child.result
					_part_index = 0
					_phase = Phase.PARTS
			return
		last_step_units += 1
		match _phase:
			Phase.ADMIT: _admit()
			Phase.LENGTH: _measure_waypoint()
			Phase.APPROACH: _approaches()
			Phase.LEG: _begin_leg()
			Phase.PARTS: _fold_part()
			Phase.FINISH: _finish()
		if _world != null and _world.revision != _world_revision:
			_invalidate()
			return

func _admit() -> void:
	if _hull.is_empty() or _hull.kind != "CARRIER" or not Specs.TYPES.has(_hull.design_type): _block("Select one actual vehicle hull."); return
	if _points.size() < 2: _block("Route needs distinct actual endpoints."); return
	_type = _hull.design_type
	_movement_class = int(Terrain.VEHICLES[_type].class)
	_surface = str(_profile.get("surface","TR02"))
	if not Terrain.SURFACES.has(_surface): _block("Unknown terrain surface " + _surface); return
	if _surface == "TR10" and _world == null: _block("A ford needs authored marked, firm, banked, depth-checked physical terrain."); return
	if _hull.get("damage_immobilized",false): _block("Damage Immobilized after a device strike; recovery is required."); return
	# Existing callable has no continuation protocol. MineService scans current
	# known markers x copied waypoints here; no claims or terrain.route call.
	if _hazard.is_valid():
		var hazard: String = _hazard.call(_hull.owner,_points)
		if not hazard.is_empty(): _block(hazard); return
	if _hull.health <= 0.25*float(_hull.vehicle_spec.health): _block("Damage Immobilized hull cannot start a route."); return
	if _hull.get("damage_immobilized",false): _block("Damage Immobilized: distinct mobility repair required."); return
	if not _hull.get("towed_by","").is_empty(): _block("Coupled tow object cannot move independently."); return
	_towing = str(_hull.get("towing",""))
	if not _towing.is_empty() and (_tow.get("health",0) <= 0 or _tow.get("towed_by","") != _hull_id): _block("Actual surviving tow coupling required."); return
	_slope = float(_profile.get("slope",0.0))
	var factor: float = float(Terrain.SURFACES[_surface].speed[_movement_class])*Terrain.slope_factor(_slope,_movement_class)
	if factor <= EPS: _block("Impassable %s or forbidden %.1f-degree slope for %s." % [_surface,_slope,_type]); return
	if _profile.get("known_mine",false): _block("Known armed mine excludes this ordinary supply route."); return
	if _profile.get("observed_hostile",false): _block("Observed hostile effective fire blocks this ordinary route; explicit protected convoy required."); return
	_width = float(_profile.get("corridor_width",8.0))
	if float(_hull.vehicle_spec.footprint.y) > _width+EPS: _block("Whole hull footprint is wider than the declared route clearance."); return
	_bridge = str(_profile.get("bridge",""))
	_gross = float(_hull.unit_mass_kg)+float(_hull.fuel)+float(_hull.contents_mass_kg)
	if not _towing.is_empty():
		_gross += float(_tow.unit_mass_kg)+float(_tow.fuel)+float(_tow.contents_mass_kg) if _tow.kind == "CARRIER" else float(_tow.unit_mass_kg)+float(_tow.contents_mass_kg)
		if _width < 20.0 and bool(_profile.get("turning",false)): _block("Tow combination requires twenty metres turn clearance."); return
	if not _bridge.is_empty():
		if not _bridges.has(_bridge): _block("Unknown crossing class " + _bridge); return
		if float(_hull.vehicle_spec.footprint.y) > float(_bridges[_bridge].width)+EPS: _block("Hull footprint exceeds %s bridge width." % _bridge); return
		if _gross > float(_bridges[_bridge].load)+EPS: _block("%s gross %.1f kg exceeds %.0f kg bridge limit." % [_bridge,_gross,_bridges[_bridge].load]); return
		if float(_profile.get("bridge_span_m",20.0)) > float(_bridges[_bridge].span)+EPS: _block("%s bridge span exceeds its supported maximum." % _bridge); return
	_base = float(Terrain.VEHICLES[_type].base)
	_rate = float(Terrain.VEHICLES[_type].rate)
	_damage_factor = 0.75 if _hull.health <= 0.5*float(_hull.vehicle_spec.health) else 1.0
	if not _towing.is_empty(): _rate *= 2.0
	_speed = _base*factor*_damage_factor
	_fuel_factor = float(Terrain.SURFACES[_surface].fuel)
	_strict_turns = bool(_profile.get("strict_turns",true))
	_phase = Phase.LENGTH

func _measure_waypoint() -> void:
	if _index >= _points.size():
		_phase = Phase.APPROACH
		return
	if typeof(_points[_index-1]) != TYPE_VECTOR2 or typeof(_points[_index]) != TYPE_VECTOR2:
		_block("Resumable route waypoints must be Vector2 physical positions.")
		result.unsupported = true
		return
	_whole_length += (_points[_index-1] as Vector2).distance_to(_points[_index])
	_index += 1

func _approaches() -> void:
	var middle: float = float(_profile.get("bridge_at_m",_whole_length/2.0))
	var half: float = float(_profile.get("bridge_span_m",20.0))/2.0
	_slow_start = middle-half-20.0
	_slow_end = middle+half+20.0
	if not _bridge.is_empty() and (_slow_start < -EPS or _slow_end > _whole_length+EPS) and not _profile.get("allow_partial_bridge",false): _block("Bridge needs real 20 m holding approaches on both banks."); return
	if _profile.get("allow_partial_bridge",false):
		_slow_start = maxf(0.0,_slow_start)
		_slow_end = minf(_whole_length,_slow_end)
	_index = 1
	_phase = Phase.LEG

func _begin_leg() -> void:
	if _index >= _points.size():
		_phase = Phase.FINISH
		return
	_leg_start = _points[_index-1]
	_leg_finish = _points[_index]
	if not _leg_start.is_finite() or not _leg_finish.is_finite(): _block("Route endpoint is not a finite physical position."); return
	_leg_length = _leg_start.distance_to(_leg_finish)
	if _leg_length <= EPS:
		_index += 1
		return
	var radius: float = 20.0 if not _towing.is_empty() else float(_radii[_type])
	if _strict_turns and _index > 1 and radius > 0.0 and (_points[_index-2] as Vector2).distance_to(_leg_start) > EPS:
		var previous: Vector2 = _points[_index-2]
		var incoming: Vector2 = (_leg_start-previous).normalized()
		var outgoing: Vector2 = (_leg_finish-_leg_start).normalized()
		var angle: float = acos(clampf(incoming.dot(outgoing),-1.0,1.0))
		if not _towing.is_empty() and angle > 0.001 and _width < 20.0: _block("Tow turn requires twenty metres clearance."); return
		if angle > 0.001 and radius*tan(angle/2.0)*2.0 > minf(previous.distance_to(_leg_start),_leg_length)+EPS:
			_block("%s cannot make this turn within its %.0f m rolling radius." % [_type,_radii[_type]])
			return
	if _world != null:
		if not _bridge.is_empty(): _block("Specified bridge fixture and authored terrain world cannot describe one crossing at once."); return
		_child = _world.begin_route({"position":_leg_start,"facing":(_leg_finish-_leg_start).angle(),"size":_hull.vehicle_spec.footprint,
			"movement_class":_movement_class,"base":_base*_damage_factor,"rate":_rate,"gross_mass_kg":_gross},_leg_finish)
		_phase = Phase.CHILD
		return
	_cuts = [0.0,_leg_length]
	if not _bridge.is_empty():
		for edge in [_slow_start,_slow_end]:
			var local_edge: float = edge-_total_distance
			if local_edge > EPS and local_edge < _leg_length-EPS: _cuts.append(local_edge)
	_cuts.sort() # At most four scalar boundaries; independent of terrain size.
	_part_index = 1
	_phase = Phase.PARTS

func _fold_part() -> void:
	if _world != null:
		if _part_index >= _lane.parts.size():
			_total_distance += _leg_length
			_lane = {}
			_child = null
			_index += 1
			_phase = Phase.LEG
			return
		var part: Dictionary = _lane.parts[_part_index]
		if not _towing.is_empty():
			part.seconds *= 4.0
			part.speed *= 0.25
		_sections.append(part)
		_total_seconds += float(part.seconds)
		_total_fuel += float(part.fuel)
		_part_index += 1
		return
	if _part_index >= _cuts.size():
		_total_distance += _leg_length
		_index += 1
		_phase = Phase.LEG
		return
	var a: float = _cuts[_part_index-1]
	var b: float = _cuts[_part_index]
	var length: float = b-a
	var middle: float = _total_distance+(a+b)/2.0
	var speed: float = minf(_speed,4.0) if not _bridge.is_empty() and middle >= _slow_start-EPS and middle <= _slow_end+EPS else _speed
	if not _towing.is_empty(): speed *= 0.25
	var seconds: float = length/speed
	var fuel: float = length/1000.0*_rate*_fuel_factor
	_sections.append({"from":_leg_start.lerp(_leg_finish,a/_leg_length),"to":_leg_start.lerp(_leg_finish,b/_leg_length),"distance":length,
		"speed":speed,"seconds":seconds,"fuel":fuel,"surface":_surface,"slope":_slope,"bridge_approach":speed <= 4.0 and not _bridge.is_empty()})
	_total_seconds += seconds
	_total_fuel += fuel
	_part_index += 1

func _finish() -> void:
	if _sections.is_empty(): _block("Route has no physical distance."); return
	result = {"ok":true,"reason":"Measured actual route","parts":_sections,"distance":_total_distance,"seconds":_total_seconds,
		"fuel":_total_fuel,"gross_kg":_gross,"bridge":_bridge,"surface":_surface,"corridor_width":_width}
	done = true

func _block(reason: String) -> void:
	result = {"ok":false,"reason":reason}
	done = true

func _invalidate() -> void:
	invalidated = true
	done = true
	result = {"ok":false,"reason":"World revision changed while planning the route.","invalidated":true}
