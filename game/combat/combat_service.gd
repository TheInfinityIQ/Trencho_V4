extends RefCounted
## G16 battle boundary; the shared ledger remains authoritative for people and goods.
const World = preload("res://game/terrain/terrain_world.gd")
const Records = preload("res://game/identity/identity_records.gd")
const WEAPONS := {
	"E01":{"ammo":"E02","range":160.0,"hit":0.55,"damage":34,"cadence":2.0,"reload":3.0,"suppression":4},
	"E05":{"ammo":"E02","range":250.0,"hit":0.45,"damage":24,"cadence":0.25,"reload":6.0,"suppression":8},
	"E19":{"ammo":"E02","range":300.0,"hit":0.70,"damage":55,"cadence":4.0,"reload":4.0,"suppression":4},
}
const EPS := 0.000001
var _rear_ref: WeakRef
var world: RefCounted
var rng := RandomNumberGenerator.new()
var cooldowns: Dictionary = {}
var gun_setups: Dictionary = {} # allocated E13 -> complete, due and squad
var reloads: Dictionary = {}
var _reload_sequence := 0
var care: Dictionary = {}
var demands: Dictionary = {}
var last_incoming: Dictionary = {}
var last_casualty: Dictionary = {}
var pinned: Dictionary = {}
var broken: Dictionary = {}
var dispersed_since: Dictionary = {}
var deaths: Dictionary = {}
var bleeding: Dictionary = {} # Actual incapacitated IDs with active deadlines.
var events: Array[Dictionary] = []
var _next_stress_tick := 1.0

func _init(rear: RefCounted, terrain: RefCounted = null) -> void:
	_rear_ref = weakref(rear)
	world = terrain if terrain != null else World.new()
	if terrain == null: world.bounds = Rect2i(0,0,4096,2048)
	rear.ledger.person_position_changed.connect(_on_person_position_changed)
	rng.seed = 16027
	_next_stress_tick = rear.time + 1.0

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func inspect_fire(shooter_id: String, target_id: String, weapon_id: String, moving_shooter: bool = false, moving_target: bool = false) -> Dictionary:
	var ledger: RefCounted = _rear().ledger
	var shooter: Dictionary = ledger.inspect_entity(shooter_id,{},false)
	var target: Dictionary = ledger.inspect_entity(target_id,{},false)
	var weapon: Dictionary = ledger.inspect_entity(weapon_id,{},false)
	if shooter.is_empty() or target.is_empty() or weapon.is_empty() or shooter.get("kind","") != "PERSON" or target.get("kind","") != "PERSON" or weapon.get("kind","") != "WEAPON": return _block("Actual shooter, person target and functional weapon are required.")
	if shooter.owner == target.owner: return _block("Direct fire on a friendly person is withheld.")
	if shooter.assignment in ["Wounded","Recovery","Dead"] or shooter.health <= 0 or not shooter.crew_station.is_empty() or _seated(shooter): return _block("Shooter must be active and dismounted.")
	if broken.has(shooter_id): return _block("Broken morale requires fallback before offensive fire.")
	if target.assignment in ["Wounded","Recovery","Dead"] or target.health <= 0 or _seated(target): return _block("No deliberate fire at incapacitated, recovering or seated people.")
	if _medic_busy(shooter_id): return _block("Active care must be interrupted before firing.")
	if _rear().forward_supply != null and _rear().forward_supply.person_committed(shooter_id): return _block("Local supply handling must finish or stop before firing.")
	if _rear().military != null and _rear().military.person_committed(shooter_id): return _block("Troop transport handling must finish before this action.")
	if _rear().field_structures != null and _rear().field_structures.working(shooter_id): return _block("Active field construction must be interrupted before firing.")
	if weapon.holder_id != shooter_id or not weapon.functional or not WEAPONS.has(weapon.design_type): return _block("Only the holder of an intact personal direct-fire weapon can fire it.")
	var spec: Dictionary = WEAPONS[weapon.design_type]
	if weapon.design_type == "E19" and shooter.qualification != "P07": return _block("A marksman rifle needs its actual P07 holder.")
	if weapon.design_type == "E05" and shooter.qualification != "P04": return _block("A portable machine gun needs its actual P04 operator.")
	if _rear().time + EPS < float(cooldowns.get(weapon_id,0.0)): return _block("Weapon cadence still in progress.")
	if reloads.has(weapon_id): return _block("Reload work is in progress.")
	var origin: Vector2 = shooter.position
	var destination: Vector2 = target.position
	if _rear().field_structures != null and not _rear().field_structures.occupant_fire_allowed(shooter_id,destination): return _block("Target is outside the bunker firing ports.")
	var distance := origin.distance_to(destination)
	if distance <= EPS or distance > float(spec.range)+EPS: return _block("Target is outside this weapon's legal direct-fire range.")
	var sight: Dictionary = world.observe(origin,destination,"ordinary",1.5,float(spec.range))
	if not sight.visible: return _block("Target is not currently visible: " + str(sight.eye.reason))
	if not sight.firing_line_clear: return _block("Firing line is obstructed: " + str(sight.muzzle.reason))
	for item in ledger.snapshot(false).entities:
		if item.id in [shooter_id,target_id] or item.owner != shooter.owner or item.kind not in ["PERSON","CARRIER"]: continue
		if item.kind == "PERSON" and item.assignment in ["Wounded","Dead"]: continue
		var along := _segment_fraction(item.position,origin,destination)
		if along <= EPS or along >= 1.0-EPS: continue
		var clearance := 0.5
		if item.kind == "CARRIER" and item.has("vehicle_spec"):
			clearance = Vector2(item.vehicle_spec.get("size",Vector2(2,2))).length()*0.5
		if item.position.distance_to(origin.lerp(destination,along)) <= clearance: return _block("Friendly person or vehicle intersects the direct firing line.")
	var protection: Dictionary = world.cover(destination,origin)
	var chance: float = float(spec.hit) * (1.0 if shooter.basic_training else 0.75) * (1.0-0.5*distance/float(spec.range))
	chance *= (0.6 if moving_shooter else 1.0) * (0.8 if moving_target else 1.0) * float(protection.hit)
	chance *= maxf(0.2,1.0-float(shooter.suppression)/125.0)
	return {"ok":true,"chance":clampf(chance,0.05,0.95),"distance":distance,"cover":protection,"loaded":weapon.loaded_rounds,"ammo_type":spec.ammo,"blocked_reason":""}

func fire(shooter_id: String, target_id: String, weapon_id: String, moving_shooter: bool = false, moving_target: bool = false) -> Dictionary:
	var assessment := inspect_fire(shooter_id,target_id,weapon_id,moving_shooter,moving_target)
	if not assessment.ok: return assessment
	var ledger: RefCounted = _rear().ledger
	var weapon: Dictionary = ledger.inspect_entity(weapon_id,{},false)
	if weapon.loaded_rounds <= 0:
		_record_demand(shooter_id,str(WEAPONS[weapon.design_type].ammo))
		return _block("Empty local weapon; matching stock elsewhere cannot fire it. " + demands[shooter_id].blocked_reason)
	var spent: Dictionary = ledger.fire_loaded_round(weapon_id)
	if not spent.ok: return _block(spent.message)
	var spec: Dictionary = WEAPONS[weapon.design_type]
	var cadence: float = float(spec.cadence)
	if weapon.design_type == "E05" and not _assistant_near(shooter_id): cadence = 0.5
	cooldowns[weapon_id] = _rear().time + cadence
	var hit := rng.randf() < float(assessment.chance)
	var target: Dictionary = ledger.inspect_entity(target_id,{},false)
	var suppression := int(spec.suppression)
	if not target.basic_training: suppression = int(ceil(float(suppression)*1.25))
	_apply_stress(target_id,0,suppression,true)
	var injury := 0
	if hit:
		injury = int(ceil(float(spec.damage)*_armour_factor(target_id)))
		injure(target_id,injury)
	if ledger.loaded_rounds(weapon_id) == 0: _record_demand(shooter_id,str(spec.ammo))
	_log("%s fired %s at %s: %s; one loaded round consumed" % [shooter_id,weapon_id,target_id,"hit" if hit else "miss"])
	return {"ok":true,"hit":hit,"injury":injury,"chance":assessment.chance,"remaining":ledger.loaded_rounds(weapon_id),"demand":demands.get(shooter_id,{})}

func request_reload(shooter_id: String, weapon_id: String, source_id: String, quantity: int) -> Dictionary:
	var ledger: RefCounted = _rear().ledger
	var shooter: Dictionary = ledger.inspect_entity(shooter_id)
	var weapon: Dictionary = ledger.inspect_entity(weapon_id)
	var stock: Dictionary = ledger.inspect_entity(source_id)
	if shooter.is_empty() or weapon.is_empty() or stock.is_empty() or not WEAPONS.has(weapon.design_type): return _block("Actual personal weapon and local matching stock are required.")
	if shooter.assignment in ["Wounded","Recovery","Dead"] or weapon.holder_id != shooter_id or stock.holder_id != shooter_id or stock.design_type != WEAPONS[weapon.design_type].ammo: return _block("Reload uses only matching loose rounds on the active holder.")
	if _rear().forward_supply != null and _rear().forward_supply.person_committed(shooter_id): return _block("Local supply handling must finish before reloading.")
	if _rear().military != null and _rear().military.person_committed(shooter_id): return _block("Troop transport handling must finish before this action.")
	if quantity <= 0 or quantity > stock.available or quantity > weapon.loaded_capacity-weapon.loaded_rounds: return _block("Reload quantity exceeds local unreserved stock or weapon capacity.")
	if reloads.has(weapon_id) or _rear().time+EPS < float(cooldowns.get(weapon_id,0.0)): return _block("Weapon is busy with fire cadence or reload.")
	var seconds: float = float(WEAPONS[weapon.design_type].reload)
	if weapon.design_type == "E05" and not _assistant_near(shooter_id): seconds = 12.0
	_reload_sequence += 1
	var claim_id := "combat-reload:%d" % _reload_sequence
	var claim: Dictionary = ledger.request_stock(claim_id,source_id,quantity,shooter_id,"Matching local weapon reload",shooter.owner)
	if not claim.ok or ledger.inspect_claim(claim_id).reserved != quantity:
		if claim.ok: ledger.release_claim(claim_id)
		return _block("Matching local rounds could not be fully reserved for reload.")
	reloads[weapon_id] = {"operator":shooter_id,"source":source_id,"quantity":quantity,"due":_rear().time+seconds,"claim":claim_id}
	return {"ok":true,"message":"Local reload committed for %.1f seconds." % seconds}

func interrupt_reload(weapon_id: String) -> Dictionary:
	if not reloads.has(weapon_id): return _block("No committed reload exists.")
	_rear().ledger.release_claim(reloads[weapon_id].claim)
	reloads.erase(weapon_id)
	return {"ok":true,"message":"Reload interrupted; unspent local rounds released."}

func deploy_field_gun(squad_id: String) -> Dictionary:
	var row: Dictionary = _rear().military.squads.get(squad_id,{})
	if row.is_empty() or row.kind != "Artillery" or row.state != "Active" or row.gun_id.is_empty(): return _block("An active allocated Artillery squad and its actual E13 are required.")
	if not _field_crew_ready(row): return _block("Four living P05 at the actual field gun are required for setup.")
	if gun_setups.has(row.gun_id):
		if gun_setups[row.gun_id].complete or gun_setups[row.gun_id].due < INF: return _block("Field gun setup is already committed or complete.")
	gun_setups[row.gun_id] = {"squad":squad_id,"due":_rear().time+20.0,"complete":false}
	return {"ok":true,"message":"Four-person field-gun setup committed for 20 seconds."}

func inspect_field_gun_fire(squad_id: String, target_id: String) -> Dictionary:
	var row: Dictionary = _rear().military.squads.get(squad_id,{})
	if row.is_empty() or row.kind != "Artillery" or not gun_setups.has(row.gun_id) or not gun_setups[row.gun_id].complete: return _block("Allocated field gun is not deployed.")
	if not _field_crew_ready(row): return _block("Four living P05 must operate the actual gun.")
	var ledger: RefCounted = _rear().ledger
	var gun: Dictionary = ledger.inspect_entity(row.gun_id)
	var target: Dictionary = ledger.inspect_entity(target_id)
	if gun.is_empty() or target.is_empty() or gun.get("health",0) <= 0 or target.get("kind","") != "PERSON" or target.assignment in ["Wounded","Recovery","Dead"] or target.owner == gun.owner: return _block("A functional gun and active hostile person are required.")
	if _rear().time+EPS < float(cooldowns.get(row.gun_id,0.0)): return _block("Field-gun cadence is in progress.")
	var distance: float = gun.position.distance_to(target.position)
	if distance < 60.0-EPS or distance > 650.0+EPS: return _block("Field-gun direct target must be 60 to 650 metres away.")
	var sight: Dictionary = world.observe(gun.position,target.position,"field_gun_deployed",1.5,650.0)
	if not sight.visible or not sight.firing_line_clear: return _block("Field-gun direct observation or firing line is blocked.")
	for item in ledger.snapshot().entities:
		if item.kind != "PERSON" or item.owner != gun.owner or item.assignment == "Dead": continue
		var along := _segment_fraction(item.position,gun.position,target.position)
		if along > EPS and along < 1.0-EPS and item.position.distance_to(gun.position.lerp(target.position,along)) <= 0.5: return _block("Friendly person blocks the direct firing line.")
	var shell := ""
	for id in row.shell_ids:
		var item: Dictionary = ledger.inspect_entity(id)
		if not item.is_empty() and item.design_type == "E14" and item.holder_id == gun.holder_id and item.available > 0:
			shell = id
			break
	if shell.is_empty(): return _block("No allocated unreserved E14 is physically at this gun; request local shells.")
	var protection: Dictionary = world.cover(target.position,gun.position)
	var chance := clampf(0.60*(1.0-0.5*distance/650.0)*float(protection.hit),0.05,0.95)
	return {"ok":true,"chance":chance,"shell":shell,"distance":distance,"cover":protection,"blocked_reason":""}

func fire_field_gun(squad_id: String, target_id: String) -> Dictionary:
	var assessment := inspect_field_gun_fire(squad_id,target_id)
	if not assessment.ok: return assessment
	var ledger: RefCounted = _rear().ledger
	var row: Dictionary = _rear().military.squads[squad_id]
	var spent: Dictionary = ledger.record_consumption(assessment.shell,1,"W04 direct field-gun shot")
	if not spent.ok: return _block(spent.message)
	cooldowns[row.gun_id] = _rear().time+10.0
	var hit := rng.randf() < float(assessment.chance)
	if hit:
		var impact: Vector2 = ledger.inspect_entity(target_id).position
		for item in ledger.snapshot().entities:
			if item.kind != "PERSON" or item.assignment == "Dead": continue
			var blast_distance: float = item.position.distance_to(impact)
			if blast_distance >= 8.0 and blast_distance <= 13.0:
				_apply_stress(item.id,0,20 if item.basic_training else 25,true)
				continue
			if blast_distance >= 8.0: continue
			var cover: Dictionary = world.cover(item.position,ledger.inspect_entity(row.gun_id).position,0,false,Vector3(impact.x,impact.y,world.ground(impact)+1.5))
			var blast: int = int(ceil(100.0*(1.0-blast_distance/8.0)*float(cover.blast)))
			var damage := maxi(blast,120 if item.id == target_id else 0)
			if damage > 0: injure(item.id,damage,true)
	_log("W04 direct shot from %s: %s; one allocated local E14 consumed" % [row.gun_id,"hit" if hit else "miss"])
	return {"ok":true,"hit":hit,"remaining_local":_rear().ledger.available_stock_at(ledger.inspect_entity(row.gun_id).holder_id,"E14")}

func injure(person_id: String, injury: int, blast: bool = false) -> Dictionary:
	var ledger: RefCounted = _rear().ledger
	var before: Dictionary = ledger.inspect_entity(person_id,{},false)
	if before.is_empty() or before.kind != "PERSON": return _block("Actual person required for injury.")
	var result: Dictionary = ledger.injure_person(person_id,injury)
	if not result.ok: return result
	if blast and result.code != "DEAD": _apply_stress(person_id,-10,0,true)
	if result.code == "INCAPACITATED":
		bleeding[person_id] = true
		_nearby_casualty(person_id,-8)
		_cancel_reload_for(person_id)
	if result.code == "DEAD": _on_death(person_id,before)
	if not before.duty_id.is_empty(): formation_changed(before.duty_id)
	_log("%s took %d injury: %s" % [person_id,injury,result.code])
	return result

func start_care(medic_id: String, patient_id: String, pack_id: String = "") -> Dictionary:
	if _rear().forward_supply != null and _rear().forward_supply.person_committed(medic_id): return _block("Local supply handling must finish before medical care.")
	if _rear().military != null and _rear().military.person_committed(medic_id): return _block("Troop transport handling must finish before this action.")
	var ledger: RefCounted = _rear().ledger
	var medic: Dictionary = ledger.inspect_entity(medic_id)
	var patient: Dictionary = ledger.inspect_entity(patient_id)
	if medic.is_empty() or patient.is_empty() or medic.kind != "PERSON" or patient.kind != "PERSON" or medic.qualification != "P03" or medic.assignment in ["Wounded","Recovery","Dead"] or patient.assignment != "Wounded" or medic.owner != patient.owner: return _block("A living P03 must care for a living friendly incapacitated patient.")
	if medic.position.distance_to(patient.position) > 2.0+EPS or _seated(medic) or not medic.crew_station.is_empty(): return _block("Medic must be stationary and within two metres of the patient.")
	if not _holds(medic_id,"E11"): return _block("Medic lacks an actual carried E11 kit.")
	if care.has(patient_id):
		care[patient_id].medic = medic_id
		care[patient_id].active = true
		return {"ok":true,"message":"Committed care resumed with preserved work and pack."}
	var pack: Dictionary = ledger.inspect_entity(pack_id)
	if pack.is_empty() or pack.kind != "STOCK" or pack.design_type != "E12" or pack.holder_id != medic_id or pack.available < 1: return _block("One unreserved E12 pack must be physically carried by this medic.")
	var consumed: Dictionary = ledger.record_consumption(pack_id,1,"Field care for "+patient_id)
	if not consumed.ok: return _block(consumed.message)
	care[patient_id] = {"medic":medic_id,"pack":pack_id,"progress":0.0,"active":true,"committed_at":_rear().time}
	return {"ok":true,"message":"One local pack committed; ten cumulative care seconds required."}

func interrupt_care(patient_id: String) -> Dictionary:
	if not care.has(patient_id) or not care[patient_id].active: return _block("No active field care to interrupt.")
	care[patient_id].active = false
	care[patient_id].medic = ""
	return {"ok":true,"message":"Care work preserved; the original bleed timer continues."}

func cancel_care(patient_id: String) -> Dictionary:
	if not care.has(patient_id): return _block("No committed treatment episode exists.")
	care.erase(patient_id)
	return {"ok":true,"message":"Treatment cancelled; consumed pack and progress are lost."}

func next_boundary() -> float:
	var next := _next_stress_tick if not last_incoming.is_empty() or not last_casualty.is_empty() else INF
	for row in gun_setups.values():
		if not row.complete: next = minf(next,float(row.due))
	for row in reloads.values(): next = minf(next,float(row.due))
	for patient_id in care:
		if care[patient_id].active: next = minf(next,_rear().time+10.0-float(care[patient_id].progress))
	for id in bleeding:
		var patient: Dictionary = _rear().ledger.inspect_entity(id,{},false)
		if patient.assignment == "Wounded": next = minf(next,_rear().time+float(patient.bleed_remaining))
	for id in dispersed_since:
		var dispersal_due: float = float(dispersed_since[id])+10.0
		if dispersal_due > _rear().time+EPS: next = minf(next,dispersal_due)
	return next

func advance_to(at: float) -> void:
	var delta: float = at-_rear().time
	if delta <= 0: return
	for patient_id in care:
		var episode: Dictionary = care[patient_id]
		if not episode.active: continue
		var medic: Dictionary = _rear().ledger.inspect_entity(episode.medic,{},false)
		var patient: Dictionary = _rear().ledger.inspect_entity(patient_id,{},false)
		if medic.is_empty() or patient.is_empty() or medic.assignment in ["Wounded","Recovery","Dead"] or patient.assignment != "Wounded" or medic.position.distance_to(patient.position) > 2.0+EPS:
			episode.active = false
			episode.medic = ""
			continue
		_rear().ledger.pause_bleed_during_care(patient_id,delta)
		episode.progress = minf(10.0,float(episode.progress)+delta)

func settle() -> bool:
	var changed := false
	var ledger: RefCounted = _rear().ledger
	for gun_id in gun_setups:
		var setup: Dictionary = gun_setups[gun_id]
		if not setup.complete and setup.due <= _rear().time+EPS:
			setup.complete = _field_crew_ready(_rear().military.squads.get(setup.squad,{}))
			if not setup.complete: setup.due = INF
			changed = true
	for id in bleeding.keys():
		var patient: Dictionary = ledger.inspect_entity(id,{},false)
		if patient.assignment != "Wounded" or patient.bleed_remaining > EPS: continue
		if ledger.bleed_out_person(id).ok:
			_on_death(id,patient)
			changed = true
	for patient_id in care.keys():
		if not care[patient_id].active or float(care[patient_id].progress) < 10.0-EPS: continue
		if ledger.finish_field_care(patient_id).ok:
			bleeding.erase(patient_id)
			care.erase(patient_id)
			changed = true
	for weapon_id in reloads.keys():
		var row: Dictionary = reloads[weapon_id]
		if float(row.due) > _rear().time+EPS: continue
		var person: Dictionary = ledger.inspect_entity(row.operator,{},false)
		ledger.release_claim(row.claim)
		if not person.is_empty() and person.assignment not in ["Wounded","Recovery","Dead"] and ledger.inspect_entity(weapon_id,{},false).holder_id == row.operator:
			var result: Dictionary = ledger.load_rounds(weapon_id,row.source,row.quantity)
			if result.ok: demands.erase(row.operator)
		reloads.erase(weapon_id)
		changed = true
	if (not last_incoming.is_empty() or not last_casualty.is_empty()) and _next_stress_tick <= _rear().time+EPS:
		_stress_tick()
		_next_stress_tick = _rear().time+1.0
		changed = true
	return changed

func _field_crew_ready(row: Dictionary) -> bool:
	if row.is_empty() or row.get("gun_id","").is_empty(): return false
	var gun: Dictionary = _rear().ledger.inspect_entity(row.gun_id,{},false)
	if gun.is_empty() or gun.get("health",0) <= 0: return false
	var count := 0
	for id in row.roster:
		var person: Dictionary = _rear().ledger.inspect_entity(id,{},false)
		if not person.is_empty() and person.qualification == "P05" and person.assignment == "Formation Duty" and person.health > 0 and person.position.distance_to(gun.position) <= 2.0 and (_rear().forward_supply == null or not _rear().forward_supply.person_committed(id)) and (_rear().military == null or not _rear().military.person_committed(id)): count += 1
	return count >= 4

func squad_cohesion(squad_id: String) -> Dictionary:
	var row: Dictionary = _rear().military.squads.get(squad_id,{})
	if row.is_empty() or row.state != "Active": return {"cohesion":0.0,"state":"Unavailable","blocked_reason":"No active actual squad."}
	var active: Array[String] = _rear().military._active_roster_members(row,true)
	var dismounted: Array[String] = []
	var people := {}
	var boarded := 0
	for id in active:
		var person: Dictionary = _rear().ledger.inspect_person_status(id)
		people[id] = person
		if _seated(person): boarded += 1
		else: dismounted.append(id)
	if boarded == active.size() and boarded > 0: return {"cohesion":1.0,"state":"Boarded","blocked_reason":"Dismount before infantry fire."}
	if dismounted.is_empty(): return {"cohesion":0.0,"state":"No active infantry","blocked_reason":"No active dismounted people."}
	var leader: Dictionary = people[row.leader] if people.has(row.leader) else _rear().ledger.inspect_person_status(row.leader)
	var near := 0
	for id in dismounted:
		if not leader.is_empty() and leader.assignment == "Formation Duty" and leader.position.distance_to(people[id].position) <= 30.0: near += 1
	var value := float(near)/float(dismounted.size())
	var state := "Coherent"
	var reason := ""
	if value < 0.5:
		state = "Dispersed" if dispersed_since.has(squad_id) and _rear().time-float(dispersed_since[squad_id]) >= 10.0 else "Regrouping"
		reason = "Offensive coordination paused; regroup around actual leader."
	return {"cohesion":value,"state":state,"blocked_reason":reason,"regroup_seconds":maxf(0.0,_rear().time-float(dispersed_since[squad_id])) if dispersed_since.has(squad_id) else 0.0}

func formation_changed(squad_id: String) -> void:
	if not _rear().military.squads.has(squad_id):
		dispersed_since.erase(squad_id)
		return
	var assessment: Dictionary = squad_cohesion(squad_id)
	if assessment.state in ["Unavailable","Boarded","No active infantry"] or assessment.cohesion >= 0.5:
		dispersed_since.erase(squad_id)
	elif not dispersed_since.has(squad_id): dispersed_since[squad_id] = _rear().time

func _on_person_position_changed(person_id: String) -> void:
	for row in _rear().military.squads.values():
		if person_id in row.roster: formation_changed(row.id)

func snapshot(owner: String = "") -> Dictionary:
	var people: Array[Dictionary] = []
	for item in _rear().ledger.snapshot().entities:
		if not owner.is_empty() and item.owner != owner: continue
		if item.kind != "PERSON" or item.assignment not in ["Wounded","Recovery","Dead"] and item.suppression == 0 and item.morale == 60: continue
		people.append({"id":item.id,"position":item.position,"assignment":item.assignment,"health":item.health,"bleed_remaining":item.bleed_remaining,"morale":item.morale,"suppression":item.suppression,"state":_state(item),"care":care.get(item.id,{}).duplicate(true)})
	var formations := {}
	for id in _rear().military.squads:
		if owner.is_empty() or _rear().military.squads[id].get("owner",_rear().PLAYER) == owner: formations[id] = squad_cohesion(id)
	var demand_rows := demands.duplicate(true)
	var care_rows := care.duplicate(true)
	if not owner.is_empty():
		for id in demand_rows.keys():
			if _rear().ledger.inspect_entity(id).get("owner","") != owner: demand_rows.erase(id)
		for id in care_rows.keys():
			if _rear().ledger.inspect_entity(id).get("owner","") != owner: care_rows.erase(id)
	return {"people":people,"formations":formations,"demands":demand_rows,"reloads":reloads.duplicate(true),"care":care_rows,"deaths":deaths.duplicate(true),"events":events.duplicate(true)}

func audit() -> Array[String]:
	var errors: Array[String] = []
	for id in deaths:
		var p: Dictionary = _rear().ledger.inspect_entity(id)
		if p.assignment != "Dead" or not p.loss_recorded: errors.append("G16 loss is not tied to one actual dead person: "+id)
	for patient_id in care:
		var patient: Dictionary = _rear().ledger.inspect_entity(patient_id)
		if patient.assignment != "Wounded" or float(care[patient_id].progress) < 0 or float(care[patient_id].progress) > 10.0: errors.append("G16 invalid committed care: "+patient_id)
	for weapon_id in reloads:
		var row: Dictionary = reloads[weapon_id]
		if _rear().ledger.inspect_claim(row.claim).get("reserved",0) != row.quantity: errors.append("G16 reload lacks actual local stock reservation: "+weapon_id)
	return errors

func _on_death(id: String, before: Dictionary) -> void:
	if deaths.has(id): return
	deaths[id] = {"at":_rear().time,"owner":before.owner,"duty":before.duty_id}
	bleeding.erase(id)
	last_incoming.erase(id)
	last_casualty.erase(id)
	pinned.erase(id)
	broken.erase(id)
	care.erase(id)
	for weapon_id in reloads.keys():
		if reloads[weapon_id].operator == id: interrupt_reload(weapon_id)
	_rear().dispatch.military_people.erase(id)
	_rear().dispatch.hq_reserve.erase(id)
	if _rear().military != null: _rear().military.record_death(id)
	if not before.duty_id.is_empty(): formation_changed(before.duty_id)
	_nearby_casualty(id,-4)
	_log("%s died; one military roster place released" % id)

func _nearby_casualty(id: String, delta: int) -> void:
	var source: Dictionary = _rear().ledger.inspect_entity(id,{},false)
	for item in _rear().ledger.entities_of_kind(Records.Kind.PERSON,false):
		if item.kind == "PERSON" and item.id != id and item.owner == source.owner and item.assignment != "Dead" and item.position.distance_to(source.position) <= 20.0:
			_apply_stress(item.id,delta,0,false)
			last_casualty[item.id] = _rear().time

func _apply_stress(id: String, morale_delta: int, suppression_delta: int, incoming: bool) -> void:
	_rear().ledger.set_person_stress(id,morale_delta,suppression_delta)
	if incoming: last_incoming[id] = _rear().time
	var person: Dictionary = _rear().ledger.inspect_entity(id,{},false)
	if person.suppression >= 60: pinned[id] = true
	elif person.suppression < 40: pinned.erase(id)
	if person.morale < 20: broken[id] = true
	elif person.morale >= 40: broken.erase(id)

func _stress_tick() -> void:
	for item in _rear().ledger.entities_of_kind(Records.Kind.PERSON,false):
		if item.kind != "PERSON" or item.assignment == "Dead": continue
		var since_fire: float = _rear().time-float(last_incoming.get(item.id,-INF))
		var since_casualty: float = _rear().time-float(last_casualty.get(item.id,-INF))
		var suppression_delta := -5 if since_fire >= 3.0-EPS and item.suppression > 0 else 0
		var morale_delta := 0
		if since_fire >= 10.0-EPS and since_casualty >= 10.0-EPS and item.morale < 60 and not _visible_hostile_near(item):
			morale_delta = mini(60-item.morale,2 if item.basic_training else 1)
		if suppression_delta != 0 or morale_delta != 0: _apply_stress(item.id,morale_delta,suppression_delta,false)
		var current: Dictionary = _rear().ledger.inspect_entity(item.id,{},false)
		if current.suppression == 0 and current.morale >= 60 and since_fire >= 10.0-EPS and since_casualty >= 10.0-EPS:
			last_incoming.erase(item.id)
			last_casualty.erase(item.id)

func _visible_hostile_near(person: Dictionary) -> bool:
	for item in _rear().ledger.entities_of_kind(Records.Kind.PERSON,false):
		if item.kind == "PERSON" and item.owner != person.owner and item.assignment not in ["Wounded","Dead"] and item.position.distance_to(person.position) <= 100.0:
			if world.is_visible(person.position,item.position): return true
	return false

func _record_demand(id: String, ammo_type: String) -> void:
	var holder: Dictionary = _rear().ledger.inspect_entity(id,{},false)
	var local: int = _rear().ledger.available_stock_at(id,ammo_type)
	var elsewhere := 0
	var sources: Array[Dictionary] = []
	for item in _rear().ledger.snapshot(false).entities:
		if item.kind != "STOCK" or item.design_type != ammo_type or item.owner != holder.owner or item.holder_id == id or item.loaded or item.available <= 0: continue
		elsewhere += int(item.available)
		sources.append({"id":item.id,"holder":item.holder_id,"available":item.available,"position":item.position})
	demands[id] = {"ammo_type":ammo_type,"local_available":local,"elsewhere":elsewhere,"sources":sources,"position":holder.position,"blocked_reason":"Need %s at %s; %d local loose, %d owned unreserved rounds elsewhere." % [ammo_type,id,local,elsewhere]}

func _cancel_reload_for(person_id: String) -> void:
	for weapon_id in reloads.keys():
		if reloads[weapon_id].operator == person_id: interrupt_reload(weapon_id)

func _armour_factor(id: String) -> float:
	var factor := 1.0
	for item in _rear().ledger.snapshot(false).entities:
		if item.holder_id != id: continue
		if item.design_type == "E03": factor -= 0.05
		if item.design_type == "E04": factor -= 0.15
	return maxf(0.0,factor)

func _assistant_near(id: String) -> bool:
	var operator: Dictionary = _rear().ledger.inspect_entity(id,{},false)
	for item in _rear().ledger.entities_of_kind(Records.Kind.PERSON,false):
		if item.kind == "PERSON" and item.id != id and item.owner == operator.owner and item.assignment == "Formation Duty" and item.health > 0 and item.position.distance_to(operator.position) <= 2.0 and not _seated(item): return true
	return false

func _holds(id: String, type: String) -> bool:
	for item in _rear().ledger.snapshot().entities:
		if item.holder_id == id and item.design_type == type and item.quantity > 0: return true
	return false

func _medic_busy(id: String) -> bool:
	for row in care.values():
		if row.active and row.medic == id: return true
	return false

func _seated(person: Dictionary) -> bool:
	return _rear().ledger.entity_kind(person.holder_id) == "CARRIER"

func _segment_fraction(point: Vector2, start: Vector2, finish: Vector2) -> float:
	return clampf((point-start).dot(finish-start)/maxf(EPS,start.distance_squared_to(finish)),0.0,1.0)

func _state(person: Dictionary) -> String:
	if person.assignment == "Wounded": return "Bleeding"
	if person.assignment == "Recovery": return "Stabilized"
	if person.assignment == "Dead": return "Dead"
	if broken.has(person.id): return "Broken"
	if pinned.has(person.id): return "Pinned"
	return "Active"

func _log(message: String) -> void:
	events.append({"at":_rear().time,"message":message})
	if events.size() > 40: events.pop_front()

func _block(reason: String) -> Dictionary:
	return {"ok":false,"blocked_reason":reason,"message":reason}
