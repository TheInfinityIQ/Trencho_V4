extends RefCounted
## GDD20.1 physical starting package, applied only while constructing a new session.
const Specs = preload("res://game/production/vehicle_specs.gd")
const STOCK := {"M01":600,"M02":300,"M03":200,"M04":600,"M05":100,"M06":40,"M07":40,"M08":200,"M09":40,"M10":20,"M11":500}
const STAFF := {"receiving":4,"workshop":4,"munitions":4,"support":0,"materials":6,"vehicle_works":4,"training":2,"dispatch":4,"hauling":16,"construction":2}

static func apply(base: RefCounted) -> void:
	var rear: RefCounted = base.rear
	assert(rear.time == 0.0 and rear.actors.is_empty())
	for i in 42: _must(rear.add_person("start-p00-%02d" % i))
	for i in 12: _must(rear.add_person("start-p01-%02d" % i,true))
	for i in 6: _must(rear.add_person("start-p08-%02d" % i,true,"P08"))
	for type in STOCK: _must(rear.ledger.add_stock("start-depot-"+type,type,STOCK[type],1.0,"depot",rear.PLAYER))
	_must(rear.construction.add_initial_park("initial-park-west",Vector2(80,145)))
	for i in 3:
		var type := "T02" if i == 2 else "T01"
		var id := "start-vehicle-%02d" % i
		_must(rear.ledger.add_initial_vehicle(id,type,"vehicle-lane",rear.PLAYER,Specs.TYPES[type],40.0))
		_must(rear.vehicles.register_initial_parked(id,i,"start-p08-%02d" % i))
	# Reserve qualified instructors before ordinary labour targets compete for people.
	_must(rear.set_target("training",2))
	for duty in STAFF:
		if duty != "training": _must(rear.set_target(duty,STAFF[duty]))
	# These people are present at the declared opening, not walking in from a prior session.
	for id in rear.actors:
		var person: Dictionary = rear.ledger.inspect_entity(id)
		if person.duty_id.is_empty() or not person.crew_station.is_empty(): continue
		_must(rear.ledger.move_entity(id,"rear",rear.ledger.inspect_entity(rear.requests[person.duty_id].place).position))
		rear.actors[id].motion = {}
		rear.actors[id].deadline = INF
		rear.actors[id].phase = "Idle"
	rear.heavy_production.start_without_recipe()
	_must(rear.production.set_stock_target(32))
	_must(rear.munitions_production.set_stock_target(6000))
	_must(rear.materials_production.set_stock_target(1000))

static func _must(result: Dictionary) -> void:
	if not result.ok: push_error(str(result))
	assert(result.ok,"Starting package initialization failed")
