extends RefCounted
## Named APC deployment and recurring supply; physical work retains its owners.
const SUPPLY_STOP := "blue-delivery"
const SUPPORT_STOP := "observation-central"
const AMMO_TARGET := 180
var _rear_ref: WeakRef
var _supply_ref: WeakRef
var _points: Dictionary
var missions: Dictionary = {}

func _init(rear: RefCounted, points: Dictionary, supply_owner: RefCounted = null) -> void:
	_rear_ref = weakref(rear)
	_points = points
	if supply_owner != null: _supply_ref = weakref(supply_owner)

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func _supply_owner() -> RefCounted:
	return _supply_ref.get_ref() if _supply_ref != null else null

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
	return {"hull":row.hull,"parent":row.parent,"origin":row.origin,"phase":row.phase,"cycle":row.phase_cycle,"stop":row.stop,"outbound":row.outbound.duplicate(),"fallback":row.fallback.duplicate()}

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
			missions[id] = {
				"hull":id,"parent":parent,"company":company_id,"intent":"","source_manifest":receipt,
				"origin":"hq-berth","stop":SUPPLY_STOP,"state":"Awaiting deployment intent","blocker":"",
				"transport_job":"","phase":"Supply","outbound":outbound,"fallback":fallback,"authority":{},
				"cycle":"","phase_cycle":"","released_cycle":"","handoff_error":"","cycle_count":0,"completed_cycles":0,
				"refill_seen_cycle":"","refill_seen_at":-INF,
				"active_need":false,"reported_need":false,"registered_need":false,"refilled":false,"support_reached":false,
				"last_attempt_time":-INF,"last_attempt_key":[],"last_ready_key":[],"tail_ready":false,
				"support_outbound":[],"support_fallback":[],"repeat_state":"Initial allocation"}
		var row: Dictionary = missions[id]
		var platoon: Dictionary = rear.military.platoons.get(parent,{})
		if row.parent != parent or platoon.get("company","") != company_id or platoon.get("owner",rear.PLAYER) != rear.PLAYER:
			row.blocker = "Deployment needs its existing own platoon parent; no automatic reparenting."
			continue
		var command_error := _command_error(row)
		if not command_error.is_empty(): row.blocker = command_error; continue
		if row.phase in ["Supply","Replenishment"] and row.state == "Holding for ammunition": _prepare_support(row,hull)
		elif row.phase == "Support" and row.state == "Support position reached" and row.active_need: _prepare_return(row,hull)
		result[id] = _payload(row)
	return result

func _command_error(row: Dictionary) -> String:
	# A new phase may replace our last acknowledged descriptor, never an unrelated
	# current parent command. Pending delivery of the new named phase is expected.
	if row.authority.is_empty(): return ""
	var intent: Dictionary = _rear().orders.intents.get(row.parent,{})
	if intent.get("state","") not in ["Acknowledged","In transit","Acknowledgement pending"]: return "Actual parent command is unavailable or paused; deployment needs reassessment."
	var named: Dictionary = intent.get("constraints",{}).get("vehicle_deployments",{}).get(row.hull,{})
	if named != _payload(row) and named != row.authority: return "Actual parent command no longer names this deployment; reassessment is required."
	return ""

func _at(row: Dictionary, hull: Dictionary, stop_id: String) -> bool:
	var stop: Dictionary = _rear().ledger.inspect_entity(stop_id,{},false)
	return hull.get("health",0) > 0 and _receipt(row.hull,hull) == row.source_manifest and stop.get("kind","") == "PLACE" and hull.get("holder_id","") == stop_id and hull.get("position",Vector2.INF) == stop.position

func _completed_at(row: Dictionary, hull: Dictionary) -> bool:
	var job: Dictionary = _rear().military.troop_transport.jobs.get(row.transport_job,{})
	return job.get("hull","") == row.hull and job.get("kind","") == "Reposition" and job.get("state","") == "Complete" and job.get("dismount_place","") == row.stop and _at(row,hull,row.stop)

func _free(row: Dictionary) -> bool:
	var rear := _rear()
	return not rear.military.hull_committed(row.hull) and not rear.forward_supply.hull_committed(row.hull) and not rear.hq._target_busy(row.hull)

func _phase(row: Dictionary, phase: String, origin: String, stop: String, outbound: Array, fallback: Array, state: String) -> void:
	# Call only at a verified completed physical leg, never at a near-marker pose.
	row.phase = phase
	# A new need does not rewrite the still-owned Support command. Publish its
	# cycle on the next physical phase boundary, when a fresh descriptor is due.
	row.phase_cycle = row.cycle
	row.origin = origin
	row.stop = stop
	row.outbound = outbound.duplicate()
	row.fallback = fallback.duplicate()
	row.intent = ""
	row.transport_job = ""
	row.state = state
	row.blocker = ""
	row.handoff_error = ""
	row.last_attempt_time = -INF
	row.last_attempt_key = []
	row.last_ready_key = []
	row.tail_ready = false

func _prepare_support(row: Dictionary, hull: Dictionary) -> void:
	if not _completed_at(row,hull) or not _free(row): return
	if row.phase == "Replenishment":
		# Receipt is recorded at the physical settle boundary. A later shot may
		# leave179 before this strategic tick; that must not erase actual receipt
		# or fabricate current readiness. Departure still requires180 afresh.
		if row.refill_seen_cycle != row.cycle: row.blocker = "Waiting to observe this cycle's actual 180-round receipt and clear couriers."; return
		row.refilled = true
		row.repeat_state = "Refilled; awaiting support reassessment"
	elif int(hull.ammunition.get("E26",0)) < AMMO_TARGET: return
	var stop: Dictionary = _rear().ledger.inspect_entity(SUPPLY_STOP,{},false)
	var support: Dictionary = _rear().ledger.inspect_entity(SUPPORT_STOP,{},false)
	if support.get("kind","") != "PLACE": row.blocker = "Declared support destination is unavailable."; return
	# The established route is retained as a proposal; transport reassesses its
	# current geometry, danger and fuel and the actual parent must acknowledge it.
	if row.support_outbound.is_empty():
		var authored: Array = _points.get("blue-support-route",[])
		row.support_outbound = authored.duplicate() if not authored.is_empty() else [stop.position,Vector2(3000,2300),Vector2(3000,3000),support.position]
		row.support_fallback = row.support_outbound.duplicate()
		row.support_fallback.reverse()
	_phase(row,"Support",SUPPLY_STOP,SUPPORT_STOP,row.support_outbound,row.support_fallback,"Awaiting support intent")

func _prepare_return(row: Dictionary, hull: Dictionary) -> void:
	if not row.reported_need or not row.registered_need or not _completed_at(row,hull) or not _free(row): return
	if row.support_fallback.is_empty(): row.blocker = "No established return route to the supply rendezvous."; return
	_phase(row,"Replenishment",SUPPORT_STOP,SUPPLY_STOP,row.support_fallback,row.support_outbound,"Awaiting replenishment return intent")
	row.repeat_state = "Awaiting acknowledged return to supply"

func _refill_error(row: Dictionary, hull: Dictionary) -> String:
	var owner := _supply_owner()
	if owner == null: return "Recurring rack supply owner is unavailable."
	var supply: Dictionary = owner.rack_replenishment_status(row.hull)
	if supply.get("hull","") != row.hull or supply.get("cycle","") != row.cycle or supply.get("stop","") != SUPPLY_STOP or int(supply.get("target",0)) != AMMO_TARGET: return "Waiting for this named APC replenishment cycle, rendezvous and target."
	if int(hull.ammunition.get("E26",0)) < AMMO_TARGET: return "Hold at the supply stop until 180 actual E26 rounds occupy the rack."
	if supply.get("state","") != "Complete" or int(supply.get("committed",0)) != 0:
		var blocker: String = str(supply.get("blocker",""))
		return blocker if not blocker.is_empty() else "Waiting for this physical refill and its couriers to finish."
	return ""

func _readiness_key(row: Dictionary, hull: Dictionary, intent: Dictionary) -> Array:
	var rear := _rear()
	# Suppress repeated denied route calculations, not physical validation or
	# route results. Unkeyed/time-aging knowledge still retries on normal ticks.
	return [row.phase_cycle,intent.id,rear.combat.world.get_instance_id(),rear.combat.world.revision,
		hull.holder_id,hull.position,hull.fuel,hull.health,hull.get("damage_immobilized",false),
		hull.get("towing",""),hull.get("towed_by",""),hull.ammunition.get("E26",0),
		hull.crew_by_station.duplicate(),hull.passengers.duplicate(),rear.military.vehicles[row.hull].route_fuel]

func settle_ready_departures() -> bool:
	# The caller owns the running/paused clock boundary. This tail consumes only
	# an existing acknowledged recurring Support phase: no new policy or demand.
	var changed := false
	for row in missions.values():
		if row.phase == "Replenishment" and row.active_need and row.refill_seen_cycle != row.cycle:
			var arrived: Dictionary = _rear().ledger.inspect_entity(row.hull,{},false)
			if _parent_error(row).is_empty() and _completed_at(row,arrived) and _free(row) and _refill_error(row,arrived).is_empty():
				row.refill_seen_cycle = row.cycle
				row.refill_seen_at = _rear().time
				changed = true
			row.tail_ready = false
			continue
		if row.phase != "Support" or not row.active_need or row.origin != SUPPLY_STOP or not row.transport_job.is_empty():
			row.tail_ready = false
			continue
		var intent := _acknowledged(row)
		if intent.is_empty() or not _command_error(row).is_empty(): row.tail_ready = false; continue
		var hull: Dictionary = _rear().ledger.inspect_entity(row.hull,{},false)
		# Partial stock and any physical courier commitment remain incomplete.
		if int(hull.get("ammunition",{}).get("E26",0)) < AMMO_TARGET or not _free(row): row.tail_ready = false; continue
		changed = _try_admit(row,hull,intent,true) or changed
	return changed

func _try_admit(row: Dictionary, hull: Dictionary, intent: Dictionary, tail_only: bool = false) -> bool:
	var rear := _rear()
	if not rear.vehicle_departures_allowed:
		row.blocker = "Paused; awaiting permission to depart on the running clock."
		row.tail_ready = false
		row.last_attempt_time = -INF
		row.last_attempt_key = []
		return false
	var error := ""
	var key: Array = []
	if tail_only:
		error = _ready_error(row,hull)
		if not error.is_empty(): row.tail_ready = false; row.blocker = error; return false
		key = _readiness_key(row,hull,intent)
		var repeated_ready: bool = row.tail_ready and row.last_ready_key == key
		row.tail_ready = true
		row.last_ready_key = key
		if (row.last_attempt_time == rear.time and row.last_attempt_key == key) or repeated_ready: return false
	var changed := false
	if row.intent.is_empty():
		var accepted := request(row.hull,row.parent,str(intent.id),row.stop,row.outbound,row.fallback)
		if not accepted.ok: row.blocker = str(accepted.message); return false
		changed = true
	row.intent = intent.id
	if not tail_only:
		error = _ready_error(row,hull)
		if not error.is_empty(): row.tail_ready = false; row.blocker = error; return changed
		key = _readiness_key(row,hull,intent)
		if row.last_attempt_time == rear.time and row.last_attempt_key == key: return changed
	row.last_attempt_time = rear.time
	row.last_attempt_key = key
	row.last_ready_key = key
	row.tail_ready = true
	# Legacy reposition still synchronously reassesses real route/fallback,
	# danger and25% fuel reserve. No cached route result authorizes this move.
	var requested: Dictionary = rear.military.request_reposition(row.hull,row.stop,row.outbound,row.fallback)
	if not requested.ok: row.blocker = str(requested.message); return changed
	row.transport_job = requested.id
	if row.phase == "Support" and row.active_need and not row.cycle.is_empty():
		# Keep the real job identity on an unexpected release denial.
		var owner := _supply_owner()
		var released: Dictionary = owner.release_rack_replenishment(row.hull,row.cycle) if owner != null else {"ok":false,"message":"Recurring rack supply owner is unavailable."}
		if not released.get("ok",false):
			var stopped: Dictionary = rear.military.interrupt_troop_trip(row.transport_job)
			row.handoff_error = str(released.get("message","The admitted deployment could not release its named refill cycle."))
			if not stopped.get("ok",false): row.handoff_error += " Transport stop refused: "+str(stopped.get("message",""))
			row.state = "Refill handoff blocked"
			row.repeat_state = row.state
			row.blocker = row.handoff_error
			return true
		row.released_cycle = row.cycle
	row.state = "Outbound"
	if row.active_need: row.repeat_state = "Returning to supply" if row.phase == "Replenishment" else "Redeploying to support"
	row.blocker = ""
	return true

func _need(row: Dictionary, hull: Dictionary) -> void:
	var owner := _supply_owner()
	if owner == null or not row.support_reached: return
	var aboard: int = int(hull.get("ammunition",{}).get("E26",0))
	if not row.active_need:
		var needs: Dictionary = _rear().military.vehicle_supply_needs(row.hull,hull)
		var ammunition: Dictionary = needs.get("ammunition",{}).get("E26",{})
		if row.phase != "Support" or row.state != "Support position reached" or not ammunition.get("urgent",false): return
		row.cycle_count += 1
		row.cycle = "%s:%s:resupply-%04d" % [row.source_manifest,row.hull,row.cycle_count]
		row.active_need = true
		row.reported_need = false
		row.registered_need = false
		row.refilled = false
		row.repeat_state = "Urgent ammunition need"
	if not row.reported_need:
		var report: Dictionary = _rear().orders.report(row.hull,"Low Supply","APC %s has %d/%d E26 rounds; urgent resupply %s at %s." % [row.hull,aboard,AMMO_TARGET,row.cycle,SUPPLY_STOP],true)
		row.reported_need = report.get("ok",false)
	if not row.registered_need:
		var requested: Dictionary = owner.request_rack_replenishment(row.hull,row.cycle,AMMO_TARGET)
		row.registered_need = requested.get("ok",false)
		if not row.registered_need: row.blocker = str(requested.get("message","Named rack replenishment is unavailable."))

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
	row.authority = _payload(row)
	row.state = "Waiting for deployment readiness"
	return {"ok":true,"message":"Named acknowledged deployment retains the same hull, crew and real transport owner."}

func _ready_error(row: Dictionary, hull: Dictionary) -> String:
	var rear := _rear()
	if _receipt(row.hull,hull) != row.source_manifest or not rear.military.vehicles.has(row.hull) or rear.military.vehicles[row.hull].parent != row.parent: return "The same completed transfer and actual parent attachment are required."
	var origin: String = row.origin
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
	if row.phase == "Support" and row.active_need:
		var refill_error := _refill_error(row,hull)
		if not refill_error.is_empty(): return refill_error
	return ""

func tick() -> bool:
	var rear := _rear()
	var changed := false
	for row in missions.values():
		var parent_error := _parent_error(row)
		if not parent_error.is_empty(): row.blocker = parent_error; continue
		var hull: Dictionary = rear.ledger.inspect_entity(row.hull,{},false)
		if _receipt(row.hull,hull) != row.source_manifest or hull.get("health",0) <= 0:
			row.blocker = "The same surviving completed transfer must remain available."
			continue
		if not row.transport_job.is_empty():
			var job: Dictionary = rear.military.troop_transport.jobs.get(row.transport_job,{})
			if not row.handoff_error.is_empty():
				row.state = "Refill handoff blocked"
				row.blocker = row.handoff_error
				continue
			if job.get("state","") == "Complete":
				if _completed_at(row,hull):
					var state := "Support position reached" if row.phase == "Support" else "Holding for ammunition"
					changed = row.state != state or changed
					row.state = state
					row.blocker = "Stopped support position; firing requires a suitable current delivered contact." if row.phase == "Support" else "Waiting for 180 actual E26 at this stop."
					if row.phase == "Support":
						row.support_reached = true
						if row.active_need and row.refilled and row.released_cycle == row.cycle:
							row.active_need = false
							row.completed_cycles = row.cycle_count
							row.repeat_state = "Support replenished"
							changed = true
					var previous_cycle: int = row.cycle_count
					_need(row,hull)
					changed = row.cycle_count != previous_cycle or changed
					if row.phase == "Support" and row.active_need and row.registered_need:
						row.blocker = "Urgent E26 resupply requested; awaiting a feasible acknowledged return." if _free(row) else "Urgent E26 resupply; physical handling still owns this hull."
					if row.phase == "Replenishment":
						row.repeat_state = "Waiting for physical refill"
						var owner := _supply_owner()
						if owner != null:
							var supply: Dictionary = owner.rack_replenishment_status(row.hull)
							if supply.get("cycle","") == row.cycle: row.blocker = str(supply.get("blocker","Waiting for this physical refill and its couriers to finish."))
					var arrived_command_error := _command_error(row)
					if not arrived_command_error.is_empty(): row.blocker = arrived_command_error
				else:
					row.state = "Not at deployment stop"
					row.blocker = "Completed transport record is not current physical arrival."
			else:
				row.state = str(job.get("state","Missing transport job"))
				row.blocker = str(job.get("blocker",""))
			continue
		var command_error := _command_error(row)
		if not command_error.is_empty(): row.blocker = command_error; continue
		var intent := _acknowledged(row)
		if intent.is_empty():
			row.blocker = "Waiting for the named deployment at the acknowledged actual parent."
			continue
		changed = _try_admit(row,hull,intent) or changed
	return changed

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in missions.values():
		# Ammunition/fuel needs come from Organization.vehicle_supply_needs; this
		# view reports only our lifecycle, never a second supply-accounting rule.
		result.append({"hull":row.hull,"parent":row.parent,"intent":row.intent,"source_manifest":row.source_manifest,
			"phase":row.phase,"origin":row.origin,"stop":row.stop,"supply_stop":SUPPLY_STOP,"state":row.state,
			"blocker":row.blocker,"transport_job":row.transport_job,"cycle":row.cycle,"phase_cycle":row.phase_cycle,
			"released_cycle":row.released_cycle,"cycle_count":row.cycle_count,"completed_cycles":row.completed_cycles,
			"refill_seen_cycle":row.refill_seen_cycle,"refill_seen_at":row.refill_seen_at,
			"active_need":row.active_need,"repeat_state":row.repeat_state})
	return result
