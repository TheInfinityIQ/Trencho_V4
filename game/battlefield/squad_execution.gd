extends RefCounted
## Executes delivered squad intent on the common clock; no hidden target search.
const EPS := 0.000001
var _rear_ref: WeakRef
var next_decision := 0.0
var motions: Dictionary = {}
var status: Dictionary = {}
var reported: Dictionary = {}
var baseline: Dictionary = {}
var policy: RefCounted

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	next_decision = rear.time

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func next_boundary() -> float:
	var boundary := next_decision
	for motion in motions.values(): boundary = minf(boundary,float(motion.deadline))
	return boundary

func person_committed(id: String) -> bool:
	return motions.has(id)

func advance_to(at: float) -> void:
	var rear: RefCounted = _rear()
	for id in motions.keys():
		var motion: Dictionary = motions[id]
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if not _on_foot(person) or _busy(id) or not person.position.is_equal_approx(motion.expected) or rear.combat.world.revision != motion.revision:
			motions.erase(id)
			continue
		if not motion.allow_unarmed and rear.military._rounds(id) == 0:
			motions.erase(id)
			continue
		if (_rear().combat.pinned.has(id) or _rear().combat.broken.has(id)) and motion.purpose not in ["Fallback","Cover"]:
			motions.erase(id)
			continue
		var remaining: float = maxf(0,at-float(motion.started))
		var point: Vector2 = motion.destination
		for part in motion.plan.parts:
			if remaining <= float(part.seconds):
				point = part.from.lerp(part.to,clampf(remaining/maxf(EPS,float(part.seconds)),0,1))
				break
			remaining -= float(part.seconds)
		var moved: Dictionary = rear.ledger.move_entity(id,motion.place,point)
		if moved.ok: motion.expected = point
		if not moved.ok or at+EPS >= float(motion.deadline): motions.erase(id)

func settle() -> bool:
	var rear: RefCounted = _rear()
	var changed := _clear_unavailable_motions()
	if rear.time+EPS < next_decision: return changed
	next_decision = rear.time+1.0
	if policy != null: policy.tick()
	for squad in rear.military.squads.values():
		var intent: Dictionary = rear.orders.intents.get(squad.id,{})
		if squad.state != "Active" or intent.get("state","") != "Acknowledged" or not intent.constraints.has("destination"): continue
		_execute(squad,intent)
	_clear_unavailable_motions()
	return true

func _clear_unavailable_motions() -> bool:
	var changed := false
	for id in motions.keys():
		if not _on_foot(_rear().ledger.inspect_entity(id)) or _busy(id) or ((_rear().combat.pinned.has(id) or _rear().combat.broken.has(id)) and motions[id].purpose not in ["Fallback","Cover"]):
			motions.erase(id)
			changed = true
	return changed

func _execute(squad: Dictionary, intent: Dictionary) -> void:
	var rear: RefCounted = _rear()
	var destination: String = str(intent.constraints.destination)
	var goal: Dictionary = rear.ledger.inspect_entity(destination)
	if goal.get("kind","") != "PLACE": status[squad.id] = "Destination unavailable"; return
	if not baseline.has(squad.id): baseline[squad.id] = squad.roster.size()
	var active: Array[String] = rear.military._active_roster_members(squad)
	if not squad.vehicle.is_empty() or intent.action == "Move by Transport": status[squad.id] = "Following troop transport order"; return
	var role: String = str(intent.constraints.get("role",squad.kind))
	var assault_blocked: bool = intent.action == "Assault HQ"
	if assault_blocked:
		for id in squad.roster:
			if motions.has(id) and motions[id].purpose != "Fallback": motions.erase(id)
		_report(squad.id,"Inability","HQ assault requires a validated company preparation plan")
	var targets: Array[Dictionary] = _targets(squad.id)
	var withdrawing := active.size() <= float(baseline[squad.id])*0.4
	if not rear.military.capability(squad.id).ok and not (role == "Guard" and intent.action == "Defend HQ"): withdrawing = true
	var broken_count := 0
	var rounds := 0
	for id in active:
		if rear.combat.broken.has(id): broken_count += 1
		rounds += rear.military._rounds(id)
	withdrawing = withdrawing or broken_count > active.size()/2.0
	var offensive: bool = intent.action in ["Seize Objective","Probe","Assault HQ"] and role == "Rifle"
	var advance_allowed := true
	var cohesion: Dictionary = rear.combat.squad_cohesion(squad.id)
	if float(cohesion.get("cohesion",0)) < 0.5: advance_allowed = false
	if cohesion.get("state","") == "Dispersed": withdrawing = true
	if offensive and not targets.is_empty():
		var strength: Dictionary = _strength(squad,targets)
		if strength.own < strength.enemy*0.8: withdrawing = true
		advance_allowed = advance_allowed and strength.own >= strength.enemy*1.3
		if not advance_allowed: _report(squad.id,"Inability","Holding: observed local strength does not support the ordinary attack ratio")
	if not active.is_empty() and float(rounds)/active.size() < 15:
		_report(squad.id,"Low Supply","Urgent local ammunition resupply",true)
		if offensive: advance_allowed = false
	var fallback_id: String = str(intent.constraints.get("fallback_place",destination))
	var fallback: Dictionary = rear.ledger.inspect_entity(fallback_id)
	if withdrawing and fallback.get("kind","") != "PLACE": status[squad.id] = "No safe declared fallback"; return
	status[squad.id] = "Withdrawing" if withdrawing else ("Advancing" if advance_allowed else "Holding for capability or supply")
	if assault_blocked and not withdrawing: status[squad.id] = "Holding for validated HQ assault preparation"
	for id in active:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if _busy(id) or not _on_foot(person): motions.erase(id); continue
		if withdrawing or rear.combat.broken.has(id):
			var at_rally: bool = person.position.distance_to(fallback.position) <= 8
			var defensive_range: float = INF if at_rally else 30.0
			var immediate_threat := false
			for target in targets:
				if person.position.distance_to(target.position) <= defensive_range: immediate_threat = true
			if not rear.combat.broken.has(id) and (at_rally or immediate_threat) and _shoot(id,targets,defensive_range): continue
			_walk(id,fallback_id,fallback.position+_offset(squad.roster.find(id)),true,"Fallback")
			continue
		if assault_blocked: continue
		if rear.combat.pinned.has(id):
			motions.erase(id)
			_shoot(id,targets,30)
			continue
		if person.qualification == "P03" and _care(id): continue
		var positioning: bool = _shoot(id,targets,30 if role == "Medical" else INF)
		if rear.military._rounds(id) == 0:
			motions.erase(id)
			_report(squad.id,"Low Supply","A named rifleman has no local rounds",true)
			continue
		if positioning: continue
		if rear.combat.reloads.values().any(func(job: Dictionary) -> bool: return job.operator == id): motions.erase(id); continue
		if advance_allowed and person.position.distance_to(goal.position) > 8:
			_walk(id,destination,goal.position+_offset(squad.roster.find(id)))
		else: motions.erase(id)
	if rear.objectives.objectives.has(destination) and not active.is_empty():
		var leader: Dictionary = rear.ledger.inspect_entity(active[0])
		if leader.position.distance_to(goal.position) <= 25 and rear.objectives.inspect(destination).owner == leader.owner:
			_report(squad.id,"Complete","Captured "+destination)

func _targets(squad_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id in _rear().orders.contacts.get(squad_id,{}):
		var known: Dictionary = _rear().orders.contact(squad_id,id)
		if known.get("current",false) and known.get("class","") not in ["Resource","Route Hub","Observation","Enemy HQ"]: rows.append(known)
	return rows

func _strength(squad: Dictionary, targets: Array[Dictionary]) -> Dictionary:
	var own := 0.0
	var enemy := 0.0
	var centre: Vector2 = targets[0].position
	var leader: Dictionary = _rear().ledger.inspect_entity(squad.leader)
	for contact in targets:
		var cover: Dictionary = _rear().combat.world.cover(contact.position,leader.position)
		enemy += float(contact.caution_strength)*(1.3 if cover.hit <= 0.5 else (1.15 if cover.hit < 1 else 1.0))
	for friendly in _rear().military.squads.values():
		if friendly.company != squad.company or friendly.kind != "Rifle": continue
		var members: Array[String] = _rear().military._active_roster_members(friendly)
		var local_count := 0
		for id in members:
			var person: Dictionary = _rear().ledger.inspect_entity(id)
			if person.position.distance_to(centre) <= 300 and not _rear().combat.broken.has(id):
				local_count += 1
		if not members.is_empty(): own += _rear().orders._squad_strength(friendly.id)*float(local_count)/members.size()
	return {"own":own,"enemy":enemy}

func _shoot(id: String, targets: Array[Dictionary], maximum_range: float) -> bool:
	var rear: RefCounted = _rear()
	for weapon in rear.ledger.entities_at(id,["WEAPON"]):
		if not weapon.functional or not rear.combat.WEAPONS.has(weapon.design_type): continue
		if weapon.loaded_rounds == 0:
			for stock in rear.ledger.entities_at(id,["STOCK"]):
				if stock.design_type == weapon.ammo_type and stock.available > 0:
					motions.erase(id)
					rear.combat.request_reload(id,weapon.id,stock.id,mini(int(stock.available),int(weapon.loaded_capacity)))
					return true
		for contact in targets:
			var person: Dictionary = rear.ledger.inspect_entity(id)
			if person.position.distance_to(contact.position) > maximum_range: continue
			var shot: Dictionary
			if str(contact.get("class","")).begins_with("T"):
				if contact.class in ["T04","T05"]: continue
				shot = rear.vehicle_combat.fire_personal_at_vehicle(id,contact.target,weapon.id)
			else: shot = rear.combat.fire(id,contact.target,weapon.id,motions.has(id))
			if not shot.ok and "Friendly" in str(shot.get("blocked_reason","")) and weapon.loaded_rounds > 0 and not rear.combat.pinned.has(id):
				var aside: Vector2 = (contact.position-person.position).normalized().orthogonal()*2.0
				_walk(id,person.holder_id,person.position+aside)
				return motions.has(id)
			return false
	return false

func _care(id: String) -> bool:
	var rear: RefCounted = _rear()
	var medic: Dictionary = rear.ledger.inspect_entity(id)
	for patient in rear.ledger.snapshot().entities:
		if patient.kind != "PERSON" or patient.owner != medic.owner or patient.assignment != "Wounded" or patient.health <= 0 or patient.position.distance_to(medic.position) > 60: continue
		if medic.position.distance_to(patient.position) > 2:
			_walk(id,patient.holder_id,patient.position+Vector2(1,0),true,"Care")
			return true
		motions.erase(id)
		for stock in rear.ledger.entities_at(id,["STOCK"]):
			if stock.design_type == "E12" and stock.available > 0: return rear.combat.start_care(id,patient.id,stock.id).ok
	return false

func _walk(id: String, place: String, destination: Vector2, allow_unarmed: bool = false, purpose: String = "Advance") -> void:
	if motions.has(id):
		if motions[id].destination.distance_to(destination) <= 1: return
		motions.erase(id)
	var rear: RefCounted = _rear()
	var person: Dictionary = rear.ledger.inspect_entity(id)
	if person.position.distance_to(destination) <= 1: return
	var plan: Dictionary = rear.combat.world.route({"position":person.position,"facing":(destination-person.position).angle(),"size":Vector2(0.6,0.6),"movement_class":0,"base":2.0,"rate":0.0,"gross_mass_kg":80.0+float(person.contents_mass_kg)},destination)
	if not plan.ok: _report(person.duty_id,"Blocked Route",str(plan.reason)); return
	motions[id] = {"place":place,"destination":destination,"started":rear.time,"deadline":rear.time+float(plan.seconds),"plan":plan,"expected":person.position,"revision":rear.combat.world.revision,"allow_unarmed":allow_unarmed,"purpose":purpose}

func _busy(id: String) -> bool:
	var rear: RefCounted = _rear()
	if rear.forward_supply.person_committed(id) or rear.forward_supply._other_busy(id): return true
	return rear.military.has_method("person_committed") and rear.military.person_committed(id)

func _on_foot(person: Dictionary) -> bool:
	return person.get("kind","") == "PERSON" and person.health > 0 and person.assignment == "Formation Duty" and person.pending_assignment == "None" and str(person.crew_station).is_empty() and _rear().ledger.inspect_entity(person.holder_id).get("kind","") == "PLACE"

func _report(squad: String, kind: String, detail: String, urgent: bool = false) -> void:
	var key := squad+":"+kind+":"+detail
	if reported.has(key): return
	var result: Dictionary = _rear().orders.report(squad,kind,detail,urgent)
	if result.ok: reported[key] = result.id

func _offset(index: int) -> Vector2:
	return Vector2((index%4-1.5)*2,(floori(index/4.0)-0.5)*2)

func snapshot() -> Dictionary:
	return {"status":status.duplicate(),"moving_people":motions.keys()}

func audit() -> Array[String]:
	var errors: Array[String] = []
	for id in motions:
		if not _on_foot(_rear().ledger.inspect_entity(id)): errors.append("Non-dismounted person retains battlefield motion: "+id)
	return errors
