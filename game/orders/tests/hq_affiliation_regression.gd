extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
var failures := 0
func _initialize() -> void:
	var base := Base.new(false,true)
	var rear: RefCounted = base.rear
	for side in ["blue","red"]:
		var owner: String = "army-"+side
		var place: String = side+"-hq-observation"
		check(rear.ledger.add_place(place,"Declared actual HQ",Vector2(2000,500 if side == "blue" else 600)).ok,"Physical HQ place")
		check(rear.orders.register_enemy_hq(place,owner).ok,"Actual HQ affiliation")
		var roster: Array[String] = []
		for index in 4:
			var id: String = side+"-observer-%d" % index
			check(rear.ledger.add_person(id,place,owner,Records.Assignment.AVAILABLE,true,"None","None").ok,"Real observer")
			check(rear.ledger.add_weapon(id+"-rifle","E01",4,id,owner,"E02",30).ok,"Actual rifle")
			check(rear.ledger.add_stock(id+"-rounds","E02",60,0.02,id,owner).ok,"Actual rounds")
			roster.append(id)
		check(rear.military.add_initial_squad(side+"-observers","Rifle",roster,side+"-company",side+"-platoon",owner).ok,"Actual army formation")
		check(rear.orders.watch(side+"-observers").ok,"Actual observation assignment")
	rear.advance_time(5)
	for side in ["blue","red"]:
		check(rear.orders.contact(side+"-observers",side+"-hq-observation").is_empty(),"Own HQ never becomes a hostile contact")
		var other := "red" if side == "blue" else "blue"
		check(not rear.orders.contact(side+"-observers",other+"-hq-observation").is_empty(),"Visible opposing HQ still delivers a real contact")
	check(base.audit().is_empty(),"HQ observation leaves the physical ledger intact")
	print("HQ affiliation regression: ",failures," failures")
	quit(0 if failures == 0 else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
