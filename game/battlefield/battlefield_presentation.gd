extends RefCounted
## Player information boundary; authoritative enemy state stays in the ledger.

static func markers(rear: RefCounted) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var entities: Array = rear.ledger.battlefield_markers(rear.PLAYER)
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
		var stop: Dictionary = rear.forward_supply.delivery_stops.get(entity.id,{}) if rear.forward_supply != null else {}
		var permitted_stop: bool = not stop.is_empty() and str(stop.get("observer_owner","")) == rear.PLAYER
		if entity.id != "hq-berth" and not rear.objectives.objectives.has(entity.id) and not rear.orders.objective_markers.has(entity.id) and not permitted_stop: return {}
		var row: Dictionary = entity.duplicate()
		if permitted_stop: row["friendly_forward_stop"] = true
		if rear.objectives.objectives.has(entity.id):
			var objective: Dictionary = rear.objectives.objectives[entity.id]
			var owner: String = str(objective.owner)
			row["ownership_label"] = ownership_label(owner,rear.PLAYER)
			row["ownership_colour"] = ownership_colour(owner,rear.PLAYER)
			row["objective_kind"] = str(objective.kind)
			row["objective_state"] = str(objective.state)
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
	return {"id":target_id,"kind":"CONTACT","position":report.position,"owner":"army-red","affiliation":"army-red","class":report.get("class","Unknown"),"age":report.age,"confidence":report.confidence,"uncertainty_m":report.uncertainty_m,"expiry_at":report.expiry_at}

static func ownership_label(owner: String, player: String = "army-blue") -> String:
	if owner == player: return "Friendly"
	if owner in ["army-blue","army-red"]: return "Enemy"
	return "Neutral"

static func ownership_colour(owner: String, player: String = "army-blue") -> Color:
	match ownership_label(owner,player):
		"Friendly": return Color("74c8ed")
		"Enemy": return Color("e48378")
	return Color("f0c565")

static func objective_feedback(objective: Dictionary, player: String = "army-blue") -> String:
	if objective.is_empty(): return ""
	var lines: Array[String] = ["Owner: %s · State: %s" % [ownership_label(str(objective.owner),player),objective.state],
		"Control: %.1f / 60" % float(objective.control)]
	var capture_reason: String = str(objective.get("blocked_reason",""))
	if not capture_reason.is_empty(): lines.append("Capture: "+capture_reason)
	if objective.kind == "Resource":
		lines.append("Current resource income: %.1f requisition per simulation second" % float(objective.income_rate))
		lines.append("Credited by this objective this session: %.1f requisition" % float(objective.income))
	else: lines.append("No requisition income from this objective type.")
	var change: Dictionary = objective.get("latest_change",{})
	if change.is_empty():
		lines.append("Latest change: No control change yet.")
		return "\n".join(lines)
	var detail := ""
	if change.from_owner != change.to_owner:
		if change.to_owner == player: detail = "Friendly control gained"
		elif change.from_owner == player: detail = "Friendly control lost"
		elif str(change.to_owner).is_empty(): detail = ownership_label(str(change.from_owner),player)+" control lost"
		else: detail = ownership_label(str(change.to_owner),player)+" control gained"
	elif change.to_state == "Contested": detail = "Contested: both armies have eligible capture presence"
	elif change.from_state == "Contested": detail = "Contest ended"
	else: detail = str(change.to_state)
	if float(change.income_from) > 0 and float(change.income_to) == 0:
		detail += ". Resource income suspended" if change.to_state == "Contested" else ". Resource income ended"
	elif float(change.income_from) == 0 and float(change.income_to) > 0:
		detail += ". Resource income eligible again" if change.from_state == "Contested" else ". Resource income eligible"
	lines.append("Latest at %.1f s: %s." % [float(change.at),detail])
	return "\n".join(lines)
