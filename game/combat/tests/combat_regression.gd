extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_a03()
	_test_vehicle_occupant_drop()
	_test_a26()
	_test_a27()
	_test_fire_gates_and_stress()
	_test_reload_commitment()
	_test_field_gun_direct()
	print("G16 combat regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _person(base: RefCounted, id: String, holder: String, owner: String, qualification: String = "None") -> void:
	_expect(base.rear.ledger.add_person(id,holder,owner,Records.Assignment.HQ_RESERVE if holder == "hq-reserve" else Records.Assignment.AVAILABLE,true,qualification,"None").ok,"add actual person "+id)

func _test_a03() -> void:
	var base := Base.new(true)
	var ledger: RefCounted = base.rear.ledger
	_person(base,"a03-patient","hq-reserve",base.rear.PLAYER)
	_person(base,"a03-recoverer","hq-reserve",base.rear.PLAYER)
	_expect(ledger.add_weapon("a03-rifle","E01",4.0,"a03-patient",base.rear.PLAYER,"E02",10).ok,"A03 real intact rifle")
	_expect(ledger.add_stock("a03-rounds","E02",8,0.02,"a03-patient",base.rear.PLAYER).ok,"A03 loose rounds")
	_expect(ledger.load_rounds("a03-rifle","a03-rounds",3).ok,"A03 loaded portion moves exactly once")
	_expect(ledger.add_stock("a03-helmet","E03",1,1.0,"a03-patient",base.rear.PLAYER).ok,"A03 worn helmet")
	_expect(ledger.total_stock("E02") == 8,"A03 loading does not create rounds")
	_expect(base.rear.combat.injure("a03-patient",100).code == "INCAPACITATED","A03 actual incapacitation")
	var drop: String = "casualty-drop:a03-patient"
	_expect(ledger.inspect_entity("a03-rifle").holder_id == drop and ledger.inspect_entity("a03-rifle").loaded_rounds == 3,"A03 intact dropped rifle keeps loaded rounds")
	_expect(ledger.available_stock_at(drop,"E02") == 5 and ledger.total_stock("E02") == 8,"A03 five loose rounds drop separately")
	_expect(ledger.inspect_entity("a03-helmet").holder_id == "a03-patient","A03 worn protection stays until death")
	_expect(ledger.transfer_weapon("a03-rifle","a03-recoverer").ok,"A03 same intact weapon is physically recoverable")
	_expect(ledger.inspect_entity("a03-rifle").functional and ledger.inspect_entity("a03-rifle").loaded_rounds == 3,"A03 recovered weapon remains functional and loaded")
	_expect(base.rear.combat.injure("a03-patient",1).code == "DEAD","A03 further injury kills incapacitated person")
	_expect(ledger.inspect_entity("a03-helmet").holder_id == drop and base.rear.combat.deaths.size() == 1,"A03 protection drops and loss records once at death")
	_expect(base.audit().is_empty(),"A03 conservation and physical holder audit: "+str(base.audit()))

func _test_a26() -> void:
	var base := Base.new(true)
	var ledger: RefCounted = base.rear.ledger
	_person(base,"a26-shooter","hq-reserve",base.rear.PLAYER)
	_expect(ledger.add_place("a26-target-place","Hostile observed place",Vector2(1650,91)).ok,"A26 target place")
	_person(base,"a26-target","a26-target-place","army-red")
	_expect(ledger.add_weapon("a26-rifle","E01",4.0,"a26-shooter",base.rear.PLAYER,"E02",10).ok,"A26 rifle")
	_expect(ledger.add_stock("a26-one","E02",1,0.02,"a26-shooter",base.rear.PLAYER).ok,"A26 one local round")
	_expect(ledger.load_rounds("a26-rifle","a26-one",1).ok,"A26 last round physically loaded")
	_expect(ledger.add_stock("a26-remote","E02",40,0.02,"hq-stock",base.rear.PLAYER).ok,"A26 remote matching stock")
	var shot: Dictionary = base.rear.combat.fire("a26-shooter","a26-target","a26-rifle")
	_expect(shot.ok and shot.remaining == 0,"A26 last loaded round fired once")
	_expect(ledger.inspect_entity("a26-target").suppression == 4,"directed rifle shot applies suppression even on a miss")
	_expect(base.rear.combat.demands.has("a26-shooter") and base.rear.combat.demands["a26-shooter"].elsewhere == 40,"A26 supply demand names actual nonlocal stock")
	base.rear.advance_time(2)
	_expect(ledger.inspect_entity("a26-target").suppression == 4,"suppression does not decay before three safe seconds")
	_expect(not base.rear.combat.fire("a26-shooter","a26-target","a26-rifle").ok,"A26 further fire stops despite stock elsewhere")
	base.rear.advance_time(1)
	_expect(ledger.inspect_entity("a26-target").suppression == 0,"suppression decays by five after three seconds without incoming fire")
	_expect(ledger.total_stock("E02") == 40 and ledger.snapshot().consumed.get("E02",0) == 1,"A26 exactly one round consumed")
	_expect(not base.rear.combat.request_reload("a26-shooter","a26-rifle","a26-remote",1).ok,"A26 remote stock cannot reload")
	_expect(base.audit().is_empty(),"A26 physical conservation audit: "+str(base.audit()))

func _test_vehicle_occupant_drop() -> void:
	var base := Base.new(true)
	var ledger: RefCounted = base.rear.ledger
	_expect(ledger.add_carrier("casualty-hull","hq-berth",base.rear.PLAYER,base.rear.PLAYER).ok,"actual occupied carrier")
	_expect(ledger.add_person("hull-passenger","casualty-hull",base.rear.PLAYER,Records.Assignment.PASSENGER,true,"None","None").ok,"actual seated passenger")
	_expect(ledger.add_weapon("hull-rifle","E01",4.0,"hull-passenger",base.rear.PLAYER,"E02",10).ok,"seated passenger weapon")
	_expect(ledger.add_stock("hull-rounds","E02",6,0.02,"hull-passenger",base.rear.PLAYER).ok,"seated passenger loose rounds")
	_expect(ledger.load_rounds("hull-rifle","hull-rounds",2).ok,"seated passenger loaded two rounds")
	_expect(base.rear.combat.injure("hull-passenger",100).code == "INCAPACITATED","seated passenger injured by external event")
	_expect(ledger.inspect_entity("hull-rifle").holder_id == "casualty-hull" and ledger.inspect_entity("hull-rifle").loaded_rounds == 2,"intact loaded weapon remains inside actual carrier")
	_expect(ledger.inspect_entity("hull-rounds").holder_id == "casualty-hull" and ledger.total_stock("E02") == 6,"loose rounds remain separately inside carrier")
	_expect(ledger.inspect_entity("hull-passenger").holder_id == "casualty-hull","patient remains physical occupant pending G27 evacuation")
	_expect(base.audit().is_empty(),"vehicle casualty physical holder audit: "+str(base.audit()))

func _test_a27() -> void:
	var base := Base.new(true)
	var ledger: RefCounted = base.rear.ledger
	_person(base,"a27-patient","hq-reserve",base.rear.PLAYER)
	_person(base,"a27-medic","hq-reserve",base.rear.PLAYER,"P03")
	_person(base,"a27-relief","hq-reserve",base.rear.PLAYER,"P03")
	for id in ["a27-medic","a27-relief"]: _expect(ledger.add_stock(id+"-kit","E11",1,4.0,id,base.rear.PLAYER).ok,"A27 actual reusable kit "+id)
	_expect(ledger.add_stock("a27-pack","E12",1,1.0,"a27-medic",base.rear.PLAYER).ok,"A27 one pack")
	_expect(base.rear.combat.injure("a27-patient",100).code == "INCAPACITATED","A27 patient incapacitated")
	_expect(base.rear.combat.start_care("a27-medic","a27-patient","a27-pack").ok,"A27 local qualified care consumes pack")
	_expect(ledger.inspect_entity("a27-medic").morale == 52,"nearby incapacitation costs eight morale")
	base.rear.advance_time(4)
	_expect(is_equal_approx(base.rear.combat.care["a27-patient"].progress,4.0),"A27 four actual work seconds")
	_expect(is_equal_approx(ledger.inspect_entity("a27-patient").bleed_remaining,60.0),"A27 active qualified care pauses remaining bleed time")
	_expect(base.rear.combat.interrupt_care("a27-patient").ok,"A27 interruption retains work")
	base.rear.advance_time(5)
	_expect(is_equal_approx(base.rear.combat.care["a27-patient"].progress,4.0) and is_equal_approx(ledger.inspect_entity("a27-patient").bleed_remaining,55.0),"A27 interrupted time resumes bleed but preserves work")
	_expect(base.rear.combat.start_care("a27-relief","a27-patient").ok,"A27 second qualified medic resumes without a second pack")
	base.rear.advance_time(6)
	_expect(ledger.inspect_entity("a27-patient").assignment == "Recovery" and ledger.inspect_entity("a27-patient").health == 35,"A27 ten cumulative seconds stabilize once")
	_expect(ledger.snapshot().consumed.get("E12",0) == 1 and base.rear.combat.care.is_empty(),"A27 one committed pack counted once")
	_person(base,"a27-bleeder","hq-reserve",base.rear.PLAYER)
	_expect(base.rear.combat.injure("a27-bleeder",100).ok,"A27 second casualty")
	base.rear.advance_time(60)
	_expect(ledger.inspect_entity("a27-bleeder").assignment == "Dead" and base.rear.combat.deaths.has("a27-bleeder"),"A27 untreated bleed-out one death")
	_expect(not base.rear.combat.injure("a27-bleeder",1).ok,"A27 no duplicate death after bleed-out")
	_expect(base.audit().is_empty(),"A27 care and loss audit: "+str(base.audit()))

func _test_fire_gates_and_stress() -> void:
	var base := Base.new(true)
	var ledger: RefCounted = base.rear.ledger
	_person(base,"gate-shooter","hq-reserve",base.rear.PLAYER)
	_expect(ledger.add_place("gate-target-place","Hostile target",Vector2(1690,91)).ok,"gate target place")
	_person(base,"gate-target","gate-target-place","army-red")
	_expect(ledger.add_weapon("gate-rifle","E01",4.0,"gate-shooter",base.rear.PLAYER,"E02",10).ok,"gate rifle")
	_expect(not base.rear.combat.inspect_fire("gate-shooter","gate-shooter","gate-rifle").ok,"friendly fire withheld")
	var clear: Dictionary = base.rear.combat.inspect_fire("gate-shooter","gate-target","gate-rifle")
	_expect(clear.ok and clear.chance > 0.05 and clear.chance < 0.55,"visible legal range yields factored chance")
	base.rear.combat.world.paint(Rect2i(1690,91,1,1),"TR06")
	var covered: Dictionary = base.rear.combat.inspect_fire("gate-shooter","gate-target","gate-rifle")
	_expect(covered.ok and covered.chance < clear.chance and is_equal_approx(covered.cover.hit,0.5),"actual dense-forest cover halves direct hit chance")
	base.rear.combat.world.obstacle("gate-wall",Rect2(1660,90,2,2),0,5)
	_expect(not base.rear.combat.inspect_fire("gate-shooter","gate-target","gate-rifle").ok,"opaque obstruction withholds fire")
	_expect(base.rear.combat.injure("gate-target",100).ok,"target incapacitation")
	_expect(not base.rear.combat.inspect_fire("gate-shooter","gate-target","gate-rifle").ok,"no deliberate incapacitated targeting")
	_expect(base.audit().is_empty(),"gates audit: "+str(base.audit()))

func _test_field_gun_direct() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var squad_people: Array[String] = []
	for i in 4:
		var id := "gunner-%d" % i
		_person(base,id,"hq-reserve",rear.PLAYER,"P05")
		squad_people.append(id)
	for i in 2:
		var id := "guard-%d" % i
		_person(base,id,"hq-reserve",rear.PLAYER)
		squad_people.append(id)
		_expect(ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"field-gun guard rifle")
		_expect(ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"field-gun guard rounds")
	for id in squad_people:
		rear.dispatch.military_people[id] = "field-gun-fixture"
		rear.dispatch.hq_reserve[id] = "Occupied"
	_expect(ledger.create_heavy_output("","","g16-field-gun","E13","hq-berth",rear.PLAYER,{"mass":180.0,"health":400}).ok,"physical field gun")
	_expect(ledger.add_stock("g16-shells","E14",10,5.0,"hq-berth",rear.PLAYER).ok,"ten local shells")
	_expect(ledger.add_stock("g16-radio","E18",1,3.0,"gunner-0",rear.PLAYER).ok,"allocated gun radio")
	var formed: Dictionary = rear.military.form_squad("Artillery",squad_people)
	_expect(formed.ok,"actual artillery squad reports: "+str(formed))
	if not formed.ok: return
	rear.advance_time(8)
	var squad_id: String = formed.id
	_expect(rear.military.squads[squad_id].state == "Active","field gun squad active after physical report")
	_expect(rear.combat.deploy_field_gun(squad_id).ok,"four P05 start twenty-second setup")
	_expect(not rear.combat.inspect_field_gun_fire(squad_id,"missing-target").ok,"undeployed gun cannot fire")
	rear.advance_time(20)
	_expect(ledger.add_place("g16-gun-target-place","Direct hostile",Vector2(1750,91)).ok,"gun target place")
	_person(base,"g16-gun-target","g16-gun-target-place","army-red")
	var assessment: Dictionary = rear.combat.inspect_field_gun_fire(squad_id,"g16-gun-target")
	_expect(assessment.ok,"deployed gun sees legal target and local allocated shell: "+str(assessment))
	if assessment.ok:
		var shot: Dictionary = rear.combat.fire_field_gun(squad_id,"g16-gun-target")
		_expect(shot.ok,"W04 direct shot releases one shell")
		_expect(ledger.snapshot().consumed.get("E14",0) == 1,"W04 one shell consumed once")
		_expect(not rear.combat.fire_field_gun(squad_id,"g16-gun-target").ok,"W04 cadence blocks immediate second shot")
	_expect(base.audit().is_empty(),"W04 physical shell and squad audit: "+str(base.audit()))
	var squad: Dictionary = rear.military.squads[squad_id]
	_expect(is_equal_approx(rear.combat.squad_cohesion(squad_id).cohesion,1.0),"same real leader and six dismounted members are cohesive")
	_expect(ledger.add_place("g16-split","Separated formation position",Vector2(1800,91)).ok,"split position")
	var separated := 0
	for id in squad.roster:
		if id == squad.leader or separated >= 4: continue
		_expect(ledger.move_entity(id,"g16-split",Vector2(1800,91)).ok,"actual person separates from leader")
		separated += 1
	_expect(rear.combat.squad_cohesion(squad_id).state == "Regrouping","cohesion below half pauses coordination")
	rear.advance_time(10)
	_expect(rear.combat.squad_cohesion(squad_id).state == "Dispersed","continued low cohesion reports dispersed")
	var victim: String = squad.roster.back()
	_expect(rear.combat.injure(victim,100).code == "INCAPACITATED","actual formation member wounded")
	_expect(victim in rear.military.squads[squad_id].roster,"incapacitation retains occupied roster place")
	_expect(rear.combat.injure(victim,1).code == "DEAD","second injury kills member")
	_expect(victim not in rear.military.squads[squad_id].roster and not rear.dispatch.military_people.has(victim),"death releases one roster and admission place")
	_expect(base.audit().is_empty(),"cohesion and casualty integration audit: "+str(base.audit()))

func _test_reload_commitment() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	_person(base,"reload-person","hq-reserve",rear.PLAYER)
	_expect(ledger.add_weapon("reload-rifle","E01",4.0,"reload-person",rear.PLAYER,"E02",10).ok,"actual reload weapon")
	_expect(ledger.add_stock("reload-rounds","E02",3,0.02,"reload-person",rear.PLAYER).ok,"actual loose reload stock")
	_expect(rear.combat.request_reload("reload-person","reload-rifle","reload-rounds",2).ok,"reload reserves two local rounds")
	_expect(ledger.inspect_entity("reload-rounds").reserved == 2 and ledger.inspect_entity("reload-rounds").available == 1,"reload commitment is visible and excludes competing issue")
	rear.advance_time(3)
	_expect(ledger.inspect_entity("reload-rifle").loaded_rounds == 2 and ledger.inspect_entity("reload-rounds").quantity == 1,"three seconds move exactly two existing rounds into weapon")
	_expect(ledger.inspect_entity("reload-rounds").reserved == 0,"completed reload releases stock claim")
	_expect(rear.combat.request_reload("reload-person","reload-rifle","reload-rounds",1).ok,"second reload commits remaining loose round")
	_expect(rear.combat.injure("reload-person",100).code == "INCAPACITATED","reload operator incapacitated")
	_expect(rear.combat.reloads.is_empty() and ledger.inspect_entity("reload-rounds").reserved == 0,"casualty interrupts reload and releases claim")
	_expect(ledger.inspect_entity("reload-rifle").loaded_rounds == 2 and ledger.inspect_entity("reload-rounds").holder_id == "casualty-drop:reload-person","already loaded rounds stay in dropped weapon; unspent round drops loose")
	_expect(base.audit().is_empty(),"reload commitment and injury audit: "+str(base.audit()))
