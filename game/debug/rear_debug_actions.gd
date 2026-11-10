extends RefCounted
## Explicit prototype cheats. Current session is supplied per click, never cached.
const STORE := "debug-supplies"
const Raw = preload("res://game/procurement/resource_catalog.gd")

static func execute(model: RefCounted, action: String) -> Dictionary:
	if action not in ["instant_build","force_deliver","infinite_resources"]:
		return {"ok":false,"message":"Unknown debug action."}
	model.debug_used = true
	if action == "infinite_resources" and model.rear.warehouse != null:
		return _warehouse_debug_batch(model)
	if action == "instant_build":
		return model.rear.construction.debug_complete_pending()
	var ids: Array = []
	if action == "infinite_resources":
		var ordered: Dictionary = model.receiving.debug_order_raw_resources()
		if not ordered.ok: return ordered
		ids = ordered.ids
	var rear: RefCounted = model.rear
	var mass: int = model.receiving.debug_pending_resource_mass(ids)
	if mass == 0:
		var empty_cargo: Dictionary = model.receiving.debug_deliver_resources("receiving",ids)
		return _finish_people_delivery(model,empty_cargo) if action == "force_deliver" else empty_cargo
	if not rear.stores.has(STORE):
		# The protected Supply Table approach stays walkable; no new footprint.
		var position: Vector2 = model.receiving.receiving_position+Vector2(0,12)
		var added: Dictionary = rear.ledger.add_place(STORE,"DEBUG supply overflow beside Receiving",position)
		if not added.ok: return added
		rear.stores[STORE] = {"id":STORE,"capacity":0.0,"accessible":true,"filter":[],"pile":false,"source_only":rear.warehouse != null}
	rear.stores[STORE].capacity += float(mass)
	if rear.warehouse != null: rear.stores[STORE].source_only = true
	var result: Dictionary = model.receiving.debug_deliver_resources(STORE,ids)
	if result.ok and action == "infinite_resources":
		result.message = "DEBUG: +1,000 of each of the nine raw resources delivered free beside the Supply Table. Click again for another batch."
	return _finish_people_delivery(model,result) if action == "force_deliver" else result

static func _warehouse_debug_batch(model: RefCounted) -> Dictionary:
	var rear: RefCounted = model.rear
	var entries: Array[Dictionary] = []
	var batch := 1
	while not rear.ledger.entity_kind("debug-batch-%06d-M01" % batch).is_empty(): batch += 1
	for code: String in Raw.MATERIALS:
		var id := "debug-batch-%06d-%s" % [batch,code]
		if not rear.ledger._free_id(id): return {"ok":false,"message":"DEBUG batch IDs are already reserved; nothing granted."}
		entries.append({"id":id,"type":code,"quantity":1000})
	if not rear.stores.has(STORE):
		var created: Dictionary = rear.ledger.add_place(STORE,"DEBUG supply cache — normal warehouse storage bypassed",model.receiving.receiving_position+Vector2(0,12))
		if not created.ok: return created
		rear.stores[STORE] = {"id":STORE,"capacity":0.0,"accessible":true,"filter":[],"pile":false,"source_only":true}
	var result: Dictionary = rear.ledger.add_debug_stock_batch(entries,STORE,rear.PLAYER)
	if result.ok:
		rear.stores[STORE].capacity += 9000.0
		rear.stores[STORE].source_only = true
		result.message = "DEBUG: +1,000 kg of each raw material, free and immediate. Normal warehouse storage bypassed; collect from DEBUG supply cache."
	return result

static func _finish_people_delivery(model: RefCounted, result: Dictionary) -> Dictionary:
	if not result.ok: return result
	var people: Dictionary = model.receiving.debug_deliver_people()
	if not people.ok: return people
	var resource_orders: int = result.ids.size()
	result.ids.append_array(people.ids)
	result.changed = result.get("changed",false) or people.changed
	result.message = "DEBUG: delivered %d resource order(s) and %d arriving worker(s) immediately." % [resource_orders,int(people.people)]
	return result
