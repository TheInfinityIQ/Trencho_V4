extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
const Resupply = preload("res://game/battlefield/opening_resupply.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	for observer in ["rifles","engineers"]: _known_fire(observer)
	_interrupted()
	_partial()
	print("Opening resupply edges: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func fixture(amount: int) -> Dictionary:
	var base := Base.new(false,true)
	var rear: RefCounted = base.rear
	check(rear.ledger.add_place("edge-stop","Declared local receipt",Vector2(2000,500)).ok,"Actual stop")
	var people := {}
	for role in ["rifles","engineers"]:
		var ids: Array[String] = []
		for index in 4:
			var id: String = role+"-%d" % index
			check(rear.ledger.add_person(id,"edge-stop",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02" if role == "engineers" and index < 2 else "None","None").ok,"Actual member")
			check(rear.ledger.move_entity(id,"edge-stop",Vector2(2000,500+index*1.5+(8 if role == "engineers" else 0))).ok,"Actual distinct queue")
			check(rear.ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual weapon")
			check(rear.ledger.add_stock(id+"-rounds","E02",60,0.02,id,rear.PLAYER).ok,"Actual rounds")
			if role == "engineers" and index < 2: check(rear.ledger.add_stock(id+"-tools","E08",1,6,id,rear.PLAYER).ok,"Actual tool")
			ids.append(id)
		check(rear.military.add_initial_squad(role,"Rifle" if role == "rifles" else "Engineer",ids,"edge-company",role+"-platoon",rear.PLAYER).ok,"Actual hierarchy")
		people[role] = ids
	for id in people.rifles: check(rear.ledger.record_consumption(id+"-rounds",60,"Declared earlier fighting in edge regression").ok,"Existing local ammunition expended")
	if amount > 0: check(rear.ledger.add_stock("edge-arrived","E02",amount,0.02,"edge-stop",rear.PLAYER).ok,"Declared physical arrived test freight")
	rear.battlefield_operations = Execution.new(rear)
	var policy := Resupply.new(rear,["rifles"],"engineers","edge-stop")
	return {"base":base,"rear":rear,"policy":policy,"people":people}
func _known_fire(observer: String) -> void:
	var f := fixture(300)
	check(f.rear.ledger.move_entity("rifles-0","edge-stop",Vector2(2019,500)).ok,"Recipient occupies allowed nineteen-metre offset")
	check(f.rear.ledger.add_place("edge-hostile","Actual known fire",Vector2(2175,500)).ok,"Actual hostile place")
	check(f.rear.ledger.add_person("edge-enemy","edge-hostile","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual visible hostile")
	check(f.rear.orders.watch(observer).ok,"Actual named element observes")
	f.rear.advance_time(0.5)
	check(not f.rear.orders.contact(observer,"edge-enemy").is_empty(),"Real report delivered before admission")
	f.policy.tick()
	check(f.rear.forward_supply.jobs.is_empty(),"Known fire denies an offset handoff even when observed only by "+observer)
	check(f.rear.military._rounds("rifles-0") == 0,"Unsafe receipt never refills the recipient")
	check(f.base.audit().is_empty(),"Known-fire refusal leaves physical facts intact")
func _interrupted() -> void:
	var f := fixture(300)
	f.rear.battlefield_operations.policy = f.policy
	f.rear.advance_time(7)
	var job: Dictionary = {}
	for row in f.rear.forward_supply.jobs.values():
		if row.recipient == "rifles-0": job = row
	check(not job.is_empty() and not str(job.get("carried_stock","")).is_empty(),"Actual source pickup completed before interruption")
	if job.is_empty(): return
	var portion: String = job.carried_stock
	var count: int = f.rear.forward_supply.jobs.size()
	var claim_count: int = f.rear.ledger.snapshot().claims.size()
	check(f.rear.forward_supply.interrupt(job.id).ok,"Interrupt actual carried handoff")
	check(f.rear.ledger.move_entity("rifles-0","edge-stop",Vector2(2025,500)).ok,"Recipient leaves legal rendezvous")
	f.rear.advance_time(2)
	check(job.state == "Interrupted Carry" and f.rear.military._rounds("rifles-0") == 0,"Same portion waits without remote handoff or duplicate issue")
	check(f.rear.ledger.move_entity("rifles-0","edge-stop",Vector2(2001,500)).ok,"Recipient physically returns to safe receipt")
	f.rear.advance_time(8)
	var original: Dictionary = f.rear.ledger.inspect_entity(portion)
	var issued: Dictionary = f.rear.ledger.inspect_entity(job.issued_stock)
	check(job.state == "Complete" and job.carried_stock == portion and original.quantity == 0 and issued.get("quantity",0) == 60 and issued.get("origin_id","") == original.origin_id,"Autonomous resume delivers the same carried portion through normal ledger split lineage")
	check(f.rear.military._rounds("rifles-0") == 60 and f.rear.forward_supply.jobs.size() == count,"Resume restores package without a second source claim")
	check(f.rear.ledger.snapshot().claims.size() == claim_count,"Interrupted carry resumes without allocating a new source claim")
	check(f.base.audit().is_empty(),"Interrupted/resumed courier reconciles")
func _partial() -> void:
	var f := fixture(20)
	f.rear.battlefield_operations.policy = f.policy
	f.rear.advance_time(20)
	check(f.rear.military._rounds("rifles-0") == 20 and f.policy.requests.has("rifles-0"),"Partial source preserves remaining real package demand")
	check(f.rear.ledger.add_stock("edge-replenished","E02",220,0.02,"edge-stop",f.rear.PLAYER).ok,"A separate actual freight portion later arrives")
	f.rear.advance_time(25)
	for id in f.people.rifles: check(f.rear.military._rounds(id) == 60,"Later source finishes the actual remaining deficit")
	check(f.policy.requests.is_empty() and f.base.audit().is_empty(),"Partial and later delivery neither duplicate nor lose rounds")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
