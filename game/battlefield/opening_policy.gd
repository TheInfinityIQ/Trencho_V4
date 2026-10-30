extends RefCounted
const Resupply = preload("res://game/battlefield/opening_resupply.gd")
## Declared playtest opening only; broad commander operation scoring is deferred.
var _rear_ref: WeakRef
var armies: Dictionary
var points: Dictionary
var phases: Dictionary = {}
var reserve_active := false
var trips: Dictionary = {}
var status: Dictionary = {}
var repositioned: Dictionary = {}
var resupply: RefCounted

func _init(rear: RefCounted, army_data: Dictionary, waypoints: Dictionary) -> void:
	_rear_ref = weakref(rear)
	armies = army_data
	points = waypoints
	resupply = Resupply.new(rear,armies["army-blue"].rifles.slice(0,2),armies["army-blue"].engineer,"blue-delivery")
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
	var actual: Dictionary = rear.ledger.inspect_entity(hull)
	var destination: String = side+"-dismount-%d" % index
	var route: Array = [actual.position]
	route.append_array(points[side+"-front-route"])
	route.append(rear.ledger.inspect_entity(destination).position)
	var returning := route.duplicate()
	returning.reverse()
	trips[id] = {"hull":hull,"squads":squads,"board":actual.holder_id,"dismount":destination,"outbound":route,"return":returning,"reserve":reserve,"started":false,"dismounted":false,"job":"","blocker":""}

func tick() -> void:
	var rear: RefCounted = _rear()
	if not reserve_active:
		for id in rear.orders.contacts.get("army-red",{}):
			var contact: Dictionary = rear.orders.contact("army-red",id)
			if contact.get("confidence",0) > 0 and contact.get("observed_strength",0) > 0: reserve_active = true; break
	for owner in armies:
		var army: Dictionary = armies[owner]
		var side := "blue" if owner == "army-blue" else "red"
		var first := "resource-centre-"+side
		for report in rear.orders.reports:
			if report.current_at == army.root and report.kind == "Complete" and report.detail == "Captured "+first:
				phases[owner] = "Probe" if side == "blue" else "Hold"
		var commander: Dictionary = rear.ledger.inspect_entity(army.commander)
		if commander.get("health",0) <= 0: status[owner] = "Commander unavailable; received intent continues"; continue
		var objective: String = "resource-centre-red" if phases[owner] == "Probe" else first
		var version: String = str(phases[owner])+str(reserve_active if side == "red" else false)
		var company_intent: Dictionary = rear.orders.intents.get(army.company,{})
		if company_intent.get("constraints",{}).get("opening_version","") != version:
			var sent: Dictionary = rear.orders.issue_order(army.root,army.company,"Probe" if phases[owner] == "Probe" else ("Hold Area" if phases[owner] == "Hold" else "Seize Objective"),"Secure the declared central approach","Opening supply and objective playtest",{"opening_version":version,"objective":objective},"Emergency" if reserve_active and side == "red" else "Normal","Own HQ staging")
			if not sent.ok: status[owner] = sent.message
			company_intent = rear.orders.intents.get(army.company,{})
		if company_intent.get("state","") != "Acknowledged": continue
		for platoon_id in rear.military.companies[army.company].platoons:
			var platoon_intent: Dictionary = rear.orders.intents.get(platoon_id,{})
			if platoon_intent.get("constraints",{}).get("relayed_from","") != company_intent.id:
				rear.orders.relay_order(army.company,platoon_id)
				continue
			if platoon_intent.get("state","") != "Acknowledged": continue
			for squad_id in rear.military.platoons[platoon_id].squads:
				var desired: Dictionary = _squad_order(owner,squad_id,objective)
				var current: Dictionary = rear.orders.intents.get(squad_id,{})
				var key: String = version+str(desired.action)+str(desired.destination)
				if current.get("constraints",{}).get("opening_key","") == key: continue
				rear.orders.issue_order(platoon_id,squad_id,desired.action,"Perform the assigned opening role","Support the company objective",{"destination":desired.destination,"fallback_place":desired.fallback,"role":desired.role,"supported_squads":[army.rifles[0],army.rifles[1]],"opening_key":key},"Normal",desired.fallback)
		status[owner] = str(phases[owner])+": "+objective
	_request_trips()
	_reposition_supply_truck()
	resupply.tick()

func _squad_order(owner: String, id: String, objective: String) -> Dictionary:
	var army: Dictionary = armies[owner]
	var side := "blue" if owner == "army-blue" else "red"
	var role := "Medical" if id == army.medical else ("Support" if id == army.engineer else "Rifle")
	if id == army.rifles[2]: return {"action":"Defend HQ","destination":side+"-guard-rally","fallback":side+"-guard-rally","role":"Guard"}
	if side == "red" and id == army.rifles[1] and not reserve_active: return {"action":"Hold Area","destination":_rear().ledger.inspect_entity(army.hulls[1].id).holder_id,"fallback":army.staging,"role":"Reserve"}
	if side == "red" and id in [army.engineer,army.medical]: return {"action":"Hold Area","destination":side+"-"+("medical" if role == "Medical" else "support")+"-rally","fallback":army.staging,"role":role}
	var fallback: String = army.staging
	for trip in trips.values():
		if id not in trip.squads: continue
		fallback = trip.dismount
		if not trip.dismounted: return {"action":"Move by Transport","destination":trip.dismount,"fallback":army.staging,"role":role}
	if side == "blue":
		fallback = "blue-supply-rally"
		if id == army.engineer: return {"action":"Hold Area","destination":"blue-delivery","fallback":fallback,"role":role}
	return {"action":"Support Formation" if role != "Rifle" else ("Probe" if phases[owner] == "Probe" else ("Hold Area" if phases[owner] == "Hold" else "Seize Objective")),"destination":objective,"fallback":fallback,"role":role}

func _request_trips() -> void:
	var rear: RefCounted = _rear()
	if not rear.military.has_method("request_troop_trip"): return
	for trip in trips.values():
		if trip.reserve and not reserve_active: continue
		if trip.started:
			var all_out := true
			for squad_id in trip.squads:
				var squad: Dictionary = rear.military.squads[squad_id]
				if not squad.vehicle.is_empty(): all_out = false
				for person_id in rear.military._active_roster_members(squad):
					if rear.ledger.inspect_entity(person_id).holder_id != trip.dismount: all_out = false
			if all_out: trip.dismounted = true
			continue
		var acknowledged := true
		for squad_id in trip.squads:
			var intent: Dictionary = rear.orders.intents.get(squad_id,{})
			if intent.get("state","") != "Acknowledged" or intent.action != "Move by Transport": acknowledged = false
		if not acknowledged: continue
		var members: Array[String] = []
		members.assign(trip.squads)
		var requested: Dictionary = rear.military.request_troop_trip(trip.hull,members,trip.board,trip.dismount,trip.outbound,trip["return"])
		if requested.ok: trip.started = true; trip.job = requested.id
		else: trip.blocker = str(requested.get("message",requested.get("blocked_reason","Transport unavailable")))

func _reposition_supply_truck() -> void:
	var rear: RefCounted = _rear()
	if repositioned.has("blue-supply") or not rear.military.has_method("request_reposition"): return
	var hull: Dictionary = rear.ledger.inspect_entity(armies["army-blue"].hulls[2].id)
	var route: Array = [hull.position,Vector2(2000,650),Vector2(2100,650),Vector2(2100,450),points["blue-service"]]
	var fallback := route.duplicate()
	fallback.reverse()
	var requested: Dictionary = rear.military.request_reposition(hull.id,"hq-berth",route,fallback)
	if requested.ok: repositioned["blue-supply"] = requested.id

func snapshot() -> Dictionary:
	var own_trips: Array[Dictionary] = []
	for id in trips:
		if id.begins_with("blue"): own_trips.append(trips[id].duplicate(true))
	return {"phase":phases.get("army-blue","Opening"),"status":status.get("army-blue","Awaiting command delivery"),"trips":own_trips,"resupply":resupply.snapshot()}
