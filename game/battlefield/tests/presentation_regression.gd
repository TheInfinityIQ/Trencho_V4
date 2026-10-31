extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Presentation = preload("res://game/battlefield/battlefield_presentation.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_projection_cases()
	var base := Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	_check(ledger.add_place("sight-stage","Actual observer staging",Vector2(2000,500)).ok,"Observer place")
	_check(ledger.add_place("hostile-stage","Actual hostile place",Vector2(2000,600)).ok,"Hostile place")
	var roster: Array[String] = []
	for index in 4:
		var id := "observer-%d" % index
		_check(ledger.add_person(id,"sight-stage",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual observer")
		_check(ledger.add_weapon(id+"-rifle","E01",4,id,rear.PLAYER,"E02",30).ok,"Actual observer rifle")
		_check(ledger.add_stock(id+"-rounds","E02",60,0.02,id,rear.PLAYER).ok,"Actual observer rounds")
		roster.append(id)
	_check(ledger.add_person("hidden-person","hostile-stage","army-red",Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual hostile person")
	_check(ledger.add_carrier("hidden-carrier","hostile-stage","army-red","army-red-hq","T01").ok,"Actual hostile carrier")
	_check(Presentation.inspect(rear,"hidden-person").is_empty(),"Unobserved hostile cannot be drawn or inspected")
	_parity(rear,["hidden-person","observer-0","missing"],"Before contact delivery")
	_check(rear.military.add_initial_squad("observer-squad","Rifle",roster,"observer-company","observer-platoon",rear.PLAYER).ok,"Actual observing formation")
	_check(rear.orders.watch("observer-squad").ok,"Watch uses actual observers")
	rear.advance_time(5)
	var known: Dictionary = Presentation.inspect(rear,"hidden-person")
	_check(known.get("kind","") == "CONTACT" and known.position == Vector2(2000,600),"Delivered contact becomes a report marker")
	_check(not known.has("health") and not known.has("holder_id") and not known.has("assignment"),"Contact exposes no hidden health or duty")
	_parity(rear,["hidden-person","observer-0","hq-berth"],"Delivered contact")
	# An isolated controller mutation models the visibility boundary of an
	# already-reported captured carrier; it does not claim a capture mechanic.
	ledger._entities["hidden-carrier"].controller = rear.PLAYER+"-hq"
	_parity(rear,["hidden-carrier"],"Physical controlled carrier wins over same-ID delivered contact")
	_check(Presentation.inspect(rear,"hidden-carrier").kind == "CARRIER","Physical marker precedes same-ID contact")
	ledger._entities["hidden-carrier"].controller = "army-red-hq"
	_check(ledger.move_entity("hidden-person","hostile-stage",Vector2(2500,1500)).ok,"Hostile moves beyond observation")
	rear.advance_time(2)
	known = Presentation.inspect(rear,"hidden-person")
	_check(known.position == Vector2(2000,600) and known.age > 0 and known.uncertainty_m > 0,"Hidden movement retains aged reported position")
	_parity(rear,["hidden-person","observer-0"],"Aged contact after actual hidden movement")
	rear.advance_time(55)
	_check(Presentation.inspect(rear,"hidden-person").is_empty(),"Expired contact is no longer selectable")
	_parity(rear,["hidden-person","observer-0"],"Expired contact")
	_check(not Presentation.inspect(rear,"observer-0").is_empty(),"Own real person remains inspectable")
	_check(base.audit().is_empty(),"Information view never mutates physical facts")
	print("Battlefield presentation regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _projection_cases() -> void:
	var base := Base.new(true,true)
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	_check(ledger.add_place("projection-stage","Physical projection fixture",Vector2(2000,500)).ok,"Projection place")
	_check(ledger.add_place("projection-marker","Public HQ marker",Vector2(2000,5500)).ok,"Public marker place")
	_check(rear.orders.register_enemy_hq("projection-marker").ok,"Public HQ without contact")
	_check(ledger.add_person("projection-person","projection-stage",rear.PLAYER,Records.Assignment.AVAILABLE,true,"None","None").ok,"Own field person")
	_check(ledger.add_weapon("projection-rifle","E01",4,"projection-person",rear.PLAYER,"E02",30).ok,"Actual held weapon metadata")
	_check(ledger.add_stock("projection-rounds","E02",20,0.02,"projection-person",rear.PLAYER).ok and ledger.load_rounds("projection-rifle","projection-rounds",5).ok,"Real loaded and loose metadata")
	_check(ledger.add_initial_vehicle("projection-hull","T02","projection-stage",rear.PLAYER,Specs.TYPES.T02,40,"Military").ok,"Own actual hull")
	_check(ledger.add_carrier("projection-controlled","projection-stage","army-red","army-blue-hq").ok,"Foreign owned player-controlled carrier")
	_check(ledger.add_carrier("projection-hostile-control","projection-stage",rear.PLAYER,"army-red-hq").ok,"Own owned enemy-controlled carrier")
	var ids: Array[String] = ["projection-person","projection-hull","projection-controlled","projection-hostile-control","base-person-01","projection-rifle","projection-stage","projection-marker","resource-central","hq-berth","missing",""]
	_parity(rear,ids,"Own/public/controller/rear/missing projections")
	_check(not Presentation.inspect(rear,"projection-person").aboard,"On-foot own person")
	_check(Presentation.inspect(rear,"projection-controlled").owner == "army-red" and Presentation.inspect(rear,"projection-controlled").affiliation == rear.PLAYER,"Carrier controller overrides physical ownership for affiliation only")
	_check(Presentation.inspect(rear,"projection-hostile-control").is_empty() and Presentation.inspect(rear,"base-person-01").is_empty(),"Hostile-controlled hull and rear person stay hidden")
	_check(ledger.board_dispatch_passenger("projection-person","projection-hull").ok,"Actual co-located passenger boards")
	_check(ledger.move_entity("projection-hull","projection-stage",Vector2(2050,525)).ok,"Actual hull and occupant change world position")
	_parity(rear,ids,"Aboard and actual hull movement")
	var aboard: Dictionary = Presentation.inspect(rear,"projection-person")
	_check(aboard.aboard and aboard.position == Vector2(2050,525),"Aboard marker uses actual moved hull position")
	_check(ledger.disembark_dispatch_passenger("projection-person","projection-hull","projection-stage").ok,"Actual passenger disembarks")
	rear.objectives.objectives["resource-central"].owner = "army-red"
	rear.objectives.objectives["resource-central"].control = -60.0
	rear.objectives.objectives["resource-central"].state = "Controlled"
	_parity(rear,ids,"Disembark and changed objective ownership fixture")
	_check(not Presentation.inspect(rear,"projection-person").aboard and Presentation.inspect(rear,"resource-central").ownership_label == "Enemy","Fresh selection sees changed aboard and public owner facts")
	_check(base.audit().is_empty(),"Projection fixtures preserve physical identities")

func _parity(rear: RefCounted, ids: Array[String], label: String) -> void:
	var expected: Array[Dictionary] = _prior_markers(rear)
	var before := {"contacts":rear.orders.contacts.duplicate(true),"visible":rear.orders.visible.duplicate(true),"pending":rear.orders.pending.duplicate(true),"reports":rear.orders.reports.duplicate(true)}
	_check(Presentation.markers(rear) == expected,label+": complete fields and canonical marker order match prior algorithm")
	for id in ids:
		var selected: Dictionary = {}
		for row in expected:
			if row.id == id: selected = row; break
		_check(Presentation.inspect(rear,id) == selected,label+": selected ID equals independent prior first marker: "+id)
	_check(before == {"contacts":rear.orders.contacts,"visible":rear.orders.visible,"pending":rear.orders.pending,"reports":rear.orders.reports},label+": contact ageing/currentness reads do not mutate observation owners")

func _prior_markers(rear: RefCounted) -> Array[Dictionary]:
	# Retained pre-optimization algorithm; does not call either new projection.
	var rows: Array[Dictionary] = []
	var entities: Array = rear.ledger.snapshot(false).entities
	var kinds := {}
	for entity in entities: kinds[entity.id] = entity.kind
	for entity in entities:
		if entity.kind == "PLACE":
			if rear.objectives.objectives.has(entity.id):
				var owner: String = str(rear.objectives.objectives[entity.id].owner)
				entity["ownership_label"] = Presentation.ownership_label(owner,rear.PLAYER)
				entity["ownership_colour"] = Presentation.ownership_colour(owner,rear.PLAYER)
			if entity.id == "hq-berth" or rear.objectives.objectives.has(entity.id) or rear.orders.objective_markers.has(entity.id): rows.append(entity)
		elif entity.kind in ["PERSON","CARRIER"]:
			var affiliation: String = str(entity.controller).trim_suffix("-hq") if entity.kind == "CARRIER" else str(entity.owner)
			if affiliation != rear.PLAYER: continue
			if entity.kind == "PERSON" and entity.rear_place == "Occupied": continue
			entity["affiliation"] = affiliation
			if entity.kind == "PERSON": entity["aboard"] = kinds.get(entity.holder_id,"") == "CARRIER"
			rows.append(entity)
	for target_id in rear.orders.contacts.get("army",{}):
		var report: Dictionary = rear.orders.contact("army",target_id)
		if report.is_empty() or report.confidence <= 0 or not report.position.is_finite() or report.get("class","") in ["Enemy HQ","Resource","Route Hub","Observation"]: continue
		rows.append({"id":target_id,"kind":"CONTACT","position":report.position,"owner":"army-red","affiliation":"army-red","class":report.get("class","Unknown"),"age":report.age,"confidence":report.confidence,"uncertainty_m":report.uncertainty_m})
	return rows

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
