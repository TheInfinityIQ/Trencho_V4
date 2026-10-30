extends SceneTree
const Base = preload("res://game/rear_base/base_simulation.gd")
const Records = preload("res://game/identity/identity_records.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var base := Base.new(true,true,false,Vector2(2000,400))
	var rear: RefCounted = base.rear
	var ledger: RefCounted = rear.ledger
	for side in ["blue","red"]:
		var owner: String = "army-"+side
		var place: String = side+"-stage"
		_check(ledger.add_place(place,"Declared staging",Vector2(2000,500 if side == "blue" else 600)).ok,"Declared staging place")
		var roster: Array[String] = []
		for index in 4:
			var id: String = side+"-person-%d" % index
			_check(ledger.add_person(id,place,owner,Records.Assignment.AVAILABLE,true,"None","None").ok,"Actual starting person")
			_check(ledger.add_weapon(id+"-rifle","E01",4,id,owner,"E02",30).ok,"Actual rifle")
			_check(ledger.add_stock(id+"-rounds","E02",60,0.02,id,owner).ok,"Actual initial rounds")
			roster.append(id)
		var registered: Dictionary = rear.military.add_initial_squad(side+"-squad","Rifle",roster,side+"-company",side+"-platoon",owner)
		_check(registered.ok,"Initial squad registered: "+str(registered))
		_check(not rear.military.add_initial_squad(side+"-duplicate","Rifle",roster,side+"-company",side+"-platoon",owner).ok,"Same people cannot occupy another initial squad")
		_check(rear.orders.watch(side+"-squad").ok,"Both armies observe through actual squad members")
	_check(ledger.add_carrier("supplier-sample","blue-stage","supplier","supplier").ok,"Supplier remains a service actor")
	_check(ledger.add_carrier("leased-sample","blue-stage","supplier","army-blue-hq").ok,"Army-controlled leased vehicle has explicit HQ affiliation")
	_check(not rear.orders.issue_order("army","red-company","Hold Area","Hold","Initial defence",{},"Normal","HQ").ok,"One army cannot order the opposing company")
	rear.advance_time(6)
	_check(rear.orders.contacts.get("army",{}).has("red-person-0"),"Blue command receives actual red contact")
	_check(rear.orders.contacts.get("army-red",{}).has("blue-person-0"),"Red command receives actual blue contact")
	_check(not rear.orders.contacts.get("army",{}).has("blue-person-0") and not rear.orders.contacts.get("army-red",{}).has("red-person-0"),"Opposing command forests never share observation channels")
	_check(not rear.orders.contacts.get("army",{}).has("supplier-sample") and not rear.orders.contacts.get("army-red",{}).has("supplier-sample"),"Supplier identity is not classified as an opposing army")
	_check(rear.orders.contacts.get("army-red",{}).has("leased-sample") and not rear.orders.contacts.get("army",{}).has("leased-sample"),"Control determines leased vehicle combat affiliation")
	_check(rear.orders.report("red-squad","Progress","Initial position held").ok,"Red subordinate sends a real report")
	rear.advance_time(4)
	var red_report_delivered := false
	for report in rear.orders.reports:
		if report.source == "red-squad" and report.current_at == "army-red" and report.state == "Delivered to Commander": red_report_delivered = true
	_check(red_report_delivered,"Red progress reaches its own Commander instead of being dropped at the root")
	var no_people: Array[String] = []
	_check(not rear.military.add_initial_squad("late","Rifle",no_people,"late-company","late-platoon","army-red").ok,"Starting formation API closes after time zero")
	_check(base.audit().is_empty(),"Both real command forests preserve ledger and membership: "+str(base.audit()))
	print("Army hierarchy regression: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
