extends RefCounted
## D04 attached charges on G20 bridges or G19 structures; all people and M06 stay in G01.
const EPS := 0.000001
var _rear_ref: WeakRef
var projects: Dictionary = {}
var events: Array[Dictionary] = []
var _sequence := 0
var _claim_sequence := 0

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func _target(kind: String, id: String) -> Dictionary:
	if kind == "Bridge": return _rear().bridges.projects.get(id,{})
	if kind == "Structure": return _rear().field_structures.projects.get(id,{})
	return {}

func _site(target: Dictionary, kind: String, bank: int) -> Vector2:
	return target.banks[bank] if kind == "Bridge" else target.center

func _place(target: Dictionary, kind: String, bank: int) -> String:
	return target.places[bank] if kind == "Bridge" else target.id

func _squad(squad_id: String, engineers: Array[String], owner: String) -> Dictionary:
	var squad: Dictionary = _rear().military.squads.get(squad_id,{})
	if squad.is_empty() or squad.kind != "Engineer" or squad.state != "Active" or engineers.size() != 2:
		return _fail("An active actual engineer squad must assign two P02 members.")
	var unique := {}
	for id in engineers:
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if unique.has(id) or id not in squad.roster or person.get("kind","") != "PERSON" or person.owner != owner or person.qualification != "P02" or person.health <= 0 or _rear().military._held(id,"E08") < 1:
			return _fail("Two distinct living squad P02 need their own physical E08.")
		unique[id] = true
	return {"ok":true,"squad":squad}

func order(kind: String, target_id: String, squad_id: String, engineers: Array[String], bank: int = 0) -> Dictionary:
	var target: Dictionary = _target(kind,target_id)
	if target.is_empty() or target.state != "Complete" or target.health <= 0 or kind == "Bridge" and bank not in [0,1] or kind == "Structure" and target.code == "S11":
		return _fail("D04 needs an existing intact completed bridge or damageable field structure.")
	var owner: String = str(_rear().ledger.inspect_entity(engineers[0]).get("owner","")) if engineers.size() > 0 else ""
	var squad_check: Dictionary = _squad(squad_id,engineers,owner)
	if not squad_check.ok: return squad_check
	for job in projects.values():
		if job.state not in ["Detonated","Cancelled","Inert"] and job.target_id == target_id: return _fail("Target already has an active attached charge.")
	for id in engineers:
		if (_rear().mines != null and _rear().mines.engineer_committed(id)) or engineer_committed(id) or _rear().bridges.engineer_committed(id) or _rear().field_structures.engineer_committed(id): return _fail("An engineer cannot work on two demolition, construction or repair jobs together.")
	var site: Vector2 = _site(target,kind,bank)
	for other in projects.values():
		if other.state in ["Placed","Arming","Armed","Waiting","Fusing"] and other.position.distance_to(site) < 4.0-EPS: return _fail("Attached D04 occupies one metre and needs four metres from another placed device.")
	if _rear().mines != null and not _rear().mines.spacing_clear(site): return _fail("Device needs four metres separation from D01-D03.")
	var sight: Dictionary = _rear().combat.world.observe(_rear().ledger.inspect_entity(engineers[0]).position,site)
	var known_health: int = int(target.health) if sight.visible else int(target.max_health)
	var count := maxi(1,ceili(float(known_health)/500.0))
	_sequence += 1
	var id := "d04-%04d" % _sequence
	projects[id] = {"id":id,"kind":"D04","target_kind":kind,"target_id":target_id,"squad":squad_id,"owner":owner,"company":squad_check.squad.company,"engineers":engineers.duplicate(),"bank":bank,"position":site,"place":_place(target,kind,bank),"known_health":known_health,"health_basis":"Observed current" if sight.visible else "Full type fallback","m06_reserved":count,"m06_consumed":0,"receipt":[],"work_required":float(10+2*count),"progress":0.0,"state":"Placing","health":0,"mode":"","armed_at":-1.0,"fuse_due":-1.0,"authorized_by":"","authorization":{},"controller":"","observed_vehicle":"","blocked_reason":"Two equipped engineers and all M06 must reach the accessible target; work and stock remain separate until placement finishes.","created_at":_rear().time,"damage":0}
	events.append({"at":_rear().time,"id":id,"kind":"Ordered","detail":"%s %d health; %d M06 fixed." % [projects[id].health_basis,known_health,count]})
	return {"ok":true,"id":id,"m06":count,"work":10+2*count,"message":"%s health fixed the M06 quantity; no stock consumed." % projects[id].health_basis}

func engineer_committed(person_id: String) -> bool:
	for row in projects.values():
		if row.state == "Placing" and person_id in row.engineers: return true
	return false

func revise(id: String, count: int) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state != "Placing" or row.m06_consumed > 0 or count < 1 or count > 100:
		return _fail("Only an unconsumed placement may revise its authorized M06 quantity.")
	_release_material(row)
	row.m06_reserved = count
	row.work_required = float(10+2*count)
	row.progress = minf(row.progress,row.work_required)
	return {"ok":true,"message":"Explicit pre-consumption quantity revision recorded."}

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
		var result: Dictionary = _rear().ledger.request_stock(claim_id,stock.id,count,row.id,"D04 fixed placement batch",row.owner)
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
		var created: Dictionary = _rear().ledger.add_place(destination,"D04 nearby physical M06 staging",holder.position)
		if not created.ok: return created
	if holder.kind == "PERSON" and holder.carrying_stock_id == stock_id:
		if count != stock.quantity: return _fail("Finish the whole active person carry.")
		return _rear().ledger.finish_carry(holder.id,destination)
	return _rear().ledger.transfer_stock(stock_id,count,destination)

func _access(row: Dictionary) -> Dictionary:
	var target: Dictionary = _target(row.target_kind,row.target_id)
	if target.is_empty() or target.state != "Complete": return _fail("Assigned target is no longer intact and accessible.")
	var squad: Dictionary = _rear().military.squads.get(row.squad,{})
	if squad.is_empty() or squad.state != "Active": return _fail("Assigned engineer squad is no longer active.")
	if row.target_kind == "Bridge" and not _rear().bridges._holding_approach(target.banks[0],target.banks[1],row.bank).ok:
		return _fail("Chosen bridge endpoint has no physical approach.")
	var last_damage: float = float(target.get("last_damage",-INF))
	if _rear().time-last_damage < 10.0-EPS: return _fail("Site has taken damage in the past ten seconds.")
	for id in row.engineers:
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if id not in squad.roster or person.get("kind","") != "PERSON" or person.health <= 0 or person.position.distance_to(row.position) > 2.0+EPS or _rear().military._held(id,"E08") < 1 or person.assignment in ["Wounded","Recovery","Dead","Training","Rear Labour"]:
			return _fail("Both assigned P02 must stand within two metres with E08 and be available.")
	for other in _rear().ledger.snapshot().entities:
		if other.kind == "PERSON" and other.owner != row.owner and other.owner in ["army-blue","army-red"] and other.health > 0 and other.position.distance_to(row.position) <= 150.0 and _rear().combat.world.observe(row.position,other.position).visible:
			return _fail("Visible hostile within 150 metres stops placement.")
	if _committed(row) != row.m06_reserved: return _fail("Full M06 quantity must be physically staged within ten metres and exclusively reserved to this project.")
	return {"ok":true}

func _withdrawn(row: Dictionary) -> bool:
	var squad: Dictionary = _rear().military.squads.get(row.squad,{})
	if squad.is_empty(): return false
	for id in squad.roster:
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if person.get("kind","") != "PERSON": return false
		if person.assignment != "Dead" and person.position.distance_to(row.position) < 25.0-EPS: return false
	return true

func remote_slot_blocker(squad_id: String, except_id: String = "") -> String:
	if _rear().mines != null:
		var blocker: String = _rear().mines.remote_slot_blocker(squad_id,except_id)
		if not blocker.is_empty(): return blocker
	for other in projects.values():
		if other.id != except_id and other.squad == squad_id and other.mode == "Remote" and other.state not in ["Detonated","Cancelled","Inert"]:
			return "Squad remote slot is reserved by %s (%s); select Fuse or make that device inert first." % [other.id,other.state]
	return ""

func _present(entity: Dictionary) -> bool:
	if entity.get("kind","") == "PERSON": return entity.get("assignment","") != "Dead"
	return int(entity.get("health",100)) > 0

func _consequences(row: Dictionary) -> Dictionary:
	var target: Dictionary = _target(row.target_kind,row.target_id)
	var stranded := 0
	var wounded := 0
	var supply := 0
	var alternate := 0
	if row.target_kind == "Bridge":
		var mid: Vector2 = (target.banks[0]+target.banks[1])*0.5
		for entity in _rear().ledger.snapshot().entities:
			if entity.get("owner","") != row.owner or entity.get("kind","") not in ["PERSON","CARRIER"] or not _present(entity): continue
			if entity.position.distance_to(mid) <= 80.0:
				if entity.kind == "PERSON":
					stranded += 1
					if entity.assignment == "Wounded": wounded += 1
				else: supply += 1
		for bridge in _rear().bridges.projects.values():
			if bridge.id != row.target_id and bridge.state == "Complete" and bridge.banks[0].distance_to(target.banks[0]) <= 300.0: alternate += 1
	return {"retreat_people_near":stranded,"wounded_evacuations_near":wounded,"forward_carriers_near":supply,"alternate_crossings_near":alternate}

func authorize(id: String, authority_id: String, plan: Dictionary) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state in ["Cancelled","Detonated","Inert"]: return _fail("Actual active D04 project required.")
	var person: Dictionary = _rear().ledger.inspect_entity(authority_id)
	var company: Dictionary = _rear().military.companies.get(row.company,{})
	if person.get("kind","") != "PERSON" or person.health <= 0 or person.owner != row.owner or authority_id not in [str(company.get("leader","")),_rear().military.commander()]:
		return _fail("Only this real company leader or living Commander may authorize denial.")
	var consequences: Dictionary = _consequences(row)
	var missing: Array[String] = []
	for key in ["retreat","forward_supply","wounded_evacuation","alternate_or_restore"]:
		if str(plan.get(key,"")).strip_edges().is_empty(): missing.append(key)
	if not missing.is_empty(): return _fail("Denial order needs explicit plans for "+", ".join(missing)+"; current physical consequences: "+str(consequences))
	var emergency: bool = bool(plan.get("emergency_hq_assault",false))
	if emergency:
		var threat_id := str(plan.get("observed_hq_threat",""))
		var contact: Dictionary = _rear().orders.contact(row.company,threat_id)
		if contact.is_empty() or not contact.get("current",false) or not Vector2(contact.position).is_finite() or Vector2(contact.position).distance_to(_rear().military.HQ) > 300.0:
			return _fail("Emergency denial needs a currently delivered direct HQ threat within 300 metres, not an unobserved named enemy.")
	if int(consequences.alternate_crossings_near) == 0 and str(plan.alternate_or_restore).strip_edges().is_empty(): return _fail("No current alternate crossing or restoration plan.")
	row.authorized_by = authority_id
	row.authorization = {"plan":plan.duplicate(true),"consequences":consequences,"at":_rear().time,"emergency":emergency}
	events.append({"at":_rear().time,"id":id,"kind":"Authorized","detail":str(row.authorization)})
	_rear().orders.report(row.squad,"Threatened Crossing","D04 denial authorized by "+authority_id+"; "+str(consequences),true)
	return {"ok":true,"consequences":consequences,"message":"Company or Commander denial order recorded with physical route and evacuation consequences."}

func set_mode(id: String, mode: String, controller: String = "") -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state not in ["Arming","Armed","Waiting"] or mode not in ["Fuse","Remote"]: return _fail("Placed D04 charge needs Fuse or Remote mode.")
	if mode == "Remote":
		var person: Dictionary = _rear().ledger.inspect_entity(controller)
		if person.get("kind","") != "PERSON" or person.health <= 0 or person.qualification != "P02" or person.owner != row.owner or controller not in _rear().military.squads[row.squad].roster or _rear().military._held(controller,"E08") < 1 or person.position.distance_to(row.position) > 300.0+EPS:
			return _fail("Living squad P02 with E08 must physically assume remote control within 300 metres.")
		var blocker := remote_slot_blocker(row.squad,id)
		if not blocker.is_empty(): return _fail(blocker)
	row.mode = mode
	row.controller = controller if mode == "Remote" else ""
	return {"ok":true,"message":"Mode and actual controller recorded; arming, authorization and clearance still gate detonation."}

func _clearance(row: Dictionary) -> Dictionary:
	if row.authorized_by.is_empty(): return _fail("Company or Commander denial authorization is missing.")
	if not _withdrawn(row): return _fail("Engineers have not physically withdrawn 25 metres.")
	var target: Dictionary = _target(row.target_kind,row.target_id)
	var radius := 13.0
	for entity in _rear().ledger.snapshot().entities:
		if entity.get("owner","") != row.owner or entity.get("kind","") not in ["PERSON","CARRIER"] or not _present(entity): continue
		if entity.position.distance_to(row.position) <= radius+EPS: return _fail("Known friendly is within the blast plus five-metre safety radius.")
		if row.target_kind == "Bridge" and _rear().bridges._on_water(target,entity.position): return _fail("Known friendly occupies the affected bridge span.")
	return {"ok":true}

func start_fuse(id: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state not in ["Armed","Waiting"] or row.mode != "Fuse": return _fail("Only armed Fuse-mode D04 can start its five-second fuse.")
	var check: Dictionary = _clearance(row)
	if not check.ok:
		row.blocked_reason = check.message
		return check
	row.state = "Fusing"
	row.fuse_due = _rear().time+5.0
	row.blocked_reason = "Five-second fuse running; clearance rechecked at detonation."
	return {"ok":true,"message":row.blocked_reason}

func _operator(row: Dictionary) -> Dictionary:
	var person: Dictionary = _rear().ledger.inspect_entity(row.controller)
	var squad: Dictionary = _rear().military.squads.get(row.squad,{})
	if squad.is_empty() or squad.state != "Active" or row.controller not in squad.roster or person.get("kind","") != "PERSON" or person.health <= 0 or person.qualification != "P02" or person.owner != row.owner or _rear().military._held(row.controller,"E08") < 1 or person.position.distance_to(row.position) > 300.0+EPS:
		return _fail("Remote operator absent, dead, out of range or missing E08; charge waits inertly.")
	return {"ok":true}

func assign_remote_vehicle(id: String, vehicle_id: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.target_kind != "Bridge" or row.mode != "Remote" or row.state not in ["Armed","Waiting"]: return _fail("Only an armed remote bridge charge can receive an assigned hostile vehicle.")
	var operator: Dictionary = _operator(row)
	if not operator.ok: return operator
	var vehicle: Dictionary = _rear().ledger.inspect_entity(vehicle_id)
	if vehicle.get("kind","") != "CARRIER" or vehicle.owner == row.owner or vehicle.owner not in ["army-blue","army-red"] or int(vehicle.get("health",100)) <= 0 or not _rear().combat.world.observe(_rear().ledger.inspect_entity(row.controller).position,vehicle.position).visible:
		return _fail("Assign only an actual hostile vehicle currently seen by this qualified remote operator.")
	row.observed_vehicle = vehicle_id
	events.append({"at":_rear().time,"id":id,"kind":"Vehicle assigned","detail":vehicle_id})
	return {"ok":true,"message":"Currently observed hostile vehicle assigned; trigger still needs live sight on the span."}

func remote_trigger(id: String, observed_vehicle_id: String = "", explicit_command: bool = false) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state not in ["Armed","Waiting"] or row.mode != "Remote": return _fail("Only armed remote D04 may trigger.")
	var operator: Dictionary = _operator(row)
	if not operator.ok:
		_lose_operator(row,operator.message)
		return operator
	if not explicit_command:
		if row.observed_vehicle.is_empty() or not observed_vehicle_id.is_empty() and observed_vehicle_id != row.observed_vehicle: return _fail("Remote vehicle trigger needs its previously observed assigned target.")
		var vehicle: Dictionary = _rear().ledger.inspect_entity(row.observed_vehicle)
		if row.target_kind != "Bridge" or vehicle.get("kind","") != "CARRIER" or vehicle.owner == row.owner or int(vehicle.get("health",100)) <= 0 or not _rear().bridges._on_water(_target("Bridge",row.target_id),vehicle.position) or not _rear().combat.world.observe(_rear().ledger.inspect_entity(row.controller).position,vehicle.position).visible:
			return _fail("Remote trigger needs an actually observed assigned hostile vehicle on this span or an explicit denial order.")
	elif row.authorized_by.is_empty(): return _fail("Explicit command trigger needs company or Commander authorization.")
	return _detonate(row)

func _lose_operator(row: Dictionary, reason: String) -> void:
	row.state = "Waiting"
	row.controller = ""
	row.observed_vehicle = ""
	row.blocked_reason = reason+" A qualified operator must explicitly assume this planted device."

func _detonate(row: Dictionary) -> Dictionary:
	var clearance: Dictionary = _clearance(row)
	if not clearance.ok:
		row.state = "Waiting"
		row.blocked_reason = clearance.message
		return clearance
	var target: Dictionary = _target(row.target_kind,row.target_id)
	var damage := 500*int(row.m06_consumed)
	var hit: Dictionary = _rear().bridges.damage(row.target_id,damage) if row.target_kind == "Bridge" else _rear().field_structures.damage(row.target_id,damage)
	if not hit.ok: return hit
	var blast: Array[String] = []
	for entity in _rear().ledger.snapshot().entities:
		if entity.get("kind","") not in ["PERSON","CARRIER"] or not _present(entity) or entity.position.distance_to(row.position) > 8.0+EPS: continue
		if entity.kind == "PERSON":
			var shelter: Dictionary = _rear().ledger.inspect_entity(entity.holder_id)
			if shelter.get("kind","") == "CARRIER" and shelter.has("vehicle_spec"): continue
			_rear().combat.injure(entity.id,200,true)
		else:
			var blast_hit: Dictionary = _rear().ledger.apply_heavy_damage(entity.id,200,60,"D04 attached demolition blast")
			if blast_hit.get("penetrated",false) and entity.has("crew"):
				var occupants: Array = entity.crew+entity.passengers
				for person_id in occupants:
					if int(blast_hit.health) > 0: _rear().combat.injure(person_id,10,true)
					else:
						var exit_point: Vector2 = _blast_exit(entity.position)
						if exit_point.is_finite() and _rear().ledger.eject_destroyed_carrier_occupant(person_id,entity.id,exit_point).ok:
							_rear().combat.injure(person_id,60,true)
							_rear().ledger.set_person_stress(person_id,0,80)
						else: _rear().ledger.kill_person(person_id,"Destroyed vehicle had no safe exit within eight metres")
		blast.append(entity.id)
	row.state = "Detonated"
	row.health = 0
	row.damage = damage
	row.blocked_reason = ""
	events.append({"at":_rear().time,"id":row.id,"kind":"Detonated","detail":"%d target damage; blast %s" % [damage,str(blast)]})
	return {"ok":true,"target_health":_target(row.target_kind,row.target_id).health,"structural_damage":damage,"blast":blast,"message":"Actual target and nearby entities took D04 damage once."}

func _blast_exit(origin: Vector2) -> Vector2:
	var directions := [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]
	for radius in range(1,9):
		for direction in directions:
			var point: Vector2 = origin+direction*float(radius)
			var cell := Vector2i(floori(point.x),floori(point.y))
			if _rear().combat.world.bounds.has_point(cell) and _rear().combat.world.support(cell,0).ok: return point
	return Vector2.INF

func cancel(id: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state != "Placing": return _fail("Only unplaced D04 work can cancel; placed explosives stay physical.")
	row.state = "Cancelled"
	_release_material(row)
	row.blocked_reason = "Unconsumed staged M06 remains at the actual target."
	return {"ok":true,"message":row.blocked_reason}

func damage_device(id: String, amount: int) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty() or row.state not in ["Placed","Arming","Armed","Waiting","Fusing"] or amount <= 0: return _fail("Only a placed physical D04 device can take positive damage.")
	row.health = maxi(0,int(row.health)-amount)
	if row.health == 0:
		row.state = "Inert"
		row.mode = ""
		row.controller = ""
		row.blocked_reason = "Destroyed attached device; consumed M06 is not recovered and no blast occurs."
		events.append({"at":_rear().time,"id":id,"kind":"Inert","detail":"Device destroyed without detonation"})
	return {"ok":true,"health":row.health,"message":row.blocked_reason if row.health == 0 else "Placed D04 device damaged."}

func next_boundary() -> float:
	var next := INF
	for row in projects.values():
		if row.state == "Placing" and _access(row).ok: next = minf(next,_rear().time+(row.work_required-row.progress)/2.0)
		elif row.state == "Arming" and _withdrawn(row): next = minf(next,float(row.armed_at))
		elif row.state == "Fusing": next = minf(next,float(row.fuse_due))
	return next

func advance_to(at: float) -> void:
	var delta: float = at-_rear().time
	if delta <= EPS: return
	for row in projects.values():
		if row.state == "Placing" and _access(row).ok: row.progress = minf(row.work_required,row.progress+2.0*delta)

func settle() -> bool:
	var changed := false
	for row in projects.values():
		if row.state == "Placing":
			_reserve_material(row)
			var access: Dictionary = _access(row)
			row.blocked_reason = "" if access.ok else access.message
			if row.progress >= row.work_required-EPS and access.ok:
				var spent: Dictionary = _rear().ledger.consume_claimed_batch(row.get("claims",[]),row.id,row.position,10.0,"M06",int(row.m06_reserved),"D04 attached demolition "+row.id)
				if spent.ok:
					row.m06_consumed = row.m06_reserved
					row.receipt = spent.receipt
					row.state = "Placed"
					row.health = 20
					row.blocked_reason = "Two engineers must withdraw at least 25 metres before ten-second arming."
					changed = true
				else: row.blocked_reason = spent.message
		elif row.state == "Placed" and _withdrawn(row):
			row.state = "Arming"
			row.armed_at = _rear().time+10.0
			row.blocked_reason = "Ten-second arming delay."
			changed = true
		elif row.state == "Arming" and not _withdrawn(row):
			row.state = "Placed"
			row.armed_at = -1.0
			row.blocked_reason = "An engineer returned within 25 metres; withdrawal and full arming delay must restart."
			changed = true
		elif row.state == "Arming" and _rear().time+EPS >= row.armed_at:
			if row.mode == "Remote" and not remote_slot_blocker(row.squad,row.id).is_empty():
				row.blocked_reason = remote_slot_blocker(row.squad,row.id)
				continue
			row.state = "Armed"
			row.blocked_reason = "Awaiting mode, authorization and actual clearance."
			changed = true
		elif row.state in ["Armed","Waiting"] and row.mode == "Remote" and not row.controller.is_empty():
			var operator: Dictionary = _operator(row)
			if not operator.ok:
				_lose_operator(row,operator.message)
				changed = true
		elif row.state == "Fusing" and _rear().time+EPS >= row.fuse_due:
			_detonate(row)
			changed = true
	return changed

func inspect(id: String) -> Dictionary:
	var row: Dictionary = projects.get(id,{})
	if row.is_empty(): return _fail("Unknown D04 project.")
	var view: Dictionary = row.duplicate(true)
	view["available_m06"] = _rear().ledger.available_stock_near(row.position,10.0,row.owner,"M06")
	view["committed_m06"] = _committed(row)
	view["local_m06"] = int(view.available_m06)+int(view.committed_m06)
	view["consequences_now"] = _consequences(row)
	view["clearance"] = _clearance(row) if row.state in ["Armed","Waiting","Fusing"] else {"ok":false,"message":"Charge not armed."}
	return view

func snapshot() -> Dictionary:
	var rows := {}
	for id in projects: rows[id] = inspect(id)
	return {"projects":rows,"events":events.duplicate(true)}

func audit() -> Array[String]:
	var errors: Array[String] = []
	for row in projects.values():
		if row.progress < -EPS or row.progress > row.work_required+EPS or row.m06_consumed not in [0,row.m06_reserved] or row.health < 0 or row.health > 20: errors.append("D04 work, device health or explosive accounting: "+row.id)
		if row.state in ["Placed","Arming","Armed","Waiting","Fusing","Detonated"] and row.m06_consumed <= 0: errors.append("Free placed D04 charge: "+row.id)
	return errors

func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
