extends RefCounted
## Detached rifle-supply presentation. Existing owners retain all decisions and goods.
const CallLog = preload("res://game/diagnostics/function_call_log.gd")

static func view(session: Node) -> Dictionary:
	CallLog.record(&"logistics/army_supply_view.gd::view")
	if session == null or session.get("simulation") == null: return {}
	var model: RefCounted = session.simulation
	var rear: RefCounted = model.rear
	var policy: RefCounted = rear.battlefield_operations.policy if rear.battlefield_operations != null else null
	var supply: RefCounted = policy.get("resupply") if policy != null else null
	if supply == null or session.get("automatic_logistics") == null: return {}
	var rifle: Dictionary = supply.rifle_supply_view()
	var holders: Array = rear.stores.keys()
	for holder in ["hq-stock",rifle.stop_id]:
		if holder not in holders: holders.append(holder)
	var counts: Dictionary = rear.ledger.available_stock_counts(holders,"E02",rear.PLAYER)
	var stock := {"rear":0,"hq":int(counts.get("hq-stock",0)),"forward":int(counts.get(rifle.stop_id,0))}
	for id in rear.stores:
		if id not in ["hq-stock",rifle.stop_id] and rear.stores[id].accessible: stock.rear += int(counts.get(id,0))
	var requests: Array[Dictionary] = []
	var blockers: Array[String] = []
	for row in session.automatic_logistics.requests.values():
		if row.type != "E02": continue
		requests.append({"id":str(row.id),"label":"Rifle ammunition · " + str(row.state),"state":str(row.state),"requested":int(row.requested),"delivered":int(row.delivered),"blocker":str(row.blocker),"cancelled":bool(row.cancelled)})
		if not row.cancelled and row.state != "Complete" and not str(row.blocker).is_empty() and str(row.blocker) not in blockers: blockers.append(str(row.blocker))
	var intent: Dictionary = session.automatic_logistics.supply_intent("E02")
	if intent.held: blockers.append("Automatic rear-to-HQ rifle-ammunition requests are held after cancellation. Resume explicitly when ready; existing HQ stock and committed forward deliveries retain their physical rules.")
	if model.speed == 0: blockers.append("Game time is paused. Start 1x when ready for physical work and travel.")
	var forward_loaded := 0
	var forward_unloaded := 0
	var active_freight := 0
	var incoming := 0
	for job in rear.forward_supply.transport.jobs.values():
		if job.type != "E02" or job.stop != rifle.stop_id: continue
		forward_loaded += int(job.loaded)
		forward_unloaded += int(job.unloaded)
		if job.state != "Complete":
			active_freight += 1
			incoming += maxi(0,int(job.quantity)-int(job.unloaded))
	var need := 0
	var remaining := 0
	var carried := 0
	var committed := 0
	for row in rifle.recipients:
		need += int(row.needed)
		remaining += int(row.remaining)
		carried += int(row.carried)
		committed += int(row.committed)
	var rear_shortage := maxi(0,remaining-int(stock.forward)-incoming-int(stock.hq))
	var summary: String = "%d rounds reported needed · %d committed to couriers · %d remaining before stock coverage. Available forward stock: %d; committed forward freight: %d; available HQ stock: %d. Military shortfall beyond those supplies: %d rounds. Rear stores already hold %d available rounds; check existing deliveries before producing more." % [need,committed,remaining,stock.forward,incoming,stock.hq,rear_shortage,stock.rear]
	var feedback: Dictionary = _supply_feedback(need,remaining,stock,incoming,bool(intent.held),not rifle.recipients.is_empty())
	summary += " " + str(feedback.detail)
	var stages: Array[Dictionary] = [
		{"label":"Available rear stock","quantity_text":"%d rounds" % stock.rear,"detail":"Accessible rear stores, excluding reserved stock. Production creates goods here; they are not yet at HQ."},
		{"label":"Available at HQ","quantity_text":"%d rounds" % stock.hq,"detail":"Actual unreserved HQ stock, including the approved starting ammunition. Rear requests below count only physical HQ receipts."},
		{"label":"HQ → forward freight","quantity_text":"%d loaded · %d unloaded" % [forward_loaded,forward_unloaded],"detail":"Cumulative handling across actual rifle-freight jobs; %d unfinished. This is separate from rear-to-HQ shipments. %s" % [active_freight,str(rifle.freight_status).replace("E02","rifle ammunition")]},
		{"label":"Available at forward stop","quantity_text":"%d rounds" % stock.forward,"detail":"Unreserved loose rounds at the military's actual local supply stop. Courier commitments are listed separately."},
		{"label":"Carried by followed recipients","quantity_text":"%d rounds" % carried,"detail":"Current loose and loaded ammunition on the followed people. Completed named-refill recipients remain followable; receipt history and current possession are separate. " + str(rifle.status)}
	]
	var facility := _munitions_site(rear)
	var actions: Array[Dictionary] = [
		{"id":"produce" if facility.get("state","") == "Complete" else "build","label":"Review ammunition production" if facility.get("state","") == "Complete" else ("Inspect munitions construction" if not facility.is_empty() else "Build a munitions workshop"),"enabled":true,"panel":"Work" if facility.get("state","") == "Complete" else "Build","facility_id":str(facility.get("id","")),"building_kind":"munitions","focus":"target"},
		{"id":"workers","label":"Manage workers","enabled":true,"panel":"Workers/Jobs"},
		{"id":"rear_requests","label":"Review HQ delivery requests","enabled":true,"panel":"Supplies"},
		{"id":"observe","label":"Observe selected recipient","enabled":not rifle.recipients.is_empty(),"panel":"Battlefield"}
	]
	if intent.held: actions.append({"id":"resume_automatic","label":"Resume automatic rifle supply","enabled":true})
	return {"title":"Army needs · Rifle ammunition","summary":summary,"recipients":rifle.recipients,"stages":stages,"requests":requests,"blockers":blockers,"held":bool(intent.held),"actions":actions,"stock":stock,"rear_shortage":rear_shortage,"forward_committed":incoming,"supply_state":str(feedback.state),"supply_feedback":str(feedback.detail)}

static func _supply_feedback(need: int, remaining: int, stock: Dictionary, incoming: int, held: bool, followed: bool) -> Dictionary:
	# These are already-read projection facts, never another inventory/capability query.
	var state := "No reported need"
	var detail := "No current rifle-ammunition shortage has been reported."
	var local_gap := maxi(0,remaining-int(stock.forward))
	var hq_gap := maxi(0,local_gap-incoming-int(stock.hq))
	if need <= 0:
		if followed: detail += " Follow actual receipt and current activity below; receipt alone does not establish a successful operation."
	elif remaining <= 0:
		state = "Courier issue"
		detail = "Engineer couriers own the reported deficit. Their committed rounds become usable only after physical recipient issue."
	elif local_gap <= 0:
		state = "Local issue"
		detail = "Available ammunition at the forward stop covers the remaining reported need. Recipients and eligible couriers must still complete local issue."
	elif local_gap <= incoming:
		state = "Forward freight"
		detail = "Already committed HQ-to-forward freight covers the local gap. Loading, travel, unloading and recipient issue must still finish; committed freight is not carried ammunition."
	elif hq_gap <= 0:
		state = "HQ stock covers need"
		detail = "Existing available HQ ammunition covers the balance after local stock and committed forward freight. Physical HQ-to-forward delivery and recipient issue are still needed; this reported need does not require extra manufacture."
	elif hq_gap <= int(stock.rear):
		state = "Rear stock covers gap"
		detail = "Existing available rear ammunition covers the shortfall beyond forward and HQ supplies. It still needs rear-to-HQ delivery, onward freight and recipient issue."
	else:
		state = "Review rear deliveries"
		detail = "%d rounds are not covered by the available unreserved rear stock and HQ/forward supplies shown here. Reserved or onboard rear-to-HQ cargo is not counted in this view. Check existing delivery requests and actual cargo before ordering extra production." % (hq_gap-int(stock.rear))
	if held: detail += " Automatic rear-to-HQ requests are held after cancellation; resume them explicitly if wanted. This hold does not recall existing forward freight."
	return {"state":state,"detail":detail}

static func _munitions_site(rear: RefCounted) -> Dictionary:
	var chosen := {}
	for id in rear.construction.instances:
		var site: Dictionary = rear.construction.instances[id]
		if site.kind != "munitions" or site.state in ["Cancelled","Destroyed","Dismantled"]: continue
		if chosen.is_empty() or (site.state == "Complete" and chosen.state != "Complete"): chosen = {"id":str(id),"state":str(site.state)}
	return chosen
