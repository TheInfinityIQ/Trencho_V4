extends RefCounted
## G22 actual D01-D03 objects, per-side observations and timed engineer work.
const Catalogue = preload("res://game/mines/device_catalogue.gd")
const EPS := 0.000001
const LIVE := ["Placed","Arming","Armed","Waiting","Fusing"]
var _rear_ref: WeakRef
var projects: Dictionary = {}
var knowledge: Dictionary = {}
var tasks: Dictionary = {}
var events: Array[Dictionary] = []
var _sequence := 0
var _claim_sequence := 0
var _handling_move := false

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	rear.ledger.entity_moved.connect(_on_moved)
	rear.ledger.route_hazard = route_blocker

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func _device(id: String) -> Dictionary:
	return projects.get(id,_rear().demolition.projects.get(id,{}))

func _devices() -> Array:
	return projects.values()+_rear().demolition.projects.values()

func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func _qualified_engineer(id: String) -> bool:
	var p: Dictionary = _rear().ledger.inspect_entity(id)
	return p.get("kind","") == "PERSON" and p.qualification == "P02" and p.health > 0 and p.assignment not in ["Wounded","Recovery","Dead","Training","Rear Labour"] and _rear().military._held(id,"E08") > 0

func _engineer(id: String) -> bool:
	if not _qualified_engineer(id): return false
	var p: Dictionary = _rear().ledger.inspect_entity(id)
	return p.crew_station.is_empty() and _rear().ledger.inspect_entity(p.holder_id).get("kind","") == "PLACE"

func engineer_committed(id: String) -> bool:
	if tasks.has(id): return true
	for row in projects.values():
		if row.state == "Placing" and row.engineer == id: return true
	return false

func _busy(id: String) -> bool:
	if _rear().recovery != null and _rear().recovery.workers.has(id): return true
	return engineer_committed(id) or _rear().demolition.engineer_committed(id) or _rear().bridges.engineer_committed(id) or _rear().field_structures.engineer_committed(id)

func spacing_clear(point: Vector2) -> bool:
	for row in projects.values():
		if row.state not in ["Cancelled","Inert","Detonated"] and row.position.distance_to(point) < 4.0-EPS: return false
	for row in _rear().demolition.projects.values():
		if row.state not in ["Cancelled","Inert","Detonated"] and row.position.distance_to(point) < 4.0-EPS: return false
	return true

func remote_slot_blocker(squad: String, except_id: String = "") -> String:
	for row in projects.values():
		if row.id != except_id and row.squad == squad and row.code == "D03" and row.state not in ["Cancelled","Inert","Detonated"]: return "Squad remote slot reserved by "+row.id
	return ""

func order(code: String, point: Vector2, squad_id: String, engineer: String, plan: Dictionary = {}) -> Dictionary:
	var squad: Dictionary = _rear().military.squads.get(squad_id,{})
	if not Catalogue.TYPES.has(code) or not point.is_finite() or squad.get("kind","") != "Engineer" or squad.state != "Active" or engineer not in squad.roster or not _engineer(engineer) or _busy(engineer): return _fail("An active Engineer squad must assign a free actual P02 with E08.")
	if not _rear().combat.world.support(Vector2i(floori(point.x),floori(point.y)),0).ok or not spacing_clear(point): return _fail("Placement needs accessible ground and four metres between devices.")
	var owner: String = _rear().ledger.inspect_entity(engineer).owner
	var count := 0
	for row in projects.values():
		if row.owner == owner and row.code != "D03" and row.state not in ["Cancelled","Inert","Detonated"]: count += 1
	if code != "D03" and count >= 96: return _fail("Army pressure-device cap is 96, including committed placements.")
	if code == "D03":
		var blocker: String = _rear().demolition.remote_slot_blocker(squad_id)
		if not blocker.is_empty(): return _fail(blocker)
	var context := {"approach":{},"friendly_corridor":plan.get("friendly_corridor",[]).duplicate(),"retreat_route":plan.get("retreat_route",[]).duplicate(),"consequences":"Global route choice remains with world/command integration; supplied passages are protected from this device's thirty-metre exclusion."}
	for key in ["friendly_corridor","retreat_route"]:
		var path: Array = context[key]
		for i in range(1,path.size()):
			if _distance(point,path[i-1],path[i]) <= 30.0+EPS: return _fail("Device would obstruct its supplied friendly corridor or retreat alternative.")
	var threat: Dictionary = _rear().ledger.inspect_entity(str(plan.get("approach_vehicle","")))
	var observer: Dictionary = _rear().ledger.inspect_entity(engineer)
	if not threat.is_empty() and threat.kind == "CARRIER" and threat.owner != owner and _rear().combat.world.observe(observer.position,threat.position).visible:
		context.approach = {"class":threat.design_type,"position":threat.position,"observed_by":engineer,"observed_at":_rear().time}
	_sequence += 1
	var id := "device-%04d" % _sequence
	var spec: Dictionary = Catalogue.TYPES[code]
	_rear().ledger.add_place(id,"Physical field-device site",point)
	projects[id] = {"id":id,"code":code,"kind":code,"position":point,"place":id,"squad":squad_id,"engineer":engineer,"owner":owner,"order_context":context,"state":"Placing","progress":0.0,"work_required":spec.work,"m06_reserved":spec.m06,"m06_consumed":0,"claims":[],"receipt":[],"health":0,"armed_at":INF,"controller":"","blocked_reason":"Actual M06 and engineer must reach site."}
	return {"ok":true,"id":id}

func _access(row: Dictionary) -> Dictionary:
	var p: Dictionary = _rear().ledger.inspect_entity(row.engineer)
	if not _engineer(row.engineer) or p.position.distance_to(row.position) > 2.0+EPS: return _fail("Assigned available P02 with E08 must stand within two metres.")
	var squad: Dictionary = _rear().military.squads.get(row.squad,{})
	if squad.get("state","") != "Active" or row.engineer not in squad.roster: return _fail("Assigned squad is no longer active.")
	for other in _rear().ledger.snapshot().entities:
		if other.kind in ["PERSON","CARRIER"] and other.get("health",100) > 0 and other.owner != row.owner and other.owner in ["army-blue","army-red"] and other.position.distance_to(row.position) <= 150.0 and _rear().combat.world.observe(row.position,other.position).visible: return _fail("Observed hostile within 150 metres stops placement.")
	if _committed(row) != row.m06_reserved: return _fail("Full physical M06 batch must be exclusively committed within ten metres.")
	return {"ok":true}

func cancel(id: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.get("state","") != "Placing": return _fail("Only unplaced work cancels; a planted device stays physical.")
	_release_material(row)
	row.state = "Cancelled"
	return {"ok":true}

func observe_placement(id: String, observer: String) -> Dictionary:
	var row: Dictionary = _device(id)
	var p: Dictionary = _rear().ledger.inspect_entity(observer)
	if row.is_empty() or row.state not in ["Placing","Arming"] or p.get("kind","") != "PERSON" or p.health <= 0 or not _rear().combat.world.observe(p.position,row.position).visible: return _fail("A living ground observer needs current sight of actual placement or its arming delay; buried armed mines need a scan.")
	if row.state == "Placing" and row.progress <= EPS: return _fail("An unworked order has no physical placement to observe.")
	_known(row,p.owner)
	return {"ok":true}

func _known(row: Dictionary, owner: String) -> void:
	if not knowledge.has(owner): knowledge[owner] = {}
	knowledge[owner][row.id] = {"id":row.id,"code":row.get("code",row.kind),"position":row.position,"state":row.state,"hazard":row.state != "Inert","observed_at":_rear().time}
	if owner == row.owner and row.state != "Inert": _rear().orders.report(row.squad,"Mine Hazard","Known device "+row.id+"; preserve friendly corridor and request sweep or another route.",true)
	for manifest in _rear().dispatch.manifests.values():
		if manifest.state != "Transit": continue
		var hull: Dictionary = _rear().ledger.inspect_entity(manifest.hull)
		if hull.owner != owner: continue
		var reason: String = route_blocker(owner,manifest.route)
		if not reason.is_empty(): _rear().dispatch.report_route_hazard(manifest.id,reason)

func inspect_known(owner: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row in knowledge.get(owner,{}).values(): rows.append(row.duplicate(true))
	return rows

func route_blocker(owner: String, points: Array) -> String:
	for marker in knowledge.get(owner,{}).values():
		if not marker.hazard: continue
		for i in range(1,points.size()):
			if _distance(marker.position,points[i-1],points[i]) <= 30.0+EPS: return "Observed mine hazard within thirty metres; stop, request engineer sweep or another route."
	return ""

func _distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var delta := finish-start
	return point.distance_to(start+delta*clampf((point-start).dot(delta)/maxf(delta.length_squared(),EPS),0.0,1.0))

func start_scan(engineer: String) -> Dictionary:
	if not _engineer(engineer) or _busy(engineer): return _fail("Stationary scanning needs a free P02 with E08.")
	var p: Dictionary = _rear().ledger.inspect_entity(engineer)
	tasks[engineer] = {"kind":"Scan","position":p.position,"progress":0.0,"required":3.0,"owner":p.owner,"target":""}
	return {"ok":true}

func start_disarm(id: String, engineer: String) -> Dictionary:
	var p: Dictionary = _rear().ledger.inspect_entity(engineer)
	var row: Dictionary = _device(id)
	if not _engineer(engineer) or _busy(engineer) or row.get("state","") not in LIVE or not knowledge.get(p.owner,{}).has(id) or p.position.distance_to(row.position) > 2.0+EPS: return _fail("Disarm needs a revealed device and free equipped P02 within two metres.")
	tasks[engineer] = {"kind":"Disarm","position":p.position,"progress":0.0,"required":12.0,"owner":p.owner,"target":id}
	return {"ok":true}

func cancel_task(engineer: String) -> Dictionary:
	tasks.erase(engineer)
	return {"ok":true}

func _task_ready(engineer: String, task: Dictionary) -> bool:
	if not _engineer(engineer): return false
	var p: Dictionary = _rear().ledger.inspect_entity(engineer)
	if task.kind == "Scan": return p.position.is_equal_approx(task.position)
	var row: Dictionary = _device(task.target)
	return row.get("state","") in LIVE and p.position.distance_to(row.position) <= 2.0+EPS

func damage_device(id: String, amount: int, observer: String) -> Dictionary:
	var row: Dictionary = _device(id)
	var p: Dictionary = _rear().ledger.inspect_entity(observer)
	if row.get("state","") not in LIVE or amount <= 0 or p.get("kind","") != "PERSON" or not knowledge.get(p.owner,{}).has(id) or not _rear().combat.world.observe(p.position,row.position).visible: return _fail("Deliberate damage needs a revealed currently observed device and positive actual damage.")
	row.health = maxi(0,int(row.health)-amount)
	if row.health == 0: _inert(row,p.owner)
	return {"ok":true,"health":row.health}

func _inert(row: Dictionary, owner: String) -> void:
	row.health = 0
	row.state = "Inert"
	row.controller = ""
	if row.kind == "D04": row.mode = ""
	row.blocked_reason = "Inert; no M06 recovered and no sympathetic blast."
	_known(row,owner)
	# Clearance only reaches other sides through actual observation/reporting.

func observe_clearance(id: String, observer: String) -> Dictionary:
	var row: Dictionary = _device(id)
	var p: Dictionary = _rear().ledger.inspect_entity(observer)
	if row.get("state","") not in ["Inert","Detonated"] or p.get("kind","") != "PERSON" or p.health <= 0 or not _rear().combat.world.observe(p.position,row.position).visible: return _fail("Clearance information needs an actual observer.")
	_known(row,p.owner)
	knowledge[p.owner][row.id].hazard = false
	return {"ok":true}

func set_controller(id: String, engineer: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.get("code","") != "D03" or row.state not in LIVE or not _operator(row,engineer): return _fail("D03 needs a living squad P02 with E08 within 300 metres.")
	row.controller = engineer
	return {"ok":true}

func _operator(row: Dictionary, engineer: String) -> bool:
	var p: Dictionary = _rear().ledger.inspect_entity(engineer)
	return _qualified_engineer(engineer) and engineer in _rear().military.squads.get(row.squad,{}).get("roster",[]) and p.owner == row.owner and p.position.distance_to(row.position) <= 300.0+EPS

func remote_trigger(id: String, vehicle: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	var hull: Dictionary = _rear().ledger.inspect_entity(vehicle)
	if row.get("code","") != "D03" or row.state != "Armed" or not _operator(row,row.controller): return _fail("An armed D03 needs its current qualified operator.")
	var p: Dictionary = _rear().ledger.inspect_entity(row.controller)
	if hull.get("kind","") != "CARRIER" or not hull.has("vehicle_spec") or hull.health <= 0 or hull.owner == row.owner or not _rear().combat.world.observe(p.position,hull.position).visible or _footprint_distance(row.position,hull.position,hull.position,hull,deg_to_rad(float(hull.get("facing_degrees",0.0)))) > 3.0+EPS: return _fail("Operator needs an actually observed hostile vehicle inside the designated six-metre trigger zone.")
	for entity in _rear().ledger.snapshot().entities:
		if entity.get("owner","") == row.owner and entity.kind in ["PERSON","CARRIER"] and (entity.get("assignment","") != "Dead" if entity.kind == "PERSON" else entity.get("health",100) > 0) and entity.position.distance_to(row.position) <= 11.0+EPS: return _fail("Known friendly within blast plus five metres withholds D03.")
	_detonate(row,vehicle)
	return {"ok":true}

func _footprint_distance(point: Vector2, start: Vector2, finish: Vector2, hull: Dictionary, facing: float) -> float:
	var direction := (finish-start).normalized() if start.distance_to(finish) > EPS else Vector2.from_angle(facing)
	var normal := direction.orthogonal()
	var relative := point-start
	var length := start.distance_to(finish)
	var half: Vector2 = hull.vehicle_spec.footprint*0.5
	var along := relative.dot(direction)
	var across := absf(relative.dot(normal))
	return Vector2(maxf(maxf(-half.x-along,along-length-half.x),0.0),maxf(across-half.y,0.0)).length()

func _contact_fraction(row: Dictionary, entity: Dictionary, start: Vector2, finish: Vector2) -> float:
	var low := 0.0
	var high := 1.0
	for iteration in 24:
		var middle: float = (low+high)*0.5
		var contact: bool = _footprint_distance(row.position,start,start.lerp(finish,middle),entity,(finish-start).angle()) <= 1.5+EPS if row.code == "D02" else _distance(row.position,start,start.lerp(finish,middle)) <= 1.0+EPS
		if contact: high = middle
		else: low = middle
	return high

func movement_limit(hull_id: String, start: Vector2, finish: Vector2) -> float:
	# Physical collision prediction, never exposed as the driver's hidden-device knowledge.
	# The mover burns only this travelled portion before the synchronous damage boundary.
	if start.is_equal_approx(finish): return 1.0
	var hull: Dictionary = _rear().ledger.inspect_entity(hull_id)
	if not hull.has("vehicle_spec"): return 1.0
	var fraction := 1.0
	for row in projects.values():
		if row.state == "Armed" and row.code == "D02" and _footprint_distance(row.position,start,finish,hull,(finish-start).angle()) <= 1.5+EPS:
			fraction = minf(fraction,_contact_fraction(row,hull,start,finish))
	return fraction

func _on_moved(id: String, start: Vector2, finish: Vector2) -> void:
	if _handling_move or start.is_equal_approx(finish): return
	if tasks.has(id) and tasks[id].kind == "Scan": tasks[id].progress = 0.0; tasks[id].position = finish
	var entity: Dictionary = _rear().ledger.inspect_entity(id)
	for row in projects.values():
		if row.state != "Armed" or row.code == "D03": continue
		entity = _rear().ledger.inspect_entity(id)
		if entity.get("health",100) <= 0: break
		var touched := false
		if row.code == "D01" and entity.kind == "PERSON" and _rear().ledger.inspect_entity(entity.holder_id).get("kind","") != "CARRIER": touched = _distance(row.position,start,finish) <= 1.0+EPS
		if row.code == "D02" and entity.kind == "CARRIER" and entity.has("vehicle_spec"): touched = _footprint_distance(row.position,start,finish,entity,(finish-start).angle()) <= 1.5+EPS
		if touched:
			# Commit contact position before blast, including a coarse timed movement step.
			var fraction: float = _contact_fraction(row,entity,start,finish)
			_handling_move = true
			_rear().ledger.move_entity(id,entity.holder_id,start.lerp(finish,fraction))
			_detonate(row,id)
			_handling_move = false
			break

func _detonate(row: Dictionary, trigger_id: String = "") -> void:
	row.state = "Detonated"
	row.health = 0
	row.controller = ""
	row.blocked_reason = "Detonated once; surrounding route hazard needs actual sweep/clearance observation."
	var spec: Dictionary = Catalogue.TYPES[row.code]
	var snapshot: Array = _rear().ledger.snapshot().entities
	var seated := {}
	for entity in snapshot:
		if entity.kind == "PERSON" and _rear().ledger.inspect_entity(entity.holder_id).get("kind","") == "CARRIER": seated[entity.id] = true
	for entity in snapshot:
		if entity.kind == "PERSON" and entity.assignment != "Dead" and not seated.has(entity.id) and entity.position.distance_to(row.position) <= spec.radius+EPS:
			var distance: float = entity.position.distance_to(row.position)
			var cover: Dictionary = _rear().combat.world.cover(entity.position,row.position,0,false,row.position)
			var injury: int = ceili(float(spec.injury)*maxf(0.0,1.0-distance/float(spec.radius))*float(cover.blast))
			if injury > 0: _rear().combat.injure(entity.id,injury,true)
		elif entity.kind == "CARRIER" and entity.has("vehicle_spec") and entity.health > 0 and row.code != "D01" and (entity.id == trigger_id or _footprint_distance(row.position,entity.position,entity.position,entity,deg_to_rad(float(entity.get("facing_degrees",0.0)))) <= spec.radius+EPS):
			var distance: float = _footprint_distance(row.position,entity.position,entity.position,entity,deg_to_rad(float(entity.get("facing_degrees",0.0))))
			var damage: int = int(spec.damage) if entity.id == trigger_id else ceili(float(spec.damage)*maxf(0.0,1.0-distance/float(spec.radius)))
			if damage <= 0: continue
			var hit: Dictionary = _rear().ledger.apply_device_damage(entity.id,damage,int(spec.penetration),row.code+" bottom blast")
			var delegated: bool = _rear().ledger.has_signal("vehicle_damaged") and not _rear().ledger.get_signal_connection_list("vehicle_damaged").is_empty()
			if hit.get("penetrated",false) and (hit.health > 0 or not delegated):
				for person_id in entity.crew+entity.passengers:
					if hit.health > 0: _rear().combat.injure(person_id,10,true)
					else:
						var exit_point: Vector2 = _rear().demolition._blast_exit(entity.position)
						if exit_point.is_finite() and _rear().ledger.eject_destroyed_carrier_occupant(person_id,entity.id,exit_point).ok:
							_rear().combat.injure(person_id,60,true)
							_rear().ledger.set_person_stress(person_id,0,80)
						else: _rear().ledger.kill_person(person_id,"Destroyed vehicle had no safe exit")
	# Owners retain issued locations; opponents learn only from an actual witness.
	_known(row,row.owner)
	for entity in snapshot:
		if entity.kind == "PERSON" and entity.health > 0 and _rear().combat.world.observe(entity.position,row.position).visible: _known(row,entity.owner)
	events.append({"at":_rear().time,"id":row.id,"kind":"Detonated","trigger":trigger_id,"surface":"Bottom" if row.code != "D01" else "Infantry"})

func next_boundary() -> float:
	var result := INF
	for row in projects.values():
		if row.state == "Placing" and _access(row).ok: result = minf(result,_rear().time+row.work_required-row.progress)
		elif row.state == "Arming": result = minf(result,row.armed_at)
	for engineer in tasks:
		if _task_ready(engineer,tasks[engineer]): result = minf(result,_rear().time+tasks[engineer].required-tasks[engineer].progress)
	return result

func advance_to(at: float) -> void:
	var delta: float = at-_rear().time
	for row in projects.values():
		if row.state == "Placing" and _access(row).ok: row.progress = minf(row.work_required,row.progress+delta)
	for engineer in tasks:
		if _task_ready(engineer,tasks[engineer]): tasks[engineer].progress = minf(tasks[engineer].required,tasks[engineer].progress+delta)

func settle() -> bool:
	var changed := false
	for row in projects.values():
		if row.state == "Placing":
			_reserve_material(row)
			var access: Dictionary = _access(row)
			row.blocked_reason = "" if access.ok else access.message
			if access.ok and row.progress >= row.work_required-EPS:
				var spent: Dictionary = _rear().ledger.consume_claimed_batch(row.claims,row.id,row.position,10.0,"M06",int(row.m06_reserved),row.code+" placement")
				if spent.ok:
					row.receipt = spent.receipt
					row.m06_consumed = row.m06_reserved
					row.health = 20
					row.state = "Arming"
					row.armed_at = _rear().time+10.0
					_known(row,row.owner)
					changed = true
		elif row.state == "Arming" and _rear().time+EPS >= row.armed_at:
			row.state = "Armed"
			row.blocked_reason = "Awaiting actual trigger."
			_known(row,row.owner)
			changed = true
		if row.state == "Armed" and row.code == "D01":
			for person in _rear().ledger.snapshot().entities:
				if person.kind == "PERSON" and person.assignment != "Dead" and person.position.distance_to(row.position) <= 1.0+EPS and _rear().ledger.inspect_entity(person.holder_id).get("kind","") != "CARRIER":
					_detonate(row,person.id)
					changed = true
					break
		if row.code == "D03" and not row.controller.is_empty() and not _operator(row,row.controller):
			row.controller = ""
			row.blocked_reason = "Lost remote operator; explicit qualified takeover required."
			changed = true
	for engineer in tasks.keys():
		var task: Dictionary = tasks[engineer]
		var person: Dictionary = _rear().ledger.inspect_entity(engineer)
		if person.get("assignment","") == "Dead" or (task.kind == "Disarm" and _device(task.target).get("state","") not in LIVE):
			tasks.erase(engineer)
			changed = true
			continue
		task["blocked_reason"] = "" if _task_ready(engineer,task) else "Equipped engineer must be stationary for scanning or within two metres for disarm."
		if _task_ready(engineer,task) and task.progress >= task.required-EPS:
			if task.kind == "Scan":
				for row in _devices():
					if row.position.distance_to(task.position) > 20.0+EPS or not _rear().combat.world.probe(task.position,row.position,0.2,0.1,20.0).clear: continue
					if row.state in LIVE: _known(row,task.owner)
					elif row.state in ["Inert","Detonated"] and knowledge.get(task.owner,{}).has(row.id):
						_known(row,task.owner)
						knowledge[task.owner][row.id].hazard = false
			else: _inert(_device(task.target),task.owner)
			tasks.erase(engineer)
			changed = true
	return changed

func inspect(id: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty(): return {}
	var view: Dictionary = row.duplicate(true)
	view.available_m06 = _rear().ledger.available_stock_near(row.position,10.0,row.owner,"M06")
	view.committed_m06 = _committed(row)
	return view

func snapshot() -> Dictionary:
	var rows := {}
	for id in projects: rows[id] = inspect(id)
	return {"projects":rows,"knowledge":knowledge.duplicate(true),"tasks":tasks.duplicate(true),"events":events.duplicate(true)}

func audit() -> Array[String]:
	var failures: Array[String] = []
	for row in projects.values():
		if row.progress < 0 or row.progress > row.work_required+EPS or row.health < 0 or row.health > 20 or row.m06_consumed not in [0,row.m06_reserved]: failures.append("Device accounting: "+row.id)
		if row.state in LIVE and row.m06_consumed != row.m06_reserved: failures.append("Unpaid physical device: "+row.id)
	return failures

func _release_material(row: Dictionary) -> void:
	for claim_id in row.get("claims",[]): _rear().ledger.release_claim(claim_id)
	row["claims"] = []

func _committed(row: Dictionary) -> int:
	var count := 0
	for id in row.get("claims",[]):
		var claim: Dictionary = _rear().ledger.inspect_claim(id)
		var stock: Dictionary = _rear().ledger.inspect_entity(str(claim.get("source_id","")))
		if stock.is_empty() or stock.position.distance_to(row.position) > 10.0+EPS: continue
		count += int(claim.get("reserved",0))
	return count

func _reserve_material(row: Dictionary) -> void:
	if _committed(row) == row.m06_reserved: return
	_release_material(row)
	if _rear().ledger.available_stock_near(row.position,10.0,row.owner,"M06") < row.m06_reserved: return
	var remaining: int = row.m06_reserved
	for stock in _rear().ledger.snapshot().entities:
		if stock.kind != "STOCK" or stock.owner != row.owner or stock.design_type != "M06" or stock.position.distance_to(row.position) > 10.0+EPS: continue
		if _rear().ledger.inspect_entity(stock.holder_id).get("kind","") != "PLACE": continue
		var count := mini(remaining,int(stock.available))
		if count <= 0: continue
		_claim_sequence += 1
		var claim_id: String = row.id+"-m06-%d" % _claim_sequence
		var result: Dictionary = _rear().ledger.request_stock(claim_id,stock.id,count,row.id,"Field device fixed placement batch",row.owner)
		if not result.ok:
			_release_material(row)
			return
		row.claims.append(claim_id)
		remaining -= count
		if remaining == 0: return

func deliver(id: String, stock_id: String, count: int) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	var stock: Dictionary = _rear().ledger.inspect_entity(stock_id)
	if row.is_empty() or row.state != "Placing" or stock.get("kind","") != "STOCK" or stock.design_type != "M06" or stock.owner != row.owner or count <= 0:
		return _fail("Only real owned M06 can be delivered to an active placement.")
	if stock.holder_id == row.place: return {"ok":true,"message":"M06 already staged at the target."}
	var holder: Dictionary = _rear().ledger.inspect_entity(stock.holder_id)
	if holder.get("kind","") not in ["PERSON","CARRIER"] or holder.position.distance_to(row.position) > 10.0+EPS:
		return _fail("A physical carrier or person must bring M06 within ten metres of the target.")
	if _rear().ledger.available_stock_near(row.position,10.0,row.owner,"M06")+count > row.m06_reserved: return _fail("Only the fixed authorized quantity may be staged.")
	var destination: String = row.place
	if not holder.position.is_equal_approx(row.position):
		destination = id+"-staging-"+str(row.get("staging_sequence",0))
		row["staging_sequence"] = int(row.get("staging_sequence",0))+1
		var created: Dictionary = _rear().ledger.add_place(destination,"Field device nearby physical M06 staging",holder.position)
		if not created.ok: return created
	if holder.kind == "PERSON" and holder.carrying_stock_id == stock_id:
		if count != stock.quantity: return _fail("Finish the whole active person carry.")
		return _rear().ledger.finish_carry(holder.id,destination)
	return _rear().ledger.transfer_stock(stock_id,count,destination)
