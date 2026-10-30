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
		quit()
		return
	for step in 12:
		rear.advance_time(5)
		var trips: Array = rear.battlefield_operations.policy.snapshot().trips
		print("Opening t=",rear.time," trips=",trips.map(func(trip: Dictionary) -> String: return trip.hull+": "+("Started" if trip.started else trip.blocker)))
	check(rear.military.troop_transport.jobs.size() >= 3,"Delivered hierarchy orders start actual transport")
	check(not rear.battlefield_operations.policy.reserve_active,"Red reserve awaits an actual report")
	check(base.audit().is_empty(),"Active opening reconciles: "+str(base.audit()))
	print("Opening regression: ",failures," failures")
	quit(0 if failures == 0 else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
