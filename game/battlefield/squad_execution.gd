extends RefCounted
## Executes delivered squad intent on the common clock; no hidden target search.
const EPS := 0.000001
const Vehicles = preload("res://game/battlefield/vehicle_execution.gd")
var vehicle_execution: RefCounted
var _rear_ref: WeakRef
var next_decision := 0.0
var motions: Dictionary = {}
var status: Dictionary = {}
var reported: Dictionary = {}
var baseline: Dictionary = {}
var policy: RefCounted
var rifle_collection: Dictionary = {}
var _collection_sequence := 0

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	vehicle_execution = Vehicles.new(rear)
	next_decision = rear.time

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func next_boundary() -> float:
	var boundary: float = minf(next_decision,vehicle_execution.next_boundary())
	for motion in motions.values(): boundary = minf(boundary,float(motion.deadline))
	return boundary

func person_committed(id: String) -> bool:
	return motions.has(id)

func advance_to(at: float) -> void:
	var rear: RefCounted = _rear()
	for id in motions.keys():
		var motion: Dictionary = motions[id]
		var person: Dictionary = rear.ledger.inspect_person_status(id)
		if not _supply_motion_valid(person,motion): motions.erase(id); continue
		if motion.purpose in ["Fallback","Supply","Supply Return"] and not _fallback_safe(person,motion.destination):
			motions.erase(id)
			_report(person.duty_id,"Inability","Delivered hostile fire made the declared route unsafe; movement stopped",true)
			continue
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
	# Consume only already-named, acknowledged refill readiness before mounted
	# fire. This adds no strategic decision or resupply-cycle generation.
	if policy != null and policy.has_method("settle_vehicle_departures"):
		changed = policy.settle_vehicle_departures() or changed
	changed = vehicle_execution.settle() or changed
	if rear.time+EPS < next_decision: return changed
	next_decision = rear.time+1.0
	if policy != null: policy.tick()
	for squad in rear.military.squads.values():
		var intent: Dictionary = rear.orders.intents.get(squad.id,{})
		if squad.state != "Active" or intent.get("state","") != "Acknowledged" or not intent.constraints.has("destination"):
			_interrupt_collection(squad.id,"Awaiting an active squad and current acknowledged operation.")
			continue
		_execute(squad,intent)
	_clear_unavailable_motions()
	return true

func _clear_unavailable_motions() -> bool:
	var changed := false
	for id in motions.keys():
		var person: Dictionary = _rear().ledger.inspect_person_status(id)
		if not _supply_motion_valid(person,motions[id]) or not _on_foot(person) or _busy(id) or ((_rear().combat.pinned.has(id) or _rear().combat.broken.has(id)) and motions[id].purpose not in ["Fallback","Cover"]):
			motions.erase(id)
			changed = true
	return changed

func _execute(squad: Dictionary, intent: Dictionary) -> void:
	var rear: RefCounted = _rear()
	var destination: String = str(intent.constraints.destination)
	var goal: Dictionary = rear.ledger.inspect_entity(destination,{},false)
	if goal.get("kind","") != "PLACE":
		_interrupt_collection(squad.id,"Current operation destination is unavailable.")
		status[squad.id] = "Destination unavailable"
		return
	if not baseline.has(squad.id): baseline[squad.id] = squad.roster.size()
	var active: Array[String] = rear.military._active_roster_members(squad)
	if not squad.vehicle.is_empty() or intent.action == "Move by Transport":
		_interrupt_collection(squad.id,"Current operation assigns physical transport.")
		for id in squad.roster: motions.erase(id)
		status[squad.id] = "Following troop transport order"
		return
	var role: String = str(intent.constraints.get("role",squad.kind))
	if role in ["Medical","Support"] and intent.action == "Support Formation": goal = _support_goal(squad,goal,intent.constraints.get("supported_squads",[]))
	var assault_blocked: bool = intent.action == "Assault HQ"
	if assault_blocked:
		for id in squad.roster:
			if motions.has(id) and motions[id].purpose != "Fallback": motions.erase(id)
		_report(squad.id,"Inability","HQ assault requires a validated company preparation plan")
	var targets: Array[Dictionary] = _targets(squad.id)
	var withdrawing := active.size() <= float(baseline[squad.id])*0.4
	var execution_capable: bool = rear.military.capability(squad.id,"Sustained Execution").ok
	var broken_count := 0
	var rounds := 0
	for id in active:
		if rear.combat.broken.has(id): broken_count += 1
		rounds += rear.military._rounds(id)
	var urgent: bool = not active.is_empty() and float(rounds)/active.size() < 15
	var collectable: bool = _collection_context(squad,intent,urgent) and not _collection_threat(active,targets)
	if not execution_capable and not collectable and not (role == "Guard" and intent.action == "Defend HQ"): withdrawing = true
	withdrawing = withdrawing or broken_count > active.size()/2.0
	var offensive: bool = intent.action in ["Seize Objective","Probe","Assault HQ"] and role == "Rifle"
	var armour: Dictionary = _blocking_armour(squad,goal.position) if offensive and squad.owner == "army-red" else {}
	if not armour.is_empty():
		_report(squad.id,"Inability","Delivered %s on the assigned approach; no actual penetrating support. Need an anti-armour capability; attempting the declared safe fallback." % str(armour.class),true)
	var advance_allowed := true
	var cohesion: Dictionary = rear.combat.squad_cohesion(squad.id)
	if float(cohesion.get("cohesion",0)) < 0.5: advance_allowed = false
	if cohesion.get("state","") == "Dispersed": withdrawing = true
	if offensive and not targets.is_empty():
		var strength: Dictionary = _strength(squad,targets)
		if strength.own < strength.enemy*0.8: withdrawing = true
		advance_allowed = advance_allowed and strength.own >= strength.enemy*1.3
		if not advance_allowed: _report(squad.id,"Inability","Holding: observed local strength does not support the ordinary attack ratio")
	if urgent:
		_report(squad.id,"Low Supply","Urgent local ammunition resupply",true)
		if offensive: advance_allowed = false
	var fallback_id: String = str(intent.constraints.get("fallback_place",destination))
	var fallback: Dictionary = rear.ledger.inspect_entity(fallback_id,{},false)
	if withdrawing and fallback.get("kind","") != "PLACE": status[squad.id] = "No safe declared fallback"; return
	if _collect_ammunition(squad,intent,active,collectable,withdrawing): return
	status[squad.id] = "Withdrawing" if withdrawing else ("Advancing" if advance_allowed else "Holding for capability or supply")
	if assault_blocked and not withdrawing: status[squad.id] = "Holding for validated HQ assault preparation"
	if not armour.is_empty() and not withdrawing: status[squad.id] = "Observed armour: seeking a safe declared fallback; otherwise holding"
	for id in active:
		var person: Dictionary = rear.ledger.inspect_person_status(id)
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
		if not armour.is_empty():
			# Existing withdrawal/Broken behavior above takes priority. Pinned
			# people retain their stopped immediate-survival behavior.
			if motions.has(id) and motions[id].purpose != "Fallback": motions.erase(id)
			if rear.combat.pinned.has(id):
				motions.erase(id)
				_shoot(id,targets,30)
				continue
			if _shoot(id,targets,30): continue
			if fallback.get("kind","") == "PLACE":
				_walk(id,fallback_id,fallback.position+_offset(squad.roster.find(id)),true,"Fallback")
			else:
				motions.erase(id)
				_report(squad.id,"Inability","Observed armour blocks this mission and no declared fallback exists; holding",true)
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
			var returning: bool = rifle_collection.get(squad.id,{}).get("released",false) and rifle_collection[squad.id].state != "Operating"
			_walk(id,destination,goal.position+_offset(squad.roster.find(id)),false,"Supply Return" if returning else "Advance")
		else: motions.erase(id)
	if rifle_collection.get(squad.id,{}).get("released",false):
		var arrived := true
		for id in active:
			if rear.ledger.inspect_person_status(id).position.distance_to(goal.position) > 8: arrived = false
		if arrived: rifle_collection[squad.id].state = "Operating"
	if rear.objectives.objectives.has(destination) and not active.is_empty():
		var leader: Dictionary = rear.ledger.inspect_person_status(active[0])
		if leader.position.distance_to(goal.position) <= 25 and rear.objectives.inspect(destination).owner == leader.owner:
			_report(squad.id,"Complete","Captured "+destination)

func _collection_owner() -> RefCounted:
	return policy.squad_supply_owner() if policy != null and policy.has_method("squad_supply_owner") else null

func _collection_context(squad: Dictionary, intent: Dictionary, urgent: bool) -> bool:
	if squad.kind != "Rifle" or intent.action == "Defend HQ" or _collection_owner() == null: return false
	if intent.get("parent","") != squad.platoon: return false
	if str(intent.constraints.get("supply_rendezvous","")).is_empty(): return false
	var row: Dictionary = rifle_collection.get(squad.id,{})
	return (urgent or (not row.is_empty() and not row.released)) and _rear().military.capability(squad.id,"Supply Collection").ok

func _interrupt_collection(squad_id: String, reason: String) -> void:
	var row: Dictionary = rifle_collection.get(squad_id,{})
	if row.is_empty(): return
	for id in motions.keys():
		if motions[id].get("squad","") == squad_id and motions[id].purpose in ["Supply","Supply Return"]: motions.erase(id)
	if not row.released:
		var owner := _collection_owner()
		if owner != null: owner.interrupt_squad_replenishment(squad_id,row.cycle)
		row.state = "Interrupted"
		row.blocker = reason
	elif row.state != "Operating": row.blocker = reason

func _collect_ammunition(squad: Dictionary, intent: Dictionary, active: Array[String], collectable: bool, withdrawing: bool) -> bool:
	var rear := _rear()
	var row: Dictionary = rifle_collection.get(squad.id,{})
	if not row.is_empty() and intent.get("parent","") != squad.platoon:
		_interrupt_collection(squad.id,"Collection needs the actual current parent's acknowledged operation.")
		status[squad.id] = "Awaiting actual parent reassessment"
		return true
	if not row.is_empty() and row.released:
		row.intent = intent.id
		if intent.action == "Defend HQ": row.state = "Operating"
	if not collectable or withdrawing:
		if not row.is_empty() and not row.released:
			_interrupt_collection(squad.id,"Immediate defence, casualty withdrawal or current command takes priority over routine collection.")
		return false
	var stop_id: String = str(intent.constraints.supply_rendezvous)
	if not row.is_empty() and not row.released and (row.get("parent",squad.platoon) != squad.platoon or row.get("owner",squad.owner) != squad.owner):
		_interrupt_collection(squad.id,"A changed parent must reassess after the prior physical collection obligations clear.")
		var prior: Dictionary = _collection_owner().squad_replenishment_status(squad.id)
		if not prior.get("handling_clear",false):
			status[squad.id] = row.blocker
			return true
		row = {} # A new acknowledged actual parent names a new cycle; no reparenting.
	if not row.is_empty() and not row.released and row.stop != stop_id:
		_interrupt_collection(squad.id,"Current parent changed the supply rendezvous; the existing physical obligation needs reassessment.")
		status[squad.id] = rifle_collection[squad.id].blocker
		return true
	if row.is_empty() or row.released:
		_collection_sequence += 1
		row = {"cycle":"%s:rifle-supply-%04d" % [squad.id,_collection_sequence],"stop":stop_id,"state":"Collecting","released":false,"intent":intent.id,"parent":squad.platoon,"owner":squad.owner,"blocker":""}
		rifle_collection[squad.id] = row
		_report(squad.id,"Low Supply","Urgent Rifle collection %s at %s." % [row.cycle,stop_id],true)
	row.intent = intent.id
	var owner := _collection_owner()
	var stop: Dictionary = rear.ledger.inspect_entity(stop_id,{},false)
	if stop.get("kind","") != "PLACE" or stop_id != owner.stop_id:
		_interrupt_collection(squad.id,"No local ammunition team serves the assigned rendezvous.")
		status[squad.id] = row.blocker
		return true
	var requested: Dictionary = owner.request_squad_replenishment(squad.id,row.cycle,60)
	if not requested.get("ok",false):
		row.blocker = str(requested.get("message","Named Rifle refill is unavailable."))
		status[squad.id] = row.blocker
		return true
	var refill: Dictionary = owner.squad_replenishment_status(squad.id)
	var arrived := true
	for id in active:
		var person: Dictionary = rear.ledger.inspect_person_status(id)
		if person.holder_id != stop_id or person.position.distance_to(stop.position) > 8: arrived = false
	if arrived and refill.get("state","") == "Complete" and refill.get("handling_clear",false):
		var released: Dictionary = owner.release_squad_replenishment(squad.id,row.cycle)
		if released.get("ok",false):
			row.released = true
			row.state = "Returning to current operation"
			row.blocker = ""
			return false
		row.blocker = str(released.get("message","Current physical refill cannot be handed off."))
	else: row.blocker = str(refill.get("blocker","Waiting for physical receipt and clear couriers."))
	row.state = "Waiting for refill" if arrived else "Collecting"
	status[squad.id] = "%s at %s: %d actual E02 still needed; %d committed. %s" % [row.state,stop_id,int(refill.get("needed",0)),int(refill.get("committed",0)),row.blocker]
	for id in active:
		var person: Dictionary = rear.ledger.inspect_person_status(id)
		if _busy(id) or rear.combat.pinned.has(id): motions.erase(id); continue
		if rear.combat.broken.has(id):
			var fallback_id: String = str(intent.constraints.get("fallback_place",stop_id))
			var fallback: Dictionary = rear.ledger.inspect_entity(fallback_id,{},false)
			if fallback.get("kind","") == "PLACE": _walk(id,fallback_id,fallback.position+_offset(squad.roster.find(id)),true,"Fallback")
			continue
		if person.holder_id == stop_id and person.position.distance_to(stop.position) <= 8:
			# Routine collection now owns this stationary Rifle carrier. An old
			# Advance/return motion cannot carry a refilled member away early.
			motions.erase(id)
			continue
		_walk(id,stop_id,stop.position+_offset(squad.roster.find(id)),true,"Supply")
	return true

func _collection_threat(active: Array[String], targets: Array[Dictionary]) -> bool:
	for id in active:
		var person: Dictionary = _rear().ledger.inspect_person_status(id)
		for target in targets:
			if person.position.distance_to(target.position) <= 30: return true
	return false

func _supply_motion_valid(person: Dictionary, motion: Dictionary) -> bool:
	if motion.purpose not in ["Supply","Supply Return"]: return true
	var intent: Dictionary = _rear().orders.intents.get(motion.squad,{})
	var squad: Dictionary = _rear().military.squads.get(motion.squad,{})
	return not squad.is_empty() and person.get("duty_id","") == motion.squad and intent.get("parent","") == squad.platoon and intent.get("state","") == "Acknowledged" and intent.get("id","") == motion.intent

func _support_goal(squad: Dictionary, objective: Dictionary, supported_squads: Array) -> Dictionary:
	var centre := Vector2.ZERO
	var count := 0
	for friendly in _rear().military.squads.values():
		if friendly.owner != squad.owner or friendly.kind != "Rifle" or friendly.id not in supported_squads: continue
		for id in _rear().military._active_roster_members(friendly):
			var person: Dictionary = _rear().ledger.inspect_person_status(id)
			if not _on_foot(person): continue
			centre += person.position
			count += 1
	var result := objective.duplicate(true)
	if count == 0: return result
	centre /= count
	var direction: float = 1.0 if squad.owner == "army-blue" else -1.0
	result.position = Vector2(centre.x,centre.y-direction*60.0)
	return result

func _blocking_armour(squad: Dictionary, destination: Vector2) -> Dictionary:
	# Read only information actually delivered to this unit. An unseen hull or
	# an unrelated contact elsewhere cannot alter the assigned mission.
	var rear: RefCounted = _rear()
	if rear.orders._has_antiarmour(squad.platoon): return {}
	var leader: Dictionary = rear.ledger.inspect_person_status(squad.leader)
	if leader.is_empty() or leader.health <= 0: return {}
	var delta: Vector2 = destination-leader.position
	for id in rear.orders.contacts.get(squad.id,{}):
		var known: Dictionary = rear.orders.contact(squad.id,id)
		if known.get("confidence",0) <= 0 or not known.position.is_finite() or known.get("class","") not in ["T04","T05"]: continue
		var fraction := 0.0 if delta.length_squared() <= EPS else clampf((known.position-leader.position).dot(delta)/delta.length_squared(),0,1)
		var nearest: Vector2 = leader.position+delta*fraction
		var effective := 450.0 if known.class == "T04" else 700.0
		if nearest.distance_to(known.position) <= effective+float(known.get("uncertainty_m",0)): return known
	return {}

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
	var leader: Dictionary = _rear().ledger.inspect_person_status(squad.leader)
	# Cohesion already halts offensive coordination during the real replacement
	# delay; no cover/strength origin can be read from a missing leader.
	if leader.is_empty() or leader.health <= 0 or leader.assignment != "Formation Duty": return {"own":0.0,"enemy":0.0}
	for contact in targets:
		var cover: Dictionary = _rear().combat.world.cover(contact.position,leader.position)
		enemy += float(contact.caution_strength)*(1.3 if cover.hit <= 0.5 else (1.15 if cover.hit < 1 else 1.0))
	for friendly in _rear().military.squads.values():
		if friendly.company != squad.company or friendly.kind != "Rifle": continue
		own += _rear().orders._squad_strength(friendly.id,centre,300.0)
	return {"own":own,"enemy":enemy}

func _shoot(id: String, targets: Array[Dictionary], maximum_range: float) -> bool:
	var rear: RefCounted = _rear()
	for weapon in rear.ledger.entities_at(id,["WEAPON"],false):
		if not weapon.functional or not rear.combat.WEAPONS.has(weapon.design_type): continue
		if weapon.loaded_rounds == 0:
			for stock in rear.ledger.entities_at(id,["STOCK"],false):
				if stock.design_type == weapon.ammo_type and stock.available > 0:
					motions.erase(id)
					rear.combat.request_reload(id,weapon.id,stock.id,mini(int(stock.available),int(weapon.loaded_capacity)))
					return true
		for contact in targets:
			var person: Dictionary = rear.ledger.inspect_person_status(id)
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
	var medic: Dictionary = rear.ledger.inspect_person_status(id)
	for patient in rear.ledger.entities_of_kind(rear.ledger.Records.Kind.PERSON,false):
		if patient.kind != "PERSON" or patient.owner != medic.owner or patient.assignment != "Wounded" or patient.health <= 0 or patient.position.distance_to(medic.position) > 60: continue
		if medic.position.distance_to(patient.position) > 2:
			_walk(id,patient.holder_id,patient.position+Vector2(1,0),true,"Care")
			return true
		motions.erase(id)
		for stock in rear.ledger.entities_at(id,["STOCK"],false):
			if stock.design_type == "E12" and stock.available > 0: return rear.combat.start_care(id,patient.id,stock.id).ok
	return false

func _walk(id: String, place: String, destination: Vector2, allow_unarmed: bool = false, purpose: String = "Advance") -> void:
	if motions.has(id):
		if motions[id].destination.distance_to(destination) <= 1: return
		motions.erase(id)
	var rear: RefCounted = _rear()
	var person: Dictionary = rear.ledger.inspect_entity(id)
	if person.position.distance_to(destination) <= 1: return
	var supply_move: bool = purpose in ["Supply","Supply Return"]
	if purpose in ["Fallback","Supply","Supply Return"] and not _fallback_safe(person,destination):
		_report(person.duty_id,"Inability","Declared route crosses delivered hostile fire; holding for a safe route",true)
		return
	if supply_move and person.position.distance_to(destination) > 600 and _collection_transport_exists(person.owner):
		_collection_transport_blocked(person.duty_id)
		return
	var plan: Dictionary = rear.combat.world.route({"position":person.position,"facing":(destination-person.position).angle(),"size":Vector2(0.6,0.6),"movement_class":0,"base":2.0,"rate":0.0,"gross_mass_kg":80.0+float(person.contents_mass_kg)},destination)
	if not plan.ok: _report(person.duty_id,"Blocked Route",str(plan.reason)); return
	if supply_move and float(plan.distance) > 600 and _collection_transport_exists(person.owner):
		_collection_transport_blocked(person.duty_id)
		return
	motions[id] = {"place":place,"destination":destination,"started":rear.time,"deadline":rear.time+float(plan.seconds),"plan":plan,"expected":person.position,"revision":rear.combat.world.revision,"allow_unarmed":allow_unarmed,"purpose":purpose}
	if supply_move:
		motions[id].squad = person.duty_id
		motions[id].intent = str(rear.orders.intents.get(person.duty_id,{}).get("id",""))
	if supply_move and rifle_collection.has(person.duty_id):
		if float(plan.distance) > 600:
			_report(person.duty_id,"Inability","No actual military personnel transport exists; safe collection foot march ETA %.1f simulation seconds." % float(plan.seconds))

func _collection_transport_exists(owner: String) -> bool:
	# Comparing a lift's arrival/trip ETA and its parent-approved admission is
	# still unconnected here. A busy existing hull does not mean none exists.
	for hull_id in _rear().military.vehicles:
		var hull: Dictionary = _rear().ledger.inspect_entity(hull_id,{},false)
		if hull.get("owner","") == owner and hull.get("health",0) > 0 and int(hull.get("vehicle_spec",{}).get("passenger_seats",0)) > 0: return true
	return false

func _collection_transport_blocked(squad_id: String) -> void:
	var row: Dictionary = rifle_collection.get(squad_id,{})
	if row.is_empty(): return
	row.blocker = "Collection journey exceeds 600 m. A passenger vehicle exists, but this build cannot yet arrange its collection trip."
	row.state = "Awaiting transport reassessment"
	status[squad_id] = row.blocker
	_report(squad_id,"Inability",row.blocker,true)

func _fallback_safe(person: Dictionary, destination: Vector2) -> bool:
	var delta: Vector2 = destination-person.position
	for target_id in _rear().orders.contacts.get(person.duty_id,{}):
		var known: Dictionary = _rear().orders.contact(person.duty_id,target_id)
		if known.get("confidence",0) <= 0 or not known.position.is_finite(): continue
		if known.get("class","") in ["Resource","Route Hub","Observation","Enemy HQ","T01","T02"]: continue
		var fraction: float = (known.position-person.position).dot(delta)/delta.length_squared()
		# Existing fire at the starting point does not prohibit moving away from it.
		if fraction <= 0: continue
		var closest: Vector2 = person.position+delta*clampf(fraction,0,1)
		var effective: float = {"T03":250.0,"T04":450.0,"T05":700.0,"P07":300.0,"P04":250.0}.get(known.get("class",""),160.0)
		if closest.distance_to(known.position) <= effective: return false
	return true

func _busy(id: String) -> bool:
	var rear: RefCounted = _rear()
	if rear.forward_supply.person_committed(id) or rear.forward_supply._other_busy(id): return true
	return rear.military.has_method("person_committed") and rear.military.person_committed(id)

func _on_foot(person: Dictionary) -> bool:
	return person.get("kind","") == "PERSON" and person.health > 0 and person.assignment == "Formation Duty" and person.pending_assignment == "None" and str(person.crew_station).is_empty() and _rear().ledger.entity_kind(person.holder_id) == "PLACE"

func _report(squad: String, kind: String, detail: String, urgent: bool = false) -> void:
	var key := squad+":"+kind+":"+detail
	if reported.has(key): return
	var result: Dictionary = _rear().orders.report(squad,kind,detail,urgent)
	if result.ok: reported[key] = result.id

func _offset(index: int) -> Vector2:
	return Vector2((index%4-1.5)*2,(floori(index/4.0)-0.5)*2)

func snapshot() -> Dictionary:
	return {"status":status.duplicate(),"moving_people":motions.keys(),"vehicles":vehicle_execution.snapshot(),"rifle_collection":rifle_collection.duplicate(true)}

func audit() -> Array[String]:
	var errors: Array[String] = []
	for id in motions:
		if not _on_foot(_rear().ledger.inspect_entity(id)): errors.append("Non-dismounted person retains battlefield motion: "+id)
	return errors
