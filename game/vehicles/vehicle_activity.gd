extends RefCounted
## Rear handling for the same F10-manufactured hulls and the shared rear clock.
const Layout = preload("res://game/staffing/rear_layout.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const EPS := 0.000001
var _rear_ref: WeakRef
var vehicles: Dictionary = {}
var fuel_jobs: Dictionary = {}
var _sequence := 0

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	rear.ledger.add_place("vehicle-lane", "F10 to F11 vehicle lane", Vector2.ZERO)

func crew_duty(id: String, station: String) -> String:
	return "crew:%s:%s" % [id,station]

func register_output(id: String, slot: int) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(id)
	assert(hull.kind == "CARRIER" and hull.vehicle_spec == Specs.TYPES[hull.design_type])
	vehicles[id] = {"id":id,"slot":slot,"state":"In F10","deadline":INF,"route":[],"distance":0.0,"length":0.0,"elapsed":0.0,"last_time":rear.time,"duration":0.0,"burned":0.0}
	for station in hull.vehicle_spec.stations:
		_add_duty(crew_duty(id,station))
	_add_duty("fuel:" + id)

func _add_duty(id: String) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	rear.requests[id] = {"id":id,"target":0,"positions":1,"priority":1,"created":rear.time,"order":rear._next(),"place":"vehicle-lane","manual":true}

func eligible(person: Dictionary, duty: String) -> bool:
	var parts := duty.split(":")
	if person.is_empty() or parts.size() < 2 or not vehicles.has(parts[1]) or person.owner != "army-blue" or person.health <= 0: return false
	if parts[0] == "fuel": return parts.size() == 2
	if parts[0] != "crew" or parts.size() != 3: return false
	var hull: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(parts[1])
	return parts[2] in hull.vehicle_spec.stations and (person.qualification == "P08" or (hull.design_type == "T03" and parts[2] == "Gunner" and person.qualification == "P04"))

func assign_station(id: String, person_id: String, station: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var duty := crew_duty(id,station)
	if not vehicles.has(id) or not rear.requests.has(duty): return _result(false,"Select a real produced hull and physical station.")
	if vehicles[id].state not in ["In F10","Parked"]: return _result(false,"Station changes need a stopped hull.")
	var hull: Dictionary = rear.ledger.inspect_entity(id)
	if hull.crew_by_station.has(station): return _result(false,"Station already occupied by " + hull.crew_by_station[station] + ".")
	if not eligible(rear.ledger.inspect_entity(person_id),duty): return _result(false,"Station needs a real qualified P08; T03 gunner also accepts P04.")
	var result: Dictionary = rear.reassign_person(person_id,duty)
	if result.ok: rear.requests[duty].target = 1
	return result

func report_path(person_id: String, duty: String) -> Array:
	var rear: RefCounted = _rear_ref.get_ref()
	var origin: Vector2 = rear.ledger.inspect_entity(person_id).position
	if duty.begins_with("fuel:"):
		var job: Dictionary = fuel_jobs.get(person_id,{})
		return _walk_from(origin,rear.ledger.inspect_entity(job.source).position) if not job.is_empty() else []
	var id := duty.split(":")[1]
	if not vehicles.has(id) or vehicles[id].state not in ["In F10","Parked"]: return []
	return _path_to_hull(origin,id)

func _path_to_hull(origin: Vector2, id: String) -> Array:
	var rear: RefCounted = _rear_ref.get_ref()
	var destination: Vector2 = rear.ledger.inspect_entity(id).position
	if vehicles[id].state == "In F10":
		var path: Array = _walk_from(origin,Layout.door("vehicle_works"))
		if not path.is_empty(): path.append(destination)
		return path
	return _walk_from(origin,destination)

func _walk_from(origin: Vector2, destination: Vector2) -> Array:
	var bay: Vector2 = _rear_ref.get_ref().ledger.inspect_entity("heavy-bay").position
	if origin.is_equal_approx(bay):
		var route: Array = [origin,Layout.door("vehicle_works")]
		if not destination.is_equal_approx(Layout.door("vehicle_works")):
			var rest: Array = Layout.path(Layout.door("vehicle_works"),destination)
			if rest.is_empty(): return []
			route.append_array(rest.slice(1))
		return route
	return Layout.path(origin,destination)

func begin_board(person_id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var person: Dictionary = rear.ledger.inspect_entity(person_id)
	var parts := String(person.duty_id).split(":")
	if parts.size() != 3 or not vehicles.has(parts[1]) or vehicles[parts[1]].state not in ["In F10","Parked"]: return _result(false,"Stopped produced hull required for station entry.")
	if not eligible(person,person.duty_id) or not person.position.is_equal_approx(rear.ledger.inspect_entity(parts[1]).position): return _result(false,"Qualified person must report physically to this hull.")
	if rear.ledger.inspect_entity(parts[1]).crew_by_station.has(parts[2]): return _result(false,"Station is physically occupied.")
	rear.actors[person_id].phase = "Vehicle Board"
	rear.actors[person_id].deadline = rear.time + 3.0
	return _result(true,"Three seconds of stopped station entry started.")

func complete_board(person_id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var parts := String(rear.ledger.inspect_entity(person_id).duty_id).split(":")
	if parts.size() != 3 or not vehicles.has(parts[1]) or vehicles[parts[1]].state not in ["In F10","Parked"]: return _result(false,"Station entry interrupted; hull is not stopped.")
	return rear.ledger.complete_vehicle_station_entry(person_id,parts[1],parts[2])

func request_exit(person_id: String) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var id: String = rear.ledger.inspect_entity(person_id).holder_id
	if not vehicles.has(id): return
	rear.actors[person_id].phase = "Vehicle Exit" if vehicles[id].state in ["In F10","Parked"] else "Vehicle Station"
	rear.actors[person_id].deadline = rear.time + 3.0 if rear.actors[person_id].phase == "Vehicle Exit" else INF

func complete_exit(person_id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var person: Dictionary = rear.ledger.inspect_entity(person_id)
	var id: String = person.holder_id
	if not vehicles.has(id) or vehicles[id].state not in ["In F10","Parked"]: return _result(false,"Exit waits for stopped hull.")
	var result: Dictionary = rear.ledger.complete_vehicle_station_exit(person_id,id)
	if result.ok and rear.requests.has(person.duty_id): rear.requests[person.duty_id].target = 0
	return result

func request_refuel(id: String, person_id: String, units: int) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	if not vehicles.has(id) or vehicles[id].state not in ["In F10","Parked"]: return _result(false,"Refuelling needs a stopped produced hull.")
	var hull: Dictionary = rear.ledger.inspect_entity(id)
	var pending := 0
	for job in fuel_jobs.values():
		if job.hull == id: pending += int(job.units)
	if units <= 0 or units > 25 or float(units + pending) > float(hull.vehicle_spec.tank_capacity)-hull.fuel+EPS: return _result(false,"Request 1–25 whole M08 units within free tank space after retained fuel carries.")
	var person: Dictionary = rear.ledger.inspect_entity(person_id)
	if person.is_empty() or not eligible(person,"fuel:"+id) or person.pending_assignment != "None" or not person.carrying_stock_id.is_empty() or not person.crew_station.is_empty() or fuel_jobs.has(person_id): return _result(false,"Select an actual free rear worker without a carry or station.")
	var source: Dictionary = {}
	for store in rear.stores.values():
		if not store.accessible: continue
		for stock in rear._stock_at(store.id):
			if stock.design_type == "M08" and stock.available >= units and not Layout.path(person.position,stock.position).is_empty():
				if source.is_empty() or person.position.distance_to(stock.position) < person.position.distance_to(source.position): source = stock
	if source.is_empty(): return _result(false,"No accessible local unreserved purchased M08 stack has those units.")
	_sequence += 1
	var claim := "vehicle-fuel-%04d" % _sequence
	var reserved: Dictionary = rear.ledger.request_stock(claim,source.id,units,person_id,"Refuel " + id,rear.PLAYER)
	if not reserved.ok or rear.ledger.inspect_claim(claim).reserved != units:
		if reserved.ok: rear.ledger.release_claim(claim)
		return _result(false,"Actual fuel source could not be reserved.")
	fuel_jobs[person_id] = {"hull":id,"source":source.id,"units":units,"claim":claim,"state":"Reporting"}
	var duty := "fuel:" + id
	var assigned: Dictionary = rear.reassign_person(person_id,duty)
	if not assigned.ok:
		rear.ledger.release_claim(claim)
		fuel_jobs.erase(person_id)
		return assigned
	rear.requests[duty].target = 1
	return _result(true,"Worker reporting to purchased M08; pickup, carry and tank handling remain.")

func begin_fuel_pickup(person_id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var job: Dictionary = fuel_jobs.get(person_id,{})
	if job.is_empty(): return _result(false,"No fuel job remains.")
	var source: Dictionary = rear.ledger.inspect_entity(job.source)
	if not rear.stores[source.holder_id].accessible:
		rear.actors[person_id].phase = "Vehicle Fuel Blocked"
		rear.actors[person_id].deadline = INF
		return _result(false,"Fuel source inaccessible; stock claim retained.")
	rear.actors[person_id].phase = "Vehicle Fuel Pickup"
	rear.actors[person_id].deadline = rear.time + 2.0
	return _result(true,"Two-second source pickup started.")

func cancel_unpicked_fuel(person_id: String) -> void:
	if not fuel_jobs.has(person_id): return
	var rear: RefCounted = _rear_ref.get_ref()
	var job: Dictionary = fuel_jobs[person_id]
	if job.claim.is_empty(): return # Carried goods must finish their physical safe handoff.
	rear.ledger.release_claim(job.claim)
	rear.requests["fuel:"+job.hull].target = 0
	fuel_jobs.erase(person_id)

func complete_fuel_pickup(person_id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var job: Dictionary = fuel_jobs.get(person_id,{})
	if job.is_empty(): return _result(false,"No fuel job remains.")
	var source: Dictionary = rear.ledger.inspect_entity(job.source)
	if not rear.stores[source.holder_id].accessible: return _result(false,"Source access lost during pickup; retain the reserved whole M08 units.")
	var result: Dictionary = rear.ledger.begin_carry(person_id,job.source,job.units,job.claim)
	if not result.ok: return result
	job.carried = result.entity_id
	job.claim = ""
	var route: Array = _path_to_hull(rear.ledger.inspect_entity(person_id).position,job.hull)
	if route.is_empty(): return _result(false,"Carried fuel waits with worker for a clear route to hull.")
	rear._move(rear.actors[person_id],"Vehicle Fuel Carry",route,1.2)
	return result

func begin_fuel_deposit(person_id: String) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	rear.actors[person_id].phase = "Vehicle Fuel Deposit"
	rear.actors[person_id].deadline = rear.time + 2.0

func complete_fuel_deposit(person_id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var job: Dictionary = fuel_jobs.get(person_id,{})
	if job.is_empty() or vehicles[job.hull].state not in ["In F10","Parked"]: return _result(false,"Fuel remains with worker until the same hull stops.")
	var result: Dictionary = rear.ledger.load_vehicle_fuel(person_id,job.hull)
	if result.ok:
		fuel_jobs.erase(person_id)
		rear.requests["fuel:"+job.hull].target = 0
	return result

func start_drive(id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	if not vehicles.has(id) or vehicles[id].state != "In F10" or rear.heavy_production.bay_occupant != id: return _result(false,"Only the same F10 occupied hull can clear this bay.")
	for job in fuel_jobs.values():
		if job.hull == id: return _result(false,"Finish this hull's physical fuel carry before driving out of F10.")
	for person_id in rear.actors:
		var person: Dictionary = rear.ledger.inspect_entity(person_id)
		if person.duty_id.begins_with("crew:"+id+":") and person.crew_station.is_empty() and rear.actors[person_id].phase in ["Reporting","Vehicle Board"]:
			return _result(false,"Finish the reporting person's stopped station entry before driving.")
	var hull: Dictionary = rear.ledger.inspect_entity(id)
	if not hull.crew_by_station.has("Driver"): return _result(false,"Awaiting Qualified Driver in the actual Driver station.")
	var driver: Dictionary = rear.ledger.inspect_entity(hull.crew_by_station.Driver)
	if driver.qualification != "P08" or driver.health <= 0: return _result(false,"Healthy actual P08 driver required.")
	var slot: int = vehicles[id].slot
	if rear.yard.state == "Moving to reserved parking": return _result(false,"Existing yard hull is moving through the shared F11 lane; wait for physical clearance.")
	if not rear.heavy_production.parking_accessible or not rear.heavy_production._slot_legal(slot,hull.design_type) or not rear.yard.occupied[slot].is_empty() or rear.yard.reserved[slot] != id: return _result(false,"Promised F11 parking occupied, inaccessible or invalid; hull stays in F10.")
	var route: Array = _route(id,slot)
	if route.is_empty(): return _result(false,"No footprint-clear lane to this promised F11 place.")
	var length: float = Layout.length(route)
	if hull.fuel+EPS < length/1000.0*_fuel_rate(hull.design_type)*1.25: return _result(false,"Fuel Empty or insufficient for real parking leg plus 25 percent reserve.")
	var row: Dictionary = vehicles[id]
	row.route = route
	row.length = length
	row.distance = 0.0
	row.elapsed = 0.0
	row.last_time = rear.time
	row.duration = _drive_seconds(hull.design_type,length)
	row.state = "Moving to F11"
	row.deadline = rear.time + row.duration
	return _result(true,"Same F10 hull moving physically toward its promised F11 place.")

func _route(id: String, slot: int) -> Array:
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(id)
	var target: Vector2 = rear.yard.PARKING_POSITIONS[slot]
	var lane_x: float = 170.0 if target.x < 180.0 else (190.0 if target.x > 180.0 else 180.0)
	var route: Array = _rounded([hull.position,Vector2(180,66),Vector2(lane_x,76),Vector2(lane_x,120),target],_turn_radius(hull.design_type))
	var size: Vector2 = hull.vehicle_spec.footprint
	for n in range(int(ceil(Layout.length(route)))+1):
		var pos: Vector2 = Layout.position(route,float(n))
		var box := Rect2(pos-size/2.0,size)
		for facility in Layout.FACILITIES:
			if facility == "park" or (facility == "vehicle_works" and pos.y < 56.0): continue
			var data: Array = Layout.FACILITIES[facility]
			if box.intersects(Rect2(data[1]-data[2]/2.0,data[2])): return []
		for index in rear.yard.occupied.size():
			if index == slot or rear.yard.occupied[index].is_empty(): continue
			var other: Dictionary = rear.ledger.inspect_entity(rear.yard.occupied[index])
			var other_size: Vector2 = other.get("vehicle_spec",{}).get("footprint",Vector2(7,2.7))
			if box.intersects(Rect2(rear.yard.PARKING_POSITIONS[index]-other_size/2.0,other_size)): return []
	return route

func _rounded(corners: Array, radius: float) -> Array:
	if radius <= 0.0: return corners
	var route: Array = [corners[0]]
	for index in range(1,corners.size()-1):
		var before: Vector2 = corners[index-1]
		var corner: Vector2 = corners[index]
		var after: Vector2 = corners[index+1]
		var incoming: Vector2 = (corner-before).normalized()
		var outgoing: Vector2 = (after-corner).normalized()
		var angle: float = acos(clampf(incoming.dot(outgoing),-1.0,1.0))
		if angle < 0.001:
			route.append(corner)
			continue
		var tangent: float = radius*tan(angle/2.0)
		if tangent*2.0 > minf(before.distance_to(corner),corner.distance_to(after)): return []
		var entry: Vector2 = corner-incoming*tangent
		var sign: float = 1.0 if incoming.cross(outgoing)>0.0 else -1.0
		var normal := Vector2(-incoming.y,incoming.x)*sign
		var center: Vector2 = entry+normal*radius
		var start_angle: float = (entry-center).angle()
		route.append(entry)
		var steps: int = maxi(4,int(ceil(radius*angle)))
		for step in range(1,steps+1): route.append(center+Vector2.from_angle(start_angle+sign*angle*float(step)/float(steps))*radius)
	route.append(corners.back())
	return route

func _turn_radius(type: String) -> float:
	return {"T01":10.0,"T02":9.0,"T03":7.0,"T04":8.0,"T05":0.0}[type]

func _drive_speed(type: String) -> float:
	if type == "T05": return _road_speed(type)
	var turn_rate: float = {"T01":45.0,"T02":45.0,"T03":70.0,"T04":40.0}[type]
	return minf(_road_speed(type),_turn_radius(type)*deg_to_rad(turn_rate))

func _drive_seconds(type: String, length: float) -> float:
	return length/_drive_speed(type)+(3.0 if type == "T05" else 0.0)

func _distance_at_time(row: Dictionary, type: String, elapsed: float) -> float:
	if type != "T05": return minf(row.length,maxf(0.0,elapsed)*_drive_speed(type))
	var travelled := 0.0
	var remaining := maxf(0.0,elapsed)
	for index in range(1,row.route.size()):
		var segment: float = (row.route[index] as Vector2).distance_to(row.route[index-1])
		var duration: float = segment/_drive_speed(type)
		if remaining < duration: return travelled+remaining*_drive_speed(type)
		travelled += segment
		remaining -= duration
		if index in [1,2]:
			if remaining < 1.5: return travelled
			remaining -= 1.5
	return row.length

func _road_speed(type: String) -> float:
	return {"T01":12.0,"T02":15.0,"T03":18.0,"T04":12.0,"T05":9.0}[type]

func _fuel_rate(type: String) -> float:
	return {"T01":2.0,"T02":2.0,"T03":1.5,"T04":4.0,"T05":6.0}[type]

func next_boundary() -> float:
	var deadline := INF
	for row in vehicles.values(): deadline = minf(deadline,row.deadline)
	return deadline

func advance_to(next_time: float) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	for id in vehicles:
		var row: Dictionary = vehicles[id]
		if row.state != "Moving to F11": continue
		var hull: Dictionary = rear.ledger.inspect_entity(id)
		row.elapsed = minf(row.duration,row.elapsed+maxf(0.0,next_time-row.last_time))
		row.last_time = next_time
		var next_distance: float = _distance_at_time(row,hull.design_type,row.elapsed)
		var burn: float = maxf(0.0,next_distance-row.distance)/1000.0*_fuel_rate(hull.design_type)
		var result: Dictionary = rear.ledger.burn_vehicle_fuel(id,burn)
		if not result.ok: push_error(result.message)
		row.burned += burn
		row.distance = next_distance
		rear.ledger.move_entity(id,"vehicle-lane",Layout.position(row.route,next_distance))

func settle() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var changed := false
	for id in vehicles:
		var row: Dictionary = vehicles[id]
		if row.state == "Moving to F11" and not rear.heavy_production.parking_accessible:
			row.state = "Stopped on lane"
			row.deadline = INF
			changed = true
		if row.state == "Stopped on lane" and rear.heavy_production.parking_accessible and rear.yard.reserved[row.slot] == id and rear.yard.occupied[row.slot].is_empty():
			row.state = "Moving to F11"
			row.last_time = rear.time
			row.deadline = rear.time + row.duration-row.elapsed
			changed = true
		if row.state == "Moving to F11" and row.deadline <= rear.time+EPS:
			var slot: int = row.slot
			rear.ledger.move_entity(id,"vehicle-lane",rear.yard.PARKING_POSITIONS[slot])
			rear.yard.occupied[slot] = id
			rear.yard.reserved[slot] = ""
			rear.heavy_production.bay_occupant = ""
			row.state = "Parked"
			row.deadline = INF
			for person_id in rear.actors:
				var person: Dictionary = rear.ledger.inspect_entity(person_id)
				if person.holder_id == id and person.pending_assignment != "None": request_exit(person_id)
			changed = true
	for person_id in fuel_jobs:
		var job: Dictionary = fuel_jobs[person_id]
		if rear.actors[person_id].phase == "Vehicle Fuel Blocked":
			if not job.claim.is_empty() and rear.stores[rear.ledger.inspect_entity(job.source).holder_id].accessible:
				rear._report(rear.actors[person_id])
				changed = true
			elif job.claim.is_empty() and vehicles[job.hull].state in ["In F10","Parked"]:
				var route: Array = _path_to_hull(rear.ledger.inspect_entity(person_id).position,job.hull)
				if not route.is_empty():
					rear._move(rear.actors[person_id],"Vehicle Fuel Carry",route,1.2)
					changed = true
	return changed

func readiness(id: String) -> Dictionary:
	var hull: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(id)
	if hull.is_empty(): return {}
	var missing: Array[String] = []
	for station in hull.vehicle_spec.stations:
		if not hull.crew_by_station.has(station): missing.append(station)
	var driver: bool = hull.crew_by_station.has("Driver")
	var fire_stations: bool = hull.crew_by_station.has("Gunner") and (hull.design_type != "T05" or hull.crew_by_station.has("Loader"))
	var ammo_type: String = {"T03":"E02","T04":"E26","T05":"E25"}.get(hull.design_type,"")
	var ammo: int = int(hull.ammunition.get(ammo_type,0)) if not ammo_type.is_empty() else 0
	return {"driver":driver,"transfer_crew_eligible":driver,"motion_ready":driver and hull.fuel > 0.0,
		"combat_crew_ready":missing.is_empty(),"main_fire_stations_ready":fire_stations,"matching_ammo":ammo,
		"combat_ready":missing.is_empty() and (ammo_type.is_empty() or ammo > 0),"missing_stations":missing}

func snapshot() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var rows: Array[Dictionary] = []
	for id in vehicles:
		var row: Dictionary = vehicles[id].duplicate(true)
		row.hull = rear.ledger.inspect_entity(id)
		row.readiness = readiness(id)
		row.fuel_claims = []
		for person_id in fuel_jobs:
			if fuel_jobs[person_id].hull == id: row.fuel_claims.append(fuel_jobs[person_id].duplicate(true))
		rows.append(row)
	return {"rows":rows,"fuel_jobs":fuel_jobs.duplicate(true)}

func audit() -> Array[String]:
	var rear: RefCounted = _rear_ref.get_ref()
	var errors: Array[String] = []
	for id in vehicles:
		var row: Dictionary = vehicles[id]
		if row.state == "In F10" and rear.heavy_production.bay_occupant != id: errors.append("Produced hull lost F10 occupancy: " + id)
		if row.state in ["Moving to F11","Stopped on lane"] and rear.heavy_production.bay_occupant != id: errors.append("F10 promise released before physical clearance: " + id)
		if row.state == "Parked" and rear.yard.occupied[row.slot] != id: errors.append("Produced hull lost F11 occupancy: " + id)
		if id not in rear.ledger.rear_fleet_hulls(rear.PLAYER): errors.append("Produced hull lost rear fleet membership: " + id)
	return errors

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
