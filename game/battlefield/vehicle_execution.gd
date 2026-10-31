extends RefCounted
## Stationary mounted fire from current delivered parent contacts, on the rear clock.
const EPS := 0.000001
var _rear_ref: WeakRef
var next_decision := 0.0
var status: Dictionary = {}
var reported: Dictionary = {}

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	next_decision = rear.time

func next_boundary() -> float:
	return next_decision

func settle() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if rear.time+EPS < next_decision: return false
	next_decision = rear.time+1.0
	var changed := false
	for id in rear.military.vehicles:
		var hull: Dictionary = rear.ledger.inspect_entity(id)
		if hull.get("owner","") != rear.PLAYER or hull.get("design_type","") not in ["T03","T04"]: continue
		changed = _execute(id,hull) or changed
	return changed

func _execute(id: String, hull: Dictionary) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var parent: String = str(rear.military.vehicles[id].parent)
	if rear.military.hull_committed(id) or rear.forward_supply.hull_committed(id) or not str(hull.get("towing","")).is_empty():
		status[id] = "Waiting for a stopped hull free of transport and local supply work."
		return false
	var capability: Dictionary = rear.military.vehicle_capability(id,"Fire")
	if not capability.ok or rear.military.vehicle_readiness(id) <= 0.0:
		status[id] = str(capability.message) if not capability.ok else "Actual vehicle readiness unavailable."
		var kind := "Low Supply" if str(status[id]).contains("rack is empty") else "Lost Capability"
		return _report(id,parent,kind,str(status[id]))
	for key in reported.keys():
		if str(key).begins_with(id+":"): reported.erase(key)
	var weapon := "MG" if hull.design_type == "T03" else "Autocannon"
	var spec: Dictionary = rear.vehicle_combat.MOUNTS[hull.design_type][weapon]
	var existing: Dictionary = rear.vehicle_combat.mounts.get(id,{})
	var contacts: Array[Dictionary] = []
	for target_id in rear.orders.contacts.get(parent,{}):
		var known: Dictionary = rear.orders.contact(parent,target_id)
		if not known.get("current",false) or not known.position.is_finite(): continue
		if known.get("class","") in ["Resource","Route Hub","Observation","Enemy HQ"]: continue
		# Class is reported information. Do not spend MG rounds on armour or
		# assume an exposed rear on a tank without reported facing/planned flank.
		if known.get("class","") == "T05" or (weapon == "MG" and known.get("class","") == "T04"): continue
		if hull.position.distance_to(known.position) > float(spec.range)+EPS: continue
		contacts.append(known)
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# Keep an acquired suitable target ahead of a previously refused one;
		# otherwise nearest blocked contacts can reset aim on every decision.
		if a.target == b.target: return false
		if a.target == existing.get("target",""): return true
		if b.target == existing.get("target",""): return false
		var first: float = hull.position.distance_squared_to(a.position)
		var second: float = hull.position.distance_squared_to(b.position)
		return a.target < b.target if first == second else first < second)
	if contacts.is_empty():
		status[id] = "Waiting for a current compatible contact delivered to the actual parent."
		return false
	if not rear.vehicle_combat.mounts.has(id):
		# Only a previously unused mount starts at the actual hull bearing.
		rear.vehicle_combat._mount(id).angle = float(hull.get("facing_degrees",0.0))
	var row: Dictionary = rear.vehicle_combat.mounts[id]
	# VehicleCombat records the desired angle immediately and a physical turn
	# deadline separately. Do not reuse that desired angle to shorten an
	# unfinished turn when a contact moves or a different contact is selected.
	if rear.time+EPS < float(row.aim_due):
		status[id] = "Finishing the actual mounted turn."
		_wake(float(row.aim_due))
		return false
	var changed := false
	for contact in contacts:
		var angle: float = rad_to_deg((contact.position-hull.position).angle())
		if row.target != contact.target or absf(wrapf(angle-float(row.angle),-180.0,180.0)) > 5.0:
			var aim: Dictionary = rear.vehicle_combat.aim(id,contact.target)
			status[id] = "Aiming at the delivered contact." if aim.ok else str(aim.blocked_reason)
			if not aim.ok: continue
			changed = true
			_wake(float(aim.due))
			if rear.time+EPS < float(aim.due): return true
		var check: Dictionary = rear.vehicle_combat.inspect_fire(id,contact.target,weapon)
		if check.ok:
			var fired: Dictionary = rear.vehicle_combat.fire(id,contact.target,weapon)
			status[id] = "Fired "+weapon+" using actual local rack ammunition." if fired.ok else str(fired.blocked_reason)
			_wake_mount(row,weapon)
			return bool(fired.ok) or changed
		status[id] = str(check.blocked_reason)
		if int(row.loaded.get(weapon,int(spec.capacity))) == 0 and not row.reload_due.has(weapon):
			var reload: Dictionary = rear.vehicle_combat.request_reload(id,weapon)
			if reload.ok:
				status[id] = "Reloading the actual mounted magazine from this hull's rack."
				_wake(float(reload.due))
				return true
		_wake_mount(row,weapon)
		if rear.time+EPS < float(row.aim_due) or row.reload_due.has(weapon) or rear.time+EPS < float(row.next_fire.get(weapon,0.0)): return changed
	return changed

func _wake(at: float) -> void:
	if at > _rear_ref.get_ref().time+EPS: next_decision = minf(next_decision,at)

func _wake_mount(row: Dictionary, weapon: String) -> void:
	_wake(float(row.aim_due))
	_wake(float(row.next_fire.get(weapon,INF)))
	_wake(float(row.reload_due.get(weapon,INF)))

func _report(id: String, parent: String, kind: String, detail: String) -> bool:
	var key := id+":"+kind+":"+detail
	if reported.has(key): return false
	var result: Dictionary = _rear_ref.get_ref().orders.report(parent,kind,id+": "+detail,true)
	if result.ok: reported[key] = result.id
	return bool(result.ok)

func snapshot() -> Dictionary:
	return {"status":status.duplicate(true)}
