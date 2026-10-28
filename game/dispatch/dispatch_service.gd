extends RefCounted
## Connected rear-to-HQ manifests. The identity ledger owns every physical object.
const Layout = preload("res://game/staffing/rear_layout.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
const Routes = preload("res://game/routes/route_planner.gd")
const EPS := 0.000001
const HQ_STOCK_KG := 20000.0
const HQ_RESERVE_LIMIT := 96
const CROSSING_CENTER := Vector2(740.0,91.0)
const MILITARY_PEOPLE_LIMIT := 384
const MILITARY_HULL_LIMIT := 24
const REAR_PEOPLE_LIMIT := 120
const HQ_BERTHS := 2
const ENTRY := Vector2(1240,91)
const HQ := Vector2(1640,91)
const HQ_QUEUE := Vector2(1600,91)
var _rear_ref: WeakRef
var manifests: Dictionary = {}
var incoming_people: Dictionary = {} # actual person ID -> accepted manifest ID
var military_people: Dictionary = {} # actual person ID -> receipt ID
var incoming_hulls: Dictionary = {} # real hull ID -> accepted manifest ID
var military_hulls: Dictionary = {} # real hull ID -> HQ receipt ID
var passenger_promises: Dictionary = {} # person ID -> manifest ID
var weapon_promises: Dictionary = {} # weapon ID -> manifest ID
var hq_reserve: Dictionary = {} # physical person ID -> HQ receiver
var return_places: Dictionary = {} # outside person ID -> rear readmission held for safety return
var hq_staff: Array[String] = []
var _sequence := 0
var _accepting := false
var _advancing_at := -1.0

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	rear.ledger.add_place("dispatch-berth","F07 real dispatch vehicle berth",Layout.door("dispatch"))
	rear.ledger.add_place("rear-exit","Rear boundary of reference safe road",Vector2(240,91))
	rear.ledger.add_place("field-entry","Friendly battlefield entry",ENTRY)
	rear.ledger.add_place("hq-berth","Friendly HQ receiving berth",HQ)
	rear.ledger.add_place("hq-queue","Friendly HQ safe receiving queue",HQ_QUEUE)
	rear.ledger.add_place("hq-stock","Friendly HQ 20,000 kg stock",HQ)
	rear.ledger.add_place("hq-reserve","Friendly HQ 96-person reserve",HQ + Vector2(15,0))
	for index in 5:
		var id := "initial-hq-%02d" % (index+1)
		rear.ledger.add_person(id,"hq-berth",rear.PLAYER,Records.Assignment.HQ_DUTY,true,"None","None")
		hq_staff.append(id)

func accept(hull_id: String, mode: String, passengers: Array, cargo: Dictionary, guns: Array = []) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	if not rear.vehicles.vehicles.has(hull_id) or rear.vehicles.vehicles[hull_id].state != "Parked": return _fail("Select the same stopped F10-produced hull at F11.")
	if mode not in ["Strategic Delivery","Fleet Transfer"] or (mode == "Strategic Delivery" and hull.design_type not in ["T01","T02"]): return _fail("Strategic Delivery needs T01/T02; Fleet Transfer permits all five real hull types.")
	if _active_manifest(hull_id) != "": return _fail("This physical hull already has an accepted manifest or unfinished return.")
	if not rear.vehicles.readiness(hull_id).transfer_crew_eligible: return _fail("A healthy actual P08 driver must occupy the distinct Driver station.")
	var seen: Dictionary = {}
	var payload := 180.0 * guns.size()
	for id in passengers:
		if seen.has(id) or passenger_promises.has(id) or incoming_people.has(id): return _fail("One real person may hold only one passenger commitment.")
		seen[id] = true
		var p: Dictionary = rear.ledger.inspect_entity(id)
		if p.is_empty() or not rear.actors.has(id) or p.owner != rear.PLAYER or p.rear_place != "Occupied" or p.health <= 0 or not p.crew_station.is_empty() or not p.carrying_stock_id.is_empty() or not p.carrying_weapon_id.is_empty() or p.pending_assignment != "None": return _fail("Passenger must be a healthy free actual rear person without carry or station: " + id)
		payload += p.unit_mass_kg + p.contents_mass_kg
	var seats: int = int(hull.vehicle_spec.passenger_seats)
	if hull.design_type == "T02" and not guns.is_empty(): seats = 8
	if passengers.size() > seats: return _fail("Passenger seats exceeded: %d requested, %d available in this %s mode." % [passengers.size(),seats,"folded-bench" if not guns.is_empty() else "normal"])
	if guns.size() > (2 if hull.design_type == "T01" else (1 if hull.design_type == "T02" else 0)): return _fail("Field gun limit exceeded for this actual hull; T01 permits two, T02 folded-bench permits one.")
	var seen_guns: Dictionary = {}
	for gun_id in guns:
		if seen_guns.has(gun_id): return _fail("The same field gun cannot occupy two manifest positions.")
		seen_guns[gun_id] = true
		if weapon_promises.has(gun_id): return _fail("Field gun is already committed to another manifest.")
		var gun: Dictionary = rear.ledger.inspect_entity(gun_id)
		if gun.is_empty() or gun.kind != "HEAVY_OBJECT" or gun.design_type != "E13" or gun.owner != rear.PLAYER or gun.holder_id != "heavy-bay" or rear.heavy_production.bay_occupant != gun_id: return _fail("Select the same packed E13 physically occupying F10 for collection.")
	for type in cargo:
		if type == "E13" or typeof(cargo[type]) != TYPE_INT or int(cargo[type]) <= 0: return _fail("Cargo requires positive whole item counts; E13 uses field-gun collection.")
		var mass: float = _unit_mass(type)
		if mass <= 0.0: return _fail("Unknown physical cargo mass for " + type)
		payload += mass * int(cargo[type])
	if payload > float(hull.vehicle_spec.payload) + EPS: return _fail("Payload exceeded: %.1f kg requested, %.1f kg permitted." % [payload,hull.vehicle_spec.payload])
	var crew: Dictionary = hull.crew_by_station
	var entrant_ids: Array = passengers.duplicate()
	if mode == "Fleet Transfer":
		for station in crew:
			var person_id: String = crew[station]
			if seen.has(person_id) or incoming_people.has(person_id): return _fail("Crew identity already committed elsewhere: " + person_id)
			var person: Dictionary = rear.ledger.inspect_entity(person_id)
			if person.rear_place != "Occupied" or person.health <= 0: return _fail("Fleet Transfer crew must be living actual rear occupants.")
			entrant_ids.append(person_id)
	if military_people.size() + incoming_people.size() + entrant_ids.size() > MILITARY_PEOPLE_LIMIT: return _fail("Military 384 admission is full for these actual passengers and transferring crew.")
	if mode == "Fleet Transfer" and military_hulls.size() + incoming_hulls.size() >= MILITARY_HULL_LIMIT: return _fail("Military 24 incoming hull admission is full.")
	_sequence += 1
	var id := "manifest-%04d" % _sequence
	var row := {"id":id,"hull":hull_id,"mode":mode,"state":"Requested","passengers":passengers.duplicate(),"cargo":cargo.duplicate(true),"guns":guns.duplicate(),"stock_items":[],"weapon_items":[],"driver":crew.Driver,"crew":crew.duplicate(),"task":{},"route":[],"route_length":0.0,"distance":0.0,"last_time":rear.time,"travel_speed":0.0,"travel_burn":0.0,"arrived":{},"unloaded":{},"blocker":"","departed":false,"hq_berth":false,"cancel_released":false,"home_slot":int(rear.vehicles.vehicles[hull_id].slot),"route_profile":{},"route_plan":{}}
	manifests[id] = row
	for person_id in passengers: passenger_promises[person_id] = id
	for person_id in entrant_ids: incoming_people[person_id] = id
	if mode == "Fleet Transfer": incoming_hulls[hull_id] = id
	for gun_id in guns: weapon_promises[gun_id] = id
	var duty := "passenger:" + id
	rear.requests[duty] = {"id":duty,"target":0,"positions":seats,"priority":1,"created":rear.time,"order":rear._next(),"place":"duty-dispatch"}
	_accepting = true
	for person_id in passengers: rear.reassign_person(person_id,duty)
	_accepting = false
	_reserve_cargo(row)
	_begin_hull_approach(row)
	rear._settle()
	return {"ok":true,"message":"Accepted one named hull, real people and capacity claims; physical staging/boarding still required.","id":id}

func _unit_mass(type: String) -> float:
	if type.begins_with("M"): return 1.0
	if type == "E01": return 4.0
	for spec in Fixed.RECIPES.values():
		if spec.output_type == type: return float(spec.unit_mass)
	return -1.0

func _active_manifest(hull_id: String) -> String:
	for id in manifests:
		if manifests[id].hull == hull_id and manifests[id].state not in ["Complete","Cancelled","Safety Returned"]: return id
	return ""

func _reserve_cargo(row: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	for type in row.cargo:
		var have := 0
		for item in row.weapon_items:
			if item.type == type: have += 1
		for item in row.stock_items:
			if item.type == type: have += int(item.quantity)
		for weapon in rear.ledger.snapshot().entities:
			if have >= int(row.cargo[type]): break
			if weapon.kind != "WEAPON" or weapon.design_type != type or weapon.owner != rear.PLAYER or weapon_promises.has(weapon.id) or not rear.stores.has(weapon.holder_id) or weapon.loaded_rounds != 0: continue
			weapon_promises[weapon.id] = row.id
			row.weapon_items.append({"type":type,"id":weapon.id,"stage":"Staged" if weapon.holder_id == "dispatch" else "Source"})
			have += 1
		for stock in rear.ledger.snapshot().entities:
			if have >= int(row.cargo[type]): break
			if stock.kind != "STOCK" or stock.design_type != type or stock.owner != rear.PLAYER or not rear.stores.has(stock.holder_id) or not rear.stores[stock.holder_id].accessible: continue
			var count: int = mini(int(row.cargo[type])-have,mini(rear.ledger.available(stock.id),int(floor(25.0/_unit_mass(type)))))
			if count <= 0: continue
			_sequence += 1
			var claim := "dispatch-stock-%04d" % _sequence
			var result: Dictionary = rear.ledger.request_stock(claim,stock.id,count,row.id,"Real outward manifest",rear.PLAYER)
			if not result.ok or rear.ledger.inspect_claim(claim).reserved != count: continue
			row.stock_items.append({"type":type,"id":stock.id,"quantity":count,"claim":claim,"stage":"Staged" if stock.holder_id == "dispatch" else "Source"})
			have += count

func _begin_hull_approach(row: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	var route: Array = Layout.path(hull.position,Layout.door("dispatch"))
	if route.is_empty():
		row.blocker = "No clear rear road to F07 Dispatch."
		return
	var length: float = Layout.length(route)
	var rate: float = rear.vehicles._fuel_rate(hull.design_type)
	if hull.fuel + EPS < length / 1000.0 * rate * 1.25:
		row.blocker = "Fuel Empty or insufficient for physical F11-to-F07 approach."
		return
	row.state = "Staging"
	_start_route(row,route,"Approaching Dispatch")
	if row.state != "Approaching Dispatch": return
	rear.vehicles.vehicles[row.hull].state = "Dispatch Approach"
	rear.yard.occupied[row.home_slot] = ""
	rear.yard.reserved[row.home_slot] = row.hull # Hold an actual predeparture/cancel return place.

func _start_route(row: Dictionary, points: Array, state: String) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var corridor: bool = state == "Transit" or (state == "Returning" and row.get("return_phase","") == "Outside") or (state == "Safety Returning" and row.get("return_phase","") == "Outside")
	var profile: Dictionary = row.route_profile.duplicate(true) if corridor else {}
	profile = _crossing_profile(profile,points)
	profile.strict_turns = false if state == "Safety Returning" else (bool(profile.get("strict_turns",true)) if corridor else false)
	var measured: Dictionary = Routes.plan(rear.ledger,row.hull,points,profile)
	if not measured.ok:
		row.blocker = measured.reason
		row.state = "Route Blocked"
		return
	row.route = points
	row.route_length = measured.distance
	row.distance = 0.0
	row.last_time = _advancing_at if _advancing_at >= 0.0 else rear.time
	row.route_started = row.last_time
	row.route_deadline = row.route_started + measured.seconds
	row.travel_speed = measured.distance/measured.seconds
	row.route_plan = measured
	row.travel_burn = 0.0
	row.state = state

func _crossing_profile(profile: Dictionary, points: Array) -> Dictionary:
	var effective: Dictionary = profile.duplicate(true)
	if str(effective.get("bridge","")).is_empty(): return effective
	var distance := 0.0
	for index in range(1,points.size()):
		var start: Vector2 = points[index-1]
		var finish: Vector2 = points[index]
		if absf(start.y-CROSSING_CENTER.y) <= EPS and absf(finish.y-CROSSING_CENTER.y) <= EPS and minf(start.x,finish.x) <= CROSSING_CENTER.x and maxf(start.x,finish.x) >= CROSSING_CENTER.x:
			effective.bridge_at_m = distance+start.distance_to(CROSSING_CENTER)
			return effective
		distance += start.distance_to(finish)
	effective.erase("bridge")
	effective.erase("bridge_at_m")
	return effective

func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func next_boundary() -> float:
	var next := INF
	for row in manifests.values():
		if row.state in ["Approaching Dispatch","Departed","Transit","Docking HQ","Returning","Safety Returning"]:
			next = minf(next,float(row.route_deadline))
		if row.state == "Safety Stop": next = minf(next,float(row.stop_deadline))
		if not row.task.is_empty(): next = minf(next,float(row.task.deadline))
	return next

func advance_to(next_time: float) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	_advancing_at = next_time
	for row in manifests.values():
		if row.state == "Safety Stop" and next_time + EPS >= float(row.stop_deadline):
			var fallback: Dictionary = request_safe_return(row.id)
			if not fallback.ok:
				row.state = "Stranded"
				row.blocker = "10-second safety hold ended; " + fallback.message + " Same hull and contents remain stopped."
		if row.state in ["Approaching Dispatch","Departed","Transit","Docking HQ","Returning","Safety Returning"]:
			var progress: Dictionary = _route_progress(row,maxf(0.0,next_time-float(row.route_started)))
			var moved: float = float(progress.distance)-float(row.distance)
			if moved > EPS:
				var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
				var fuel: float = maxf(0.0,float(progress.fuel)-float(row.travel_burn))
				if fuel > hull.fuel + EPS:
					var fraction: float = hull.fuel/fuel
					moved *= fraction
					fuel = hull.fuel
					row.blocker = "Fuel Empty; same hull stopped with its actual contents and claims."
					row.state = "Fuel Empty"
				rear.ledger.burn_vehicle_fuel(row.hull,fuel)
				row.travel_burn += fuel
				row.distance += moved
				rear.ledger.move_entity(row.hull,"rear",Layout.position(row.route,row.distance))
			row.last_time = next_time
			if row.state != "Fuel Empty" and row.distance + EPS >= row.route_length: _finish_route(row)
		if row.task.is_empty(): continue
		var task: Dictionary = row.task
		if not task.route.is_empty():
			var elapsed: float = minf(task.deadline,next_time)-task.started
			var position: Vector2 = Layout.position(task.route,elapsed*task.speed)
			for person_id in task.actors: rear.ledger.move_entity(person_id,"rear",position)
			if task.phase in ["Gun Carry","Gun Return Carry"]: rear.ledger.move_field_gun(task.gun,"rear",position)
		if task.deadline <= next_time + EPS: _finish_task(row)
	_advancing_at = -1.0

func _route_progress(row: Dictionary, elapsed: float) -> Dictionary:
	var distance := 0.0
	var fuel := 0.0
	var remaining: float = minf(elapsed,float(row.route_plan.seconds))
	for part in row.route_plan.parts:
		var used: float = minf(remaining,float(part.seconds))
		if used <= 0.0: break
		var fraction: float = used/float(part.seconds)
		distance += float(part.distance)*fraction
		fuel += float(part.fuel)*fraction
		remaining -= used
	return {"distance":distance,"fuel":fuel}

func _finish_route(row: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	if row.state == "Approaching Dispatch":
		rear.ledger.move_entity(row.hull,"dispatch-berth",Layout.door("dispatch"))
		row.state = "Cancelling" if row.get("cancel_after_route",false) else "Staging"
	elif row.state == "Departed":
		for person_id in row.passengers: rear.ledger.set_rear_place(person_id,"Occupied","None")
		for person_id in row.crew.values(): rear.ledger.set_rear_place(person_id,"Occupied","Held Home" if row.mode == "Strategic Delivery" else "None")
		if row.mode == "Fleet Transfer": rear.yard.reserved[row.home_slot] = ""
		_start_route(row,[rear.ledger.inspect_entity(row.hull).position,ENTRY,HQ_QUEUE],"Transit")
	elif row.state == "Transit":
		rear.ledger.move_entity(row.hull,"hq-queue",HQ_QUEUE)
		row.state = "Waiting HQ Berth"
		row.blocker = "Waiting at the real HQ queue for one of two receiving berths."
	elif row.state == "Docking HQ":
		rear.ledger.move_entity(row.hull,"hq-berth",HQ)
		row.state = "Arrived"
		row.blocker = ""
		row.arrived = _physical_totals(row)
	elif row.state == "Safety Returning":
		if row.return_phase == "Outside":
			for person_id in row.passengers:
				if return_places.has(person_id):
					rear.ledger.set_rear_place(person_id,"None","Occupied")
					return_places.erase(person_id)
					incoming_people.erase(person_id)
			for person_id in row.crew.values():
				if return_places.has(person_id):
					rear.ledger.set_rear_place(person_id,"None","Occupied")
					return_places.erase(person_id)
					incoming_people.erase(person_id)
				elif rear.ledger.inspect_entity(person_id).rear_place == "Held Home": rear.ledger.set_rear_place(person_id,"Held Home","Occupied")
			row.return_phase = "Rear"
			_start_route(row,Layout.path(rear.ledger.inspect_entity(row.hull).position,Layout.door("dispatch")),"Safety Returning")
			return
		rear.ledger.move_entity(row.hull,"dispatch-berth",Layout.door("dispatch"))
		incoming_hulls.erase(row.hull)
		row.state = "Cancelling"
		row.blocker = "Physical safety-return unloading remains before this hull can park."
	elif row.state == "Returning":
		if row.get("return_phase","") == "Outside":
			_start_route(row,[rear.ledger.inspect_entity(row.hull).position,ENTRY,rear.ledger.inspect_entity("rear-exit").position],"Returning")
			row.return_phase = "Rear"
			return
		if row.get("return_phase","") == "Rear":
			for person_id in row.crew.values():
				if rear.ledger.inspect_entity(person_id).rear_place == "Held Home": rear.ledger.set_rear_place(person_id,"Held Home","Occupied")
			_start_route(row,Layout.path(rear.ledger.inspect_entity(row.hull).position,rear.yard.PARKING_POSITIONS[row.home_slot]),"Returning")
			row.return_phase = "Park"
			return
		var slot: int = row.home_slot
		var park: Vector2 = rear.yard.PARKING_POSITIONS[slot]
		rear.ledger.move_entity(row.hull,"rear",park)
		rear.yard.reserved[slot] = ""
		rear.yard.occupied[slot] = row.hull
		rear.vehicles.vehicles[row.hull].state = "Parked"
		row.state = ("Safety Returned" if row.get("safety_return",false) else "Cancelled") if row.get("return_phase","") == "Cancel" else "Complete"
		if row.state == "Safety Returned":
			for person_id in row.passengers: passenger_promises.erase(person_id)
			for gun_id in row.guns: weapon_promises.erase(gun_id)
			for item in row.weapon_items: weapon_promises.erase(item.id)

func _physical_totals(row: Dictionary) -> Dictionary:
	var totals: Dictionary = {"people":row.passengers.size(),"guns":0}
	for item in row.stock_items:
		if item.stage == "Onboard": totals[item.type] = int(totals.get(item.type,0)) + int(item.quantity)
	for item in row.weapon_items:
		if item.stage == "Onboard": totals[item.type] = int(totals.get(item.type,0)) + 1
	for gun_id in row.guns:
		if _rear_ref.get_ref().ledger.inspect_entity(gun_id).holder_id == row.hull: totals.guns += 1
	return totals

func settle() -> bool:
	if _accepting: return false
	var changed := false
	for row in manifests.values():
		if row.state in ["Complete","Cancelled","Safety Returned","Approaching Dispatch","Departed","Transit","Docking HQ","Returning","Safety Returning"] or not row.task.is_empty(): continue
		if row.state in ["Requested","Staging","Ready","Loading"]:
			var before: int = row.stock_items.size() + row.weapon_items.size()
			_reserve_cargo(row)
			changed = before != row.stock_items.size() + row.weapon_items.size() or changed
			changed = _schedule_preparation(row) or changed
		elif row.state in ["Arrived","Unloading"]:
			changed = _schedule_hq(row) or changed
		elif row.state == "Waiting HQ Berth":
			if _hq_berth_count() >= HQ_BERTHS: row.blocker = "Both actual HQ receiving berths are occupied; same hull and cargo wait outside."
			else:
				var rear: RefCounted = _rear_ref.get_ref()
				row.hq_berth = true
				row.blocker = ""
				_start_route(row,[rear.ledger.inspect_entity(row.hull).position,HQ],"Docking HQ")
				changed = true
		elif row.state == "Cancelling":
			changed = _schedule_cancel(row) or changed
	return changed

func _ready_worker() -> String:
	var rear: RefCounted = _rear_ref.get_ref()
	for id in rear.actors:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		if p.duty_id == "dispatch" and p.pending_assignment == "None" and rear.actors[id].phase == "Idle" and p.health > 0 and p.carrying_stock_id.is_empty() and p.carrying_weapon_id.is_empty(): return id
	return ""

func _start_task(row: Dictionary, phase: String, actors: Array, seconds: float, route: Array = []) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var started: float = _advancing_at if _advancing_at >= 0.0 else rear.time
	row.task = {"phase":phase,"actors":actors.duplicate(),"started":started,"deadline":started+seconds,"route":route,"speed":Layout.length(route)/seconds if not route.is_empty() and seconds > 0.0 else 0.0}
	for person_id in actors:
		if rear.actors.has(person_id):
			rear.actors[person_id].phase = "Dispatch " + phase
			rear.actors[person_id].deadline = INF
			rear.actors[person_id].motion = {}

func _clear_task(row: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	for person_id in row.task.get("actors",[]):
		if rear.actors.has(person_id): rear.actors[person_id].phase = "Idle"
	row.task = {}

func _schedule_preparation(row: Dictionary) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if row.state == "Requested":
		_begin_hull_approach(row)
		return row.state == "Approaching Dispatch"
	if rear.ledger.inspect_entity(row.hull).holder_id != "dispatch-berth": return false
	for gun_id in row.guns:
		if rear.ledger.inspect_entity(gun_id).holder_id == row.hull: continue
		if rear.heavy_production.bay_occupant != gun_id or not rear.heavy_production.bay_accessible:
			row.blocker = "The same F10 field gun or Vehicle Works access is unavailable."
			return false
		var loaders: Array[String] = []
		for person_id in rear.actors:
			var p: Dictionary = rear.ledger.inspect_entity(person_id)
			if p.duty_id == "vehicle_works" and rear.actors[person_id].phase == "Idle" and p.health > 0 and p.position.is_equal_approx(Layout.door("vehicle_works")):
				loaders.append(person_id)
				if loaders.size() == 2: break
		if loaders.size() != 2:
			row.blocker = "Field gun at F10 needs two actual available loaders at Vehicle Works for 20 active seconds."
			return false
		_start_task(row,"Gun Handling",loaders,20.0)
		row.task.gun = gun_id
		row.state = "Loading"
		row.blocker = ""
		return true
	var worker := _ready_worker()
	for index in row.stock_items.size():
		var item: Dictionary = row.stock_items[index]
		if item.stage != "Source": continue
		if worker.is_empty():
			row.blocker = "Real Dispatch worker needed to stage reserved cargo."
			return false
		var source: Dictionary = rear.ledger.inspect_entity(item.id)
		if source.is_empty() or not rear.stores[source.holder_id].accessible:
			row.blocker = "Reserved cargo source is inaccessible; claim retained."
			return false
		var path: Array = Layout.path(rear.ledger.inspect_entity(worker).position,source.position)
		if path.is_empty(): row.blocker = "No clear walking route to reserved cargo source."; return false
		_start_task(row,"Stock Approach",[worker],Layout.length(path)/1.5,path)
		row.task.item_index = index
		row.state = "Staging"
		return true
	for index in row.weapon_items.size():
		var item: Dictionary = row.weapon_items[index]
		if item.stage != "Source": continue
		if worker.is_empty(): row.blocker = "Real Dispatch worker needed to collect the reserved rifle."; return false
		var source: Dictionary = rear.ledger.inspect_entity(item.id)
		var path: Array = Layout.path(rear.ledger.inspect_entity(worker).position,source.position)
		if path.is_empty(): row.blocker = "No clear walking route to actual rifle."; return false
		_start_task(row,"Weapon Approach",[worker],Layout.length(path)/1.5,path)
		row.task.item_index = index
		row.state = "Staging"
		return true
	for person_id in row.passengers:
		var p: Dictionary = rear.ledger.inspect_entity(person_id)
		if p.holder_id == row.hull: continue
		if p.duty_id == "passenger:"+row.id and rear.actors[person_id].phase == "Idle" and p.position.is_equal_approx(Layout.door("dispatch")):
			_start_task(row,"Passenger Board",[person_id],1.0)
			row.state = "Loading"
			return true
	for index in row.stock_items.size():
		var item: Dictionary = row.stock_items[index]
		if item.stage != "Staged": continue
		if worker.is_empty(): row.blocker = "One real Dispatch worker is needed for two-second pickup/drop loading."; return false
		_start_task(row,"Stock Load Pickup",[worker],2.0)
		row.task.item_index = index
		row.state = "Loading"
		return true
	for index in row.weapon_items.size():
		var item: Dictionary = row.weapon_items[index]
		if item.stage != "Staged": continue
		if worker.is_empty(): row.blocker = "One real Dispatch worker is needed to load the intact rifle."; return false
		_start_task(row,"Weapon Load Pickup",[worker],2.0)
		row.task.item_index = index
		row.state = "Loading"
		return true
	for type in row.cargo:
		var have := 0
		for item in row.weapon_items:
			if item.type == type: have += 1
		for item in row.stock_items:
			if item.type == type: have += int(item.quantity)
		if have < int(row.cargo[type]):
			row.blocker = "Actual %s short by %d; request/produce and stage real goods." % [type,int(row.cargo[type])-have]
			row.state = "Staging"
			return false
	for person_id in row.passengers:
		if rear.ledger.inspect_entity(person_id).holder_id != row.hull:
			row.blocker = "Wait for the actual named passenger to report and board."
			return false
	row.state = "Loaded Waiting Dispatch"
	row.blocker = ""
	return true

func _finish_task(row: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var task: Dictionary = row.task
	var phase: String = task.phase
	var worker: String = task.actors[0] if not task.actors.is_empty() else ""
	var result: Dictionary = {"ok":true}
	if phase == "Gun Handling":
		var path: Array = Layout.path(Layout.door("vehicle_works"),Layout.door("dispatch"))
		if path.is_empty(): row.blocker = "Gun gear route to F07 blocked; same gun remains in F10."; _clear_task(row); return
		result = rear.ledger.move_field_gun(task.gun,"rear",Layout.door("vehicle_works"))
		if not result.ok: row.blocker = result.message; _clear_task(row); return
		rear.heavy_production.bay_occupant = ""
		_start_task(row,"Gun Carry",task.actors,Layout.length(path)/1.2,path)
		row.task.gun = task.gun
		return
	if phase == "Gun Carry":
		result = rear.ledger.transfer_field_gun(task.gun,"rear",row.hull)
	elif phase == "Passenger Board":
		result = rear.ledger.board_dispatch_passenger(worker,row.hull)
	elif phase in ["Stock Approach","Weapon Approach"]:
		_start_task(row,"Stock Pickup" if phase == "Stock Approach" else "Weapon Pickup",[worker],2.0)
		row.task.item_index = task.item_index
		return
	elif phase == "Stock Pickup":
		var item: Dictionary = row.stock_items[task.item_index]
		result = rear.ledger.begin_carry(worker,item.id,item.quantity,item.claim)
		if result.ok:
			item.id = result.entity_id
			item.claim = ""
	elif phase == "Weapon Pickup":
		result = rear.ledger.begin_weapon_carry(worker,row.weapon_items[task.item_index].id)
	if phase in ["Stock Pickup","Weapon Pickup"] and result.ok:
		var path: Array = Layout.path(rear.ledger.inspect_entity(worker).position,Layout.door("dispatch"))
		_start_task(row,"Stock Carry" if phase == "Stock Pickup" else "Weapon Carry",[worker],Layout.length(path)/1.2,path)
		row.task.item_index = task.item_index
		return
	if phase in ["Stock Carry","Weapon Carry"]:
		_start_task(row,"Stock Drop" if phase == "Stock Carry" else "Weapon Drop",[worker],2.0)
		row.task.item_index = task.item_index
		return
	if phase == "Stock Drop":
		result = rear.ledger.finish_carry(worker,"dispatch")
		if result.ok:
			var item: Dictionary = row.stock_items[task.item_index]
			item.id = result.entity_id
			item.stage = "Staged"
			_sequence += 1
			item.claim = "dispatch-stock-%04d" % _sequence
			rear.ledger.request_stock(item.claim,item.id,item.quantity,row.id,"Reserved staged manifest cargo",rear.PLAYER)
	elif phase == "Weapon Drop":
		result = rear.ledger.finish_weapon_carry(worker,"dispatch")
		if result.ok: row.weapon_items[task.item_index].stage = "Staged"
	elif phase == "Stock Load Pickup":
		var item: Dictionary = row.stock_items[task.item_index]
		result = rear.ledger.begin_carry(worker,item.id,item.quantity,item.claim)
		if result.ok: item.id = result.entity_id; item.claim = ""
	elif phase == "Weapon Load Pickup":
		result = rear.ledger.begin_weapon_carry(worker,row.weapon_items[task.item_index].id)
	if phase in ["Stock Load Pickup","Weapon Load Pickup"] and result.ok:
		_start_task(row,"Stock Load Drop" if phase == "Stock Load Pickup" else "Weapon Load Drop",[worker],2.0)
		row.task.item_index = task.item_index
		return
	if phase == "Stock Load Drop":
		result = rear.ledger.finish_carry_to_carrier(worker,row.hull)
		if result.ok: row.stock_items[task.item_index].id = result.entity_id; row.stock_items[task.item_index].stage = "Onboard"
	elif phase == "Weapon Load Drop":
		result = rear.ledger.finish_weapon_carry(worker,row.hull)
		if result.ok: row.weapon_items[task.item_index].stage = "Onboard"
	elif phase == "HQ Passenger Exit":
		result = rear.ledger.disembark_dispatch_passenger(worker,row.hull,"hq-berth")
		if result.ok:
			_start_task(row,"HQ Passenger Walk",[worker],10.0,[HQ,HQ+Vector2(15,0)])
			return
	elif phase == "HQ Passenger Walk":
		result = rear.ledger.complete_hq_reserve_receipt(worker,"hq-reserve")
		if result.ok:
			incoming_people.erase(worker)
			military_people[worker] = row.id
			hq_reserve[worker] = "Occupied"
			row.unloaded.people = int(row.unloaded.get("people",0)) + 1
	elif phase in ["HQ Stock Pickup","HQ Weapon Pickup","Cancel Stock Pickup","Cancel Weapon Pickup"]:
		var next := phase.replace("Pickup","Drop")
		_start_task(row,next,task.actors,2.0)
		row.task.item_id = task.item_id
		return
	elif phase == "HQ Stock Drop":
		for item in row.stock_items:
			if item.id != task.item_id: continue
			result = rear.ledger.transfer_stock(item.id,item.quantity,"hq-stock")
			if result.ok:
				item.id = result.entity_id
				item.stage = "Unloaded"
				row.unloaded[item.type] = int(row.unloaded.get(item.type,0)) + int(item.quantity)
			break
	elif phase == "HQ Weapon Drop":
		result = rear.ledger.transfer_weapon(task.item_id,"hq-stock")
		if result.ok:
			for item in row.weapon_items:
				if item.id == task.item_id:
					item.stage = "Unloaded"
					row.unloaded[item.type] = int(row.unloaded.get(item.type,0)) + 1
					break
	elif phase == "HQ Gun Unload":
		result = rear.ledger.transfer_field_gun(task.gun,row.hull,"hq-stock")
		if result.ok: row.unloaded.guns = int(row.unloaded.get("guns",0)) + 1
	elif phase == "Cancel Passenger Exit":
		result = rear.ledger.disembark_dispatch_passenger(worker,row.hull,"dispatch-berth")
		if result.ok: result = rear.ledger.complete_dispatch_cancel_person(worker,"dispatch-berth")
	elif phase == "Cancel Stock Drop":
		for item in row.stock_items:
			if item.id != task.item_id: continue
			result = rear.ledger.transfer_stock(item.id,item.quantity,"dispatch")
			if result.ok: item.id = result.entity_id; item.stage = "Staged"
			break
	elif phase == "Cancel Weapon Drop":
		result = rear.ledger.transfer_weapon(task.item_id,"dispatch")
		if result.ok:
			for item in row.weapon_items:
				if item.id == task.item_id: item.stage = "Staged"; break
	elif phase == "Gun Return Handling":
		result = rear.ledger.move_field_gun(task.gun,"rear",Layout.door("dispatch"))
		if result.ok:
			var path: Array = Layout.path(Layout.door("dispatch"),Layout.door("vehicle_works"))
			_start_task(row,"Gun Return Carry",task.actors,Layout.length(path)/1.2,path)
			row.task.gun = task.gun
			return
	elif phase == "Gun Return Carry":
		result = rear.ledger.transfer_field_gun(task.gun,"rear","heavy-bay")
		if result.ok: rear.heavy_production.bay_occupant = task.gun
	if not result.ok: row.blocker = result.message
	_clear_task(row)
	if phase == "Passenger Board" and result.ok: rear.actors[worker].phase = "Passenger Seated"

func route_preview(id: String, candidate: Dictionary = {}) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var row: Dictionary = manifests.get(id,{})
	if row.is_empty(): return _fail("Select an accepted physical manifest.")
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	var profile: Dictionary = candidate if not candidate.is_empty() else row.route_profile
	var rear_exit: Vector2 = rear.ledger.inspect_entity("rear-exit").position
	var segments: Array[Dictionary] = []
	var road_start: Vector2 = hull.position
	if hull.holder_id != "dispatch-berth":
		var approach: Array = Layout.path(hull.position,Layout.door("dispatch"))
		if approach.is_empty(): return _fail("No physical route from this hull to F07 dispatch.")
		var approach_plan: Dictionary = Routes.plan(rear.ledger,row.hull,approach,{"strict_turns":false})
		if not approach_plan.ok: return _fail(approach_plan.reason)
		segments.append(approach_plan)
		road_start = Layout.door("dispatch")
	var outward_rear: Dictionary = Routes.plan(rear.ledger,row.hull,[road_start,rear_exit],{"strict_turns":false})
	if not outward_rear.ok: return _fail(outward_rear.reason)
	segments.append(outward_rear)
	var outward: Dictionary = Routes.plan(rear.ledger,row.hull,[rear_exit,ENTRY,HQ_QUEUE],_crossing_profile(profile,[rear_exit,ENTRY,HQ_QUEUE]))
	if not outward.ok: return _fail(outward.reason)
	segments.append(outward)
	var dock: Dictionary = Routes.plan(rear.ledger,row.hull,[HQ_QUEUE,HQ])
	if not dock.ok: return _fail(dock.reason)
	segments.append(dock)
	if row.mode == "Strategic Delivery":
		var back: Dictionary = Routes.plan(rear.ledger,row.hull,[HQ,ENTRY,rear_exit],_crossing_profile(profile,[HQ,ENTRY,rear_exit]))
		if not back.ok: return _fail(back.reason)
		segments.append(back)
		var home: Array = Layout.path(rear_exit,rear.yard.PARKING_POSITIONS[row.home_slot])
		if home.is_empty(): return _fail("No physical rear route to the same F11 home slot.")
		var home_plan: Dictionary = Routes.plan(rear.ledger,row.hull,home,{"strict_turns":false})
		if not home_plan.ok: return _fail(home_plan.reason)
		segments.append(home_plan)
	var distance := 0.0
	var seconds := 0.0
	var fuel := 0.0
	for segment in segments:
		distance += float(segment.distance)
		seconds += float(segment.seconds)
		fuel += float(segment.fuel)
	var required: float = fuel*1.25
	return {"ok":true,"message":"Measured route and physical gross load.","distance":distance,"seconds":seconds,"fuel":fuel,"required_fuel":required,"tank_fuel":hull.fuel,"gross_kg":Routes.gross_kg(rear.ledger,row.hull),"profile":profile.duplicate(true),"segments":segments,"fuel_ok":hull.fuel+EPS >= required}

func set_route_profile(id: String, profile: Dictionary) -> Dictionary:
	var row: Dictionary = manifests.get(id,{})
	if row.is_empty() or row.departed or row.state in ["Cancelled","Cancelling","Complete"]: return _fail("Route edits require an accepted predeparture manifest.")
	var preview: Dictionary = route_preview(id,profile)
	if not preview.ok: return preview
	row.route_profile = profile.duplicate(true)
	row.full_route_plan = preview
	return {"ok":true,"message":"Actual route profile selected: %.1f m, %.2f fuel needed with 25 percent reserve; %.2f in same tank." % [preview.distance,preview.required_fuel,preview.tank_fuel]}

func depart(id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var row: Dictionary = manifests.get(id,{})
	if row.is_empty() or row.state != "Loaded Waiting Dispatch" or not row.task.is_empty(): return _fail("Wait for every real cargo item and passenger to finish physical loading.")
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	if hull.holder_id != "dispatch-berth" or not rear.vehicles.readiness(row.hull).transfer_crew_eligible: return _fail("Healthy actual P08 driver and stopped loaded hull are required at F07.")
	if not row.guns.is_empty():
		for gun_id in row.guns:
			if rear.ledger.inspect_entity(gun_id).holder_id != row.hull: return _fail("The same F10 field gun has not finished actual collection.")
	var count := 0
	for item in row.stock_items:
		if item.stage != "Onboard": return _fail("All reserved stock must be aboard.")
		count += int(item.quantity)
	for item in row.weapon_items:
		if item.stage != "Onboard": return _fail("All actual intact weapons must be aboard.")
	for type in row.cargo:
		var have := 0
		for item in row.stock_items:
			if item.type == type: have += int(item.quantity)
		for item in row.weapon_items:
			if item.type == type: have += 1
		if have != int(row.cargo[type]): return _fail("Partial dispatch is disabled: %s requested %d, onboard %d." % [type,int(row.cargo[type]),have])
	for person_id in row.passengers:
		if rear.ledger.inspect_entity(person_id).holder_id != row.hull: return _fail("A named passenger has not actually boarded: " + person_id)
	var plan: Dictionary = route_preview(id)
	if not plan.ok: return plan
	row.full_route_plan = plan
	if hull.fuel + EPS < plan.required_fuel: return _fail("Fuel Empty or insufficient for destination and next resupply with 25 percent reserve: %.2f needed over %.1f m, %.2f physically in tank; a reserved M08 carry is not tank fuel." % [plan.required_fuel,plan.distance,hull.fuel])
	if row.mode == "Fleet Transfer" and not incoming_hulls.has(row.hull): return _fail("Incoming military hull 24 claim is missing.")
	if _rear_ref.get_ref().receiving.rear_population() + _rear_ref.get_ref().receiving.incoming_people() > REAR_PEOPLE_LIMIT: return _fail("Rear 120 occupancy is invalid; departure cannot mask overbooking.")
	row.departed = true
	_start_route(row,[hull.position,rear.ledger.inspect_entity("rear-exit").position],"Departed")
	rear.vehicles.vehicles[row.hull].state = "Departed"
	return {"ok":true,"message":"Irreversible physical trip begun with the same loaded hull and claims."}

func _hq_berth_count() -> int:
	var count := 0
	for row in manifests.values():
		if row.hq_berth and row.state in ["Docking HQ","Arrived","Unloading"]: count += 1
	return count

func _schedule_hq(row: Dictionary) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if rear.ledger.inspect_entity(row.hull).holder_id != "hq-berth": return false
	if not row.hq_berth:
		if _hq_berth_count() > HQ_BERTHS:
			row.blocker = "Both actual HQ receiving berths are occupied."
			return false
		row.hq_berth = true
	if not row.get("hq_started",false):
		if row.mode == "Fleet Transfer":
			var committed: Dictionary = rear.ledger.complete_hq_hull_receipt(row.hull)
			if not committed.ok: row.blocker = committed.message; return false
			incoming_hulls.erase(row.hull)
			military_hulls[row.hull] = row.id
			for person_id in row.crew.values():
				incoming_people.erase(person_id)
				military_people[person_id] = row.id
		row.hq_started = true
		row.state = "Unloading"
		return true
	for person_id in row.passengers:
		if not incoming_people.has(person_id): continue
		var p: Dictionary = rear.ledger.inspect_entity(person_id)
		if p.holder_id == row.hull:
			if hq_reserve.size() >= HQ_RESERVE_LIMIT:
				row.blocker = "HQ Reserve 96 full; passenger waits aboard in their actual seat."
				return false
			if hq_staff.is_empty(): row.blocker = "No actual HQ receiving staff."; return false
			hq_reserve[person_id] = "Incoming"
			_start_task(row,"HQ Passenger Exit",[person_id],1.0)
			return true
	for item in row.stock_items:
		if item.stage != "Onboard": continue
		if rear.ledger.inspect_entity("hq-stock").contents_mass_kg + float(item.quantity)*_unit_mass(item.type) > HQ_STOCK_KG + EPS:
			row.blocker = "HQ stock 20,000 kg full; cargo remains physically aboard."
			return false
		if hq_staff.is_empty(): row.blocker = "No actual HQ cargo handler."; return false
		_start_task(row,"HQ Stock Pickup",[hq_staff[0]],2.0)
		row.task.item_id = item.id
		return true
	for item in row.weapon_items:
		if item.stage != "Onboard": continue
		if rear.ledger.inspect_entity("hq-stock").contents_mass_kg + _unit_mass(item.type) > HQ_STOCK_KG + EPS: row.blocker = "HQ stock 20,000 kg full."; return false
		_start_task(row,"HQ Weapon Pickup",[hq_staff[0]],2.0)
		row.task.item_id = item.id
		return true
	for gun_id in row.guns:
		if rear.ledger.inspect_entity(gun_id).holder_id != row.hull: continue
		if rear.ledger.inspect_entity("hq-stock").contents_mass_kg + 180.0 > HQ_STOCK_KG + EPS: row.blocker = "HQ stock 20,000 kg full for field gun."; return false
		if hq_staff.size() < 2: row.blocker = "Two actual HQ field-gun handlers required."; return false
		_start_task(row,"HQ Gun Unload",[hq_staff[0],hq_staff[1]],20.0)
		row.task.gun = gun_id
		return true
	for person_id in row.passengers:
		if incoming_people.has(person_id): return false
	row.hq_berth = false
	if row.mode == "Fleet Transfer": row.state = "Complete"
	else:
		row.return_phase = "Outside"
		_start_route(row,[rear.ledger.inspect_entity(row.hull).position,ENTRY],"Returning")
	return true

func request_safe_return(id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var row: Dictionary = manifests.get(id,{})
	if row.is_empty() or row.state not in ["Transit","Waiting HQ Berth","Docking HQ","Safety Stop","Stranded"] or row.get("hq_started",false): return _fail("Only the same outbound hull before HQ receipt can request a safety return.")
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	var needing: Array[String] = []
	for person_id in row.passengers:
		if rear.ledger.inspect_entity(person_id).rear_place == "None": needing.append(person_id)
	if row.mode == "Fleet Transfer":
		for person_id in row.crew.values():
			if rear.ledger.inspect_entity(person_id).rear_place == "None": needing.append(person_id)
	if rear.receiving.rear_population() + rear.receiving.incoming_people() + return_places.size() + needing.size() > REAR_PEOPLE_LIMIT: return _fail("Rear 120 is full; same hull waits outside with every person and military claim intact.")
	var route: Array = [hull.position,rear.ledger.inspect_entity("rear-exit").position]
	var home_route: Array = Layout.path(rear.ledger.inspect_entity("rear-exit").position,Layout.door("dispatch"))
	if home_route.is_empty(): return _fail("No safe physical rear re-entry route; actual hull and admissions stay outside.")
	var needed_fuel: float = (Layout.length(route)+Layout.length(home_route)+Layout.length(Layout.path(Layout.door("dispatch"),rear.yard.PARKING_POSITIONS[row.home_slot])))/1000.0*rear.vehicles._fuel_rate(hull.design_type)*1.25
	var return_profile: Dictionary = row.route_profile.duplicate(true)
	return_profile.erase("known_mine")
	return_profile.erase("observed_hostile")
	return_profile.strict_turns = false
	return_profile.allow_partial_bridge = true
	var outside_plan: Dictionary = Routes.plan(rear.ledger,row.hull,route,_crossing_profile(return_profile,route))
	if not outside_plan.ok: return _fail(outside_plan.reason)
	var rear_plan: Dictionary = Routes.plan(rear.ledger,row.hull,home_route,{"strict_turns":false})
	if not rear_plan.ok: return _fail(rear_plan.reason)
	var park_plan: Dictionary = Routes.plan(rear.ledger,row.hull,Layout.path(Layout.door("dispatch"),rear.yard.PARKING_POSITIONS[row.home_slot]),{"strict_turns":false})
	if not park_plan.ok: return _fail(park_plan.reason)
	needed_fuel = (float(outside_plan.fuel)+float(rear_plan.fuel)+float(park_plan.fuel))*1.25
	if hull.fuel + EPS < needed_fuel: return _fail("Fuel Empty or insufficient for real safety return plus 25 percent reserve; same hull waits outside.")
	for person_id in needing: return_places[person_id] = id
	row.hq_berth = false
	row.safety_return = true
	row.return_phase = "Outside"
	row.arrived = {}
	row.route_profile = return_profile
	_start_route(row,route,"Safety Returning")
	return {"ok":true,"message":"Safety return reserved real rear places; same occupied hull is moving home. No trip refund or early military release."}

func report_route_hazard(id: String, reason: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var row: Dictionary = manifests.get(id,{})
	if row.is_empty() or row.state != "Transit" or reason.is_empty(): return _fail("A named observed route hazard can stop only the same outbound hull before HQ.")
	row.state = "Safety Stop"
	row.stop_deadline = rear.time + 10.0
	row.blocker = reason + "; same hull stopped at its latest actual safe position for up to 10 seconds."
	return {"ok":true,"message":row.blocker}

func clear_route_hazard(id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var row: Dictionary = manifests.get(id,{})
	if row.is_empty() or row.state != "Safety Stop" or rear.time > float(row.stop_deadline) + EPS: return _fail("Only a live safety hold may resume before its ten-second deadline.")
	var elapsed := 0.0
	var left: float = row.distance
	for part in row.route_plan.parts:
		var used: float = minf(left,float(part.distance))
		elapsed += used/float(part.speed)
		left -= used
		if left <= EPS: break
	row.blocker = ""
	row.route_started = rear.time-elapsed
	row.route_deadline = row.route_started+float(row.route_plan.seconds)
	row.last_time = rear.time
	row.state = "Transit"
	return {"ok":true,"message":"Cleared known hazard; same hull resumes measured remaining route from its actual stop."}

func cancel(id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var row: Dictionary = manifests.get(id,{})
	if row.is_empty() or row.departed or row.state in ["Complete","Cancelled","Cancelling"]: return _fail("Only an accepted predeparture manifest can withdraw its own commitments once.")
	row.cancel_released = true
	for person_id in row.passengers:
		incoming_people.erase(person_id)
		passenger_promises.erase(person_id)
		if rear.ledger.inspect_entity(person_id).holder_id != row.hull: rear.reassign_person(person_id,"Available")
	if row.mode == "Fleet Transfer":
		incoming_hulls.erase(row.hull)
		for person_id in row.crew.values(): incoming_people.erase(person_id)
	for gun_id in row.guns: weapon_promises.erase(gun_id)
	for item in row.weapon_items: weapon_promises.erase(item.id)
	for item in row.stock_items:
		if not item.claim.is_empty(): rear.ledger.release_claim(item.claim); item.claim = ""
	row.state = "Cancelling"
	if rear.ledger.inspect_entity(row.hull).holder_id == "dispatch-berth" and not row.task.is_empty(): row.blocker = "Current handling must finish before actual unloading."
	if rear.vehicles.vehicles[row.hull].state == "Dispatch Approach": row.cancel_after_route = true
	rear._settle()
	return {"ok":true,"message":"Commitments withdrawn once; anything already aboard needs physical cancellation unloading and vehicle return."}

func change_mode(id: String, mode: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var row: Dictionary = manifests.get(id,{})
	if row.is_empty() or row.departed or row.state in ["Cancelled","Cancelling","Complete"]: return _fail("Only a live predeparture manifest can change mode.")
	if mode == row.mode: return {"ok":true,"message":"The same mode and claims remain."}
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	if mode not in ["Strategic Delivery","Fleet Transfer"] or (mode == "Strategic Delivery" and hull.design_type not in ["T01","T02"]): return _fail("Strategic Delivery accepts only T01/T02; old mode and claims remain.")
	if mode == "Fleet Transfer":
		if military_hulls.size() + incoming_hulls.size() >= MILITARY_HULL_LIMIT: return _fail("Military hull 24 full; old mode and claims remain.")
		if military_people.size() + incoming_people.size() + row.crew.size() > MILITARY_PEOPLE_LIMIT: return _fail("Military people 384 full for actual crew; old mode and claims remain.")
		for person_id in row.crew.values():
			var p: Dictionary = rear.ledger.inspect_entity(person_id)
			if incoming_people.has(person_id) or p.rear_place != "Occupied" or p.assignment == "Dead": return _fail("Actual crew unavailable for Fleet Transfer; old mode and claims remain: "+person_id)
		incoming_hulls[row.hull] = row.id
		for person_id in row.crew.values(): incoming_people[person_id] = row.id
	else:
		incoming_hulls.erase(row.hull)
		for person_id in row.crew.values(): incoming_people.erase(person_id)
	row.mode = mode
	row.erase("full_route_plan")
	return {"ok":true,"message":"Mode and only its own crew/hull admissions changed atomically before departure."}

func add_field_gun(id: String, gun_id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var row: Dictionary = manifests.get(id,{})
	if row.is_empty() or row.departed or row.state in ["Cancelled","Cancelling","Complete"]: return _fail("Add a field gun only to an accepted predeparture manifest.")
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	var limit := 2 if hull.design_type == "T01" else (1 if hull.design_type == "T02" else 0)
	if row.guns.size() >= limit: return _fail("This hull's field-gun limit is already used; old manifest remains.")
	if hull.design_type == "T02" and row.passengers.size() > 8: return _fail("T02 folded-bench mode allows at most eight passengers with a gun.")
	if _manifest_payload(row) + 180.0 > float(hull.vehicle_spec.payload) + EPS: return _fail("Added field gun exceeds this hull's payload.")
	var gun: Dictionary = rear.ledger.inspect_entity(gun_id)
	if gun.is_empty() or gun.kind != "HEAVY_OBJECT" or gun.design_type != "E13" or gun.holder_id != "heavy-bay" or rear.heavy_production.bay_occupant != gun_id or weapon_promises.has(gun_id): return _fail("Select the same uncommitted E13 currently occupying F10.")
	row.guns.append(gun_id)
	weapon_promises[gun_id] = id
	row.erase("full_route_plan")
	row.state = "Staging"
	rear._settle()
	return {"ok":true,"message":"Second actual field gun promised; two loaders must collect it before departure."}

func _manifest_payload(row: Dictionary) -> float:
	var rear: RefCounted = _rear_ref.get_ref()
	var mass: float = 180.0 * row.guns.size()
	for id in row.passengers:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		mass += p.unit_mass_kg + p.contents_mass_kg
	for type in row.cargo: mass += _unit_mass(type) * int(row.cargo[type])
	return mass

func _schedule_cancel(row: Dictionary) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
	if hull.holder_id != "dispatch-berth":
		if rear.vehicles.vehicles[row.hull].state == "Parked": row.state = "Cancelled"; return true
		return false
	for person_id in row.passengers:
		if rear.ledger.inspect_entity(person_id).holder_id == row.hull:
			_start_task(row,"Cancel Passenger Exit",[person_id],1.0)
			return true
	for item in row.stock_items:
		if item.stage != "Onboard": continue
		var worker := _ready_worker()
		if worker.is_empty(): row.blocker = "Real Dispatch worker needed for physical cancellation cargo unload."; return false
		_start_task(row,"Cancel Stock Pickup",[worker],2.0)
		row.task.item_id = item.id
		return true
	for item in row.weapon_items:
		if item.stage != "Onboard": continue
		var worker := _ready_worker()
		if worker.is_empty(): row.blocker = "Real Dispatch worker needed for physical cancellation rifle unload."; return false
		_start_task(row,"Cancel Weapon Pickup",[worker],2.0)
		row.task.item_id = item.id
		return true
	for gun_id in row.guns:
		if rear.ledger.inspect_entity(gun_id).holder_id != row.hull: continue
		if not rear.heavy_production.bay_occupant.is_empty(): row.blocker = "F10 bay occupied; cannot physically return the collected field gun."; return false
		var loaders: Array[String] = []
		for person_id in rear.actors:
			var p: Dictionary = rear.ledger.inspect_entity(person_id)
			if p.duty_id == "vehicle_works" and rear.actors[person_id].phase == "Idle" and p.health > 0 and p.position.is_equal_approx(Layout.door("dispatch")):
				loaders.append(person_id)
				if loaders.size() == 2: break
		if loaders.size() != 2: row.blocker = "Two actual F07 field-gun loaders must be present to unload/return it."; return false
		_start_task(row,"Gun Return Handling",loaders,20.0)
		row.task.gun = gun_id
		return true
	var route: Array = Layout.path(hull.position,rear.yard.PARKING_POSITIONS[row.home_slot])
	if route.is_empty(): row.blocker = "No legal real route back to promised F11 place."; return false
	row.return_phase = "Cancel"
	_start_route(row,route,"Returning")
	return true

func snapshot() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var rows: Array[Dictionary] = []
	for id in manifests:
		var row: Dictionary = manifests[id]
		var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
		var requested: Dictionary = row.cargo.duplicate(true)
		requested.people = row.passengers.size()
		requested.guns = row.guns.size()
		var committed: Dictionary = {"people":0,"guns":0}
		var staged: Dictionary = {"people":0,"guns":0}
		var onboard: Dictionary = {"people":0,"guns":0}
		for person_id in row.passengers:
			if incoming_people.has(person_id): committed.people += 1
			var p: Dictionary = rear.ledger.inspect_entity(person_id)
			if p.holder_id == row.hull: onboard.people += 1
			elif p.duty_id == "passenger:"+id and p.position.is_equal_approx(Layout.door("dispatch")): staged.people += 1
		for gun_id in row.guns:
			if weapon_promises.has(gun_id): committed.guns += 1
			if rear.ledger.inspect_entity(gun_id).holder_id == row.hull: onboard.guns += 1
		for item in row.stock_items:
			var p: Dictionary = rear.ledger.inspect_entity(item.id)
			if p.is_empty(): continue
			var claim: Dictionary = rear.ledger.inspect_claim(item.claim) if not item.claim.is_empty() else {}
			committed[item.type] = int(committed.get(item.type,0)) + int(claim.get("reserved",0))
			if p.holder_id == "dispatch" and item.stage == "Staged": staged[item.type] = int(staged.get(item.type,0)) + int(item.quantity)
			if p.holder_id == row.hull: onboard[item.type] = int(onboard.get(item.type,0)) + int(item.quantity)
		for item in row.weapon_items:
			var p: Dictionary = rear.ledger.inspect_entity(item.id)
			if weapon_promises.has(item.id): committed[item.type] = int(committed.get(item.type,0)) + 1
			if p.holder_id == "dispatch" and item.stage == "Staged": staged[item.type] = int(staged.get(item.type,0)) + 1
			if p.holder_id == row.hull: onboard[item.type] = int(onboard.get(item.type,0)) + 1
		var copy: Dictionary = row.duplicate(true)
		copy.hull_physical = hull
		copy.requested = requested
		copy.committed = committed
		copy.staged = staged
		copy.onboard = onboard
		copy.arrived = row.arrived.duplicate(true)
		copy.unloaded = row.unloaded.duplicate(true)
		copy.seats_used = hull.passengers.size()
		copy.payload_used = _payload_mass(row)
		rows.append(copy)
	return {"rows":rows,"military_people":military_people.size(),"incoming_people":incoming_people.size(),"military_hulls":military_hulls.size(),"incoming_hulls":incoming_hulls.size(),"return_places":return_places.size(),"hq_reserve":hq_reserve.size(),"hq_stock_kg":rear.ledger.inspect_entity("hq-stock").contents_mass_kg}

func _payload_mass(row: Dictionary) -> float:
	var rear: RefCounted = _rear_ref.get_ref()
	var total := 0.0
	for person_id in row.passengers:
		var p: Dictionary = rear.ledger.inspect_entity(person_id)
		if p.holder_id == row.hull: total += p.unit_mass_kg + p.contents_mass_kg
	for item in row.stock_items:
		if item.stage == "Onboard": total += item.quantity * _unit_mass(item.type)
	for item in row.weapon_items:
		if item.stage == "Onboard": total += _unit_mass(item.type)
	for gun_id in row.guns:
		if rear.ledger.inspect_entity(gun_id).holder_id == row.hull: total += 180.0
	return total

func audit() -> Array[String]:
	var rear: RefCounted = _rear_ref.get_ref()
	var errors: Array[String] = []
	if military_people.size() + incoming_people.size() > MILITARY_PEOPLE_LIMIT: errors.append("Military 384 admission overbooked")
	if military_hulls.size() + incoming_hulls.size() > MILITARY_HULL_LIMIT: errors.append("Military 24 hull admission overbooked")
	if hq_reserve.size() > HQ_RESERVE_LIMIT: errors.append("HQ Reserve 96 overbooked")
	if rear.receiving.rear_population() + rear.receiving.incoming_people() + return_places.size() > REAR_PEOPLE_LIMIT: errors.append("Rear 120 return admission overbooked")
	if rear.ledger.inspect_entity("hq-stock").contents_mass_kg > HQ_STOCK_KG + EPS: errors.append("HQ stock 20,000 kg overfilled")
	for row in manifests.values():
		var hull: Dictionary = rear.ledger.inspect_entity(row.hull)
		if hull.is_empty(): errors.append("Missing dispatch hull: "+row.id); continue
		var seats: int = 8 if hull.design_type == "T02" and not row.guns.is_empty() else int(hull.vehicle_spec.passenger_seats)
		if hull.passengers.size() > seats: errors.append("Dispatch passenger seats exceeded: "+row.id)
		if _payload_mass(row) > float(hull.vehicle_spec.payload) + EPS: errors.append("Dispatch payload exceeded: "+row.id)
		if row.state == "Complete" and row.mode == "Fleet Transfer" and hull.fleet_domain != "Military": errors.append("Transfer completed without actual hull receipt: "+row.id)
	return errors
