extends RefCounted
## G24 owns timed recovery and once-only consequences on existing identities.
const Routes = preload("res://game/routes/route_planner.gd")
const EPS := 0.000001
var _rear_ref: WeakRef
var jobs: Dictionary = {}
var workers: Dictionary = {}
var events: Array[Dictionary] = []
var couplings: Dictionary = {}
var journeys: Dictionary = {}

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	rear.ledger.vehicle_damaged.connect(_on_damage)

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func _fail(reason: String) -> Dictionary:
	return {"ok":false,"blocked_reason":reason,"message":reason}

func _on_damage(id: String) -> void:
	var rear: RefCounted = _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(id)
	if not hull.has("vehicle_spec"): return
	if hull.health > 0 or hull.destruction_resolved: return
	var world: RefCounted = rear.combat.world
	var tile: Dictionary = world.cell(Vector2i(hull.position.floor()))
	var submerged: bool = hull.submerged or tile.terrain == "TR11" and not tile.get("overlay",{}).get("complete",false)
	var safe := Vector2(INF,INF)
	if not submerged:
		var candidates: Array[Vector2] = []
		for y in range(-8,9):
			for x in range(-8,9):
				var offset := Vector2(x,y)
				if offset.length() > 8.0 or offset.length() < 0.5: continue
				var local := offset.rotated(-deg_to_rad(float(hull.facing_degrees)))
				if absf(local.x) <= hull.vehicle_spec.footprint.x/2.0+0.3 and absf(local.y) <= hull.vehicle_spec.footprint.y/2.0+0.3: continue
				candidates.append(offset)
		candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.length_squared() < b.length_squared())
		for offset in candidates:
			var at: Vector2 = hull.position+offset
			if _ground(at):
				safe = at
				break
	var result: Dictionary = rear.ledger.resolve_vehicle_wreck(id,submerged)
	if not result.ok: return
	for person_id in hull.crew+hull.passengers:
		var person: Dictionary = rear.ledger.inspect_entity(person_id)
		if person.assignment != "Dead":
			if submerged or not safe.is_finite():
				if rear.ledger.kill_person(person_id,"Vehicle destruction without survivable ground").ok: rear.combat._on_death(person_id,person)
			else:
				rear.combat.injure(person_id,60)
				rear.combat._apply_stress(person_id,0,80,true)
		if safe.is_finite(): rear.ledger.eject_destroyed_carrier_occupant(person_id,id,safe)
	rear.ledger.release_wreck_belongings(id,result.pile,submerged)
	if not submerged:
		world.obstacle("wreck:"+id,Rect2(hull.position-hull.vehicle_spec.footprint/2.0,hull.vehicle_spec.footprint),0.0,1.0,true,false)
	rear.dispatch.military_hulls.erase(id)
	events.append({"time":rear.time,"hull":id,"kind":"Destroyed","pile":result.pile,"submerged":submerged,"occupants":hull.crew+hull.passengers})

func _ground(at: Vector2) -> bool:
	return _rear().combat.world.route({"position":at,"facing":0.0,"size":Vector2(0.6,0.6),"movement_class":0,"base":1.5,"rate":0.0,"gross_mass_kg":80.0},at+Vector2(0.01,0)).ok

func _stationary(id: String) -> bool:
	var rear: RefCounted = _rear()
	for journey in journeys.values():
		if journey.tractor == id or journey.target == id: return false
	if rear.vehicles.vehicles.has(id) and rear.vehicles.vehicles[id].state not in ["In F10","Parked"]: return false
	for crossing in rear.bridges.traffic.values():
		if crossing.entity == id or crossing.get("tow","") == id: return false
	for row in rear.dispatch.manifests.values():
		if row.hull == id and row.state in ["Approaching Dispatch","Departed","Transit","Docking HQ","Returning","Safety Returning"]: return false
	return true

func _safe(hull: Dictionary) -> String:
	if not _stationary(hull.id): return "Vehicle must remain stationary."
	if _rear().time-float(hull.last_damage_at) < 10.0-EPS: return "Damage in the past ten seconds blocks work."
	for person in _rear().ledger.snapshot().entities:
		if person.kind == "PERSON" and person.owner != hull.owner and person.owner in ["army-blue","army-red"] and person.health > 0 and person.position.distance_to(hull.position) <= 150.0 and _rear().combat.world.observe(hull.position,person.position).visible: return "Visible hostile within 150 metres blocks work."
	return ""

func _engineer(id: String, hull: Dictionary) -> bool:
	var p: Dictionary = _rear().ledger.inspect_entity(id)
	if p.get("kind","") != "PERSON" or p.owner != hull.owner or p.qualification != "P02" or not p.basic_training or p.assignment in ["Wounded","Recovery","Dead"] or not p.crew_station.is_empty(): return false
	if _rear().ledger.inspect_entity(p.holder_id).get("kind","") != "PLACE": return false
	var delta: Vector2 = (p.position-hull.position).rotated(-deg_to_rad(float(hull.facing_degrees))).abs()-Vector2(hull.vehicle_spec.footprint)/2.0
	if Vector2(maxf(0,delta.x),maxf(0,delta.y)).length() > 2.0+EPS: return false
	return _rear().military._held(id,"E08") > 0 and _ground(p.position)

func start_repair(id: String, engineers: Array, mode: String = "Health") -> Dictionary:
	var hull: Dictionary = _rear().ledger.inspect_entity(id)
	if hull.get("kind","") != "CARRIER" or not hull.has("vehicle_spec") or mode not in ["Health","Mobility","Clear wreck"]: return _fail("Actual hull and valid recovery action required.")
	if jobs.has(id) or couplings.has(id) or _rear().field_structures.repairs.has(id): return _fail("One committed job already owns this hull.")
	if mode == "Clear wreck":
		if hull.health > 0 or hull.submerged or hull.wreck_cleared: return _fail("Reachable uncleared land wreck required.")
	elif hull.health <= 0 or mode == "Health" and hull.health >= hull.max_health or mode == "Mobility" and not hull.damage_immobilized: return _fail("Action does not match actual damage state.")
	var reason := _safe(hull)
	if not reason.is_empty(): return _fail(reason)
	if engineers.is_empty() or engineers.size() > 2: return _fail("One or two actual engineers required.")
	var unique: Dictionary = {}
	for person_id in engineers:
		if unique.has(person_id) or workers.has(person_id) or _rear().bridges.engineer_committed(person_id) or _rear().field_structures.engineer_committed(person_id) or not _engineer(person_id,hull): return _fail("Distinct available P02 with E08 must be within two metres on accessible ground.")
		unique[person_id] = true
	var cost := 10 if mode == "Health" else 20
	var paid: Dictionary = _rear().ledger.consume_local_vehicle_material(id,cost)
	if not paid.ok: return _fail(paid.message)
	jobs[id] = {"hull":id,"mode":mode,"engineers":engineers.duplicate(),"progress":0.0,"work":40.0 if mode == "Health" else 60.0,"cost":cost,"last":_rear().time,"rate":0.0,"blocked_reason":""}
	for person_id in engineers: workers[person_id] = id
	return {"ok":true,"message":"Local M11 committed once; active engineer work required."}

func cancel(id: String) -> Dictionary:
	if not jobs.has(id): return _fail("No committed recovery job.")
	for person_id in jobs[id].engineers: workers.erase(person_id)
	jobs.erase(id)
	return {"ok":true,"message":"Job cancelled; consumed repair material is not refunded."}

func _rate(job: Dictionary) -> float:
	var hull: Dictionary = _rear().ledger.inspect_entity(job.hull)
	var reason := _safe(hull)
	if job.mode != "Clear wreck" and hull.health <= 0: reason = "Destroyed hull cannot be repaired."
	if not reason.is_empty():
		job.blocked_reason = reason
		return 0.0
	var rate := 0.0
	for id in job.engineers:
		if _engineer(id,hull): rate += 1.0
	job.blocked_reason = "" if rate > 0.0 else "Engineers or kits no longer locally eligible."
	return rate

func next_boundary() -> float:
	var next := INF
	for journey in journeys.values():
		if journey.blocked_reason.is_empty(): next = minf(next,_rear().time+float(journey.part.seconds)-float(journey.progress))
	for job in jobs.values():
		job.rate = _rate(job)
		if job.rate > 0: next = minf(next,_rear().time+(float(job.work)-float(job.progress))/float(job.rate))
		else:
			var damage: float = _rear().ledger.inspect_entity(job.hull).last_damage_at+10.0
			if damage > _rear().time+EPS: next = minf(next,damage)
	for job in couplings.values():
		job.rate = 1.0 if _coupling_check(job.tractor,job.target,job.engineer,job.attach).ok else 0.0
		if job.rate > 0: next = minf(next,_rear().time+20.0-float(job.progress))
	return next

func advance_to(at: float) -> void:
	for tractor in journeys.keys():
		var journey: Dictionary = journeys[tractor]
		var delta: float = at-float(journey.last)
		journey.last = at
		if not journey.blocked_reason.is_empty(): continue
		var lead: Dictionary = _rear().ledger.inspect_entity(tractor)
		var target: Dictionary = _rear().ledger.inspect_entity(journey.target)
		if lead.health <= 0 or target.health <= 0 or lead.towing != journey.target or lead.damage_immobilized or lead.health <= lead.max_health/4:
			journey.blocked_reason = "Damage or coupling loss interrupted recovery travel."
			continue
		var part: Dictionary = journey.part
		var earned := minf(delta,float(part.seconds)-float(journey.progress))
		var position: Vector2 = Vector2(part.from).lerp(part.to,(float(journey.progress)+earned)/float(part.seconds))
		var travel: Vector2 = position-Vector2(lead.position)
		var fraction := 1.0
		var mines: RefCounted = _rear().get("mines")
		if mines != null:
			fraction = minf(mines.movement_limit(tractor,lead.position,position),mines.movement_limit(target.id,target.position,Vector2(target.position)+travel))
		var fuel: float = float(part.fuel)*earned/float(part.seconds)*fraction
		if not _rear().ledger.burn_vehicle_fuel(tractor,fuel).ok:
			journey.blocked_reason = "Fuel Empty; actual travel held."
			continue
		journey.progress += earned*fraction
		var lead_goal: Vector2 = Vector2(lead.position)+travel*fraction
		var target_goal: Vector2 = Vector2(target.position)+travel*fraction
		var target_health: int = target.health
		_rear().ledger.move_entity(tractor,lead.holder_id,lead_goal)
		# Mine damage runs synchronously inside move_entity and can eject/uncouple.
		# Never move the old target snapshot after its physical coupling is lost.
		lead = _rear().ledger.inspect_entity(tractor)
		target = _rear().ledger.inspect_entity(journey.target)
		if lead.health <= 0 or target.health <= 0 or lead.towing != journey.target or target.towed_by != tractor or lead.damage_immobilized or lead.health <= lead.max_health/4:
			journey.blocked_reason = "Mine contact, damage or coupling loss stopped both recovery bodies."
			continue
		_rear().ledger.move_entity(target.id,target.holder_id,target_goal)
		lead = _rear().ledger.inspect_entity(tractor)
		target = _rear().ledger.inspect_entity(journey.target)
		if fraction < 1.0-EPS or lead.health <= 0 or target.health <= 0 or lead.towing != journey.target or target.towed_by != tractor or lead.damage_immobilized or target.health < target_health:
			journey.blocked_reason = "Mine contact, damage or coupling loss stopped both recovery bodies."
			continue
		if journey.progress+EPS >= float(part.seconds):
			journey.index += 1
			if journey.index >= journey.parts.size(): journeys.erase(tractor)
			else:
				journey.part = journey.parts[journey.index]
				journey.progress = 0.0
	for tractor in couplings.keys():
		var coupling: Dictionary = couplings[tractor]
		coupling.progress += (at-float(coupling.last))*float(coupling.rate)
		coupling.last = at
		if coupling.progress+EPS >= 20.0:
			_rear().ledger.set_tow_pair(tractor,coupling.target,coupling.attach)
			workers.erase(coupling.engineer)
			couplings.erase(tractor)
	for id in jobs.keys():
		var job: Dictionary = jobs[id]
		job.progress = minf(job.work,float(job.progress)+(at-float(job.last))*float(job.rate))
		job.last = at
		if job.progress+EPS < job.work: continue
		var done: Dictionary = _rear().ledger.finish_vehicle_recovery(id,job.mode)
		if done.ok and job.mode == "Clear wreck":
			var world: RefCounted = _rear().combat.world
			for index in range(world.obstacles.size()-1,-1,-1):
				if world.obstacles[index].id == "wreck:"+id: world.obstacles.remove_at(index)
			world.revision += 1
		events.append({"time":at,"hull":id,"kind":job.mode,"ok":done.ok})
		cancel(id)

func _coupling_check(tractor_id: String, target_id: String, engineer_id: String, attach: bool) -> Dictionary:
	var tractor: Dictionary = _rear().ledger.inspect_entity(tractor_id)
	var target: Dictionary = _rear().ledger.inspect_entity(target_id)
	if tractor.get("kind","") != "CARRIER" or tractor.get("health",0) <= 0 or target.get("kind","") not in ["CARRIER","HEAVY_OBJECT"] or target.get("health",0) <= 0 or tractor_id == target_id or tractor.owner != target.owner: return _fail("Distinct surviving friendly tractor and tow object required; wrecks cannot be towed.")
	if not _stationary(tractor_id) or not _stationary(target_id) or not _engineer(engineer_id,tractor): return _fail("P02 with E08 must remain beside the stationary tractor.")
	if not attach:
		return {"ok":true} if tractor.towing == target_id else _fail("This actual pair is not coupled.")
	if not tractor.towing.is_empty() or not tractor.towed_by.is_empty() or not target.get("towed_by","").is_empty() or not target.get("towing","").is_empty(): return _fail("Tow chains and multiple tow objects are forbidden.")
	var mass: float = Routes.gross_kg(_rear().ledger,target_id) if target.kind == "CARRIER" else float(target.unit_mass_kg)+float(target.contents_mass_kg)
	if tractor.design_type == "T01":
		if target.design_type not in ["T03","E13"] or mass > 3000.0+EPS: return _fail("T01 can tow only a disabled technical or field gun up to 3000 kg.")
	elif tractor.design_type != "T05" or mass > 35000.0+EPS: return _fail("T05 tow limit is 35000 kg; other tractors cannot tow.")
	if target.kind == "CARRIER" and inspect(target_id).conditions.is_empty(): return _fail("Tow target must actually be disabled.")
	if tractor.position.distance_to(target.position) > 14.0+EPS: return _fail("Bring actual tow object within fourteen metres for coupling.")
	return {"ok":true}

func start_coupling(tractor: String, target: String, engineer: String, attach: bool = true) -> Dictionary:
	if couplings.has(tractor) or workers.has(engineer) or jobs.has(tractor) or jobs.has(target) or _rear().bridges.engineer_committed(engineer) or _rear().field_structures.engineer_committed(engineer): return _fail("Recovery work already owns this person or vehicle.")
	var check := _coupling_check(tractor,target,engineer,attach)
	if not check.ok: return check
	couplings[tractor] = {"tractor":tractor,"target":target,"engineer":engineer,"attach":attach,"progress":0.0,"last":_rear().time,"rate":0.0}
	workers[engineer] = tractor
	return {"ok":true,"message":"Twenty active stationary seconds of kit work required."}

func start_tow_route(tractor: String, destination: Vector2) -> Dictionary:
	var hull: Dictionary = _rear().ledger.inspect_entity(tractor)
	if hull.get("towing","").is_empty() or not _stationary(tractor) or jobs.has(tractor) or couplings.has(tractor): return _fail("Stationary coupled tractor without another recovery job required.")
	var state := inspect(tractor)
	if not state.conditions.is_empty(): return _fail(state.blocked_reason)
	var target: Dictionary = _rear().ledger.inspect_entity(hull.towing)
	var direction: Vector2 = (destination-hull.position).normalized()
	if target.position.distance_to(hull.position-direction*12.0) > 2.0: return _fail("Align the actual tow pair twelve metres apart before starting the straight recovery lane.")
	var plan: Dictionary = Routes.plan(_rear().ledger,tractor,[hull.position,destination],{"world":_rear().combat.world})
	if not plan.ok: return _fail(plan.reason)
	if hull.fuel+EPS < plan.fuel: return _fail("Actual tractor tank lacks complete recovery-route fuel.")
	# The tow object retains its own terrain/footprint access, including a field gun.
	var size: Vector2 = target.vehicle_spec.footprint if target.kind == "CARRIER" else Vector2(4,2)
	var movement_class: int = 2 if target.design_type == "T05" else 1
	var lane: Dictionary = _rear().combat.world.route({"position":target.position,"facing":direction.angle(),"size":size,"movement_class":movement_class,"base":1.0,"rate":0.0,"gross_mass_kg":plan.gross_kg},destination-direction*12.0)
	if not lane.ok: return _fail("Tow object's terrain: "+lane.reason)
	journeys[tractor] = {"tractor":tractor,"target":target.id,"parts":plan.parts,"part":plan.parts[0],"index":0,"progress":0.0,"last":_rear().time,"blocked_reason":""}
	return {"ok":true,"seconds":plan.seconds,"fuel":plan.fuel,"gross_kg":plan.gross_kg}

func inspect(id: String) -> Dictionary:
	var hull: Dictionary = _rear().ledger.inspect_entity(id)
	if hull.get("kind","") != "CARRIER" or not hull.has("vehicle_spec"): return _fail("Actual hull required.")
	var reasons: Array[String] = []
	if hull.health <= 0: reasons.append("Destroyed")
	if hull.damage_immobilized or hull.health <= hull.max_health/4: reasons.append("Damage Immobilized")
	if hull.fuel <= EPS: reasons.append("Fuel Empty")
	var driver: Dictionary = _rear().ledger.inspect_entity(hull.crew_by_station.get("Driver",""))
	if driver.get("health",0) <= 0 or driver.get("qualification","") != "P08" or driver.get("holder_id","") != id: reasons.append("Missing Driver")
	var terrain: Dictionary = _rear().field_structures.assess_vehicle(id,deg_to_rad(float(hull.facing_degrees)))
	if not terrain.ok: reasons.append("Terrain Stranded: "+terrain.reason)
	return {"ok":true,"hull":hull,"gross_kg":Routes.gross_kg(_rear().ledger,id),"conditions":reasons,"job":jobs.get(id,{}).duplicate(true),"coupling":couplings.get(id,{}).duplicate(true),"journey":journeys.get(id,{}).duplicate(true),"available_m11":_rear().ledger.local_vehicle_material(id),"blocked_reason":"; ".join(reasons)}

func snapshot() -> Dictionary:
	var hulls: Array[Dictionary] = []
	for item in _rear().ledger.snapshot().entities:
		if item.kind == "CARRIER" and item.has("vehicle_spec"): hulls.append(inspect(item.id))
	return {"hulls":hulls,"jobs":jobs.duplicate(true),"couplings":couplings.duplicate(true),"journeys":journeys.duplicate(true),"events":events.duplicate(true)}

func audit() -> Array[String]:
	var errors: Array[String] = []
	for item in _rear().ledger.snapshot().entities:
		if item.kind != "CARRIER" or not item.has("vehicle_spec"): continue
		if not item.towing.is_empty():
			var target: Dictionary = _rear().ledger.inspect_entity(item.towing)
			if target.get("towed_by","") != item.id or item.health <= 0 or target.get("health",0) <= 0: errors.append("Broken actual tow pair: "+item.id)
		if item.health <= 0 and not item.destruction_resolved: errors.append("Unresolved destroyed vehicle: "+item.id)
	for id in workers:
		if not jobs.has(workers[id]) and not couplings.has(workers[id]): errors.append("Recovery worker lacks one actual job: "+id)
	return errors
