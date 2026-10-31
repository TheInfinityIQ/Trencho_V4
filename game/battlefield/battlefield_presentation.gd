extends RefCounted
## Player information boundary; authoritative enemy state stays in the ledger.

static func markers(rear: RefCounted) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var entities: Array = rear.ledger.snapshot(false).entities
	for entity in entities:
		var row := _entity_marker(rear,entity)
		if not row.is_empty(): rows.append(row)
	for target_id in rear.orders.contacts.get("army",{}):
		var row := _contact_marker(rear,target_id)
		if not row.is_empty(): rows.append(row)
	return rows

static func inspect(rear: RefCounted, id: String) -> Dictionary:
	# The original ordered marker list puts a visible physical entity before
	# a same-ID contact. Read fresh metadata without rebuilding that whole list.
	var row := _entity_marker(rear,rear.ledger.inspect_entity(id,{},false))
	return row if not row.is_empty() else _contact_marker(rear,id)

static func _entity_marker(rear: RefCounted, entity: Dictionary) -> Dictionary:
	if entity.is_empty(): return {}
	if entity.kind == "PLACE":
		if entity.id != "hq-berth" and not rear.objectives.objectives.has(entity.id) and not rear.orders.objective_markers.has(entity.id): return {}
		var row: Dictionary = entity.duplicate()
		if rear.objectives.objectives.has(entity.id):
			var owner: String = str(rear.objectives.objectives[entity.id].owner)
			row["ownership_label"] = ownership_label(owner,rear.PLAYER)
			row["ownership_colour"] = ownership_colour(owner,rear.PLAYER)
		return row
	elif entity.kind in ["PERSON","CARRIER"]:
		var affiliation: String = str(entity.controller).trim_suffix("-hq") if entity.kind == "CARRIER" else str(entity.owner)
		if affiliation != rear.PLAYER: return {}
		if entity.kind == "PERSON" and entity.rear_place == "Occupied": return {}
		var row: Dictionary = entity.duplicate()
		row["affiliation"] = affiliation
		if entity.kind == "PERSON": row["aboard"] = rear.ledger.entity_kind(entity.holder_id) == "CARRIER"
		return row
	return {}

static func _contact_marker(rear: RefCounted, target_id: String) -> Dictionary:
	var report: Dictionary = rear.orders.contact("army",target_id)
	if report.is_empty() or report.confidence <= 0 or not report.position.is_finite() or report.get("class","") in ["Enemy HQ","Resource","Route Hub","Observation"]: return {}
	return {"id":target_id,"kind":"CONTACT","position":report.position,"owner":"army-red","affiliation":"army-red","class":report.get("class","Unknown"),"age":report.age,"confidence":report.confidence,"uncertainty_m":report.uncertainty_m}

static func ownership_label(owner: String, player: String = "army-blue") -> String:
	if owner == player: return "Friendly"
	if owner in ["army-blue","army-red"]: return "Enemy"
	return "Neutral"

static func ownership_colour(owner: String, player: String = "army-blue") -> Color:
	match ownership_label(owner,player):
		"Friendly": return Color("74c8ed")
		"Enemy": return Color("e48378")
	return Color("f0c565")
