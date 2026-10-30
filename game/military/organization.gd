extends RefCounted
## G15 command organization. The shared ledger remains the owner of every person, hull and item.
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const TroopTransport = preload("res://game/military/troop_transport.gd")
const HQ := Vector2(1640.0,91.0)
const EPS := 0.000001
const KINDS: Array[String] = ["Rifle","Machine gun","Mortar","Engineer","Medical","Artillery","Reconnaissance","Marksman"]
const MINIMUM := {"Rifle":4,"Machine gun":4,"Mortar":4,"Engineer":4,"Medical":4,"Artillery":6,"Reconnaissance":4,"Marksman":4}
const SPECIALISTS := {"Rifle":{"None":0},"Machine gun":{"P04":2},"Mortar":{"P04":3},"Engineer":{"P02":2},"Medical":{"P03":1},"Artillery":{"P05":4},"Reconnaissance":{"P06":1},"Marksman":{"P07":1}}
var hq_position: Vector2
var _rear_ref: WeakRef
var companies: Dictionary = {}
var platoons: Dictionary = {}
var squads: Dictionary = {}
var vehicles: Dictionary = {}
var troop_transport: RefCounted
var crew_reports: Dictionary = {} # person ID -> one real station report
var replacement_reports: Dictionary = {} # person ID -> an unfilled active roster place
var artillery_guns: Dictionary = {} # physical E13 ID -> one squad
var demands: Dictionary = {}
var _sequence := 0
var _need_sequence := 0
var status := "HQ command awaits four actually equipped, received reserve people."
var _commander_id := "initial-hq-05"

func _init(rear: RefCounted) -> void:
	_rear_ref = weakref(rear)
	hq_position = rear.ledger.inspect_entity("hq-berth").position
	rear.ledger.add_place("hq-formation","Military formation report at HQ",hq_position)
	troop_transport = TroopTransport.new(rear,self)


func request_troop_trip(hull_id: String, squad_ids: Array, board_place_id: String, dismount_place_id: String,
		outbound_points: Array, return_points: Array) -> Dictionary:
	return troop_transport.request_trip(hull_id,squad_ids,board_place_id,dismount_place_id,outbound_points,return_points)


func request_reposition(hull_id: String, destination_place_id: String, route_points: Array, fallback_points: Array) -> Dictionary:
	return troop_transport.request_reposition(hull_id,destination_place_id,route_points,fallback_points)


func interrupt_troop_trip(id: String) -> Dictionary:
	return troop_transport.interrupt_trip(id)


func resume_troop_trip(id: String, route_points: Array = []) -> Dictionary:
	return troop_transport.resume_trip(id,route_points)


func hull_committed(id: String) -> bool:
	return troop_transport.hull_committed(id)


func person_committed(id: String) -> bool:
	return troop_transport.person_committed(id)

func add_initial_squad(id: String, kind: String, people: Array[String], company_id: String, platoon_id: String, owner: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	if rear.time != 0.0 or id.is_empty() or company_id.is_empty() or platoon_id.is_empty() or owner not in ["army-blue","army-red"] or squads.has(id) or kind not in ["Rifle","Engineer","Medical"] or people.size() < MINIMUM.get(kind,9) or people.size() > 8:
		return _fail("Initial squad requires time zero, one declared army, unique hierarchy and a supported actual roster.")
	if companies.has(company_id) and companies[company_id].get("owner",rear.PLAYER) != owner: return _fail("A company cannot contain opposing armies.")
	if owner == rear.PLAYER and rear.dispatch.military_people.size()+rear.dispatch.incoming_people.size()+people.size() > 384: return _fail("Initial military person admission is full.")
	if _owned_count(squads,owner) >= 27 or (not companies.has(company_id) and _owned_count(companies,owner) >= 3) or (not platoons.has(platoon_id) and _owned_count(platoons,owner) >= 9): return _fail("This army's initial hierarchy capacity is full.")
	if platoons.has(platoon_id) and (platoons[platoon_id].company != company_id or platoons[platoon_id].squads.size() >= 3): return _fail("Initial platoon parent or capacity conflicts.")
	if not platoons.has(platoon_id) and companies.has(company_id) and companies[company_id].platoons.size() >= 3: return _fail("Company platoon capacity reached.")
	var seen := {}
	for person_id in people:
		var person: Dictionary = rear.ledger.inspect_entity(person_id)
		if seen.has(person_id) or rear.actors.has(person_id) or person.get("rear_place","") != "None" or person.get("owner","") != owner or person.get("assignment","") != "Available" or person.get("health",0) <= 0 or person.get("pending_assignment","") != "None" or not str(person.get("crew_station","")).is_empty() or not str(person.get("carrying_stock_id","")).is_empty() or not str(person.get("carrying_weapon_id","")).is_empty() or rear.ledger.inspect_entity(person.get("holder_id","")).get("kind","") != "PLACE": return _fail("Initial members must be distinct, living, free battlefield people of this army on foot.")
		seen[person_id] = true
	var package: Dictionary = _package(kind,people)
	if not package.ok: return package
	if not companies.has(company_id): companies[company_id] = {"id":company_id,"owner":owner,"army_id":"army" if owner == rear.PLAYER else owner,"platoons":[],"service_vehicles":[],"leader":"","blocker":""}
	if not platoons.has(platoon_id):
		platoons[platoon_id] = {"id":platoon_id,"owner":owner,"company":company_id,"squads":[],"vehicles":[],"leader":"","blocker":""}
		companies[company_id].platoons.append(platoon_id)
	for person_id in people:
		var assigned: Dictionary = rear.ledger.assign_initial_formation(person_id,id)
		assert(assigned.ok)
		if owner == rear.PLAYER: rear.dispatch.military_people[person_id] = "Initial formation"
	squads[id] = {"id":id,"owner":owner,"kind":kind,"company":company_id,"platoon":platoon_id,"roster":people.duplicate(),"state":"Active","leader":"","acting":false,"equipment":{},"report_due":INF,"replacement_due":INF,"gun_id":"","shell_claims":[],"shell_ids":[],"vehicle":"","blocker":"","replacement_attempted":false}
	platoons[platoon_id].squads.append(id)
	_appoint_squad(squads[id])
	_appoint_seniors()
	return {"ok":true,"id":id,"message":"Initial squad registered with its existing people and real parent hierarchy."}

func request_need(kind: String, reason: String, priority: int = 4, parent_value: int = 0) -> Dictionary:
	if kind not in KINDS or reason.is_empty() or priority < 0 or priority > 9 or parent_value < 0 or parent_value > 9:
		return _fail("Command needs one known squad type, reason, priority and parent-mission value.")
	_need_sequence += 1
	var id := "need-%04d" % _need_sequence
	demands[id] = {"id":id,"kind":kind,"reason":reason,"priority":priority,"parent_value":parent_value,"since":_rear_ref.get_ref().time}
	return {"ok":true,"id":id,"message":"HQ command recorded a formation need; real people and gear still govern."}

func assess_squad(kind: String, people: Array[String]) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	if kind not in KINDS: return _fail("Choose a defined G15 squad type.")
	if people.size() < int(MINIMUM[kind]): return _fail("%s needs at least %d actual people; only %d offered." % [kind,MINIMUM[kind],people.size()])
	if people.size() > 8: return _fail("An ordinary squad has at most eight actual roster places.")
	if _owned_count(squads,_rear_ref.get_ref().PLAYER) >= 27: return _fail("Army infantry cap is 27 squads and 216 roster places.")
	var unique := {}
	var specialist_count := 0
	for id in people:
		if unique.has(id): return _fail("One person cannot occupy two squad places.")
		unique[id] = true
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if not rear.dispatch.military_people.has(id) or rear.dispatch.hq_reserve.get(id,"") != "Occupied" or person.is_empty() or person.assignment != "HQ Reserve" or person.holder_id != "hq-reserve" or person.health <= 0 or person.pending_assignment != "None" or not person.crew_station.is_empty() or rear.hq._target_busy(id):
			return _fail("%s must finish HQ receipt, issue and any prior duty before reporting to a squad." % id)
		if not person.carrying_stock_id.is_empty() or not person.carrying_weapon_id.is_empty(): return _fail("%s must finish its carried-goods handoff." % id)
		if not person.basic_training and kind != "Rifle": return _fail("Specialist squads need basic-trained members; conscripts may serve only an acting Rifle role.")
		var required_special: String = str(SPECIALISTS[kind].keys()[0])
		if kind == "Rifle" and person.qualification != "None" and not _immediate_rifle_need():
			return _fail("HQ command retains specialists for compatible roles unless immediate HQ survival is declared.")
		if kind != "Rifle" and person.qualification not in [required_special,"None"]:
			return _fail("A specialist belongs to a compatible role, not an unrelated guard place.")
		for qualification in SPECIALISTS[kind]:
			if qualification != "None" and person.qualification == qualification: specialist_count += 1
	if kind != "Rifle":
		var required: int = int(SPECIALISTS[kind].values()[0])
		if specialist_count < required: return _fail("%s needs %d real qualified %s members; only %d offered." % [kind,required,SPECIALISTS[kind].keys()[0],specialist_count])
	var package: Dictionary = _package(kind,people)
	if not package.ok: return package
	return {"ok":true,"message":"Type minimum, distinct received people, issued package and roster cap are satisfied.","equipment":package.equipment}

func form_squad(kind: String, people: Array[String]) -> Dictionary:
	# Command calls this boundary; the player UI exposes inspection only.
	var eligibility: Dictionary = assess_squad(kind,people)
	if not eligibility.ok: return eligibility
	var rear: RefCounted = _rear_ref.get_ref()
	var parent: Dictionary = _available_platoon()
	if parent.is_empty(): return _fail("Army has three companies, nine platoons or this parent's three squad places full.")
	_sequence += 1
	while squads.has("squad-%04d" % _sequence): _sequence += 1
	var id := "squad-%04d" % _sequence
	var accepted: Array[String] = []
	for person_id in people:
		var result: Dictionary = rear.ledger.request_formation_report(person_id,id)
		if not result.ok:
			for prior in accepted: rear.ledger.cancel_formation_report(prior,id)
			_prune_empty_parent(parent.id)
			return _fail(result.message)
		accepted.append(person_id)
	var artillery := {"gun":"","claims":[],"shells":[]}
	if kind == "Artillery":
		artillery = _reserve_artillery(id)
		if artillery.gun.is_empty():
			for prior in accepted: rear.ledger.cancel_formation_report(prior,id)
			_prune_empty_parent(parent.id)
			return _fail("Actual unallocated E13 and ten claimable E14 are required for this artillery squad.")
	var travel: float = hq_position.distance_to(rear.ledger.inspect_entity(people[0]).position)/2.0
	# Reserve and formation report are 15 m apart in the accepted HQ layout.
	travel = maxf(1.0,travel)
	squads[id] = {"id":id,"kind":kind,"company":parent.company,"platoon":parent.id,
		"roster":people.duplicate(),"state":"Reporting","leader":"","acting":false,
		"equipment":eligibility.equipment,"report_due":rear.time+travel,"replacement_due":INF,
		"gun_id":artillery.gun,"shell_claims":artillery.claims,"shell_ids":artillery.shells,
		"vehicle":"","blocker":"Real members walking from HQ Reserve to formation report.","replacement_attempted":false}
	platoons[parent.id].squads.append(id)
	status = "%s %s reports at HQ; %d existing people remain on reserve duty until arrival." % [kind,id,people.size()]
	return {"ok":true,"id":id,"message":status}

func cancel_pending_squad(squad_id: String) -> Dictionary:
	var row: Dictionary = squads.get(squad_id,{})
	if row.is_empty() or row.state != "Reporting": return _fail("Only an uncompleted squad report can release its unused formation intent.")
	var rear: RefCounted = _rear_ref.get_ref()
	for id in row.roster:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if person.assignment != "HQ Reserve" or person.holder_id != "hq-reserve" or person.pending_duty != squad_id:
			return _fail("A person already completed this report; command must arrange a real onward destination.")
	for id in row.roster: rear.ledger.cancel_formation_report(id,squad_id)
	for claim in row.shell_claims: rear.ledger.release_claim(claim.id)
	if not row.gun_id.is_empty(): artillery_guns.erase(row.gun_id)
	platoons[row.platoon].squads.erase(squad_id)
	squads.erase(squad_id)
	_prune_empty_parent(row.platoon)
	status = "%s pending report cancelled; same people and gear remain at their actual HQ holders." % squad_id
	return {"ok":true,"message":status}

func cancel_replacement(person_id: String) -> Dictionary:
	var report: Dictionary = replacement_reports.get(person_id,{})
	if report.is_empty(): return _fail("No pending replacement report belongs to this person.")
	if _rear_ref.get_ref().ledger.inspect_entity(person_id).get("holder_id","") != "hq-reserve": return _fail("This person has moved; arrange a real return before releasing the roster intent.")
	var cancelled: Dictionary = _rear_ref.get_ref().ledger.cancel_formation_report(person_id,report.squad)
	if not cancelled.ok: return cancelled
	replacement_reports.erase(person_id)
	return {"ok":true,"message":"Only this unused roster intent released; same person remains at HQ Reserve."}

func cancel_crew_report(person_id: String) -> Dictionary:
	var report: Dictionary = crew_reports.get(person_id,{})
	if report.is_empty(): return _fail("No pending crew report belongs to this person.")
	if _rear_ref.get_ref().ledger.inspect_entity(person_id).get("holder_id","") != "hq-reserve": return _fail("This person has moved; arrange a real return before releasing the station intent.")
	var duty := "vehicle:%s:%s" % [report.hull,report.station]
	var cancelled: Dictionary = _rear_ref.get_ref().ledger.cancel_formation_report(person_id,duty)
	if not cancelled.ok: return cancelled
	crew_reports.erase(person_id)
	return {"ok":true,"message":"Only this unused crew station intent released; same person remains at HQ Reserve."}

func next_boundary() -> float:
	var next: float = troop_transport.next_boundary()
	for row in squads.values():
		next = minf(next,minf(float(row.report_due),float(row.replacement_due)))
	for row in crew_reports.values(): next = minf(next,float(row.due))
	for row in replacement_reports.values(): next = minf(next,float(row.due))
	return next

func advance_to(at: float) -> void:
	troop_transport.advance_to(at)

func record_death(person_id: String) -> void:
	# One physical death vacates one roster place; living wounded remain assigned.
	for row in squads.values():
		if person_id not in row.roster: continue
		row.roster.erase(person_id)
		if row.leader == person_id:
			_rear_ref.get_ref().ledger.clear_formation_appointment(person_id)
			row.leader = ""
			row.replacement_due = _rear_ref.get_ref().time+5.0
			row.replacement_attempted = false
		row.blocker = "Actual person lost; roster place and package require replacement."
	for row in platoons.values():
		if row.leader == person_id: row.leader = ""
	for row in companies.values():
		if row.leader == person_id: row.leader = ""
	for id in replacement_reports.keys():
		if id == person_id: replacement_reports.erase(id)
	for id in crew_reports.keys():
		if id == person_id: crew_reports.erase(id)
	status = "%s died; one actual formation place released." % person_id

func settle() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var changed: bool = troop_transport.settle()
	for id in replacement_reports.keys():
		var report: Dictionary = replacement_reports[id]
		if report.due > rear.time+EPS: continue
		var moved: Dictionary = rear.ledger.move_entity(id,"hq-formation",hq_position)
		if moved.ok:
			var joined: Dictionary = rear.ledger.complete_formation_report(id,report.squad,"hq-formation")
			if joined.ok:
				squads[report.squad].roster.append(id)
				rear.dispatch.hq_reserve.erase(id)
				replacement_reports.erase(id)
				status = "%s joined %s only after the real report walk." % [id,report.squad]
				changed = true
			else: report.blocker = joined.message
		else: report.blocker = moved.message
		report.due = INF
	for id in crew_reports.keys():
		var report: Dictionary = crew_reports[id]
		if report.due > rear.time+EPS: continue
		var moved: Dictionary = rear.ledger.move_entity(id,"hq-berth",hq_position)
		if moved.ok:
			var joined: Dictionary = rear.ledger.complete_military_crew_report(id,report.hull,report.station)
			if joined.ok:
				rear.dispatch.hq_reserve.erase(id)
				if vehicles.has(report.hull): vehicles[report.hull].crew = rear.ledger.inspect_entity(report.hull).crew_by_station.duplicate(true)
				status = "%s physically reported as %s on %s." % [id,report.station,report.hull]
				crew_reports.erase(id)
				changed = true
			else: report.blocker = joined.message
		else: report.blocker = moved.message
		report.due = INF
	for id in squads:
		var row: Dictionary = squads[id]
		if row.state == "Reporting" and row.report_due <= rear.time+EPS:
			for person_id in row.roster:
				var moved: Dictionary = rear.ledger.move_entity(person_id,"hq-formation",hq_position)
				if not moved.ok:
					row.blocker = moved.message
					continue
				var joined: Dictionary = rear.ledger.complete_formation_report(person_id,id,"hq-formation")
				if joined.ok: rear.dispatch.hq_reserve.erase(person_id)
				else: row.blocker = joined.message
			if _all_reported(row):
				if row.kind != "Artillery" or _equip_artillery(row):
					row.state = "Active"
					row.report_due = INF
					row.blocker = ""
					_appoint_squad(row)
					_appoint_seniors()
					changed = true
				else:
					row.state = "Equipping"
					row.report_due = INF
			else:
				row.report_due = INF
		elif row.state == "Equipping" and _equip_artillery(row):
			row.state = "Active"
			row.blocker = ""
			_appoint_squad(row)
			_appoint_seniors()
			changed = true
		elif row.state == "Active":
			var leader: Dictionary = rear.ledger.inspect_entity(row.leader)
			if leader.is_empty() or int(leader.get("health",0)) <= 0 or leader.duty_id != id:
				if row.replacement_due == INF and not row.replacement_attempted:
					if not row.leader.is_empty(): rear.ledger.clear_formation_appointment(row.leader)
					row.replacement_due = rear.time+5.0
					row.blocker = "Leader lost; five-second replacement delay. Existing intent continues."
					changed = true
				elif row.replacement_due <= rear.time+EPS:
					row.replacement_due = INF
					row.replacement_attempted = true
					_appoint_squad(row)
					_appoint_seniors()
					changed = true
	if _auto_replace(): changed = true
	if replacement_reports.is_empty() and not _has_reporting() and _auto_organize(): changed = true
	if _auto_issue_for_need(): changed = true
	if _auto_vehicle(): changed = true
	if _sync_commander(): changed = true
	return changed

func _sync_commander() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var current: Dictionary = rear.ledger.inspect_entity(_commander_id)
	if not current.is_empty() and current.health > 0: return false
	var successor := commander()
	if successor.is_empty() or successor == _commander_id:
		status = "Commander absent; no living trained senior leader may act."
		return false
	if not _commander_id.is_empty(): rear.ledger.clear_formation_appointment(_commander_id)
	_commander_id = successor
	for row in companies.values():
		if row.leader == successor:
			row.leader = ""
			row.blocker = "Company command delegated to acting Commander; another trained subordinate needed."
	for row in platoons.values():
		if row.leader == successor:
			row.leader = ""
			row.blocker = "Platoon command delegated to acting Commander; another trained subordinate needed."
	rear.ledger.set_formation_appointment(successor,"Squad; Acting Commander")
	_appoint_seniors()
	status = "%s acts as Commander without a new person or location change." % successor
	return true

func request_replacement(squad_id: String, person_id: String) -> Dictionary:
	var row: Dictionary = squads.get(squad_id,{})
	var rear: RefCounted = _rear_ref.get_ref()
	if row.is_empty() or row.state != "Active" or not row.vehicle.is_empty(): return _fail("An active dismounted squad must have a lawful real roster destination.")
	var pending := 0
	for report in replacement_reports.values():
		if report.squad == squad_id: pending += 1
	if row.roster.size()+pending >= 8: return _fail("Eight actual or reserved roster places are already occupied.")
	var person: Dictionary = rear.ledger.inspect_entity(person_id)
	if person.get("owner","") != row.get("owner",rear.PLAYER): return _fail("Replacement must belong to the squad's army.")
	if not rear.dispatch.military_people.has(person_id) or rear.dispatch.hq_reserve.get(person_id,"") != "Occupied" or person.is_empty() or person.pending_assignment != "None" or rear.hq._target_busy(person_id):
		return _fail("Only a physically received, free HQ Reserve member may report as a replacement.")
	if not _replacement_ready(row,person_id): return _fail("Replacement needs the matching qualification and actually issued role package.")
	var result: Dictionary = rear.ledger.request_formation_report(person_id,squad_id)
	if not result.ok: return result
	replacement_reports[person_id] = {"person":person_id,"squad":squad_id,"due":rear.time+hq_position.distance_to(person.position)/2.0,"blocker":"Walking to the existing squad."}
	return {"ok":true,"message":"Vacant roster place reserved; the same person remains HQ Reserve until actual rendezvous."}

func _auto_replace() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var ids: Array = rear.dispatch.hq_reserve.keys()
	ids.sort()
	for row in squads.values():
		if row.state != "Active" or row.roster.size() >= 8 or not row.vehicle.is_empty(): continue
		for id in ids:
			var person: Dictionary = rear.ledger.inspect_entity(id)
			if person.is_empty() or person.pending_assignment != "None" or person.assignment != "HQ Reserve" or rear.hq._target_busy(id): continue
			if not _replacement_ready(row,id): continue
			if request_replacement(row.id,id).ok: return true
	return false

func _replacement_ready(row: Dictionary, id: String) -> bool:
	var person: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(id)
	if person.is_empty() or person.health <= 0: return false
	if row.kind == "Rifle": return person.qualification == "None" and _rifle_ready(id)
	if not person.basic_training: return false
	var special: String = str(SPECIALISTS[row.kind].keys()[0])
	if person.qualification == special: return _specialist_ready(row.kind,id)
	return person.qualification == "None" and _rifle_ready(id)

func _auto_vehicle() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var hull_ids: Array = rear.dispatch.military_hulls.keys()
	hull_ids.sort()
	for hull_id in hull_ids:
		var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
		if hull.is_empty() or hull.fleet_domain != "Military" or hull.holder_id != "hq-berth" or hull.health <= 0: continue
		if not vehicles.has(hull_id) and hull.crew_by_station.has("Driver"):
			for platoon_id in platoons:
				if platoons[platoon_id].vehicles.size() < 2 and attach_vehicle(hull_id,platoon_id).ok: return true
			for company_id in companies:
				if companies[company_id].service_vehicles.size() < 2 and attach_vehicle(hull_id,company_id).ok: return true
		for station in hull.vehicle_spec.stations:
			if hull.crew_by_station.has(station): continue
			var pending := false
			for report in crew_reports.values():
				if report.hull == hull_id and report.station == station: pending = true
			if pending: continue
			var ids: Array = rear.dispatch.hq_reserve.keys()
			ids.sort()
			for id in ids:
				var person: Dictionary = rear.ledger.inspect_entity(id)
				if person.is_empty() or person.pending_assignment != "None" or rear.hq._target_busy(id): continue
				if person.qualification != "P08" and not (hull.design_type == "T03" and station == "Gunner" and person.qualification == "P04"): continue
				if assign_crew(id,hull_id,station).ok: return true
	return false

func assign_crew(person_id: String, hull_id: String, station: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	if not rear.dispatch.military_people.has(person_id) or rear.dispatch.hq_reserve.get(person_id,"") != "Occupied" or not rear.dispatch.military_hulls.has(hull_id):
		return _fail("Only an admitted military hull and physically received HQ Reserve crew member are eligible.")
	for report in crew_reports.values():
		if report.hull == hull_id and report.station == station: return _fail("This real crew station already has a pending report.")
	var result: Dictionary = rear.ledger.request_military_crew_report(person_id,hull_id,station)
	if not result.ok: return result
	crew_reports[person_id] = {"person":person_id,"hull":hull_id,"station":station,"due":rear.time+hq_position.distance_to(rear.ledger.inspect_entity(person_id).position)/2.0,"blocker":"Walking to the stopped hull."}
	return {"ok":true,"message":"Qualified person committed to a timed HQ crew report; station remains empty until arrival."}

func attach_vehicle(hull_id: String, parent_id: String) -> Dictionary:
	return _attach_vehicle(hull_id,parent_id,true)


func attach_initial_vehicle(hull_id: String, parent_id: String) -> Dictionary:
	if _rear_ref.get_ref().time != 0.0: return _fail("Initial vehicle attachment is only available at time zero.")
	return _attach_vehicle(hull_id,parent_id,false)


func _attach_vehicle(hull_id: String, parent_id: String, require_dispatch: bool) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	if vehicles.has(hull_id) or (require_dispatch and not rear.dispatch.military_hulls.has(hull_id)) or hull.is_empty() or hull.fleet_domain != "Military" or hull.owner not in ["army-blue","army-red"] or not Specs.TYPES.has(hull.design_type) or hull.vehicle_spec != Specs.TYPES[hull.design_type]:
		return _fail("Attach one actual admitted military hull once; an incoming or rear hull is not an element.")
	if _owned_count(vehicles,hull.owner) >= 24: return _fail("Army military fleet cap is 24 actual hulls.")
	if _living_crew_id(hull,"Driver").is_empty(): return _fail("A vehicle element needs its living, actually assigned qualified driver before attachment.")
	if platoons.has(parent_id):
		if platoons[parent_id].get("owner",rear.PLAYER) != hull.owner: return _fail("A hull may attach only to its own army.")
		if platoons[parent_id].vehicles.size() >= 2: return _fail("A platoon may attach at most two vehicle elements.")
		platoons[parent_id].vehicles.append(hull_id)
	elif companies.has(parent_id):
		if companies[parent_id].get("owner",rear.PLAYER) != hull.owner: return _fail("A hull may attach only to its own army.")
		if companies[parent_id].service_vehicles.size() >= 2: return _fail("A company may attach at most two additional service vehicles.")
		companies[parent_id].service_vehicles.append(hull_id)
	else: return _fail("Choose one existing real platoon or company parent.")
	vehicles[hull_id] = {"id":hull_id,"owner":hull.owner,"parent":parent_id,"crew":hull.crew_by_station.duplicate(true),"passenger_squad":"","passenger_squads":[],"ammo_target":{},"route_fuel":0.0,"blocker":""}
	return {"ok":true,"message":"Same military hull attached as a vehicle element with distinct actual crew."}

func set_vehicle_mission(hull_id: String, ammo_target: Dictionary, route_fuel: float) -> Dictionary:
	if not vehicles.has(hull_id) or not is_finite(route_fuel) or route_fuel < 0.0: return _fail("A real attached hull and finite route fuel are required.")
	var hull: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(hull_id)
	for type in ammo_target:
		if int(ammo_target[type]) < 0 or not hull.vehicle_spec.rack_capacity.has(type) or int(ammo_target[type]) > int(hull.vehicle_spec.rack_capacity[type]):
			return _fail("Mission ammunition target must fit each matching actual rack.")
	vehicles[hull_id].ammo_target = ammo_target.duplicate(true)
	vehicles[hull_id].route_fuel = route_fuel
	return {"ok":true,"message":"Vehicle mission uses actual crew, health, rack stock and route fuel."}

func vehicle_readiness(hull_id: String) -> float:
	if not vehicles.has(hull_id): return 0.0
	var row: Dictionary = vehicles[hull_id]
	var hull: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(hull_id)
	if hull.is_empty() or int(hull.health) <= 0: return 0.0
	var staffed := 0
	for station in hull.vehicle_spec.stations:
		if not _living_crew_id(hull,station).is_empty(): staffed += 1
	var crew := float(staffed)/float(hull.vehicle_spec.stations.size())
	var health := float(hull.health)/float(hull.vehicle_spec.health)
	var ammo := 1.0
	for type in row.ammo_target:
		var target: int = int(row.ammo_target[type])
		if target > 0: ammo = minf(ammo,float(hull.ammunition.get(type,0))/float(target))
	var fuel := 1.0 if row.route_fuel <= EPS else minf(1.0,float(hull.fuel)/float(row.route_fuel))
	return clampf(minf(minf(crew,health),minf(ammo,fuel)),0.0,1.0)

func vehicle_capability(hull_id: String, purpose: String) -> Dictionary:
	if purpose not in ["Movement","Fire","Transport"]: return _fail("Choose a real movement, fire or transport purpose.")
	if not vehicles.has(hull_id): return _fail("No attached actual military hull has this identity.")
	var row: Dictionary = vehicles[hull_id]
	var hull: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(hull_id)
	if hull.is_empty() or hull.health <= 0 or _living_crew_id(hull,"Driver").is_empty():
		return _fail("Vehicle needs a healthy actual hull and qualified driver.")
	if purpose in ["Movement","Transport"] and (hull.fuel <= EPS or hull.fuel+EPS < row.route_fuel):
		return _fail("Actual fuel does not support movement and its declared route.")
	if purpose == "Fire":
		if hull.vehicle_spec.rack_capacity.is_empty() or _living_crew_id(hull,"Gunner").is_empty():
			return _fail("Actual mounted weapon and gunner are required to fire.")
		var armed := false
		for type in hull.vehicle_spec.rack_capacity:
			if int(hull.ammunition.get(type,0)) > 0: armed = true
		if not armed: return _fail("Actual matching vehicle rack is empty.")
	if purpose == "Transport" and (row.passenger_squad.is_empty() or hull.passengers.is_empty()):
		return _fail("A real separately rostered squad must occupy passenger seats.")
	return {"ok":true,"message":"Actual hull, operators and purpose-specific stores support this G15 role."}

func _living_crew_id(hull: Dictionary, station: String) -> String:
	if hull.is_empty() or not hull.has("crew_by_station") or not hull.crew_by_station.has(station): return ""
	var id: String = hull.crew_by_station[station]
	var person: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(id)
	if person.is_empty() or person.health <= 0 or not person.basic_training or person.holder_id != hull.id or person.crew_station != station or person.assignment != "Formation Duty" or person.duty_id != "vehicle:"+hull.id: return ""
	if person.qualification != "P08" and not (hull.design_type == "T03" and station == "Gunner" and person.qualification == "P04"): return ""
	return id

func board_squad(squad_id: String, hull_id: String) -> Dictionary:
	var row: Dictionary = squads.get(squad_id,{})
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	if row.is_empty() or row.state != "Active" or not vehicles.has(hull_id) or not row.vehicle.is_empty() or hull.is_empty() or hull_committed(hull_id):
		return _fail("Only an active unboarded squad may use an attached military hull.")
	if row.get("owner",rear.PLAYER) != hull.owner: return _fail("Squad passengers must belong to the hull's army.")
	if _vehicle_squads(hull_id).size() >= (2 if hull.design_type == "T02" else 1): return _fail("This actual hull has no free separate squad commitment.")
	if row.roster.size()+hull.passengers.size() > int(hull.vehicle_spec.passenger_seats):
		return _fail("Actual squad passengers exceed seats; crew stations are separate.")
	for id in row.roster:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		if rear.forward_supply != null and rear.forward_supply.person_committed(id):
			return _fail("Local supply handoff must finish before this person boards.")
		if p.health <= 0 or p.holder_id != "hq-formation" or not p.crew_station.is_empty() or not p.position.is_equal_approx(hull.position):
			return _fail("Every living roster member must physically reach the stopped hull before boarding.")
	var reserved: Dictionary = _reserve_transport_manifest(hull_id,[squad_id])
	if not reserved.ok: return reserved
	for id in row.roster:
		var boarded: Dictionary = rear.ledger.board_formation_passenger(id,hull_id)
		if not boarded.ok: return boarded
	return {"ok":true,"message":"Same squad members occupy passenger seats; actual crew remain separate."}

func exit_squad(squad_id: String, place_id: String = "hq-formation") -> Dictionary:
	var row: Dictionary = squads.get(squad_id,{})
	if row.is_empty() or row.vehicle.is_empty(): return _fail("Only an actually boarded squad may disembark.")
	var hull_id: String = row.vehicle
	if hull_committed(hull_id): return _fail("Timed troop movement owns this hull's passenger exit.")
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	if hull.holder_id != "hq-berth" and hull.holder_id != place_id: return _fail("Stop at the same lawful actual exit place before squad disembarkation.")
	if rear.ledger.inspect_entity(place_id).get("kind","") != "PLACE" or not hull.position.is_equal_approx(rear.ledger.inspect_entity(place_id).position): return _fail("Dismount needs a physical stopped exit place at the hull.")
	for id in row.roster:
		var result: Dictionary = rear.ledger.exit_formation_passenger(id,hull_id,place_id)
		if not result.ok: return result
	_release_transport_squad(hull_id,squad_id)
	return {"ok":true,"message":"Same roster physically left the passenger seats at the hull's actual place."}


func _reserve_transport_manifest(hull_id: String, squad_ids: Array) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	if not vehicles.has(hull_id) or hull.is_empty(): return _fail("Only one actual attached military hull can hold this manifest.")
	var existing: Array = _vehicle_squads(hull_id)
	if existing.size()+squad_ids.size() > (2 if hull.design_type == "T02" else 1): return _fail("The hull's separate squad places are full.")
	var seen := {}
	var count: int = hull.passengers.size()
	for squad_id in squad_ids:
		var row: Dictionary = squads.get(squad_id,{})
		if seen.has(squad_id) or squad_id in existing or row.is_empty() or row.state != "Active" or not row.vehicle.is_empty() or row.get("owner",rear.PLAYER) != hull.owner:
			return _fail("Only distinct active unboarded squads of this hull's army may reserve passenger places.")
		seen[squad_id] = true
		count += row.roster.size()
	if count > int(hull.vehicle_spec.passenger_seats): return _fail("Named roster members exceed actual passenger seats.")
	for squad_id in squad_ids:
		squads[squad_id].vehicle = hull_id
		existing.append(squad_id)
	vehicles[hull_id].passenger_squads = existing
	vehicles[hull_id].passenger_squad = str(existing[0]) if not existing.is_empty() else ""
	return {"ok":true,"message":"Actual squad roster places committed to the same hull."}


func _release_transport_squad(hull_id: String, squad_id: String) -> void:
	if not vehicles.has(hull_id) or not squads.has(squad_id): return
	var existing: Array = _vehicle_squads(hull_id)
	existing.erase(squad_id)
	vehicles[hull_id].passenger_squads = existing
	vehicles[hull_id].passenger_squad = str(existing[0]) if not existing.is_empty() else ""
	squads[squad_id].vehicle = ""


func _vehicle_squads(hull_id: String) -> Array:
	if not vehicles.has(hull_id): return []
	var row: Dictionary = vehicles[hull_id]
	var result: Array = row.get("passenger_squads",[]).duplicate()
	if result.is_empty() and not str(row.get("passenger_squad","")).is_empty(): result.append(row.passenger_squad)
	return result

func _all_reported(row: Dictionary) -> bool:
	for id in row.roster:
		var person: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(id)
		if person.assignment != "Formation Duty" or person.duty_id != row.id: return false
	return true

func _has_reporting() -> bool:
	for row in squads.values():
		if row.state in ["Reporting","Equipping"]: return true
	return false

func _artillery_sources() -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var gun := ""
	var shells: Array[Dictionary] = []
	var needed := 10
	for item in rear.ledger.snapshot().entities:
		if item.owner != rear.PLAYER or item.holder_id not in ["hq-berth","hq-stock"]: continue
		if item.kind == "HEAVY_OBJECT" and item.design_type == "E13" and item.health > 0 and not artillery_guns.has(item.id) and gun.is_empty(): gun = item.id
		elif item.kind == "STOCK" and item.design_type == "E14" and needed > 0:
			var count: int = mini(needed,rear.ledger.available(item.id))
			if count > 0:
				shells.append({"source":item.id,"quantity":count})
				needed -= count
	return {"gun":gun if needed == 0 else "","shells":shells if needed == 0 else []}

func _reserve_artillery(squad_id: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	var sources: Dictionary = _artillery_sources()
	if sources.gun.is_empty(): return {"gun":"","claims":[],"shells":[]}
	var claims: Array[Dictionary] = []
	for source in sources.shells:
		var claim_id := squad_id+"-shell-%d" % claims.size()
		var requested: Dictionary = rear.ledger.request_stock(claim_id,source.source,source.quantity,squad_id,"Issued artillery shell package",rear.PLAYER)
		var claim: Dictionary = rear.ledger.inspect_claim(claim_id)
		if not requested.ok or int(claim.get("reserved",0)) != int(source.quantity):
			for earlier in claims: rear.ledger.release_claim(earlier.id)
			if requested.ok: rear.ledger.release_claim(claim_id)
			return {"gun":"","claims":[],"shells":[]}
		claims.append({"id":claim_id,"source":source.source,"quantity":source.quantity})
	artillery_guns[sources.gun] = squad_id
	return {"gun":sources.gun,"claims":claims,"shells":[]}

func _equip_artillery(row: Dictionary) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var gun: Dictionary = rear.ledger.inspect_entity(row.gun_id)
	if gun.is_empty() or gun.health <= 0:
		row.blocker = "Allocated field gun is absent or destroyed."
		return false
	if gun.holder_id in ["hq-berth","hq-stock"]:
		var moved: Dictionary = rear.ledger.move_field_gun(row.gun_id,"hq-formation",hq_position)
		if not moved.ok:
			row.blocker = moved.message
			return false
	for claim in row.shell_claims.duplicate(true):
		var existing: Dictionary = rear.ledger.inspect_claim(claim.id)
		if existing.is_empty() or int(existing.get("reserved",0)) < int(claim.quantity):
			row.blocker = "Allocated shells are missing from their actual HQ stock claim."
			return false
		var handed: Dictionary = rear.ledger.transfer_stock(claim.source,claim.quantity,"hq-formation",claim.id)
		if not handed.ok:
			row.blocker = handed.message
			return false
		row.shell_ids.append(handed.entity_id)
		rear.ledger.release_claim(claim.id)
		row.shell_claims.erase(claim)
	return true

func _prune_empty_parent(platoon_id: String) -> void:
	if not platoons.has(platoon_id): return
	var platoon: Dictionary = platoons[platoon_id]
	if not platoon.squads.is_empty() or not platoon.vehicles.is_empty(): return
	var company_id: String = platoon.company
	companies[company_id].platoons.erase(platoon_id)
	platoons.erase(platoon_id)
	if companies[company_id].platoons.is_empty() and companies[company_id].service_vehicles.is_empty(): companies.erase(company_id)

func _available_platoon() -> Dictionary:
	for id in platoons:
		if platoons[id].get("owner",_rear_ref.get_ref().PLAYER) == _rear_ref.get_ref().PLAYER and platoons[id].squads.size() < 3: return platoons[id]
	if _owned_count(platoons,_rear_ref.get_ref().PLAYER) >= 9: return {}
	var company_id := ""
	for id in companies:
		if companies[id].get("owner",_rear_ref.get_ref().PLAYER) == _rear_ref.get_ref().PLAYER and companies[id].platoons.size() < 3:
			company_id = id
			break
	if company_id.is_empty():
		if _owned_count(companies,_rear_ref.get_ref().PLAYER) >= 3: return {}
		var company_serial := companies.size()+1
		company_id = "company-%02d" % company_serial
		while companies.has(company_id):
			company_serial += 1
			company_id = "company-%02d" % company_serial
		companies[company_id] = {"id":company_id,"platoons":[],"service_vehicles":[],"leader":"","blocker":"Awaiting an eligible existing subordinate leader."}
	var platoon_serial := platoons.size()+1
	var platoon_id := "platoon-%02d" % platoon_serial
	while platoons.has(platoon_id):
		platoon_serial += 1
		platoon_id = "platoon-%02d" % platoon_serial
	platoons[platoon_id] = {"id":platoon_id,"company":company_id,"squads":[],"vehicles":[],"leader":"","blocker":"Awaiting an eligible existing squad leader."}
	companies[company_id].platoons.append(platoon_id)
	return platoons[platoon_id]

func _appoint_squad(row: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	row.leader = ""
	row.acting = false
	for id in row.roster:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		if p.assignment == "Formation Duty" and p.duty_id == row.id and p.health > 0 and p.basic_training:
			row.leader = id
			rear.ledger.set_formation_appointment(id,"Squad")
			break
	if row.leader.is_empty() and row.kind == "Rifle":
		for id in row.roster:
			var p: Dictionary = rear.ledger.inspect_entity(id)
			if p.assignment == "Formation Duty" and p.duty_id == row.id and p.health > 0:
				row.leader = id
				row.acting = true
				rear.ledger.set_acting_rifle_appointment(id,row.id)
				break
	row.blocker = "Acting conscript leader has no radio or specialist capability." if row.acting else ("No living eligible squad leader." if row.leader.is_empty() else "")
	if not row.leader.is_empty(): row.replacement_attempted = false
	if rear.combat != null: rear.combat.formation_changed(row.id)

func _appoint_seniors() -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var used := {}
	if _commander_id != "initial-hq-05" and rear.ledger.inspect_entity(_commander_id).get("health",0) > 0: used[_commander_id] = true
	for squad in squads.values():
		if not squad.leader.is_empty() and rear.ledger.inspect_entity(squad.leader).get("health",0) > 0:
			rear.ledger.set_formation_appointment(squad.leader,"Squad; Acting Commander" if squad.leader == _commander_id else "Squad")
	for id in platoons:
		var row: Dictionary = platoons[id]
		row.leader = ""
		for squad_id in row.squads:
			var leader: String = squads[squad_id].leader
			var p: Dictionary = rear.ledger.inspect_entity(leader)
			if not p.is_empty() and p.basic_training and p.health > 0 and not used.has(leader):
				row.leader = leader
				used[leader] = true
				rear.ledger.set_formation_appointment(leader,"Squad; Platoon")
				break
		row.blocker = "Senior responsibility delegated upward; trained subordinate leader unavailable." if row.leader.is_empty() else ""
	for id in companies:
		var row: Dictionary = companies[id]
		row.leader = ""
		for platoon_id in row.platoons:
			for squad_id in platoons[platoon_id].squads:
				var leader: String = squads[squad_id].leader
				var p: Dictionary = rear.ledger.inspect_entity(leader)
				if not p.is_empty() and p.basic_training and p.health > 0 and not used.has(leader):
					row.leader = leader
					used[leader] = true
					rear.ledger.set_formation_appointment(leader,"Squad; Company")
					break
			if not row.leader.is_empty(): break
		row.blocker = "Senior responsibility delegated upward; trained subordinate leader unavailable." if row.leader.is_empty() else ""

func _auto_organize() -> bool:
	var ordered: Array[Dictionary] = []
	for demand in demands.values(): ordered.append(demand)
	ordered.sort_custom(_need_before)
	var default_need := ordered.is_empty()
	if default_need: ordered.append({"id":"","kind":"Rifle","reason":"Normal minimum HQ formation","priority":9})
	for need in ordered:
		var kind: String = need.kind
		var people: Array[String] = _candidate_people(kind)
		var result: Dictionary = assess_squad(kind,people)
		if result.ok:
			var formed: Dictionary = form_squad(kind,people)
			if formed.ok:
				if not default_need: demands.erase(need.id)
				return true
		status = "No additional minimum Rifle package in free HQ Reserve." if default_need else "%s blocked: %s" % [kind,result.message]
	return false

func _candidate_people(kind: String) -> Array[String]:
	var rear: RefCounted = _rear_ref.get_ref()
	var ids: Array = rear.dispatch.hq_reserve.keys()
	ids.sort()
	var specialists: Array[String] = []
	var guards: Array[String] = []
	for id in ids:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		if p.is_empty() or p.assignment != "HQ Reserve" or p.holder_id != "hq-reserve" or p.health <= 0 or p.pending_assignment != "None" or rear.hq._target_busy(id): continue
		if kind == "Rifle":
			if p.qualification == "None" and _rifle_ready(id): guards.append(id)
		elif p.qualification == str(SPECIALISTS[kind].keys()[0]): specialists.append(id)
		elif p.basic_training and p.qualification == "None" and _rifle_ready(id): guards.append(id)
	var result: Array[String] = []
	var special_need: int = int(SPECIALISTS[kind].values()[0])
	for id in specialists:
		if result.size() >= special_need: break
		result.append(id)
	for id in guards:
		if result.size() >= 8: break
		result.append(id)
	return result

func _auto_issue_for_need() -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var ordered: Array[Dictionary] = []
	for demand in demands.values(): ordered.append(demand)
	ordered.sort_custom(_need_before)
	for demand in ordered:
		var kind: String = demand.kind
		if kind == "Rifle": continue # G14 issues generic reserve rifles and rounds.
		var candidates: Array[String] = []
		var generic_guards := 0
		var ids: Array = rear.dispatch.hq_reserve.keys()
		ids.sort()
		for id in ids:
			var person: Dictionary = rear.ledger.inspect_entity(id)
			if person.is_empty() or person.assignment != "HQ Reserve" or person.holder_id != "hq-reserve" or person.health <= 0 or not person.basic_training or person.pending_assignment != "None": continue
			if person.qualification == str(SPECIALISTS[kind].keys()[0]): candidates.append(id)
			elif person.qualification == "None": generic_guards += 1
		if candidates.size() < int(SPECIALISTS[kind].values()[0]) or generic_guards < int(MINIMUM[kind])-int(SPECIALISTS[kind].values()[0]): continue
		for plan in _issue_plan(kind):
			var position: int = int(plan.position)
			if position >= candidates.size(): continue
			var target: String = candidates[position]
			var type: String = plan.type
			var quantity: int = int(plan.quantity)
			var held: int = _rounds(target) if type == "E02" else _held(target,type)
			if held >= quantity or rear.hq._target_busy(target): continue
			var requested: Dictionary
			if bool(plan.weapon):
				requested = _issue_weapon(target,type)
			else:
				requested = rear.hq.request_person_stock(target,type,quantity-held)
			if requested.ok:
				status = "HQ command requested actual %s issue to qualified %s for %s." % [type,target,kind]
				return true
			status = "%s issue blocked for %s: %s" % [type,target,requested.message]
	return false

func _need_before(a: Dictionary, b: Dictionary) -> bool:
	if a.priority != b.priority: return a.priority < b.priority
	if a.parent_value != b.parent_value: return a.parent_value > b.parent_value
	if a.since != b.since: return a.since < b.since
	return a.id < b.id

func _immediate_rifle_need() -> bool:
	for need in demands.values():
		if need.kind == "Rifle" and int(need.priority) == 0: return true
	return false

func _issue_weapon(person_id: String, type: String) -> Dictionary:
	var rear: RefCounted = _rear_ref.get_ref()
	for item in rear.ledger.snapshot().entities:
		if item.kind == "WEAPON" and item.design_type == type and item.holder_id == "hq-stock" and item.owner == rear.PLAYER and item.functional and not rear.hq.weapon_promises.has(item.id):
			return rear.hq.request_person_weapon(person_id,item.id)
	return _fail("No actual unpromised %s weapon is unloaded at HQ stock." % type)

func _issue_plan(kind: String) -> Array[Dictionary]:
	match kind:
		"Machine gun": return [{"position":0,"type":"E05","quantity":1,"weapon":true},{"position":0,"type":"E02","quantity":180,"weapon":false}]
		"Mortar": return [{"position":0,"type":"E06","quantity":1,"weapon":true},{"position":1,"type":"E07","quantity":6,"weapon":false},{"position":2,"type":"E18","quantity":1,"weapon":false}]
		"Engineer": return [{"position":0,"type":"E08","quantity":1,"weapon":false},{"position":1,"type":"E08","quantity":1,"weapon":false},{"position":0,"type":"E01","quantity":1,"weapon":true},{"position":1,"type":"E01","quantity":1,"weapon":true},{"position":0,"type":"E02","quantity":30,"weapon":false},{"position":1,"type":"E02","quantity":30,"weapon":false}]
		"Medical": return [{"position":0,"type":"E11","quantity":1,"weapon":false},{"position":0,"type":"E12","quantity":3,"weapon":false},{"position":0,"type":"E21","quantity":1,"weapon":false}]
		"Artillery": return [{"position":0,"type":"E18","quantity":1,"weapon":false}]
		"Reconnaissance": return [{"position":0,"type":"E15","quantity":1,"weapon":false},{"position":0,"type":"E16","quantity":1,"weapon":false},{"position":0,"type":"E17","quantity":1,"weapon":false},{"position":0,"type":"E20","quantity":1,"weapon":false}]
		"Marksman": return [{"position":0,"type":"E19","quantity":1,"weapon":true},{"position":0,"type":"E02","quantity":30,"weapon":false},{"position":0,"type":"E20","quantity":1,"weapon":false}]
	return []

func _package(kind: String, people: Array[String], squad_id: String = "") -> Dictionary:
	if people.size() < int(MINIMUM[kind]): return _fail("%s needs at least %d living, physically assigned people; only %d are active." % [kind,MINIMUM[kind],people.size()])
	var rear: RefCounted = _rear_ref.get_ref()
	var required := {}
	var specialist_ids: Array[String] = []
	var other_ids: Array[String] = []
	var special: String = str(SPECIALISTS[kind].keys()[0])
	for id in people:
		var p: Dictionary = rear.ledger.inspect_entity(id)
		if special != "None" and p.qualification == special: specialist_ids.append(id)
		else: other_ids.append(id)
	if kind != "Rifle" and specialist_ids.size() < int(SPECIALISTS[kind].values()[0]):
		return _fail("%s needs %d living, physically assigned %s specialists; only %d are active." % [kind,SPECIALISTS[kind].values()[0],special,specialist_ids.size()])
	var mandatory_rifles: Array[String] = people if kind in ["Rifle","Engineer"] else other_ids
	if kind != "Rifle" and other_ids.size() < int(MINIMUM[kind])-int(SPECIALISTS[kind].values()[0]):
		return _fail("%s needs actual generic guards alongside its qualified specialists." % kind)
	for id in mandatory_rifles:
		if not _rifle_ready(id): return _fail("%s needs an actually issued E01 and at least 30 matching E02 rounds." % id)
	match kind:
		"Machine gun": required = {"E05":1,"E02":180}
		"Mortar": required = {"E06":1,"E07":6,"E18":1}
		"Engineer": required = {"E08":2}
		"Medical": required = {"E11":1,"E12":3,"E21":1}
		"Artillery": required = {"E13":1,"E14":10,"E18":1}
		"Reconnaissance": required = {"E15":1,"E16":1,"E17":1,"E20":1}
		"Marksman": required = {"E19":1,"E20":1}
	if kind == "Marksman":
		for id in specialist_ids:
			if _held(id,"E19") < 1 or _rounds(id) < 30: return _fail("Marksman specialist needs an issued E19, binoculars and 30 matching rounds.")
	if kind == "Medical" and specialist_ids.size() > 0 and _held(specialist_ids[0],"E11") < 1:
		return _fail("Actual P03 medic must hold the E11 kit.")
	if kind == "Reconnaissance" and specialist_ids.size() > 0 and _held(specialist_ids[0],"E15") < 1:
		return _fail("Actual P06 operator must hold the E15 drone.")
	if kind == "Mortar" and _held_any(specialist_ids,"E06") < 1: return _fail("Actual P04 crew must have the E06 mortar.")
	if kind == "Machine gun" and _held_any(specialist_ids,"E05") < 1: return _fail("Actual P04 crew must have the E05 gun.")
	var equipment := {}
	for type in required:
		var count := _held_any(people,type)
		if kind == "Artillery" and type in ["E13","E14"]: count = _artillery_count(type,squad_id)
		if kind == "Machine gun" and type == "E02": count = _rounds_any(specialist_ids)
		if count < int(required[type]): return _fail("%s minimum package needs %d actual locally issued %s; only %d present." % [kind,required[type],type,count])
		equipment[type] = count
	return {"ok":true,"equipment":equipment}

func _artillery_count(type: String, squad_id: String) -> int:
	var rear: RefCounted = _rear_ref.get_ref()
	if squad_id.is_empty():
		var sources: Dictionary = _artillery_sources()
		return (1 if not sources.gun.is_empty() else 0) if type == "E13" else (10 if not sources.gun.is_empty() else 0)
	var row: Dictionary = squads.get(squad_id,{})
	if row.is_empty(): return 0
	if type == "E13":
		var gun: Dictionary = rear.ledger.inspect_entity(row.gun_id)
		return 1 if not gun.is_empty() and gun.health > 0 and gun.holder_id == "hq-formation" else 0
	var total := 0
	for id in row.shell_ids:
		var shell: Dictionary = rear.ledger.inspect_entity(id)
		if not shell.is_empty() and shell.design_type == "E14" and shell.holder_id == "hq-formation": total += int(shell.quantity)
	return total

func _specialist_ready(kind: String, id: String) -> bool:
	match kind:
		"Machine gun": return _held(id,"E05") > 0
		"Mortar": return _held(id,"E06") > 0 or _held(id,"E07") > 0
		"Engineer": return _held(id,"E08") > 0 and _rifle_ready(id)
		"Medical": return _held(id,"E11") > 0
		"Artillery": return true
		"Reconnaissance": return _held(id,"E15") > 0
		"Marksman": return _held(id,"E19") > 0 and _rounds(id) >= 30
	return false

func _rifle_ready(id: String) -> bool:
	return _held(id,"E01") > 0 and _rounds(id) >= 30

func _held(id: String, type: String) -> int:
	var total := 0
	for item in _rear_ref.get_ref().ledger.entities_at(id,["WEAPON","STOCK","HEAVY_OBJECT"]):
		if item.holder_id == id and item.design_type == type and item.kind in ["WEAPON","STOCK","HEAVY_OBJECT"]: total += item.quantity
	return total

func _held_any(ids: Array[String], type: String) -> int:
	var total := 0
	for id in ids: total += _held(id,type)
	return total

func _rounds(id: String) -> int:
	var total := _held(id,"E02")
	var rear: RefCounted = _rear_ref.get_ref()
	for item in rear.ledger.entities_at(id,["WEAPON"]):
			if item.kind == "WEAPON" and item.holder_id == id and item.design_type in ["E01","E05","E19"]: total += int(item.loaded_rounds)
	return total

func _rounds_any(ids: Array[String]) -> int:
	var total := 0
	for id in ids: total += _rounds(id)
	return total

func _at_berth(type: String) -> int:
	var total := 0
	for item in _rear_ref.get_ref().ledger.snapshot().entities:
		if item.design_type == type and item.holder_id == "hq-berth" and item.owner == _rear_ref.get_ref().PLAYER: total += item.quantity
	return total

func snapshot(owner: String = "") -> Dictionary:
	var rows: Array[Dictionary] = []
	for row in squads.values():
		if not owner.is_empty() and row.get("owner",_rear_ref.get_ref().PLAYER) != owner: continue
		var copy: Dictionary = row.duplicate(true)
		copy.readiness = readiness(row.id)
		rows.append(copy)
	var company_rows: Dictionary = companies.duplicate(true)
	var platoon_rows: Dictionary = platoons.duplicate(true)
	var vehicle_rows: Dictionary = vehicles.duplicate(true)
	if not owner.is_empty():
		for id in company_rows.keys():
			if company_rows[id].get("owner",_rear_ref.get_ref().PLAYER) != owner: company_rows.erase(id)
		for id in platoon_rows.keys():
			if platoon_rows[id].get("owner",_rear_ref.get_ref().PLAYER) != owner: platoon_rows.erase(id)
		for id in vehicle_rows.keys():
			if vehicle_rows[id].get("owner",_rear_ref.get_ref().PLAYER) != owner: vehicle_rows.erase(id)
	return {"companies":company_rows,"platoons":platoon_rows,"squads":rows,
		"vehicles":vehicle_rows,"demands":demands.duplicate(true) if owner.is_empty() or owner == _rear_ref.get_ref().PLAYER else {},
		"status":status if owner.is_empty() else "Army command and physical formations active.",
		"shortages":shortages(owner),"troop_transport":troop_transport.snapshot(owner),
		"commander":commander(),"military_people":_rear_ref.get_ref().dispatch.military_people.size(),
		"reserve":_rear_ref.get_ref().dispatch.hq_reserve.size()}

func shortages(owner: String = "") -> Array[String]:
	var result: Array[String] = []
	if owner.is_empty() or owner == _rear_ref.get_ref().PLAYER:
		for demand in demands.values():
			var assessment: Dictionary = assess_squad(demand.kind,_candidate_people(demand.kind))
			if not assessment.ok: result.append("%s: %s" % [demand.kind,assessment.message])
	for row in squads.values():
		if not owner.is_empty() and row.get("owner",_rear_ref.get_ref().PLAYER) != owner: continue
		if row.state in ["Reporting","Equipping"]: result.append("%s: %s" % [row.id,row.blocker])
		elif row.state == "Active" and row.vehicle.is_empty():
			var readiness_result: Dictionary = capability(row.id)
			if not readiness_result.ok: result.append("%s: %s" % [row.id,readiness_result.message])
	for row in platoons.values():
		if not owner.is_empty() and row.get("owner",_rear_ref.get_ref().PLAYER) != owner: continue
		if row.leader.is_empty(): result.append("%s: %s" % [row.id,row.blocker])
	for row in companies.values():
		if not owner.is_empty() and row.get("owner",_rear_ref.get_ref().PLAYER) != owner: continue
		if row.leader.is_empty(): result.append("%s: %s" % [row.id,row.blocker])
	if owner.is_empty() or owner == _rear_ref.get_ref().PLAYER:
		for hull_id in _rear_ref.get_ref().dispatch.military_hulls:
			var hull: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(hull_id)
			if hull.is_empty() or not hull.has("vehicle_spec"): continue
			for station in hull.vehicle_spec.stations:
				if _living_crew_id(hull,station).is_empty(): result.append("%s: missing living, assigned %s crew" % [hull_id,station])
			if not vehicles.has(hull_id) and hull.crew_by_station.has("Driver"): result.append("%s: no free platoon or company vehicle place" % hull_id)
	return result

func readiness(id: String) -> float:
	var row: Dictionary = squads.get(id,{})
	if row.is_empty() or row.state != "Active": return 0.0
	var active: Array[String] = _active_roster_members(row,true)
	var equipment := 1.0
	var ammunition := 1.0
	var desired: Dictionary = _desired_equipment(row.kind)
	for type in desired:
		var amount: int = _held_any(active,type)
		if row.kind == "Artillery" and type == "E13": amount = _artillery_count(type,id)
		equipment = minf(equipment,float(amount)/float(desired[type]))
	var rifle_carriers: Array[String] = []
	for person_id in active:
		if _held(person_id,"E01") > 0 or _held(person_id,"E19") > 0: rifle_carriers.append(person_id)
	var personal_target := 30 if row.kind in ["Engineer","Medical","Reconnaissance"] else 60
	for person_id in rifle_carriers: ammunition = minf(ammunition,float(_rounds(person_id))/float(personal_target))
	if row.kind == "Rifle":
		ammunition = minf(ammunition,float(rifle_carriers.size())/8.0)
	elif row.kind == "Machine gun":
		var specialists: Array[String] = _roster_specialists(row,active)
		ammunition = minf(ammunition,float(_rounds_any(specialists))/360.0)
	elif row.kind == "Mortar": ammunition = minf(ammunition,float(_held_any(active,"E07"))/12.0)
	elif row.kind == "Artillery": ammunition = minf(ammunition,float(_artillery_count("E14",id))/20.0)
	return clampf(minf(minf(float(active.size())/8.0,equipment),ammunition),0.0,1.0)

func capability(id: String) -> Dictionary:
	var row: Dictionary = squads.get(id,{})
	if row.is_empty() or row.state != "Active": return _fail("Only a physically reported active squad has capability.")
	if not row.vehicle.is_empty(): return _fail("Mounted passengers cannot provide dismounted fire or capture until actual exit.")
	var active: Array[String] = _active_roster_members(row)
	if row.leader.is_empty() or row.leader not in active: return _fail("Squad has no living, physically assigned leader during replacement delay.")
	var leader: Dictionary = _rear_ref.get_ref().ledger.inspect_entity(row.leader)
	if not leader.basic_training and not (row.kind == "Rifle" and row.acting): return _fail("Squad leader lacks the required training or Rifle acting exception.")
	var package: Dictionary = _package(row.kind,active,id)
	if not package.ok: return package
	return {"ok":true,"message":"Type minimum, actual local package and leader permit this squad's G15 role."}

func _active_roster_members(row: Dictionary, include_boarded: bool = false) -> Array[String]:
	var rear: RefCounted = _rear_ref.get_ref()
	var active: Array[String] = []
	for id in row.roster:
		var person: Dictionary = rear.ledger.inspect_person_status(id)
		if person.is_empty() or person.health <= 0 or person.assignment != "Formation Duty" or person.duty_id != row.id or not person.crew_station.is_empty(): continue
		var holder: String = rear.ledger.entity_kind(person.holder_id)
		if holder.is_empty() or (holder == "CARRIER" and (not include_boarded or person.holder_id != row.vehicle)): continue
		active.append(id)
	return active

func _desired_equipment(kind: String) -> Dictionary:
	match kind:
		"Rifle": return {"E01":8}
		"Machine gun": return {"E05":1,"E01":6}
		"Mortar": return {"E06":1,"E18":1,"E01":5}
		"Engineer": return {"E08":2,"E01":8}
		"Medical": return {"E11":2,"E12":12,"E21":2,"E01":6}
		"Artillery": return {"E13":1,"E18":1,"E01":4}
		"Reconnaissance": return {"E15":1,"E16":1,"E17":3,"E20":1,"E01":6}
		"Marksman": return {"E19":2,"E20":2,"E01":6}
	return {}

func _roster_specialists(row: Dictionary, active: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var code: String = str(SPECIALISTS[row.kind].keys()[0])
	for id in active:
		if _rear_ref.get_ref().ledger.inspect_entity(id).qualification == code: result.append(id)
	return result

func commander() -> String:
	var rear: RefCounted = _rear_ref.get_ref()
	var appointed: Dictionary = rear.ledger.inspect_entity(_commander_id)
	if not appointed.is_empty() and appointed.health > 0: return appointed.id
	var original: Dictionary = rear.ledger.inspect_entity("initial-hq-05")
	if not original.is_empty() and original.health > 0: return original.id
	for company in companies.values():
		if company.get("owner",rear.PLAYER) != rear.PLAYER: continue
		var p: Dictionary = rear.ledger.inspect_entity(company.leader)
		if not p.is_empty() and p.health > 0 and p.basic_training: return p.id
	for platoon in platoons.values():
		if platoon.get("owner",rear.PLAYER) != rear.PLAYER: continue
		var p: Dictionary = rear.ledger.inspect_entity(platoon.leader)
		if not p.is_empty() and p.health > 0 and p.basic_training: return p.id
	return ""

func audit() -> Array[String]:
	var errors: Array[String] = troop_transport.audit()
	var rear: RefCounted = _rear_ref.get_ref()
	for owner in ["army-blue","army-red"]:
		if _owned_count(companies,owner) > 3 or _owned_count(platoons,owner) > 9 or _owned_count(squads,owner) > 27 or _owned_count(vehicles,owner) > 24: errors.append("G15 army organizational cap exceeded: " + owner)
	var seen := {}
	for row in squads.values():
		if row.roster.size() > 8: errors.append("Overfull G15 squad "+row.id)
		if not platoons.has(row.platoon) or not companies.has(row.company) or (platoons.has(row.platoon) and (platoons[row.platoon].company != row.company or row.id not in platoons[row.platoon].squads)): errors.append("G15 squad has no consistent real parent: "+row.id)
		if not row.leader.is_empty() and row.leader not in row.roster: errors.append("G15 leader is outside its real squad: "+row.id)
		if row.kind == "Artillery" and (row.gun_id.is_empty() or artillery_guns.get(row.gun_id,"") != row.id): errors.append("G15 artillery lacks exclusive gun allocation: "+row.id)
		for id in row.roster:
			if seen.has(id): errors.append("Person in two G15 squads: "+id)
			seen[id] = true
			var p: Dictionary = rear.ledger.inspect_entity(id)
			if row.state == "Active" and (p.is_empty() or p.duty_id != row.id or p.assignment not in ["Formation Duty","Wounded","Recovery"]): errors.append("Active G15 roster lacks real duty: "+id)
		if not row.vehicle.is_empty():
			if not vehicles.has(row.vehicle) or row.id not in _vehicle_squads(row.vehicle): errors.append("G15 passenger squad lacks matching vehicle element: "+row.id)
	for row in platoons.values():
		if row.squads.size() > 3 or row.vehicles.size() > 2: errors.append("Overfull G15 platoon "+row.id)
		if not companies.has(row.company) or (companies.has(row.company) and row.id not in companies[row.company].platoons): errors.append("G15 platoon has no consistent company: "+row.id)
	for row in companies.values():
		if row.platoons.size() > 3 or row.service_vehicles.size() > 2: errors.append("Overfull G15 company "+row.id)
	var senior_seen := {}
	for row in platoons.values():
		if row.leader.is_empty(): continue
		if senior_seen.has(row.leader): errors.append("G15 person holds two senior appointments: "+row.leader)
		senior_seen[row.leader] = true
	for row in companies.values():
		if row.leader.is_empty(): continue
		if senior_seen.has(row.leader): errors.append("G15 person holds two senior appointments: "+row.leader)
		senior_seen[row.leader] = true
	for row in vehicles.values():
		var hull: Dictionary = rear.ledger.inspect_entity(row.id)
		if hull.is_empty() or hull.fleet_domain != "Military": errors.append("G15 vehicle element lacks real military hull: "+row.id)
		for squad_id in _vehicle_squads(row.id):
			if not squads.has(squad_id) or squads[squad_id].vehicle != row.id or squads[squad_id].get("owner",rear.PLAYER) != row.get("owner",rear.PLAYER):
				errors.append("G15 passenger manifest lacks matching owned squad: "+row.id+":"+str(squad_id))
		if platoons.has(row.parent):
			if row.id not in platoons[row.parent].vehicles: errors.append("G15 hull missing from parent platoon: "+row.id)
		elif companies.has(row.parent):
			if row.id not in companies[row.parent].service_vehicles: errors.append("G15 hull missing from parent company: "+row.id)
		else: errors.append("G15 hull has no real parent: "+row.id)
		if not hull.is_empty():
			for station in hull.crew_by_station:
				var person: Dictionary = rear.ledger.inspect_entity(hull.crew_by_station[station])
				# Incapacitation does not physically vacate a station; operational crew
				# eligibility remains the stricter _living_crew_id contract.
				if person.is_empty() or person.crew_station != station or person.holder_id != row.id or person.assignment not in ["Formation Duty","Wounded","Recovery","Dead"]: errors.append("G15 crew station lacks same qualified person: "+row.id+":"+station)
			for person_id in hull.passengers:
				if hull.crew_by_station.values().has(person_id): errors.append("G15 person is both crew and passenger: "+person_id)
	return errors

func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func _owned_count(rows: Dictionary, owner: String) -> int:
	var count := 0
	for row in rows.values():
		if row.get("owner",_rear_ref.get_ref().PLAYER) == owner: count += 1
	return count
