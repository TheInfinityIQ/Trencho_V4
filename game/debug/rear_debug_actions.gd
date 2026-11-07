extends RefCounted
## Explicit prototype cheats. Current session is supplied per click, never cached.
const STORE := "debug-supplies"

static func execute(model: RefCounted, action: String) -> Dictionary:
	if action not in ["instant_build","force_deliver","infinite_resources"]:
		return {"ok":false,"message":"Unknown debug action."}
	model.debug_used = true
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
		return model.receiving.debug_deliver_resources("receiving",ids)
	if not rear.stores.has(STORE):
		# The protected Supply Table approach stays walkable; no new footprint.
		var position: Vector2 = model.receiving.receiving_position+Vector2(0,12)
		var added: Dictionary = rear.ledger.add_place(STORE,"DEBUG supply overflow beside Receiving",position)
		if not added.ok: return added
		rear.stores[STORE] = {"id":STORE,"capacity":0.0,"accessible":true,"filter":[],"pile":false}
	rear.stores[STORE].capacity += float(mass)
	var result: Dictionary = model.receiving.debug_deliver_resources(STORE,ids)
	if result.ok and action == "infinite_resources":
		result.message = "DEBUG: +1,000 of each of the nine raw resources delivered free beside the Supply Table. Click again for another batch."
	return result
