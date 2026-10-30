extends RefCounted
## Local military issue for this opening; all movement/stock stays in ForwardSupply.
const TRIGGER := 30
const TARGET := 60
var _rear_ref: WeakRef
var rifle_squads: Array
var engineer_squad: String
var stop_id: String
var requests: Dictionary = {}
var owned_jobs: Dictionary = {}
var status := "Waiting for actual local ammunition need."

func _init(rear: RefCounted, rifles: Array, engineers: String, stop: String) -> void:
	_rear_ref = weakref(rear)
	rifle_squads = rifles.duplicate()
	engineer_squad = engineers
	stop_id = stop

func tick() -> void:
	var rear: RefCounted = _rear_ref.get_ref()
	var stop: Dictionary = rear.ledger.inspect_entity(stop_id)
	if stop.get("kind","") != "PLACE": return
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
	return {"requests":rows,"available_E02":available,"status":status,"engineer_squad":engineer_squad}
