extends SceneTree
## Arranged authored-force objective transitions; no ordinary combat/supply-cycle claim.
const Farmland = preload("res://game/scenario/farmland_session.gd")
const BattlefieldView = preload("res://game/battlefield/battlefield_view.gd")
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _require(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _move_people(rear: RefCounted, people: Array, destination: String) -> bool:
	var at: Vector2 = rear.ledger.inspect_entity(destination,{},false).position
	for index in people.size():
		if not _require(rear.ledger.move_entity(str(people[index]),destination,at+Vector2(index,0)).ok,"Arrange the same authored people at a physical endpoint."): return false
	return true

func _run() -> void:
	var base: RefCounted = Farmland.create_empty_field()
	var rear: RefCounted = base.rear
	var armies: Dictionary = rear.battlefield_operations.policy.armies
	var blue: Array = rear.military.squads[armies[rear.PLAYER].rifles[0]].roster
	var red: Array = rear.military.squads[armies["army-red"].rifles[0]].roster
	# Isolate the capture authority from autonomous combat/orders, retaining all
	# existing identities, weapons, rounds, receiving account and real clock.
	rear.battlefield_operations = null
	var objective_id := "resource-centre-blue"
	if not _move_people(rear,blue,objective_id): return
	rear.advance_time(0)
	var view := BattlefieldView.new()
	view.bind(base)
	view.selected_id = objective_id
	root.add_child(view)
	for _frame in 2: await process_frame
	rear.advance_time(15)
	var captured: Dictionary = rear.objectives.inspect(objective_id)
	if not _require(captured.owner == rear.PLAYER and captured.state == "Controlled" and captured.income_rate == 1.5 and captured.income == 0,"Actual eligible people establish friendly ownership before any objective credit."): return
	if not _require(not captured.get("latest_change",{}).is_empty(),"Capture must retain the actual latest transition for player feedback."): return
	if not _require(captured.latest_change.at == rear.time and captured.latest_change.from_owner == "" and captured.latest_change.to_owner == rear.PLAYER and captured.latest_change.income_from == 0 and captured.latest_change.income_to == 1.5,"Capture feedback records actual owner and rate transition, not payment."): return
	view._refresh()
	if not _require(view._inspector.text.contains("State: Controlled") and view._inspector.text.contains("Friendly control gained") and view._inspector.text.contains("Credited by this objective this session: 0.0 requisition"),"Actual inspector separates current control and rate from credited money."): return
	rear.advance_time(4)
	if not _require(rear.objectives.inspect(objective_id).income == 6,"Uncontested real control credits six requisition in four seconds."): return
	if not _move_people(rear,red,objective_id): return
	rear.advance_time(0)
	var contested: Dictionary = rear.objectives.inspect(objective_id)
	if not _require(contested.state == "Contested" and contested.owner == rear.PLAYER and contested.income_rate == 0 and contested.latest_change.income_from == 1.5 and contested.latest_change.income_to == 0,"Actual opposing presence contests without removing the current owner and pauses income."): return
	view._refresh()
	if not _require(view._inspector.text.contains("State: Contested") and view._inspector.text.contains("Resource income suspended") and view._inspector.text.contains("Credited by this objective this session: 6.0 requisition"),"Inspector explains contested income without claiming earned money was lost."): return
	var prior_income: float = rear.receiving.snapshot().income
	rear.advance_time(4)
	if not _require(rear.objectives.inspect(objective_id).income == 6 and is_equal_approx(rear.receiving.snapshot().income-prior_income,24),"Contest contributes no objective credit while existing baseline income continues."): return
	if not _move_people(rear,red,str(armies["army-red"].staging)): return
	rear.advance_time(0)
	var cleared: Dictionary = rear.objectives.inspect(objective_id)
	if not _require(cleared.state == "Controlled" and cleared.income_rate == 1.5 and not cleared.blue.is_empty() and cleared.red.is_empty() and cleared.capture_rate == 0 and cleared.latest_change.from_state == "Contested" and cleared.latest_change.income_from == 0 and cleared.latest_change.income_to == 1.5,"Leaving real opposing people clears contest and resumes eligibility."): return
	view._refresh()
	if not _require(view._inspector.text.contains("Contest ended") and view._inspector.text.contains("Resource income eligible again") and not view._inspector.text.contains("no opposing capture presence"),"Red departure ends contest without claiming enemy clearance."): return
	rear.advance_time(4)
	if not _require(rear.objectives.inspect(objective_id).income == 12,"Resumed eligible control credits a further six requisition."): return
	if not _move_people(rear,red,objective_id): return
	rear.advance_time(0)
	if not _require(rear.objectives.inspect(objective_id).state == "Contested","Returning actual Red presence must start another contest before Blue leaves."): return
	if not _move_people(rear,blue,str(armies[rear.PLAYER].staging)): return
	rear.advance_time(0)
	var blue_left: Dictionary = rear.objectives.inspect(objective_id)
	if not _require(blue_left.owner == rear.PLAYER and blue_left.state == "Controlled" and blue_left.blue.is_empty() and not blue_left.red.is_empty() and blue_left.capture_rate == -4 and blue_left.income_rate == 1.5 and blue_left.latest_change.from_state == "Contested","Blue departure ends contest while Red continues neutralizing the still-friendly objective under existing income rules."): return
	view._refresh()
	if not _require(view._inspector.text.contains("Contest ended") and not view._inspector.text.contains("no opposing capture presence") and not view._inspector.text.contains("Contest cleared") and view._inspector.text.contains("Current resource income: 1.5"),"Blue departure cannot claim Red capture presence cleared or stop pre-neutralization income early."): return
	rear.advance_time(1)
	if not _require(rear.objectives.inspect(objective_id).control == 56 and rear.objectives.inspect(objective_id).income == 13.5,"Red capture work continues while unchanged friendly ownership credits its final pre-neutralization income."): return
	rear.advance_time(14)
	var lost: Dictionary = rear.objectives.inspect(objective_id)
	if not _require(lost.owner == "" and lost.control == 0 and lost.income_rate == 0 and lost.latest_change.from_owner == rear.PLAYER and lost.latest_change.to_owner == "","Existing opposing capture work removes friendly ownership at the real zero-control boundary."): return
	view._refresh()
	if not _require(view._inspector.text.contains("Friendly control lost") and view._inspector.text.contains("Resource income ended"),"Inspector explains actual friendly control and income loss."): return
	var transition: Dictionary = lost.latest_change.duplicate(true)
	var events_before: int = rear.objectives.events.size()
	for _repeat in 3: rear.advance_time(0)
	if not _require(rear.objectives.inspect(objective_id).latest_change == transition and rear.objectives.events.size() == events_before,"Repeated unchanged settlement cannot create another transition or ownership event."): return
	var physical_before: Dictionary = rear.ledger.snapshot(false)
	var objectives_before: Dictionary = rear.objectives.snapshot()
	var money_before: Dictionary = rear.receiving.snapshot()
	lost.latest_change.to_owner = "detached-check"
	for _repeat in 3: view._refresh()
	if not _require(rear.ledger.snapshot(false) == physical_before and rear.objectives.snapshot() == objectives_before and rear.receiving.snapshot() == money_before,"Detached nested transition and repeated UI reads preserve physical, objective and money authority."): return
	if not _require(rear.ledger.inspect_entity("start-blue-hq-E02",{},false).quantity == 6000,"Authored6000 HQ rifle rounds remain untouched."): return
	# Repeat both departures on neutral ground using only the same authored
	# people and zero existing control. No owner, credit or absence is invented.
	if not _move_people(rear,blue,objective_id): return
	rear.advance_time(0)
	if not _require(rear.objectives.inspect(objective_id).state == "Contested" and rear.objectives.inspect(objective_id).owner.is_empty(),"Both real sides contest the now-neutral objective."): return
	if not _move_people(rear,red,str(armies["army-red"].staging)): return
	rear.advance_time(0)
	var neutral_blue: Dictionary = rear.objectives.inspect(objective_id)
	view._refresh()
	if not _require(neutral_blue.state == "Neutral" and neutral_blue.owner.is_empty() and neutral_blue.capture_rate == 4 and neutral_blue.income_rate == 0 and view._inspector.text.contains("Contest ended") and not view._inspector.text.contains("no opposing capture presence"),"Red departure leaves actual Blue capture work on neutral ground without granting ownership, income or claimed clearance."): return
	rear.advance_time(1)
	if not _require(rear.objectives.inspect(objective_id).control == 4,"Remaining Blue people earn actual neutral capture progress."): return
	if not _move_people(rear,red,objective_id): return
	rear.advance_time(0)
	if not _require(rear.objectives.inspect(objective_id).state == "Contested","Red return must actually contest neutral progress before Blue leaves."): return
	if not _move_people(rear,blue,str(armies[rear.PLAYER].staging)): return
	rear.advance_time(0)
	var neutral_red: Dictionary = rear.objectives.inspect(objective_id)
	view._refresh()
	if not _require(neutral_red.state == "Neutral" and neutral_red.owner.is_empty() and neutral_red.capture_rate == -4 and neutral_red.income_rate == 0 and view._inspector.text.contains("Contest ended") and not view._inspector.text.contains("no opposing capture presence") and not view._inspector.text.contains("Contest cleared"),"Blue departure leaves real Red capture work on neutral ground without a false clearance claim."): return
	rear.advance_time(1)
	if not _require(rear.objectives.inspect(objective_id).control == 0,"Remaining Red people reverse actual neutral capture progress."): return
	var replacement: RefCounted = Farmland.create_empty_field()
	view.bind(replacement)
	view._refresh()
	if not _require(replacement.rear.objectives.inspect(objective_id).get("latest_change",{}).is_empty() and not view._inspector.text.contains("Friendly control lost") and not view._inspector.text.contains("Contest ended"),"Binding a new simulation cannot retain the previous objective transition."): return
	if not _require(base.audit().is_empty() and replacement.audit().is_empty(),"Arranged transitions and inspection preserve actual identities and accounting."): return
	view.queue_free()
	for _frame in 2: await process_frame
	print(JSON.stringify({"result":"PASS","checks":checks,"scope":"Arranged authored-force capture/contest/both departures/loss including neutral ground, actual credit timing, headless real inspector text, duplicate settlement, detached reads and simulation replacement. No ordinary combat, supply return/reuse, second replenishment, native-input, visible rendering or FPS certification."}))
	quit(0)
