extends RefCounted
## G17 command links and observations. Actual people, goods and terrain remain with G01/G08/G15/G16.
const EPS := 0.000001
const ACTIONS: Array[String] = ["Defend HQ","Hold Area","Seize Objective","Probe","Support Formation","Prepare Assault","Assault HQ","Move by Transport","Escort Convoy","Deliver Supply","Resupply","Regroup","Evacuate","Build Infrastructure","Secure Crossing","Clear Minefield","Deny Crossing","Recover Vehicle"]
const REPORTS: Array[String] = ["Contact","Progress","Complete","Inability","Casualties","Lost Capability","Low Supply","Blocked Route","Mine Hazard","Threatened Crossing","Opportunity"]
var _rear_ref: WeakRef
var watch_squads: Dictionary = {} # actual active squad ID -> last sampling time
var visible: Dictionary = {} # squad -> target -> current direct sight result
var contacts: Dictionary = {} # echelon -> target -> last observed report, never hidden state
var reports: Array[Dictionary] = []
var pending: Array[Dictionary] = [] # actual link deliveries, including sharing and acknowledgments
var intents: Dictionary = {} # real echelon -> delivered intent
var responsibilities: Dictionary = {} # platoon -> fixing/flanking plan and state
var failed_since: Dictionary = {} # local unsolved reason key -> first detection time
var decisions: Dictionary = {} # platoon -> next two-second local review
var leader_missing_since: Dictionary = {} # ordered squad -> first actual missing-leader sample
var objective_markers: Dictionary = {} # scenario-declared physical places, never contacts by registration alone
var objective_affiliations: Dictionary = {} # HQ ownership makes the marker hostile only to the opposing army.
var preparation_demands: Dictionary = {} # company -> physical requirements for §16.3
var _next_observation := INF
var _sequence := 0
var status := "Awaiting actual formations and observed information."

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func watch(squad_id: String) -> Dictionary:
	var squad: Dictionary = _rear().military.squads.get(squad_id,{})
	if squad.is_empty() or squad.state != "Active": return _block("Only an active real G15 squad can observe through its members.")
	watch_squads[squad_id] = _rear().time
	_sample_squad(squad_id)
	_next_observation = minf(_next_observation,_rear().time+1.0)
	return {"ok":true,"message":"Actual squad members sample G08 visibility each second."}

func unwatch(squad_id: String) -> Dictionary:
	if not watch_squads.has(squad_id): return _block("This squad has no active observation assignment.")
	watch_squads.erase(squad_id)
	visible.erase(squad_id)
	if watch_squads.is_empty(): _next_observation = INF
	return {"ok":true,"message":"Observation assignment ended; old contacts age from their original sighting."}

func register_enemy_hq(place_id: String, owner: String = "army-red") -> Dictionary:
	var place: Dictionary = _rear().ledger.inspect_entity(place_id)
	if place.get("kind","") != "PLACE" or objective_markers.has(place_id) or owner not in ["army-blue","army-red"]: return _block("An actual unique scenario enemy-HQ place and army affiliation are required.")
	objective_markers[place_id] = "Enemy HQ"
	objective_affiliations[place_id] = owner
	return {"ok":true,"message":"Physical enemy HQ marker declared; command has no contact until a real observer sees it."}

func contact(echelon_id: String, target_id: String) -> Dictionary:
	var known: Dictionary = contacts.get(echelon_id,{}).get(target_id,{})
	if known.is_empty(): return {}
	var result: Dictionary = known.duplicate(true)
	result.age = maxf(0.0,_rear().time-float(result.observed_at))
	result.confidence = clampf(1.0-0.02*float(result.age),0.0,1.0)
	result.uncertainty_m = float(result.age)*2.0
	result.caution_strength = float(result.observed_strength)*1.25 if result.age > 10.0 else float(result.observed_strength)
	if result.confidence <= EPS: result.position = Vector2.INF
	# One half-second squad share plus up to three one-second command links.
	# The original observer must still have direct sight at the current sample.
	result.current = result.age <= 4.0+EPS and _source_current(result.source,target_id)
	return result

func current_contact(echelon_id: String, target_id: String) -> bool:
	var row: Dictionary = contact(echelon_id,target_id)
	return not row.is_empty() and row.current

func issue_order(parent_id: String, child_id: String, action: String, outcome: String, purpose: String, constraints: Dictionary, priority: String, fallback: String) -> Dictionary:
	if _parent(child_id) != parent_id or action not in ACTIONS or outcome.is_empty() or purpose.is_empty() or priority not in ["Emergency","High","Normal","Low"] or fallback.is_empty():
		return _block("Intent needs a real parent-child link, supported action, outcome, purpose, constraints, priority and fallback.")
	var hold_seconds := 3.0 if _rear().military.squads.has(child_id) else 10.0
	if intents.has(child_id) and _rear().time < float(intents[child_id].issued_at)+hold_seconds-EPS and priority != "Emergency":
		return _block("Current mission/action persists for its ten/three-second hold unless an Emergency safety change is required.")
	_sequence += 1
	var intent := {"id":"intent-%04d" % _sequence,"parent":parent_id,"child":child_id,"action":action,"outcome":outcome,"purpose":purpose,"constraints":constraints.duplicate(true),"priority":priority,"fallback":fallback,"issued_at":_rear().time,"received_at":-1.0,"acknowledged_at":-1.0,"state":"In transit","blocked_reason":"One real command link to deliver."}
	intents[child_id] = intent
	pending.append({"due":_rear().time+1.0,"kind":"Intent","child":child_id,"id":intent.id})
	return {"ok":true,"id":intent.id,"message":"Intent sent down one real echelon; subordinate receipt and acknowledgement pending."}

func relay_order(parent_id: String, child_id: String) -> Dictionary:
	var intent: Dictionary = intents.get(parent_id,{})
	if intent.is_empty() or intent.state != "Acknowledged" or _parent(child_id) != parent_id:
		return _block("A parent must receive and acknowledge its own intent before relaying it to a real subordinate.")
	var constraints: Dictionary = intent.constraints.duplicate(true)
	constraints["relayed_from"] = intent.id
	return issue_order(parent_id,child_id,intent.action,intent.outcome,intent.purpose,constraints,intent.priority,intent.fallback)

func report(unit_id: String, kind: String, detail: String, urgent: bool = false) -> Dictionary:
	if kind not in REPORTS or detail.is_empty() or _parent(unit_id).is_empty(): return _block("A real subordinate and meaningful report type/detail are required.")
	_sequence += 1
	var row := {"id":"report-%04d" % _sequence,"source":unit_id,"kind":kind,"detail":detail,"observed_at":_rear().time,"reported_at":_rear().time,"urgent":urgent,"current_at":unit_id,"state":"In transit","path":[unit_id]}
	_push_up(row,unit_id)
	return {"ok":true,"id":row.id,"message":"Report travels upward one real command link per second."}

func plan_supported_flank(platoon_id: String, fixing_id: String, flanking_id: String, target_id: String, fallback: String) -> Dictionary:
	var platoon: Dictionary = _rear().military.platoons.get(platoon_id,{})
	if platoon.is_empty() or fixing_id == flanking_id or fixing_id not in platoon.squads or flanking_id not in platoon.squads or fallback.is_empty(): return _block("Two distinct actual squads in the same platoon and a fallback are required.")
	var known: Dictionary = contact(platoon_id,target_id)
	if known.is_empty() or known.confidence <= 0.0 or not known.current: return _block("Platoon needs a current delivered hostile contact, not an unseen exact target.")
	var fixing: Dictionary = _rear().military.capability(fixing_id)
	var flanking: Dictionary = _rear().military.capability(flanking_id)
	if not fixing.ok or not flanking.ok: return _block("Both real dismounted squads need their actual minimum capability.")
	if _rear().military.squads[fixing_id].acting or _rear().military.squads[flanking_id].acting: return _block("An acting conscript squad cannot initiate split-team manoeuvre.")
	if known.get("class","") in ["T04","T05"] and not _has_antiarmour(platoon_id): return _block("Observed armour cannot be assaulted by rifle strength without a real penetrating support capability.")
	var local_strength: float = _squad_strength(fixing_id)+_squad_strength(flanking_id)
	if local_strength < float(known.caution_strength)*1.3: return _block("Actual eligible local strength is below the 1.3 ordinary-attack threshold.")
	var fix_ammo: Dictionary = _fixing_ammunition(fixing_id,target_id)
	if not fix_ammo.ok: return fix_ammo
	var flank_geometry: Dictionary = _flank_geometry(fixing_id,flanking_id,known.position)
	if not flank_geometry.ok: return flank_geometry
	for squad_id in [fixing_id,flanking_id]:
		if intents.has(squad_id) and _rear().time < float(intents[squad_id].issued_at)+3.0-EPS:
			return _block("Existing squad tactical action remains owned for three seconds; wait or issue an Emergency safety change.")
	responsibilities[platoon_id] = {"platoon":platoon_id,"fixing":fixing_id,"flanking":flanking_id,"target":target_id,"contact_observed_at":known.observed_at,"started_at":_rear().time,"state":"Supported","fixing_action":"Hold covered firing line and suppress the observed target","flanking_action":"Move at least 30 degrees around observed target under active fixing fire","fallback":fallback,"blocker":"","angle_degrees":flank_geometry.angle_degrees,"local_ammo":fix_ammo.rounds,"eligible_strength":local_strength,"known_enemy_strength":known.caution_strength}
	decisions[platoon_id] = _rear().time+1.0
	var fix_order: Dictionary = issue_order(platoon_id,fixing_id,"Support Formation","Fix the observed target","Enable the other squad's flank",{"target":target_id},"High",fallback)
	var flank_order: Dictionary = issue_order(platoon_id,flanking_id,"Seize Objective","Reach the observed target flank","Exploit fixing fire",{"target":target_id,"minimum_angle_degrees":30.0},"High",fallback)
	assert(fix_order.ok and flank_order.ok)
	status = "%s assigns %s to fix and %s to flank a delivered contact." % [platoon_id,fixing_id,flanking_id]
	return {"ok":true,"message":status}

func prepare_hq_assault(company_id: String, enemy_hq_id: String, operation_plan: Dictionary = {}) -> Dictionary:
	var company: Dictionary = _rear().military.companies.get(company_id,{})
	if company.is_empty() or objective_markers.get(enemy_hq_id,"") != "Enemy HQ": return _block("A real company and declared physical enemy HQ are required.")
	var ammo_needs: Array[Dictionary] = []
	for platoon_id in company.platoons:
		for squad_id in _rear().military.platoons[platoon_id].squads:
			var squad: Dictionary = _rear().military.squads[squad_id]
			if squad.kind not in ["Rifle","Marksman"]: continue
			for person_id in _rear().military._active_roster_members(squad):
				if _rear().military._held(person_id,"E01") == 0 and _rear().military._held(person_id,"E19") == 0: continue
				var carried: int = _rear().military._rounds(person_id)
				if carried < 90: ammo_needs.append({"person":person_id,"type":"E02","required":90,"present":carried,"missing":90-carried,"position":_rear().ledger.inspect_entity(person_id).position,"consequence":"HQ assault ineligible until 90 actual carried rounds"})
	var pending_requirements: Array[String] = []
	var route: Dictionary = operation_plan.get("route",{})
	if route.get("state","") != "Feasible" or str(route.get("evidence","")).is_empty() or str(route.get("fallback","")).is_empty():
		pending_requirements.append("Route owner must confirm feasible supply and fallback routes with evidence.")
	var transport: Dictionary = operation_plan.get("transport",{})
	var transport_needs: Array[Dictionary] = []
	match transport.get("mode",""):
		"Foot":
			if str(transport.get("evidence","")).is_empty(): pending_requirements.append("Foot approach needs an actual route ETA/evidence, not an assumed absent transport need.")
		"Vehicles":
			var requested: Array = transport.get("hulls",[])
			if requested.is_empty(): pending_requirements.append("Vehicle transport needs named real assigned hulls.")
			for hull_id in requested:
				var id := str(hull_id)
				var assigned: bool = _company_hulls(company_id).has(id)
				var capable: bool = assigned and bool(_rear().military.vehicle_capability(id,"Transport").ok)
				if not capable: transport_needs.append({"hull":id,"required":"assigned, crewed and physically boarded transport","missing":true,"consequence":"Assault staging waits for actual usable transport or a revised foot plan."})
		_:
			pending_requirements.append("Transport mode is unknown; choose evidenced foot or named actual vehicles.")
	var fuel_needs: Array[Dictionary] = []
	var fuel_plan: Dictionary = operation_plan.get("fuel_required",{})
	var fuel_sources: Dictionary = operation_plan.get("fuel_source",{})
	var operating_hulls: Array = operation_plan.get("operating_hulls",[])
	for hull_id in operating_hulls:
		var id := str(hull_id)
		if not _company_hulls(company_id).has(id):
			fuel_needs.append({"hull":id,"required":"assigned military vehicle","missing":true,"consequence":"Unassigned hull cannot support the assault."})
			continue
		if not fuel_plan.has(id) or not is_finite(float(fuel_plan[id])) or float(fuel_plan[id]) <= 0.0:
			pending_requirements.append("Route owner must provide positive route-and-fallback fuel for %s." % id)
			continue
		var hull: Dictionary = _rear().ledger.inspect_entity(id)
		var base_route: float = float(fuel_plan[id])
		var required: float = base_route*1.25
		var present: float = float(hull.fuel)
		if present+EPS < required:
			var source_id := str(fuel_sources.get(id,""))
			var source: Dictionary = _rear().ledger.inspect_entity(source_id) if not source_id.is_empty() else {}
			fuel_needs.append({"hull":id,"type":"M08","base_route_and_fallback":base_route,"reserve_fraction":0.25,"required":required,"present":present,"missing":required-present,"source":source_id if source.get("design_type","") == "M08" else "Unassigned","source_available":int(source.get("available",0)) if source.get("design_type","") == "M08" else 0,"source_reserved":int(source.get("reserved",0)) if source.get("design_type","") == "M08" else 0,"consequence":"This actual hull lacks route-and-fallback fuel plus 25% reserve."})
	for hull_id in transport.get("hulls",[]):
		if _company_hulls(company_id).has(str(hull_id)) and not operating_hulls.has(hull_id): pending_requirements.append("Transport hull %s needs an operating-hull fuel plan." % str(hull_id))
	var engineering: Dictionary = operation_plan.get("engineering",{})
	var engineering_needs: Array[Dictionary] = []
	match engineering.get("state",""):
		"Clear":
			if str(engineering.get("evidence","")).is_empty(): pending_requirements.append("Engineering clearance needs actual route survey evidence.")
		"Needed":
			for requirement in engineering.get("requirements",[]):
				engineering_needs.append({"project":requirement.duplicate(true),"missing":true,"consequence":"Required engineer work must be completed by G21 before assault."})
			if engineering_needs.is_empty(): pending_requirements.append("Needed engineer work requires a named project and quantities from G21.")
		_:
			pending_requirements.append("Engineering state unknown; G21 or route survey must clear or name the work.")
	preparation_demands[company_id] = {"enemy_hq":enemy_hq_id,"ammo":ammo_needs,"fuel":fuel_needs,"transport":transport_needs,"engineering":engineering_needs,"pending":pending_requirements,"route":route.duplicate(true),"plan":operation_plan.duplicate(true),"support":"Actual armoured or indirect support required","created_at":_rear().time}
	return {"ok":true,"message":"Physical assault demands recorded before eligibility; no stock or personnel moved.","demands":preparation_demands[company_id].duplicate(true)}

func _company_hulls(company_id: String) -> Array[String]:
	var result: Array[String] = []
	var company: Dictionary = _rear().military.companies.get(company_id,{})
	if company.is_empty(): return result
	for id in company.service_vehicles: result.append(id)
	for platoon_id in company.platoons:
		for id in _rear().military.platoons[platoon_id].vehicles: result.append(id)
	return result

func assess_hq_assault(company_id: String, enemy_hq_id: String, route_ok: bool) -> Dictionary:
	var company: Dictionary = _rear().military.companies.get(company_id,{})
	if company.is_empty() or objective_markers.get(enemy_hq_id,"") != "Enemy HQ": return _block("A real company and declared enemy HQ are required.")
	var prepared: Dictionary = preparation_demands.get(company_id,{})
	if prepared.is_empty() or prepared.enemy_hq != enemy_hq_id: return _block("Prepare Assault must record actual ammunition, fuel, transport, engineering and route demands before final eligibility.")
	prepare_hq_assault(company_id,enemy_hq_id,prepared.plan)
	prepared = preparation_demands[company_id]
	var hq: Dictionary = contact(company_id,enemy_hq_id)
	if hq.is_empty() or hq.confidence <= 0.0: return _block("Enemy HQ is not located by a surviving delivered observation.")
	if not route_ok: return _block("No feasible actual supply and fallback route has been confirmed.")
	if not prepared.pending.is_empty(): return _block("Assault preparation remains unconfirmed: "+str(prepared.pending[0]))
	for category in ["fuel","transport","engineering"]:
		if not prepared[category].is_empty(): return _block("Assault preparation has unmet %s requirements: %s" % [category,str(prepared[category][0].consequence)])
	var squads: Array[String] = []
	for platoon_id in company.platoons:
		for squad_id in _rear().military.platoons[platoon_id].squads:
			if _rear().military.squads[squad_id].state == "Active": squads.append(squad_id)
	if squads.is_empty(): return _block("Company lacks actual active combat squads.")
	var readiness := 1.0
	var attackers := 0.0
	for squad_id in squads:
		readiness = minf(readiness,_rear().military.readiness(squad_id))
		attackers += _squad_strength(squad_id,Vector2.INF,INF,"Deployment")
		var squad: Dictionary = _rear().military.squads[squad_id]
		if squad.kind not in ["Rifle","Marksman"]: continue
		for person_id in _rear().military._active_roster_members(squad):
			if _rear().military._held(person_id,"E01")+_rear().military._held(person_id,"E19") > 0 and _rear().military._rounds(person_id) < 90:
				return _block("Dismounted rifle and marksman carriers each require 90 physically carried E02 before HQ assault.")
	if readiness < 0.75: return _block("Actual company readiness is below the 0.75 HQ assault threshold.")
	var support := _company_support(company_id,prepared.plan.get("operating_hulls",[]))
	if not support.ok: return support
	var defenders := 0.0
	for target_id in contacts.get(company_id,{}):
		if target_id == enemy_hq_id: continue
		var known: Dictionary = contact(company_id,target_id)
		if known.confidence <= 0.0 or known.position.distance_to(hq.position) > 150.0: continue
		defenders += float(known.caution_strength)
	if defenders == 0.0 and not _current_recon_of_hq(company_id,enemy_hq_id): return _block("No observed HQ defenders; a current reconnaissance/probe must confirm the approach before treating it as empty.")
	if defenders > 0.0 and attackers < defenders*1.5: return _block("Actual attacking eligible strength is below 1.5 times known local defenders.")
	return {"ok":true,"message":"§16.3 HQ assault gates satisfied using delivered observations and actual company people, ammunition and support.","readiness":readiness,"attackers":attackers,"known_defenders":defenders,"support":support.id}

func _company_support(company_id: String, operating_hulls: Array) -> Dictionary:
	var company: Dictionary = _rear().military.companies[company_id]
	var hulls: Array[String] = []
	for hull_id in company.service_vehicles: hulls.append(hull_id)
	for platoon_id in company.platoons:
		for hull_id in _rear().military.platoons[platoon_id].vehicles: hulls.append(hull_id)
		for squad_id in _rear().military.platoons[platoon_id].squads:
			var squad: Dictionary = _rear().military.squads[squad_id]
			if squad.kind == "Artillery" and _rear().combat.gun_setups.get(squad.gun_id,{}).get("complete",false) and _rear().military.capability(squad_id).ok:
				return {"ok":true,"id":squad.gun_id}
	for hull_id in hulls:
		if hull_id not in operating_hulls: continue
		var hull: Dictionary = _rear().ledger.inspect_entity(hull_id)
		if hull.design_type in ["T04","T05"] and _rear().military.vehicle_capability(hull_id,"Fire").ok and _rear().military.vehicle_capability(hull_id,"Movement").ok: return {"ok":true,"id":hull_id}
	return _block("HQ assault needs an actual operating armoured or indirect support element; engineer demolition integration remains with G21.")

func _current_recon_of_hq(company_id: String, enemy_hq_id: String) -> bool:
	var company: Dictionary = _rear().military.companies[company_id]
	for platoon_id in company.platoons:
		for squad_id in _rear().military.platoons[platoon_id].squads:
			if _rear().military.squads[squad_id].kind == "Reconnaissance" and visible.get(squad_id,{}).has(enemy_hq_id): return true
	return false

func next_boundary() -> float:
	var next: float = _next_observation
	for row in pending: next = minf(next,float(row.due))
	for id in decisions: next = minf(next,float(decisions[id]))
	if not intents.is_empty(): next = minf(next,_rear().time+1.0)
	for key in failed_since:
		var due: float = float(failed_since[key])+10.0
		if due > _rear().time+EPS: next = minf(next,due)
	return next

func advance_to(_at: float) -> void:
	pass

func settle() -> bool:
	var changed := false
	var now: float = _rear().time
	if _next_observation <= now+EPS:
		var entities: Array = _rear().ledger.snapshot(false).entities if not watch_squads.is_empty() else []
		for id in watch_squads.keys(): _sample_squad(id,entities)
		_next_observation = now+1.0 if not watch_squads.is_empty() else INF
		changed = true
	for entry in pending.duplicate():
		if float(entry.due) > now+EPS: continue
		pending.erase(entry)
		_deliver(entry)
		changed = true
	for id in decisions.keys():
		if float(decisions[id]) > now+EPS: continue
		_review_flank(id)
		decisions[id] = now+1.0 if responsibilities.has(id) and responsibilities[id].state == "Supported" else INF
		changed = true
	for key in failed_since.keys():
		if float(failed_since[key])+10.0 > now+EPS: continue
		var parts: PackedStringArray = key.split(":",false,1)
		if parts.size() == 2: report(parts[0],"Inability",parts[1])
		failed_since.erase(key)
		changed = true
	for id in intents:
		if not _rear().military.squads.has(id): continue
		var squad: Dictionary = _rear().military.squads[id]
		var leader: Dictionary = _rear().ledger.inspect_entity(str(squad.leader))
		var missing: bool = leader.is_empty() or leader.get("assignment","") in ["Wounded","Dead"] or not leader.get("active",true)
		if not missing:
			leader_missing_since.erase(id)
			continue
		if not leader_missing_since.has(id): leader_missing_since[id] = now
		if now-float(leader_missing_since[id]) >= 20.0 and not str(intents[id].state).begins_with("Paused"):
			intents[id].state = "Paused: leader absent beyond fallback window"
			report(id,"Inability","Leader absent for twenty seconds; holding under fallback and requesting command replacement.",true)
			changed = true
	return changed

func snapshot() -> Dictionary:
	var inspected: Dictionary = {}
	for echelon in contacts:
		inspected[echelon] = {}
		for target in contacts[echelon]: inspected[echelon][target] = contact(echelon,target)
	return {"contacts":inspected,"visible":visible.duplicate(true),"intents":intents.duplicate(true),"responsibilities":responsibilities.duplicate(true),"preparation_demands":preparation_demands.duplicate(true),"pending":pending.duplicate(true),"reports":reports.duplicate(true),"status":status}

func audit() -> Array[String]:
	var failures: Array[String] = []
	for echelon in contacts:
		for target in contacts[echelon]:
			var row: Dictionary = contacts[echelon][target]
			if row.observed_at > _rear().time+EPS or not row.has("source") or row.has("health") or row.has("fuel") or row.has("ammunition"): failures.append("G17 contact leaks hidden state or future time: "+target)
	for id in responsibilities:
		var row: Dictionary = responsibilities[id]
		if row.fixing == row.flanking or _parent(row.fixing) != id or _parent(row.flanking) != id: failures.append("G17 flank lacks distinct actual platoon squads: "+id)
	return failures

func _sample_squad(squad_id: String, sampled_entities: Array = []) -> void:
	var squad: Dictionary = _rear().military.squads.get(squad_id,{})
	if squad.is_empty() or squad.state != "Active":
		unwatch(squad_id)
		return
	var seen := {}
	var ledger: RefCounted = _rear().ledger
	var entities: Array = ledger.snapshot(false).entities if sampled_entities.is_empty() else sampled_entities
	var world: RefCounted = _rear().combat.world
	var maximum: float = float(world.Catalog.ROLES.ordinary.range)+float(world.EPS)
	for person_id in _rear().military._active_roster_members(squad):
		var observer: Dictionary = ledger.inspect_person_status(person_id)
		for target in entities:
			var affiliation: String = str(target.controller).trim_suffix("-hq") if target.kind == "CARRIER" else str(target.owner)
			if target.kind not in ["PERSON","CARRIER"] or affiliation not in ["army-blue","army-red"] or affiliation == observer.owner or target.get("assignment","") in ["Wounded","Dead"]: continue
			# The exact ordinary sight-range bound cannot produce a contact.
			# Reject it before terrain heights/rays or protected-hull inspection.
			if observer.position.distance_to(target.position) > maximum: continue
			# Protected occupants are observed through their hull, not as exposed people.
			if target.kind == "PERSON" and ledger.entity_kind(target.holder_id) == "CARRIER" and not _rear().vehicle_combat._exposed_gunner(target): continue
			if _rear().combat.world.observe(observer.position,target.position).visible:
				var estimated_strength := 10.0 if target.design_type == "T05" else (6.0 if target.design_type == "T04" else (3.0 if target.design_type == "T03" else 1.0))
				seen[target.id] = {"target":target.id,"class":target.design_type,"position":target.position,"observed_count":1,"observed_strength":estimated_strength,"source":person_id,"observed_at":_rear().time,"visible_facing":target.get("facing","Unknown")}
		for objective_id in objective_markers:
			if objective_affiliations.get(objective_id,"") == observer.owner: continue
			var place: Dictionary = ledger.inspect_entity(objective_id,{},false)
			if observer.position.distance_to(place.position) > maximum: continue
			if _rear().combat.world.observe(observer.position,place.position).visible:
				seen[objective_id] = {"target":objective_id,"class":objective_markers[objective_id],"position":place.position,"observed_count":1,"observed_strength":0.0,"source":person_id,"observed_at":_rear().time,"visible_facing":"Unknown"}
	visible[squad_id] = seen
	for target_id in seen:
		var row: Dictionary = seen[target_id]
		pending.append({"due":_rear().time+0.5,"kind":"Contact","destination":squad_id,"report":row})
	watch_squads[squad_id] = _rear().time

func _deliver(entry: Dictionary) -> void:
	match entry.kind:
		"Contact":
			var destination: String = entry.destination
			var report: Dictionary = entry.report
			var prior: Dictionary = contacts.get(destination,{}).get(report.target,{})
			if prior.is_empty() or float(report.observed_at) >= float(prior.observed_at):
				if not contacts.has(destination): contacts[destination] = {}
				contacts[destination][report.target] = report.duplicate(true)
			if not _parent(destination).is_empty(): pending.append({"due":_rear().time+1.0,"kind":"Contact","destination":_parent(destination),"report":report})
		"Intent":
			if intents.has(entry.child) and intents[entry.child].id == entry.id:
				intents[entry.child].received_at = _rear().time
				intents[entry.child].state = "Acknowledgement pending"
				intents[entry.child].blocked_reason = ""
				pending.append({"due":_rear().time+1.0,"kind":"Acknowledge","child":entry.child,"id":entry.id})
		"Acknowledge":
			if intents.has(entry.child) and intents[entry.child].id == entry.id:
				intents[entry.child].acknowledged_at = _rear().time
				intents[entry.child].state = "Acknowledged"
		"Report":
			var row: Dictionary = entry.report
			row.current_at = entry.destination
			row.path.append(entry.destination)
			if entry.destination in ["army","army-red"]:
				row.state = "Delivered to Commander"
				reports.append(row)
			else: _push_up(row,entry.destination)

func _push_up(row: Dictionary, from: String) -> void:
	var parent: String = _parent(from)
	if parent.is_empty(): return
	pending.append({"due":_rear().time+1.0,"kind":"Report","destination":parent,"report":row})

func _review_flank(platoon_id: String) -> void:
	if not responsibilities.has(platoon_id): return
	var plan: Dictionary = responsibilities[platoon_id]
	var ammo: Dictionary = _fixing_ammunition(plan.fixing,plan.target)
	var contact_now: Dictionary = contact(platoon_id,plan.target)
	var fixing: Dictionary = _rear().military.capability(plan.fixing,"Sustained Execution")
	var flanking: Dictionary = _rear().military.capability(plan.flanking,"Sustained Execution")
	var cohesion: Dictionary = _rear().combat.squad_cohesion(plan.flanking)
	if ammo.ok and fixing.ok and flanking.ok and contact_now.current and cohesion.state == "Coherent": return
	plan.state = "Paused"
	plan.blocker = "Fixing ammunition/capability, current contact or flanking cohesion lost; manoeuvre paused for cover and reassessment."
	if not ammo.ok: plan.blocker = ammo.message
	if not contact_now.current: plan.blocker = "Observed target is no longer current; pause flank and probe before advancing."
	if cohesion.state != "Coherent": plan.blocker = "Flanking squad must regroup around its real leader."
	if intents.has(plan.flanking): intents[plan.flanking].state = "Paused: " + plan.blocker
	if intents.has(plan.fixing): intents[plan.fixing].state = "Unable to fix: " + plan.blocker
	status = "%s cannot continue supported flank: %s" % [platoon_id,plan.blocker]
	var key := "%s:%s" % [platoon_id,plan.blocker]
	if not failed_since.has(key): failed_since[key] = _rear().time
	report(plan.fixing,"Low Supply",plan.blocker)

func _fixing_ammunition(squad_id: String, target_id: String) -> Dictionary:
	var squad: Dictionary = _rear().military.squads.get(squad_id,{})
	if squad.is_empty(): return _block("Actual fixing squad absent.")
	var target: Dictionary = _rear().ledger.inspect_entity(target_id)
	for id in _rear().military._active_roster_members(squad):
		for item in _rear().ledger.snapshot().entities:
			if item.kind != "WEAPON" or item.holder_id != id or item.design_type not in ["E01","E05","E19"] or item.loaded_rounds <= 0: continue
			if _rear().combat.inspect_fire(id,target_id,item.id).ok: return {"ok":true,"rounds":item.loaded_rounds,"shooter":id,"weapon":item.id}
	if target.is_empty(): return _block("Observed target identity no longer exists.")
	return _block("Fixing squad has no eligible loaded matching weapon with a current legal firing line; flank must pause and request local E02.")

func _squad_strength(squad_id: String, centre: Vector2 = Vector2.INF, radius: float = INF, purpose: String = "Sustained Execution") -> float:
	var squad: Dictionary = _rear().military.squads.get(squad_id,{})
	if squad.is_empty() or not _rear().military.capability(squad_id,purpose).ok: return 0.0
	var total := 0.0
	for id in _rear().military._active_roster_members(squad):
		if squad.kind == "Rifle" and (not _rear().military.rifle_can_fight(id) or _rear().combat.broken.has(id)): continue
		var person: Dictionary = _rear().ledger.inspect_entity(id)
		if centre.is_finite() and person.position.distance_to(centre) > radius: continue
		var base := 1.5 if squad.kind == "Marksman" and _rear().military._held(id,"E19") > 0 else 1.0
		var factor := float(person.health)/100.0 * (1.0-float(person.suppression)/200.0)
		var cover: Dictionary = _rear().combat.world.cover(person.position,Vector2.INF)
		if cover.hit <= 0.5: factor *= 1.3
		elif cover.hit < 1.0: factor *= 1.15
		total += base*factor
	return total

func _has_antiarmour(platoon_id: String) -> bool:
	var platoon: Dictionary = _rear().military.platoons.get(platoon_id,{})
	if platoon.is_empty(): return false
	for squad_id in platoon.squads:
		var squad: Dictionary = _rear().military.squads[squad_id]
		if squad.kind == "Artillery" and _rear().combat.gun_setups.get(squad.gun_id,{}).get("complete",false) and _rear().military.capability(squad_id).ok: return true
	for hull_id in platoon.vehicles:
		var hull: Dictionary = _rear().ledger.inspect_entity(hull_id)
		if hull.design_type == "T05" and _rear().military.vehicle_capability(hull_id,"Fire").ok: return true
	return false

func _flank_geometry(fixing_id: String, flanking_id: String, target: Vector2) -> Dictionary:
	var fixed: Dictionary = _rear().military.squads[fixing_id]
	var flank: Dictionary = _rear().military.squads[flanking_id]
	var fixing: Dictionary = _rear().ledger.inspect_entity(fixed.leader)
	var flanker: Dictionary = _rear().ledger.inspect_entity(flank.leader)
	if fixing.is_empty() or flanker.is_empty(): return _block("Both real squad leaders need positions for a supported flank.")
	var angle: float = absf(rad_to_deg((fixing.position-target).angle_to(flanker.position-target)))
	if angle < 30.0-EPS: return _block("Actual fixing and flanking positions need at least 30 degrees of separation around target.")
	return {"ok":true,"angle_degrees":angle}

func _parent(id: String) -> String:
	if id == "army": return ""
	if _rear().military.squads.has(id): return str(_rear().military.squads[id].platoon)
	if _rear().military.platoons.has(id): return str(_rear().military.platoons[id].company)
	if _rear().military.companies.has(id): return str(_rear().military.companies[id].get("army_id","army"))
	return ""

func _source_current(source_id: String, target_id: String) -> bool:
	for id in visible:
		if visible[id].has(target_id) and visible[id][target_id].source == source_id: return true
	return false

func _block(message: String) -> Dictionary:
	return {"ok":false,"message":message,"blocked_reason":message}
