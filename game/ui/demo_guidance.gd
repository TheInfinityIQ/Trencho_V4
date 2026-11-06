extends RefCounted
## Read-only bridge between existing factory guidance and real delivery preparation.
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
const Factory = preload("res://game/rear_base/factory_plan.gd")
const Army = preload("res://game/logistics/army_supply_view.gd")
const RETIRED := ["Cancelled", "Destroyed", "Dismantled"]

static func view(session: Node) -> Dictionary:
	CallLog.record(&"ui/demo_guidance.gd::view")
	if not is_instance_valid(session) or session.simulation == null: return {}
	var model: RefCounted = session.simulation
	var rear: RefCounted = model.rear
	var factory := Factory.view(model)
	var facilities := _facilities(rear)
	var school := _school(rear)
	var transport := _transport(rear)
	var army := Army.view(session)
	var milestones: Array[Dictionary] = [
		{"title":"Factory", "detail":"Building Materials and rifle ammunition manufactured this session." if factory.complete else "Use the guided factory task in Production: workers, construction and actual new output."},
		{"title":"School and crew", "detail":"%d live rear crew-qualified people; %d instructors present; %d course places reserved. A qualification grants no vehicle or equipment." % [school.crew,school.instructors,school.courses]},
		{"title":"Rear transport", "detail":"%d live rear transport trucks; %d parked with a seated Driver; %d active supply trips. Departure still checks fuel, route, cargo and handling." % [transport.trucks,transport.driven,transport.trips]},
		{"title":"Army needs", "detail":"Open the real demand and receipt stages. Starting HQ stock, rear output, HQ receipt and frontline issue are separate." if not army.is_empty() else "No connected Army supply view is available in this scene."}
	]
	var action := _next(factory,facilities,school,transport,army)
	if model.speed == 0: action.reason += " Game time is paused; use 1x when ready for arrivals, reporting, work and travel."
	return {"milestones":milestones,"next_action":action,"factory":factory,"school":school,"transport":transport,"army_available":not army.is_empty(),"army_status":"No connected Army needs in this scene." if army.is_empty() else ("No current rear ammunition shortfall after existing military supply coverage." if int(army.rear_shortage) == 0 else "Current military shortfall beyond existing supply: %d rifle rounds." % army.rear_shortage)}

static func _facilities(rear: RefCounted) -> Dictionary:
	var result := {"training":{},"vehicle_works":{},"park":{},"dispatch":{}}
	for id in rear.construction.instances:
		var row: Dictionary = rear.construction.instances[id]
		if row.kind not in result or row.state in RETIRED: continue
		var previous: Dictionary = result[row.kind]
		# One completed centre with actual handlers satisfies this preparation.
		# Once found, later unstaffed copies need neither a read nor another target.
		if row.kind == "dispatch" and int(previous.get("requested",0)) > 0 and int(previous.get("present",0)) > 0: continue
		var candidate := {"id":str(id),"state":str(row.state),"blocker":str(row.get("blocker","")),"requested":int(rear.requests.get(id,{}).get("target",0)),"present":rear._present(id) if row.kind == "dispatch" and row.state == "Complete" else 0}
		var staffed_dispatch: bool = row.kind == "dispatch" and row.state == "Complete" and candidate.requested > 0 and candidate.present > 0
		if previous.is_empty() or (row.state == "Complete" and previous.state != "Complete") or staffed_dispatch:
			result[row.kind] = candidate
	return result

static func _school(rear: RefCounted) -> Dictionary:
	var result := {"basic":0,"crew":0,"courses":0,"instructors":rear.training.instructors().size(),"crew_access":rear.training.course_accessible("P08")}
	# The rear actor registry bounds this read to actual rear people, not world entities.
	for id in rear.actors:
		var person: Dictionary = rear.ledger.inspect_person_status(id)
		if person.is_empty() or person.owner != rear.PLAYER or person.health <= 0 or person.rear_place != "Occupied": continue
		if person.basic_training: result.basic += 1
		if person.qualification == "P08": result.crew += 1
	for row in rear.training.rows:
		if row.state not in ["Completed","Withdrawn"]: result.courses += 1
	return result

static func _transport(rear: RefCounted) -> Dictionary:
	var result := {"trucks":0,"driven":0,"fueled":0,"trips":0}
	for id in rear.vehicles.vehicles:
		var hull: Dictionary = rear.ledger.inspect_entity(id,{},false)
		if hull.is_empty() or hull.owner != rear.PLAYER or hull.controller != rear.PLAYER or hull.fleet_domain != "Rear" or hull.health <= 0 or hull.design_type not in ["T01","T02"]: continue
		result.trucks += 1
		if rear.vehicles.vehicles[id].state != "Parked": continue
		if rear.vehicles.readiness(id).driver:
			result.driven += 1
			if hull.fuel > 0.0: result.fueled += 1
	for row in rear.dispatch.manifests.values():
		if row.mode == "Strategic Delivery" and row.state not in ["Complete","Cancelled","Safety Returned"]: result.trips += 1
	return result

static func _next(factory: Dictionary, facilities: Dictionary, school: Dictionary, transport: Dictionary, army: Dictionary) -> Dictionary:
	if army.get("held",false): return _action("ArmyNeeds","Review held Army supply","Automatic rifle supply remains held after cancellation. Review Army needs and resume explicitly if wanted; this guide never resumes it.")
	if transport.trips > 0: return _action("ArmyNeeds","Follow the current supply trip","An actual rear shipment is active. Follow HQ receipts and return progress before committing another truck. HQ receipt does not establish frontline issue.")
	if not factory.complete:
		var current: Dictionary = factory.next_action
		return _action(str(current.panel),str(current.label),str(current.reason))
	if transport.driven == 0 and school.crew == 0:
		var school_site := _site_action(facilities.training,"School")
		if not school_site.is_empty(): return school_site
		if school.basic == 0: return _action("Supplies","Review recovery instructor","No live basic-trained person is registered in the rear. Supplies offers the existing recovery instructor route and shows any pending arrival, capacity or price blocker. Then request an instructor at the School.")
		if school.instructors == 0: return _action("Train","Assign a School instructor","A basic-trained person exists, but no instructor is physically present at a School. Request an instructor and allow reporting; courses need actual coverage.")
		if not school.crew_access: return _action("Build","Review vehicle course access","Vehicle crew training requires declared vehicle-recipe access. Review Vehicle Works construction and the course access reason in Training; selecting a recipe alone is insufficient.")
		return _action("Train","Review crew training","%d course places are reserved. Train an ordinary worker in Basic infantry, then Vehicle crew. A student or requested place is not a seated Driver; completed people retain their actual qualification." % school.courses)
	if transport.trucks == 0:
		for entry in [["vehicle_works","Vehicle Works"],["park","Vehicle Park"]]:
			var site := _site_action(facilities[entry[0]],entry[1])
			if not site.is_empty(): return site
		return _action("Work","Manufacture a transport truck","Use the completed Vehicle Works to order a resource or troop transport. Actual ingredients, operators, bay and parking admission are required. A vehicle order is not a finished truck.")
	if transport.driven == 0: return _action("Vehicles","Seat a qualified Driver","An actual transport exists, but none is parked with a physically seated Driver. Check parking, crew qualification and reporting in Vehicles. A requested crew assignment is not a seated person.")
	if transport.fueled == 0: return _action("Vehicles","Review transport fuel","A Driver is seated in a parked transport, but no such truck has fuel. Use the existing real refuelling controls; the full outward/return route is checked before departure.")
	var dispatch_site := _site_action(facilities.dispatch,"Logistics Centre")
	if not dispatch_site.is_empty(): return dispatch_site
	var dispatch: Dictionary = facilities.dispatch
	if int(dispatch.requested) == 0 or int(dispatch.present) == 0:
		return _action("Workers/Jobs","Staff the Logistics Centre","No completed Logistics Centre currently has both requested and present handlers. At the shown centre, %d are requested and %d present. Request handlers at one usable centre and allow reporting; hauling and loading still take physical time." % [dispatch.requested,dispatch.present])
	return _action("ArmyNeeds","Review actual Army needs",_army_reason(army))

static func _site_action(site: Dictionary, name: String) -> Dictionary:
	if site.is_empty(): return _action("Build","Build a " + name,"Place the %s through Build and request real builders and materials. This is preparation for transport, not proof that the army currently needs new production." % name)
	if site.state != "Complete": return _action("Build","Inspect " + name + " construction","%s is %s. Check the site's builders, material delivery and access. %s" % [name,site.state,site.blocker])
	return {}

static func _army_reason(army: Dictionary) -> String:
	if army.is_empty(): return "This scene has no connected military demand reader; use the connected main game to inspect actual Army needs."
	if int(army.rear_shortage) == 0: return "Current military need is covered by existing local, committed forward or HQ supply. Do not assume more manufacture is needed. Army needs separates starting HQ stock, rear stock and actual receipts; other capability requirements still apply."
	return "The military reports %d rifle rounds beyond local, forward commitments and HQ coverage; %d rounds are already available in rear stores. Review existing shipments and actual blockers before choosing production. Supply permits capability only when the recipient physically receives it and other requirements are met." % [army.rear_shortage,army.stock.rear]

static func _action(panel: String, label: String, reason: String) -> Dictionary:
	return {"panel":panel,"label":label,"reason":reason}
