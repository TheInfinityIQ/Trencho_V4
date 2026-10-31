extends RefCounted
const Resupply = preload("res://game/battlefield/opening_resupply.gd")
const Deployment = preload("res://game/battlefield/vehicle_deployment.gd")
const ResourceOperations = preload("res://game/battlefield/resource_operations.gd")
## Authored deployment followed by bounded, knowledge-based resource proposals.
var _rear_ref: WeakRef
var armies: Dictionary
var points: Dictionary
var phases: Dictionary = {}
var reserve_active := false
var trips: Dictionary = {}
var status: Dictionary = {}
var repositioned: Dictionary = {}
var resupply: RefCounted
var deployments: RefCounted
var resource_operations: RefCounted
var _resource_reported: Dictionary = {}
var _trip_admission_cursor := 0
var _last_trip_attempt := -INF
var _trip_request_sequence := 0
var _company_order_ids: Dictionary = {}
var _child_orders: Dictionary = {}
var _supply_hull_orders: Dictionary = {}
const LIVE_ORDER_STATES := ["In transit","Acknowledgement pending","Acknowledged"]

func _init(rear: RefCounted, army_data: Dictionary, waypoints: Dictionary) -> void:
	_rear_ref = weakref(rear)
	armies = army_data
	points = waypoints
	resupply = Resupply.new(rear,armies["army-blue"].rifles.slice(0,2),armies["army-blue"].engineer,"blue-delivery")
	deployments = Deployment.new(rear,points,resupply)
	resource_operations = ResourceOperations.new(rear,armies)
	for side in ["blue","red"]:
		var owner: String = "army-"+side
		phases[owner] = "Opening"
		var army: Dictionary = armies[owner]
		if side == "blue": rear.ledger.add_place("blue-supply-rally","Local resupply rally",points["blue-delivery"]+Vector2(0,-10))
		for item in [["guard",army.hq+Vector2(0,60 if side == "blue" else -60)],["support",points[side+"-troop-staging"]],["medical",points[side+"-troop-staging"]]]:
			rear.ledger.add_place(side+"-"+str(item[0])+"-rally","Declared opening rally",item[1])
		for index in 2:
			var at: Vector2 = points[side+"-dismount"]+Vector2(-20,-20*index if side == "blue" else 20*index)
			rear.ledger.add_place(side+"-dismount-%d" % index,"Declared troop dismount",at)
		var hulls: Array = army.hulls
		if side == "blue":
			_add_trip("blue-rifles",hulls[0].id,[army.rifles[0],army.rifles[1]],side,0,false)
			_add_trip("blue-support",hulls[1].id,[army.engineer,army.medical],side,1,false)
		else:
			_add_trip("red-forward",hulls[0].id,[army.rifles[0]],side,0,false)
			_add_trip("red-reserve",hulls[1].id,[army.rifles[1]],side,1,true)

func _rear() -> RefCounted:
	return _rear_ref.get_ref()

func _add_trip(id: String, hull: String, squads: Array, side: String, index: int, reserve: bool) -> void:
	var rear: RefCounted = _rear()
	var actual: Dictionary = rear.ledger.inspect_entity(hull,{},false)
	var destination: String = side+"-dismount-%d" % index
	var route: Array = [actual.position]
	route.append_array(points[side+"-front-route"])
	route.append(rear.ledger.inspect_entity(destination,{},false).position)
	var returning := route.duplicate()
	returning.reverse()
	trips[id] = {"id":id,"hull":hull,"squads":squads,"board":actual.holder_id,"dismount":destination,"outbound":route,"return":returning,"reserve":reserve,"started":false,"admitted_at":-1.0,"dismounted":false,"job":"","request":"","blocker":""}

func tick() -> void:
	var rear: RefCounted = _rear()
	if not reserve_active:
		for id in rear.orders.contacts.get("army-red",{}):
			var contact: Dictionary = rear.orders.contact("army-red",id)
			if contact.get("confidence",0) > 0 and contact.get("observed_strength",0) > 0: reserve_active = true; break
	var enabled := {}
	var available := {}
	for owner in armies:
		var army: Dictionary = armies[owner]
		enabled[owner] = _owns_company_order(army.company,army.root,rear.orders.intents.get(army.company,{})) and rear.ledger.inspect_person_status(army.commander).get("health",0) > 0
		available[owner] = _resource_squads(army)
	resource_operations.tick(armies,available,enabled)
	var observation: Dictionary = resource_operations.observation()
	if not observation.is_empty():
		var report: Dictionary = rear.orders.report(observation.source,"Progress",observation.detail)
		if report.ok: resource_operations.record_observed(observation.key,observation.affiliation)
	for owner in armies:
		var army: Dictionary = armies[owner]
		var side := "blue" if owner == "army-blue" else "red"
		var first := "resource-centre-"+side
		var commander: Dictionary = rear.ledger.inspect_person_status(army.commander)
		if commander.get("health",0) <= 0: status[owner] = "Commander unavailable; received intent continues"; continue
		var operation: Dictionary = resource_operations.proposal(owner)
		if not operation.is_empty(): phases[owner] = str(operation.phase)
		var objective: String = str(operation.get("objective",first))
		var action: String = str(operation.get("action","Seize Objective"))
		var version: String = str(phases[owner])+str(reserve_active if side == "red" else false)
		if not operation.is_empty(): version += str(operation.version)
		var company_intent: Dictionary = rear.orders.intents.get(army.company,{})
		var opening_owned: bool = _owns_company_order(army.company,army.root,company_intent)
		var vehicle_deployments: Dictionary = deployments.payloads(army.company) if opening_owned and owner == rear.PLAYER else {}
		var deployment_versions: Array[String] = []
		for hull_id in vehicle_deployments:
			var payload: Dictionary = vehicle_deployments[hull_id]
			deployment_versions.append(str([hull_id,rear.dispatch.military_hulls[hull_id],payload]))
		if not vehicle_deployments.is_empty(): version += str(deployment_versions)
		if opening_owned and company_intent.get("constraints",{}).get("opening_version","") != version:
			var constraints := {"opening_version":version,"objective":objective}
			if not operation.is_empty(): constraints.resource_operation = operation.duplicate(true)
			if not vehicle_deployments.is_empty(): constraints.vehicle_deployments = vehicle_deployments
			var sent: Dictionary = rear.orders.issue_order(army.root,army.company,action,"Secure the declared resource operation","Continue useful resource operations with actual supply and capability",constraints,"Emergency" if reserve_active and side == "red" else "Normal",str(operation.get("fallback",army.staging)))
			if not sent.ok: status[owner] = sent.message
			else:
				_company_order_ids[army.company] = sent.id
				if not operation.is_empty(): resource_operations.record_issued(owner,str(operation.version),str(sent.id))
			company_intent = rear.orders.intents.get(army.company,{})
		if company_intent.get("state","") != "Acknowledged": continue
		# A denied update cannot authorize new scenario instructions under the old
		# acknowledged parent. The old operation continues until the update arrives.
		if opening_owned and company_intent.get("constraints",{}).get("opening_version","") != version: continue
		for platoon_id in rear.military.companies[army.company].platoons:
			var platoon_intent: Dictionary = _relay_once(army.company,platoon_id,company_intent)
			if platoon_intent.is_empty(): continue
			for squad_id in rear.military.platoons[platoon_id].squads:
				if not opening_owned:
					_relay_once(platoon_id,squad_id,platoon_intent)
					continue
				var desired: Dictionary = _squad_order(owner,squad_id,objective)
				var current: Dictionary = rear.orders.intents.get(squad_id,{})
				if not _may_issue_child(squad_id,str(platoon_intent.id),current): continue
				var key: String = version+str(desired.action)+str(desired.destination)+str(desired.get("supply",""))
				if current.get("constraints",{}).get("opening_key","") == key: continue
				var constraints := {"destination":desired.destination,"fallback_place":desired.fallback,"role":desired.role,"supported_squads":[army.rifles[0],army.rifles[1]],"opening_key":key}
				if not str(desired.get("supply","")).is_empty(): constraints.supply_rendezvous = desired.supply
				var sent: Dictionary = rear.orders.issue_order(platoon_id,squad_id,desired.action,"Perform the assigned opening role","Support the company objective",constraints,"Normal",desired.fallback)
				_remember_child_attempt(squad_id,str(platoon_intent.id),current,sent)
		status[owner] = str(phases[owner])+": "+objective if opening_owned else "Following the current parent operation."
		var resource_blocker: String = resource_operations.blocker(owner)
		if opening_owned and not resource_blocker.is_empty():
			status[owner] += " · "+resource_blocker
			if resource_blocker.begins_with("No feasible") or resource_blocker.begins_with("Resource operation needs"):
				if _resource_reported.get(owner,"") != resource_blocker:
					var reported: Dictionary = rear.orders.report(army.company,"Inability",resource_blocker)
					if reported.ok: _resource_reported[owner] = resource_blocker
	_request_trips()
	_reposition_supply_truck()
	resupply.tick()
	deployments.tick()

func _resource_squads(army: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id in army.rifles.slice(0,2):
		var released := false
		for trip in trips.values():
			if id in trip.squads and trip.dismounted: released = true; break
		if released: result.append(id)
	return result

func settle_vehicle_departures() -> bool:
	return deployments.settle_ready_departures()

func squad_supply_owner() -> RefCounted:
	return resupply

func authorize_supply_transport(proposal: Dictionary, allow_issue: bool) -> Dictionary:
	var rear := _rear()
	var hull_id: String = str(proposal.get("hull",""))
	var descriptor: Dictionary = proposal.get("authority",{})
	var attachment: Dictionary = rear.military.vehicles.get(hull_id,{})
	var squad: Dictionary = rear.military.squads.get(str(descriptor.get("squad","")),{})
	var operation: Dictionary = rear.orders.intents.get(str(descriptor.get("squad","")),{})
	if attachment.is_empty() or squad.is_empty() or squad.get("owner","") != rear.PLAYER or operation.get("state","") != "Acknowledged" or operation.get("id","") != descriptor.get("operation_intent","") or operation.get("parent","") != squad.platoon:
		return {"ok":false,"message":"Awaiting the actual squad parent's current acknowledged operation."}
	if str(proposal.get("parent","")) != str(attachment.parent): return {"ok":false,"message":"The vehicle's actual command parent changed; reassess the journey."}
	var current: Dictionary = rear.orders.intents.get(hull_id,{})
	if not current.is_empty() and (current.get("id","") != _supply_hull_orders.get(hull_id,"") or current.get("state","") not in LIVE_ORDER_STATES):
		return {"ok":false,"message":"The vehicle has another current assignment; collection cannot take it."}
	if not current.is_empty() and current.get("constraints",{}).get("supply_transport",{}) == descriptor:
		return {"ok":true,"hull_intent":current.id,"pending":current.state != "Acknowledged","changed":false,"delay_seconds":maxf(0,float(current.issued_at)+2.0-rear.time),"message":"Existing named vehicle assignment retained."}
	var hold: float = maxf(0,float(current.get("issued_at",-INF))+10.0-rear.time)
	if not allow_issue:
		return {"ok":true,"hull_intent":"","pending":true,"changed":false,"delay_seconds":hold+2.0,"message":"Vehicle parent can consider this collection assignment."}
	var sent: Dictionary = rear.orders.issue_order(str(attachment.parent),hull_id,"Move by Transport","Carry the named Rifle cohort for its current supply journey","Support the acknowledged Rifle operation",{"supply_transport":descriptor},"Normal",str(descriptor.get("pickup","")))
	if sent.get("ok",false):
		_supply_hull_orders[hull_id] = sent.id
		sent.hull_intent = sent.id
		sent.pending = true
		sent.changed = true
		sent.delay_seconds = 2.0
	return sent

func _owns_company_order(company_id: String, root_id: String, current: Dictionary) -> bool:
	if not _company_order_ids.has(company_id):
		if current.is_empty(): return true
		# Attaching to an existing order is not permission to replace it.
		_company_order_ids[company_id] = ""
		return false
	return not str(_company_order_ids[company_id]).is_empty() and current.get("id","") == _company_order_ids[company_id] and current.get("parent","") == root_id and current.get("state","") in LIVE_ORDER_STATES

func _may_issue_child(child_id: String, parent_order_id: String, current: Dictionary) -> bool:
	var current_id: String = str(current.get("id",""))
	var current_state: String = str(current.get("state",""))
	if not _child_orders.has(child_id):
		_child_orders[child_id] = {"source":parent_order_id,"issued":"","basis":current_id,
			"basis_state":current_state,"pending":current.is_empty()}
		return current.is_empty()
	var row: Dictionary = _child_orders[child_id]
	if row.source != parent_order_id:
		# A genuinely new authoritative parent can issue a new child operation.
		row.source = parent_order_id
		row.issued = ""
		row.basis = current_id
		row.basis_state = current_state
		row.pending = true
	if row.pending:
		if current_id != row.basis or (not current.is_empty() and current_state not in LIVE_ORDER_STATES and current_state != row.basis_state):
			row.pending = false
			return false
		return true
	return not str(row.issued).is_empty() and current_id == row.issued and current_state in LIVE_ORDER_STATES

func _remember_child_attempt(child_id: String, source: String, current: Dictionary, result: Dictionary) -> void:
	var row: Dictionary = _child_orders[child_id]
	row.source = source
	row.pending = not result.ok
	row.basis = str(current.get("id",""))
	row.basis_state = str(current.get("state",""))
	if result.ok: row.issued = result.id

func _relay_once(parent_id: String, child_id: String, parent_order: Dictionary) -> Dictionary:
	var current: Dictionary = _rear().orders.intents.get(child_id,{})
	var remembered: Dictionary = _child_orders.get(child_id,{})
	if not remembered.is_empty() and remembered.source == parent_order.id and not remembered.pending and remembered.issued == current.get("id",""):
		return current if current.get("state","") == "Acknowledged" else {}
	if not _may_issue_child(child_id,str(parent_order.id),current): return {}
	var sent: Dictionary = _rear().orders.relay_order(parent_id,child_id)
	_remember_child_attempt(child_id,str(parent_order.id),current,sent)
	return {}

func _squad_order(owner: String, id: String, objective: String) -> Dictionary:
	var army: Dictionary = armies[owner]
	var side := "blue" if owner == "army-blue" else "red"
	var role := "Medical" if id == army.medical else ("Support" if id == army.engineer else "Rifle")
	if id == army.rifles[2]: return {"action":"Defend HQ","destination":side+"-guard-rally","fallback":side+"-guard-rally","role":"Guard"}
	if side == "red" and id == army.rifles[1] and not reserve_active: return {"action":"Hold Area","destination":_rear().ledger.inspect_entity(army.hulls[1].id,{},false).holder_id,"fallback":army.staging,"role":"Reserve"}
	if side == "red" and id in [army.engineer,army.medical]: return {"action":"Hold Area","destination":side+"-"+("medical" if role == "Medical" else "support")+"-rally","fallback":army.staging,"role":role}
	var fallback: String = army.staging
	for trip in trips.values():
		if id not in trip.squads: continue
		fallback = trip.dismount
		if not trip.dismounted: return {"action":"Move by Transport","destination":trip.dismount,"fallback":army.staging,"role":role}
	if side == "blue":
		fallback = "blue-supply-rally"
		if id == army.engineer: return {"action":"Hold Area","destination":"blue-delivery","fallback":fallback,"role":role}
	var operation: Dictionary = resource_operations.proposal(owner)
	return {"action":"Support Formation" if role != "Rifle" else str(operation.get("action","Seize Objective")),"destination":objective,"fallback":fallback,"role":role,"supply":"blue-delivery" if side == "blue" and role == "Rifle" else ""}

func _request_trips() -> void:
	var rear: RefCounted = _rear()
	if not rear.military.has_method("request_troop_trip"): return
	refresh_trip_admissions()
	var ordered: Array = trips.values()
	for trip in ordered:
		if trip.reserve and not reserve_active: continue
		if trip.started:
			var all_out := true
			for squad_id in trip.squads:
				var squad: Dictionary = rear.military.squads[squad_id]
				if not squad.vehicle.is_empty(): all_out = false
				for person_id in rear.military._active_roster_members(squad):
					if rear.ledger.inspect_person_status(person_id).holder_id != trip.dismount: all_out = false
			if all_out: trip.dismounted = true
	# One potentially expensive physical admission per existing decision tick.
	# Rotate even after a refusal so one invalid queued lift cannot starve others.
	if rear.time == _last_trip_attempt: return
	for offset in ordered.size():
		var index: int = (_trip_admission_cursor+offset)%ordered.size()
		var trip: Dictionary = ordered[index]
		if trip.started or not str(trip.request).is_empty() or (trip.reserve and not reserve_active): continue
		var acknowledged := true
		var intent_ids := {}
		for squad_id in trip.squads:
			var intent: Dictionary = rear.orders.intents.get(squad_id,{})
			if intent.get("state","") != "Acknowledged" or intent.action != "Move by Transport": acknowledged = false
			if intent.get("id","") != _child_orders.get(squad_id,{}).get("issued","") or intent.get("constraints",{}).get("destination","") != trip.dismount: acknowledged = false
			intent_ids[squad_id] = str(intent.get("id",""))
		if not acknowledged: continue
		_trip_admission_cursor = (index+1)%ordered.size()
		_last_trip_attempt = rear.time
		var members: Array[String] = []
		members.assign(trip.squads)
		var transport: RefCounted = rear.military.troop_transport
		if transport.incremental_planning:
			_trip_request_sequence += 1
			var key: String = "%s:%d" % [trip.id,_trip_request_sequence]
			var queued: Dictionary = transport.request_trip_deferred(key,trip.hull,members,trip.board,trip.dismount,trip.outbound,trip["return"],intent_ids)
			if queued.ok:
				trip.request = key
				trip.blocker = "Planning transport route; passengers are not committed."
			else: trip.blocker = str(queued.get("message","Transport planning unavailable"))
			return
		var requested: Dictionary = rear.military.request_troop_trip(trip.hull,members,trip.board,trip.dismount,trip.outbound,trip["return"])
		if requested.ok: trip.started = true; trip.job = requested.id; trip.admitted_at = rear.time; trip.blocker = ""
		else: trip.blocker = str(requested.get("message",requested.get("blocked_reason","Transport unavailable")))
		return

func refresh_trip_admissions() -> void:
	var rear: RefCounted = _rear()
	var transport: RefCounted = rear.military.troop_transport
	if not transport.incremental_planning: return
	for trip in trips.values():
		if str(trip.request).is_empty(): continue
		var admission: Dictionary = transport.planning_status(trip.request)
		match str(admission.get("state","")):
			"Pending": trip.blocker = "Planning transport route; passengers are not committed."
			"Ready": trip.blocker = "Route ready; passengers are not committed."
			"Admitted":
				trip.started = true
				trip.job = str(admission.job)
				trip.admitted_at = float(admission.get("admitted_at",rear.time))
				trip.blocker = ""
				trip.request = ""
			"Blocked", "Cancelled":
				trip.blocker = str(admission.get("message","Transport planning stopped."))
				trip.request = ""

func _reposition_supply_truck() -> void:
	var rear: RefCounted = _rear()
	if repositioned.has("blue-supply") or not rear.military.has_method("request_reposition"): return
	var hull: Dictionary = rear.ledger.inspect_entity(armies["army-blue"].hulls[2].id,{},false)
	var route: Array = [hull.position,Vector2(2000,650),Vector2(2100,650),Vector2(2100,450),points["blue-service"]]
	var fallback := route.duplicate()
	fallback.reverse()
	var requested: Dictionary = rear.military.request_reposition(hull.id,"hq-berth",route,fallback)
	if requested.ok: repositioned["blue-supply"] = requested.id

func snapshot() -> Dictionary:
	var own_trips: Array[Dictionary] = []
	for id in trips:
		if id.begins_with("blue"): own_trips.append(trips[id].duplicate(true))
	return {"phase":phases.get("army-blue","Opening"),"status":status.get("army-blue","Awaiting command delivery"),"trips":own_trips,"resupply":resupply.snapshot(),"deployments":deployments.snapshot(),"resource_operations":resource_operations.snapshot("army-blue")}
