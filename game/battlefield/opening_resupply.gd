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

func _init(rear: RefCounted, rifles: Array, engineers: String, stop: String) -> void:
	_rear_ref = weakref(rear)
	rifle_squads = rifles.duplicate()
	engineer_squad = engineers
	stop_id = stop

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
	if stop.get("kind","") != "PLACE": _tick_replenishments(stop); return
	_tick_racks(stop)
	_tick_replenishments(stop)
	for job_id in owned_jobs.keys():
		var job: Dictionary = rear.forward_supply.jobs.get(job_id,{})
		if job.is_empty() or job.state in ["Complete","Interrupted"]: owned_jobs.erase(job_id); continue
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
		var needed: int = int(requests[id])-rear.military._rounds(id)
		if needed <= 0: requests.erase(id); continue
		needed -= _committed(id)
		if needed <= 0: status = "Actual couriers are carrying the committed deficit."; continue
		if not _at_stop(person,stop) or not _free(id): status = "Waiting for the named rifle member at the local supply rendezvous."; continue
		if not _safe(person.duty_id,stop.position): status = "Delivered hostile fire blocks safe local receipt."; continue
		var source := ""
		for stock in rear.ledger.entities_at(stop_id,["STOCK"]):
			if stock.owner == rear.PLAYER and stock.design_type == "E02" and stock.available > 0: source = stock.id; break
		if source.is_empty(): status = "Local E02 is missing; manufacture and physically deliver freight."; continue
		var engineers: Dictionary = rear.military.squads.get(engineer_squad,{})
		if engineers.is_empty(): status = "The actual Engineer courier element is unavailable."; continue
		var started := false
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
				status = "Engineer courier collecting actual E02 for a depleted Rifle member."
				started = true
				break
			status = issued.message
		if not started: status = "Waiting for an eligible local Engineer courier and carry capacity."

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
	return {"requests":rows,"available_E02":available,"status":status,"engineer_squad":engineer_squad,"rack_requests":racks,"available_E26":available_e26,"rack_status":rack_status,"rack_replenishments":replenishments}
