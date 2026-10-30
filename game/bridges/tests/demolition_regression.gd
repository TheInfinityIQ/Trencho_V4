extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_a36()
	print("G21 demolition regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(detail)

func _reserve(base: RefCounted, id: String, engineer: bool) -> void:
	var rear: RefCounted = base.rear
	_check(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P02" if engineer else "None","None").ok,"real received reserve "+id)
	rear.dispatch.military_people[id] = "g21-receipt"
	rear.dispatch.hq_reserve[id] = "Occupied"
	_check(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",30).ok,"physical rifle "+id)
	_check(rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"physical ammunition "+id)
	if engineer: _check(rear.ledger.add_stock(id+"-kit","E08",1,5.0,id,rear.PLAYER).ok,"physical E08 "+id)

func _a36() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	rear.combat.world.paint(Rect2i(101,10,30,20),"TR11")
	var ordered: Dictionary = rear.bridges.order("B03",Vector2(100.5,20.5),Vector2(131.5,20.5))
	_check(ordered.ok and ordered.max_health == 7000,"A36 actual full-health 30 m B03")
	if not ordered.ok: return
	var bridge_id: String = ordered.id
	for i in 4:
		var id := "builder-%d" % i
		_check(rear.ledger.add_person(id,bridge_id+"-a",rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02").ok,"actual bridge builder")
		_check(rear.ledger.add_stock(id+"-kit","E08",1,5.0,id,rear.PLAYER).ok,"builder E08")
		_check(rear.bridges.assign_engineer(bridge_id,id).ok,"builder assigned")
	_check(rear.ledger.add_carrier("construction-carrier","hq-stock",rear.PLAYER,rear.PLAYER).ok,"physical construction carrier")
	_check(rear.ledger.add_stock("construction-m11","M11",2400,1.0,"construction-carrier",rear.PLAYER).ok,"physical B03 M11")
	_check(rear.ledger.move_entity("construction-carrier","hq-stock",Vector2(100.5,20.5)).ok,"M11 physically arrives")
	_check(rear.bridges.deliver_material(bridge_id,"construction-m11",2400).ok,"M11 staged")
	rear.advance_time(300)
	_check(rear.bridges.inspect(bridge_id).state == "Complete" and rear.bridges.inspect(bridge_id).health == 7000,"full-health B03 completed")
	for i in 4: _reserve(base,"denial-%d" % i,i < 2)
	var roster: Array[String] = ["denial-0","denial-1","denial-2","denial-3"]
	var formation: Dictionary = rear.military.form_squad("Engineer",roster)
	_check(formation.ok,"actual G15 engineer squad forms: "+formation.get("message",""))
	if not formation.ok: return
	rear.advance_time(8)
	var squad_id: String = formation.id
	_check(rear.military.squads[squad_id].state == "Active","actual squad reports")
	var bank: Vector2 = rear.bridges.projects[bridge_id].banks[0]
	for i in 2: _check(rear.ledger.move_entity("denial-%d" % i,bridge_id+"-a",bank).ok,"engineer walks to actual endpoint")
	var engineers: Array[String] = ["denial-0","denial-1"]
	var demolition: Dictionary = rear.demolition.order("Bridge",bridge_id,squad_id,engineers)
	_check(demolition.ok and demolition.m06 == 14 and demolition.work == 38,"A36 fixed fourteen M06 and 38 work: "+demolition.get("message",""))
	if not demolition.ok: return
	var id: String = demolition.id
	var competing: Dictionary = rear.field_structures.order("S02",Vector2(300.5,100.5))
	_check(competing.ok and not rear.field_structures.assign_engineer(competing.id,"denial-0").ok,"placing D04 engineer cannot simultaneously build field structure")
	rear.advance_time(20)
	_check(rear.demolition.inspect(id).progress == 0.0 and rear.ledger.total_stock("M06") == 0,"remote stock cannot advance or become free charge")
	_check(rear.ledger.add_carrier("charge-carrier","hq-stock",rear.PLAYER,rear.PLAYER).ok,"real charge carrier")
	_check(rear.ledger.add_stock("charge-m06","M06",14,1.0,"charge-carrier",rear.PLAYER).ok,"fourteen manufactured-equivalent physical charges in carrier")
	_check(not rear.demolition.deliver(id,"charge-m06",14).ok,"remote M06 refused")
	_check(rear.ledger.move_entity("charge-carrier","hq-stock",bank+Vector2(-5,0)).ok,"carrier reaches 5 m staging")
	_check(rear.demolition.deliver(id,"charge-m06",14).ok,"nearby stock staged at real location")
	_check(rear.demolition.inspect(id).local_m06 == 14,"all fourteen local M06 visible")
	rear.advance_time(18.5)
	_check(is_equal_approx(rear.demolition.inspect(id).progress,37.0) and rear.demolition.inspect(id).m06_consumed == 0,"fractional placement preserves unconsumed material")
	_check(rear.ledger.move_entity("denial-1",bridge_id+"-a",bank+Vector2(-3,0)).ok,"one engineer interrupted")
	rear.advance_time(10)
	_check(is_equal_approx(rear.demolition.inspect(id).progress,37.0) and rear.demolition.inspect(id).m06_consumed == 0,"interrupted work and M06 preserved")
	_check(rear.ledger.move_entity("denial-1",bridge_id+"-a",bank).ok,"engineer resumes")
	rear.advance_time(0.5)
	_check(rear.demolition.inspect(id).state == "Placed" and rear.demolition.inspect(id).m06_consumed == 14 and rear.ledger.total_stock("M06") == 0,"A36 exactly fourteen M06 consumed at placement finish")
	_check(not rear.military.commander().is_empty(),"actual living Commander")
	var plan := {"retreat":"withdraw west","forward_supply":"halt eastbound carriers","wounded_evacuation":"evacuate west before blast","alternate_or_restore":"rebuild B03 with full M11"}
	var invented_emergency: Dictionary = plan.duplicate(true)
	invented_emergency["emergency_hq_assault"] = true
	invented_emergency["observed_hq_threat"] = "unseen-hull"
	_check(not rear.demolition.authorize(id,rear.military.commander(),invented_emergency).ok,"invented HQ threat cannot justify emergency bridge denial")
	var auth: Dictionary = rear.demolition.authorize(id,rear.military.commander(),plan)
	_check(auth.ok,"actual Commander records route consequences: "+auth.get("message",""))
	_check(not rear.demolition.set_mode(id,"Fuse").ok,"unarmed placement cannot set fuse")
	for i in 2: _check(rear.ledger.move_entity("denial-%d" % i,bridge_id+"-a",bank+Vector2(-30,0)).ok,"engineer withdraws thirty metres")
	for i in 4: _check(rear.ledger.move_entity("builder-%d" % i,bridge_id+"-a",bank+Vector2(-30,4+i)).ok,"builders clear actual blast radius")
	_check(rear.ledger.move_entity("construction-carrier","hq-stock",bank+Vector2(-30,-4)).ok,"construction carrier clears blast")
	_check(rear.ledger.move_entity("charge-carrier","hq-stock",bank+Vector2(-30,-6)).ok,"charge carrier clears blast")
	rear.advance_time(0)
	_check(rear.demolition.inspect(id).state == "Arming","withdrawal starts real arming")
	rear.advance_time(5)
	_check(rear.ledger.move_entity("denial-1",bridge_id+"-a",bank).ok,"engineer returns during arming delay")
	rear.advance_time(0)
	_check(rear.demolition.inspect(id).state == "Placed","return interrupts arming without unconsuming the placed device")
	_check(rear.ledger.move_entity("denial-1",bridge_id+"-a",bank+Vector2(-30,1)).ok,"engineer withdraws again")
	rear.advance_time(0)
	_check(rear.demolition.inspect(id).state == "Arming","fresh withdrawal restarts full ten-second arming")
	rear.advance_time(10)
	_check(rear.demolition.inspect(id).state == "Armed","ten second arming delay")
	_check(rear.demolition.set_mode(id,"Remote","denial-0").ok,"real squad engineer assumes remote mode")
	_check(not rear.demolition.remote_trigger(id).ok,"remote trigger cannot invent an assigned hostile vehicle")
	_check(rear.ledger.add_carrier("observed-hostile-carrier",bridge_id+"-b","army-red","army-red","T01").ok,"hostile vehicle has a physical identity")
	_check(rear.ledger.move_entity("observed-hostile-carrier",bridge_id+"-b",Vector2(140.5,20.5)).ok,"hostile carrier occupies visible far approach")
	_check(rear.demolition.assign_remote_vehicle(id,"observed-hostile-carrier").ok,"operator assigns only actually observed hostile vehicle")
	_check(not rear.demolition.remote_trigger(id).ok and rear.bridges.inspect(bridge_id).health == 7000,"assigned observed vehicle off span cannot remotely detonate")
	_check(rear.ledger.add_person("friendly-on-span",bridge_id+"-a",rear.PLAYER,Records.Assignment.AVAILABLE,true).ok,"friendly physically exists")
	_check(rear.ledger.move_entity("friendly-on-span",bridge_id+"-a",Vector2(115.5,20.5)).ok,"friendly occupies affected span")
	_check(rear.ledger.move_entity("observed-hostile-carrier",bridge_id+"-b",Vector2(116.5,20.5)).ok,"assigned hostile vehicle physically reaches span")
	_check(not rear.demolition.remote_trigger(id).ok and rear.demolition.inspect(id).state == "Waiting" and rear.bridges.inspect(bridge_id).health == 7000,"observed span vehicle cannot override friendly bridge clearance")
	_check(rear.ledger.move_entity("observed-hostile-carrier",bridge_id+"-b",Vector2(140.5,20.5)).ok,"hostile leaves before fuse test")
	_check(rear.demolition.set_mode(id,"Fuse").ok,"fuse chosen")
	_check(not rear.demolition.start_fuse(id).ok and rear.bridges.inspect(bridge_id).health == 7000,"A36 friendly on bridge withholds detonation")
	_check(rear.ledger.move_entity("friendly-on-span",bridge_id+"-a",bank+Vector2(-30,2)).ok,"friendly physically clears bridge and blast")
	_check(rear.demolition.start_fuse(id).ok,"valid clearance starts five-second fuse")
	rear.advance_time(4.9)
	_check(rear.bridges.inspect(bridge_id).health == 7000,"fuse cannot detonate early")
	_check(rear.ledger.move_entity("friendly-on-span",bridge_id+"-a",Vector2(115.5,20.5)).ok,"friendly re-enters during running fuse")
	rear.advance_time(0.1)
	_check(rear.demolition.inspect(id).state == "Waiting" and rear.bridges.inspect(bridge_id).health == 7000,"fuse rechecks clearance and withholds late friendly casualty")
	_check(rear.ledger.move_entity("friendly-on-span",bridge_id+"-a",bank+Vector2(-30,2)).ok,"friendly clears after withheld fuse")
	_check(rear.demolition.start_fuse(id).ok,"whole new fuse begins after renewed clearance")
	rear.advance_time(5)
	_check(rear.demolition.inspect(id).state == "Detonated" and rear.bridges.inspect(bridge_id).state == "Destroyed" and rear.bridges.inspect(bridge_id).health == 0,"A36 fourteen charges inflict 7000 structural damage")
	_check(not rear.bridges.request_crossing(bridge_id,"friendly-on-span",0).ok,"destroyed deck no longer traversable")
	_structure_remote(base,squad_id)
	_world_remote(base,squad_id)
	_check(base.audit().is_empty(),"A36 shared ledger and project audit: "+str(base.audit()))

func _structure_remote(base: RefCounted, squad_id: String) -> void:
	var rear: RefCounted = base.rear
	var center := Vector2(220.5,100.5)
	var ordered: Dictionary = rear.field_structures.order("S02",center)
	_check(ordered.ok,"actual sandbag structure target")
	if not ordered.ok: return
	var site_id: String = ordered.id
	for i in 2:
		var builder := "builder-%d" % i
		_check(rear.ledger.move_entity(builder,site_id,center).ok,"builder reaches actual structure")
		_check(rear.field_structures.assign_engineer(site_id,builder).ok,"structure builder committed")
	_check(rear.ledger.add_carrier("structure-carrier","hq-stock",rear.PLAYER,rear.PLAYER).ok,"structure freight carrier")
	_check(rear.ledger.add_stock("structure-m11","M11",25,1.0,"structure-carrier",rear.PLAYER).ok,"structure M11")
	_check(rear.ledger.move_entity("structure-carrier","hq-stock",center).ok,"M11 carrier reaches structure")
	_check(rear.field_structures.deliver_material(site_id,"structure-m11",25).ok,"S02 material physically staged")
	rear.advance_time(30)
	_check(rear.field_structures.inspect(site_id).state == "Complete" and rear.field_structures.inspect(site_id).health == 500,"S02 completed with actual builders")
	for i in 2: _check(rear.ledger.move_entity("denial-%d" % i,site_id,center).ok,"demolition squad reaches structure")
	var engineers: Array[String] = ["denial-0","denial-1"]
	var project: Dictionary = rear.demolition.order("Structure",site_id,squad_id,engineers)
	_check(project.ok and project.m06 == 1 and project.work == 12,"structure D04 health-based quantity and work")
	if not project.ok: return
	var id: String = project.id
	_check(rear.ledger.add_stock("structure-m06","M06",1,1.0,"structure-carrier",rear.PLAYER).ok,"physical structure M06")
	_check(rear.demolition.deliver(id,"structure-m06",1).ok,"structure explosive delivered")
	rear.advance_time(6)
	_check(rear.demolition.inspect(id).state == "Placed" and rear.demolition.inspect(id).m06_consumed == 1,"structure charge placed and consumed once")
	for i in 2:
		_check(rear.ledger.move_entity("builder-%d" % i,site_id,center+Vector2(30,4+i)).ok,"builders leave structure blast")
		_check(rear.ledger.move_entity("denial-%d" % i,site_id,center+Vector2(30,i)).ok,"demolition engineers withdraw")
	_check(rear.ledger.move_entity("structure-carrier","hq-stock",center+Vector2(30,-5)).ok,"structure freight clears blast")
	rear.advance_time(10)
	_check(rear.demolition.inspect(id).state == "Armed","structure charge arms after withdrawal and ten seconds")
	_check(rear.demolition.set_mode(id,"Remote","denial-0").ok,"qualified E08 operator assumes remote charge")
	_check(not rear.demolition.remote_trigger(id,"",true).ok,"unauthorized explicit remote denial withheld")
	var plan := {"retreat":"withdraw through west route","forward_supply":"halt carriers","wounded_evacuation":"clear patients","alternate_or_restore":"restore sandbags after denial"}
	_check(rear.demolition.authorize(id,rear.military.commander(),plan).ok,"Commander authorizes structure denial consequences")
	_check(rear.ledger.move_entity("denial-0",site_id,center+Vector2(350,0)).ok,"remote operator physically leaves range")
	_check(not rear.demolition.remote_trigger(id,"",true).ok and rear.demolition.inspect(id).state == "Waiting" and rear.field_structures.inspect(site_id).health == 500,"lost operator leaves physical charge inertly waiting")
	_check(rear.ledger.move_entity("denial-0",site_id,center+Vector2(30,0)).ok,"former operator returns within range")
	_check(not rear.demolition.remote_trigger(id,"",true).ok,"old controller cannot silently resume without a new physical takeover")
	_check(rear.demolition.set_mode(id,"Remote","denial-1").ok,"second actual qualified operator assumes charge")
	_check(rear.ledger.add_person("hostile-near-structure",site_id,"army-red",Records.Assignment.AVAILABLE,true).ok,"actual hostile in blast")
	_check(rear.ledger.move_entity("hostile-near-structure",site_id,center+Vector2(4,0)).ok,"hostile physically within eight metres")
	_check(rear.ledger.reserve_rear_hull("blast-hull-claim","army-red","g21-test").ok,"actual hostile vehicle admission")
	_check(rear.ledger.create_heavy_output("blast-hull-claim","g21-test","blast-t01","T01","hq-berth","army-red",Specs.TYPES.T01).ok,"real canonical hostile T01 hull")
	_check(rear.ledger.move_entity("blast-t01",site_id,center+Vector2(6,0)).ok,"hostile T01 enters eight-metre blast")
	_check(rear.ledger.add_person("blast-passenger","blast-t01","army-red",Records.Assignment.PASSENGER,true).ok,"actual vehicle passenger sheltered by hull")
	_check(rear.ledger.reserve_rear_hull("wreck-claim","army-red","g21-test").ok,"second actual hostile hull admission")
	_check(rear.ledger.create_heavy_output("wreck-claim","g21-test","wreck-t01","T01","hq-berth","army-red",Specs.TYPES.T01).ok,"second real hostile T01 hull")
	_check(rear.ledger.move_entity("wreck-t01",site_id,center+Vector2(7,1)).ok,"damaged hostile T01 within blast")
	_check(rear.ledger.apply_heavy_damage("wreck-t01",350,60,"fixture prior battle damage").ok,"actual hull has 100 health before blast")
	_check(rear.ledger.add_person("wreck-passenger","wreck-t01","army-red",Records.Assignment.PASSENGER,true).ok,"actual occupant in damaged hull")
	var fired: Dictionary = rear.demolition.remote_trigger(id,"",true)
	_check(fired.ok and rear.field_structures.inspect(site_id).state == "Destroyed" and rear.field_structures.inspect(site_id).health == 0,"remote D04 destroys actual 500-health S02")
	_check(rear.ledger.inspect_entity("hostile-near-structure").assignment == "Wounded","blast inflicts 200 actual infantry injury")
	_check(rear.ledger.inspect_entity("blast-t01").health == 250 and rear.ledger.inspect_entity("blast-passenger").health == 90,"penetrating blast deals 200 hull and only 10 protected occupant injury")
	_check(rear.ledger.inspect_entity("wreck-t01").state == "Destroyed by blast" and rear.ledger.inspect_entity("wreck-passenger").holder_id == site_id and rear.ledger.inspect_entity("wreck-passenger").health == 40,"destroyed hull ejects occupant to passable ground with one 60 injury")

func _world_remote(base: RefCounted, squad_id: String) -> void:
	var rear: RefCounted = base.rear
	var bank := Vector2(400.5,20.5)
	rear.combat.world.paint(Rect2i(401,10,10,20),"TR11")
	var deck: Array[Vector2i] = []
	for x in range(401,411):
		for y in range(19,22): deck.append(Vector2i(x,y))
	_check(rear.combat.world.set_bridge_surface("world-river-01",deck,[],"B01",1000.0,4.0,2.0,[0],true).ok,"scenario supplies existing unowned bridge surface")
	var registered: Dictionary = rear.bridges.register_existing_bridge("world-river-01","B01",bank,Vector2(411.5,20.5))
	_check(registered.ok,"existing authored crossing registration: "+registered.get("message",""))
	if not registered.ok: return
	_check(rear.bridges.inspect(registered.id).source == "World" and rear.bridges.inspect(registered.id).health == 1000 and rear.bridges.inspect(registered.id).m11_consumed == 0,"unowned world B01 has real health without invented construction stock")
	for i in 2: _check(rear.ledger.move_entity("denial-%d" % i,registered.id+"-a",bank).ok,"squad reaches unowned bridge endpoint")
	var engineers: Array[String] = ["denial-0","denial-1"]
	var ordered: Dictionary = rear.demolition.order("Bridge",registered.id,squad_id,engineers)
	_check(ordered.ok and ordered.m06 == 2,"unowned B01 gets two health-based M06")
	if not ordered.ok: return
	var id: String = ordered.id
	_check(rear.ledger.add_carrier("world-charge-carrier","hq-stock",rear.PLAYER,rear.PLAYER).ok,"real world-bridge explosive carrier")
	_check(rear.ledger.add_stock("world-charge-m06","M06",2,1.0,"world-charge-carrier",rear.PLAYER).ok,"real two M06")
	_check(rear.ledger.move_entity("world-charge-carrier","hq-stock",bank).ok,"charges physically reach world bridge")
	_check(rear.demolition.deliver(id,"world-charge-m06",2).ok,"world-bridge charges staged")
	rear.advance_time(7)
	_check(rear.demolition.inspect(id).state == "Placed","world bridge charge physically placed")
	for i in 2: _check(rear.ledger.move_entity("denial-%d" % i,registered.id+"-a",bank+Vector2(-30,i)).ok,"engineers withdraw from authored span")
	_check(rear.ledger.move_entity("world-charge-carrier","hq-stock",bank+Vector2(-30,-4)).ok,"freight clears authored span")
	rear.advance_time(10)
	_check(rear.demolition.inspect(id).state == "Armed","world-bridge charge arms after full delay")
	var plan := {"retreat":"withdraw west","forward_supply":"stop convoy","wounded_evacuation":"clear patients","alternate_or_restore":"rebuild B01 from full physical M11"}
	_check(rear.demolition.authorize(id,rear.military.commander(),plan).ok,"Commander authorizes unowned bridge denial")
	_check(rear.demolition.set_mode(id,"Remote","denial-1").ok,"living engineer controls one remote D04")
	_check(rear.demolition.damage_device(id,1).ok and rear.demolition.inspect(id).health == 19,"placed D04 device has physical twenty-health body")
	_check(rear.ledger.add_carrier("world-hostile-hull",registered.id+"-b","army-red","army-red","T01").ok,"hostile carrier at authored bridge")
	_check(rear.ledger.move_entity("world-hostile-hull",registered.id+"-b",Vector2(420.5,20.5)).ok,"hostile vehicle first observed off span")
	_check(rear.demolition.assign_remote_vehicle(id,"world-hostile-hull").ok,"remote operator assigns observed hostile vehicle")
	_check(rear.ledger.move_entity("world-hostile-hull",registered.id+"-b",Vector2(406.5,20.5)).ok,"same assigned vehicle enters actual span")
	_check(rear.ledger.add_person("world-hostile-person",registered.id+"-b","army-red",Records.Assignment.AVAILABLE,true).ok,"hostile person exists on span")
	_check(rear.ledger.move_entity("world-hostile-person",registered.id+"-b",Vector2(407.5,20.5)).ok,"hostile infantry physically on water deck")
	var result: Dictionary = rear.demolition.remote_trigger(id)
	_check(result.ok and rear.bridges.inspect(registered.id).state == "Destroyed" and rear.bridges.inspect(registered.id).health == 0,"observed hostile vehicle triggers authorized remote destruction of unowned span")
	_check(rear.ledger.inspect_entity("world-hostile-hull").state == "Destroyed by bridge collapse" and rear.ledger.inspect_entity("world-hostile-person").assignment == "Dead","all physical span occupants suffer collapse casualties")
	_check(not rear.bridges.rebuild(registered.id).ok,"unowned destroyed world bridge needs a real restoring army")
	_check(rear.bridges.rebuild(registered.id,0,rear.PLAYER).ok and rear.bridges.inspect(registered.id).state != "Complete" and rear.bridges.inspect(registered.id).m11_consumed == 0,"restoration opens original full M11/work obligation without granting a deck")
