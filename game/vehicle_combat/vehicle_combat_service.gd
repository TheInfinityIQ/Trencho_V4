extends RefCounted
## G23 mounted weapons use the same hull, people, stock and clock as the rest of the game.
const EPS := 0.000001
const MOUNTS := {
	"T03":{"MG":{"ammo":"E02","range":250.0,"hit":0.45,"person":24,"vehicle":18,"structure":2,"penetration":8,"capacity":60,"reload":6.0,"turn":90.0,"moving":0.55}},
	"T04":{"Autocannon":{"ammo":"E26","range":450.0,"hit":0.60,"person":35,"vehicle":35,"structure":20,"penetration":45,"capacity":30,"reload":6.0,"turn":60.0,"moving":0.75}},
	"T05":{
		"Main":{"ammo":"E25","range":700.0,"hit":0.65,"person":140,"vehicle":260,"structure":400,"penetration":130,"capacity":1,"reload":8.0,"turn":45.0,"moving":0.60},
		"Coax":{"ammo":"E02","range":250.0,"hit":0.45,"person":24,"vehicle":18,"structure":2,"penetration":8,"capacity":60,"reload":6.0,"turn":45.0,"moving":1.0},
	},
}
const PERSONAL := {
	"E01":{"range":160.0,"hit":0.55,"person":34,"damage":10,"penetration":5,"cadence":2.0},
	"E05":{"range":250.0,"hit":0.45,"person":24,"damage":18,"penetration":8,"cadence":0.25},
	"E19":{"range":300.0,"hit":0.70,"person":55,"damage":14,"penetration":8,"cadence":4.0},
}
var _rear_ref: WeakRef
var rng := RandomNumberGenerator.new()
var mounts: Dictionary = {}
var projectiles: Array[Dictionary] = []
var events: Array[Dictionary] = []

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	rng.seed = 23031

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func _target(id: String) -> Dictionary:
	var entity: Dictionary = _rear().ledger.inspect_entity(id)
	if not entity.is_empty() and entity.kind != "PLACE": return entity
	if _rear().field_structures != null:
		var field: Dictionary = _rear().field_structures.inspect(id)
		if not field.is_empty() and field.state == "Complete" and field.health > 0 and field.code != "S11":
			return {"id":id,"kind":"STRUCTURE","owner":field.owner,"position":field.center,"health":field.health,"service":"field"}
	if _rear().bridges != null:
		var bridge: Dictionary = _rear().bridges.inspect(id)
		if bridge.get("state","") == "Complete" and bridge.get("health",0) > 0 and not bridge.deck.is_empty():
			var middle: Vector2 = Vector2(bridge.deck[int(bridge.deck.size()/2)])
			return {"id":id,"kind":"STRUCTURE","owner":bridge.owner,"position":middle,"health":bridge.health,"service":"bridge"}
	return {}

func _damage_structure(target: Dictionary, damage: int) -> Dictionary:
	if target.service == "field": return _rear().field_structures.damage(target.id,damage)
	return _rear().bridges.damage(target.id,damage)

func _block(reason: String) -> Dictionary:
	return {"ok":false,"blocked_reason":reason}

func _mount(id: String) -> Dictionary:
	if not mounts.has(id):
		mounts[id] = {"angle":0.0,"target":"","aim_due":0.0,"selected":"","switch_due":0.0,"loaded":{},"reload_due":{},"next_fire":{},"burst":0}
	return mounts[id]

func _operator(hull: Dictionary, station: String) -> String:
	if not hull.get("crew_by_station",{}).has(station): return ""
	var id: String = hull.crew_by_station[station]
	var person: Dictionary = _rear().ledger.inspect_entity(id)
	if person.is_empty() or person.health <= 0 or person.holder_id != hull.id or person.crew_station != station or not person.basic_training or person.assignment in ["Wounded","Recovery","Dead"]: return ""
	if person.qualification != "P08" and not (hull.design_type == "T03" and station == "Gunner" and person.qualification == "P04"): return ""
	return id

func _exposed_gunner(person: Dictionary) -> bool:
	if person.get("kind","") != "PERSON" or person.get("crew_station","") != "Gunner": return false
	var hull: Dictionary = _rear().ledger.inspect_entity(person.holder_id)
	return hull.get("design_type","") == "T03" and hull.get("health",0) > 0

func _surface(target: Dictionary, origin: Vector2) -> String:
	var direction: Vector2 = origin-target.position
	if direction.length_squared() <= EPS: return "Side"
	var offset: float = absf(wrapf(rad_to_deg(direction.angle())-float(target.facing_degrees),-180.0,180.0))
	if offset <= 60.0: return "Front"
	if offset >= 120.0: return "Rear"
	return "Side"

func _friendly_line_blocker(owner: String, shooter_id: String, target_id: String, origin: Vector2, destination: Vector2) -> String:
	var direction: Vector2 = destination-origin
	if direction.length_squared() <= EPS: return ""
	for item in _rear().ledger.snapshot().entities:
		if item.id in [shooter_id,target_id] or item.owner != owner or item.kind not in ["PERSON","CARRIER"]: continue
		if item.kind == "PERSON" and (item.health <= 0 or _seated(item)): continue
		var fraction: float = (item.position-origin).dot(direction)/direction.length_squared()
		if fraction <= EPS or fraction >= 1.0-EPS: continue
		var clearance := 0.5
		if item.kind == "CARRIER" and item.has("vehicle_spec"): clearance = float(item.vehicle_spec.footprint.y)*0.5
		if item.position.distance_to(origin+direction*fraction) <= clearance: return item.id
	return ""

func set_facing(id: String, degrees: float) -> Dictionary:
	return _rear().ledger.set_vehicle_facing(id,degrees)

func aim(id: String, target_id: String) -> Dictionary:
	var hull: Dictionary = _rear().ledger.inspect_entity(id)
	var target: Dictionary = _target(target_id)
	if hull.is_empty() or target.is_empty() or not MOUNTS.has(hull.get("design_type","")) or hull.health <= 0 or target.position == hull.position: return _block("Actual armed hull and distinct positioned target required.")
	if _operator(hull,"Gunner").is_empty(): return _block("Actual gunner must occupy the hull station.")
	var row: Dictionary = _mount(id)
	var angle: float = rad_to_deg((target.position-hull.position).angle())
	var turn: float = float(MOUNTS[hull.design_type].values()[0].turn)
	var delta: float = absf(wrapf(angle-float(row.angle),-180.0,180.0))
	row.target = target_id
	row.aim_due = _rear().time+maxf(0.0,delta-5.0)/turn
	row.angle = angle
	return {"ok":true,"due":row.aim_due}

func select_weapon(id: String, weapon: String) -> Dictionary:
	var hull: Dictionary = _rear().ledger.inspect_entity(id)
	if hull.is_empty() or hull.design_type != "T05" or weapon not in ["Main","Coax"] or _operator(hull,"Gunner").is_empty(): return _block("Actual tank gunner and integral main or coax required.")
	var row: Dictionary = _mount(id)
	if row.selected != weapon:
		row.selected = weapon
		row.switch_due = _rear().time+1.0
	return {"ok":true,"due":row.switch_due}

func inspect_fire(id: String, target_id: String, weapon: String, moving: bool = false) -> Dictionary:
	var hull: Dictionary = _rear().ledger.inspect_entity(id)
	var target: Dictionary = _target(target_id)
	if hull.is_empty() or not MOUNTS.has(hull.get("design_type","")) or not MOUNTS[hull.design_type].has(weapon) or hull.health <= 0: return _block("Surviving actual hull and integral mount required.")
	if not hull.get("towing","").is_empty(): return _block("Tractor cannot fire while towing.")
	if target.is_empty() or target.owner == hull.owner or target.get("health",0) <= 0 or target.kind not in ["PERSON","CARRIER","STRUCTURE"]: return _block("Active hostile person, vehicle or structure required.")
	if target.kind == "PERSON" and (target.assignment in ["Wounded","Recovery","Dead"] or (_seated(target) and not _exposed_gunner(target))): return _block("Protected seated or incapacitated people cannot be targeted through a hull.")
	if _operator(hull,"Gunner").is_empty(): return _block("Actual living gunner absent.")
	if weapon == "Main" and _operator(hull,"Loader").is_empty(): return _block("Main gun requires separate actual loader.")
	if moving and _operator(hull,"Driver").is_empty(): return _block("Moving fire requires separate actual driver.")
	var spec: Dictionary = MOUNTS[hull.design_type][weapon]
	var row: Dictionary = _mount(id)
	if row.target != target_id or _rear().time+EPS < float(row.aim_due): return _block("Turret not yet aligned within five degrees.")
	var angle: float = rad_to_deg((target.position-hull.position).angle())
	if absf(wrapf(angle-float(row.angle),-180.0,180.0)) > 5.0: return _block("Target moved outside aligned arc.")
	if hull.design_type == "T05" and row.selected != weapon: return _block("Tank gunner must select the main or coax mount.")
	if _rear().time+EPS < float(row.switch_due): return _block("Tank weapon switch needs one second.")
	if _rear().time+EPS < float(row.next_fire.get(weapon,0.0)): return _block("Mounted firing cadence in progress.")
	if row.reload_due.has(weapon): return _block("Mounted reload in progress.")
	var distance: float = hull.position.distance_to(target.position)
	if distance <= EPS or distance > float(spec.range)+EPS: return _block("Target outside mounted weapon range.")
	if weapon == "Main" and target.kind == "PERSON":
		var cluster := 0
		for person in _rear().ledger.snapshot().entities:
			if person.kind == "PERSON" and person.owner == target.owner and person.health > 0 and not _seated(person) and person.position.distance_to(target.position) < 6.0: cluster += 1
		if cluster < 4: return _block("Main shell against exposed infantry requires a cluster of at least four.")
	if weapon in ["Main","Autocannon"]:
		var radius := 6.0 if weapon == "Main" else 2.0
		for person in _rear().ledger.snapshot().entities:
			if person.kind == "PERSON" and person.owner == hull.owner and person.health > 0 and not _seated(person) and person.position.distance_to(target.position) < radius: return _block("Friendly person occupies the cannon blast area.")
	var sight: Dictionary = _rear().combat.world.observe(hull.position,target.position,"ordinary",1.5,float(spec.range))
	if not sight.visible or not sight.firing_line_clear: return _block("Observation or firing line blocked.")
	var friendly: String = _friendly_line_blocker(hull.owner,id,target_id,hull.position,target.position)
	if not friendly.is_empty(): return _block("Friendly person or vehicle "+friendly+" intersects the direct firing line.")
	var stock: int = _available_rack(id,str(spec.ammo))
	if stock <= 0: return _block("Matching ammunition absent from this hull's unreserved rack; remote stock cannot fire.")
	var loaded: int = mini(int(row.loaded.get(weapon,int(spec.capacity))),stock)
	if loaded <= 0: return _block("Mounted magazine empty; reload from this hull's rack.")
	var chance: float = float(spec.hit)*(1.0-0.5*distance/float(spec.range))*(float(spec.moving) if moving else 1.0)
	if target.kind == "PERSON":
		chance *= float(_rear().combat.world.cover(target.position,hull.position).hit)
		if _exposed_gunner(target): chance *= 0.65
	return {"ok":true,"chance":clampf(chance,0.05,0.95),"surface":_surface(target,hull.position) if target.kind == "CARRIER" else "","loaded":loaded,"local":stock}

func fire(id: String, target_id: String, weapon: String, moving: bool = false) -> Dictionary:
	var check: Dictionary = inspect_fire(id,target_id,weapon,moving)
	if not check.ok: return check
	var ledger: RefCounted = _rear().ledger
	var hull: Dictionary = ledger.inspect_entity(id)
	var target: Dictionary = _target(target_id)
	var spec: Dictionary = MOUNTS[hull.design_type][weapon]
	var spent: Dictionary = ledger.record_consumption(_rack_source(id,str(spec.ammo)),1,"Mounted "+weapon+" fired from "+id)
	if not spent.ok: return _block(spent.message)
	var row: Dictionary = _mount(id)
	row.loaded[weapon] = int(check.loaded)-1
	if weapon == "Autocannon":
		row.burst = (int(row.burst)+1)%3
		row.next_fire[weapon] = _rear().time+(4.0/3.0 if row.burst == 0 else 1.0/3.0)
	else: row.next_fire[weapon] = _rear().time+(8.0 if weapon == "Main" else 0.25)
	var hit: bool = rng.randf() < float(check.chance)
	if weapon in ["Main","Autocannon"]:
		var due: float = _rear().time+maxf(0.25,hull.position.distance_to(target.position)/300.0)
		var impact: Vector2 = target.position
		if not hit:
			var blast_radius: float = 6.0 if weapon == "Main" else 2.0
			impact += Vector2.from_angle(rng.randf_range(0.0,TAU))*blast_radius*1.5
		projectiles.append({"due":due,"hull":id,"weapon":weapon,"target":target_id,"position":impact,"hit":hit,"surface":check.surface,"shooter_position":hull.position})
		events.append({"time":_rear().time,"hull":id,"weapon":weapon,"target":target_id,"phase":"Released","ammo":spec.ammo,"impact_due":due})
		return {"ok":true,"released":true,"impact_due":due,"remaining_local":_available_rack(id,str(spec.ammo))}
	var damage := 0
	var penetrated := false
	if hit and target.kind == "CARRIER":
		var result: Dictionary = ledger.apply_vehicle_surface_damage(target_id,int(spec.vehicle),int(spec.penetration),str(check.surface),weapon+" strike from "+id)
		penetrated = bool(result.get("penetrated",false))
		damage = int(spec.vehicle) if penetrated else 0
		if penetrated and int(result.health) > 0 and damage >= 35 and weapon in ["Main","Autocannon"]:
			for person_id in target.crew + target.passengers:
				if ledger.inspect_entity(person_id).health > 0: _rear().combat.injure(person_id,10)
	elif hit and target.kind == "STRUCTURE":
		damage = int(spec.structure)
		_damage_structure(target,damage)
	elif hit:
		damage = int(spec.person)
		_rear().combat.injure(target_id,damage)
	events.append({"time":_rear().time,"hull":id,"weapon":weapon,"target":target_id,"hit":hit,"damage":damage,"surface":check.surface,"ammo":spec.ammo})
	return {"ok":true,"hit":hit,"damage":damage,"penetrated":penetrated,"surface":check.surface,"remaining_local":_available_rack(id,str(spec.ammo))}

func request_reload(id: String, weapon: String) -> Dictionary:
	var hull: Dictionary = _rear().ledger.inspect_entity(id)
	if hull.is_empty() or not MOUNTS.has(hull.get("design_type","")) or not MOUNTS[hull.design_type].has(weapon): return _block("Actual integral mount required.")
	if (weapon == "Main" and _operator(hull,"Loader").is_empty()) or (weapon != "Main" and _operator(hull,"Gunner").is_empty()): return _block("Actual reload operator absent.")
	var spec: Dictionary = MOUNTS[hull.design_type][weapon]
	var row: Dictionary = _mount(id)
	if row.reload_due.has(weapon) or int(row.loaded.get(weapon,mini(int(spec.capacity),_available_rack(id,str(spec.ammo))))) > 0: return _block("Magazine still loaded or reload already committed.")
	if _available_rack(id,str(spec.ammo)) <= 0: return _block("No local unreserved matching rack ammunition.")
	row.reload_due[weapon] = _rear().time+float(spec.reload)
	return {"ok":true,"due":row.reload_due[weapon]}

func interrupt_reload(id: String, weapon: String) -> Dictionary:
	var row: Dictionary = _mount(id)
	if not row.reload_due.has(weapon): return _block("No reload commitment.")
	row.reload_due.erase(weapon)
	return {"ok":true,"message":"Reload interrupted; physical rounds remain unspent."}

func next_boundary() -> float:
	var due := INF
	for row in mounts.values():
		for at in row.reload_due.values(): due = minf(due,float(at))
	for shot in projectiles: due = minf(due,float(shot.due))
	return due

func advance_to(at: float) -> void:
	for shot in projectiles.duplicate():
		if float(shot.due) <= at+EPS:
			_resolve_cannon(shot)
			projectiles.erase(shot)
	for id in mounts:
		var row: Dictionary = mounts[id]
		var hull: Dictionary = _rear().ledger.inspect_entity(id)
		for weapon in row.reload_due.keys():
			if float(row.reload_due[weapon]) > at+EPS: continue
			var spec: Dictionary = MOUNTS.get(hull.get("design_type",""),{}).get(weapon,{})
			if not spec.is_empty() and (not _operator(hull,"Loader").is_empty() if weapon == "Main" else not _operator(hull,"Gunner").is_empty()):
				row.loaded[weapon] = mini(int(spec.capacity),_available_rack(id,str(spec.ammo)))
			row.reload_due.erase(weapon)

func _resolve_cannon(shot: Dictionary) -> void:
	var ledger: RefCounted = _rear().ledger
	var target: Dictionary = _target(shot.target)
	var shooter: Dictionary = ledger.inspect_entity(shot.hull)
	var spec: Dictionary = MOUNTS[shooter.design_type][shot.weapon]
	var radius: float = 6.0 if shot.weapon == "Main" else 2.0
	var blast_person: int = 100 if shot.weapon == "Main" else 30
	var blast_penetration: int = 20 if shot.weapon == "Main" else 10
	var direct: bool = bool(shot.hit) and not target.is_empty() and target.get("health",0) > 0 and target.position.distance_to(shot.position) <= 1.0
	var affected: Array[Dictionary] = []
	if target.get("kind","") == "STRUCTURE":
		var structure_distance: float = target.position.distance_to(shot.position)
		var structure_damage: int = int(spec.structure) if direct else int(ceil(float(spec.structure)*(1.0-structure_distance/radius))) if structure_distance < radius else 0
		if structure_damage > 0:
			_damage_structure(target,structure_damage)
			affected.append({"id":target.id,"kind":"STRUCTURE","damage":structure_damage})
	for item in ledger.snapshot().entities:
		if item.kind not in ["PERSON","CARRIER"] or item.get("health",0) <= 0: continue
		if item.kind == "PERSON" and _seated(item) and not (item.id == shot.target and _exposed_gunner(item)): continue
		var distance: float = item.position.distance_to(shot.position)
		if distance > radius and not (direct and item.id == shot.target): continue
		var damage := 0
		var penetration := 0
		if item.kind == "PERSON":
			var cover: Dictionary = _rear().combat.world.cover(item.position,shot.shooter_position)
			damage = int(ceil(float(blast_person)*(1.0-distance/radius)*float(cover.blast))) if distance < radius else 0
			if direct and item.id == shot.target: damage = maxi(damage,int(spec.person))
		else:
			damage = int(ceil(float(spec.vehicle)*(1.0-distance/radius))) if distance < radius else 0
			penetration = blast_penetration
			if direct and item.id == shot.target:
				damage = maxi(damage,int(spec.vehicle))
				penetration = int(spec.penetration)
		if damage > 0: affected.append({"id":item.id,"kind":item.kind,"damage":damage,"penetration":penetration,"surface":_surface(item,shot.shooter_position) if item.kind == "CARRIER" else ""})
	for item in affected:
		if item.kind == "STRUCTURE": continue # Already applied through its owning structure service.
		if item.kind == "PERSON":
			_rear().combat.injure(item.id,item.damage,true)
			continue
		var before: Dictionary = ledger.inspect_entity(item.id)
		var result: Dictionary = ledger.apply_vehicle_surface_damage(item.id,item.damage,item.penetration,item.surface,shot.weapon+" impact from "+shot.hull)
		if not result.get("penetrated",false) or int(result.health) <= 0 or item.damage < 35: continue
		for person_id in before.crew + before.passengers:
			if ledger.inspect_entity(person_id).health > 0: _rear().combat.injure(person_id,10)
	events.append({"time":shot.due,"hull":shot.hull,"weapon":shot.weapon,"target":shot.target,"phase":"Impact" if not affected.is_empty() else "Miss","direct":direct,"position":shot.position,"affected":affected})

func inspect(id: String) -> Dictionary:
	var hull: Dictionary = _rear().ledger.inspect_entity(id)
	if hull.is_empty(): return {}
	var row: Dictionary = _mount(id)
	var available := {}
	var reserved := {}
	for item in _rear().ledger.snapshot().entities:
		if item.kind != "STOCK" or item.holder_id != id or not hull.get("vehicle_spec",{}).get("rack_capacity",{}).has(item.design_type): continue
		available[item.design_type] = int(available.get(item.design_type,0))+int(item.available)
		reserved[item.design_type] = int(reserved.get(item.design_type,0))+int(item.reserved)
	return {"hull":id,"position":hull.position,"facing":hull.get("facing_degrees",0.0),"health":hull.get("health",0),"crew":hull.get("crew_by_station",{}),"rack":hull.get("ammunition",{}),"rack_available":available,"rack_reserved":reserved,"aim_target":row.target,"aim_due":row.aim_due,"loaded":row.loaded.duplicate(),"reload_due":row.reload_due.duplicate(),"next_fire":row.next_fire.duplicate(),"selected":row.selected}

func inspect_personal_vehicle(shooter_id: String, target_id: String, weapon_id: String) -> Dictionary:
	var ledger: RefCounted = _rear().ledger
	var person: Dictionary = ledger.inspect_entity(shooter_id)
	var target: Dictionary = ledger.inspect_entity(target_id)
	var gun: Dictionary = ledger.inspect_entity(weapon_id)
	if person.is_empty() or target.is_empty() or gun.is_empty() or person.kind != "PERSON" or gun.kind != "WEAPON" or not PERSONAL.has(gun.design_type): return _block("Actual infantry weapon and surviving vehicle target required.")
	if target.kind == "PERSON" and not _exposed_gunner(target): return _block("Seated occupants cannot be selected separately through armour.")
	if target.kind == "CARRIER" and not target.has("vehicle_spec"): return _block("Actual vehicle target required.")
	if target.kind not in ["PERSON","CARRIER"]: return _block("Actual exposed gunner or vehicle target required.")
	if person.owner == target.owner or target.health <= 0 or person.health <= 0 or person.assignment in ["Wounded","Recovery","Dead"] or _seated(person) or not person.crew_station.is_empty(): return _block("Living dismounted hostile shooter and surviving hull required.")
	if _rear().forward_supply != null and _rear().forward_supply.person_committed(shooter_id): return _block("Forward issue handoff occupies this person.")
	if _rear().military != null and _rear().military.person_committed(shooter_id): return _block("Troop transport handling occupies this person.")
	if gun.holder_id != shooter_id or not gun.functional or gun.loaded_rounds <= 0: return _block("Shooter must hold a functional weapon with its own loaded E02.")
	if gun.design_type == "E05" and person.qualification != "P04": return _block("Portable machine gun requires actual P04.")
	if gun.design_type == "E19" and person.qualification != "P07": return _block("Marksman rifle requires actual P07.")
	if _rear().time+EPS < float(_rear().combat.cooldowns.get(weapon_id,0.0)): return _block("Personal weapon cadence in progress.")
	var spec: Dictionary = PERSONAL[gun.design_type]
	var distance: float = person.position.distance_to(target.position)
	if distance <= EPS or distance > float(spec.range)+EPS: return _block("Vehicle outside personal weapon range.")
	var sight: Dictionary = _rear().combat.world.observe(person.position,target.position,"ordinary",1.5,float(spec.range))
	if not sight.visible or not sight.firing_line_clear: return _block("Observation or firing line blocked.")
	var friendly: String = _friendly_line_blocker(person.owner,shooter_id,target_id,person.position,target.position)
	if not friendly.is_empty(): return _block("Friendly person or vehicle "+friendly+" intersects the direct firing line.")
	return {"ok":true,"chance":clampf(float(spec.hit)*(1.0-0.5*distance/float(spec.range))*(0.65 if target.kind == "PERSON" else 1.0),0.05,0.95),"surface":_surface(target,person.position) if target.kind == "CARRIER" else ""}

func fire_personal_at_vehicle(shooter_id: String, target_id: String, weapon_id: String) -> Dictionary:
	var check: Dictionary = inspect_personal_vehicle(shooter_id,target_id,weapon_id)
	if not check.ok: return check
	var ledger: RefCounted = _rear().ledger
	var gun: Dictionary = ledger.inspect_entity(weapon_id)
	var spent: Dictionary = ledger.fire_loaded_round(weapon_id)
	if not spent.ok: return _block(spent.message)
	var spec: Dictionary = PERSONAL[gun.design_type]
	_rear().combat.cooldowns[weapon_id] = _rear().time+float(spec.cadence)
	var hit: bool = rng.randf() < float(check.chance)
	var penetrated := false
	if hit:
		var target: Dictionary = ledger.inspect_entity(target_id)
		if target.kind == "PERSON":
			var injury: int = int(spec.person)
			_rear().combat.injure(target_id,injury)
			return {"ok":true,"hit":true,"injury":injury,"surface":""}
		var result: Dictionary = ledger.apply_vehicle_surface_damage(target_id,int(spec.damage),int(spec.penetration),str(check.surface),"Personal "+gun.design_type+" strike")
		penetrated = bool(result.get("penetrated",false))
	return {"ok":true,"hit":hit,"penetrated":penetrated,"damage":int(spec.damage) if penetrated else 0,"surface":check.surface}

func _rack_source(id: String, ammo: String) -> String:
	for item in _rear().ledger.snapshot().entities:
		if item.kind == "STOCK" and item.holder_id == id and item.design_type == ammo and item.available > 0: return item.id
	return ""

func _available_rack(id: String, ammo: String) -> int:
	var total := 0
	for item in _rear().ledger.snapshot().entities:
		if item.kind == "STOCK" and item.holder_id == id and item.design_type == ammo: total += int(item.available)
	return total

func _seated(person: Dictionary) -> bool:
	return _rear().ledger.entity_kind(person.holder_id) == "CARRIER"
