extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_a28_observation_and_real_delay()
	_test_a29_supported_flank_loses_ammunition()
	_test_hq_assault_eligibility()
	_test_unfuelled_armour_cannot_satisfy_assault_support()
	_test_intent_and_report_chain()
	print("G17 order regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _squad(base: RefCounted, prefix: String, count: int = 4) -> String:
	var rear: RefCounted = base.rear
	var people: Array[String] = []
	for i in count:
		var id := "%s-person-%d" % [prefix,i]
		_expect(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"None","None").ok,"real squad member "+id)
		rear.dispatch.military_people[id] = prefix
		rear.dispatch.hq_reserve[id] = "Occupied"
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"real rifle "+id)
		_expect(rear.ledger.add_stock(id+"-ammo","E02",30,0.02,id,rear.PLAYER).ok,"real matching stock "+id)
		_expect(rear.ledger.load_rounds(id+"-rifle",id+"-ammo",1).ok,"one physically loaded round "+id)
		people.append(id)
	var result: Dictionary = rear.military.form_squad("Rifle",people)
	_expect(result.ok,"actual equipped people start Rifle formation")
	return str(result.get("id",""))

func _enemy(base: RefCounted, id: String, position: Vector2) -> void:
	var ledger: RefCounted = base.rear.ledger
	_expect(ledger.add_place(id+"-place","Observed enemy position",position).ok,"enemy physical place")
	_expect(ledger.add_person(id,id+"-place","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"enemy actual person")

func _test_a28_observation_and_real_delay() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var squad_id := _squad(base,"a28")
	rear.advance_time(8)
	_expect(rear.military.squads[squad_id].state == "Active","A28 squad physically reported")
	_enemy(base,"a28-enemy",Vector2(1710,91))
	_expect(rear.orders.watch(squad_id).ok,"A28 real squad starts observing")
	_expect(rear.orders.contact(squad_id,"a28-enemy").is_empty(),"A28 squad sharing takes half second")
	rear.advance_time(0.5)
	var squad_contact: Dictionary = rear.orders.contact(squad_id,"a28-enemy")
	_expect(not squad_contact.is_empty() and squad_contact.observed_at == 8.0 and is_equal_approx(squad_contact.age,0.5),"A28 shared contact keeps actual first sighting time")
	var platoon_id: String = rear.military.squads[squad_id].platoon
	_expect(rear.orders.contact(platoon_id,"a28-enemy").is_empty(),"A28 platoon lacks contact before real link delay")
	rear.advance_time(1)
	_expect(rear.orders.contact(platoon_id,"a28-enemy").observed_at == 8.0,"A28 one-second platoon message does not renew sighting")
	rear.advance_time(28.5)
	var fresh: Dictionary = rear.orders.contact(squad_id,"a28-enemy")
	_expect(fresh.confidence >= 0.98 and fresh.age <= 1.0 and fresh.current,"A28 stationary target stays fresh under continuous actual sight")
	var army_before: Dictionary = rear.orders.contact("army","a28-enemy")
	_expect(army_before.observed_at <= fresh.observed_at and army_before.age >= fresh.age,"A28 Commander has delayed original observation, not future knowledge")
	rear.combat.world.obstacle("a28-wall",Rect2(Vector2(1680,90),Vector2(2,3)),0,5)
	rear.advance_time(1)
	_expect(not rear.orders.current_contact(squad_id,"a28-enemy"),"A28 actual sight loss ends current targeting")
	var last: Dictionary = rear.orders.contact(squad_id,"a28-enemy")
	rear.advance_time(11)
	var aged: Dictionary = rear.orders.contact(squad_id,"a28-enemy")
	_expect(aged.observed_at == last.observed_at and aged.age > 10.0 and aged.confidence < 0.8,"A28 age and confidence decay from last actual observation")
	_expect(is_equal_approx(aged.caution_strength,1.25),"A28 stale strength gains 25 percent caution")
	rear.advance_time(40)
	_expect(rear.orders.contact(squad_id,"a28-enemy").confidence == 0.0 and rear.orders.contact(squad_id,"a28-enemy").position == Vector2.INF,"A28 zero-confidence position ceases to be a target")
	_expect(base.audit().is_empty(),"A28 information never changes physical identity: "+str(base.audit()))

func _test_a29_supported_flank_loses_ammunition() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var fixing := _squad(base,"fix")
	var flanking := _squad(base,"flank")
	rear.advance_time(8)
	var platoon_id: String = rear.military.squads[fixing].platoon
	_expect(rear.military.squads[flanking].platoon == platoon_id,"A29 two real squads share one platoon")
	_expect(rear.ledger.add_place("flank-place","Physical flanking position",Vector2(1700,141)).ok,"A29 flanking place")
	for id in rear.military.squads[flanking].roster: _expect(rear.ledger.move_entity(id,"flank-place",Vector2(1700,141)).ok,"A29 member actually takes flank position")
	_enemy(base,"a29-enemy",Vector2(1700,91))
	_expect(rear.orders.watch(fixing).ok and rear.orders.watch(flanking).ok,"A29 both actual squads observe locally")
	rear.advance_time(2)
	var plan: Dictionary = rear.orders.plan_supported_flank(platoon_id,fixing,flanking,"a29-enemy","Withdraw to covered rally")
	_expect(plan.ok,"A29 current contact, actual fire and thirty-degree geometry permit supported flank: "+str(plan))
	if not plan.ok: return
	_expect(rear.orders.responsibilities[platoon_id].fixing == fixing and rear.orders.responsibilities[platoon_id].flanking == flanking,"A29 fixing and flanking responsibilities differ")
	_expect(rear.orders.responsibilities[platoon_id].angle_degrees >= 30.0,"A29 real leader positions satisfy geometry")
	rear.advance_time(2)
	_expect(rear.orders.intents[fixing].state == "Acknowledged" and rear.orders.intents[flanking].state == "Acknowledged","A29 both real squads acknowledge received intents within two seconds")
	for id in rear.military.squads[fixing].roster:
		_expect(rear.ledger.fire_loaded_round(id+"-rifle").ok,"A29 last loaded fixing round physically spent")
		_expect(rear.ledger.record_loss(id+"-ammo",29,"A29 controlled local stock removal").ok,"A29 remaining fixing rounds physically removed")
	rear.advance_time(1)
	var paused: Dictionary = rear.orders.responsibilities[platoon_id]
	_expect(paused.state == "Paused" and paused.blocker.contains("E02"),"A29 flank pauses within one second with actionable missing local ammunition")
	_expect(rear.orders.intents[flanking].state.begins_with("Paused"),"A29 flanker does not continue unsupported advance")
	rear.advance_time(12)
	var inability := false
	for item in rear.orders.reports:
		if item.kind == "Inability" and item.path.has("army"): inability = true
	_expect(inability,"A29 unresolved support loss escalates through platoon and company to Commander")
	_expect(base.audit().is_empty(),"A29 real ammo removal and command chain preserve physical audit: "+str(base.audit()))

func _test_hq_assault_eligibility() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var rifle := _squad(base,"assault")
	rear.advance_time(8)
	var company_id: String = rear.military.squads[rifle].company
	_expect(rear.ledger.add_place("enemy-hq-marker","Physical scenario enemy HQ",Vector2(1710,91)).ok,"actual HQ marker place")
	_expect(rear.orders.register_enemy_hq("enemy-hq-marker").ok,"scenario declares physical enemy HQ without revealing contact")
	_expect(rear.orders.assess_hq_assault(company_id,"enemy-hq-marker",true).message.contains("Prepare Assault"),"final HQ assault cannot skip preparation")
	var prepared: Dictionary = rear.orders.prepare_hq_assault(company_id,"enemy-hq-marker")
	_expect(prepared.ok and prepared.demands.ammo.size() == 4,"Prepare Assault exposes four actual 90-round person shortages")
	_expect(prepared.demands.pending.size() == 3,"unknown route, transport and engineering remain explicit pending requirements")
	_expect(rear.orders.watch(rifle).ok,"actual squad observes HQ marker")
	rear.advance_time(3)
	_expect(not rear.orders.contact(company_id,"enemy-hq-marker").is_empty(),"HQ location reaches company after real links")
	_expect(rear.orders.assess_hq_assault(company_id,"enemy-hq-marker",true).message.contains("unconfirmed"),"located HQ cannot bypass unknown preparation with a route_ok flag")
	var plan := {"route":{"state":"Feasible","evidence":"controlled G08 clear approach","fallback":"covered return"},"transport":{"mode":"Foot","evidence":"controlled G08 foot ETA"},"engineering":{"state":"Clear","evidence":"controlled G08 obstacle survey"},"operating_hulls":[],"fuel_required":{}}
	prepared = rear.orders.prepare_hq_assault(company_id,"enemy-hq-marker",plan)
	_expect(prepared.demands.pending.is_empty() and prepared.demands.transport.is_empty() and prepared.demands.engineering.is_empty(),"explicit evidenced foot and clear approach settle nonvehicle preparation")
	var blocked: Dictionary = rear.orders.assess_hq_assault(company_id,"enemy-hq-marker",true)
	_expect(not blocked.ok and blocked.message.contains("90"),"HQ assault refuses ordinary thirty-round rifle carriers")
	var engineer_plan: Dictionary = plan.duplicate(true)
	engineer_plan.engineering = {"state":"Needed","requirements":[{"project":"Clear surveyed minefield","type":"G21 engineer plan","quantity":1}]}
	prepared = rear.orders.prepare_hq_assault(company_id,"enemy-hq-marker",engineer_plan)
	_expect(prepared.demands.engineering.size() == 1 and rear.orders.assess_hq_assault(company_id,"enemy-hq-marker",true).message.contains("engineering"),"named unmet engineer work remains visible and blocks final eligibility")
	var transport_plan: Dictionary = plan.duplicate(true)
	transport_plan.transport = {"mode":"Vehicles","hulls":["unassigned-truck"]}
	prepared = rear.orders.prepare_hq_assault(company_id,"enemy-hq-marker",transport_plan)
	_expect(prepared.demands.transport.size() == 1 and rear.orders.assess_hq_assault(company_id,"enemy-hq-marker",true).message.contains("transport"),"unassigned transport cannot be invented by a route plan")
	_expect(rear.ledger.reserve_rear_hull("assault-admission",rear.PLAYER,"assault-fixture").ok,"actual support hull admission")
	_expect(rear.ledger.create_heavy_output("assault-admission","assault-fixture","assault-truck","T02","hq-berth",rear.PLAYER,Specs.TYPES.T02).ok,"actual empty unfuelled T02")
	_expect(rear.ledger.complete_hq_hull_receipt("assault-truck").ok,"same hull enters military fleet")
	rear.dispatch.military_hulls["assault-truck"] = "assault-fixture"
	_expect(rear.ledger.add_person("assault-driver","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08","None").ok,"actual qualified reserve driver")
	rear.dispatch.military_people["assault-driver"] = "assault-fixture"
	rear.dispatch.hq_reserve["assault-driver"] = "Occupied"
	_expect(rear.military.assign_crew("assault-driver","assault-truck","Driver").ok,"driver starts physical hull report")
	rear.advance_time(8)
	_expect(rear.military.vehicles.has("assault-truck"),"same staffed hull is assigned to company hierarchy")
	var fuel_plan: Dictionary = plan.duplicate(true)
	fuel_plan.operating_hulls = ["assault-truck"]
	fuel_plan.fuel_required = {"assault-truck":5.0}
	_expect(rear.ledger.add_stock("assault-fuel-source","M08",10,1.0,"hq-berth",rear.PLAYER).ok,"real available M08 source remains outside the hull tank")
	fuel_plan.fuel_source = {"assault-truck":"assault-fuel-source"}
	prepared = rear.orders.prepare_hq_assault(company_id,"enemy-hq-marker",fuel_plan)
	_expect(prepared.demands.fuel.size() == 1 and is_equal_approx(prepared.demands.fuel[0].missing,6.25) and prepared.demands.fuel[0].type == "M08" and prepared.demands.fuel[0].source_available == 10,"actual zero-fuel assigned hull exposes route and fallback reserve shortage and source availability without imaginary fueling")
	_expect(rear.orders.assess_hq_assault(company_id,"enemy-hq-marker",true).message.contains("fuel"),"missing physical fuel blocks eligibility before readiness")
	rear.orders.prepare_hq_assault(company_id,"enemy-hq-marker",plan)
	for id in rear.military.squads[rifle].roster:
		_expect(rear.ledger.add_stock(id+"-assault-ammo","E02",60,0.02,id,rear.PLAYER).ok,"actual additional assault rounds on carrier")
	blocked = rear.orders.assess_hq_assault(company_id,"enemy-hq-marker",true)
	_expect(not blocked.ok and blocked.message.contains("readiness"),"four-person squad cannot claim company readiness 0.75")
	_expect(base.audit().is_empty(),"HQ assault gate inspects actual goods without spending or moving them: "+str(base.audit()))

func _test_intent_and_report_chain() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var squad_id := _squad(base,"chain")
	rear.advance_time(8)
	var platoon_id: String = rear.military.squads[squad_id].platoon
	var company_id: String = rear.military.squads[squad_id].company
	var first: Dictionary = rear.orders.issue_order("army",company_id,"Hold Area","Protect the rear approach","Keep supply route open",{"area":"rear approach"},"Normal","Withdraw to HQ if overwhelmed")
	_expect(first.ok,"Commander sends fully specified intent to actual company")
	_expect(not rear.orders.relay_order(company_id,platoon_id).ok,"company cannot relay unreceived intent")
	rear.advance_time(2)
	_expect(rear.orders.intents[company_id].state == "Acknowledged","company receipt and acknowledgement each take one command link")
	_expect(rear.orders.relay_order(company_id,platoon_id).ok,"company relays inherited purpose and fallback to actual platoon")
	rear.advance_time(2)
	_expect(rear.orders.relay_order(platoon_id,squad_id).ok,"platoon relays received command to actual squad")
	rear.advance_time(2)
	_expect(rear.orders.intents[squad_id].state == "Acknowledged","squad receives and acknowledges after real links")
	_expect(rear.orders.intents[squad_id].constraints.relayed_from == rear.orders.intents[platoon_id].id,"relay retains parent intent lineage")
	_expect(not rear.orders.issue_order(platoon_id,squad_id,"Probe","Find route","Support parent purpose",{},"Normal","Hold").ok,"ten-second mission persistence prevents arbitrary thrash")
	_expect(rear.orders.report(squad_id,"Progress","Approach remains open").ok,"squad can report observed progress upward")
	_expect(rear.orders.reports.is_empty(),"Commander cannot read progress before three real upward links")
	rear.advance_time(3)
	_expect(rear.orders.reports.size() == 1 and rear.orders.reports[0].path == [squad_id,platoon_id,company_id,"army"],"progress reaches Commander only through squad, platoon and company")
	_expect(rear.orders.reports[0].observed_at == 14.0,"three-second message delay never rewrites original report time")
	_expect(base.audit().is_empty(),"command chain remains detached from physical ledger: "+str(base.audit()))

func _test_unfuelled_armour_cannot_satisfy_assault_support() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var rifle := _squad(base,"armour",8)
	rear.advance_time(8)
	var company_id: String = rear.military.squads[rifle].company
	for id in rear.military.squads[rifle].roster:
		_expect(rear.ledger.add_stock(id+"-extra","E02",60,0.02,id,rear.PLAYER).ok,"eight carriers physically carry assault ammunition")
	_expect(rear.military.readiness(rifle) >= 0.75,"actual eight-person company assault formation meets readiness threshold")
	_expect(rear.ledger.reserve_rear_hull("armour-admission",rear.PLAYER,"armour-fixture").ok,"actual T04 admission")
	_expect(rear.ledger.create_heavy_output("armour-admission","armour-fixture","armour-apc","T04","hq-berth",rear.PLAYER,Specs.TYPES.T04).ok,"actual unfuelled T04 support hull")
	_expect(rear.ledger.complete_hq_hull_receipt("armour-apc").ok,"same T04 enters military fleet")
	rear.dispatch.military_hulls["armour-apc"] = "armour-fixture"
	for station in ["Driver","Gunner","Commander"]:
		var id := "armour-crew-"+str(station).to_lower()
		_expect(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08","None").ok,"actual qualified T04 crew member")
		rear.dispatch.military_people[id] = "armour-fixture"
		rear.dispatch.hq_reserve[id] = "Occupied"
	_expect(rear.military.assign_crew("armour-crew-driver","armour-apc","Driver").ok,"actual driver report starts")
	rear.advance_time(8)
	_expect(rear.military.vehicles.has("armour-apc"),"T04 joins actual company hierarchy")
	_expect(rear.ledger.add_stock("armour-shell","E26",1,0.5,"armour-apc",rear.PLAYER).ok,"matching physical T04 rack ammunition")
	_expect(rear.military.vehicle_capability("armour-apc","Fire").ok and not rear.military.vehicle_capability("armour-apc","Movement").ok,"armed T04 can fire but zero fuel prevents movement")
	_expect(rear.ledger.add_place("armour-hq","Declared enemy HQ",Vector2(1710,91)).ok,"physical enemy HQ marker")
	_expect(rear.orders.register_enemy_hq("armour-hq").ok,"HQ declaration gives no free contact")
	_expect(rear.orders.watch(rifle).ok,"real rifle squad observes the HQ")
	rear.advance_time(3)
	var plan := {"route":{"state":"Feasible","evidence":"controlled G08 route","fallback":"covered return"},"transport":{"mode":"Foot","evidence":"controlled foot ETA"},"engineering":{"state":"Clear","evidence":"controlled survey"},"operating_hulls":[],"fuel_required":{}}
	rear.orders.prepare_hq_assault(company_id,"armour-hq",plan)
	_expect(rear.orders.assess_hq_assault(company_id,"armour-hq",true).message.contains("support"),"unlisted T04 cannot satisfy operating assault support")
	plan.operating_hulls = ["armour-apc"]
	plan.fuel_required = {"armour-apc":5.0}
	var prepared: Dictionary = rear.orders.prepare_hq_assault(company_id,"armour-hq",plan)
	_expect(prepared.demands.fuel.size() == 1 and is_equal_approx(prepared.demands.fuel[0].missing,6.25),"listed T04 exposes actual M08 shortage with reserve")
	_expect(rear.orders.assess_hq_assault(company_id,"armour-hq",true).message.contains("fuel"),"fire-ready but immobile T04 cannot pass assault eligibility")
	_expect(base.audit().is_empty(),"unfuelled T04 remains physical, assigned and reconciled: "+str(base.audit()))
