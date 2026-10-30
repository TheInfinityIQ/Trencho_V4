extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Presentation = preload("res://game/battlefield/battlefield_presentation.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
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
	_check(Presentation.inspect(rear,"hidden-person").is_empty(),"Unobserved hostile cannot be drawn or inspected")
	_check(rear.military.add_initial_squad("observer-squad","Rifle",roster,"observer-company","observer-platoon",rear.PLAYER).ok,"Actual observing formation")
	_check(rear.orders.watch("observer-squad").ok,"Watch uses actual observers")
	rear.advance_time(5)
	var known: Dictionary = Presentation.inspect(rear,"hidden-person")
	_check(known.get("kind","") == "CONTACT" and known.position == Vector2(2000,600),"Delivered contact becomes a report marker")
	_check(not known.has("health") and not known.has("holder_id") and not known.has("assignment"),"Contact exposes no hidden health or duty")
	_check(ledger.move_entity("hidden-person","hostile-stage",Vector2(2500,1500)).ok,"Hostile moves beyond observation")
	rear.advance_time(2)
	known = Presentation.inspect(rear,"hidden-person")
	_check(known.position == Vector2(2000,600) and known.age > 0 and known.uncertainty_m > 0,"Hidden movement retains aged reported position")
	rear.advance_time(55)
	_check(Presentation.inspect(rear,"hidden-person").is_empty(),"Expired contact is no longer selectable")
	_check(not Presentation.inspect(rear,"observer-0").is_empty(),"Own real person remains inspectable")
	_check(base.audit().is_empty(),"Information view never mutates physical facts")
	print("Battlefield presentation regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
