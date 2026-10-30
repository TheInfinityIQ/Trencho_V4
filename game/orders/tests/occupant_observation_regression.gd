extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
const Specs = preload("res://game/production/vehicle_specs.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func squad(rear: RefCounted, side: String, role: String, place: String) -> String:
	var id: String = side+"-"+role
	var roster: Array[String] = []
	for index in 4:
		var person: String = id+"-%d" % index
		check(rear.ledger.add_person(person,place,"army-"+side,Records.Assignment.AVAILABLE,true,"None","None").ok,"real person")
		check(rear.ledger.add_weapon(person+"-rifle","E01",4,person,"army-"+side,"E02",30).ok,"real rifle")
		check(rear.ledger.add_stock(person+"-rounds","E02",60,0.02,person,"army-"+side).ok,"real ammo")
		roster.append(person)
	check(rear.military.add_initial_squad(id,"Rifle",roster,id+"-company",id+"-platoon","army-"+side).ok,"real squad")
	return id

func board(rear: RefCounted, side: String) -> bool:
	var id: String = side+"-passengers"
	var hull: String = side+"-T04"
	if not rear.military._reserve_transport_manifest(hull,[id]).ok: return false
	for person in rear.military.squads[id].roster:
		if not rear.ledger.board_formation_passenger(person,hull).ok: return false
	return true

func _initialize() -> void:
	var base: RefCounted = Base.new(false,true)
	var rear: RefCounted = base.rear
	for side in ["blue","red"]:
		var owner: String = "army-"+side
		var place: String = side+"-observation-place"
		check(rear.ledger.add_place(place,"Actual observation fixture",Vector2(2000,500 if side == "blue" else 600)).ok,"physical place")
		squad(rear,side,"observers",place)
		var passengers: String = squad(rear,side,"passengers",place)
		for type in ["T04","T03"]:
			var hull: String = side+"-"+type
			check(rear.ledger.add_initial_vehicle(hull,type,place,owner,Specs.TYPES[type],float(Specs.TYPES[type].tank_capacity),"Military").ok,"actual hull")
			for station in Specs.TYPES[type].stations:
				var crew: String = hull+"-"+str(station)
				check(rear.ledger.add_person(crew,place,owner,Records.Assignment.AVAILABLE,true,"P04" if type == "T03" and station == "Gunner" else "P08","None").ok,"actual qualified crew")
				check(rear.ledger.assign_initial_vehicle_crew(crew,hull,station).ok,"actual seated crew")
			check(rear.military.attach_initial_vehicle(hull,passengers+"-platoon").ok,"actual military element")
		check(board(rear,side),"actual separate passenger squad boards")
	for side in ["blue","red"]: check(rear.orders.watch(side+"-observers").ok,"real observer watches")
	rear.advance_time(0.5)
	for side in ["blue","red"]:
		var other := "red" if side == "blue" else "blue"
		var observer: String = side+"-observers"
		for station in Specs.TYPES.T04.stations:
			check(rear.orders.contact(observer,other+"-T04-"+str(station)).is_empty(),"protected hostile T04 crew has no individual report")
		for index in 4: check(rear.orders.contact(observer,other+"-passengers-%d" % index).is_empty(),"protected hostile passenger has no individual report")
		check(rear.orders.contact(observer,other+"-T03-Driver").is_empty(),"protected T03 driver stays concealed")
		check(not rear.orders.contact(observer,other+"-T03-Gunner").is_empty(),"exposed T03 gunner remains observed")
		var hull: Dictionary = rear.orders.contact(observer,other+"-T04")
		check(not hull.is_empty() and hull.current and hull.observed_strength == 6,"actual hull remains current without separately counting concealed occupants")
		check(rear.orders.contact(observer,side+"-T04").is_empty(),"own hull does not become hostile")
	for side in ["blue","red"]: check(rear.military.exit_squad(side+"-passengers",side+"-observation-place").ok,"actual squad dismount")
	rear.advance_time(0.5)
	for side in ["blue","red"]:
		var other := "red" if side == "blue" else "blue"
		check(rear.orders.contact(side+"-observers",other+"-passengers-0").is_empty(),"next sample still needs actual half-second report delay")
	rear.advance_time(0.5)
	var observed_at := {}
	for side in ["blue","red"]:
		var other := "red" if side == "blue" else "blue"
		var report: Dictionary = rear.orders.contact(side+"-observers",other+"-passengers-0")
		check(not report.is_empty() and report.current and is_equal_approx(report.observed_at,1) and is_equal_approx(report.age,0.5),"dismounted actual person reports original sample time, delay and current source")
		observed_at[side] = report.observed_at
	for side in ["blue","red"]: check(board(rear,side),"same actual people reboard")
	rear.advance_time(0.5)
	for side in ["blue","red"]:
		var other := "red" if side == "blue" else "blue"
		var report: Dictionary = rear.orders.contact(side+"-observers",other+"-passengers-0")
		check(not report.current and report.observed_at == observed_at[side] and report.age >= 1,"reboarded person's old report ages without current sight or hidden-state refresh")
	check(base.audit().is_empty(),"observation and real seating reconcile: "+str(base.audit()))
	print("Occupant observation regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
