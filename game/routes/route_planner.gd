extends RefCounted
## G13 measured route and load contract for the same ledger-owned hull.
const Terrain = preload("res://game/terrain/terrain_catalog.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const TerrainWorld = preload("res://game/terrain/terrain_world.gd")
const EPS := 0.000001
const BRIDGES := {
	"B01":{"width":2.0,"span":20.0,"load":1000.0},
	"B02":{"width":6.0,"span":30.0,"load":10000.0},
	"B03":{"width":8.0,"span":60.0,"load":80000.0},
}
const RADII := {"T01":10.0,"T02":9.0,"T03":7.0,"T04":8.0,"T05":0.0}

static func gross_kg(ledger: RefCounted, hull_id: String) -> float:
	var hull: Dictionary = ledger.inspect_entity(hull_id)
	if hull.is_empty() or hull.kind != "CARRIER": return -1.0
	# Contents include each actual child and its nested gear/ammunition exactly once.
	return float(hull.unit_mass_kg) + float(hull.fuel) + float(hull.contents_mass_kg)

static func plan(ledger: RefCounted, hull_id: String, points: Array, profile: Dictionary = {}) -> Dictionary:
	var hull: Dictionary = ledger.inspect_entity(hull_id)
	if hull.is_empty() or hull.kind != "CARRIER" or not Specs.TYPES.has(hull.design_type): return _blocked("Select one actual vehicle hull.")
	if points.size() < 2: return _blocked("Route needs distinct actual endpoints.")
	var type: String = hull.design_type
	var movement_class: int = int(Terrain.VEHICLES[type].class)
	var world: TerrainWorld = profile.get("world") as TerrainWorld
	var surface: String = str(profile.get("surface","TR02"))
	if not Terrain.SURFACES.has(surface): return _blocked("Unknown terrain surface " + surface)
	if surface == "TR10" and world == null: return _blocked("A ford needs authored marked, firm, banked, depth-checked physical terrain.")
	if hull.health <= 0.25*float(hull.vehicle_spec.health): return _blocked("Damage Immobilized hull cannot start a route.")
	var slope: float = float(profile.get("slope",0.0))
	var slope_factor: float = Terrain.slope_factor(slope,movement_class)
	var factor: float = float(Terrain.SURFACES[surface].speed[movement_class]) * slope_factor
	if factor <= EPS: return _blocked("Impassable %s or forbidden %.1f-degree slope for %s." % [surface,slope,type])
	if profile.get("known_mine",false): return _blocked("Known armed mine excludes this ordinary supply route.")
	if profile.get("observed_hostile",false): return _blocked("Observed hostile effective fire blocks this ordinary route; explicit protected convoy required.")
	var width: float = float(profile.get("corridor_width",8.0))
	if float(hull.vehicle_spec.footprint.y) > width + EPS: return _blocked("Whole hull footprint is wider than the declared route clearance.")
	var bridge: String = str(profile.get("bridge",""))
	var gross: float = gross_kg(ledger,hull_id)
	if not bridge.is_empty():
		if not BRIDGES.has(bridge): return _blocked("Unknown crossing class " + bridge)
		if float(hull.vehicle_spec.footprint.y) > float(BRIDGES[bridge].width) + EPS: return _blocked("Hull footprint exceeds %s bridge width." % bridge)
		if gross > float(BRIDGES[bridge].load) + EPS: return _blocked("%s gross %.1f kg exceeds %.0f kg bridge limit." % [bridge,gross,BRIDGES[bridge].load])
		if float(profile.get("bridge_span_m",20.0)) > float(BRIDGES[bridge].span) + EPS: return _blocked("%s bridge span exceeds its supported maximum." % bridge)
	var sections: Array[Dictionary] = []
	var total_distance := 0.0
	var total_seconds := 0.0
	var total_fuel := 0.0
	var base: float = float(Terrain.VEHICLES[type].base)
	var rate: float = float(Terrain.VEHICLES[type].rate)
	var damage_factor := 0.75 if hull.health <= 0.5*float(hull.vehicle_spec.health) else 1.0
	var speed: float = base*factor*damage_factor
	var fuel_factor: float = float(Terrain.SURFACES[surface].fuel)
	var strict_turns: bool = bool(profile.get("strict_turns",true))
	var whole_length := 0.0
	for index in range(1,points.size()): whole_length += (points[index-1] as Vector2).distance_to(points[index])
	var bridge_middle: float = float(profile.get("bridge_at_m",whole_length/2.0))
	var bridge_half: float = float(profile.get("bridge_span_m",20.0))/2.0
	var slow_start: float = bridge_middle-bridge_half-20.0
	var slow_end: float = bridge_middle+bridge_half+20.0
	if not bridge.is_empty() and (slow_start < -EPS or slow_end > whole_length+EPS) and not profile.get("allow_partial_bridge",false): return _blocked("Bridge needs real 20 m holding approaches on both banks.")
	if profile.get("allow_partial_bridge",false):
		slow_start = maxf(0.0,slow_start)
		slow_end = minf(whole_length,slow_end)
	for index in range(1,points.size()):
		var start: Vector2 = points[index-1]
		var finish: Vector2 = points[index]
		if not start.is_finite() or not finish.is_finite(): return _blocked("Route endpoint is not a finite physical position.")
		var length: float = start.distance_to(finish)
		if length <= EPS: continue
		if strict_turns and index > 1 and RADII[type] > 0.0 and (points[index-2] as Vector2).distance_to(start) > EPS:
			var previous: Vector2 = points[index-2]
			var incoming: Vector2 = (start-previous).normalized()
			var outgoing: Vector2 = (finish-start).normalized()
			var angle: float = acos(clampf(incoming.dot(outgoing),-1.0,1.0))
			if angle > 0.001 and RADII[type]*tan(angle/2.0)*2.0 > minf(previous.distance_to(start),length) + EPS:
				return _blocked("%s cannot make this turn within its %.0f m rolling radius." % [type,RADII[type]])
		if world != null:
			if not bridge.is_empty(): return _blocked("Specified bridge fixture and authored terrain world cannot describe one crossing at once.")
			var lane: Dictionary = world.route({"position":start,"facing":(finish-start).angle(),"size":hull.vehicle_spec.footprint,"movement_class":movement_class,"base":base*damage_factor,"rate":rate},finish)
			if not lane.ok: return _blocked(lane.reason)
			for part in lane.parts:
				sections.append(part)
				total_seconds += float(part.seconds)
				total_fuel += float(part.fuel)
			total_distance += length
			continue
		var cuts: Array[float] = [0.0,length]
		if not bridge.is_empty():
			for edge in [slow_start,slow_end]:
				var local_edge: float = edge-total_distance
				if local_edge > EPS and local_edge < length-EPS: cuts.append(local_edge)
		cuts.sort()
		for part_index in range(1,cuts.size()):
			var a: float = cuts[part_index-1]
			var b: float = cuts[part_index]
			var part_length: float = b-a
			var mid_global: float = total_distance+(a+b)/2.0
			var part_speed: float = minf(speed,4.0) if not bridge.is_empty() and mid_global >= slow_start-EPS and mid_global <= slow_end+EPS else speed
			var seconds: float = part_length/part_speed
			var fuel: float = part_length/1000.0*rate*fuel_factor
			sections.append({"from":start.lerp(finish,a/length),"to":start.lerp(finish,b/length),"distance":part_length,"speed":part_speed,"seconds":seconds,"fuel":fuel,"surface":surface,"slope":slope,"bridge_approach":part_speed <= 4.0 and not bridge.is_empty()})
			total_seconds += seconds
			total_fuel += fuel
		total_distance += length
	if sections.is_empty(): return _blocked("Route has no physical distance.")
	return {"ok":true,"reason":"Measured actual route","parts":sections,"distance":total_distance,"seconds":total_seconds,"fuel":total_fuel,"gross_kg":gross,"bridge":bridge,"surface":surface,"corridor_width":width}

static func _blocked(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}
