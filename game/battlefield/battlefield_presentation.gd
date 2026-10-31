extends RefCounted
## Player information boundary; authoritative enemy state stays in the ledger.

static func markers(rear: RefCounted) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var entities: Array = rear.ledger.snapshot(false).entities
	var kinds := {}
	for entity in entities: kinds[entity.id] = entity.kind
	for entity in entities:
		if entity.kind == "PLACE":
			if rear.objectives.objectives.has(entity.id):
				var owner: String = str(rear.objectives.objectives[entity.id].owner)
				entity["ownership_label"] = ownership_label(owner,rear.PLAYER)
				entity["ownership_colour"] = ownership_colour(owner,rear.PLAYER)
			if entity.id == "hq-berth" or rear.objectives.objectives.has(entity.id) or rear.orders.objective_markers.has(entity.id): rows.append(entity)
		elif entity.kind in ["PERSON","CARRIER"]:
			var affiliation: String = str(entity.controller).trim_suffix("-hq") if entity.kind == "CARRIER" else str(entity.owner)
			if affiliation != rear.PLAYER: continue
			if entity.kind == "PERSON" and entity.rear_place == "Occupied": continue
			entity["affiliation"] = affiliation
			if entity.kind == "PERSON": entity["aboard"] = kinds.get(entity.holder_id,"") == "CARRIER"
			rows.append(entity)
	for target_id in rear.orders.contacts.get("army",{}):
		var report: Dictionary = rear.orders.contact("army",target_id)
		if report.is_empty() or report.confidence <= 0 or not report.position.is_finite() or report.get("class","") in ["Enemy HQ","Resource","Route Hub","Observation"]: continue
		rows.append({"id":target_id,"kind":"CONTACT","position":report.position,"owner":"army-red","affiliation":"army-red","class":report.get("class","Unknown"),"age":report.age,"confidence":report.confidence,"uncertainty_m":report.uncertainty_m})
	return rows

static func inspect(rear: RefCounted, id: String) -> Dictionary:
	for row in markers(rear):
		if row.id == id: return row
	return {}

static func ownership_label(owner: String, player: String = "army-blue") -> String:
	if owner == player: return "Friendly"
	if owner in ["army-blue","army-red"]: return "Enemy"
	return "Neutral"

static func ownership_colour(owner: String, player: String = "army-blue") -> Color:
	match ownership_label(owner,player):
		"Friendly": return Color("74c8ed")
		"Enemy": return Color("e48378")
	return Color("f0c565")
