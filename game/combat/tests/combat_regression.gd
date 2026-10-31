extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
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
	_test_cohesion_inspection_independence()
	_test_cohesion_local_reads()
	_test_stress_projection_parity()
	print("G16 combat regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _test_stress_projection_parity() -> void:
	var current := Base.new(true)
	var legacy := Base.new(true)
	for base in [current,legacy]:
		var ledger: RefCounted = base.rear.ledger
		_expect(ledger.add_place("stress-safe","Safe stress fixture",Vector2(1000,1000)).ok,"safe stress place")
		_expect(ledger.add_place("stress-near","Exposed stress fixture",Vector2(1300,1000)).ok,"exposed stress place")
		_expect(ledger.add_place("stress-hostile","Visible hostile",Vector2(1350,1000)).ok,"hostile stress place")
		for id in ["stress-trained","stress-untrained","stress-exposed","stress-broken","stress-dead"]:
			var holder := "stress-hostile" if id == "stress-dead" else ("stress-near" if id == "stress-exposed" else "stress-safe")
			_expect(ledger.add_person(id,holder,"army-blue",Records.Assignment.AVAILABLE,id != "stress-untrained").ok,"stress person "+id)
			base.rear.combat._apply_stress(id,-2,5,true)
			base.rear.combat.last_casualty[id] = 0.0
		_expect(ledger.add_person("stress-enemy","stress-hostile","army-red").ok,"real hostile inhibits nearby recovery")
		base.rear.combat._apply_stress("stress-broken",-40,60,false)
		_expect(base.rear.combat.injure("stress-dead",100).code == "INCAPACITATED","actual casualty before death")
		_expect(base.rear.combat.injure("stress-dead",1).code == "DEAD","actual death is excluded from stress tick")
		# Keep nested goods in the snapshot oracle; stress must ignore their mass.
		_expect(ledger.add_stock("stress-gear","E03",1,1.0,"stress-trained","army-blue").ok,"real retained gear")
	for at in [2.0,3.0,10.0,11.0]:
		for base in [current,legacy]:
			var delta: float = at-base.rear.time
			base.rear.ledger.advance_time(delta)
			base.rear.time = at
		current.rear.combat._stress_tick()
		_legacy_stress_tick(legacy.rear)
		_expect(current.rear.ledger.snapshot() == legacy.rear.ledger.snapshot(),"Person projection preserves exact full-ledger stress outcomes at "+str(at))
		for field in ["last_incoming","last_casualty","pinned","broken"]:
			_expect(current.rear.combat.get(field) == legacy.rear.combat.get(field),"Stress projection preserves "+field+" transitions")
	_expect(current.rear.ledger.inspect_entity("stress-trained").morale == 60 and not current.rear.combat.last_incoming.has("stress-trained"),"Safe trained recovery clears incoming history")
	_expect(current.rear.ledger.inspect_entity("stress-exposed").morale == 58 and current.rear.combat.last_incoming.has("stress-exposed"),"Visible hostile keeps exposed morale and incoming history unresolved")

func _legacy_stress_tick(rear: RefCounted) -> void:
	# Retained pre-projection algorithm: take a complete snapshot before mutation.
	var combat: RefCounted = rear.combat
	for item in rear.ledger.snapshot().entities:
		if item.kind != "PERSON" or item.assignment == "Dead": continue
		var since_fire: float = rear.time-float(combat.last_incoming.get(item.id,-INF))
		var since_casualty: float = rear.time-float(combat.last_casualty.get(item.id,-INF))
		var suppression_delta := -5 if since_fire >= 3.0-0.000001 and item.suppression > 0 else 0
		var morale_delta := 0
		if since_fire >= 10.0-0.000001 and since_casualty >= 10.0-0.000001 and item.morale < 60:
			var hostile := false
			for other in rear.ledger.snapshot().entities:
				if other.kind == "PERSON" and other.owner != item.owner and other.assignment not in ["Wounded","Dead"] and other.position.distance_to(item.position) <= 100.0:
					if combat.world.observe(item.position,other.position).visible: hostile = true; break
			if not hostile: morale_delta = mini(60-item.morale,2 if item.basic_training else 1)
		if suppression_delta != 0 or morale_delta != 0: combat._apply_stress(item.id,morale_delta,suppression_delta,false)
		var person: Dictionary = rear.ledger.inspect_entity(item.id)
		if person.suppression == 0 and person.morale >= 60 and since_fire >= 10.0-0.000001 and since_casualty >= 10.0-0.000001:
			combat.last_incoming.erase(item.id)
			combat.last_casualty.erase(item.id)

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
	_expect(ledger.add_carrier("g16-issue-carrier","hq-berth",rear.PLAYER,rear.PLAYER).ok,"actual local forward issue carrier")
	_expect(ledger.add_stock("g16-issue-rounds","E02",1,0.02,"g16-issue-carrier",rear.PLAYER).ok,"actual round aboard issue carrier")
	var handoff: Dictionary = rear.forward_supply.start_issue("g16-issue-rounds","guard-0","gunner-0",1,"hq-berth")
	_expect(handoff.ok,"artillery gunner begins real local handoff")
	if handoff.ok:
		_expect(not rear.combat.deploy_field_gun(squad_id).ok,"one committed P05 cannot simultaneously set up a four-person gun")
		_expect(rear.forward_supply.interrupt(handoff.id).ok,"gunner is released from pre-pickup handoff")
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
		if ledger.inspect_entity("g16-gun-target").assignment != "Wounded": _expect(rear.combat.injure("g16-gun-target",100).code == "INCAPACITATED","gun target wounded for Recovery eligibility")
		_person(base,"red-medic","g16-gun-target-place","army-red","P03")
		_expect(ledger.add_stock("red-kit","E11",1,4.0,"red-medic","army-red").ok,"hostile qualified-care kit")
		_expect(ledger.add_stock("red-pack","E12",1,1.0,"red-medic","army-red").ok,"hostile care pack")
		_expect(rear.combat.start_care("red-medic","g16-gun-target","red-pack").ok,"actual hostile care starts")
		rear.advance_time(10)
		_expect(ledger.inspect_entity("g16-gun-target").assignment == "Recovery","gun target stabilized into Recovery")
		_expect(not rear.combat.inspect_field_gun_fire(squad_id,"g16-gun-target").ok,"W04 withholds deliberate fire on recovering person")
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

func _rifle_squad_for_cohesion(base: RefCounted, prefix: String) -> String:
	var rear: RefCounted = base.rear
	var ids: Array[String] = []
	for i in 4:
		var id := prefix+"-person-%d" % i
		_person(base,id,"hq-reserve",rear.PLAYER)
		ids.append(id)
		rear.dispatch.military_people[id] = prefix
		rear.dispatch.hq_reserve[id] = "Occupied"
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"cohesion fixture rifle")
		_expect(rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"cohesion fixture rounds")
	var result: Dictionary = rear.military.form_squad("Rifle",ids)
	_expect(result.ok,"cohesion fixture forms actual Rifle squad")
	if not result.ok: return ""
	rear.advance_time(8)
	_expect(rear.military.squads[result.id].state == "Active","cohesion fixture reports physically")
	_expect(rear.ledger.add_place(prefix+"-split","Actual separated position",Vector2(1700,91)).ok,"cohesion split place")
	var squad: Dictionary = rear.military.squads[result.id]
	for id in squad.roster:
		if id == squad.leader: continue
		_expect(rear.ledger.move_entity(id,prefix+"-split",Vector2(1700,91)).ok,"person actually separates from leader")
	return result.id

func _test_cohesion_inspection_independence() -> void:
	var quiet := Base.new(true)
	var observed := Base.new(true)
	var quiet_id := _rifle_squad_for_cohesion(quiet,"quiet")
	var observed_id := _rifle_squad_for_cohesion(observed,"observed")
	if quiet_id.is_empty() or observed_id.is_empty(): return
	var quiet_started: float = quiet.rear.combat.dispersed_since[quiet_id]
	var observed_started: float = observed.rear.combat.dispersed_since[observed_id]
	_expect(is_equal_approx(quiet_started,observed_started),"same actual separation event starts both timers")
	quiet.rear.advance_time(10)
	for i in 10:
		observed.rear.advance_time(1)
		observed.rear.combat.snapshot()
		observed.rear.combat.squad_cohesion(observed_id)
	_expect(quiet.rear.combat.squad_cohesion(quiet_id).state == "Dispersed","ten seconds without any inspection still reaches Dispersed")
	_expect(observed.rear.combat.squad_cohesion(observed_id).state == "Dispersed","frequent inspection reaches same Dispersed state")
	_expect(is_equal_approx(float(quiet.rear.combat.dispersed_since[quiet_id]),quiet_started) and is_equal_approx(float(observed.rear.combat.dispersed_since[observed_id]),observed_started),"inspection never starts or resets the simulation-owned timer")
	_expect(quiet.audit().is_empty() and observed.audit().is_empty(),"cohesion inspection independence preserves actual rosters")

func _test_cohesion_local_reads() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var ids: Array[String] = []
	for index in 4:
		var id := "cohesion-local-%d" % index
		_expect(ledger.add_person(id,"hq-formation",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"actual local-read infantry")
		_expect(ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok and ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"real local-read package")
		ids.append(id)
	var formed: Dictionary = rear.military.add_initial_squad("cohesion-local","Rifle",ids,"cohesion-company","cohesion-platoon",rear.PLAYER)
	_expect(formed.ok,"actual local-read squad")
	if not formed.ok: return
	var row: Dictionary = rear.military.squads[formed.id]
	var leader: String = row.leader
	_expect(ledger.add_initial_vehicle("cohesion-hull","T02","hq-formation",rear.PLAYER,Specs.TYPES.T02,40,"Military").ok,"real cohesion transport")
	_expect(ledger.add_person("cohesion-driver","hq-formation",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok,"real cohesion driver")
	_expect(ledger.assign_initial_vehicle_crew("cohesion-driver","cohesion-hull","Driver").ok and rear.military.attach_initial_vehicle("cohesion-hull","cohesion-platoon").ok,"actual staffed and attached cohesion hull")
	_compare_cohesion(rear,formed.id)
	_compare_cohesion(rear,"missing")
	# Isolated query fixtures retain duplicate roster and absent/non-roster leaders.
	row.roster.append(ids[0])
	_compare_cohesion(rear,formed.id)
	row.roster.pop_back()
	for other in ["","missing","cohesion-driver"]:
		row.leader = other
		_compare_cohesion(rear,formed.id)
	row.leader = leader
	row.state = "Reporting"
	_compare_cohesion(rear,formed.id)
	row.state = "Active"
	_expect(rear.military._reserve_transport_manifest("cohesion-hull",[formed.id]).ok,"real passenger commitment")
	for id in ids:
		_expect(ledger.board_formation_passenger(id,"cohesion-hull").ok,"actual sequential boarding")
		_compare_cohesion(rear,formed.id)
	_expect(rear.combat.squad_cohesion(formed.id).state == "Boarded","all actual passengers retain boarded result")
	_expect(rear.military.exit_squad(formed.id).ok,"actual dismount restores ground position")
	_compare_cohesion(rear,formed.id)
	var origin: Vector2 = ledger.inspect_person_status(leader).position
	_expect(ledger.add_place("cohesion-local-split","Actual split position",origin+Vector2(45,0)).ok,"local-read separation place")
	for id in ids:
		if id != leader: _expect(ledger.move_entity(id,"cohesion-local-split",origin+Vector2(45,0)).ok,"actual dispersal")
	_compare_cohesion(rear,formed.id)
	rear.advance_time(10)
	_compare_cohesion(rear,formed.id)
	_expect(rear.combat.squad_cohesion(formed.id).state == "Dispersed","existing real dispersal timer still reaches threshold")
	_expect(rear.combat.injure(leader,100).code == "INCAPACITATED","leader becomes absent from active read set")
	_compare_cohesion(rear,formed.id)
	for id in ids:
		if id != leader: _expect(rear.combat.injure(id,100).ok,"actual remaining incapacitation")
	_compare_cohesion(rear,formed.id)
	_expect(rear.combat.squad_cohesion(formed.id).state == "No active infantry","empty active set retains prior result")

func _compare_cohesion(rear: RefCounted, id: String) -> void:
	var before: Dictionary = rear.combat.dispersed_since.duplicate(true)
	var expected: Dictionary = _legacy_cohesion(rear,id)
	var result: Dictionary = rear.combat.squad_cohesion(id)
	_expect(var_to_bytes(result) == var_to_bytes(expected),"Cohesion fields exactly match retained original independent reads")
	result.state = "Mutated result"
	_expect(rear.combat.squad_cohesion(id) == expected and rear.combat.dispersed_since == before,"Cohesion result is detached and inspection preserves timer ownership")

func _legacy_cohesion(rear: RefCounted, squad_id: String) -> Dictionary:
	var row: Dictionary = rear.military.squads.get(squad_id,{})
	if row.is_empty() or row.state != "Active": return {"cohesion":0.0,"state":"Unavailable","blocked_reason":"No active actual squad."}
	var active: Array[String] = rear.military._active_roster_members(row,true)
	var dismounted: Array[String] = []
	var boarded := 0
	for id in active:
		if rear.combat._seated(rear.ledger.inspect_person_status(id)): boarded += 1
		else: dismounted.append(id)
	if boarded == active.size() and boarded > 0: return {"cohesion":1.0,"state":"Boarded","blocked_reason":"Dismount before infantry fire."}
	if dismounted.is_empty(): return {"cohesion":0.0,"state":"No active infantry","blocked_reason":"No active dismounted people."}
	var leader: Dictionary = rear.ledger.inspect_person_status(row.leader)
	var near := 0
	for id in dismounted:
		if not leader.is_empty() and leader.assignment == "Formation Duty" and leader.position.distance_to(rear.ledger.inspect_person_status(id).position) <= 30.0: near += 1
	var value := float(near)/float(dismounted.size())
	var state := "Coherent"
	var reason := ""
	if value < 0.5:
		state = "Dispersed" if rear.combat.dispersed_since.has(squad_id) and rear.time-float(rear.combat.dispersed_since[squad_id]) >= 10.0 else "Regrouping"
		reason = "Offensive coordination paused; regroup around actual leader."
	return {"cohesion":value,"state":state,"blocked_reason":reason,"regroup_seconds":maxf(0.0,rear.time-float(rear.combat.dispersed_since[squad_id])) if rear.combat.dispersed_since.has(squad_id) else 0.0}
