extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Lane = preload("res://game/terrain/lane_simulation.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_a31_bunker_delivery()
	_a32_service_gates()
	_a14_destroyed_causeway()
	_repairs_cancellation_and_clearance()
	_roads_and_heavy_upgrade()
	_person_handoff()
	print("G19 field regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(detail)

func _engineer(rear: RefCounted, id: String, site_id: String) -> void:
	_check(rear.ledger.add_person(id,site_id,rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02").ok,"actual P02 at "+site_id)
	_check(rear.ledger.add_stock(id+"-e08","E08",1,5.0,id,rear.PLAYER).ok,"actual issued E08 at "+site_id)

func _a31_bunker_delivery() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var field: RefCounted = rear.field_structures
	var ordered: Dictionary = field.order("S03",Vector2(80,20))
	_check(ordered.ok,"A31 actual bunker site ordered")
	var site_id: String = ordered.id
	_engineer(rear,"a31-engineer",site_id)
	_check(field.assign_engineer(site_id,"a31-engineer").ok,"A31 real engineer assigned")
	_check(rear.ledger.add_carrier("a31-truck","hq-stock",rear.PLAYER,rear.PLAYER).ok,"A31 carrier at HQ")
	_check(rear.ledger.add_stock("a31-m11","M11",300,1.0,"a31-truck",rear.PLAYER).ok,"A31 actual M11 remains at HQ")
	rear.advance_time(100)
	_check(field.inspect(site_id).progress == 0.0 and field.inspect(site_id).m11_missing == 300,"A31 HQ materials cannot earn work")
	_check(not field.inspect(site_id).service.ok and field.inspect(site_id).occupants.is_empty(),"A31 empty unfinished bunker has no capability or occupants")
	_check(not field.deliver_material(site_id,"a31-m11",300).ok,"A31 remote truck cannot deposit stock")
	_check(rear.ledger.move_entity("a31-truck",site_id,Vector2(80,20)).ok,"A31 controlled arrival fixture places the same real carrier at the site; live trip remains G26a")
	_check(field.deliver_material(site_id,"a31-m11",300).ok,"A31 same M11 physically staged from arrived carrier")
	_check(field.inspect(site_id).m11_consumed == 300,"A31 delivered full batch consumed once at start")
	rear.advance_time(200)
	_check(field.inspect(site_id).progress == 200.0 and field.inspect(site_id).state == "Building","A31 one P02 earns 200 of 400 work")
	_check(rear.ledger.move_entity("a31-engineer","hq-stock",rear.ledger.inspect_entity("hq-stock").position).ok,"A31 real engineer leaves site")
	rear.advance_time(30)
	_check(field.inspect(site_id).progress == 200.0 and field.inspect(site_id).state == "Paused","A31 interruption preserves consumed M11 and partial work")
	_check(rear.ledger.move_entity("a31-engineer",site_id,Vector2(80,20)).ok,"A31 same engineer returns")
	rear.advance_time(200)
	_check(field.inspect(site_id).state == "Complete" and field.inspect(site_id).health == 3000,"A31 bunker completes at exact remaining work")
	_check(field.inspect(site_id).occupants.is_empty() and not field.bunker_port_allows(site_id,"a31-engineer",Vector2(90,20)),"A31 completion creates neither occupant nor gun")
	_check(field.enter(site_id,"a31-engineer").ok and field.bunker_port_allows(site_id,"a31-engineer",Vector2(90,20)),"A31 actual occupant enters east-facing 120-degree port")
	_check(not field.bunker_port_allows(site_id,"a31-engineer",Vector2(70,20)),"A31 rear angle cannot fire through front ports")
	_check(rear.combat.world.cover(Vector2(80,20),Vector2(90,20)).hit == 0.25 and rear.combat.world.cover(Vector2(80,20),Vector2(70,20)).hit == 1.0,"A31 completed bunker shields its actual construction-facing front, not the rear")
	_check(base.audit().is_empty(),"A31 material and personnel audit reconciles: "+str(base.audit()))

func _a32_service_gates() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var field: RefCounted = rear.field_structures
	var codes := ["S07","S08","S09","S10"]
	var centers := [Vector2(120,20),Vector2(170,20),Vector2(220,20),Vector2(270,20)]
	var ids: Array[String] = []
	for i in codes.size():
		var row: Dictionary = field.order(codes[i],centers[i])
		_check(row.ok,"A32 actual "+codes[i]+" site ordered")
		var id: String = row.id
		ids.append(id)
		_engineer(rear,"a32-builder-%d" % i,id)
		_check(rear.ledger.add_stock("a32-build-m11-%d" % i,"M11",int(field.projects[id].m11_required),1.0,id,rear.PLAYER).ok,"A32 full actual construction M11 at "+id)
		_check(field.assign_engineer(id,"a32-builder-%d" % i).ok,"A32 construction engineer assigned")
	rear.advance_time(480)
	for id in ids:
		_check(field.inspect(id).state == "Complete","A32 completed physical "+id)
		_check(not field.service_status(id).ok,"A32 empty service blocked at "+id)
	for suffix in ["one","two"]:
		var id: String = "a32-logistics-"+suffix
		_check(rear.ledger.add_person(id,ids[0],rear.PLAYER,Records.Assignment.AVAILABLE,true).ok,"A32 real logistics staff "+id)
		_check(field.assign_staff(ids[0],id).ok,"A32 depot staff assigned")
	_check(not field.service_status(ids[0]).ok,"A32 depot with staff but no delivered goods is inert")
	_check(rear.ledger.add_stock("a32-depot-cargo","E02",20,0.02,ids[0],rear.PLAYER).ok,"A32 actual depot goods arrive")
	_check(field.service_status(ids[0]).ok,"A32 depot becomes stocked and staffed")
	_check(rear.ledger.add_carrier("a32-depot-truck",ids[0],rear.PLAYER,rear.PLAYER).ok,"A32 actual truck reaches depot")
	_check(field.dock_vehicle(ids[0],"a32-depot-truck").ok,"A32 truck occupies one of two actual berths")
	_check(field.withdraw_stock(ids[0],"a32-depot-cargo",10,"a32-depot-truck").ok,"A32 staffed depot loads ten existing physical goods into same truck")
	_check(rear.ledger.available_stock_at(ids[0],"E02") == 10 and rear.ledger.inspect_entity("a32-depot-truck").contents_mass_kg > 0.0,"A32 depot and truck account for split stock without creation")
	_check(rear.ledger.add_person("a32-medic",ids[1],rear.PLAYER,Records.Assignment.AVAILABLE,true,"P03").ok,"A32 actual medic")
	_check(field.assign_staff(ids[1],"a32-medic").ok,"A32 medic assigned")
	_check(not field.service_status(ids[1]).ok,"A32 aid post without kit and pack remains inert")
	_check(rear.ledger.add_stock("a32-e11","E11",1,5.0,"a32-medic",rear.PLAYER).ok,"A32 actual carried medic kit")
	_check(rear.ledger.add_stock("a32-e12","E12",1,1.0,ids[1],rear.PLAYER).ok,"A32 actual local medicine")
	_check(field.service_status(ids[1]).ok,"A32 aid post becomes ready only with actual medic, kit and medicine")
	_check(rear.ledger.add_person("a32-patient",ids[1],rear.PLAYER,Records.Assignment.AVAILABLE,true).ok,"A32 actual patient at aid post")
	_check(rear.combat.injure("a32-patient",100).ok,"A32 patient actually incapacitated")
	_check(field.admit_patient(ids[1],"a32-patient").ok,"A32 real wounded patient occupies one of eight places")
	var carried_pack: Dictionary = rear.ledger.transfer_stock("a32-e12",1,"a32-medic")
	_check(carried_pack.ok,"A32 same E12 physically handed to local medic")
	_check(field.start_aid_care(ids[1],"a32-patient",carried_pack.entity_id).ok,"A32 aid post delegates to actual G16 timed care and consumes one carried pack")
	rear.advance_time(10)
	_check(rear.ledger.inspect_entity("a32-patient").assignment == "Recovery" and rear.ledger.inspect_entity("a32-patient").health == 35,"A32 ten seconds of actual care stabilize same patient, no free healing")
	_check(rear.ledger.add_person("a32-repairer",ids[2],rear.PLAYER,Records.Assignment.AVAILABLE,true,"P02").ok,"A32 real repair engineer")
	_check(field.assign_staff(ids[2],"a32-repairer").ok,"A32 repairer assigned")
	_check(not field.service_status(ids[2]).ok,"A32 repair point alone grants no repair")
	_check(rear.ledger.add_stock("a32-repair-e08","E08",1,5.0,"a32-repairer",rear.PLAYER).ok,"A32 actual repair kit")
	_check(rear.ledger.add_stock("a32-repair-m11","M11",10,1.0,ids[2],rear.PLAYER).ok,"A32 actual repair material")
	_check(field.service_status(ids[2]).ok,"A32 repair point becomes supplied and staffed")
	_check(rear.ledger.reserve_rear_hull("a32-admission",rear.PLAYER,"a32-fixture").ok,"A32 actual damaged T02 admission")
	_check(rear.ledger.create_heavy_output("a32-admission","a32-fixture","a32-t02","T02","hq-berth",rear.PLAYER,Specs.TYPES.T02).ok,"A32 actual T02 created")
	_check(rear.ledger.complete_hq_hull_receipt("a32-t02").ok,"A32 T02 enters military fleet")
	_check(rear.ledger.move_entity("a32-t02",ids[2],centers[2]).ok,"A32 same T02 physically arrives at repair bay")
	rear.ledger._entities["a32-t02"].health = 250 # Declared damage fixture; repair must use the public timed operation.
	_check(field.request_repair("a32-t02",["a32-repairer"],ids[2]).ok,"A32 one repair consumes actual ten M11 at S09")
	_check(rear.ledger.inspect_entity("a32-t02").health == 250 and rear.ledger.available_stock_at(ids[2],"M11") == 0,"A32 repair request grants no immediate health and consumes local material once")
	rear.advance_time(40)
	_check(rear.ledger.inspect_entity("a32-t02").health == 350,"A32 same actual T02 gains only 100 health after 40 P02 work")
	_check(rear.ledger.add_person("a32-observer",ids[3],rear.PLAYER,Records.Assignment.AVAILABLE,true).ok,"A32 real trained observer")
	_check(field.assign_staff(ids[3],"a32-observer").ok,"A32 observer assigned")
	_check(not field.service_status(ids[3]).ok,"A32 lookout without binoculars cannot see")
	_check(rear.ledger.add_stock("a32-e20","E20",1,1.0,"a32-observer",rear.PLAYER).ok,"A32 actual binoculars")
	_check(field.service_status(ids[3]).ok and field.lookout_observe(ids[3],Vector2(700,20)).visible,"A32 staffed E20 lookout sees within 500m")
	_check(base.audit().is_empty(),"A32 service identities and materials audit reconcile: "+str(base.audit()))

func _a14_destroyed_causeway() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var field: RefCounted = rear.field_structures
	var world: RefCounted = rear.combat.world
	world.paint(Rect2i(300,17,20,6),"TR09")
	var ordered: Dictionary = field.order("S12",Vector2(310,20))
	_check(ordered.ok,"A14 actual shallow-swamp causeway ordered")
	var id: String = ordered.id
	_engineer(rear,"a14-engineer",id)
	_check(field.assign_engineer(id,"a14-engineer").ok,"A14 real engineer assigned")
	_check(rear.ledger.add_stock("a14-m11","M11",100,1.0,id,rear.PLAYER).ok,"A14 real local construction M11")
	rear.advance_time(160)
	_check(field.inspect(id).state == "Complete" and world.support(Vector2i(310,20),1).ok,"A14 complete causeway supports wheel")
	_check(rear.ledger.reserve_rear_hull("a14-admission",rear.PLAYER,"a14-fixture").ok,"A14 actual T02 admission")
	_check(rear.ledger.create_heavy_output("a14-admission","a14-fixture","a14-t02","T02","hq-berth",rear.PLAYER,Specs.TYPES.T02).ok,"A14 actual empty T02 hull")
	_check(rear.ledger.complete_hq_hull_receipt("a14-t02").ok,"A14 same T02 joins military fleet")
	var lane := Lane.new()
	lane.world = world
	lane.initialize("T02",Vector2(294,20))
	lane.entity.gross_mass_kg = 3200.0
	lane.destination = Vector2(326,20)
	_check(lane.start().ok,"A14 same wheeled body starts legal crossing")
	lane.advance(2)
	_check(lane.entity.position.x > 300.0 and lane.entity.position.x < 320.0,"A14 wheel actually reaches causeway")
	_check(rear.ledger.move_entity("a14-t02",id,lane.entity.position).ok,"A14 actual ledger hull occupies crossed surface")
	_check(field.assess_vehicle("a14-t02").ok,"A14 actual T02 has legal terrain support while causeway exists")
	_check(field.damage(id,1200).ok and not world.support(Vector2i(310,20),1).ok,"A14 destruction removes support without hull injury")
	_check(field.assess_vehicle("a14-t02").status == "Terrain Stranded" and rear.ledger.inspect_entity("a14-t02").health == 400,"A14 actual same T02 is stranded at full health")
	lane.advance(0.1)
	_check(lane.state == "Blocked" and lane.reason.contains("TR09"),"A14 wheel is Terrain Stranded at actual position")
	var stranded_x: float = lane.entity.position.x
	_check(field.rebuild(id).ok,"A14 full physical rebuild requested")
	_check(field.assign_engineer(id,"a14-engineer").ok,"A14 engineer recommitted")
	_check(rear.ledger.add_stock("a14-rebuild-m11","M11",100,1.0,id,rear.PLAYER).ok,"A14 new M11 batch physically staged")
	rear.advance_time(170)
	_check(lane.entity.position.x == stranded_x and field.inspect(id).state == "Complete","A14 rebuild observes ten-second damage pause and restores road without teleporting body: "+str(field.inspect(id).state))
	_check(field.assess_vehicle("a14-t02").ok and rear.ledger.inspect_entity("a14-t02").position.x == stranded_x,"A14 support restoration leaves actual hull in place")
	_check(lane.start().ok,"A14 same stranded wheel may legally resume on rebuilt causeway")
	lane.advance(20)
	_check(lane.state == "Arrived","A14 same body finishes legal journey after support restoration")
	_check(base.audit().is_empty(),"A14 causeway materials and identities audit reconcile: "+str(base.audit()))

func _repairs_cancellation_and_clearance() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var field: RefCounted = rear.field_structures
	var sand: String = field.order("S02",Vector2(400,20)).id
	_engineer(rear,"repair-engineer",sand)
	_check(rear.ledger.add_stock("sand-build","M11",25,1.0,sand,rear.PLAYER).ok,"real sandbag M11")
	_check(field.assign_engineer(sand,"repair-engineer").ok,"real sandbag builder")
	rear.advance_time(60)
	_check(field.inspect(sand).health == 500,"sandbags complete with full actual health")
	_check(field.damage(sand,125).ok,"actual sandbags damaged")
	_check(rear.ledger.add_stock("sand-repair","M11",10,1.0,sand,rear.PLAYER).ok,"ten actual repair M11")
	_check(not field.request_repair(sand,["repair-engineer"]).ok,"repair blocked for ten seconds after damage")
	rear.advance_time(10)
	_check(field.request_repair(sand,["repair-engineer"]).ok,"safe P02 repair consumes ten M11 once")
	_check(rear.ledger.available_stock_at(sand,"M11") == 0 and field.inspect(sand).health == 375,"health does not rise on repair request")
	rear.advance_time(40)
	_check(field.inspect(sand).health == 475 and field.repairs.is_empty(),"40 work seconds restore 100 health, capped below maximum")
	_check(rear.ledger.reserve_rear_hull("crush-admission",rear.PLAYER,"crush-fixture").ok,"actual T05 admission for sandbag crush")
	_check(rear.ledger.create_heavy_output("crush-admission","crush-fixture","crush-t05","T05","hq-berth",rear.PLAYER,Specs.TYPES.T05).ok,"actual T05 hull created without free crew")
	_check(rear.ledger.complete_hq_hull_receipt("crush-t05").ok,"same T05 joins military fleet")
	_check(rear.ledger.move_entity("crush-t05",sand,Vector2(400,20)).ok,"same T05 reaches sandbags")
	_check(field.crush_segment(sand,"crush-t05").ok and field.inspect(sand).state == "Complete","actual tank contact starts without an instant clear")
	rear.advance_time(2)
	_check(field.crush_contacts[sand].progress == 2.0 and field.inspect(sand).state == "Complete","tank contact has not cleared sandbags before three real seconds")
	rear.advance_time(1)
	_check(field.inspect(sand).state == "Destroyed","T05 crushes actual sandbags after three real contact seconds")
	_check(rear.ledger.inspect_entity("crush-t05").health == 1200,"sandbag crush does not invent tank hull injury")
	var trench: String = field.order("S01",Vector2(450,20)).id
	_engineer(rear,"cancel-engineer",trench)
	_check(rear.ledger.add_stock("trench-build","M11",100,1.0,trench,rear.PLAYER).ok,"full trench stock at physical site")
	_check(field.assign_engineer(trench,"cancel-engineer").ok,"trench P02 assigned")
	rear.advance_time(50)
	_check(field.inspect(trench).progress == 50.0,"earned partial work before cancellation")
	_check(field.cancel(trench).recovered == 50,"cancellation returns half of consumed M11")
	_check(rear.ledger.available_stock_at("field-salvage-"+trench,"M11") == 50,"recovered M11 exists as one physical pile")
	var untouched: String = field.order("S10",Vector2(480,20)).id
	_check(rear.ledger.add_stock("untouched-m11","M11",60,1.0,untouched,rear.PLAYER).ok,"pre-start staged lookout M11")
	_check(field.cancel(untouched).recovered == 0 and rear.ledger.available_stock_at(untouched,"M11") == 60,"pre-start cancellation retains all staged stock")
	var wire: String = field.order("S04",Vector2(530,20)).id
	_engineer(rear,"wire-engineer",wire)
	_check(rear.ledger.add_stock("wire-build","M11",20,1.0,wire,rear.PLAYER).ok,"wire physical M11")
	_check(field.assign_engineer(wire,"wire-engineer").ok,"wire local P02")
	rear.advance_time(40)
	var world: RefCounted = rear.combat.world
	var wheel := Lane.new()
	wheel.world = world
	wheel.initialize("T02",Vector2(514,20))
	wheel.destination = Vector2(546,20)
	_check(not wheel.start().ok,"completed wire blocks a wheeled footprint")
	var track := Lane.new()
	track.world = world
	track.initialize("T05",Vector2(514,20))
	track.destination = Vector2(546,20)
	_check(track.start().ok,"tracked hull may contact wire at reduced terrain speed")
	_check(field.clear_segment(wire,"wire-engineer").ok,"one actual P02 with E08 begins wire clearance")
	rear.advance_time(19)
	_check(field.inspect(wire).state == "Complete","wire still blocks before full 20 work")
	rear.advance_time(1)
	_check(field.inspect(wire).state == "Destroyed" and wheel.start().ok,"wire cleared after actual work with no free materials")
	var obstacle: String = field.order("S05",Vector2(580,20)).id
	_engineer(rear,"obstacle-engineer",obstacle)
	_check(rear.ledger.add_stock("obstacle-m11","M11",150,1.0,obstacle,rear.PLAYER).ok,"actual S05 construction M11")
	_check(field.assign_engineer(obstacle,"obstacle-engineer").ok,"S05 actual P02")
	rear.advance_time(180)
	var blocked_track := Lane.new()
	blocked_track.world = world
	blocked_track.initialize("T05",Vector2(564,20))
	blocked_track.destination = Vector2(596,20)
	_check(not blocked_track.start().ok,"completed S05 blocks tracked hulls")
	_check(field.clear_segment(obstacle,"obstacle-engineer").ok,"actual P02 starts 120-work S05 dismantling")
	rear.advance_time(120)
	_check(field.inspect(obstacle).state == "Destroyed" and blocked_track.start().ok,"dismantled S05 stops blocking only after full work")
	var cache: String = field.order("S06",Vector2(630,20)).id
	_engineer(rear,"cache-engineer",cache)
	_check(rear.ledger.add_stock("cache-build","M11",100,1.0,cache,rear.PLAYER).ok,"actual cache construction M11")
	_check(field.assign_engineer(cache,"cache-engineer").ok,"cache actual P02")
	rear.advance_time(150)
	_check(not field.service_status(cache).ok,"empty forward cache creates no goods")
	_check(rear.ledger.add_stock("cache-rounds","E02",100,0.02,cache,rear.PLAYER).ok,"same cache gains physical loose rounds")
	_check(field.service_status(cache).ok,"stocked cache works without invented permanent staff")
	_check(rear.ledger.add_carrier("cache-truck",cache,rear.PLAYER,rear.PLAYER).ok,"actual vehicle reaches cache")
	_check(field.withdraw_stock(cache,"cache-rounds",50,"cache-truck").ok,"cache self-service moves only existing local stock to actual carrier")
	_check(rear.ledger.available_stock_at(cache,"E02") == 50,"cache keeps remaining real stock")
	_check(field.order("S06",Vector2(660,20)).ok and not field.order("S06",Vector2(690,20)).ok,"two forward caches per company cap is visible and enforced")
	_check(base.audit().is_empty(),"cancel, repair, clearance identities and M11 reconcile: "+str(base.audit()))

func _roads_and_heavy_upgrade() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var field: RefCounted = rear.field_structures
	var world: RefCounted = rear.combat.world
	var road: String = field.order("S11",Vector2(600,20)).id
	_engineer(rear,"road-engineer",road)
	_check(rear.ledger.add_stock("road-m11","M11",40,1.0,road,rear.PLAYER).ok,"road M11 physically staged")
	_check(field.assign_engineer(road,"road-engineer").ok,"road actual P02")
	_check(world.support(Vector2i(600,20),1).surface == "TR01","unfinished S11 grants no road surface")
	rear.advance_time(80)
	_check(world.support(Vector2i(600,20),1).surface == "TR02" and field.inspect(road).health == 0,"S11 completed overlay has road factor and no health")
	world.paint(Rect2i(640,17,20,6),"TR09")
	_check(not field.order("S11",Vector2(650,20)).ok,"road rejects swamp")
	var causeway: String = field.order("S12",Vector2(650,20)).id
	_engineer(rear,"upgrade-engineer",causeway)
	_check(rear.ledger.add_stock("basic-m11","M11",100,1.0,causeway,rear.PLAYER).ok,"basic causeway M11")
	_check(field.assign_engineer(causeway,"upgrade-engineer").ok,"basic causeway P02")
	rear.advance_time(160)
	var heavy := Lane.new()
	heavy.world = world
	heavy.initialize("T05",Vector2(634,20))
	heavy.entity.gross_mass_kg = 30000.0
	heavy.destination = Vector2(666,20)
	_check(not heavy.start().ok and heavy.reason.contains("load"),"8t basic causeway rejects real 30t class load")
	_check(field.upgrade_causeway(causeway).ok and not heavy.start().ok,"heavy upgrade closes the segment to traffic during work")
	_check(rear.ledger.add_stock("heavy-m11","M11",100,1.0,causeway,rear.PLAYER).ok,"another 100 M11 makes total cost double")
	_check(field.assign_engineer(causeway,"upgrade-engineer").ok,"same engineer assigned for another 160 work")
	rear.advance_time(160)
	_check(field.inspect(causeway).state == "Complete" and field.inspect(causeway).load_kg == 80000.0,"heavy upgrade completes at 80t")
	_check(heavy.start().ok,"same heavy body now has legal upgraded support")
	_check(base.audit().is_empty(),"road and causeway materials reconcile: "+str(base.audit()))

func _person_handoff() -> void:
	var base := Base.new(true)
	var rear: RefCounted = base.rear
	var field: RefCounted = rear.field_structures
	var site: String = field.order("S02",Vector2(760,20)).id
	_engineer(rear,"person-site-engineer",site)
	_check(field.assign_engineer(site,"person-site-engineer").ok,"real engineer assigned to person-delivered sandbags")
	_check(rear.ledger.add_place("field-source","Controlled field supply origin",Vector2(730,20)).ok,"named physical source for carry fixture")
	_check(rear.ledger.add_person("field-hauler","field-source",rear.PLAYER).ok,"same actual field hauler exists")
	_check(rear.ledger.request_assignment("field-hauler",Records.Assignment.REAR_LABOUR,"field-haul").ok,"hauler has exclusive actual labour duty")
	_check(rear.ledger.add_stock("field-hand-m11","M11",25,1.0,"field-source",rear.PLAYER).ok,"actual 25 kg M11 starts at field source")
	var picked: Dictionary = rear.ledger.begin_carry("field-hauler","field-hand-m11",25)
	_check(picked.ok,"one legal 25 kg person carry begins at source")
	_check(not field.deliver_material(site,picked.entity_id,25).ok,"remote carried goods cannot stage construction")
	_check(rear.ledger.move_entity("field-hauler",site,Vector2(760,20)).ok,"controlled arrival fixture moves same carrier and held goods to site")
	var before: float = field.inspect(site).progress
	_check(field.deliver_material(site,picked.entity_id,25).ok,"active carry deposits whole material load through G01 safe handoff")
	_check(field.inspect(site).m11_consumed == 25 and field.inspect(site).progress == before,"all local M11 consumed at work start but handoff earns zero engineer work")
	rear.advance_time(60)
	_check(field.inspect(site).state == "Complete","person-delivered materials enable timed construction")
	_check(base.audit().is_empty(),"person carry, stock split and consumed material audit reconcile: "+str(base.audit()))
