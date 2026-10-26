extends RefCounted
## Named explicit fixtures. Rectangle extents, physical heights and profiles are inspectable.

const Catalog = preload("res://game/terrain/terrain_catalog.gd")
const World = preload("res://game/terrain/terrain_world.gd")
const Lane = preload("res://game/terrain/lane_simulation.gd")


static func movement_cases() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	for surface in Catalog.SURFACES:
		for type in ["person", "T01", "T02", "T03", "T04", "T05"]:
			cases.append({"name": "%s %s / %s" % [surface, Catalog.SURFACES[surface].name, type], "surface": surface, "type": type})
	for slope in [10.0, 10.001, 15.0, 15.001, 25.0, 25.001, 40.0, 40.001]:
		for type in ["person", "T02", "T05"]:
			cases.append({"name": "Slope %.3f degrees / %s" % [slope, type], "surface": "TR01", "type": type, "slope": slope})
	for values in [["person", 0.6], ["person", 0.601], ["T02", 0.35], ["T02", 0.351], ["T05", 0.8], ["T05", 0.801]]:
		cases.append({"name": "Ford %.3fm / %s" % [values[1], values[0]], "surface": "TR10", "type": values[0], "depth": values[1]})
	for variant in ["Foot-only ford", "Soft ford bottom", "Inaccessible ford bank", "Unmarked ford", "Deep bog", "Track clear forest gap", "Track trunk contact", "Wheel boulder contact", "Narrow town alley", "Completed crossing", "Unbuilt crossing", "Narrow crossing", "Adjacent cliff", "Road cannot erase slope", "Completed causeway", "Unbuilt causeway"]:
		cases.append({"name": variant, "variant": variant, "surface": "TR01", "type": "T05" if variant.begins_with("Track") else "T02"})
	return cases


static func lane(spec: Dictionary) -> RefCounted:
	var simulation := Lane.new()
	var world: RefCounted = simulation.world
	world.bounds = Rect2i(0, 0, 100, 24)
	var properties := {"marked": true, "firm": true, "banks": true, "classes": [0, 1, 2], "depth": spec.get("depth", 0.3), "vegetation_height": 12.0, "canopy": true}
	properties.gradient = Vector2(tan(deg_to_rad(float(spec.get("slope", 0.0)))), 0)
	world.paint(world.bounds, spec.surface, properties)
	simulation.initialize(spec.type)
	var variant: String = spec.get("variant", "")
	match variant:
		"Foot-only ford", "Soft ford bottom", "Inaccessible ford bank", "Unmarked ford":
			properties.classes = [0] if variant == "Foot-only ford" else [0, 1, 2]
			properties.firm = variant != "Soft ford bottom"
			properties.banks = variant != "Inaccessible ford bank"
			properties.marked = variant != "Unmarked ford"
			world.paint(world.bounds, "TR10", properties)
		"Deep bog": world.paint(world.bounds, "TR09", {"deep_bog": true})
		"Track clear forest gap", "Track trunk contact":
			world.paint(world.bounds, "TR06", properties)
			var y := 14.0 if variant == "Track clear forest gap" else 13.5
			world.obstacle("actual-tree-trunk", Rect2(35.1, y, 0.2, 1.0), 0, 12)
		"Wheel boulder contact": world.obstacle("boulder", Rect2(35.1, 13.1, 0.1, 0.2), 0, 2.2)
		"Narrow town alley":
			world.paint(world.bounds, "TR08")
			world.obstacle("north-building", Rect2(25, 0, 20, 10.8), 0, 8)
			world.obstacle("south-building", Rect2(25, 13.2, 20, 10.8), 0, 8)
		"Completed crossing", "Unbuilt crossing", "Narrow crossing", "Adjacent cliff", "Road cannot erase slope":
			world.paint(Rect2i(30, 0, 20, 24), "TR11")
			var overlay := {"kind": "crossing", "complete": variant != "Unbuilt crossing", "classes": [0, 1, 2], "height": 0.0}
			world.paint(Rect2i(30, 9 if variant == "Narrow crossing" else 8, 20, 2 if variant == "Narrow crossing" else 8), "TR11", {"overlay": overlay})
			if variant == "Adjacent cliff": world.paint(Rect2i(40, 13, 1, 1), "TR12")
			if variant == "Road cannot erase slope": world.paint(Rect2i(40, 11, 1, 1), "TR01", {"overlay": overlay, "gradient": Vector2(tan(deg_to_rad(26.0)), 0)})
		"Completed causeway", "Unbuilt causeway":
			world.paint(Rect2i(30, 0, 20, 24), "TR09")
			world.paint(Rect2i(30, 9, 20, 6), "TR09", {"overlay": {"kind": "causeway", "complete": variant == "Completed causeway", "classes": [0, 1]}})
	return simulation


static func sight_cases() -> Array[String]:
	return ["Ordinary at 220m", "Ordinary beyond 220m", "Mixed foliage just below budget", "Mixed foliage reaches 100", "Ridge blocks ground eye", "Drone sees beyond ridge; ground muzzle blocked", "Low crops block ground", "Drone ignores low crops", "Drone target under dense canopy", "Opaque tree trunk", "Opaque building", "Opaque smoke / ground", "Opaque smoke / drone", "Eye clears low ridge; rifle muzzle blocked", "Elevated target", "Directional rock front", "Directional rock rear", "Strongest forest and sandbag", "Bunker physical shield", "Exposed crossing deck", "Vehicle has no forest bonus"]


static func sight(name: String) -> Dictionary:
	var world := World.new()
	var observer := Vector2(10, 20)
	var target := Vector2(210, 20)
	var role := "ordinary"
	var muzzle := 1.5
	var cover_class := 0
	match name:
		"Ordinary at 220m": target.x = 230
		"Ordinary beyond 220m": target.x = 230.001
		"Mixed foliage just below budget", "Mixed foliage reaches 100":
			# 20m dense =60; 39/40m light =39/40. Distinct patches add.
			world.paint(Rect2i(30, 19, 20, 2), "TR06", {"vegetation_height": 18.0, "canopy": true})
			world.paint(Rect2i(70, 19, 39 if name.contains("below") else 40, 2), "TR05", {"vegetation_height": 12.0})
		"Ridge blocks ground eye", "Drone sees beyond ridge; ground muzzle blocked":
			world.paint(Rect2i(100, 19, 2, 2), "TR01", {"height": 8.0})
			if name.begins_with("Drone"): role = "drone"
		"Low crops block ground", "Drone ignores low crops":
			target.x = 230
			world.paint(Rect2i(15, 19, 200, 2), "TR04", {"vegetation_height": 2.5})
			if name.begins_with("Drone"): role = "drone"
		"Drone target under dense canopy":
			role = "drone"
			world.paint(Rect2i(205, 18, 10, 4), "TR06", {"vegetation_height": 18.0, "canopy": true})
		"Opaque tree trunk": world.obstacle("tree-trunk", Rect2(110, 19.8, 0.3, 0.4), 0, 12)
		"Opaque building": world.obstacle("building", Rect2(110, 17, 8, 6), 0, 8)
		"Opaque smoke / ground", "Opaque smoke / drone":
			world.obstacle("declared-static-smoke", Rect2(190, 0, 40, 40), 0, 60, false)
			if name.ends_with("drone"): role = "drone"
		"Eye clears low ridge; rifle muzzle blocked":
			target.x = 110
			world.paint(Rect2i(20, 19, 1, 2), "TR01", {"height": 1.65})
		"Elevated target": world.paint(Rect2i(210, 19, 2, 2), "TR01", {"height": 15.0})
		"Directional rock front", "Directional rock rear":
			target = Vector2(30, 20)
			observer = Vector2(10 if name.ends_with("front") else 50, 20)
			world.paint(Rect2i(29, 19, 2, 2), "TR07")
			world.shields.append({"id": "rock-shield", "kind": "rock", "area": Rect2(29, 19, 2, 2), "rect": Rect2(28, 19, 0.5, 2), "bottom": 0.0, "top": 2.0})
		"Strongest forest and sandbag", "Bunker physical shield":
			target = Vector2(30, 20)
			world.paint(Rect2i(29, 19, 2, 2), "TR06", {"vegetation_height": 18.0})
			world.shields.append({"id": "declared-shield", "kind": "S03" if name.begins_with("Bunker") else "S02", "area": Rect2(29, 19, 2, 2), "rect": Rect2(28, 19, 0.5, 2), "bottom": 0.0, "top": 2.0})
		"Exposed crossing deck": world.paint(Rect2i(209, 19, 3, 2), "TR06", {"overlay": {"complete": true, "kind": "crossing", "classes": [0, 1, 2]}})
		"Vehicle has no forest bonus":
			world.paint(Rect2i(209, 19, 3, 2), "TR06", {"vegetation_height": 18.0})
			cover_class = 2
	return {"world": world, "observer": observer, "target": target, "role": role, "muzzle": muzzle, "weapon_range": 220.0, "cover_class": cover_class}
