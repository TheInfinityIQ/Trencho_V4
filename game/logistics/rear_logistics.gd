extends Node
## Event-woken physical hauling and return-trip delivery requests for the live rear.
signal changed
const Recipes = preload("res://game/production/fixed_production.gd")
const Resources = preload("res://game/procurement/resource_catalog.gd")
var _session_ref: WeakRef
var requests: Dictionary = {}
var _sequence := 0
var _factory_cursor := 0
var _factory_remaining := 0
var _delivery_cursor := 0
var _delivery_remaining := 0
var _turn := 0
var _army_requests: Dictionary = {}
var _army_holds: Dictionary = {}
var _supply_ref: WeakRef

func _init(session: Node) -> void:
	_session_ref = weakref(session)
	set_process(false)
	session.state_changed.connect(_wake)
	session.simulation_changed.connect(_replace_model)

static func shipment_types() -> Array[String]:
	var types: Array[String] = []
	for type in Resources.MATERIALS: types.append(type)
	for spec in Recipes.RECIPES.values():
		if spec.get("heavy",false) or str(spec.output_type).begins_with("T"): continue
		if str(spec.output_type) not in types: types.append(str(spec.output_type))
	types.sort()
	return types

func _model() -> RefCounted:
	var session: Node = _session_ref.get_ref()
	return session.simulation if session != null else null

func _replace_model(_next: RefCounted) -> void:
	if _supply_ref != null:
		var prior: RefCounted = _supply_ref.get_ref()
		if prior != null and prior.rear_supply_needed.is_connected(ensure_army_supply): prior.rear_supply_needed.disconnect(ensure_army_supply)
	_supply_ref = null
	requests.clear()
	_army_requests.clear()
	_army_holds.clear()
	_sequence = 0
	_factory_cursor = 0
	_delivery_cursor = 0
	_factory_remaining = 0
	_delivery_remaining = 0
	if _next.rear.battlefield_operations != null:
		var policy: RefCounted = _next.rear.battlefield_operations.policy
		if policy != null and policy.get("resupply") is RefCounted:
			var supply: RefCounted = policy.resupply
			_supply_ref = weakref(supply)
			supply.rear_supply_needed.connect(ensure_army_supply)
	changed.emit()
	_wake()

func _wake() -> void:
	var model := _model()
	if model == null or not model.empty_field_opening: return
	_factory_remaining = maxi(_factory_remaining,model.rear._production_activities().size())
	_delivery_remaining = maxi(_delivery_remaining,requests.size())
	set_process(_factory_remaining > 0 or _delivery_remaining > 0)

func _process(_delta: float) -> void:
	var model := _model()
	if model == null or not model.empty_field_opening:
		set_process(false)
		return
	# One candidate and at most one physical command per rendered frame.
	# A finite event-triggered pass drains to idle; there is no idle timer/poll.
	_turn = (_turn+1)%2
	if _factory_remaining > 0 and (_turn == 0 or _delivery_remaining == 0):
		var activities: Array[RefCounted] = model.rear._production_activities()
		if activities.is_empty(): _factory_remaining = 0
		else:
			_factory_cursor %= activities.size()
			var did_work := _supply_factory(activities[_factory_cursor])
			if not did_work:
				_factory_cursor += 1
				_factory_remaining -= 1
	elif _delivery_remaining > 0:
		var ids: Array = requests.keys()
		if ids.is_empty(): _delivery_remaining = 0
		else:
			_delivery_cursor %= ids.size()
			var did_work := _advance_request(requests[ids[_delivery_cursor]])
			if not did_work:
				_delivery_cursor += 1
				_delivery_remaining -= 1
	set_process(_factory_remaining > 0 or _delivery_remaining > 0)

func _supply_factory(activity: RefCounted) -> bool:
	var demand: Dictionary = activity.logistics_demand()
	if demand.is_empty(): return false
	for type in demand.missing:
		if _ensure_haul(str(demand.destination),str(type),int(demand.missing[type]),int(demand.priority),activity).get("ok",false): return true
	return false

func _source_inventory(destination: String, type: String) -> Array[Dictionary]:
	var rear: RefCounted = _model().rear
	var excluded := {}
	for activity in rear._production_activities(): excluded[activity._spec.input_store] = true
	var sources: Array[Dictionary] = []
	for id in rear.stores:
		if id == destination or excluded.has(id) or not rear.stores[id].accessible: continue
		var site: Dictionary = rear.construction.instances.get(id,{})
		if not site.is_empty() and site.state != "Complete": continue
		var inventory: Dictionary = rear.ledger.owned_inventory_at(id,rear.PLAYER)
		var available: int = int(inventory.available.get(type,0))
		for weapon in inventory.weapons:
			if weapon.design_type == type and not rear.dispatch.weapon_promises.has(weapon.id): available += 1
		# In-flight claims are already excluded by available(); subtract only
		# still-unselected demand, so two factories cannot promise the same stock.
		for job in rear.jobs:
			if not job.cancelled and job.source == id and job.type == type:
				available -= maxi(0,int(job.requested)-int(job.delivered)-rear._in_flight(job.id))
		if available > 0: sources.append({"id":id,"available":available})
	return sources

func _ensure_haul(destination: String, type: String, missing: int, priority: int = 1, factory: RefCounted = null) -> Dictionary:
	var rear: RefCounted = _model().rear
	for job in rear.jobs:
		if not job.cancelled and job.destination == destination and job.type == type:
			missing -= maxi(0,int(job.requested)-int(job.delivered))
	if missing <= 0: return {"ok":false}
	for source in _source_inventory(destination,type):
		var result: Dictionary = rear.request_haul(source.id,destination,type,mini(missing,int(source.available)),priority,[],factory)
		if result.ok: changed.emit()
		return result
	return {"ok":false}

func request_delivery(type: String, quantity: int) -> Dictionary:
	return _queue_delivery(type,quantity,false)

func supply_intent(type: String) -> Dictionary:
	# Detached player intent, separate from physical request/cargo state.
	return {"held":_army_holds.has(type),"automatic_request_id":str(_army_requests.get(type,""))}

func resume_automatic_supply(type: String) -> Dictionary:
	var model := _model()
	if model == null or not model.empty_field_opening or type not in shipment_types():
		return {"ok":false,"requires_reconciliation":false,"message":"Choose a supported supply in the live game."}
	if not _army_holds.has(type):
		return {"ok":true,"requires_reconciliation":false,"message":"Automatic supply is already enabled."}
	_army_holds.erase(type)
	var prior: Dictionary = requests.get(str(_army_requests.get(type,"")),{})
	if not prior.is_empty() and prior.cancelled: _army_requests.erase(type)
	var supply: RefCounted = _supply_ref.get_ref() if _supply_ref != null else null
	if supply != null: supply.invalidate_rear_supply_need(type)
	changed.emit()
	return {"ok":true,"requires_reconciliation":false,"message":"Automatic supply resumed. The next military supply decision will recompute actual need; cancelled requests stay cancelled."}

func _queue_delivery(type: String, quantity: int, automatic: bool) -> Dictionary:
	if _model() == null or not _model().empty_field_opening: return {"ok":false,"requires_reconciliation":false,"message":"Army delivery requests belong to the live empty-field game."}
	if type not in shipment_types() or quantity <= 0: return {"ok":false,"requires_reconciliation":false,"message":"Choose a supported supply and a positive whole quantity."}
	_sequence += 1
	var id := "rear-delivery-%04d" % _sequence
	requests[id] = {"id":id,"type":type,"requested":quantity,"delivered":0,"manifest":"","credited":{},"cancelled":false,"state":"Queued","blocker":"Waiting for actual supplies, a staffed Logistics Centre and a ready driven truck."}
	if automatic:
		_army_requests[type] = id
		requests[id].automatic = true
	else:
		_army_holds.erase(type)
		var held: Dictionary = requests.get(str(_army_requests.get(type,"")),{})
		if not held.is_empty() and held.cancelled: _army_requests.erase(type)
		# Ask the source owner to publish a fresh shortage at its next event.
		# Manual intent never becomes the automatic request's mutable target.
		var supply: RefCounted = _supply_ref.get_ref() if _supply_ref != null else null
		if supply != null: supply.invalidate_rear_supply_need(type)
	_wake()
	changed.emit()
	return {"ok":true,"requires_reconciliation":false,"id":id,"message":"Supply requested. Actual workers load available goods onto a real truck; it delivers and returns before another trip."}

func _uncredited_hq_receipt(row: Dictionary, manifest: Dictionary) -> int:
	if manifest.is_empty(): return 0
	return maxi(0,int(manifest.unloaded.get(row.type,0))-int(row.credited.get(manifest.id,0)))

func ensure_army_supply(type: String, quantity: int) -> void:
	var model := _model()
	if model == null or not model.empty_field_opening or quantity < 0 or _army_holds.has(type): return
	var current: Dictionary = requests.get(str(_army_requests.get(type,"")),{})
	# Explicit cancellation remains player intent, not a zero-demand transition.
	if not current.is_empty() and current.cancelled: return
	var uncovered := quantity
	for row in requests.values():
		if row.id == current.get("id","") or row.type != type or row.state == "Complete": continue
		var trip: Dictionary = model.rear.dispatch.manifests.get(row.manifest,{})
		# Source coverage already includes actual HQ receipt, even before this
		# request's high-water mark catches up. Never count those rounds twice.
		var promised: int = maxi(0,int(row.requested)-int(row.delivered)-_uncredited_hq_receipt(row,trip))
		if row.cancelled:
			if trip.is_empty() or not trip.departed or trip.state in ["Complete","Cancelled","Safety Returned"]: continue
			promised = maxi(0,int(trip.cargo.get(type,0))-int(trip.unloaded.get(type,0)))
		uncovered -= promised
	uncovered = maxi(0,uncovered)
	if current.is_empty() or current.state == "Complete":
		if uncovered > 0: _queue_delivery(type,uncovered,true)
		return
	var manifest: Dictionary = model.rear.dispatch.manifests.get(current.manifest,{})
	var uncredited: int = _uncredited_hq_receipt(current,manifest)
	var accepted := 0
	if not str(current.manifest).is_empty():
		if manifest.is_empty():
			# Missing owned records retain the unresolved promise and blocked path.
			accepted = maxi(0,int(current.requested)-int(current.delivered)-uncredited)
		elif manifest.state not in ["Complete","Cancelled","Safety Returned"]:
			accepted = maxi(0,int(manifest.cargo.get(type,0))-int(manifest.unloaded.get(type,0)))
	var target: int = int(current.delivered)+uncredited+maxi(uncovered,accepted)
	var awaiting_need: bool = bool(current.get("awaiting_need",false))
	if target == int(current.requested) and not awaiting_need: return
	current.requested = target
	if awaiting_need: current.awaiting_need = false
	if str(current.manifest).is_empty() and target == int(current.delivered):
		_set_status(current,"Complete","No additional automatic load currently needed. Physical deliveries and recipient issue keep their own progress.")
	else:
		_wake()
		changed.emit()

func cancel_request(id: String) -> Dictionary:
	var row: Dictionary = requests.get(id,{})
	if row.is_empty() or row.cancelled or row.state == "Complete": return {"ok":false,"requires_reconciliation":false,"message":"Select a live delivery request."}
	row.cancelled = true
	_army_holds[row.type] = true
	var rear: RefCounted = _model().rear
	var manifest: Dictionary = rear.dispatch.manifests.get(row.manifest,{})
	if not manifest.is_empty() and not manifest.departed and manifest.state not in ["Complete","Cancelled","Safety Returned"]: rear.dispatch.cancel(manifest.id)
	_set_status(row,"Cancelling" if not manifest.is_empty() else "Cancelled","Already delivered goods remain at HQ; a departed shipment completes its physical trip.")
	_wake()
	return {"ok":true,"message":"Unsent remainder cancelled. Carried goods and the active truck retain their physical return/unloading rules."}

func _set_status(row: Dictionary, state: String, blocker: String = "") -> void:
	if row.state == state and row.blocker == blocker: return
	row.state = state
	row.blocker = blocker
	changed.emit()

func _advance_request(row: Dictionary) -> bool:
	var model := _model()
	var rear: RefCounted = model.rear
	if not str(row.manifest).is_empty():
		var manifest: Dictionary = rear.dispatch.manifests.get(row.manifest,{})
		if manifest.is_empty():
			_set_status(row,"Blocked","The owned physical manifest is unavailable; inspect Dispatch.")
			return false
		var unloaded: int = int(manifest.unloaded.get(row.type,0))
		var credited: int = int(row.credited.get(manifest.id,0))
		if unloaded > credited:
			row.delivered += unloaded-credited
			row.credited[manifest.id] = unloaded
			# Receipt changes outstanding promises even when net Army need is unchanged.
			# Invalidate only publication; the next military decision owns fresh coverage.
			var supply: RefCounted = _supply_ref.get_ref() if _supply_ref != null else null
			var operations: RefCounted = rear.battlefield_operations
			if model == _model() and supply != null and operations != null:
				var policy: RefCounted = operations.policy
				if policy != null and policy.get("resupply") == supply:
					supply.invalidate_rear_supply_need(str(row.type))
			changed.emit()
		if manifest.state in ["Complete","Cancelled","Safety Returned"]:
			row.manifest = ""
			if row.get("automatic",false) and not row.cancelled and row.delivered < row.requested:
				# The accepted floor is gone. Await fresh military need before a
				# next load, rather than reusing a protected but obsolete target.
				row.awaiting_need = true
				var supply: RefCounted = _supply_ref.get_ref() if _supply_ref != null else null
				var operations: RefCounted = rear.battlefield_operations
				if model == _model() and supply != null and operations != null:
					var policy: RefCounted = operations.policy
					if policy != null and policy.get("resupply") == supply:
						supply.invalidate_rear_supply_need(str(row.type))
			_set_status(row,"Cancelled" if row.cancelled else ("Complete" if row.delivered >= row.requested else "Queued"))
			return true
		if row.cancelled: return false
		_set_status(row,str(manifest.state),str(manifest.blocker))
		if manifest.state == "Loaded Waiting Dispatch" and model.speed > 0:
			var departure: Dictionary = rear.dispatch.depart(manifest.id)
			if not departure.ok: _set_status(row,"Waiting",str(departure.message))
			return bool(departure.ok)
		# Dispatch already owns physical source pickup, staging and loading;
		# adding a separate haul here would duplicate its reserved freight.
		return false
	if row.cancelled or row.delivered >= row.requested: return false
	if row.get("automatic",false) and row.get("awaiting_need",false):
		_set_status(row,"Waiting","Waiting for current military need before another automatic load.")
		return false
	if model.speed == 0:
		_set_status(row,"Queued","Start time to prepare the next physical delivery.")
		return false
	var site_id: String = rear.dispatch.ready_dispatch_site()
	if site_id.is_empty():
		_set_status(row,"Waiting","Waiting for an accessible Logistics Centre with requested staff and an eligible idle handler. Staff who are reporting, carrying or changing duties are not ready for a new load.")
		return false
	var site: Dictionary = rear.dispatch.dispatch_sites[site_id]
	var inventory: Dictionary = rear.ledger.owned_inventory_at(site.store,rear.PLAYER)
	var available: int = int(inventory.available.get(row.type,0))
	for weapon in inventory.weapons:
		if weapon.design_type == row.type and not rear.dispatch.weapon_promises.has(weapon.id): available += 1
	for source in _source_inventory(site.store,row.type): available += int(source.available)
	if available <= 0:
		_set_status(row,"Waiting","Manufacture or purchase the requested supplies; none are available for this shipment.")
		return false
	for hull_id in rear.vehicles.vehicles:
		if rear.vehicles.vehicles[hull_id].state != "Parked" or not rear.dispatch._active_manifest(hull_id).is_empty(): continue
		var hull: Dictionary = rear.ledger.inspect_entity(hull_id,{},false)
		if hull.design_type not in ["T01","T02"] or not rear.vehicles.readiness(hull_id).transfer_crew_eligible: continue
		var quantity := mini(int(row.requested)-int(row.delivered),mini(available,int(floor(float(hull.vehicle_spec.payload)/rear.dispatch._unit_mass(row.type)))))
		if quantity <= 0: continue
		var accepted: Dictionary = rear.dispatch.accept(hull_id,"Strategic Delivery",[],{row.type:quantity},[],site_id)
		if not accepted.ok: _set_status(row,"Waiting",str(accepted.message)); return false
		row.manifest = accepted.id
		_set_status(row,"Preparing","Workers must physically stage and load the accepted cargo.")
		return true
	_set_status(row,"Waiting","Build a transport truck, park it and seat a qualified Driver. Fuel and real loading remain required.")
	return false
