extends SceneTree
const Session = preload("res://game/scenario/farmland_session.gd")
const Records = preload("res://game/identity/identity_records.gd")
var failures := 0
func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var base: RefCounted = Session.create()
	print("Opening constructed in ",(Time.get_ticks_msec()-started)/1000.0," s")
	var rear: RefCounted = base.rear
	var refused_first: bool = "--refuse-first-lift" in OS.get_cmdline_user_args()
	if refused_first: rear.battlefield_operations.policy.trips["blue-rifles"].outbound = []
	check(rear.time == 0 and base.speed == 0,"Session begins paused")
	check(rear.objectives.objectives.size() == 9 and rear.military.squads.size() == 10,"Complete authored opening is populated")
	check(rear.military.vehicles.size() == 8,"Both armies attach their four physical hulls")
	check(base.audit().is_empty(),"Initial session reconciles: "+str(base.audit()))
	for entity in rear.ledger.snapshot().entities:
		check(is_equal_approx(float(entity.contents_mass_kg),float(rear.ledger.inspect_entity(entity.id).contents_mass_kg)),"Snapshot preserves recursive mass for "+entity.id)
	var player: Dictionary = base.snapshot()
	check(player.military.squads.size() == 5 and player.combat.formations.size() == 5,"Player panels include own formations only")
	check(rear.ledger.total_stock("E01",rear.PLAYER) == 56 and rear.ledger.total_stock("E02",rear.PLAYER) == 8820,"Own goods readout does not expose opposing inventory totals")
	check(not player.rear.people.any(func(person: Dictionary) -> bool: return person.owner == "army-red"),"Staff panel excludes hidden enemy people")
	if "--profile-steady" in OS.get_cmdline_user_args():
		rear.advance_time(6)
		EngineDebugger.profiler_enable("scripts",false)
		print("STEADY PROFILE START")
		EngineDebugger.profiler_enable("scripts",true)
		rear.advance_time(2)
		EngineDebugger.profiler_enable("scripts",false)
		print("STEADY PROFILE END")
		quit()
		return
	if "--profile-only" in OS.get_cmdline_user_args() or "--profile-transport" in OS.get_cmdline_user_args():
		rear.advance_time(6 if "--profile-transport" in OS.get_cmdline_user_args() else 1)
		print("Opening first second at ",(Time.get_ticks_msec()-started)/1000.0," wall seconds")
		for id in rear.battlefield_operations.policy.trips:
			var trip: Dictionary = rear.battlefield_operations.policy.trips[id]
			print(id," started=",trip.started," blocker=",trip.blocker)
		quit()
		return
	var supply_playthrough: bool = "--supply-playthrough" in OS.get_cmdline_user_args()
	var playthrough: bool = "--playthrough" in OS.get_cmdline_user_args() or supply_playthrough
	var forward_rifle_weapons := {}
	if supply_playthrough:
		for squad_id in ["start-blue-squad-00","start-blue-squad-01"]:
			for person_id in rear.military._active_roster_members(rear.military.squads[squad_id]):
				for weapon in rear.ledger.entities_at(person_id,["WEAPON"],false):
					if weapon.design_type == "E01": forward_rifle_weapons[weapon.id] = true
	var delivery_id := ""
	var first_issue_at := -1.0
	var consumed_at_issue := 0
	var arrived_round_fired := false
	var event_cursor := 0
	for step in (480 if supply_playthrough else (300 if playthrough else 6)):
		rear.advance_time(5)
		if supply_playthrough and delivery_id.is_empty() and rear.time >= 420:
			var loaders: Array = rear.dispatch.free_hq_handlers(4)
			var route: Dictionary = rear.forward_supply.delivery_stops["blue-delivery"]
			if not loaders.is_empty():
				var result: Dictionary = rear.forward_supply.request_delivery("start-blue-vehicle-02","start-blue-hq-E02",500,"blue-delivery",route.outbound_points,route.return_points,loaders[0],"start-blue-squad-03-person-00")
				if result.ok: delivery_id = result.id; print("SUPPLY ACTUAL REQUEST t=",rear.time," ",result)
				elif step%12 == 11: print("SUPPLY REQUEST BLOCKER ",result)
		if supply_playthrough and first_issue_at < 0 and rear.forward_supply.jobs.values().any(func(job: Dictionary) -> bool: return job.state == "Complete"):
			first_issue_at = rear.time
			consumed_at_issue = int(rear.ledger.snapshot().consumed.get("E02",0))
			print("SUPPLY ACTUAL ISSUE t=",first_issue_at," jobs=",rear.forward_supply.jobs)
		if supply_playthrough:
			# Exact fired-portion lineage proves delivered freight was used by a
			# forward Rifle member, rather than counting unrelated army-wide shots.
			var events: Array = rear.ledger.get("_events")
			while event_cursor < events.size():
				var event: Dictionary = events[event_cursor]
				event_cursor += 1
				var description: String = str(event.description)
				if not description.begins_with("One loaded round fired from "): continue
				if not forward_rifle_weapons.has(description.trim_prefix("One loaded round fired from ")): continue
				if rear.ledger.inspect_entity(event.entity_id).get("origin_id","") == "start-blue-hq-E02": arrived_round_fired = true; print("SUPPLY DELIVERED ROUND FIRED ",event)
		var trips: Array = rear.battlefield_operations.policy.snapshot().trips
		if not playthrough or step%12 == 11:
			print("Opening t=",rear.time," phase=",rear.battlefield_operations.policy.phases," consumed=",rear.ledger.snapshot().consumed.get("E02",0)," trips=",trips.map(func(trip: Dictionary) -> String: return trip.hull+": "+("Dismounted" if trip.dismounted else ("Started" if trip.started else trip.blocker))))
			if supply_playthrough:
				print("SUPPLY OBSERVE ",rear.battlefield_operations.policy.resupply.snapshot()," delivery=",rear.forward_supply.transport.jobs.get(delivery_id,{}).get("state","Not requested")," rifle_status=",rear.battlefield_operations.status)
		if supply_playthrough and arrived_round_fired and not delivery_id.is_empty() and rear.forward_supply.transport.jobs.get(delivery_id,{}).get("state","") == "Complete": break
	var lift_count: int = rear.military.troop_transport.jobs.values().filter(func(job: Dictionary) -> bool: return job.kind == "Troop Trip").size()
	check(lift_count >= 3 if playthrough else lift_count == (2 if refused_first else 3),"Delivered hierarchy orders start eligible initial troop trips; later reserve activation may add another")
	var admission_times: Array = []
	for id in ["blue-rifles","blue-support","red-forward"]:
		var trip: Dictionary = rear.battlefield_operations.policy.trips[id]
		if not trip.started: continue
		check(trip.admitted_at not in admission_times,"Initial physical admissions occupy distinct existing decision ticks")
		admission_times.append(trip.admitted_at)
	if refused_first:
		check(not rear.battlefield_operations.policy.trips["blue-rifles"].started and not rear.battlefield_operations.policy.trips["blue-rifles"].blocker.is_empty(),"Invalid first lift retains its actual refusal")
		check(rear.battlefield_operations.policy.trips["blue-support"].started,"A refused first lift does not starve the next friendly lift")
	check(rear.battlefield_operations.policy.trips["red-forward"].started,"Red's opening is not blocked by observing its own HQ as hostile")
	if not playthrough: check(not rear.battlefield_operations.policy.reserve_active,"Red reserve awaits an actual report")
	if playthrough:
		check(rear.objectives.events.any(func(event: Dictionary) -> bool: return event.id == "resource-centre-blue" and event.to == "army-blue"),"Blue physically captures its first Resource")
		check(rear.objectives.events.any(func(event: Dictionary) -> bool: return event.id == "resource-centre-red" and event.to == "army-red"),"Red physically deploys and captures its first Resource")
		check(int(rear.ledger.snapshot().consumed.get("E02",0)) > 0,"The ordinary opening produces actual autonomous fire")
		for id in ["start-red-squad-03","start-red-squad-04"]:
			for member in rear.military._active_roster_members(rear.military.squads[id]):
				check(rear.ledger.inspect_entity(member).position.distance_to(Vector2(2000,5380)) <= 35,"Red Engineer/Medical hold their declared HQ support rallies")
	if supply_playthrough:
		check(not delivery_id.is_empty() and rear.forward_supply.transport.jobs.get(delivery_id,{}).get("state","") == "Complete","Actual500E02 delivery and same-hull return completes")
		check(first_issue_at >= 0,"Natural combat need reaches physical autonomous Engineer issue")
		check(arrived_round_fired,"Forward Rifle actually fires a round descended from the delivered HQ stock")
	check(base.audit().is_empty(),"Active opening reconciles: "+str(base.audit()))
	if playthrough: _print_final_diagnostics(rear)
	print("Opening regression: ",failures," failures")
	quit(0 if failures == 0 else 1)

static func _print_final_diagnostics(rear: RefCounted) -> void:
	# Final read only: no extra simulation steps or per-tick observations.
	# A status label has no recorded timestamp and does not prove movement.
	# Narrow metadata queries avoid copying the long run's full event history.
	var entities: Array[Dictionary] = rear.ledger.entities_of_kind(Records.Kind.PERSON,false)
	entities.append_array(rear.ledger.entities_of_kind(Records.Kind.WEAPON,false))
	entities.append_array(rear.ledger.entities_of_type("E02",["STOCK"],false))
	var by_id := {}
	var rounds := {}
	for entity in entities: by_id[entity.id] = entity
	for entity in entities:
		if entity.kind != "STOCK" or entity.design_type != "E02" or entity.quantity <= 0: continue
		var holder: Dictionary = by_id.get(entity.holder_id,{})
		var person_id: String = str(holder.get("holder_id","")) if holder.get("kind","") == "WEAPON" else str(entity.holder_id)
		var bucket: String = "loaded" if holder.get("kind","") == "WEAPON" else "loose"
		if not rounds.has(person_id): rounds[person_id] = {"loose":0,"loaded":0}
		rounds[person_id][bucket] += int(entity.quantity)
	var latest_blockers := {}
	var report_rows: Array = rear.orders.reports.duplicate()
	for entry in rear.orders.pending:
		if entry.kind == "Report": report_rows.append(entry.report)
	for report in report_rows:
		if report.kind not in ["Blocked Route","Inability","Lost Capability","Low Supply"]: continue
		var prior: Dictionary = latest_blockers.get(report.source,{})
		if prior.is_empty() or float(report.observed_at) >= float(prior.observed_at): latest_blockers[report.source] = report
	print("FINAL DIAGNOSTICS sampled_at=",rear.time,"; current physical roster facts; recorded labels/reports are historical, not proof of ongoing movement; E02 includes reserved/foreign physically held portions")
	for squad in rear.military.squads.values():
		var living := 0
		var health_positive := 0
		var missing := 0
		var centre := Vector2.ZERO
		var low := Vector2.INF
		var high := -Vector2.INF
		var loose := 0
		var loaded := 0
		var motion_records: Array[Dictionary] = []
		for id in squad.roster:
			var person: Dictionary = by_id.get(id,{})
			if person.get("kind","") != "PERSON": missing += 1; continue
			var held: Dictionary = rounds.get(id,{})
			loose += int(held.get("loose",0))
			loaded += int(held.get("loaded",0))
			if person.assignment != "Dead":
				living += 1
				centre += person.position
				low = low.min(person.position)
				high = high.max(person.position)
			if person.health > 0: health_positive += 1
			var motion: Dictionary = rear.battlefield_operations.motions.get(id,{})
			if not motion.is_empty(): motion_records.append({"person":id,"purpose":motion.purpose,"started_at":motion.started,"deadline":motion.deadline})
		var positions: Dictionary = {} if living == 0 else {"centroid":centre/living,"min":low,"max":high}
		var report: Dictionary = latest_blockers.get(squad.id,{})
		var blocker: Dictionary = {} if report.is_empty() else {"id":report.id,"kind":report.kind,"detail":report.detail,"observed_at":report.observed_at,"age_at_sample":rear.time-float(report.observed_at),"report_state":report.state,"current_at":report.current_at}
		var intent: Dictionary = rear.orders.intents.get(squad.id,{})
		print("FINAL SQUAD ",squad.id," ",{"owner":squad.get("owner",rear.PLAYER),"roster_count":squad.roster.size(),"missing_roster_ids":missing,"living_not_dead":living,"health_positive":health_positive,"living_positions":positions,"E02_roster_loose":loose,"E02_roster_loaded":loaded,"E02_roster_total":loose+loaded,"last_status_time_unknown":rear.battlefield_operations.status.get(squad.id,"Not recorded"),"motion_records_at_sample":motion_records,"last_recorded_blocker_report":blocker,"intent_action":intent.get("action","None"),"intent_state":intent.get("state","None"),"contacts":_final_contacts(rear,squad.id)})
	var owners: Array[Dictionary] = []
	for objective in rear.objectives.objectives.values():
		owners.append({"id":objective.id,"owner":objective.owner,"state":objective.state,"control":objective.control,"last_at":objective.last_at})
	print("FINAL OBJECTIVES sampled_at=",rear.time," ",owners)

static func _final_contacts(rear: RefCounted, squad_id: String) -> Dictionary:
	var known: Array = rear.orders.contacts.get(squad_id,{}).values()
	known.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.observed_at) > float(b.observed_at))
	var actors: Array = known.filter(func(contact: Dictionary) -> bool: return contact.get("class","") not in ["Resource","Route Hub","Observation","Enemy HQ"])
	var sampled: Array = actors if not actors.is_empty() else known
	var newest: Array[Dictionary] = []
	# Bound final contact reads: report exactly which newest contacts were
	# sampled, rather than claiming currentness for the whole historical set.
	for index in mini(3,sampled.size()):
		var contact: Dictionary = rear.orders.contact(squad_id,str(sampled[index].target))
		newest.append({"target":contact.target,"class":contact.get("class",""),"observed_at":contact.observed_at,"age_at_sample":contact.age,"current_at_sample":contact.current})
	return {"recorded_count":known.size(),"actor_report_count":actors.size(),"sample_kind":"Newest actor reports" if not actors.is_empty() else "Newest markers; no actor reports","newest_three_sampled":newest}

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
