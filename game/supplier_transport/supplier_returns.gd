extends RefCounted
## Receiving-owned return transaction. No stock search or frame callback.
var _owner: WeakRef

func _init(receiving: RefCounted) -> void:
	_owner = weakref(receiving)

func quote(order: Dictionary) -> Dictionary:
	var service: RefCounted = _owner.get_ref()
	var quantities := {}
	var fingerprint: Array[String] = [str(order.id)]
	var ids: Array = order.get("aboard_packets",{}).keys()
	ids.sort()
	var refund := 0
	for id: String in ids:
		var count := int(order.aboard_packets[id])
		var code := str(order.source_codes[id])
		var price := int(order.get("paid_prices",{}).get(code,0))
		quantities[code] = int(quantities.get(code,0))+count
		refund += count*price
		fingerprint.append("%s:%d:%d" % [id,count,price])
	var requested := bool(order.get("return_requested",false))
	var completed := bool(order.get("return_completed",false))
	var message := "Select a stopped materials truck with cargo still aboard."
	var eligible: bool = order.kind == "Freight" and order.state == "Berthed" and not ids.is_empty() and not requested
	if eligible: message = "Return remaining cargo; transport fees are retained."
	if requested:
		message = "Finishing safe worker handoffs before return."
		if ready(order): message = "Closing truck for return; refund pending actual exit."
		if order.state == "Departing": message = "Returning cargo; refund pending actual exit."
		if completed: message = "Returned %d kg; %d requisition refunded. Transport fee retained: %d." % [int(order.return_kg),int(order.return_refund),int(order.get("transport_paid",0))]
		if not str(order.get("return_error","")).is_empty(): message = str(order.return_error)
	return {"eligible":eligible,"quantities":quantities,"refund":refund,"fee":int(order.get("transport_paid",0)),"fingerprint":"|".join(fingerprint),"message":message,"time":float(service._time)}

func confirm(id: String, expected: String) -> Dictionary:
	var service: RefCounted = _owner.get_ref()
	var order: Dictionary = service._find_order(id)
	if order.is_empty(): return _reject("The delivery no longer exists.")
	var offer := quote(order)
	if not offer.eligible or expected != offer.fingerprint:
		return _reject("The truck or remaining cargo changed. Review the delivery and confirm again; nothing was returned.")
	var releases := {}
	var withdrawals := {}
	for person_id: String in service._workers:
		var job: Dictionary = service._workers[person_id].job
		if job.get("order_id","") != id: continue
		var person: Dictionary = service.ledger.inspect_person_status(person_id)
		if not str(person.get("carrying_stock_id","")).is_empty() or not str(person.get("joint_carry_id","")).is_empty(): continue
		if job.phase == "Truck return": continue # Already withdrawing after reassignment.
		var claim: Dictionary = service.ledger.inspect_claim(str(job.claim_id))
		if not claim.is_empty() and not claim.cancelled: releases[str(job.claim_id)] = person_id
		var path: Array = []
		if person.get("supplier_access_id","") == id:
			path = _withdrawal_path(order,job,Vector2(person.position))
			if path.is_empty(): return _reject("The worker's safe exit corridor is unavailable; nothing changed.")
		withdrawals[person_id] = path
	var locked: Dictionary = service.ledger.reserve_supplier_return(id,order.stock_ids,releases,service.PLAYER)
	if not locked.ok: return locked
	order.return_requested = true
	order.return_claims = locked.claims
	order.return_quote = offer.duplicate(true)
	order.storage_warning = ""
	for person_id: String in withdrawals:
		var job: Dictionary = service._workers[person_id].job
		if job.has("storage"):
			service.warehouse.release(str(job.storage))
			job.erase("storage")
		if service.warehouse != null: service.warehouse.release_point(person_id)
		service.ledger.release_handling_points(person_id,"receiving")
		var path: Array = withdrawals[person_id]
		if path.is_empty():
			service.ledger.release_handling_points(person_id,id)
			service._workers[person_id].job = {}
		else:
			job.phase = "Truck return"
			job.path = path
			job.return_exit_point = path.back()
			job.started_at = float(service._time)
			job.ends_at = float(service._time)+maxf(0.001,float(service._path_length(path))/1.5)
		service.worker_activity_changed.emit(person_id)
	service._event("Return confirmed; original remaining goods locked, existing carries finish safely",id)
	service.supplier_state_changed.emit()
	return {"ok":true,"message":"Return accepted. Workers finish safely; goods-only refund follows the truck's actual exit."}

func _withdrawal_path(order: Dictionary, job: Dictionary, origin: Vector2) -> Array:
	var service: RefCounted = _owner.get_ref()
	var freight: RefCounted = service.freight
	var rear: Vector2 = freight.to_world(order,Vector3(0,0,freight.REAR_Z))
	if job.phase != "Approach":
		# These phases are at the actual shelf, so this is the already known ramp corridor.
		if job.phase not in ["Pickup","Storage access"]: return []
		return [origin,freight.to_world(order,Vector3(0,0,freight.RAMP_TOP_Z)),freight.to_world(order,Vector3(0,0,freight.RAMP_GROUND_Z)),rear]
	var ingress: Array = job.path
	var rear_index := ingress.find(rear)
	if rear_index < 0: return []
	var duration := float(job.ends_at)-float(job.started_at)
	var fraction := clampf((float(service._time)-float(job.started_at))/duration,0.0,1.0) if duration > 0.0 else 1.0
	var remaining: float = float(service._path_length(ingress))*fraction
	var last_reached := 0
	for index in range(1,ingress.size()):
		var distance: float = Vector2(ingress[index-1]).distance_to(ingress[index])
		if remaining < distance-0.000001: break
		remaining -= distance
		last_reached = index
	if last_reached < rear_index:
		return [origin] # Proven still outside: no boarding took place, release here.
	var path: Array = [origin]
	for index in range(last_reached,rear_index-1,-1): path.append(ingress[index])
	return path

func ready(order: Dictionary) -> bool:
	if not order.get("return_requested",false) or order.get("return_completed",false): return false
	var service: RefCounted = _owner.get_ref()
	for worker: Dictionary in service._workers.values():
		if worker.job.get("order_id","") == order.id: return false
	return order.get("aisle_workers",[]).is_empty()

func complete(order: Dictionary) -> Dictionary:
	var service: RefCounted = _owner.get_ref()
	if not order.get("return_requested",false) or order.get("return_completed",false): return {"ok":true}
	var receipt: Dictionary = service.ledger.return_supplier_cargo(str(order.id),order.return_claims,service._exit(order),service.PLAYER)
	if not receipt.ok: return receipt
	var refund := 0
	var kg := 0
	for row: Dictionary in receipt.receipt:
		kg += int(row.quantity)
		refund += int(row.quantity)*int(order.get("paid_prices",{}).get(str(row.type),0))
	order.return_completed = true
	order.return_refund = refund
	order.return_kg = kg
	service._money += refund
	service._refunds += refund
	service._event("Actual supplier exit: goods-only refund paid once",str(order.id))
	return {"ok":true,"refund":refund,"quantity":kg}

func abandon_for_debug(order: Dictionary) -> void:
	if not order.get("return_requested",false) or order.get("return_completed",false): return
	var service: RefCounted = _owner.get_ref()
	for id: String in order.return_claims: service.ledger.release_claim(id)
	order.return_requested = false
	order.return_debug_bypass = true

func _reject(message: String) -> Dictionary:
	return {"ok":false,"requires_reconciliation":false,"code":"RETURN_UNAVAILABLE","message":message}
