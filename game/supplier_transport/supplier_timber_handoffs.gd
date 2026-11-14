extends RefCounted
## Pending physical obligations, never inventory. Ledger and warehouse own goods.
var pending: Dictionary = {}
var _owner: WeakRef

func _init(receiving: RefCounted) -> void:
	_owner = weakref(receiving)
	var owner_ref := weakref(self)
	receiving.ledger.joint_carries.custody_changed.connect(func(state: String, details: Dictionary) -> void:
		var owner: RefCounted = owner_ref.get_ref()
		if owner != null: owner._custody_changed(state,details))

func has_pending(order_id: String) -> bool:
	for row: Dictionary in pending.values():
		if row.order == order_id: return true
	return false

func _custody_changed(state: String, details: Dictionary) -> void:
	var service: RefCounted = _owner.get_ref()
	if service == null: return
	var id := str(details.id)
	if state == "Carrying":
		var order_id := ""
		# A recovery inherits only an existing ground obligation; unrelated later
		# hauling of this origin from warehouse storage is not supplier delivery.
		for old_id: String in pending.keys():
			var previous: Dictionary = pending[old_id]
			if previous.state != "Ground" or previous.stock != details.source: continue
			order_id = str(previous.order)
			if int(service.ledger.inspect_entity(str(details.source),{},false).get("quantity",0)) == 0: pending.erase(old_id)
			break
		if order_id.is_empty():
			for order: Dictionary in service._orders:
				if order.kind == "Freight" and order.id == details.source_holder and details.source in order.stock_ids:
					order_id = str(order.id)
					break
		if order_id.is_empty(): return
		pending[id] = {"order":order_id,"stock":str(details.stock),"origin":str(details.origin),"state":state}
	elif pending.has(id):
		pending[id].stock = str(details.stock)
		pending[id].state = state
	else: return
	service.supplier_state_changed.emit()

func stock_committed(stock_id: String) -> void:
	var service: RefCounted = _owner.get_ref()
	if service == null: return
	for id: String in pending.keys():
		var row: Dictionary = pending[id]
		if row.state != "Deposited" or row.stock != stock_id: continue
		var stock: Dictionary = service.ledger.inspect_entity(stock_id,{},false)
		if stock.get("design_type","") != "M04" or stock.get("origin_id","") != row.origin or stock.get("holder_id","") != "receiving": return
		var order: Dictionary = service._find_order(str(row.order))
		order.unloaded.M04 = int(order.unloaded.get("M04",0))+int(stock.quantity)
		pending.erase(id)
		service._event("Paired timber physically stored in its warehouse cell",stock_id)
		service.supplier_state_changed.emit()
		return
