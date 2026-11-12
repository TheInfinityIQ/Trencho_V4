extends RefCounted
## Read-only selected-person facts from the already-permitted row and one held-inventory snapshot.

static func project(rear: RefCounted, person: Dictionary, held: Array) -> Dictionary:
	if person.get("kind","") != "PERSON" or person.get("owner","") != rear.PLAYER or person.get("rear_place","") == "Occupied" or bool(person.get("aboard",false)): return {}
	var id := str(person.id)
	var loose := 0
	var loaded := 0
	var weapons := 0
	var reloading := false
	for item: Dictionary in held:
		if item.get("kind","") == "STOCK" and item.get("design_type","") == "E02":
			loose += int(item.get("quantity",0))
		elif item.get("kind","") == "WEAPON" and item.get("ammo_type","") == "E02":
			weapons += 1
			loaded += int(item.get("loaded_rounds",0))
			var reload: Dictionary = rear.combat.reloads.get(str(item.id),{})
			if str(reload.get("operator","")) == id: reloading = true
	var motion := "Unavailable."
	var operations: RefCounted = rear.battlefield_operations
	if operations != null:
		var current: Dictionary = operations.motions.get(id,{})
		if current.is_empty(): motion = "No current foot-movement record."
		elif bool(current.get("pending",false)): motion = "Foot movement being planned."
		else: motion = "Foot movement in progress."
	var reload_state := "No held E02 weapon."
	if weapons > 0: reload_state = "Reload in progress." if reloading else "No active reload of held E02 weapons."
	return {"loose_e02":loose,"loaded_e02":loaded,"motion":motion,"reload":reload_state,
		"receipt":rear.forward_supply.observe_personal_receipt(rear.PLAYER,person)}
