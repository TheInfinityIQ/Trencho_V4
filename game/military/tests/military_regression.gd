extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_a25()
	_test_vehicle_element_and_passengers()
	_test_leadership_delay_and_acting_commander()
	_test_acting_rifle_conscript()
	_test_other_squad_minima()
	_test_replacements_readiness_and_roster_cap()
	_test_requested_specialist_issue()
	_test_pending_intent_cancellation()
	_test_need_order_and_duplicate_type()
	print("G15 military regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _person(base: RefCounted, id: String, qualification: String = "None", rifle: bool = false) -> void:
	var rear: RefCounted = base.rear
	_expect(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,qualification,"None").ok,"real HQ Reserve person "+id)
	rear.dispatch.military_people[id] = "g15-receipt"
	rear.dispatch.hq_reserve[id] = "Occupied"
	if rifle:
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"issued rifle "+id)
		_expect(rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"issued matching rounds "+id)

func _test_a25() -> void:
	var rifle := Base.new(true)
	var three: Array[String] = ["rifle-1","rifle-2","rifle-3"]
	for id in three: _person(rifle,id,"None",true)
	_expect(not rifle.rear.military.assess_squad("Rifle",three).ok,"A25 three actual infantry cannot form ordinary Rifle")
	_person(rifle,"rifle-4","None",true)
	var four: Array[String] = ["rifle-1","rifle-2","rifle-3","rifle-4"]
	_expect(rifle.rear.military.assess_squad("Rifle",four).ok,"A25 four actually equipped infantry can form minimum Rifle")
	rifle.rear.advance_time(0)
	_expect(rifle.rear.military.squads.size() == 1,"HQ command automatically starts one real Rifle formation")
	_expect(rifle.rear.dispatch.hq_reserve.size() == 4,"claim is not a completed physical HQ Reserve departure")
	rifle.rear.advance_time(8)
	var squad: Dictionary = rifle.rear.military.squads.values()[0]
	_expect(squad.state == "Active" and squad.roster.size() == 4,"same four report physically and become active")
	_expect(rifle.rear.dispatch.hq_reserve.is_empty(),"actual report releases four HQ Reserve places")
	_expect(str(rifle.rear.military.shortages()).contains("company-01"),"one trained squad leader cannot also fill both separate senior appointments")
	for id in four:
		var p: Dictionary = rifle.rear.ledger.inspect_entity(id)
		_expect(p.assignment == "Formation Duty" and p.duty_id == squad.id and p.holder_id == "hq-formation","same person has one formation duty and real report position")
	_expect(rifle.audit().is_empty(),"A25 Rifle state and stock conserved: "+str(rifle.audit()))
	var artillery := Base.new(true)
	var five: Array[String] = []
	for i in 4:
		var id := "gunner-%d" % i
		_person(artillery,id,"P05")
		five.append(id)
	_person(artillery,"guard-1","None",true)
	five.append("guard-1")
	_expect(not artillery.rear.military.assess_squad("Artillery",five).ok,"A25 five people including four P05 cannot form Artillery")
	_person(artillery,"guard-2","None",true)
	var six: Array[String] = five.duplicate()
	six.append("guard-2")
	_expect(artillery.rear.ledger.create_heavy_output("","","field-gun","E13","hq-berth",artillery.rear.PLAYER,{"mass":180.0,"health":300}).ok,"actual field gun delivered locally")
	_expect(artillery.rear.ledger.add_stock("gun-shells","E14",10,5.0,"hq-berth",artillery.rear.PLAYER).ok,"ten actual local shells")
	_expect(artillery.rear.ledger.add_stock("gun-radio","E18",1,3.0,"gunner-0",artillery.rear.PLAYER).ok,"issued radio")
	_expect(artillery.rear.military.assess_squad("Artillery",six).ok,"A25 six including four P05 and actual package can form Artillery")
	_expect(artillery.rear.military.form_squad("Artillery",six).ok,"first real Artillery squad reserves its own gun and ten shells")
	var second: Array[String] = []
	for i in 4:
		var id := "other-gunner-%d" % i
		_person(artillery,id,"P05")
		second.append(id)
	for i in 2:
		var id := "other-guard-%d" % i
		_person(artillery,id,"None",true)
		second.append(id)
	_expect(not artillery.rear.military.assess_squad("Artillery",second).ok,"one field gun and ten reserved shells cannot satisfy two distinct squads")
	artillery.rear.advance_time(8)
	var first_artillery: Dictionary = artillery.rear.military.squads.values()[0]
	_expect(first_artillery.state == "Active" and first_artillery.shell_ids.size() == 1,"same gun and actual shell portion reach formation at report boundary")
	_expect(artillery.rear.ledger.inspect_entity("field-gun").holder_id == "hq-formation","one allocated physical field gun reports to formation")
	_expect(artillery.rear.military.capability(first_artillery.id).ok,"artillery capability uses its own allocated local gun and shells")
	_expect(not artillery.rear.military.assess_squad("Artillery",second).ok,"allocated formation equipment remains unavailable after report")
	_expect(artillery.audit().is_empty(),"A25 Artillery fixture conserved: "+str(artillery.audit()))

func _test_vehicle_element_and_passengers() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	for i in 4: _person(base,"mounted-%d" % i,"None",true)
	rear.advance_time(8)
	_expect(rear.military.squads.size() == 1,"real four-member squad reports before vehicle attachment")
	var squad: Dictionary = rear.military.squads.values()[0]
	_expect(rear.ledger.reserve_rear_hull("g15-vehicle-admission",rear.PLAYER,"g15-fixture").ok,"real hull admission")
	_expect(rear.ledger.create_heavy_output("g15-vehicle-admission","g15-fixture","g15-apc","T04","hq-berth",rear.PLAYER,Specs.TYPES.T04).ok,"actual T04 at HQ berth")
	_expect(rear.ledger.complete_hq_hull_receipt("g15-apc").ok,"same T04 transferred to military fleet")
	rear.dispatch.military_hulls["g15-apc"] = "g15-fixture"
	_expect(not rear.military.attach_vehicle("g15-apc",squad.platoon).ok,"uncrewed hull does not become a ready element")
	for station in ["Driver","Gunner","Commander"]:
		var id: String = "crew-"+str(station).to_lower()
		_person(base,id,"P08")
	_expect(rear.military.assign_crew("crew-driver","g15-apc","Driver").ok,"same P08 begins a real driver report")
	rear.advance_time(0)
	_expect(rear.military.crew_reports.size() == 3,"HQ command automatically reserves two remaining distinct P08 crew stations")
	_expect(rear.military.shortages().size() >= 1,"pending physical crew stations remain visible as shortages")
	_expect(rear.dispatch.hq_reserve.size() == 3,"crew report claims do not release reserve places early")
	rear.advance_time(8)
	var hull: Dictionary = rear.ledger.inspect_entity("g15-apc")
	_expect(hull.crew_by_station.size() == 3 and hull.passengers.is_empty(),"three actual crew stations filled with distinct people")
	_expect(rear.dispatch.hq_reserve.is_empty(),"actual crew report releases exactly three reserve places")
	_expect(rear.military.vehicles.has("g15-apc") and rear.military.vehicles["g15-apc"].parent == squad.platoon,"HQ command automatically attaches the same staffed T04 to its real platoon")
	_expect(not rear.military.attach_vehicle("g15-apc",squad.platoon).ok,"same hull cannot attach twice")
	_expect(rear.military.vehicle_readiness("g15-apc") == 1.0,"fully crewed healthy T04 has full readiness without a mission demand")
	_expect(not rear.military.vehicle_capability("g15-apc","Movement").ok,"numerical readiness cannot invent fuel for actual movement")
	_expect(rear.military.set_vehicle_mission("g15-apc",{"E26":10},5.0).ok,"actual mission sets matching rack and route-fuel targets")
	_expect(rear.military.vehicle_readiness("g15-apc") == 0.0,"empty ammunition and fuel override healthy crew")
	_expect(not rear.military.vehicle_capability("g15-apc","Fire").ok,"healthy gunner cannot fire an empty matching rack")
	_expect(rear.military.board_squad(squad.id,"g15-apc").ok,"same four squad members board actual passenger seats")
	_expect(not rear.military.capability(squad.id).ok,"mounted squad cannot claim dismounted fire or capture capability")
	var second_roster: Array[String] = []
	for i in 4:
		var id := "other-mounted-%d" % i
		_person(base,id,"None",true)
		second_roster.append(id)
	_expect(rear.military.form_squad("Rifle",second_roster).ok,"second real squad may exist beside first vehicle attachment")
	rear.advance_time(8)
	var second_squad: Dictionary = rear.military.squads.values()[1]
	_expect(not rear.military.board_squad(second_squad.id,"g15-apc").ok,"one attached element cannot silently accept a second squad even if seats remain")
	hull = rear.ledger.inspect_entity("g15-apc")
	_expect(hull.crew.size() == 3 and hull.passengers.size() == 4,"crew and squad passengers occupy separate pools")
	_expect(rear.military.exit_squad(squad.id).ok,"same roster physically exits at HQ")
	_expect(rear.military.capability(squad.id).ok,"same squad regains dismounted role only after actual exit")
	_expect(rear.ledger.inspect_entity("g15-apc").crew.size() == 3 and rear.ledger.inspect_entity("g15-apc").passengers.is_empty(),"disembark leaves crew stations occupied")
	_expect(base.audit().is_empty(),"vehicle attachment and boarding conserve identities: "+str(base.audit()))

func _test_leadership_delay_and_acting_commander() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	for i in 4: _person(base,"leader-%d" % i,"None",true)
	rear.advance_time(8)
	var squad: Dictionary = rear.military.squads.values()[0]
	var first: String = squad.leader
	_expect(not first.is_empty(),"real trained member holds squad appointment")
	_expect(rear.military.commander() == "initial-hq-05","original fixed Commander remains one identified person")
	rear.ledger._entities[first].health = 0 # G16 owns the eventual casualty transition; this is a leadership fixture.
	rear.advance_time(0)
	_expect(squad.replacement_due == rear.time+5.0,"leader loss starts five-second replacement delay")
	rear.advance_time(4.9)
	_expect(squad.leader == first,"existing leader appointment is not replaced before five seconds")
	rear.advance_time(0.2)
	_expect(not squad.leader.is_empty() and squad.leader != first,"another existing trained member takes squad appointment after delay")
	var second: String = squad.leader
	rear.ledger._entities["initial-hq-05"].health = 0
	rear.advance_time(0)
	_expect(rear.military.commander() == second,"highest eligible existing senior acts as Commander")
	_expect(rear.ledger.inspect_entity(second).leader_appointment.contains("Acting Commander"),"same trained identity holds acting command without moving")
	_expect(base.audit().is_empty(),"leadership succession keeps one physical identity: "+str(base.audit()))

func _test_acting_rifle_conscript() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	for i in 4:
		var id := "conscript-%d" % i
		_expect(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,false,"None","None").ok,"same actual conscript in HQ Reserve")
		rear.dispatch.military_people[id] = "g15-conscript"
		rear.dispatch.hq_reserve[id] = "Occupied"
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"actual issued conscript rifle")
		_expect(rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"actual issued conscript rounds")
	rear.advance_time(8)
	var row: Dictionary = rear.military.squads.values()[0]
	_expect(row.kind == "Rifle" and row.acting and not row.leader.is_empty(),"untrained Rifle roster uses a real acting squad leader")
	_expect(rear.ledger.inspect_entity(row.leader).leader_appointment == "Acting Rifle Squad","acting exception is recorded on the same untrained identity")
	_expect(rear.military.platoons[row.platoon].leader.is_empty(),"untrained acting Rifle leader cannot fill trained senior appointment")
	_expect(base.audit().is_empty(),"conscript acting appointment keeps real identities exclusive")

func _test_other_squad_minima() -> void:
	var mg := Base.new(true)
	for i in 2: _person(mg,"mg-%d" % i,"P04")
	for i in 2: _person(mg,"mg-guard-%d" % i,"None",true)
	var mg_ids: Array[String] = ["mg-0","mg-1","mg-guard-0","mg-guard-1"]
	_expect(mg.rear.ledger.add_weapon("mg-gun","E05",10.0,"mg-0",mg.rear.PLAYER,"E02",360).ok,"real P04 holds E05")
	_expect(not mg.rear.military.assess_squad("Machine gun",mg_ids).ok,"Machine gun requires actual team rounds")
	_expect(mg.rear.ledger.add_stock("mg-team-rounds","E02",180,0.02,"mg-0",mg.rear.PLAYER).ok,"issued E02 team stock")
	_expect(mg.rear.military.assess_squad("Machine gun",mg_ids).ok,"two P04, gun, team rounds and armed guards meet minimum")
	var mortar := Base.new(true)
	for i in 3: _person(mortar,"mortar-%d" % i,"P04")
	_person(mortar,"mortar-guard","None",true)
	var mortar_ids: Array[String] = ["mortar-0","mortar-1","mortar-2","mortar-guard"]
	_expect(mortar.rear.ledger.add_weapon("mortar-tube","E06",12.0,"mortar-0",mortar.rear.PLAYER,"E07",1).ok,"actual P04 holds mortar")
	_expect(mortar.rear.ledger.add_stock("mortar-bombs","E07",6,1.0,"mortar-1",mortar.rear.PLAYER).ok,"actual six bombs")
	_expect(not mortar.rear.military.assess_squad("Mortar",mortar_ids).ok,"Mortar lacks required issued radio")
	_expect(mortar.rear.ledger.add_stock("mortar-radio","E18",1,3.0,"mortar-2",mortar.rear.PLAYER).ok,"actual radio")
	_expect(mortar.rear.military.assess_squad("Mortar",mortar_ids).ok,"three P04, tube, bombs, radio and armed guard meet minimum")
	var engineer := Base.new(true)
	for i in 2: _person(engineer,"engineer-%d" % i,"P02",true)
	for i in 2: _person(engineer,"engineer-guard-%d" % i,"None",true)
	var engineer_ids: Array[String] = ["engineer-0","engineer-1","engineer-guard-0","engineer-guard-1"]
	_expect(engineer.rear.ledger.add_stock("engineer-kit-0","E08",1,5.0,"engineer-0",engineer.rear.PLAYER).ok,"first actual kit")
	_expect(not engineer.rear.military.assess_squad("Engineer",engineer_ids).ok,"Engineer lacks second issued kit")
	_expect(engineer.rear.ledger.add_stock("engineer-kit-1","E08",1,5.0,"engineer-1",engineer.rear.PLAYER).ok,"second actual kit")
	_expect(engineer.rear.military.assess_squad("Engineer",engineer_ids).ok,"two P02 with kits and four armed members meet minimum")
	var medical := Base.new(true)
	_person(medical,"medic","P03")
	for i in 3: _person(medical,"medic-guard-%d" % i,"None",true)
	var medical_ids: Array[String] = ["medic","medic-guard-0","medic-guard-1","medic-guard-2"]
	_expect(medical.rear.ledger.add_stock("medic-kit","E11",1,5.0,"medic",medical.rear.PLAYER).ok,"actual medic kit")
	_expect(medical.rear.ledger.add_stock("medic-packs","E12",3,1.0,"medic",medical.rear.PLAYER).ok,"actual three packs")
	_expect(not medical.rear.military.assess_squad("Medical",medical_ids).ok,"Medical lacks stretcher")
	_expect(medical.rear.ledger.add_stock("medic-stretcher","E21",1,5.0,"medic",medical.rear.PLAYER).ok,"actual stretcher")
	_expect(medical.rear.military.assess_squad("Medical",medical_ids).ok,"P03, kit, packs, stretcher and armed guards meet minimum")
	var recon := Base.new(true)
	_person(recon,"operator","P06")
	for i in 3: _person(recon,"recon-guard-%d" % i,"None",true)
	var recon_ids: Array[String] = ["operator","recon-guard-0","recon-guard-1","recon-guard-2"]
	for item in [["E15",1],["E16",1],["E17",1]]:
		_expect(recon.rear.ledger.add_stock("recon-"+str(item[0]),str(item[0]),int(item[1]),2.0,"operator",recon.rear.PLAYER).ok,"actual recon equipment "+str(item[0]))
	_expect(not recon.rear.military.assess_squad("Reconnaissance",recon_ids).ok,"Reconnaissance lacks E20 binoculars")
	_expect(recon.rear.ledger.add_stock("recon-E20","E20",1,1.0,"operator",recon.rear.PLAYER).ok,"actual binoculars")
	_expect(recon.rear.military.assess_squad("Reconnaissance",recon_ids).ok,"P06 drone package and armed guards meet minimum")
	var marksman := Base.new(true)
	_person(marksman,"marksman","P07")
	for i in 3: _person(marksman,"marksman-guard-%d" % i,"None",true)
	var marksman_ids: Array[String] = ["marksman","marksman-guard-0","marksman-guard-1","marksman-guard-2"]
	_expect(marksman.rear.ledger.add_weapon("marksman-rifle","E19",7.0,"marksman",marksman.rear.PLAYER,"E02",30).ok,"actual issued marksman rifle")
	_expect(marksman.rear.ledger.add_stock("marksman-rounds","E02",30,0.02,"marksman",marksman.rear.PLAYER).ok,"actual matching rounds")
	_expect(not marksman.rear.military.assess_squad("Marksman",marksman_ids).ok,"Marksman lacks issued binoculars")
	_expect(marksman.rear.ledger.add_stock("marksman-binoculars","E20",1,1.0,"marksman",marksman.rear.PLAYER).ok,"actual issued binoculars")
	_expect(marksman.rear.military.assess_squad("Marksman",marksman_ids).ok,"P07 rifle, binoculars, rounds and armed guards meet minimum")
	_check_type_formation(mg,"Machine gun",mg_ids)
	_check_type_formation(mortar,"Mortar",mortar_ids)
	_check_type_formation(engineer,"Engineer",engineer_ids)
	_check_type_formation(medical,"Medical",medical_ids)
	_check_type_formation(recon,"Reconnaissance",recon_ids)
	_check_type_formation(marksman,"Marksman",marksman_ids)

func _check_type_formation(base: RefCounted, kind: String, people: Array[String]) -> void:
	_expect(base.rear.military.form_squad(kind,people).ok,"real %s squad reserves the exact named roster" % kind)
	base.rear.advance_time(8)
	var row: Dictionary = base.rear.military.squads.values()[0]
	_expect(row.kind == kind and row.state == "Active" and row.roster.size() == people.size(),"%s physically reports with its actual minimum" % kind)
	_expect(base.rear.military.capability(row.id).ok,"%s retains its locally issued minimum after reporting" % kind)
	_expect(base.audit().is_empty(),"%s report conserves physical identities: %s" % [kind,str(base.audit())])

func _test_replacements_readiness_and_roster_cap() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	for i in 4: _person(base,"reserve-%d" % i,"None",true)
	rear.advance_time(8)
	var squad: Dictionary = rear.military.squads.values()[0]
	_expect(is_equal_approx(rear.military.readiness(squad.id),0.5),"four actual Rifles with 30 rounds each yield minimum-of-personnel/equipment/ammunition 0.5")
	_expect(rear.military.capability(squad.id).ok,"explicit minimum capability accepts four despite readiness below full target")
	for i in range(4,9): _person(base,"reserve-%d" % i,"None",true)
	rear.advance_time(0)
	_expect(rear.military.replacement_reports.size() == 4,"HQ command reserves only four vacant roster places before a new squad")
	_expect(rear.dispatch.hq_reserve.size() == 5,"five actual reserves still occupy HQ places during replacement report")
	rear.advance_time(8)
	_expect(squad.roster.size() == 8 and rear.military.replacement_reports.is_empty(),"four same people physically join existing squad at rendezvous")
	_expect(rear.dispatch.hq_reserve.size() == 1,"one unselected reserve remains physically at HQ")
	_expect(not rear.military.request_replacement(squad.id,"reserve-8").ok,"ninth roster person refused without freeing a real place")
	_expect(rear.military.capability(squad.id).ok,"full roster retains exact minimum capability")
	var weapon: Dictionary = rear.ledger.transfer_weapon("reserve-0-rifle","hq-formation")
	_expect(weapon.ok,"one same rifle removed at actual local point")
	_expect(not rear.military.capability(squad.id).ok,"numeric readiness cannot override missing mandatory issued rifle")
	_expect(rear.military.readiness(squad.id) < 1.0,"least-satisfied equipment type lowers readiness when one rifle leaves")
	_expect(base.audit().is_empty(),"replacement and readiness preserve all physical identities: "+str(base.audit()))

func _test_requested_specialist_issue() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	for i in 2: _person(base,"engineer-%d" % i,"P02")
	for i in 2: _person(base,"engineer-guard-%d" % i,"None",true)
	for i in 2:
		_expect(rear.ledger.add_weapon("hq-engineer-rifle-%d" % i,"E01",4.0,"hq-stock",rear.PLAYER,"E02",30).ok,"real unissued engineer rifle at HQ")
	_expect(rear.ledger.add_stock("hq-engineer-rounds","E02",60,0.02,"hq-stock",rear.PLAYER).ok,"actual matching HQ rounds")
	_expect(rear.ledger.add_stock("hq-engineer-kits","E08",2,4.0,"hq-stock",rear.PLAYER).ok,"two actual HQ engineer kits")
	_expect(rear.military.request_need("Engineer","Required blocked route",2).ok,"named command need requests compatible specialists")
	rear.advance_time(180)
	var found := false
	for row in rear.military.squads.values():
		if row.kind == "Engineer" and row.state == "Active" and rear.military.capability(row.id).ok: found = true
	_expect(found,"HQ physically issues matching kits, rifles and rounds before forming active Engineer squad")
	_expect(base.audit().is_empty(),"specialist issue and formation conserve people and stock: "+str(base.audit()))

func _test_pending_intent_cancellation() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	for i in 4: _person(base,"cancel-rifle-%d" % i,"None",true)
	rear.advance_time(0)
	var pending: Dictionary = rear.military.squads.values()[0]
	_expect(rear.ledger.move_entity("cancel-rifle-0","hq-formation",Vector2(1640.0,91.0)).ok,"fixture moves one pending person to actual formation place")
	_expect(not rear.military.cancel_pending_squad(pending.id).ok,"command cannot erase a roster intent after a person physically left HQ Reserve")
	_expect(rear.ledger.move_entity("cancel-rifle-0","hq-reserve",Vector2(1625.0,91.0)).ok,"fixture returns same person physically before safe cancellation")
	_expect(rear.military.cancel_pending_squad(pending.id).ok,"command may release only an uncompleted formation intent")
	_expect(rear.military.squads.is_empty() and rear.military.platoons.is_empty() and rear.military.companies.is_empty(),"cancelled empty hierarchy leaves no invented parent")
	_expect(rear.dispatch.hq_reserve.size() == 4 and rear.ledger.inspect_entity("cancel-rifle-0").pending_assignment == "None","same four people keep their occupied physical HQ Reserve places")
	rear.advance_time(8)
	var active: Dictionary = rear.military.squads.values()[0]
	_person(base,"cancel-replacement","None",true)
	rear.advance_time(0)
	_expect(rear.military.replacement_reports.has("cancel-replacement"),"replacement reserves exactly one vacant roster intent")
	_expect(rear.military.cancel_replacement("cancel-replacement").ok,"unused replacement intent cancels without changing active roster")
	_expect(active.roster.size() == 4 and rear.dispatch.hq_reserve.has("cancel-replacement"),"same replacement stays physically at HQ Reserve")
	_expect(rear.ledger.reserve_rear_hull("cancel-hull-admission",rear.PLAYER,"cancel-fixture").ok,"real hull admission for crew cancellation")
	_expect(rear.ledger.create_heavy_output("cancel-hull-admission","cancel-fixture","cancel-hull","T02","hq-berth",rear.PLAYER,Specs.TYPES.T02).ok,"real stopped transport hull")
	_expect(rear.ledger.complete_hq_hull_receipt("cancel-hull").ok,"same hull enters military domain")
	rear.dispatch.military_hulls["cancel-hull"] = "cancel-fixture"
	_person(base,"cancel-driver","P08")
	_expect(rear.military.assign_crew("cancel-driver","cancel-hull","Driver").ok,"qualified actual driver begins station report")
	_expect(rear.military.cancel_crew_report("cancel-driver").ok,"only pending crew station intent cancels")
	_expect(rear.ledger.inspect_entity("cancel-driver").assignment == "HQ Reserve" and rear.dispatch.hq_reserve.has("cancel-driver"),"same driver keeps physical reserve duty")
	_expect(base.audit().is_empty(),"cancelled formation, replacement and crew intents conserve identities")
	var guns := Base.new(true)
	var gun_roster: Array[String] = []
	for i in 4:
		var id := "cancel-gunner-%d" % i
		_person(guns,id,"P05")
		gun_roster.append(id)
	for i in 2:
		var id := "cancel-guard-%d" % i
		_person(guns,id,"None",true)
		gun_roster.append(id)
	_expect(guns.rear.ledger.create_heavy_output("","","cancel-gun","E13","hq-berth",guns.rear.PLAYER,{"mass":180.0,"health":300}).ok,"one actual cancellable field gun")
	_expect(guns.rear.ledger.add_stock("cancel-shells","E14",20,5.0,"hq-berth",guns.rear.PLAYER).ok,"two real ten-shell artillery packages")
	_expect(guns.rear.ledger.add_stock("cancel-radio","E18",1,3.0,"cancel-gunner-0",guns.rear.PLAYER).ok,"actual issued artillery radio")
	_expect(guns.rear.military.form_squad("Artillery",gun_roster).ok,"Artillery reserves one gun and ten shells")
	var gun_squad: Dictionary = guns.rear.military.squads.values()[0]
	var other_roster: Array[String] = []
	for i in 4:
		var id := "other-cancel-gunner-%d" % i
		_person(guns,id,"P05")
		other_roster.append(id)
	for i in 2:
		var id := "other-cancel-guard-%d" % i
		_person(guns,id,"None",true)
		other_roster.append(id)
	_expect(guns.rear.ledger.create_heavy_output("","","other-cancel-gun","E13","hq-berth",guns.rear.PLAYER,{"mass":180.0,"health":300}).ok,"second distinct local field gun")
	_expect(guns.rear.ledger.add_stock("other-cancel-radio","E18",1,3.0,"other-cancel-gunner-0",guns.rear.PLAYER).ok,"second issued artillery radio")
	_expect(guns.rear.military.form_squad("Artillery",other_roster).ok,"second Artillery claims only its own gun and shells")
	var other_squad: Dictionary = guns.rear.military.squads.values()[1]
	_expect(guns.rear.ledger.available("cancel-shells") == 0,"both distinct pending artillery claims hold ten actual shells each")
	_expect(guns.rear.military.cancel_pending_squad(gun_squad.id).ok,"cancelled uncompleted Artillery releases its own gear claims")
	_expect(not guns.rear.military.cancel_pending_squad(gun_squad.id).ok,"repeated cancellation cannot release another squad's commitments")
	_expect(guns.rear.ledger.available("cancel-shells") == 10 and guns.rear.military.artillery_guns.size() == 1,"only cancelled gun and ten shells return to local availability")
	_expect(guns.rear.military.squads.has(other_squad.id) and guns.rear.ledger.inspect_claim(other_squad.shell_claims[0].id).reserved == 10,"other artillery roster and exact stock claim remain reserved")
	guns.rear.advance_time(8)
	_expect(other_squad.state == "Active" and guns.rear.military.capability(other_squad.id).ok,"uncancelled artillery physically reports with its own gun and shells")
	_expect(guns.audit().is_empty(),"cancelled Artillery report conserves real people and gear")

func _test_need_order_and_duplicate_type() -> void:
	var base := Base.new(true)
	for i in 4: _person(base,"need-rifle-%d" % i,"None",true)
	var older: Dictionary = base.rear.military.request_need("Rifle","Lower-value parent mission",2,1)
	var higher: Dictionary = base.rear.military.request_need("Rifle","Higher-value parent mission",2,8)
	_expect(older.ok and higher.ok and older.id != higher.id,"two same-type parent missions keep distinct formation needs")
	base.rear.advance_time(0)
	_expect(base.rear.military.squads.size() == 1,"one actual package satisfies only one queued need")
	_expect(base.rear.military.demands.size() == 1 and base.rear.military.demands.has(older.id),"higher-value equal-priority parent need is served before older lower-value need")
	_expect(base.audit().is_empty(),"distinct need order leaves physical identities exclusive")
