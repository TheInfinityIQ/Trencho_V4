extends SceneTree
const Session = preload("res://game/scenario/farmland_session.gd")
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
				if not str(event.description).begins_with("One loaded round fired from start-blue-squad-0"): continue
				if rear.ledger.inspect_entity(event.entity_id).get("origin_id","") == "start-blue-hq-E02": arrived_round_fired = true; print("SUPPLY DELIVERED ROUND FIRED ",event)
		var trips: Array = rear.battlefield_operations.policy.snapshot().trips
		if not playthrough or step%12 == 11:
			print("Opening t=",rear.time," phase=",rear.battlefield_operations.policy.phases," consumed=",rear.ledger.snapshot().consumed.get("E02",0)," trips=",trips.map(func(trip: Dictionary) -> String: return trip.hull+": "+("Dismounted" if trip.dismounted else ("Started" if trip.started else trip.blocker))))
			if supply_playthrough:
				print("SUPPLY OBSERVE ",rear.battlefield_operations.policy.resupply.snapshot()," delivery=",rear.forward_supply.transport.jobs.get(delivery_id,{}).get("state","Not requested")," rifle_status=",rear.battlefield_operations.status)
		if supply_playthrough and arrived_round_fired and rear.forward_supply.transport.jobs[delivery_id].state == "Complete": break
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
		check(not delivery_id.is_empty() and rear.forward_supply.transport.jobs[delivery_id].state == "Complete","Actual500E02 delivery and same-hull return completes")
		check(first_issue_at >= 0,"Natural combat need reaches physical autonomous Engineer issue")
		check(arrived_round_fired,"Forward Rifle actually fires a round descended from the delivered HQ stock")
	check(base.audit().is_empty(),"Active opening reconciles: "+str(base.audit()))
	print("Opening regression: ",failures," failures")
	quit(0 if failures == 0 else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
