extends RefCounted
## Pure order-time packing. No scene, inventory, price or clock mutation.
const Catalog = preload("res://game/procurement/resource_catalog.gd")
const Packages = preload("res://game/warehousing/material_packages.gd")
const EPS := 0.000001
const FLOOR_Y := 1.02
const FRONT_Z := 0.35
const SIDE_SPAN := 2.20
const RACK_DEPTH := 0.53
const POST := 0.02
const TRAY := 0.03
const SPECS := {
	"S1":{"length":2.20,"tops":[0.425,0.85]},
	"S2":{"length":0.70,"tops":[0.10,0.55,1.00]},
	"S3":{"length":0.70,"tops":[0.10,0.70]},
	"S4":{"length":0.70,"tops":[0.10,0.70]},
}
const FAMILY := {"M01":"S1","M02":"S2","M03":"S3","M04":"S1","M05":"S4","M06":"S2","M07":"S4","M08":"S3","M09":"S4","M10":"S4","M11":"S2"}

static func quote(cart: Dictionary, vehicle_limit: int) -> Dictionary:
	var validated: Dictionary = Catalog.quote(cart,vehicle_limit)
	if not validated.ok: return validated
	var codes: Array = cart.keys()
	codes.sort()
	var groups := {}
	var volume := 0.0
	var serial := 0
	for code: String in codes:
		var quantity: int = int(cart[code])
		var count := int(ceil(float(quantity)/float(Packages.capacity(code))))
		var size: Vector3 = Packages.TYPES[code].size
		volume += float(count)*size.x*size.y*size.z
	# Even unobstructed side zones cannot hold this volume. Bound allocation
	# before expanding thousands of packets or evaluating candidate orders.
	if volume > float(vehicle_limit)*2.0*SIDE_SPAN*RACK_DEPTH*1.5+EPS:
		return _full()
	for code: String in codes:
		groups[code] = []
		for part: Dictionary in Packages.split(code,int(cart[code])):
			serial += 1
			groups[code].append({"id":"packet-%05d" % serial,"code":code,"quantity":int(part.quantity),"outer":part.size})
	var orders: Array = [codes.duplicate(),codes.duplicate(),codes.duplicate()]
	orders[0].sort_custom(func(a: String,b: String) -> bool:
		if (a == "M04") != (b == "M04"): return a == "M04"
		var va: float = _volume(groups[a])
		var vb: float = _volume(groups[b])
		return a < b if is_equal_approx(va,vb) else va > vb)
	orders[1].sort_custom(func(a: String,b: String) -> bool:
		return a < b if FAMILY[a] == FAMILY[b] else str(FAMILY[a]) < str(FAMILY[b]))
	var best: Array = []
	var best_score := INF
	for order: Array in orders:
		var plan: Array = []
		var valid := true
		for code: String in order:
			if not _group(plan,groups[code],vehicle_limit):
				valid = false
				break
		if valid:
			var score := _score(plan,codes)
			if score < best_score:
				best = plan
				best_score = score
	if best.is_empty(): return _full()
	var cost := 0
	for truck: Dictionary in best:
		_dependencies(truck)
		truck.goods_cost = 0
		for code: String in truck.cargo: truck.goods_cost += int(truck.cargo[code])*int(Catalog.MATERIALS[code].price)
		truck.fee = Catalog.TRANSPORT_FEE
		truck.cost = int(truck.goods_cost)+int(truck.fee)
		cost += int(truck.cost)
		for rack: Dictionary in truck.racks: rack.erase("spaces")
	return {"ok":true,"code":"OK","message":"Spatial quote; supported shelves and clear central aisle. Heuristic, not a proven global optimum.","vehicles":best,"vehicle_count":best.size(),"mass_kg":validated.mass_kg,"transport_fees":best.size()*Catalog.TRANSPORT_FEE,"cost":cost}

static func _volume(parts: Array) -> float:
	var total := 0.0
	for part: Dictionary in parts:
		var size: Vector3 = part.outer
		total += size.x*size.y*size.z
	return total

static func _truck() -> Dictionary:
	return {"racks":[],"packages":[],"mass_kg":0,"cargo":{}}

static func _group(plan: Array, packets: Array, limit: int) -> bool:
	# Prefer one existing truck for the whole material before fragmenting it.
	for index in plan.size():
		var candidate: Dictionary = plan[index].duplicate(true)
		if _fill(candidate,packets).is_empty():
			plan[index] = candidate
			return true
	var spread: Array = plan.duplicate(true)
	var remaining: Array = packets.duplicate()
	for truck: Dictionary in spread: remaining = _fill(truck,remaining)
	# Splitting over already needed trucks may save an additional vehicle.
	if remaining.is_empty():
		plan.assign(spread)
		return true
	var fresh := _truck()
	var fresh_remaining := _fill(fresh,packets)
	# If both choices add a truck, keep this whole material together.
	if fresh_remaining.is_empty():
		if plan.size() >= limit: return false
		plan.append(fresh)
		return true
	plan.assign(spread)
	while not remaining.is_empty():
		if plan.size() >= limit: return false
		fresh = _truck()
		var after := _fill(fresh,remaining)
		if after.size() == remaining.size(): return false
		plan.append(fresh)
		remaining = after
	return true

static func _fill(truck: Dictionary, packets: Array) -> Array:
	var remaining: Array = []
	for packet: Dictionary in packets:
		if int(truck.mass_kg)+int(packet.quantity) > Catalog.TRUCK_KG or not _place(truck,packet): remaining.append(packet)
	return remaining

static func _place(truck: Dictionary, packet: Dictionary) -> bool:
	var family: String = FAMILY[packet.code]
	var choice := _choice(truck,packet,family)
	if choice.is_empty():
		if not _add_rack(truck,family,packet.code == "M04"): return false
		choice = _choice(truck,packet,family)
		if choice.is_empty(): return false
	var rack: Dictionary = truck.racks[int(choice.rack)]
	var space: Dictionary = rack.spaces[int(choice.space)]
	var box: AABB = space.box
	var size: Vector3 = choice.size
	if packet.code == "M04":
		# Centre full-length planks on the two accepted cantilever saddles.
		box.position.x += (box.size.x-size.x)/2.0
		box.size.x = size.x
		box.position.z += (box.size.z-size.z)/2.0
		box.size.z = size.z
	var placed: Dictionary = packet.duplicate()
	placed.merge({"rack":str(rack.id),"position":box.position+Vector3(size.x/2.0,0,size.z/2.0),"size":size,"quarter_turn":bool(choice.turn),"support":str(space.support)})
	truck.packages.append(placed)
	truck.mass_kg += int(packet.quantity)
	truck.cargo[packet.code] = int(truck.cargo.get(packet.code,0))+int(packet.quantity)
	rack.spaces.remove_at(int(choice.space))
	# Three disjoint residual cuboids. Every retained base is an actual deck
	# or one fully supporting package; no unsupported bridging or floating fill.
	_space(rack,AABB(box.position+Vector3(size.x,0,0),Vector3(box.size.x-size.x,box.size.y,box.size.z)),str(space.support))
	_space(rack,AABB(box.position+Vector3(0,0,size.z),Vector3(size.x,box.size.y,box.size.z-size.z)),str(space.support))
	if packet.code not in ["M03","M04","M08"]:
		_space(rack,AABB(box.position+Vector3(0,size.y,0),Vector3(size.x,box.size.y-size.y,size.z)),str(packet.id))
	return true

static func _choice(truck: Dictionary, packet: Dictionary, family: String) -> Dictionary:
	var best := {}
	var score := INF
	var outer: Vector3 = packet.outer
	for rack_index in truck.racks.size():
		var rack: Dictionary = truck.racks[rack_index]
		if rack.family != family: continue
		if packet.code == "M04" and int(rack.side) != -1: continue
		for index in rack.spaces.size():
			var box: AABB = rack.spaces[index].box
			for turn: bool in [false,true]:
				if packet.code == "M04" and not turn: continue
				var size := Vector3(outer.z,outer.y,outer.x) if turn else outer
				if size.x > box.size.x+EPS or size.y > box.size.y+EPS or size.z > box.size.z+EPS: continue
				var value: float = box.get_volume()+box.position.y*0.00001
				if value < score:
					score = value
					best = {"rack":rack_index,"space":index,"size":size,"turn":turn}
	return best

static func _add_rack(truck: Dictionary, family: String, left_only: bool = false) -> bool:
	var length: float = SPECS[family].length
	for side: int in [-1,1]:
		if left_only and side != -1: continue
		var used := 0.0
		for rack: Dictionary in truck.racks:
			if int(rack.side) == side: used += float(SPECS[rack.family].length)
		if used+length > SIDE_SPAN+EPS: continue
		var origin := Vector3(-0.93 if side < 0 else 0.40,FLOOR_Y,FRONT_Z+0.10+used)
		var row := {"id":"rack-%02d" % truck.racks.size(),"family":family,"side":side,"origin":origin,"size":Vector3(RACK_DEPTH,1.50,length),"spaces":[]}
		var tops: Array = SPECS[family].tops
		for index in tops.size():
			var ceiling: float = float(tops[index+1])-TRAY if index+1 < tops.size() else 1.50
			_space(row,AABB(origin+Vector3(POST,float(tops[index]),POST),Vector3(RACK_DEPTH-2.0*POST,ceiling-float(tops[index]),length-2.0*POST)),"deck-%02d" % index)
		truck.racks.append(row)
		return true
	return false

static func _space(rack: Dictionary, box: AABB, support: String) -> void:
	if box.size.x > EPS and box.size.y > EPS and box.size.z > EPS: rack.spaces.append({"box":box,"support":support})

static func _score(plan: Array, codes: Array) -> float:
	var fractures := 0
	var racks := 0
	for code: String in codes:
		var trucks := 0
		for truck: Dictionary in plan:
			if truck.cargo.has(code): trucks += 1
		fractures += maxi(0,trucks-1)
	for truck: Dictionary in plan: racks += truck.racks.size()
	return float(plan.size())*1000000000.0+float(fractures)*1000000.0+float(racks)

static func _dependencies(truck: Dictionary) -> void:
	# Compute once for the immutable confirmed layout, never by scanning entities
	# during worker selection or rendering. An actual pickup clears a blocker.
	for packet: Dictionary in truck.packages:
		packet.blocked_by = []
		var bounds := AABB(packet.position-Vector3(packet.size.x/2.0,0,packet.size.z/2.0),packet.size)
		for other: Dictionary in truck.packages:
			if other.id == packet.id or other.rack != packet.rack: continue
			if other.support == packet.id:
				packet.blocked_by.append(str(other.id))
				continue
			var obstacle := AABB(other.position-Vector3(other.size.x/2.0,0,other.size.z/2.0),other.size)
			if obstacle.position.y >= bounds.end.y-EPS and minf(bounds.end.x,obstacle.end.x)-maxf(bounds.position.x,obstacle.position.x)>EPS and minf(bounds.end.z,obstacle.end.z)-maxf(bounds.position.z,obstacle.position.z)>EPS:
				packet.blocked_by.append(str(other.id))
				continue
			var nearer: bool = obstacle.position.x > bounds.position.x+EPS if bounds.get_center().x < 0.0 else obstacle.end.x < bounds.end.x-EPS
			if nearer and minf(bounds.end.y,obstacle.end.y)-maxf(bounds.position.y,obstacle.position.y)>EPS and minf(bounds.end.z,obstacle.end.z)-maxf(bounds.position.z,obstacle.position.z)>EPS:
				packet.blocked_by.append(str(other.id))

static func _full() -> Dictionary:
	return {"ok":false,"code":"SPATIAL_FREIGHT_FULL","message":"The complete shipment cannot fit the available material trucks while preserving shelves, supported cargo and the clear aisle."}
