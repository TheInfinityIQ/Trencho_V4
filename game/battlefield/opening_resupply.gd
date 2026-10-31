extends RefCounted
## Local military issue for this opening; all movement/stock stays in ForwardSupply.
const TRIGGER := 30
const TARGET := 60
const RACK_TARGET := 180
var _rear_ref: WeakRef
var rifle_squads: Array
var engineer_squad: String
var stop_id: String
var requests: Dictionary = {}
var owned_jobs: Dictionary = {}
var status := "Waiting for actual local ammunition need."
var rack_requests: Dictionary = {}
var rack_status := "Waiting for an initially empty local T04 rack."
var _rack_seen: Dictionary = {}
var _rack_jobs: Dictionary = {} # Owned job -> already credited physical deposits.
var _rack_supplied: Dictionary = {}
var _rack_replenishments: Dictionary = {}
var _rack_cycle_keys: Dictionary = {} # Hull -> accepted keys, including closed cycles.
var _squad_replenishments: Dictionary = {}
var _squad_cycle_keys: Dictionary = {}

func _init(rear: RefCounted, rifles: Array, engineers: String, stop: String) -> void:
	_rear_ref = weakref(rear)
	rifle_squads = rifles.duplicate()
	engineer_squad = engineers
	stop_id = stop

func request_squad_replenishment(squad_id: String, cycle_key: String, target: int = 60) -> Dictionary:
	if cycle_key.is_empty(): return {"ok":false,"message":"Squad replenishment needs a named cycle."}
	var previous: Dictionary = _squad_replenishments.get(squad_id,{})
	if _squad_cycle_keys.get(squad_id,{}).has(cycle_key):
		if not previous.is_empty() and previous.cycle == cycle_key and previous.interrupted and not previous.released:
			var resume_error: String = _squad_basis_error(previous)
			if not resume_error.is_empty(): return {"ok":false,"message":resume_error}
			previous.interrupted = false
			_seed_squad(previous)
		return {"ok":true,"squad":squad_id,"cycle":cycle_key,"message":"Existing squad cycle retained; no duplicate issue work created."}
	if target <= 0: return {"ok":false,"message":"A squad refill needs a positive actual-round target."}
	if not previous.is_empty() and (_squad_pending(previous,_squad_members(previous)) or (not previous.released and _squad_basis_error(previous).is_empty())):
		return {"ok":false,"message":"The current squad cycle or its physical handling is still unresolved."}
	var rear: RefCounted = _rear_ref.get_ref()
	var squad: Dictionary = rear.military.squads.get(squad_id,{})
	var row := {"squad":squad_id,"cycle":cycle_key,"target":target,"owner":rear.PLAYER,
		"parent":str(squad.get("platoon","")),"interrupted":false,"released":false,"jobs":[],"blockers":{},"seeded":{}}
	var error: String = _squad_basis_error(row)
	if not error.is_empty(): return {"ok":false,"message":error}
	_squad_replenishments[squad_id] = row
	if not _squad_cycle_keys.has(squad_id): _squad_cycle_keys[squad_id] = {}
	_squad_cycle_keys[squad_id][cycle_key] = true
	_seed_squad(row)
	return {"ok":true,"squad":squad_id,"cycle":cycle_key,"message":"Named squad refill requested through the existing local issue owner."}

func interrupt_squad_replenishment(squad_id: String, cycle_key: String) -> Dictionary:
	var row: Dictionary = _squad_replenishments.get(squad_id,{})
	if row.is_empty() or row.cycle != cycle_key: return {"ok":false,"message":"Only the exact current squad cycle can be interrupted."}
	if row.released: return {"ok":false,"message":"This squad cycle was already handed off."}
	row.interrupted = true
	_interrupt_squad_jobs(row)
	return {"ok":true,"squad":squad_id,"cycle":cycle_key,"message":"Squad collection interrupted; actual courier goods and claims retain their owners."}

func release_squad_replenishment(squad_id: String, cycle_key: String) -> Dictionary:
	var row: Dictionary = _squad_replenishments.get(squad_id,{})
	if row.is_empty() or row.cycle != cycle_key: return {"ok":false,"message":"Only the exact current squad cycle can be handed off."}
	if row.released: return {"ok":true,"squad":squad_id,"cycle":cycle_key,"message":"Squad cycle already handed off."}
	var current: Dictionary = squad_replenishment_status(squad_id)
	if current.state != "Complete" or not current.handling_clear: return {"ok":false,"message":"Every eligible carrier must reach its actual target with physical handling clear before handoff."}
	row.released = true
	_retire_squad_requests(row,true)
	return {"ok":true,"squad":squad_id,"cycle":cycle_key,"message":"Completed squad refill handed off; normal operation may resume under its owner."}

func squad_replenishment_status(squad_id: String) -> Dictionary:
	var row: Dictionary = _squad_replenishments.get(squad_id,{})
	if row.is_empty(): return {}
	var rear: RefCounted = _rear_ref.get_ref()
	var stop: Dictionary = rear.ledger.inspect_entity(stop_id,{},false)
	var eligible: Array[String] = _squad_members(row)
	var people: Array[Dictionary] = []
	var needed := 0
	var committed := 0
	var all_equipped: bool = not eligible.is_empty()
	var all_at_stop: bool = not eligible.is_empty()
	var blocker := ""
	for id in eligible:
		var person: Dictionary = rear.ledger.inspect_person_status(id)
		var rounds: int = rear.military._rounds(id)
		var deficit: int = maxi(0,int(row.target)-rounds)
		var pending: int = _committed(id)
		var has_rifle: bool = _squad_has_rifle(id)
		var at_stop: bool = stop.get("kind","") == "PLACE" and _at_stop(person,stop)
		var reason := ""
		if not has_rifle: reason = "Actual functional rifle is missing; ammunition alone does not restore this carrier."
		elif deficit > 0 and not at_stop: reason = "Carrier must physically reach the local supply rendezvous."
		elif pending > 0: reason = _person_issue_blocker(id)
		elif not _free(id): reason = "Existing physical movement or handling must finish."
		elif deficit > 0: reason = str(row.blockers.get(id,"Waiting for actual local E02 and an eligible Engineer courier."))
		needed += deficit
		committed += pending
		all_equipped = all_equipped and has_rifle
		all_at_stop = all_at_stop and at_stop
		if blocker.is_empty() and not reason.is_empty(): blocker = reason
		people.append({"person":id,"rounds":rounds,"target":row.target,"needed":deficit,"committed":pending,"has_rifle":has_rifle,"at_stop":at_stop,"blocker":reason})
	var handling_clear: bool = not _squad_pending(row,eligible)
	for id in eligible:
		if not _free(id): handling_clear = false
	var state := "Pending"
	var basis_error: String = _squad_basis_error(row)
	if row.interrupted:
		state = "Interrupted"
		blocker = basis_error if not basis_error.is_empty() else "Collection is interrupted; retained courier work requires the same cycle or explicit physical resolution."
	elif not basis_error.is_empty(): state = "Blocked"; blocker = basis_error
	elif row.released: state = "Closed"; blocker = "Squad refill handed off; later collection requires a new named cycle."
	elif eligible.is_empty(): state = "Blocked"; blocker = "No current eligible living Rifle carriers remain; no refill is credited."
	elif not all_equipped: state = "Blocked"
	elif needed == 0 and handling_clear: state = "Complete"; blocker = ""
	elif not handling_clear:
		state = "Handling"
		if blocker.is_empty(): blocker = "Original courier work remains unresolved, including work for members no longer eligible."
	elif not all_at_stop: state = "Collecting"
	var available := 0
	for stock in rear.ledger.entities_at(stop_id,["STOCK"],false):
		if stock.owner == row.owner and stock.design_type == "E02" and stock.available > 0: available += int(stock.available)
	return {"squad":squad_id,"cycle":row.cycle,"state":state,"stop":stop_id,"target":row.target,"eligible":eligible,"people":people,
		"needed":needed,"committed":committed,"handling_clear":handling_clear,"at_stop":all_at_stop,"available_at_stop":available,"blocker":blocker,"released":row.released}

func _squad_members(row: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var rear: RefCounted = _rear_ref.get_ref()
	for id in rear.military.squads.get(row.squad,{}).get("roster",[]):
		var person: Dictionary = rear.ledger.inspect_person_status(id)
		if person.get("owner","") == row.owner and person.get("assignment","") == "Formation Duty" and person.get("health",0) > 0 and person.get("duty_id","") == row.squad:
			result.append(id)
	return result

func _squad_basis_error(row: Dictionary) -> String:
	var rear: RefCounted = _rear_ref.get_ref()
	var squad: Dictionary = rear.military.squads.get(row.squad,{})
	if row.squad not in rifle_squads or squad.get("kind","") != "Rifle" or squad.get("state","") != "Active" or squad.get("owner",rear.PLAYER) != row.owner or row.owner != rear.PLAYER:
		return "The original active own Rifle squad is unavailable to this collection cycle."
	var parent: Dictionary = rear.military.platoons.get(row.parent,{})
	if squad.get("platoon","") != row.parent or parent.get("owner",rear.PLAYER) != row.owner or parent.is_empty():
		return "Squad parent or ownership changed; this collection cannot automatically reparent."
	if rear.ledger.entity_kind(stop_id) != "PLACE" or not rear.forward_supply.delivery_stops.has(stop_id): return "The declared local squad supply stop is unavailable."
	return ""

func _squad_has_rifle(id: String) -> bool:
	for weapon in _rear_ref.get_ref().ledger.entities_at(id,["WEAPON"],false):
		if weapon.design_type == "E01" and weapon.functional and weapon.ammo_type == "E02": return true
	return false

func _person_issue_pending(job: Dictionary) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if rear.ledger.inspect_claim(job.claim).get("reserved",0) > 0: return true
	var carry: Dictionary = rear.ledger.inspect_entity(str(job.get("carried_stock","")),{},false)
	if carry.get("holder_id","") == job.handler and carry.get("quantity",0) > 0: return true
	return job.state not in ["Complete","Interrupted"]

func _person_issue_blocker(id: String) -> String:
	for job in _rear_ref.get_ref().forward_supply.jobs.values():
		if job.recipient == id and job.type == "E02" and _person_issue_pending(job):
			if not str(job.blocker).is_empty(): return str(job.blocker)
	return "Existing courier allocation must arrive physically; pending rounds are not carried rounds."

func _squad_pending(row: Dictionary, eligible: Array[String]) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	for job_id in row.jobs:
		if not rear.forward_supply.jobs.has(job_id): return true
	for job in rear.forward_supply.jobs.values():
		if (job.id in row.jobs or job.recipient in eligible or job.handler in eligible) and _person_issue_pending(job): return true
	return false

func _named_person_request(id: String) -> Dictionary:
	var person: Dictionary = _rear_ref.get_ref().ledger.inspect_person_status(id)
	var row: Dictionary = _squad_replenishments.get(str(person.get("duty_id","")),{})
	return row if not row.is_empty() and id in _squad_members(row) else {}

func _named_job_request(job_id: String) -> Dictionary:
	for row in _squad_replenishments.values():
		if job_id in row.jobs: return row
	return {}

func _seed_squad(row: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var members: Array[String] = _squad_members(row)
	_retire_squad_requests(row)
	for job_id in owned_jobs:
		var job: Dictionary = rear.forward_supply.jobs.get(job_id,{})
		if not job.is_empty() and job.recipient in members and _person_issue_pending(job) and job_id not in row.jobs: row.jobs.append(job_id)
	for id in members:
		if _squad_has_rifle(id) and rear.military._rounds(id) < int(row.target):
			if not row.seeded.has(id): row.seeded[id] = int(requests.get(id,0))
			requests[id] = maxi(int(requests.get(id,0)),int(row.target))

func _retire_squad_requests(row: Dictionary, all_members: bool = false) -> void:
	var members: Array[String] = [] if all_members else _squad_members(row)
	for id in row.seeded.keys():
		if id in members: continue
		# Retire only our unchanged target, preserving an earlier independent need.
		if int(requests.get(id,0)) == int(row.target):
			var prior: int = int(row.seeded[id])
			if prior > 0 and _rear_ref.get_ref().military._rounds(id) < prior: requests[id] = prior
			else: requests.erase(id)
		row.seeded.erase(id)

func _interrupt_squad_jobs(row: Dictionary) -> void:
	for job_id in row.jobs:
		var job: Dictionary = _rear_ref.get_ref().forward_supply.jobs.get(job_id,{})
		if not job.is_empty() and job.state not in ["Complete","Interrupted","Interrupted Carry"]: _rear_ref.get_ref().forward_supply.interrupt(job_id)

func _tick_squad_requests() -> void:
	for row in _squad_replenishments.values():
		if row.interrupted or not _squad_basis_error(row).is_empty():
			_retire_squad_requests(row)
			_interrupt_squad_jobs(row)
		elif not row.released: _seed_squad(row)

func _person_status(id: String, message: String) -> void:
	status = message
	var row: Dictionary = _named_person_request(id)
	if not row.is_empty() and not row.released: row.blockers[id] = message

func request_rack_replenishment(hull_id: String, cycle_key: String, target: int = 180) -> Dictionary:
	if cycle_key.is_empty(): return {"ok":false,"message":"Rack replenishment needs a named cycle."}
	if _rack_cycle_keys.get(hull_id,{}).has(cycle_key):
		return {"ok":true,"hull":hull_id,"cycle":cycle_key,"message":"Existing cycle retained; no duplicate rack work created."}
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id,{},false)
	var stop: Dictionary = rear.ledger.inspect_entity(stop_id,{},false)
	var previous: Dictionary = _rack_replenishments.get(hull_id,{})
	if not previous.is_empty():
		var current: Dictionary = rack_replenishment_status(hull_id)
		var obsolete: bool = not _replenishment_error(previous,hull,stop).is_empty()
		if _replenishment_pending(previous) or (not obsolete and (not previous.completed or not previous.released or current.committed > 0)):
			return {"ok":false,"message":"The existing rack cycle or its physical courier work is still unresolved."}
	var attachment: Dictionary = rear.military.vehicles.get(hull_id,{})
	var row := {"hull":hull_id,"cycle":cycle_key,"target":target,"owner":rear.PLAYER,"parent":str(attachment.get("parent","")),
		"state":"Pending","blocker":"Waiting for the same APC at its local supply stop.","completed":false,"released":false,"jobs":[]}
	var error: String = _replenishment_error(row,hull,stop)
	if not error.is_empty(): return {"ok":false,"message":error}
	if target <= 0 or target > int(hull.vehicle_spec.rack_capacity.get("E26",0)):
		return {"ok":false,"message":"Rack target must be positive and within this APC's actual E26 capacity."}
	_rack_replenishments[hull_id] = row
	if not _rack_cycle_keys.has(hull_id): _rack_cycle_keys[hull_id] = {}
	_rack_cycle_keys[hull_id][cycle_key] = true
	return {"ok":true,"hull":hull_id,"cycle":cycle_key,"message":"Named current-deficit rack replenishment requested."}

func release_rack_replenishment(hull_id: String, cycle_key: String) -> Dictionary:
	# The deployment owner calls this only after real Support movement admission.
	# Its new movement commitment is allowed; this releases bookkeeping, not goods.
	var row: Dictionary = _rack_replenishments.get(hull_id,{})
	if row.is_empty() or row.cycle != cycle_key: return {"ok":false,"message":"Only the exact current rack cycle can be handed off."}
	if row.released: return {"ok":true,"hull":hull_id,"cycle":cycle_key,"message":"This rack cycle was already handed off."}
	var current: Dictionary = rack_replenishment_status(hull_id)
	if current.state != "Complete" or current.aboard < row.target or current.committed > 0 or _replenishment_pending(row):
		return {"ok":false,"message":"Actual rack target and all physical courier work must be complete before handoff."}
	row.completed = true
	row.released = true
	return {"ok":true,"hull":hull_id,"cycle":cycle_key,"message":"Completed rack cycle handed off; later consumption requires a new named cycle."}

func rack_replenishment_status(hull_id: String) -> Dictionary:
	var row: Dictionary = _rack_replenishments.get(hull_id,{})
	if row.is_empty(): return {}
	var rear: RefCounted = _rear_ref.get_ref()
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id,{},false)
	var aboard: int = int(hull.get("ammunition",{}).get("E26",0))
	var needed: int = maxi(0,int(row.target)-aboard)
	var committed: int = _rack_committed(hull_id)
	var state: String = row.state
	var blocker: String = row.blocker
	var error: String = _replenishment_error(row,hull,rear.ledger.inspect_entity(stop_id,{},false))
	if not error.is_empty(): state = "Blocked"; blocker = error
	elif needed == 0 and committed == 0 and not _replenishment_pending(row): state = "Complete"; blocker = ""
	elif row.released:
		state = "Closed"
		blocker = "Prior refill handed off; another current deficit requires a new named cycle." if needed > 0 else "Prior refill handed off; other physical rack courier work must clear."
	elif state == "Complete":
		state = "Pending"
		blocker = "Current refill remains open; actual rack needs %d more rounds before departure." % needed
	return {"state":state,"cycle":row.cycle,"hull":hull_id,"aboard":aboard,"target":row.target,"needed":needed,
		"committed":committed,"available_at_stop":_replenishment_available(),"stop":stop_id,"blocker":blocker,"released":row.released}

func tick() -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var stop: Dictionary = rear.ledger.inspect_entity(stop_id)
	_tick_squad_requests()
	if stop.get("kind","") != "PLACE": _tick_replenishments(stop); return
	_tick_racks(stop)
	_tick_replenishments(stop)
	for job_id in owned_jobs.keys():
		var job: Dictionary = rear.forward_supply.jobs.get(job_id,{})
		if job.is_empty() or job.state in ["Complete","Interrupted"]: owned_jobs.erase(job_id); continue
		var named: Dictionary = _named_job_request(job_id)
		if not named.is_empty() and (named.interrupted or not _squad_basis_error(named).is_empty() or job.recipient not in _squad_members(named)):
			if job.state != "Interrupted Carry": rear.forward_supply.interrupt(job_id)
			continue
		var current_recipient: Dictionary = rear.ledger.inspect_entity(job.recipient)
		if not _safe(str(current_recipient.get("duty_id","")),stop.position):
			if job.state != "Interrupted Carry": rear.forward_supply.interrupt(job_id)
			status = "Delivered hostile fire stopped the local courier task."
			continue
		if job.state != "Interrupted Carry": continue
		var recipient: Dictionary = rear.ledger.inspect_entity(job.recipient)
		var handler: Dictionary = rear.ledger.inspect_entity(job.handler)
		if not _at_stop(recipient,stop) or not _at_stop(handler,stop) or not _safe(recipient.duty_id,stop.position): continue
		# Resume owns the same existing carried portion. Its own admission checks
		# deliberately allow that courier's existing handoff commitment.
		var resumed: Dictionary = rear.forward_supply.resume_issue(job_id)
		status = "Same Engineer courier resumes the existing carried portion." if resumed.ok else resumed.message
	for squad_id in rifle_squads:
		var squad: Dictionary = rear.military.squads.get(squad_id,{})
		if squad.is_empty() or squad.get("owner",rear.PLAYER) != rear.PLAYER: continue
		for id in rear.military._active_roster_members(squad):
			if rear.military._rounds(id) < TRIGGER and not requests.has(id): requests[id] = TARGET
	for id in requests.keys():
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if person.get("owner","") != rear.PLAYER or person.get("assignment","") != "Formation Duty" or person.get("health",0) <= 0:
			requests.erase(id)
			continue
		var named: Dictionary = _named_person_request(id)
		if not named.is_empty() and not named.released:
			if named.interrupted or not _squad_basis_error(named).is_empty(): continue
			if not _squad_has_rifle(id): _person_status(id,"Actual functional rifle must be restored before this named refill."); continue
		var needed: int = int(requests[id])-rear.military._rounds(id)
		if needed <= 0: requests.erase(id); continue
		needed -= _committed(id)
		if needed <= 0: _person_status(id,"Actual couriers are carrying the committed deficit."); continue
		if not _at_stop(person,stop) or not _free(id): _person_status(id,"Waiting for the named rifle member at the local supply rendezvous."); continue
		if not _safe(person.duty_id,stop.position): _person_status(id,"Delivered hostile fire blocks safe local receipt."); continue
		var source := ""
		for stock in rear.ledger.entities_at(stop_id,["STOCK"]):
			if stock.owner == rear.PLAYER and stock.design_type == "E02" and stock.available > 0: source = stock.id; break
		if source.is_empty(): _person_status(id,"Local E02 is missing; manufacture and physically deliver freight."); continue
		var engineers: Dictionary = rear.military.squads.get(engineer_squad,{})
		if engineers.is_empty(): _person_status(id,"The actual Engineer courier element is unavailable."); continue
		var started := false
		var refusal := ""
		for handler_id in rear.military._active_roster_members(engineers):
			if handler_id == id or not _free(handler_id): continue
			var handler: Dictionary = rear.ledger.inspect_entity(handler_id)
			if not _at_stop(handler,stop): continue
			var stock: Dictionary = rear.ledger.inspect_entity(source)
			var amount: int = mini(needed,int(stock.available))
			amount = mini(amount,int(floorf((25.0-float(handler.contents_mass_kg))/float(stock.unit_mass_kg))))
			amount = mini(amount,int(floorf((25.0-float(person.contents_mass_kg))/float(stock.unit_mass_kg))))
			if amount <= 0: continue
			var issued: Dictionary = rear.forward_supply.start_issue(source,id,handler_id,amount,stop_id)
			if issued.ok:
				owned_jobs[issued.id] = true
				if not named.is_empty() and not named.released: named.jobs.append(issued.id)
				_person_status(id,"Engineer courier collecting actual E02 for a depleted Rifle member.")
				started = true
				break
			refusal = issued.message
		if not started: _person_status(id,refusal if not refusal.is_empty() else "Waiting for an eligible local Engineer courier and carry capacity.")

func _tick_racks(stop: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	for job_id in _rack_jobs.keys():
		var job: Dictionary = rear.forward_supply.rack_issue.jobs.get(job_id,{})
		if job.is_empty(): _rack_jobs.erase(job_id); continue
		_rack_supplied[job.hull] = int(_rack_supplied.get(job.hull,0))+int(job.issued)-int(_rack_jobs[job_id])
		_rack_jobs[job_id] = int(job.issued)
		if job.state in ["Complete","Interrupted"]: _rack_jobs.erase(job_id); continue
		var parent: String = str(rear.military.vehicles.get(job.hull,{}).get("parent",""))
		if not _safe(parent,stop.position):
			if job.state != "Interrupted Carry": rear.forward_supply.rack_issue.interrupt(job_id)
			rack_status = "Delivered hostile fire stopped the local rack courier."
			continue
		if job.state == "Interrupted Carry":
			var resumed: Dictionary = rear.forward_supply.rack_issue.resume(job_id)
			rack_status = "Same Engineer resumes the existing E26 portion." if resumed.ok else resumed.message
	for id in rear.military.vehicles:
		if _rack_seen.has(id): continue
		var hull: Dictionary = rear.ledger.inspect_entity(id,{},false)
		if not _rack_at_stop(id,hull,stop): continue
		_rack_seen[id] = true
		if int(hull.ammunition.get("E26",0)) == 0:
			rack_requests[id] = RACK_TARGET
			_rack_supplied[id] = 0
	for id in rack_requests.keys():
		var hull: Dictionary = rear.ledger.inspect_entity(id,{},false)
		var needed: int = _rack_needed(id,hull)
		if needed <= 0:
			rack_requests.erase(id)
			rack_status = "Initial E26 allocation physically delivered."
			continue
		if not _rack_at_stop(id,hull,stop): rack_status = "Waiting for the same T04 at the local supply stop."; continue
		needed -= _rack_committed(id)
		if needed <= 0: rack_status = "Actual rack couriers own the initial E26 deficit."; continue
		if rear.forward_supply.hull_committed(id): continue
		var parent: String = str(rear.military.vehicles[id].parent)
		if not _safe(parent,stop.position): rack_status = "Delivered hostile fire blocks safe rack receipt."; continue
		var source := ""
		for stock in rear.ledger.entities_at(stop_id,["STOCK"],false):
			if stock.owner == rear.PLAYER and stock.design_type == "E26" and stock.available > 0: source = stock.id; break
		if source.is_empty(): rack_status = "Local E26 is missing; manufacture and physically deliver freight."; continue
		var engineers: Dictionary = rear.military.squads.get(engineer_squad,{})
		if engineers.is_empty() or engineers.kind != "Engineer" or engineers.state != "Active" or engineers.get("owner",rear.PLAYER) != rear.PLAYER:
			rack_status = "The actual Engineer courier element is unavailable."
			continue
		var started := false
		for handler_id in rear.military._active_roster_members(engineers):
			if not _free(handler_id): continue
			var handler: Dictionary = rear.ledger.inspect_person_status(handler_id)
			if not _at_stop(handler,stop): continue
			var stock: Dictionary = rear.ledger.inspect_entity(source,{},false)
			var amount: int = mini(needed,mini(int(stock.available),maxi(0,240-int(hull.ammunition.get("E26",0)))))
			if amount <= 0: continue
			var issued: Dictionary = rear.forward_supply.request_vehicle_rack_issue(source,id,handler_id,amount,stop_id)
			if issued.ok:
				_rack_jobs[issued.id] = 0
				rack_status = "Engineer collecting actual E26 for the initially empty T04."
				started = true
				break
			rack_status = issued.message
		if not started: rack_status = "Waiting for an eligible local Engineer rack courier."

func _tick_replenishments(stop: Dictionary) -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	for row in _rack_replenishments.values():
		var hull: Dictionary = rear.ledger.inspect_entity(row.hull,{},false)
		var error: String = _replenishment_error(row,hull,stop)
		if not error.is_empty():
			_interrupt_replenishment(row)
			row.state = "Blocked"
			row.blocker = error
			continue
		if row.released: continue # Only a real deployment handoff closes the cycle.
		if int(hull.ammunition.get("E26",0)) >= int(row.target) and _rack_committed(row.hull) == 0 and not _replenishment_pending(row):
			row.completed = true
			row.state = "Complete"
			row.blocker = ""
			continue
		if not _safe(row.parent,stop.position):
			_interrupt_replenishment(row)
			row.state = "Blocked"
			row.blocker = "Delivered hostile fire blocks safe rack receipt and courier work."
			continue
		var waiting := false
		for job_id in row.jobs.duplicate():
			var job: Dictionary = rear.forward_supply.rack_issue.jobs.get(job_id,{})
			if job.is_empty():
				waiting = true
				row.state = "Blocked"
				row.blocker = "Owned rack courier record is missing; its physical obligation cannot be verified."
				continue
			if not _replenishment_job_pending(job): row.jobs.erase(job_id); continue
			waiting = true
			if job.state == "Interrupted Carry":
				var resumed: Dictionary = rear.forward_supply.rack_issue.resume(job_id)
				row.state = "Delivering" if resumed.ok else "Interrupted Carry"
				row.blocker = "Same Engineer resumes its existing actual E26 portion." if resumed.ok else resumed.message
			else:
				row.state = "Delivering"
				row.blocker = str(job.blocker) if not str(job.blocker).is_empty() else "Existing Engineer courier is handling actual ammunition."
		if waiting: continue
		var aboard: int = int(hull.ammunition.get("E26",0))
		var needed: int = maxi(0,int(row.target)-aboard)
		var committed: int = _rack_committed(row.hull)
		if not _rack_at_stop(row.hull,hull,stop):
			row.state = "Waiting Arrival"
			row.blocker = "Same APC must physically stop within 20 m of the declared supply stop."
			continue
		if committed > 0:
			row.state = "Delivering"
			row.blocker = "Existing rack couriers own %d pending rounds; actual aboard still needs %d." % [committed,needed]
			continue
		if rear.forward_supply.hull_committed(row.hull) or rear.military.hull_committed(row.hull):
			row.state = "Blocked"
			row.blocker = "Same APC must finish its existing physical movement or supply commitment."
			continue
		var source: Dictionary = {}
		for stock in rear.ledger.entities_at(stop_id,["STOCK"],false):
			if stock.owner == row.owner and stock.design_type == "E26" and stock.available > 0: source = stock; break
		if source.is_empty():
			row.state = "Waiting Stock"
			row.blocker = "Local unreserved autocannon rounds (E26) are missing; %d actual rounds are still needed." % needed
			continue
		var engineers: Dictionary = rear.military.squads.get(engineer_squad,{})
		if engineers.is_empty() or engineers.kind != "Engineer" or engineers.state != "Active" or engineers.get("owner",rear.PLAYER) != row.owner:
			row.state = "Blocked"
			row.blocker = "The actual owned Engineer courier element is unavailable."
			continue
		row.state = "Waiting Handler"
		row.blocker = "Waiting for a free actual Engineer within 20 m, with room for one whole round."
		for handler_id in rear.military._active_roster_members(engineers):
			if not _free(handler_id): continue
			var handler: Dictionary = rear.ledger.inspect_person_status(handler_id)
			if not _at_stop(handler,stop): continue
			var capacity: int = int(hull.vehicle_spec.rack_capacity.get("E26",0))
			var amount: int = mini(maxi(0,needed-committed),mini(int(source.available),maxi(0,capacity-aboard-committed)))
			if amount <= 0: continue
			var issued: Dictionary = rear.forward_supply.request_vehicle_rack_issue(source.id,row.hull,handler_id,amount,stop_id)
			if issued.ok:
				row.jobs.append(issued.id)
				row.state = "Delivering"
				row.blocker = "Engineer collecting actual E26 for this named current-deficit refill."
				break
			row.blocker = issued.message

func _replenishment_error(row: Dictionary, hull: Dictionary, stop: Dictionary) -> String:
	var rear: RefCounted = _rear_ref.get_ref()
	if stop.get("kind","") != "PLACE" or not rear.forward_supply.delivery_stops.has(stop_id): return "The declared physical rack supply stop is unavailable."
	if hull.get("kind","") != "CARRIER" or hull.get("design_type","") != "T04" or hull.get("fleet_domain","") != "Military" or hull.get("owner","") != row.owner or row.owner != rear.PLAYER:
		return "The original own military APC is no longer available to this refill cycle."
	if hull.get("health",0) <= 0: return "The original APC was destroyed; this refill cannot transfer to another hull."
	var attachment: Dictionary = rear.military.vehicles.get(row.hull,{})
	if attachment.get("owner","") != row.owner or str(attachment.get("parent","")) != row.parent or str(row.parent).is_empty():
		return "APC parent or ownership changed; the original refill cycle cannot automatically reparent."
	var formation: Dictionary = rear.military.platoons.get(row.parent,rear.military.companies.get(row.parent,{}))
	if formation.is_empty() or formation.get("owner",rear.PLAYER) != row.owner: return "The original owned APC parent element is unavailable."
	return ""

func _replenishment_available() -> int:
	var rear: RefCounted = _rear_ref.get_ref()
	var available := 0
	for stock in rear.ledger.entities_at(stop_id,["STOCK"],false):
		if stock.owner == rear.PLAYER and stock.design_type == "E26" and stock.available > 0: available += int(stock.available)
	return available

func _replenishment_job_pending(job: Dictionary) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	var carry: Dictionary = rear.ledger.inspect_entity(str(job.get("carry","")),{},false)
	if carry.get("holder_id","") == job.handler and carry.get("quantity",0) > 0: return true
	if rear.ledger.inspect_claim(job.claim).get("reserved",0) > 0: return true
	return job.state not in ["Complete","Interrupted"]

func _replenishment_pending(row: Dictionary) -> bool:
	for job_id in row.jobs:
		var job: Dictionary = _rear_ref.get_ref().forward_supply.rack_issue.jobs.get(job_id,{})
		if job.is_empty() or _replenishment_job_pending(job): return true
	return false

func _interrupt_replenishment(row: Dictionary) -> void:
	for job_id in row.jobs:
		var job: Dictionary = _rear_ref.get_ref().forward_supply.rack_issue.jobs.get(job_id,{})
		if not job.is_empty() and job.state not in ["Complete","Interrupted","Interrupted Carry"]:
			_rear_ref.get_ref().forward_supply.rack_issue.interrupt(job_id)

func _rack_at_stop(id: String, hull: Dictionary, stop: Dictionary) -> bool:
	return hull.get("owner","") == _rear_ref.get_ref().PLAYER and hull.get("design_type","") == "T04" and hull.get("fleet_domain","") == "Military" and hull.get("health",0) > 0 and _rear_ref.get_ref().military.vehicles.has(id) and hull.holder_id == stop_id and hull.position.distance_to(stop.position) <= 20.0

func _rack_needed(id: String, hull: Dictionary) -> int:
	# Deposited rounds count toward this one initial allocation even after firing.
	return maxi(0,int(rack_requests[id])-maxi(int(hull.get("ammunition",{}).get("E26",0)),int(_rack_supplied.get(id,0))))

func _rack_committed(id: String) -> int:
	var total := 0
	for job in _rear_ref.get_ref().forward_supply.rack_issue.jobs.values():
		if job.hull == id and job.state not in ["Complete","Interrupted"]: total += int(job.quantity)-int(job.issued)
	return total

func _committed(recipient: String) -> int:
	var total := 0
	for job in _rear_ref.get_ref().forward_supply.jobs.values():
		if job.recipient == recipient and job.type == "E02" and job.state not in ["Complete","Interrupted"]: total += int(job.quantity)
	return total

func _free(id: String) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	if rear.forward_supply.person_committed(id) or rear.forward_supply._other_busy(id) or rear.military.person_committed(id): return false
	return rear.battlefield_operations == null or not rear.battlefield_operations.person_committed(id)

func _at_stop(person: Dictionary, stop: Dictionary) -> bool:
	return person.get("assignment","") == "Formation Duty" and person.get("owner","") == _rear_ref.get_ref().PLAYER and person.get("health",0) > 0 and str(person.get("crew_station","")).is_empty() and _rear_ref.get_ref().ledger.entity_kind(person.holder_id) == "PLACE" and person.position.distance_to(stop.position) <= 20.0

func _safe(squad_id: String, at: Vector2) -> bool:
	var rear: RefCounted = _rear_ref.get_ref()
	for echelon in [squad_id,engineer_squad]:
		for id in rear.orders.contacts.get(echelon,{}):
			var known: Dictionary = rear.orders.contact(echelon,id)
			if known.get("confidence",0) <= 0 or not known.position.is_finite() or known.get("class","") in ["Resource","Route Hub","Observation","T01","T02"]: continue
			var effective: float = {"T03":250.0,"T04":450.0,"T05":700.0,"Enemy HQ":300.0,"P07":300.0,"P04":250.0}.get(known.get("class",""),160.0)
			# Both people and their straight local handoff legs stay inside this
			# convex20m disk. Protect the whole area using each element's reports.
			if at.distance_to(known.position) <= effective+20.0+float(known.get("uncertainty_m",0)): return false
	return true

func snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	var rear: RefCounted = _rear_ref.get_ref()
	for id in requests:
		rows.append({"person":id,"needed":maxi(0,int(requests[id])-rear.military._rounds(id)),"committed":_committed(id)})
	var available := 0
	for stock in rear.ledger.entities_at(stop_id,["STOCK"]):
		if stock.owner == rear.PLAYER and stock.design_type == "E02": available += int(stock.available)
	var racks: Array[Dictionary] = []
	for id in rack_requests:
		racks.append({"hull":id,"needed":_rack_needed(id,rear.ledger.inspect_entity(id,{},false)),"committed":_rack_committed(id)})
	var available_e26 := 0
	for stock in rear.ledger.entities_at(stop_id,["STOCK"],false):
		if stock.owner == rear.PLAYER and stock.design_type == "E26": available_e26 += int(stock.available)
	var replenishments: Array[Dictionary] = []
	for hull_id in _rack_replenishments: replenishments.append(rack_replenishment_status(hull_id))
	var squads: Array[Dictionary] = []
	for squad_id in _squad_replenishments: squads.append(squad_replenishment_status(squad_id))
	return {"requests":rows,"available_E02":available,"status":status,"engineer_squad":engineer_squad,"rack_requests":racks,"available_E26":available_e26,"rack_status":rack_status,"rack_replenishments":replenishments,"squad_replenishments":squads}
