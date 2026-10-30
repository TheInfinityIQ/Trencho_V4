extends SceneTree
const World = preload("res://game/terrain/terrain_world.gd")
const Map = preload("res://game/battlefield/farmland_scenario.gd")
const Base = preload("res://game/rear_base/base_simulation.gd")
const Routes = preload("res://game/routes/route_planner.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var world := World.new()
	Map.apply(world)
	expect(world.bounds == Rect2i(0,0,4000,6000) and world.cells.is_empty(),"Full-size metre world with compact base regions")
	var totals := budget(world)
	print("Farmland budgets: ",totals)
	var targets := {"Water":8,"Forest":14,"Rock":8,"Swamp":4,"Town":12,"Farm":34,"Open":20}
	for group in targets: expect(absf(totals.get(group,0.0)-targets[group]) <= 3.0,"Dominant budget: "+group)
	expect(totals.get("Road",0.0) >= 0.5 and totals.get("Road",0.0) <= 2.0,"Road overlay area0.5–2percent")
	expect(Map.OBJECTIVES.size() == 9,"Six Resources two Hubs one Observation")
	for objective in Map.OBJECTIVES:
		expect(world.cell(Vector2i(objective.position)).terrain == "TR01","Dry objective site: "+objective.id)
	for hq in [Map.BLUE_HQ,Map.RED_HQ]:
		for x in range(-300,301,50):
			for y in range(-300,301,50):
				if Vector2(x,y).length() > 300: continue
				var terrain: String = world.cell(Vector2i(hq)+Vector2i(x,y)).terrain
				expect(terrain in ["TR01","TR02"],"Dry300m HQ safe-start")
	for key in ["blue-service-route","red-service-route","blue-front-route","red-front-route","blue-delivery-route","red-delivery-route"]: check_path(world,Map.waypoints()[key])
	for x in [1000,3000]: check_path(world,[Vector2(x,650),Vector2(x,5350)])
	var tank := {"position":Vector2(1000,2700),"facing":PI/2.0,"size":Vector2(8.5,3.5),"movement_class":2,"base":6.0,"rate":6.0,"gross_mass_kg":35000.0}
	var driven: Dictionary = world.route(tank,Vector2(1000,2720))
	expect(driven.ok and is_equal_approx(driven.seconds,20.0/9.0) and is_equal_approx(driven.fuel,0.12),"Real road route applies actual tank speed and fuel")
	expect(not world.support(Vector2i(200,1000),1).ok and not world.support(Vector2i(3100,1000),1).ok,"Actual pond and dense forest exclude wheeled travel")
	var sight: Dictionary = world.probe(Vector2(1440,2370),Vector2(1480,2370),1.7,1.7,220)
	expect(not sight.clear,"Town shell blocks actual observation")
	world.paint(Rect2i(2000,2300,1,1),"TR13")
	expect(world.cell(Vector2i(2000,2300)).terrain == "TR13","Runtime terrain mutation overrides authored base")
	check_initial_defences()
	print("Farmland regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func check_initial_defences() -> void:
	var base := Base.new()
	var rear: RefCounted = base.rear
	Map.apply(rear.combat.world)
	rear.ledger.add_stock("declared-hq-m11","M11",600,1.0,"hq-stock",rear.PLAYER)
	var people: int = rear.ledger.snapshot().entities.filter(func(p: Dictionary) -> bool: return p.kind == "PERSON").size()
	var result: Dictionary = Map.initialize_defences(rear)
	expect(result.ok and rear.field_structures.projects.size() == 6,"Both HQs receive one trench and two sandbags")
	for row in rear.field_structures.projects.values():
		expect(row.state == "Complete" and row.health == row.max_health and row.occupants.is_empty() and row.initial_supply,"Actual completed empty starting defence")
	expect(rear.ledger.available_stock_at("hq-stock","M11") == 600 and rear.ledger.snapshot().entities.filter(func(p: Dictionary) -> bool: return p.kind == "PERSON").size() == people,"Initial defences deduct no loose HQ stock and invent no people")
	expect(not Map.initialize_defences(rear).ok and rear.field_structures.projects.size() == 6,"Repeated initialisation cannot duplicate physical defences")
	expect(base.audit().is_empty(),"Initial defence owners reconcile with the live services")
	rear.ledger.add_initial_vehicle("route-validation-t01","T01","vehicle-lane",rear.PLAYER,Specs.TYPES.T01,40)
	for side in ["blue","red"]:
		for suffix in ["-delivery-route","-delivery-return"]:
			var route: Dictionary = Routes.plan(rear.ledger,"route-validation-t01",Map.waypoints()[side+suffix])
			expect(route.ok,"Actual T01 rolling-turn contract accepts authored supply route: "+side+suffix+" / "+str(route.get("reason","")))
	rear.advance_time(1)
	expect(not rear.field_structures.initialize_defence("S01",Vector2(100,100),rear.PLAYER).ok,"No runtime free defence initialization")

func check_path(world: RefCounted, points: Array) -> void:
	for index in range(1,points.size()):
		var a: Vector2 = points[index-1]
		var b: Vector2 = points[index]
		var body := {"size":Vector2(8.5,3.5),"facing":(b-a).angle()}
		for obstacle in world.obstacles: expect(world._overlap_interval(body,a,b,obstacle.rect).x < 0,"Authored heavy lane avoids physical building")
		for metre in range(0,int(a.distance_to(b))+1,10):
			var at: Vector2 = a.move_toward(b,metre)
			for offset in [Vector2.ZERO,Vector2(4,4),Vector2(-4,-4)]:
				for movement_class in [0,1,2]: expect(world.support(Vector2i(at+offset),movement_class).ok,"Authored lane supports actual class footprint")

func budget(world: RefCounted) -> Dictionary:
	var xs: Array[int] = [0,4000]
	var ys: Array[int] = [0,6000]
	for region in world.base_regions:
		for x in [region.area.position.x,region.area.end.x]:
			if x not in xs: xs.append(x)
		for y in [region.area.position.y,region.area.end.y]:
			if y not in ys: ys.append(y)
	xs.sort()
	ys.sort()
	var counts: Dictionary = {}
	for yi in range(1,ys.size()):
		for xi in range(1,xs.size()):
			var at := Vector2i(xs[xi-1],ys[yi-1])
			var tile: Dictionary = world.cell(at)
			var group: String = tile.get("cover_group","")
			if tile.get("road",false):
				# Roads are an overlay, retain the dominant group beneath them.
				for index in range(world.base_regions.size()-1,-1,-1):
					var region: Dictionary = world.base_regions[index]
					if region.area.has_point(at) and not region.tile.get("road",false):
						group = region.tile.cover_group
						expect(region.tile.terrain not in ["TR09","TR10","TR11","TR12"],"Road never invents support across wet or impassable ground")
						break
				counts.Road = counts.get("Road",0.0)+(xs[xi]-at.x)*(ys[yi]-at.y)/240000.0
			counts[group] = counts.get(group,0.0)+(xs[xi]-at.x)*(ys[yi]-at.y)/240000.0
	return counts

func expect(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
