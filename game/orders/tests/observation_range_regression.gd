extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const World = preload("res://game/terrain/terrain_world.gd")
const Records = preload("res://game/identity/identity_records.gd")
class CountedWorld extends World:
	var sampled: Array[Vector2] = []
	func is_visible(observer: Vector2, target: Vector2, role: String = "ordinary") -> bool:
		sampled.append(target)
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
	check(rear.orders.watch("range-squad").ok,"Actual observation begins")
	rear.advance_time(0.5)
	check(rear.orders.contact("range-squad","range-inside").get("current",false),"Inside range retains actual delivered sight")
	check(rear.orders.contact("range-squad","range-edge").get("current",false),"Exact ordinary range remains inclusive")
	check(rear.orders.contact("range-squad","range-hq").get("current",false),"Exact-range objective marker still uses real sight and command sharing")
	check(rear.orders.contact("range-squad","range-outside").is_empty() and rear.orders.contact("range-squad","range-distant").is_empty(),"Out-of-range physical people produce no contact")
	check(not world.sampled.has(Vector2(2220.01,500)) and not world.sampled.has(Vector2(3200,500)),"Impossible out-of-range contacts do no terrain height or ray work")
	check(world.sampled.has(Vector2(2219,500)) and world.sampled.has(Vector2(2220,500)),"Feasible contacts still pass through actual terrain sight")
	check(base.audit().is_empty(),"Range filtering changes no physical person, weapon or round")
	print("Observation range regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
