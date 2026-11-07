extends RefCounted
## Explicit-time characterization, shared by capture and GdUnit4 verification.
const Base = preload("res://game/rear_base/base_simulation.gd")
const Opening = preload("res://game/scenario/farmland_session.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Counter = preload("res://game/diagnostics/function_call_log.gd")


static func run() -> Dictionary:
	var states: Dictionary = {}
	var measurements: Dictionary = {}
	var world: RefCounted = Opening.create_empty_field()
	_require(world.set_speed(1))
	states.world_start = _checkpoint(world)
	for _frame in 120: world.tick(1.0 / 60.0)
	states.world_two_seconds = _checkpoint(world)
	measurements.world_checks = measure_checks(world)
	var leader := ""
	for row in world.rear.military.squads.values():
		if row.state == "Active" and row.get("owner", world.rear.PLAYER) == world.rear.PLAYER:
			leader = row.leader
			break
	assert(not leader.is_empty(), "The authored world needs a living active leader.")
	_require(world.rear.combat.injure(leader, 500))
	world.rear.advance_time(0)
	states.leader_incapacitated = _checkpoint(world)
	world.rear.advance_time(4)
	states.leader_waiting = _checkpoint(world)
	world.rear.advance_time(2)
	states.leader_replacement_boundary = _checkpoint(world)
	var hq: RefCounted = hq_fixture()
	states.hq_reserved = _checkpoint(hq)
	for seconds in [2.0, 2.0, 7.5, 8.5, 40.0]:
		hq.rear.advance_time(seconds)
		states["hq_at_" + str(hq.rear.time)] = _checkpoint(hq)
	measurements.hq_checks = measure_checks(hq)
	var coarse: RefCounted = hq_fixture()
	coarse.rear.advance_time(60)
	states.hq_coarse = _checkpoint(coarse)
	var partitioned: RefCounted = hq_fixture()
	for _step in 60: partitioned.rear.advance_time(1)
	states.hq_partitioned = _checkpoint(partitioned)
	return {"states": states, "measurements": measurements}


static func hq_fixture() -> RefCounted:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	_require(ledger.reserve_rear_hull("read-admission", rear.PLAYER, "read-fixture"))
	_require(ledger.create_heavy_output("read-admission", "read-fixture", "read-tank", "T05", "heavy-bay", rear.PLAYER, Specs.TYPES.T05))
	_require(ledger.move_entity("read-tank", "hq-berth", rear.hq.hq_position))
	_require(ledger.complete_hq_hull_receipt("read-tank"))
	rear.dispatch.military_hulls["read-tank"] = "read-receipt"
	_require(ledger.add_stock("read-shells", "E25", 3, 12.0, "hq-stock", rear.PLAYER))
	_require(ledger.add_stock("read-fuel", "M08", 5, 1.0, "hq-stock", rear.PLAYER))
	for trained in [false, true]:
		var id := "read-trained" if trained else "read-untrained"
		_require(ledger.add_person(id, "hq-reserve", rear.PLAYER, Records.Assignment.HQ_RESERVE, trained))
		rear.dispatch.hq_reserve[id] = "Occupied"
		rear.dispatch.military_people[id] = "read-receipt"
	_require(ledger.add_weapon("read-rifle", "E01", 4.0, "hq-stock", rear.PLAYER, "E02", 30))
	_require(ledger.add_stock("read-rounds", "E02", 930, 0.02, "hq-stock", rear.PLAYER))
	rear.advance_time(0)
	return base


static func measure_checks(base: RefCounted, repeats: int = 100) -> Dictionary:
	var result := {}
	var actions := {
		"commander": base.rear.military._sync_commander,
		"auto_vehicle": base.rear.military._auto_vehicle,
		"hq_auto_issue": base.rear.hq._auto_request,
	}
	for label in actions:
		var before := Counter.totals()
		var start := Time.get_ticks_usec()
		for _repeat in repeats: actions[label].call()
		var elapsed := Time.get_ticks_usec() - start
		var after := Counter.totals()
		result[label] = {"repeats": repeats, "elapsed_usec": elapsed,
			"full_inspections": int(after.get("identity/identity_ledger.gd::inspect_entity", 0)) - int(before.get("identity/identity_ledger.gd::inspect_entity", 0))}
	return result


static func _checkpoint(base: RefCounted) -> Dictionary:
	var rear: RefCounted = base.rear
	var state := {"ledger": rear.ledger.snapshot(), "squads": rear.military.squads,
		"platoons": rear.military.platoons, "companies": rear.military.companies,
		"vehicles": rear.military.vehicles, "replacement_reports": rear.military.replacement_reports,
		"crew_reports": rear.military.crew_reports, "commander": rear.military._commander_id,
		"military_status": rear.military.status, "hq_jobs": rear.hq.jobs,
		"hq_status": rear.hq.auto_status, "receiving": base.receiving.snapshot()}
	var text := JSON.stringify(state, "", true, true)
	assert(not text.contains("<RefCounted#"), "Characterization must not include instance-specific object IDs.")
	return {"sha256": text.sha256_text(), "time": rear.time, "audit": base.audit(),
		"tank": _json_safe(rear.ledger.inspect_entity("read-tank")), "rifle": _json_safe(rear.ledger.inspect_entity("read-rifle"))}


static func _json_safe(value: Variant) -> Variant:
	# Keep engine-canonical hashes above unchanged; only sanitize report details.
	if value is float and not is_finite(value): return "-INF" if value < 0 else "INF"
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _json_safe(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(_json_safe(item))
		return result
	return value


static func _require(result: Dictionary) -> void:
	assert(result.ok, str(result))
