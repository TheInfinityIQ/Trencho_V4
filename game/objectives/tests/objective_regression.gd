extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Execution = preload("res://game/battlefield/squad_execution.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_transport_dismount_capture_and_income()
	_test_contest_reversal_and_decay()
	_test_eligibility_and_nonresource_income()
	_test_proximity_snapshot_oracle()
	print("G18 objective regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _squad(base: RefCounted, prefix: String) -> String:
	var rear: RefCounted = base.rear
	var people: Array[String] = []
	for i in 4:
		var id := "%s-person-%d" % [prefix,i]
		_expect(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"None","None").ok,"actual HQ Reserve squad member")
		rear.dispatch.military_people[id] = prefix
		rear.dispatch.hq_reserve[id] = "Occupied"
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"functional physical rifle")
		_expect(rear.ledger.add_stock(id+"-ammo","E02",30,0.02,id,rear.PLAYER).ok,"matching physical rounds")
		_expect(rear.ledger.load_rounds(id+"-rifle",id+"-ammo",1).ok,"loaded physical round")
		people.append(id)
	var result: Dictionary = rear.military.form_squad("Rifle",people)
	_expect(result.ok,"real Rifle squad forms: "+str(result))
	return str(result.get("id",""))

func _transport(base: RefCounted, squad_id: String) -> String:
	var rear: RefCounted = base.rear
	var hull_id := "capture-transport"
	_expect(rear.ledger.reserve_rear_hull("capture-admission",rear.PLAYER,"capture-fixture").ok,"actual transport admission")
	_expect(rear.ledger.create_heavy_output("capture-admission","capture-fixture",hull_id,"T02","hq-berth",rear.PLAYER,Specs.TYPES.T02).ok,"empty physical transport")
	_expect(rear.ledger.complete_hq_hull_receipt(hull_id).ok,"same transport enters military fleet")
	rear.dispatch.military_hulls[hull_id] = "capture-fixture"
	_expect(rear.ledger.add_person("capture-driver","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08","None").ok,"qualified real driver")
	rear.dispatch.military_people["capture-driver"] = "capture-fixture"
	rear.dispatch.hq_reserve["capture-driver"] = "Occupied"
	_expect(rear.military.assign_crew("capture-driver",hull_id,"Driver").ok,"physical driver report starts")
	rear.advance_time(8)
	_expect(rear.military.vehicles.has(hull_id),"same transport assigned to squad platoon")
	_expect(rear.military.board_squad(squad_id,hull_id).ok,"four physical people board real passenger seats")
	return hull_id

func _test_transport_dismount_capture_and_income() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var squad_id := _squad(base,"a30")
	rear.advance_time(8)
	var hull_id := _transport(base,squad_id)
	var hull: Dictionary = rear.ledger.inspect_entity(hull_id)
	_expect(rear.ledger.add_place("resource-a30","Resource objective",hull.position).ok,"objective has actual physical metre position")
	_expect(rear.objectives.register("resource-a30","Resource").ok,"resource registered without ownership")
	rear.advance_time(30)
	var held: Dictionary = rear.objectives.inspect("resource-a30")
	_expect(held.control == 0.0 and held.owner.is_empty() and held.blue.is_empty(),"parked occupied transport contributes zero capture for thirty seconds")
	var passenger_blockers := 0
	for blocker in held.blockers:
		if str(blocker.person).begins_with("a30-person") and str(blocker.reason).contains("dismount"): passenger_blockers += 1
	_expect(passenger_blockers == 4,"inspection names all four boarded people and their actual exit blocker")
	_expect(is_equal_approx(rear.receiving.snapshot().income,46.0*6.0),"transport passengers grant no resource income beyond baseline")
	_expect(rear.military.exit_squad(squad_id).ok,"same four members physically dismount at legal stopped place")
	rear.advance_time(0)
	_expect(rear.objectives.inspect("resource-a30").blue.size() == 4,"four actual armed dismounted people become eligible")
	rear.advance_time(14.75)
	_expect(rear.objectives.inspect("resource-a30").owner.is_empty(),"neutral control remains unowned before fifteen seconds")
	rear.advance_time(0.25)
	var owned: Dictionary = rear.objectives.inspect("resource-a30")
	_expect(owned.control == 60.0 and owned.owner == rear.PLAYER and owned.income_rate == 1.5 and owned.capture_rate == 0.0,"four dismounted people take neutral control at exact fifteen-second boundary without displaying impossible further progress")
	_expect(is_equal_approx(rear.receiving.snapshot().income,61.0*6.0),"no resource income credited before actual full control")
	rear.advance_time(10)
	_expect(is_equal_approx(rear.receiving.snapshot().income,71.0*6.0+15.0),"owned uncontested Resource adds continuous 1.5/s to existing requisition account")
	_expect(is_equal_approx(rear.receiving.snapshot().money,2500.0+71.0*6.0+15.0),"money and income use same existing requisition ledger")
	_expect(base.audit().is_empty(),"A30 physical squad, transport, objective and money audit reconcile: "+str(base.audit()))

func _test_contest_reversal_and_decay() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var squad_id := _squad(base,"contest")
	rear.advance_time(8)
	_expect(rear.ledger.add_place("resource-contest","Resource objective",Vector2(1640,91)).ok,"physical contested resource")
	_expect(rear.objectives.register("resource-contest","Resource").ok,"registered neutral resource")
	rear.advance_time(10)
	_expect(rear.objectives.inspect("resource-contest").control == 40.0,"four eligible people produce capped four work per second")
	_expect(rear.ledger.add_place("remote-place","Safe remote place",Vector2(1500,91)).ok,"actual departure destination")
	for id in rear.military.squads[squad_id].roster: _expect(rear.ledger.move_entity(id,"remote-place",Vector2(1500,91)).ok,"same member physically leaves radius")
	rear.advance_time(0)
	rear.advance_time(20)
	_expect(rear.objectives.inspect("resource-contest").control == 0.0,"unowned partial progress decays toward zero at two per second")
	for id in rear.military.squads[squad_id].roster: _expect(rear.ledger.move_entity(id,"hq-formation",Vector2(1640,91)).ok,"same member physically returns")
	rear.advance_time(0)
	rear.advance_time(15)
	_expect(rear.objectives.inspect("resource-contest").owner == rear.PLAYER,"returning real squad captures resource")
	for i in 4:
		var id := "red-person-%d" % i
		_expect(rear.ledger.add_person(id,"resource-contest","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"real hostile person enters objective")
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,"army-red","E02",10).ok,"hostile carries functional rifle")
		_expect(rear.ledger.add_stock(id+"-ammo","E02",1,0.02,id,"army-red").ok,"hostile carries matching round")
	rear.advance_time(0)
	var contested: Dictionary = rear.objectives.inspect("resource-contest")
	_expect(contested.state == "Contested" and contested.blue.size() == 4 and contested.red.size() == 4,"two actual armies contest without progress")
	var prior_income: float = rear.receiving.snapshot().income
	rear.advance_time(10)
	_expect(rear.objectives.inspect("resource-contest").control == 60.0 and is_equal_approx(rear.receiving.snapshot().income-prior_income,60.0),"contested resource grants no additional income")
	for id in rear.military.squads[squad_id].roster: _expect(rear.ledger.move_entity(id,"remote-place",Vector2(1500,91)).ok,"blue squad physically retreats")
	rear.advance_time(0)
	rear.advance_time(15)
	_expect(rear.objectives.inspect("resource-contest").control == 0.0 and rear.objectives.inspect("resource-contest").owner.is_empty(),"four red people remove blue owner at zero after fifteen seconds")
	rear.advance_time(15)
	_expect(rear.objectives.inspect("resource-contest").control == -60.0 and rear.objectives.inspect("resource-contest").owner == "army-red","another fifteen seconds reverses full ownership")
	_expect(base.audit().is_empty(),"contested and reversed actual identities reconcile: "+str(base.audit()))

func _test_eligibility_and_nonresource_income() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var site := Vector2(1700,200)
	_expect(rear.ledger.add_place("route-hub","Physical route hub",site).ok,"actual operational place")
	_expect(rear.objectives.register("route-hub","Route Hub").ok,"route hub has control but no material or money grant")
	for i in 5:
		var id := "eligible-%d" % i
		_expect(rear.ledger.add_person(id,"route-hub",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"actual person within objective radius")
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",10).ok,"actual functional carried weapon")
		if i < 4:
			_expect(rear.ledger.add_stock(id+"-round","E02",1,0.02,id,rear.PLAYER).ok,"one physically available matching round")
	rear.advance_time(0)
	var seen: Dictionary = rear.objectives.inspect("route-hub")
	_expect(seen.blue.size() == 4 and seen.capture_rate == 4.0,"fifth empty rifle supplies zero work; four eligible people meet cap")
	_expect(seen.blockers.size() == 1 and seen.blockers[0].reason.contains("matching"),"inspection explains empty-rifle ineligibility")
	_expect(rear.ledger.add_stock("eligible-4-round","E02",1,0.02,"eligible-4",rear.PLAYER).ok,"fifth matching round physically added")
	rear.advance_time(0)
	_expect(rear.objectives.inspect("route-hub").blue.size() == 5 and rear.objectives.inspect("route-hub").capture_rate == 4.0,"five eligible bodies still capped at four work")
	_expect(rear.ledger.add_place("just-outside","Actual point beyond radius",site+Vector2(25.01,0)).ok,"physical beyond-radius point")
	_expect(rear.ledger.move_entity("eligible-4","just-outside",site+Vector2(25.01,0)).ok,"same fifth body physically leaves radius")
	rear.advance_time(0)
	_expect(rear.objectives.inspect("route-hub").blue.size() == 4,"25.01 m is outside capture radius")
	_expect(rear.ledger.move_entity("eligible-4","route-hub",site+Vector2(25,0)).ok,"same person reaches exact radius boundary")
	rear.advance_time(0)
	_expect(rear.objectives.inspect("route-hub").blue.size() == 5,"25.0 m boundary is included")
	rear.combat._apply_stress("eligible-0",-50,0,false)
	rear.advance_time(0)
	_expect(rear.objectives.inspect("route-hub").blue.size() == 4 and str(rear.objectives.inspect("route-hub").blockers).contains("Broken"),"G16 Broken person cannot contribute work")
	_expect(rear.combat.injure("eligible-1",100).ok,"actual second person incapacitated")
	rear.advance_time(0)
	_expect(rear.objectives.inspect("route-hub").blue.size() == 3,"incapacitated person also supplies zero")
	var start_money: float = rear.receiving.snapshot().money
	rear.advance_time(20)
	_expect(rear.objectives.inspect("route-hub").owner == rear.PLAYER and is_equal_approx(rear.receiving.snapshot().money-start_money,120.0),"three people take twenty seconds, but Route Hub adds no requisition to baseline")
	_expect(base.audit().is_empty(),"eligibility filters and nonresource income preserve identities: "+str(base.audit()))


func _oracle_person(rear: RefCounted, id: String, at: Vector2, owner: String = "army-blue", weapon: bool = true, ammo: String = "E02", count: int = 1, gear_owner: String = "") -> String:
	var ledger: RefCounted = rear.ledger
	_expect(ledger.add_person(id,"oracle-a",owner,Records.Assignment.AVAILABLE,true,"None","None").ok,"oracle actual person "+id)
	_expect(ledger.move_entity(id,"oracle-a",at).ok,"oracle physical person position")
	var actual_owner: String = owner if gear_owner.is_empty() else gear_owner
	if weapon: _expect(ledger.add_weapon(id+"-rifle","E01",4,id,actual_owner,"E02",30).ok,"oracle actual functional weapon")
	if count > 0: _expect(ledger.add_stock(id+"-ammo",ammo,count,1.0 if ammo == "M11" else 0.02,id,actual_owner).ok,"oracle actual loose stock")
	return id


func _test_proximity_snapshot_oracle() -> void:
	var base := Base.new(false,true,false,Vector2(1640,91),false)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var at := Vector2(2000,500)
	for entry in [["oracle-a",at,"Resource"],["oracle-b",at+Vector2(10,0),"Observation"],["oracle-c",at+Vector2(500,0),"Route Hub"]]:
		_expect(ledger.add_place(entry[0],"Oracle actual objective",entry[1]).ok,"oracle physical objective")
		_expect(rear.objectives.register(entry[0],entry[2]).ok,"oracle registered objective order")
	var roster: Array[String] = []
	for index in 4: roster.append(_oracle_person(rear,"oracle-foot-%d" % index,at,rear.PLAYER,true,"E02",30))
	_expect(rear.military.add_initial_squad("oracle-foot","Rifle",roster,"oracle-company","oracle-platoon",rear.PLAYER).ok,"oracle real formation")
	_oracle_person(rear,"oracle-red",at+Vector2(0,1),"army-red")
	_oracle_person(rear,"oracle-foreign-person",at,"supplier")
	_oracle_person(rear,"oracle-boundary",at-Vector2(25,0))
	_oracle_person(rear,"oracle-outside",at-Vector2(25.01,0))
	_oracle_person(rear,"oracle-distant",at+Vector2(1000,0))
	_oracle_person(rear,"oracle-unarmed",at,rear.PLAYER,false,"E02",0)
	_oracle_person(rear,"oracle-wrong-ammo",at,rear.PLAYER,true,"M11")
	_oracle_person(rear,"oracle-reserved",at)
	_expect(ledger.request_stock("oracle-reservation","oracle-reserved-ammo",1,"oracle","unavailable loose round",rear.PLAYER).ok,"oracle real round reservation")
	_oracle_person(rear,"oracle-loaded",at,rear.PLAYER,true,"E02",2)
	_expect(ledger.load_rounds("oracle-loaded-rifle","oracle-loaded-ammo",1).ok,"oracle actual loaded round")
	_expect(ledger.request_stock("oracle-loaded-reservation","oracle-loaded-ammo",1,"oracle","unavailable remaining loose round",rear.PLAYER).ok,"oracle loaded person has reserved loose stock")
	_oracle_person(rear,"oracle-broken-weapon",at)
	# Declared damaged fixture weapon, as in the existing production stock tests.
	ledger._entities["oracle-broken-weapon-rifle"].health = 0
	_oracle_person(rear,"oracle-foreign-gear",at,rear.PLAYER,true,"E02",1,"army-red")
	_oracle_person(rear,"oracle-broken",at)
	rear.combat._apply_stress("oracle-broken",-50,0,false)
	for state in ["wounded","recovery","dead"]:
		var id: String = _oracle_person(rear,"oracle-"+state,at)
		_expect(ledger.injure_person(id,100).ok,"oracle actual incapacitation")
		if state == "recovery": _expect(ledger.finish_field_care(id).ok,"oracle actual recovery")
		if state == "dead": _expect(ledger.kill_person(id,"oracle casualty").ok,"oracle actual death")
	_oracle_person(rear,"oracle-courier",at)
	_expect(ledger.request_assignment("oracle-courier",Records.Assignment.REAR_LABOUR,"oracle-carry").ok,"oracle actual labour assignment")
	_expect(ledger.add_stock("oracle-freight","M11",1,1,"oracle-a",rear.PLAYER).ok,"oracle real local freight")
	_expect(ledger.begin_carry("oracle-courier","oracle-freight",1).ok,"oracle actual carry")
	_expect(ledger.request_assignment("oracle-courier",Records.Assignment.AVAILABLE,"").ok,"oracle actual pending carry handoff")
	_expect(ledger.add_initial_vehicle("oracle-truck","T02","oracle-a",rear.PLAYER,Specs.TYPES.T02,40,"Military").ok,"oracle physical carrier")
	_expect(ledger.add_person("oracle-driver","oracle-a",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P08","None").ok,"oracle real qualified driver")
	_expect(ledger.assign_initial_vehicle_crew("oracle-driver","oracle-truck","Driver").ok,"oracle actual crew occupancy")
	_expect(rear.military.attach_initial_vehicle("oracle-truck","oracle-platoon").ok,"oracle attached hull")
	_compare_snapshot_oracle(rear,"nearby physical eligibility, ammunition and multiple objectives")
	var first: Dictionary = rear.objectives.inspect("oracle-a")
	_expect("oracle-boundary" in first.blue and "oracle-outside" not in first.blue,"exact radius included and actual just-outside person excluded")
	_expect("oracle-foreign-gear" in first.blue and "oracle-loaded" in first.blue and "oracle-courier" in first.blue,"legacy eligibility retains foreign held gear, loaded round and active carry/pending states")
	_expect("oracle-reserved" not in first.blue and "oracle-wrong-ammo" not in first.blue and "oracle-broken-weapon" not in first.blue,"reserved-only, mismatched and broken weapons remain blocked")
	_expect(rear.military._reserve_transport_manifest("oracle-truck",["oracle-foot"]).ok,"oracle actual passenger manifest")
	for id in roster: _expect(ledger.board_formation_passenger(id,"oracle-truck").ok,"oracle actual passenger boards")
	_expect(ledger.injure_person("oracle-driver",100).ok,"oracle seated incapacitation retains first blocker priority")
	_compare_snapshot_oracle(rear,"aboard passengers and wounded crew priority")
	_expect(rear.military.exit_squad("oracle-foot","oracle-a").ok,"oracle same passengers dismount")
	_expect(ledger.finish_carry("oracle-courier","oracle-a").ok,"oracle same freight deposits before duty handoff")
	rear.battlefield_operations = Execution.new(rear)
	rear.battlefield_operations._walk(roster[0],"oracle-a",at+Vector2(8,0))
	_expect(rear.battlefield_operations.person_committed(roster[0]),"oracle real tactical walking commitment")
	rear.advance_time(2)
	_compare_snapshot_oracle(rear,"actual movement and dismounted people retain legacy participation")
	rear.battlefield_operations = null
	_expect(ledger.move_entity("oracle-foot-2","oracle-c",at+Vector2(500,0)).ok,"oracle real move to distinct objective")
	_compare_snapshot_oracle(rear,"distinct objective presence and person order")
	_expect(ledger.add_place("oracle-away","Actual remote fixture location",Vector2(3500,4500)).ok,"oracle remote physical place")
	_expect(ledger.move_entity("oracle-truck","oracle-away",Vector2(3500,4500)).ok,"oracle hull and crew leave objective radius")
	for person in ledger.entities_of_kind(Records.Kind.PERSON,false):
		if str(person.id).begins_with("oracle-") and ledger.entity_kind(person.holder_id) == "PLACE":
			_expect(ledger.move_entity(person.id,"oracle-away",Vector2(3500,4500)).ok,"oracle physical departure")
	_compare_snapshot_oracle(rear,"departures clear all prior presence and blockers")
	for row in rear.objectives.objectives.values(): _expect(row.blue.is_empty() and row.red.is_empty() and row.blockers.is_empty(),"empty nearby set clears every objective")
	_compare_snapshot_oracle(rear,"repeated empty refresh remains unchanged")
	_expect(base.audit().is_empty(),"oracle physical fixtures reconcile: "+str(base.audit()))


func _compare_snapshot_oracle(rear: RefCounted, label: String) -> void:
	_compare_person_query(rear,label)
	var expected: Dictionary = _legacy_snapshot_refresh(rear)
	var ledger_events: int = rear.ledger._events.size()
	var money: float = rear.receiving.requisition_balance()
	var changed: bool = rear.objectives._refresh()
	_expect(changed == expected.changed,"legacy changed result: "+label)
	_expect(rear.objectives.objectives == expected.rows,"legacy exact objective rows, participant/blocker order, control and income: "+label)
	_expect(rear.ledger._events.size() == ledger_events and rear.receiving.requisition_balance() == money,"refresh remains a read of physical/account state: "+label)

func _compare_person_query(rear: RefCounted, label: String) -> void:
	var points: Array[Vector2] = []
	for row in rear.objectives.objectives.values(): points.append(row.position)
	var full: Array[Dictionary] = []
	var metadata: Array[Dictionary] = []
	# Independent complete inspection retains all people before the old filter.
	for person in rear.ledger.snapshot().entities:
		if person.kind != "PERSON" or person.owner not in [rear.PLAYER,"army-red"]: continue
		for row in rear.objectives.objectives.values():
			if person.position.distance_to(row.position) > 25.0+0.000001: continue
			full.append(person)
			var projected: Dictionary = person.duplicate(true)
			projected.erase("contents_mass_kg")
			metadata.append(projected)
			break
	_expect(rear.ledger.persons_near_any(points,25.0+0.000001,[rear.PLAYER,"army-red"]) == full,"Nearby person query preserves full fields, default mass and canonical order: "+label)
	var queried: Array[Dictionary] = rear.ledger.persons_near_any(points,25.0+0.000001,[rear.PLAYER,"army-red"],false)
	_expect(queried == metadata,"Nearby metadata matches original full-snapshot proximity selection: "+label)
	for person in queried: person.position = Vector2.INF
	var repeated: Array = points.duplicate()
	repeated.reverse()
	if not points.is_empty(): repeated.append(points[0])
	_expect(rear.ledger.persons_near_any(repeated,25.0+0.000001,["army-red",rear.PLAYER,rear.PLAYER],false) == metadata,"Reordered/repeated points and owners keep each detached person once in ledger order: "+label)
	_expect(rear.ledger.persons_near_any([],25.0,[rear.PLAYER]).is_empty() and rear.ledger.persons_near_any(points,25.0,[]).is_empty(),"Empty proximity or owner selection returns no people")


func _legacy_snapshot_refresh(rear: RefCounted) -> Dictionary:
	# Independent retained algorithm: full metadata snapshot and all held goods
	# are classified before any person/objective proximity checks.
	var rows: Dictionary = rear.objectives.objectives.duplicate(true)
	var blue := {}
	var red := {}
	var blockers: Array[Dictionary] = []
	var entities: Array = rear.ledger.snapshot(false).entities
	var by_id := {}
	for item in entities: by_id[item.id] = item
	var held_weapons := {}
	var held_rounds := {}
	for item in entities:
		if item.kind == "WEAPON" and item.functional:
			if not held_weapons.has(item.holder_id): held_weapons[item.holder_id] = []
			held_weapons[item.holder_id].append(item)
		elif item.kind == "STOCK" and item.available > 0:
			if not held_rounds.has(item.holder_id): held_rounds[item.holder_id] = {}
			held_rounds[item.holder_id][item.design_type] = int(held_rounds[item.holder_id].get(item.design_type,0))+int(item.available)
	for person in entities:
		if person.kind != "PERSON" or person.owner not in [rear.PLAYER,"army-red"]: continue
		var reason := ""
		var holder: Dictionary = by_id.get(person.holder_id,{})
		if holder.get("kind","") != "PLACE" or not str(person.crew_station).is_empty(): reason = "Still aboard or crewing a vehicle; physically dismount first."
		elif person.health <= 0 or person.assignment in ["Wounded","Recovery","Dead"]: reason = "Wounded, recovering or dead people cannot capture."
		elif rear.combat.broken.has(person.id): reason = "Broken morale requires regrouping."
		else:
			var armed := false
			for weapon in held_weapons.get(person.id,[]):
				if weapon.loaded_rounds > 0 or int(held_rounds.get(person.id,{}).get(weapon.ammo_type,0)) > 0: armed = true
				if armed: break
			if not armed: reason = "No functional carried weapon with a matching available round."
		for row in rows.values():
			if person.position.distance_to(row.position) > 25.0+0.000001: continue
			if reason.is_empty():
				if person.owner == rear.PLAYER:
					if not blue.has(row.id): blue[row.id] = []
					blue[row.id].append(person.id)
				else:
					if not red.has(row.id): red[row.id] = []
					red[row.id].append(person.id)
			else: blockers.append({"objective":row.id,"person":person.id,"position":person.position,"holder":person.holder_id,"reason":reason})
	var changed := false
	for row in rows.values():
		var present_blue: Array = blue.get(row.id,[])
		var present_red: Array = red.get(row.id,[])
		var present_blockers: Array = []
		for blocker in blockers:
			if blocker.objective == row.id: present_blockers.append(blocker)
		if row.blue != present_blue or row.red != present_red or row.blockers != present_blockers: changed = true
		row.blue = present_blue
		row.red = present_red
		row.blockers = present_blockers
	return {"rows":rows,"changed":changed}
