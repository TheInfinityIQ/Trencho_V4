extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var minimum: Dictionary = _fixture("minimum")
	var rear: RefCounted = minimum.base.rear
	_order(minimum,"Seize Objective")
	_check(rear.combat.injure(minimum.roster[3],100).ok,"Actual fourth member incapacitated")
	rear.advance_time(4)
	_check(rear.ledger.inspect_entity(minimum.roster[0]).position.y < 540 and rear.battlefield_operations.status[minimum.squad] == "Withdrawing","Below-minimum squad withdraws even with no visible hostile")
	_check(minimum.base.audit().is_empty(),"Incapacitated motion and live fallback reconcile")
	var assault: Dictionary = _fixture("assault")
	_order(assault,"Assault HQ")
	assault.base.rear.advance_time(3)
	_check(assault.base.rear.battlefield_operations.motions.is_empty() and assault.base.rear.ledger.inspect_entity(assault.roster[0]).position.y == 540,"Acknowledgement cannot bypass the absent HQ preparation gate")
	assault.base.rear.combat._apply_stress(assault.roster[0],-50,0,true)
	assault.base.rear.advance_time(2)
	_check(assault.base.rear.ledger.inspect_entity(assault.roster[0]).position.y < 540,"Refused HQ assault preserves Broken person's physical fallback")
	_check(assault.base.rear.combat.injure(assault.roster[3],100).ok,"HQ assault roster loses its fourth member")
	assault.base.rear.advance_time(2)
	_check(assault.base.rear.ledger.inspect_entity(assault.roster[1]).position.y < 540,"Refused HQ assault preserves below-minimum squad withdrawal")
	var pinned: Dictionary = _fixture("pinned")
	_order(pinned,"Seize Objective")
	pinned.base.rear.advance_time(1)
	var before: Vector2 = pinned.base.rear.ledger.inspect_entity(pinned.roster[0]).position
	pinned.base.rear.combat._apply_stress(pinned.roster[0],0,60,true)
	pinned.base.rear.advance_time(0.25)
	_check(pinned.base.rear.ledger.inspect_entity(pinned.roster[0]).position == before and not pinned.base.rear.battlefield_operations.motions.has(pinned.roster[0]),"Pinned status stops offensive motion before the next decision tick")
	_check(pinned.base.audit().is_empty(),"Pinned motion cleanup preserves physical facts")
	var unsafe: Dictionary = _fixture("unsafe")
	var physical: RefCounted = unsafe.base.rear
	_check(physical.ledger.add_place("unsafe-threat","Observed threat on fallback lane",Vector2(2000,520)).ok,"Actual fallback threat place")
	_check(physical.ledger.add_person("unsafe-hostile","unsafe-threat","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual hostile on fallback lane")
	_check(physical.orders.watch(unsafe.squad).ok,"Actual observation samples the fallback threat")
	physical.advance_time(0.5)
	var operations: RefCounted = physical.battlefield_operations
	operations._walk(unsafe.roster[0],"unsafe-fallback",Vector2(2000,500),true,"Fallback")
	_check(not operations.person_committed(unsafe.roster[0]),"Fallback cannot cross a delivered hostile firing area")
	operations._walk(unsafe.roster[0],"unsafe-goal",Vector2(2000,650),true,"Fallback")
	physical.advance_time(0.25)
	_check(physical.ledger.inspect_entity(unsafe.roster[0]).position.y > 540,"Known incoming fire still permits actual movement away from it")
	print("Execution safety regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _fixture(prefix: String) -> Dictionary:
	var base := Base.new(true,true)
	var rear: RefCounted = base.rear
	for item in [["stage",Vector2(2000,540)],["fallback",Vector2(2000,500)],["goal",Vector2(2000,650)]]: _check(rear.ledger.add_place(prefix+"-"+item[0],"Declared execution location",item[1]).ok,"Actual place")
	var roster: Array[String] = []
	for index in 4:
		var id := prefix+"-person-%d" % index
		_check(rear.ledger.add_person(id,prefix+"-stage",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual starting member")
		_check(rear.ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual rifle")
		_check(rear.ledger.add_stock(id+"-rounds","E02",60,0.02,id,rear.PLAYER).ok,"Actual rounds")
		roster.append(id)
	_check(rear.military.add_initial_squad(prefix+"-squad","Rifle",roster,prefix+"-company",prefix+"-platoon",rear.PLAYER).ok,"Actual hierarchy")
	rear.battlefield_operations = Execution.new(rear)
	return {"base":base,"roster":roster,"prefix":prefix,"squad":prefix+"-squad"}

func _order(fixture: Dictionary, action: String) -> void:
	var prefix: String = fixture.prefix
	_check(fixture.base.rear.orders.issue_order(prefix+"-platoon",fixture.squad,action,"Assigned approach","Regression execution",{"destination":prefix+"-goal","fallback_place":prefix+"-fallback","role":"Rifle"},"Normal","Declared fallback").ok,"Actual delivered tactical intent")
	fixture.base.rear.advance_time(2)

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
