extends RefCounted
## Two declared opening legs; transport, fuel, crews and goods retain their owners.
const SUPPLY_STOP := "blue-delivery"
const SUPPORT_STOP := "observation-central"
const AMMO_TARGET := 180
var _rear_ref: WeakRef
var _points: Dictionary
var missions: Dictionary = {}

func _init(rear: RefCounted, points: Dictionary) -> void:
	_rear_ref = weakref(rear)
	_points = points

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func _completed_manifest(id: String) -> String:
	var rear := _rear()
	var receipt: String = str(rear.dispatch.military_hulls.get(id,""))
	var manifest: Dictionary = rear.dispatch.manifests.get(receipt,{})
	if manifest.get("hull","") != id or manifest.get("mode","") != "Fleet Transfer" or manifest.get("state","") != "Complete" or rear.dispatch.incoming_hulls.has(id): return ""
	return receipt

func _receipt(id: String, hull: Dictionary) -> String:
	if hull.get("kind","") != "CARRIER" or hull.get("owner","") != _rear().PLAYER or hull.get("design_type","") != "T04" or hull.get("fleet_domain","") != "Military": return ""
	return _completed_manifest(id)

func _payload(row: Dictionary) -> Dictionary:
	return {"hull":row.hull,"parent":row.parent,"stop":row.stop,"outbound":row.outbound.duplicate(),"fallback":row.fallback.duplicate()}

func payloads(company_id: String) -> Dictionary:
	var rear := _rear()
	var result: Dictionary = {}
	var ids: Array = rear.military.vehicles.keys()
	ids.sort()
	for id in ids:
		# Starting receipt labels do not resolve to manifests. Avoid inspecting their
		# hull/crew/stock snapshots on every otherwise unchanged opening decision.
		if _completed_manifest(id).is_empty(): continue
		var hull: Dictionary = rear.ledger.inspect_entity(id,{},false)
		var receipt := _receipt(id,hull)
		if receipt.is_empty(): continue
		var parent: String = str(rear.military.vehicles[id].parent)
		if not missions.has(id):
			var outbound: Array = _points["blue-delivery-route"].duplicate()
			var fallback := outbound.duplicate()
			fallback.reverse()
			missions[id] = {"hull":id,"parent":parent,"company":company_id,"intent":"","source_manifest":receipt,"stop":SUPPLY_STOP,"state":"Awaiting deployment intent","blocker":"","transport_job":"","phase":"Supply","outbound":outbound,"fallback":fallback}
		var row: Dictionary = missions[id]
		var platoon: Dictionary = rear.military.platoons.get(parent,{})
		if row.parent != parent or platoon.get("company","") != company_id or platoon.get("owner",rear.PLAYER) != rear.PLAYER:
			row.blocker = "Deployment needs its existing own platoon parent; no automatic reparenting."
			continue
		if row.phase == "Supply" and row.state == "Holding for ammunition" and int(hull.ammunition.get("E26",0)) >= AMMO_TARGET and not rear.military.hull_committed(id) and not rear.forward_supply.hull_committed(id):
			var stop: Dictionary = rear.ledger.inspect_entity(SUPPLY_STOP,{},false)
			var support: Dictionary = rear.ledger.inspect_entity(SUPPORT_STOP,{},false)
			if hull.holder_id == SUPPLY_STOP and hull.position == stop.get("position",Vector2.INF) and support.get("kind","") == "PLACE":
				row.phase = "Support"
				row.stop = SUPPORT_STOP
				row.outbound = [stop.position,Vector2(3000,2300),Vector2(3000,3000),support.position]
				row.fallback = row.outbound.duplicate()
				row.fallback.reverse()
				row.intent = ""
				row.transport_job = ""
				row.state = "Awaiting support intent"
				row.blocker = ""
		result[id] = _payload(row)
	return result

func _parent_error(row: Dictionary) -> String:
	var military: RefCounted = _rear().military
	var platoon: Dictionary = military.platoons.get(row.parent,{})
	if not military.vehicles.has(row.hull) or military.vehicles[row.hull].parent != row.parent or platoon.get("company","") != row.company or platoon.get("owner",_rear().PLAYER) != _rear().PLAYER:
		return "Deployment needs its existing own platoon parent; no automatic reparenting."
	return ""

func _acknowledged(row: Dictionary) -> Dictionary:
	if not _parent_error(row).is_empty(): return {}
	var intent: Dictionary = _rear().orders.intents.get(row.parent,{})
	if intent.get("state","") != "Acknowledged": return {}
	var named: Dictionary = intent.get("constraints",{}).get("vehicle_deployments",{})
	if named.get(row.hull,{}) != _payload(row): return {}
	return intent

func request(hull_id: String, parent_id: String, intent_id: String, stop_id: String, outbound_points: Array, fallback_points: Array) -> Dictionary:
	if not missions.has(hull_id): return {"ok":false,"message":"No completed named transfer has a deployment descriptor."}
	var row: Dictionary = missions[hull_id]
	if not row.intent.is_empty() or not row.transport_job.is_empty(): return {"ok":false,"message":"This named deployment phase is already admitted."}
	if parent_id != row.parent or stop_id != row.stop or outbound_points != row.outbound or fallback_points != row.fallback: return {"ok":false,"message":"Deployment must match the declared actual-parent route and stop."}
	var intent := _acknowledged(row)
	if intent.get("id","") != intent_id or intent_id.is_empty(): return {"ok":false,"message":"The actual attached parent must acknowledge this named deployment first."}
	var rear := _rear()
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id,{},false)
	if _receipt(hull_id,hull) != row.source_manifest or not rear.military.vehicles.has(hull_id) or rear.military.vehicles[hull_id].parent != parent_id: return {"ok":false,"message":"The same completed military transfer and attachment must still exist."}
	var mission: Dictionary = rear.military.set_vehicle_mission(hull_id,{"E26":AMMO_TARGET},float(rear.military.vehicles[hull_id].route_fuel))
	if not mission.ok: return mission
	row.intent = intent_id
	row.state = "Waiting for deployment readiness"
	return {"ok":true,"message":"Named acknowledged deployment retains the same hull, crew and real transport owner."}

func _ready_error(row: Dictionary, hull: Dictionary) -> String:
	var rear := _rear()
	if _receipt(row.hull,hull) != row.source_manifest or not rear.military.vehicles.has(row.hull) or rear.military.vehicles[row.hull].parent != row.parent: return "The same completed transfer and actual parent attachment are required."
	var origin := "hq-berth" if row.phase == "Supply" else SUPPLY_STOP
	var place: Dictionary = rear.ledger.inspect_entity(origin,{},false)
	if hull.holder_id != origin or hull.position != place.get("position",Vector2.INF): return "The same stopped hull must remain at its declared physical origin."
	var crew: Dictionary = {}
	for station in ["Driver","Gunner","Commander"]:
		var person: String = rear.military._living_crew_id(hull,station)
		if person.is_empty() or crew.has(person): return "Three distinct living qualified P08 crew must occupy Driver, Gunner and Commander."
		crew[person] = true
	if rear.military.hull_committed(row.hull) or rear.forward_supply.hull_committed(row.hull) or rear.hq._target_busy(row.hull): return "Transport or physical supply handling still owns this hull."
	var movement: Dictionary = rear.military.vehicle_capability(row.hull,"Movement")
	if not movement.ok: return str(movement.message)
	if row.phase == "Support" and int(hull.ammunition.get("E26",0)) < AMMO_TARGET: return "Hold at the supply stop until 180 actual E26 rounds occupy the rack."
	return ""

func tick() -> bool:
	var rear := _rear()
	var changed := false
	for row in missions.values():
		if not row.transport_job.is_empty():
			var job: Dictionary = rear.military.troop_transport.jobs.get(row.transport_job,{})
			var arriving_hull: Dictionary = rear.ledger.inspect_entity(row.hull,{},false)
			var stop: Dictionary = rear.ledger.inspect_entity(row.stop,{},false)
			if job.get("state","") == "Complete":
				if arriving_hull.get("holder_id","") == row.stop and arriving_hull.get("position",Vector2.INF) == stop.get("position",Vector2.INF):
					var state := "Holding for ammunition" if row.phase == "Supply" else "Support position reached"
					changed = row.state != state or changed
					row.state = state
					row.blocker = "Waiting for 180 actual E26 at this stop." if row.phase == "Supply" else "Stopped support position; firing requires a suitable current delivered contact."
				else:
					row.state = "Not at deployment stop"
					row.blocker = "Completed transport record is not current physical arrival."
			else:
				row.state = str(job.get("state","Missing transport job"))
				row.blocker = str(job.get("blocker",""))
			continue
		var parent_error := _parent_error(row)
		if not parent_error.is_empty(): row.blocker = parent_error; continue
		var intent := _acknowledged(row)
		if intent.is_empty():
			row.blocker = "Waiting for the named deployment at the acknowledged actual parent."
			continue
		if row.intent.is_empty():
			var accepted := request(row.hull,row.parent,str(intent.id),row.stop,row.outbound,row.fallback)
			if not accepted.ok: row.blocker = str(accepted.message); continue
			changed = true
		# A revised command must finish its normal acknowledgement before admission.
		row.intent = intent.id
		var hull: Dictionary = rear.ledger.inspect_entity(row.hull,{},false)
		var error := _ready_error(row,hull)
		if not error.is_empty(): row.blocker = error; continue
		var requested: Dictionary = rear.military.request_reposition(row.hull,row.stop,row.outbound,row.fallback)
		if not requested.ok: row.blocker = str(requested.message); continue
		row.transport_job = requested.id
		row.state = "Outbound"
		row.blocker = ""
		changed = true
	return changed

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in missions.values():
		result.append({"hull":row.hull,"parent":row.parent,"intent":row.intent,"source_manifest":row.source_manifest,"stop":row.stop,"state":row.state,"blocker":row.blocker,"transport_job":row.transport_job})
	return result
