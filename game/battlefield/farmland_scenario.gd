extends RefCounted
## Recorded representative Farmland and Towns layout; not the four-family generator.
const SIZE := Vector2i(4000,6000)
const BLUE_HQ := Vector2(2000,400)
const RED_HQ := Vector2(2000,5600)
const SEED := 831030
const OBJECTIVES := [
	{"id":"resource-west-blue","kind":"Resource","position":Vector2(800,2600)},
	{"id":"resource-centre-blue","kind":"Resource","position":Vector2(2000,2600)},
	{"id":"resource-east-blue","kind":"Resource","position":Vector2(3200,2600)},
	{"id":"resource-west-red","kind":"Resource","position":Vector2(800,3400)},
	{"id":"resource-centre-red","kind":"Resource","position":Vector2(2000,3400)},
	{"id":"resource-east-red","kind":"Resource","position":Vector2(3200,3400)},
	{"id":"route-hub-west","kind":"Route Hub","position":Vector2(1000,3000)},
	{"id":"route-hub-east","kind":"Route Hub","position":Vector2(3000,3000)},
	{"id":"observation-central","kind":"Observation","position":Vector2(2000,3000)},
]
const COLOURS := {"TR01":"71875a","TR02":"b7aa89","TR03":"93915d","TR04":"aaa35d","TR05":"496b45","TR06":"34563c","TR07":"777b70","TR08":"8c8580","TR09":"536f65","TR11":"416e87"}

static func apply(world: RefCounted) -> void:
	assert(world.base_regions.is_empty() and world.cells.is_empty())
	world.bounds = Rect2i(Vector2i.ZERO,SIZE)
	world.scenario = {"family":"Farmland and Towns","seed":SEED,"version":1,"objectives":OBJECTIVES.duplicate(true),"waypoints":waypoints()}
	world.add_base_region(world.bounds,"TR03",{"cover_group":"Farm"})
	# Broad authored land parcels, reflected across the front for equal home burden.
	var patches := [
		[Rect2i(0,0,4000,350),"TR01","Open"],
		[Rect2i(3800,500,200,2500),"TR01","Open"],
		[Rect2i(750,500,550,900),"TR01","Open"],
		[Rect2i(150,900,600,1000),"TR11","Water"],
		[Rect2i(3200,1800,600,600),"TR11","Water"],
		[Rect2i(100,1900,700,1000),"TR05","Forest"],
		[Rect2i(2900,600,700,1000),"TR06","Forest"],
		[Rect2i(1450,1450,400,700),"TR05","Forest"],
		[Rect2i(800,1500,400,1200),"TR07","Rock"],
		[Rect2i(2500,1300,400,1200),"TR07","Rock"],
		[Rect2i(150,500,600,400),"TR09","Swamp"],
		[Rect2i(3200,1600,600,400),"TR09","Swamp"],
		[Rect2i(1200,2200,900,800),"TR08","Town"],
		[Rect2i(2100,300,900,800),"TR08","Town"],
	]
	for patch in patches:
		_region_pair(world,patch[0],patch[1],patch[2])
		if patch[2] in ["Water","Forest","Rock","Swamp"]:
			var area: Rect2i = patch[0]
			# Broad stepped edges make coherent ponds/stands instead of single rectangular biomes.
			_region_pair(world,Rect2i(area.position,Vector2i(70,60)),"TR03","Farm")
			_region_pair(world,Rect2i(area.end-Vector2i(50,90),Vector2i(50,90)),"TR03","Farm")
	# Coherent crop parcels alternate within surviving farmland without changing its cover group.
	for x in [1900,2200,3000]:
		for y in [1200,1700,2200]:
			var area := Rect2i(x,y,180,300)
			if world.cell(area.get_center()).get("cover_group","") == "Farm": _region_pair(world,area,"TR04","Farm")
	# Dry safe starts and wide staging pads precede the shared road network.
	for hq in [BLUE_HQ,RED_HQ]: world.add_base_region(Rect2i(Vector2i(hq)-Vector2i(320,320),Vector2i(640,640)),"TR01",{"cover_group":"Open"})
	for y in [620,5380]: world.add_base_region(Rect2i(1700,y-70,600,140),"TR01",{"cover_group":"Open"})
	# Two independent north/south heavy corridors are 2km apart; no water crossing is assumed.
	for x in [1000,3000]:
		world.add_base_region(Rect2i(x-8,600,16,4800),"TR02",{"road":true})
	for y in [650,2600,3000,3400,5350]: world.add_base_region(Rect2i(790,y-8,2420,16),"TR02",{"road":true})
	world.add_base_region(Rect2i(1992,0,16,308),"TR02",{"road":true})
	world.add_base_region(Rect2i(1992,5692,16,308),"TR02",{"road":true})
	for y in [300,5700]: world.add_base_region(Rect2i(1992,y-8,116,16),"TR02",{"road":true})
	# Service berths are behind/alongside the opaque HQ; bypass them east of the building.
	for y in [450,5650]: world.add_base_region(Rect2i(1992,y-8,116,16),"TR02",{"road":true})
	world.add_base_region(Rect2i(2092,292,16,366),"TR02",{"road":true})
	world.add_base_region(Rect2i(2092,5342,16,366),"TR02",{"road":true})
	for y in [2300,3700]:
		world.add_base_region(Rect2i(1992,y-8,1016,16),"TR02",{"road":true})
		world.add_base_region(Rect2i(1960,y-40,100,80),"TR01",{"cover_group":"Open"})
	for x in [1000,3000]:
		for y in [650,2300,2600,3000,3400,3700,5350]: world.add_base_region(Rect2i(x-20,y-20,40,40),"TR02",{"road":true})
	for objective in OBJECTIVES:
		world.add_base_region(Rect2i(Vector2i(objective.position)-Vector2i(30,30),Vector2i(60,60)),"TR01",{"cover_group":"Open"})
	# Physical natural cover is on both approaches, outside the clear objective pads.
	for objective in OBJECTIVES:
		for side in [-1,1]:
			world.add_base_region(Rect2i(Vector2i(objective.position)+Vector2i(45,side*85-15),Vector2i(60,30)),"TR05",{"cover_group":"Forest"})
	# These building shells block sight and movement. Garrison/destruction remains a separate owner.
	for centre in [Vector2(1500,2400),Vector2(2500,800),Vector2(1500,3600),Vector2(2500,5200)]:
		for offset in [Vector2(-40,-30),Vector2(40,-30),Vector2(-40,30),Vector2(40,30)]:
			var at: Vector2 = centre+offset
			world.obstacle("town-shell-%d-%d" % [int(at.x),int(at.y)],Rect2(at-Vector2(4,3),Vector2(8,6)),0,6,true,true)

static func _region_pair(world: RefCounted, area: Rect2i, terrain: String, group: String) -> void:
	world.add_base_region(area,terrain,{"cover_group":group})
	world.add_base_region(Rect2i(area.position.x,6000-area.end.y,area.size.x,area.size.y),terrain,{"cover_group":group})

static func waypoints() -> Dictionary:
	var result := {
		"blue-service":Vector2(2000,450),"red-service":Vector2(2000,5650),
		"blue-troop-staging":Vector2(2000,620),"red-troop-staging":Vector2(2000,5380),
		"blue-dismount":Vector2(2000,2300),"red-dismount":Vector2(2000,3700),
		"blue-delivery":Vector2(2020,2300),"red-delivery":Vector2(2020,3700),
		"blue-service-route":[Vector2(2000,450),Vector2(2100,450),Vector2(2100,650),Vector2(2000,650),Vector2(2000,620)],
		"red-service-route":[Vector2(2000,5650),Vector2(2100,5650),Vector2(2100,5350),Vector2(2000,5350),Vector2(2000,5380)],
		"blue-front-route":[Vector2(2000,620),Vector2(2000,650),Vector2(3000,650),Vector2(3000,2300),Vector2(2000,2300)],
		"red-front-route":[Vector2(2000,5380),Vector2(2000,5350),Vector2(3000,5350),Vector2(3000,3700),Vector2(2000,3700)],
	}
	for side in ["blue","red"]:
		var delivery: Array = result[side+"-service-route"].duplicate()
		delivery.append_array(result[side+"-front-route"].slice(1))
		delivery.append(result[side+"-delivery"])
		result[side+"-delivery-route"] = delivery
		var home := delivery.duplicate()
		home.reverse()
		result[side+"-delivery-return"] = home
	return result

static func initialize_defences(rear: RefCounted) -> Dictionary:
	var ids: Array[String] = []
	for side in [{"hq":BLUE_HQ,"owner":"army-blue","direction":1.0},{"hq":RED_HQ,"owner":"army-red","direction":-1.0}]:
		for item in [["S01",Vector2(0,80)],["S02",Vector2(-35,75)],["S02",Vector2(35,75)]]:
			var offset: Vector2 = item[1]
			offset.y *= side.direction
			var result: Dictionary = rear.field_structures.initialize_defence(item[0],side.hq+offset,side.owner,side.direction*PI/2.0)
			if not result.ok: return result
			ids.append(result.id)
	return {"ok":true,"ids":ids,"message":"Both HQs have their declared empty opening defences."}
