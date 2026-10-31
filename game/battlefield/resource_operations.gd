extends RefCounted
## Bounded resource proposals. Opening alone issues orders; Execution owns action.
## Reports/own facts are synchronous small policy stages. Terrain work shares one
## returned-frame cooperative allowance, not a fresh deadline per candidate.
const EPS := 0.000001
const REVIEW_SECONDS := 10.0
const CHANGE_REPORTS := ["Inability","Casualties","Lost Capability","Low Supply","Blocked Route","Opportunity","Threatened Crossing"]
const FIRE_RANGE := {"T03":250.0,"T04":450.0,"T05":700.0,"P07":300.0,"P04":250.0}
var planning_revision: int = 0
var _rear_ref: WeakRef
var _rows: Dictionary = {}
var _resources: Dictionary = {}
var _report_cursor := 0
var _turn := 0
var _planning_turn := 0
var _observation: Dictionary = {}
var _observed: Dictionary = {}
var _observation_cursors: Dictionary = {}

func _init(rear: RefCounted, armies: Dictionary) -> void:
	_rear_ref = weakref(rear)
	# Public authored identities/positions, not live remote ownership or occupants.
	for id in rear.objectives.objectives:
		var objective: Dictionary = rear.objectives.objectives[id]
		if objective.kind == "Resource": _resources[id] = objective.position
	for owner in armies:
		_rows[owner] = {"owner":owner,"active":false,"known":{},"served":{},"operation":{},"issued_operation":{},"trigger":false,"completed":false,
			"next_review":0.0,"search":{},"blocker":"","threats":[],"generation":0,"inputs":[]}

func proposal(owner: String) -> Dictionary:
	return _rows.get(owner,{}).get("operation",{}).duplicate(true)

func blocker(owner: String) -> String:
	return str(_rows.get(owner,{}).get("blocker",""))

func observation() -> Dictionary:
	return _observation.duplicate()

func record_observed(key: String, affiliation: String) -> void:
	_observed[key] = {"affiliation":affiliation,"observer":_observation.get("observer",""),"position":_observation.get("position",Vector2.INF),"observed_at":_observation.get("observed_at",_rear().time)}

func record_issued(owner: String, version: String, intent: String) -> void:
	var row: Dictionary = _rows[owner]
	if row.operation.get("version","") != version or not str(row.operation.get("intent","")).is_empty(): return
	row.operation.intent = intent
	row.operation.issued_at = _rear().time
	row.issued_operation = row.operation.duplicate(true)
	row.served[row.operation.objective] = _rear().time

func tick(armies: Dictionary, available: Dictionary, enabled: Dictionary) -> void:
	_observation = {}
	if not _rear().vehicle_departures_allowed: return
	var units := 0
	# OrderService appends only after actual root delivery; pending owns transit.
	while _report_cursor < _rear().orders.reports.size() and units < 16:
		_observe_report(_rear().orders.reports[_report_cursor],armies)
		_report_cursor += 1
		units += 1
	var owners: Array = armies.keys()
	if owners.is_empty(): return
	var owner: String = str(owners[_turn%owners.size()])
	_turn += 1
	var row: Dictionary = _rows[owner]
	if not enabled.get(owner,false): row.search = {}; return
	if not row.active: return # The initial actual lift/capture/report chain is intact.
	var army: Dictionary = armies[owner]
	_observation = _local_observation(army,available.get(owner,[]),owner)
	if row.search.is_empty():
		if _rear().time+EPS < float(row.next_review): return
		var current_force := _force(army,available.get(owner,[]),owner)
		var inputs: Array = [_rear().combat.world.get_instance_id(),_rear().combat.world.revision,current_force.squads]
		for leader in current_force.leaders: inputs.append([leader.id,leader.members])
		if inputs != row.inputs: row.inputs = inputs; row.trigger = true
		var threats: Array = _threatened(row,_contacts(army.root))
		if threats != row.threats: row.threats = threats; row.trigger = true
		row.next_review = _rear().time+REVIEW_SECONDS
		if not row.trigger: return
		if not row.operation.is_empty() and (str(row.operation.get("intent","")).is_empty() or _rear().time < float(row.operation.issued_at)+REVIEW_SECONDS-EPS): return
		_begin_search(row,army,available.get(owner,[]),owner)

func has_planning_work() -> bool:
	for row in _rows.values():
		if not row.search.is_empty(): return true
	return false

func invalidate_planning() -> void:
	for row in _rows.values():
		row.search = {}
		if str(row.operation.get("intent","")).is_empty(): row.operation = row.issued_operation.duplicate(true)
		row.trigger = row.active
		row.next_review = _rear().time
		if row.active: row.blocker = "Inputs changed; current issued operation continues until fresh resource review."
	_observation = {}
	planning_revision += 1

func cancel_planning() -> void:
	for row in _rows.values():
		row.search = {}
		if str(row.operation.get("intent","")).is_empty(): row.operation = row.issued_operation.duplicate(true)
		row.trigger = false
		if row.active: row.blocker = "Private resource planning cancelled; issued orders retain their actual owner."
	_observation = {}
	planning_revision += 1

func pump_planning(_allow_commit: bool, max_units: int = 128, budget_usec: int = 4000) -> bool:
	# Pure geometry and proposal metadata only, including while paused. Policy
	# ticks retain all report submission, review/capture and real order issuance.
	if max_units <= 0 or budget_usec <= 0: return false
	var deadline: int = Time.get_ticks_usec()+budget_usec
	var units := 0
	var owners: Array = _rows.keys()
	var owner := ""
	while units < owners.size() and units < max_units and Time.get_ticks_usec() < deadline:
		var candidate_owner: String = str(owners[_planning_turn%owners.size()])
		_planning_turn += 1
		units += 1
		if not _rows[candidate_owner].search.is_empty(): owner = candidate_owner; break
	if owner.is_empty(): return false
	var row: Dictionary = _rows[owner]
	var search: Dictionary = row.search
	if search.world != _rear().combat.world or search.revision != search.world.revision:
		row.search = {}; row.trigger = true; row.next_review = _rear().time
		row.blocker = "Terrain changed; reassessing the resource routes."
		planning_revision += 1
		return false
	while units < max_units and Time.get_ticks_usec() < deadline:
		if search.work != null:
			if search.work.invalidated:
				row.search = {}; row.trigger = true; row.next_review = _rear().time
				planning_revision += 1
				return false
			if not search.work.done:
				search.work.step(max_units-units,maxi(1,deadline-Time.get_ticks_usec()))
				return false # Child consumes the frame's entire remaining allowance.
			units += 1
			_finish_leg(row)
			continue
		units += 1
		if search.index >= search.candidates.size(): _choose(row,search.army,search.available,owner); return false
		var candidate: Dictionary = search.candidates[search.index]
		if candidate.leg >= candidate.legs.size():
			candidate.score = float(candidate.base)-0.1*float(candidate.seconds)-30.0*float(candidate.enemy)/float(search.force.strength)
			search.ready.append(candidate)
			search.index += 1
			continue
		var leg: Dictionary = candidate.legs[candidate.leg]
		var error := _hazard(owner,[leg.from,leg.to])
		if not error.is_empty(): _reject(search,candidate,error); continue
		if leg.safe and not _safe_segment(leg.from,leg.to,search.contacts): _reject(search,candidate,"Known hostile fire excludes the supply or fallback corridor."); continue
		if (leg.from as Vector2).distance_to(leg.to) <= EPS: candidate.leg += 1; continue
		search.work = search.world.begin_route({"position":leg.from,"facing":(leg.to-leg.from).angle(),"size":Vector2(0.6,0.6),
			"movement_class":0,"base":2.0,"rate":0.0,"gross_mass_kg":leg.mass},leg.to)
	return false

func _observe_report(report: Dictionary, armies: Dictionary) -> void:
	for owner in armies:
		var army: Dictionary = armies[owner]
		if report.get("current_at","") != army.root: continue
		var row: Dictionary = _rows[owner]
		if report.kind == "Complete" and str(report.detail).begins_with("Captured "):
			var id: String = str(report.detail).trim_prefix("Captured ")
			if not _resources.has(id): return
			if float(report.observed_at) >= float(row.known.get(id,{}).get("at",-INF)): row.known[id] = {"owner":owner,"at":report.observed_at}
			if id == "resource-centre-"+("blue" if owner == _rear().PLAYER else "red"): row.active = true
			if row.active and (row.operation.is_empty() or (row.operation.objective == id and float(report.observed_at)+EPS >= float(row.operation.get("issued_at",INF)))):
				row.completed = true; row.trigger = true
		elif report.kind == "Progress":
			for id in _resources:
				for affiliation in ["army-blue","army-red","Neutral"]:
					if report.detail != "Resource "+id+" observed "+affiliation: continue
					var known_owner: String = "" if affiliation == "Neutral" else str(affiliation)
					var prior: Dictionary = row.known.get(id,{})
					if float(report.observed_at) < float(prior.get("at",-INF)): return
					if prior.get("owner","Unknown") != known_owner and row.active: row.trigger = true
					row.known[id] = {"owner":known_owner,"at":report.observed_at}
					return
		elif row.active and report.kind in CHANGE_REPORTS: row.trigger = true
		return

func _local_observation(army: Dictionary, available: Array, owner: String) -> Dictionary:
	var ids: Array = _resources.keys()
	if ids.is_empty(): return {}
	var index: int = int(_observation_cursors.get(owner,0))
	var id: String = str(ids[index%ids.size()])
	_observation_cursors[owner] = index+1
	for squad_id in available:
		var squad: Dictionary = _rear().military.squads.get(squad_id,{})
		if squad.get("owner","") != owner or not _rear().military.capability(squad_id,"Sustained Execution").ok: continue
		var person: Dictionary = _rear().ledger.inspect_person_status(squad.leader)
		if _rear().ledger.entity_kind(str(person.get("holder_id",""))) != "PLACE" or person.position.distance_to(_resources[id]) > 25.0: continue
		if not _rear().combat.world.is_visible(person.position,_resources[id]): continue
		# The live owner is read only at an actual local observer, never remotely.
		var affiliation: String = str(_rear().objectives.objectives[id].owner)
		if affiliation.is_empty(): affiliation = "Neutral"
		var key := owner+":"+id
		if _observed.get(key,{}).get("affiliation","") == affiliation: return {}
		return {"source":squad_id,"observer":person.id,"position":person.position,"observed_at":_rear().time,
			"detail":"Resource "+id+" observed "+affiliation,"key":key,"affiliation":affiliation}
	return {}

func _contacts(root: String) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	for id in _rear().orders.contacts.get(root,{}):
		var known: Dictionary = _rear().orders.contact(root,id)
		if known.get("confidence",0) > 0 and known.get("observed_strength",0) > 0 and known.get("position",Vector2.INF).is_finite(): contacts.append(known)
	return contacts

func _threatened(row: Dictionary, contacts: Array[Dictionary]) -> Array:
	var result: Array = []
	for id in _resources:
		if row.known.get(id,{}).get("owner","") != str(row.get("owner","")): continue
		for known in contacts:
			if _resources[id].distance_to(known.position) <= float(FIRE_RANGE.get(known.get("class",""),160.0))+100.0+float(known.uncertainty_m): result.append(id); break
	return result

func _force(army: Dictionary, available: Array, owner: String) -> Dictionary:
	var rear: RefCounted = _rear()
	var leaders: Array[Dictionary] = []
	var squads: Array[String] = []
	var strength := 0.0
	for id in available:
		if id == army.rifles[2] or id not in army.rifles: continue # Keep the real HQ guard.
		var squad: Dictionary = rear.military.squads.get(id,{})
		if squad.get("owner","") != owner or squad.get("state","") != "Active" or squad.company != army.company: continue
		if not rear.military.capability(id,"Sustained Execution").ok: continue
		var cohesion: Dictionary = rear.combat.squad_cohesion(id)
		if float(cohesion.get("cohesion",0)) < 0.5 or cohesion.get("state","") == "Dispersed": continue
		var leader: Dictionary = rear.ledger.inspect_entity(squad.leader)
		if rear.combat.pinned.has(squad.leader) or rear.combat.broken.has(squad.leader) or rear.ledger.entity_kind(leader.holder_id) != "PLACE" or rear.military.person_committed(squad.leader) or rear.forward_supply.person_committed(squad.leader) or rear.forward_supply._other_busy(squad.leader): continue
		var eligible: float = rear.orders._squad_strength(id)
		if eligible <= EPS: continue
		strength += eligible
		squads.append(id)
		leaders.append({"id":leader.id,"squad":id,"members":rear.military._active_roster_members(squad),"position":leader.position,"mass":float(leader.unit_mass_kg)+float(leader.contents_mass_kg)})
	return {"squads":squads,"leaders":leaders,"strength":strength}

func _begin_search(row: Dictionary, army: Dictionary, available: Array, owner: String) -> void:
	var force := _force(army,available,owner)
	if force.squads.is_empty(): row.blocker = "Resource operation needs actual dismounted Rifle capability, leader and cohesion; holding for supply or recovery."; return
	var supply: String = "blue-delivery" if owner == _rear().PLAYER else str(army.stock)
	var fallback: String = "blue-supply-rally" if owner == _rear().PLAYER else "red-dismount-0"
	var supply_place: Dictionary = _rear().ledger.inspect_entity(supply,{},false)
	var fallback_place: Dictionary = _rear().ledger.inspect_entity(fallback,{},false)
	if supply_place.get("kind","") != "PLACE" or fallback_place.get("kind","") != "PLACE": row.blocker = "A real existing supply and fallback corridor is required."; return
	var contacts := _contacts(army.root)
	var threats := _threatened(row,contacts)
	var candidates: Array[Dictionary] = []
	for id in _resources:
		var context := _candidate_context(row,id,owner,contacts,force,threats)
		if not context.ok: continue
		var legs: Array[Dictionary] = []
		for leader in force.leaders: legs.append({"from":leader.position,"to":_resources[id],"mass":leader.mass,"safe":false,"travel":true})
		var mass: float = float(force.leaders[0].mass)
		legs.append({"from":_resources[id],"to":fallback_place.position,"mass":mass,"safe":true,"travel":false})
		legs.append({"from":fallback_place.position,"to":supply_place.position,"mass":mass,"safe":true,"travel":false})
		# Ownership outside delivered friendly capture reports is unknown, so probe
		# that approach instead of silently treating a distant enemy resource empty.
		candidates.append({"objective":id,"action":context.action,"base":context.base,"enemy":context.enemy,"seconds":0.0,"legs":legs,"leg":0,"score":-INF,
			"supply":supply,"fallback":fallback,"served":float(row.served.get(id,-INF))})
	row.search = {"world":_rear().combat.world,"revision":_rear().combat.world.revision,"force":force,"contacts":contacts,
		"army":army.duplicate(true),"available":available.duplicate(),"candidates":candidates,"index":0,"work":null,"ready":[],"notes":[]}
	row.blocker = "Measuring resource approach, supply and fallback; current acknowledged operation continues."
	planning_revision += 1

func _candidate_context(row: Dictionary, id: String, owner: String, contacts: Array[Dictionary], force: Dictionary, threats: Array) -> Dictionary:
	var owned: bool = row.known.get(id,{}).get("owner","") == owner
	if owned and id not in threats: return {"ok":false}
	var enemy := 0.0
	for known in contacts:
		var range_m: float = float(FIRE_RANGE.get(known.get("class",""),160.0))+float(known.uncertainty_m)
		var relevant: bool = _resources[id].distance_to(known.position) <= maxf(300.0,range_m+100.0)
		for leader in force.leaders:
			var delta: Vector2 = _resources[id]-leader.position
			var fraction: float = (known.position-leader.position).dot(delta)/maxf(EPS,delta.length_squared())
			if fraction >= 0 and fraction <= 1 and known.position.distance_to(leader.position+delta*fraction) <= range_m: relevant = true
		if not relevant: continue
		# The infantry slice has no penetrating support plan. A remote vehicle or
		# an unseen empty enemy rack is not an answer to required armour.
		if known.get("class","") in ["T04","T05"]: return {"ok":false}
		enemy += float(known.caution_strength)
	if float(force.strength)+EPS < enemy*1.3: return {"ok":false}
	var neutral: bool = row.known.has(id) and str(row.known[id].owner).is_empty() and _rear().time-float(row.known[id].at) <= 50.0
	return {"ok":true,"enemy":enemy,"action":"Hold Area" if owned else ("Seize Objective" if neutral else "Probe"),"base":85.0 if owned else (80.0 if neutral else 40.0)}

func _finish_leg(row: Dictionary) -> void:
	var search: Dictionary = row.search
	var candidate: Dictionary = search.candidates[search.index]
	var plan: Dictionary = search.work.result
	search.work = null
	if not plan.get("ok",false): _reject(search,candidate,str(plan.get("reason","Unsupported resource route."))); return
	if candidate.legs[candidate.leg].travel: candidate.seconds = maxf(float(candidate.seconds),float(plan.seconds))
	candidate.leg += 1

func _reject(search: Dictionary, candidate: Dictionary, reason: String) -> void:
	search.notes.append(str(candidate.objective)+": "+reason)
	search.index += 1
	search.work = null

func _choose(row: Dictionary, army: Dictionary, available: Array, owner: String) -> void:
	planning_revision += 1
	var search: Dictionary = row.search
	var force := _force(army,available,owner)
	var contacts := _contacts(army.root)
	var threats := _threatened(row,contacts)
	var best := {}
	var fresh_ready: Array[Dictionary] = []
	for candidate in search.ready:
		if force.squads != search.force.squads or float(force.strength) <= EPS: continue
		var context := _candidate_context(row,str(candidate.objective),owner,contacts,force,threats)
		if not context.ok: continue
		# Fresh delivered danger and actual own capability gate the proposal. These
		# route estimates grant no movement: Execution revalidates each actual walk.
		var safe := true
		for leg in candidate.legs:
			if not _hazard(owner,[leg.from,leg.to]).is_empty() or (leg.safe and not _safe_segment(leg.from,leg.to,contacts)): safe = false; break
		if not safe: continue
		candidate.enemy = context.enemy
		candidate.action = context.action
		candidate.base = context.base
		candidate.score = float(candidate.base)-0.1*float(candidate.seconds)-30.0*float(context.enemy)/float(force.strength)
		fresh_ready.append(candidate)
		if best.is_empty() or candidate.score > best.score+EPS or (absf(float(candidate.score)-float(best.score)) <= EPS and (candidate.seconds < best.seconds-EPS or (absf(float(candidate.seconds)-float(best.seconds)) <= EPS and candidate.served < best.served))): best = candidate
	row.search = {}
	row.trigger = false
	if best.is_empty(): row.blocker = "No feasible resource operation with current capability and safe supply/fallback. "+" ".join(search.notes); return
	# A report can refresh an ongoing mission without reversing it for tiny score
	# changes. Completion, lost feasibility or a higher resource priority can switch.
	if not row.completed and not row.operation.is_empty():
		for candidate in fresh_ready:
			if candidate.objective == row.operation.objective and float(best.base) <= float(candidate.base): row.blocker = "Current resource operation remains feasible; retaining its acknowledged mission."; return
	row.generation += 1
	row.operation = {"objective":best.objective,"action":best.action,"phase":"Protect Resource" if best.action == "Hold Area" else ("Seize Resource" if best.action == "Seize Objective" else "Probe Resource"),
		"version":"resource-%d" % row.generation,"reason":"Protect reported ownership" if best.action == "Hold Area" else ("Seize a locally reported neutral resource" if best.action == "Seize Objective" else "Probe an unconfirmed resource approach"),
		"score":best.score,"travel_seconds":best.seconds,"supply":best.supply,"fallback":best.fallback,
		"squads":force.squads.duplicate(),"intent":"","issued_at":INF}
	row.completed = false
	row.blocker = ""

func _safe_segment(from: Vector2, to: Vector2, contacts: Array[Dictionary]) -> bool:
	var delta: Vector2 = to-from
	if delta.length_squared() <= EPS: return true
	for known in contacts:
		var fraction: float = (known.position-from).dot(delta)/delta.length_squared()
		if fraction <= 0: continue # Moving away from existing fire remains possible.
		var closest: Vector2 = from+delta*clampf(fraction,0,1)
		if closest.distance_to(known.position) <= float(FIRE_RANGE.get(known.get("class",""),160.0))+float(known.uncertainty_m): return false
	return true

func _hazard(owner: String, points: Array) -> String:
	return str(_rear().ledger.route_hazard.call(owner,points)) if _rear().ledger.route_hazard.is_valid() else ""

func snapshot(owner: String) -> Dictionary:
	var row: Dictionary = _rows.get(owner,{})
	return {"active":row.get("active",false),"operation":proposal(owner),"planning":not row.get("search",{}).is_empty(),"blocker":row.get("blocker","")}

func _rear() -> RefCounted:
	return _rear_ref.get_ref()
