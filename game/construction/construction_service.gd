extends RefCounted
## G05 physical rear sites. This owns facility instances, not people, stock or time.
const Layout = preload("res://game/staffing/rear_layout.gd")
const Catalog = preload("res://game/construction/construction_catalogue.gd")
const Selectable = preload("res://game/production/selectable_production.gd")
const Fixed = preload("res://game/production/fixed_production.gd")
const Heavy = preload("res://game/production/heavy_production.gd")
const EPS := 0.000001
const BOUNDS := Rect2(Vector2.ZERO,Vector2(240,180))
var _rear_ref: WeakRef
var instances: Dictionary = {}
var activities: Dictionary = {}
var office_desired: Dictionary = {"construction":0}
var office_members: Dictionary = {} # real person ID -> F12 office while serving a site
var _syncing_offices := false
var _transferring := false
var _sequence := 0

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	for kind in Layout.FACILITIES:
		var f: Array = Layout.FACILITIES[kind]
		var id: String = "initial-"+str(kind)
		instances[id] = {"id":id,"kind":kind,"center":f[1],"size":f[2],"door":f[4],
			"quarter_turn":false,"state":"Complete","protected_starter":kind in ["terminal","personnel","receiving","construction","materials"],
			"m11":int(Catalog.SPECS[kind].m11),"work":float(Catalog.SPECS[kind].work),
			"progress":float(Catalog.SPECS[kind].work),"site_store":"","blocker":"","builders":{},"haul_job":""}

func preview(kind: String, center: Vector2, quarter_turn: bool = false) -> Dictionary:
	if not Catalog.SPECS.has(kind) or bool(Catalog.SPECS[kind].get("fixed",false)):
		return _fail("F01 Terminal and F08 Personnel are fixed; choose a buildable F-series facility.")
	if not center.is_finite(): return _fail("Choose a finite rear position.")
	var size: Vector2 = Catalog.footprint(kind,quarter_turn)
	var footprint := Rect2(center-size/2.0,size)
	if not BOUNDS.encloses(footprint.grow(1.0)): return _fail("Whole building and one-metre handling edge must fit the 240 by 180 metre rear.")
	var door := center-Vector2(size.x/2.0+1.0,0)
	for row in instances.values():
		if row.state in ["Dismantled","Cancelled"] and _rear_ref.get_ref().ledger.loose_stock_mass_at(row.id) <= EPS: continue
		var other := Rect2(row.center-row.size/2.0,row.size)
		if footprint.grow(0.25).intersects(other.grow(0.25)):
			return _fail("Footprint overlaps actual %s %s." % [row.kind,row.id])
		if other.grow(0.25).has_point(door): return _fail("Entrance obstructed by an existing building.")
	var access: Array = Layout.path(Layout.door("construction"),door)
	if access.is_empty(): return _fail("No walking route from F12 builders to this entrance.")
	for row in instances.values():
		if (row.state in ["Dismantled","Cancelled"] and _rear_ref.get_ref().ledger.loose_stock_mass_at(row.id) <= EPS) or row.id.begins_with("initial-"): continue
		if _path_hits(access,Rect2(row.center-row.size/2.0,row.size).grow(0.25)):
			return _fail("New site entrance route crosses existing %s." % row.id)
	for anchor in Layout.FACILITIES:
		var path: Array = Layout.path(Layout.door("construction"),Layout.door(anchor))
		if path.is_empty() or _path_hits(path,footprint.grow(0.6)):
			return _fail("Placement closes the only accepted walking access to %s." % Layout.FACILITIES[anchor][0])
	for row in instances.values():
		if row.id.begins_with("initial-") or row.state in ["Cancelled","Dismantled"]: continue
		for anchor in ["construction","depot","receiving","dispatch"]:
			var existing_access: Array = Layout.path(row.door,Layout.door(anchor))
			if existing_access.is_empty() or _path_hits(existing_access,footprint.grow(0.6)):
				return _fail("Placement closes an existing site's walking or hauling access.")
	for pair in [["vehicle_works","park"],["vehicle_works","dispatch"]]:
		var road: Array = Layout.path(Layout.door(pair[0]),Layout.door(pair[1]))
		if road.is_empty() or _path_hits(road,footprint.grow(4.0)):
			return _fail("Placement narrows an eight-metre vehicle service road.")
	var exit_road: Array = Layout.path(Layout.door("dispatch"),Vector2(240,91))
	if exit_road.is_empty() or _path_hits(exit_road,footprint.grow(4.0)):
		return _fail("Placement narrows the eight-metre dispatch exit road.")
	if kind in ["vehicle_works","park","dispatch"]:
		var road_target: Vector2 = Layout.FACILITIES["park"][1] if kind == "vehicle_works" else (Layout.FACILITIES["vehicle_works"][1] if kind == "park" else Vector2(240,91))
		var target_id: String = "initial-park" if kind == "vehicle_works" else ("initial-vehicle_works" if kind == "park" else "")
		var road_start: Vector2 = door if kind in ["dispatch","vehicle_works"] else center
		if vehicle_path(road_start,road_target,[target_id],footprint).is_empty():
			return _fail("This facility has no eight-metre-clear vehicle connection.")
		if kind == "dispatch" and vehicle_path(Layout.FACILITIES["park"][1],door,["initial-park"],footprint).is_empty():
			return _fail("A parked hull cannot reach this F07 berth on an eight-metre-clear road.")
	return {"ok":true,"kind":kind,"center":center,"size":size,"door":door,"footprint":footprint,
		"m11":int(Catalog.SPECS[kind].m11),"work":float(Catalog.SPECS[kind].work),
		"message":"Legal bounded footprint, entrance, walking access and eight-metre vehicle roads."}

func place(kind: String, center: Vector2, quarter_turn: bool = false) -> Dictionary:
	var plan: Dictionary = preview(kind,center,quarter_turn)
	if not plan.ok: return plan
	var rear: RefCounted = _rear_ref.get_ref()
	_sequence += 1
	var id := "site-%04d" % _sequence
	var added: Dictionary = rear.ledger.add_place(id,"%s physical construction site" % Catalog.SPECS[kind].code,center)
	if not added.ok: return added
	rear.stores[id] = {"id":id,"capacity":float(plan.m11),"accessible":true,"filter":["M11"],"pile":false}
	_register_builders(id,plan.door,rear)
	instances[id] = {"id":id,"kind":kind,"center":center,"size":plan.size,"door":plan.door,
		"quarter_turn":quarter_turn,"state":"Awaiting M11","protected_starter":false,
		"m11":plan.m11,"work":plan.work,"progress":0.0,"site_store":id,
		"blocker":"Deliver %d real M11 from an accessible rear store." % plan.m11,"builders":{},"haul_job":""}
	rear._settle()
	return {"ok":true,"id":id,"message":"Site placed; footprint and access reserved. Deliver real M11 and assign up to four builders."}

func _path_hits(path: Array, box: Rect2) -> bool:
	for index in range(1,path.size()):
		var a: Vector2 = path[index-1]
		var b: Vector2 = path[index]
		if box.has_point(a) or box.has_point(b): return true
		var corners := [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
		for edge in 4:
			if Geometry2D.segment_intersects_segment(a,b,corners[edge],corners[(edge+1)%4]) != null: return true
	return false

func vehicle_path(start: Vector2, goal: Vector2, ignored: Array = [], candidate: Rect2 = Rect2()) -> Array:
	var boxes: Array[Rect2] = []
	for row in instances.values():
		if row.id in ignored or row.kind == "park" or row.state in ["Cancelled","Dismantled"]: continue
		boxes.append(Rect2(row.center-row.size/2.0,row.size).grow(4.0))
	if candidate.has_area():
		var grown: Rect2 = candidate.grow(4.0)
		if not grown.has_point(start) and not grown.has_point(goal): boxes.append(grown)
	var nodes: Array[Vector2] = [start,goal]
	for box in boxes:
		var outer: Rect2 = box.grow(0.5)
		for corner in [outer.position,Vector2(outer.end.x,outer.position.y),outer.end,Vector2(outer.position.x,outer.end.y)]:
			if BOUNDS.grow(-4.0).has_point(corner): nodes.append(corner)
	var distances: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for _node in nodes:
		distances.append(INF)
		previous.append(-1)
		visited.append(false)
	distances[0] = 0.0
	for _step in nodes.size():
		var nearest := -1
		for index in nodes.size():
			if not visited[index] and (nearest < 0 or distances[index] < distances[nearest]): nearest = index
		if nearest < 0 or distances[nearest] == INF or nearest == 1: break
		visited[nearest] = true
		for index in nodes.size():
			if visited[index] or not _vehicle_segment_clear(nodes[nearest],nodes[index],boxes): continue
			var candidate_distance: float = distances[nearest]+nodes[nearest].distance_to(nodes[index])
			if candidate_distance < distances[index]:
				distances[index] = candidate_distance
				previous[index] = nearest
	if distances[1] == INF: return []
	var result: Array = [goal]
	var cursor := 1
	while cursor != 0:
		cursor = previous[cursor]
		result.push_front(nodes[cursor])
	return result

func _vehicle_segment_clear(start: Vector2, goal: Vector2, boxes: Array[Rect2]) -> bool:
	var road_bounds: Rect2 = BOUNDS.grow(-4.0)
	if not (road_bounds.has_point(start) or start == Vector2(240,91)) or not (road_bounds.has_point(goal) or goal == Vector2(240,91)): return false
	for box in boxes:
		if _path_hits([start,goal],box): return false
	return true

func parking_owner(slot: int) -> String:
	if slot < 4: return "initial-park"
	for row in instances.values():
		if row.kind == "park" and slot in row.get("parking_slots",[]): return row.id
	return ""

func snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	for row in instances.values(): rows.append(row.duplicate(true))
	return {"rows":rows,"time":_rear_ref.get_ref().time}

func audit() -> Array[String]:
	var errors: Array[String] = []
	for row in instances.values():
		if row.progress < -EPS or row.progress > row.work+EPS: errors.append("Construction work out of bounds "+row.id)
	return errors

func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func _register_builders(id: String, door: Vector2, rear: RefCounted) -> void:
	var duty := "builders-" + id
	rear.ledger.add_place("duty-" + duty, "F12 builders at " + id, door)
	rear.requests[duty] = {"id":duty,"target":0,"positions":4,"priority":1,"created":rear.time,"order":rear._next(),"place":"duty-" + duty,"manual":true}

func order_materials(id: String, source: String, priority: int = 1) -> Dictionary:
	if not instances.has(id): return _fail("Choose an actual construction site.")
	var row: Dictionary = instances[id]
	if row.state != "Awaiting M11": return _fail("Only an awaiting site can request its build materials.")
	var rear: RefCounted = _rear_ref.get_ref()
	if not rear.stores.has(source) or source == id: return _fail("Choose an actual separate M11 store.")
	var local: int = rear.ledger.available_stock_at(id,"M11")
	var in_flight := 0
	for job in rear.jobs:
		if job.destination == id and job.type == "M11" and not job.cancelled: in_flight += maxi(0,int(job.requested)-int(job.delivered))
	var needed: int = maxi(0,int(row.m11)-local-in_flight)
	if needed == 0: return _fail("The complete M11 delivery is already here or committed.")
	var result: Dictionary = rear.request_haul(source,id,"M11",needed,priority)
	if result.ok: row.haul_job = result.id
	return result

func is_office(id: String) -> bool:
	return id == "construction" or (instances.has(id) and instances[id].kind == "construction" and instances[id].state == "Complete")

func _site_members(id: String) -> Array[String]:
	var rear: RefCounted = _rear_ref.get_ref()
	var members: Array[String] = []
	for person_id in office_members:
		var person: Dictionary = rear.ledger.inspect_entity(person_id)
		if person.duty_id == "builders-"+id or person.pending_duty == "builders-"+id: members.append(person_id)
	members.sort()
	return members

func _office_site_count(office: String) -> int:
	var count := 0
	var rear: RefCounted = _rear_ref.get_ref()
	for person_id in office_members:
		if office_members[person_id] == office and rear.ledger.inspect_entity(person_id).duty_id.begins_with("builders-"): count += 1
	return count

func _sync_office(office: String, priority: int = 1) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var request: Dictionary = rear.requests[office]
	request.target = maxi(0,int(office_desired.get(office,0))-_office_site_count(office))
	request.priority = priority
	request.created = rear.time
	request.order = rear._next()
	rear._rebalance()

func set_office_staff(office: String, count: int, priority: int = 1) -> Dictionary:
	if not is_office(office) or count < 0 or count > 4: return _fail("Choose a complete F12 and zero to four real office builders.")
	var rear: RefCounted = _rear_ref.get_ref()
	var assigned: Array[String] = []
	for person_id in office_members:
		if office_members[person_id] == office and rear.ledger.inspect_entity(person_id).duty_id.begins_with("builders-"): assigned.append(person_id)
	assigned.sort()
	while assigned.size() > count:
		var person_id: String = assigned.pop_back()
		var site: String = str(rear.ledger.inspect_entity(person_id).duty_id).trim_prefix("builders-")
		rear.requests["builders-"+site].target = maxi(0,int(rear.requests["builders-"+site].target)-1)
		_transferring = true
		rear.reassign_person(person_id,office)
		_transferring = false
		office_members.erase(person_id)
	office_desired[office] = count
	_sync_office(office,priority)
	rear._settle()
	return {"ok":true,"message":"F12 builder staffing recorded; these same people may travel to sites."}

func _release_site_builders(id: String) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	for person_id in _site_members(id):
		var office: String = office_members[person_id]
		_transferring = true
		rear.reassign_person(person_id,office)
		_transferring = false
		office_members.erase(person_id)
		_sync_office(office)
	rear.requests["builders-"+id].target = 0

func set_builders(id: String, count: int, priority: int = 1) -> Dictionary:
	if not instances.has(id) or count < 0 or count > 4: return _fail("Choose an actual site and zero to four builders.")
	var row: Dictionary = instances[id]
	if row.state not in ["Awaiting M11","Building","Clearing","Dismantling"]: return _fail("This site has no active construction duty.")
	var rear: RefCounted = _rear_ref.get_ref()
	var members: Array[String] = _site_members(id)
	while members.size() > count:
		var person_id: String = members.pop_back()
		var office: String = office_members[person_id]
		_transferring = true
		rear.reassign_person(person_id,office)
		_transferring = false
		office_members.erase(person_id)
		_sync_office(office)
	var needed: int = count-members.size()
	var candidates: Array[Dictionary] = []
	for office in office_desired:
		if not is_office(office): continue
		for person_id in rear.actors:
			var person: Dictionary = rear.ledger.inspect_entity(person_id)
			if person.duty_id == office and person.pending_assignment == "None" and rear.actors[person_id].phase == "Idle":
				candidates.append({"person":person_id,"office":office})
	if candidates.size() < needed: return _fail("Staff an F12 office with enough actual available builders before assigning this site.")
	for index in needed:
		var chosen: Dictionary = candidates[index]
		_transferring = true
		var result: Dictionary = rear.reassign_person(chosen.person,"builders-"+id)
		_transferring = false
		if not result.ok: return result
		office_members[chosen.person] = chosen.office
		_sync_office(chosen.office)
	rear.requests["builders-"+id].target = count
	rear.requests["builders-"+id].priority = priority
	rear._settle()
	return {"ok":true,"message":"Same actual F12 staff travel to this site; at most four work here."}

func on_builder_reassigned(person_id: String, former_duty: String) -> void:
	if not office_members.has(person_id) or not former_duty.begins_with("builders-"): return
	var office: String = office_members[person_id]
	office_members.erase(person_id)
	var rear: RefCounted = _rear_ref.get_ref()
	if rear.requests.has(former_duty): rear.requests[former_duty].target = maxi(0,int(rear.requests[former_duty].target)-1)
	_sync_office(office)

func cancel(id: String) -> Dictionary:
	if not instances.has(id): return _fail("Choose an actual site.")
	var row: Dictionary = instances[id]
	if row.state not in ["Awaiting M11","Building"]: return _fail("Only unfinished construction can be cancelled.")
	var rear: RefCounted = _rear_ref.get_ref()
	_stop_haul(row,rear)
	_release_site_builders(id)
	row.state = "Cancelled"
	row.blocker = "Cancelled; delivered M11 is recoverable at this site."
	_return_site_stock(row,rear)
	return {"ok":true,"message":"Cancelled; half the build M11 was consumed only if work began. Remaining real M11 returns by hauling."}

func _stop_haul(row: Dictionary, rear: RefCounted) -> void:
	for job in rear.jobs:
		if job.destination == row.id and not job.cancelled and job.delivered < job.requested:
			rear.cancel_job(job.id)

func _return_site_stock(row: Dictionary, rear: RefCounted) -> void:
	for stock in rear._stock_at(row.id):
		if stock.design_type == "M11" and stock.available > 0:
			rear.request_haul(row.id,"depot","M11",stock.available)

func _workers(row: Dictionary) -> int:
	var rear: RefCounted = _rear_ref.get_ref()
	return mini(4,rear._present("builders-"+row.id))

func _ready(row: Dictionary) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	return rear.ledger.available_stock_at(row.id,"M11") >= int(row.m11) and _workers(row) > 0

func next_boundary() -> float:
	var rear: RefCounted = _rear_ref.get_ref()
	var next := INF
	for row in instances.values():
		if row.state in ["Building","Dismantling"] and _workers(row) > 0 or (row.state == "Awaiting M11" and _ready(row)):
			var required: float = 20.0 if row.state == "Dismantling" else float(row.work)
			next = minf(next,rear.time+(required-float(row.progress))/_workers(row))
	return next

func advance_work(delta: float) -> void:
	if delta <= 0.0: return
	var rear: RefCounted = _rear_ref.get_ref()
	for row in instances.values():
		if row.state == "Awaiting M11" and _ready(row):
			# The first earned work consumes floor(M11/2); the other half stays local.
			var result: Dictionary = rear.ledger.consume_local_batch(row.id,rear.PLAYER,{"M11":int(row.m11)/2},"Started "+row.id)
			if result.ok:
				row.state = "Building"
				row.blocker = ""
		if row.state in ["Building","Dismantling"] and _workers(row) > 0:
			var required: float = 20.0 if row.state == "Dismantling" else float(row.work)
			row.progress = minf(required,float(row.progress)+delta*_workers(row))
			if (required-float(row.progress))/_workers(row) <= EPS: row.progress = required

func advance_to(_next_time: float) -> void:
	pass

func settle() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var changed := false
	for row in instances.values():
		if row.state == "Clearing":
			_queue_clearance(row,rear)
			if _cleared(row,rear):
				row.state = "Dismantling"
				row.blocker = "Assign up to four builders for twenty work seconds."
				changed = true
		if row.state == "Building" and float(row.progress) >= float(row.work)-EPS:
			var remaining: int = int(row.m11)-int(row.m11)/2
			var result: Dictionary = rear.ledger.consume_local_batch(row.id,rear.PLAYER,{"M11":remaining},"Completed "+row.id)
			if not result.ok: continue
			row.state = "Complete"
			row.blocker = ""
			_release_site_builders(row.id)
			_activate(row,rear)
			changed = true
		elif row.state == "Dismantling" and float(row.progress) >= 20.0-EPS:
			row.state = "Dismantled"
			for key in ["input_store","output_store"]:
				var store_id: String = row.get(key,"")
				if not store_id.is_empty():
					rear.stores[store_id].accessible = false
					rear.stores[store_id].capacity = 0.0
			if activities.has(row.id):
				rear.additional_productions.erase(activities[row.id])
				activities.erase(row.id)
			if rear.requests.has(row.id):
				rear.requests[row.id].target = 0
				rear.requests[row.id].positions = 0
			row.blocker = ""
			_release_site_builders(row.id)
			var salvage: int = int(row.m11)/2
			if salvage > 0:
				rear.ledger.add_stock(row.id+"-salvage","M11",salvage,1.0,row.id,rear.PLAYER)
				_return_site_stock(row,rear)
			changed = true
	return changed

func _activate(row: Dictionary, rear: RefCounted) -> void:
	var spec: Dictionary = Catalog.SPECS[row.kind]
	var duty: String = row.id
	if Layout.FACILITIES[row.kind][3] > 0:
		rear.ledger.add_place("duty-"+duty,row.kind+" copy staff entrance",row.door)
		rear.requests[duty] = {"id":duty,"target":0,"positions":Layout.FACILITIES[row.kind][3],"priority":1,"created":rear.time,"order":rear._next(),"place":"duty-"+duty}
	for role in ["input","output"]:
		var key: String = str(role)+"_kg"
		if spec.has(key):
			var store_id: String = row.id+"-"+role
			rear.ledger.add_place(store_id,row.kind+" copy "+role+" store",row.door)
			rear.stores[store_id] = {"id":store_id,"capacity":float(spec[key]),"accessible":true,"filter":[],"pile":false}
			row[role+"_store"] = store_id
	if row.kind == "training": rear.training.add_training_site(row.id,row.center,row.id)
	if row.kind == "construction": office_desired[row.id] = 0
	if row.kind == "park": row.parking_slots = rear.yard.add_park(row.center)
	if row.kind == "receiving":
		rear.receiving.add_freight_berth(row.id,row.output_store,row.door-Vector2(2,0),row.id,row.door)
	if row.kind == "dispatch": rear.dispatch.add_dispatch_site(row.id,row.output_store,row.id,row.door)
	if row.kind == "vehicle_works":
		var bay: String = row.id+"-bay"
		var overrides := {"duty":row.id,"facility":spec.code,"input_store":row.input_store,
			"output_store":bay,"door":row.door,"bay_position":row.center}
		var activity: RefCounted = Heavy.new(rear,rear.heavy_production._declared_access,overrides)
		activity.mode = "Stock target"
		rear.additional_productions.append(activity)
		activities[row.id] = activity
	if row.kind in ["workshop","munitions","support","materials"]:
		var recipe: String = {"workshop":"R01","munitions":"R02","support":"R11","materials":"R26"}[row.kind]
		var overrides := {"duty":row.id,"facility":spec.code,
			"input_store":row.input_store,"output_store":row.output_store}
		var activity: RefCounted
		if row.kind == "materials":
			activity = Fixed.new(rear,recipe,overrides)
		else:
			var original: RefCounted = {"workshop":rear.production,"munitions":rear.munitions_production,"support":rear.support_production}[row.kind]
			activity = Selectable.new(rear,recipe,original._choices,original._essential,original._declared_access,overrides)
		activity.mode = "Stock target"
		rear.additional_productions.append(activity)
		activities[row.id] = activity

func request_dismantle(id: String) -> Dictionary:
	if not instances.has(id): return _fail("Choose an actual facility.")
	var row: Dictionary = instances[id]
	if row.state != "Complete" or row.protected_starter: return _fail("Protected starter or unfinished facility cannot be dismantled.")
	var rear: RefCounted = _rear_ref.get_ref()
	if row.kind == "receiving" and (rear.receiving.berth_committed(id) or rear.receiving.freight_admitted() > rear.receiving.freight_limit()-1):
		return _fail("This F02 berth is required by a committed supplier vehicle.")
	if row.kind == "training" and (rear.training.site_busy(id) or rear.training._unfinished().size() > rear.training.snapshot().student_places-12):
		return _fail("Reserved or present students still need this F06 capacity.")
	if row.kind == "dispatch" and rear.dispatch.site_committed(id):
		return _fail("This F07 berth has an active manifest or returning vehicle.")
	if row.kind == "construction" and (_office_site_count(id) > 0 or rear._committed(id) > 0):
		return _fail("Return or reassign this F12 office's actual builders before dismantling.")
	if row.kind == "park":
		for slot in row.get("parking_slots",[]):
			if not rear.yard.occupied[slot].is_empty() or not rear.yard.reserved[slot].is_empty():
				return _fail("F11 has an occupied or promised parking place.")
	for activity in rear._production_activities():
		if activity._spec.duty == id and not activity.batch.is_empty():
			return _fail("A live production batch must finish or be cancelled before dismantling.")
		if activity._spec.duty == id and activity.has_method("accept_order") and (not activity._order.is_empty() or not activity.bay_occupant.is_empty()):
			return _fail("An accepted heavy order or physical output still occupies this F10 bay.")
	for key in ["input_store","output_store"]:
		var store_id: String = row.get(key,"")
		if store_id.is_empty(): continue
		if rear._reserved_space(store_id) > EPS:
			return _fail("Stored goods have an active destination or output promise.")
		for job in rear.jobs:
			if not job.cancelled and job.destination == store_id and job.delivered < job.requested:
				return _fail("An active haul still promises goods to this facility.")
	if not rear.requests.has("builders-"+id): _register_builders(id,row.door,rear)
	if activities.has(id): activities[id].enabled = false
	if rear.requests.has(id): rear.set_target(id,0)
	if row.kind == "receiving": rear.receiving.remove_freight_berth(id)
	if row.kind == "dispatch": rear.dispatch.remove_dispatch_site(id)
	if row.kind == "training": rear.training.retire_training_site(id)
	if row.kind == "park": rear.yard.retire_park(row.get("parking_slots",[]))
	if row.kind == "construction": office_desired.erase(id)
	row.state = "Clearing"
	row.progress = 0.0
	row.blocker = "Stored goods must be hauled out before twenty builder work seconds."
	_queue_clearance(row,rear)
	rear._settle()
	return {"ok":true,"message":"Dismantle requested; stored goods return by real hauling, then builders work twenty seconds."}

func _queue_clearance(row: Dictionary, rear: RefCounted) -> void:
	for key in ["input_store","output_store"]:
		var store_id: String = row.get(key,"")
		if store_id.is_empty(): continue
		var available_by_type: Dictionary = {}
		for stock in rear._stock_at(store_id):
			if stock.available > 0:
				available_by_type[stock.design_type] = int(available_by_type.get(stock.design_type,0)) + int(stock.available)
		for type in available_by_type:
			var already := 0
			for job in rear.jobs:
				if job.source == store_id and job.type == type and not job.cancelled:
					already += maxi(0,int(job.requested)-int(job.delivered))
			var needed: int = maxi(0,int(available_by_type[type])-already)
			if needed > 0: rear._queue_haul(store_id,"depot",type,needed,1)

func _cleared(row: Dictionary, rear: RefCounted) -> bool:
	for key in ["input_store","output_store"]:
		var store_id: String = row.get(key,"")
		if store_id.is_empty(): continue
		if rear.ledger.loose_stock_mass_at(store_id) > EPS or rear._reserved_space(store_id) > EPS: return false
	return true
