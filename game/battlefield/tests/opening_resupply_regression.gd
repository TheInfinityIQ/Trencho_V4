extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
const Resupply = preload("res://game/battlefield/opening_resupply.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	var base := Base.new(false,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	check(ledger.add_place("issue-rally","Safe actual receipt",Vector2(2000,500)).ok,"Actual rally")
	check(ledger.add_place("issue-goal","Declared approach",Vector2(2030,500)).ok,"Actual approach")
	check(ledger.add_place("issue-hostile","Observed opponent beyond receipt fire range",Vector2(2170,500)).ok,"Actual hostile place")
	var rifles: Array[String] = []
	var engineers: Array[String] = []
	for role in ["rifle","engineer"]:
		for index in 4:
			var id: String = role+"-issue-%d" % index
			check(ledger.add_person(id,"issue-rally",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02" if role == "engineer" and index < 2 else "None","None").ok,"Real member")
			check(ledger.move_entity(id,"issue-rally",Vector2(2000,500+index*1.5+(8 if role == "engineer" else 0))).ok,"Actual distinct person position")
			check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual retained rifle")
			check(ledger.add_stock(id+"-rounds","E02",60 if role == "rifle" else 30,0.02,id,rear.PLAYER).ok,"Actual initial ammunition")
			if role == "engineer" and index < 2: check(ledger.add_stock(id+"-tools","E08",1,6,id,rear.PLAYER).ok,"Actual Engineer tool")
			if role == "rifle": rifles.append(id)
			else: engineers.append(id)
	check(rear.military.add_initial_squad("issue-rifles","Rifle",rifles,"issue-company","issue-rifle-platoon",rear.PLAYER).ok,"Actual Rifle hierarchy")
	check(rear.military.add_initial_squad("issue-engineers","Engineer",engineers,"issue-company","issue-engineer-platoon",rear.PLAYER).ok,"Actual Engineer hierarchy")
	for id in rifles: check(ledger.record_consumption(id+"-rounds",60,"Declared prior fighting in this regression").ok,"Actual ammunition already expended")
	rear.battlefield_operations = Execution.new(rear)
	var policy := Resupply.new(rear,["issue-rifles"],"issue-engineers","issue-rally")
	rear.battlefield_operations.policy = policy
	check(rear.orders.issue_order("issue-rifle-platoon","issue-rifles","Seize Objective","Approach","Test actual supply response",{"destination":"issue-goal","fallback_place":"issue-rally","role":"Rifle"},"Normal","issue-rally").ok,"Actual tactical intent")
	rear.advance_time(2)
	check(policy.requests.size() == 4 and rear.forward_supply.jobs.is_empty(),"Absent arrived ammunition creates real unmet requests without refilling")
	check(ledger.add_stock("arrived-issue-ammo","E02",300,0.02,"issue-rally",rear.PLAYER).ok,"Declared already-arrived physical test freight")
	rear.advance_time(4)
	check(rear.forward_supply.jobs.size() == 4,"Four actual eligible couriers commit distinct member deficits")
	check(ledger.inspect_entity("arrived-issue-ammo").available == 60,"Concurrent handlers commit the full deficit once through existing reservations/carries")
	for id in rifles: check(rear.military._rounds(id) == 0,"Reservation does not equip a remote person")
	rear.advance_time(25)
	for id in rifles: check(rear.military._rounds(id) == 60,"Actual timed pickup, walking and drop restores a member's package")
	check(rear.forward_supply.jobs.size() == 4 and policy.requests.is_empty(),"Completed desired package does not create duplicate or continuous top-off jobs")
	check(ledger.add_person("issue-opponent","issue-hostile","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual hostile person")
	check(rear.orders.watch("issue-rifles").ok,"Actual observation after safe local issue")
	var before: int = int(ledger.snapshot().consumed.get("E02",0))
	rear.advance_time(20)
	check(int(ledger.snapshot().consumed.get("E02",0)) > before,"Autonomous reload and fire consume the physically issued rounds")
	check(rear.forward_supply.jobs.size() == 4,"Firing a few rounds does not trigger per-shot top off")
	check(base.audit().is_empty(),"Local autonomous issue reconciles original stock, people and duties")
	print("Opening resupply regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
