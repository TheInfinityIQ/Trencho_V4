extends RefCounted
## G18 control and income over the shared G01/G15/G16 physical state and clock.
const Records = preload("res://game/identity/identity_records.gd")
const EPS := 0.000001
const RADIUS := 25.0
const RESOURCE_INCOME := 1.5
const KINDS: Array[String] = ["Resource", "Route Hub", "Observation"]
var _rear_ref: WeakRef
var objectives: Dictionary = {}
var events: Array[Dictionary] = []
var _income_total := 0.0

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func register(place_id: String, kind: String) -> Dictionary:
	var place: Dictionary = _rear().ledger.inspect_entity(place_id)
	if place.get("kind","") != "PLACE" or kind not in KINDS or objectives.has(place_id):
		return {"ok":false,"message":"Register one unique physical place as Resource, Route Hub or Observation."}
	var limit := 6 if kind == "Resource" else (2 if kind == "Route Hub" else 1)
	var used := 0
	for row in objectives.values():
		if row.kind == kind: used += 1
	if used >= limit: return {"ok":false,"message":"Scenario objective count exceeds the GDD kind limit."}
	objectives[place_id] = {"id":place_id,"kind":kind,"position":place.position,"control":0.0,"owner":"","state":"Neutral","blue":[],"red":[],"blockers":[],"income":0.0,"last_at":_rear().time}
	_refresh()
	return {"ok":true,"message":"Physical objective registered at 25 m radius; no owner or income granted."}

func next_boundary() -> float:
	var next := INF
	for row in objectives.values():
		var rate: float = _rate(row)
		if absf(rate) <= EPS: continue
		var goal := 60.0 if rate > 0.0 else -60.0
		if row.blue.is_empty() and row.red.is_empty():
			goal = 60.0 if row.owner == _rear().PLAYER else (-60.0 if row.owner == "army-red" else 0.0)
		elif row.owner == _rear().PLAYER and rate < 0.0 and row.control > 0.0: goal = 0.0
		elif row.owner == "army-red" and rate > 0.0 and row.control < 0.0: goal = 0.0
		if absf(goal-float(row.control)) > EPS: next = minf(next,_rear().time+absf(goal-float(row.control))/absf(rate))
	return next

func advance_to(at: float) -> void:
	var delta: float = at-_rear().time
	if delta <= EPS: return
	for row in objectives.values():
		if row.kind == "Resource" and row.state != "Contested" and row.owner == _rear().PLAYER:
			var credited: float = RESOURCE_INCOME*delta
			_rear().receiving.credit_objective_income(credited)
			row.income += credited
			_income_total += credited
		row.control = clampf(float(row.control)+_rate(row)*delta,-60.0,60.0)
		row.last_at = at

func settle() -> bool:
	if objectives.is_empty(): return false
	var changed := _refresh()
	for row in objectives.values():
		var previous_owner: String = row.owner
		if (previous_owner == _rear().PLAYER and row.control <= EPS) or (previous_owner == "army-red" and row.control >= -EPS): row.owner = ""
		if row.control >= 60.0-EPS: row.owner = _rear().PLAYER
		elif row.control <= -60.0+EPS: row.owner = "army-red"
		if row.owner != previous_owner:
			events.append({"at":_rear().time,"id":row.id,"from":previous_owner,"to":row.owner,"control":row.control})
			if not row.owner.is_empty():
				var participants: Array = row.blue if row.owner == _rear().PLAYER else row.red
				for id in participants: _rear().ledger.set_person_stress(id,5,0)
			changed = true
		var state := "Contested" if not row.blue.is_empty() and not row.red.is_empty() else ("Controlled" if not row.owner.is_empty() else "Neutral")
		if state != row.state:
			row.state = state
			changed = true
	return changed

func inspect(place_id: String) -> Dictionary:
	if not objectives.has(place_id): return {}
	var row: Dictionary = objectives[place_id].duplicate(true)
	row["radius"] = RADIUS
	var effective_rate: float = _rate(row)
	if row.control >= 60.0-EPS and effective_rate > 0.0 or row.control <= -60.0+EPS and effective_rate < 0.0: effective_rate = 0.0
	row["capture_rate"] = effective_rate
	row["income_rate"] = RESOURCE_INCOME if row.kind == "Resource" and row.owner == _rear().PLAYER and row.state != "Contested" else 0.0
	row["blocked_reason"] = "Both armies present: no capture progress or resource income." if row.state == "Contested" else ("No eligible armed dismounted people within 25 m." if row.blue.is_empty() and row.red.is_empty() else "")
	return row

func snapshot() -> Dictionary:
	var rows := {}
	for id in objectives: rows[id] = inspect(id)
	return {"objectives":rows,"income_total":_income_total,"events":events.duplicate(true)}

func audit() -> Array[String]:
	var failures: Array[String] = []
	for id in objectives:
		var row: Dictionary = objectives[id]
		if _rear().ledger.inspect_entity(id).get("kind","") != "PLACE" or absf(float(row.control)) > 60.0+EPS: failures.append("G18 objective place/control invalid: "+id)
		if row.owner == _rear().PLAYER and row.control < -EPS or row.owner == "army-red" and row.control > EPS: failures.append("G18 owner/control contradiction: "+id)
	return failures

func _rate(row: Dictionary) -> float:
	if not row.blue.is_empty() and not row.red.is_empty(): return 0.0
	if not row.blue.is_empty(): return float(mini(4,row.blue.size()))
	if not row.red.is_empty(): return -float(mini(4,row.red.size()))
	var goal := 60.0 if row.owner == _rear().PLAYER else (-60.0 if row.owner == "army-red" else 0.0)
	if float(row.control) < goal-EPS: return 2.0
	if float(row.control) > goal+EPS: return -2.0
	return 0.0

func _refresh() -> bool:
	if objectives.is_empty(): return false
	var blue: Dictionary = {}
	var red: Dictionary = {}
	var blockers: Array[Dictionary] = []
	var ledger: RefCounted = _rear().ledger
	var people: Array[Dictionary] = []
	var reasons := {}
	var armed_candidates: Array[String] = []
	var positions: Array[Vector2] = []
	for row in objectives.values(): positions.append(row.position)
	for person in ledger.persons_near_any(positions,RADIUS+EPS,[_rear().PLAYER,"army-red"],false):
		people.append(person)
		var reason := ""
		if ledger.entity_kind(person.holder_id) != "PLACE" or not str(person.crew_station).is_empty(): reason = "Still aboard or crewing a vehicle; physically dismount first."
		elif person.health <= 0 or person.assignment in ["Wounded","Recovery","Dead"]: reason = "Wounded, recovering or dead people cannot capture."
		elif _rear().combat.broken.has(person.id): reason = "Broken morale requires regrouping."
		reasons[person.id] = reason
		if reason.is_empty(): armed_candidates.append(person.id)
	# Inspect held goods only for nearby people whose earlier physical blockers
	# permit an ammunition check. Both queries retain canonical ledger order.
	var entities: Array = ledger.entities_at_any(armed_candidates,["WEAPON","STOCK"],false)
	var held_weapons: Dictionary = {}
	var held_rounds: Dictionary = {}
	for item in entities:
		if item.kind == "WEAPON" and item.functional:
			if not held_weapons.has(item.holder_id): held_weapons[item.holder_id] = []
			held_weapons[item.holder_id].append(item)
		elif item.kind == "STOCK" and item.available > 0:
			if not held_rounds.has(item.holder_id): held_rounds[item.holder_id] = {}
			held_rounds[item.holder_id][item.design_type] = int(held_rounds[item.holder_id].get(item.design_type,0))+int(item.available)
	for person in people:
		var reason: String = reasons[person.id]
		if reason.is_empty():
			var armed := false
			for weapon in held_weapons.get(person.id,[]):
				if weapon.loaded_rounds > 0 or int(held_rounds.get(person.id,{}).get(weapon.ammo_type,0)) > 0: armed = true
				if armed: break
			if not armed: reason = "No functional carried weapon with a matching available round."
		for row in objectives.values():
			if person.position.distance_to(row.position) > RADIUS+EPS: continue
			if reason.is_empty():
				if person.owner == _rear().PLAYER:
					if not blue.has(row.id): blue[row.id] = []
					blue[row.id].append(person.id)
				else:
					if not red.has(row.id): red[row.id] = []
					red[row.id].append(person.id)
			else: blockers.append({"objective":row.id,"person":person.id,"position":person.position,"holder":person.holder_id,"reason":reason})
	var changed := false
	for row in objectives.values():
		var present_blue: Array = blue.get(row.id,[])
		var present_red: Array = red.get(row.id,[])
		var present_blockers: Array = []
		for blocker in blockers:
			if blocker.objective == row.id: present_blockers.append(blocker)
		if row.blue != present_blue or row.red != present_red or row.blockers != present_blockers: changed = true
		row.blue = present_blue
		row.red = present_red
		row.blockers = present_blockers
	return changed
