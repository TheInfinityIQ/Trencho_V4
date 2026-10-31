extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Presentation = preload("res://game/battlefield/battlefield_presentation.gd")
const View = preload("res://game/battlefield/battlefield_view.tscn")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	var base: RefCounted = Base.new(true,true,true,Vector2(2000,450),false)
	var rear: RefCounted = base.rear
	for side in ["blue","red","neutral"]:
		var place: String = "ownership-"+side
		var at := Vector2(2000,2200 if side == "blue" else (3000 if side == "red" else 3800))
		check(rear.ledger.add_place(place,"Resource",at).ok,"actual objective place")
		check(rear.objectives.register(place,"Resource").ok,"actual objective registration")
		check(Presentation.inspect(rear,place).ownership_label == "Neutral","uncaptured objective starts neutral")
		if side == "neutral": continue
		var roster: Array[String] = []
		for index in 4:
			var id: String = side+"-capture-%d" % index
			check(rear.ledger.add_person(id,place,"army-"+side,Records.Assignment.AVAILABLE,true,"None","None").ok,"actual capture member")
			check(rear.ledger.add_weapon(id+"-rifle","E01",4,id,"army-"+side,"E02",30).ok,"actual rifle")
			check(rear.ledger.add_stock(id+"-rounds","E02",60,0.02,id,"army-"+side).ok,"actual ammunition")
			roster.append(id)
		check(rear.military.add_initial_squad(side+"-capture","Rifle",roster,side+"-company",side+"-platoon","army-"+side).ok,"actual capture squad")
	rear.advance_time(60)
	var view: Control = View.instantiate()
	view.simulation = base
	root.add_child(view)
	await process_frame
	var labels := {"blue":"Friendly","red":"Enemy","neutral":"Neutral"}
	var colours := {"blue":Color("74c8ed"),"red":Color("e48378"),"neutral":Color("f0c565")}
	for side in labels:
		var id: String = "ownership-"+side
		var marker: Dictionary = Presentation.inspect(rear,id)
		check(rear.objectives.inspect(id).owner == ("" if side == "neutral" else "army-"+side),"real common-clock capture establishes ownership")
		check(marker.ownership_label == labels[side] and marker.ownership_colour == colours[side],"objective ring follows actual captured affiliation")
		check(marker.kind == "PLACE" and marker.design_type == "Place","ownership decoration preserves objective marker identity")
		check(not marker.has("blue") and not marker.has("red") and not marker.has("blockers"),"ownership marker exposes no capture participant internals")
		view.selected_id = id
		view._refresh()
		var text: String = view.get("_inspector").text
		check(text.contains("Owner: "+labels[side]) and not text.contains("army-blue") and not text.contains("army-red"),"selected objective uses player-facing ownership words")
	check(Presentation.ownership_label("army-red","army-red") == "Friendly" and Presentation.ownership_label("army-blue","army-red") == "Enemy","ownership words follow player affiliation")
	check(base.audit().is_empty(),"read-only ownership view preserves physical capture facts")
	view.queue_free()
	await process_frame
	print("Objective ownership regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
