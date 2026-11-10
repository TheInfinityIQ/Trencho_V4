extends RefCounted
## One finite office bundle, actual hauler and physical freight on the existing clock.
const Layout = preload("res://game/staffing/rear_layout.gd")
const EPS := 0.000001
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
var _rear_ref: WeakRef
var _warehouse_dirty := true
var _warehouse_obstacles: Array[Rect2] = []
var trucks: Dictionary = {} # office ID -> actual truck/trip, retained even after retirement

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func _curb(point: Vector2, own: String = "") -> Dictionary:
	var rear := _rear()
	for offset in [Vector2.ZERO,Vector2(-4,0),Vector2(4,0),Vector2(0,-4),Vector2(0,4),Vector2(-8,0),Vector2(8,0),Vector2(0,-8),Vector2(0,8)]:
		var at: Vector2 = point+offset
		if not rear.construction.vehicle_path(at,at).is_empty() and _clear([at,at],own) and not rear.walk_path(at,point).is_empty(): return {"position":at}
	return {}

func _clear(path: Array, own: String) -> bool:
	var rear := _rear()
	if path.is_empty(): return false
	for site in rear.construction.instances.values():
		if site.kind == "park" or site.state in ["Cancelled","Dismantled"]: continue
		if rear.construction._path_hits(path,Rect2(site.center-site.size/2.0,site.size).grow(4.0)): return false
	for hull in rear.ledger.map_markers():
		if hull.kind != "CARRIER" or hull.id == own: continue
		if rear.construction._path_hits(path,Rect2(hull.position-Vector2(4,4),Vector2(8,8))): return false
	return true

func _route(start: Vector2, goal: Vector2, own: String) -> Array:
	var rear := _rear()
	var path: Array = rear.construction.vehicle_path(start,goal)
	if path.is_empty(): return []
	var rounded: Array = rear.vehicles._rounded(path,rear.vehicles._turn_radius("T01"))
	if _clear(rounded,own): return rounded
	# Tight walking-graph corners cannot turn a T01. Use the same geometry owner
	# with a wider interior corridor, joined to roadside points by clear stubs.
	var best: Array = []
	for first: Vector2 in _road_anchors(start,own):
		for last: Vector2 in _road_anchors(goal,own):
			var middle: Array = rear.construction._clearance_path(first,last,[],Rect2(),14.0)
			if middle.is_empty(): continue
			var corners: Array = [start]
			if not start.is_equal_approx(first): corners.append(first)
			corners.append_array(middle.slice(1))
			if not last.is_equal_approx(goal): corners.append(goal)
			rounded = rear.vehicles._rounded(corners,rear.vehicles._turn_radius("T01"))
			if _clear(rounded,own) and (best.is_empty() or Layout.length(rounded)<Layout.length(best)): best = rounded
	return best

func _road_anchors(point: Vector2, own: String) -> Array[Vector2]:
	var rear := _rear()
	var result: Array[Vector2] = []
	for offset in [Vector2.ZERO,Vector2(-24,0),Vector2(24,0),Vector2(0,-24),Vector2(0,24)]:
		var at: Vector2 = point+offset
		if not rear.construction._clearance_path(at,at,[],Rect2(),14.0).is_empty() and _clear([point,at],own): result.append(at)
	return result

func _register(office: Dictionary) -> bool:
	var rear := _rear()
	var id: String = office.id+"-utility-truck"
	var curb := _curb(office.door)
	if curb.is_empty():
		# A blocked office door is never a legal spawn. A remote clear rear berth
		# is allowed, with actual walking/vehicle approach still required per trip.
		for y in range(12,169,12):
			for x in range(12,229,12):
				var at := Vector2(x,y)
				if not rear.construction.vehicle_path(at,at).is_empty() and _clear([at,at],id) and not rear.walk_path(at,office.door).is_empty():
					curb = {"position":at}
					break
			if not curb.is_empty(): break
	if curb.is_empty():
		var newly_pending: bool = not trucks.has(office.id)
		trucks[office.id] = {"id":id,"office":office.id,"worker":"","phase":"Awaiting clear staging","deadline":INF,"motion":{},"blocker":"No legal truck berth; clear rear vehicle space. Foot hauling remains available.","created":false}
		return newly_pending
	var home: Vector2 = curb.position
	var place: String = id+"-home"
	rear.ledger.add_place(place,"Construction truck home for "+office.id,home)
	var added: Dictionary = rear.ledger.create_construction_truck(id,place,rear.PLAYER)
	if not added.ok:
		push_error(str(added))
		return false
	rear.vehicles.register_construction(id)
	trucks[office.id] = {"id":id,"office":office.id,"home":home,"worker":"","phase":"Parked","deadline":INF,"motion":{},"blocker":"" if not curb.is_empty() else "No clear office roadside berth; using foot hauling.","recovering":false,"loaded":0,"delivered":0,"trips":0,"distance":0.0,"burned":0.0,"created":true}
	return true

func warehouse_access_changed() -> void:
	_warehouse_dirty = true

func _source_batch(stock: Dictionary, limit: int) -> Array[Dictionary]:
	var rear := _rear()
	var result: Array[Dictionary] = []
	var candidates: Array = [stock]
	var module_id: String = rear.warehouse.stock_module(stock.id) if rear.warehouse != null else ""
	if not module_id.is_empty():
		var connected: Dictionary = rear.warehouse.connected_modules(module_id)
		for item: Dictionary in rear._stock_at(stock.holder_id,false):
			if item.id != stock.id and item.design_type == stock.design_type and item.available > 0 and connected.has(rear.warehouse.stock_module(item.id)): candidates.append(item)
	for item: Dictionary in candidates:
		var count := mini(limit,int(item.available))
		if count <= 0: continue
		result.append({"stock":str(item.id),"count":count,"claim":""})
		limit -= count
		if limit <= 0: break
	return result

func _source_curb(stock: Dictionary, own: String) -> Dictionary:
	var rear := _rear()
	var module_id: String = rear.warehouse.stock_module(stock.id) if rear.warehouse != null else ""
	if module_id.is_empty(): return _curb(stock.position,own)
	for door: Vector2 in rear.warehouse.exterior_doors(module_id):
		var curb := _curb(door,own)
		if not curb.is_empty(): return curb
	return {}

func release_source_claims(actor: Dictionary) -> void:
	var rear := _rear()
	var released := {}
	for part: Dictionary in actor.load.get("batch",[]):
		if not str(part.claim).is_empty():
			rear.ledger.release_claim(part.claim)
			released[str(part.claim)] = true
		part.claim = ""
	if not str(actor.load.get("claim","")).is_empty() and not released.has(str(actor.load.claim)): rear.ledger.release_claim(actor.load.claim)
	actor.load.claim = ""
	if rear.warehouse != null: rear.warehouse.release_point(str(actor.id))

func option(job: Dictionary, person: Dictionary, stock: Dictionary) -> Dictionary:
	var rear := _rear()
	var reason := "Foot haul: no completed Construction Office utility truck. "
	if rear.construction.instances[job.destination].state not in ["Awaiting M11","Building"]: return {"reason":"Foot haul: destination is not an unfinished site. "}
	var best: Dictionary = {}
	var worker: Dictionary = rear.ledger.inspect_entity(person.id)
	if float(worker.contents_mass_kg) >= 25.0 or not str(worker.carrying_stock_id).is_empty() or not str(worker.carrying_weapon_id).is_empty() or not str(worker.crew_station).is_empty(): return {"reason":"Foot haul: no free personal handling allowance for utility loading. "}
	for row in trucks.values():
		if rear.construction.instances[row.office].state != "Complete": continue
		reason = "Foot haul: construction truck busy or unavailable. "
		if row.phase == "Awaiting clear staging":
			reason = "Foot haul: "+str(row.blocker)+" "
			continue
		if not str(row.worker).is_empty() or row.phase != "Parked": continue
		var hull: Dictionary = rear.ledger.inspect_entity(row.id)
		if hull.health <= 0 or hull.damage_immobilized: continue
		if hull.fuel <= EPS:
			reason = "Foot haul: empty construction-truck tank. Buy M08; Vehicles > Carry purchased fuel into this tank."
			continue
		var fuel_pending := false
		for fuel_job in rear.vehicles.fuel_jobs.values():
			if fuel_job.hull == row.id: fuel_pending = true
		if fuel_pending: continue
		var from := _source_curb(stock,row.id)
		var to := _curb(rear.ledger.inspect_entity(job.destination,{},false).position,row.id)
		reason = "Foot haul: no clear construction-truck route/roadside handling point. "
		if from.is_empty() or to.is_empty(): continue
		var first := _route(hull.position,from.position,row.id)
		var cargo := _route(from.position,to.position,row.id)
		var back := _route(to.position,row.home,row.id)
		var approach: Array = rear.walk_path(person.position,hull.position)
		if first.is_empty() or cargo.is_empty() or back.is_empty() or approach.is_empty(): continue
		var distance: float = Layout.length(first)+Layout.length(cargo)+Layout.length(back)
		reason = "Foot haul: truck fuel insufficient; buy M08, then Vehicles > select construction truck > Carry purchased fuel into this tank using an available worker. "
		if hull.fuel+EPS < distance/1000.0*rear.vehicles._fuel_rate("T01")*1.25: continue
		var count: int = int(job.requested)-int(job.delivered)-rear._in_flight(job.id)
		count = mini(count,int(floor((float(hull.vehicle_spec.payload)-float(hull.contents_mass_kg))/float(stock.unit_mass_kg))))
		count = mini(count,int(floor(rear._free_space(job.destination)/float(stock.unit_mass_kg))))
		var batch := _source_batch(stock,count)
		count = 0
		for part: Dictionary in batch: count += int(part.count)
		if count <= int(floor((25.0-float(worker.contents_mass_kg))/float(stock.unit_mass_kg))):
			reason = "Foot haul: remaining available portion fits one personal carry, or bulk destination space is unavailable. "
			continue
		if not rear._valid_destination(job.destination,job.type,count*float(stock.unit_mass_kg)): continue
		if best.is_empty() or distance < float(best.distance): best = {"job":job,"stock":stock,"count":count,"batch":batch,"truck":row.office,"source_curb":from.position,"destination_curb":to.position,"first":first,"cargo_route":cargo,"back":back,"approach":approach,"distance":distance}
	return best if not best.is_empty() else {"reason":reason}

func start(actor: Dictionary, selected: Dictionary) -> void:
	var rear := _rear()
	var row: Dictionary = trucks[selected.truck]
	var retained: Dictionary = rear.ledger.retain_construction_driver(actor.id,row.id)
	if not retained.ok:
		rear._release_load(actor)
		return
	actor.load.truck = row.id
	actor.phase = "Construction truck"
	actor.motion = {}
	actor.deadline = INF
	row.worker = actor.id
	row.source_curb = selected.source_curb
	row.destination_curb = selected.destination_curb
	row.first = selected.first
	row.cargo_route = selected.cargo_route
	row.back = selected.back
	row.loaded = 0
	row.batch_index = 0
	row.delivered = 0
	row.recovering = false
	row.blocker = ""
	rear.vehicles.vehicles[row.id].state = "Construction work"
	_walk(row,"Approach truck",rear.ledger.inspect_entity(row.id).position,1.5)

func _wait(row: Dictionary, phase: String, seconds: float) -> void:
	row.phase = phase
	row.motion = {}
	row.deadline = _rear().time+seconds

func _walk(row: Dictionary, phase: String, target: Vector2, speed: float) -> void:
	var rear := _rear()
	var origin: Vector2 = rear.ledger.inspect_entity(row.worker,{},false).position
	row.phase = phase
	row.target = target
	row.speed = speed
	var path: Array = rear.walk_path(origin,target)
	row.motion = {} if path.is_empty() else {"path":path,"started":rear.time,"speed":speed,"driving":false,"distance":0.0}
	row.deadline = INF if path.is_empty() else rear.time+Layout.length(path)/speed
	if path.is_empty(): row.blocker = "Construction truck: worker route blocked; real cargo/worker retained. Clear the route."

func _drive(row: Dictionary, phase: String, path: Array) -> void:
	var rear := _rear()
	var live_hull: Dictionary = rear.ledger.inspect_entity(row.id,{},false)
	if live_hull.health <= 0 or live_hull.damage_immobilized or not _clear(path,row.id):
		_recover(row,"Vehicle route blocked; unloading safely at current truck position.")
		return
	var length: float = Layout.length(path)
	var hull: Dictionary = rear.ledger.inspect_entity(row.id)
	if hull.fuel+EPS < length/1000.0*rear.vehicles._fuel_rate("T01"):
		_recover(row,"Insufficient finite fuel; buy M08 and use Vehicles > Carry purchased fuel into this tank. Foot hauling remains available.")
		return
	row.phase = phase
	row.motion = {"path":path,"started":rear.time,"speed":rear.vehicles._drive_speed("T01"),"driving":true,"distance":0.0}
	row.deadline = rear.time+length/float(row.motion.speed)

func next_boundary() -> float:
	var next := INF
	for row in trucks.values(): next = minf(next,float(row.deadline))
	return next

func advance_to(next_time: float) -> void:
	var rear := _rear()
	for row in trucks.values():
		if row.motion.is_empty(): continue
		var motion: Dictionary = row.motion
		var length: float = Layout.length(motion.path)
		var distance: float = minf(length,maxf(0.0,next_time-float(motion.started))*float(motion.speed))
		var id: String = row.id if motion.driving else row.worker
		if motion.driving:
			var burn: float = (distance-float(motion.distance))/1000.0*rear.vehicles._fuel_rate("T01")
			var burned: Dictionary = rear.ledger.burn_vehicle_fuel(row.id,burn)
			if not burned.ok:
				row.blocker = burned.message
				row.motion = {}
				row.deadline = INF
				continue
			row.burned += burn
			row.distance += distance-float(motion.distance)
		motion.distance = distance
		rear.ledger.move_entity(id,"rear",Layout.position(motion.path,distance))

func cancel_actor(actor: Dictionary) -> void:
	for row in trucks.values():
		if row.worker != actor.id: continue
		if not row.recovering or row.phase == "Recovery blocked":
			row.recovering = false
			_recover(row,"Construction haul cancelled/reassigned or safe handoff retried; cargo remains recoverable.")
		return

func _recover(row: Dictionary, reason: String) -> void:
	if row.recovering: return
	var rear := _rear()
	var actor: Dictionary = rear.actors[row.worker]
	release_source_claims(actor)
	row.recovering = true
	row.motion = {}
	row.deadline = INF
	row.blocker = reason
	var point: Vector2 = rear.ledger.inspect_entity(row.id,{},false).position
	var pile: String = "utility-pile-%04d" % rear._next()
	rear.ledger.add_place(pile,"Recoverable construction truck cargo; physical unload",point)
	var mass := 0.0
	var count := 0
	for stock in rear._stock_at(row.id):
		mass += float(stock.quantity)*float(stock.unit_mass_kg)
		count += int(stock.quantity)
	var person: Dictionary = rear.ledger.inspect_entity(row.worker)
	if not str(person.carrying_stock_id).is_empty():
		var carried: Dictionary = rear.ledger.inspect_entity(person.carrying_stock_id)
		mass += float(carried.quantity)*float(carried.unit_mass_kg)
		count += int(carried.quantity)
	rear.stores[pile] = {"id":pile,"capacity":maxf(1.0,mass),"accessible":true,"filter":["M11"],"pile":true}
	actor.load.destination = pile
	actor.load.count = count
	actor.load.mass = mass
	var job: Dictionary = rear._job(actor.load.job)
	job.blocker = reason
	if not job.cancelled and pile not in job.recovery_sources: job.recovery_sources.append(pile)
	if person.health <= 0:
		_block(row,reason+" Actual hauler incapacitated; no replacement person granted.",true)
	elif not str(person.crew_station).is_empty():
		_wait(row,"Recovery exit",3.0)
	elif not str(person.carrying_stock_id).is_empty():
		_walk(row,"Recovery carry",point,1.2)
	else:
		_walk(row,"Recovery return",point,1.5)

func settle() -> bool:
	var rear := _rear()
	var changed := false
	var access_changed := _warehouse_dirty
	_warehouse_dirty = false
	var geometry_changed := false
	if access_changed and rear.warehouse != null:
		var actual: Array[Rect2] = rear.warehouse.obstacles()
		geometry_changed = actual != _warehouse_obstacles
		if geometry_changed: _warehouse_obstacles = actual.duplicate()

	for office in rear.construction.instances.values():
		if office.kind == "construction" and office.state == "Complete" and (not trucks.has(office.id) or not trucks[office.id].get("created",false)):
			var profile: bool = CallLog.enabled and OS.get_environment("TRENCHO_PROFILE_STAGES") == "1"
			var started: int = Time.get_ticks_usec() if profile else 0
			changed = _register(office) or changed
			if profile: CallLog.record_duration(&"construction/complete/register_truck",Time.get_ticks_usec()-started)
	for row in trucks.values():
		var office_active: bool = rear.construction.instances[row.office].state == "Complete"
		if str(row.worker).is_empty():
			if not office_active and row.phase != "Retired":
				row.phase = "Retired"
				if rear.vehicles.vehicles.has(row.id): rear.vehicles.vehicles[row.id].state = "Retired"
				changed = true
			continue
		var actor: Dictionary = rear.actors[row.worker]
		var job: Dictionary = rear._job(actor.load.job)
		var person: Dictionary = rear.ledger.inspect_person_status(row.worker)
		var hull: Dictionary = rear.ledger.inspect_entity(row.id,{},false)
		if not row.recovering and (person.health <= 0 or hull.health <= 0 or hull.damage_immobilized):
			_recover(row,"Truck or actual hauler incapacitated; stopped and retained real cargo.")
			changed = true
		if row.phase == "Recovery blocked" and row.get("resume_when_healthy",false) and person.health > 0 and person.assignment == "Rear Labour":
			row.recovering = false
			_recover(row,"Actual hauler recovered; resuming safe physical cargo handoff.")
			changed = true
		if not row.recovering and not row.motion.is_empty() and row.motion.get("driving",false) and not _clear(row.motion.path,row.id):
			_recover(row,"Vehicle access changed; stopped with real cargo retained.")
			changed = true
		if not row.motion.is_empty() and not row.motion.get("driving",false):
			var remaining_path: Array = [person.position]
			remaining_path.append_array(row.motion.path.slice(1))
			if geometry_changed:
				_walk(row,row.phase,row.target,float(row.speed))
				changed = true
			for site in rear.construction.instances.values():
				if rear.warehouse != null and rear.warehouse.modules.has(site.id): continue
				if site.kind == "park" or site.state in ["Cancelled","Dismantled"]: continue
				if rear.construction._path_hits(remaining_path,Rect2(site.center-site.size/2.0,site.size).grow(0.25)):
					_walk(row,row.phase,row.target,float(row.speed))
					changed = true
					break
		var destination_active: bool = rear.construction.instances.get(job.destination,{}).get("state","") in ["Awaiting M11","Building"]
		if not row.recovering and (not office_active or job.cancelled or person.pending_assignment != "None" or (int(actor.load.count)>0 and not destination_active) or not rear.stores[actor.load.source].accessible or not rear._valid_destination(actor.load.destination,actor.load.type,float(actor.load.mass),actor.id)):
			_recover(row,"Construction truck stopped: office/site/worker/access changed; real cargo retained for safe unloading.")
			changed = true
		if row.phase == "Load access" and access_changed:
			_next_load(row)
			changed = row.phase != "Load access" or changed
		if float(row.deadline) <= rear.time+EPS:
			row.motion = {}
			row.deadline = INF
			_finish(row)
			changed = true
		elif row.motion.is_empty() and float(row.deadline) == INF and row.has("target") and row.phase in ["Approach truck","Load approach","Carry load","Carry unload","Unload return","Return cab","Recovery return","Recovery carry"]:
			if rear.warehouse != null and not access_changed: continue
			var path: Array = rear.walk_path(rear.ledger.inspect_entity(row.worker,{},false).position,row.target)
			if not path.is_empty():
				_walk(row,row.phase,row.target,float(row.speed))
				changed = true
	return changed

func _block(row: Dictionary, message: String, resume_when_healthy: bool = false) -> void:
	row.phase = "Recovery blocked"
	row.motion = {}
	row.deadline = INF
	row.resume_when_healthy = resume_when_healthy
	row.blocker = message+" Real cargo/hauler retained. After restoring health/access, Workers / Jobs: select this person, choose Available, Reassign selected person to retry safe unloading."

func _station(row: Dictionary, entering: bool) -> bool:
	var result: Dictionary = _rear().ledger.construction_driver_station(row.worker,row.id,entering)
	if not result.ok:
		if not row.recovering: _recover(row,str(result.message))
		else: _block(row,str(result.message))
	return result.ok

func _next_load(row: Dictionary) -> void:
	var rear := _rear()
	var actor: Dictionary = rear.actors[row.worker]
	if int(row.loaded) >= int(actor.load.count):
		release_source_claims(actor)
		_wait(row,"Board delivery",3.0)
		return
	if actor.load.has("batch"):
		var part: Dictionary = actor.load.batch[int(row.batch_index)]
		actor.load.stock = str(part.stock)
		actor.load.claim = str(part.claim)
	var stock: Dictionary = rear.ledger.inspect_entity(actor.load.stock,{},false)
	var point: Vector2 = rear.stock_work_point(str(row.worker),stock,true) if rear.warehouse != null else stock.position
	if not point.is_finite() or rear.walk_path(rear.ledger.inspect_entity(row.worker,{},false).position,point).is_empty():
		row.phase = "Load access"
		row.motion = {}
		row.deadline = INF
		row.blocker = "Waiting for the reserved shelf handling face; cargo remains on its shelf."
		if rear.warehouse != null: rear.warehouse.release_point(str(row.worker))
		return
	row.blocker = ""
	_walk(row,"Load approach",point,1.5)

func _next_unload(row: Dictionary) -> void:
	var rear := _rear()
	var actor: Dictionary = rear.actors[row.worker]
	if rear._stock_at(row.id).is_empty():
		if row.recovering:
			_release(row)
		else:
			_walk(row,"Return cab",rear.ledger.inspect_entity(row.id,{},false).position,1.5)
		return
	_wait(row,"Unload pickup",2.0)

func _finish(row: Dictionary) -> void:
	var rear := _rear()
	var actor: Dictionary = rear.actors[row.worker]
	var result := {"ok":true}
	match row.phase:
		"Approach truck": _wait(row,"Board source",3.0)
		"Board source":
			if _station(row,true): _drive(row,"Drive source",_route(rear.ledger.inspect_entity(row.id).position,row.source_curb,row.id))
		"Drive source": _wait(row,"Exit load",3.0)
		"Exit load":
			if _station(row,false): _next_load(row)
		"Load approach": _wait(row,"Load pickup",2.0)
		"Load pickup":
			var person: Dictionary = rear.ledger.inspect_entity(row.worker)
			var stock: Dictionary = rear.ledger.inspect_entity(actor.load.stock)
			var count: int = mini(int(actor.load.count)-int(row.loaded),int(floor((25.0-float(person.contents_mass_kg))/float(stock.unit_mass_kg))))
			if actor.load.has("batch"): count = mini(count,int(actor.load.batch[int(row.batch_index)].count))
			result = rear.ledger.begin_carry(row.worker,actor.load.stock,count,actor.load.claim)
			if result.ok:
				actor.load.carried = result.entity_id
				if rear.warehouse != null: rear.warehouse.release_point(str(row.worker))
				_walk(row,"Carry load",rear.ledger.inspect_entity(row.id,{},false).position,1.2)
		"Carry load": _wait(row,"Load drop",2.0)
		"Load drop":
			var carried: Dictionary = rear.ledger.inspect_entity(actor.load.carried)
			result = rear.ledger.finish_carry_to_carrier(row.worker,row.id)
			if result.ok:
				row.loaded += int(carried.quantity)
				if actor.load.has("batch"):
					var part: Dictionary = actor.load.batch[int(row.batch_index)]
					part.count -= int(carried.quantity)
					if int(part.count) <= 0:
						rear.ledger.release_claim(str(part.claim))
						part.claim = ""
						actor.load.claim = ""
						row.batch_index += 1
				actor.load.carried = ""
				_next_load(row)
		"Board delivery":
			if _station(row,true): _drive(row,"Drive delivery",_route(rear.ledger.inspect_entity(row.id).position,row.destination_curb,row.id))
		"Drive delivery": _wait(row,"Exit delivery",3.0)
		"Exit delivery":
			if _station(row,false): _next_unload(row)
		"Unload pickup":
			var stock: Dictionary = rear._stock_at(row.id)[0]
			var person: Dictionary = rear.ledger.inspect_entity(row.worker)
			var count: int = mini(int(stock.available),int(floor((25.0-float(person.contents_mass_kg))/float(stock.unit_mass_kg))))
			result = rear.ledger.begin_carry(row.worker,stock.id,count)
			if result.ok:
				actor.load.carried = result.entity_id
				_walk(row,"Carry unload",rear.ledger.inspect_entity(actor.load.destination,{},false).position,1.2)
		"Carry unload": _wait(row,"Unload drop",2.0)
		"Unload drop", "Recovery deposit":
			var carried: Dictionary = rear.ledger.inspect_entity(actor.load.carried)
			result = rear.ledger.finish_carry(row.worker,actor.load.destination)
			if result.ok:
				actor.load.count -= int(carried.quantity)
				actor.load.mass -= float(carried.quantity)*float(carried.unit_mass_kg)
				actor.load.carried = ""
				var job: Dictionary = rear._job(actor.load.job)
				if not row.recovering and not job.cancelled:
					job.delivered += int(carried.quantity)
					row.delivered += int(carried.quantity)
					job.blocker = "Construction truck physical delivery %d/%d" % [job.delivered,job.requested]
				_walk(row,"Unload return",rear.ledger.inspect_entity(row.id,{},false).position,1.5)
		"Unload return", "Recovery return": _next_unload(row)
		"Return cab": _wait(row,"Board return",3.0)
		"Board return":
			if _station(row,true): _drive(row,"Drive return",_route(rear.ledger.inspect_entity(row.id).position,row.home,row.id))
		"Drive return": _wait(row,"Exit return",3.0)
		"Exit return":
			if _station(row,false):
				row.trips += 1
				_release(row)
		"Recovery exit":
			if _station(row,false): _next_unload(row)
		"Recovery carry": _wait(row,"Recovery deposit",2.0)
	if not result.ok:
		row.blocker = str(result.get("message","Physical construction truck handling blocked; cargo retained."))
		if not row.recovering: _recover(row,row.blocker)
		else: _block(row,row.blocker)

func _release(row: Dictionary) -> void:
	var rear := _rear()
	var worker: String = row.worker
	var released: Dictionary = rear.ledger.release_construction_driver(worker,row.id)
	if not released.ok:
		_block(row,str(released.message))
		return
	var actor: Dictionary = rear.actors[worker]
	release_source_claims(actor)
	actor.load = {}
	actor.phase = "Idle"
	actor.deadline = INF
	actor.motion = {}
	row.worker = ""
	row.phase = "Parked" if rear.construction.instances[row.office].state == "Complete" else "Retired"
	row.deadline = INF
	row.motion = {}
	rear.vehicles.vehicles[row.id].state = row.phase
	if not rear.ledger.person_has_duty(worker,"hauling"):
		rear._report(actor)
		if str(rear.ledger.inspect_person_status(worker).duty_id).is_empty(): rear._rebalance()
