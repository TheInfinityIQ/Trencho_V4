extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var base := Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	check(ledger.add_place("sustain-stage","Actual deployment",Vector2(2000,540)).ok,"Actual stage")
	check(ledger.add_place("sustain-goal","Assigned objective",Vector2(2000,650)).ok,"Actual goal")
	var roster: Array[String] = []
	for index in 8:
		var id := "sustain-person-%d" % index
		check(ledger.add_person(id,"sustain-stage",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual member")
		check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual issued rifle")
		check(ledger.add_stock(id+"-ammo","E02",30,0.02,id,rear.PLAYER).ok,"Actual deployment rounds")
		check(ledger.load_rounds(id+"-rifle",id+"-ammo",1).ok,"Actual loaded round")
		roster.append(id)
	check(rear.military.add_initial_squad("sustain-squad","Rifle",roster,"sustain-company","sustain-platoon",rear.PLAYER).ok,"Actual full hierarchy")
	check(rear.military.capability("sustain-squad").ok,"Thirty per person meets deployment gate")
	check(rear.military._held(roster[0],"E01") == 1 and rear.military._held(roster[0],"E02") == 29 and rear.military._rounds(roster[0]) == 30,"Metadata counts preserve one rifle, twenty-nine loose rounds and one loaded round exactly once")
	var full_strength: float = rear.orders._squad_strength("sustain-squad")
	check(ledger.fire_loaded_round(roster[0]+"-rifle").ok,"One actual round expended")
	check(rear.military._held(roster[0],"E02") == 29 and rear.military._rounds(roster[0]) == 29,"Actual shot changes loaded-plus-loose count without inventing a loose round")
	check(not rear.military.capability("sustain-squad").ok,"Twenty-nine still fails a new deployment package")
	check(rear.military.capability("sustain-squad","Sustained Execution").ok,"Twenty-nine does not end existing Rifle intent")
	check(is_equal_approx(rear.orders._squad_strength("sustain-squad"),full_strength),"Actual reloadable member retains armed strength below deployment threshold")
	rear.battlefield_operations = Execution.new(rear)
	check(rear.orders.issue_order("sustain-platoon","sustain-squad","Seize Objective","Continue assigned approach","Sustained execution regression",{"destination":"sustain-goal","fallback_place":"sustain-stage","role":"Rifle"},"Normal","Actual staging").ok,"Actual tactical intent")
	rear.advance_time(8)
	check(rear.battlefield_operations.status["sustain-squad"] != "Withdrawing" and ledger.inspect_person_status(roster[0]).position.y > 540,"Below-package acknowledged squad keeps actual movement")
	# Controlled prior expenditure isolates empty-member accounting, not playthrough evidence.
	for index in 4: _empty(rear,roster[index])
	check(rear.military.squads["sustain-squad"].roster.size() == 8,"Four armed members do not rewrite eight actual identities")
	check(is_equal_approx(rear.orders._squad_strength("sustain-squad"),full_strength/2),"Four empty members contribute exactly zero armed strength")
	for index in range(4,8): check(ledger.move_entity(roster[index],"sustain-stage",Vector2(2400,540)).ok,"Armed member physically outside local area")
	check(rear.orders._squad_strength("sustain-squad",Vector2(2000,540),300) == 0,"Nearby empty members cannot borrow distant armed strength")
	for index in range(4,8): check(ledger.move_entity(roster[index],"sustain-stage",Vector2(2000,540)).ok,"Same armed member physically returns")
	_empty(rear,roster[4])
	rear.advance_time(5)
	check(rear.orders.reports.any(func(row: Dictionary) -> bool: return row.source == "sustain-squad" and row.kind == "Low Supply" and row.urgent and "Urgent" in row.detail),"Actual average below fifteen still sends urgent supply report")
	for index in range(5,8): _empty(rear,roster[index])
	check(not rear.military.capability("sustain-squad","Sustained Execution").ok and rear.orders._squad_strength("sustain-squad") == 0,"Entirely empty squad has no sustained armed capability")
	var last: String = roster[7]
	check(ledger.add_stock("sustain-reload","E02",1,0.02,last,rear.PLAYER).ok,"Actual last local reload round")
	check(rear.combat.request_reload(last,last+"-rifle","sustain-reload",1).ok,"Same operator commits its real reload")
	check(ledger.inspect_entity("sustain-reload").available == 0 and rear.military._held(last,"E02") == 1 and rear.military._rounds(last) == 1,"Reserved local reload remains physical quantity even when availability is zero")
	check(rear.military.rifle_can_fight(last),"Own committed reload does not oscillate armed strength to zero")
	check(rear.combat.interrupt_reload(last+"-rifle").ok,"Actual reload released")
	check(ledger.request_stock("unrelated-claim","sustain-reload",1,"other-task","Other physical commitment",rear.PLAYER).ok,"Last local round committed to unrelated task")
	check(not rear.military.rifle_can_fight(last),"Unrelated reserved-only rounds do not grant armed strength")
	check(ledger.release_claim("unrelated-claim").ok,"Unrelated claim released")
	for id in roster: check(ledger.add_stock(id+"-assault","E02",90,0.02,id,rear.PLAYER).ok,"Actual ninety-round preparation")
	check(ledger.move_entity(roster[0],"sustain-stage",Vector2(2000,540)).ok,"Member physically at weapon handoff place")
	check(ledger.transfer_weapon(roster[0]+"-rifle","sustain-stage").ok,"Actual rifle missing from one prepared member")
	check(rear.military.readiness("sustain-squad") >= 0.75,"Missing one rifle can still exceed numerical assault readiness")
	check(rear.orders._squad_strength("sustain-squad") > 0 and rear.orders._squad_strength("sustain-squad",Vector2.INF,INF,"Deployment") == 0,"HQ strength preserves strict package despite sustained seven-person armed strength")
	check(base.audit().is_empty(),"Physical identities, rounds and movement reconcile: "+str(base.audit()))
	_test_actual_fire()
	print("Sustained Rifle regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _test_actual_fire() -> void:
	var base := Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	check(ledger.add_place("live-stage","Actual firing place",Vector2(2000,540)).ok,"Actual firing stage")
	check(ledger.add_place("live-target-place","Actual contact place",Vector2(2130,540)).ok,"Actual contact place")
	check(ledger.add_person("live-target","live-target-place","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual hostile person")
	var roster: Array[String] = []
	for index in 8:
		var id := "live-person-%d" % index
		check(ledger.add_person(id,"live-stage",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual firing member")
		check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual firing rifle")
		check(ledger.add_stock(id+"-ammo","E02",30,0.02,id,rear.PLAYER).ok,"Actual thirty-round package")
		check(ledger.load_rounds(id+"-rifle",id+"-ammo",1).ok,"Actual loaded firing round")
		roster.append(id)
	check(rear.military.add_initial_squad("live-squad","Rifle",roster,"live-company","live-platoon",rear.PLAYER).ok,"Actual firing hierarchy")
	rear.battlefield_operations = Execution.new(rear)
	check(rear.orders.watch("live-squad").ok,"Actual squad observation")
	check(rear.orders.issue_order("live-platoon","live-squad","Hold Area","Keep actual covered line","Sustained fire observation",{"destination":"live-stage","fallback_place":"live-stage","role":"Rifle"},"Normal","Actual stage").ok,"Actual acknowledged hold intent")
	rear.advance_time(8)
	check(int(ledger.snapshot().consumed.get("E02",0)) > 0 and rear.combat.events.any(func(row: Dictionary) -> bool: return "fired" in row.message),"Delivered contact produces actual autonomous shots across thirty to twenty-nine")
	check(not rear.military.capability("live-squad").ok and rear.military.capability("live-squad","Sustained Execution").ok and rear.battlefield_operations.status["live-squad"] != "Withdrawing","Actual firing below package preserves existing intent and strict new-deployment refusal")
	check(base.audit().is_empty(),"Autonomous shots and continued intent reconcile")

func _empty(rear: RefCounted, id: String) -> void:
	var ledger: RefCounted = rear.ledger
	if ledger.inspect_entity(id+"-rifle").loaded_rounds > 0: check(ledger.unload_rounds(id+"-rifle").ok,"Actual magazine returned to holder")
	for stock in ledger.entities_at(id,["STOCK"]):
		if stock.design_type == "E02" and stock.quantity > 0: check(ledger.record_consumption(stock.id,stock.quantity,"Controlled prior expenditure").ok,"Existing physical rounds expended")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(detail)
