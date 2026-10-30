extends SceneTree
## The local issue service must advance and exclude combat on the common clock.

const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	var base := Base.new(true, true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var people: Array[String] = ["clock-shooter", "clock-handler", "clock-guard-a", "clock-guard-b"]
	for id in people:
		_check(ledger.add_person(id, "hq-reserve", rear.PLAYER, Records.Assignment.HQ_RESERVE, true).ok, "Named HQ reserve person")
		rear.dispatch.military_people[id] = "starting-receipt"
		rear.dispatch.hq_reserve[id] = "Occupied"
		_check(ledger.add_weapon(id + "-rifle", "E01", 4.0, id, rear.PLAYER, "E02", 30).ok, "Issued actual rifle")
		_check(ledger.add_stock(id + "-rounds", "E02", 30, 0.02, id, rear.PLAYER).ok, "Issued actual rounds")
	_check(ledger.load_rounds("clock-shooter-rifle", "clock-shooter-rounds", 1).ok, "One actual round is loaded before the handoff")
	rear.advance_time(8)
	_check(rear.military.squads.size() == 1, "G15 formed one actual squad")
	_check(ledger.add_place("clock-stop", "Forward stop", Vector2(500, 20)).ok, "Physical stop exists")
	for index in people.size():
		_check(ledger.move_entity(people[index], "clock-stop", Vector2(505 - index * 2, 20)).ok, "Squad member reached stop")
	_check(ledger.add_place("clock-target-place", "Visible hostile", Vector2(515, 20)).ok, "Hostile place exists")
	_check(ledger.add_person("clock-target", "clock-target-place", "army-red", Records.Assignment.AVAILABLE, true).ok, "Hostile identity exists")
	_check(ledger.reserve_rear_hull("clock-hostile-admission", "army-red", "clock-hostile").ok, "Hostile hull admission exists")
	_check(ledger.create_heavy_output("clock-hostile-admission", "clock-hostile", "clock-hostile", "T02", "clock-target-place", "army-red", Specs.TYPES.T02).ok, "Hostile physical vehicle exists")
	_check(ledger.move_entity("clock-hostile", "clock-target-place", Vector2(515, 20)).ok, "Hostile vehicle is in weapon range")
	var before_issue: Dictionary = rear.vehicle_combat.inspect_personal_vehicle("clock-shooter", "clock-hostile", "clock-shooter-rifle")
	_check(before_issue.ok, "Uncommitted infantry may target nearby hostile vehicle: " + str(before_issue))
	_check(ledger.add_carrier("clock-carrier", "clock-stop", rear.PLAYER, rear.PLAYER).ok, "Real friendly carrier at stop")
	_check(ledger.add_stock("clock-load", "E02", 5, 0.02, "clock-carrier", rear.PLAYER).ok, "Real load aboard carrier")
	var issued: Dictionary = rear.forward_supply.start_issue("clock-load", "clock-shooter", "clock-handler", 5, "clock-stop")
	_check(issued.ok, "Forward issue begins from the arrived load")
	if issued.ok:
		_check(not rear.combat.inspect_fire("clock-shooter", "clock-target", "clock-shooter-rifle").ok, "Committed recipient cannot fire during issue")
		var blocked_vehicle_shot: Dictionary = rear.vehicle_combat.fire_personal_at_vehicle("clock-shooter", "clock-hostile", "clock-shooter-rifle")
		_check(not blocked_vehicle_shot.ok and "handoff" in str(blocked_vehicle_shot.get("blocked_reason", "")), "Committed recipient cannot fire at vehicle through alternate combat path")
		_check(ledger.inspect_entity("clock-shooter-rifle").loaded_rounds == 1, "Blocked vehicle shot preserves loaded round")
		_check(not rear.combat.request_reload("clock-shooter", "clock-shooter-rifle", "clock-shooter-rounds", 5).ok, "Committed recipient cannot reload during issue")
		base.set_speed(1)
		base.tick(20)
		_check(rear.forward_supply.jobs[issued.id].state == "Complete", "Ordinary shared clock completes local pickup and handoff")
		var stock_id: String = rear.forward_supply.jobs[issued.id].issued_stock
		_check(ledger.inspect_entity(stock_id).holder_id == "clock-shooter", "Exact real portion reaches the recipient")
		var vehicle_shot: Dictionary = rear.vehicle_combat.fire_personal_at_vehicle("clock-shooter", "clock-hostile", "clock-shooter-rifle")
		_check(vehicle_shot.ok, "Issue completion releases alternate vehicle fire path: " + str(vehicle_shot))
		rear.advance_time(2)
		var reload: Dictionary = rear.combat.request_reload("clock-shooter", "clock-shooter-rifle", stock_id, 5)
		_check(reload.ok, "Existing G16 reload accepts delivered local rounds: " + str(reload))
		base.tick(20)
		_check(ledger.inspect_entity("clock-shooter-rifle").loaded_rounds == 5, "Reload completes on shared clock")
		_check(rear.combat.fire("clock-shooter", "clock-target", "clock-shooter-rifle").ok, "Physical delivery restores fire")
	_check(base.audit().is_empty(), "Integrated owners and ledger remain consistent")
	print("Forward clock regression: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
