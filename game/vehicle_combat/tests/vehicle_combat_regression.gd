extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
const Records = preload("res://game/identity/identity_records.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_a13_a24_a40()
	_test_a39()
	_test_burst_travel_and_t03()
	_test_blast_and_surface_boundaries()
	_test_moved_target_keeps_impact()
	_test_real_structure_impact()
	_test_real_bridge_impact()
	_test_a30()
	print("G23 vehicle combat regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _hull(base: RefCounted, id: String, type: String, owner: String, place: String = "hq-berth") -> void:
	var ledger: RefCounted = base.rear.ledger
	_expect(ledger.reserve_rear_hull(id+"-admission",owner,id).ok,"actual fleet admission "+id)
	_expect(ledger.create_heavy_output(id+"-admission",id,id,type,place,owner,Specs.TYPES[type]).ok,"same manufactured "+type+" hull")
	if owner == base.rear.PLAYER:
		_expect(ledger.complete_hq_hull_receipt(id).ok,"same hull transferred to military fleet")
		base.rear.dispatch.military_hulls[id] = id

func _crew(base: RefCounted, hull_id: String, station: String) -> void:
	var rear: RefCounted = base.rear
	var id := hull_id+"-"+station.to_lower()
	_expect(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P08","None").ok,"real P08 "+station)
	rear.dispatch.military_people[id] = id
	rear.dispatch.hq_reserve[id] = "Occupied"
	_expect(rear.military.assign_crew(id,hull_id,station).ok,"actual timed "+station+" report")
	rear.advance_time(8)
	_expect(rear.ledger.inspect_entity(hull_id).crew_by_station.has(station),"distinct person occupies "+station)

func _test_a13_a24_a40() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	_hull(base,"g23-tank","T05",rear.PLAYER)
	_hull(base,"g23-target","T04","army-red")
	_expect(rear.ledger.add_place("g23-target-place","Hostile target position",Vector2(1740,91)).ok,"real hostile target place")
	_expect(rear.ledger.move_entity("g23-target","g23-target-place",Vector2(1740,91)).ok,"hostile APC at actual target position")
	_crew(base,"g23-tank","Driver")
	_expect(rear.ledger.inspect_entity("g23-tank").crew_by_station.size() == 1,"A13 single P08 occupies only Driver station")
	_expect(not rear.vehicle_combat.aim("g23-tank","g23-target").ok,"driver cannot aim main gun")
	_crew(base,"g23-tank","Gunner")
	_expect(rear.vehicle_combat.aim("g23-tank","g23-target").ok,"actual gunner aims")
	_expect(rear.vehicle_combat.select_weapon("g23-tank","Main").ok,"gunner begins one-second main selection")
	rear.advance_time(1)
	_expect(not rear.vehicle_combat.inspect_fire("g23-tank","g23-target","Main").ok,"A13 and A40 main fire requires separate loader")
	_expect(rear.ledger.add_stock("g23-coax","E02",6,0.02,"g23-tank",rear.PLAYER).ok,"physical coax rack E02")
	_expect(rear.vehicle_combat.select_weapon("g23-tank","Coax").ok,"gunner switches to compatible coax")
	rear.advance_time(1)
	var coax: Dictionary = rear.vehicle_combat.fire("g23-tank","g23-target","Coax")
	_expect(coax.ok and coax.remaining_local == 5,"A40 gunner fires one actual hull-held E02 without loader")
	_expect(not rear.vehicle_combat.inspect_fire("g23-tank","g23-target","Main").ok,"ample coax rounds never authorize main shell")
	_crew(base,"g23-tank","Loader")
	_expect(rear.vehicle_combat.select_weapon("g23-tank","Main").ok,"gunner switches back to main")
	rear.advance_time(1)
	_expect(not rear.vehicle_combat.inspect_fire("g23-tank","g23-target","Main").ok,"A40 loader cannot create missing E25")
	_expect(rear.ledger.add_stock("g23-hq-shells","E25",2,12.0,"hq-stock",rear.PLAYER).ok,"fresh shells exist as unloaded HQ stock")
	_expect(rear.ledger.add_place("g23-remote","Tank operating two kilometres from HQ",Vector2(3640,91)).ok,"real remote place")
	_expect(rear.ledger.move_entity("g23-tank","g23-remote",Vector2(3640,91)).ok,"same tank reaches remote position")
	_expect(not rear.hq.request_vehicle_ammo("g23-tank","E25",2).ok,"A24 remote tank refuses HQ rack issue")
	_expect(rear.ledger.inspect_entity("g23-tank").ammunition.get("E25",0) == 0,"A24 HQ stock never teleports into remote rack")
	_expect(rear.ledger.move_entity("g23-tank","hq-berth",Vector2(1640,91)).ok,"same tank returns locally for actual shell transfer")
	var issue: Dictionary = rear.hq.request_vehicle_ammo("g23-tank","E25",2)
	_expect(issue.ok,"physical local HQ shell issue starts")
	if issue.ok:
		_expect(rear.ledger.inspect_entity("g23-tank").ammunition.get("E25",0) == 0,"reservation does not fill main rack")
		rear.advance_time(4)
		_expect(rear.ledger.inspect_entity("g23-tank").ammunition.get("E25",0) == 2,"two actual shells transferred to same hull")
	_expect(rear.vehicle_combat.aim("g23-tank","g23-target").ok,"gunner reacquires after tank movement")
	_expect(rear.vehicle_combat.inspect_fire("g23-tank","g23-target","Main").ok,"A13 loaded main gun now needs and has actual gunner, loader and E25")
	var initial: int = rear.ledger.inspect_entity("g23-target").health
	var main: Dictionary = rear.vehicle_combat.fire("g23-tank","g23-target","Main")
	_expect(main.ok and is_equal_approx(float(main.impact_due)-rear.time,1.0/3.0) and rear.ledger.inspect_entity("g23-tank").ammunition.E25 == 1,"W07 consumes one local E25 at release, with 300 m/s travel")
	rear.advance_time(0.2)
	_expect(rear.ledger.inspect_entity("g23-target").health == initial,"cannon cannot injure before impact time")
	rear.advance_time(0.2)
	_expect(rear.vehicle_combat.events.back().phase in ["Impact","Miss"],"cannon impact resolves on shared event clock")
	_expect(rear.vehicle_combat.select_weapon("g23-tank","Coax").ok,"gunner can operate coax while loader prepares main")
	_expect(rear.vehicle_combat.request_reload("g23-tank","Main").ok,"separate loader reloads W07 with one real shell left")
	rear.advance_time(8)
	_expect(rear.vehicle_combat.inspect("g23-tank").loaded.Main == 1,"main shell becomes loaded while coax remains selected")
	_crew(base,"g23-tank","Commander")
	_expect(rear.ledger.inspect_entity("g23-tank").crew_by_station.size() == 4,"A13 full four-station combat crew is distinct")
	_expect(base.audit().is_empty(),"A13/A24/A40 exact person and stock conservation: "+str(base.audit()))

func _test_a39() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	_hull(base,"a39-apc","T04",rear.PLAYER)
	_hull(base,"a39-tank","T05","army-red")
	_expect(rear.ledger.add_place("a39-target-place","Tank target",Vector2(1740,91)).ok,"tank target place")
	_expect(rear.ledger.move_entity("a39-tank","a39-target-place",Vector2(1740,91)).ok,"tank physically at target")
	_expect(rear.vehicle_combat.set_facing("a39-tank",180).ok,"tank front faces incoming attacker")
	_crew(base,"a39-apc","Driver")
	_crew(base,"a39-apc","Gunner")
	_crew(base,"a39-apc","Commander")
	_expect(rear.ledger.add_stock("a39-autocannon","E26",20,0.5,"a39-apc",rear.PLAYER).ok,"actual hull rack E26")
	_expect(rear.vehicle_combat.aim("a39-apc","a39-tank").ok,"autocannon turret aims at front")
	var front: Dictionary = rear.vehicle_combat.inspect_fire("a39-apc","a39-tank","Autocannon")
	_expect(front.ok and front.surface == "Front","actual relative facing selects tank front")
	var original: int = rear.ledger.inspect_entity("a39-tank").health
	for i in 10:
		var shot: Dictionary = rear.vehicle_combat.fire("a39-apc","a39-tank","Autocannon")
		_expect(shot.ok and shot.released,"A39 front autocannon shot releases one real E26")
		rear.advance_time(2)
	_expect(rear.ledger.inspect_entity("a39-tank").health == original,"ten front shots cause exactly zero hull injury")
	_expect(rear.ledger.add_person("a39-rifleman","hq-formation",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"actual dismounted rifleman")
	_expect(rear.ledger.add_weapon("a39-rifle","E01",4.0,"a39-rifleman",rear.PLAYER,"E02",10).ok,"real carried rifle")
	_expect(rear.ledger.add_stock("a39-rifle-rounds","E02",10,0.02,"a39-rifleman",rear.PLAYER).ok,"real personal rounds")
	_expect(rear.ledger.load_rounds("a39-rifle","a39-rifle-rounds",10).ok,"real loaded rifle")
	for i in 10:
		var rifle: Dictionary = rear.vehicle_combat.fire_personal_at_vehicle("a39-rifleman","a39-tank","a39-rifle")
		_expect(rifle.ok and rifle.damage == 0,"A39 rifle cannot become tank armour counter")
		rear.advance_time(2)
	_expect(rear.ledger.inspect_entity("a39-tank").health == original,"rifle rounds cause zero tank hull injury")
	_expect(rear.ledger.add_place("a39-rear-position","Flanking APC position",Vector2(1840,91)).ok,"physical flanking place")
	_expect(rear.ledger.move_entity("a39-apc","a39-rear-position",Vector2(1840,91)).ok,"same APC reaches tank rear")
	_expect(rear.vehicle_combat.aim("a39-apc","a39-tank").ok,"turret traverses to rear target")
	rear.advance_time(3)
	var rear_check: Dictionary = rear.vehicle_combat.inspect_fire("a39-apc","a39-tank","Autocannon")
	_expect(rear_check.ok and rear_check.surface == "Rear","actual geometry selects 40-armour rear")
	for i in 10:
		var shot: Dictionary = rear.vehicle_combat.fire("a39-apc","a39-tank","Autocannon")
		_expect(shot.ok and shot.released,"rear autocannon burst consumes real E26 at release")
		rear.advance_time(2)
	_expect(rear.ledger.inspect_entity("a39-tank").health < original,"A39 rear 45-penetration autocannon damages same tank after travel")
	_expect(base.audit().is_empty(),"A39 rounds and physical hull audit: "+str(base.audit()))

func _test_burst_travel_and_t03() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	_hull(base,"burst-apc","T04",rear.PLAYER)
	_hull(base,"burst-tank","T05","army-red")
	_expect(rear.ledger.add_place("burst-target-place","Hostile front",Vector2(1740,91)).ok,"actual hostile target place")
	_expect(rear.ledger.move_entity("burst-tank","burst-target-place",Vector2(1740,91)).ok,"actual target at 100 metres")
	_expect(rear.vehicle_combat.set_facing("burst-tank",180).ok,"front armour faces APC")
	_crew(base,"burst-apc","Gunner")
	_expect(rear.ledger.add_stock("burst-rounds","E26",4,0.5,"burst-apc",rear.PLAYER).ok,"four local autocannon rounds")
	_expect(rear.vehicle_combat.aim("burst-apc","burst-tank").ok,"turret aims")
	var shot: Dictionary = rear.vehicle_combat.fire("burst-apc","burst-tank","Autocannon")
	_expect(shot.ok and is_equal_approx(float(shot.impact_due)-rear.time,1.0/3.0),"first W06 release has real 300 m/s flight")
	_expect(not rear.vehicle_combat.inspect_fire("burst-apc","burst-tank","Autocannon").ok,"second burst shot blocked before 0.33 seconds")
	rear.advance_time(1.0/3.0)
	_expect(rear.vehicle_combat.fire("burst-apc","burst-tank","Autocannon").ok,"second W06 shot at 0.33 seconds")
	rear.advance_time(1.0/3.0)
	_expect(rear.vehicle_combat.fire("burst-apc","burst-tank","Autocannon").ok,"third W06 shot at 0.67 seconds")
	rear.advance_time(1.32)
	_expect(not rear.vehicle_combat.inspect_fire("burst-apc","burst-tank","Autocannon").ok,"next W06 burst withheld before two-second mark")
	rear.advance_time(0.02)
	_expect(rear.vehicle_combat.fire("burst-apc","burst-tank","Autocannon").ok,"new W06 burst opens at two seconds")
	_expect(rear.ledger.inspect_entity("burst-apc").ammunition.E26 == 0,"all four actual rack rounds consumed once")
	_expect(not rear.vehicle_combat.request_reload("burst-apc","Autocannon").ok,"empty local rack cannot reload from remote stock")
	_hull(base,"t03-live","T03",rear.PLAYER)
	_expect(rear.ledger.add_person("t03-p04","hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"P04","None").ok,"real P04 available for T03 gunner")
	rear.dispatch.military_people["t03-p04"] = "t03-live"
	rear.dispatch.hq_reserve["t03-p04"] = "Occupied"
	_expect(rear.military.assign_crew("t03-p04","t03-live","Gunner").ok,"P04 reports to T03 gunner station")
	rear.advance_time(8)
	_expect(rear.ledger.add_stock("t03-rack","E02",2,0.02,"t03-live",rear.PLAYER).ok,"same T03 carries E02")
	_expect(rear.vehicle_combat.aim("t03-live","burst-tank").ok,"T03 stationary gunner alone can aim")
	var stationary_fire: Dictionary = rear.vehicle_combat.inspect_fire("t03-live","burst-tank","MG")
	var moving: Dictionary = rear.vehicle_combat.inspect_fire("t03-live","burst-tank","MG",true)
	_expect(stationary_fire.ok and not moving.ok,"driverless T03 can defend stationary but cannot fire moving")
	_expect(rear.vehicle_combat.fire("t03-live","burst-tank","MG").ok,"P04 fires actual mounted W02 and local E02")
	_expect(rear.ledger.add_place("t03-red-shooter-place","Hostile rifleman",Vector2(1740,91)).ok,"hostile rifleman place")
	_expect(rear.ledger.add_person("t03-red-shooter","t03-red-shooter-place","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"actual hostile rifleman")
	_expect(rear.ledger.add_weapon("t03-red-rifle","E01",4.0,"t03-red-shooter","army-red","E02",10).ok,"hostile carries E01")
	_expect(rear.ledger.add_stock("t03-red-ammo","E02",1,0.02,"t03-red-shooter","army-red").ok,"hostile holds E02")
	_expect(rear.ledger.load_rounds("t03-red-rifle","t03-red-ammo",1).ok,"hostile loads E02")
	var exposed: Dictionary = rear.vehicle_combat.inspect_personal_vehicle("t03-red-shooter","t03-p04","t03-red-rifle")
	_expect(exposed.ok and exposed.chance < 0.55,"T03 exposed roof gunner is selectable with 0.65 cover multiplier")
	_expect(rear.ledger.add_person("t03-passenger","t03-live",rear.PLAYER,Records.Assignment.PASSENGER,true,"None","None").ok,"real protected passenger")
	_expect(not rear.vehicle_combat.inspect_personal_vehicle("t03-red-shooter","t03-passenger","t03-red-rifle").ok,"seated passenger cannot be selected through hull")
	_expect(base.audit().is_empty(),"T03 gunner, W06 burst and actual ammunition audit: "+str(base.audit()))

func _test_blast_and_surface_boundaries() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	_hull(base,"blast-apc","T04",rear.PLAYER)
	_hull(base,"blast-target","T04","army-red")
	_expect(rear.ledger.add_place("blast-target-place","Hostile APC position",Vector2(1740,91)).ok,"real hostile APC place")
	_expect(rear.ledger.move_entity("blast-target","blast-target-place",Vector2(1740,91)).ok,"hostile APC positioned")
	_expect(rear.ledger.add_person("blast-passenger","blast-target","army-red",Records.Assignment.PASSENGER,true,"None","None").ok,"real seated hostile passenger")
	_crew(base,"blast-apc","Gunner")
	_expect(rear.ledger.add_stock("blast-e26","E26",10,0.5,"blast-apc",rear.PLAYER).ok,"real local autocannon rounds")
	_expect(rear.vehicle_combat.aim("blast-apc","blast-target").ok,"turret aims at occupied hostile hull")
	var struck := false
	for i in 10:
		var release: Dictionary = rear.vehicle_combat.fire("blast-apc","blast-target","Autocannon")
		_expect(release.ok,"one actual E26 fired at occupied hull")
		rear.advance_time(2)
		if rear.ledger.inspect_entity("blast-target").health < 650:
			struck = true
			break
	_expect(struck,"penetrating autocannon shot reaches actual hull after flight")
	_expect(rear.ledger.inspect_entity("blast-target").health == 615,"one direct versus blast result causes 35 hull damage once")
	_expect(rear.ledger.inspect_entity("blast-passenger").health == 90,"protected seated passenger gets one 10-injury penetration consequence, no double blast")
	var ledger: RefCounted = rear.ledger
	_hull(base,"surface-tank","T05","army-red")
	_expect(ledger.apply_vehicle_surface_damage("surface-tank",20,20,"Top","top probe").ok,"real tank top hit assessed")
	_expect(ledger.inspect_entity("surface-tank").health == 1200,"20 penetration cannot defeat 25 top armour")
	_expect(ledger.apply_vehicle_surface_damage("surface-tank",20,25,"Top","top probe").penetrated,"25 penetration reaches top armour boundary")
	_expect(ledger.apply_vehicle_surface_damage("surface-tank",20,44,"Bottom","bottom probe").penetrated == false,"44 penetration fails 45 bottom armour")
	_expect(ledger.apply_vehicle_surface_damage("surface-tank",20,45,"Bottom","bottom probe").penetrated,"45 penetration reaches bottom armour boundary")
	_expect(base.audit().is_empty(),"single-shot occupant injury and top/bottom surface accounting: "+str(base.audit()))

func _test_moved_target_keeps_impact() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	_hull(base,"flight-apc","T04",rear.PLAYER)
	_hull(base,"flight-target","T04","army-red")
	_expect(rear.ledger.add_place("flight-point","Recorded cannon impact point",Vector2(1740,91)).ok,"real impact place")
	_expect(rear.ledger.add_place("flight-escape","Moving target destination",Vector2(1800,91)).ok,"real escape place")
	_expect(rear.ledger.move_entity("flight-target","flight-point",Vector2(1740,91)).ok,"target originally at impact point")
	_expect(rear.ledger.add_person("flight-bystander","flight-point","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"separate actual person at recorded impact")
	_crew(base,"flight-apc","Gunner")
	_expect(rear.ledger.add_stock("flight-e26","E26",1,0.5,"flight-apc",rear.PLAYER).ok,"one actual local round")
	_expect(rear.vehicle_combat.aim("flight-apc","flight-target").ok,"turret aligns at original target")
	var released: Dictionary = rear.vehicle_combat.fire("flight-apc","flight-target","Autocannon")
	_expect(released.ok and rear.vehicle_combat.projectiles.size() == 1 and rear.vehicle_combat.projectiles[0].hit,"seeded cannon round releases toward physical original point")
	_expect(rear.ledger.move_entity("flight-target","flight-escape",Vector2(1800,91)).ok,"intended hull moves before impact")
	rear.advance_time(0.4)
	_expect(rear.ledger.inspect_entity("flight-target").health == 650,"moved hull receives no copied direct hit")
	_expect(rear.ledger.inspect_entity("flight-bystander").health == 70,"released shell still blasts separate actual person at original impact point")
	_expect(rear.vehicle_combat.projectiles.is_empty(),"in-flight shot resolves exactly once")
	_expect(base.audit().is_empty(),"moved target and physical blast audit: "+str(base.audit()))

func _test_real_structure_impact() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var site: Dictionary = rear.field_structures.order("S02",Vector2(2000,500),"army-red")
	_expect(site.ok,"actual hostile S02 project ordered")
	if not site.ok: return
	_expect(rear.ledger.add_person("structure-builder",site.id,"army-red",Records.Assignment.AVAILABLE,true,"P02").ok,"actual hostile engineer at site")
	_expect(rear.ledger.add_stock("structure-kit","E08",1,5.0,"structure-builder","army-red").ok,"actual E08 issued")
	_expect(rear.ledger.add_stock("structure-m11","M11",25,1.0,site.id,"army-red").ok,"exact physical S02 M11")
	_expect(rear.field_structures.assign_engineer(site.id,"structure-builder").ok,"engineer assigned to real project")
	rear.advance_time(60)
	_expect(rear.field_structures.inspect(site.id).state == "Complete","real S02 completes after actual engineer work")
	_hull(base,"structure-apc","T04",rear.PLAYER)
	_crew(base,"structure-apc","Gunner")
	_expect(rear.ledger.add_place("structure-attack-place","APC direct-fire point",Vector2(1900,500)).ok,"real attacking position")
	_expect(rear.ledger.move_entity("structure-apc","structure-attack-place",Vector2(1900,500)).ok,"same APC at 100m attack point")
	_expect(rear.ledger.add_stock("structure-e26","E26",10,0.5,"structure-apc",rear.PLAYER).ok,"actual local E26")
	_expect(not rear.vehicle_combat.aim("structure-apc","hq-stock").ok,"ordinary ledger place is ineligible, without bridge lookup error")
	_expect(rear.vehicle_combat.aim("structure-apc",site.id).ok,"turret aims at actual completed S02")
	var before: int = rear.field_structures.inspect(site.id).health
	var released: Dictionary = rear.vehicle_combat.fire("structure-apc",site.id,"Autocannon")
	_expect(released.ok and rear.ledger.inspect_entity("structure-apc").ammunition.E26 == 9,"real structure-target W06 release consumes one local round: "+str(released))
	if not released.ok: return
	rear.advance_time(0.4)
	_expect(rear.vehicle_combat.projectiles.is_empty(),"actual structure-target projectile resolves on shared clock")
	_expect(rear.field_structures.inspect(site.id).health == before-20,"direct W06 impact changes actual S02 health by 20 once")
	_expect(base.audit().is_empty(),"completed structure impact and E26 accounting: "+str(base.audit()))

func _test_real_bridge_impact() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	rear.combat.world.paint(Rect2i(1001,990,20,20),"TR11")
	var bridge: Dictionary = rear.bridges.order("B01",Vector2(1000.5,1000.5),Vector2(1021.5,1000.5),"army-red")
	_expect(bridge.ok,"actual hostile B01 placed across real water")
	if not bridge.ok: return
	var bank: String = rear.bridges.projects[bridge.id].places[0]
	_expect(rear.ledger.add_stock("bridge-m11","M11",int(bridge.m11),1.0,bank,"army-red").ok,"full physical bridge M11 at bank")
	for i in 2:
		var id := "bridge-red-engineer-%d" % i
		_expect(rear.ledger.add_person(id,bank,"army-red",Records.Assignment.AVAILABLE,true,"P02").ok,"real hostile bridge engineer")
		_expect(rear.ledger.add_stock(id+"-e08","E08",1,5.0,id,"army-red").ok,"actual engineer kit")
		_expect(rear.bridges.assign_engineer(bridge.id,id).ok,"same engineer committed to B01")
	rear.advance_time(float(bridge.work)/2.0)
	_expect(rear.bridges.inspect(bridge.id).state == "Complete","real bridge completed by actual work and M11")
	_hull(base,"bridge-apc","T04",rear.PLAYER)
	_crew(base,"bridge-apc","Gunner")
	_expect(rear.ledger.add_place("bridge-attack-place","APC bank firing point",Vector2(1080,1000.5)).ok,"actual firing place")
	_expect(rear.ledger.move_entity("bridge-apc","bridge-attack-place",Vector2(1080,1000.5)).ok,"same APC at supported bank")
	_expect(rear.ledger.add_stock("bridge-e26","E26",4,0.5,"bridge-apc",rear.PLAYER).ok,"actual hull ammunition")
	_expect(rear.vehicle_combat.aim("bridge-apc",bridge.id).ok,"turret aims at actual completed bridge")
	rear.advance_time(3)
	var before: int = rear.bridges.inspect(bridge.id).health
	var shot: Dictionary = rear.vehicle_combat.fire("bridge-apc",bridge.id,"Autocannon")
	_expect(shot.ok,"autocannon can release at actual hostile bridge: "+str(shot))
	if not shot.ok: return
	_expect(rear.ledger.inspect_entity("bridge-apc").ammunition.E26 == 3,"one actual round consumed at bridge shot release")
	rear.advance_time(0.3)
	_expect(rear.bridges.inspect(bridge.id).health == before-20,"actual bridge service receives one W06 structure injury at impact")
	_expect(base.audit().is_empty(),"bridge impact and physical ammunition audit: "+str(base.audit()))

func _test_a30() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var roster: Array[String] = []
	for i in 4:
		var id := "a30-member-%d" % i
		_expect(rear.ledger.add_person(id,"hq-reserve",rear.PLAYER,Records.Assignment.HQ_RESERVE,true,"None","None").ok,"actual squad member")
		rear.dispatch.military_people[id] = id
		rear.dispatch.hq_reserve[id] = "Occupied"
		_expect(rear.ledger.add_weapon(id+"-rifle","E01",4.0,id,rear.PLAYER,"E02",10).ok,"carried rifle")
		_expect(rear.ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"carried rounds")
		_expect(rear.ledger.load_rounds(id+"-rifle",id+"-rounds",1).ok,"loaded rifle round")
		roster.append(id)
	var squad: Dictionary = rear.military.form_squad("Rifle",roster)
	_expect(squad.ok,"real four-person rifle squad forms: "+str(squad))
	rear.advance_time(8)
	_hull(base,"a30-apc","T04",rear.PLAYER)
	_crew(base,"a30-apc","Driver")
	_crew(base,"a30-apc","Gunner")
	_crew(base,"a30-apc","Commander")
	_expect(rear.military.board_squad(squad.id,"a30-apc").ok,"one real squad boards T04's passenger seats")
	_expect(rear.ledger.add_place("a30-objective","Field objective at stopped APC",Vector2(1740,91)).ok,"physical field objective")
	_expect(rear.ledger.move_entity("a30-apc","a30-objective",Vector2(1740,91)).ok,"same occupied APC reaches field objective fixture")
	_expect(rear.objectives.register("a30-objective","Resource").ok,"objective registered")
	rear.advance_time(15)
	_expect(rear.objectives.inspect("a30-objective").control == 0.0,"A30 seated APC passengers never capture")
	_expect(rear.military.exit_squad(squad.id,"a30-objective").ok,"same four members physically dismount at field objective")
	rear.advance_time(15)
	_expect(rear.objectives.inspect("a30-objective").owner == rear.PLAYER,"A30 four actual armed dismounted people capture in fifteen seconds")
	_expect(base.audit().is_empty(),"A30 person, vehicle and stock audit: "+str(base.audit()))
