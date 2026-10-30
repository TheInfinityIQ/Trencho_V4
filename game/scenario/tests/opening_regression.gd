extends SceneTree
const Session = preload("res://game/scenario/farmland_session.gd")
var failures := 0
func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var base: RefCounted = Session.create()
	print("Opening constructed in ",(Time.get_ticks_msec()-started)/1000.0," s")
	var rear: RefCounted = base.rear
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
	var playthrough: bool = "--playthrough" in OS.get_cmdline_user_args()
	for step in (300 if playthrough else 6):
		rear.advance_time(5)
		var trips: Array = rear.battlefield_operations.policy.snapshot().trips
		if not playthrough or step%12 == 11:
			print("Opening t=",rear.time," phase=",rear.battlefield_operations.policy.phases," consumed=",rear.ledger.snapshot().consumed.get("E02",0)," trips=",trips.map(func(trip: Dictionary) -> String: return trip.hull+": "+("Dismounted" if trip.dismounted else ("Started" if trip.started else trip.blocker))))
	check(rear.military.troop_transport.jobs.values().filter(func(job: Dictionary) -> bool: return job.kind == "Troop Trip").size() == 3,"Delivered hierarchy orders start all three actual troop trips")
	check(rear.battlefield_operations.policy.trips["red-forward"].started,"Red's opening is not blocked by observing its own HQ as hostile")
	if not playthrough: check(not rear.battlefield_operations.policy.reserve_active,"Red reserve awaits an actual report")
	if playthrough:
		check(rear.objectives.events.any(func(event: Dictionary) -> bool: return event.id == "resource-centre-blue" and event.to == "army-blue"),"Blue physically captures its first Resource")
		check(rear.objectives.events.any(func(event: Dictionary) -> bool: return event.id == "resource-centre-red" and event.to == "army-red"),"Red physically deploys and captures its first Resource")
		check(int(rear.ledger.snapshot().consumed.get("E02",0)) > 0,"The ordinary opening produces actual autonomous fire")
		for id in ["start-red-squad-03","start-red-squad-04"]:
			for member in rear.military._active_roster_members(rear.military.squads[id]):
				check(rear.ledger.inspect_entity(member).position.distance_to(Vector2(2000,5380)) <= 35,"Red Engineer/Medical hold their declared HQ support rallies")
	check(base.audit().is_empty(),"Active opening reconciles: "+str(base.audit()))
	print("Opening regression: ",failures," failures")
	quit(0 if failures == 0 else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
