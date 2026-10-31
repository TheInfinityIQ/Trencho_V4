extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const World = preload("res://game/terrain/terrain_world.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Orders = preload("res://game/orders/order_service.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")

class PriorOrders extends Orders:
	# Complete prior sampling algorithm from 4228e4c; no candidate-list reuse.
	func _sample_squad(squad_id: String, sampled_entities: Array = []) -> void:
		var squad: Dictionary = _rear().military.squads.get(squad_id,{})
		if squad.is_empty() or squad.state != "Active":
			unwatch(squad_id)
			return
		var seen := {}
		var ledger: RefCounted = _rear().ledger
		var entities: Array = ledger.snapshot(false).entities if sampled_entities.is_empty() else sampled_entities
		var world: RefCounted = _rear().combat.world
		var maximum: float = float(world.Catalog.ROLES.ordinary.range)+float(world.EPS)
		for person_id in _rear().military._active_roster_members(squad):
			var observer: Dictionary = ledger.inspect_person_status(person_id)
			for target in entities:
				var affiliation: String = str(target.controller).trim_suffix("-hq") if target.kind == "CARRIER" else str(target.owner)
				if target.kind not in ["PERSON","CARRIER"] or affiliation not in ["army-blue","army-red"] or affiliation == observer.owner or target.get("assignment","") in ["Wounded","Dead"]: continue
				# The exact ordinary sight-range bound cannot produce a contact.
				# Reject it before terrain heights/rays or protected-hull inspection.
				if observer.position.distance_to(target.position) > maximum: continue
				# Protected occupants are observed through their hull, not as exposed people.
				if target.kind == "PERSON" and ledger.entity_kind(target.holder_id) == "CARRIER" and not _rear().vehicle_combat._exposed_gunner(target): continue
				if world.is_visible(observer.position,target.position):
					var estimated_strength := 10.0 if target.design_type == "T05" else (6.0 if target.design_type == "T04" else (3.0 if target.design_type == "T03" else 1.0))
					seen[target.id] = {"target":target.id,"class":target.design_type,"position":target.position,"observed_count":1,"observed_strength":estimated_strength,"source":person_id,"observed_at":_rear().time,"visible_facing":target.get("facing","Unknown")}
			for objective_id in objective_markers:
				if objective_affiliations.get(objective_id,"") == observer.owner: continue
				var place: Dictionary = ledger.inspect_entity(objective_id,{},false)
				if observer.position.distance_to(place.position) > maximum: continue
				if world.is_visible(observer.position,place.position):
					seen[objective_id] = {"target":objective_id,"class":objective_markers[objective_id],"position":place.position,"observed_count":1,"observed_strength":0.0,"source":person_id,"observed_at":_rear().time,"visible_facing":"Unknown"}
		visible[squad_id] = seen
		for target_id in seen:
			var row: Dictionary = seen[target_id]
			pending.append({"due":_rear().time+0.5,"kind":"Contact","destination":squad_id,"report":row})
		watch_squads[squad_id] = _rear().time

class CountedWorld extends World:
	var sampled: Array[Vector2] = []
	var trace: Array[Dictionary] = []
	func is_visible(observer: Vector2, target: Vector2, role: String = "ordinary") -> bool:
		sampled.append(target)
		trace.append({"observer":observer,"target":target,"role":role})
		return super.is_visible(observer,target,role)
var checks := 0
var failures := 0
func _initialize() -> void:
	var base := Base.new(false,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	var world := CountedWorld.new()
	world.bounds = Rect2i(0,0,4000,6000)
	rear.combat.world = world
	check(ledger.add_place("range-stage","Actual observer place",Vector2(2000,500)).ok,"Observer place")
	var roster: Array[String] = []
	for index in 4:
		var id := "range-person-%d" % index
		check(ledger.add_person(id,"range-stage",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual observer")
		check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual rifle")
		check(ledger.add_stock(id+"-rounds","E02",30,0.02,id,rear.PLAYER).ok,"Actual matching rounds")
		roster.append(id)
	check(rear.military.add_initial_squad("range-squad","Rifle",roster,"range-company","range-platoon",rear.PLAYER).ok,"Actual observation hierarchy")
	for item in [["inside",2219.0],["edge",2220.0],["outside",2220.01],["distant",3200.0]]:
		var id: String = "range-"+str(item[0])
		check(ledger.add_place(id+"-place","Actual hostile location",Vector2(item[1],500)).ok,"Actual hostile place")
		check(ledger.add_person(id,id+"-place","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual hostile person")
	check(ledger.add_place("range-hq","Actual hostile HQ marker",Vector2(2220,500)).ok,"Actual HQ at inclusive range")
	check(rear.orders.register_enemy_hq("range-hq").ok,"Scenario HQ declaration")
	_classification_targets(rear)
	check(rear.orders.watch("range-squad").ok,"Actual observation begins")
	rear.advance_time(0.5)
	check(rear.orders.contact("range-squad","range-inside").get("current",false),"Inside range retains actual delivered sight")
	check(rear.orders.contact("range-squad","range-edge").get("current",false),"Exact ordinary range remains inclusive")
	check(rear.orders.contact("range-squad","range-hq").get("current",false),"Exact-range objective marker still uses real sight and command sharing")
	check(rear.orders.contact("range-squad","range-outside").is_empty() and rear.orders.contact("range-squad","range-distant").is_empty(),"Out-of-range physical people produce no contact")
	check(not world.sampled.has(Vector2(2220.01,500)) and not world.sampled.has(Vector2(3200,500)),"Impossible out-of-range contacts do no terrain height or ray work")
	check(world.sampled.has(Vector2(2219,500)) and world.sampled.has(Vector2(2220,500)),"Feasible contacts still pass through actual terrain sight")
	_classification_parity(rear,world,roster)
	check(base.audit().is_empty(),"Range filtering changes no physical person, weapon or round")
	print("Observation range regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _classification_targets(rear: RefCounted) -> void:
	var ledger: RefCounted = rear.ledger
	check(ledger.add_place("candidate-stage","Actual classification targets",Vector2(2000,600)).ok,"Classification stage")
	check(ledger.add_place("candidate-blue-hq","Actual friendly HQ marker",Vector2(2000,500)).ok and rear.orders.register_enemy_hq("candidate-blue-hq",rear.PLAYER).ok,"Friendly HQ marker")
	var red_roster: Array[String] = []
	for index in 4:
		var id: String = "candidate-red-%d" % index
		check(ledger.add_person(id,"candidate-stage","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual red observer")
		check(ledger.add_weapon(id+"-rifle","E01",4,id,"army-red","E02",30).ok and ledger.add_stock(id+"-rounds","E02",30,0.02,id,"army-red").ok,"Actual red observer package")
		red_roster.append(id)
	check(rear.military.add_initial_squad("candidate-red-squad","Rifle",red_roster,"candidate-red-company","candidate-red-platoon","army-red").ok,"Actual red observation hierarchy")
	for type in ["T03","T04"]:
		var hull: String = "candidate-"+type
		check(ledger.add_initial_vehicle(hull,type,"candidate-stage","army-red",Specs.TYPES[type],0,"Military").ok,"Physical target hull")
		check(ledger.add_person(hull+"-gunner","candidate-stage","army-red",Records.Assignment.AVAILABLE,true,"P04" if type == "T03" else "P08","None").ok,"Actual qualified gunner")
		check(ledger.assign_initial_vehicle_crew(hull+"-gunner",hull,"Gunner").ok,"Actual occupied gunner station")
	check(ledger.add_person("candidate-passenger","candidate-stage","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok and ledger.board_dispatch_passenger("candidate-passenger","candidate-T04").ok,"Actual protected passenger")
	check(ledger.add_carrier("candidate-controlled","candidate-stage","army-red","army-blue-hq").ok,"Foreign owned friendly-controlled carrier")
	check(ledger.add_carrier("candidate-hostile-control","candidate-stage",rear.PLAYER,"army-red-hq").ok,"Own owned hostile-controlled carrier")
	check(ledger.add_carrier("candidate-supplier","candidate-stage","supplier","supplier").ok,"External supplier is not a hostile army")
	for state in ["wounded","dead","recovery"]:
		var id: String = "candidate-"+state
		check(ledger.add_person(id,"candidate-stage","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual status target")
		if state == "dead": check(ledger.kill_person(id,"Classification fixture casualty").ok,"Actual dead target")
		else:
			check(ledger.injure_person(id,100).ok,"Actual wounded target")
			if state == "recovery": check(ledger.finish_field_care(id).ok,"Actual Recovery remains eligible under original predicate")

func _sample_state(orders: RefCounted, squad_id: String) -> Dictionary:
	return {"visible":orders.visible,"visible_ids":orders.visible.keys(),"seen_ids":orders.visible.get(squad_id,{}).keys(),"pending":orders.pending,"watch":orders.watch_squads,"watch_ids":orders.watch_squads.keys(),"next":orders.get("_next_observation"),"contacts":orders.contacts}

func _sample_parity(rear: RefCounted, world: RefCounted, squad_id: String, entities: Array, label: String) -> void:
	var prior := PriorOrders.new(rear)
	for key in ["visible","pending","watch_squads","contacts","objective_markers","objective_affiliations"]: prior.set(key,rear.orders.get(key).duplicate(true))
	prior.set("_next_observation",rear.orders.get("_next_observation"))
	var physical_before: Dictionary = rear.ledger.snapshot(false)
	world.trace.clear()
	prior._sample_squad(squad_id,entities)
	var expected_trace: Array = world.trace.duplicate(true)
	world.trace.clear()
	rear.orders._sample_squad(squad_id,entities)
	check(var_to_bytes(_sample_state(rear.orders,squad_id)) == var_to_bytes(_sample_state(prior,squad_id)),label+": independent prior visible/source/order/pending/watch/contact state matches exactly")
	check(world.trace == expected_trace,label+": ordered real observer/target/role terrain calls remain identical")
	check(rear.ledger.snapshot(false) == physical_before,label+": sampling does not mutate physical state or time")

func _classification_parity(rear: RefCounted, world: RefCounted, roster: Array[String]) -> void:
	var ledger: RefCounted = rear.ledger
	_sample_parity(rear,world,"range-squad",[],"Blue default snapshot")
	var seen: Dictionary = rear.orders.visible["range-squad"]
	check(seen["range-inside"].source == roster[-1],"Last observing roster member retains source precedence")
	check(not seen.has("candidate-wounded") and not seen.has("candidate-dead") and seen.has("candidate-recovery"),"Only original Wounded/Dead assignment exclusions apply")
	check(not seen.has("candidate-passenger") and not seen.has("candidate-T04-gunner") and seen.has("candidate-T03-gunner"),"Protected occupant and actual exposed-gunner checks remain per target")
	check(not seen.has("candidate-controlled") and seen.has("candidate-hostile-control") and not seen.has("candidate-supplier"),"Carrier controller and army whitelist remain exact")
	_sample_parity(rear,world,"candidate-red-squad",[],"Red actual owner")
	check(not rear.orders.visible["candidate-red-squad"].has("range-hq") and rear.orders.visible["candidate-red-squad"].has("candidate-blue-hq"),"Each actual owner excludes its own HQ marker")
	var supplied: Array = ledger.snapshot(false).entities
	supplied.reverse()
	supplied.append(ledger.inspect_person_status("range-inside"))
	_sample_parity(rear,world,"range-squad",supplied,"Supplied reversed snapshot with repeated physical target row")
	check(world.trace.filter(func(row: Dictionary) -> bool: return row.target == Vector2(2219,500)).size() == roster.size()*2,"Repeated target rows retain every observer's real sight evaluation")
	# Isolated read-boundary fixture: restore the same identity's owner before
	# auditing. Formation affiliation cannot substitute for actual observer owner.
	ledger._entities[roster[-1]].owner = "army-red"
	_sample_parity(rear,world,"range-squad",[],"Mixed actual owners within one active roster")
	check(rear.orders.visible["range-squad"]["range-inside"].source == roster[-2] and rear.orders.visible["range-squad"][roster[0]].source == roster[-1],"Per-owner lists do not reorder interleaved source overwrites")
	ledger._entities[roster[-1]].owner = rear.PLAYER
	_sample_parity(rear,world,"range-squad",[],"Restored owner on same service sees fresh classification")
	check(ledger.move_entity("range-inside","range-inside-place",Vector2(3200,500)).ok,"Actual target moves out of range")
	ledger._entities["candidate-hostile-control"].controller = "army-blue-hq"
	check(ledger.injure_person("candidate-recovery",35).ok,"Actual Recovery becomes Wounded")
	_sample_parity(rear,world,"range-squad",[],"Same service after position/controller/assignment changes")
	check(ledger.move_entity("range-inside","range-inside-place",Vector2(2219,500)).ok and ledger.finish_field_care("candidate-recovery").ok,"Actual target and patient return to eligible facts")
	ledger._entities["candidate-hostile-control"].controller = "army-red-hq"
	_sample_parity(rear,world,"range-squad",[],"Changed facts restored without cross-call candidate reuse")
	var squad: Dictionary = rear.military.squads["range-squad"]
	var saved_roster: Array = squad.roster
	squad.roster = []
	_sample_parity(rear,world,"range-squad",[],"No active observers")
	squad.roster = saved_roster
	squad.state = "Reporting"
	_sample_parity(rear,world,"range-squad",[],"Inactive formation retains unwatch behavior")
	squad.state = "Active"
	_sample_parity(rear,world,"missing-squad",[],"Missing formation retains default unwatch behavior")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
